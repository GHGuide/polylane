#!/usr/bin/env bash
# Execute one behavior scenario against one skill snapshot and score observable
# concepts without placing the expected terms in the model prompt.
set -euo pipefail

need() { [ -n "${!1:-}" ] || { echo "skill-agent-eval: missing $1" >&2; exit 2; }; }
for var in POLYLANE_SKILL_PATH POLYLANE_SKILL_EVAL_CASE POLYLANE_SKILL_EVAL_RESULT POLYLANE_SKILL_EVAL_WORKDIR POLYLANE_SKILL_EVAL_MODEL POLYLANE_SKILL_EVAL_EFFORT POLYLANE_SKILL_EVAL_VARIANT POLYLANE_SKILL_EVAL_REPEAT; do need "$var"; done
command -v jq >/dev/null 2>&1 || { echo "skill-agent-eval: jq required" >&2; exit 2; }
[ -f "$POLYLANE_SKILL_PATH/SKILL.md" ] || { echo "skill-agent-eval: SKILL.md missing" >&2; exit 2; }
jq -e '(.scenario|type=="string" and length>0) and
  (.required|type=="array" and all(.[];type=="string" and length>0)) and
  ((.required_any // [])|type=="array" and all(.[]; type=="array" and length>0 and all(.[];type=="string" and length>0))) and
  (.hard_required|type=="array" and all(.[];type=="string" and length>0)) and
  ((.hard_required_any // [])|type=="array" and all(.[]; type=="array" and length>0 and all(.[];type=="string" and length>0))) and
  (.forbidden|type=="array" and all(.[];type=="string" and length>0))' \
  "$POLYLANE_SKILL_EVAL_CASE" >/dev/null || { echo "skill-agent-eval: invalid case assertions" >&2; exit 2; }

mkdir -p "$POLYLANE_SKILL_EVAL_WORKDIR"
response="$POLYLANE_SKILL_EVAL_WORKDIR/response.txt"
prompt="$POLYLANE_SKILL_EVAL_WORKDIR/prompt.txt"
scenario=$(jq -r '.scenario' "$POLYLANE_SKILL_EVAL_CASE")
start=$(date +%s)
agent_rc=0

if [ -n "${POLYLANE_SKILL_EVAL_RESPONSE:-}" ]; then
  printf '%s\n' "$POLYLANE_SKILL_EVAL_RESPONSE" > "$response"
else
  {
    printf '%s\n' 'Follow the supplied skill exactly. Treat the scenario as a real autonomous-agent decision.'
    printf '%s\n' 'Do not use tools or modify files. State the concrete action you would take and why, concisely.'
    printf '\n<skill>\n'; sed -n '1,1200p' "$POLYLANE_SKILL_PATH/SKILL.md"; printf '</skill>\n'
    printf '\n<scenario>\n%s\n</scenario>\n' "$scenario"
  } > "$prompt"
  agent="${POLYLANE_SKILL_EVAL_AGENT:-codex}"
  case "$agent" in
    codex)
      command -v codex >/dev/null 2>&1 || agent_rc=127
      if [ "$agent_rc" -eq 0 ]; then
        args=(exec --ephemeral --ignore-user-config --ignore-rules --sandbox read-only --skip-git-repo-check -C "$POLYLANE_SKILL_EVAL_WORKDIR" -o "$response" --color never)
        [ "$POLYLANE_SKILL_EVAL_MODEL" = default ] || args+=(--model "$POLYLANE_SKILL_EVAL_MODEL")
        args+=(-c "model_reasoning_effort=\"$POLYLANE_SKILL_EVAL_EFFORT\"" -)
        codex "${args[@]}" < "$prompt" > "$POLYLANE_SKILL_EVAL_WORKDIR/agent.log" 2>&1 || agent_rc=$?
      fi
      ;;
    claude)
      command -v claude >/dev/null 2>&1 || agent_rc=127
      if [ "$agent_rc" -eq 0 ]; then
        args=(--print --bare --tools "" --permission-mode dontAsk --no-session-persistence --effort "$POLYLANE_SKILL_EVAL_EFFORT")
        [ "$POLYLANE_SKILL_EVAL_MODEL" = default ] || args+=(--model "$POLYLANE_SKILL_EVAL_MODEL")
        claude "${args[@]}" "$(sed -n '1,2000p' "$prompt")" > "$response" 2> "$POLYLANE_SKILL_EVAL_WORKDIR/agent.log" || agent_rc=$?
      fi
      ;;
    *) echo "skill-agent-eval: unsupported agent: $agent" >&2; agent_rc=2 ;;
  esac
fi

[ -f "$response" ] || : > "$response"
passed=0; total=0; hard_fail=false
while IFS= read -r term; do
  [ -n "$term" ] || continue
  total=$((total + 1))
  grep -qiF -- "$term" "$response" && passed=$((passed + 1))
done < <(jq -r '.required[]' "$POLYLANE_SKILL_EVAL_CASE")
while IFS= read -r group; do
  [ -n "$group" ] || continue
  total=$((total + 1)); matched=0
  while IFS= read -r term; do
    grep -qiF -- "$term" "$response" && matched=1
  done < <(printf '%s' "$group" | jq -r '.[]')
  [ "$matched" -eq 0 ] || passed=$((passed + 1))
done < <(jq -c '.required_any[]?' "$POLYLANE_SKILL_EVAL_CASE")
while IFS= read -r term; do
  [ -n "$term" ] || continue
  total=$((total + 1))
  if ! grep -qiF -- "$term" "$response"; then passed=$((passed + 1)); fi
done < <(jq -r '.forbidden[]' "$POLYLANE_SKILL_EVAL_CASE")
while IFS= read -r term; do
  [ -n "$term" ] || continue
  grep -qiF -- "$term" "$response" || hard_fail=true
done < <(jq -r '.hard_required[]' "$POLYLANE_SKILL_EVAL_CASE")
while IFS= read -r group; do
  [ -n "$group" ] || continue
  matched=0
  while IFS= read -r term; do
    grep -qiF -- "$term" "$response" && matched=1
  done < <(printf '%s' "$group" | jq -r '.[]')
  [ "$matched" -eq 1 ] || hard_fail=true
done < <(jq -c '.hard_required_any[]?' "$POLYLANE_SKILL_EVAL_CASE")
[ "$agent_rc" -eq 0 ] || hard_fail=true
[ "$total" -gt 0 ] || { echo "skill-agent-eval: case has no assertions" >&2; exit 2; }
score=$(awk -v pass="$passed" -v total="$total" 'BEGIN { print pass/total }')
bytes=$(( $(wc -c < "$POLYLANE_SKILL_PATH/SKILL.md" | tr -d ' ') + $(wc -c < "$response" | tr -d ' ') + ${#scenario} ))
tokens=$(( (bytes + 3) / 4 ))
duration_ms=$(( ($(date +%s) - start) * 1000 ))
jq -cn --argjson score "$score" --argjson hard_fail "$hard_fail" --argjson tokens "$tokens" \
  --argjson duration_ms "$duration_ms" --argjson agent_rc "$agent_rc" --argjson assertions_total "$total" \
  --arg variant "$POLYLANE_SKILL_EVAL_VARIANT" \
  '{score:$score,hard_fail:$hard_fail,tokens:$tokens,duration_ms:$duration_ms,interventions:0,
    assertions_total:$assertions_total,agent_rc:$agent_rc,variant:$variant}' > "$POLYLANE_SKILL_EVAL_RESULT"
