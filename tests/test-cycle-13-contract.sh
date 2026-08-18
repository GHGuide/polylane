#!/usr/bin/env bash
# Hermetic cycle-13 journey: vague brief → recommended discovery → prepared
# Claude/Codex manifests → compiled prompts/skill evidence/hooks → GO/CONTINUE.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
DISCOVERY="$ROOT/bin/polylane-discovery.sh"
MEM="$ROOT/bin/polylane-memory.sh"
CYCLE_TOOL="$ROOT/bin/polylane-cycle.sh"
SCOUT="$ROOT/bin/polylane-scout.sh"
HOOKS="$ROOT/bin/polylane-hooks.sh"
CERTIFY="$ROOT/bin/polylane-certify.sh"
BRIEF_FIXTURE="$ROOT/tests/fixtures/cycle-13/vague-brief.txt"

command -v jq >/dev/null 2>&1 || { pass "cycle13-skipped-no-jq"; finish; exit 0; }
make_tmpdir
P="$TEST_TMPDIR/project"
mkdir -p "$P/.polylane/lanes" "$P/docs/polylane" "$P/skills"
export CODEX_SKILLS_DIR="$P/skills"

write_skill() {
  local path="$1" name="$2" description="$3" tools="$4"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
---
name: $name
description: $description
compatibility: codex, claude
allowed-tools: $tools
---
This body must be read only after the planner selects this named skill.
EOF
}

write_skill "$P/skills/engineering/testing-strategy/SKILL.md" testing-strategy \
  'Write focused executable tests for a lane contract.' 'bash, jq'
write_skill "$P/skills/superpowers/verification-before-completion/SKILL.md" verification \
  'Check evidence and terminal gates before completion.' 'bash, jq'
write_skill "$P/skills/ui/browser-screenshots/SKILL.md" browser-screenshots \
  'Capture browser screenshots and compare UI rendering.' 'bash, playwright'
write_skill "$P/skills/ui/accessibility-review/SKILL.md" accessibility-review \
  'Review accessible interaction states for a product UI.' 'bash, playwright'

# Vague input takes recommended answers without a transcript-dependent pause.
DISCOVERY_STATE="$P/.polylane/discovery.json"
BRIEF=$(cat "$BRIEF_FIXTURE")
assert_ok "cycle13-vague-brief-fixture" "$DISCOVERY" init "$DISCOVERY_STATE" "$BRIEF"
for question in q-user q-workflow q-success; do
  assert_ok "cycle13-recommended-$question" "$DISCOVERY" answer "$DISCOVERY_STATE" "$question" recommended
done
assert_ok "cycle13-locks-recommended-strategy" "$DISCOVERY" lock "$DISCOVERY_STATE" "$P/docs/discovery"
assert_contains "cycle13-strategy-keeps-vague-brief" "hand work" "$(cat "$P/docs/discovery/north-star.md")"

STATE="$P/docs/polylane/max-state.json"
"$MEM" "$STATE" init "vague brief fixture" >/dev/null
"$MEM" "$STATE" add-criterion c30 "policy and prompt contract" >/dev/null
"$MEM" "$STATE" add-milestone m13 "cycle 13" >/dev/null
"$MEM" "$STATE" add-subgoal m13 s1 "build the recommended minimum" 10 >/dev/null
"$MEM" "$STATE" add-accept s1 true >/dev/null
printf '# cycle 13 fixture plan\n' > "$P/docs/polylane/cycle-1-plan.md"
printf '# index\n' > "$P/docs/polylane/INDEX.md"

KIT="$P/.polylane/lane-skills.json"
"$SCOUT" arm-role "$KIT" builder predefined \
  engineering:testing-strategy superpowers:verification-before-completion
"$SCOUT" arm-role "$KIT" builder specific \
  ui:browser-screenshots ui:accessibility-review

