#!/usr/bin/env bash
# A NO-GO/UNKNOWN integration verdict is repaired in-process; it is not reported
# as a cycle boundary until the autonomous repair budget is actually exhausted.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

# This unit exercises verdict-repair control flow, not the profile bundle
# grader. Keep the newly-added pre-verdict gate hermetic so ambient project
# manifests/evidence cannot short-circuit the mocked merge gate below, while
# counting calls so the production repair loop cannot silently bypass it.
DOMAIN_GRADE_CALLS=0
domain_grade_gate() { DOMAIN_GRADE_CALLS=$((DOMAIN_GRADE_CALLS + 1)); return 0; }

make_tmpdir
LOG="$TEST_TMPDIR/calls"
: > "$LOG"
MERGES=0

# Integration repairs run in a scratch worktree, while pipe-pane writes the
# transcript under the canonical orchestration checkout. The generated prompt
# must carry that absolute path or the replacement agent re-derives from zero.
REPO_ROOT="$TEST_TMPDIR/canonical root"
INT_NAME="integration"
seed="$TEST_TMPDIR/seed.txt"
printf 'ORIGINAL INTEGRATION GOAL' > "$seed"
repair_prompt=$(build_integrator_repair_prompt "$seed" 1 "NO-GO" "docs/attempt.md")
assert_contains "gate-repair-keeps-original" \
  "ORIGINAL INTEGRATION GOAL" "$repair_prompt"
assert_contains "gate-repair-points-canonical-transcript" \
  "$REPO_ROOT/docs/lane-logs/integration.log" "$repair_prompt"

merge_gate() {
  MERGES=$((MERGES + 1))
  if [ "$MERGES" -lt 3 ]; then VERDICT_RESULT="NO-GO"; return 1; fi
  VERDICT_RESULT="GO"; return 0
}
repair_integrator_verdict() { printf 'repair\n' >> "$LOG"; }
poll_done() { printf 'poll\n' >> "$LOG"; return 0; }
capture_stats() { printf 'capture\n' >> "$LOG"; }

POLYLANE_INTEGRATOR_REPAIRS=3
gate_with_repairs; repair_eventually_go_rc=$?
assert_eq "repair-eventually-go" "0" "$repair_eventually_go_rc"
assert_eq "repair-calls-domain-grader-before-each-merge" "3" "$DOMAIN_GRADE_CALLS"
assert_eq "repair-two-waves" "2" "$(grep -c '^repair$' "$LOG")"
assert_eq "repair-polls-each-wave" "2" "$(grep -c '^poll$' "$LOG")"
assert_eq "repair-captures-each-wave" "2" "$(grep -c '^capture$' "$LOG")"

: > "$LOG"
MERGES=0
merge_gate() { MERGES=$((MERGES + 1)); VERDICT_RESULT="NO-GO"; return 1; }
POLYLANE_INTEGRATOR_REPAIRS=2
assert_fail "repair-exhaustion-fails" gate_with_repairs
assert_eq "repair-cap-exact" "2" "$(grep -c '^repair$' "$LOG")"

# The shared zero-repair policy must also stop integrator repair waves unless a
# dedicated override was explicitly supplied.
: > "$LOG"
MERGES=0
unset POLYLANE_INTEGRATOR_REPAIRS VERDICT_REPAIRABLE
POLYLANE_MAX_REPAIRS=0
assert_fail "repair-shared-zero-stops-integrator-wave" gate_with_repairs
assert_eq "repair-shared-zero-spawns-none" "0" "$(grep -c '^repair$' "$LOG")"

: > "$LOG"
MERGES=0
POLYLANE_INTEGRATOR_REPAIRS=1
assert_fail "repair-explicit-integrator-override-still-applies" gate_with_repairs
assert_eq "repair-explicit-integrator-override-wins" "1" "$(grep -c '^repair$' "$LOG")"
unset POLYLANE_MAX_REPAIRS

