#!/usr/bin/env bash
# polylane-promptopt.sh — compile and compare immutable builder prompts.
# Bash 3.2 only. Read-only commands never change the supplied prompt.
set -euo pipefail

usage() {
  echo "usage: polylane-promptopt.sh metrics <prompt> | check <prompt> [budget] | compile <prompt> | compile-selected <prompt> <kit> <lane> <output> | compare <champion> <challenger>" >&2
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
    *) return 1 ;;
  esac
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
    compile-selected) [ "$#" -eq 5 ] || { usage; return 2; }; compile_selected "$2" "$3" "$4" "$5" ;;
    compare) [ "$#" -eq 3 ] || { usage; return 2; }; compare "$2" "$3" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
