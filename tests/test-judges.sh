#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

JUDGES="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-judges.sh"
make_tmpdir
M="$TEST_TMPDIR/manifest.json"; TREE="$TEST_TMPDIR/tree"; OUT="$TEST_TMPDIR/out"
mkdir -p "$TREE"
cat > "$M" <<'JSON'
{"quality_judges":[
 {"name":"unit","lens":"correctness","command":"test -d .","timeout_s":2},
 {"name":"security","lens":"security","command":"test -f missing","timeout_s":2},
 {"name":"ux","lens":"usability","command":"printf usable","timeout_s":2}
]}
JSON
run_out=$("$JUDGES" run "$M" "$TREE" "$OUT" 2>&1); run_rc=$?
assert_eq "judges-fail-when-any-judge-fails" "1" "$run_rc"
assert_contains "judges-actionable-per-failure" "security (security) failed" "$run_out"
assert_eq "judges-three-isolated-evidence" "3" "$(find "$OUT" -name '*.evidence' | wc -l | tr -d ' ')"
assert_eq "judges-aggregate-status" "failed" "$(jq -r '.status' "$OUT/judges.json")"

jq '.quality_judges[0].command="sleep 2" | .quality_judges[0].timeout_s=1 | .quality_judges[1].command="true"' "$M" > "$TEST_TMPDIR/timeout.json"
timeout_out=$("$JUDGES" run "$TEST_TMPDIR/timeout.json" "$TREE" "$TEST_TMPDIR/timeout" 2>&1); timeout_rc=$?
assert_eq "judges-enforce-timeout" "1" "$timeout_rc"
assert_eq "judges-timeout-is-aggregated" "timeout" "$(jq -r '.judges[0].status' "$TEST_TMPDIR/timeout/judges.json")"

jq '.quality_judges[2].lens="security"' "$M" > "$TEST_TMPDIR/duplicate.json"
assert_rc "judges-reject-duplicate-lens" 2 "$JUDGES" run "$TEST_TMPDIR/duplicate.json" "$TREE" "$OUT"
finish