: > "$LOG"
MERGES=0
merge_gate() {
  MERGES=$((MERGES + 1))
  VERDICT_RESULT="NO-GO"
  VERDICT_REPAIRABLE="NO"
  return 1
}
POLYLANE_INTEGRATOR_REPAIRS=3
gate_with_repairs >/dev/null 2>&1
unrepairable_rc=$?
assert_eq "unrepairable-host-gate-stops" "1" "$unrepairable_rc"
assert_eq "unrepairable-gate-read-once" "1" "$MERGES"
assert_eq "unrepairable-spawns-zero-repairs" "0" "$(wc -l < "$LOG" | tr -d ' ')"

# Failed strict admission is a transaction boundary.  A replacement prompt must
# be admitted before checkpointing, removing current-run evidence, changing the
# live prompt/runtime settings, respawning a pane, or recording a restart.
. "$RUNNER"
make_tmpdir
REPO_ROOT="$TEST_TMPDIR/root"; INT_WORKTREE="$TEST_TMPDIR/int"; INT_NAME=integrator
mkdir -p "$REPO_ROOT/.polylane/lanes" "$INT_WORKTREE/docs"
git -C "$INT_WORKTREE" init -q -b main
git -C "$INT_WORKTREE" config user.email test@example.invalid
git -C "$INT_WORKTREE" config user.name test
printf 'status bytes\n' > "$INT_WORKTREE/docs/status-integrator.md"
printf 'POLYLANE-VERDICT: NO-GO run=transaction-run\n' > "$INT_WORKTREE/docs/verify-integration.md"
git -C "$INT_WORKTREE" add docs && git -C "$INT_WORKTREE" commit -qm evidence
INT_PROMPT="$TEST_TMPDIR/strict-integrator.md"
cat > "$INT_PROMPT" <<'EOF'
ULTIMATE-GOAL: transactional repair.
CURRENT-SUBGOAL: preserve failed handoff.
GOAL: admit strict replacement before mutation.
OWN: bin/polylane-run.sh.
FORBIDDEN: weakening checks.
PREDEFINED-SKILLS: none.
LANE-SPECIFIC-SKILLS: none.
Read only the named kit once.
TEST-CADENCE: focused.
DELEGATION: forbidden.
CHECK-CACHE: use cache.
EXTERNAL-EVIDENCE: none.
VERIFY: STATUS: transaction DONE run=transaction-run.
EOF
ORCHESTRATION_CONTRACT=2; DRY_RUN=0; RUN_ID=transaction-run; VERDICT_RESULT=NO-GO
INT_PANE_IDX=7
TX_LOG="$TEST_TMPDIR/transaction.log"
checkpoint_lane() { printf 'checkpoint\n' >> "$TX_LOG"; git -C "$1" commit --allow-empty -qm checkpoint; }
refresh_manifest_runtime_settings() { printf 'refresh\n' >> "$TX_LOG"; }
retry_set() { printf 'retry\n' >> "$TX_LOG"; }
wedge_hash_set() { :; }; wedge_cnt_set() { :; }; pane_cmd_for() { printf command; }
repipe_pane_log() { printf 'repipe\n' >> "$TX_LOG"; }; notify_event() { :; }
RESTART_EVENTS=0
run_stats() { RESTART_EVENTS=$((RESTART_EVENTS + 1)); printf 'restart\n' >> "$TX_LOG"; }
run() { printf 'pane\n' >> "$TX_LOG"; return 0; }
# Simulate strict promptopt rejection after construction, before committing any
# recovery mutation.  This is intentionally a direct admission failure, not a
# malformed source fixture that would obscure transaction ordering.
assert_prompt() { return 1; }
HEAD_BEFORE=$(git -C "$INT_WORKTREE" rev-parse HEAD)
STATUS_BEFORE=$(cksum "$INT_WORKTREE/docs/status-integrator.md")
VERDICT_BEFORE=$(cksum "$INT_WORKTREE/docs/verify-integration.md")
PROMPT_BEFORE=$INT_PROMPT
PANE_BEFORE=$INT_PANE_IDX
repair_integrator_verdict 1 >/dev/null 2>&1
transaction_rc=$?
assert_eq "repair-admission-failure-returns-nonzero" "1" "$transaction_rc"
assert_eq "repair-admission-failure-preserves-head" "$HEAD_BEFORE" "$(git -C "$INT_WORKTREE" rev-parse HEAD)"
assert_eq "repair-admission-failure-preserves-status-bytes" "$STATUS_BEFORE" "$(cksum "$INT_WORKTREE/docs/status-integrator.md")"
assert_eq "repair-admission-failure-preserves-verdict-bytes" "$VERDICT_BEFORE" "$(cksum "$INT_WORKTREE/docs/verify-integration.md")"
assert_eq "repair-admission-failure-preserves-prompt-selection" "$PROMPT_BEFORE" "$INT_PROMPT"
assert_eq "repair-admission-failure-preserves-pane-identity" "$PANE_BEFORE" "$INT_PANE_IDX"
assert_eq "repair-admission-failure-performs-no-pane-action" "" "$(cat "$TX_LOG" 2>/dev/null || true)"
assert_eq "repair-admission-failure-preserves-restart-telemetry" "0" "$RESTART_EVENTS"

