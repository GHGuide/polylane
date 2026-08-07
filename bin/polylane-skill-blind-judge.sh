#!/usr/bin/env bash
# Blind A/B judge for two anonymized skill snapshots. The adapter sees only A
# and B paths; the evolution runtime owns the secret champion mapping.
set -euo pipefail

need() { [ -n "${!1:-}" ] || { echo "skill-blind-judge: missing $1" >&2; exit 2; }; }
for var in POLYLANE_SKILL_BLIND_A_PATH POLYLANE_SKILL_BLIND_B_PATH POLYLANE_SKILL_JUDGE_RESULT POLYLANE_SKILL_JUDGE_WORKDIR POLYLANE_SKILL_JUDGE_EVALS POLYLANE_SKILL_JUDGE_NAME POLYLANE_SKILL_EVAL_MODEL POLYLANE_SKILL_EVAL_EFFORT; do need "$var"; done
command -v jq >/dev/null 2>&1 || { echo "skill-blind-judge: jq required" >&2; exit 2; }
for dir in "$POLYLANE_SKILL_BLIND_A_PATH" "$POLYLANE_SKILL_BLIND_B_PATH"; do
  [ -f "$dir/SKILL.md" ] || { echo "skill-blind-judge: SKILL.md missing in $dir" >&2; exit 2; }
done
judge=$(jq -c --arg name "$POLYLANE_SKILL_JUDGE_NAME" '.judges[]|select(.name==$name)' "$POLYLANE_SKILL_JUDGE_EVALS")
[ -n "$judge" ] || { echo "skill-blind-judge: unknown judge" >&2; exit 2; }
scenario=$(printf '%s' "$judge" | jq -r '.scenario // "Compare the skills for reliable autonomous execution."')
rubric=$(printf '%s' "$judge" | jq -r '.rubric // .lens // .name')
mkdir -p "$POLYLANE_SKILL_JUDGE_WORKDIR"
response="$POLYLANE_SKILL_JUDGE_WORKDIR/response.json"
prompt="$POLYLANE_SKILL_JUDGE_WORKDIR/prompt.txt"
start=$(date +%s); agent_rc=0

if [ -n "${POLYLANE_SKILL_JUDGE_RESPONSE:-}" ]; then
  printf '%s\n' "$POLYLANE_SKILL_JUDGE_RESPONSE" > "$response"
else
  {
    printf '%s\n' 'You are an independent blind evaluator. Compare Skill A and Skill B without guessing their identity.'
    printf 'Scenario: %s\nRubric: %s\n' "$scenario" "$rubric"
    printf '%s\n' 'Return only JSON: {"winner":"A|B|tie","confidence":0.0,"reason":"brief evidence"}.'
    printf '\n<skill-a>\n'; sed -n '1,1200p' "$POLYLANE_SKILL_BLIND_A_PATH/SKILL.md"; printf '</skill-a>\n'
    printf '\n<skill-b>\n'; sed -n '1,1200p' "$POLYLANE_SKILL_BLIND_B_PATH/SKILL.md"; printf '</skill-b>\n'
  } > "$prompt"
  agent="${POLYLANE_SKILL_EVAL_AGENT:-codex}"
  case "$agent" in
    codex)
      command -v codex >/dev/null 2>&1 || agent_rc=127
      if [ "$agent_rc" -eq 0 ]; then
        args=(exec --ephemeral --ignore-user-config --ignore-rules --sandbox read-only --skip-git-repo-check -C "$POLYLANE_SKILL_JUDGE_WORKDIR" -o "$response" --color never)
        [ "$POLYLANE_SKILL_EVAL_MODEL" = default ] || args+=(--model "$POLYLANE_SKILL_EVAL_MODEL")
        args+=(-c "model_reasoning_effort=\"$POLYLANE_SKILL_EVAL_EFFORT\"" -)
        codex "${args[@]}" < "$prompt" > "$POLYLANE_SKILL_JUDGE_WORKDIR/agent.log" 2>&1 || agent_rc=$?
      fi
      ;;
    claude)
      command -v claude >/dev/null 2>&1 || agent_rc=127
      if [ "$agent_rc" -eq 0 ]; then
        args=(--print --bare --tools "" --permission-mode dontAsk --no-session-persistence --effort "$POLYLANE_SKILL_EVAL_EFFORT")
        [ "$POLYLANE_SKILL_EVAL_MODEL" = default ] || args+=(--model "$POLYLANE_SKILL_EVAL_MODEL")
        claude "${args[@]}" "$(sed -n '1,2400p' "$prompt")" > "$response" 2> "$POLYLANE_SKILL_JUDGE_WORKDIR/agent.log" || agent_rc=$?
      fi
      ;;
    *) agent_rc=2 ;;
  esac
fi

valid=false
if [ "$agent_rc" -eq 0 ] && jq -e 'type=="object" and (.winner=="A" or .winner=="B" or .winner=="tie") and
  (.confidence|type=="number" and .>=0 and .<=1)' "$response" >/dev/null 2>&1; then valid=true; fi
if [ "$valid" = true ]; then
  winner=$(jq -r '.winner' "$response"); confidence=$(jq -r '.confidence' "$response"); hard_fail=false
else
  winner=tie; confidence=0; hard_fail=true
fi
bytes=$(( $(wc -c < "$POLYLANE_SKILL_BLIND_A_PATH/SKILL.md" | tr -d ' ') + $(wc -c < "$POLYLANE_SKILL_BLIND_B_PATH/SKILL.md" | tr -d ' ') + $(wc -c < "$response" 2>/dev/null | tr -d ' ' || echo 0) ))
tokens=$(( (bytes + 3) / 4 )); duration_ms=$(( ($(date +%s) - start) * 1000 ))
jq -cn --arg winner "$winner" --argjson confidence "$confidence" --argjson hard_fail "$hard_fail" \
  --argjson tokens "$tokens" --argjson duration_ms "$duration_ms" --argjson agent_rc "$agent_rc" \
  '{winner:$winner,confidence:$confidence,hard_fail:$hard_fail,tokens:$tokens,duration_ms:$duration_ms,agent_rc:$agent_rc}' \
  > "$POLYLANE_SKILL_JUDGE_RESULT"
