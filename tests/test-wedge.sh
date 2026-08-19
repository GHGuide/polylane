#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034 # sourced runner consumes fixture globals
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
LANE_EFFORTS=(high); LANE_WHASH=(); LANE_WCNT=(); LANE_RETRIES=(); LANE_RESUMED=(0)
FAILED_LANES=""; STALLED_LANES=""; NEEDS_DECISION_LANES=""
mkdir -p "$TEST_TMPDIR/wt/docs"
FAKE_AGENT_LIVE=0
pane_agent_live() { [ "$FAKE_AGENT_LIVE" = "1" ]; }
FAKE_CPU=0
pane_tree_cpu_seconds() { printf '%s' "$FAKE_CPU"; }

# A completed shell command or agent progress message is not a completed turn.
# Codex emits agent_message items between later tools and silent reasoning.
REPO_ROOT="$TEST_TMPDIR"
mkdir -p "$REPO_ROOT/docs/lane-logs"
printf '%s\n' '{"type":"item.completed","item":{"type":"command_execution","status":"completed"}}' > "$REPO_ROOT/docs/lane-logs/a.log"
assert_fail "completed-command-is-not-terminal-turn" lane_terminal_turn a
printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message"}}' >> "$REPO_ROOT/docs/lane-logs/a.log"
assert_fail "agent-message-is-progress-not-terminal" lane_terminal_turn a
printf '%s\n' '{"type":"turn.completed"}' >> "$REPO_ROOT/docs/lane-logs/a.log"
assert_ok "completed-turn-is-terminal" lane_terminal_turn a
printf '%s\n' '{"type":"turn.started"}' >> "$REPO_ROOT/docs/lane-logs/a.log"
assert_fail "new-turn-clears-stale-terminal-event" lane_terminal_turn a
printf '%s\n' '{"type":"error","message":"provider failed"}' >> "$REPO_ROOT/docs/lane-logs/a.log"
assert_ok "latest-error-is-terminal" lane_terminal_turn a
rm -f "$REPO_ROOT/docs/lane-logs/a.log"

# Claude Code keeps its process alive after an `end_turn`. Its idle screen and
# its in-flight screen both paint a blank prompt, but only the active turn offers
# "esc to interrupt". Classify the former as terminal so it gets the normal
# bounded recovery window; never shorten a legitimate high-effort turn.
FAKE_PANE_TXT='· Churning… (almost done thinking with xhigh effort)
─────────────────────────────────────────────────────────────
❯
─────────────────────────────────────────────────────────────
  accept edits on (shift+tab to cycle) · esc to interrupt'
assert_fail "active-claude-turn-is-not-idle" pane_claude_idle_prompt 0
FAKE_PANE_TXT='✻ Sautéed for 13s
─────────────────────────────────────────────────────────────
❯
─────────────────────────────────────────────────────────────
  accept edits on (shift+tab to cycle)'
assert_ok "claude-end-turn-at-input-is-idle" pane_claude_idle_prompt 0

# A quoted glyph or approval choice is not an empty Claude input surface.
FAKE_PANE_TXT='Do you want to proceed?
❯ 1. Yes
  2. No'
assert_fail "approval-menu-is-not-idle-input" pane_claude_idle_prompt 0

# Regression: the append-only transcript can retain an old agent_message while
# a high-effort Codex turn is still live. It is progress, not a turn boundary,
# so the real classifier must keep the long live-turn grace rather than restart
# the lane through the normal dead-pane window.
printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message"}}' > "$REPO_ROOT/docs/lane-logs/a.log"
LANE_WHASH=(); LANE_WCNT=()
FAKE_AGENT_LIVE=1
POLYLANE_LIVE_WEDGE_CHECKS=0
FAKE_PANE_TXT='quiet live high-effort Codex turn'
pane_wedged a 0; :
wedge_cnt_set a 4
pane_wedged a 0; rcOldProgressLive=$?
assert_eq "old-agent-message-keeps-live-high-effort-turn-from-restart" "1" "$rcOldProgressLive"
FAKE_AGENT_LIVE=0
rm -f "$REPO_ROOT/docs/lane-logs/a.log"

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

