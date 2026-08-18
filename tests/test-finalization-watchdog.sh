#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034
# Executable v3 finalization and durable watchdog regression contract.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

FINALIZER="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-finalize.sh"
assert_ok "finalize-helper-executable" test -x "$FINALIZER"
command -v jq >/dev/null 2>&1 || { pass "finalization-skipped-no-jq"; finish; exit 0; }

make_tmpdir
PROJECT="$TEST_TMPDIR/project"; WT="$PROJECT/wt"
mkdir -p "$WT/docs" "$PROJECT/.polylane"
git -C "$WT" init -q -b main
git -C "$WT" config user.email test@example.invalid
git -C "$WT" config user.name test
printf 'base\n' > "$WT/base"
git -C "$WT" add base && git -C "$WT" commit -qm base
printf 'implementation evidence run=v3-run\n' > "$WT/docs/verify-builder.md"
git -C "$WT" add docs/verify-builder.md && git -C "$WT" commit -qm implementation

assert_ok "finalize-builder-commits-handoff" "$FINALIZER" \
  --project-root "$PROJECT" --worktree "$WT" --lane builder --run-id v3-run --role builder
STATE="$PROJECT/.polylane/finalization/v3-run/builder.json"
assert_eq "finalize-builder-handoff-committed" HANDOFF_COMMITTED "$(jq -r .state "$STATE")"
assert_eq "finalize-builder-head-bound" "$(git -C "$WT" rev-parse HEAD)" "$(jq -r .handoff_head "$STATE")"
assert_eq "finalize-builder-exact-marker" 'STATUS: builder DONE run=v3-run' \
  "$(git -C "$WT" show HEAD:docs/status-builder.md)"
assert_eq "finalize-builder-clean" "" "$(git -C "$WT" status --porcelain)"

# A crash between prepare and commit stays HANDOFF_PENDING. Runner recovery may
# not checkpoint, delete, normalize, append, or recommit those partial bytes.
printf 'more evidence run=v3-partial\n' > "$WT/docs/verify-partial.md"
git -C "$WT" add docs/verify-partial.md && git -C "$WT" commit -qm partial-implementation
POLYLANE_FINALIZE_INTERRUPT=after-marker "$FINALIZER" \
  --project-root "$PROJECT" --worktree "$WT" --lane partial --run-id v3-partial --role builder \
  >/dev/null 2>&1
partial_rc=$?
assert_eq "finalize-partial-interrupts" 75 "$partial_rc"
PARTIAL_STATE="$PROJECT/.polylane/finalization/v3-partial/partial.json"
assert_eq "finalize-partial-state-pending" HANDOFF_PENDING "$(jq -r .state "$PARTIAL_STATE")"
PARTIAL_HEAD=$(git -C "$WT" rev-parse HEAD)
PARTIAL_BYTES=$(cksum "$WT/docs/status-partial.md")
PROJECT_ROOT="$PROJECT" RUN_ID=v3-partial ORCHESTRATION_CONTRACT=3
assert_fail "checkpoint-refuses-partial-handoff" checkpoint_lane "$WT" partial
assert_eq "checkpoint-partial-preserves-head" "$PARTIAL_HEAD" "$(git -C "$WT" rev-parse HEAD)"
assert_eq "checkpoint-partial-preserves-bytes" "$PARTIAL_BYTES" "$(cksum "$WT/docs/status-partial.md")"

# The worker-owned helper itself may recover its pending transaction.
assert_ok "finalize-worker-recovers-pending" "$FINALIZER" \
  --project-root "$PROJECT" --worktree "$WT" --lane partial --run-id v3-partial --role builder
assert_eq "finalize-recovery-committed" HANDOFF_COMMITTED "$(jq -r .state "$PARTIAL_STATE")"

# Role is explicit: an integrator may have any safe lane name. Its exact final
# verdict line, status marker, HEAD, and clean tree form one authoritative handoff.
printf 'integration evidence run=v3-int\n' > "$WT/docs/verify-integration.md"
git -C "$WT" add docs/verify-integration.md && git -C "$WT" commit -qm integration-evidence
assert_ok "finalize-explicit-integrator-role" "$FINALIZER" \
  --project-root "$PROJECT" --worktree "$WT" --lane verifier-x --run-id v3-int \
  --role integrator --verdict READY-FOR-HOST-GATE
ORCHESTRATION_CONTRACT=3; RUN_ID=v3-int; INT_NAME=verifier-x; INT_ROLE=integrator
MANIFEST="$PROJECT/.polylane/run.json"; BASE=$(git -C "$WT" rev-list --max-parents=0 HEAD)
printf '%s\n' '{"orchestration_contract":3,"integrator":{"name":"verifier-x","role":"integrator"},"lanes":[]}' > "$MANIFEST"
pane_index_for() { return 1; }
assert_ok "done-v3-authoritative-integrator-handoff" lane_done "$WT" verifier-x
printf 'tamper\n' >> "$WT/docs/verify-integration.md"
assert_fail "done-v3-rejects-dirty-verdict" lane_done "$WT" verifier-x
git -C "$WT" restore docs/verify-integration.md

# Pane paint can churn forever; only a durable transition resets elapsed time.
PROJECT_ROOT="$PROJECT" RUN_ID=watch-run ORCHESTRATION_CONTRACT=3
LANE_NAMES=(watch); LANE_WORKTREES=("$WT"); LANE_PANE_IDX=(4)
pane_agent_live() { return 1; }
lane_terminal_or_idle() { return 1; }
lane_active_command() { return 1; }
POLYLANE_WEDGE_SECONDS=10
POLYLANE_NOW_EPOCH=100 pane_wedged watch 4 >/dev/null 2>&1 || true
POLYLANE_NOW_EPOCH=105 pane_wedged watch 4 >/dev/null 2>&1
assert_eq "watchdog-durable-elapsed-not-yet-expired" 1 "$?"
POLYLANE_NOW_EPOCH=111 pane_wedged watch 4 >/dev/null 2>&1
assert_eq "watchdog-changing-pane-cannot-prevent-timeout" 0 "$?"

finish
