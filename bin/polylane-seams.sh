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
  # Test fixtures, dependencies, and generated exports are not integrated
  # source surfaces. Prune them before grep so framework internals cannot
  # introduce false dangling IDs. This form remains portable to BSD find and
  # the Bash 3.2 environment supported by Polylane.
  refs=$( { find "$dir" \( -type d \( -name tests -o -name node_modules -o -name .next -o -name '.next-*' -o -name out-ios \) -prune \) -o \( -type f \( -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' -o -name '*.html' -o -name '*.htm' \) -exec grep -hoE "getElementById\(['\"][A-Za-z0-9_-]+['\"]\)" {} + \) 2>/dev/null || true
            find "$dir" \( -type d \( -name tests -o -name node_modules -o -name .next -o -name '.next-*' -o -name out-ios \) -prune \) -o \( -type f \( -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' -o -name '*.html' -o -name '*.htm' \) -exec grep -hoE "querySelector\(['\"]#[A-Za-z0-9_-]+['\"]\)" {} + \) 2>/dev/null || true; } \
          | grep -oE "[A-Za-z0-9_-]+" | grep -vE '^(getElementById|querySelector)$' | sort -u || true )
  prods=$( find "$dir" \( -type d \( -name tests -o -name node_modules -o -name .next -o -name '.next-*' -o -name out-ios \) -prune \) -o \( -type f \( -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' -o -name '*.html' -o -name '*.htm' \) -exec grep -hoE "id=['\"][A-Za-z0-9_-]+['\"]" {} + \) 2>/dev/null \
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
