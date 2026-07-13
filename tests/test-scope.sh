#!/usr/bin/env bash
# polylane-scope.sh — own_globs isolation: path-in-scope, pairwise overlap, witness.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
SCOPE="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-scope.sh"
. "$SCOPE"

# pure matchers
assert_ok   "scope-in"        path_in_any "src/alpha/x.js"            "src/alpha/**"
assert_ok   "scope-in-deep"   path_in_any "src/alpha/a/b/c.js"        "src/alpha/**"
assert_fail "scope-out"       path_in_any "src/beta/y.js"             "src/alpha/**"
assert_ok   "scope-overlap-nested"  globs_overlap "src/**"        "src/api/**"
assert_ok   "scope-overlap-samefile" globs_overlap "shared/x.js" "shared/x.js"
assert_fail "scope-disjoint-dirs"   globs_overlap "src/alpha/**" "src/beta/**"
assert_fail "scope-disjoint-ext"    globs_overlap "src/*.js"     "src/*.ts"

command -v jq >/dev/null 2>&1 || { pass "scope-manifest-skipped-no-jq"; finish; exit 0; }
make_tmpdir
# clean manifest -> check-static passes; check-lane accepts in-scope, rejects out
cat > "$TEST_TMPDIR/ok.json" <<'JSON'
{"lanes":[{"name":"a","own_globs":["src/alpha/**"]},{"name":"b","own_globs":["src/beta/**"]}]}
JSON
assert_ok   "scope-static-clean"    "$SCOPE" check-static "$TEST_TMPDIR/ok.json"
assert_ok   "scope-lane-in-scope"   "$SCOPE" check-lane   "$TEST_TMPDIR/ok.json" a "src/alpha/x.js"
assert_fail "scope-lane-out-scope"  "$SCOPE" check-lane   "$TEST_TMPDIR/ok.json" a "src/beta/y.js"
# overlapping manifest -> static fails with a witness pair
cat > "$TEST_TMPDIR/bad.json" <<'JSON'
{"lanes":[{"name":"a","own_globs":["src/**"]},{"name":"b","own_globs":["src/api/**"]}]}
JSON
assert_fail "scope-static-overlap"  "$SCOPE" check-static "$TEST_TMPDIR/bad.json"
assert_contains "scope-overlap-witness" "SCOPE-OVERLAP" "$("$SCOPE" check-static "$TEST_TMPDIR/bad.json" 2>&1)"
# empty own_globs -> static fails
cat > "$TEST_TMPDIR/empty.json" <<'JSON'
{"lanes":[{"name":"a","own_globs":[]}]}
JSON
assert_fail "scope-static-empty"    "$SCOPE" check-static "$TEST_TMPDIR/empty.json"
finish
