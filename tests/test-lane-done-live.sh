#!/usr/bin/env bash
# A committed contract-v2 handoff remains working while its nonce-bound worker lives.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
WT="$TEST_TMPDIR/wt"
mkdir -p "$WT/docs"
git -C "$WT" init -q -b main
git -C "$WT" config user.email test@example.invalid
git -C "$WT" config user.name test
printf 'base\n' > "$WT/base"
git -C "$WT" add base && git -C "$WT" commit -qm base
printf 'STATUS: builder DONE run=live-run\n' > "$WT/docs/status-builder.md"
git -C "$WT" add docs/status-builder.md && git -C "$WT" commit -qm done

ORCHESTRATION_CONTRACT=2
RUN_ID=live-run
BASE=$(git -C "$WT" rev-list --max-parents=0 HEAD)
MANIFEST="$TEST_TMPDIR/run.json"
cat > "$MANIFEST" <<'JSON'
{"base":"main","write_plan_contract":1,"lanes":[{"name":"builder","own_globs":["docs/status-builder.md"],"planned_writes":["docs/status-builder.md"]}]}
JSON
LANE_NAMES=(builder)
LANE_PANE_IDX=(4)
INT_NAME=integrator
pane_for_worktree() { [ "$1" = "$WT" ] && printf '4'; }
LIVE=1
pane_agent_live() { [ "$LIVE" = 1 ]; }

assert_fail "done-v2-rejects-committed-marker-while-mapped-agent-live" lane_done "$WT" builder
LIVE=0
assert_ok "done-v2-accepts-same-marker-after-agent-exit" lane_done "$WT" builder
pane_for_worktree() { return 1; }
LIVE=1
assert_ok "done-v2-unmapped-fixture-remains-pure" lane_done "$WT" builder

# Completion grades the committed builder diff against the manifest, not only
# the prelaunch static scope promise.
printf 'escaped\n' > "$WT/outside.txt"
git -C "$WT" add outside.txt && git -C "$WT" commit -qm out-of-scope
assert_fail "done-v2-rejects-committed-out-of-scope-path" lane_done "$WT" builder
git -C "$WT" rm -q outside.txt && git -C "$WT" commit -qm remove-out-of-scope
assert_ok "done-v2-accepts-scope-clean-net-diff" lane_done "$WT" builder
SAVED_MANIFEST=$MANIFEST
MANIFEST="$TEST_TMPDIR/missing-manifest.json"
assert_fail "done-v2-scope-gate-fails-closed-without-manifest" lane_done "$WT" builder
MANIFEST=$SAVED_MANIFEST

# READY follows the same liveness gate for the nonce-bound integrator pane.
printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=live-run\n' > "$WT/docs/verify-integration.md"
git -C "$WT" add docs/verify-integration.md && git -C "$WT" commit -qm ready
LANE_NAMES=()
INT_NAME=integrator
INT_PANE_IDX=8
pane_for_worktree() { [ "$1" = "$WT" ] && printf '8'; }
LIVE=1
assert_fail "ready-v2-rejects-committed-handoff-while-integrator-live" lane_done "$WT" integrator
LIVE=0
assert_ok "ready-v2-accepts-same-handoff-after-agent-exit" lane_done "$WT" integrator

# Runtime injection supplies one ordered finalization protocol without changing
# the source's exact-once scalar contracts; both launch gates accept the result.
SOURCE="$TEST_TMPDIR/source.prompt"
RUNTIME="$TEST_TMPDIR/runtime.prompt"
cat > "$SOURCE" <<'EOF'
ULTIMATE-GOAL: ship safely.
CURRENT-SUBGOAL: prove finality.
GOAL: finish builder.
OWN: runtime files.
FORBIDDEN: unrelated files.
PREDEFINED-SKILLS: engineering:debug
LANE-SPECIFIC-SKILLS: engineering:debug
Read only the named kit once.
TEST-CADENCE: focused first.
DELEGATION: forbidden.
CHECK-CACHE: use $PWD/.polylane/check-cache/builder.
EXTERNAL-EVIDENCE: none.
VERIFY: verify then STATUS: builder DONE run=live-run.
PLANNED-WRITES: stale/outside.md. This authored boundary must be replaced.
EOF
inject_runtime_prompt_contract "$SOURCE" builder "$RUNTIME"
assert_eq "runtime-finalize-injected-once" "1" "$(grep -c '^POLYLANE-RUNTIME-FINALIZE:' "$RUNTIME" || true)"
assert_eq "runtime-write-plan-boundary-injected-once" "1" "$(grep -c '^PLANNED-WRITES:' "$RUNTIME" || true)"
assert_contains "runtime-write-plan-boundary-is-current-lane" "docs/status-builder.md" "$(grep '^PLANNED-WRITES:' "$RUNTIME")"
assert_eq "runtime-write-plan-boundary-replaces-authored-stale-value" "0" \
  "$(grep -cF 'stale/outside.md' "$RUNTIME" || true)"
assert_ok "runtime-finalize-promptopt-strict" "$SCRIPT_DIR/../bin/polylane-promptopt.sh" check "$RUNTIME"
assert_ok "runtime-finalize-promptlint-strict" \
  env POLYLANE_STRICT_PROMPTS=1 POLYLANE_RUNTIME_COMPILED=1 \
  "$SCRIPT_DIR/../bin/polylane-promptlint.sh" lint "$RUNTIME" builder false builder

# Recovery addenda preserve, rather than append, the strict scalar contracts.
REPAIR="$TEST_TMPDIR/repair.prompt"
build_repair_prompt "$SOURCE" builder 2 > "$REPAIR"
assert_ok "runtime-repair-preserves-strict-scalars" \
  "$SCRIPT_DIR/../bin/polylane-promptopt.sh" check "$REPAIR"

finish
