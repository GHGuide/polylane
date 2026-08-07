#!/usr/bin/env bash
# Real-agent skill evaluation adapters, exercised through deterministic response seams.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADAPTER="$ROOT/bin/polylane-skill-agent-eval.sh"
JUDGE="$ROOT/bin/polylane-skill-blind-judge.sh"
EVOLVE="$ROOT/bin/polylane-skill-evolve.sh"
DEFAULT_EVALS="$ROOT/benchmarks/skill-evolution/polylane/evals.json"

make_tmpdir
SKILL="$TEST_TMPDIR/skill"; WORK="$TEST_TMPDIR/work"; mkdir -p "$SKILL" "$WORK"
printf '%s\n' '---' 'name: demo' 'description: Use when a cycle must continue.' '---' '' '# Demo' > "$SKILL/SKILL.md"

CASE="$TEST_TMPDIR/case.json"
jq -n '{id:"continue",split:"dev",scenario:"A GO verdict arrived but route says CONTINUE.",
  required:["CONTINUE"],required_any:[["next cycle","following cycle"]],
  hard_required:["CONTINUE"],hard_required_any:[["launch","start"]],forbidden:["stop now"]}' > "$CASE"
RESULT="$WORK/result.json"
POLYLANE_SKILL_PATH="$SKILL" POLYLANE_SKILL_EVAL_CASE="$CASE" \
POLYLANE_SKILL_EVAL_RESULT="$RESULT" POLYLANE_SKILL_EVAL_WORKDIR="$WORK" \
POLYLANE_SKILL_EVAL_MODEL=default POLYLANE_SKILL_EVAL_EFFORT=high \
POLYLANE_SKILL_EVAL_VARIANT=candidate POLYLANE_SKILL_EVAL_REPEAT=1 \
POLYLANE_SKILL_EVAL_RESPONSE='Take CONTINUE and launch the next cycle.' \
  "$ADAPTER"
assert_eq "skill-agent-eval-perfect-score" "1" "$(jq -r '.score' "$RESULT")"
assert_eq "skill-agent-eval-no-hard-failure" "false" "$(jq -r '.hard_fail' "$RESULT")"
assert_eq "skill-agent-eval-records-zero-interventions" "0" "$(jq -r '.interventions' "$RESULT")"
assert_eq "skill-agent-eval-counts-alternative-group-once" "3" "$(jq -r '.assertions_total' "$RESULT")"
assert_ok "skill-agent-eval-records-token-proxy" jq -e '.tokens > 0 and .duration_ms >= 0' "$RESULT"

POLYLANE_SKILL_PATH="$SKILL" POLYLANE_SKILL_EVAL_CASE="$CASE" \
POLYLANE_SKILL_EVAL_RESULT="$RESULT" POLYLANE_SKILL_EVAL_WORKDIR="$WORK" \
POLYLANE_SKILL_EVAL_MODEL=default POLYLANE_SKILL_EVAL_EFFORT=high \
POLYLANE_SKILL_EVAL_VARIANT=candidate POLYLANE_SKILL_EVAL_REPEAT=1 \
POLYLANE_SKILL_EVAL_RESPONSE='Take CONTINUE, but wait.' \
  "$ADAPTER"
assert_eq "skill-agent-eval-hard-alternative-group-fails" "true" "$(jq -r '.hard_fail' "$RESULT")"

POLYLANE_SKILL_PATH="$SKILL" POLYLANE_SKILL_EVAL_CASE="$CASE" \
POLYLANE_SKILL_EVAL_RESULT="$RESULT" POLYLANE_SKILL_EVAL_WORKDIR="$WORK" \
POLYLANE_SKILL_EVAL_MODEL=default POLYLANE_SKILL_EVAL_EFFORT=high \
POLYLANE_SKILL_EVAL_VARIANT=candidate POLYLANE_SKILL_EVAL_REPEAT=1 \
POLYLANE_SKILL_EVAL_RESPONSE='Stop now.' \
  "$ADAPTER"
assert_eq "skill-agent-eval-hard-required-fails" "true" "$(jq -r '.hard_fail' "$RESULT")"
assert_eq "skill-agent-eval-forbidden-lowers-score" "0" "$(jq -r '.score' "$RESULT")"

mkdir -p "$TEST_TMPDIR/A" "$TEST_TMPDIR/B" "$TEST_TMPDIR/judge"
cp "$SKILL/SKILL.md" "$TEST_TMPDIR/A/SKILL.md"
cp "$SKILL/SKILL.md" "$TEST_TMPDIR/B/SKILL.md"
JRESULT="$TEST_TMPDIR/judge/result.json"
POLYLANE_SKILL_BLIND_A_PATH="$TEST_TMPDIR/A" POLYLANE_SKILL_BLIND_B_PATH="$TEST_TMPDIR/B" \
POLYLANE_SKILL_JUDGE_RESULT="$JRESULT" POLYLANE_SKILL_JUDGE_WORKDIR="$TEST_TMPDIR/judge" \
POLYLANE_SKILL_JUDGE_EVALS="$DEFAULT_EVALS" POLYLANE_SKILL_JUDGE_NAME=product \
POLYLANE_SKILL_EVAL_MODEL=default POLYLANE_SKILL_EVAL_EFFORT=high \
POLYLANE_SKILL_JUDGE_RESPONSE='{"winner":"A","confidence":0.8,"reason":"clearer"}' \
  "$JUDGE"
assert_eq "skill-blind-judge-preserves-label" "A" "$(jq -r '.winner' "$JRESULT")"
assert_eq "skill-blind-judge-valid-result" "false" "$(jq -r '.hard_fail' "$JRESULT")"
assert_ok "skill-default-evals-validate" "$EVOLVE" validate "$DEFAULT_EVALS"

finish
