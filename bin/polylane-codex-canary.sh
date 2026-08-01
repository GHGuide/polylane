#!/usr/bin/env bash
# polylane-codex-canary.sh — small real-Codex, real-tmux end-to-end forward test.
# Creates a throwaway git repo, runs one contract-v2 builder + integrator through
# the supervisor, proves the runtime attach line, acceptance, promotion, state,
# report, and cleanup. This spends two tiny Codex CLI calls.
#
# Env: POLYLANE_CANARY_MODEL (default gpt-5.6-terra)
#      POLYLANE_CANARY_KEEP=1 preserves the throwaway repo for diagnosis.
set -euo pipefail

BIN=$(cd "$(dirname "$0")" && pwd)
for dep in git jq tmux codex; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "codex-canary: missing $dep" >&2; exit 2
  }
done

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/polylane-codex-canary.XXXXXX")
SESSION="pl-codex-canary-$$"
MODEL="${POLYLANE_CANARY_MODEL:-gpt-5.6-terra}"
RUN_ID="canary-$(date +%s)-$$"

cleanup_canary() {
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  if [ "${POLYLANE_CANARY_KEEP:-0}" = "1" ]; then
    echo "codex-canary: kept $ROOT" >&2
  else
    rm -rf "$ROOT"
  fi
}
trap cleanup_canary EXIT

cd "$ROOT"
git init -q -b main
git config user.email polylane-canary@example.invalid
git config user.name "Polylane Canary"
printf '.polylane/\ndocs/status-*.md\ndocs/lane-logs/\n' > .gitignore
printf 'polylane codex canary\n' > README.md
git add .gitignore README.md
git commit -qm "canary seed"

mkdir -p .polylane/lanes docs/polylane
STATE="$ROOT/docs/polylane/max-state.json"
"$BIN/polylane-memory.sh" "$STATE" init "Prove real Codex tmux execution" >/dev/null
"$BIN/polylane-memory.sh" "$STATE" add-criterion c1 "canary promoted and verified" 10 >/dev/null
"$BIN/polylane-memory.sh" "$STATE" add-milestone m1 "real runtime" >/dev/null
"$BIN/polylane-memory.sh" "$STATE" add-subgoal m1 s1 "write exact canary artifact" 10 >/dev/null
"$BIN/polylane-memory.sh" "$STATE" add-accept s1 \
  "test -f canary/ok.txt && grep -qx 'POLYLANE CODEX CANARY OK' canary/ok.txt" >/dev/null
"$BIN/polylane-memory.sh" "$STATE" add-accept s1 \
  "test \"\$(cat canary/ok.txt)\" = 'POLYLANE CODEX CANARY OK'" --tier terminal >/dev/null
printf '# Canary cycle 1\n\nWrite and verify the exact canary artifact.\n' > docs/polylane/cycle-1-plan.md
printf '# Polylane index\n\n- [Cycle 1](cycle-1-plan.md)\n' > docs/polylane/INDEX.md

SKILLS=()
for skill in engineering:testing-strategy engineering:debug engineering:code-review \
  superpowers:executing-plans deep-research humanizer; do
  if "$BIN/polylane-scout.sh" installed "$skill"; then SKILLS+=("$skill"); fi
  [ "${#SKILLS[@]}" -ge 4 ] && break
done
[ "${#SKILLS[@]}" -ge 4 ] || {
  echo "codex-canary: needs four installed skills for contract-v2 kit" >&2; exit 2
}

KIT="$ROOT/.polylane/lane-skills.json"
"$BIN/polylane-scout.sh" arm-role "$KIT" builder predefined "${SKILLS[0]}" "${SKILLS[1]}"
"$BIN/polylane-scout.sh" arm-role "$KIT" builder specific "${SKILLS[2]}" "${SKILLS[3]}"

