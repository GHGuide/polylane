#!/usr/bin/env bash
# polylane-promptlint.sh — a generated lane prompt must carry the validated structure
# (objective, OWN/FORBIDDEN, nonce DONE marker, verify). Catches the orchestrator
# dropping a block (the real marker-drift / missing-boundary bugs) before launch.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
LINT="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-promptlint.sh"
. "$LINT"

make_tmpdir
GOOD="$TEST_TMPDIR/good.txt"
cat > "$GOOD" <<'P'
/goal build the thing. OWN: src/x. FORBIDDEN: everything else.
DONE-SIGNAL: STATUS: x DONE run=<RUN_ID>. Write docs/verify-x.md with proof.
P
assert_ok "lint-good" lint_one "$GOOD" x

# each missing element fails with a named gap
miss_test() {
  local name="$1" drop="$2"
  local f="$TEST_TMPDIR/$name.txt"
  grep -viE "$drop" "$GOOD" > "$f" || true
  assert_fail "lint-missing-$name" lint_one "$f" "$name"
}
miss_test objective  'GOAL|/goal'
miss_test own        'OWN'
miss_test forbidden  'FORBIDDEN'
miss_test nonce      'run='
miss_test verify     'verify'

# the message names what's missing
out=$(lint_one "$TEST_TMPDIR/nonce.txt" nonce 2>&1 || true)
assert_contains "lint-names-gap" "nonce(run=" "$out"

# empty prompt fails
: > "$TEST_TMPDIR/empty.txt"
assert_fail "lint-empty" lint_one "$TEST_TMPDIR/empty.txt" e

finish
