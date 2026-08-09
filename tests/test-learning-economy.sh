#!/usr/bin/env bash
# Accepted-outcome learning, benchmark admission, and bounded economy policy.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
OPT="$ROOT/bin/polylane-optimize.sh"
BENCH="$ROOT/bin/polylane-skill-benchmark.sh"
CATALOG="$ROOT/bin/polylane-skill-catalog.sh"

if ! command -v jq >/dev/null 2>&1; then
  pass "learning-economy-skipped-no-jq"; finish; exit 0
fi

make_tmpdir
LEDGER="$TEST_TMPDIR/evidence.jsonl"
BENCH_LEDGER="$TEST_TMPDIR/benchmarks.jsonl"
POLICY="$TEST_TMPDIR/policy.json"

receipt() { # FILE ID MODEL EFFORT LANES CONTEXT QUALITY CRITERIA SUBGOALS VERDICT STATUS [REGRESSION]
  jq -n --arg id "$2" --arg model "$3" --arg effort "$4" --arg verdict "${10}" --arg status "${11}" \
    --argjson lanes "$5" --argjson context "$6" --argjson quality "$7" --argjson criteria "$8" --argjson subgoals "$9" \
    --argjson regression "${12:-false}" \
    '{schema:"polylane-evidence/v1",run:"run-1",cycle:16,lane:"builder",lane_shape:"api-single",domain:"api",model:$model,effort:$effort,lane_count:$lanes,context_tokens:$context,selected_skills:["skill:lower-match"],tokens:1000,wall_seconds:60,verified_criteria_delta:$criteria,verified_subgoal_delta:$subgoals,quality_score:$quality,quality_regression:$regression,acceptance_hash:$id,acceptance_status:$status,verdict:$verdict}' > "$1"
}

benchmark_receipt() { # FILE ID SKILL FINGERPRINT DELTA VERDICT HARD STATUS [HURT]
  jq -n --arg id "$2" --arg skill "$3" --arg fp "$4" --arg verdict "$6" --arg status "$8" \
    --argjson delta "$5" --argjson hard "$7" --argjson hurt "${9:-false}" \
    '{schema:"polylane-skill-benchmark/v1",receipt_id:$id,skill:{id:$skill,fingerprint:$fp},lane_shape:"api-single",domain:"api",quality_adjusted_delta:$delta,hard_checks:$hard,acceptance_status:$status,verdict:$verdict,hurt:$hurt}' > "$1"
}

cat > "$POLICY" <<'JSON'
{"schema":"polylane-policy/v1","domain":"api","lane_shape":"api-single","model":"gpt-5.6-terra","effort":"medium","lane_count":2,"context_tokens":4000,"available_models":["gpt-5.6-luna","gpt-5.6-terra"],"bounds":{"lane_count":{"min":1,"max":3},"context_tokens":{"min":1000,"max":6000}},"minimum_samples":3,"role":"builder"}
JSON

# RED: these binaries and their evidence-gated contracts do not exist yet.
assert_ok "economy-optimizer-exists" test -x "$OPT"
assert_ok "economy-benchmark-exists" test -x "$BENCH"

BAD="$TEST_TMPDIR/bad.json"
printf '{not json\n' > "$BAD"
assert_fail "economy-rejects-malformed-receipt" "$OPT" validate "$BAD"
receipt "$TEST_TMPDIR/unaccepted.json" u1 gpt-5.6-terra medium 2 4000 2 2 0 GO pending
assert_fail "economy-rejects-unaccepted-receipt" "$OPT" record "$LEDGER" "$TEST_TMPDIR/unaccepted.json"

# Three baseline receipts are deliberately slower but safe; cheap regressions must not win.
for n in 1 2 3; do
  receipt "$TEST_TMPDIR/base-$n.json" "base-$n" gpt-5.6-terra medium 2 4000 2 2 0 GO accepted
  assert_ok "economy-records-baseline-$n" "$OPT" record "$LEDGER" "$TEST_TMPDIR/base-$n.json"
done
receipt "$TEST_TMPDIR/duplicate.json" base-1 gpt-5.6-terra medium 2 4000 2 2 0 GO accepted
assert_ok "economy-duplicate-is-idempotent" "$OPT" record "$LEDGER" "$TEST_TMPDIR/duplicate.json"
assert_eq "economy-deduplicates-receipt-identity" 3 "$(jq -s 'length' "$LEDGER")"