cat > .polylane/lanes/builder.txt <<PROMPT
Project: tiny Polylane Codex canary. YOUR LANE = builder.
GOAL: create canary/ok.txt containing exactly POLYLANE CODEX CANARY OK.
OWN: canary/** and docs/verify-builder.md and docs/status-builder.md.
FORBIDDEN: every other path; do not edit README.md or orchestration files.
PREDEFINED-SKILLS: ${SKILLS[0]} ${SKILLS[1]}
LANE-SPECIFIC-SKILLS: ${SKILLS[2]} ${SKILLS[3]}
Read and apply the named skills, using only what this tiny task needs.
TEST-CADENCE: run the focused exact-content check before DONE; no broad suite.
DELEGATION: forbidden; do not spawn subagents, collaboration agents, or fan-out.
CHECK-CACHE: use $BIN/polylane-check.sh $ROOT/.polylane/check-cache/builder -- <command>
for expensive checks and reuse unchanged results.
EXTERNAL-EVIDENCE: none; do not invent a manual blocker.
Create the file and docs/verify-builder.md with the exact check output. Commit only
your owned files. Then write docs/status-builder.md with first line exactly:
STATUS: builder DONE run=$RUN_ID
Do not stop before the marker exists.
PROMPT

cat > .polylane/lanes/integrator.txt <<PROMPT
Project: tiny Polylane Codex canary. YOUR LANE = integrator.
GOAL: merge lane/canary-builder into this integrator branch and verify exact content.
OWN: integrator branch, docs/verify-integration.md, docs/status-integrator.md.
FORBIDDEN: never switch to or edit main directly.
PREDEFINED-SKILLS: ${SKILLS[0]} ${SKILLS[1]}
LANE-SPECIFIC-SKILLS: ${SKILLS[2]} ${SKILLS[3]}
Read and apply the named skills, using only what this tiny task needs.
TEST-CADENCE: merge current builder HEAD; run focused exact-content verification.
DELEGATION: forbidden; do not spawn subagents, collaboration agents, or fan-out.
CHECK-CACHE: use $BIN/polylane-check.sh $ROOT/.polylane/check-cache/integrator -- <command>
for expensive checks and reuse unchanged results.
EXTERNAL-EVIDENCE: none; this canary is fully autonomous.
Run git merge --no-edit lane/canary-builder. Verify canary/ok.txt contains exactly
POLYLANE CODEX CANARY OK. Write and commit docs/verify-integration.md with evidence,
ending on its own line exactly:
POLYLANE-VERDICT: GO run=$RUN_ID
Write docs/status-integrator.md with first line exactly:
STATUS: integrator DONE run=$RUN_ID
Do not stop before both markers exist.
PROMPT

cat > .polylane/run.json <<JSON
{
  "orchestration_contract": 2,
  "run_id": "$RUN_ID",
  "cycle": 1,
  "state_file": "docs/polylane/max-state.json",
  "lane_skills_file": ".polylane/lane-skills.json",
  "cycle_plan_file": "docs/polylane/cycle-1-plan.md",
  "target_subgoals": ["s1"],
  "base": "main",
  "agent": "codex",
  "available_models": ["$MODEL"],
  "integrator": {
    "name": "integrator",
    "model": "$MODEL",
    "effort": "medium",
    "branch": "lane/canary-integrator",
    "worktree": "$ROOT/.polylane/wt/integrator",
    "prompt_file": ".polylane/lanes/integrator.txt"
  },
  "lanes": [{
    "name": "builder",
    "model": "$MODEL",
    "effort": "medium",
    "branch": "lane/canary-builder",
    "worktree": "$ROOT/.polylane/wt/builder",
    "prompt_file": ".polylane/lanes/builder.txt",
    "own_globs": ["canary/**"],
    "target_subgoals": ["s1"]
  }]
}
JSON

POLYLANE_SESSION="$SESSION" POLYLANE_SUP_INTERVAL=1 \
  "$BIN/polylane-supervisor.sh" "$ROOT/.polylane/run.json" &
SUP_PID=$!

WATCH=$(POLYLANE_SESSION="$SESSION" "$BIN/polylane-cycle.sh" runtime \
  "$ROOT/.polylane/run.json" 45) || {
    wait "$SUP_PID" 2>/dev/null || true
    echo "codex-canary: live runtime was never observable" >&2
    exit 1
  }
printf '%s\n' "$WATCH"

wait "$SUP_PID"
grep -qx 'POLYLANE CODEX CANARY OK' canary/ok.txt
grep -q '\*\*Outcome:\*\* GO' docs/polylane-report.md
[ "$(jq -r '.milestones[0].subgoals[0].status' "$STATE")" = "done" ]
[ "$(jq -r '[.accept[] | select(.status=="pass")] | length' "$STATE")" = "2" ]
git merge-base --is-ancestor lane/canary-integrator main 2>/dev/null ||
  ! git show-ref --verify --quiet refs/heads/lane/canary-integrator
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "codex-canary: tmux session still active after completion" >&2
  exit 1
fi

echo "CODEX-CANARY: PASS model=$MODEL"
