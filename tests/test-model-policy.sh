#!/usr/bin/env bash
# Agent-aware manifest/CLI policy.  These are deliberately function-level tests:
# the runner calls this policy before it creates a worktree or tmux pane.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

policy_state() {
  (
    AGENT="$1"; INTENSITY="$2"; MANIFEST_INTENSITY="$3"
    AVAILABLE_MODELS=( $4 )
    LANE_NAMES=(builder hardest mechanical security)
    LANE_MODELS=(claude-haiku-4-5 claude-sonnet-5 claude-opus-4-8 claude-haiku-4-5)
    LANE_EFFORTS=(medium medium xhigh medium)
    LANE_ROLES=(builder hardest mechanical security)
    INT_NAME=integrator; INT_MODEL=claude-sonnet-5; INT_EFFORT=high
    MODEL_OVERRIDES=()
    resolve_model_policy >/dev/null || exit $?
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s' \
      "${LANE_MODELS[0]}" "${LANE_EFFORTS[0]}" \
      "${LANE_MODELS[1]}" "${LANE_EFFORTS[1]}" \
      "${LANE_MODELS[2]}" "${LANE_EFFORTS[2]}" \
      "${LANE_MODELS[3]}" "${LANE_EFFORTS[3]}" "$INT_MODEL" "$INT_EFFORT"
  )
}

# Manifest intensity, not a duplicate CLI option, is the default policy.
assert_eq "policy-manifest-intensity-claude" \
  "claude-sonnet-5|high|claude-sonnet-5|high|claude-sonnet-5|medium|claude-opus-4-8|high|claude-fable-5|xhigh" \
  "$(policy_state claude '' balanced 'claude-haiku-4-5 claude-sonnet-5 claude-opus-4-8 claude-fable-5')"

# An explicit CLI intensity wins over the manifest default; Codex tiers are
# luna < terra < sol and a one-model manifest compresses model selection only.
assert_eq "policy-cli-intensity-codex" \
  "gpt-5.6-sol|high|gpt-5.6-sol|high|gpt-5.6-terra|medium|gpt-5.6-terra|high|gpt-5.6-sol|xhigh" \
  "$(policy_state codex performance economy 'gpt-5.6-luna gpt-5.6-terra gpt-5.6-sol')"
assert_eq "policy-codex-single-model-compresses" \
  "gpt-5.6-terra|high|gpt-5.6-terra|high|gpt-5.6-terra|medium|gpt-5.6-terra|high|gpt-5.6-terra|xhigh" \
  "$(policy_state codex max '' 'gpt-5.6-terra')"

# Role clamps are mechanical, including the ordinary-builder ceiling and
# security's non-refusal (never lowest-tier) minimum.
assert_eq "policy-role-clamps" \
  "gpt-5.6-sol|high|gpt-5.6-sol|high|gpt-5.6-terra|medium|gpt-5.6-terra|high|gpt-5.6-sol|xhigh" \
  "$(policy_state codex max '' 'gpt-5.6-luna gpt-5.6-terra gpt-5.6-sol')"

# Without an intensity the manifest's deliberate per-lane settings survive.
assert_eq "policy-missing-intensity-preserves-manifest" \
  "claude-haiku-4-5|medium|claude-sonnet-5|medium|claude-opus-4-8|xhigh|claude-haiku-4-5|medium|claude-sonnet-5|high" \
  "$(policy_state claude '' '' 'claude-haiku-4-5 claude-sonnet-5 claude-opus-4-8 claude-fable-5')"

# Old manifests that opt out of intensity and available_models may deliberately
# target a custom agent command. Active policy validation must not retroactively
# reject that established explicit model/effort contract.
policy_legacy_custom() {
  (
    AGENT=claude; INTENSITY=""; MANIFEST_INTENSITY=""; AVAILABLE_MODELS=()
    LANE_NAMES=(builder); LANE_MODELS=(custom-model); LANE_EFFORTS=(legacy-effort); LANE_ROLES=(builder)
    INT_NAME=integrator; INT_MODEL=custom-integrator; INT_EFFORT=legacy-effort; MODEL_OVERRIDES=()
    resolve_model_policy
  )
}
assert_ok "policy-legacy-custom-manifest-preserved" policy_legacy_custom

