#!/usr/bin/env bash
#
# polylane-supervisor.sh <manifest.json> [runner-args...]
#
# Crash-proof outer loop for polylane-run.sh — makes RUNNER DEATH A NON-EVENT.
# Real runs (Twin Delta, LeLau: 5,400+ message sessions) showed the dominant
# failure mode is not bad lane work but the long-lived runner dying mid-run
# ("runner died again — the recurring failure mode"), which silently stops
# polling, approval-relay, integration, and merge until a human notices. This
# supervisor owns the runner's lifecycle:
#
#   launch  : starts polylane-run.sh (with --yes) as a child, logs to a file
#   watch   : every POLYLANE_SUP_INTERVAL (20s) —
#               * drains permission prompts (approval relay OUTSIDE the runner,
#                 so a dead runner no longer strands lanes on approvals):
#                 SAFE -> auto-approve; CRITICAL -> park + notify (never answered)
#               * writes a heartbeat file (polylane-state.sh surfaces its age)
#   revive  : runner exited WITHOUT writing this run's report -> crash. Relaunch
#             with --resume (idempotent: DONE lanes are skipped) up to
#             POLYLANE_SUP_MAX_RESTARTS (10). A runner that DID write the report
#             ended legitimately (GO or NO-GO) -> exit with its code. NO-GO is a
#             clean verdict, NOT a crash — never "revived" into a zombie run.
#   halt    : restart cap exhausted -> notify halt, exit 1, worktrees intact.
#
# Panes are found by WORKTREE PATH, not remembered index, so the relay works
# across restarts. `--check-once` runs a single watch tick with no launch (ops /
# tests). bash-3.2 safe.
#
# Env: POLYLANE_SESSION (tmux session), POLYLANE_SUP_INTERVAL, POLYLANE_SUP_MAX_RESTARTS.

set -euo pipefail

SUP_MANIFEST="${1:?usage: polylane-supervisor.sh <manifest.json> [runner-args...]}"
shift || true

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# Runner is inert when sourced (main guarded by BASH_SOURCE) — reuse its
# detectors: pane_awaiting_approval, approval_is_critical, pane_stalled,
# lane_done, parse_verdict, notify_event.
# shellcheck source=polylane-run.sh
. "$SCRIPT_DIR/polylane-run.sh"

TMUX_SESSION="${POLYLANE_SESSION:-polylane}"
SUP_INTERVAL="${POLYLANE_SUP_INTERVAL:-20}"
SUP_MAX_RESTARTS="${POLYLANE_SUP_MAX_RESTARTS:-10}"
# per-run nonce: the sourced lane_done must trust markers by the SAME run= tag the
# runner uses, else nonce-tagged DONE lanes read as not-done and get needlessly revived.
# shellcheck disable=SC2034  # consumed by the sourced runner's lane_done
RUN_ID=$(jq -r '.run_id // ""' "$SUP_MANIFEST")

MDIR=$(cd "$(dirname "$SUP_MANIFEST")" && pwd)
PROJECT_ROOT=$(cd "$MDIR/.." && pwd)
REPORT="$PROJECT_ROOT/docs/polylane-report.md"
HEARTBEAT="$MDIR/supervisor-heartbeat"
RUNNER_LOG="$MDIR/runner.log"
DECIDED=""            # lanes parked on a critical approval (notified once)
SUP_START=$(date +%s)

sup_log() { printf '[supervisor %s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

# report_fresh : 0 iff the run report exists and was written AFTER we started —
# a stale report from a previous cycle must not read as "this run finished"
# (a stale report file fooled finish-detection in a real run).
report_fresh() {
  [ -f "$REPORT" ] || return 1
  local mt; mt=$(stat -f %m "$REPORT" 2>/dev/null || stat -c %Y "$REPORT" 2>/dev/null || echo 0)
  [ "$mt" -ge "$SUP_START" ]
}

# pane_for_wt WT : print the pane index whose cwd is WT, else fail.
pane_for_wt() {
  local wt="$1" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in *"|$wt") printf '%s' "${line%%|*}"; return 0 ;; esac
  done < <(tmux list-panes -t "$TMUX_SESSION:0" -F '#{pane_index}|#{pane_current_path}' 2>/dev/null || true)
  return 1
}

