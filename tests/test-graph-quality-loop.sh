#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
GRAPH="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-graph.sh"
make_tmpdir
M="$TEST_TMPDIR/manifest.json"; G="$TEST_TMPDIR/graph.json"
cat > "$M" <<'JSON'
{"orchestration_contract":2,"run_id":"quality-loop","cycle":1,"target_subgoals":["g"],"integrator":{"name":"i","model":"m","effort":"high"},"lanes":[{"name":"a","model":"m","effort":"high","own_globs":["src/**"],"target_subgoals":["g"]}],"quality_judges":[{"name":"tests","lens":"correctness","command":"true","timeout_s":1},{"name":"security","lens":"security","command":"true","timeout_s":1},{"name":"ux","lens":"usability","command":"true","timeout_s":1}]}
JSON
assert_ok "quality-graph-compiles" "$GRAPH" compile "$M" "$G"
assert_eq "quality-graph-has-judge-boundary" "2" "$(jq '[.nodes[] | select(.id=="judges" or .id=="judge-repair")] | length' "$G")"
assert_eq "quality-graph-single-repair-loop" "1" "$(jq '[.loops[] | select(.from=="judge-repair" and .to=="judges" and .max_iterations==1)] | length' "$G")"
assert_ok "quality-graph-valid" "$GRAPH" validate "$G"

# The visual gate is opt-in: requesting it creates a bounded two-repair route
# before ordinary promotion, while legacy quality-judge graphs remain unchanged.
jq '.visual_quality=true' "$M" > "$TEST_TMPDIR/visual-manifest.json"
assert_ok "visual-quality-graph-compiles-on-explicit-request" "$GRAPH" compile "$TEST_TMPDIR/visual-manifest.json" "$TEST_TMPDIR/visual-graph.json"
assert_eq "visual-quality-graph-has-gate-and-repair" "2" "$(jq '[.nodes[] | select(.id=="visual-quality" or .id=="visual-repair")] | length' "$TEST_TMPDIR/visual-graph.json")"
assert_eq "visual-quality-graph-allows-two-targeted-repairs" "1" "$(jq '[.loops[] | select(.from=="visual-repair" and .to=="visual-quality" and .max_iterations==2)] | length' "$TEST_TMPDIR/visual-graph.json")"
finish