BUILDER_PROMPT="$P/.polylane/lanes/builder.txt"
INTEGRATOR_PROMPT="$P/.polylane/lanes/integrator.txt"
cat > "$BUILDER_PROMPT" <<'PROMPT'
ULTIMATE-GOAL: A stranger can complete a distinctive verified product run unattended.
CURRENT-SUBGOAL: Build the recommended minimum from the vague brief.
GOAL: Implement the isolated builder contract.
OWN: src/**. FORBIDDEN: files outside src/**.
PREDEFINED-SKILLS: engineering:testing-strategy superpowers:verification-before-completion
LANE-SPECIFIC-SKILLS: ui:browser-screenshots ui:accessibility-review
Read only the named kit once; do not enumerate or rediscover skills.
TEST-CADENCE: Run focused checks first and leave terminal certification to the integrator.
DELEGATION: forbidden; do not spawn subagents or fan-out.
CHECK-CACHE: use $PWD/.polylane/check-cache/builder with polylane-check.sh for repeat checks.
EXTERNAL-EVIDENCE: keep physical-only proof external while autonomous work continues.
VERIFY: write docs/verify-builder.md before the current-run marker.
Keep the frozen contracts truthful.
Keep the frozen contracts truthful.
Finish STATUS: builder DONE run=c13-codex.
PROMPT
cat > "$INTEGRATOR_PROMPT" <<'PROMPT'
ULTIMATE-GOAL: A stranger can complete a distinctive verified product run unattended.
CURRENT-SUBGOAL: Build the recommended minimum from the vague brief.
GOAL: Certify the integrated builder result.
OWN: integrator branch. FORBIDDEN: direct base-branch edits.
PREDEFINED-SKILLS: engineering:testing-strategy superpowers:verification-before-completion
LANE-SPECIFIC-SKILLS: ui:browser-screenshots ui:accessibility-review
Read only the named kit once; do not enumerate or rediscover skills.
TEST-CADENCE: Run focused failures first and the terminal suite once at certification.
DELEGATION: forbidden; do not spawn subagents or fan-out.
CHECK-CACHE: use $PWD/.polylane/check-cache/integrator with polylane-check.sh for repeat checks.
EXTERNAL-EVIDENCE: keep physical-only proof external while autonomous work continues.
VERIFY: write docs/verify-integration.md before the current-run verdict.
Finish STATUS: integrator DONE run=c13-codex.
POLYLANE-VERDICT: GO run=c13-codex
PROMPT

write_manifest() {
  local output="$1" agent="$2" run_id="$3" models="$4" model="$5"
  cat > "$output" <<JSON
{
  "orchestration_contract":2,
  "run_id":"$run_id",
  "cycle":1,
  "agent":"$agent",
  "intensity":"balanced",
  "available_models":$models,
  "state_file":"docs/polylane/max-state.json",
  "lane_skills_file":".polylane/lane-skills.json",
  "cycle_plan_file":"docs/polylane/cycle-1-plan.md",
  "target_subgoals":["s1"],
  "base":"main",
  "integrator":{"name":"integrator","model":"$model","effort":"high","branch":"lane/integrator","worktree":"$P/.polylane/wt/integrator","prompt_file":".polylane/lanes/integrator.txt"},
  "lanes":[{"name":"builder","role":"mechanical","model":"$model","effort":"high","branch":"lane/builder","worktree":"$P/.polylane/wt/builder","prompt_file":".polylane/lanes/builder.txt","own_globs":["src/**","docs/status-builder.md"],"target_subgoals":["s1"]}]
}
JSON
}

CODEX_MANIFEST="$P/.polylane/codex.json"
CLAUDE_MANIFEST="$P/.polylane/claude.json"
write_manifest "$CODEX_MANIFEST" codex c13-codex '["gpt-5.6-luna","gpt-5.6-terra","gpt-5.6-sol"]' gpt-5.6-terra
write_manifest "$CLAUDE_MANIFEST" claude c13-claude '["claude-haiku-4-5","claude-sonnet-5","claude-opus-4-8","claude-fable-5"]' claude-sonnet-5
assert_ok "cycle13-skill-kit-migrates-to-trusted-paths" "$SCOUT" migrate "$KIT"
assert_ok "cycle13-skill-kit-validates-trusted-paths" "$SCOUT" validate "$KIT" "$CODEX_MANIFEST"

# Contract-v2 preflight compiles a separate launch prompt; the authored source
# stays unchanged while pane_cmd receives the verified normalized copy.
MANIFEST="$CODEX_MANIFEST"; INTENSITY=""; MODEL_OVERRIDES=(); load_manifest
if preflight_contract; then pass "cycle13-codex-plan-manifest-preflight"; else fail "cycle13-codex-plan-manifest-preflight"; fi
assert_contains "cycle13-codex-launches-compiled-prompt" "/compiled-prompts/c13-codex/builder.txt" "${LANE_PROMPTS[0]}"
assert_eq "cycle13-source-prompt-unchanged" "2" "$(grep -c '^Keep the frozen contracts truthful\.$' "$BUILDER_PROMPT")"
assert_eq "cycle13-compiled-prompt-deduped" "1" "$(grep -c '^Keep the frozen contracts truthful\.$' "${LANE_PROMPTS[0]}")"
BUILDER_RECORD=$(jq -r '.lanes.builder.selected.predefined[0] | "SELECTED-SKILL: \(.id) | \(.path) | \(.source) | \(.fingerprint) | \(.reason)"' "$KIT")
assert_contains "cycle13-runner-delivers-exact-selected-record" "$BUILDER_RECORD" "$(cat "${LANE_PROMPTS[0]}")"
assert_eq "cycle13-runner-delivers-all-trusted-records" "4" "$(grep -c '^SELECTED-SKILL:' "${LANE_PROMPTS[0]}")"
assert_eq "cycle13-runner-places-records-beside-kit" "yes" "$(awk '
  /Read only the named kit once/ { named = NR; next }
  named && /^SELECTED-SKILL:/ { print (NR == named + 2 ? "yes" : "no"); exit }
' "${LANE_PROMPTS[0]}")"
assert_contains "cycle13-runner-requires-selected-read-receipts" "SKILL-READ: id | path | fingerprint" "$(cat "${LANE_PROMPTS[0]}")"
assert_eq "cycle13-unselected-integrator-remains-noop" "0" "$(grep -c '^SELECTED-SKILL:' "$INT_PROMPT" || true)"

# Integrator selections are optional for compatibility, but once typed records
# exist they must pass the same dedupe/path/fingerprint/budget pipeline and reach
# the compiled launch prompt exactly once.
"$SCOUT" arm-role "$KIT" integrator predefined \
  engineering:testing-strategy superpowers:verification-before-completion
"$SCOUT" arm-role "$KIT" integrator specific \
  ui:browser-screenshots ui:accessibility-review
BAD_INTEGRATOR_KIT="$P/.polylane/lane-skills-bad-integrator.json"
jq '.lanes.integrator.selected.predefined[0].fingerprint = "1-1"' "$KIT" > "$BAD_INTEGRATOR_KIT"
assert_fail "cycle13-integrator-selected-fingerprint-is-enforced" \
  "$SCOUT" validate "$BAD_INTEGRATOR_KIT" "$CODEX_MANIFEST"
MANIFEST="$CODEX_MANIFEST"; INTENSITY=""; MODEL_OVERRIDES=(); load_manifest
if preflight_contract; then pass "cycle13-selected-integrator-recompiles"; else fail "cycle13-selected-integrator-recompiles"; fi
INTEGRATOR_RECORD=$(jq -r '.lanes.integrator.selected.predefined[0] | "SELECTED-SKILL: \(.id) | \(.path) | \(.source) | \(.fingerprint) | \(.reason)"' "$KIT")
assert_contains "cycle13-integrator-delivers-exact-selected-record" "$INTEGRATOR_RECORD" "$(cat "$INT_PROMPT")"
assert_eq "cycle13-integrator-delivers-all-trusted-records" "4" "$(grep -c '^SELECTED-SKILL:' "$INT_PROMPT")"
assert_contains "cycle13-integrator-requires-selected-read-receipts" "SKILL-READ: id | path | fingerprint" "$(cat "$INT_PROMPT")"
RUNTIME_RELAY='COORD="$POLYLANE_PROJECT_ROOT/bin/polylane-coordinate.sh"; "$COORD" pending "$POLYLANE_COORDINATION_FILE"'
assert_contains "cycle13-builder-gets-live-relay-command" "$RUNTIME_RELAY" "$(cat "${LANE_PROMPTS[0]}")"
assert_contains "cycle13-integrator-gets-live-relay-command" "$RUNTIME_RELAY" "$(cat "$INT_PROMPT")"
assert_eq "cycle13-builder-gets-one-live-relay-contract" "1" "$(grep -cF 'POLYLANE-RUNTIME-RELAY:' "${LANE_PROMPTS[0]}" || true)"
assert_eq "cycle13-integrator-gets-one-live-relay-contract" "1" "$(grep -cF 'POLYLANE-RUNTIME-RELAY:' "$INT_PROMPT" || true)"
assert_contains "cycle13-runtime-rejects-parallel-status-as-live" \
  'docs/parallel-status.md is post-cycle evidence only, never the live relay.' \
  "$(cat "$INT_PROMPT")"
assert_contains "cycle13-builder-gets-literal-done-path" \
  'POLYLANE-RUNTIME-DONE: write only docs/status-builder.md; first line exactly `STATUS: builder DONE run=c13-codex`.' \
  "$(cat "${LANE_PROMPTS[0]}")"
CODEX_POLICY=$(apply_overrides; emit_effective_model_policy)
assert_contains "cycle13-codex-policy-visible" "policy lane=builder role=mechanical source=role-clamp model=gpt-5.6-terra effort=medium" "$CODEX_POLICY"
assert_contains "cycle13-codex-integrator-clamp" "policy lane=integrator role=integrator source=role-clamp model=gpt-5.6-sol effort=xhigh" "$CODEX_POLICY"

CLI_MANIFEST="$P/.polylane/codex-cli.json"
jq '.lanes[0].role="builder"' "$CODEX_MANIFEST" > "$CLI_MANIFEST"
MANIFEST="$CLI_MANIFEST"; INTENSITY=performance; MODEL_OVERRIDES=("builder=gpt-5.6-luna"); load_manifest
CLI_POLICY=$(apply_overrides; emit_effective_model_policy)
assert_contains "cycle13-cli-model-override-final-before-safety-clamps" "policy lane=builder role=builder source=CLI override model=gpt-5.6-luna effort=high" "$CLI_POLICY"

# Reuse the same authored fixture for Claude with its own nonce. A source
# prompt's current-run marker is intentionally exact and cannot bleed across
# the two simulated manifests.
sed 's/run=c13-codex/run=c13-claude/g' "$BUILDER_PROMPT" > "$BUILDER_PROMPT.claude"
mv "$BUILDER_PROMPT.claude" "$BUILDER_PROMPT"
sed 's/run=c13-codex/run=c13-claude/g' "$INTEGRATOR_PROMPT" > "$INTEGRATOR_PROMPT.claude"
mv "$INTEGRATOR_PROMPT.claude" "$INTEGRATOR_PROMPT"
MANIFEST="$CLAUDE_MANIFEST"; INTENSITY=""; MODEL_OVERRIDES=(); load_manifest
if preflight_contract; then pass "cycle13-claude-plan-manifest-preflight"; else fail "cycle13-claude-plan-manifest-preflight"; fi
CLAUDE_POLICY=$(apply_overrides; emit_effective_model_policy)
assert_contains "cycle13-claude-policy-visible" "policy lane=builder role=mechanical source=role-clamp model=claude-sonnet-5 effort=medium" "$CLAUDE_POLICY"

# Planning sees only trusted metadata and produces explainable candidates. The
# builder prompt still carries only its four selected ids, never catalog bodies.
CATALOG="$P/.polylane/skill-catalog.json"
LANE_SPEC="$P/.polylane/builder-lane.json"
OUTCOMES="$P/docs/polylane/skill-outcomes.jsonl"
cat > "$LANE_SPEC" <<'JSON'
{"role":"builder","goal":"capture and compare UI screenshots","activities":["capture screenshots"],"own_globs":["src/components/**/*.tsx"],"agent":"codex","required_tools":["bash","playwright"]}
JSON
assert_ok "cycle13-catalog-index-metadata-only" "$SCOUT" catalog-index "$CATALOG"
RECOMMEND="$P/.polylane/recommend.json"
assert_ok "cycle13-catalog-recommend" bash -c '"$1" catalog-recommend "$2" "$3" "$4" > "$5"' _ "$SCOUT" "$CATALOG" "$LANE_SPEC" "$OUTCOMES" "$RECOMMEND"
assert_eq "cycle13-catalog-recommendation-explained" "ui:browser-screenshots" "$(jq -r '.candidates[0].id' "$RECOMMEND")"
assert_eq "cycle13-catalog-never-emits-skill-body" "false" "$(jq -e '.skills[] | select(.description | contains("must be read"))' "$CATALOG" >/dev/null && echo true || echo false)"
BROWSER_PATH=$(jq -r '.lanes.builder.selected.specific[] | select(.id == "ui:browser-screenshots") | .path' "$KIT")
BROWSER_FINGERPRINT=$(jq -r '.lanes.builder.selected.specific[] | select(.id == "ui:browser-screenshots") | .fingerprint' "$KIT")
cat > "$P/docs/verify-builder.md" <<'VERIFY'
SKILL-EVIDENCE: engineering:testing-strategy — helped: a focused contract assertion caught a missing compiled launch path.
SKILL-EVIDENCE: superpowers:verification-before-completion — helped: checked the current-run marker before simulated close.
SKILL-EVIDENCE: ui:browser-screenshots — helped: recommendation matches the screenshot activity and required tool.
SKILL-EVIDENCE: ui:accessibility-review — unused: no interactive state was implemented in this fixture.
VERIFY
printf 'SKILL-READ: ui:browser-screenshots | %s | %s\n' "$BROWSER_PATH" "$BROWSER_FINGERPRINT" >> "$P/docs/verify-builder.md"
AUDIT="$P/.polylane/skill-use.json"
assert_ok "cycle13-skill-use-audit" bash -c '"$1" use-audit "$2" "$3" "$4" "$5" "$6" > "$7"' _ "$SCOUT" "$KIT" builder "$P/docs/verify-builder.md" ui "$OUTCOMES" "$AUDIT"
assert_eq "cycle13-skill-use-helped" "ui:browser-screenshots" "$(jq -r '.helped[] | select(.id == "ui:browser-screenshots") | .id' "$AUDIT")"
assert_eq "cycle13-skill-use-unused" "ui:accessibility-review" "$(jq -r '.unused[] | select(. == "ui:accessibility-review")' "$AUDIT")"

