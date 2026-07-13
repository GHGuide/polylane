#!/usr/bin/env bash
# polylane-seams.sh — mechanical "the two halves don't wire up" detector on the
# INTEGRATED tree. Grep out cross-file name interfaces and report danglers the
# integrator's prose verdict waves through (real bug: getElementById('export-btn')
# with the button never landing in index.html). Feeds merge_gate an auto-NO-GO.
#   scan <dir>   -> `SEAM-DANGLING: dom-id <id>` per dangler; exit 1 iff any, else 0.
# `|| true` on every grep: a grep that matches nothing returns 1, which under
# `set -o pipefail` would otherwise abort the whole scan.
set -euo pipefail

scan_dom() {
  local dir="$1" refs prods id found=0
  refs=$( { grep -rhoE "getElementById\(['\"][A-Za-z0-9_-]+['\"]\)" "$dir" 2>/dev/null || true
            grep -rhoE "querySelector\(['\"]#[A-Za-z0-9_-]+['\"]\)"  "$dir" 2>/dev/null || true; } \
          | grep -oE "[A-Za-z0-9_-]+" | grep -vE '^(getElementById|querySelector)$' | sort -u || true )
  prods=$( grep -rhoE "id=['\"][A-Za-z0-9_-]+['\"]" "$dir" 2>/dev/null \
           | grep -oE "['\"][A-Za-z0-9_-]+['\"]" | tr -d "\"'" | sort -u || true )
  for id in $refs; do
    printf '%s\n' "$prods" | grep -qx "$id" || { echo "SEAM-DANGLING: dom-id $id"; found=1; }
  done
  return $found
}

case "${1:-}" in
  scan) shift; scan_dom "$@" ;;
  *) echo "usage: polylane-seams.sh scan <dir>" >&2; exit 2 ;;
esac
