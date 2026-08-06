#!/usr/bin/env bash
# Emit explicit report items from the supplied current-run evidence files.

set -euo pipefail

usage() {
  echo "usage: polylane-report-items.sh <evidence.md> [...]" >&2
  exit 2
}

[ "$#" -gt 0 ] || usage

for evidence in "$@"; do
  [ -f "$evidence" ] || {
    echo "polylane-report-items.sh: not a file: $evidence" >&2
    exit 2
  }

  awk '
    /^#{1,6}[[:space:]]+(Deferred|External|Open items)[[:space:]]*#*[[:space:]]*$/ {
      in_items = 1
      next
    }
    /^#{1,6}[[:space:]]/ {
      in_items = 0
      next
    }
    in_items && /^[-*+][[:space:]]+[^[:space:]]/ {
      item = $0
      sub(/^[-*+][[:space:]]+/, "", item)
      if (item ~ /^(STATUS:|POLYLANE-VERDICT:)/) next
      if (item ~ /^`/ || item ~ /^\$[[:space:]]/) next
      if (item ~ /^(bash|sh|zsh|git|make|npm|pnpm|yarn|node|python|pytest)[[:space:]]/) next
      print $0
    }
  ' "$evidence"
done
