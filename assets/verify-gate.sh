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
for s in "$DIR"/docs/status-*.md; do
  [ -f "$s" ] || continue
  head -1 "$s" 2>/dev/null | grep -q 'DONE' || continue
  lane=$(basename "$s" .md); lane=${lane#status-}
  # the integrator's evidence file is verify-integration.md, not verify-integrator.md
  ev="verify-$lane.md"; [ "$lane" = integrator ] && ev="verify-integration.md"
  if [ ! -s "$DIR/docs/$ev" ]; then
    echo "polylane verify-gate: lane '$lane' claims DONE in $s but docs/$ev is missing/empty. Write the verification evidence (what you built + proof it works) before finishing." >&2
    exit 2
  fi
done
exit 0
