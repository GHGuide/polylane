#!/usr/bin/env bash
# Cycle-16 cross-contract behavior: domain gating, evidence learning, safety, and provider parity.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
ADVANCED="$ROOT/bin/polylane-advanced.sh"
DISCOVERY="$ROOT/bin/polylane-discovery.sh"
SCOUT="$ROOT/bin/polylane-scout.sh"

if ! command -v jq >/dev/null 2>&1; then
  pass "cycle16-skipped-no-jq"; finish; exit 0
fi

make_tmpdir
PROJECT="$TEST_TMPDIR/project"
mkdir -p "$PROJECT/.polylane" "$PROJECT/docs/polylane" "$PROJECT/artifacts"
printf 'verified artifact\n' > "$PROJECT/artifacts/result.txt"

cat > "$PROJECT/docs/polylane/PROJECT_PROFILE.json" <<'JSON'
{"version":1,"kind":"custom","outcome":"Produce a verified local artifact","deliverables":[{"artifact":"source","path":"artifacts/result.txt","description":"checked artifact"}],"evidence_modes":["deterministic"],"risk_tier":"low","external_action_policy":{"mode":"not-needed","actions":[]},"domain_runtime":{"provenance":{"source_id":"local-fixture","input_hash":"fixture-hash","collected_at":"2026-08-09T00:00:00Z","method":"deterministic-test","fixture_or_public":"fixture"},"checks":{"declared_artifacts":true,"declared_evidence_modes":true,"risk_action_policy":true}}}
JSON

cat > "$PROJECT/.polylane/run.json" <<'JSON'
{"base":"main","run_id":"c16-test","cycle":16,"prompt_token_budget":4000,"available_models":["gpt-5.6-luna","gpt-5.6-terra"],"lanes":[{"name":"builder","model":"gpt-5.6-terra","effort":"medium","own_globs":["artifacts/**"]}],"domain_runtime":{"enabled":true,"profile":"docs/polylane/PROJECT_PROFILE.json","registration":".polylane/domain-runtime/grader-registration.json","bundle":"docs/polylane/domain-runtime/bundle.json","grade":"docs/polylane/domain-runtime/grade.json"},"outcome_learning":{"enabled":true,"ledger":"docs/polylane/accepted-outcomes.jsonl","domain":"custom","lane_shapes":{"builder":"custom-artifact-v1"},"minimum_samples":3}}
JSON
MANIFEST="$PROJECT/.polylane/run.json"

assert_ok "cycle16-registers-profile-grader-before-launch" "$ADVANCED" preflight "$MANIFEST"
assert_ok "cycle16-grader-registration-is-executable" jq -e '.schema == "polylane-domain-grader-registration/v1" and .contract.version == "domain-runtime/v1"' "$PROJECT/.polylane/domain-runtime/grader-registration.json"
assert_ok "cycle16-profile-bundle-grade-passes" "$ADVANCED" domain-grade "$MANIFEST" "$PROJECT"
assert_eq "cycle16-profile-grade-is-pass" PASS "$(jq -r .verdict "$PROJECT/docs/polylane/domain-runtime/grade.json")"
jq '.domain_runtime.checks.risk_action_policy=false' "$PROJECT/docs/polylane/PROJECT_PROFILE.json" > "$PROJECT/docs/polylane/profile.next" && mv "$PROJECT/docs/polylane/profile.next" "$PROJECT/docs/polylane/PROJECT_PROFILE.json"
assert_fail "cycle16-profile-grade-fails-on-required-evidence" "$ADVANCED" domain-grade "$MANIFEST" "$PROJECT"
jq '.domain_runtime.checks.risk_action_policy=true' "$PROJECT/docs/polylane/PROJECT_PROFILE.json" > "$PROJECT/docs/polylane/profile.next" && mv "$PROJECT/docs/polylane/profile.next" "$PROJECT/docs/polylane/PROJECT_PROFILE.json"
BAD_MANIFEST="$PROJECT/.polylane/bad.json"
jq '.domain_runtime.profile="../outside.json"' "$MANIFEST" > "$BAD_MANIFEST"
assert_fail "cycle16-domain-gate-rejects-traversal" "$ADVANCED" preflight "$BAD_MANIFEST"
ln -s "PROJECT_PROFILE.json" "$PROJECT/docs/polylane/profile-link.json"
jq '.domain_runtime.profile="docs/polylane/profile-link.json"' "$MANIFEST" > "$BAD_MANIFEST"
assert_fail "cycle16-domain-gate-rejects-profile-symlink" "$ADVANCED" preflight "$BAD_MANIFEST"

