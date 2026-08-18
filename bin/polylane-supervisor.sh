#!/usr/bin/env bash
#
# polylane-supervisor.sh <manifest.json> [runner-args...]
#
# Crash-proof outer loop for polylane-run.sh — makes RUNNER DEATH A NON-EVENT.
# Real runs (Twin Delta, LeLau: 5,400+ message sessions) showed the dominant
# failure mode is not bad lane work but the long-lived runner dying mid-run
# ("runner died again — the recurring failure mode"), which silently stops
# polling, approval-relay, integration, and merge until a human notices. This
# supervisor owns the runner's lifecycle:
#
#   launch  : starts polylane-run.sh (with --yes) as a child, logs to a file
#   watch   : every POLYLANE_SUP_INTERVAL (5s) —
#               * drains permission prompts (approval relay OUTSIDE the runner,
#                 so a dead runner no longer strands lanes on approvals):
#                 SAFE -> auto-approve; CRITICAL -> park + notify (never answered)
#               * writes a heartbeat file (polylane-state.sh surfaces its age)
#   revive  : runner exited WITHOUT writing this run's report -> crash. Relaunch
#             with --resume (idempotent: DONE lanes are skipped) up to
#             POLYLANE_SUP_MAX_RESTARTS (10). A runner that DID write the report
#             ended with GO / EXTERNAL-EVIDENCE-OPEN / NO-GO -> clean cycle end.
#             A HALTED report is recoverable runner failure and is resumed.
#   halt    : restart cap exhausted -> notify halt, exit 1, worktrees intact.
#
# Panes are found by nonce-bound identity, not remembered index, so the relay
# works across restarts and agent cwd drift. `--check-once` runs a single watch
# tick with no launch (ops / tests). bash-3.2 safe.
#
# Env: POLYLANE_SESSION (tmux session), POLYLANE_SUP_INTERVAL, POLYLANE_SUP_MAX_RESTARTS.

set -euo pipefail

supervisor_usage() {
  cat <<'USAGE'
polylane-supervisor.sh — crash-proof outer loop for polylane-run.sh

USAGE:
  bin/polylane-supervisor.sh <manifest.json> [runner-args...]
  bin/polylane-supervisor.sh --help

The supervisor adds --yes when absent, relays safe approvals, and resumes a runner
that dies before writing a terminal report.
USAGE
}

case "${1:-}" in
  -h|--help) supervisor_usage; exit 0 ;;
  '') supervisor_usage >&2; exit 2 ;;
esac

SUP_MANIFEST="${1:?usage: polylane-supervisor.sh <manifest.json> [runner-args...]}"
shift || true

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# Runner is inert when sourced (main guarded by BASH_SOURCE) — reuse its
# detectors: pane_awaiting_approval, approval_is_critical, pane_stalled,
# lane_done, parse_verdict, notify_event.
# shellcheck source=polylane-run.sh
. "$SCRIPT_DIR/polylane-run.sh"
# Keep this explicit as well: packaged supervisors and test harnesses may swap
# in a minimal runner adapter, but tmux isolation remains a supervisor contract.
# shellcheck source=polylane-tmux.sh
. "$SCRIPT_DIR/polylane-tmux.sh"

TMUX_SESSION="${POLYLANE_SESSION:-$(jq -r '.session // "polylane"' "$SUP_MANIFEST")}"
SUP_INTERVAL="${POLYLANE_SUP_INTERVAL:-5}"
SUP_MAX_RESTARTS="${POLYLANE_SUP_MAX_RESTARTS:-10}"
# per-run nonce: the sourced lane_done must trust markers by the SAME run= tag the
# runner uses, else nonce-tagged DONE lanes read as not-done and get needlessly revived.
# shellcheck disable=SC2034  # consumed by the sourced runner's lane_done
RUN_ID=$(jq -r '.run_id // ""' "$SUP_MANIFEST")
polylane_tmux_configure "$RUN_ID" ensure

