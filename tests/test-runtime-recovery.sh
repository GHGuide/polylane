#!/usr/bin/env bash
# Missing mapped panes must be recreated before any launch/retry is counted.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
KEYLOG="$TEST_TMPDIR/tmux.log"; : > "$KEYLOG"
TMUX_SESSION=recovery-test
SESSION_STARTED=1
LANE_NAMES=(builder); LANE_PANE_IDX=(4); LANE_WORKTREES=("$TEST_TMPDIR/wt")
LANE_MODELS=(codex); LANE_PROMPTS=("$TEST_TMPDIR/prompt"); LANE_EFFORTS=()
LANE_RETRIES=(0); LANE_WHASH=(); LANE_WCNT=(); LANE_PHASH=(); LANE_PCNT=()
FAILED_LANES=""; STALLED_LANES=""; RUN_ID=recovery-run
mkdir -p "$TEST_TMPDIR/wt/docs"; printf 'build\n' > "$TEST_TMPDIR/prompt"
FAKE_PANES='0 1 7'
tmux() {
  printf '%s\n' "$*" >> "$KEYLOG"
  case "$1" in
    list-panes) printf '%s\n' $FAKE_PANES ;;
    split-window) printf '7\n'; FAKE_PANES="$FAKE_PANES 7" ;;
    *) return 0 ;;
  esac
}
checkpoint_lane() { :; }
refresh_manifest_runtime_settings() { :; }
pane_cmd_for() { printf 'agent-launch'; }
pipe_pane_log() { printf 'pipe %s %s\n' "$1" "$2" >> "$KEYLOG"; }
material_progress_stalled() { return 1; }
pane_retryable_error() { return 1; }
pane_dead() { return 1; }
pane_wedged() { return 1; }

health_check "builder:$TEST_TMPDIR/wt"
assert_eq "missing-pane-remapped" "7" "${LANE_PANE_IDX[0]}"
assert_eq "missing-pane-counts-after-launch" "1" "${LANE_RETRIES[7]}"
assert_contains "missing-pane-creates-owned-pane" "split-window -t recovery-test:0 -P -F #{pane_index}" "$(cat "$KEYLOG")"
assert_contains "missing-pane-attaches-log" "pipe 7 builder" "$(cat "$KEYLOG")"
assert_eq "missing-pane-never-sends-old-target" "0" "$(grep -c 'recovery-test:0.4' "$KEYLOG" || true)"

# Pane indices are tmux-owned and may be renumbered when completed panes leave.
# A later integrator launch must trust split-window's returned index, not a stale
# NEXT_PANE_IDX guess, or the runner seeds a missing pane and a resume duplicates it.
NEXT_PANE_IDX=9
new_pane integrator >/dev/null
assert_eq "new-pane-uses-tmux-returned-index" "7" "$NEW_PANE_IDX"
assert_eq "new-pane-next-follows-actual-index" "8" "$NEXT_PANE_IDX"

finish
