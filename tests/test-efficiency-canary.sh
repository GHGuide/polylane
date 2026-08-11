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
{"run_id":"eff-1","wall_s":$1,"lanes":{"a":{"launches":1,"restarts":0},"b":{"launches":1,"restarts":0},"integrator":{"launches":1,"restarts":0}},"supervisor_restarts":$2,"terminal_gates":$3,"tokens":$4,"token_state":"$5","cleanup":"$6"}
JSON
}

write_stats 120 0 1 4567 known pending
assert_ok "efficiency-gate-capture" "$EFF" capture --manifest "$MF" --stats "$ST" --proof "$PF" --phase gate
assert_ok "efficiency-gate-verify" "$EFF" verify --proof "$PF" --phase gate
assert_ok "efficiency-gate-verifies-current-run" "$EFF" verify --proof "$PF" --phase gate --run-id eff-1
assert_fail "efficiency-gate-rejects-wrong-expected-run" "$EFF" verify --proof "$PF" --phase gate --run-id stale-run
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

# A deliberately focused cycle may complete cleanup without consuming the
# terminal boundary. Its manifest contract, not the terminal default, is truth.
MF_ZERO="$TEST_TMPDIR/focused-zero.json"
cat > "$MF_ZERO" <<'JSON'
{
  "run_id":"eff-zero",
  "lanes":[{"name":"a"}],
  "efficiency_canary":{"expected_launches":1,"max_restarts":0,"max_wall_s":900,"expected_terminal_gates":0}
}
JSON
cat > "$ST" <<'JSON'
{"run_id":"eff-zero","wall_s":140,"lanes":{"a":{"launches":1,"restarts":0}},"supervisor_restarts":0,"terminal_gates":0,"tokens":4567,"token_state":"known","cleanup":"complete"}
JSON
assert_ok "efficiency-focused-zero-gate-final-capture" "$EFF" capture --manifest "$MF_ZERO" --stats "$ST" --proof "$PF" --phase final
assert_ok "efficiency-focused-zero-gate-final-verify" "$EFF" verify --proof "$PF" --phase final --run-id eff-zero
assert_contains "efficiency-focused-zero-gate-proof" "Terminal gates: 0 / 0" "$(cat "$PF")"

write_stats 140 0 1 null unknown complete
assert_ok "efficiency-default-one-gate-final-capture" "$EFF" capture --manifest "$MF" --stats "$ST" --proof "$PF" --phase final
assert_ok "efficiency-default-one-gate-final-verify" "$EFF" verify --proof "$PF" --phase final
assert_contains "efficiency-default-one-gate-proof" "Terminal gates: 1 / 1" "$(cat "$PF")"

LEGACY_PF="$TEST_TMPDIR/legacy-efficiency-proof.md"
cat > "$LEGACY_PF" <<'EOF'
# polylane efficiency proof

- Run: legacy-eff-1
- Phase: final
- Status: PASS
- Terminal gates: 1
- Unexpected launches: 0
EOF
assert_ok "efficiency-legacy-one-gate-verify" "$EFF" verify --proof "$LEGACY_PF" --phase final --run-id legacy-eff-1

MISMATCH_PF="$TEST_TMPDIR/mismatched-efficiency-proof.md"
sed 's/Terminal gates: 1$/Terminal gates: 0 \/ 1/' "$LEGACY_PF" > "$MISMATCH_PF"
assert_fail "efficiency-terminal-gate-mismatch-rejected" "$EFF" verify --proof "$MISMATCH_PF" --phase final --run-id legacy-eff-1

MALFORMED_PF="$TEST_TMPDIR/malformed-efficiency-proof.md"
sed 's/Terminal gates: 1$/Terminal gates: zero \/ zero/' "$LEGACY_PF" > "$MALFORMED_PF"
assert_fail "efficiency-malformed-terminal-gate-proof-rejected" "$EFF" verify --proof "$MALFORMED_PF" --phase final --run-id legacy-eff-1

# The host-owned gate proof must never modify a completed integrator checkout.
# It is run-scoped canonical evidence, and its nonce is exported to terminal
# acceptance so an inherited proof from an older cycle cannot pass.
. "$RUNNER"
HOST_PROJECT="$TEST_TMPDIR/host-project"
HOST_INT="$TEST_TMPDIR/host-integrator"
mkdir -p "$HOST_PROJECT/docs/polylane" "$HOST_INT/docs/polylane"
git -C "$HOST_INT" init -q -b main
git -C "$HOST_INT" config user.email test@example.invalid
git -C "$HOST_INT" config user.name test
printf '%s\n' '# inherited tracked proof' > "$HOST_INT/docs/polylane/efficiency-proof.md"
git -C "$HOST_INT" add docs/polylane/efficiency-proof.md
git -C "$HOST_INT" commit -qm base
write_stats 120 0 1 4567 known pending
cp "$ST" "$HOST_PROJECT/docs/polylane/run-stats.json"
PROJECT_ROOT="$HOST_PROJECT"
REPO_ROOT="$HOST_PROJECT"
INT_WORKTREE="$HOST_INT"
MANIFEST="$MF"
RUN_ID=eff-1
DRY_RUN=0
write_efficiency_proof gate >/dev/null 2>&1
runner_proof_rc=$?
assert_eq "efficiency-runner-writes-host-scoped-gate-proof" "0" "$runner_proof_rc"
assert_ok "efficiency-runner-leaves-integrator-clean" test -z "$(git -C "$HOST_INT" status --porcelain)"
assert_ok "efficiency-runner-names-current-run-proof" test -f "$HOST_PROJECT/docs/polylane/efficiency-proofs/eff-1-gate.md"
assert_eq "efficiency-runner-exports-current-proof" "$HOST_PROJECT/docs/polylane/efficiency-proofs/eff-1-gate.md" "${EFFICIENCY_GATE_PROOF:-}"
assert_ok "efficiency-runner-proof-carries-current-run" "$EFF" verify --proof "${EFFICIENCY_GATE_PROOF:-missing}" --phase gate --run-id eff-1

