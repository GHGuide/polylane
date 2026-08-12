#!/usr/bin/env bash
# polylane-taste-prompts.sh — immutable baseline/current study prompt compiler.
#
# One spec compiles both study arms from the frozen templates in
# benchmarks/taste-live/prompts/: a byte-identical shared contract (literal
# brief, ultimate goal, task/state oracle, offline output, accessibility,
# fixed model/config), a baseline method bound byte-exactly to the pre-visual
# skill revision, and a current method carrying the visual-intelligence
# treatment (provenance-bound reference packet, three structural directions
# with one memory-blind, design lock, bounded repair, coordinator-owned
# review). Neither arm may self-judge. Missing or weak reference provenance
# blocks the current arm (rc 6, EXTERNAL-EVIDENCE-OPEN) — it never weakens
# it. Deterministic: same inputs, same bytes, same hashes.
# Bash 3.2 + jq + read-only `git show`.
set -euo pipefail

BASELINE_REV=0b802ad13ada13a0dc7cc702a526ed17d3348851
BASELINE_LINES="336,337" # the pre-visual one-shot design-lock doctrine, exact
BASELINE_MATERIAL_SHA256=2393058a7c0c6d92975c0f1f4ccfc97c6c7f89dc5d0914680fd4e1423cb5d142
PROMPT_BYTE_BUDGET=16000
INJECTION_RE='(ignore[[:space:]]+(all[[:space:]]+)?(previous|prior)[[:space:]]+instructions|system[[:space:]]+prompt|reveal[[:space:]]+(the[[:space:]]+)?(prompt|instructions)|assistant[[:space:]]+instructions)'
LEAKAGE_RE='winner|certif|champion|trophy'

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$BIN_DIR/.." && pwd)"
TEMPLATE_DIR="$ROOT/benchmarks/taste-live/prompts"
PROMPTOPT="$BIN_DIR/polylane-promptopt.sh"