MDIR=$(cd "$(dirname "$SUP_MANIFEST")" && pwd -P)
PROJECT_ROOT=$(cd "$MDIR/.." && pwd -P)
REPORT="$PROJECT_ROOT/docs/polylane-report.md"
RUN_STATS="$PROJECT_ROOT/docs/polylane/run-stats.json"
HEARTBEAT="$MDIR/supervisor-heartbeat"
RUNNER_LOG="$MDIR/runner.log"
SUP_LOCK="$MDIR/supervisor.lock"
DECIDED=""            # lanes parked on a critical approval (notified once)
SUP_START=$(date +%s)
SUP_CHILD_PID=""

sup_log() { printf '[supervisor %s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

supervisor_stop() {
  local sig="$1" code="$2"
  trap - INT TERM
  sup_log "received $sig — stopping the active runner and exiting"
  if [ -n "$SUP_CHILD_PID" ] && kill -0 "$SUP_CHILD_PID" 2>/dev/null; then
    case "$sig" in
      INT)  kill -INT "$SUP_CHILD_PID" 2>/dev/null || true ;;
      TERM) kill -TERM "$SUP_CHILD_PID" 2>/dev/null || true ;;
    esac
    wait "$SUP_CHILD_PID" 2>/dev/null || true
  fi
  exit "$code"
}

record_supervisor_restart() {
  [ -x "$SCRIPT_DIR/polylane-run-stats.sh" ] || return 0
  "$SCRIPT_DIR/polylane-run-stats.sh" supervisor-restart --file "$RUN_STATS"
}

supervisor_disk_free_gb() {
  if [ -n "${POLYLANE_DISK_PROBE:-}" ] && [ -x "$POLYLANE_DISK_PROBE" ]; then
    "$POLYLANE_DISK_PROBE" "$PROJECT_ROOT" 2>/dev/null | sed -n '1p'
  else
    df -Pk "$PROJECT_ROOT" 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}'
  fi
}

supervisor_disk_ready() {
  local floor="${POLYLANE_MIN_DISK_GB:-2}" free
  free=$(supervisor_disk_free_gb)
  [ -n "$free" ] || return 0
  [ "$free" -ge "$floor" ] 2>/dev/null
}

# report_fresh : 0 iff the run report exists and was written AFTER we started —
# a stale report from a previous cycle must not read as "this run finished"
# (a stale report file fooled finish-detection in a real run).
report_fresh() {
  [ -f "$REPORT" ] || return 1
  local mt; mt=$(stat -c %Y "$REPORT" 2>/dev/null || stat -f %m "$REPORT" 2>/dev/null || echo 0)
  [ "$mt" -ge "$SUP_START" ] || return 1
  grep -qF -- "**Run:** $RUN_ID" "$REPORT"
}

report_outcome() {
  [ -f "$REPORT" ] || { echo "UNKNOWN"; return; }
  sed -n 's/.*\*\*Outcome:\*\*[[:space:]]*\([^[:space:]·]*\).*/\1/p' "$REPORT" | head -1
}

# pane_for_wt WT : print the nonce-bound pane index for WT, else fail.
pane_for_wt() {
  polylane_tmux_find_pane "$TMUX_SESSION" "$RUN_ID" "$1"
}

# drain_approvals : the runner-independent approval relay. For every unfinished
# lane pane sitting on a permission menu: safe -> approve; critical -> park+notify.
drain_approvals() {
  local name wt idx txt
  while IFS='|' read -r name wt; do
    [ -n "$name" ] || continue
    lane_done "$wt" "$name" && continue
    idx=$(pane_for_wt "$wt") || continue
    pane_awaiting_approval "$idx" || continue
    txt=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p -S -20 2>/dev/null || true)
    if approval_is_critical "$txt"; then
      case " $DECIDED " in *" $name "*) continue ;; esac
      DECIDED="$DECIDED $name"
      sup_log "lane '$name' asks a CRITICAL approval — parked for a human decision"
      notify_event approval "lane '$name' asks approval for a critical action — decide in chat"
    else
      if printf '%s' "$txt" | grep -qE '2\.[[:space:]]*Yes'; then
        tmux send-keys -t "$TMUX_SESSION:0.$idx" '2' 2>/dev/null || true
      else
        tmux send-keys -t "$TMUX_SESSION:0.$idx" '1' 2>/dev/null || true
      fi
      sup_log "auto-approved a safe prompt for lane '$name'"
    fi
  done < <(jq -r '(.lanes[] | "\(.name)|\(.worktree)"), (.integrator | "\(.name)|\(.worktree)")' "$SUP_MANIFEST")
}