# The frozen terminal command is launched by polylane-memory, so prove the
# runner exports the exact host proof path and nonce into both acceptance calls.
REAL_SCRIPT_DIR="$SCRIPT_DIR"
FAKE_BIN="$TEST_TMPDIR/fake-bin"
ENV_LOG="$TEST_TMPDIR/acceptance-env.log"
mkdir -p "$FAKE_BIN" "$HOST_INT"
cat > "$FAKE_BIN/polylane-memory.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s|%s\n' "${POLYLANE_EFFICIENCY_PROOF:-}" "${POLYLANE_EXPECTED_RUN_ID:-}" "$*" >> "$POLYLANE_TEST_ENV_LOG"
EOF
chmod +x "$FAKE_BIN/polylane-memory.sh"
STATE_FILE="$TEST_TMPDIR/acceptance-state.json"
cat > "$STATE_FILE" <<'JSON'
{"milestones":[{"subgoals":[{"id":"s1","status":"done"}]}],"accept":[]}
JSON
ACCEPT_MANIFEST="$TEST_TMPDIR/acceptance-manifest.json"
printf '%s\n' '{"target_subgoals":["s1"]}' > "$ACCEPT_MANIFEST"
SCRIPT_DIR="$FAKE_BIN"
MANIFEST="$ACCEPT_MANIFEST"
CYCLE=21
ORCHESTRATION_CONTRACT=2
POLYLANE_TEST_ENV_LOG="$ENV_LOG"
export POLYLANE_TEST_ENV_LOG

# The cheap READY precheck runs before the host has created this run's gate
# proof.  It must not leak a nonce without its matching proof: doing so makes a
# nested efficiency canary compare the new nonce against an inherited/default
# proof and reject otherwise-green work.
SAVED_EFFICIENCY_GATE_PROOF="$EFFICIENCY_GATE_PROOF"
EFFICIENCY_GATE_PROOF=
RUN_ID=pre-gate-run
: > "$ENV_LOG"
assert_ok "efficiency-focused-precheck-runs-without-proof-context" contract_focused_acceptance_gate
assert_eq "efficiency-focused-precheck-exports-no-half-context" \
  "||$STATE_FILE check-accept --cycle 21 --targets s1 --focused" "$(cat "$ENV_LOG")"

# A final GO without terminal work also has no host gate proof. Its focused
# acceptance child must not inherit a stale proof or receive a nonce alone.
: > "$ENV_LOG"
assert_ok "efficiency-focused-only-go-runs-without-proof-context" contract_acceptance_gate GO
assert_eq "efficiency-focused-only-go-exports-no-half-context" \
  "||$STATE_FILE check-accept --cycle 21 --targets s1 --focused" "$(cat "$ENV_LOG")"

EFFICIENCY_GATE_PROOF="$SAVED_EFFICIENCY_GATE_PROOF"
RUN_ID=eff-1
: > "$ENV_LOG"
assert_ok "efficiency-acceptance-inherits-host-proof" contract_acceptance_gate GO 1
assert_eq "efficiency-focused-only-acceptance-exports-proof-once" "1" "$(grep -cF "${EFFICIENCY_GATE_PROOF}|eff-1|" "$ENV_LOG")"
SCRIPT_DIR="$REAL_SCRIPT_DIR"
unset POLYLANE_TEST_ENV_LOG

jq '.run_id="stale-run"' "$ST" > "$ST.tmp" && mv "$ST.tmp" "$ST"
assert_fail "efficiency-stale-run-rejected" "$EFF" capture --manifest "$MF" --stats "$ST" --proof "$PF" --phase final

# During the real terminal gate, the runner writes this canonical candidate.
# The frozen acceptance command separately requires the file to exist.
CANONICAL="${POLYLANE_EFFICIENCY_PROOF:-$(cd "$(dirname "$0")/.." && pwd)/docs/polylane/efficiency-proof.md}"
if [ -f "$CANONICAL" ]; then
  if grep -qF -- '- Status: PASS' "$CANONICAL" && [ -n "${POLYLANE_EXPECTED_RUN_ID:-}" ]; then
    assert_ok "efficiency-canonical-proof" "$EFF" verify --proof "$CANONICAL" --run-id "$POLYLANE_EXPECTED_RUN_ID"
  elif grep -qF -- '- Status: PASS' "$CANONICAL"; then
    assert_ok "efficiency-canonical-proof" "$EFF" verify --proof "$CANONICAL"
  else
    # Cycle 32's preserved failed proof is historical evidence, not a current
    # terminal candidate; it must remain rejected until a fresh capture writes
    # the explicit actual/expected gate contract.
    assert_fail "efficiency-canonical-failed-proof-rejected" "$EFF" verify --proof "$CANONICAL"
  fi
fi

DRY_RUN=1
MANIFEST="$MF"
PROJECT_ROOT="$TEST_TMPDIR/no-runtime-stats"
INT_WORKTREE="$TEST_TMPDIR/no-integration-worktree"
assert_ok "efficiency-dry-run-noop" write_efficiency_proof final

finish