receipt "$TEST_TMPDIR/nogo.json" ng-1 gpt-5.6-luna low 2 4000 9 9 0 NO-GO accepted
assert_fail "economy-rejects-no-go" "$OPT" record "$LEDGER" "$TEST_TMPDIR/nogo.json"
receipt "$TEST_TMPDIR/regression.json" qr-1 gpt-5.6-luna low 2 4000 9 9 0 GO accepted true
assert_fail "economy-rejects-quality-regression" "$OPT" record "$LEDGER" "$TEST_TMPDIR/regression.json"
receipt "$TEST_TMPDIR/zero.json" z-1 gpt-5.6-luna low 2 4000 9 0 0 GO accepted
assert_ok "economy-accepts-zero-delta-but-values-it-zero" "$OPT" record "$LEDGER" "$TEST_TMPDIR/zero.json"

# Insufficient samples, unavailable models, and multiple simultaneous changes keep default.
receipt "$TEST_TMPDIR/thin.json" thin-1 gpt-5.6-luna medium 2 3000 5 3 0 GO accepted
assert_ok "economy-records-thin-evidence" "$OPT" record "$LEDGER" "$TEST_TMPDIR/thin.json"
REC="$TEST_TMPDIR/recommend.json"
assert_ok "economy-recommend-thin-safe-default" bash -c '"$1" recommend "$2" "$3" --json > "$4"' _ "$OPT" "$LEDGER" "$POLICY" "$REC"
assert_eq "economy-thin-evidence-is-not-safe-to-apply" false "$(jq -r .safe_to_apply "$REC")"
assert_contains "economy-thin-evidence-explained" "minimum samples" "$(jq -r .reason "$REC")"

for n in 1 2 3; do
  receipt "$TEST_TMPDIR/luna-$n.json" "luna-$n" gpt-5.6-luna medium 2 4000 5 3 0 GO accepted
  assert_ok "economy-records-efficient-$n" "$OPT" record "$LEDGER" "$TEST_TMPDIR/luna-$n.json"
done
assert_ok "economy-recommends-efficient-policy" bash -c '"$1" recommend "$2" "$3" --json > "$4"' _ "$OPT" "$LEDGER" "$POLICY" "$REC"
assert_eq "economy-efficient-model-wins" gpt-5.6-luna "$(jq -r '.recommendation.model' "$REC")"
assert_eq "economy-one-step-only" 1 "$(jq -r '.changed_fields | length' "$REC")"
assert_eq "economy-recommendation-is-safe" true "$(jq -r .safe_to_apply "$REC")"
assert_contains "economy-reports-score-definition" "min(median progress" "$(jq -r .score_definition "$REC")"
assert_eq "economy-reports-samples" 3 "$(jq -r .samples.candidate "$REC")"

UNAVAILABLE="$TEST_TMPDIR/unavailable-policy.json"
jq '.available_models=["gpt-5.6-terra"]' "$POLICY" > "$UNAVAILABLE"
assert_ok "economy-unavailable-model-safe-default" bash -c '"$1" recommend "$2" "$3" --json > "$4"' _ "$OPT" "$LEDGER" "$UNAVAILABLE" "$REC"
assert_eq "economy-unavailable-model-blocked" false "$(jq -r .safe_to_apply "$REC")"

TERMINAL="$TEST_TMPDIR/terminal-policy.json"
jq '.role="integrator"' "$POLICY" > "$TERMINAL"
assert_ok "economy-terminal-clamp-safe-default" bash -c '"$1" recommend "$2" "$3" --json > "$4"' _ "$OPT" "$LEDGER" "$TERMINAL" "$REC"
assert_eq "economy-terminal-cannot-downgrade" false "$(jq -r .safe_to_apply "$REC")"

OUT_OF_BOUNDS="$TEST_TMPDIR/oob.json"
for n in 1 2 3; do
  receipt "$TEST_TMPDIR/oob-$n.json" "oob-$n" gpt-5.6-terra medium 9 4000 20 3 0 GO accepted
  assert_ok "economy-records-oob-$n" "$OPT" record "$LEDGER" "$TEST_TMPDIR/oob-$n.json"
done
assert_ok "economy-lane-bound-safe-default" bash -c '"$1" recommend "$2" "$3" --json > "$4"' _ "$OPT" "$LEDGER" "$POLICY" "$REC"
assert_eq "economy-lane-bound-blocked" gpt-5.6-luna "$(jq -r '.recommendation.model' "$REC")"

# Stable ties choose lexicographically by the policy tuple.
TIE_LEDGER="$TEST_TMPDIR/tie.jsonl"
for model in gpt-5.6-luna gpt-5.6-terra; do
  for n in 1 2 3; do
    receipt "$TEST_TMPDIR/tie-$model-$n.json" "tie-$model-$n" "$model" medium 2 4000 3 2 0 GO accepted
    assert_ok "economy-records-tie-$model-$n" "$OPT" record "$TIE_LEDGER" "$TEST_TMPDIR/tie-$model-$n.json"
  done
