#!/usr/bin/env bash
# polylane-rehearse.sh — the canary itself must reach promote-on-GO and gate on NO-GO.
# Drives the REAL runner with real tmux, so it's SLOW + gated behind POLYLANE_REHEARSE=1
# to keep the default suite fast/hermetic. Run on demand: POLYLANE_REHEARSE=1 tests/run.sh
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
RH="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-rehearse.sh"

if [ "${POLYLANE_REHEARSE:-0}" != "1" ]; then
  pass "rehearse-gated-off (set POLYLANE_REHEARSE=1 to run the live canary)"; finish; exit 0
fi
if ! command -v tmux >/dev/null 2>&1; then
  pass "rehearse-skipped-no-tmux"; finish; exit 0
fi

out=$("$RH" go 2>&1); rc=$?
if [ "$rc" = 77 ]; then pass "rehearse-skipped-no-tmux"; finish; exit 0; fi
assert_eq "rehearse-go-reaches-promote" "0" "$rc"
assert_contains "rehearse-go-marker" "REHEARSE-GO" "$out"

out=$("$RH" nogo 2>&1); rc=$?
assert_eq "rehearse-nogo-gate-holds" "0" "$rc"
assert_contains "rehearse-nogo-marker" "REHEARSE-NOGO" "$out"
finish
