#!/usr/bin/env bash
# Startup send-key recovery is a launch correction, not a model restart.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

RESTARTS=0
assert_prompt() { :; }
lane_prompt_get() { printf '%s' fixture-prompt; }
checkpoint_lane() { :; }
refresh_manifest_runtime_settings() { :; }
wedge_hash_set() { :; }
wedge_cnt_set() { :; }
progress_hash_set() { :; }
progress_count_set() { :; }
retry_get() { printf '0'; }
pane_cmd_for() { printf 'fixture-command'; }
pane_exists() { return 0; }
run() { return 0; }
repipe_pane_log() { :; }
run_stats() {
  [ "$1" = lane-restart ] && RESTARTS=$((RESTARTS + 1))
}

respawn_lane 1 builder /tmp 0
assert_eq "seed-recovery-does-not-count-restart" "0" "$RESTARTS"

respawn_lane 1 builder /tmp
assert_eq "runtime-respawn-still-counts-restart" "1" "$RESTARTS"

finish
