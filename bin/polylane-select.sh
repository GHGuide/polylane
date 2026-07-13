#!/usr/bin/env bash
# polylane-select.sh — champion/challenger selection for ONE flagged lane. Each
# variant worktree writes a `POLYLANE-SCORE: <int>` sentinel (own line) in its
# verify file; the winner (highest score; tie -> fewer LOC) is merged, the rest
# discarded. Pure + main-guarded so tests source the functions.
#   pick <id>|<scorefile>|<loc>  [<id>|<scorefile>|<loc> ...]   -> winning id (or empty)
set -euo pipefail

# _score FILE : last own-line POLYLANE-SCORE int, or empty (missing/garbled -> empty).
_score() {
  [ -f "$1" ] || return 0
  grep -E '^[[:space:]]*POLYLANE-SCORE:[[:space:]]*-?[0-9]+[[:space:]]*$' "$1" 2>/dev/null \
    | tail -1 | grep -Eo '\-?[0-9]+' | tail -1
}

# pick_best_attempt SPEC... : SPEC = "id|scorefile|loc". Highest score wins; tie ->
# fewer loc; an unscored/garbled variant NEVER wins; all-unscored -> empty string.
pick_best_attempt() {
  local best="" bs="" bl="" spec id rest sf loc sc
  for spec in "$@"; do
    id="${spec%%|*}"; rest="${spec#*|}"; sf="${rest%%|*}"; loc="${rest##*|}"
    sc=$(_score "$sf"); [ -z "$sc" ] && continue
    if [ -z "$best" ] || [ "$sc" -gt "$bs" ] || { [ "$sc" -eq "$bs" ] && [ "$loc" -lt "$bl" ]; }; then
      best="$id"; bs="$sc"; bl="$loc"
    fi
  done
  printf '%s' "$best"
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  case "${1:-}" in
    pick) shift; pick_best_attempt "$@" ;;
    *) echo "usage: polylane-select.sh pick <id>|<scorefile>|<loc> ..." >&2; exit 2 ;;
  esac
fi