done
assert_ok "economy-tie-is-deterministic" bash -c '"$1" recommend "$2" "$3" --json > "$4"' _ "$OPT" "$TIE_LEDGER" "$POLICY" "$REC"
assert_eq "economy-tie-stable-model" gpt-5.6-luna "$(jq -r '.recommendation.model' "$REC")"
assert_ok "economy-summarizes-accepted-and-ignored" bash -c '"$1" summarize "$2" > "$3"' _ "$OPT" "$LEDGER" "$TEST_TMPDIR/summary.json"
assert_eq "economy-summary-accepted-count" 11 "$(jq -r .accepted "$TEST_TMPDIR/summary.json")"

# A lexical catalog match stays a candidate; only matching, fingerprinted, hard-passing lanes are recommended.
FP_GOOD="fp-good"; FP_BAD="fp-bad"
for n in 1 2 3; do
  benchmark_receipt "$TEST_TMPDIR/bench-$n.json" "bench-$n" skill:lower-match "$FP_GOOD" 4 GO true accepted
  assert_ok "benchmark-records-good-$n" "$BENCH" record "$BENCH_LEDGER" "$TEST_TMPDIR/bench-$n.json"
done
benchmark_receipt "$TEST_TMPDIR/bench-fail.json" bench-fail skill:lexical "$FP_BAD" 9 NO-GO false accepted
assert_ok "benchmark-records-failed-visible" "$BENCH" record "$BENCH_LEDGER" "$TEST_TMPDIR/bench-fail.json"

CAND="$TEST_TMPDIR/candidate.json"
printf '%s\n' '{"id":"skill:lower-match","fingerprint":"fp-good","domain":"api","lane_shape":"api-single"}' > "$CAND"
assert_ok "benchmark-gate-recommends-proven-fingerprint" bash -c '"$1" gate "$2" "$3" > "$4"' _ "$BENCH" "$BENCH_LEDGER" "$CAND" "$TEST_TMPDIR/gate.json"
assert_eq "benchmark-gate-safe" true "$(jq -r .safe_to_apply "$TEST_TMPDIR/gate.json")"
jq '.fingerprint="changed"' "$CAND" > "$TEST_TMPDIR/changed.json"
assert_ok "benchmark-changed-fingerprint-visible-but-blocked" bash -c '"$1" gate "$2" "$3" > "$4"' _ "$BENCH" "$BENCH_LEDGER" "$TEST_TMPDIR/changed.json" "$TEST_TMPDIR/gate.json"
assert_eq "benchmark-changed-fingerprint-blocked" false "$(jq -r .safe_to_apply "$TEST_TMPDIR/gate.json")"

CAT="$TEST_TMPDIR/catalog.json"; LANE="$TEST_TMPDIR/lane.json"
cat > "$CAT" <<'JSON'
{"schema":1,"skills":[
 {"id":"skill:lexical","path":"/tmp/lexical","name":"API API API","description":"build api endpoint route api endpoint route","source":"trusted-root","fingerprint":"fp-bad","compatibility":["codex"],"allowed_tools":["bash"]},
 {"id":"skill:lower-match","path":"/tmp/lower","name":"endpoint helper","description":"build one API endpoint safely","source":"trusted-root","fingerprint":"fp-good","compatibility":["codex"],"allowed_tools":["bash"]}]}
JSON
cat > "$LANE" <<'JSON'
{"role":"builder","lane_shape":"api-single","goal":"build an API endpoint","activities":["build API endpoint"],"own_globs":["routes/api.js"],"agent":"codex","required_tools":["bash"]}
JSON
assert_ok "catalog-benchmark-evidence-configured" env POLYLANE_SKILL_BENCHMARK_LEDGER="$BENCH_LEDGER" "$CATALOG" recommend "$CAT" "$LANE" "$TEST_TMPDIR/legacy.jsonl"
CAT_REC=$(env POLYLANE_SKILL_BENCHMARK_LEDGER="$BENCH_LEDGER" "$CATALOG" recommend "$CAT" "$LANE" "$TEST_TMPDIR/legacy.jsonl")
assert_eq "catalog-benchmark-beats-lexical-false-positive" skill:lower-match "$(printf '%s' "$CAT_REC" | jq -r '.candidates[0].id')"
assert_eq "catalog-unbenchmarked-is-candidate" candidate "$(printf '%s' "$CAT_REC" | jq -r '.candidates[] | select(.id == "skill:lexical") | .status')"
assert_eq "catalog-benchmarked-is-recommended" recommended "$(printf '%s' "$CAT_REC" | jq -r '.candidates[0].status')"

finish
