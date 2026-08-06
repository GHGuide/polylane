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
  local prompt="$1" block
  for block in GOAL CONTEXT CONSTRAINTS VERIFICATION; do
    grep -q "^## ${block}[[:space:]]*$" "$prompt" || {
      echo "polylane-promptopt: missing strict block: $block" >&2
      return 3
    }
  done
}

check() {
  local prompt="$1" budget="${2:-8000}" result tokens
  require_prompt "$prompt" || return $?
  case "$budget" in ''|*[!0-9]*)
    echo "polylane-promptopt: budget must be a positive integer" >&2; return 2 ;;
  esac
  [ "$budget" -gt 0 ] || {
    echo "polylane-promptopt: budget must be a positive integer" >&2; return 2
  }
  strict_blocks "$prompt" || return $?
  result=$(metrics "$prompt")
  tokens=$(printf '%s' "$result" | sed -n 's/.*"tokens":\([0-9][0-9]*\).*/\1/p')
  if [ "$tokens" -gt "$budget" ]; then
    echo "polylane-promptopt: estimated tokens $tokens exceed budget $budget" >&2
    return 4
  fi
  printf '%s\n' "$result"
}

case "${1:-}" in
  metrics) [ "$#" -eq 2 ] || { usage; exit 2; }; metrics "$2" ;;
  check) [ "$#" -eq 2 ] || [ "$#" -eq 3 ] || { usage; exit 2; }; check "$2" "${3:-}" ;;
  *) usage; exit 2 ;;
esac
