#!/usr/bin/env bash
# A durable runner applies intentional live model/effort tuning on its next
# respawn, but an unchanged manifest cannot undo an in-process fallback.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
MANIFEST="$TEST_TMPDIR/run.json"

write_manifest() {
  local lane_model="$1" lane_effort="$2" int_model="$3" int_effort="$4" codex_sandbox="${5:-workspace-write}"
  cat > "$MANIFEST" <<JSON
{
  "codex_sandbox": "$codex_sandbox",
  "lanes": [{
    "name": "builder",
    "model": "$lane_model",
    "effort": "$lane_effort"
  }],
  "integrator": {
    "name": "integrator",
    "model": "$int_model",
    "effort": "$int_effort"
  }
}
JSON
}

LANE_NAMES=(builder)
LANE_MODELS=(gpt-5.6-sol)
LANE_EFFORTS=(xhigh)
INT_NAME=integrator
INT_MODEL=gpt-5.6-sol
INT_EFFORT=xhigh
CODEX_SANDBOX=workspace-write

write_manifest gpt-5.6-sol xhigh gpt-5.6-sol xhigh workspace-write
MANIFEST_RUNTIME_FINGERPRINT=$(runtime_settings_fingerprint)
write_manifest gpt-5.6-terra high gpt-5.6-terra high danger-full-access
refresh_manifest_runtime_settings >/dev/null
assert_eq "live-builder-model" "gpt-5.6-terra" "${LANE_MODELS[0]}"
assert_eq "live-builder-effort" "high" "${LANE_EFFORTS[0]}"
assert_eq "live-integrator-model" "gpt-5.6-terra" "$INT_MODEL"
assert_eq "live-integrator-effort" "high" "$INT_EFFORT"
assert_eq "live-codex-sandbox" "danger-full-access" "$CODEX_SANDBOX"

# Simulate a runner-owned no-progress/paywall downgrade. With no further
# manifest edit, refresh must leave this lower-cost setting intact.
LANE_MODELS[0]=local-fallback
LANE_EFFORTS[0]=low
INT_MODEL=local-integrator-fallback
INT_EFFORT=medium
refresh_manifest_runtime_settings >/dev/null
assert_eq "unchanged-keeps-builder-fallback" "local-fallback" "${LANE_MODELS[0]}"
assert_eq "unchanged-keeps-builder-effort" "low" "${LANE_EFFORTS[0]}"
assert_eq "unchanged-keeps-integrator-fallback" "local-integrator-fallback" "$INT_MODEL"
assert_eq "unchanged-keeps-integrator-effort" "medium" "$INT_EFFORT"

# Both generic recovery and verdict-repair recovery must refresh before they
# build their next pane command.
runner_source=$(cat "$RUNNER")
assert_contains "generic-respawn-refreshes-runtime" \
  'checkpoint_lane "$wt" "$name"
  refresh_manifest_runtime_settings' "$runner_source"
assert_contains "verdict-repair-refreshes-runtime" \
  'wedge_hash_set "$INT_NAME" ""; wedge_cnt_set "$INT_NAME" 0
  refresh_manifest_runtime_settings
  cmd=$(pane_cmd_for "$INT_NAME")' "$runner_source"

finish
