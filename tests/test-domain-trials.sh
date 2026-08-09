#!/usr/bin/env bash
# Real-source trial corpus stays offline by default; live reads are explicitly optional.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TRIALS="$ROOT/bin/polylane-domain-trials.sh"
CORPUS="$ROOT/benchmarks/domain-trials/v1"

make_tmpdir

assert_ok "trials-real-corpus-validates" "$TRIALS" validate "$CORPUS"
assert_eq "trials-seven-domain-kinds" "7" "$(find "$CORPUS/cases" -name '*.json' | wc -l | tr -d ' ')"
assert_ok "trials-has-market-series" jq -e '.domain == "trading" and any(.grading.checks[]; . == "chronological_no_leakage")' "$CORPUS/cases/trading-sp500-window.json"
assert_ok "trials-has-openalex-record" jq -e '.source.url | test("api.openalex.org|api.crossref.org")' "$CORPUS/cases/research-crossref-record.json"
assert_ok "trials-has-authoritative-operations-standard" jq -e '.source.url | test("csrc.nist.gov")' "$CORPUS/cases/operations-nist-incident.json"

cp -R "$CORPUS" "$TEST_TMPDIR/tampered"
printf 'tamper\n' >> "$TEST_TMPDIR/tampered/raw/trading-sp500-window.csv"
assert_fail "trials-rejects-tampered-snapshot" "$TRIALS" validate "$TEST_TMPDIR/tampered"

HELPER="$TEST_TMPDIR/domain-helper.sh"
apply_helper() {
  :
}
cat > "$HELPER" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "artifact for $(jq -r .id "$POLYLANE_DOMAIN_CASE")" > "$POLYLANE_DOMAIN_WORKDIR/answer.txt"
jq -n --arg artifact "$POLYLANE_DOMAIN_WORKDIR/answer.txt" '{verdict:"pass",interventions:0,artifact:$artifact}' > "$POLYLANE_DOMAIN_RESULT"
EOF
chmod +x "$HELPER"

OUT="$TEST_TMPDIR/out"
assert_ok "trials-runs-isolated-deterministic-helper" env POLYLANE_DOMAIN_HELPER="$HELPER" "$TRIALS" run "$CORPUS" "$OUT"
assert_eq "trials-one-record-per-case" "7" "$(wc -l < "$OUT/results.jsonl" | tr -d ' ')"
assert_eq "trials-records-expected-verdict" "pass" "$(jq -r 'select(.id == "trading-sp500-window") | .expected_verdict' "$OUT/results.jsonl")"
assert_eq "trials-records-actual-verdict" "pass" "$(jq -r 'select(.id == "trading-sp500-window") | .actual_verdict' "$OUT/results.jsonl")"
assert_ok "trials-records-reproducibility-hash" jq -e 'all(.reproducibility_hash; test("^[0-9a-f]{64}$"))' "$OUT/results.jsonl"

SUMMARY=$("$TRIALS" summarize "$OUT" --json)
assert_eq "trials-summary-count" "7" "$(printf '%s' "$SUMMARY" | jq -r .cases)"
assert_eq "trials-summary-no-unproven" "0" "$(printf '%s' "$SUMMARY" | jq -r .unproven)"

LIVE_OUT="$TEST_TMPDIR/live-out"
assert_ok "trials-live-network-absence-is-skip" env POLYLANE_DOMAIN_HELPER="$HELPER" POLYLANE_DOMAIN_LIVE_URL='https://127.0.0.1:1/unavailable' "$TRIALS" run "$CORPUS" "$LIVE_OUT" --live --domain research
assert_eq "trials-live-receipt-labeled-skip" "SKIP" "$(jq -r .status "$LIVE_OUT/live-receipt.json")"

finish
