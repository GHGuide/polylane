#!/usr/bin/env bash
# polylane-scope.sh — enforce the own_globs isolation contract that the manifest
# declares but nothing checked. Two gates:
#   check-static <manifest>        : every lane has non-empty own_globs AND no two
#                                    lanes' glob sets can match the same path.
#   check-lane   <manifest> <lane> <path>...  : every given path is inside <lane>'s
#                                    own_globs (feed it `git diff --name-only`).
# Matching is CONSERVATIVE: ** collapses to * (case's * already spans '/'), so it
# errs toward "matches"/"overlaps" — a false NO-GO is safe; a false GO that ships a
# silent same-file double-write is not. Pure bash-3.2 (case only), main-guarded.
set -euo pipefail

# shellcheck disable=SC2254  # $g is DELIBERATELY a glob pattern here — that's the matcher
_match() { local p="$1" g="${2//\*\*/*}"; case "$p" in $g) return 0 ;; *) return 1 ;; esac; }
path_in_any() { local p="$1"; shift; local g rc=1; for g in "$@"; do if _match "$p" "$g"; then rc=0; break; fi; done; return $rc; }
_probe() { printf '%s' "${1//\*/X}"; }   # concrete witness path: every * / ** -> literal X
globs_overlap() {                        # 0 iff some path could match BOTH glob sets
  local A="$1" B="$2" ga gb pr
  for ga in $A; do pr=$(_probe "$ga"); for gb in $B; do _match "$pr" "$gb" && return 0; done; done
  for gb in $B; do pr=$(_probe "$gb"); for ga in $A; do _match "$pr" "$ga" && return 0; done; done
  return 1
}

_lane_globs() { jq -r --arg n "$2" '.lanes[] | select(.name==$n) | .own_globs[]?' "$1"; }

check_static() {
  local mf="$1" names i j a b ga gb rc=0
  command -v jq >/dev/null 2>&1 || { echo "polylane-scope: jq required" >&2; return 2; }
  names=$(jq -r '.lanes[].name' "$mf")
  for a in $names; do
    ga=$(_lane_globs "$mf" "$a" | tr '\n' ' ')
    [ -n "${ga// /}" ] || { echo "SCOPE-EMPTY: lane '$a' has no own_globs" >&2; rc=2; }
  done
  # unordered pairs
  set -- $names
  i=1
  while [ "$i" -le "$#" ]; do
    j=$((i + 1))
    while [ "$j" -le "$#" ]; do
      a=$(eval "echo \${$i}"); b=$(eval "echo \${$j}")
      ga=$(_lane_globs "$mf" "$a" | tr '\n' ' '); gb=$(_lane_globs "$mf" "$b" | tr '\n' ' ')
      if globs_overlap "$ga" "$gb"; then
        echo "SCOPE-OVERLAP: lanes '$a' and '$b' can both match a path (own_globs collide)" >&2; rc=2
      fi
      j=$((j + 1))
    done
    i=$((i + 1))
  done
  return $rc
}

check_lane() {
  local mf="$1" lane="$2"; shift 2
  local globs p rc=0
  globs=$(_lane_globs "$mf" "$lane" | tr '\n' ' ')
  for p in "$@"; do
    path_in_any "$p" $globs || { echo "SCOPE-VIOLATION: lane '$lane' wrote out-of-scope path '$p'" >&2; rc=2; }
  done
  return $rc
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  case "${1:-}" in
    check-static) shift; check_static "$@" ;;
    check-lane)   shift; check_lane   "$@" ;;
    *) echo "usage: polylane-scope.sh check-static <manifest> | check-lane <manifest> <lane> <path>..." >&2; exit 2 ;;
  esac
fi
