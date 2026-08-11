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
ULTIMATE-GOAL: build the product from a brief to verified completion. CURRENT-SUBGOAL: prompt economy.
GOAL: preserve every strict prompt contract.
OWN: src/x. FORBIDDEN: everything else.
DONE-SIGNAL: STATUS: x DONE run=<RUN_ID>. Write docs/verify-x.md with proof.
PREDEFINED-SKILLS: engineering:debug
LANE-SPECIFIC-SKILLS: design:accessibility-review
Read only the named kit once; do not browse skill inventories after launch.
TEST-CADENCE: focused while iterating; subsystem before DONE; full only in integrator.
DELEGATION: forbidden; this tmux Codex CLI is the only agent for the lane.
CHECK-CACHE: use bin/polylane-check.sh "$PWD/.polylane/check-cache/x" -- <command>; never rerun unchanged expensive checks.
EXTERNAL-EVIDENCE: missing people, credentials, hardware, or third-party access stays EXTERNAL-EVIDENCE-OPEN and never becomes PASS.
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
miss_test ultimate   'ULTIMATE-GOAL'
miss_test subgoal    'CURRENT-SUBGOAL'
miss_test own        'OWN'
miss_test forbidden  'FORBIDDEN'
miss_test nonce      'run='
miss_test verify     'verify'

POLYLANE_STRICT_PROMPTS=1 assert_ok "lint-strict-good" lint_one "$GOOD" x
cat >> "$GOOD" <<'P'
GOAL: duplicate exact-once label.
P
POLYLANE_STRICT_PROMPTS=1 assert_fail "lint-strict-rejects-duplicate-exact-once-label" lint_one "$GOOD" x
sed -i.bak '$d' "$GOOD"
STRICT_BAD="$TEST_TMPDIR/strict-bad.txt"
grep -v 'TEST-CADENCE' "$GOOD" > "$STRICT_BAD"
POLYLANE_STRICT_PROMPTS=1 assert_fail "lint-strict-missing-cadence" lint_one "$STRICT_BAD" x
grep -v 'DELEGATION:' "$GOOD" > "$TEST_TMPDIR/strict-no-delegation.txt"
POLYLANE_STRICT_PROMPTS=1 assert_fail "lint-strict-missing-delegation" lint_one "$TEST_TMPDIR/strict-no-delegation.txt" x
grep -v 'CHECK-CACHE:' "$GOOD" > "$TEST_TMPDIR/strict-no-cache.txt"
POLYLANE_STRICT_PROMPTS=1 assert_fail "lint-strict-missing-cache" lint_one "$TEST_TMPDIR/strict-no-cache.txt" x
sed 's#\$PWD/.polylane/check-cache/x#/tmp/check-cache/x#' "$GOOD" > "$TEST_TMPDIR/strict-nonlocal-cache.txt"
POLYLANE_STRICT_PROMPTS=1 assert_fail "lint-strict-rejects-nonlocal-cache" lint_one "$TEST_TMPDIR/strict-nonlocal-cache.txt" x
sed 's/Read only the named kit once; do not browse skill inventories after launch./Browse all installed skills before editing./' "$GOOD" > "$TEST_TMPDIR/strict-inventory-dump.txt"
POLYLANE_STRICT_PROMPTS=1 assert_fail "lint-strict-rejects-inventory-dump" lint_one "$TEST_TMPDIR/strict-inventory-dump.txt" x

