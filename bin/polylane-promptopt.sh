#!/usr/bin/env bash
# polylane-promptopt.sh — compile and compare immutable builder prompts.
# Bash 3.2 only. Read-only commands never change the supplied prompt.
set -euo pipefail

usage() {
  echo "usage: polylane-promptopt.sh metrics <prompt> | check <prompt> [budget] | compile <prompt> | compile-selected <prompt> <kit> <lane> <output> | compare <champion> <challenger> | ui-version <prompt>" >&2
}

require_prompt() {
  [ -f "$1" ] || { echo "polylane-promptopt: prompt not found: $1" >&2; return 2; }
}

# A deliberately conservative deterministic estimate. It is not provider billing.
metrics() {
  local prompt="$1" bytes tokens
  require_prompt "$prompt" || return $?
  bytes=$(wc -c < "$prompt" | tr -d '[:space:]')
  tokens=$(( (bytes + 2) / 3 ))
  printf '{"bytes":%s,"tokens":%s,"estimated_tokens":%s,"token_estimate_method":"ceil(bytes/3)","conservative_token_estimate":%s,"conservative_token_estimate_method":"bytes"}\n' "$bytes" "$tokens" "$tokens" "$bytes"
}

scalar_label() {
  case "$1" in
    ULTIMATE-GOAL:*) echo ULTIMATE-GOAL ;;
    CURRENT-SUBGOAL:*) echo CURRENT-SUBGOAL ;;
    GOAL:*) echo GOAL ;;
    OWN:*) echo OWN ;;
    FORBIDDEN:*) echo FORBIDDEN ;;
    PREDEFINED-SKILLS:*) echo PREDEFINED-SKILLS ;;
    LANE-SPECIFIC-SKILLS:*) echo LANE-SPECIFIC-SKILLS ;;
    TEST-CADENCE:*) echo TEST-CADENCE ;;
    DELEGATION:*) echo DELEGATION ;;
    CHECK-CACHE:*) echo CHECK-CACHE ;;
    EXTERNAL-EVIDENCE:*) echo EXTERNAL-EVIDENCE ;;
    VERIFY:*) echo VERIFY ;;
    # Manifest-derived UI profile scalars (present only on surface:"ui" lanes).
    # They are exact-once and immutable: dropping, weakening, or duplicating any
    # one must break scalar validation and the frozen-contract comparison.
    UI-CONTRACT:*) echo UI-CONTRACT ;;
    UI-IMPLEMENT:*) echo UI-IMPLEMENT ;;
    UI-CONTENT:*) echo UI-CONTENT ;;
    UI-EVIDENCE:*) echo UI-EVIDENCE ;;
    UI-REVIEW-BOUNDARY:*) echo UI-REVIEW-BOUNDARY ;;
    *) return 1 ;;
  esac
}

sha256_text() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    return 1
  fi
}

