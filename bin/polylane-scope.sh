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
# _pair_overlap GLOB GLOB : 0 iff a path exists matching BOTH. Walks path segments —
# ** absorbs all remaining segments; * matches one; a literal must fnmatch the other
# side. Catches cross-wildcard collisions a single all-*→X witness misses
# (src/a/** vs src/*/shared.ts on src/a/shared.ts). Conservative: errs toward overlap.
_pair_overlap() {
  local sa sb i=0
  local -a A B
  # read -ra splits on '/' and never glob-expands (so ** stays literal) — no set -f needed
  IFS=/ read -ra A <<<"$1"
  IFS=/ read -ra B <<<"$2"
  while :; do
    sa="${A[$i]:-}"; sb="${B[$i]:-}"
    [ -z "$sa" ] && [ -z "$sb" ] && return 0          # both exhausted, same depth
    case "$sa" in '**') return 0 ;; esac              # ** absorbs the rest
    case "$sb" in '**') return 0 ;; esac
    { [ -z "$sa" ] || [ -z "$sb" ]; } && return 1     # different depth
    if [ "$sa" != '*' ] && [ "$sb" != '*' ]; then     # both literal-ish -> must fnmatch
      # shellcheck disable=SC2254  # $sa/$sb are intentional fnmatch patterns
      case "$sa" in $sb) : ;; *) case "$sb" in $sa) : ;; *) return 1 ;; esac ;; esac
    fi
    i=$((i + 1))
  done
}
globs_overlap() {                        # 0 iff some path could match BOTH glob sets
  local setA="$1" setB="$2" ga gb
  for ga in $setA; do for gb in $setB; do _pair_overlap "$ga" "$gb" && return 0; done; done
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

# check_status_markers MANIFEST : every builder owns exactly its canonical DONE
# marker, and no second/broad glob can match any docs/status-*.md path. A broad
# docs glob silently authorizes a lane to overwrite another lane's completion
# signal; a shortened explicit path makes the worker follow a contract the poll
# can never observe. Both are free pre-launch plan errors.
check_status_markers() {
  local mf="$1" names lane canonical glob exact_count rc=0
  command -v jq >/dev/null 2>&1 || { echo "polylane-scope: jq required" >&2; return 2; }
  names=$(jq -r '.lanes[].name' "$mf")
  for lane in $names; do
    canonical="docs/status-$lane.md"
    exact_count=0
    while IFS= read -r glob; do
      [ -n "$glob" ] || continue
      if [ "$glob" = "$canonical" ]; then
        exact_count=$((exact_count + 1))
      elif _pair_overlap "$glob" 'docs/status-*.md'; then
        echo "SCOPE-STATUS: lane '$lane' noncanonical glob '$glob' can own a status marker; only '$canonical' is allowed" >&2
        rc=2
      fi
    done < <(_lane_globs "$mf" "$lane")
    if [ "$exact_count" -ne 1 ]; then
      echo "SCOPE-STATUS: lane '$lane' must own '$canonical' exactly once (found $exact_count)" >&2
      rc=2
    fi
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
    check-status) shift; check_status_markers "$@" ;;
    check-lane)   shift; check_lane   "$@" ;;
    *) echo "usage: polylane-scope.sh check-static <manifest> | check-status <manifest> | check-lane <manifest> <lane> <path>..." >&2; exit 2 ;;
  esac
fi
