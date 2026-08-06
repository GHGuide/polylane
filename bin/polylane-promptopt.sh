#!/usr/bin/env bash
# polylane-promptopt.sh — validate immutable worker prompt blocks and report
# deterministic local estimates. It never edits its input or creates sidecars.
set -euo pipefail

usage() {
  echo "usage: polylane-promptopt.sh metrics <prompt> | check <prompt> [budget]" >&2
}

require_prompt() {
  [ -f "$1" ] || { echo "polylane-promptopt: prompt not found: $1" >&2; return 2; }
}

metrics() {
  local prompt="$1" bytes tokens
  require_prompt "$prompt" || return $?
  bytes=$(wc -c < "$prompt" | tr -d '[:space:]')
  tokens=$(awk '{ words += NF } END { print words + 0 }' "$prompt")
  printf '{"bytes":%s,"tokens":%s}\n' "$bytes" "$tokens"
}

strict_blocks() {
  local prompt="$1" spec label pattern
  for spec in \
    'ultimate-goal|^ULTIMATE-GOAL:' \
    'current-subgoal|^CURRENT-SUBGOAL:' \
    'goal|^GOAL:' \
    'ownership|OWN' \
    'forbidden-boundary|FORBIDDEN' \
    'predefined-skills|^PREDEFINED-SKILLS:' \
    'lane-specific-skills|^LANE-SPECIFIC-SKILLS:' \
    'selected-kit|Read only the named kit once' \
    'test-cadence|^TEST-CADENCE:' \
    'delegation|^DELEGATION:' \
    'check-cache|^CHECK-CACHE:' \
    'external-evidence|^EXTERNAL-EVIDENCE:' \
    'verification|VERIFY' \
    'nonce-done-marker|STATUS:.*DONE.*run='; do
    label=${spec%%|*}; pattern=${spec#*|}
    grep -qiE "$pattern" "$prompt" || {
      echo "polylane-promptopt: missing strict block: $label" >&2
      return 3
    }
  done
}

check() {
  local prompt="$1" budget="${2:-8000}" byte_budget="${POLYLANE_PROMPT_BYTE_BUDGET:-}" result bytes tokens
  require_prompt "$prompt" || return $?
  case "$budget" in ''|*[!0-9]*)
    echo "polylane-promptopt: budget must be a positive integer" >&2; return 2 ;;
  esac
  [ "$budget" -gt 0 ] || {
    echo "polylane-promptopt: budget must be a positive integer" >&2; return 2
  }
  if [ -n "$byte_budget" ]; then
    case "$byte_budget" in ''|*[!0-9]*)
      echo "polylane-promptopt: byte budget must be a positive integer" >&2; return 2 ;;
    esac
    [ "$byte_budget" -gt 0 ] || {
      echo "polylane-promptopt: byte budget must be a positive integer" >&2; return 2
    }
  fi
  strict_blocks "$prompt" || return $?
  result=$(metrics "$prompt")
  bytes=$(printf '%s' "$result" | sed -n 's/.*"bytes":\([0-9][0-9]*\).*/\1/p')
  tokens=$(printf '%s' "$result" | sed -n 's/.*"tokens":\([0-9][0-9]*\).*/\1/p')
  if [ "$tokens" -gt "$budget" ]; then
    echo "polylane-promptopt: estimated tokens $tokens exceed budget $budget" >&2
    return 4
  fi
  if [ -n "$byte_budget" ] && [ "$bytes" -gt "$byte_budget" ]; then
    echo "polylane-promptopt: bytes $bytes exceed budget $byte_budget" >&2
    return 4
  fi
  printf '%s\n' "$result"
}

main() {
  case "${1:-}" in
    metrics) [ "$#" -eq 2 ] || { usage; return 2; }; metrics "$2" ;;
    check) [ "$#" -eq 2 ] || [ "$#" -eq 3 ] || { usage; return 2; }; check "$2" "${3:-}" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