STATE="$PROJECT/.polylane/discovery.json"
assert_ok "cycle16-typed-discovery-init" "$DISCOVERY" init "$STATE" "safe research outcome" research
assert_ok "cycle16-after-cycle-continues-without-material-question" "$DISCOVERY" after-cycle "$STATE" none
assert_fail "cycle16-after-cycle-rejects-generic-question" "$DISCOVERY" after-cycle "$STATE" none "Anything else?"
assert_ok "cycle16-after-cycle-records-material-reason" "$DISCOVERY" after-cycle "$STATE" evidence "Which source result could invalidate the conclusion?"
assert_eq "cycle16-after-cycle-keeps-domain-context" research "$(jq -r '.nodes[-1].domain_kind' "$STATE")"

SCOUT_REC="$PROJECT/.polylane/candidates.json"
printf '%s\n' '{"candidates":[{"id":"demo","path":"/not-used","reason":"unbenchmarked","source":"trusted-root","fingerprint":"fp","status":"candidate","safe_to_apply":false}]}' > "$SCOUT_REC"
assert_fail "cycle16-scout-never-arms-unbenchmarked-candidate" "$SCOUT" arm-recommendation "$PROJECT/.polylane/kits.json" builder specific "$SCOUT_REC" demo

receipt() { # FILE ID MODEL QUALITY
  jq -n --arg id "$2" --arg model "$3" --argjson quality "$4" \
    '{schema:"polylane-evidence/v1",run:"prior",cycle:15,lane:"builder",lane_shape:"custom-artifact-v1",domain:"custom",model:$model,effort:"medium",lane_count:1,context_tokens:4000,selected_skills:[],tokens:1000,wall_seconds:60,verified_criteria_delta:2,verified_subgoal_delta:1,quality_score:$quality,acceptance_hash:$id,acceptance_status:"accepted",verdict:"GO"}' > "$1"
}
LEDGER="$PROJECT/docs/polylane/accepted-outcomes.jsonl"
for n in 1 2 3; do
  receipt "$PROJECT/.polylane/base-$n.json" "base-$n" gpt-5.6-terra 1
  "$ROOT/bin/polylane-optimize.sh" record "$LEDGER" "$PROJECT/.polylane/base-$n.json" >/dev/null
  receipt "$PROJECT/.polylane/luna-$n.json" "luna-$n" gpt-5.6-luna 5
  "$ROOT/bin/polylane-optimize.sh" record "$LEDGER" "$PROJECT/.polylane/luna-$n.json" >/dev/null
done

# Source the runner only for the pre-launch policy function; this never opens tmux.
rm -rf "$PROJECT/docs/polylane/domain-runtime"
git init -q -b main "$PROJECT"
git -C "$PROJECT" config user.email test@example.com
git -C "$PROJECT" config user.name test
git -C "$PROJECT" add . && git -C "$PROJECT" commit -qm base
printf 'POLYLANE-VERDICT: GO run=c16-test\n' > "$PROJECT/docs/verify-integration.md"
git -C "$PROJECT" add docs/verify-integration.md && git -C "$PROJECT" commit -qm integration
. "$RUNNER"
MANIFEST="$PROJECT/.polylane/run.json"
PROJECT_ROOT="$PROJECT"; RUN_ID=c16-test; DRY_RUN=0; PROMPT_TOKEN_BUDGET=4000
LANE_NAMES=(builder); LANE_MODELS=(gpt-5.6-terra); LANE_EFFORTS=(medium); LANE_ROLES=(builder); LANE_POLICY_SOURCES=(manifest)
AVAILABLE_MODELS=(gpt-5.6-luna gpt-5.6-terra)
INT_WORKTREE="$PROJECT"
if domain_grade_gate >/dev/null 2>&1; then pass "cycle16-runner-commits-profile-grade-before-promotion"; else fail "cycle16-runner-commits-profile-grade-before-promotion" "domain grade gate failed"; fi
assert_ok "cycle16-domain-evidence-is-tracked" git -C "$PROJECT" ls-files --error-unmatch docs/polylane/domain-runtime/bundle.json docs/polylane/domain-runtime/grade.json
assert_ok "cycle16-domain-result-enters-integrator-evidence" grep -q '^DOMAIN-GRADER: PASS' "$PROJECT/docs/verify-integration.md"