policy_rc() {
  (
    AGENT=codex; INTENSITY=balanced; MANIFEST_INTENSITY=""
    AVAILABLE_MODELS=(gpt-5.6-terra "$1")
    LANE_NAMES=(builder); LANE_MODELS=(gpt-5.6-terra); LANE_EFFORTS=(medium); LANE_ROLES=(builder)
    INT_NAME=integrator; INT_MODEL=gpt-5.6-terra; INT_EFFORT=high; MODEL_OVERRIDES=()
    resolve_model_policy
  )
}
assert_rc "policy-rejects-unknown-model-id" 2 policy_rc gpt-5.6-mystery

policy_bad_override() {
  (
    AGENT=codex; INTENSITY=balanced; MANIFEST_INTENSITY=""
    AVAILABLE_MODELS=(gpt-5.6-terra)
    LANE_NAMES=(builder); LANE_MODELS=(gpt-5.6-terra); LANE_EFFORTS=(medium); LANE_ROLES=(builder)
    INT_NAME=integrator; INT_MODEL=gpt-5.6-terra; INT_EFFORT=high
    MODEL_OVERRIDES=(builder=gpt-5.6-sol)
    resolve_model_policy
  )
}
assert_rc "policy-rejects-unavailable-cli-model" 2 policy_bad_override

policy_bad_effort() {
  (
    AGENT=claude; INTENSITY=""; MANIFEST_INTENSITY=""; AVAILABLE_MODELS=(claude-haiku-4-5 claude-sonnet-5)
    LANE_NAMES=(builder); LANE_MODELS=(claude-haiku-4-5); LANE_EFFORTS=(max); LANE_ROLES=(builder)
    INT_NAME=integrator; INT_MODEL=claude-sonnet-5; INT_EFFORT=high; MODEL_OVERRIDES=()
    resolve_model_policy
  )
}
assert_rc "policy-rejects-unsupported-effort" 2 policy_bad_effort

policy_explanation() {
  (
    AGENT=codex; INTENSITY=performance; MANIFEST_INTENSITY=economy
    AVAILABLE_MODELS=(gpt-5.6-luna gpt-5.6-terra gpt-5.6-sol)
    LANE_NAMES=(builder security); LANE_MODELS=(gpt-5.6-luna gpt-5.6-luna); LANE_EFFORTS=(medium medium); LANE_ROLES=(builder security)
    INT_NAME=integrator; INT_MODEL=gpt-5.6-luna; INT_EFFORT=medium; MODEL_OVERRIDES=()
    resolve_model_policy && emit_effective_model_policy
  )
}
EXPLANATION=$(policy_explanation)
assert_contains "policy-explains-cli-source" "policy lane=builder role=builder source=CLI override model=gpt-5.6-sol effort=high" "$EXPLANATION"
assert_contains "policy-explains-role-clamp" "policy lane=security role=security source=role-clamp model=gpt-5.6-terra effort=high" "$EXPLANATION"
assert_contains "policy-explains-integrator" "policy lane=integrator role=integrator source=role-clamp model=gpt-5.6-sol effort=xhigh" "$EXPLANATION"

# Rebuilding packets on a supervisor resume must not manufacture a second
# compaction observation (which would otherwise inflate the refinement queue).
make_tmpdir
PROJECT_ROOT="$TEST_TMPDIR"; CYCLE=13; RUN_ID=policy-resume; PRIME_HYBRID=1; DRY_RUN=0
"$TESTS_DIR/../bin/polylane-harness.sh" init "$PROJECT_ROOT/docs/polylane/harness" >/dev/null
assert_ok "policy-prime-observe-first" prime_hybrid_observe compaction context "bounded packets built for run $RUN_ID"
assert_ok "policy-prime-observe-idempotent" prime_hybrid_observe compaction context "bounded packets built for run $RUN_ID"
assert_eq "policy-prime-compaction-once" "1" \
  "$(jq -s '[.[] | select(.kind == "compaction" and .subject == "context")] | length' "$PROJECT_ROOT/docs/polylane/harness/refinement-observations.jsonl")"

finish
