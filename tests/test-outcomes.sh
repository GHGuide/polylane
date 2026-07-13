#!/usr/bin/env bash
# polylane-outcomes.sh — deterministic signature + risk threshold + tune, seeded JSONL.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
OUTC="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-outcomes.sh"

command -v jq >/dev/null 2>&1 || { pass "outcomes-skipped-no-jq"; finish; exit 0; }
make_tmpdir
export POLYLANE_OUTCOMES="$TEST_TMPDIR/outcomes.jsonl"
export POLYLANE_HUBS="$TEST_TMPDIR/hubs.txt"

# hub registry drives the hub<k> component
"$OUTC" hub add "src/router.ts" >/dev/null
assert_eq "sig-no-hub"  "b1:hub0:crowd0" "$("$OUTC" signature 'src/a.ts')"
assert_eq "sig-hub"     "b1:hub1:crowd0" "$("$OUTC" signature 'src/router.ts')"
assert_eq "sig-crowd"   "b1:hub0:crowd1" "$("$OUTC" signature 'src/**')"

# seed 4 NO-GO for the hub shape -> predict flags it
sig=$("$OUTC" signature 'src/router.ts')
for i in 1 2 3 4; do "$OUTC" record lane$i "$sig" claude-sonnet-5 NO-GO >/dev/null; done
cat > "$TEST_TMPDIR/mf.json" <<'JSON'
{"lanes":[{"name":"nav","own_globs":["src/router.ts"]},{"name":"leaf","own_globs":["src/leaf.ts"]}]}
JSON
out=$("$OUTC" predict "$TEST_TMPDIR/mf.json") && rc=0 || rc=$?
assert_contains "predict-flags-hub" "RISK nav" "$out"
assert_contains "predict-names-hub" "router.ts" "$out"
assert_eq       "predict-rc5"       "5" "$rc"
assert_ok       "predict-clears-leaf-only" sh -c "! printf '%s' \"$out\" | grep -q 'RISK leaf'"

# tune: haiku cleared this shape once -> cheapest GO model returned
"$OUTC" record x "$sig" claude-opus-4-8 GO >/dev/null
"$OUTC" record y "$sig" claude-haiku-4-5 GO >/dev/null
assert_eq "tune-cheapest-proven" "claude-haiku-4-5" "$("$OUTC" tune "$sig")"
finish