RUNTIME_GOOD="$TEST_TMPDIR/runtime-good.txt"
cp "$GOOD" "$RUNTIME_GOOD"
cat >> "$RUNTIME_GOOD" <<'P'
POLYLANE-RUNTIME-RELAY: run `COORD="$POLYLANE_PROJECT_ROOT/bin/polylane-coordinate.sh"; "$COORD" pending "$POLYLANE_COORDINATION_FILE"`; docs/parallel-status.md is post-cycle evidence only, never the live relay.
POLYLANE-RUNTIME-ROOTS: source edits/tests/Graphify use "$POLYLANE_SOURCE_ROOT" (query `${POLYLANE_SOURCE_ROOT:-$PWD}/graphify-out/q.py`); coordination/workers/harness use "$POLYLANE_PROJECT_ROOT".
POLYLANE-RUNTIME-DONE: write only docs/status-x.md; first line exactly `STATUS: x DONE run=run-1`.
POLYLANE-RUNTIME-FINALIZE: immediately before completion, run the final relay and durable inbox read; handle all addressed autonomous work; run focused verification; scope-stage every owned changed or new file with `git add <your files>`; commit implementation and evidence; verify `git status --short` contains only runner-owned `.polylane-prompt.txt` and `graphify-out`; only then write the current-run status file and integrator verdict, force-add ignored status files with `git add -f`, commit that final handoff, and immediately exit. No reads, tests, edits, relay decisions, or commits may follow the marker/verdict commit.
P
POLYLANE_STRICT_PROMPTS=1 POLYLANE_RUNTIME_COMPILED=1 assert_ok \
  "lint-runtime-builder-canonical-status-path" lint_one "$RUNTIME_GOOD" x false builder
POLYLANE_STRICT_PROMPTS=1 POLYLANE_RUNTIME_COMPILED=1 POLYLANE_WRITE_PLAN_CONTRACT=1 assert_fail \
  "lint-runtime-write-plan-requires-boundary" lint_one "$RUNTIME_GOOD" x false builder
printf '%s\n' 'PLANNED-WRITES: docs/status-x.md, src/x.' >> "$RUNTIME_GOOD"
POLYLANE_STRICT_PROMPTS=1 POLYLANE_RUNTIME_COMPILED=1 POLYLANE_WRITE_PLAN_CONTRACT=1 assert_ok \
  "lint-runtime-write-plan-accepts-boundary" lint_one "$RUNTIME_GOOD" x false builder
grep -v 'POLYLANE-RUNTIME-ROOTS:' "$RUNTIME_GOOD" > "$TEST_TMPDIR/runtime-no-roots.txt"
POLYLANE_STRICT_PROMPTS=1 POLYLANE_RUNTIME_COMPILED=1 assert_fail \
  "lint-runtime-requires-source-control-roots-contract" lint_one "$TEST_TMPDIR/runtime-no-roots.txt" x false builder
grep -v 'POLYLANE-RUNTIME-FINALIZE:' "$RUNTIME_GOOD" > "$TEST_TMPDIR/runtime-no-finalize.txt"
POLYLANE_STRICT_PROMPTS=1 POLYLANE_RUNTIME_COMPILED=1 assert_fail \
  "lint-runtime-requires-finalize-contract" lint_one "$TEST_TMPDIR/runtime-no-finalize.txt" x false builder
sed 's/run focused verification; scope-stage every owned changed or new file/scope-stage every owned changed or new file; run focused verification/' \
  "$RUNTIME_GOOD" > "$TEST_TMPDIR/runtime-reordered-finalize.txt"
POLYLANE_STRICT_PROMPTS=1 POLYLANE_RUNTIME_COMPILED=1 assert_fail \
  "lint-runtime-rejects-reordered-finalize-contract" lint_one "$TEST_TMPDIR/runtime-reordered-finalize.txt" x false builder
cp "$RUNTIME_GOOD" "$TEST_TMPDIR/runtime-wrong-status.txt"
printf '%s\n' 'Also write docs/status-short.md before completion.' >> "$TEST_TMPDIR/runtime-wrong-status.txt"
POLYLANE_STRICT_PROMPTS=1 POLYLANE_RUNTIME_COMPILED=1 assert_fail \
  "lint-runtime-builder-rejects-conflicting-status-path" lint_one "$TEST_TMPDIR/runtime-wrong-status.txt" x false builder
