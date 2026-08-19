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
#
# Typed sections and mandatory locked bytes (defect
# c42b-unsafe-whole-document-prompt-dedupe). The v3 schemas define neither
# term, so both are defined narrowly here and nowhere else:
#
#   TYPED SECTION — a fenced region of a compiled prompt. The fences are the
#   `=== NAME ===` / `=== END NAME ===` pairs the frozen templates emit, plus
#   the three inline quoted-data pairs BRIEF-BEGIN/BRIEF-END,
#   TASK-ORACLE-BEGIN/TASK-ORACLE-END and REF-PACKET-BEGIN/REF-PACKET-END.
#
#   MANDATORY LOCKED BYTES — every byte, fences included, of the typed
#   sections whose digest this compiler freezes into receipt.json: the quoted
#   brief (brief.sha256), the quoted task oracle (oracle_sha256), the quoted
#   reference packet (current.ref_packet_sha256), the pinned baseline material
#   (baseline.material_sha256) and the design lock (current.design_lock_sha256).
#
# Deduplication therefore runs per typed section and never inside a locked
# one, so no section can delete another section's line and no frozen digest
# can be invalidated by the optimization pass.
set -euo pipefail

BASELINE_REV=0b802ad13ada13a0dc7cc702a526ed17d3348851
BASELINE_LINES="336,337" # the pre-visual one-shot design-lock doctrine, exact
BASELINE_MATERIAL_SHA256=2393058a7c0c6d92975c0f1f4ccfc97c6c7f89dc5d0914680fd4e1423cb5d142
PROMPT_BYTE_BUDGET=16000
RETENTION_DIR=artifacts
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

# locked_fence LINE : "open" or "close" for a locked typed-section fence, else
# nothing. See the header for what counts as locked.
locked_fence() {
  case "$1" in
    'BRIEF-BEGIN '*|'TASK-ORACLE-BEGIN '*|'REF-PACKET-BEGIN '*|\
    '=== BASELINE MATERIAL ==='|'=== DESIGN LOCK ===') printf 'open\n' ;;
    'BRIEF-END'|'TASK-ORACLE-END'|'REF-PACKET-END'|\
    '=== END BASELINE MATERIAL ==='|'=== END DESIGN LOCK ===') printf 'close\n' ;;
  esac
}

# locked_bytes PROMPT : every mandatory locked byte, fences included, in file
# order. rc 1 on an unbalanced fence so a truncated prompt can never compare
# equal by accident.
locked_bytes() {
  local prompt="$1" raw locked=0 kind
  while IFS= read -r raw || [ -n "$raw" ]; do
    kind=$(locked_fence "$raw")
    if [ "$locked" = 1 ]; then
      printf '%s\n' "$raw"
      [ "$kind" = close ] && locked=0
      continue
    fi
    [ "$kind" = open ] || continue
    printf '%s\n' "$raw"
    locked=1
  done < "$prompt"
  [ "$locked" = 0 ]
}

# dedupe_typed PROMPT : the optimization pass. Lines are trimmed, blank runs
# collapsed, and a repeat dropped only when its earlier twin sits in the same
# typed section — the seen set resets at every fence. Locked typed sections are
# copied byte-for-byte and contribute nothing to any seen set, so mandatory
# locked bytes cannot be trimmed, deduplicated, or suppressed by prose
# elsewhere in the document.
dedupe_typed() {
  local prompt="$1" raw line seen="" previous="" locked=0 kind
  while IFS= read -r raw || [ -n "$raw" ]; do
    kind=$(locked_fence "$raw")
    if [ "$locked" = 1 ]; then
      printf '%s\n' "$raw"
      previous="$raw"
      [ "$kind" = close ] && { locked=0; seen=""; }
      continue
    fi
    if [ "$kind" = open ]; then
      printf '%s\n' "$raw"
      previous="$raw"; locked=1; seen=""
      continue
    fi
    line=$(trim_line "$raw")
    case "$line" in '=== '*) seen="" ;; esac
    if [ -z "$line" ]; then
      [ -z "$previous" ] || printf '\n'
      previous=""
      continue
    fi
    case "|$seen|" in
      *"|$line|"*) continue ;;
      *) seen="$seen|$line" ;;
    esac
    printf '%s\n' "$line"
    previous="$line"
  done < "$prompt"
  [ "$locked" = 0 ]
}

