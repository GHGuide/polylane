#!/usr/bin/env bash
# polylane-bisect.sh — salvage-merge via lane bisection (delta debugging). On an
# integrator NO-GO, find the minimal FAILING lane subset (the culprit(s)) and the
# maximal GREEN subset to promote, so one poisoned lane can't discard its good
# neighbours. Pure + main-guarded.
#
# VERIFY CALLBACK: a command named by $POLYLANE_VERIFY_CMD (default "verify_subset")
# is invoked as `$cmd "<csv-subset>"` and must exit 0 iff that subset VERIFIES GREEN,
# non-zero iff it FAILS. The helper never defines it (the caller wires it to a real
# merge-into-scratch + integrator smoke, or a test stub).
set -euo pipefail

_verify() { "${POLYLANE_VERIFY_CMD:-verify_subset}" "$1"; }
_csv()    { local out="" x; for x in $1; do out="${out:+$out,}$x"; done; printf '%s' "$out"; }
_remove() { local out="" x; for x in $1; do [ "$x" = "$2" ] || out="${out:+$out }$x"; done; printf '%s' "$out"; }

# minimal_failing_subset SPACE_LIST -> a 1-minimal FAILING subset (removing any one
# member makes it pass). Precondition: _verify(full list) fails.
minimal_failing_subset() {
  local S="$1" changed=1 x rest
  while [ "$changed" = 1 ]; do
    changed=0
    for x in $S; do
      rest=$(_remove "$S" "$x"); [ -z "$rest" ] && continue
      if ! _verify "$(_csv "$rest")"; then S="$rest"; changed=1; break; fi
    done
  done
  printf '%s' "$S"
}

# salvage LANE... : prints `POLYLANE-SALVAGE: green=<csv> culprit=<csv>`. Iteratively
# strips each minimal failing subset until the remainder verifies green.
salvage() {
  local full="$*" working culprits="" m x y keep w
  [ -z "$full" ] && { echo "polylane-bisect: no lanes" >&2; return 2; }
  if _verify "$(_csv "$full")"; then
    printf 'POLYLANE-SALVAGE: green=%s culprit=\n' "$(_csv "$full")"; return 0
  fi
  working="$full"
  while [ -n "$working" ] && ! _verify "$(_csv "$working")"; do
    m=$(minimal_failing_subset "$working"); culprits="${culprits:+$culprits }$m"
    w=""; for x in $working; do
      keep=1; for y in $m; do [ "$x" = "$y" ] && keep=0; done
      [ "$keep" = 1 ] && w="${w:+$w }$x"
    done
    working="$w"
  done
  printf 'POLYLANE-SALVAGE: green=%s culprit=%s\n' "$(_csv "$working")" "$(_csv "$culprits")"
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  case "${1:-}" in
    salvage) shift
      [ "$#" -ge 3 ] || { echo "polylane-bisect: salvage needs >=3 lanes (not worth bisecting below 3)" >&2; exit 2; }
      salvage "$@" ;;
    *) echo "usage: polylane-bisect.sh salvage <lane> <lane> <lane> [...]" >&2; exit 2 ;;
  esac
fi
