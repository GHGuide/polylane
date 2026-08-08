#!/usr/bin/env bash
# A replacement runner adopts its own surviving tmux panes instead of launching
# duplicate Codex processes or colliding on `tmux new-session`.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

if ! command -v tmux >/dev/null 2>&1; then
  pass "session-resume-skipped-no-tmux"
  finish
  exit 0
fi

# An installed client is not a usable runtime when host policy blocks its Unix
# socket. Probe an actual session so this integration test does not report five
# misleading product failures before any runner code executes.
TMUX_PROBE_SESSION="polylane-test-probe-$$"
tmux new-session -d -s "$TMUX_PROBE_SESSION" "sh -c 'sleep 5'" >/dev/null 2>&1 || true
if ! tmux has-session -t "$TMUX_PROBE_SESSION" 2>/dev/null; then
  pass "session-resume-skipped-unusable-tmux"
  finish
  exit 0
fi
tmux kill-session -t "$TMUX_PROBE_SESSION" 2>/dev/null || true

make_tmpdir
TMUX_SESSION="polylane-test-adopt-$$"
trap 'tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true; cleanup_tmpdirs' EXIT

PROJECT_ROOT="$TEST_TMPDIR/project"
MANIFEST="$PROJECT_ROOT/.polylane/run.json"
RUN_ID="run-adopt"
polylane_tmux_configure "$RUN_ID" ensure
RESUME=1
DRY_RUN=0
INT_NAME=integrator
INT_WORKTREE="$TEST_TMPDIR/int"
LANE_NAMES=(builder)
LANE_WORKTREES=("$TEST_TMPDIR/builder")
LANE_PANE_IDX=(-1)
LANE_RESUMED=(0)
LANE_ADOPTED=(0)
mkdir -p "$PROJECT_ROOT/.polylane" "$LANE_WORKTREES" "$INT_WORKTREE"
PROJECT_ROOT=$(cd "$PROJECT_ROOT" && pwd -P)
MANIFEST="$PROJECT_ROOT/.polylane/run.json"

tmux new-session -d -s "$TMUX_SESSION" -c "$LANE_WORKTREES" \
  "sh -c 'sleep 20'"
tmux set-option -q -t "$TMUX_SESSION" @polylane_run_id "$RUN_ID"
tmux set-option -q -t "$TMUX_SESSION" @polylane_project "$PROJECT_ROOT"

adopt_existing_session
assert_eq "resume-session-started" "1" "$SESSION_STARTED"
assert_eq "resume-pane-adopted" "1" "${LANE_ADOPTED[0]}"
assert_eq "resume-pane-index" "0" "${LANE_PANE_IDX[0]}"
assert_ok "resume-session-owned" session_owned_by_run

# A fresh observer with no POLYLANE_SESSION environment recovers the exact live
# attach command from those ownership tags.
printf '{"base":"main","run_id":"%s","integrator":{"name":"integrator","branch":"lane/int","worktree":"%s"},"lanes":[{"name":"builder","branch":"lane/builder","worktree":"%s"}]}\n' \
  "$RUN_ID" "$INT_WORKTREE" "${LANE_WORKTREES[0]}" > "$MANIFEST"
printf '%s runner=alive restarts=0\n' "$(date '+%F %T')" > "$PROJECT_ROOT/.polylane/supervisor-heartbeat"
watch=$(unset POLYLANE_SESSION; "$(dirname "$RUNNER")/polylane-cycle.sh" runtime "$MANIFEST" 0)
assert_eq "resume-observer-discovers-session" "env -u TMUX TMUX_TMPDIR=$TMUX_TMPDIR tmux attach -t $TMUX_SESSION" "$watch"

# tmux reports a login shell while Codex may be its child. The health check must
# inspect descendants and leave that live agent alone.
ln -s /bin/sleep "$TEST_TMPDIR/codex"
tmux respawn-pane -k -t "$TMUX_SESSION:0.0" \
  "zsh -c '$TEST_TMPDIR/codex 20 & wait'"
sleep 0.2
AGENT=codex
assert_fail "resume-live-child-not-dead" pane_dead 0

# Same session name with different ownership must be rejected.
tmux set-option -q -t "$TMUX_SESSION" @polylane_run_id "other-run"
assert_fail "resume-foreign-session-rejected" session_owned_by_run

finish
