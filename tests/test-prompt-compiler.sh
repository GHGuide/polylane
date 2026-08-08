#!/usr/bin/env bash
# Frozen semantic compiler fixtures: optimize without losing any hard contract.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
PROMPTOPT="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-promptopt.sh"
ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
FIXTURES="$ROOT/benchmarks/prompt-optimization/fixtures"

make_tmpdir
SOURCE="$FIXTURES/valid-source.txt"
COMPILED="$TEST_TMPDIR/compiled.txt"
"$PROMPTOPT" compile "$SOURCE" > "$COMPILED"

assert_ok "compiler-compiled-prompt-checks" "$PROMPTOPT" check "$COMPILED" 10000
assert_eq "compiler-goal-exactly-once" "1" "$(grep -c '^GOAL:' "$COMPILED")"
assert_eq "compiler-duplicate-material-collapsed" "1" "$(grep -c '^Keep the hard contracts truthful\.$' "$COMPILED")"
assert_contains "compiler-preserves-predefined-skills" \
  "superpowers:test-driven-development superpowers:verification-before-completion" "$(cat "$COMPILED")"
assert_contains "compiler-preserves-lane-skills" \
  "caveman:caveman-compress product-management:write-spec" "$(cat "$COMPILED")"

out=$("$PROMPTOPT" compile "$FIXTURES/contradictory.txt" 2>&1 || true)
assert_contains "compiler-names-conflicting-label" "GOAL" "$out"
assert_contains "compiler-names-conflicting-values" "Remove safety checks" "$out"
assert_fail "compiler-rejects-conflicting-scalar" "$PROMPTOPT" compile "$FIXTURES/contradictory.txt"

out=$("$PROMPTOPT" compile "$FIXTURES/duplicate-label.txt" 2>&1 || true)
assert_contains "compiler-names-duplicate-label" "GOAL" "$out"
assert_fail "compiler-rejects-duplicate-exact-once" "$PROMPTOPT" compile "$FIXTURES/duplicate-label.txt"

assert_fail "compiler-rejects-missing-contract" "$PROMPTOPT" compile "$FIXTURES/missing-contract.txt"
assert_fail "compiler-rejects-over-budget" "$PROMPTOPT" check "$FIXTURES/over-budget.txt" 1

finish
