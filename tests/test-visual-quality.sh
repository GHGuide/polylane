#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

QUALITY="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-visual-quality.sh"
make_tmpdir
ROOT="$TEST_TMPDIR/project"; mkdir -p "$ROOT/shots"
for state in desktop mobile empty loading error hover focus; do printf '%s' image > "$ROOT/shots/$state.png"; done
EVIDENCE="$TEST_TMPDIR/evidence.json"; CONTRACT="$TEST_TMPDIR/contract.json"; OUT="$TEST_TMPDIR/visual-verdict.json"
cat > "$EVIDENCE" <<'JSON'
{"schema":1,"root":"PROJECT_ROOT","screenshots":[
 {"surface":"home","viewport":"desktop","state":"default","path":"shots/desktop.png"},
 {"surface":"home","viewport":"mobile","state":"default","path":"shots/mobile.png"},
 {"surface":"home","viewport":"desktop","state":"empty","path":"shots/empty.png"},
 {"surface":"home","viewport":"desktop","state":"loading","path":"shots/loading.png"},
 {"surface":"home","viewport":"desktop","state":"error","path":"shots/error.png"},
 {"surface":"home","viewport":"desktop","state":"hover","path":"shots/hover.png"},
 {"surface":"home","viewport":"desktop","state":"focus","path":"shots/focus.png"}],
 "flow":[{"surface":"home","action":"open","result":"detail"}],"texts":["Original copy"],"assets":["own.svg"],"generic_patterns":[],
 "lenses":[{"lens":"originality","status":"passed","findings":[]},{"lens":"fit_polish","status":"passed","findings":[]},{"lens":"accessibility","status":"passed","findings":[]}]}
JSON
sed "s|PROJECT_ROOT|$ROOT|" "$EVIDENCE" > "$EVIDENCE.tmp" && mv "$EVIDENCE.tmp" "$EVIDENCE"
printf '%s\n' '{"prohibited_text":["Copied launch copy"],"prohibited_assets":["brand-logo.svg"]}' > "$CONTRACT"

assert_eq "visual-quality-all-lenses-must-pass" "passed" "$("$QUALITY" run "$EVIDENCE" "$CONTRACT" "$OUT" 2>/dev/null && jq -r .status "$OUT")"
assert_ok "visual-quality-writes-promotion-verdict" test -s "$OUT"

# The visual loop itself is promoted only when a ten-prompt corpus records a
# decisive new-workflow win on at least 70% of prompts and no accessibility loss.
CORPUS="$TEST_TMPDIR/corpus.json"; BENCHMARK_OUT="$TEST_TMPDIR/benchmark.json"
cat > "$CORPUS" <<'JSON'
{"schema":1,"prompts":[
 {"id":"p1","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p2","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p3","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p4","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p5","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p6","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p7","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p8","old":{"distinction":7,"polish":7,"accessibility":9},"new":{"distinction":4,"polish":4,"accessibility":9}},
 {"id":"p9","old":{"distinction":7,"polish":7,"accessibility":9},"new":{"distinction":4,"polish":4,"accessibility":9}},
 {"id":"p10","old":{"distinction":7,"polish":7,"accessibility":9},"new":{"distinction":4,"polish":4,"accessibility":9}}]}
JSON
assert_eq "visual-benchmark-requires-seventy-percent-decisive-wins" "passed" "$("$QUALITY" benchmark "$CORPUS" "$BENCHMARK_OUT" 2>/dev/null && jq -r .status "$BENCHMARK_OUT")"

jq '.prompts[0].new.accessibility = 8' "$CORPUS" > "$CORPUS.tmp" && mv "$CORPUS.tmp" "$CORPUS"
assert_fail "visual-benchmark-rejects-accessibility-regression" "$QUALITY" benchmark "$CORPUS" "$BENCHMARK_OUT"
finish
