#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034 # sourced runner consumes fixture globals
# Missing mapped panes must be recreated before any launch/retry is counted.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
# This fixture verifies the runner's default three-attempt recovery contract.
# A self-hosted terminal suite may inherit a stricter live-run policy; keep that
# operator setting out of the unit fixture without changing the parent process.
unset POLYLANE_MAX_RETRIES
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
FAKE_WORKTREE_PANES=""
polylane_tmux_find_pane() {
  local session="$1" run_id="$2" worktree="$3" line
  for line in $FAKE_WORKTREE_PANES; do
    [ "${line#*|}" = "$worktree" ] && { printf '%s' "${line%%|*}"; return 0; }
  done
  return 1
}
polylane_tmux_tag_pane() { printf 'tag %s %s %s %s %s\n' "$@" >> "$KEYLOG"; }
tmux() {
  case "$1" in
    display-message)
      case "$*" in
        *'#{pane_current_command}'*) printf 'zsh\n' ;;
        *'#{pane_pid}'*) printf '4242\n' ;;
      esac
      ;;
    *) printf '%s\n' "$*" >> "$KEYLOG" ;;
  esac
  case "$1" in
    list-panes)
      case "$*" in
        *'#{pane_index}|#{pane_current_path}'*) printf '%s\n' $FAKE_WORKTREE_PANES ;;
        *) printf '%s\n' $FAKE_PANES ;;
      esac
      ;;
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

# tmux may report its shell while a Codex child is still actively running.
# A manifest reader can leave IFS='|'; process matching must restore ordinary
# word splitting instead of treating `codex node` as one impossible process.
AGENT=codex
ps() { printf 'codex\n'; }
pgrep() { :; }
IFS='|'
assert_ok "quiet-codex-child-is-live" pane_agent_live 4
assert_fail "quiet-codex-child-is-not-dead" pane_dead 4
IFS=$' \t\n'

health_check "builder:$TEST_TMPDIR/wt"
assert_eq "missing-pane-remapped" "7" "${LANE_PANE_IDX[0]}"
assert_eq "missing-pane-counts-after-launch" "1" "${LANE_RETRIES[7]}"
assert_contains "missing-pane-creates-owned-pane" "split-window -t recovery-test:0 -P -F #{pane_index}" "$(cat "$KEYLOG")"
assert_contains "missing-pane-attaches-log" "pipe 7 builder" "$(cat "$KEYLOG")"
assert_contains "missing-pane-tags-replacement" "tag recovery-test 7 recovery-run builder $TEST_TMPDIR/wt" "$(cat "$KEYLOG")"
assert_eq "missing-pane-never-sends-old-target" "0" "$(grep -c 'recovery-test:0.4' "$KEYLOG" || true)"

# tmux can renumber a surviving pane after another pane exits. The numeric
# mapping is then stale even though the worker is still alive at the same
# worktree. Recovery must rebind that pane, preserve its retry state, and never
# split a duplicate agent into the same worktree.
: > "$KEYLOG"
FAKE_PANES='0 2'
FAKE_WORKTREE_PANES="2|$TEST_TMPDIR/wt"
LANE_PANE_IDX=(4); LANE_RETRIES=(); LANE_RETRIES[4]=2
LANE_REPAIRS=(); LANE_REPAIRS[4]=1
health_check "builder:$TEST_TMPDIR/wt"
assert_eq "renumbered-pane-rebound" "2" "${LANE_PANE_IDX[0]}"
assert_eq "renumbered-pane-preserves-retries" "2" "${LANE_RETRIES[2]}"
assert_eq "renumbered-pane-preserves-repairs" "1" "${LANE_REPAIRS[2]}"
assert_eq "renumbered-pane-never-duplicates" "0" "$(grep -c 'split-window' "$KEYLOG" || true)"
assert_contains "renumbered-pane-restores-log" "pipe 2 builder" "$(cat "$KEYLOG")"

# Pane indices are tmux-owned and may be renumbered when completed panes leave.
# A later integrator launch must trust split-window's returned index, not a stale
# NEXT_PANE_IDX guess, or the runner seeds a missing pane and a resume duplicates it.
NEXT_PANE_IDX=9
new_pane integrator >/dev/null
assert_eq "new-pane-uses-tmux-returned-index" "7" "$NEW_PANE_IDX"
assert_eq "new-pane-next-follows-actual-index" "8" "$NEXT_PANE_IDX"

# Failed lanes retain the actual recovery cause, not a generic retry label.
# A missing mapped pane and a finite live-turn silence cap require different
# operator actions and must therefore survive to report publication.
FAILED_LANES=""; LANE_FAILURE_REASONS=(); LANE_PANE_IDX=(4); FAKE_PANES='0 1 7'; FAKE_WORKTREE_PANES=""
POLYLANE_MAX_RETRIES=0
health_check "builder:$TEST_TMPDIR/wt"
assert_eq "missing-pane-stores-exact-failure-reason" "mapped pane missing past retries" "$(lane_failure_reason_get builder)"