printf '%s\n' 'Run "$POLYLANE_PROJECT_ROOT/bin/polylane-refine.sh" propose-or-decline "$POLYLANE_HARNESS_DIR".' >> "$RUNTIME_GOOD"
POLYLANE_STRICT_PROMPTS=1 POLYLANE_RUNTIME_COMPILED=1 assert_fail \
  "lint-runtime-rejects-fictional-refine-subcommand" lint_one "$RUNTIME_GOOD" x false builder

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

  cp "$GOOD" "$TEST_TMPDIR/.polylane/lanes/prime.txt"
  cat >> "$TEST_TMPDIR/.polylane/lanes/prime.txt" <<'P'
Read POLYLANE_CONTEXT_PACKET exactly once. Use the durable inbox through
"$POLYLANE_PROJECT_ROOT/bin/polylane-workers.sh" inbox "$POLYLANE_PROJECT_ROOT" "$POLYLANE_WORKER_ID" for follow-ups.
P
  cp "$TEST_TMPDIR/.polylane/lanes/prime.txt" "$TEST_TMPDIR/.polylane/lanes/prime-integrator.txt"
  cat >> "$TEST_TMPDIR/.polylane/lanes/prime-integrator.txt" <<'P'
Run "$POLYLANE_PROJECT_ROOT/bin/polylane-refine.sh" queue "$POLYLANE_HARNESS_DIR", then exactly one real `propose` or `decline` for every eligible refinement queue item; `propose-or-decline` is NOT a subcommand.
P
  cat > "$TEST_TMPDIR/.polylane/prime.json" <<'JSON'
{"base":"main","prime_hybrid":true,"lanes":[{"name":"prime","prompt_file":".polylane/lanes/prime.txt"}],"integrator":{"name":"prime-integrator","prompt_file":".polylane/lanes/prime-integrator.txt"}}
JSON
  assert_ok "lint-prime-hybrid-continuity" "$LINT" lint-run "$TEST_TMPDIR/.polylane/prime.json"
  sed 's#"\$POLYLANE_PROJECT_ROOT/bin/polylane-workers.sh" inbox "\$POLYLANE_PROJECT_ROOT" "\$POLYLANE_WORKER_ID"#"$POLYLANE_PROJECT_ROOT/bin/polylane-workers.sh" inbox "$POLYLANE_WORKER_ID" "$POLYLANE_PROJECT_ROOT"#' "$TEST_TMPDIR/.polylane/lanes/prime.txt" > "$TEST_TMPDIR/.polylane/lanes/prime-wrong-order.txt"
  sed 's#prime.txt#prime-wrong-order.txt#' "$TEST_TMPDIR/.polylane/prime.json" > "$TEST_TMPDIR/.polylane/prime-wrong-order.json"
  assert_fail "lint-prime-hybrid-requires-exact-inbox-command-order" "$LINT" lint-run "$TEST_TMPDIR/.polylane/prime-wrong-order.json"
  grep -v 'durable inbox' "$TEST_TMPDIR/.polylane/lanes/prime.txt" > "$TEST_TMPDIR/.polylane/lanes/prime-missing.txt"
  sed 's#prime.txt#prime-missing.txt#' "$TEST_TMPDIR/.polylane/prime.json" > "$TEST_TMPDIR/.polylane/prime-missing.json"
  assert_fail "lint-prime-hybrid-requires-inbox" "$LINT" lint-run "$TEST_TMPDIR/.polylane/prime-missing.json"
  grep -v 'exactly one real' "$TEST_TMPDIR/.polylane/lanes/prime-integrator.txt" > "$TEST_TMPDIR/.polylane/lanes/prime-integrator-missing.txt"
  sed 's#prime-integrator.txt#prime-integrator-missing.txt#' "$TEST_TMPDIR/.polylane/prime.json" > "$TEST_TMPDIR/.polylane/prime-integrator-missing.json"
  assert_fail "lint-prime-hybrid-requires-integrator-refinement-decision" \
    "$LINT" lint-run "$TEST_TMPDIR/.polylane/prime-integrator-missing.json"
else pass "lint-run-skipped-no-jq"; fi

finish
