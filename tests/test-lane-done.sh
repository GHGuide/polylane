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

# a DONE line with NO trailing newline IS detected — markers.sh `done` emits no
# newline, so read (|| true) must still see the fully-populated first line.
printf 'STATUS: alpha DONE' > "$TEST_TMPDIR/docs/status-alpha.md"
assert_ok "done-no-trailing-newline-detected" lane_done "$TEST_TMPDIR" alpha
# empty file is still NOT done (first="" != DONE line)
: > "$TEST_TMPDIR/docs/status-alpha.md"
assert_fail "done-empty-file-not-done" lane_done "$TEST_TMPDIR" alpha

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

# Contract v2 must not observe a marker before the lane has committed its final
# source/evidence checkpoint. This prevents promotion from racing a live commit.
G="$TEST_TMPDIR/contract-v2"
mkdir -p "$G"
(
  cd "$G"
  git init -q -b main
  git config user.email test@example.com
  git config user.name test
  printf 'base\n' > base.txt
  git add base.txt
  git commit -qm base
  mkdir -p docs
)
ORCHESTRATION_CONTRACT=2
RUN_ID=run-2
printf 'STATUS: alpha DONE run=run-2\n' > "$G/docs/status-alpha.md"
assert_fail "done-v2-rejects-uncommitted-marker" lane_done "$G" alpha
(cd "$G" && git add docs/status-alpha.md && git commit -qm done)
assert_ok "done-v2-accepts-committed-clean-checkpoint" lane_done "$G" alpha
printf 'still writing evidence\n' > "$G/docs/verify-alpha.md"
assert_fail "done-v2-rejects-dirty-checkpoint" lane_done "$G" alpha
(cd "$G" && git add docs/verify-alpha.md && git commit -qm evidence)
assert_ok "done-v2-accepts-final-clean-checkpoint" lane_done "$G" alpha

# A current, committed READY handoff completes only the integrator's local turn;
# it does not self-authorize GO. This breaks the circular wait where a prompt
# defers STATUS:DONE until the host gate, while the host gate waits for DONE.
INT_NAME=integrator
printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=run-2\n' > "$G/docs/verify-integration.md"
assert_fail "done-v2-ready-rejects-uncommitted-evidence" lane_done "$G" integrator
(cd "$G" && git add docs/verify-integration.md && git commit -qm ready)
assert_ok "done-v2-ready-accepts-committed-integrator-handoff" lane_done "$G" integrator
printf 'POLYLANE-VERDICT: NO-GO run=run-2\n' > "$G/docs/verify-integration.md"
(cd "$G" && git add docs/verify-integration.md && git commit -qm no-go)
assert_fail "done-v2-ready-rejects-no-go" lane_done "$G" integrator
printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=stale-run\n' > "$G/docs/verify-integration.md"
(cd "$G" && git add docs/verify-integration.md && git commit -qm stale-ready)
assert_fail "done-v2-ready-rejects-stale-nonce" lane_done "$G" integrator
printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=run-2\n' > "$G/docs/verify-integration.md"
(cd "$G" && git add docs/verify-integration.md && git commit -qm current-ready)
assert_ok "done-v2-ready-restores-current-nonce" lane_done "$G" integrator

# The runner-created graph link is an untracked helper, not unfinished lane work.
# Any other untracked path remains a real dirty checkpoint and must still block DONE.
mkdir -p "$TEST_TMPDIR/runner-graph"
ln -s "$TEST_TMPDIR/runner-graph" "$G/graphify-out"
REPO_ROOT="$G" ORCHESTRATION_CONTRACT=2 RUN_ID=run-2
assert_ok "done-v2-ignores-owned-graphify-symlink" lane_done "$G" alpha
printf 'authoritative prompt\n' > "$TEST_TMPDIR/authoritative-prompt.txt"
cp "$TEST_TMPDIR/authoritative-prompt.txt" "$G/.polylane-prompt.txt"
LANE_NAMES=(alpha)
LANE_PROMPTS=("$TEST_TMPDIR/authoritative-prompt.txt")
assert_ok "done-v2-ignores-identical-runtime-prompt" lane_done "$G" alpha
printf 'tampered\n' > "$G/.polylane-prompt.txt"
assert_fail "done-v2-rejects-mutated-runtime-prompt" lane_done "$G" alpha
cp "$TEST_TMPDIR/authoritative-prompt.txt" "$G/.polylane-prompt.txt"
printf 'untracked\n' > "$G/real-untracked.txt"
assert_fail "done-v2-other-untracked-still-blocks" lane_done "$G" alpha
rm -f "$G/real-untracked.txt" "$G/graphify-out" "$G/.polylane-prompt.txt"

finish