# A generic project does not opt into domain grading. The advanced helper owns
# that optionality, and the runner must leave its result and repository state
# untouched rather than treating a successful skip as durable grade evidence.
GENERIC_PROJECT="$TEST_TMPDIR/generic-project"
mkdir -p "$GENERIC_PROJECT/.polylane" "$GENERIC_PROJECT/docs/polylane"
cat > "$GENERIC_PROJECT/.polylane/run.json" <<'JSON'
{"base":"main","run_id":"c16-generic","cycle":16,"prompt_token_budget":4000,"available_models":["gpt-5.6-luna"],"lanes":[{"name":"builder","model":"gpt-5.6-luna","effort":"medium","own_globs":["artifacts/**"]}]}
JSON
printf 'POLYLANE-VERDICT: GO run=c16-generic\n' > "$GENERIC_PROJECT/docs/verify-integration.md"
git init -q -b main "$GENERIC_PROJECT"
git -C "$GENERIC_PROJECT" config user.email test@example.com
git -C "$GENERIC_PROJECT" config user.name test
git -C "$GENERIC_PROJECT" add . && git -C "$GENERIC_PROJECT" commit -qm generic-base
GENERIC_HEAD=$(git -C "$GENERIC_PROJECT" rev-parse HEAD)
MANIFEST="$GENERIC_PROJECT/.polylane/run.json"
INT_WORKTREE="$GENERIC_PROJECT"
GENERIC_OUTPUT=""
if GENERIC_OUTPUT=$(domain_grade_gate); then
  pass "cycle16-runner-skips-unrequested-domain-grade"
else
  fail "cycle16-runner-skips-unrequested-domain-grade" "domain grade gate failed"
fi
assert_contains "cycle16-runner-preserves-not-requested-domain-result" \
  "ADVANCED: domain-grader=not-requested" "$GENERIC_OUTPUT"
assert_ok "cycle16-runner-skips-domain-bundle-and-grade-files" \
  test ! -e "$GENERIC_PROJECT/docs/polylane/domain-runtime/bundle.json" -a ! -e "$GENERIC_PROJECT/docs/polylane/domain-runtime/grade.json"
assert_eq "cycle16-runner-keeps-generic-integration-evidence" \
  "POLYLANE-VERDICT: GO run=c16-generic" "$(cat "$GENERIC_PROJECT/docs/verify-integration.md")"
assert_eq "cycle16-runner-skips-domain-grade-commit" "$GENERIC_HEAD" "$(git -C "$GENERIC_PROJECT" rev-parse HEAD)"
assert_ok "cycle16-runner-leaves-generic-repository-clean" git -C "$GENERIC_PROJECT" diff --quiet

MANIFEST="$PROJECT/.polylane/run.json"
INT_WORKTREE="$PROJECT"
if economy_plan_gate >/dev/null 2>&1; then pass "cycle16-economy-applies-measured-available-model"; else fail "cycle16-economy-applies-measured-available-model" "plan gate failed"; fi
assert_eq "cycle16-economy-model-updated" gpt-5.6-luna "${LANE_MODELS[0]}"
assert_ok "cycle16-economy-recommendation-log-is-durable" jq -e '.safe_to_apply and .applied' "$PROJECT/docs/polylane/economy-recommendations/c16-test.jsonl"
assert_ok "cycle16-accepted-receipt-keeps-unknown-measurements-honest" "$ADVANCED" accepted-receipt "$MANIFEST" c16-test 16 GO
assert_eq "cycle16-accepted-receipt-is-not-fake-optimizer-row" "measurements unavailable; not supplied to optimizer" "$(jq -r .optimizer_eligibility "$PROJECT/docs/polylane/outcome-receipts/c16-test.json")"

# Both entrypoints must carry the same executable semantics, while behavior above
# proves these are not advertising-only checks.
for file in "$ROOT/SKILL.md" "$ROOT/codex/SKILL.md"; do
  assert_ok "cycle16-provider-$(basename "$(dirname "$file")")-typed-discovery" grep -qi 'typed adapter tree' "$file"
  assert_ok "cycle16-provider-$(basename "$(dirname "$file")")-bundle-grader" grep -qi 'checksum-mismatched' "$file"
  assert_ok "cycle16-provider-$(basename "$(dirname "$file")")-outcome-learning" grep -qi 'accepted-outcome receipt' "$file"
  assert_ok "cycle16-provider-$(basename "$(dirname "$file")")-approval-hash" grep -qi 'receipt hash' "$file"
done

finish
