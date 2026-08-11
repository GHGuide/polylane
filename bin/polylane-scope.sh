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

# check_write_plan MANIFEST : opt-in contract for generated plans.  Exact planned
# writes are deliberately narrower than ownership globs: a planner must name a
# safe, unique repository-relative path and the static gate proves its owner can
# write it before git worktrees or tmux panes exist.  Legacy manifests omit the
# version and remain unchanged.
planned_write_safe() {
  local path="$1" part
  case "$path" in
    ''|/*|*/|*'//'*) return 1 ;;
    *'*'*|*'?'*|*'['*|*']'*|*'{'*|*'}'*) return 1 ;;
  esac
  local IFS=/
  for part in $path; do
    case "$part" in ''|.|..) return 1 ;; esac
  done
}

check_write_plan() {
  local mf="$1" contract names lane globs writes path dup rc=0
  command -v jq >/dev/null 2>&1 || { echo "polylane-scope: jq required" >&2; return 2; }
  contract=$(jq -r 'if has("write_plan_contract") then .write_plan_contract else 0 end' "$mf") || return 2
  case "$contract" in
    0|null) return 0 ;;
    1) : ;;
    *) echo "SCOPE-WRITE-PLAN: write_plan_contract must be 1 when present" >&2; return 2 ;;
  esac
  names=$(jq -r '.lanes[].name' "$mf")
  for lane in $names; do
    if ! jq -e --arg n "$lane" '
      any(.lanes[]; .name==$n and
        (.planned_writes | type=="array" and length>0 and
          all(.[]; (type=="string") and (contains("\n") | not) and (contains("\r") | not) and (index("\u0000") | not))))
    ' "$mf" >/dev/null 2>&1; then
      echo "SCOPE-WRITE-PLAN: lane '$lane' needs a non-empty planned_writes array" >&2
      rc=2
      continue
    fi
    writes=$(jq -r --arg n "$lane" '.lanes[] | select(.name==$n) | .planned_writes[]' "$mf")
    dup=$(printf '%s\n' "$writes" | LC_ALL=C sort | uniq -d | head -n 1)
    if [ -n "$dup" ]; then
      echo "SCOPE-WRITE-PLAN: lane '$lane' repeats planned write '$dup'" >&2
      rc=2
    fi
    globs=$(_lane_globs "$mf" "$lane" | tr '\n' ' ')
    while IFS= read -r path; do
      if ! planned_write_safe "$path"; then
        echo "SCOPE-WRITE-PLAN: lane '$lane' has unsafe planned write '$path'" >&2
        rc=2
      elif ! path_in_any "$path" $globs; then
        echo "SCOPE-WRITE-PLAN: lane '$lane' planned write is out of scope '$path'" >&2
        rc=2
      fi
    done <<EOF
$writes
EOF
  done
  return $rc
}

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
  check_write_plan "$mf" || rc=2
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
    check-write-plan) shift; check_write_plan "$@" ;;
    *) echo "usage: polylane-scope.sh check-static <manifest> | check-status <manifest> | check-lane <manifest> <lane> <path>... | check-write-plan <manifest>" >&2; exit 2 ;;
  esac
fi
