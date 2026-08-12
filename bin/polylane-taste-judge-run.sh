#!/usr/bin/env bash
# polylane-taste-judge-run.sh — provider-neutral visual-judge campaign runner.
#
# Executes ONE immutable work-unit manifest (taste-judge-workunit/v1) with an
# isolated, uniquely-claimed run directory. It invokes the declared invocation
# adapter (a fixture here; a live provider adapter is owned by another lane and
# gated downstream), captures a complete raw-response receipt, and classifies the
# terminal outcome via the sibling deterministic parser. It never mints a live
# receipt and never infers a choice.
#
# Architecture (engineering:architecture ADR): orchestration (this file) is kept
# separate from the provider adapter — the adapter is a data field in the sealed
# manifest (.adapter.command + fingerprint); the runner only invokes and fingerprints
# it, and delegates every schema decision to polylane-taste-judge-parse.sh.
#
# Risk controls (operations:risk-assessment register):
#   - retry exhaustion: at most ONE retry, and only for infrastructure failure
#     (timeout / adapter unavailable / nonzero exit). Never after a substantive
#     vote or a parse failure.
#   - duplicate worker / crash-resume: CAS-style claim on the run dir keyed to the
#     manifest hash; a completed run replays its terminal exit idempotently; a
#     partial run finalizes from the sealed receipt without re-invoking the adapter.
#   - alias / stolen dir / mutated work unit: any manifest whose hash differs from
#     the dir's claim is refused (rc 3) and the incumbent is left untouched.
#   - fabrication: fingerprint mismatch or a missing adapter fails closed as
#     infrastructure — the adapter is never invoked and no response is fabricated.
#
# Terminal exit codes: 0 voted|abstained (substantive) · 1 failed-infra ·
#   2 failed-parse · 3 isolation refusal · 4 malformed/ineligible manifest.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PARSE="$HERE/polylane-taste-judge-parse.sh"
# Reuse the sibling parser's schema authority: manifest-shape validation, response
# classification, SHA helper and the duplicate-key-safe JSON guard. Its main() is
# BASH_SOURCE-guarded, so sourcing runs nothing.
# shellcheck source=/dev/null
. "$PARSE"

runlog() { echo "TASTE-JUDGE-RUN: $*" >&2; }

now_iso() { printf '%s' "${POLYLANE_TASTE_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"; }

# ---- run-dir receipt writers (atomic; append-only event log) ----------------

append_event() {
  local kind="$1" detail="${2:-}"
  jq -cn --arg k "$kind" --arg d "$detail" --arg wu "$WU" --arg now "$(now_iso)" \
    '{event:$k,detail:$d,work_unit_id:$wu,at:$now}' >> "$RD/events.jsonl"
}

write_state() {
  local status="$1" tmp="$RD/state.json.tmp.$$"
  jq -n --arg wu "$WU" --arg sess "$SESSION" --arg msha "$MANIFEST_SHA" \
     --arg disp "$DISPLAY" --arg status "$status" --argjson attempts "$ATTEMPTS" \
     --argjson retry "$RETRY_USED" --arg now "$(now_iso)" '
    {schema_version:"taste-judge-run-state/v1",work_unit_id:$wu,session_id:$sess,
     display_order:$disp,manifest_sha256:$msha,status:$status,attempts:$attempts,
     retry_used:$retry,updated_at:$now}' > "$tmp"
  [ -f "$RD/state.json" ] && cp "$RD/state.json" "$RD/state.json.bak" 2>/dev/null || true
  mv "$tmp" "$RD/state.json"
}

write_capture() {
  local dest="$1" n="$2" rc="$3" timed_out="$4" rsha="$5" rbytes="$6" start="$7" end="$8"
  jq -n --argjson attempt "$n" --arg fp "$ADAPTER_ACTUAL_FP" --argjson rc "$rc" \
     --argjson to "$timed_out" --arg rs "$rsha" --argjson rb "$rbytes" \
     --arg s "$start" --arg e "$end" '
    {schema_version:"taste-judge-capture/v1",attempt:$attempt,adapter_fingerprint:$fp,
     exit_code:$rc,timed_out:$to,response_sha256:$rs,response_bytes:$rb,
     started_at:$s,ended_at:$e}' > "$dest"
}

