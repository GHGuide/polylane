#!/usr/bin/env bash
# product benchmark corpus validation, isolated adapter execution, reproducible summary.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
BENCH="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-product-benchmark.sh"

make_tmpdir
CORPUS="$TEST_TMPDIR/corpus"; OUT="$TEST_TMPDIR/out"; mkdir -p "$CORPUS"
case_file() {
  local id="$1"
  cat > "$CORPUS/$id.json" <<EOF
{"schema":"schema-v1","id":"$id","title":"$id title","brief":"Help a real person do $id.","product_shape":"web app","feasibility":"feasible","rubric":["delivers core task","handles empty state"]}
EOF
}
case_file pantry-planner
case_file shift-handoff

assert_ok "benchmark-valid-corpus" "$BENCH" validate "$CORPUS"

cp "$CORPUS/pantry-planner.json" "$CORPUS/duplicate.json"
assert_fail "benchmark-rejects-duplicate-id" "$BENCH" validate "$CORPUS"
rm "$CORPUS/duplicate.json"
printf '{bad json\n' > "$CORPUS/malformed.json"
assert_fail "benchmark-rejects-malformed-json" "$BENCH" validate "$CORPUS"
rm "$CORPUS/malformed.json"
jq 'del(.rubric)' "$CORPUS/pantry-planner.json" > "$CORPUS/missing.json"
assert_fail "benchmark-rejects-missing-rubric" "$BENCH" validate "$CORPUS"
rm "$CORPUS/missing.json"
jq '.feasibility = "impossible"' "$CORPUS/pantry-planner.json" > "$CORPUS/bad.json"
assert_fail "benchmark-rejects-bad-feasibility" "$BENCH" validate "$CORPUS"
rm "$CORPUS/bad.json"

ADAPTER="$TEST_TMPDIR/adapter.sh"
cat > "$ADAPTER" <<'EOF'
#!/usr/bin/env bash
set -eu
[ -f "$POLYLANE_BENCH_CASE" ]
[ -d "$POLYLANE_BENCH_WORKDIR" ]
case_id=$(jq -r '.id' "$POLYLANE_BENCH_CASE")
if [ "$case_id" = "pantry-planner" ]; then
  printf '{"tokens":321,"completion":1,"product_quality":0.8,"score":0.75}\n' > "$POLYLANE_BENCH_RESULT"
else
  printf '{"interventions":2,"completion":0.5,"product_quality":0.7,"score":0.75}\n' > "$POLYLANE_BENCH_RESULT"
fi
EOF
chmod +x "$ADAPTER"
assert_ok "benchmark-run-isolated-adapter" "$BENCH" run "$CORPUS" "$OUT" -- "$ADAPTER"
assert_eq "benchmark-one-record-per-case" "2" "$(wc -l < "$OUT/results.jsonl" | tr -d ' ')"
assert_eq "benchmark-case-workdirs-isolated" "2" "$(find "$OUT/cases" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
assert_eq "benchmark-captures-tokens" "321" "$(jq -r 'select(.id == "pantry-planner") | .tokens' "$OUT/results.jsonl")"
assert_eq "benchmark-captures-interventions" "2" "$(jq -r 'select(.id == "shift-handoff") | .interventions' "$OUT/results.jsonl")"
assert_eq "benchmark-captures-completion" "1" "$(jq -r 'select(.id == "pantry-planner") | .completion' "$OUT/results.jsonl")"
assert_eq "benchmark-captures-product-quality" "0.7" "$(jq -r 'select(.id == "shift-handoff") | .product_quality' "$OUT/results.jsonl")"
assert_eq "benchmark-records-adapter-rc" "0" "$(jq -r 'select(.id == "pantry-planner") | .adapter_rc' "$OUT/results.jsonl")"
assert_eq "benchmark-preserves-unknown-metric" "null" "$(jq -r 'select(.id == "shift-handoff") | .tokens' "$OUT/results.jsonl")"
printf '[]\n' > "$TEST_TMPDIR/wrong-shape.json"
assert_eq "benchmark-wrong-shaped-result-is-unknown" "null" \
  "$(bash -c '. "$1"; json_metric "$2" tokens' _ "$BENCH" "$TEST_TMPDIR/wrong-shape.json")"
printf '{"tokens":"unknown","metrics":7}\n' > "$TEST_TMPDIR/wrong-nested-shape.json"
assert_eq "benchmark-wrong-nested-shape-is-unknown" "null" \
  "$(bash -c '. "$1"; json_metric "$2" tokens' _ "$BENCH" "$TEST_TMPDIR/wrong-nested-shape.json" 2>/dev/null)"

SUMMARY_JSON=$("$BENCH" summarize "$OUT" --json)
assert_eq "benchmark-summary-reproducible-count" "2" "$(printf '%s' "$SUMMARY_JSON" | jq -r '.cases')"
assert_eq "benchmark-summary-does-not-zero-unknown" "null" "$(printf '%s' "$SUMMARY_JSON" | jq -r '.mean_tokens')"
assert_eq "benchmark-summary-completion" "0.75" "$(printf '%s' "$SUMMARY_JSON" | jq -r '.mean_completion')"
assert_eq "benchmark-summary-product-quality" "0.75" "$(printf '%s' "$SUMMARY_JSON" | jq -r '.mean_product_quality')"
assert_contains "benchmark-summary-text" "Cases: 2" "$("$BENCH" summarize "$OUT")"

finish