# retain OUT SRC : place SRC in OUT's content-addressed store and echo its
# sha256. The digest is the name, so an existing address already holds exactly
# these bytes; stored files are made read-only. Nothing is overwritten and
# nothing is removed — that is what keeps the promoted chain immutable.
retain() {
  local out="$1" src="$2" sha dest
  sha=$(sha256_file "$src") || return 2
  dest="$out/$RETENTION_DIR/$sha"
  if [ ! -f "$dest" ]; then
    cp "$src" "$dest.tmp.$$" || return 2
    chmod 444 "$dest.tmp.$$" || return 2
    mv "$dest.tmp.$$" "$dest" || return 2
  fi
  printf '%s\n' "$sha"
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

# optimize PROMPT WORKDIR NAME : write the delivered bytes with typed-section
# deduplication (never whole-document), then prove three things — the delivered
# prompt still passes promptopt, no locked scalar changed (compare must WIN),
# and every mandatory locked byte survived byte-for-byte.
# Echoes "<raw_metrics>|<optimized_metrics>".
optimize() {
  local prompt="$1" work="$2" name="$3" opt raw_metrics opt_metrics raw_locked opt_locked
  opt="$work/$name.optimized.md"
  dedupe_typed "$prompt" > "$opt" || { die "unbalanced typed-section fence in $name"; return 2; }
  bash "$PROMPTOPT" check "$opt" "$PROMPT_BYTE_BUDGET" >/dev/null || { die "delivered $name fails promptopt check"; return 2; }
  bash "$PROMPTOPT" compare "$prompt" "$opt" >/dev/null || { die "optimization changed a locked scalar in $name"; return 2; }
  raw_locked=$(locked_bytes "$prompt") || { die "unbalanced typed-section fence in compiled $name"; return 2; }
  opt_locked=$(locked_bytes "$opt") || { die "unbalanced typed-section fence in delivered $name"; return 2; }
  [ -n "$raw_locked" ] || { die "compiled $name carries no mandatory locked bytes"; return 2; }
  [ "$(sha256_text "$raw_locked")" = "$(sha256_text "$opt_locked")" ] ||
    { die "optimization altered mandatory locked bytes in $name"; return 2; }
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

  # The delivered bytes were consumed right here: the optimization pass read
  # them to prove no locked scalar and no mandatory locked byte moved. Receipt
  # that consumption so the chain closes on an artifact instead of on a
  # deleted file.
  jq -nS --arg run_id "$R_RUN_ID" \
    --arg b_sha "$(sha256_file "$out/baseline.optimized.md")" \
    --argjson b_bytes "$(wc -c < "$out/baseline.optimized.md" | tr -d '[:space:]')" \
    --arg c_sha "$(sha256_file "$out/current.optimized.md")" \
    --argjson c_bytes "$(wc -c < "$out/current.optimized.md" | tr -d '[:space:]')" '
    {schema_version: "taste-prompt-consumed/v1", run_id: $run_id,
     dedupe_scope: "typed-section", locked_bytes: "unaltered",
     consumed: [
       {arm: "baseline", delivered: "baseline.optimized.md",
        delivered_sha256: $b_sha, delivered_bytes: $b_bytes, locked_scalars: "unchanged"},
       {arm: "current", delivered: "current.optimized.md",
        delivered_sha256: $c_sha, delivered_bytes: $c_bytes, locked_scalars: "unchanged"}]}
  ' > "$out/consumed-receipt.json"

  # Immutable, addressable retention of the whole promoted chain.
  mkdir -p "$out/$RETENTION_DIR"
  [ -d "$out/$RETENTION_DIR" ] && [ ! -L "$out/$RETENTION_DIR" ] ||
    { die "retention store unavailable: $out/$RETENTION_DIR"; return 2; }
  local chain sha
  chain=$(
    printf '%s\t%s\t%s\n' source spec.json "$(retain "$out" "$spec")"
    printf '%s\t%s\t%s\n' source brief "$(retain "$out" "$R_BRIEF_PATH")"
    printf '%s\t%s\t%s\n' source task-oracle "$(retain "$out" "$R_ORACLE_PATH")"
    printf '%s\t%s\t%s\n' source reference-packet "$(retain "$out" "$packet_path")"
    printf '%s\t%s\t%s\n' source baseline-builder.md "$(retain "$out" "$TEMPLATE_DIR/baseline-builder.md")"
    printf '%s\t%s\t%s\n' source current-builder.md "$(retain "$out" "$TEMPLATE_DIR/current-builder.md")"
    printf '%s\t%s\t%s\n' compiled baseline.md "$(retain "$out" "$out/baseline.md")"
    printf '%s\t%s\t%s\n' compiled current.md "$(retain "$out" "$out/current.md")"
    printf '%s\t%s\t%s\n' delivered baseline.optimized.md "$(retain "$out" "$out/baseline.optimized.md")"
    printf '%s\t%s\t%s\n' delivered current.optimized.md "$(retain "$out" "$out/current.optimized.md")"
    printf '%s\t%s\t%s\n' consumed consumed-receipt.json "$(retain "$out" "$out/consumed-receipt.json")"
  )
  chain=$(printf '%s\n' "$chain" |
    jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {stage: .[0], name: .[1], sha256: .[2]})')
  jq -e 'length == 11 and all(.[]; .sha256 | type == "string" and test("^[0-9a-f]{64}$"))' <<<"$chain" >/dev/null 2>&1 ||
    { die "retention chain incomplete"; return 2; }
  for sha in $(jq -r '.[].sha256' <<<"$chain"); do
    [ -f "$out/$RETENTION_DIR/$sha" ] || { die "retained artifact not addressable: $sha"; return 2; }
  done

  jq -nS \
    --argjson retention_chain "$chain" \
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
       identity_policy: "identity lines differ only in arm token and OWN/VERIFY/STATUS paths"},
     retention: {store: "artifacts", addressing: "sha256", immutable: true,
       chain: $retention_chain}}
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

  # Retention: the promoted chain stays complete, immutable, and addressable.
  jq -e '
    .retention.store == "artifacts" and .retention.addressing == "sha256"
    and .retention.immutable == true
    and (.retention.chain | type == "array" and length >= 11)
    and ([.retention.chain[].stage] | unique) == ["compiled","consumed","delivered","source"]
    and all(.retention.chain[]; (.name | type == "string" and length > 0)
      and (.sha256 | type == "string" and test("^[0-9a-f]{64}$")))
  ' "$receipt" >/dev/null 2>&1 || { die "receipt does not address a four-stage retention chain"; return 2; }
  for f in baseline.optimized.md current.optimized.md consumed-receipt.json; do
    [ -f "$out/$f" ] && [ ! -L "$out/$f" ] || { die "promotion artifact deleted: $f"; return 2; }
  done
  local sha addr
  for sha in $(jq -r '.retention.chain[].sha256' "$receipt"); do
    addr="$out/$RETENTION_DIR/$sha"
    [ -f "$addr" ] && [ ! -L "$addr" ] || { die "retained artifact deleted after promotion: $sha"; return 2; }
    [ "$(sha256_file "$addr")" = "$sha" ] || { die "retained artifact mutated after promotion: $sha"; return 2; }
  done
  for f in baseline.md current.md baseline.optimized.md current.optimized.md consumed-receipt.json; do
    [ "$(jq -r --arg n "$f" '.retention.chain[] | select(.name == $n) | .sha256' "$receipt")" = "$(sha256_file "$out/$f")" ] ||
      { die "promoted $f no longer matches its retained address"; return 2; }
  done
  jq -e '.schema_version == "taste-prompt-consumed/v1" and (.consumed | length == 2)' \
    "$out/consumed-receipt.json" >/dev/null 2>&1 || { die "invalid consumed receipt"; return 2; }
  for f in baseline current; do
    [ "$(jq -r --arg a "$f" '.consumed[] | select(.arm == $a) | .delivered_sha256' "$out/consumed-receipt.json")" = \
      "$(sha256_file "$out/$f.optimized.md")" ] ||
      { die "consumed receipt does not bind the delivered $f bytes"; return 2; }
  done

  # The delivered bytes must still be exactly what typed-section optimization
  # produces from the compiled prompt.
  local scratch drift=""
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/taste-prompts-verify.XXXXXX") || { die "scratch directory unavailable"; return 2; }
  optimize "$out/baseline.md" "$scratch" baseline >/dev/null || { rm -rf "$scratch"; return 2; }
  optimize "$out/current.md" "$scratch" current >/dev/null || { rm -rf "$scratch"; return 2; }
  for f in baseline current; do
    [ "$(sha256_file "$scratch/$f.optimized.md")" = "$(sha256_file "$out/$f.optimized.md")" ] || drift="$f"
  done
  rm -rf "$scratch"
  [ -z "$drift" ] || { die "delivered $drift bytes drifted from the compiled prompt"; return 2; }
}

main() {
  case "${1:-}" in
    compile) [ "$#" -eq 3 ] || { usage; return 2; }; compile "$2" "$3" ;;
    verify) [ "$#" -eq 2 ] || { usage; return 2; }; verify "$2" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
