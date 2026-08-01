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

finish
