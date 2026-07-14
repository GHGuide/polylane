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

# B13: an integrator-less manifest must not phantom-lint a "null" lane / grep a dir
if command -v jq >/dev/null 2>&1; then
  mkdir -p "$TEST_TMPDIR/.polylane/lanes"
  cp "$GOOD" "$TEST_TMPDIR/.polylane/lanes/only.txt"
  cat > "$TEST_TMPDIR/.polylane/run.json" <<'JSON'
{"base":"main","lanes":[{"name":"only","prompt_file":".polylane/lanes/only.txt"}]}
JSON
  out=$("$LINT" lint-run "$TEST_TMPDIR/.polylane/run.json" 2>&1); rc=$?
  assert_eq "lint-run-no-integrator-rc0" "0" "$rc"
  if printf '%s' "$out" | grep -qiE 'Is a directory|null'; then fail "lint-run-clean-stderr" "$out"; else pass "lint-run-clean-stderr"; fi
else pass "lint-run-skipped-no-jq"; fi

finish
