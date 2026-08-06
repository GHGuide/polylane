#!/usr/bin/env bash
# polylane-advanced.sh — runner-facing admission, optional routing, and outcome adapter.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)

usage() {
  echo "usage: polylane-advanced.sh preflight|select|salvage|seams|record <manifest> [args]" >&2
}

manifest_ok() { [ -f "$1" ] && jq -e 'type == "object" and (.lanes | type == "array")' "$1" >/dev/null 2>&1; }

preflight() {
  local manifest="$1" risk_rc=0
  "$SCRIPT_DIR/polylane-outcomes.sh" predict "$manifest" || risk_rc=$?
  case "$risk_rc" in 0) printf 'ADVANCED: risk=admitted\n' ;; 5) printf 'ADVANCED: risk=flagged-admitted\n' ;; *) return "$risk_rc" ;; esac
  if jq -e '.champion_candidates | type == "array" and length > 0' "$manifest" >/dev/null 2>&1; then
    printf 'ADVANCED: selection=requested\n'
  else
    printf 'ADVANCED: selection=not-requested\n'
  fi
  if jq -e '(.salvage_verify_cmd | type == "string" and length > 0)' "$manifest" >/dev/null 2>&1; then
    printf 'ADVANCED: salvage=requested\n'
  else
    printf 'ADVANCED: salvage=not-requested\n'
  fi
}

select_champion() {
  local manifest="$1" candidates winner
  if ! jq -e '.champion_candidates | type == "array" and length > 0 and all(.[]; type == "string")' "$manifest" >/dev/null 2>&1; then
    printf 'ADVANCED: selection=not-requested\n'; return 0
  fi
  candidates=$(jq -r '.champion_candidates[]' "$manifest")
  # shellcheck disable=SC2086 # candidates are manifest-delimited argv specs.
  winner=$("$SCRIPT_DIR/polylane-select.sh" pick $candidates)
  printf 'ADVANCED: selection=%s\n' "${winner:-none}"
}

salvage() {
  local manifest="$1" verify lanes count
  if ! jq -e '(.salvage_verify_cmd | type == "string" and length > 0)' "$manifest" >/dev/null 2>&1; then
    printf 'ADVANCED: salvage=not-requested\n'; return 0
  fi
  verify=$(jq -r '.salvage_verify_cmd' "$manifest")
  lanes=$(jq -r '.salvage_lanes // [.lanes[].name] | .[]' "$manifest")
  count=$(printf '%s\n' "$lanes" | sed '/^$/d' | wc -l | tr -d ' ')
  [ "$count" -ge 3 ] || { echo 'ADVANCED: salvage requires at least three lanes' >&2; return 2; }
  # shellcheck disable=SC2086 # configured verifier is intentionally a command name.
  POLYLANE_VERIFY_CMD="$verify" "$SCRIPT_DIR/polylane-bisect.sh" salvage $lanes
}

seams() { # MANIFEST TREE EVIDENCE — preserve mechanical evidence for the gate
  local manifest="$1" tree="$2" evidence="$3" output rc=0
  [ -d "$tree" ] || { echo "ADVANCED: seam tree does not exist: $tree" >&2; return 2; }
  output=$("$SCRIPT_DIR/polylane-seams.sh" scan "$tree" 2>&1) || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf 'ADVANCED: seams=passed evidence=%s\n' "$evidence"
  else
    mkdir -p "$(dirname "$evidence")"
    printf '\n%s\n' "$output" >> "$evidence"
    printf '%s\n' "$output" >&2
    printf 'ADVANCED: seams=failed evidence=%s\n' "$evidence" >&2
  fi
  return "$rc"
}

record() {
  local manifest="$1" verdict="$2" lane model globs sig
  while IFS=$'\t' read -r lane model globs; do
    [ -n "$lane" ] || continue
    set -f
    # shellcheck disable=SC2086 # own_globs are patterns, not filesystem globs.
    sig=$("$SCRIPT_DIR/polylane-outcomes.sh" signature $globs)
    set +f
    "$SCRIPT_DIR/polylane-outcomes.sh" record "$lane" "$sig" "$model" "$verdict"
  done < <(jq -r '.lanes[] | [.name, .model, (.own_globs | join(" "))] | @tsv' "$manifest")
  printf 'ADVANCED: outcomes=recorded verdict=%s\n' "$verdict"
}

main() {
  [ $# -ge 2 ] || { usage; return 2; }
  local cmd="$1" manifest="$2"
  manifest_ok "$manifest" || { echo "ADVANCED: invalid manifest" >&2; return 2; }
  case "$cmd" in
    preflight) [ $# -eq 2 ] || { usage; return 2; }; preflight "$manifest" ;;
    select) [ $# -eq 2 ] || { usage; return 2; }; select_champion "$manifest" ;;
    salvage) [ $# -eq 2 ] || { usage; return 2; }; salvage "$manifest" ;;
    seams) [ $# -eq 4 ] || { usage; return 2; }; seams "$manifest" "$3" "$4" ;;
    record) [ $# -eq 3 ] || { usage; return 2; }; record "$manifest" "$3" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