# Transcript/prose may quote the trust question, but only a live numbered
# affirmative menu is actionable.  Never type into a worker from a mention.
: > "$KEYLOG"
FAKE_PANE_TXT='I cannot proceed until "Do you trust the files in this folder?" is answered.'
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_eq "trust-prose-without-option-untouched" "" "$(cat "$KEYLOG")"

: > "$KEYLOG"
FAKE_PANE_TXT='Welcome to the guide: Press Enter to continue reading the example below.'
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_eq "banner-prose-without-live-banner-untouched" "" "$(cat "$KEYLOG")"

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
POLYLANE_WEDGE_CHECKS=4
FAKE_PANE_TXT='❯ (stuck empty input)'
pane_wedged a 0; rc1=$?
pane_wedged a 0; rc2=$?
pane_wedged a 0; rc3=$?
pane_wedged a 0; rc4=$?
pane_wedged a 0; rc5=$?
assert_eq "wedge-check1-not-yet" "1" "$rc1"     # cnt 0 (first sight)
assert_eq "wedge-check2-not-yet" "1" "$rc2"     # cnt 1
assert_eq "wedge-check3-not-yet" "1" "$rc3"     # cnt 2
assert_eq "wedge-check4-not-yet" "1" "$rc4"     # cnt 3
assert_eq "wedge-check5-fires"   "0" "$rc5"     # cnt 4 >= default 4

# changing content resets the counter
LANE_WHASH=(); LANE_WCNT=()
FAKE_PANE_TXT='screen A'; pane_wedged a 0; :
FAKE_PANE_TXT='screen B'; pane_wedged a 0; rcA=$?
FAKE_PANE_TXT='screen B'; pane_wedged a 0; rcB=$?
FAKE_PANE_TXT='screen B'; pane_wedged a 0; rcC=$?
FAKE_PANE_TXT='screen B'; pane_wedged a 0; rcD=$?
FAKE_PANE_TXT='screen B'; pane_wedged a 0; rcE=$?
assert_eq "wedge-change-resets"  "1" "$rcA"
assert_eq "wedge-after-reset-1"  "1" "$rcB"
assert_eq "wedge-after-reset-2"  "1" "$rcC"
assert_eq "wedge-after-reset-3"  "1" "$rcD"
assert_eq "wedge-after-reset-4"  "0" "$rcE"

# A genuinely active command remains untouched even when its PID is alive.
LANE_WHASH=(); LANE_WCNT=()
FAKE_AGENT_LIVE=1
lane_active_command() { return 0; }
FAKE_PANE_TXT='quiet live codex turn'
pane_wedged a 0; :
wedge_cnt_set a 4
pane_wedged a 0; rcLiveCommand=$?
assert_eq "live-command-untouched" "1" "$rcLiveCommand"
lane_active_command() { return 1; }
lane_terminal_turn() { return 0; }
pane_wedged a 0; :  # switch the tracker from pane paint to durable activity
wedge_cnt_set a 3
pane_wedged a 0; rcLiveShort=$?
wedge_cnt_set a 4
pane_wedged a 0; rcLiveLong=$?
assert_eq "live-terminal-turn-recovers-at-60s" "0" "$rcLiveShort"
assert_eq "live-terminal-turn-remains-recoverable" "0" "$rcLiveLong"

