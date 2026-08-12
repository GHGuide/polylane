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
path_in_any() ( local p="$1"; shift; local g rc=1; set -f; for g in "$@"; do if _match "$p" "$g"; then rc=0; break; fi; done; return $rc; )
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
globs_overlap() (                        # 0 iff some path could match BOTH glob sets
  local setA="$1" setB="$2" ga gb
  set -f
  for ga in $setA; do for gb in $setB; do _pair_overlap "$ga" "$gb" && return 0; done; done
  return 1
)

_lane_globs() { jq -r --arg n "$2" '.lanes[] | select(.name==$n) | .own_globs[]?' "$1"; }

# --- exclusive candidate group -----------------------------------------------
# A tournament runs exactly three same-base candidate lanes that DELIBERATELY
# share one module scope. Their mutual overlap is legal ONLY inside the declared
# group globs; ordinary lanes may never overlap them; exactly one selected tip
# may reach integration. Legacy manifests omit candidate_group and are unchanged.
_candidate_members() {
  jq -r 'if has("candidate_group") then (.candidate_group.members[]? // empty) else empty end' "$1" 2>/dev/null
}

# check_candidate_group MANIFEST : validate the exclusive-group declaration.
# No group -> 0. Bad shape/member/scope/selection -> 2 with a SCOPE-CANDIDATE
# witness. Each member's non-status globs must EQUAL the shared group globs, so
# the three overlap only inside the group and nowhere else.
check_candidate_group() {
  local mf="$1" shared m mglobs selected lane_names rc=0
  command -v jq >/dev/null 2>&1 || { echo "polylane-scope: jq required" >&2; return 2; }
  [ "$(jq -r 'has("candidate_group")' "$mf" 2>/dev/null)" = true ] || return 0
  if ! jq -e '.candidate_group | (type=="object")
      and ((keys - ["members","shared_globs","selected","base_lane"]) | length == 0)
      and (.members | type=="array" and length==3 and ((unique|length)==3) and all(.[]; type=="string" and length>0))
      and (.shared_globs | type=="array" and length>0 and ((unique|length)==length) and all(.[]; type=="string" and length>0))
      and ((has("selected")|not) or (.selected|type=="string" and length>0))' "$mf" >/dev/null 2>&1; then
    echo "SCOPE-CANDIDATE: candidate_group must have exactly three unique members and non-empty shared_globs" >&2
    return 2
  fi
  lane_names=" $(jq -r '.lanes[].name' "$mf" | tr '\n' ' ') "
  shared=$(jq -r '.candidate_group.shared_globs[]' "$mf" | LC_ALL=C sort)
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    case "$lane_names" in *" $m "*) ;; *) echo "SCOPE-CANDIDATE: member '$m' is not a declared lane" >&2; rc=2; continue ;; esac
    mglobs=$(jq -r --arg m "$m" '.lanes[] | select(.name==$m) | .own_globs[] | select(. != ("docs/status-"+$m+".md"))' "$mf" | LC_ALL=C sort)
    if [ "$mglobs" != "$shared" ]; then
      echo "SCOPE-CANDIDATE: member '$m' scope must equal the shared group globs (no escape outside the exclusive group)" >&2
      rc=2
    fi
  done < <(_candidate_members "$mf")
  selected=$(jq -r '.candidate_group.selected // empty' "$mf")
  if [ -n "$selected" ]; then
    case " $(_candidate_members "$mf" | tr '\n' ' ') " in
      *" $selected "*) ;;
      *) echo "SCOPE-CANDIDATE: selected tip '$selected' is not a group member" >&2; rc=2 ;;
    esac
  fi
  return $rc
}

# integration_tip MANIFEST : print the single selected candidate tip permitted to
# reach the ordinary integration join. Ambiguity or absence fails closed.
integration_tip() {
  local mf="$1" selected
  check_candidate_group "$mf" || return 2
  [ "$(jq -r 'has("candidate_group")' "$mf" 2>/dev/null)" = true ] || { echo "SCOPE-CANDIDATE: no candidate_group" >&2; return 2; }
  selected=$(jq -r '.candidate_group.selected // empty' "$mf")
  [ -n "$selected" ] || { echo "SCOPE-CANDIDATE: no selected integration tip" >&2; return 2; }
  printf '%s\n' "$selected"
}

