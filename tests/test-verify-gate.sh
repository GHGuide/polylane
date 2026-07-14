#!/usr/bin/env bash
# assets/verify-gate.sh — Stop hook: block a lane that claims DONE without its
# verify evidence file. Deterministic verification-before-completion.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
GATE="$(cd "$(dirname "$RUNNER")" && pwd)/../assets/verify-gate.sh"

make_tmpdir
mkdir -p "$TEST_TMPDIR/docs"
run_gate() { CLAUDE_PROJECT_DIR="$TEST_TMPDIR" bash "$GATE" <<<'{}'; }

# no status file at all -> allow (nothing claimed)
assert_ok "gate-allows-when-no-status" run_gate

# status DONE but NO verify -> BLOCK (exit 2)
printf 'STATUS: alpha DONE run=r1\n' > "$TEST_TMPDIR/docs/status-alpha.md"
assert_rc "gate-blocks-done-without-verify" 2 env CLAUDE_PROJECT_DIR="$TEST_TMPDIR" bash "$GATE" </dev/null

# add the verify evidence -> allow
printf 'built alpha; tests green\n' > "$TEST_TMPDIR/docs/verify-alpha.md"
assert_ok "gate-allows-with-verify" run_gate

# stop_hook_active -> never hard-loop, allow even if verify missing
rm -f "$TEST_TMPDIR/docs/verify-alpha.md"
assert_ok "gate-no-loop-when-active" sh -c "CLAUDE_PROJECT_DIR='$TEST_TMPDIR' bash '$GATE' <<<'{\"stop_hook_active\":true}'"

# B11: integrator's evidence is verify-integration.md (not verify-integrator.md)
rm -f "$TEST_TMPDIR/docs/"status-* "$TEST_TMPDIR/docs/"verify-*
printf 'STATUS: integrator DONE run=r1\n' > "$TEST_TMPDIR/docs/status-integrator.md"
assert_rc "gate-blocks-integrator-no-verify" 2 env CLAUDE_PROJECT_DIR="$TEST_TMPDIR" bash "$GATE" </dev/null
printf 'evidence\n' > "$TEST_TMPDIR/docs/verify-integration.md"
assert_ok "gate-allows-integrator-with-integration-md" run_gate

finish
