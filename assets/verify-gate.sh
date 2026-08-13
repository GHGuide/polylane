#!/usr/bin/env bash
# Stop hook — a lane may NOT finish having claimed DONE without leaving evidence.
# If docs/status-<lane>.md says DONE but docs/verify-<lane>.md is missing/empty,
# BLOCK (exit 2) so the agent must write the proof before stopping. The lane prompt
# only ASKS for verification; this hook ENFORCES it deterministically (the research
# lesson: hooks are the deterministic layer under a probabilistic agent).
# Must exit 0 on every non-block path (missing dir, closed stdout, set -e callers).
input=$(cat 2>/dev/null || true)
# already retried once via a stop hook -> don't hard-loop; let the agent stop.
case "$input" in *'"stop_hook_active":true'*) exit 0 ;; esac

DIR="${CLAUDE_PROJECT_DIR:-.}"
lane=""
run_id=""
role=""
explicit=0
while [ "$#" -gt 0 ]; do
  explicit=1
  case "$1" in
    --project) DIR=${2:-}; shift 2 ;;
    --lane) lane=${2:-}; shift 2 ;;
    --run-id) run_id=${2:-}; shift 2 ;;
    --role) role=${2:-}; shift 2 ;;
    *) echo "usage: verify-gate.sh --project ROOT --lane NAME --run-id RUN --role builder|integrator" >&2; exit 2 ;;
  esac
done
if [ "$explicit" = 1 ]; then
  case "$lane" in ''|*[!A-Za-z0-9._-]*) echo "polylane verify-gate: explicit lane is invalid" >&2; exit 2 ;; esac
  case "$run_id" in ''|*[!A-Za-z0-9._-]*) echo "polylane verify-gate: explicit run is invalid" >&2; exit 2 ;; esac
  case "$role" in builder|integrator) : ;; *) echo "polylane verify-gate: explicit role is invalid" >&2; exit 2 ;; esac
  marker="STATUS: $lane DONE run=$run_id"
  status="$DIR/docs/status-$lane.md"
  [ "$role" = integrator ] && ev=verify-integration.md || ev="verify-$lane.md"
  if [ ! -f "$status" ] || [ "$(sed -n '1p' "$status")" != "$marker" ] || [ ! -s "$DIR/docs/$ev" ]; then
    echo "polylane verify-gate: explicit $role '$lane' lacks exact current-run marker/evidence for run=$run_id" >&2
    exit 2
  fi
  if [ "$role" = integrator ]; then
    tail -n 1 "$DIR/docs/$ev" | grep -Eq "^POLYLANE-VERDICT: (GO|READY-FOR-HOST-GATE|EXTERNAL-EVIDENCE-OPEN|NO-GO) run=$run_id$" || {
      echo "polylane verify-gate: integrator verdict is not the exact final current-run line" >&2
      exit 2
    }
  elif ! grep -qF "run=$run_id" "$DIR/docs/$ev"; then
    echo "polylane verify-gate: builder evidence is not tagged run=$run_id" >&2
    exit 2
  fi
  exit 0
fi

for s in "$DIR"/docs/status-*.md; do
  [ -f "$s" ] || continue
  head -1 "$s" 2>/dev/null | grep -q 'DONE' || continue
  lane=$(basename "$s" .md); lane=${lane#status-}
  ev="verify-$lane.md"
  [ "$lane" = integrator ] && ev=verify-integration.md
  if [ ! -s "$DIR/docs/$ev" ]; then
    echo "polylane verify-gate: lane '$lane' claims DONE in $s but docs/$ev is missing/empty. Write the verification evidence (what you built + proof it works) before finishing." >&2
    exit 2
  fi
done
exit 0