# A repo-relative path with no absolute anchor, no `..` climb, and no empty
# segment. Mirrors the capture verifier's safety rule so a UI scalar cannot
# smuggle an escape or symlink-style path into a builder prompt.
ui_safe_relpath() {
  local path="$1" part old_ifs
  case "$path" in ""|/*|*'//'*) return 1 ;; esac
  old_ifs=$IFS; IFS='/'
  for part in $path; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
}

ui_field() {  # ui_field LINE KEY : echo the whitespace-delimited value of KEY=…
  printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p" | head -1
}

# validate_ui_profile PROMPT : if the prompt carries any UI-* scalar it must
# carry all five, with a mode=ui versioned contract, 64-hex reference/design and
# goal/subgoal binding hashes, safe capture/tournament paths, a bounded repair
# attempt, and a coordinator-owned (never builder-self-certified) review verdict.
# Prompts with no UI-* scalar are non-UI and skip this entirely (backward compat).
validate_ui_profile() {
  local prompt="$1" contract implement review label goal subgoal path attempt
  grep -qE '^[[:space:]]*UI-(CONTRACT|IMPLEMENT|CONTENT|EVIDENCE|REVIEW-BOUNDARY):' "$prompt" || return 0
  for label in UI-CONTRACT UI-IMPLEMENT UI-CONTENT UI-EVIDENCE UI-REVIEW-BOUNDARY; do
    grep -qE "^[[:space:]]*$label:" "$prompt" || {
      echo "polylane-promptopt: UI profile present but missing scalar: $label" >&2; return 3
    }
  done
  contract=$(trim_line "$(grep -E '^[[:space:]]*UI-CONTRACT:' "$prompt" | head -1)")
  implement=$(trim_line "$(grep -E '^[[:space:]]*UI-IMPLEMENT:' "$prompt" | head -1)")
  review=$(trim_line "$(grep -E '^[[:space:]]*UI-REVIEW-BOUNDARY:' "$prompt" | head -1)")

  case " $contract " in *' mode=ui '*) : ;; *) echo "polylane-promptopt: UI-CONTRACT mode must be ui" >&2; return 5 ;; esac
  printf '%s\n' "$contract" | grep -qE 'ui_contract=v[0-9]+( |$)' || { echo "polylane-promptopt: UI-CONTRACT needs a versioned ui_contract=v<n>" >&2; return 5; }
  for label in ref_packet_sha256 design_lock_sha256 goal_sha256 subgoal_sha256; do
    printf '%s\n' "$(ui_field "$contract" "$label")" | grep -qE '^[0-9a-f]{64}$' ||
      { echo "polylane-promptopt: UI-CONTRACT $label is not a 64-hex digest (placeholder/stale)" >&2; return 5; }
  done
  goal=$(trim_line "$(sed -n 's/^[[:space:]]*GOAL://p' "$prompt" | head -1)")
  subgoal=$(trim_line "$(sed -n 's/^[[:space:]]*CURRENT-SUBGOAL://p' "$prompt" | head -1)")
  [ "$(ui_field "$contract" goal_sha256)" = "$(sha256_text "$goal")" ] ||
    { echo "polylane-promptopt: UI-CONTRACT goal_sha256 does not bind the GOAL scalar" >&2; return 5; }
  [ "$(ui_field "$contract" subgoal_sha256)" = "$(sha256_text "$subgoal")" ] ||
    { echo "polylane-promptopt: UI-CONTRACT subgoal_sha256 does not bind the CURRENT-SUBGOAL scalar" >&2; return 5; }

  for label in capture_matrix tournament; do
    path=$(ui_field "$implement" "$label")
    [ -n "$path" ] || { echo "polylane-promptopt: UI-IMPLEMENT missing $label" >&2; return 5; }
    ui_safe_relpath "$path" || { echo "polylane-promptopt: UI-IMPLEMENT $label is not a safe repo-relative path: $path" >&2; return 5; }
  done
  attempt=$(ui_field "$implement" repair_attempt)
  case "$attempt" in 0|1|2) : ;; *) echo "polylane-promptopt: UI-IMPLEMENT repair_attempt must be 0, 1, or 2" >&2; return 5 ;; esac
  printf '%s\n' "$(ui_field "$implement" incumbent)" | grep -qE '^[A-Za-z0-9._-]+$' ||
    { echo "polylane-promptopt: UI-IMPLEMENT incumbent must be an opaque id" >&2; return 5; }

  printf '%s\n' "$review" | grep -qi 'coordinator' || { echo "polylane-promptopt: UI-REVIEW-BOUNDARY must name coordinator verdict ownership" >&2; return 5; }
  printf '%s\n' "$review" | grep -qiE 'cannot (self-certify|grade itself)' || { echo "polylane-promptopt: UI-REVIEW-BOUNDARY must forbid builder self-certification" >&2; return 5; }
  printf '%s\n' "$review" | grep -qiE 'builder ((may|can|is allowed to) self-certify|owns the verdict|grades itself)' &&
    { echo "polylane-promptopt: UI-REVIEW-BOUNDARY grants a builder-owned verdict" >&2; return 5; }
  return 0
}

trim_line() {
  printf '%s\n' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g'
}

# Reject repeated scalar labels before de-duplicating ordinary material. That keeps
# exact-once contracts observable instead of silently choosing a winner.
validate_scalars() {
  local prompt="$1" raw line label value prior
  local labels="" values=""
  while IFS= read -r raw || [ -n "$raw" ]; do
    line=$(trim_line "$raw")
    [ -n "$line" ] || continue
    label=$(scalar_label "$line" || true)
    [ -n "$label" ] || continue
    value=${line#*:}
    value=$(trim_line "$value")
    case "|$labels|" in
      *"|$label|"*)
        prior=$(printf '%s\n' "$values" | sed -n "s/^$label|//p" | head -1)
        if [ "$prior" = "$value" ]; then
          echo "polylane-promptopt: duplicated exact-once label: $label value: $value" >&2
        else
          echo "polylane-promptopt: conflicting scalar contract: $label values: $prior | $value" >&2
        fi
        return 5
        ;;
      *) labels="$labels|$label"; values="${values}"$'\n'"$label|$value" ;;
    esac
  done < "$prompt"
}

strict_blocks() {
  local prompt="$1" spec label pattern
  validate_scalars "$prompt" || return $?
  validate_ui_profile "$prompt" || return $?
  # Historical generated prompts may keep the two adjacent ownership
  # boundaries on one line (`OWN: … FORBIDDEN: …`). Promptlint has always
  # accepted that form, so compilation must preserve rather than reject it.
  for spec in \
    'ultimate-goal|^ULTIMATE-GOAL:' \
    'current-subgoal|^CURRENT-SUBGOAL:' \
    'goal|^GOAL:' \
    'ownership|^OWN:' \
    'forbidden-boundary|FORBIDDEN:' \
    'predefined-skills|^PREDEFINED-SKILLS:' \
    'lane-specific-skills|^LANE-SPECIFIC-SKILLS:' \
    'selected-kit|Read only the named kit once' \
    'test-cadence|^TEST-CADENCE:' \
    'delegation|^DELEGATION:' \
    'check-cache|^CHECK-CACHE:' \
    'external-evidence|^EXTERNAL-EVIDENCE:' \
    'verification|^VERIFY:' \
    'nonce-done-marker|STATUS:.*DONE.*run='; do
    label=${spec%%|*}; pattern=${spec#*|}
    grep -qiE "$pattern" "$prompt" || {
      echo "polylane-promptopt: missing strict block: $label" >&2
      return 3
    }
  done
}

compile() {
  local prompt="$1" raw line previous="" seen=""
  require_prompt "$prompt" || return $?
  strict_blocks "$prompt" || return $?
  while IFS= read -r raw || [ -n "$raw" ]; do
    line=$(trim_line "$raw")
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
}

# compile_selected PROMPT KIT LANE OUTPUT: retain the prompt's name-only role
# labels, then append the typed selected records exactly once. It reads JSON
# metadata only; SKILL.md bodies are intentionally never loaded here.
compile_selected() {
  local prompt="$1" kit="$2" lane="$3" output="$4" raw line previous="" seen="" inventory records paths duplicate tmp injected=""
  require_prompt "$prompt" || return $?
  strict_blocks "$prompt" || return $?
  [ -f "$kit" ] && jq -e --arg lane "$lane" '
    .version == 3 and (.lanes[$lane] | type == "object")
    and (((.lanes[$lane].selected.predefined // []) + (.lanes[$lane].selected.specific // [])) | length > 0)
    and all(((.lanes[$lane].selected.predefined // []) + (.lanes[$lane].selected.specific // []))[];
      (.id | type == "string" and length > 0)
      and (.path | type == "string" and startswith("/") and endswith("/SKILL.md"))
      and (.reason | type == "string" and length > 0)
      and (.source | type == "string" and length > 0)
      and (.fingerprint | type == "string" and test("^[0-9]+-[0-9]+$")))
  ' "$kit" >/dev/null 2>&1 || {
    echo "polylane-promptopt: missing or invalid typed selected-skill records for lane '$lane'" >&2; return 5;
  }
  inventory=$(jq -c --arg lane "$lane" '(.lanes[$lane].selected.predefined // []) + (.lanes[$lane].selected.specific // [])' "$kit")
  jq -e '
    group_by([.id, .path])
    | map(select(length > 1)
          | select((map({source, fingerprint, reason}) | unique | length) > 1))
    | length == 0
  ' <<<"$inventory" >/dev/null || {
    echo "polylane-promptopt: conflicting immutable selected-skill record" >&2; return 5;
  }
  records=$(jq -c 'sort_by(.id, .path, .source, .fingerprint, .reason) | unique_by(.id, .path)' <<<"$inventory")
  jq -e 'all(.[]; .id != "graphify" and .id != "graphify-auto")' <<<"$records" >/dev/null || {
    echo "polylane-promptopt: graphify navigation infrastructure is query-only; remove graphify or graphify-auto from selected builder skills and use graphify-out/q.py directly" >&2; return 5;
  }
  [ "$(jq 'length' <<<"$records")" -le 4 ] || { echo "polylane-promptopt: selected skill inventory exceeds four" >&2; return 5; }
  paths=$(jq -r '.[].path' <<<"$records")
  duplicate=$(printf '%s\n' "$paths" | LC_ALL=C sort | uniq -d)
  [ -z "$duplicate" ] || { echo "polylane-promptopt: selected skill path duplicated" >&2; return 5; }
  tmp="$output.tmp.$$"
  : > "$tmp"
  while IFS= read -r raw || [ -n "$raw" ]; do
    line=$(trim_line "$raw")
    case "$line" in SELECTED-SKILL:*|SKILL-DELIVERY:*|SKILL-RECEIPTS:*) continue ;; esac
    if [ -z "$line" ]; then
      [ -z "$previous" ] || printf '\n' >> "$tmp"
      previous=""
      continue
    fi
    case "|$seen|" in *"|$line|"*) continue ;; *) seen="$seen|$line" ;; esac
    printf '%s\n' "$line" >> "$tmp"
    if [ "$injected" = "" ] && printf '%s\n' "$line" | grep -q '^Read only the named kit once'; then
      printf 'SKILL-DELIVERY: exact selected records for lane %s; no discovery or inventory.\n' "$lane" >> "$tmp"
      jq -r '.[] | "SELECTED-SKILL: \(.id) | \(.path) | \(.source) | \(.fingerprint) | \(.reason)"' <<<"$records" >> "$tmp"
      printf 'SKILL-RECEIPTS: For each selected skill, record SKILL-READ: id | path | fingerprint; final verification must include SKILL-EVIDENCE: id — helped|unused|hurt: specific observation.\n' >> "$tmp"
      injected=1
    fi
    previous="$line"
  done < "$prompt"
  [ "$injected" = "1" ] || { rm -f "$tmp"; echo "polylane-promptopt: missing named-kit instruction" >&2; return 3; }
  mv "$tmp" "$output"
}

# ui-version PROMPT : echo the manifest-derived visual-contract version (e.g. v1)
# carried on the UI-CONTRACT scalar, or nothing for a non-UI prompt. Lets the
# runner assert equality with manifest .visual_quality.contract_version without
# re-parsing the whole scalar.
ui_version() {
  local prompt="$1" line
  require_prompt "$prompt" || return $?
  line=$(grep -E '^[[:space:]]*UI-CONTRACT:' "$prompt" | head -1 || true)
  [ -n "$line" ] || return 0
  ui_field "$(trim_line "$line")" ui_contract
}

check() {
  local prompt="$1" budget="${2:-8000}" byte_budget="${POLYLANE_PROMPT_BYTE_BUDGET:-}" result bytes tokens conservative_tokens
  require_prompt "$prompt" || return $?
  case "$budget" in ''|*[!0-9]*) echo "polylane-promptopt: budget must be a positive integer" >&2; return 2 ;; esac
  [ "$budget" -gt 0 ] || { echo "polylane-promptopt: budget must be a positive integer" >&2; return 2; }
  if [ -n "$byte_budget" ]; then
    case "$byte_budget" in ''|*[!0-9]*) echo "polylane-promptopt: byte budget must be a positive integer" >&2; return 2 ;; esac
    [ "$byte_budget" -gt 0 ] || { echo "polylane-promptopt: byte budget must be a positive integer" >&2; return 2; }
  fi
  strict_blocks "$prompt" || return $?
  result=$(metrics "$prompt")
  bytes=$(printf '%s' "$result" | sed -n 's/.*"bytes":\([0-9][0-9]*\).*/\1/p')
  tokens=$(printf '%s' "$result" | sed -n 's/.*"tokens":\([0-9][0-9]*\).*/\1/p')
  conservative_tokens=$(printf '%s' "$result" | sed -n 's/.*"conservative_token_estimate":\([0-9][0-9]*\).*/\1/p')
  if [ "$conservative_tokens" -gt "$budget" ]; then
    echo "polylane-promptopt: conservative estimated tokens $conservative_tokens exceed budget $budget" >&2; return 4
  fi
  if [ -n "$byte_budget" ] && [ "$bytes" -gt "$byte_budget" ]; then
    echo "polylane-promptopt: bytes $bytes exceed budget $byte_budget" >&2; return 4
  fi
  printf '%s\n' "$result"
}

