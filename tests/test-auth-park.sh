#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034 # sourced runner consumes fixture globals
# AUTH-EXPIRED PANES — a lane whose provider login died shows "Login expired ·
# Please run /login" and waits forever. That pane matches no error/stall/approval
# signature; the wedge detector used to respawn it into the same login screen
# until the restart cap halted the run with a misleading "runner died" diagnosis
# (observed live 2026-08-18, 4 frozen lanes). Respawning cannot mint credentials:
# the only correct move is park + surface, exactly once, and never respawn.
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

TMUX_SESSION=atest
LANE_NAMES=(a); LANE_PANE_IDX=(0); LANE_WORKTREES=("$TEST_TMPDIR/wt")
LANE_EFFORTS=(high); LANE_WHASH=(); LANE_WCNT=(); LANE_RETRIES=(); LANE_RESUMED=(0)
FAILED_LANES=""; STALLED_LANES=""; NEEDS_DECISION_LANES=""
mkdir -p "$TEST_TMPDIR/wt/docs"
notify_event() { :; }

# --- login-expired pane -> parked, no keys sent -------------------------------
FAKE_PANE_TXT='⏺ Login expired · Please run /login
Not logged in · Run /login
❯ '
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_ok  "auth-expired-parks-lane" lane_needs_decision a
assert_eq  "auth-expired-no-keys" "" "$(cat "$KEYLOG")"

# parked exactly once — a second sweep must not duplicate the escalation
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_eq "auth-park-idempotent" "a" "${NEEDS_DECISION_LANES}"

# --- other login phrasings also park ------------------------------------------
NEEDS_DECISION_LANES=""
FAKE_PANE_TXT='OAuth session expired and could not be refreshed'
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_ok "oauth-expired-parks-lane" lane_needs_decision a

# --- a working pane is untouched ----------------------------------------------
NEEDS_DECISION_LANES=""
FAKE_PANE_TXT='✻ Ideating… (2m · thinking)'
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_fail "working-pane-not-parked" lane_needs_decision a

# a DONE lane is never parked even if the screen shows a login banner
printf 'STATUS: a DONE\n' > "$TEST_TMPDIR/wt/docs/status-a.md"
FAKE_PANE_TXT='Login expired · Please run /login'
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_fail "done-lane-not-parked" lane_needs_decision a
rm -f "$TEST_TMPDIR/wt/docs/status-a.md"

# --- prose ABOUT logins must not park (word-boundary / dialog-shape guard) ----
NEEDS_DECISION_LANES=""
FAKE_PANE_TXT='⏺ Reading auth.md — the doc says users who see "login expired" messages should re-authenticate; adding that note to the runbook now'
startup_check "a:$TEST_TMPDIR/wt" >/dev/null
assert_fail "prose-about-login-not-parked" lane_needs_decision a

# --- health_check skips a parked lane (no respawn into the login screen) ------
NEEDS_DECISION_LANES="a"
RESPAWNS=0
respawn_lane() { RESPAWNS=$((RESPAWNS + 1)); }
recreate_lane_pane() { RESPAWNS=$((RESPAWNS + 1)); }
pane_exists() { return 0; }
pane_index_for() { printf '0'; }
pane_agent_live() { return 0; }
lane_active_command() { return 1; }
lane_terminal_or_idle() { return 1; }
pane_retryable_error() { return 1; }
pane_dead() { return 1; }
material_progress_stalled() { return 1; }
resolve_stalls() { :; }
lane_completion_scope_failure_reason() { :; }
pane_for_worktree() { printf '0'; }
pane_wedged() { return 0; }   # even a "wedged" parked lane stays parked
health_check "a:$TEST_TMPDIR/wt" >/dev/null 2>&1
assert_eq "parked-lane-never-respawned" "0" "$RESPAWNS"

# --- safe file reads auto-approve; secret-bearing targets never do ------------
# Claude renders home paths as ~/…; the whole-screen critical scan once parked a
# lane for an hour over its own armed kit path. Target line decides, not screen.
KIT_TXT=' Read file
  Read(~/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/systematic-debugging/SKILL.md)
 Do you want to proceed?
 ❯ 1. Yes
   2. Yes, allow reading from systematic-debugging/ during this session
   3. No'
assert_ok  "kit-read-is-safe" approval_is_safe_read "$KIT_TXT"
SECRET_TXT=' Read file
  Read(~/.ssh/id_rsa)
 Do you want to proceed?
 ❯ 1. Yes
   2. No'
assert_fail "secret-read-not-safe" approval_is_safe_read "$SECRET_TXT"
ENV_TXT=' Read(  /repo/.env.production )
 Do you want to proceed?
 ❯ 1. Yes'
assert_fail "env-read-not-safe" approval_is_safe_read "$ENV_TXT"
BASH_TXT=' Bash command
   rm -rf /
 Do you want to proceed?
 ❯ 1. Yes'
assert_fail "bash-dialog-not-a-read" approval_is_safe_read "$BASH_TXT"
# surrounding screen text with the word token must NOT block a benign read target
NOISE_TXT=' … prompt tail mentions api_key and token handling …
 Read file
  Read(/repo/references/visual-intelligence.md)
 Do you want to proceed?
 ❯ 1. Yes'
assert_ok "screen-noise-does-not-block-read" approval_is_safe_read "$NOISE_TXT"

# --- an answered dialog unparks the lane in health_check -----------------------
NEEDS_DECISION_LANES="a"
pane_awaiting_approval() { return 1; }   # dialog gone
FAKE_PANE_TXT='✻ working again'
RESPAWNS=0
health_check "a:$TEST_TMPDIR/wt" >/dev/null 2>&1
assert_fail "answered-dialog-unparks" lane_needs_decision a

# a still-pending dialog keeps the park
NEEDS_DECISION_LANES="a"
RESPAWNS=0
pane_awaiting_approval() { return 0; }
health_check "a:$TEST_TMPDIR/wt" >/dev/null 2>&1
assert_ok "pending-dialog-stays-parked" lane_needs_decision a
assert_eq "pending-dialog-no-respawn" "0" "$RESPAWNS"

finish
