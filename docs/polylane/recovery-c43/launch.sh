#!/usr/bin/env bash
# One-command cycle-43 recovery launch. Usage: launch.sh [codex|claude]
# Restores the validated scratch files, gates on doctor (incl. provider auth),
# then hands off to the supervisor. Safe to re-run; refuses on any gate failure.
set -euo pipefail
AGENT="${1:-codex}"
case "$AGENT" in codex|claude) ;; *) echo "usage: launch.sh [codex|claude]" >&2; exit 2 ;; esac
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
SRC="docs/polylane/recovery-c43"
mkdir -p .polylane/lanes
cp "$SRC/c43-contract-import.txt" "$SRC/c43-integrator.txt" .polylane/lanes/
cp "$SRC/lane-skills-c43.json" .polylane/lane-skills-c43.json
cp "$SRC/run-$AGENT.json" ".polylane/run-recovery-$AGENT.json"
POLYLANE_AGENT="$AGENT" bin/polylane-doctor.sh ".polylane/run-recovery-$AGENT.json"
POLYLANE_SESSION=polylane-c43-recovery bin/polylane-supervisor.sh ".polylane/run-recovery-$AGENT.json"
