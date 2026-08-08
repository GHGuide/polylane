#!/usr/bin/env bash
# A NO-GO/UNKNOWN integration verdict is repaired in-process; it is not reported
# as a cycle boundary until the autonomous repair budget is actually exhausted.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

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
assert_ok "repair-eventually-go" gate_with_repairs
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
HOST_GATES=0
EFFICIENCY_PROOFS=0
TERMINAL_EVENTS=0
contract_acceptance_gate() { HOST_GATES=$((HOST_GATES + 1)); return 1; }
merge_gate >/dev/null 2>&1; host_fail_rc=$?
assert_eq "ready-host-gate-failure-is-not-go" "1" "$host_fail_rc"
assert_eq "ready-host-gate-failure-runs-once" "1" "$HOST_GATES"
assert_eq "ready-host-gate-failure-proves-once" "1" "$EFFICIENCY_PROOFS"
assert_eq "ready-host-gate-failure-stops-repair" "NO" "$VERDICT_REPAIRABLE"

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
