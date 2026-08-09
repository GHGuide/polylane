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
unset RUN_ID

finish
