#!/usr/bin/env bash
# Contract v2 prevents an apparently valid Codex run from launching with no
# durable route, acceptance, skill kits, prompt discipline, or cycle artifacts.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

command -v jq >/dev/null 2>&1 || { pass "contract-skipped-no-jq"; finish; exit 0; }
make_tmpdir
P="$TEST_TMPDIR/project"
mkdir -p "$P/.polylane/lanes" "$P/docs/polylane" "$P/skills/testing-strategy" \
  "$P/skills/debug" "$P/skills/computer-use" "$P/skills/accessibility-review"
export CODEX_SKILLS_DIR="$P/skills"

STATE="$P/docs/polylane/max-state.json"
"$(dirname "$RUNNER")/polylane-memory.sh" "$STATE" init "ship" >/dev/null
"$(dirname "$RUNNER")/polylane-memory.sh" "$STATE" add-criterion c1 "works" >/dev/null
"$(dirname "$RUNNER")/polylane-memory.sh" "$STATE" add-milestone m1 "build" >/dev/null
"$(dirname "$RUNNER")/polylane-memory.sh" "$STATE" add-subgoal m1 s1 "feature" 10 >/dev/null
"$(dirname "$RUNNER")/polylane-memory.sh" "$STATE" add-accept s1 true >/dev/null

PROMPT="$P/.polylane/lanes/builder.txt"
cat > "$PROMPT" <<'PROMPT'
ULTIMATE-GOAL: ship a complete, verified product.
CURRENT-SUBGOAL: feature works.
GOAL: ship the feature.
OWN: src/**. FORBIDDEN: everything else.
PREDEFINED-SKILLS: testing-strategy debug
LANE-SPECIFIC-SKILLS: computer-use accessibility-review
Read only the named kit once; do not enumerate or rediscover skills.
TEST-CADENCE: focused first; subsystem before DONE; full suite only in integration.
DELEGATION: forbidden; do not spawn subagents or fan-out.
CHECK-CACHE: use polylane-check.sh with $PWD/.polylane/check-cache/ for expensive checks; reuse unchanged results.
EXTERNAL-EVIDENCE: keep physical-only proof external; continue all autonomous work.
Write docs/verify-builder.md. Finish STATUS: builder DONE run=run-1.
PROMPT
cat > "$P/.polylane/lanes/integrator.txt" <<'PROMPT'
ULTIMATE-GOAL: ship a complete, verified product.
CURRENT-SUBGOAL: feature works.
GOAL: integrate the feature.
OWN: integrator branch. FORBIDDEN: base branch.
PREDEFINED-SKILLS: testing-strategy debug
LANE-SPECIFIC-SKILLS: computer-use accessibility-review
Read only the named kit once; do not enumerate or rediscover skills.
TEST-CADENCE: focused failures first; full terminal suite once.
DELEGATION: forbidden; do not spawn subagents or fan-out.
CHECK-CACHE: use polylane-check.sh with $PWD/.polylane/check-cache/ for expensive checks; reuse unchanged results.
EXTERNAL-EVIDENCE: keep physical-only proof external; continue autonomous work.
Write docs/verify-integration.md ending POLYLANE-VERDICT: GO run=run-1.
Finish STATUS: integrator DONE run=run-1.
PROMPT
printf '# cycle plan\n' > "$P/docs/polylane/cycle-1-plan.md"
printf '# index\n' > "$P/docs/polylane/INDEX.md"

KIT="$P/.polylane/lane-skills.json"
SCOUT="$(dirname "$RUNNER")/polylane-scout.sh"
"$SCOUT" arm-role "$KIT" builder predefined testing-strategy debug
"$SCOUT" arm-role "$KIT" builder specific computer-use accessibility-review

MANIFEST="$P/.polylane/run.json"
cat > "$MANIFEST" <<JSON
{
  "orchestration_contract": 2,
  "run_id": "run-1",
  "cycle": 1,
  "state_file": "docs/polylane/max-state.json",
  "lane_skills_file": ".polylane/lane-skills.json",
  "cycle_plan_file": "docs/polylane/cycle-1-plan.md",
  "target_subgoals": ["s1"],
  "base": "main",
  "agent": "codex",
  "integrator": {
    "name":"integrator","model":"gpt","branch":"lane/integrator",
    "worktree":"$P/.polylane/wt/integrator",
    "prompt_file":".polylane/lanes/integrator.txt"
  },
  "lanes": [{
    "name":"builder","model":"gpt","branch":"lane/builder",
    "worktree":"$P/.polylane/wt/builder",
    "prompt_file":".polylane/lanes/builder.txt",
    "own_globs":["src/**"],"target_subgoals":["s1"]
  }]
}
JSON

MANIFEST="$MANIFEST"
load_manifest
assert_ok "contract-valid-before-launch" preflight_contract

BAD="$P/.polylane/legacy.json"
jq 'del(.orchestration_contract)' "$MANIFEST" > "$BAD"
MANIFEST="$BAD"; load_manifest
assert_rc "codex-legacy-rejected" 2 preflight_contract

mkdir -p "$P/.polylane/wt/builder"
RESUME=1
assert_ok "codex-existing-legacy-resume-grandfathered" preflight_contract
RESUME=0

MANIFEST="$P/.polylane/run.json"; load_manifest
grep -v 'TEST-CADENCE:' "$PROMPT" > "$P/.polylane/lanes/builder-bad.txt"
jq '.lanes[0].prompt_file=".polylane/lanes/builder-bad.txt"' "$MANIFEST" > "$P/.polylane/bad-prompt.json"
MANIFEST="$P/.polylane/bad-prompt.json"; load_manifest
assert_rc "contract-rejects-weak-prompt" 2 preflight_contract

finish
