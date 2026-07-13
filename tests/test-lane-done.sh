#!/usr/bin/env bash
# lane_done WORKTREE NAME -> 0 iff first line of <wt>/docs/status-<name>.md
# is exactly "STATUS: <name> DONE" (frozen DONE contract).

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

assert_ok   "done-valid"        lane_done "$FIXTURES/lane-done/valid" alpha
assert_fail "done-wrong-name"   lane_done "$FIXTURES/lane-done/wrong-name" alpha
assert_fail "done-missing-file" lane_done "$FIXTURES/lane-done/does-not-exist" alpha
assert_fail "done-empty-file"   lane_done "$FIXTURES/lane-done/empty" alpha

# only the FIRST line counts — DONE buried on line 2 is not DONE
make_tmpdir
mkdir -p "$TEST_TMPDIR/docs"
printf 'still working\nSTATUS: alpha DONE\n' > "$TEST_TMPDIR/docs/status-alpha.md"
assert_fail "done-not-first-line" lane_done "$TEST_TMPDIR" alpha

# exact match — leading whitespace / trailing text breaks it
printf ' STATUS: alpha DONE\n' > "$TEST_TMPDIR/docs/status-alpha.md"
assert_fail "done-leading-space" lane_done "$TEST_TMPDIR" alpha
printf 'STATUS: alpha DONE (almost)\n' > "$TEST_TMPDIR/docs/status-alpha.md"
assert_fail "done-trailing-text" lane_done "$TEST_TMPDIR" alpha

# current behavior: a DONE line with NO trailing newline is NOT detected
# (`read -r` hits EOF -> rc 1 -> lane_done returns 1). Pinned as-is; flagged
# to the engine lane in docs/parallel-status.md.
printf 'STATUS: alpha DONE' > "$TEST_TMPDIR/docs/status-alpha.md"
assert_fail "done-no-trailing-newline-not-done" lane_done "$TEST_TMPDIR" alpha

# --- per-run nonce (allowlist trust) ---------------------------------------
RUN_ID="99-7"
printf 'STATUS: alpha DONE run=99-7\n' > "$TEST_TMPDIR/docs/status-alpha.md"
assert_ok   "done-nonce-match"      lane_done "$TEST_TMPDIR" alpha
printf 'STATUS: alpha DONE run=11-2\n' > "$TEST_TMPDIR/docs/status-alpha.md"
assert_fail "done-nonce-stale"      lane_done "$TEST_TMPDIR" alpha
printf 'STATUS: alpha DONE\n' > "$TEST_TMPDIR/docs/status-alpha.md"
assert_fail "done-nonceless-in-nonce-mode" lane_done "$TEST_TMPDIR" alpha
unset RUN_ID   # legacy path still exact-matches (guards backward compat)
assert_ok   "done-legacy-when-no-nonce" lane_done "$TEST_TMPDIR" alpha

finish