# drain_approvals : the runner-independent approval relay. For every unfinished
# lane pane sitting on a permission menu: safe -> approve; critical -> park+notify.
drain_approvals() {
  local name wt idx txt
  while IFS='|' read -r name wt; do
    [ -n "$name" ] || continue
    lane_done "$wt" "$name" && continue
    idx=$(pane_for_wt "$wt") || continue
    pane_awaiting_approval "$idx" || continue
    txt=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p -S -20 2>/dev/null || true)
    if approval_is_critical "$txt"; then
      case " $DECIDED " in *" $name "*) continue ;; esac
      DECIDED="$DECIDED $name"
      sup_log "lane '$name' asks a CRITICAL approval — parked for a human decision"
      notify_event approval "lane '$name' asks approval for a critical action — decide in chat"
    else
      if printf '%s' "$txt" | grep -qE '2\.[[:space:]]*Yes'; then
        tmux send-keys -t "$TMUX_SESSION:0.$idx" '2' 2>/dev/null || true
      else
        tmux send-keys -t "$TMUX_SESSION:0.$idx" '1' 2>/dev/null || true
      fi
      sup_log "auto-approved a safe prompt for lane '$name'"
    fi
  done < <(jq -r '(.lanes[] | "\(.name)|\(.worktree)"), (.integrator | "\(.name)|\(.worktree)")' "$SUP_MANIFEST")
}

heartbeat() { printf '%s runner=%s restarts=%s\n' "$(date '+%F %T')" "$1" "$2" > "$HEARTBEAT" 2>/dev/null || true; }

# one watch tick (also the --check-once body): relay + heartbeat.
tick() { drain_approvals; heartbeat "${1:-unknown}" "${2:-0}"; }

# --- main ----------------------------------------------------------------------
supervisor_main() {
  local restarts=0 rc pid args_line
  # default --yes: the supervisor IS the unattended path; keep user args too.
  case " $* " in *" --yes "*) args_line="$*" ;; *) args_line="--yes${*:+ $*}" ;; esac

  while :; do
    sup_log "launching runner (attempt $((restarts + 1))/$((SUP_MAX_RESTARTS + 1))): polylane-run.sh $SUP_MANIFEST $args_line"
    # shellcheck disable=SC2086  # args_line is intentionally word-split
    POLYLANE_SESSION="$TMUX_SESSION" "$SCRIPT_DIR/polylane-run.sh" "$SUP_MANIFEST" $args_line >> "$RUNNER_LOG" 2>&1 &
    pid=$!

    while kill -0 "$pid" 2>/dev/null; do
      tick alive "$restarts"
      sleep "$SUP_INTERVAL"
    done
    # a crashed child returns nonzero from `wait` — must NOT kill the supervisor
    rc=0; wait "$pid" 2>/dev/null || rc=$?

    if report_fresh; then
      # legitimate end — GO (rc 0) or NO-GO (rc 1). Either way: done, not a crash.
      sup_log "runner finished legitimately (rc=$rc, report written) — supervisor exiting"
      heartbeat finished "$restarts"
      return "$rc"
    fi

    restarts=$((restarts + 1))
    if [ "$restarts" -gt "$SUP_MAX_RESTARTS" ]; then
      sup_log "runner died without a report and the restart cap ($SUP_MAX_RESTARTS) is exhausted — halting"
      notify_event halt "supervisor: runner crashed ${restarts}x without finishing — halted, worktrees intact"
      heartbeat halted "$restarts"
      return 1
    fi
    sup_log "runner DIED without a report (rc=$rc) — reviving with --resume (${restarts}/${SUP_MAX_RESTARTS})"
    notify_event stall "supervisor revived the runner (crash ${restarts}/${SUP_MAX_RESTARTS})"
    case " $args_line " in *" --resume "*) : ;; *) args_line="$args_line --resume" ;; esac
  done
}

if [ "${1:-}" = "--check-once" ] || [ "${SUP_CHECK_ONCE:-0}" = "1" ]; then
  tick check-once 0
  exit 0
fi

# Only run when executed directly (tests source the functions above).
if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  supervisor_main "$@"
fi
