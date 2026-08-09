#!/usr/bin/env bash
# Accelerated fixtures prove recovery without tmux, network, branches, or sleeps.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOAK="$ROOT/bin/polylane-soak.sh"
make_tmpdir

RUN="$TEST_TMPDIR/run"
assert_ok "soak-accelerated-all-fixture-faults-recover" "$SOAK" run "$RUN" --accelerated --iterations 8 --seed 41
assert_eq "soak-terminal-truth" "passed" "$(jq -r .terminal_status "$RUN/summary.json")"
assert_eq "soak-exactly-once-fault-receipts" "6" "$(find "$RUN/faults" -name '*.json' | wc -l | tr -d ' ')"
assert_eq "soak-steady-state-restored" "true" "$(jq -r .steady_state.restored "$RUN/summary.json")"
assert_eq "soak-no-sleeps-in-accelerated" "0" "$(jq -r .sleep_seconds "$RUN/summary.json")"

RESUME="$TEST_TMPDIR/resume"
assert_fail "soak-interrupts-for-resume" "$SOAK" run "$RESUME" --accelerated --iterations 7 --stop-after 3 --seed 7
assert_eq "soak-checkpoint-is-incomplete" "interrupted" "$(jq -r .status "$RESUME/state.json")"
printf '{malformed checkpoint\n' > "$RESUME/state.json"
assert_ok "soak-resumes-from-atomic-backup" "$SOAK" run "$RESUME" --accelerated --iterations 7 --seed 7
assert_eq "soak-resume-terminal-summary" "passed" "$(jq -r .terminal_status "$RESUME/summary.json")"
assert_eq "soak-resume-never-duplicates-fault" "1" "$(jq -s '[.[] | select(.fault == "worker-death")] | length' "$RESUME/faults"/*.json)"

FAIL="$TEST_TMPDIR/failure"
assert_fail "soak-bounded-recovery-fails-closed" "$SOAK" run "$FAIL" --accelerated --iterations 2 --seed 1 --max-recovery-attempts 0
assert_eq "soak-failed-summary-is-truthful" "failed" "$(jq -r .terminal_status "$FAIL/summary.json")"

STALE="$TEST_TMPDIR/stale"
mkdir -p "$STALE/markers"
printf 'old-run\n' > "$STALE/markers/nonce"
assert_ok "soak-stale-run-marker-is-isolated" "$SOAK" run "$STALE" --accelerated --iterations 2 --seed 9
assert_eq "soak-stale-marker-not-adopted" "old-run" "$(cat "$STALE/markers/nonce")"

assert_fail "soak-rejects-invalid-duration" "$SOAK" configure "$TEST_TMPDIR/bad" --hours 5
for hours in 6 12 24; do
  assert_ok "soak-configures-${hours}h-without-waiting" "$SOAK" configure "$TEST_TMPDIR/h$hours" --hours "$hours" --seed 2
  assert_eq "soak-${hours}h-wall-clock-mode" "wall-clock" "$(jq -r .mode "$TEST_TMPDIR/h$hours/state.json")"
done

finish