# READY-FOR-HOST-GATE is a nonce-bound candidate, not a self-authorized GO.
# The outer merge gate runs the frozen coordinator checks once, then converts
# only a passing result to GO. A failed terminal gate is immutable for this run:
# retrying it would exceed the one-gate efficiency contract.
. "$RUNNER"
DOMAIN_GRADE_CALLS=0
domain_grade_gate() { DOMAIN_GRADE_CALLS=$((DOMAIN_GRADE_CALLS + 1)); return 0; }
make_tmpdir
INT_WORKTREE="$TEST_TMPDIR/int"; mkdir -p "$INT_WORKTREE/docs"
MANIFEST="$TEST_TMPDIR/manifest.json"
printf '%s\n' '{"lanes":[]}' > "$MANIFEST"
RUN_ID=host-gate-run
printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=host-gate-run\n' > "$INT_WORKTREE/docs/verify-integration.md"
HOST_GATES=0
EFFICIENCY_PROOFS=0
TERMINAL_EVENTS=0
contract_focused_acceptance_gate() { return 0; }
contract_ready_verdict() { printf 'GO'; }
contract_terminal_eligible() { return 0; }
run_stats() {
  [ "${1:-}" != terminal-gate ] || TERMINAL_EVENTS=$((TERMINAL_EVENTS + 1))
  return 0
}
write_efficiency_proof() {
  EFFICIENCY_PROOFS=$((EFFICIENCY_PROOFS + 1))
  [ "$TERMINAL_EVENTS" = 1 ]
}
contract_acceptance_gate() {
  HOST_GATES=$((HOST_GATES + 1))
  [ "${2:-0}" = 1 ]
}
merge_gate; host_rc=$?
assert_eq "ready-host-gate-passes" "0" "$host_rc"
assert_eq "ready-host-gate-runs-once" "1" "$HOST_GATES"
assert_eq "ready-efficiency-proof-runs-once" "1" "$EFFICIENCY_PROOFS"
assert_eq "ready-terminal-gate-counted-before-proof" "1" "$TERMINAL_EVENTS"
assert_eq "ready-host-gate-converts-to-go" "GO" "$VERDICT_RESULT"

printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=host-gate-run\n' > "$INT_WORKTREE/docs/verify-integration.md"
HOST_GATES=0
EFFICIENCY_PROOFS=0
TERMINAL_EVENTS=0
contract_ready_verdict() { printf 'EXTERNAL-EVIDENCE-OPEN'; }
contract_acceptance_gate() {
  HOST_GATES=$((HOST_GATES + 1))
  [ "${1:-}" = EXTERNAL-EVIDENCE-OPEN ] && [ "${2:-0}" = 1 ]
}
merge_gate; external_rc=$?
assert_eq "ready-host-gate-preserves-external-route" "0" "$external_rc"
assert_eq "ready-host-gate-external-runs-once" "1" "$HOST_GATES"
assert_eq "ready-host-gate-converts-to-external" "EXTERNAL-EVIDENCE-OPEN" "$VERDICT_RESULT"

