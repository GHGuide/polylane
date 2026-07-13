#!/usr/bin/env bash
# The "initialized but never started" wedge class: workers launch, pane looks
# healthy, nothing ever happens. Three defenses under test:
#   1. startup_check  — answers the folder-trust / onboarding dialogs (poll-fast).
#   2. pane_wedged    — content-hash frozen across N health checks -> respawn.
#   3. counter reset  — a respawn gets a fresh wedge window.
# tmux is stubbed with a shell function: capture-pane returns $FAKE_PANE_TXT and
# send-keys appends to $KEYLOG, so the logic runs without a real tmux server.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
KEYLOG="$TEST_TMPDIR/keys.log"; : > "$KEYLOG"
FAKE_PANE_TXT=""

tmux() {
  case "$1" in
    capture-pane) printf '%s\n' "$FAKE_PANE_TXT" ;;
    send-keys)    printf '%s\n' "$*" >> "$KEYLOG" ;;
    *)            return 0 ;;
  esac
}

# minimal lane fixture: one lane 'a', pane 0, no status file (not done)
TMUX_SESSION=wtest
LANE_NAMES=(a); LANE_PANE_IDX=(0); LANE_WORKTREES=("$TEST_TMPDIR/wt")
LANE_WHASH=(); LANE_WCNT=(); LANE_RETRIES=(); LANE_RESUMED=(0)
FAILED_LANES=""; STALLED_LANES=""; NEEDS_DECISION_LANES=""
mkdir -p "$TEST_TMPDIR/wt/docs"

# --- 1. startup_check answers the trust dialog -------------------------------
FAKE_PANE_TXT='Do you trust the files in this folder?
❯ 1. Yes, proceed
  2. No, exit'
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_contains "trust-sends-1"     "send-keys -t wtest:0.0 1" "$(cat "$KEYLOG")"
assert_contains "trust-sends-enter" "Enter"                    "$(cat "$KEYLOG")"

# onboarding banner -> Enter only
: > "$KEYLOG"
FAKE_PANE_TXT='Welcome! Press Enter to continue'
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_contains "banner-sends-enter" "Enter" "$(cat "$KEYLOG")"

# a working pane (no dialog) -> no keys sent
: > "$KEYLOG"
FAKE_PANE_TXT='✻ Ideating… (2m · thinking)'
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_eq "working-pane-untouched" "" "$(cat "$KEYLOG")"

# a DONE lane is never touched even if a dialog shows
printf 'STATUS: a DONE\n' > "$TEST_TMPDIR/wt/docs/status-a.md"
: > "$KEYLOG"
FAKE_PANE_TXT='Do you trust the files in this folder?'
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_eq "done-lane-untouched" "" "$(cat "$KEYLOG")"
rm -f "$TEST_TMPDIR/wt/docs/status-a.md"

# --- 2. pane_wedged: frozen content across checks ----------------------------
# NOTE: assert_ok/assert_fail run in a subshell, so state-mutating calls must run
# directly; assert on the captured rc instead.
LANE_WHASH=(); LANE_WCNT=()
FAKE_PANE_TXT='❯ (stuck empty input)'
pane_wedged a 0; rc1=$?
pane_wedged a 0; rc2=$?
pane_wedged a 0; rc3=$?
assert_eq "wedge-check1-not-yet" "1" "$rc1"     # cnt 0 (first sight)
assert_eq "wedge-check2-not-yet" "1" "$rc2"     # cnt 1
assert_eq "wedge-check3-fires"   "0" "$rc3"     # cnt 2 >= default 2

# changing content resets the counter
LANE_WHASH=(); LANE_WCNT=()
FAKE_PANE_TXT='screen A'; pane_wedged a 0; :
FAKE_PANE_TXT='screen B'; pane_wedged a 0; rcA=$?
FAKE_PANE_TXT='screen B'; pane_wedged a 0; rcB=$?
FAKE_PANE_TXT='screen B'; pane_wedged a 0; rcC=$?
assert_eq "wedge-change-resets"  "1" "$rcA"
assert_eq "wedge-after-reset-1"  "1" "$rcB"
assert_eq "wedge-after-reset-2"  "0" "$rcC"

# --- 3. respawn resets the wedge window --------------------------------------
wedge_hash_set a ""; wedge_cnt_set a 0
FAKE_PANE_TXT='frozen'; pane_wedged a 0; pane_wedged a 0; :
wedge_hash_set a ""; wedge_cnt_set a 0                 # what respawn_lane does
pane_wedged a 0; rcR=$?
assert_eq "respawn-fresh-window" "1" "$rcR"            # needs 2 fresh checks again

finish