# Hooks are optional project fragments; both providers restore the same bounded
# context and accept only a current-run completion proof.
cat > "$P/.polylane/lifecycle-hooks.json" <<'JSON'
{"memory_brief":"Preserve the verified lane result.","north_star":"A stranger gets an unattended verified product.","settled_decisions":["Supervisor remains authoritative."],"byte_cap":256}
JSON
CODEX_START=$(printf '%s' '{"run_id":"c13-codex","lane":"builder"}' | "$HOOKS" codex SessionStart --project "$P")
CLAUDE_START=$(printf '%s' '{"run_id":"c13-codex","lane":"builder"}' | "$HOOKS" claude SessionStart --project "$P")
assert_eq "cycle13-hook-start-provider-parity" "$(printf '%s' "$CODEX_START" | jq -r .hookSpecificOutput.additionalContext)" "$(printf '%s' "$CLAUDE_START" | jq -r .hookSpecificOutput.additionalContext)"
printf '%s\n' 'STATUS: builder DONE run=c13-codex' > "$P/docs/status-builder.md"
printf '%s\n' 'builder evidence run=c13-codex' >> "$P/docs/verify-builder.md"
CODEX_STOP=$(printf '%s' '{"run_id":"c13-codex","lane":"builder"}' | "$HOOKS" codex Stop --project "$P")
CLAUDE_STOP=$(printf '%s' '{"run_id":"c13-codex","lane":"builder"}' | "$HOOKS" claude Stop --project "$P")
assert_eq "cycle13-hook-stop-codex-current-run" true "$(printf '%s' "$CODEX_STOP" | jq -r .continue)"
assert_eq "cycle13-hook-stop-claude-current-run" true "$(printf '%s' "$CLAUDE_STOP" | jq -r .continue)"