# A READY handoff for a focused-only recovery target promotes after its focused
# proof without a terminal telemetry event, proof, or terminal acceptance call.
printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=host-gate-run\n' > "$INT_WORKTREE/docs/verify-integration.md"
HOST_GATES=0; EFFICIENCY_PROOFS=0; TERMINAL_EVENTS=0
contract_terminal_eligible() { return 1; }
contract_acceptance_gate() { HOST_GATES=$((HOST_GATES + 1)); return 0; }
merge_gate; focused_only_ready_rc=$?
assert_eq "ready-focused-only-promotes" "0" "$focused_only_ready_rc"
assert_eq "ready-focused-only-skips-terminal-count" "0" "$TERMINAL_EVENTS"
assert_eq "ready-focused-only-skips-proof" "0" "$EFFICIENCY_PROOFS"
assert_eq "ready-focused-only-runs-focused-host-completion" "1" "$HOST_GATES"
contract_terminal_eligible() { return 0; }
contract_ready_verdict() { printf 'GO'; }

printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=host-gate-run\n' > "$INT_WORKTREE/docs/verify-integration.md"
HOST_GATES=0
EFFICIENCY_PROOFS=0
TERMINAL_EVENTS=0
contract_acceptance_gate() { HOST_GATES=$((HOST_GATES + 1)); return 1; }
merge_gate >/dev/null 2>&1; host_fail_rc=$?
assert_eq "ready-host-gate-failure-is-not-go" "1" "$host_fail_rc"
assert_eq "ready-host-gate-failure-runs-once" "1" "$HOST_GATES"
assert_eq "ready-host-gate-failure-proves-once" "1" "$EFFICIENCY_PROOFS"
assert_eq "ready-host-gate-failure-stops-repair" "NO" "$VERDICT_REPAIRABLE"

# Host gate diagnostics belong to canonical host state, never the completed
# integrator checkout.  A committed current READY handoff must remain clean and
# continue to satisfy lane_done on resume after a terminal host failure.
HOST_ROOT="$TEST_TMPDIR/host-root"; HOST_INT="$HOST_ROOT/integrator"
mkdir -p "$HOST_INT/docs"; (
  cd "$HOST_INT"; git init -q -b main; git config user.email t@t; git config user.name t
  printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=host-gate-run\n' > docs/verify-integration.md
  git add docs/verify-integration.md; git commit -qm ready
)
REPO_ROOT="$HOST_ROOT"; INT_WORKTREE="$HOST_INT"; INT_NAME=integrator
ORCHESTRATION_CONTRACT=2
HOST_GATES=0; EFFICIENCY_PROOFS=0; TERMINAL_EVENTS=0
contract_focused_acceptance_gate() { return 0; }
contract_ready_verdict() { printf 'GO'; }
write_efficiency_proof() { return 0; }
contract_acceptance_gate() { HOST_GATES=$((HOST_GATES + 1)); return 1; }
merge_gate >/dev/null 2>&1; host_clean_rc=$?
assert_eq "host-failure-is-no-go" "1" "$host_clean_rc"
assert_eq "host-failure-keeps-integrator-clean" "" "$(git -C "$HOST_INT" status --porcelain)"
assert_ok "host-failure-ready-still-resumable" lane_done "$HOST_INT" integrator
assert_ok "host-failure-recorded-canonically" test -f "$HOST_ROOT/docs/polylane/host-gate-failures/host-gate-run.md"

