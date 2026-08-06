#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ADVANCED="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-advanced.sh"
. "$RUNNER"
make_tmpdir
M="$TEST_TMPDIR/manifest.json"
cat > "$M" <<'JSON'
{"base":"main","lanes":[{"name":"alpha","model":"gpt","own_globs":["src/**"]},{"name":"beta","model":"gpt","own_globs":["lib/**"]},{"name":"gamma","model":"gpt","own_globs":["docs/**"]}]}
JSON
OUT="$TEST_TMPDIR/outcomes.jsonl"
POLYLANE_OUTCOMES="$OUT" assert_ok "advanced-preflight-risk-admitted" "$ADVANCED" preflight "$M"
MANIFEST="$M"; SCRIPT_DIR="$(dirname "$ADVANCED")"
POLYLANE_OUTCOMES="$OUT" assert_ok "runner-calls-advanced-preflight-adapter" advanced_runtime preflight
preflight=$(POLYLANE_OUTCOMES="$OUT" "$ADVANCED" preflight "$M")
assert_contains "advanced-preflight-selection-not-requested" "selection=not-requested" "$preflight"
assert_contains "advanced-preflight-salvage-not-requested" "salvage=not-requested" "$preflight"
POLYLANE_OUTCOMES="$OUT" assert_ok "advanced-records-every-lane" "$ADVANCED" record "$M" GO
assert_eq "advanced-record-count" "3" "$(jq -s 'length' "$OUT")"

jq '.champion_candidates=["a|/no-score|1"]' "$M" > "$TEST_TMPDIR/select.json"
select_out=$("$ADVANCED" select "$TEST_TMPDIR/select.json")
assert_contains "advanced-select-explicit-config" "selection=" "$select_out"
salvage_out=$("$ADVANCED" salvage "$M")
assert_contains "advanced-salvage-not-requested" "salvage=not-requested" "$salvage_out"
finish
