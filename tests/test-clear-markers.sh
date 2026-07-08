#!/usr/bin/env bash
# Regression: a fresh worktree that inherits a BASE-committed status marker must
# NOT be seen as already-DONE. clear_stale_markers removes the inherited marker so
# the poll waits for a marker THIS run writes. (Real-run bug: a committed
# docs/status-integrator.md made a fresh integrator poll return DONE in 0s.)

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
wt="$TEST_TMPDIR/wt"; mkdir -p "$wt/docs"

# a stale committed marker looks exactly like a real DONE
printf 'STATUS: integrator DONE\n' > "$wt/docs/status-integrator.md"
assert_ok   "stale-marker-looks-done" lane_done "$wt" integrator

# clearing it removes the poison
DRY_RUN=0 clear_stale_markers "$wt" integrator
assert_fail "cleared-marker-not-done" lane_done "$wt" integrator

# dry-run must NOT delete (preview only)
printf 'STATUS: integrator DONE\n' > "$wt/docs/status-integrator.md"
DRY_RUN=1 clear_stale_markers "$wt" integrator >/dev/null 2>&1
assert_ok   "dry-run-keeps-marker" lane_done "$wt" integrator

# clearing one lane leaves another lane's marker intact
printf 'STATUS: a DONE\n' > "$wt/docs/status-a.md"
printf 'STATUS: b DONE\n' > "$wt/docs/status-b.md"
DRY_RUN=0 clear_stale_markers "$wt" a
assert_fail "cleared-a" lane_done "$wt" a
assert_ok   "kept-b"    lane_done "$wt" b

finish
