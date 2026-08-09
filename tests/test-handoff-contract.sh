#!/usr/bin/env bash
# Atomic handoff: every advertised prompt source must state one executable,
# marker-last finalization transaction, and strict lint must reject omissions.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
LINT="$ROOT/bin/polylane-promptlint.sh"

make_tmpdir

contract='POLYLANE-RUNTIME-FINALIZE:'
ordered='POLYLANE-RUNTIME-FINALIZE: immediately before completion, run the final relay and durable inbox read; handle all addressed autonomous work; run focused verification; scope-stage every owned changed or new file with `git add <your files>`; commit implementation and evidence; verify `git status --short` contains only runner-owned `.polylane-prompt.txt` and `graphify-out`; only then write the current-run status file'
for f in references/prompt-blocks.md references/lane-template.md references/planning.md SKILL.md codex/SKILL.md; do
  body=$(cat "$ROOT/$f")
  assert_contains "handoff-contract-advertised-$f" "$contract" "$body"
  assert_contains "handoff-contract-ordered-$f" "$ordered" "$body"
  assert_contains "handoff-contract-exit-$f" "immediately exit" "$body"
  assert_contains "handoff-contract-scoped-add-$f" "git add <your files>" "$body"
  assert_contains "handoff-contract-builder-form-$f" "Builder final handoff:" "$body"
  assert_contains "handoff-contract-integrator-form-$f" "Integrator final handoff:" "$body"
done

assert_contains "handoff-contract-refinement-queue" \
  '"$POLYLANE_PROJECT_ROOT/bin/polylane-refine.sh" queue "$POLYLANE_HARNESS_DIR"' \
  "$(cat "$ROOT/references/prompt-blocks.md")"
for f in references/prompt-blocks.md references/lane-template.md references/planning.md SKILL.md codex/SKILL.md; do
  body=$(cat "$ROOT/$f")
  assert_contains "handoff-contract-refinement-executable-$f" \
    'then exactly one real `propose` or `decline`' "$body"
  assert_contains "handoff-contract-refinement-not-subcommand-$f" \
    '`propose-or-decline` is NOT a subcommand' "$body"
done
if rg -n 'polylane-refine\.sh propose-or-decline' \
  "$ROOT/SKILL.md" "$ROOT/codex/SKILL.md" "$ROOT/references"; then
  fail "handoff-contract-no-fictional-refine-subcommand" "advertised prompt invokes propose-or-decline"
else
  pass "handoff-contract-no-fictional-refine-subcommand"
fi

PROMPT="$TEST_TMPDIR/prompt.txt"
cat > "$PROMPT" <<'PROMPT'
GOAL: x
ULTIMATE-GOAL: x
CURRENT-SUBGOAL: x
OWN: x
FORBIDDEN: x
PREDEFINED-SKILLS: x
LANE-SPECIFIC-SKILLS: x
TEST-CADENCE: x
DELEGATION: forbidden
CHECK-CACHE: "$PWD/.polylane/check-cache/x"
EXTERNAL-EVIDENCE: none
VERIFY: x
STATUS: x DONE run=run-1
POLYLANE-RUNTIME-RELAY: COORD="$POLYLANE_PROJECT_ROOT/bin/polylane-coordinate.sh"; "$COORD" pending "$POLYLANE_COORDINATION_FILE"; docs/parallel-status.md is post-cycle evidence only, never the live relay.
POLYLANE-RUNTIME-DONE: write only docs/status-x.md; first line exactly `STATUS: x DONE run=run-1`.
PROMPT
POLYLANE_STRICT_PROMPTS=1 POLYLANE_RUNTIME_COMPILED=1 assert_fail \
  "handoff-contract-strict-lint-requires-finalize" "$LINT" lint "$PROMPT" x

finish
