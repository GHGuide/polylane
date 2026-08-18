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
contract_ready_verdict() { printf 'GO'; }
run_stats() {
  [ "${1:-}" != terminal-gate ] || TERMINAL_EVENTS=$((TERMINAL_EVENTS + 1))
  return 0
}
write_efficiency_proof() {
  EFFICIENCY_PROOFS=$((EFFICIENCY_PROOFS + 1))
  [ "$TERMINAL_EVENTS" = 1 ]
}
# These gate tests isolate READY routing; the receipt implementation has its own
# real git/state/toolchain fixture in test-terminal-cache.sh.
terminal_gate_pass_receipt_valid() { return 1; }
terminal_gate_pass_receipt_record() { return 0; }
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

# A matching durable PASS receipt avoids a second terminal attempt after a
# coordinator crash, while the cheap focused gate and current efficiency proof
# still run at the resumed boundary.
printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=host-gate-run\n' > "$INT_WORKTREE/docs/verify-integration.md"
HOST_GATES=0
EFFICIENCY_PROOFS=0
TERMINAL_EVENTS=0
RECEIPT_RECORDS=0
contract_focused_acceptance_gate() { return 0; }
contract_ready_verdict() { printf 'GO'; }
terminal_gate_pass_receipt_valid() { return 0; }
terminal_gate_pass_receipt_record() { RECEIPT_RECORDS=$((RECEIPT_RECORDS + 1)); }
contract_acceptance_gate() { HOST_GATES=$((HOST_GATES + 1)); return 0; }
write_efficiency_proof() { EFFICIENCY_PROOFS=$((EFFICIENCY_PROOFS + 1)); return 0; }
merge_gate; cache_hit_rc=$?
assert_eq "ready-terminal-cache-hit-passes" "0" "$cache_hit_rc"
assert_eq "ready-terminal-cache-hit-skips-command" "0" "$HOST_GATES"
assert_eq "ready-terminal-cache-hit-does-not-count-new-gate" "0" "$TERMINAL_EVENTS"
assert_eq "ready-terminal-cache-hit-refreshes-efficiency-proof" "1" "$EFFICIENCY_PROOFS"
assert_eq "ready-terminal-cache-hit-does-not-rewrite-receipt" "0" "$RECEIPT_RECORDS"
assert_eq "ready-terminal-cache-hit-converts-to-go" "GO" "$VERDICT_RESULT"
unset RUN_ID

finish
