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
# B6: cross-wildcard collision (single-witness probe missed this) — MUST flag overlap
assert_ok   "scope-overlap-cross-wildcard" globs_overlap "src/a/**" "src/*/shared.ts"
cat > "$TEST_TMPDIR/xw.json" <<'JSON'
{"lanes":[{"name":"a","own_globs":["src/a/**"]},{"name":"b","own_globs":["src/*/shared.ts"]}]}
JSON
assert_fail "scope-static-cross-wildcard" "$SCOPE" check-static "$TEST_TMPDIR/xw.json"

# Contract-v2 status ownership is exact: the lane must own its canonical marker,
# and no second/broad glob may cover any status marker path.
cat > "$TEST_TMPDIR/status-ok.json" <<'JSON'
{"lanes":[{"name":"a","own_globs":["src/a/**","docs/status-a.md"]},{"name":"b","own_globs":["src/b/**","docs/status-b.md"]}]}
JSON
assert_ok "scope-status-canonical" "$SCOPE" check-status "$TEST_TMPDIR/status-ok.json"
cat > "$TEST_TMPDIR/status-missing.json" <<'JSON'
{"lanes":[{"name":"long-lane","own_globs":["src/**","docs/status-short.md"]}]}
JSON
assert_fail "scope-status-rejects-shortened-marker" "$SCOPE" check-status "$TEST_TMPDIR/status-missing.json"
cat > "$TEST_TMPDIR/status-broad.json" <<'JSON'
{"lanes":[{"name":"a","own_globs":["docs/status-a.md","docs/**"]}]}
JSON
assert_fail "scope-status-rejects-broad-second-owner" "$SCOPE" check-status "$TEST_TMPDIR/status-broad.json"
cat > "$TEST_TMPDIR/status-duplicate.json" <<'JSON'
{"lanes":[{"name":"a","own_globs":["docs/status-a.md","docs/status-a.md"]}]}
JSON
assert_fail "scope-status-rejects-duplicate-canonical" "$SCOPE" check-status "$TEST_TMPDIR/status-duplicate.json"

# New generated plans opt in to exact write declarations.  The static gate must
# prove every declared write is safe, unique, and owned before launch side effects.
cat > "$TEST_TMPDIR/write-plan-ok.json" <<'JSON'
{"write_plan_contract":1,"lanes":[{"name":"a","own_globs":["src/a/**","docs/status-a.md"],"planned_writes":["src/a/one.sh","docs/status-a.md"]}]}
JSON
assert_ok "scope-write-plan-valid" "$SCOPE" check-static "$TEST_TMPDIR/write-plan-ok.json"
for bad in missing absolute traversal glob duplicate outside; do
  case "$bad" in
    missing) json='{"write_plan_contract":1,"lanes":[{"name":"a","own_globs":["src/a/**"]}]}' ;;
    absolute) json='{"write_plan_contract":1,"lanes":[{"name":"a","own_globs":["src/a/**"],"planned_writes":["/tmp/a"]}]}' ;;
    traversal) json='{"write_plan_contract":1,"lanes":[{"name":"a","own_globs":["src/a/**"],"planned_writes":["src/a/../b"]}]}' ;;
    glob) json='{"write_plan_contract":1,"lanes":[{"name":"a","own_globs":["src/a/**"],"planned_writes":["src/a/*.sh"]}]}' ;;
    duplicate) json='{"write_plan_contract":1,"lanes":[{"name":"a","own_globs":["src/a/**"],"planned_writes":["src/a/x","src/a/x"]}]}' ;;
    outside) json='{"write_plan_contract":1,"lanes":[{"name":"a","own_globs":["src/a/**"],"planned_writes":["src/b/x"]}]}' ;;
  esac
  printf '%s' "$json" > "$TEST_TMPDIR/write-plan-$bad.json"
  assert_fail "scope-write-plan-rejects-$bad" "$SCOPE" check-static "$TEST_TMPDIR/write-plan-$bad.json"
done

# Declared globs are data, not cwd-relative shell expansions. Exercise every
# production consumer from a checkout containing paths that would expand src/**.
EXPAND_ROOT="$TEST_TMPDIR/glob-expansion"
mkdir -p "$EXPAND_ROOT/src/a"
: > "$EXPAND_ROOT/src/a/existing.txt"
cat > "$EXPAND_ROOT/write-plan.json" <<'JSON'
{"write_plan_contract":1,"lanes":[{"name":"a","own_globs":["src/**"],"planned_writes":["src/new/file.txt"]}]}
JSON
cat > "$EXPAND_ROOT/overlap.json" <<'JSON'
{"lanes":[{"name":"a","own_globs":["src/**"]},{"name":"b","own_globs":["src/a/**"]}]}
JSON
SCOPE_START="$PWD"
cd "$EXPAND_ROOT"
assert_ok "scope-cwd-glob-does-not-break-write-plan" "$SCOPE" check-static "$EXPAND_ROOT/write-plan.json"
assert_ok "scope-cwd-glob-does-not-break-check-lane" "$SCOPE" check-lane "$EXPAND_ROOT/write-plan.json" a "src/new/file.txt"
assert_fail "scope-cwd-glob-does-not-hide-overlap" "$SCOPE" check-static "$EXPAND_ROOT/overlap.json"
cd "$SCOPE_START"

# A production-sized carve must not exhaust Bash 3.2's process-substitution job
# table.  The old static gate re-ran jq for every glob in every lane pair; fifteen
# five-glob lanes plus their write plan crossed the macOS Bash threshold and died
# with SIGTRAP (rc 133) before any worker could launch.
jq -n '{
  write_plan_contract: 1,
  lanes: [range(0; 15) as $lane | {
    name: "stress-\($lane)",
    own_globs: [range(0; 5) as $glob | "stress/\($lane)/g\($glob)/**"],
    planned_writes: [range(0; 7) as $write |
      "stress/\($lane)/g\($write % 5)/file-\($write).txt"]
  }]
}' > "$TEST_TMPDIR/production-size.json"
assert_ok "scope-static-production-size-no-sigtrap" \
  "$SCOPE" check-static "$TEST_TMPDIR/production-size.json"

# Pin the root cause as well as the symptom. Each lane's globs may be loaded once
# for the pairwise gate (plus once per planned write in the existing write-plan
# validator), but never once per glob/pair combination. The latter created 700+
# process substitutions in one Bash process and made SIGTRAP timing-dependent.
SCOPE_GLOB_CALLS="$TEST_TMPDIR/scope-glob-calls"
: > "$SCOPE_GLOB_CALLS"
_lane_globs() {
  printf x >> "$SCOPE_GLOB_CALLS"
  jq -r --arg n "$2" '.lanes[] | select(.name==$n) | .own_globs[]?' "$1"
}
assert_ok "scope-static-production-size-instrumented" \
  check_static "$TEST_TMPDIR/production-size.json"
scope_glob_call_count=$(wc -c < "$SCOPE_GLOB_CALLS" | tr -d ' ')
if [ "$scope_glob_call_count" -le 150 ]; then
  pass "scope-static-bounds-manifest-glob-loads"
else
  fail "scope-static-bounds-manifest-glob-loads" \
    "expected at most 150 lane-glob loads, got $scope_glob_call_count"
fi

finish