write_summary() {
  local status="$1" decision="$2" rsha="$3" code="$4" tmp="$RD/summary.json.tmp.$$"
  jq -n --arg wu "$WU" --arg sess "$SESSION" --arg mirror "$MIRROR" --arg role "$ROLE" \
     --arg disp "$DISPLAY" --arg status "$status" --argjson decision "$decision" \
     --arg rsha "$rsha" --argjson attempts "$ATTEMPTS" --argjson retry "$RETRY_USED" \
     --argjson code "$code" --arg msha "$MANIFEST_SHA" --arg now "$(now_iso)" '
    {schema_version:"taste-judge-run-summary/v1",work_unit_id:$wu,session_id:$sess,
     mirror_group_id:$mirror,role:$role,display_order:$disp,terminal_status:$status,
     decision:$decision,response_sha256:($rsha|if .=="" then null else . end),
     attempts:$attempts,retry_used:$retry,exit_code:$code,manifest_sha256:$msha,
     sealed_at:$now}' > "$tmp"
  mv "$tmp" "$RD/summary.json"
}

# The request handed to the adapter binds only positions A/B (never candidate
# identity). The fixture reads .work_unit_id; a live adapter reads the rest.
write_request() {
  jq -n --arg wu "$WU" --arg judge "$JUDGE" --arg disp "$DISPLAY" --arg rs "$RESP_SCHEMA" \
     --arg imgA "$IMG_A" --arg imgB "$IMG_B" --arg brief "$BRIEF" --arg cap "$CAP" \
     --arg prompt "$PROMPT" --argjson deadline "$DEADLINE" '
    {schema_version:"taste-judge-request/v1",work_unit_id:$wu,judge_id:$judge,
     display_order:$disp,response_schema:$rs,images:{A:$imgA,B:$imgB},
     brief_sha256:$brief,capture_manifest_sha256:$cap,prompt_sha256:$prompt,
     deadline_s:$deadline}' > "$1"
}

# ---- adapter invocation with a portable deadline watchdog -------------------

# adapter_ready — the declared adapter exists, is executable, and matches the
# sealed fingerprint. Sets ADAPTER_ACTUAL_FP. Fail-closed: any doubt -> infra.
adapter_ready() {
  local bin="${CMD[0]:-}"
  [ -n "$bin" ] && [ -f "$bin" ] && [ -x "$bin" ] || return 1
  ADAPTER_ACTUAL_FP=$(sha256_file "$bin" 2>/dev/null) || return 1
  [ "$ADAPTER_ACTUAL_FP" = "$ADAPTER_FP" ]
}

TIMED_OUT=0
invoke_adapter() {
  local deadline="$1" req="$2" resp="$3" errf="$4" flag="$3.timedout"
  rm -f "$flag"
  "${CMD[@]}" "$req" >"$resp" 2>"$errf" &
  local pid=$!
  (
    sleep "$deadline"
    if kill -0 "$pid" 2>/dev/null; then
      : > "$flag"
      kill -TERM "$pid" 2>/dev/null || true
      sleep 1
      kill -KILL "$pid" 2>/dev/null || true
    fi
  ) &
  local watch=$! rc=0
  wait "$pid" 2>/dev/null || rc=$?
  kill -TERM "$watch" 2>/dev/null || true
  wait "$watch" 2>/dev/null || true
  TIMED_OUT=0
  [ -e "$flag" ] && TIMED_OUT=1
  rm -f "$flag"
  return "$rc"
}