heartbeat() {
  # Successful runner cleanup intentionally removes .polylane. Do not recreate it
  # or emit a redirection error for a final "finished" heartbeat.
  [ -d "$MDIR" ] || return 0
  printf '%s runner=%s restarts=%s\n' "$(date '+%F %T')" "$1" "$2" > "$HEARTBEAT" 2>/dev/null || true
}

# one watch tick (also the --check-once body): relay + heartbeat.
tick() { drain_approvals; heartbeat "${1:-unknown}" "${2:-0}"; }

tmux_watch_command() { polylane_tmux_watch_command "$TMUX_SESSION"; }

# acquire_lock : only one supervisor may own a manifest. Atomic mkdir works on
# macOS/bash 3.2 and prevents two restart loops from launching competing runners.
# A lock whose recorded PID no longer exists is reclaimed.
acquire_lock() {
  local owner=""
  if mkdir "$SUP_LOCK" 2>/dev/null; then
    printf '%s\n' "$$" > "$SUP_LOCK/pid"
    return 0
  fi
  [ -f "$SUP_LOCK/pid" ] && IFS= read -r owner < "$SUP_LOCK/pid" || true
  if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
    sup_log "another supervisor already owns this run (pid=$owner) — refusing duplicate launch"
    return 1
  fi
  rm -rf "$SUP_LOCK"
  mkdir "$SUP_LOCK" 2>/dev/null || {
    sup_log "could not acquire supervisor lock: $SUP_LOCK"
    return 1
  }
  printf '%s\n' "$$" > "$SUP_LOCK/pid"
}

release_lock() {
  local owner=""
  [ -f "$SUP_LOCK/pid" ] && IFS= read -r owner < "$SUP_LOCK/pid" || true
  [ "$owner" = "$$" ] && rm -rf "$SUP_LOCK"
  return 0
}

