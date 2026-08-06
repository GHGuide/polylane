#!/usr/bin/env bash
# The final walk-away canary is graded from runner telemetry, not lane prose.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

EFF="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-efficiency.sh"
make_tmpdir
MF="$TEST_TMPDIR/run.json"
ST="$TEST_TMPDIR/run-stats.json"
PF="$TEST_TMPDIR/efficiency-proof.md"

cat > "$MF" <<'JSON'
{
  "run_id":"eff-1",
  "lanes":[{"name":"a"},{"name":"b"}],
  "integrator":{"name":"integrator"},
  "efficiency_canary":{"max_restarts":0,"max_wall_s":900}
}
JSON

write_stats() {
  cat > "$ST" <<JSON
{"wall_s":$1,"lanes":{"a":{"launches":1,"restarts":0},"b":{"launches":1,"restarts":0},"integrator":{"launches":1,"restarts":0}},"supervisor_restarts":$2,"terminal_gates":$3,"tokens":$4,"token_state":"$5","cleanup":"$6"}
JSON
}

write_stats 120 0 1 4567 known pending
assert_ok "efficiency-gate-capture" "$EFF" capture --manifest "$MF" --stats "$ST" --proof "$PF" --phase gate
assert_ok "efficiency-gate-verify" "$EFF" verify --proof "$PF" --phase gate
assert_contains "efficiency-launch-budget" "Launches: 3 / 3" "$(cat "$PF")"
assert_contains "efficiency-one-gate" "Terminal gates: 1" "$(cat "$PF")"
assert_contains "efficiency-token-truth" "Tokens: 4567 (known)" "$(cat "$PF")"

write_stats 130 1 1 null unknown pending
assert_fail "efficiency-restart-rejected" "$EFF" capture --manifest "$MF" --stats "$ST" --proof "$PF" --phase gate
assert_contains "efficiency-failure-durable" "Status: FAIL" "$(cat "$PF")"

write_stats 140 0 1 null unknown complete
assert_ok "efficiency-final-capture" "$EFF" capture --manifest "$MF" --stats "$ST" --proof "$PF" --phase final
assert_ok "efficiency-final-verify" "$EFF" verify --proof "$PF" --phase final
assert_contains "efficiency-unknown-not-zero" "Tokens: unknown" "$(cat "$PF")"
assert_contains "efficiency-clean" "Cleanup: complete" "$(cat "$PF")"

# During the real terminal gate, the runner writes this canonical candidate.
# The frozen acceptance command separately requires the file to exist.
CANONICAL="$(cd "$(dirname "$0")/.." && pwd)/docs/polylane/efficiency-proof.md"
if [ -f "$CANONICAL" ]; then
  assert_ok "efficiency-canonical-proof" "$EFF" verify --proof "$CANONICAL"
fi

. "$RUNNER"
DRY_RUN=1
MANIFEST="$MF"
PROJECT_ROOT="$TEST_TMPDIR/no-runtime-stats"
INT_WORKTREE="$TEST_TMPDIR/no-integration-worktree"
assert_ok "efficiency-dry-run-noop" write_efficiency_proof final

finish
