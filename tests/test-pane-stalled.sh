#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034 # sourced runner consumes fixture globals
# pane_stalled requires a live credits/upgrade decision, never prose alone.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
FAKE_BIN="$TEST_TMPDIR/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${TMUX_ARGS_LOG:-/dev/null}"
if [[ " $* " == *" capture-pane "* && " $* " == *" -J "* ]]; then
  printf '%s\n' "${PANE_TEXT_JOINED:-${PANE_TEXT:-}}"
else
  printf '%s\n' "${PANE_TEXT:-}"
fi
EOF
chmod +x "$FAKE_BIN/tmux"
PATH="$FAKE_BIN:$PATH"
TMUX_SESSION="pane-stalled-test"
TMUX_ARGS_LOG="$TEST_TMPDIR/tmux-args.log"
export TMUX_ARGS_LOG
: > "$TMUX_ARGS_LOG"

export PANE_TEXT='Source prose says usage limit, but no action is offered.'
assert_fail "pane-stalled-prose-usage-limit-is-not-paywall" pane_stalled 0

export PANE_TEXT="printf '%s' '\\''usage limit|Switch to usage credits'"
assert_fail "pane-stalled-source-line-is-not-paywall" pane_stalled 0

export PANE_TEXT='Usage limit reached. Switch to usage credits to continue. [1] Switch [2] Cancel'
assert_ok "pane-stalled-credits-decision-is-paywall" pane_stalled 0

export PANE_TEXT='You need more capacity. Upgrade your plan. [1] Upgrade [2] Cancel'
assert_ok "pane-stalled-upgrade-decision-is-paywall" pane_stalled 0

export PANE_TEXT="You've hit your session limit · resets 8:40pm (Europe/Chisinau)
/usage-credits to finish what you’re working on."
assert_ok "pane-stalled-no-menu-session-cooldown" pane_stalled 0
assert_ok "pane-session-cooldown-exact-ui" pane_session_cooldown 0
POLYLANE_NOW_HM=20:39
assert_fail "pane-session-reset-not-due-before-time" pane_session_reset_due 0
POLYLANE_NOW_HM=20:40
assert_ok "pane-session-reset-due-at-time" pane_session_reset_due 0
POLYLANE_NOW_HM=20:41
assert_ok "pane-session-reset-due-after-time" pane_session_reset_due 0
unset POLYLANE_NOW_HM

# The cooldown path bypasses the ordinary fallback/credits policy: wait before
# the printed reset, then resume the exact frozen lane once the free window is
# due. No model fallback or paid-credit keystroke is attempted.
LANE_NAMES=(a); LANE_PANE_IDX=(0); LANE_WORKTREES=("$TEST_TMPDIR/wt")
mkdir -p "$TEST_TMPDIR/wt/docs"
STALLED_LANES=a
RESPAWNS=0
RESUME_MODE=""
notify_event() { :; }
respawn_lane() { RESPAWNS=$((RESPAWNS + 1)); RESUME_MODE="${5:-}"; }
POLYLANE_ON_LIMIT=fallback
POLYLANE_NOW_HM=20:39
resolve_stalls "a:$TEST_TMPDIR/wt" > "$TEST_TMPDIR/wait.out"
WAIT_OUT=$(cat "$TEST_TMPDIR/wait.out")
assert_contains "session-cooldown-waits-before-free-reset" "waiting for its printed free reset" "$WAIT_OUT"
assert_eq "session-cooldown-does-not-respawn-early" "0" "$RESPAWNS"
assert_eq "session-cooldown-remains-stalled-before-reset" "a" "$STALLED_LANES"
POLYLANE_NOW_HM=20:40
resolve_stalls "a:$TEST_TMPDIR/wt" > "$TEST_TMPDIR/resume.out"
RESUME_OUT=$(cat "$TEST_TMPDIR/resume.out")
assert_contains "session-cooldown-resumes-at-free-reset" "free reset window reached" "$RESUME_OUT"
assert_eq "session-cooldown-respawns-once" "1" "$RESPAWNS"
assert_eq "session-cooldown-preserves-live-conversation" "resume" "$RESUME_MODE"
assert_eq "session-cooldown-clears-stall-after-resume" "" "$STALLED_LANES"
unset POLYLANE_NOW_HM POLYLANE_ON_LIMIT