# A quiet high-effort Codex child whose latest durable boundary is turn.started
# is still in-flight.  The former 40-check cap falsely halted Cycle 27 at a
# ten-second health interval, so the production grace is effort-scaled seconds
# and the derived check ceiling must remain independent of poll cadence.
lane_terminal_turn() { return 1; }
LANE_WHASH=(); LANE_WCNT=()
unset POLYLANE_LIVE_WEDGE_CHECKS POLYLANE_LIVE_WEDGE_SECONDS POLYLANE_LIVE_WEDGE_HARD_SECONDS
POLYLANE_HEALTH_INTERVAL=10
printf '%s\n' '{"type":"turn.started"}' > "$REPO_ROOT/docs/lane-logs/a.log"
pane_wedged a 0; :
wedge_cnt_set a 40
pane_wedged a 0; rcHighQuiet=$?
assert_eq "quiet-high-effort-turn-started-survives-old-40-check-cap" "1" "$rcHighQuiet"
assert_eq "quiet-high-effort-live-turn-ceiling-is-seconds-derived" "180" "$(lane_live_wedge_checks a)"
POLYLANE_LIVE_WEDGE_SECONDS=7200
assert_eq "quiet-high-effort-explicit-multi-hour-window-is-not-silently-clamped" "7200" "$(lane_live_wedge_seconds a)"
unset POLYLANE_LIVE_WEDGE_SECONDS
POLYLANE_LIVE_WEDGE_HARD_SECONDS=60
wedge_cnt_set a 6
pane_wedged a 0; rcHighBounded=$?
assert_eq "quiet-high-effort-live-turn-hard-cap-still-recovers" "0" "$rcHighBounded"
unset POLYLANE_LIVE_WEDGE_HARD_SECONDS

# Exact live incident: Claude returned `end_turn` to an empty prompt without a
# DONE marker. Even though its process remains alive and the structured Codex
# transcript has no turn boundary, the UI classifier must select the short
# terminal-turn window instead of waiting the xhigh one-hour silence cap.
LANE_WHASH=(); LANE_WCNT=()
POLYLANE_HEALTH_INTERVAL=15
POLYLANE_WEDGE_CHECKS=4
FAKE_PANE_TXT='✻ Sautéed for 13s
─────────────────────────────────────────────────────────────
❯
─────────────────────────────────────────────────────────────
  accept edits on (shift+tab to cycle)'
pane_wedged a 0; :
wedge_cnt_set a 3
pane_wedged a 0; rcClaudeIdle=$?
assert_eq "live-claude-end-turn-recovers-at-60s" "0" "$rcClaudeIdle"
FAKE_AGENT_LIVE=0

# --- 3. respawn resets the wedge window --------------------------------------
wedge_hash_set a ""; wedge_cnt_set a 0
FAKE_PANE_TXT='frozen'; pane_wedged a 0; pane_wedged a 0; :
wedge_hash_set a ""; wedge_cnt_set a 0                 # what respawn_lane does
pane_wedged a 0; rcR=$?
assert_eq "respawn-fresh-window" "1" "$rcR"            # needs 4 fresh checks again

# --- CPU burn proves work; mere child processes do not -----------------------
# Claude Code freezes pane paint during a long tool call (an hour-long suite),
# so hash detection sees a dead screen. CPU burn is the agent-agnostic proof.
# Child PRESENCE is not: persistent MCP servers (npm exec …-mcp, uvx) live for
# the whole session and would make every lane permanently un-wedgeable.
LANE_WHASH=(); LANE_WCNT=(); LANE_PCPU=()
FAKE_AGENT_LIVE=1
lane_active_command() { return 1; }
lane_terminal_or_idle() { return 1; }
FAKE_PANE_TXT='frozen for an hour during tests/run.sh'
FAKE_CPU=100; pane_wedged a 0; :          # first sight seeds the baseline
FAKE_CPU=140                              # +40s CPU: a suite is running
wedge_cnt_set a 99
pane_wedged a 0; rcBusy=$?
assert_eq "cpu-burn-never-wedges"    "1" "$rcBusy"
assert_eq "cpu-burn-resets-counter"  "0" "$(wedge_cnt_get a)"

# an idle agent with live MCP servers burns ~nothing and MUST still wedge
LANE_WHASH=(); LANE_WCNT=(); LANE_PCPU=()
FAKE_CPU=200; pane_wedged a 0; :
FAKE_CPU=200                              # idle: no CPU advance
wedge_cnt_set a 500                       # far past any live-turn grace
pane_wedged a 0; rcIdle=$?
assert_eq "idle-with-mcp-children-still-wedges" "0" "$rcIdle"
FAKE_AGENT_LIVE=0

finish
