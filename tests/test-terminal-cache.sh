#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034 # sourced runner consumes fixture globals
# A terminal PASS may be reused only for the exact run, integration commit,
# frozen acceptance, toolchain, platform, and exported environment.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

command -v jq >/dev/null 2>&1 || { pass "terminal-cache-skipped-no-jq"; finish; exit 0; }
command -v git >/dev/null 2>&1 || { pass "terminal-cache-skipped-no-git"; finish; exit 0; }

make_tmpdir
PROJECT_ROOT="$TEST_TMPDIR/project"
INT_WORKTREE="$TEST_TMPDIR/integrator"
STATE_FILE="$PROJECT_ROOT/docs/polylane/max-state.json"
MANIFEST="$PROJECT_ROOT/.polylane/run.json"
MEM="$(dirname "$RUNNER")/polylane-memory.sh"
mkdir -p "$PROJECT_ROOT/.polylane" "$PROJECT_ROOT/docs/polylane" "$INT_WORKTREE"

git -C "$INT_WORKTREE" init -q
git -C "$INT_WORKTREE" config user.email test@example.com
git -C "$INT_WORKTREE" config user.name Test
printf 'v1\n' > "$INT_WORKTREE/product.txt"
git -C "$INT_WORKTREE" add product.txt
git -C "$INT_WORKTREE" commit -qm initial

"$MEM" "$STATE_FILE" init goal >/dev/null
"$MEM" "$STATE_FILE" add-milestone m1 build >/dev/null
"$MEM" "$STATE_FILE" add-subgoal m1 s1 target 10 >/dev/null
"$MEM" "$STATE_FILE" add-accept s1 true --tier terminal >/dev/null
(cd "$INT_WORKTREE" && "$MEM" "$STATE_FILE" check-accept --targets s1 --only-terminal >/dev/null)

TOOL_DIR="$TEST_TMPDIR/tools"
mkdir -p "$TOOL_DIR"
printf '#!/bin/sh\nexit 0\n' > "$TOOL_DIR/fixture-tool"
chmod +x "$TOOL_DIR/fixture-tool"
PATH="$TOOL_DIR:$PATH"; export PATH
printf '%s\n' '{"target_subgoals":["s1"],"terminal_cache_tools":["fixture-tool"]}' > "$MANIFEST"

RUN_ID=cache-run
CYCLE=1
ORCHESTRATION_CONTRACT=2
POLYLANE_TERMINAL_INPUT=one; export POLYLANE_TERMINAL_INPUT

fp1=$(terminal_gate_fingerprint GO)
fp1_repeat=$(terminal_gate_fingerprint GO)
assert_eq "terminal-cache-fingerprint-stable" "$fp1" "$fp1_repeat"
assert_fail "terminal-cache-missing-receipt-is-miss" terminal_gate_pass_receipt_valid GO
assert_ok "terminal-cache-records-pass" terminal_gate_pass_receipt_record GO
assert_ok "terminal-cache-exact-pass-hits" terminal_gate_pass_receipt_valid GO

RECEIPT=$(terminal_gate_receipt_path)
assert_ok "terminal-cache-receipt-is-runner-owned" runner_owned_promotion_path "docs/polylane/terminal-gates/cache-run.json"
assert_fail "terminal-cache-arbitrary-json-is-not-runner-owned" runner_owned_promotion_path "docs/polylane/terminal-gates/arbitrary/other.json"
assert_ok "terminal-cache-receipt-json" jq -e '.version == 1 and .status == "pass" and .run_id == "cache-run"' "$RECEIPT"
assert_eq "terminal-cache-receipt-commit" "$(git -C "$INT_WORKTREE" rev-parse HEAD)" "$(jq -r '.integrator_commit' "$RECEIPT")"

jq '(.accept[] | select(.sid == "s1")).cmd = "false"' "$STATE_FILE" > "$STATE_FILE.tmp"
mv "$STATE_FILE.tmp" "$STATE_FILE"
fp_command=$(terminal_gate_fingerprint GO)
assert_fail "terminal-cache-command-change-invalidates-fingerprint" test "$fp1" = "$fp_command"
assert_fail "terminal-cache-command-change-is-miss" terminal_gate_pass_receipt_valid GO
jq '(.accept[] | select(.sid == "s1")).cmd = "true"' "$STATE_FILE" > "$STATE_FILE.tmp"
mv "$STATE_FILE.tmp" "$STATE_FILE"

printf 'v2\n' > "$INT_WORKTREE/product.txt"
git -C "$INT_WORKTREE" commit -qam source-change
fp_source=$(terminal_gate_fingerprint GO)
assert_fail "terminal-cache-source-commit-invalidates-fingerprint" test "$fp1" = "$fp_source"

printf '#!/bin/sh\n# changed tool\nexit 0\n' > "$TOOL_DIR/fixture-tool"
fp_tool=$(terminal_gate_fingerprint GO)
assert_fail "terminal-cache-tool-change-invalidates-fingerprint" test "$fp_source" = "$fp_tool"

POLYLANE_TERMINAL_INPUT=two; export POLYLANE_TERMINAL_INPUT
fp_env=$(terminal_gate_fingerprint GO)
assert_fail "terminal-cache-environment-change-invalidates-fingerprint" test "$fp_tool" = "$fp_env"

jq '.status = "fail"' "$RECEIPT" > "$RECEIPT.tmp"
mv "$RECEIPT.tmp" "$RECEIPT"
assert_fail "terminal-cache-never-reuses-nonpass" terminal_gate_pass_receipt_valid GO

finish
