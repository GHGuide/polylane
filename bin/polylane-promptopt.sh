#!/usr/bin/env bash
# polylane-promptopt.sh — compile and compare immutable builder prompts.
# Bash 3.2 only. Read-only commands never change the supplied prompt.
set -euo pipefail

usage() {
  echo "usage: polylane-promptopt.sh metrics <prompt> | check <prompt> [budget] | compile <prompt> | compare <champion> <challenger>" >&2
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
    compare) [ "$#" -eq 3 ] || { usage; return 2; }; compare "$2" "$3" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
