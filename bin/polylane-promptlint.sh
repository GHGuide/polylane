#!/usr/bin/env bash
# polylane-promptlint.sh — deterministic gate on a GENERATED lane prompt before launch.
# The orchestrator writes each .polylane/lanes/<lane>.txt with an LLM, so a block can be
# dropped (the marker-drift + missing-OWN/FORBIDDEN bugs were exactly this). This lints
# for the empirically-validated structure — objective, tool/file boundaries, the nonce
# DONE contract, verify evidence — the way DSPy/promptfoo enforce prompt quality, but
# cheap and offline (the prompts are generated fresh per lane, so there's nothing to
# compile). Reports PROMPT-LINT: <lane> missing <what>; exit 6 if any lane fails.
#   lint <lane-prompt-file> [<lane-name>]     one prompt
#   lint-run <manifest>                        every lane's prompt in a run.json
# Pure bash-3.2 + jq (jq only for lint-run); main-guarded.
set -euo pipefail

# required token -> human label. A prompt must contain each (case-insensitive).
lint_one() {
  local f="$1" lane="${2:-$(basename "$1" .txt)}" miss=""
  [ -s "$f" ] || { echo "PROMPT-LINT: $lane empty-or-missing $f"; return 6; }
  grep -qiE 'GOAL|/goal' "$f"        || miss="$miss objective(GOAL)"
  grep -qi  'OWN'  "$f"              || miss="$miss ownership(OWN)"
  grep -qi  'FORBIDDEN' "$f"         || miss="$miss boundaries(FORBIDDEN)"
  grep -qE  'STATUS:.*DONE'  "$f"    || miss="$miss done-marker(STATUS:..DONE)"
  grep -q   'run='  "$f"             || miss="$miss nonce(run=<RUN_ID>)"
  grep -qi  'verify' "$f"            || miss="$miss verify-evidence"
  if [ -n "$miss" ]; then echo "PROMPT-LINT: $lane missing$miss"; return 6; fi
  return 0
}

lint_run() {
  local mf="$1" rc=0 lane pf dir
  command -v jq >/dev/null 2>&1 || { echo "polylane-promptlint: jq required for lint-run" >&2; return 2; }
  dir=$(cd "$(dirname "$mf")/.." && pwd)   # .polylane/ -> project root
  # `// empty`: a manifest with no integrator yields no phantom "null" lane
  for lane in $(jq -r '.lanes[].name, (.integrator.name // empty)' "$mf"); do
    pf=$(jq -r --arg n "$lane" '(.lanes[],.integrator) | select(.name==$n) | .prompt_file' "$mf" | head -1)
    [ -n "$pf" ] && [ "$pf" != "null" ] || { echo "PROMPT-LINT: $lane no prompt_file"; rc=6; continue; }
    case "$pf" in /*) : ;; *) pf="$dir/$pf" ;; esac
    lint_one "$pf" "$lane" || rc=6
  done
  return $rc
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  case "${1:-}" in
    lint)     shift; lint_one "$@" ;;
    lint-run) shift; lint_run "${1:?usage: lint-run <manifest>}" ;;
    *) echo "usage: polylane-promptlint.sh lint <prompt-file> [lane] | lint-run <manifest>" >&2; exit 2 ;;
  esac
fi
