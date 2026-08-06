#!/usr/bin/env bash
# A vanished owned session is a recoverable runner exit, not an endless poll.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
mkdir -p "$TEST_TMPDIR/wt/docs"
TMUX_SESSION="lost-session-$$"
SESSION_STARTED=1
RUN_ID=survival-run
ORCHESTRATION_CONTRACT=2
tmux() { return 1; }

lost_out=$(poll_done "builder:$TEST_TMPDIR/wt" 2>&1); lost_rc=$?
assert_eq "runtime-session-loss-distinct-recoverable-status" "75" "$lost_rc"
assert_contains "runtime-session-loss-actionable" "SESSION-LOST:" "$lost_out"

finish