contract_values() {
  local prompt="$1" raw line label
  while IFS= read -r raw || [ -n "$raw" ]; do
    line=$(trim_line "$raw")
    label=$(scalar_label "$line" || true)
    [ -n "$label" ] && printf '%s|%s\n' "$label" "${line#*:}"
  done < "$prompt"
  grep -qi 'Read only the named kit once' "$prompt" && echo 'selected-kit|present'
  grep -qiE 'STATUS:.*DONE.*run=' "$prompt" && echo 'nonce-done-marker|present'
}

compare() {
  local champion="$1" challenger="$2" champion_contracts challenger_contracts cmetrics hmetrics
  require_prompt "$champion" || return $?
  require_prompt "$challenger" || return $?
  strict_blocks "$champion" || return $?
  strict_blocks "$challenger" || return $?
  champion_contracts=$(contract_values "$champion")
  challenger_contracts=$(contract_values "$challenger")
  if [ "$champion_contracts" != "$challenger_contracts" ]; then
    echo "polylane-promptopt: challenger loses: required contract behavior differs" >&2
    return 7
  fi
  cmetrics=$(metrics "$champion")
  hmetrics=$(metrics "$challenger")
  printf '{"outcome":"WIN","champion":%s,"challenger":%s,"comparison":"frozen-contracts-equivalent"}\n' "$cmetrics" "$hmetrics"
}

main() {
  case "${1:-}" in
    metrics) [ "$#" -eq 2 ] || { usage; return 2; }; metrics "$2" ;;
    check) [ "$#" -eq 2 ] || [ "$#" -eq 3 ] || { usage; return 2; }; check "$2" "${3:-}" ;;
    compile) [ "$#" -eq 2 ] || { usage; return 2; }; compile "$2" ;;
    ui-version) [ "$#" -eq 2 ] || { usage; return 2; }; ui_version "$2" ;;
    compile-selected) [ "$#" -eq 5 ] || { usage; return 2; }; compile_selected "$2" "$3" "$4" "$5" ;;
    compare) [ "$#" -eq 3 ] || { usage; return 2; }; compare "$2" "$3" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
