#!/usr/bin/env bash
# Prompt optimization must retain each mandatory block and report deterministic
# machine-readable size metrics without mutating the source prompt.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
PROMPTOPT="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-promptopt.sh"

make_tmpdir
PROMPT="$TEST_TMPDIR/valid.md"
cat > "$PROMPT" <<'EOF'
ULTIMATE-GOAL: Ship the smallest useful product.
CURRENT-SUBGOAL: Prove the prompt launch gate.
GOAL: preserve every strict prompt contract.
OWN: tests/**.
FORBIDDEN: everything else.
PREDEFINED-SKILLS: engineering:testing-strategy
LANE-SPECIFIC-SKILLS: engineering:debug
Read only the named kit once.
TEST-CADENCE: focused first; full suite only in integration.
DELEGATION: forbidden.
CHECK-CACHE: use $PWD/.polylane/check-cache/promptopt.
EXTERNAL-EVIDENCE: never turn missing physical proof into PASS.
VERIFY: write evidence and finish STATUS: promptopt DONE run=prompt-run.
EOF
ORIGINAL=$(cksum "$PROMPT")

METRICS=$("$PROMPTOPT" metrics "$PROMPT")
assert_ok "promptopt-metrics-json" jq -e '.bytes > 0 and .tokens > 0 and .estimated_tokens == .tokens and .token_estimate_method == "ceil(bytes/3)"' <<<"$METRICS"
bytes=$(jq -r '.bytes' <<<"$METRICS")
expected=$(( (bytes + 2) / 3 ))
assert_eq "promptopt-metrics-conservative-byte-estimate" "$expected" "$(jq -r '.tokens' <<<"$METRICS")"
assert_ok "promptopt-check-valid" "$PROMPTOPT" check "$PROMPT" 500
assert_eq "promptopt-check-never-rewrites-source" "$ORIGINAL" "$(cksum "$PROMPT")"

MISSING="$TEST_TMPDIR/missing.md"
grep -v '^TEST-CADENCE:' "$PROMPT" > "$MISSING"
assert_fail "promptopt-check-rejects-missing-strict-block" "$PROMPTOPT" check "$MISSING"
assert_fail "promptopt-check-rejects-over-budget" "$PROMPTOPT" check "$PROMPT" 1
assert_fail "promptopt-check-rejects-over-byte-budget" env POLYLANE_PROMPT_BYTE_BUDGET=1 "$PROMPTOPT" check "$PROMPT" 500

make_tmpdir
ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
CORPUS="$ROOT/benchmarks/prompt-optimization"
assert_ok "promptopt-corpus-champion-challenger-win" \
  "$PROMPTOPT" compare "$CORPUS/fixtures/valid-source.txt" "$CORPUS/fixtures/valid-source.txt"
assert_fail "promptopt-corpus-smaller-weakened-challenger-loses" \
  "$PROMPTOPT" compare "$CORPUS/fixtures/valid-source.txt" "$CORPUS/fixtures/weakened-goal.txt"

finish