HOST_GATES=0
EFFICIENCY_PROOFS=0
TERMINAL_EVENTS=0
contract_focused_acceptance_gate() { return 1; }
contract_acceptance_gate() { HOST_GATES=$((HOST_GATES + 1)); return 0; }
merge_gate >/dev/null 2>&1; focused_fail_rc=$?
assert_eq "ready-focused-failure-is-not-go" "1" "$focused_fail_rc"
assert_eq "ready-focused-failure-consumes-zero-terminal-gates" "0" "$TERMINAL_EVENTS"
assert_eq "ready-focused-failure-skips-efficiency-proof" "0" "$EFFICIENCY_PROOFS"
assert_eq "ready-focused-failure-skips-terminal-acceptance" "0" "$HOST_GATES"
assert_eq "ready-focused-failure-remains-repairable" "YES" "$VERDICT_REPAIRABLE"
contract_focused_acceptance_gate() { return 0; }
contract_acceptance_gate() { HOST_GATES=$((HOST_GATES + 1)); return 1; }

printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=host-gate-run\n' > "$INT_WORKTREE/docs/verify-integration.md"
HOST_GATES=0
EFFICIENCY_PROOFS=0
TERMINAL_EVENTS=0
REPAIRS=0
POLYLANE_INTEGRATOR_REPAIRS=3
repair_integrator_verdict() { REPAIRS=$((REPAIRS + 1)); }
graph_authority_require() { return 0; }
graph_authority_record_ready_node() { return 0; }
gate_with_repairs >/dev/null 2>&1; loop_rc=$?
assert_eq "ready-host-gate-failure-stops-loop" "1" "$loop_rc"
assert_eq "ready-host-gate-failure-loop-runs-once" "1" "$HOST_GATES"
assert_eq "ready-host-gate-failure-loop-spawns-no-repair" "0" "$REPAIRS"

HOST_GATES=0
write_efficiency_proof() { return 1; }
contract_acceptance_gate() { HOST_GATES=$((HOST_GATES + 1)); return 0; }
merge_gate >/dev/null 2>&1; proof_fail_rc=$?
assert_eq "ready-efficiency-proof-failure-is-not-go" "1" "$proof_fail_rc"
assert_eq "ready-efficiency-proof-failure-skips-acceptance" "0" "$HOST_GATES"
assert_eq "ready-efficiency-proof-failure-is-no-go" "NO-GO" "$VERDICT_RESULT"
assert_eq "ready-efficiency-proof-failure-stops-repair" "NO" "$VERDICT_REPAIRABLE"

# Immutable launch/restart history is runner-owned eligibility, so an observed
# overage rejects READY before terminal-gate telemetry is incremented or the
# expensive acceptance/proof boundary runs.
printf '%s\n' '{"lanes":[],"efficiency_canary":{"expected_launches":1,"max_restarts":0}}' > "$MANIFEST"
run_stats() {
  if [ "${1:-}" = snapshot ]; then
    printf '%s\n' '{"lanes":{"integrator":{"launches":1,"restarts":1}},"supervisor_restarts":0}'
  else
    [ "${1:-}" != terminal-gate ] || TERMINAL_EVENTS=$((TERMINAL_EVENTS + 1))
  fi
}
HOST_GATES=0; EFFICIENCY_PROOFS=0; TERMINAL_EVENTS=0
write_efficiency_proof() { EFFICIENCY_PROOFS=$((EFFICIENCY_PROOFS + 1)); return 0; }
contract_acceptance_gate() { HOST_GATES=$((HOST_GATES + 1)); return 0; }
printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=host-gate-run\n' > "$INT_WORKTREE/docs/verify-integration.md"
merge_gate >/dev/null 2>&1; eligibility_rc=$?
assert_eq "ready-runtime-overage-is-no-go" "1" "$eligibility_rc"
assert_eq "ready-runtime-overage-consumes-zero-terminal-gates" "0" "$TERMINAL_EVENTS"
assert_eq "ready-runtime-overage-skips-proof" "0" "$EFFICIENCY_PROOFS"
assert_eq "ready-runtime-overage-skips-acceptance" "0" "$HOST_GATES"
assert_eq "ready-runtime-overage-is-not-repairable" "NO" "$VERDICT_REPAIRABLE"
unset RUN_ID

finish