# Codex exits after printing a dated account-wide usage cooldown.  It has no
# numbered menu, so it must enter the same sticky free-reset path instead of
# being misclassified as a dead pane and burning every retry/repair attempt.
export PANE_TEXT="You've hit your usage limit. Visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at Aug 18th, 2026 3:31 PM."
pane_dead() { return 0; }
assert_ok "pane-stalled-codex-dated-usage-cooldown" pane_stalled 0
assert_ok "pane-session-cooldown-codex-exact-ui" pane_session_cooldown 0
POLYLANE_CODEX_TZ=Europe/Chisinau
POLYLANE_NOW_EPOCH=1787056259
assert_fail "pane-codex-reset-not-due-one-second-before" pane_session_reset_due 0
POLYLANE_NOW_EPOCH=1787056260
assert_ok "pane-codex-reset-due-at-time" pane_session_reset_due 0

export PANE_TEXT="You've hit your usage limit. Visit https://chatgpt.com/codex/settings/usage to purchase more credits or Try again at Aug 18th, 2026 3:31 pm."
assert_ok "pane-codex-reset-parser-is-case-insensitive" pane_session_cooldown 0
assert_ok "pane-codex-reset-case-variant-due" pane_session_reset_due 0

export PANE_TEXT=$'You\'ve hit your usage limit. Visit https://chatgpt.com/codex/settings/\nusage to purchase more credits or try again at Aug 18th, 2026 3:31 PM.'
export PANE_TEXT_JOINED="You've hit your usage limit. Visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at Aug 18th, 2026 3:31 PM."
assert_ok "pane-codex-wrapped-terminal-output-is-joined" pane_session_cooldown 0
assert_contains "pane-codex-capture-requests-joined-lines" "capture-pane -J -S -20" "$(cat "$TMUX_ARGS_LOG")"
unset PANE_TEXT_JOINED

export PANE_TEXT="You've hit your usage limit. Visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at Aug 18th, 2026 3:31 PM."
pane_dead() { return 1; }
assert_fail "pane-codex-exact-message-in-live-work-is-not-cooldown" pane_session_cooldown 0
pane_dead() { return 0; }

for malformed in \
  "Apr 31st, 2026 3:31 PM" \
  "Feb 29th, 2027 3:31 PM" \
  "Aug 0th, 2026 3:31 PM" \
  "Aug 18th, 2026 0:31 PM"; do
  export PANE_TEXT="You've hit your usage limit. Visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at $malformed."
  assert_fail "pane-codex-malformed-date-rejected-$malformed" pane_session_cooldown 0
done

export PANE_TEXT="You've hit your usage limit. Visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at Aug 18th, 2026 3:31 PM."
TZ=UTC
export TZ
POLYLANE_CODEX_TZ=Europe/Chisinau
assert_ok "pane-codex-explicit-display-timezone-wins" pane_session_reset_due 0
POLYLANE_CODEX_TZ='../invalid'
assert_fail "pane-codex-invalid-display-timezone-fails-closed" pane_session_cooldown 0
POLYLANE_CODEX_TZ='Not/AZone'
assert_fail "pane-codex-missing-display-timezone-fails-closed" pane_session_cooldown 0
POLYLANE_CODEX_TZ=Europe/Chisinau

STALLED_LANES=a
RESPAWNS=0
RESUME_MODE=""
POLYLANE_ON_LIMIT=fallback
POLYLANE_NOW_EPOCH=1787056259
resolve_stalls "a:$TEST_TMPDIR/wt" > "$TEST_TMPDIR/codex-wait.out"
assert_eq "codex-cooldown-does-not-fallback-before-reset" "0" "$RESPAWNS"
assert_eq "codex-cooldown-remains-stalled-before-reset" "a" "$STALLED_LANES"
POLYLANE_NOW_EPOCH=1787056260
resolve_stalls "a:$TEST_TMPDIR/wt" > "$TEST_TMPDIR/codex-resume.out"
assert_eq "codex-cooldown-respawns-once-at-reset" "1" "$RESPAWNS"
assert_eq "codex-cooldown-resumes-frozen-conversation" "resume" "$RESUME_MODE"
assert_eq "codex-cooldown-clears-stall-after-resume" "" "$STALLED_LANES"
unset POLYLANE_NOW_EPOCH POLYLANE_ON_LIMIT POLYLANE_CODEX_TZ TZ

export PANE_TEXT="Documentation example: You've hit your session limit and it resets 8:40pm."
assert_fail "pane-session-limit-prose-without-live-command-is-not-stalled" pane_stalled 0

export PANE_TEXT='Build passed: usage limit fixture mentioned in test output.'
assert_fail "pane-stalled-passing-output-is-not-paywall" pane_stalled 0

finish
