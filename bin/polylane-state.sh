#!/usr/bin/env bash
#
# polylane-state.sh <manifest.json> [--json]
#
# THE single authoritative state surface for a polylane run. One invocation
# answers everything an orchestrator/human otherwise reconstructs by hand from
# panes + git + files (the #1 turn-burner in real runs):
#
#   runner   : alive | dead            (is a polylane-run.sh driving this manifest?)
#   verdict  : GO | EXTERNAL-EVIDENCE-OPEN | NO-GO | UNKNOWN
#   report   : present | absent        (docs/polylane-report.md)
#   heartbeat: age of the supervisor heartbeat, if one is running
#   per lane : status · pane · branch HEAD · commits ahead of base
#
# Lane status precedence (first match wins):
#   done               status file says DONE (the runner's own signal)
#   awaiting-approval  pane is sitting on a permission menu (critical? flagged)
#   stalled            pane shows a usage-limit / paywall prompt
#   errored            pane shows a transient API/network error signature
#   likely-done        no live pane BUT the branch has commits — work exists,
#                      done-signal missing (verify + recover, don't wait)
#   working            pane alive, agent process in the foreground
#   no-pane            lane has no pane and no commits (not started / lost)
#
# Panes are discovered by WORKTREE PATH (pane_current_path), not by remembered
# index — so state stays correct across runner restarts. Read-only: never sends
# keys, never mutates. bash-3.2 safe.

set -euo pipefail

MANIFEST="${1:?usage: polylane-state.sh <manifest.json> [--json]}"
JSON=0; [ "${2:-}" = "--json" ] && JSON=1
[ -f "$MANIFEST" ] || { echo "polylane-state: no manifest at $MANIFEST" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "polylane-state: jq required" >&2; exit 1; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MDIR=$(cd "$(dirname "$MANIFEST")" && pwd -P)
# Load contract/root before sourcing runner helpers so lane_done uses the
# runner's strict nonce and dirty-tree semantics for this manifest.
PROJECT_ROOT=$(cd "$MDIR/.." && pwd -P)
# shellcheck disable=SC2034  # consumed by the sourced runner's lane_done
ORCHESTRATION_CONTRACT=$(jq -r '.orchestration_contract // 0' "$MANIFEST")
# shellcheck disable=SC2034  # consumed by the sourced runner's lane_done
REPO_ROOT=$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PROJECT_ROOT")
# Source the runner for its battle-tested detectors (parse_verdict, pane_*,
# agent_procs). It only runs main when executed directly, so sourcing is inert.
# shellcheck source=polylane-run.sh
. "$SCRIPT_DIR/polylane-run.sh"

BASE=$(jq -r '.base // "main"' "$MANIFEST")
# per-run nonce: the sourced lane_done/parse_verdict trust markers only when run=
# matches. MUST match the runner's, or a nonce-tagged DONE reads here as not-done.
# shellcheck disable=SC2034  # consumed by the sourced runner's lane_done/parse_verdict
RUN_ID=$(jq -r '.run_id // ""' "$MANIFEST")
polylane_tmux_configure "$RUN_ID"
# shellcheck disable=SC2034  # consumed by the sourced runner's agent_procs/pane_dead
AGENT=$(jq -r '.agent // "claude"' "$MANIFEST")
REPORT="$PROJECT_ROOT/docs/polylane-report.md"

# discover_session : recover the exact session without relying on chat memory or
# the observer's environment. New manifests persist `.session`; upgraded legacy
# runs are discovered from the ownership tags written by polylane-run.sh.
discover_session() {
  local explicit manifest_session session tagged_run tagged_project
  manifest_session=$(jq -r '.session // ""' "$MANIFEST")
  [ -n "$manifest_session" ] && { printf '%s' "$manifest_session"; return; }
  while IFS='|' read -r session tagged_run tagged_project; do
    [ -n "$session" ] || continue
    if [ "$tagged_run" = "${RUN_ID:-}" ] && [ "$tagged_project" = "$PROJECT_ROOT" ]; then
      printf '%s' "$session"
      return
    fi
  done < <(tmux list-sessions -F '#{session_name}|#{@polylane_run_id}|#{@polylane_project}' 2>/dev/null || true)
  explicit="${POLYLANE_SESSION:-}"
  [ -n "$explicit" ] && { printf '%s' "$explicit"; return; }
  printf 'polylane'
}

TMUX_SESSION=$(discover_session)

tmux_session_active() { tmux has-session -t "$TMUX_SESSION" 2>/dev/null; }
tmux_watch_command() { polylane_tmux_watch_command "$TMUX_SESSION"; }

# --- pane discovery by worktree path (index-free, restart-proof) --------------
PANE_LIST=$(tmux list-panes -t "$TMUX_SESSION:0" -F '#{pane_index}|#{pane_current_path}|#{pane_current_command}' 2>/dev/null || true)

pane_for_wt() { # -> "idx|cmd" or ""
  local wt="$1" line idx rest pane_path cmd
  [ ! -d "$wt" ] || wt=$(cd "$wt" 2>/dev/null && pwd -P)
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    idx="${line%%|*}"
    rest="${line#*|}"
    pane_path="${rest%%|*}"
    cmd="${line##*|}"
    [ ! -d "$pane_path" ] || pane_path=$(cd "$pane_path" 2>/dev/null && pwd -P)
    [ "$pane_path" = "$wt" ] && { printf '%s|%s' "$idx" "$cmd"; return 0; }
  done <<EOF
$PANE_LIST
EOF
  return 1
}

# --- per-lane status ----------------------------------------------------------
lane_state() { # NAME WT -> "status|paneidx|head|ahead"
  local name="$1" wt="$2" status="" idx="-" head="-" ahead="0" pc txt br
  br=$(jq -r --arg n "$name" '(.lanes[] | select(.name==$n) | .branch) // (.integrator | select(.name==$n) | .branch) // ""' "$MANIFEST")
  if [ -n "$br" ] && git -C "$PROJECT_ROOT" rev-parse --verify -q "$br" >/dev/null 2>&1; then
    head=$(git -C "$PROJECT_ROOT" rev-parse --short "$br" 2>/dev/null || echo "-")
    ahead=$(git -C "$PROJECT_ROOT" rev-list --count "$BASE..$br" 2>/dev/null || echo "0")
  fi
  if pc=$(pane_for_wt "$wt"); then idx="${pc%%|*}"; fi

  if lane_done "$wt" "$name"; then
    status="done"
  elif [ "$idx" != "-" ] && pane_awaiting_approval "$idx"; then
    txt=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p -S -20 2>/dev/null || true)
    if approval_is_critical "$txt"; then status="awaiting-approval(CRITICAL)"; else status="awaiting-approval(safe)"; fi
  elif [ "$idx" != "-" ] && pane_stalled "$idx"; then
    status="stalled(usage-limit)"
  elif [ "$idx" != "-" ] && pane_errored "$idx"; then
    status="errored(transient)"
  elif [ "$idx" = "-" ] || pane_dead "$idx"; then
    if [ "$ahead" -gt 0 ] 2>/dev/null; then status="likely-done(verify me)"; else status="no-pane"; fi
  else
    status="working"
  fi
  printf '%s|%s|%s|%s' "$status" "$idx" "$head" "$ahead"
}

