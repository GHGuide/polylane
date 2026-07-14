#!/usr/bin/env bash
# --intensity / --model resolution (documented CLI contract): preset -> effort,
# preset -> model via ladder against available_models, apply_overrides remaps
# every lane + integrator, --model wins over the preset, bad input exit codes.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

# preset_effort — MUST match references/model-selection.md's intensity table
assert_eq "effort-economy"     "medium" "$(preset_effort economy)"
assert_eq "effort-balanced"    "high"   "$(preset_effort balanced)"
assert_eq "effort-performance" "high"   "$(preset_effort performance)"
assert_eq "effort-max"         "xhigh"  "$(preset_effort max)"
assert_fail "effort-unknown-rc1" preset_effort turbo

# model_available
AVAILABLE_MODELS=(claude-haiku-4-5 claude-sonnet-5 claude-opus-4-8)
assert_ok   "model-available-hit"  model_available claude-sonnet-5
assert_fail "model-available-miss" model_available claude-fable-5

# preset_model ladder against the fixture manifest's models
assert_eq "preset-economy"     "claude-haiku-4-5" "$(preset_model economy)"
assert_eq "preset-balanced"    "claude-sonnet-5"  "$(preset_model balanced)"
assert_eq "preset-performance" "claude-opus-4-8"  "$(preset_model performance)"
assert_eq "preset-max"         "claude-opus-4-8"  "$(preset_model max)"
assert_fail "preset-unknown-rc1" preset_model turbo

# graceful fallback: none of the ladder available -> first available id
AVAILABLE_MODELS=(custom-local-model)
assert_eq "preset-fallback-first-available" "custom-local-model" "$(preset_model performance)"

# --- apply_overrides on the fixture manifest ----------------------------------

# ov_state EXTRA_SETUP -> "lane_models|lane_efforts|int_model|int_effort" after
# apply_overrides, run in a subshell so exits stay contained.
ov_state() {
  ( MANIFEST="$FIXTURES/project/.polylane/run.json"
    load_manifest
    eval "$1"
    apply_overrides >/dev/null 2>&1 \
      && printf '%s|%s|%s|%s' "${LANE_MODELS[*]}" "${LANE_EFFORTS[*]}" "$INT_MODEL" "$INT_EFFORT" )
}

# no flags -> untouched manifest values
assert_eq "ov-noop" \
  "claude-sonnet-5 claude-haiku-4-5|medium |claude-opus-4-8|high" \
  "$(ov_state ':')"

# --intensity economy remaps lanes to haiku/medium; integrator effort clamped to xhigh
assert_eq "ov-intensity-all" \
  "claude-haiku-4-5 claude-haiku-4-5|medium medium|claude-haiku-4-5|xhigh" \
  "$(ov_state 'INTENSITY=economy')"

# --model wins over --intensity for the named lane; integrator overridable by name (effort stays xhigh)
assert_eq "ov-model-beats-intensity" \
  "claude-haiku-4-5 claude-opus-4-8|medium medium|claude-sonnet-5|xhigh" \
  "$(ov_state 'INTENSITY=economy; MODEL_OVERRIDES=(beta=claude-opus-4-8 integrator=claude-sonnet-5)')"

# error exits (documented): unknown preset 2, empty available_models 1, unknown lane 2, malformed 2
ov_rc() {
  ( MANIFEST="$FIXTURES/project/.polylane/run.json"; load_manifest; eval "$1"; apply_overrides )
}
assert_rc "ov-unknown-preset-exit2" 2 ov_rc 'INTENSITY=turbo'
assert_rc "ov-empty-models-exit1"   1 ov_rc 'INTENSITY=economy; AVAILABLE_MODELS=()'
assert_rc "ov-unknown-lane-exit2"   2 ov_rc 'MODEL_OVERRIDES=(gamma=claude-opus-4-8)'
assert_rc "ov-malformed-exit2"      2 ov_rc 'MODEL_OVERRIDES=(no-equals-sign)'

finish