# Keep manifest glob records newline-delimited until the intentional `case`
# matcher. Flattening and then expanding an unquoted list lets the caller's cwd
# rewrite src/** into real checkout paths before scope sees the declared glob.
path_in_lane_globs() {
  local mf="$1" lane="$2" path="$3" glob
  while IFS= read -r glob; do
    [ -n "$glob" ] && _match "$path" "$glob" && return 0
  done < <(_lane_globs "$mf" "$lane")
  return 1
}

lane_globs_overlap() {
  local mf="$1" lane_a="$2" lane_b="$3" ga gb
  while IFS= read -r ga; do
    [ -n "$ga" ] || continue
    while IFS= read -r gb; do
      [ -n "$gb" ] && _pair_overlap "$ga" "$gb" && return 0
    done < <(_lane_globs "$mf" "$lane_b")
  done < <(_lane_globs "$mf" "$lane_a")
  return 1
}

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
  local mf="$1" contract names lane writes path dup rc=0
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
    while IFS= read -r path; do
      if ! planned_write_safe "$path"; then
        echo "SCOPE-WRITE-PLAN: lane '$lane' has unsafe planned write '$path'" >&2
        rc=2
      elif ! path_in_lane_globs "$mf" "$lane" "$path"; then
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
  local mf="$1" names i j a b ga gb rc=0 members lane_count
  local -a lane_names lane_glob_sets
  command -v jq >/dev/null 2>&1 || { echo "polylane-scope: jq required" >&2; return 2; }
  names=$(jq -r '.lanes[].name' "$mf")
  members=" $(_candidate_members "$mf" | tr '\n' ' ') "
  for a in $names; do
    ga=$(_lane_globs "$mf" "$a" | tr '\n' ' ')
    [ -n "${ga// /}" ] || { echo "SCOPE-EMPTY: lane '$a' has no own_globs" >&2; rc=2; }
    lane_names[${#lane_names[@]}]="$a"
    lane_glob_sets[${#lane_glob_sets[@]}]="$ga"
  done
  # Unordered pairs. Load each lane's globs once above: re-running jq inside
  # lane_globs_overlap for every glob/pair created hundreds of process
  # substitutions and crashes macOS Bash 3.2 around a production-sized carve.
  lane_count=${#lane_names[@]}
  i=0
  while [ "$i" -lt "$lane_count" ]; do
    j=$((i + 1))
    while [ "$j" -lt "$lane_count" ]; do
      a="${lane_names[$i]}"; b="${lane_names[$j]}"
      ga="${lane_glob_sets[$i]}"; gb="${lane_glob_sets[$j]}"
      # Two members of the exclusive candidate group are ALLOWED to overlap —
      # that is the whole point of the same-base tournament. check_candidate_group
      # (below) confines that overlap to the declared group globs. Any other pair,
      # including member-vs-ordinary, is still a hard isolation violation.
      case "$members" in
        *" $a "*)
          case "$members" in *" $b "*) j=$((j + 1)); continue ;; esac ;;
      esac
      if globs_overlap "$ga" "$gb"; then
        echo "SCOPE-OVERLAP: lanes '$a' and '$b' can both match a path (own_globs collide)" >&2; rc=2
      fi
      j=$((j + 1))
    done
    i=$((i + 1))
  done
  check_write_plan "$mf" || rc=2
  check_candidate_group "$mf" || rc=2
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
  local p rc=0
  for p in "$@"; do
    path_in_lane_globs "$mf" "$lane" "$p" || { echo "SCOPE-VIOLATION: lane '$lane' wrote out-of-scope path '$p'" >&2; rc=2; }
  done
  return $rc
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  case "${1:-}" in
    check-static) shift; check_static "$@" ;;
    check-status) shift; check_status_markers "$@" ;;
    check-lane)   shift; check_lane   "$@" ;;
    check-write-plan) shift; check_write_plan "$@" ;;
    check-candidates) shift; check_candidate_group "$@" ;;
    integration-tip) shift; integration_tip "$@" ;;
    *) echo "usage: polylane-scope.sh check-static <manifest> | check-status <manifest> | check-lane <manifest> <lane> <path>... | check-write-plan <manifest> | check-candidates <manifest> | integration-tip <manifest>" >&2; exit 2 ;;
  esac
fi