FAILED_LANES=""; LANE_FAILURE_REASONS=(); LANE_PANE_IDX=(7); FAKE_PANES='0 1 7'; FAKE_WORKTREE_PANES=""
pane_agent_live() { return 0; }
lane_terminal_turn() { return 1; }
pane_wedged() { return 0; }
POLYLANE_MAX_REPAIRS=0
POLYLANE_LIVE_WEDGE_HARD_SECONDS=60
health_check "builder:$TEST_TMPDIR/wt"
assert_eq "live-turn-stores-effective-silence-reason" "live turn silence cap exhausted after 60s" "$(lane_failure_reason_get builder)"

FAILED_LANES=""; LANE_FAILURE_REASONS=(); LANE_PANE_IDX=(7); FAKE_PANES='0 1 7'
pane_retryable_error() { return 0; }
pane_wedged() { return 1; }
health_check "builder:$TEST_TMPDIR/wt"
assert_eq "retry-exhaustion-retains-actual-transient-cause" \
  "transient/dead/wedged retries and repairs exhausted: a transient error after agent exit" \
  "$(lane_failure_reason_get builder)"

INT_NAME=integrator
INT_PANE_IDX=7
FAILED_LANES=""; INT_FAILURE_REASON=""; LANE_FAILURE_REASONS=(); LANE_RETRIES=(); LANE_REPAIRS=()
pane_retryable_error() { return 1; }
pane_agent_live() { return 0; }
lane_terminal_turn() { return 1; }
pane_wedged() { return 0; }
POLYLANE_MAX_RETRIES=0
POLYLANE_MAX_REPAIRS=0
POLYLANE_LIVE_WEDGE_HARD_SECONDS=60
health_check "integrator:$TEST_TMPDIR/wt"
assert_eq "integrator-health-stores-live-turn-reason" "live turn silence cap exhausted after 60s" "$(lane_failure_reason_get integrator)"
assert_eq "integrator-health-records-failed-lane" "integrator" "$FAILED_LANES"
unset POLYLANE_MAX_RETRIES POLYLANE_MAX_REPAIRS POLYLANE_LIVE_WEDGE_HARD_SECONDS

# A clean, current-run committed handoff that violates its declared ownership is
# terminal evidence, not an unfinished pane. It must retain the offending path
# and consume neither retry nor repair budget across repeated polls.
SCOPE_WT="$TEST_TMPDIR/scope-wt"
git init -q -b main "$SCOPE_WT"
git -C "$SCOPE_WT" config user.email test@example.invalid
git -C "$SCOPE_WT" config user.name test
mkdir -p "$SCOPE_WT/docs"
printf 'base\n' > "$SCOPE_WT/base.txt"
git -C "$SCOPE_WT" add base.txt && git -C "$SCOPE_WT" commit -qm base
SCOPE_BASE=$(git -C "$SCOPE_WT" rev-parse HEAD)
printf 'escaped\n' > "$SCOPE_WT/outside.txt"
printf 'STATUS: scope DONE run=scope-run\n' > "$SCOPE_WT/docs/status-scope.md"
git -C "$SCOPE_WT" add outside.txt docs/status-scope.md && git -C "$SCOPE_WT" commit -qm done
SCOPE_MANIFEST="$TEST_TMPDIR/scope-run.json"
printf '%s\n' '{"base":"main","lanes":[{"name":"scope","own_globs":["docs/status-scope.md"]}]}' > "$SCOPE_MANIFEST"
MANIFEST="$SCOPE_MANIFEST"; BASE="$SCOPE_BASE"; ORCHESTRATION_CONTRACT=2; RUN_ID=scope-run
REPO_ROOT="$TEST_TMPDIR/recovery-repo"; mkdir -p "$REPO_ROOT/docs/lane-logs"
LANE_NAMES=(scope); LANE_WORKTREES=("$SCOPE_WT"); LANE_PANE_IDX=(7); LANE_RETRIES=(); LANE_REPAIRS=()
FAILED_LANES=""; LANE_FAILURE_REASONS=(); RESPAWNS=0
pane_for_worktree() { return 1; }
pane_exists() { return 0; }
pane_retryable_error() { return 1; }
pane_dead() { return 1; }
pane_wedged() { return 1; }
respawn_lane() { RESPAWNS=$((RESPAWNS + 1)); }
scope_reason=$(lane_completion_scope_failure_reason "$SCOPE_WT" scope 2>&1 || true)
assert_contains "scope-handoff-captures-real-offending-path" "outside.txt" "$scope_reason"
health_check "scope:$SCOPE_WT"
assert_eq "scope-handoff-fails-lane-once" "scope" "$FAILED_LANES"
assert_contains "scope-handoff-stores-bounded-real-reason" "outside.txt" "$(lane_failure_reason_get scope)"
assert_eq "scope-handoff-never-respawns" "0" "$RESPAWNS"
health_check "scope:$SCOPE_WT"
assert_eq "scope-handoff-repeat-does-not-replan-or-respawn" "0" "$RESPAWNS"

# An uncommitted marker/worktree is still in progress, never terminal evidence.
printf 'uncommitted\n' > "$SCOPE_WT/dirty.txt"
dirty_reason=$(lane_completion_scope_failure_reason "$SCOPE_WT" scope 2>&1 || true)
assert_eq "scope-handoff-dirty-tree-is-not-terminal" "" "$dirty_reason"

finish