usage() { echo "usage: polylane-taste-prompts.sh compile SPEC OUT_DIR | verify OUT_DIR" >&2; }
die() { echo "TASTE-PROMPTS: $*" >&2; return 2; }

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
sha256_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }
trim_line() { printf '%s\n' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g'; }
quote_file() { sed 's/^/| /; s/^| $/|/' "$1"; }

regular_json_without_duplicate_keys() {
  local file="$1" duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

safe_relpath() {
  local path="$1" part old_ifs
  case "$path" in ""|/*|*'//'*) return 1 ;; esac
  old_ifs=$IFS; IFS='/'
  for part in $path; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
}

shared_section() { sed -n '/^=== SHARED CONTRACT ===$/,/^=== END SHARED CONTRACT ===$/p' "$1"; }
material_section() {
  sed -n '/^=== BASELINE MATERIAL ===$/,/^=== END BASELINE MATERIAL ===$/p' "$1" | sed '1d;$d' | sed 's/^| //; s/^|$//'
}
design_lock_section() { sed -n '/^=== DESIGN LOCK ===$/,/^=== END DESIGN LOCK ===$/p' "$1"; }

# The pre-visual skill material, byte-verified against the pinned revision.
# Fail-closed: an absent object or a digest mismatch is UNKNOWN, never a
# fixture fallback.
baseline_material() {
  local material
  material=$(git -C "$ROOT" show "$BASELINE_REV:SKILL.md" 2>/dev/null | sed -n "${BASELINE_LINES}p") || true
  [ -n "$material" ] || { die "baseline revision $BASELINE_REV unavailable — UNKNOWN, no fixture fallback"; return 2; }
  [ "$(printf '%s\n' "$material" | shasum -a 256 | awk '{print $1}')" = "$BASELINE_MATERIAL_SHA256" ] ||
    { die "baseline material digest mismatch for $BASELINE_REV:SKILL.md lines $BASELINE_LINES"; return 2; }
  printf '%s\n' "$material"
}

# validate_packet SPEC_CATEGORY BRIEF_ID PACKET : rc 6 + EXTERNAL-EVIDENCE-OPEN
# on any missing or weak provenance. Blocks the current arm, never weakens it.
validate_packet() {
  local category="$1" brief_id="$2" packet="$3" canonical
  if ! regular_json_without_duplicate_keys "$packet"; then
    echo "TASTE-PROMPTS: EXTERNAL-EVIDENCE-OPEN — reference packet missing or malformed ($packet); the current arm is blocked, not weakened" >&2
    return 6
  fi
  jq -e --arg bid "$brief_id" --arg cat "$category" '
    .schema_version == "taste-reference-packet/v1"
    and .brief_id == $bid and .category == $cat
    and (.references | type == "array" and length >= 4 and length <= 6)
    and ([.references[] | select(.role == "category")] | length >= 3 and length <= 5)
    and ([.references[] | select(.role == "wildcard")] | length == 1)
    and all(.references[]; (.role | IN("category","wildcard"))
      and (.url | type == "string" and test("^https?://"))
      and (.licence | type == "string" and length > 0)
      and (.observed | type == "string" and length > 0)
      and (.accessed | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))
      and (.screenshot_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
      and (.provenance | type == "string" and length > 0)
      and (.borrow | type == "string" and length > 0)
      and (.transform | type == "string" and length > 0)
      and (.avoid | type == "string" and length > 0))
    and all(.references[] | select(.role == "category"); .category == $cat)
    and all(.references[] | select(.role == "wildcard");
      (.category | type == "string" and length > 0) and .category != $cat)
  ' "$packet" >/dev/null 2>&1 || {
    echo "TASTE-PROMPTS: EXTERNAL-EVIDENCE-OPEN — reference provenance incomplete (need 3-5 same-category refs + 1 adjacent wildcard, each with url/licence/observed/accessed/screenshot_sha256/provenance/borrow/transform/avoid); the current arm is blocked, not weakened" >&2
    return 6
  }
  canonical=$(jq -cS . "$packet")
  if printf '%s' "$canonical" | LC_ALL=C tr 'A-Z' 'a-z' | grep -qE "$INJECTION_RE"; then
    echo "TASTE-PROMPTS: EXTERNAL-EVIDENCE-OPEN — reference packet carries prompt-injection content; the current arm is blocked, not weakened" >&2
    return 6
  fi
}

# render TEMPLATE DEST : block tokens on their own line, inline tokens
# everywhere else. Late hash tokens (GOAL/SUBGOAL/DESIGN_LOCK sha) survive
# pass 1 untouched and are filled by finalize_current.
render() {
  local tpl="$1" dest="$2" line
  : > "$dest"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '{{BRIEF_BLOCK}}') quote_file "$R_BRIEF_PATH" >> "$dest"; continue ;;
      '{{ORACLE_BLOCK}}') quote_file "$R_ORACLE_PATH" >> "$dest"; continue ;;
      '{{MATERIAL_BLOCK}}') printf '%s\n' "$R_MATERIAL_QUOTED" >> "$dest"; continue ;;
      '{{REF_PACKET_BLOCK}}') printf '%s\n' "$R_PACKET_QUOTED" >> "$dest"; continue ;;
    esac
    line=${line//"{{RUN_ID}}"/$R_RUN_ID}
    line=${line//"{{BRIEF_ID}}"/$R_BRIEF_ID}
    line=${line//"{{CATEGORY}}"/$R_CATEGORY}
    line=${line//"{{BRIEF_SHA256}}"/$R_BRIEF_SHA}
    line=${line//"{{ORACLE_SHA256}}"/$R_ORACLE_SHA}
    line=${line//"{{ULTIMATE_GOAL}}"/$R_ULTIMATE_GOAL}
    line=${line//"{{SUBGOAL}}"/$R_SUBGOAL}
    line=${line//"{{MODEL}}"/$R_MODEL}
    line=${line//"{{EFFORT}}"/$R_EFFORT}
    line=${line//"{{OUT_ROOT}}"/$R_OUT_ROOT}
    line=${line//"{{INCUMBENT}}"/$R_INCUMBENT}
    line=${line//"{{BASELINE_REV}}"/$BASELINE_REV}
    line=${line//"{{MATERIAL_SHA256}}"/$BASELINE_MATERIAL_SHA256}
    line=${line//"{{REF_PACKET_SHA256}}"/$R_PACKET_SHA}
    printf '%s\n' "$line" >> "$dest"
  done < "$tpl"
}

finalize_current() { # pass1 dest goal_sha subgoal_sha lock_sha
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line//"{{GOAL_SHA256}}"/$3}
    line=${line//"{{SUBGOAL_SHA256}}"/$4}
    line=${line//"{{DESIGN_LOCK_SHA256}}"/$5}
    printf '%s\n' "$line"
  done < "$1" > "$2"
}

# Self-checks shared by compile and verify. Fail-closed.
check_prompt_pair() {
  local baseline="$1" current="$2"
  [ "$(shared_section "$baseline" | shasum -a 256)" = "$(shared_section "$current" | shasum -a 256)" ] &&
    [ -n "$(shared_section "$baseline")" ] || { die "shared contract differs across arms"; return 2; }
  ! grep -q '{{' "$baseline" && ! grep -q '{{' "$current" || { die "unfilled template token"; return 2; }
  local token
  for token in 'UI-CONTRACT:' 'UI-IMPLEMENT:' 'UI-CONTENT:' 'UI-EVIDENCE:' 'UI-REVIEW-BOUNDARY:' \
    'REFERENCE PACKET' 'DIRECTION-A' 'DESIGN LOCK' 'memory-blind' 'BOUNDED-REPAIR:'; do
    ! grep -qF -- "$token" "$baseline" || { die "baseline received current visual treatment: $token"; return 2; }
    grep -qF -- "$token" "$current" || { die "current arm lost its treatment: $token"; return 2; }
  done
  ! LC_ALL=C grep -qiE "$LEAKAGE_RE" "$baseline" && ! LC_ALL=C grep -qiE "$LEAKAGE_RE" "$current" ||
    { die "verdict/certificate vocabulary leaked into a builder prompt"; return 2; }
  ! grep -qE 'https?://' "$baseline" || { die "remote URL in baseline arm"; return 2; }
  [ "$(sed '/^REF-PACKET-BEGIN/,/^REF-PACKET-END/d' "$current" | grep -cE 'https?://' || true)" = 0 ] ||
    { die "remote URL outside the quoted reference packet"; return 2; }
  grep -qF "revision=$BASELINE_REV" "$baseline" || { die "baseline revision binding missing"; return 2; }
  [ "$(material_section "$baseline" | shasum -a 256 | awk '{print $1}')" = "$BASELINE_MATERIAL_SHA256" ] ||
    { die "embedded baseline material does not match the pinned revision digest"; return 2; }
  bash "$PROMPTOPT" check "$baseline" "$PROMPT_BYTE_BUDGET" >/dev/null || { die "baseline fails promptopt check"; return 2; }
  bash "$PROMPTOPT" check "$current" "$PROMPT_BYTE_BUDGET" >/dev/null || { die "current fails promptopt check"; return 2; }
  [ -z "$(bash "$PROMPTOPT" ui-version "$baseline")" ] || { die "baseline carries a UI contract version"; return 2; }
  [ "$(bash "$PROMPTOPT" ui-version "$current")" = v2 ] || { die "current UI contract version is not v2"; return 2; }
}

# optimize PROMPT WORKDIR NAME : run polylane-promptopt compilation as the
# optimization pass and prove no locked scalar changed (compare must WIN).
# Echoes "<raw_metrics>|<optimized_metrics>".
optimize() {
  local prompt="$1" work="$2" name="$3" opt raw_metrics opt_metrics
  opt="$work/$name.optimized.md"
  bash "$PROMPTOPT" compile "$prompt" > "$opt" || { die "promptopt compile failed for $name"; return 2; }
  bash "$PROMPTOPT" compare "$prompt" "$opt" >/dev/null || { die "optimization changed a locked scalar in $name"; return 2; }
  raw_metrics=$(bash "$PROMPTOPT" metrics "$prompt")
  opt_metrics=$(bash "$PROMPTOPT" metrics "$opt")
  printf '%s|%s\n' "$raw_metrics" "$opt_metrics"
}

compile() {
  local spec="$1" out="$2"
  command -v jq >/dev/null 2>&1 || { die "jq is required"; return 2; }
  regular_json_without_duplicate_keys "$spec" || { die "invalid spec JSON: $spec"; return 2; }
  jq -e '
    .schema_version == "taste-prompt-spec/v1"
    and (.run_id | type == "string" and test("^[A-Za-z0-9._-]+$"))
    and (.brief | type == "object")
    and (.brief.id | type == "string" and test("^[A-Za-z0-9._-]+$"))
    and (.brief.category | type == "string" and test("^[a-z][a-z0-9-]*$"))
    and (.brief.path | type == "string" and length > 0)
    and (.goal | type == "string" and length > 0 and (test("[[:cntrl:]]") | not))
    and (.subgoal | type == "string" and length > 0 and (test("[[:cntrl:]]") | not))
    and (.builder.model | type == "string" and test("^[A-Za-z0-9._-]+$"))
    and (.builder.effort | type == "string" and test("^[A-Za-z0-9._-]+$"))
    and (.task_oracle | type == "string" and length > 0)
    and (.output_root | type == "string" and length > 0)
    and (.incumbent | type == "string" and test("^[A-Za-z0-9._-]+$"))
    and (.reference_packet | type == "string" and length > 0)
  ' "$spec" >/dev/null 2>&1 || { die "malformed spec (need taste-prompt-spec/v1 fields)"; return 2; }

  R_RUN_ID=$(jq -r .run_id "$spec")
  R_BRIEF_ID=$(jq -r .brief.id "$spec")
  R_CATEGORY=$(jq -r .brief.category "$spec")
  R_BRIEF_PATH=$(jq -r .brief.path "$spec")
  R_ULTIMATE_GOAL=$(jq -r .goal "$spec")
  R_SUBGOAL=$(jq -r .subgoal "$spec")
  R_MODEL=$(jq -r .builder.model "$spec")
  R_EFFORT=$(jq -r .builder.effort "$spec")
  R_ORACLE_PATH=$(jq -r .task_oracle "$spec")
  R_OUT_ROOT=$(jq -r .output_root "$spec")
  R_INCUMBENT=$(jq -r .incumbent "$spec")
  local packet_path
  packet_path=$(jq -r .reference_packet "$spec")

  safe_relpath "$R_OUT_ROOT" || { die "output_root is not a safe repo-relative path: $R_OUT_ROOT"; return 2; }
  [ -f "$R_BRIEF_PATH" ] && [ ! -L "$R_BRIEF_PATH" ] || { die "brief unavailable: $R_BRIEF_PATH"; return 2; }
  regular_json_without_duplicate_keys "$R_ORACLE_PATH" || { die "task oracle missing or malformed: $R_ORACLE_PATH"; return 2; }
  jq -e '.schema_version | type == "string" and length > 0' "$R_ORACLE_PATH" >/dev/null 2>&1 ||
    { die "task oracle lacks a schema_version"; return 2; }
  [ -f "$TEMPLATE_DIR/baseline-builder.md" ] && [ -f "$TEMPLATE_DIR/current-builder.md" ] ||
    { die "frozen templates missing under $TEMPLATE_DIR"; return 2; }

  # Provenance gate before any output is written: a blocked packet blocks the
  # whole pair so the study never receives a half-compiled comparison.
  validate_packet "$R_CATEGORY" "$R_BRIEF_ID" "$packet_path" || return $?

  local material
  material=$(baseline_material) || return $?
  R_MATERIAL_QUOTED=$(printf '%s\n' "$material" | sed 's/^/| /; s/^| $/|/')
  R_PACKET_SHA=$(jq -cS . "$packet_path" | shasum -a 256 | awk '{print $1}')
  R_PACKET_QUOTED=$(jq -S . "$packet_path" | sed 's/^/| /; s/^| $/|/')
  R_BRIEF_SHA=$(sha256_file "$R_BRIEF_PATH")
  R_ORACLE_SHA=$(sha256_file "$R_ORACLE_PATH")

  mkdir -p "$out"
  [ -d "$out" ] && [ ! -L "$out" ] || { die "output directory unavailable: $out"; return 2; }

  render "$TEMPLATE_DIR/baseline-builder.md" "$out/baseline.md"
  local pass1="$out/.current.pass1.$$"
  render "$TEMPLATE_DIR/current-builder.md" "$pass1"
  local goal_value subgoal_value goal_sha subgoal_sha lock_sha
  goal_value=$(trim_line "$(sed -n 's/^[[:space:]]*GOAL://p' "$pass1" | head -1)")
  subgoal_value=$(trim_line "$(sed -n 's/^[[:space:]]*CURRENT-SUBGOAL://p' "$pass1" | head -1)")
  goal_sha=$(sha256_text "$goal_value")
  subgoal_sha=$(sha256_text "$subgoal_value")
  lock_sha=$(design_lock_section "$pass1" | shasum -a 256 | awk '{print $1}')
  finalize_current "$pass1" "$out/current.md" "$goal_sha" "$subgoal_sha" "$lock_sha"
  rm -f "$pass1"

  check_prompt_pair "$out/baseline.md" "$out/current.md" || return $?

  local baseline_opt current_opt
  baseline_opt=$(optimize "$out/baseline.md" "$out" baseline) || return $?
  current_opt=$(optimize "$out/current.md" "$out" current) || return $?
  rm -f "$out/baseline.optimized.md" "$out/current.optimized.md"

  jq -nS \
    --arg run_id "$R_RUN_ID" --arg brief_id "$R_BRIEF_ID" --arg category "$R_CATEGORY" \
    --arg brief_sha "$R_BRIEF_SHA" --arg oracle_sha "$R_ORACLE_SHA" \
    --arg model "$R_MODEL" --arg effort "$R_EFFORT" --arg out_root "$R_OUT_ROOT" \
    --arg b_sha "$(sha256_file "$out/baseline.md")" --arg c_sha "$(sha256_file "$out/current.md")" \
    --arg b_tpl "$(sha256_file "$TEMPLATE_DIR/baseline-builder.md")" \
    --arg c_tpl "$(sha256_file "$TEMPLATE_DIR/current-builder.md")" \
    --arg rev "$BASELINE_REV" --arg lines "$BASELINE_LINES" --arg mat "$BASELINE_MATERIAL_SHA256" \
    --arg packet "$R_PACKET_SHA" --arg lock "$lock_sha" --arg goal "$goal_sha" --arg subgoal "$subgoal_sha" \
    --arg incumbent "$R_INCUMBENT" --arg shared "$(shared_section "$out/baseline.md" | shasum -a 256 | awk '{print $1}')" \
    --argjson budget "$PROMPT_BYTE_BUDGET" \
    --argjson b_raw "${baseline_opt%%|*}" --argjson b_opt "${baseline_opt##*|}" \
    --argjson c_raw "${current_opt%%|*}" --argjson c_opt "${current_opt##*|}" '
    {schema_version: "taste-prompt-receipt/v1", run_id: $run_id,
     brief: {id: $brief_id, category: $category, sha256: $brief_sha},
     oracle_sha256: $oracle_sha,
     builder: {model: $model, effort: $effort},
     output_root: $out_root, budget_bytes: $budget,
     baseline: {template: "baseline-builder.md", template_sha256: $b_tpl,
       prompt_sha256: $b_sha, revision: $rev, material_lines: $lines,
       material_sha256: $mat, metrics: $b_raw, optimized_metrics: $b_opt,
       optimization: "no-scalar-change"},
     current: {template: "current-builder.md", template_sha256: $c_tpl,
       prompt_sha256: $c_sha, ref_packet_sha256: $packet,
       design_lock_sha256: $lock, goal_sha256: $goal, subgoal_sha256: $subgoal,
       incumbent: $incumbent, metrics: $c_raw, optimized_metrics: $c_opt,
       optimization: "no-scalar-change"},
     fairness: {shared_contract_sha256: $shared, shared_contract_equal: true,
       identity_policy: "identity lines differ only in arm token and OWN/VERIFY/STATUS paths"}}
  ' > "$out/receipt.json"
}

verify() {
  local out="$1" receipt f
  receipt="$out/receipt.json"
  command -v jq >/dev/null 2>&1 || { die "jq is required"; return 2; }
  [ -d "$out" ] && [ ! -L "$out" ] || { die "output directory unavailable: $out"; return 2; }
  regular_json_without_duplicate_keys "$receipt" || { die "invalid receipt"; return 2; }
  jq -e '.schema_version == "taste-prompt-receipt/v1"' "$receipt" >/dev/null 2>&1 || { die "unknown receipt schema"; return 2; }
  for f in baseline.md current.md; do
    [ -f "$out/$f" ] && [ ! -L "$out/$f" ] || { die "compiled prompt missing: $f"; return 2; }
  done
  [ "$(sha256_file "$out/baseline.md")" = "$(jq -r .baseline.prompt_sha256 "$receipt")" ] ||
    { die "baseline.md bytes do not match the receipt"; return 2; }
  [ "$(sha256_file "$out/current.md")" = "$(jq -r .current.prompt_sha256 "$receipt")" ] ||
    { die "current.md bytes do not match the receipt"; return 2; }
  [ "$(sha256_file "$TEMPLATE_DIR/baseline-builder.md")" = "$(jq -r .baseline.template_sha256 "$receipt")" ] ||
    { die "baseline template drifted from the frozen digest"; return 2; }
  [ "$(sha256_file "$TEMPLATE_DIR/current-builder.md")" = "$(jq -r .current.template_sha256 "$receipt")" ] ||
    { die "current template drifted from the frozen digest"; return 2; }
  [ "$(jq -r .baseline.revision "$receipt")" = "$BASELINE_REV" ] || { die "receipt pins a different baseline revision"; return 2; }
  [ "$(shared_section "$out/baseline.md" | shasum -a 256 | awk '{print $1}')" = "$(jq -r .fairness.shared_contract_sha256 "$receipt")" ] ||
    { die "shared contract does not match the receipt"; return 2; }
  local ui_line
  ui_line=$(grep '^UI-CONTRACT:' "$out/current.md" | head -1)
  case "$ui_line" in
    *"ref_packet_sha256=$(jq -r .current.ref_packet_sha256 "$receipt")"*) : ;;
    *) die "UI-CONTRACT packet digest does not match the receipt"; return 2 ;;
  esac
  grep -qF "REF-PACKET-BEGIN sha256=$(jq -r .current.ref_packet_sha256 "$receipt")" "$out/current.md" ||
    { die "reference packet block digest does not match the receipt"; return 2; }
  [ "$(design_lock_section "$out/current.md" | shasum -a 256 | awk '{print $1}')" = "$(jq -r .current.design_lock_sha256 "$receipt")" ] ||
    { die "design lock section does not match the receipt"; return 2; }
  check_prompt_pair "$out/baseline.md" "$out/current.md" || return $?
  optimize "$out/baseline.md" "${TMPDIR:-/tmp}" ".taste-prompts-verify-baseline.$$" >/dev/null || return $?
  optimize "$out/current.md" "${TMPDIR:-/tmp}" ".taste-prompts-verify-current.$$" >/dev/null || return $?
  rm -f "${TMPDIR:-/tmp}/.taste-prompts-verify-baseline.$$.optimized.md" "${TMPDIR:-/tmp}/.taste-prompts-verify-current.$$.optimized.md"
}

main() {
  case "${1:-}" in
    compile) [ "$#" -eq 3 ] || { usage; return 2; }; compile "$2" "$3" ;;
    verify) [ "$#" -eq 2 ] || { usage; return 2; }; verify "$2" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