# --- main ----------------------------------------------------------------------
supervisor_main() {
  local restarts=0 rc pid args_line outcome last_err
  acquire_lock || return 1
  trap release_lock EXIT
  trap 'supervisor_stop INT 130' INT
  trap 'supervisor_stop TERM 143' TERM
  # default --yes: the supervisor IS the unattended path; keep user args too.
  case " $* " in *" --yes "*) args_line="$*" ;; *) args_line="--yes${*:+ $*}" ;; esac

  while :; do
    while ! supervisor_disk_ready; do
      sup_log "disk headroom low — waiting before launch (floor=${POLYLANE_MIN_DISK_GB:-2}GB); restart budget unchanged"
      heartbeat disk-wait "$restarts"
      sleep "${POLYLANE_SUP_DISK_BACKOFF:-30}"
    done
    if [ "$restarts" -gt 0 ]; then
      record_supervisor_restart || sup_log "could not record supervisor restart telemetry"
    fi
    sup_log "launching runner (attempt $((restarts + 1))/$((SUP_MAX_RESTARTS + 1))): polylane-run.sh $SUP_MANIFEST $args_line"
    sup_log "watch active tmux: $(tmux_watch_command)"
    # shellcheck disable=SC2086  # args_line is intentionally word-split
    POLYLANE_SESSION="$TMUX_SESSION" "$SCRIPT_DIR/polylane-run.sh" "$SUP_MANIFEST" $args_line >> "$RUNNER_LOG" 2>&1 &
    pid=$!
    SUP_CHILD_PID="$pid"

    while kill -0 "$pid" 2>/dev/null; do
      tick alive "$restarts"
      sleep "$SUP_INTERVAL"
    done
    # a crashed child returns nonzero from `wait` — must NOT kill the supervisor
    rc=0; wait "$pid" 2>/dev/null || rc=$?
    SUP_CHILD_PID=""

    if report_fresh; then
      outcome=$(report_outcome)
      case "$outcome" in
        HALTED|UNKNOWN|"")
          if [ -s "$MDIR/needs-user" ]; then
            sup_log "$outcome outcome exhausted autonomous no-progress replans — user input is required; not relaunching identical work"
            heartbeat needs-user "$restarts"
            return 1
          fi
          restarts=$((restarts + 1))
          if [ "$restarts" -gt "$SUP_MAX_RESTARTS" ]; then
            sup_log "runner wrote a $outcome report and the restart cap ($SUP_MAX_RESTARTS) is exhausted — halting"
            heartbeat halted "$restarts"
            return 1
          fi
          sup_log "$outcome outcome is recoverable — reviving with --resume (${restarts}/${SUP_MAX_RESTARTS})"
          case " $args_line " in *" --resume "*) : ;; *) args_line="$args_line --resume" ;; esac
          SUP_START=$(date +%s)
          continue
          ;;
        GO|EXTERNAL-EVIDENCE-OPEN)
          sup_log "runner finished legitimately (outcome=$outcome, rc=$rc) — cycle complete"
          heartbeat finished "$restarts"
          return 0
          ;;
        NO-GO)
          sup_log "runner finished legitimately (outcome=NO-GO, rc=$rc) — runner-level repair exhausted"
          heartbeat finished "$restarts"
          return "$rc"
          ;;
      esac
    fi

    # rc=2 is the runner's usage/manifest/contract/preflight class. The same
    # immutable manifest cannot heal by relaunching, and no work has begun, so
    # preserve the first diagnostic instead of burning the restart budget on
    # identical failures (and emitting repeated failure notifications).
    if [ "$rc" = 2 ]; then
      sup_log "runner stopped on deterministic preflight/configuration failure (rc=2) — not relaunching identical work"
      heartbeat halted "$restarts"
      return 2
    fi

    restarts=$((restarts + 1))
    # A bare rc is undiagnosable from outside (a die() preflight loop burned the
    # whole cap opaquely on 2026-08-18); always surface the runner's dying words.
    last_err=$(tail -n 5 "$RUNNER_LOG" 2>/dev/null | grep -E 'polylane-run:|error|fatal|FAIL' | tail -n 1 || true)
    [ -n "$last_err" ] || last_err=$(tail -n 1 "$RUNNER_LOG" 2>/dev/null || true)
    if [ "$restarts" -gt "$SUP_MAX_RESTARTS" ]; then
      sup_log "runner died without a report and the restart cap ($SUP_MAX_RESTARTS) is exhausted — halting. last error: ${last_err:-<empty runner.log>}"
      notify_event halt "supervisor: runner crashed ${restarts}x without finishing — halted, worktrees intact. last error: ${last_err:-<empty runner.log>}"
      heartbeat halted "$restarts"
      return 1
    fi
    if [ "$rc" = 75 ]; then
      sup_log "runner lost its owned tmux session (recoverable rc=75) — resuming without duplicate panes (${restarts}/${SUP_MAX_RESTARTS})"
    else
      sup_log "runner DIED without a report (rc=$rc) — last error: ${last_err:-<empty runner.log>} — reviving with --resume (${restarts}/${SUP_MAX_RESTARTS})"
    fi
    notify_event stall "supervisor revived the runner (crash ${restarts}/${SUP_MAX_RESTARTS})"
    case " $args_line " in *" --resume "*) : ;; *) args_line="$args_line --resume" ;; esac
  done
}

if [ "${1:-}" = "--check-once" ] || [ "${SUP_CHECK_ONCE:-0}" = "1" ]; then
  tick check-once 0
  exit 0
fi

# Only run when executed directly (tests source the functions above).
if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  supervisor_main "$@"
fi