# run_attempt N — one adapter invocation, immutable receipt, classified outcome
# into ATTEMPT_OUTCOME (vote|abstain|invalid|infra).
run_attempt() {
  local n="$1" adir="$RD/attempts/$1"
  mkdir -p "$adir"
  write_request "$adir/request.json"
  local resp="$adir/response.json" errf="$adir/stderr.log" start end rc=0
  start=$(now_iso)
  append_event attempt_start "$n"
  invoke_adapter "$DEADLINE" "$adir/request.json" "$resp" "$errf" || rc=$?
  end=$(now_iso)
  local timed_out=false; [ "$TIMED_OUT" = 1 ] && timed_out=true
  local rsha rbytes
  rsha=$( [ -f "$resp" ] && sha256_file "$resp" || echo "" )
  rbytes=$( [ -f "$resp" ] && wc -c < "$resp" | tr -d ' ' || echo 0 )
  write_capture "$adir/capture.json" "$n" "$rc" "$timed_out" "$rsha" "$rbytes" "$start" "$end"
  # Escrow the raw receipt immutably so no later step can rewrite a verdict.
  chmod 0444 "$resp" "$adir/capture.json" 2>/dev/null || true
  append_event attempt_captured "$n"
  if [ "$timed_out" = true ] || [ "$rc" -ne 0 ]; then
    ATTEMPT_OUTCOME=infra
  else
    local cls; cls=$(classify "$MANIFEST" "$resp") || true
    case "$cls" in vote) ATTEMPT_OUTCOME=vote ;; abstain) ATTEMPT_OUTCOME=abstain ;; *) ATTEMPT_OUTCOME=invalid ;; esac
  fi
}

# finalize STATUS EXIT_CODE ATTEMPT_N — seal the terminal receipts.
finalize() {
  local status="$1" code="$2" n="$3" resp="$RD/attempts/$3/response.json"
  local rsha="" decision=null choice
  [ -f "$resp" ] && rsha=$(sha256_file "$resp")
  case "$status" in
    voted)     choice=$(jq -r .choice "$resp"); decision="\"$choice\"" ;;
    abstained) decision="\"abstain\"" ;;
  esac
  write_summary "$status" "$decision" "$rsha" "$code"
  write_state "$status"
  append_event terminal "$status"
}