# The autonomous route remains CONTINUE until the focused acceptance and its
# criterion are truly complete. The questions artifact records the recommended
# default rather than creating a blocking unknown choice.
assert_contains "cycle13-open-route-continues" "CONTINUE s1" "$("$CYCLE_TOOL" route "$STATE")"
printf '%s\n' '# Emergent questions' '' '- Recommended: continue with the smallest verified builder plan.' > "$P/docs/polylane/cycle-1-questions.md"
assert_contains "cycle13-emergent-question-recommended" "Recommended" "$(cat "$P/docs/polylane/cycle-1-questions.md")"
"$MEM" "$STATE" check-accept --cycle 1 --targets s1 --focused >/dev/null
"$MEM" "$STATE" set-status s1 done "simulated GO close" 1 >/dev/null
"$MEM" "$STATE" set-status c30 done "policy checked" 1 >/dev/null
assert_eq "cycle13-simulated-go-close" "COMPLETE" "$("$CYCLE_TOOL" route "$STATE")"
printf '%s\n' 'POLYLANE-VERDICT: GO run=c13-codex' > "$P/docs/verify-integration.md"
RUN_ID=c13-codex
assert_eq "cycle13-current-run-go-sentinel" GO "$(parse_verdict "$P/docs/verify-integration.md")"

for layer in discovery planning/prompt model-policy skill-routing graph/runtime/recovery integration/learning install/parity ShellCheck rehearsal; do
  assert_contains "cycle13-certify-names-$layer" "$layer" "$(cat "$CERTIFY")"
done

finish