# --- run-level facts ----------------------------------------------------------
# A runner is "alive" when it can be tied to this exact manifest or a fresh
# supervisor heartbeat says the runner is alive. Do not use ps/lsof here: state
# checks are the fast path during long runs and must not hang behind process-table
# enumeration under load.
runner_alive="dead"
REAL_MANIFEST="$MDIR/$(basename "$MANIFEST")"
while IFS= read -r line; do
  case "$line" in *"polylane-run.sh"*" $REAL_MANIFEST"*) runner_alive="alive"; break ;; esac
done < <(pgrep -fl "polylane-run\.sh" 2>/dev/null || true)

INT_NAME=$(jq -r '.integrator.name // ""' "$MANIFEST")
INT_WT=$(jq -r '.integrator.worktree // ""' "$MANIFEST")
verdict="UNKNOWN"
[ -n "$INT_WT" ] && verdict=$(parse_verdict "$INT_WT/docs/verify-integration.md")

report="absent"; [ -f "$REPORT" ] && report="present"
hb="$MDIR/supervisor-heartbeat"; hb_age="-"
if [ -f "$hb" ]; then
  # GNU stat accepts BSD's `-f` but prints a multi-line filesystem report, so
  # probing BSD syntax first corrupts arithmetic on Linux. GNU `-c` fails
  # cleanly on BSD/macOS, making this order portable across both CI runners.
  now=$(date +%s); mt=$(stat -c %Y "$hb" 2>/dev/null || stat -f %m "$hb" 2>/dev/null || echo "$now")
  hb_age="$((now - mt))s"
  if [ "$((now - mt))" -le "${POLYLANE_STATE_HEARTBEAT_LIVE_SECS:-90}" ] && grep -q 'runner=alive' "$hb" 2>/dev/null; then
    runner_alive="alive"
  fi
fi
# A surviving tmux shell is preserved state, not a live runtime. Advertise an
# attach command only while the runner/heartbeat proves the supervised CLI is
# active; otherwise observers must report paused/idle.
watch="-"
if [ "$runner_alive" = "alive" ] && tmux_session_active; then
  watch="$(tmux_watch_command)"
fi

# --- emit ----------------------------------------------------------------------
NAMES=(); WTS=()
while IFS='|' read -r n w; do [ -n "$n" ] && { NAMES+=("$n"); WTS+=("$w"); }; done < <(jq -r '.lanes[] | "\(.name)|\(.worktree)"' "$MANIFEST")
[ -n "$INT_NAME" ] && { NAMES+=("$INT_NAME"); WTS+=("$INT_WT"); }

if [ "$JSON" = "1" ]; then
  lanes_json="[]"
  for i in "${!NAMES[@]}"; do
    IFS='|' read -r st idx head ahead <<EOF
$(lane_state "${NAMES[$i]}" "${WTS[$i]}")
EOF
    lanes_json=$(printf '%s' "$lanes_json" | jq --arg n "${NAMES[$i]}" --arg s "$st" --arg p "$idx" --arg h "$head" --argjson a "${ahead:-0}" '. + [{name:$n,status:$s,pane:$p,head:$h,commits_ahead:$a}]')
  done
  jq -n --arg runner "$runner_alive" --arg verdict "$verdict" --arg report "$report" --arg hb "$hb_age" --arg session "$TMUX_SESSION" --arg watch "$watch" --argjson lanes "$lanes_json" \
    '{runner:$runner, verdict:$verdict, report:$report, heartbeat_age:$hb, session:$session, watch:$watch, lanes:$lanes}'
else
  echo "runner: $runner_alive · verdict: $verdict · report: $report · heartbeat: $hb_age · session: $TMUX_SESSION · watch: $watch"
  for i in "${!NAMES[@]}"; do
    IFS='|' read -r st idx head ahead <<EOF
$(lane_state "${NAMES[$i]}" "${WTS[$i]}")
EOF
    printf '  %-16s %-28s pane=%-3s head=%-9s +%s\n' "${NAMES[$i]}" "$st" "$idx" "$head" "$ahead"
  done
fi