# finalize_from_receipt — a crash left a captured response but no terminal state.
# Finalize from the sealed receipt WITHOUT re-invoking the adapter.
finalize_from_receipt() {
  local n="" b d resp cap
  for d in "$RD"/attempts/*/; do
    b=$(basename "$d")
    case "$b" in ''|*[!0-9]*) continue ;; esac
    if [ -z "$n" ] || [ "$b" -gt "$n" ]; then n="$b"; fi
  done
  [ -n "$n" ] || { finalize failed-infra 1 1; return 1; }
  ATTEMPTS=$(jq -r '.attempts // 1' "$RD/state.json" 2>/dev/null || echo "$n")
  RETRY_USED=$(jq -r '.retry_used // false' "$RD/state.json" 2>/dev/null || echo false)
  resp="$RD/attempts/$n/response.json"; cap="$RD/attempts/$n/capture.json"
  [ -f "$resp" ] || { finalize failed-infra 1 "$n"; return 1; }
  # Integrity: the escrowed hash must still match the escrowed bytes.
  if [ -f "$cap" ]; then
    local capsha actual; capsha=$(jq -r '.response_sha256 // ""' "$cap"); actual=$(sha256_file "$resp")
    [ "$capsha" = "$actual" ] || { finalize failed-parse 2 "$n"; return 2; }
  fi
  local cls; cls=$(classify "$MANIFEST" "$resp") || true
  case "$cls" in
    vote)    finalize voted 0 "$n"; return 0 ;;
    abstain) finalize abstained 0 "$n"; return 0 ;;
    *)       finalize failed-parse 2 "$n"; return 2 ;;
  esac
}

# drive_attempts — fresh execution with bounded infra retry.
can_retry() { [ "$RETRY_USED" = false ] && [ "$1" -lt 2 ]; }
drive_attempts() {
  ATTEMPTS=0; RETRY_USED=false
  local n=1
  while :; do
    ATTEMPTS=$n
    write_state running
    if ! adapter_ready; then
      append_event adapter_unavailable "$n"
      if can_retry "$n"; then RETRY_USED=true; n=2; continue; fi
      finalize failed-infra 1 "$n"; return 1
    fi
    run_attempt "$n"
    case "$ATTEMPT_OUTCOME" in
      vote)    finalize voted 0 "$n"; return 0 ;;
      abstain) finalize abstained 0 "$n"; return 0 ;;
      invalid) finalize failed-parse 2 "$n"; return 2 ;;  # parse failure -> no retry
      infra)
        if can_retry "$n"; then RETRY_USED=true; n=2; append_event retry "$n"; continue; fi
        finalize failed-infra 1 "$n"; return 1 ;;
    esac
  done
}

# read_claim_sha — the manifest hash this dir is claimed by, from whichever
# receipt survives (summary first, then state, then its atomic backup). Corrupt
# JSON is skipped, never fatal. Also sets CLAIM_TERMINAL / CLAIM_CODE from a
# terminal summary.
CLAIM_SHA=""; CLAIM_TERMINAL=""; CLAIM_CODE=""
read_claim() {
  CLAIM_SHA=""; CLAIM_TERMINAL=""; CLAIM_CODE=""
  local f
  if regular_json_without_duplicate_keys "$RD/summary.json"; then
    CLAIM_SHA=$(jq -r '.manifest_sha256 // ""' "$RD/summary.json")
    CLAIM_TERMINAL=$(jq -r '.terminal_status // ""' "$RD/summary.json")
    CLAIM_CODE=$(jq -r '.exit_code // ""' "$RD/summary.json")
    return 0
  fi
  for f in "$RD/state.json" "$RD/state.json.bak"; do
    if regular_json_without_duplicate_keys "$f"; then
      CLAIM_SHA=$(jq -r '.manifest_sha256 // ""' "$f"); return 0
    fi
  done
}

run_cmd() {
  MANIFEST="$1"; RD="$2"
  [ -f "$MANIFEST" ] || { runlog "manifest not found: $MANIFEST"; return 4; }
  MANIFEST_SHA=$(sha256_file "$MANIFEST")
  mkdir -p "$RD"

  # Isolation FIRST: a run dir is bound to exactly one immutable work unit. Any
  # manifest whose hash differs from the dir's claim is a foreign / mutated /
  # aliased unit and is refused (rc 3) before we even parse it — so a stolen dir
  # or a changed session/orientation can never touch the incumbent's state.
  read_claim
  if [ -n "$CLAIM_SHA" ] && [ "$CLAIM_SHA" != "$MANIFEST_SHA" ]; then
    runlog "isolation refusal: dir claimed by a different work unit"
    return 3
  fi

  validate_manifest_shape "$MANIFEST" || { runlog "manifest is malformed or ineligible"; return 4; }

  WU=$(jq -r .work_unit_id "$MANIFEST")
  SESSION=$(jq -r .session_id "$MANIFEST")
  DISPLAY=$(jq -r .display_order "$MANIFEST")
  ROLE=$(jq -r .role "$MANIFEST")
  MIRROR=$(jq -r .mirror_group_id "$MANIFEST")
  JUDGE=$(jq -r .judge_id "$MANIFEST")
  DEADLINE=$(jq -r .deadline_s "$MANIFEST")
  RESP_SCHEMA=$(jq -r .response_schema "$MANIFEST")
  IMG_A=$(jq -r .images.A "$MANIFEST"); IMG_B=$(jq -r .images.B "$MANIFEST")
  BRIEF=$(jq -r .brief_sha256 "$MANIFEST"); CAP=$(jq -r .capture_manifest_sha256 "$MANIFEST")
  PROMPT=$(jq -r .prompt_sha256 "$MANIFEST")
  ADAPTER_FP=$(jq -r .adapter.fingerprint "$MANIFEST")
  CMD=()
  while IFS= read -r line; do CMD+=("$line"); done < <(jq -r '.adapter.command[]' "$MANIFEST")

  # --- claim matches: resume idempotently, never re-invoking the adapter -----
  if [ -n "$CLAIM_SHA" ]; then            # == MANIFEST_SHA
    if [ -n "$CLAIM_TERMINAL" ]; then
      return "${CLAIM_CODE:-0}"           # duplicate worker: replay the sealed exit
    fi
    finalize_from_receipt; return $?       # partial completion: finalize from receipt
  fi

  drive_attempts
}

main() {
  command -v jq >/dev/null 2>&1 || { runlog "jq is required"; return 4; }
  case "${1:-}" in
    run) [ $# -eq 3 ] || { runlog "usage: polylane-taste-judge-run.sh run <manifest> <run-dir>"; return 2; }
         run_cmd "$2" "$3" ;;
    *)   runlog "usage: polylane-taste-judge-run.sh run <manifest> <run-dir>"; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
