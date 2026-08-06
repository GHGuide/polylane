#!/usr/bin/env bash
#
# polylane-run.sh — parallel-lane build engine (worktrees · tmux · git · agent CLI)
#
# Splits a manifest of lanes into git worktrees, launches one seeded selected-agent
# pane per lane in a tmux session, polls each lane's DONE file, auto-runs the
# integrator, gates on a verified engineering verdict, then deletes scratch after
# one confirmation. See .polylane/SCHEMA.md for the manifest + conventions.
#
# CONTRACTS (frozen — other lanes depend on these):
#   manifest .polylane/run.json:
#     {base, integrator:{name,model,branch,worktree,prompt_file},
#      lanes:[{name,model,branch,worktree,prompt_file,own_globs}]}
#   CLI:  bin/polylane-run.sh <manifest.json> [--dry-run] [--yes] [--resume]
#         [--push] [--intensity economy|balanced|performance|max] [--model lane=id]...
#   DONE: <worktree>/docs/status-<name>.md  first line == "STATUS: <name> DONE"
#
# SAFETY: never `git add -A`; never `git branch -D`; never rm outside the
#         worktree dirs + .polylane/; abort (non-zero) on any merge conflict.
#
# The script is a library of functions plus a guarded `main`; `set -euo
# pipefail` is enabled inside main only, so the file can be sourced by tests.

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

usage() {
  cat <<'EOF'
polylane-run.sh — parallel-lane build engine (worktrees · tmux · git · claude)

USAGE:
  bin/polylane-run.sh <manifest.json> [--dry-run] [--yes] [--resume] [--push]
                      [--intensity <economy|balanced|performance|max>]
                      [--model <lane=model_id>]...

ARGS:
  <manifest.json>   path to a .polylane/run.json manifest (see .polylane/SCHEMA.md)

OPTIONS:
  --dry-run              print every git/tmux command without executing anything
  --yes                  skip the final delete-confirmation prompt
  --resume               skip lanes whose DONE file is already valid (no respawn);
                         launch only the unfinished lanes
  --push                 after a GO verdict + cleanup, git push the current branch
  --intensity <preset>   remap EVERY lane + integrator to the preset's model
                         (resolved against the manifest's available_models) and
                         effort. preset: economy|balanced|performance|max.
  --model <lane=id>      override ONE lane's (or the integrator's) model by name.
                         Repeatable; applied after --intensity so it always wins.
  -h, --help             show this help and exit 0

FLOW:
  split worktrees -> launch seeded selected-agent panes (tmux session 'polylane';
  each pane's transcript mirrors to docs/lane-logs/<lane>.log — kept)
  -> poll each <worktree>/docs/status-<name>.md for DONE (per-lane status line;
     transient errors auto-retry with a WIP checkpoint; usage-limit paywalls
     stall the lane and wait for a human — never auto-answered)
  -> run integrator -> gate/repair verdict in <int-worktree>/docs/verify-integration.md
  -> one confirm -> remove worktrees + merged branches + .polylane scratch
     (keeps docs/verify-*.md, docs/parallel-status.md, docs/lane-logs/)

DEPS: tmux, jq, git, and the selected agent CLI (codex, claude, aider, or custom)

ENV:
  POLYLANE_POLL_INTERVAL    seconds between DONE-file polls (default 2)
  POLYLANE_HEALTH_INTERVAL  seconds between error-scans that auto-retry a lane
                            stuck on a transient API/network error (default 15)
  POLYLANE_MAX_RETRIES      retries per lane before it is marked failed (default 3)
  POLYLANE_ON_LIMIT         what to do when a lane hits a usage-limit paywall, so
                            an unattended run never hangs on it:
                              fallback (default) respawn on the next model down the
                                        ladder (fable->opus->sonnet->haiku) that is
                                        in the manifest's available_models
                              credits  auto-select "switch to usage credits"
                              wait     hold POLYLANE_STALL_MAX health-cycles, then
                                        mark the lane failed (halt with a report)
  POLYLANE_STALL_MAX        wait-policy: health-cycles to hold before failing (default 6)
  POLYLANE_MAX_REPAIRS      Reflexion repairs before a lane is failed: once retries
                            are exhausted the lane respawns with a "reflect on your
                            prior transcript, then take a DIFFERENT approach" prompt
                            instead of failing outright (default 1; 0 disables)
  POLYLANE_MIN_DISK_GB      free-space floor in GB (default 2). Preflight ABORTS below
                            it; a run that dips below it mid-flight HALTS gracefully
                            (worktrees intact, resumable) instead of ENOSPC-crashing.
  POLYLANE_PROGRESS_CHECKS  unchanged-source health sweeps before command-churn
                            replan (default 12)
  POLYLANE_PROGRESS_MIN_COMMANDS
                            command executions required before that replan (default 20)
  POLYLANE_PROGRESS_REPLANS narrowed model/effort-downgraded replans before the
                            lane stops as NEEDS-USER (default 2)
EOF
}

# tmux session name — POLYLANE_SESSION lets parallel runs coexist (default: polylane).
TMUX_SESSION="${POLYLANE_SESSION:-polylane}"

# dir this script lives in — the notify hook is resolved as a sibling.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)

# notify_event EVENT MSG : best-effort hook into bin/polylane-notify.sh (a
# sibling script another lane may install). Fires ONLY if it exists and is
# executable; missing/broken hook is never fatal to the run.
# Events: done | go | no-go | halt | stall.
notify_event() {
  local hook="${SCRIPT_DIR:-.}/polylane-notify.sh"
  [ -x "$hook" ] || return 0
  run "$hook" "$1" "$2" 2>/dev/null || true
}

# run CMD... : in dry-run print it; otherwise execute it (argv form, no eval).
run() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf '+ %s\n' "$*"
  else
    "$@"
  fi
}

# safe_rm PATH : refuse to remove anything not under REPO_ROOT.
safe_rm() {
  local p="$1" root="${REPO_ROOT:-}"
  if [ -z "$root" ]; then
    echo "safe_rm REFUSED (no REPO_ROOT set): $p" >&2
    return 1
  fi
  case "$p" in
    "$root"/*) run rm -rf "$p" ;;
    *) echo "safe_rm REFUSED (outside repo root $root): $p" >&2; return 1 ;;
  esac
}

# disk_free_gb DIR : whole GB free on the volume holding DIR (empty if unreadable).
disk_free_gb() {
  df -Pk "${1:-.}" 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}'
}

# disk_guard : 0 if free space is at/above POLYLANE_MIN_DISK_GB; else warn + return 1.
# Cheap df — lets the poll loop HALT gracefully (worktrees intact, resumable) rather
# than let a lane ENOSPC-crash mid-task. Unreadable df => pass (never a false halt).
disk_guard() {
  local floor="${POLYLANE_MIN_DISK_GB:-2}" free
  free=$(disk_free_gb "${REPO_ROOT:-.}")
  [ -n "$free" ] || return 0
  [ "$free" -ge "$floor" ] && return 0
  echo "polylane-run: DISK LOW — only ${free}GB free (< ${floor}GB floor). Halting before" >&2
  echo "  ENOSPC; worktrees left intact — free space, then re-run with --resume." >&2
  return 1
}

# ---------------------------------------------------------------------------
# arg parsing
# ---------------------------------------------------------------------------

parse_args() {
  DRY_RUN=0
  YES=0
  RESUME=0
  PUSH=0
  MANIFEST=""
  INTENSITY=""
  MODEL_OVERRIDES=()
  [ $# -eq 0 ] && { usage >&2; exit 2; }
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --dry-run) DRY_RUN=1 ;;
      --yes)     YES=1 ;;
      --resume)  RESUME=1 ;;
      --push)    PUSH=1 ;;
      --intensity)   shift; [ $# -gt 0 ] || { echo "polylane-run: --intensity requires a value (economy|balanced|performance|max)" >&2; exit 2; }; INTENSITY="$1" ;;
      --intensity=*) INTENSITY="${1#*=}" ;;
      --model)       shift; [ $# -gt 0 ] || { echo "polylane-run: --model requires lane=model_id" >&2; exit 2; }; MODEL_OVERRIDES+=("$1") ;;
      --model=*)     MODEL_OVERRIDES+=("${1#*=}") ;;
      --)        shift; [ $# -gt 0 ] && MANIFEST="$1" ;;
      -*)        echo "polylane-run: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *)
        if [ -z "$MANIFEST" ]; then
          MANIFEST="$1"
        else
          echo "polylane-run: unexpected extra argument: $1" >&2; exit 2
        fi
        ;;
    esac
    shift
  done
  [ -n "$MANIFEST" ] || { echo "polylane-run: manifest argument required" >&2; usage >&2; exit 2; }
}

# ---------------------------------------------------------------------------
# preflight
# ---------------------------------------------------------------------------

preflight_basic() {
  local missing=() d
  for d in jq git; do
    command -v "$d" >/dev/null 2>&1 || missing+=("$d")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "polylane-run: missing required dependencies: ${missing[*]}" >&2
    echo "  jq = manifest parse, git = worktrees" >&2
    echo "  install the missing tool(s) and retry." >&2
    exit 1
  fi
  if [ ! -f "$MANIFEST" ]; then
    echo "polylane-run: manifest not found: $MANIFEST" >&2
    exit 1
  fi
  if ! jq empty "$MANIFEST" 2>/dev/null; then
    echo "polylane-run: manifest is not valid JSON: $MANIFEST" >&2
    exit 1
  fi
}

preflight_agent() {
  local missing=() d agent
  agent="$(agent_selected)"
  for d in tmux git jq; do
    command -v "$d" >/dev/null 2>&1 || missing+=("$d")
  done
  if [ -z "${POLYLANE_AGENT_CMD:-}" ]; then
    case "$agent" in
      claude) d=claude ;;
      codex|gpt|openai) d=codex ;;
      aider) d=aider ;;
      *) d="" ;;
    esac
    [ -z "$d" ] || command -v "$d" >/dev/null 2>&1 || missing+=("$d")
  fi
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "polylane-run: missing required dependencies: ${missing[*]}" >&2
    echo "  tmux = pane management, ${agent} = builders, jq = manifest parse, git = worktrees" >&2
    echo "  install the missing tool(s) and retry, or set POLYLANE_AGENT_CMD with {model} and {prompt}." >&2
    exit 1
  fi
  # disk floor — worktrees + tmux pane logs grow during a run; abort BEFORE
  # launching rather than ENOSPC-crash mid-lane. Reads the manifest's volume.
  local floor="${POLYLANE_MIN_DISK_GB:-2}" free
  free=$(disk_free_gb "$(dirname "$MANIFEST")")
  if [ -n "$free" ] && [ "$free" -lt "$floor" ]; then
    echo "polylane-run: only ${free}GB free (< ${floor}GB floor) — free space or lower POLYLANE_MIN_DISK_GB." >&2
    echo "  worktrees + pane logs grow during a run; starting now risks an ENOSPC crash mid-lane." >&2
    exit 1
  fi
}

tmux_watch_command() { printf 'tmux attach -t %s' "$TMUX_SESSION"; }

# ---------------------------------------------------------------------------
# manifest -> globals
# ---------------------------------------------------------------------------

# abs_prompt PATH : make a manifest prompt_file absolute. Relative paths in the
# manifest are anchored at PROJECT_ROOT (the dir that CONTAINS .polylane). Panes
# `cd` into lane worktrees that do NOT contain .polylane/, so a relative
# "$(cat .polylane/lanes/x.txt)" reads NOTHING there and launches claude with an
# empty prompt (the "panes open but sit at an empty input" bug). Absolute paths
# read correctly from any pane cwd.
abs_prompt() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$PROJECT_ROOT" "$1" ;;
  esac
}

abs_project_path() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$PROJECT_ROOT" "$1" ;;
  esac
}

# die MSG : print a fatal error and stop before any side effect.
die() { echo "polylane-run: $*" >&2; exit 2; }

load_manifest() {
  BASE=$(jq -r '.base' "$MANIFEST")
  # per-run nonce: markers are trusted ONLY when their run= tag equals THIS run's
  # nonce, so a leftover DONE/verdict from any earlier run reads as not-done/UNKNOWN
  # (an allowlist, vs the enumerate-every-path blocklist in clear_stale_markers).
  # Absent -> "" -> legacy exact-match behavior (fully backward-compatible).
  RUN_ID=$(jq -r '.run_id // ""' "$MANIFEST")
  # which agent CLI each pane launches — claude (default), codex/gpt, aider, or a
  # custom POLYLANE_AGENT_CMD template. Env POLYLANE_AGENT overrides the manifest.
  AGENT=$(jq -r '.agent // "claude"' "$MANIFEST")
  # Codex lanes default to the least-surprising writable isolation. A run may
  # explicitly select another supported Codex sandbox, and the environment can
  # override it for host-specific recovery without replacing the whole agent
  # command template.
  CODEX_SANDBOX=$(jq -r '.codex_sandbox // "workspace-write"' "$MANIFEST")
  # PROJECT_ROOT = parent of the manifest's own dir (.polylane) = the project root
  # where .polylane/lanes/*.txt actually live. Robust even outside a git checkout.
  local _mdir
  _mdir=$(cd "$(dirname "$MANIFEST")" && pwd -P)
  PROJECT_ROOT=$(cd "$_mdir/.." && pwd -P)
  MANIFEST_SESSION=$(jq -r '.session // ""' "$MANIFEST")
  if [ -z "${POLYLANE_SESSION:-}" ] && [ -n "$MANIFEST_SESSION" ]; then
    TMUX_SESSION="$MANIFEST_SESSION"
  fi
  ORCHESTRATION_CONTRACT=$(jq -r '.orchestration_contract // 0' "$MANIFEST")
  MANIFEST_GRAPH_MODE=$(jq -r '.graph_mode // ""' "$MANIFEST")
  CYCLE=$(jq -r '.cycle // 0' "$MANIFEST")
  STATE_FILE=$(jq -r '.state_file // ""' "$MANIFEST")
  LANE_SKILLS_FILE=$(jq -r '.lane_skills_file // ""' "$MANIFEST")
  CYCLE_PLAN_FILE=$(jq -r '.cycle_plan_file // ""' "$MANIFEST")
  [ -z "$STATE_FILE" ] || STATE_FILE=$(abs_project_path "$STATE_FILE")
  [ -z "$LANE_SKILLS_FILE" ] || LANE_SKILLS_FILE=$(abs_project_path "$LANE_SKILLS_FILE")
  [ -z "$CYCLE_PLAN_FILE" ] || CYCLE_PLAN_FILE=$(abs_project_path "$CYCLE_PLAN_FILE")
  INT_NAME=$(jq -r '.integrator.name' "$MANIFEST")
  INT_MODEL=$(jq -r '.integrator.model' "$MANIFEST")
  INT_BRANCH=$(jq -r '.integrator.branch' "$MANIFEST")
  INT_WORKTREE=$(jq -r '.integrator.worktree' "$MANIFEST")
  INT_PROMPT=$(abs_prompt "$(jq -r '.integrator.prompt_file' "$MANIFEST")")
  # effort is optional; absent -> "" (no behavior change). // "" also maps a JSON null.
  INT_EFFORT=$(jq -r '.integrator.effort // ""' "$MANIFEST")

  # available_models feeds --intensity resolution; absent -> empty array.
  AVAILABLE_MODELS=()
  local m
  while IFS= read -r m; do
    [ -n "$m" ] && AVAILABLE_MODELS+=("$m")
  done < <(jq -r '.available_models // [] | .[]' "$MANIFEST")

  LANE_NAMES=(); LANE_MODELS=(); LANE_EFFORTS=(); LANE_BRANCHES=(); LANE_WORKTREES=(); LANE_PROMPTS=(); LANE_POLLSPEC=()
  LANE_PANE_IDX=(); LANE_RESUMED=(); LANE_ADOPTED=(); LANE_WHASH=(); LANE_WCNT=()
  LANE_PHASH=(); LANE_PCNT=(); LANE_PCOMMANDS=(); LANE_PREPLANS=()
  INT_PANE_IDX=-1; NEXT_PANE_IDX=0; SESSION_STARTED=0
  local n i
  n=$(jq '.lanes | length' "$MANIFEST")
  for ((i = 0; i < n; i++)); do
    LANE_NAMES+=("$(jq -r ".lanes[$i].name" "$MANIFEST")")
    LANE_MODELS+=("$(jq -r ".lanes[$i].model" "$MANIFEST")")
    LANE_EFFORTS+=("$(jq -r ".lanes[$i].effort // \"\"" "$MANIFEST")")
    LANE_BRANCHES+=("$(jq -r ".lanes[$i].branch" "$MANIFEST")")
    LANE_WORKTREES+=("$(jq -r ".lanes[$i].worktree" "$MANIFEST")")
    LANE_PROMPTS+=("$(abs_prompt "$(jq -r ".lanes[$i].prompt_file" "$MANIFEST")")")
    LANE_POLLSPEC+=("$(jq -r ".lanes[$i].name" "$MANIFEST"):$(jq -r ".lanes[$i].worktree" "$MANIFEST")")
    LANE_PANE_IDX+=(-1); LANE_RESUMED+=(0); LANE_ADOPTED+=(0)
  done

  MANIFEST_RUNTIME_FINGERPRINT=$(runtime_settings_fingerprint)
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  # shellcheck disable=SC2034  # kept for sourcers (tests source this file's functions)
  BASE_WT="$REPO_ROOT"

  validate_manifest
}

# preflight_contract : Codex runs use orchestration contract v2 by default. This
# converts the workflow promises into executable launch gates, before worktrees or
# tmux exist. POLYLANE_ALLOW_LEGACY=1 is an explicit compatibility escape hatch.
# A --resume may also grandfather an already-materialized legacy Codex run so an
# upgraded supervisor cannot strand work that was launched under contract v1.
preflight_contract() {
  local strict=0 lane prompt sid next next_id previous legacy_wt
  if [ "${ORCHESTRATION_CONTRACT:-0}" -ge 2 ] 2>/dev/null; then
    strict=1
  elif [ "$(agent_selected)" = "codex" ] || [ "$(agent_selected)" = "gpt" ] || [ "$(agent_selected)" = "openai" ]; then
    if [ "${POLYLANE_ALLOW_LEGACY:-0}" = "1" ]; then
      return 0
    fi
    if [ "${RESUME:-0}" = "1" ] && [ -n "${RUN_ID:-}" ]; then
      for legacy_wt in "${LANE_WORKTREES[@]}" "$INT_WORKTREE"; do
        if [ -d "$legacy_wt" ]; then
          echo "ORCHESTRATION-CONTRACT: grandfathering existing legacy Codex run for --resume; migrate next cycle" >&2
          return 0
        fi
      done
    fi
    die "Codex manifest needs orchestration_contract: 2 (set POLYLANE_ALLOW_LEGACY=1 only for migration)"
  fi
  case "$(graph_mode_selected 2>/dev/null || true)" in
    authoritative|shadow|off) : ;;
    *) die "graph_mode must be authoritative, shadow, or off" ;;
  esac
  [ "$strict" = "1" ] || return 0

  [ "${CYCLE:-0}" -ge 1 ] 2>/dev/null || die "contract v2 needs integer cycle >= 1"
  [ -n "${RUN_ID:-}" ] || die "contract v2 needs a fresh non-empty run_id"
  case "$RUN_ID" in *[!A-Za-z0-9._-]*)
    die "contract v2 run_id must use only A-Za-z0-9._-" ;;
  esac
  [ -n "${STATE_FILE:-}" ] && [ -s "$STATE_FILE" ] || die "contract v2 state_file is missing/empty"
  [ -n "${LANE_SKILLS_FILE:-}" ] && [ -s "$LANE_SKILLS_FILE" ] || die "contract v2 lane_skills_file is missing/empty"
  [ -n "${CYCLE_PLAN_FILE:-}" ] && [ -s "$CYCLE_PLAN_FILE" ] || die "contract v2 cycle_plan_file is missing/empty"
  [ -s "$PROJECT_ROOT/docs/polylane/INDEX.md" ] || die "contract v2 needs docs/polylane/INDEX.md"

  jq -e '
    (.target_subgoals | type=="array" and length>0)
    and all(.lanes[]; (.target_subgoals | type=="array" and length>0))
    and (([.lanes[].target_subgoals[]] | unique) -
         ([.target_subgoals[]] | unique) | length == 0)
  ' "$MANIFEST" >/dev/null 2>&1 ||
    die "contract v2 needs non-empty target_subgoals globally and on every builder lane"

  "$SCRIPT_DIR/polylane-scope.sh" check-static "$MANIFEST" ||
    die "contract v2 scope isolation failed"
  POLYLANE_STRICT_PROMPTS=1 "$SCRIPT_DIR/polylane-promptlint.sh" lint-run "$MANIFEST" ||
    die "contract v2 prompt lint failed"
  "$SCRIPT_DIR/polylane-scout.sh" validate "$LANE_SKILLS_FILE" "$MANIFEST" ||
    die "contract v2 lane skill kits failed"
  for lane in "${LANE_NAMES[@]}"; do
    prompt=$(jq -r --arg n "$lane" '.lanes[] | select(.name==$n) | .prompt_file' "$MANIFEST")
    prompt=$(abs_project_path "$prompt")
    "$SCRIPT_DIR/polylane-scout.sh" lint "$LANE_SKILLS_FILE" "$lane" "$prompt" ||
      die "contract v2 lane '$lane' prompt does not invoke its armed skills"
    grep -qF "STATUS: $lane DONE run=$RUN_ID" "$prompt" ||
      die "contract v2 lane '$lane' prompt lacks its exact current-run DONE marker"
  done
  if ! grep -qF "POLYLANE-VERDICT:" "$INT_PROMPT" ||
     ! grep -qF "run=$RUN_ID" "$INT_PROMPT"; then
    die "contract v2 integrator prompt lacks a current-run verdict sentinel"
  fi

  for sid in $(jq -r '.target_subgoals[]' "$MANIFEST"); do
    jq -e --arg sid "$sid" '
      any(.milestones[].subgoals[]; .id==$sid and (.status=="open" or .status=="doing"))
      and any((.accept // [])[]; .sid==$sid)
    ' "$STATE_FILE" >/dev/null ||
      die "target subgoal '$sid' must be open/doing with frozen acceptance registered"
  done
  next=$("$SCRIPT_DIR/polylane-memory.sh" "$STATE_FILE" next)
  next_id="${next%%  *}"
  [ -n "$next_id" ] || die "contract v2 has no autonomous next subgoal to execute"
  jq -e --arg sid "$next_id" 'any(.target_subgoals[]; .==$sid)' "$MANIFEST" >/dev/null ||
    die "highest-priority next subgoal '$next_id' is not routed into this cycle"

  if [ "$CYCLE" -gt 1 ]; then
    previous=$((CYCLE - 1))
    "$SCRIPT_DIR/polylane-cycle.sh" artifacts "$PROJECT_ROOT" "$previous" "$STATE_FILE" ||
      die "prior cycle $previous is not durably closed"
  fi
  echo "ORCHESTRATION-CONTRACT: v2 cycle=$CYCLE target=$next_id"
}

# ---------------------------------------------------------------------------
# contract-v2 execution graph runtime. Contract-v2 defaults to authoritative:
# scheduling decisions are admitted by the immutable graph, while `shadow` keeps
# the prior observational mode available for migration and `off` preserves the
# legacy runner path.
# ---------------------------------------------------------------------------

graph_mode_selected() {
  local mode="${POLYLANE_GRAPH_MODE:-${MANIFEST_GRAPH_MODE:-}}"
  if [ -z "$mode" ] && [ "${POLYLANE_GRAPH_SHADOW:-1}" = "0" ]; then
    mode=off
  fi
  if [ -z "$mode" ]; then
    if [ "${ORCHESTRATION_CONTRACT:-0}" -ge 2 ] 2>/dev/null; then mode=authoritative; else mode=off; fi
  fi
  case "$mode" in authoritative|shadow|off) printf '%s' "$mode" ;; *) return 2 ;; esac
}

graph_runtime_enabled() {
  local mode
  mode=$(graph_mode_selected) || return 1
  [ "$mode" != off ]
}

graph_authority_enabled() {
  [ "$(graph_mode_selected 2>/dev/null || true)" = authoritative ]
}

graph_shadow_enabled() {
  graph_runtime_enabled
}

graph_shadow_error() {
  printf 'GRAPH-SHADOW: %s\n' "$*" >&2
  return 1
}

graph_authority_error() {
  printf 'GRAPH-AUTHORITY: %s\n' "$*" >&2
  return 1
}

# graph_authority_require NODE ACTION fails closed unless NODE is currently
# emitted by the production ready CLI from the verified ledger replay. The
# replay format carries state objects while `ready` consumes state strings, so
# the disposable conversion is deliberately outside both immutable artifacts.
graph_authority_require() {
  local node="$1" action="$2" replay state ready tmp out
  graph_authority_enabled || return 0
  graph_shadow_validate || { graph_authority_error "cannot $action: graph or ledger validation failed"; return 1; }
  if ! replay=$("$SCRIPT_DIR/polylane-events.sh" replay "$EVENTS_FILE" "$RUN_ID" "$GRAPH_ID" 2>&1); then
    graph_authority_error "cannot $action: ledger replay failed: ${replay:-unknown error}"
    return 1
  fi
  tmp=$(mktemp "$(dirname "$EVENTS_FILE")/.polylane-ready.XXXXXX") || {
    graph_authority_error "cannot $action: cannot create disposable readiness checkpoint"
    return 1
  }
  if ! printf '%s\n' "$replay" | jq -c '{nodes: .nodes}' > "$tmp"; then
    rm -f "$tmp"
    graph_authority_error "cannot $action: ledger replay has an unreadable state"
    return 1
  fi
  if ! ready=$("$SCRIPT_DIR/polylane-graph.sh" ready "$GRAPH_FILE" "$tmp" 2>&1); then
    rm -f "$tmp"
    graph_authority_error "cannot $action: ready-node query failed: ${ready:-unknown error}"
    return 1
  fi
  rm -f "$tmp"
  if ! printf '%s\n' "$ready" | grep -Fx -- "$node" >/dev/null; then
    state=$(printf '%s\n' "$replay" | jq -r --arg node "$node" '.nodes[$node].state // "pending"' 2>/dev/null || echo unknown)
    graph_authority_error "refused $action for $node: node is $state, not currently graph-ready"
    return 1
  fi
}

graph_authority_start() {
  graph_authority_enabled || return 0
  graph_authority_record_ready_node start succeeded 0 graph-start
}

graph_authority_record_ready_node() {
  local node="$1" target="$2" attempt="${3:-0}" reason="${4:-runner-boundary}"
  graph_authority_enabled || { graph_shadow_record_node "$node" "$target" "$attempt" "$reason"; return; }
  # A supervisor may resume after the runner recorded the same completed
  # boundary but before its next instruction. Idempotent replay is safe; never
  # demand readiness again from an already-final node.
  local replay state replay_attempt
  replay=$("$SCRIPT_DIR/polylane-events.sh" replay "$EVENTS_FILE" "$RUN_ID" "$GRAPH_ID" 2>/dev/null) || {
    graph_authority_error "cannot advance $node: ledger replay failed"
    return 1
  }
  state=$(printf '%s\n' "$replay" | jq -r --arg node "$node" '.nodes[$node].state // "pending"' 2>/dev/null || echo unknown)
  replay_attempt=$(printf '%s\n' "$replay" | jq -r --arg node "$node" '.nodes[$node].attempt // 0' 2>/dev/null || echo 0)
  if [ "$state" = "$target" ]; then
    [ "$target" = failed ] || return 0
    [ "$replay_attempt" -lt "$attempt" ] || return 0
  fi
  graph_authority_require "$node" "advance" || return 1
  graph_shadow_record_node "$node" "$target" "$attempt" "$reason"
}

graph_authority_record_builders() {
  local outcome="$1" i node target first_failed=""
  graph_authority_enabled || { graph_shadow_record_builders "$outcome"; return; }
  for i in "${!LANE_NAMES[@]}"; do
    node="lane:${LANE_NAMES[$i]}"
    if [ "$outcome" = succeeded ] || lane_done "${LANE_WORKTREES[$i]}" "${LANE_NAMES[$i]}"; then
      target=succeeded
    else
      target=failed
      [ -n "$first_failed" ] || first_failed="$node"
    fi
    graph_authority_record_ready_node "$node" "$target" 0 builder-done || return 1
  done
  if [ "$outcome" = succeeded ]; then
    graph_authority_record_ready_node builders-joined succeeded 0 builders-joined
  else
    graph_authority_require halt "halt after builder failure" || return 1
    graph_authority_record_ready_node halt succeeded 0 builder-halted
  fi
}

graph_authority_halt_node() {
  local node="$1"
  graph_authority_enabled || { graph_shadow_record_decision HALTED "$node"; return; }
  graph_authority_record_ready_node "$node" failed 0 halted || return 1
  graph_authority_require halt "halt after $node failure" || return 1
  graph_authority_record_ready_node halt succeeded 0 halted
}

graph_authority_no_go() {
  graph_authority_enabled || { graph_shadow_record_decision NO-GO; return; }
  graph_authority_record_ready_node verifier failed 0 NO-GO || return 1
  graph_authority_require halt "halt exhausted verifier route" || return 1
  graph_authority_record_ready_node halt succeeded 0 NO-GO
}

# graph_shadow_validate checks both immutable inputs before a caller relies on
# the shadow. The graph remains observational: this never returns ready work.
graph_shadow_validate() {
  graph_shadow_enabled || return 0
  local graph_tool="$SCRIPT_DIR/polylane-graph.sh"
  local events_tool="$SCRIPT_DIR/polylane-events.sh" out current_graph_id
  [ -n "${GRAPH_FILE:-}" ] && [ -n "${EVENTS_FILE:-}" ] && [ -n "${GRAPH_ID:-}" ] || {
    graph_shadow_error 'graph shadow was not initialized'
    return 1
  }
  if ! out=$("$graph_tool" validate "$GRAPH_FILE" 2>&1); then
    graph_shadow_error "invalid graph at $GRAPH_FILE: ${out:-validation failed}"
    return 1
  fi
  current_graph_id=$(jq -r '.graph_id // ""' "$GRAPH_FILE" 2>/dev/null) || {
    graph_shadow_error "cannot read graph_id from $GRAPH_FILE"
    return 1
  }
  [ "$current_graph_id" = "$GRAPH_ID" ] || {
    graph_shadow_error "graph_id changed after compile (expected $GRAPH_ID, got ${current_graph_id:-empty})"
    return 1
  }
  if ! out=$("$events_tool" verify "$EVENTS_FILE" "$RUN_ID" "$GRAPH_ID" 2>&1); then
    graph_shadow_error "invalid event ledger at $EVENTS_FILE: ${out:-verification failed}"
    return 1
  fi
}

# graph_shadow_init compiles atomically via polylane-graph.sh, then creates the
# ledger with an atomic rename. Resume preserves and validates prior events.
graph_shadow_init() {
  graph_shadow_enabled || {
    GRAPH_FILE=''; EVENTS_FILE=''; GRAPH_ID=''
    return 0
  }
  local dir graph_tool="$SCRIPT_DIR/polylane-graph.sh" events_tool="$SCRIPT_DIR/polylane-events.sh"
  local out tmp
  dir=$(dirname "$MANIFEST")
  GRAPH_FILE="$dir/graph.json"
  EVENTS_FILE="$dir/events.jsonl"
  if ! out=$("$graph_tool" compile "$MANIFEST" "$GRAPH_FILE" 2>&1); then
    graph_shadow_error "compile failed for $MANIFEST: ${out:-compiler failed}"
    return 1
  fi
  if ! out=$("$graph_tool" validate "$GRAPH_FILE" 2>&1); then
    graph_shadow_error "compiled graph is invalid at $GRAPH_FILE: ${out:-validation failed}"
    return 1
  fi
  GRAPH_ID=$(jq -r '.graph_id // ""' "$GRAPH_FILE" 2>/dev/null) || {
    graph_shadow_error "cannot read graph_id from $GRAPH_FILE"
    return 1
  }
  [ -n "$GRAPH_ID" ] || {
    graph_shadow_error "compiled graph has no graph_id: $GRAPH_FILE"
    return 1
  }
  if [ "${RESUME:-0}" = "1" ] && [ -e "$EVENTS_FILE" ]; then
    if ! out=$("$events_tool" verify "$EVENTS_FILE" "$RUN_ID" "$GRAPH_ID" 2>&1); then
      graph_shadow_error "resume ledger is invalid at $EVENTS_FILE: ${out:-verification failed}"
      return 1
    fi
  else
    tmp=$(mktemp "$dir/.polylane-events.XXXXXX") || {
      graph_shadow_error "cannot initialize event ledger beside $MANIFEST"
      return 1
    }
    if ! mv "$tmp" "$EVENTS_FILE"; then
      rm -f "$tmp"
      graph_shadow_error "cannot install event ledger at $EVENTS_FILE"
      return 1
    fi
  fi
  graph_shadow_validate
}

graph_shadow_edge_exact() {
  local from="$1" outcome="$2" expected="$3" actual
  actual=$(jq -r --arg from "$from" --arg outcome "$outcome" '
    [(.edges[]?, .loops[]?)
      | select(.from == $from and .outcome == $outcome)
      | .to]
    | sort | join(",")
  ' "$GRAPH_FILE" 2>/dev/null) || {
    graph_shadow_error "cannot inspect route $from/$outcome in $GRAPH_FILE"
    return 1
  }
  [ "$actual" = "$expected" ] || {
    graph_shadow_error "route mismatch for $from/$outcome (runner=$expected graph=${actual:-none})"
    return 1
  }
}

# graph_shadow_parity compares only decisions the current runner already made.
# It never calls graph ready-routing and therefore cannot change scheduling.
graph_shadow_parity() {
  graph_shadow_enabled || return 0
  local decision="$1" node="${2:-}"
  graph_shadow_validate || return 1
  case "$decision" in
    GO|EXTERNAL-EVIDENCE-OPEN)
      graph_shadow_edge_exact verifier passed promote &&
        graph_shadow_edge_exact promote succeeded complete
      ;;
    NO-GO)
      graph_shadow_edge_exact verifier failed halt,repair &&
        graph_shadow_edge_exact repair failed halt
      ;;
    HALTED)
      [ -n "$node" ] || {
        graph_shadow_error 'HALTED parity needs the failed runner node'
        return 1
      }
      graph_shadow_edge_exact "$node" failed halt
      ;;
    RESUME)
      case "$node" in
        lane:*) graph_shadow_edge_exact "$node" succeeded builders-joined ;;
        integrator) graph_shadow_edge_exact integrator succeeded verifier ;;
        *) graph_shadow_error "resume parity has unknown node: ${node:-empty}"; return 1 ;;
      esac
      ;;
    *) graph_shadow_error "unsupported runner decision: $decision"; return 1 ;;
  esac
}

graph_shadow_append() {
  graph_shadow_enabled || return 0
  local node="$1" from="$2" to="$3" attempt="$4" key="$5" reason="$6" out
  if ! out=$("$SCRIPT_DIR/polylane-events.sh" append "$EVENTS_FILE" "$RUN_ID" "$GRAPH_ID" \
      "$node" "$from" "$to" "$attempt" "$key" "$reason" 2>&1); then
    graph_shadow_error "event append failed for $node $from->$to: ${out:-append failed}"
    return 1
  fi
}

# graph_shadow_record_node advances one observed node to the runner's final
# state. Replay makes interrupted writes and supervisor resume safe.
graph_shadow_record_node() {
  graph_shadow_enabled || return 0
  local node="$1" target="$2" attempt="${3:-0}" reason="${4:-runner-boundary}"
  local replay state replay_attempt key
  graph_shadow_validate || return 1
  if ! replay=$("$SCRIPT_DIR/polylane-events.sh" replay "$EVENTS_FILE" "$RUN_ID" "$GRAPH_ID" 2>&1); then
    graph_shadow_error "event replay failed before recording $node: ${replay:-replay failed}"
    return 1
  fi
  state=$(printf '%s\n' "$replay" | jq -r --arg node "$node" '.nodes[$node].state // "pending"' 2>/dev/null) || {
    graph_shadow_error "cannot read replayed state for $node"
    return 1
  }
  replay_attempt=$(printf '%s\n' "$replay" | jq -r --arg node "$node" '.nodes[$node].attempt // 0' 2>/dev/null) || {
    graph_shadow_error "cannot read replayed attempt for $node"
    return 1
  }
  if [ "$state" = "$target" ]; then
    [ "$target" = failed ] || return 0
    [ "$replay_attempt" -lt "$attempt" ] || return 0
  fi
  case "$state" in
    pending)
      key="shadow:$node:$attempt"
      graph_shadow_append "$node" pending ready "$attempt" "$key:ready" "$reason" || return 1
      state=ready
      ;;
    failed)
      attempt=$((replay_attempt + 1))
      key="shadow:$node:$attempt"
      graph_shadow_append "$node" failed ready "$attempt" "$key:retry" "$reason" || return 1
      state=ready
      ;;
    ready|running)
      attempt="$replay_attempt"
      key="shadow:$node:$attempt"
      ;;
    *)
      graph_shadow_error "cannot move $node from terminal shadow state $state to $target"
      return 1
      ;;
  esac
  if [ "$state" = ready ]; then
    graph_shadow_append "$node" ready running "$attempt" "$key:running" "$reason" || return 1
    state=running
  fi
  case "$target" in succeeded|failed|blocked) : ;;
    *) graph_shadow_error "unsupported event target for $node: $target"; return 1 ;;
  esac
  graph_shadow_append "$node" "$state" "$target" "$attempt" "$key:$target" "$reason" || return 1
  graph_shadow_validate
}

graph_shadow_record_resume() {
  graph_shadow_enabled || return 0
  if graph_authority_enabled; then
    graph_authority_record_ready_node "$1" succeeded 0 resume
    return
  fi
  graph_shadow_parity RESUME "$1" || return 1
  graph_shadow_record_node "$1" succeeded 0 resume
}

graph_shadow_record_resumes() {
  graph_shadow_enabled || return 0
  local i
  for i in "${!LANE_NAMES[@]}"; do
    lane_resumed "$i" || continue
    graph_shadow_record_resume "lane:${LANE_NAMES[$i]}" || return 1
  done
}

graph_shadow_record_builders() {
  graph_shadow_enabled || return 0
  local outcome="$1" i node first_failed=''
  for i in "${!LANE_NAMES[@]}"; do
    node="lane:${LANE_NAMES[$i]}"
    if [ "$outcome" = succeeded ] || lane_done "${LANE_WORKTREES[$i]}" "${LANE_NAMES[$i]}"; then
      graph_shadow_record_node "$node" succeeded 0 builder-done || return 1
    else
      graph_shadow_record_node "$node" failed 0 builder-halted || return 1
      [ -n "$first_failed" ] || first_failed="$node"
    fi
  done
  if [ "$outcome" != succeeded ]; then
    [ -n "$first_failed" ] || {
      graph_shadow_error 'builder halt had no failed graph node'
      return 1
    }
    graph_shadow_record_decision HALTED "$first_failed"
  fi
}

graph_shadow_record_decision() {
  graph_shadow_enabled || return 0
  local decision="$1" node="${2:-}" attempt="${GRAPH_SHADOW_VERIFIER_ATTEMPT:-0}"
  graph_shadow_parity "$decision" "$node" || return 1
  case "$decision" in
    GO|EXTERNAL-EVIDENCE-OPEN)
      graph_shadow_record_node verifier succeeded "$attempt" "$decision" || return 1
      graph_shadow_record_node promote succeeded 0 "$decision" || return 1
      graph_shadow_record_node complete succeeded 0 "$decision" || return 1
      ;;
    NO-GO)
      graph_shadow_record_node verifier failed "$attempt" NO-GO || return 1
      graph_shadow_record_node repair failed "$attempt" NO-GO || return 1
      graph_shadow_record_node halt succeeded 0 NO-GO || return 1
      ;;
    HALTED)
      graph_shadow_record_node "$node" failed 0 HALTED || return 1
      graph_shadow_record_node halt succeeded 0 HALTED || return 1
      ;;
  esac
  graph_shadow_validate
}

# validate_manifest : fail LOUD before any git/tmux side effect on a malformed plan.
# jq -r turns a missing key into the literal string "null", so an under-specified
# lane would otherwise `git worktree add null -b null` and a 0-lane manifest would
# poll forever. Catch all of it here.
validate_manifest() {
  local i nm seen=""
  [ "${#LANE_NAMES[@]}" -ge 1 ] || die "manifest has no lanes — nothing to run"
  if [ -n "${MANIFEST_SESSION:-}" ]; then
    case "$MANIFEST_SESSION" in
      *[!A-Za-z0-9._-]*) die "manifest session has unsafe chars — use [A-Za-z0-9._-] only" ;;
    esac
  fi
  # agent must be a known profile unless a custom command template is supplied
  if [ -z "${POLYLANE_AGENT_CMD:-}" ]; then
    case "$(agent_selected)" in
      claude|codex|gpt|openai|aider) : ;;
      *) die "unknown agent '$(agent_selected)' — use claude|codex|gpt|aider, or set POLYLANE_AGENT_CMD with {model} {prompt}" ;;
    esac
  fi
  case "$(agent_selected)" in
    codex|gpt|openai)
      case "$(codex_sandbox_selected)" in
        read-only|workspace-write|danger-full-access) : ;;
        *) die "invalid Codex sandbox '$(codex_sandbox_selected)' — use read-only|workspace-write|danger-full-access" ;;
      esac
      ;;
  esac
  for field in INT_NAME INT_MODEL INT_BRANCH INT_WORKTREE; do
    [ "${!field}" = "null" ] && die "integrator.$(printf '%s' "$field" | tr 'A-Z_' 'a-z ' ) is missing in the manifest"
  done
  for i in "${!LANE_NAMES[@]}"; do
    nm="${LANE_NAMES[$i]}"
    for f in "$nm" "${LANE_MODELS[$i]}" "${LANE_BRANCHES[$i]}" "${LANE_WORKTREES[$i]}"; do
      [ "$f" = "null" ] || [ -z "$f" ] && die "lane #$i ('$nm') is missing a required field (name/model/branch/worktree)"
    done
    # lane names must be unique — they key the poll, the status file, and the pane label
    case " $seen " in *" $nm "*) die "duplicate lane name '$nm' — names must be unique" ;; esac
    # and shell/path safe — they land in tmux commands, branch names, and file paths
    case "$nm" in *[!A-Za-z0-9_-]*) die "lane name '$nm' has unsafe chars — use [A-Za-z0-9_-] only" ;; esac
    seen="$seen $nm"
  done
}

# ---------------------------------------------------------------------------
# intensity presets + runtime overrides (--intensity / --model)
# ---------------------------------------------------------------------------

# model_available ID : 0 iff ID is one of AVAILABLE_MODELS.
model_available() {
  local want="$1" m
  for m in "${AVAILABLE_MODELS[@]:-}"; do
    [ "$m" = "$want" ] && return 0
  done
  return 1
}

# preset_effort PRESET : echo the reasoning effort for a preset; rc 1 if unknown.
preset_effort() {
  # MUST match references/model-selection.md's intensity table (single source of truth).
  case "$1" in
    economy)     echo medium ;;
    balanced)    echo high ;;
    performance) echo high ;;
    max)         echo xhigh ;;
    *) return 1 ;;
  esac
}

# preset_model PRESET : echo the model id a preset resolves to. Walks the
# preset's preference ladder and returns the first id present in
# AVAILABLE_MODELS; if none of the ladder is available, falls back to the first
# available id (graceful). rc 1 for an unknown preset. Assumes a non-empty
# AVAILABLE_MODELS (apply_overrides guards that before calling).
preset_model() {
  local preset="$1" ladder m
  case "$preset" in
    economy)     ladder="claude-haiku-4-5 claude-fable-5 claude-sonnet-5 claude-opus-4-8" ;;
    balanced)    ladder="claude-sonnet-5 claude-fable-5 claude-haiku-4-5 claude-opus-4-8" ;;
    performance) ladder="claude-opus-4-8 claude-sonnet-5 claude-fable-5 claude-haiku-4-5" ;;
    max)         ladder="claude-opus-4-8 claude-sonnet-5 claude-fable-5 claude-haiku-4-5" ;;
    *) return 1 ;;
  esac
  for m in $ladder; do
    if model_available "$m"; then echo "$m"; return 0; fi
  done
  echo "${AVAILABLE_MODELS[0]}"
}

# apply_overrides : mutate the loaded lane/integrator model+effort from the CLI
# --intensity preset (all lanes + integrator) then --model lane=id (one lane,
# wins over the preset). Runs BEFORE any worktree/pane side effect; a bad
# preset / empty available_models / unknown lane exits non-zero, creating
# nothing. No-op when neither flag is passed.
apply_overrides() {
  local i eff mdl ov name id found

  if [ -n "${INTENSITY:-}" ]; then
    if ! eff=$(preset_effort "$INTENSITY"); then
      echo "polylane-run: unknown --intensity '$INTENSITY' (want economy|balanced|performance|max)" >&2
      exit 2
    fi
    if [ "${#AVAILABLE_MODELS[@]}" -eq 0 ]; then
      echo "polylane-run: --intensity needs a non-empty \"available_models\" in $MANIFEST" >&2
      exit 1
    fi
    mdl=$(preset_model "$INTENSITY")
    for i in "${!LANE_NAMES[@]}"; do
      LANE_MODELS[i]="$mdl"; LANE_EFFORTS[i]="$eff"
    done
    # integrator effort is clamped to xhigh regardless of preset (spec: the integrator's
    # cross-lane verify is the run's most critical judgment — never under-power it).
    INT_MODEL="$mdl"; INT_EFFORT="xhigh"
    echo "== intensity '$INTENSITY' -> lanes model=$mdl effort=$eff · integrator effort=xhigh =="
  fi

  for ov in "${MODEL_OVERRIDES[@]:-}"; do
    [ -n "$ov" ] || continue
    case "$ov" in
      *=*) : ;;
      *) echo "polylane-run: malformed --model '$ov' (want lane=model_id)" >&2; exit 2 ;;
    esac
    name="${ov%%=*}"; id="${ov#*=}"
    if [ -z "$name" ] || [ -z "$id" ]; then
      echo "polylane-run: malformed --model '$ov' (want lane=model_id)" >&2; exit 2
    fi
    found=0
    if [ "$name" = "$INT_NAME" ]; then INT_MODEL="$id"; found=1; fi
    for i in "${!LANE_NAMES[@]}"; do
      if [ "${LANE_NAMES[$i]}" = "$name" ]; then LANE_MODELS[i]="$id"; found=1; fi
    done
    if [ "$found" != "1" ]; then
      echo "polylane-run: --model names unknown lane '$name' (not a lane or the integrator)" >&2
      exit 2
    fi
    # Warn (don't die) if the id isn't in available_models — the list may be a stale
    # probe and the user may know a model it can't see; but a typo'd id would only
    # surface as a per-lane launch failure minutes later, so flag it now.
    if [ "${#AVAILABLE_MODELS[@]}" -gt 0 ] && ! model_available "$id"; then
      echo "polylane-run: WARNING — override model '$id' is not in available_models; launching anyway (typo? the lane will fail if the CLI can't reach it)" >&2
    fi
    echo "== model override: $name -> $id =="
  done
}

# ---------------------------------------------------------------------------
# split — one worktree per lane (idempotent)
# ---------------------------------------------------------------------------

add_worktree() {
  local wt="$1" br="$2"
  # Idempotency is a real-run concern; in dry-run always show the intended add.
  if [ "${DRY_RUN:-0}" != "1" ]; then
    if [ -d "$wt" ] || git worktree list --porcelain 2>/dev/null | grep -qF "worktree $wt"; then
      echo "worktree/path already exists, skipping: $wt"
      return 0
    fi
  fi
  if git show-ref --verify --quiet "refs/heads/$br"; then
    run git worktree add "$wt" "$br"
  else
    run git worktree add "$wt" -b "$br" "$BASE"
  fi
  share_graph "$wt"
}

# share_graph WT : symlink the parent repo's graphify-out/ into a fresh worktree.
# graphify-out/ is gitignored (0 tracked files), and `git worktree add` checks out
# TRACKED files only — so every lane was born graphless: its mandatory "query the
# graph" step either rebuilt the whole graph (N lanes = N redundant builds) or fell
# back to an Explore agent (the exact token cost graphify exists to avoid). One
# symlink gives every lane the parent's CURRENT graph for free. Read-only by
# contract: the orchestrator refreshes ONCE per cycle before launch; lanes only
# query (their prompts no longer run /graphify-auto).
share_graph() {
  local wt="$1" src="$REPO_ROOT/graphify-out"
  [ "${DRY_RUN:-0}" = "1" ] && { [ -d "$src" ] && echo "+ (dry-run) would symlink graphify-out into $wt"; return 0; }
  [ -d "$src" ] || return 0                      # no graph in this project — nothing to share
  [ -e "$wt/graphify-out" ] && return 0          # already there (resumed/reused worktree)
  ln -s "$src" "$wt/graphify-out" 2>/dev/null || true   # best-effort; lanes have the Explore fallback
}

# clear_stale_markers WT NAME : a fresh worktree checks out BASE and thus inherits
# ANY status/verify file committed on BASE by an earlier run — a stale "DONE" that
# makes the poll return instantly, or a stale "GO" the gate would trust. Delete the
# lane's own markers so THIS run must write them fresh. (Real-run bug: a committed
# docs/status-integrator.md + verify-integration.md made a fresh integrator poll
# return in 0s and the gate read an old GO.) No-op in dry-run.
clear_stale_markers() {
  local wt="$1" name="$2"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would clear any stale $wt/docs/status-$name.md"
    return 0
  fi
  rm -f "$wt/docs/status-$name.md"
}

split_worktrees() {
  local i
  for i in "${!LANE_NAMES[@]}"; do
    lane_resumed "$i" && continue
    add_worktree "${LANE_WORKTREES[$i]}" "${LANE_BRANCHES[$i]}"
    clear_stale_markers "${LANE_WORKTREES[$i]}" "${LANE_NAMES[$i]}"
  done
}

# ---------------------------------------------------------------------------
# resume — skip lanes whose DONE file is already valid
# ---------------------------------------------------------------------------

# lane_resumed IDX : 0 iff lane IDX was marked resumed (skip launch, no pane).
lane_resumed() { [ "${LANE_RESUMED[$1]:-0}" = "1" ]; }

# mark_resumed : with --resume, flag every lane whose DONE file is already
# valid so split/launch skip it. Runs BEFORE any worktree/pane side effect.
# A missing worktree or a stale/invalid status file simply relaunches the lane.
mark_resumed() {
  local i
  [ "${RESUME:-0}" = "1" ] || return 0
  for i in "${!LANE_NAMES[@]}"; do
    if lane_done "${LANE_WORKTREES[$i]}" "${LANE_NAMES[$i]}"; then
      LANE_RESUMED[i]=1
      echo "resume: lane '${LANE_NAMES[$i]}' already DONE — skipping launch"
    fi
  done
}

# ---------------------------------------------------------------------------
# launch — one seeded selected-agent pane per lane
# ---------------------------------------------------------------------------

# pane_cmd WORKTREE MODEL PROMPT_FILE [EFFORT] : the literal command a pane's
# shell runs. Reads the prompt at pane runtime via $(cat ...) — no prompt text
# is embedded in the orchestrator. On seed failure it copies the prompt to the
# clipboard and starts a bare claude so the operator can paste it.
# A non-empty EFFORT is exported to the pane as POLYLANE_EFFORT (a harmless env
# prefix claude ignores if unused).
# Every interpolated value is %q-escaped: a worktree/prompt path (or model id)
# containing spaces or quotes stays one shell word instead of splitting the
# command or escaping its quoting.
# --- agent adapter -----------------------------------------------------------
# polylane's pipeline (worktrees, poll, verdict, promote, cleanup) is agent-
# AGNOSTIC — it only watches files + panes. The ONE Claude-specific thing is how a
# pane launches its agent. agent_template makes that pluggable so a lane can run
# GPT (OpenAI codex), aider, or any CLI. Resolution order:
#   1. $POLYLANE_AGENT_CMD — a full custom template (highest priority).
#   2. the selected profile: $POLYLANE_AGENT (env) or `.agent` in the manifest.
#   3. claude (default — unchanged behavior).
# The template MUST contain {model} and {prompt}; pane_cmd substitutes both,
# %q-quoted. It may also contain {effort}. Effort is additionally passed to EVERY
# agent as the POLYLANE_EFFORT env var (agents that don't use it are unaffected).
agent_selected() { printf '%s' "${POLYLANE_AGENT:-${AGENT:-claude}}"; }
codex_sandbox_selected() {
  printf '%s' "${POLYLANE_CODEX_SANDBOX:-${CODEX_SANDBOX:-workspace-write}}"
}

agent_template() {
  if [ -n "${POLYLANE_AGENT_CMD:-}" ]; then printf '%s' "$POLYLANE_AGENT_CMD"; return; fi
  local pmode="${POLYLANE_PERMISSION_MODE:-acceptEdits}" codex_sandbox
  codex_sandbox=$(codex_sandbox_selected)
  case "$(agent_selected)" in
    # acceptEdits: lanes edit only their own files in an isolated worktree, so edits
    # are always safe to auto-accept; the walk-away design can't block per-edit.
    # --effort: the CLI's real reasoning-effort flag (low|medium|high|xhigh|max — the
    # SAME vocabulary polylane resolves from intensity). Without it a Claude lane's
    # effort was pure prompt-discretion ("run at HIGH effort, confirm with /model"),
    # while codex lanes already got it mechanically via model_reasoning_effort.
    claude)            printf 'claude --permission-mode %s --effort {effort} --model {model} "$(cat {prompt})"' "$(printf '%q' "$pmode")" ;;
    codex|gpt|openai)  printf 'codex exec --json --disable multi_agent --disable multi_agent_v2 --disable enable_fanout --sandbox %s{add_dir} -c approval_policy=never -c model_reasoning_effort={effort} --model {model} - < {prompt}' "$(printf '%q' "$codex_sandbox")" ;;
    aider)             printf 'aider --model {model} --message-file {prompt} --yes-always --no-auto-commits' ;;
    *) echo "polylane-run: unknown agent '$(agent_selected)' — set POLYLANE_AGENT_CMD to a template containing {model} and {prompt}" >&2; return 2 ;;
  esac
}

# codex_workspace_git_add_dir WT : `workspace-write` permits the linked
# worktree but not its shared repository metadata, so commits fail. Grant only
# the canonical common Git directory; read-only and explicitly dangerous modes
# intentionally receive no additional access flag.
codex_workspace_git_add_dir() {
  local wt="$1" common
  case "$(agent_selected):$(codex_sandbox_selected)" in
    codex:workspace-write|gpt:workspace-write|openai:workspace-write) : ;;
    *) return 0 ;;
  esac
  common=$(git -C "$wt" rev-parse --git-common-dir 2>/dev/null) || return 0
  case "$common" in
    /*) : ;;
    *) common=$(cd "$wt/$common" 2>/dev/null && pwd -P) || return 0 ;;
  esac
  [ -d "$common" ] || return 0
  printf ' --add-dir %s' "$(printf '%q' "$common")"
}

# agent_procs : process names that mean "the agent is still working" (for pane_dead).
agent_procs() {
  case "$(agent_selected)" in
    claude)            printf 'claude node' ;;
    codex|gpt|openai)  printf 'codex node' ;;
    aider)             printf 'aider python python3' ;;
    *)                 printf 'claude node codex aider python python3  node' ;;  # custom: permissive
  esac
}

pane_cmd() {
  local wt="$1" model="$2" pf="$3" effort="${4:-}" resume="${5:-}" pfx=""
  local qwt qmodel qpf qeffort tmpl add_dir
  qwt=$(printf '%q' "$wt"); qmodel=$(printf '%q' "$model"); qpf=$(printf '%q' "$pf"); qeffort=$(printf '%q' "${effort:-medium}")
  [ -n "$effort" ] && pfx="POLYLANE_EFFORT=$(printf '%q' "$effort") "
  # NEVER launch an agent with no prompt: that starts an amnesiac session with no
  # locked goal (the "pane sits at an empty input" bug). If the seeded agent exits
  # for ANY reason (crash, limit, /exit) the pane drops to a shell and prints a
  # marker; the health-check owns recovery — it re-seeds THIS same command.
  tmpl=$(agent_template) || tmpl='claude --model {model} "$(cat {prompt})"'
  add_dir=$(codex_workspace_git_add_dir "$wt")
  # RESPAWN with context: a re-seeded Claude lane otherwise starts a BRAND-NEW session
  # from the original prompt — its files survive (checkpoint_lane commits them) but
  # everything it worked out in-context is lost, so it re-derives from zero. `--continue`
  # resumes the most recent conversation IN THIS DIRECTORY (each lane owns its worktree),
  # and still delivers the prompt as the next message — resume + re-anchor the goal.
  # codex exec is stateless so it has no equivalent; only the claude profile gets this.
  if [ -n "$resume" ] && [ "$(agent_selected)" = claude ]; then
    tmpl=${tmpl/claude /claude --continue }
  fi
  tmpl=${tmpl//'{model}'/$qmodel}
  tmpl=${tmpl//'{prompt}'/$qpf}
  tmpl=${tmpl//'{effort}'/$qeffort}
  tmpl=${tmpl//'{add_dir}'/$add_dir}
  # shellcheck disable=SC2016  # $(cat …) must expand in the PANE's shell, not here
  printf 'cd %s && %s%s; printf "\\n[polylane] lane exited (rc=%%s) — health-check respawns if not DONE\\n" "$?"' \
    "$qwt" "$pfx" "$tmpl"
}

# assert_prompt PATH NAME : fail loudly (before any pane opens) if a lane's prompt
# file is missing or empty — the exact condition that otherwise launches an empty
# claude session that silently sits at a blank input.
assert_prompt() {
  local pf="$1" name="$2"
  # In dry-run this is a preview with no side effects — a missing prompt is a
  # warning, not a hard stop, so `--dry-run` works before the planner emits files.
  if [ ! -f "$pf" ] || [ ! -s "$pf" ]; then
    if [ "${DRY_RUN:-0}" = "1" ]; then
      echo "+ (dry-run) note: prompt file for lane '$name' not present yet: $pf" >&2
      return 0
    fi
    echo "polylane-run: prompt file MISSING/EMPTY for lane '$name': $pf" >&2
    echo "  the planner (/polylane) must emit it before launch — nothing to seed." >&2
    exit 1
  fi
}

# pipe_pane_log IDX NAME : mirror pane IDX's full transcript to
# docs/lane-logs/<NAME>.log (repo root; dir created; cleanup KEEPS it).
# -o makes ordinary launch/adoption calls idempotent. A respawn must call
# repipe_pane_log instead: tmux can retain stale pipe metadata after replacing a
# pane process, causing `pipe-pane -o` to silently leave the new transcript
# disconnected.
# The log path is %q-escaped — the pipe command runs through a shell.
pipe_pane_log() {
  local idx="$1" name="$2" dir="${REPO_ROOT:-.}/docs/lane-logs" qlog
  # best-effort: transcript logging must never break the run itself
  run mkdir -p "$dir" 2>/dev/null || { echo "pipe-pane: cannot create $dir — no transcript for '$name'" >&2; return 0; }
  qlog=$(printf '%q' "$dir/$name.log")
  run tmux pipe-pane -o -t "$TMUX_SESSION:0.$idx" "cat >> $qlog" 2>/dev/null || true
}

# repipe_pane_log IDX NAME : explicitly close any stale pipe left by
# `respawn-pane`, then attach a fresh logger to the replacement process.
repipe_pane_log() {
  local idx="$1" name="$2"
  run tmux pipe-pane -t "$TMUX_SESSION:0.$idx" 2>/dev/null || true
  pipe_pane_log "$idx" "$name"
}

# pane_for_worktree WT : print the pane index currently rooted at WT.
pane_for_worktree() {
  local wt="$1" line pane_path
  [ ! -d "$wt" ] || wt=$(cd "$wt" 2>/dev/null && pwd -P)
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    pane_path="${line#*|}"
    [ ! -d "$pane_path" ] || pane_path=$(cd "$pane_path" 2>/dev/null && pwd -P)
    [ "$pane_path" = "$wt" ] && { printf '%s' "${line%%|*}"; return 0; }
  done < <(tmux list-panes -t "$TMUX_SESSION:0" -F '#{pane_index}|#{pane_current_path}' 2>/dev/null || true)
  return 1
}

# session_owned_by_run : an existing session is adoptable only when it is tagged
# for this exact project/run, or (migration only) an untagged --resume session has
# a pane rooted in one of this manifest's worktrees. Never kill/adopt an unrelated
# session merely because its user-visible name happens to collide.
session_owned_by_run() {
  local tagged_run tagged_project i
  tmux has-session -t "$TMUX_SESSION" 2>/dev/null || return 1
  tagged_run=$(tmux show-options -t "$TMUX_SESSION" -v @polylane_run_id 2>/dev/null || true)
  tagged_project=$(tmux show-options -t "$TMUX_SESSION" -v @polylane_project 2>/dev/null || true)
  if [ -n "$tagged_run$tagged_project" ]; then
    [ "$tagged_run" = "${RUN_ID:-}" ] && [ "$tagged_project" = "${PROJECT_ROOT:-}" ]
    return
  fi
  [ "${RESUME:-0}" = "1" ] || return 1
  for i in "${!LANE_WORKTREES[@]}"; do
    pane_for_worktree "${LANE_WORKTREES[$i]}" >/dev/null && return 0
  done
  pane_for_worktree "$INT_WORKTREE" >/dev/null
}

tag_session() {
  [ "${DRY_RUN:-0}" = "1" ] && return 0
  run tmux set-option -q -t "$TMUX_SESSION" @polylane_run_id "${RUN_ID:-legacy}"
  run tmux set-option -q -t "$TMUX_SESSION" @polylane_project "${PROJECT_ROOT:-unknown}"
}

# adopt_existing_session : reconnect runner state to surviving tmux panes after a
# runner/supervisor crash. This is the critical resume seam: unfinished live Codex
# processes remain authoritative and are watched instead of duplicated.
adopt_existing_session() {
  local i idx max=-1 line
  [ "${RESUME:-0}" = "1" ] || return 0
  tmux has-session -t "$TMUX_SESSION" 2>/dev/null || return 0
  session_owned_by_run || die "SESSION-COLLISION: tmux '$TMUX_SESSION' is not owned by run ${RUN_ID:-legacy}; use a distinct POLYLANE_SESSION"
  SESSION_STARTED=1
  tag_session
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ "$line" -gt "$max" ] 2>/dev/null && max="$line"
  done < <(tmux list-panes -t "$TMUX_SESSION:0" -F '#{pane_index}' 2>/dev/null || true)
  NEXT_PANE_IDX=$((max + 1))
  for i in "${!LANE_NAMES[@]}"; do
    lane_resumed "$i" && continue
    if idx=$(pane_for_worktree "${LANE_WORKTREES[$i]}"); then
      LANE_PANE_IDX[i]="$idx"
      LANE_ADOPTED[i]=1
      echo "resume: adopted live tmux pane $idx for lane '${LANE_NAMES[$i]}'"
      pipe_pane_log "$idx" "${LANE_NAMES[$i]}"
    fi
  done
}

lane_adopted() { [ "${LANE_ADOPTED[$1]:-0}" = "1" ]; }

# new_pane WINDOW_NAME : create the next pane (new-session for the first,
# split-window after) and set NEW_PANE_IDX. Panes are targeted by EXPLICIT
# index ($TMUX_SESSION:0.N) everywhere, so health-check/respawn/stats stay
# correct when --resume skips lanes (positional index != lane order then).
new_pane() {
  if [ "${SESSION_STARTED:-0}" != "1" ]; then
    if [ "${DRY_RUN:-0}" != "1" ] && tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
      die "SESSION-COLLISION: tmux '$TMUX_SESSION' already exists; resume the owned run or choose a distinct POLYLANE_SESSION"
    fi
    # size the detached session generously: the default 80x24 can't tile a 3rd+ pane
    # ("no space for new pane" -> a later seed_pane hits "can't find pane: N"). tmux
    # resizes to the real client on attach, so a big virtual size is free.
    run tmux new-session -d -s "$TMUX_SESSION" -x "${POLYLANE_TMUX_COLS:-250}" -y "${POLYLANE_TMUX_ROWS:-60}" -n "${1:-lanes}"
    SESSION_STARTED=1
    tag_session
  else
    run tmux split-window -t "$TMUX_SESSION"
    run tmux select-layout -t "$TMUX_SESSION" tiled
  fi
  NEW_PANE_IDX="${NEXT_PANE_IDX:-0}"
  NEXT_PANE_IDX=$(( NEW_PANE_IDX + 1 ))
}

# seed_pane IDX CMD : type the seeded launch command into pane IDX.
# -l = literal: the command types as-is even if a chunk matches a tmux key name.
seed_pane() {
  run tmux send-keys -t "$TMUX_SESSION:0.$1" -l "$2"
  run tmux send-keys -t "$TMUX_SESSION:0.$1" C-m
}

launch_panes() {
  local i pc
  LAUNCHED=0
  # Preflight ALL prompts first — better to abort before opening a single pane
  # than to leave half a tmux session of empty claude sessions.
  for i in "${!LANE_NAMES[@]}"; do
    lane_resumed "$i" && continue
    lane_adopted "$i" && continue
    assert_prompt "${LANE_PROMPTS[$i]}" "${LANE_NAMES[$i]}"
  done
  for i in "${!LANE_NAMES[@]}"; do
    lane_resumed "$i" && continue
    lane_adopted "$i" && continue
    echo "lane ${LANE_NAMES[$i]}: model=${LANE_MODELS[$i]} effort=${LANE_EFFORTS[$i]:-(default)}"
    pc=$(pane_cmd "${LANE_WORKTREES[$i]}" "${LANE_MODELS[$i]}" "${LANE_PROMPTS[$i]}" "${LANE_EFFORTS[$i]:-}")
    graph_authority_require "lane:${LANE_NAMES[$i]}" "launch lane '${LANE_NAMES[$i]}'" || return 1
    new_pane "${LANE_NAMES[$i]}"
    LANE_PANE_IDX[i]="$NEW_PANE_IDX"
    seed_pane "$NEW_PANE_IDX" "$pc"
    pipe_pane_log "$NEW_PANE_IDX" "${LANE_NAMES[$i]}"
    LAUNCHED=$(( LAUNCHED + 1 ))
  done
}

# ---------------------------------------------------------------------------
# poll — wait for DONE files
# ---------------------------------------------------------------------------

# lane_done WORKTREE NAME : 0 iff the status marker matches this run. Contract-v2
# lanes are DONE only after that marker and every lane change are committed. This
# closes the marker-before-commit race where the runner could merge an older tip
# while the live agent was still staging its evidence.
lane_done() {
  local wt="$1" name="$2" f="$1/docs/status-$2.md" first="" head_first="" rel="docs/status-$2.md" dirty
  [ -f "$f" ] || return 1
  # `|| true`: read returns non-zero at EOF-before-newline but STILL populates $first,
  # so a marker written without a trailing newline (markers.sh done emits none) is read
  # correctly instead of reading as not-done forever. Empty file -> first="" -> != DONE.
  IFS= read -r first < "$f" || true
  if [ -n "${RUN_ID:-}" ]; then
    [ "$first" = "STATUS: $name DONE run=$RUN_ID" ] || return 1
  else
    [ "$first" = "STATUS: $name DONE" ] || return 1
  fi
  if [ "${ORCHESTRATION_CONTRACT:-0}" -ge 2 ] 2>/dev/null; then
    git -C "$wt" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
    dirty=$(git -C "$wt" status --porcelain --untracked-files=all --ignore-submodules=all 2>/dev/null) || return 1
    # `share_graph` creates exactly this untracked symlink in a lane. Accept it
    # only when it resolves to this runner's canonical graph directory; every
    # other dirty/untracked path remains a completion blocker.
    if [ -L "$wt/graphify-out" ] && [ -d "${REPO_ROOT:-}/graphify-out" ]; then
      local graph_link graph_owner
      graph_link=$(cd "$wt/graphify-out" 2>/dev/null && pwd -P) || graph_link=""
      graph_owner=$(cd "${REPO_ROOT:-}/graphify-out" 2>/dev/null && pwd -P) || graph_owner=""
      if [ -n "$graph_link" ] && [ "$graph_link" = "$graph_owner" ]; then
        dirty=$(printf '%s\n' "$dirty" | awk '$0 != "?? graphify-out"')
      fi
    fi
    [ -z "$dirty" ] || return 1
    git -C "$wt" cat-file -e "HEAD:$rel" 2>/dev/null || return 1
    IFS= read -r head_first < <(git -C "$wt" show "HEAD:$rel" 2>/dev/null) || true
    if [ -n "${RUN_ID:-}" ]; then
      [ "$head_first" = "STATUS: $name DONE run=$RUN_ID" ] || return 1
    else
      [ "$head_first" = "STATUS: $name DONE" ] || return 1
    fi
  fi
  return 0
}

# --- health-check + auto-retry (transient API/network errors) ----------------
# A lane that hits a 500 / overloaded / network error stops WITHOUT writing its
# DONE file, so a plain DONE-poll would hang forever. Every POLYLANE_HEALTH_INTERVAL
# (default 15s) we scan each unfinished lane's pane for an error banner and
# respawn (retry) it, up to POLYLANE_MAX_RETRIES (default 3). Past the cap the lane
# is marked failed so the run halts with a report instead of hanging.
# bash-3.2 safe: indexed arrays only (LANE_RETRIES keyed by pane index), no assoc.

# pane_index_for NAME : tmux pane index for a lane / the integrator, from the
# explicit mapping assigned at launch. -1 if unknown or never launched (e.g.
# a lane skipped by --resume has no pane).
pane_index_for() {
  local name="$1" i
  for i in "${!LANE_NAMES[@]}"; do
    [ "${LANE_NAMES[$i]}" = "$name" ] && { printf '%s' "${LANE_PANE_IDX[$i]:--1}"; return; }
  done
  [ "$name" = "${INT_NAME:-}" ] && { printf '%s' "${INT_PANE_IDX:--1}"; return; }
  printf '%s' "-1"
}

# pane_cmd_for NAME : the seeded launch command for a lane / the integrator.
pane_cmd_for() {
  local name="$1" resume="${2:-}" i
  for i in "${!LANE_NAMES[@]}"; do
    [ "${LANE_NAMES[$i]}" = "$name" ] && {
      pane_cmd "${LANE_WORKTREES[$i]}" "${LANE_MODELS[$i]}" "${LANE_PROMPTS[$i]}" "${LANE_EFFORTS[$i]:-}" "$resume"
      return
    }
  done
  [ "$name" = "${INT_NAME:-}" ] && pane_cmd "$INT_WORKTREE" "$INT_MODEL" "$INT_PROMPT" "${INT_EFFORT:-}" "$resume"
}

# pane_errored IDX : 0 iff the pane shows a transient error signature (or died).
pane_errored() {
  local idx="$1" txt
  [ "$idx" -ge 0 ] 2>/dev/null || return 1
  txt=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p 2>/dev/null || true)
  printf '%s' "$txt" | grep -qiE \
    'API Error|Internal server error|overloaded|rate.?limit|Connection error|network error|5[0-9][0-9] (Internal|error)|status\.claude\.com' \
    && return 0
  return 1
}

# pane_retryable_error IDX : an error signature is destructive only after the
# lane's agent process has exited. Codex JSON streams legitimately retain failed
# MCP/tool calls in pane scrollback while the same turn keeps working; respawning
# on that text discards a productive, expensive context. A still-live process
# that actually freezes is recovered by pane_wedged after the normal grace window.
pane_retryable_error() {
  pane_errored "$1" && pane_dead "$1"
}

lane_failed() { case " ${FAILED_LANES:-} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# --- usage-limit stall (money decision — never auto-answered/retried) ---------
# A pane asking to buy/switch credits is STALLED, not errored: a respawn would
# just re-hit the paywall, and auto-answering would spend money without a
# human. Detect it, notify once, surface it in the poll + report, and wait.

# pane_stalled IDX : 0 iff the pane shows a usage-limit / paywall prompt.
pane_stalled() {
  local idx="$1" txt
  [ "$idx" -ge 0 ] 2>/dev/null || return 1
  txt=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p 2>/dev/null || true)
  printf '%s' "$txt" | grep -qiE 'usage limit|Switch to usage credits|Upgrade your plan'
}

lane_stalled() { case " ${STALLED_LANES:-} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# stall_check SPEC... : mark newly stalled lanes (sticky) and notify ONCE each.
stall_check() {
  local s name wt idx
  for s in "$@"; do
    name="${s%%:*}"; wt="${s#*:}"
    lane_done "$wt" "$name" && continue
    lane_failed "$name" && continue
    lane_stalled "$name" && continue
    idx=$(pane_index_for "$name")
    pane_stalled "$idx" || continue
    STALLED_LANES="${STALLED_LANES:+$STALLED_LANES }$name"
    echo "stall: lane '$name' hit a usage limit — waiting for a human decision (no auto-retry)"
    notify_event stall "lane '$name' hit a usage limit — human decision needed"
  done
}
retry_get()   { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && printf '%s' "${LANE_RETRIES[$i]:-0}" || printf '0'; }
retry_set()   { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && LANE_RETRIES[i]="$2"; }

# --- approval relay: auto-approve SAFE prompts, escalate CRITICAL ones ---------
# Lanes run in acceptEdits mode, so file edits never prompt. A lane can still hit a
# permission prompt for a NON-edit tool (a bash command, etc.). A walk-away run must
# not hang on it, but must not blindly approve something destructive either. So:
#   - SAFE (default in an isolated worktree: local test/build/git-add/mkdir/…) -> auto-approve.
#   - CRITICAL (network, destructive, secrets, force-push, outside the worktree)
#     -> DO NOT auto-answer; fire an 'approval' notification (once) and PARK it for a
#        human decision, exactly like a usage stall. The orchestrator relays it to the
#        user and sends the chosen keystroke.

# pane_awaiting_approval IDX : 0 iff the pane shows a permission menu.
pane_awaiting_approval() {
  local idx="$1" txt
  [ "$idx" -ge 0 ] 2>/dev/null || return 1
  txt=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p 2>/dev/null || true)
  printf '%s' "$txt" | grep -qiE 'Do you want to (run|proceed|make|create|delete|allow)|Do you want to proceed\?' \
    && printf '%s' "$txt" | grep -qE '❯?[[:space:]]*1\.[[:space:]]*Yes'
}

# --- startup unstick: answer the CLI's own onboarding prompts -----------------
# The "workers initialize but never start" wedge: a fresh worktree is a NEW path,
# so the agent CLI shows a folder-TRUST dialog ("Do you trust the files in this
# folder?") before reading any input — the seeded prompt sits unread underneath.
# That dialog matches none of the error/stall/approval signatures, the process is
# alive, so the health loop saw a healthy pane doing nothing, forever. These
# prompts are SAFE by construction (the worktree is polylane's own checkout of the
# user's own repo), so answer them at poll frequency (5s), not health frequency.
# startup_check SPEC... : per unfinished lane, clear trust/onboarding dialogs.
startup_check() {
  local s name wt idx txt
  for s in "$@"; do
    name="${s%%:*}"; wt="${s#*:}"
    lane_done "$wt" "$name" && continue
    lane_failed "$name" && continue
    idx=$(pane_index_for "$name")
    [ "$idx" -ge 0 ] 2>/dev/null || continue
    txt=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p 2>/dev/null || true)
    if printf '%s' "$txt" | grep -qiE 'Do you trust the files in this (folder|directory)|Trust this (folder|workspace)'; then
      # option 1 = "Yes, proceed" — our own worktree, always trusted
      tmux send-keys -t "$TMUX_SESSION:0.$idx" '1' 2>/dev/null
      tmux send-keys -t "$TMUX_SESSION:0.$idx" Enter 2>/dev/null
      echo "startup: lane '$name' — answered folder-trust dialog"
    elif printf '%s' "$txt" | grep -qiE 'Press Enter to continue|to get started'; then
      tmux send-keys -t "$TMUX_SESSION:0.$idx" Enter 2>/dev/null
      echo "startup: lane '$name' — cleared an onboarding banner"
    fi
  done
}

# approval_is_critical "<pane text>" : 0 iff the requested action looks dangerous —
# then it is escalated instead of auto-approved. Conservative: anything network,
# destructive, secret-touching, force-pushing, or reaching outside the worktree.
approval_is_critical() {
  printf '%s' "$1" | grep -qiE \
    'rm +-[a-z]*f|git +push|--force|force-with-lease|curl |wget |sudo |ssh |scp |npm +(i|install|publish)|yarn +add|pnpm +add|pip +install|( |^)brew |( |^)apt |>[[:space:]]*/|/etc/|/usr/|/bin/|~/\.|\.env|secret|password|api[_-]?key|token|credential|( |^)kill |chmod +7|( |^)eval |mkfs|( |^)dd '
}

# approval_check SPEC... : per unfinished lane, auto-approve a safe prompt or escalate.
approval_check() {
  local s name wt idx txt
  for s in "$@"; do
    name="${s%%:*}"; wt="${s#*:}"
    lane_done "$wt" "$name" && continue
    lane_failed "$name" && continue
    lane_stalled "$name" && continue
    idx=$(pane_index_for "$name")
    pane_awaiting_approval "$idx" || continue
    txt=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p -S -20 2>/dev/null || true)
    if approval_is_critical "$txt"; then
      lane_needs_decision "$name" && continue        # already escalated — leave parked
      NEEDS_DECISION_LANES="${NEEDS_DECISION_LANES:+$NEEDS_DECISION_LANES }$name"
      echo "approval: lane '$name' needs a DECISION (critical action) — parked for a human"
      notify_event approval "lane '$name' asks approval for a critical action — decide in chat"
    else
      # safe (isolated worktree, local op) — approve + stop re-asking for its kind
      if printf '%s' "$txt" | grep -qE '2\.[[:space:]]*Yes'; then
        tmux send-keys -t "$TMUX_SESSION:0.$idx" '2' 2>/dev/null   # "…don't ask again / allow all"
      else
        tmux send-keys -t "$TMUX_SESSION:0.$idx" '1' 2>/dev/null   # "Yes"
      fi
      echo "approval: auto-approved a safe prompt for lane '$name'"
    fi
  done
}
lane_needs_decision() { case " ${NEEDS_DECISION_LANES:-} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# --- walk-away recovery: dead panes + usage-limit fallback --------------------
# For a TRULY unattended run every not-DONE lane must keep making progress with
# zero human input. Three recovery paths, all owned by the health-check:
#   errored  -> respawn same seed (transient API/network)         [existing]
#   dead     -> pane dropped to a shell (agent exited) -> respawn same seed
#   stalled  -> usage-limit paywall -> POLYLANE_ON_LIMIT policy (below)

# pane_agent_live IDX : 0 iff the pane command or bounded descendant tree still
# contains the selected agent. Kept separate so the wedge detector can give a
# live inference/build/test turn a longer quiet window than an empty shell.
pane_agent_live() {
  local idx="$1" cmd p pane_pid
  [ "$idx" -ge 0 ] 2>/dev/null || return 1
  cmd=$(tmux display-message -t "$TMUX_SESSION:0.$idx" -p '#{pane_current_command}' 2>/dev/null || echo "")
  for p in $(agent_procs); do
    case "$cmd" in *"$p"*) return 0 ;; esac
  done
  # tmux often reports the pane's login shell while `codex exec` is a child (or
  # grandchild). Inspect the bounded descendant tree too.
  pane_pid=$(tmux display-message -t "$TMUX_SESSION:0.$idx" -p '#{pane_pid}' 2>/dev/null || true)
  [ -n "$pane_pid" ] && process_tree_has_agent "$pane_pid"
}

# pane_dead IDX : 0 iff the pane's foreground process is a plain shell (the agent
# exited) rather than a live agent process. Agent-aware (agent_procs), so it works
# for claude, codex/gpt, aider, or a custom agent. Unknown cmd -> not dead.
pane_dead() {
  local idx="$1" cmd
  [ "$idx" -ge 0 ] 2>/dev/null || return 1
  pane_agent_live "$idx" && return 1
  cmd=$(tmux display-message -t "$TMUX_SESSION:0.$idx" -p '#{pane_current_command}' 2>/dev/null || echo "")
  [ -z "$cmd" ] && return 1                              # unknown -> leave it
  case "$cmd" in
    *sh|-*) return 0 ;;                                  # shell prompt = agent exited
    *)      return 1 ;;                                  # unknown -> no false respawn
  esac
}

process_tree_has_agent() {
  local queue="$1" seen="" pid comm child p count=0
  while [ -n "$queue" ] && [ "$count" -lt 128 ]; do
    pid="${queue%% *}"
    if [ "$queue" = "$pid" ]; then queue=""; else queue="${queue#* }"; fi
    case " $seen " in *" $pid "*) continue ;; esac
    seen="$seen $pid"; count=$((count + 1))
    comm=$(ps -p "$pid" -o comm= 2>/dev/null || true)
    for p in $(agent_procs); do
      case "$comm" in *"/$p"|"$p"|*"/$p "*) return 0 ;; esac
    done
    for child in $(pgrep -P "$pid" 2>/dev/null || true); do
      queue="${queue:+$queue }$child"
    done
  done
  return 1
}

# unstall NAME : drop NAME from the sticky STALLED_LANES set.
unstall() {
  local out="" x
  for x in ${STALLED_LANES:-}; do [ "$x" = "$1" ] || out="${out:+$out }$x"; done
  STALLED_LANES="$out"
}

# lane_model_get/set NAME : the live model for a lane / the integrator (mutated
# by a usage-limit fallback so pane_cmd_for + the report reflect the downgrade).
lane_model_get() {
  local i
  for i in "${!LANE_NAMES[@]}"; do [ "${LANE_NAMES[$i]}" = "$1" ] && { printf '%s' "${LANE_MODELS[$i]}"; return; }; done
  [ "$1" = "${INT_NAME:-}" ] && printf '%s' "${INT_MODEL:-}"
}
lane_model_set() {
  local i
  for i in "${!LANE_NAMES[@]}"; do [ "${LANE_NAMES[$i]}" = "$1" ] && { LANE_MODELS[i]="$2"; return; }; done
  [ "$1" = "${INT_NAME:-}" ] && INT_MODEL="$2"
}

lane_effort_get() {
  local i
  for i in "${!LANE_NAMES[@]}"; do [ "${LANE_NAMES[$i]}" = "$1" ] && { printf '%s' "${LANE_EFFORTS[$i]:-medium}"; return; }; done
  [ "$1" = "${INT_NAME:-}" ] && printf '%s' "${INT_EFFORT:-medium}"
}
lane_effort_set() {
  local i
  for i in "${!LANE_NAMES[@]}"; do [ "${LANE_NAMES[$i]}" = "$1" ] && { LANE_EFFORTS[i]="$2"; return; }; done
  [ "$1" = "${INT_NAME:-}" ] && INT_EFFORT="$2"
}

# runtime_settings_fingerprint : stable checksum of manifest fields that may be
# deliberately tuned while a durable runner stays alive. Internal fallbacks do
# not change it, so an unchanged manifest cannot undo an in-process downgrade.
runtime_settings_fingerprint() {
  [ -n "${MANIFEST:-}" ] && [ -f "$MANIFEST" ] || return 1
  jq -c '{
    codex_sandbox:(.codex_sandbox // "workspace-write"),
    lanes: [.lanes[] | {name, model, effort:(.effort // "")}],
    integrator: {
      name:.integrator.name,
      model:.integrator.model,
      effort:(.integrator.effort // "")
    }
  }' "$MANIFEST" 2>/dev/null | cksum | awk '{print $1 ":" $2}'
}

# refresh_manifest_runtime_settings : apply an explicit live manifest model or
# effort edit before the next respawn. This lets an observer narrow an expensive
# lane without restarting or duplicating the supervisor. Unchanged manifests do
# not overwrite usage-limit or command-churn fallbacks held in runner memory.
refresh_manifest_runtime_settings() {
  local current i name model effort int_model int_effort codex_sandbox
  current=$(runtime_settings_fingerprint) || return 0
  [ -n "${MANIFEST_RUNTIME_FINGERPRINT:-}" ] || {
    MANIFEST_RUNTIME_FINGERPRINT="$current"
    return 0
  }
  [ "$current" != "$MANIFEST_RUNTIME_FINGERPRINT" ] || return 0

  for i in "${!LANE_NAMES[@]}"; do
    name="${LANE_NAMES[$i]}"
    model=$(jq -r --arg n "$name" '.lanes[] | select(.name==$n) | .model' "$MANIFEST" 2>/dev/null | head -n 1)
    effort=$(jq -r --arg n "$name" '.lanes[] | select(.name==$n) | (.effort // "")' "$MANIFEST" 2>/dev/null | head -n 1)
    [ -n "$model" ] && [ "$model" != "null" ] || {
      echo "runtime-config: ignored invalid live manifest edit for lane '$name'" >&2
      return 0
    }
    LANE_MODELS[i]="$model"
    LANE_EFFORTS[i]="$effort"
  done

  int_model=$(jq -r '.integrator.model' "$MANIFEST" 2>/dev/null)
  int_effort=$(jq -r '.integrator.effort // ""' "$MANIFEST" 2>/dev/null)
  [ -n "$int_model" ] && [ "$int_model" != "null" ] || {
    echo "runtime-config: ignored invalid live manifest integrator edit" >&2
    return 0
  }
  INT_MODEL="$int_model"
  INT_EFFORT="$int_effort"
  codex_sandbox=$(jq -r '.codex_sandbox // "workspace-write"' "$MANIFEST" 2>/dev/null)
  case "$codex_sandbox" in
    read-only|workspace-write|danger-full-access) CODEX_SANDBOX="$codex_sandbox" ;;
    *)
      echo "runtime-config: ignored invalid live manifest Codex sandbox '$codex_sandbox'" >&2
      return 0
      ;;
  esac
  MANIFEST_RUNTIME_FINGERPRINT="$current"
  echo "runtime-config: reloaded live manifest model/effort/sandbox settings"
}

next_lower_effort() {
  case "$1" in
    ultra|max|xhigh) printf 'high' ;;
    high)            printf 'medium' ;;
    medium)          printf 'low' ;;
    *)               printf 'low' ;;
  esac
}

stallwait_get() { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && printf '%s' "${LANE_STALLWAIT[$i]:-0}" || printf '0'; }
stallwait_set() { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && LANE_STALLWAIT[i]="$2"; }

# next_fallback_model CURRENT : echo the next model DOWN the fallback ladder that
# is in AVAILABLE_MODELS. Ladder is ordered by likelihood of a plan limit
# (Fable first — it burns weekly limits fastest), so fallback walks fable ->
# opus -> sonnet -> haiku. rc 1 when nothing is left below CURRENT (=> lane fails).
next_fallback_model() {
  local cur="$1" past=0 m ladder
  case "$(agent_selected)" in
    codex|gpt|openai) ladder="gpt-5.6-sol gpt-5.6-terra" ;;
    *)                ladder="claude-fable-5 claude-opus-4-8 claude-sonnet-5 claude-haiku-4-5" ;;
  esac
  for m in $ladder; do
    if [ "$past" = "1" ]; then model_available "$m" && { printf '%s' "$m"; return 0; }; fi
    [ "$m" = "$cur" ] && past=1
  done
  # CURRENT not on the ladder: offer the first available model that isn't CURRENT.
  if [ "$past" = "0" ]; then
    for m in $ladder; do
      [ "$m" != "$cur" ] && model_available "$m" && { printf '%s' "$m"; return 0; }
    done
  fi
  return 1
}

# respawn_lane IDX NAME WT : checkpoint WIP then re-seed the pane with the CURRENT
# (possibly downgraded) model. Used by both dead-pane recovery and stall fallback.
respawn_lane() {
  local idx="$1" name="$2" wt="$3" cmd
  checkpoint_lane "$wt" "$name"
  refresh_manifest_runtime_settings
  # fresh wedge window: a respawned pane gets full POLYLANE_WEDGE_CHECKS before it
  # can be declared frozen again (otherwise the stale hash re-triggers instantly).
  wedge_hash_set "$name" ""; wedge_cnt_set "$name" 0
  progress_hash_set "$name" ""; progress_count_set "$name" 0
  # FIRST respawn resumes the lane's session (keeps everything it worked out); later
  # respawns use the proven cold seed, so a session that genuinely can't resume costs
  # exactly one retry instead of looping on a failing --continue.
  local resume=""
  [ "$(retry_get "$name")" = "1" ] && resume=resume
  cmd=$(pane_cmd_for "$name" "$resume")
  if ! run tmux respawn-pane -k -t "$TMUX_SESSION:0.$idx" "$cmd" 2>/dev/null; then
    run tmux send-keys -t "$TMUX_SESSION:0.$idx" C-c 2>/dev/null || true
    run tmux send-keys -t "$TMUX_SESSION:0.$idx" -l "$cmd" 2>/dev/null || true
    run tmux send-keys -t "$TMUX_SESSION:0.$idx" C-m 2>/dev/null || true
  fi
  repipe_pane_log "$idx" "$name"
}

# --- Reflexion: reflect-then-repair before giving up on a lane ----------------
# When transient retries are exhausted the lane has likely failed on APPROACH,
# not luck — so a plain respawn of the SAME prompt just fails again. Instead we
# respawn ONCE more with an augmented prompt that makes the lane read its own
# prior transcript (docs/lane-logs/<name>.log), write a 3-line reflection, and
# take a DIFFERENT approach. Cheap (no extra model call from bash — the lane does
# the reflection itself) and high-leverage. Capped by POLYLANE_MAX_REPAIRS.
lane_prompt_get() {
  local i
  for i in "${!LANE_NAMES[@]}"; do [ "${LANE_NAMES[$i]}" = "$1" ] && { printf '%s' "${LANE_PROMPTS[$i]}"; return; }; done
  [ "$1" = "${INT_NAME:-}" ] && printf '%s' "${INT_PROMPT:-}"
}
lane_prompt_set() {
  local i
  for i in "${!LANE_NAMES[@]}"; do [ "${LANE_NAMES[$i]}" = "$1" ] && { LANE_PROMPTS[i]="$2"; return; }; done
  [ "$1" = "${INT_NAME:-}" ] && INT_PROMPT="$2"
}
repairs_get() { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && printf '%s' "${LANE_REPAIRS[$i]:-0}" || printf '0'; }
repairs_set() { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && LANE_REPAIRS[i]="$2"; }

# build_repair_prompt SRC NAME K -> stdout : original prompt + a reflect-then-fix
# addendum. Kept as a pure function so it is unit-testable without tmux.
build_repair_prompt() {
  local src="$1" name="$2" k="$3"
  local transcript="${REPO_ROOT:-.}/docs/lane-logs/$name.log"
  cat "$src" 2>/dev/null
  printf '\n\n── REPAIR ATTEMPT %s (a prior attempt did NOT reach DONE) ──────────────\n' "$k"
  printf 'FIRST, before any new work: read the tail of `%s` (your own\n' "$transcript"
  printf 'prior transcript) and any docs/verify-%s.md. Write a 3-line reflection into\n' "$name"
  printf 'docs/verify-%s.md — (1) what went wrong (2) the root cause (3) the DIFFERENT\n' "$name"
  printf 'approach you will now take. THEN fix and drive to DONE. Do NOT repeat the\n'
  printf 'failed approach. Your locked goal is unchanged.\n'
  printf 'DELEGATION: forbidden. Do not spawn subagents, collaboration agents, or fan-out.\n'
  printf 'CHECK-CACHE: do not repeat an unchanged expensive check; use polylane-check.sh.\n'
}

# reflect_and_repair NAME WT IDX : write the augmented prompt, point the lane at
# it, reset the transient-retry budget, and respawn. rc 1 if the file cannot be
# written (caller then marks the lane failed).
reflect_and_repair() {
  local name="$1" wt="$2" idx="$3" k src dir repair
  k=$(repairs_get "$name"); k=$((k + 1))
  dir="$REPO_ROOT/.polylane/lanes"; run mkdir -p "$dir" 2>/dev/null || true
  src=$(lane_prompt_get "$name")
  repair="$dir/$name.repair.txt"
  build_repair_prompt "$src" "$name" "$k" > "$repair" 2>/dev/null \
    || { echo "reflexion: could not write $repair for '$name'" >&2; return 1; }
  lane_prompt_set "$name" "$repair"   # future respawns use the repaired prompt
  repairs_set "$name" "$k"
  retry_set "$name" 0                  # fresh transient budget after a repair
  echo "reflexion: lane '$name' — repair attempt $k (reflect-then-fix), respawning pane $idx"
  notify_event stall "lane '$name': repair attempt $k (reflect + retry)"
  respawn_lane "$idx" "$name" "$wt"
}

# resolve_stalls SPEC... : act on each usage-limit-stalled lane per POLYLANE_ON_LIMIT
# (default fallback). Every branch is terminating — a stalled lane ends up either
# working again (fallback/credits) or failed (no model left / wait exhausted) — so
# an unattended run never hangs on a paywall.
resolve_stalls() {
  local policy="${POLYLANE_ON_LIMIT:-fallback}" s name wt idx cur nxt w wmax
  for s in "$@"; do
    name="${s%%:*}"; wt="${s#*:}"
    lane_stalled "$name" || continue
    lane_done "$wt" "$name" && { unstall "$name"; continue; }
    idx=$(pane_index_for "$name")
    case "$policy" in
      wait)
        w=$(stallwait_get "$name"); w=$((w + 1)); stallwait_set "$name" "$w"
        wmax="${POLYLANE_STALL_MAX:-6}"
        if [ "$w" -ge "$wmax" ]; then
          echo "stall: lane '$name' still limited after $w checks — marking failed (POLYLANE_ON_LIMIT=wait)." >&2
          FAILED_LANES="${FAILED_LANES:+$FAILED_LANES }$name"; unstall "$name"
        else
          echo "stall: lane '$name' limited — waiting ($w/$wmax, POLYLANE_ON_LIMIT=wait)"
        fi
        ;;
      credits)
        echo "stall: lane '$name' limited — selecting 'usage credits' (POLYLANE_ON_LIMIT=credits)"
        run tmux send-keys -t "$TMUX_SESSION:0.$idx" Down 2>/dev/null || true
        run tmux send-keys -t "$TMUX_SESSION:0.$idx" C-m 2>/dev/null || true
        unstall "$name"   # gave it credits; if it re-stalls it re-marks next poll
        ;;
      fallback|*)
        cur=$(lane_model_get "$name")
        if nxt=$(next_fallback_model "$cur"); then
          echo "stall: lane '$name' limited on $cur — falling back to $nxt (POLYLANE_ON_LIMIT=fallback)"
          notify_event stall "lane '$name': $cur limited — retrying on $nxt"
          lane_model_set "$name" "$nxt"
          respawn_lane "$idx" "$name" "$wt"
          unstall "$name"
        else
          echo "stall: lane '$name' limited on $cur, no fallback model left — marking failed." >&2
          notify_event halt "lane '$name': usage limited, no fallback model available"
          FAILED_LANES="${FAILED_LANES:+$FAILED_LANES }$name"; unstall "$name"
        fi
        ;;
    esac
  done
}

# checkpoint_lane WT NAME : commit tracked WIP on the lane branch BEFORE a
# respawn, so a retry can never lose work (a fresh claude session may reset or
# rewrite files). `commit -am` covers tracked edits only — untracked files
# survive a respawn anyway (the pane process dies, the tree doesn't) and bulk-
# adding them would violate the never-`git add -A` rule. Best-effort: a failed
# commit (e.g. missing identity) warns but never blocks the retry.
checkpoint_lane() {
  local wt="$1" name="$2"
  if git -C "$wt" diff --quiet 2>/dev/null && git -C "$wt" diff --cached --quiet 2>/dev/null; then
    return 0
  fi
  echo "health: checkpointing lane '$name' WIP before retry"
  run git -C "$wt" commit -am "WIP checkpoint (polylane auto-retry: $name)" \
    || echo "health: WIP checkpoint failed in $wt — continuing with retry" >&2
}

# pane_wedged NAME IDX : 0 iff the pane's content has not changed across a
# bounded health window while the lane is unfinished. Empty/dead-start panes use
# POLYLANE_WEDGE_CHECKS (default 4 = about 60s). A confirmed live agent uses the
# longer POLYLANE_LIVE_WEDGE_CHECKS (default 20 = about 5m), because Codex can
# legitimately emit no pane bytes while inference or a quiet verifier is active.
# This still recovers a genuinely hung live turn, without destroying an expensive
# context every time a valid command is quiet for one minute.
pane_wedged() {
  local name="$1" idx="$2" h prev cnt limit
  h=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p 2>/dev/null | cksum | cut -d' ' -f1)
  [ -n "$h" ] || return 1
  prev=$(wedge_hash_get "$name"); cnt=$(wedge_cnt_get "$name")
  if [ "$h" = "$prev" ]; then cnt=$((cnt + 1)); else cnt=0; fi
  wedge_hash_set "$name" "$h"; wedge_cnt_set "$name" "$cnt"
  limit="${POLYLANE_WEDGE_CHECKS:-4}"
  pane_agent_live "$idx" && limit="${POLYLANE_LIVE_WEDGE_CHECKS:-20}"
  [ "$cnt" -ge "$limit" ]
}
wedge_hash_get() { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && printf '%s' "${LANE_WHASH[$i]:-}" || printf ''; }
wedge_hash_set() { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && LANE_WHASH[i]="$2"; }
wedge_cnt_get()  { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && printf '%s' "${LANE_WCNT[$i]:-0}" || printf '0'; }
wedge_cnt_set()  { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && LANE_WCNT[i]="$2"; }

# Material-progress guard: a pane whose screen keeps changing can still churn
# through commands without changing source or producing evidence. After a
# bounded number of health checks AND command executions on the same material
# fingerprint, checkpoint it, lower model/effort where possible, and respawn
# with a narrow no-repeat plan.
worktree_fingerprint() {
  local wt="$1"
  {
    git -C "$wt" rev-parse HEAD 2>/dev/null || true
    git -C "$wt" diff --no-ext-diff --binary 2>/dev/null || true
    git -C "$wt" diff --cached --no-ext-diff --binary 2>/dev/null || true
    git -C "$wt" status --porcelain=v1 2>/dev/null || true
  } | cksum | awk '{print $1 ":" $2}'
}
lane_command_count() {
  local name="$1" log="${REPO_ROOT:-.}/docs/lane-logs/$1.log" count
  [ -f "$log" ] || { printf '0'; return; }
  count=$(grep -cE '"type":"item.started".*"type":"command_execution"|"type":"command_execution".*"status":"in_progress"' "$log" 2>/dev/null || true)
  printf '%s' "${count:-0}"
}
lane_material_event_count() {
  local name="$1" log="${REPO_ROOT:-.}/docs/lane-logs/$1.log" count
  [ -f "$log" ] || { printf '0'; return; }
  # Codex emits completed agent milestones and file changes as compact JSONL.
  # These are durable semantic/evidence progress even when a certification lane
  # intentionally leaves executable source untouched.
  count=$(grep -cE '"type":"item.completed".*"type":"(agent_message|file_change)"' "$log" 2>/dev/null || true)
  printf '%s' "${count:-0}"
}
material_progress_fingerprint() {
  printf '%s:%s' "$(worktree_fingerprint "$2")" "$(lane_material_event_count "$1")"
}
progress_hash_get()     { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && printf '%s' "${LANE_PHASH[$i]:-}" || printf ''; }
progress_hash_set()     { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && LANE_PHASH[i]="$2"; }
progress_count_get()    { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && printf '%s' "${LANE_PCNT[$i]:-0}" || printf '0'; }
progress_count_set()    { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && LANE_PCNT[i]="$2"; }
progress_commands_get() { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && printf '%s' "${LANE_PCOMMANDS[$i]:-0}" || printf '0'; }
progress_commands_set() { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && LANE_PCOMMANDS[i]="$2"; }
progress_replans_get()  { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && printf '%s' "${LANE_PREPLANS[$i]:-0}" || printf '0'; }
progress_replans_set()  { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && LANE_PREPLANS[i]="$2"; }

material_progress_stalled() {
  local name="$1" wt="$2" fp prev cnt commands baseline delta
  fp=$(material_progress_fingerprint "$name" "$wt")
  prev=$(progress_hash_get "$name")
  commands=$(lane_command_count "$name")
  if [ -z "$prev" ] || [ "$fp" != "$prev" ]; then
    progress_hash_set "$name" "$fp"
    progress_count_set "$name" 0
    progress_commands_set "$name" "$commands"
    return 1
  fi
  cnt=$(progress_count_get "$name"); cnt=$((cnt + 1))
  baseline=$(progress_commands_get "$name")
  delta=$((commands - baseline))
  progress_count_set "$name" "$cnt"
  [ "$cnt" -ge "${POLYLANE_PROGRESS_CHECKS:-12}" ] &&
    [ "$delta" -ge "${POLYLANE_PROGRESS_MIN_COMMANDS:-20}" ]
}

replan_churning_lane() {
  local name="$1" wt="$2" idx="$3" count max cur next effort lower src repair dir
  count=$(progress_replans_get "$name"); count=$((count + 1))
  max="${POLYLANE_PROGRESS_REPLANS:-2}"
  if [ "$count" -gt "$max" ]; then
    echo "usage-guard: lane '$name' made no source/evidence progress after $max narrowed replans — user input required; stopping usage burn." >&2
    notify_event approval "lane '$name' exhausted no-progress replans — inspect evidence and choose a new core approach"
    NEEDS_DECISION_LANES="${NEEDS_DECISION_LANES:+$NEEDS_DECISION_LANES }$name"
    FAILED_LANES="${FAILED_LANES:+$FAILED_LANES }$name"
    mkdir -p "$REPO_ROOT/.polylane" 2>/dev/null || true
    printf '%s\n' "$name" >> "$REPO_ROOT/.polylane/needs-user"
    return 1
  fi
  progress_replans_set "$name" "$count"
  cur=$(lane_model_get "$name")
  if next=$(next_fallback_model "$cur"); then lane_model_set "$name" "$next"; else next="$cur"; fi
  effort=$(lane_effort_get "$name"); lower=$(next_lower_effort "$effort"); lane_effort_set "$name" "$lower"
  dir="$REPO_ROOT/.polylane/lanes"; mkdir -p "$dir"
  src=$(lane_prompt_get "$name")
  repair="$dir/$name.progress-replan-$count.txt"
  {
    cat "$src" 2>/dev/null
    printf '\n\n── USAGE-GUARD REPLAN %s ─────────────────────────────────────\n' "$count"
    printf 'Your transcript executed many commands without a source-state change.\n'
    printf 'Stop broad auditing. Produce the smallest concrete change/evidence that advances GOAL.\n'
    printf 'DELEGATION: forbidden; do not spawn subagents, collaboration agents, or fan-out.\n'
    printf 'CHECK-CACHE: use %s/polylane-check.sh %s/.polylane/check-cache/%s -- <command>;\n' "$SCRIPT_DIR" "$REPO_ROOT" "$name"
    printf 'never rerun an unchanged expensive pass or failure. Read its saved log instead.\n'
    printf 'Work only from current evidence, make one narrow plan, execute it, then finish DONE.\n'
  } > "$repair"
  lane_prompt_set "$name" "$repair"
  echo "usage-guard: lane '$name' source/evidence unchanged under command churn — replan $count/$max, model=$next effort=$lower"
  notify_event stall "lane '$name' command churn — narrowed replan $count/$max on $next/$lower"
  progress_hash_set "$name" ""; progress_count_set "$name" 0
  respawn_lane "$idx" "$name" "$wt"
}

# health_check SPEC... : retry any errored, not-yet-done lane; mark failed past cap.
health_check() {
  local specs=("$@") s name wt idx max n why
  max="${POLYLANE_MAX_RETRIES:-3}"
  resolve_stalls "${specs[@]}"   # usage-limit paywalls first (fallback/credits/wait)
  for s in "${specs[@]}"; do
    name="${s%%:*}"; wt="${s#*:}"
    lane_done "$wt" "$name" && continue
    lane_failed "$name" && continue
    lane_stalled "$name" && continue   # still mid-resolution this cycle
    idx=$(pane_index_for "$name")
    # respawn a lane that is showing a transient error, has died back to a shell
    # (claude exited without DONE — amnesia), or is WEDGED (alive but frozen).
    if material_progress_stalled "$name" "$wt"; then
      replan_churning_lane "$name" "$wt" "$idx" || true
      continue
    elif pane_retryable_error "$idx"; then why="a transient error after agent exit"
    elif pane_dead "$idx"; then why="a dead pane ($(agent_selected) exited)"
    elif pane_wedged "$name" "$idx"; then why="a wedged pane (no output for $(( ${POLYLANE_WEDGE_CHECKS:-4} * ${POLYLANE_HEALTH_INTERVAL:-15} ))s)"
    else continue
    fi
    n=$(retry_get "$name"); n=$((n + 1)); retry_set "$name" "$n"
    if [ "$n" -le "$max" ]; then
      echo "health: lane '$name' — $why — retry $n/$max, respawning pane $idx"
      respawn_lane "$idx" "$name" "$wt"
    else
      # transient retries exhausted — a plain respawn keeps failing the same way.
      # Try ONE Reflexion repair (reflect on the transcript, take a new approach)
      # before giving up; only mark failed once repairs are also exhausted.
      local rmax rc
      rmax="${POLYLANE_MAX_REPAIRS:-1}"; rc=$(repairs_get "$name")
      if [ "$rc" -lt "$rmax" ] && reflect_and_repair "$name" "$wt" "$idx"; then
        :   # repaired — fresh budget, new approach
      else
        echo "health: lane '$name' failed after $max retries + $rc repair(s) — marking failed." >&2
        FAILED_LANES="${FAILED_LANES:+$FAILED_LANES }$name"
      fi
    fi
  done
}

# verify_seeds : shortly after launch, re-seed any pane whose seed was lost to the
# send-keys race (keys typed before the pane's shell was ready → command vanished,
# pane sits at a bare shell). Without this the first health check catches it, but
# only after POLYLANE_HEALTH_INTERVAL (15s) of dead air. Free — not a retry.
verify_seeds() {
  [ "${DRY_RUN:-0}" = "1" ] && return 0
  local wait="${POLYLANE_SEED_VERIFY:-2}" i name
  sleep "$wait"
  for i in "${!LANE_NAMES[@]}"; do
    lane_resumed "$i" && continue
    name="${LANE_NAMES[$i]}"
    if pane_dead "${LANE_PANE_IDX[$i]}"; then
      echo "launch: lane '$name' seed did not take (pane at a shell) — re-seeding"
      respawn_lane "${LANE_PANE_IDX[$i]}" "$name" "${LANE_WORKTREES[$i]}"
    fi
  done
}

# fmt_elapsed SECS : "12m03s" (minutes never truncated to hours — poll spans
# are short enough that raw minutes read fine).
fmt_elapsed() { printf '%dm%02ds' $(( $1 / 60 )) $(( $1 % 60 )); }

# poll_done SPEC... : each SPEC is "name:worktree". Returns 0 when all DONE, or 3
# if the only remaining lanes have failed past the retry cap (halt, don't hang).
# Every poll prints one status line per lane: name · state · elapsed.
poll_done() {
  local specs=("$@") interval="${POLYLANE_POLL_INTERVAL:-2}"
  local hinterval="${POLYLANE_HEALTH_INTERVAL:-15}" since=0 t0 elapsed
  t0=$(date +%s)
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would poll for DONE (auto-retry errored lanes every ${hinterval}s): ${specs[*]}"
    return 0
  fi
  while :; do
    local done=0 settled=0 total=${#specs[@]} s name wt state
    stall_check "${specs[@]}"      # every poll: stalls need timely human attention
    startup_check "${specs[@]}"    # every poll: clear trust/onboarding dialogs (fast unstick)
    approval_check "${specs[@]}"   # every poll: auto-approve safe prompts, escalate critical
    if ! disk_guard; then       # low disk mid-run: halt (resumable), don't crash
      notify_event halt "disk below ${POLYLANE_MIN_DISK_GB:-2}GB — halted; free space, then --resume"
      return 3
    fi
    elapsed=$(fmt_elapsed $(( $(date +%s) - t0 )))
    for s in "${specs[@]}"; do
      name="${s%%:*}"; wt="${s#*:}"
      if lane_done "$wt" "$name"; then
        state="DONE"; done=$((done + 1)); settled=$((settled + 1))
      elif lane_failed "$name"; then
        state="failed"; settled=$((settled + 1))
      elif lane_stalled "$name"; then
        state="stalled"   # waits — not settled: a human can un-stall it
      else
        state="working"
      fi
      echo "  $name · $state · $elapsed"
    done
    echo "poll: $done/$total DONE${FAILED_LANES:+ (failed: $FAILED_LANES)}"
    [ "$done" -eq "$total" ] && return 0
    [ "$settled" -eq "$total" ] && return 3
    if [ "${SESSION_STARTED:-0}" = "1" ] && ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
      echo "SESSION-LOST: owned tmux session '$TMUX_SESSION' vanished with unfinished work; supervisor must resume with --resume." >&2
      return 75
    fi
    sleep "$interval"; since=$((since + interval))
    if [ "$since" -ge "$hinterval" ]; then health_check "${specs[@]}"; since=0; fi
  done
}

# ---------------------------------------------------------------------------
# integrator
# ---------------------------------------------------------------------------

run_integrator() {
  graph_authority_require integrator "launch integrator '$INT_NAME'" || return 1
  assert_prompt "$INT_PROMPT" "$INT_NAME"
  add_worktree "$INT_WORKTREE" "$INT_BRANCH"
  # a fresh integrator worktree must NOT inherit a prior run's committed DONE/verdict
  clear_stale_markers "$INT_WORKTREE" "$INT_NAME"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would clear any stale $INT_WORKTREE/docs/verify-integration.md"
  else
    rm -f "$INT_WORKTREE/docs/verify-integration.md"   # gate must read THIS run's verdict
  fi
  local pc
  echo "lane $INT_NAME: model=$INT_MODEL effort=${INT_EFFORT:-(default)}"
  pc=$(pane_cmd "$INT_WORKTREE" "$INT_MODEL" "$INT_PROMPT" "${INT_EFFORT:-}")
  # new_pane also handles the all-lanes-resumed case (no session yet).
  new_pane "$INT_NAME"
  INT_PANE_IDX="$NEW_PANE_IDX"
  seed_pane "$NEW_PANE_IDX" "$pc"
  pipe_pane_log "$NEW_PANE_IDX" "$INT_NAME"
}

adopt_integrator() {
  local idx
  [ "${RESUME:-0}" = "1" ] || return 1
  [ "${SESSION_STARTED:-0}" = "1" ] || return 1
  if idx=$(pane_for_worktree "$INT_WORKTREE"); then
    INT_PANE_IDX="$idx"
    echo "resume: adopted live tmux pane $idx for integrator '$INT_NAME'"
    pipe_pane_log "$idx" "$INT_NAME"
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# merge gate
# ---------------------------------------------------------------------------

# parse_verdict FILE : GO | EXTERNAL-EVIDENCE-OPEN | NO-GO | UNKNOWN.
parse_verdict() {
  local f="$1" line
  [ -f "$f" ] || { echo "UNKNOWN"; return; }
  # The ONLY trusted verdict is an explicit machine sentinel on its OWN line —
  # immune to prose that merely mentions "GO"/"NO-GO" and to stray fixture files.
  # FAIL-SAFE: if ANY sentinel line says NO-GO, the verdict is NO-GO regardless of
  # order (a GO written after a NO-GO must never override it). Only an all-GO set of
  # sentinels is a GO.
  # a mechanical seam dangler (polylane-seams.sh appended it to the evidence) is an
  # auto-NO-GO regardless of what the LLM wrote — non-wiring the prose verdict missed.
  if grep -q '^SEAM-DANGLING:' "$f" 2>/dev/null; then echo "NO-GO"; return; fi
  local sentinels pat
  # nonce mode: only a sentinel tagged run=THIS-RUN counts (a committed stale GO from
  # an earlier run reads as UNKNOWN). Absent RUN_ID -> legacy exact-match (backward-compat).
  if [ -n "${RUN_ID:-}" ]; then
    pat='^[[:space:]]*POLYLANE-VERDICT:[[:space:]]*(GO|EXTERNAL-EVIDENCE-OPEN|NO-GO)[[:space:]]+run='"$RUN_ID"'[[:space:]]*$'
  else
    pat='^[[:space:]]*POLYLANE-VERDICT:[[:space:]]*(GO|EXTERNAL-EVIDENCE-OPEN|NO-GO)[[:space:]]*$'
  fi
  sentinels=$(grep -E "$pat" "$f")
  if [ -n "$sentinels" ]; then
    printf '%s' "$sentinels" | grep -q 'NO-GO' && { echo "NO-GO"; return; }
    printf '%s' "$sentinels" | grep -q 'EXTERNAL-EVIDENCE-OPEN' &&
      { echo "EXTERNAL-EVIDENCE-OPEN"; return; }
    echo "GO"; return
  fi
  # NO sentinel = the integrator did not complete its contract (crash, stall, wrong
  # format). Do NOT guess a verdict from prose — that risks a FALSE GO merging
  # unverified work. UNKNOWN, which merge_gate treats as a non-GO (nothing merged).
  echo "UNKNOWN"
}

# parse_repairability FILE : YES | NO. NO is trusted only from an exact
# nonce-bound marker on its own line. It means the integrator proved that another
# model repair wave cannot change the result (for example, the host blocks the
# required compiler before source execution). Missing/malformed markers default
# to YES so crashes and ordinary NO-GOs still receive autonomous repair.
parse_repairability() {
  local f="$1" pat
  [ -f "$f" ] || { echo "YES"; return; }
  if [ -n "${RUN_ID:-}" ]; then
    pat='^[[:space:]]*POLYLANE-REPAIRABLE:[[:space:]]*NO[[:space:]]+run='"$RUN_ID"'[[:space:]]*$'
  else
    pat='^[[:space:]]*POLYLANE-REPAIRABLE:[[:space:]]*NO[[:space:]]*$'
  fi
  grep -Eq "$pat" "$f" 2>/dev/null && echo "NO" || echo "YES"
}

# contract_acceptance_gate : run only this cycle's focused graders in the
# integrator worktree. If these are the last autonomous subgoals, also run the
# terminal suite once before promotion.
report_acceptance_failures() {
  printf 'ACCEPTANCE-GATE: failed frozen checks:\n' >&2
  jq -r '(.accept // [])[] | select(.status=="fail") | "\(.sid): \(.cmd) [fail]"' \
    "$STATE_FILE" >&2 || true
}

contract_acceptance_gate() {
  local verdict="${1:-GO}" targets outside terminal_targets
  [ "${ORCHESTRATION_CONTRACT:-0}" -ge 2 ] 2>/dev/null || return 0
  targets=$(jq -r '.target_subgoals | join(",")' "$MANIFEST")
  (
    cd "$INT_WORKTREE"
    export REPO="$PWD" REPO_ROOT="$PWD"
    "$SCRIPT_DIR/polylane-memory.sh" "$STATE_FILE" check-accept \
      --cycle "$CYCLE" --targets "$targets" --focused
  ) || { report_acceptance_failures; return 1; }
  outside=$(jq -r --arg targets ",$targets," '
    [.milestones[].subgoals[]
      | select(.status=="open" or .status=="doing")
      | .id as $sid
      | select(($targets | contains("," + $sid + ",")) | not)]
    | length
  ' "$STATE_FILE")
  if [ "$outside" = "0" ]; then
    if [ "$verdict" = "EXTERNAL-EVIDENCE-OPEN" ]; then
      # External terminal checks require a human, physical device, independent
      # witness, or distribution authority. Re-running them locally cannot turn
      # them green and previously made EXTERNAL-EVIDENCE-OPEN impossible: the
      # command failure returned before the external-status allowance below.
      # Refresh only terminal checks whose subgoals are still autonomous.
      terminal_targets=$(jq -r '
        ([.milestones[].subgoals[] | select(.status=="external") | .id]) as $external
        | [(.accept // [])[]
            | select((.tier // "focused")=="terminal")
            | .sid
            | select(. as $sid | any($external[]; .==$sid) | not)]
        | unique
        | join(",")
      ' "$STATE_FILE")
      if [ -n "$terminal_targets" ]; then
        (
          cd "$INT_WORKTREE"
          export REPO="$PWD" REPO_ROOT="$PWD"
          "$SCRIPT_DIR/polylane-memory.sh" "$STATE_FILE" check-accept \
            --cycle "$CYCLE" --targets "$terminal_targets" --only-terminal
        ) || { report_acceptance_failures; return 1; }
      fi
      jq -e '
        ([.milestones[].subgoals[] | select(.status=="external") | .id]) as $external
        | all((.accept // [])[]
            | select((.tier // "focused")=="terminal");
            .status=="pass" or (.sid as $sid | any($external[]; .==$sid)))
      ' "$STATE_FILE" >/dev/null || return 1
    else
      (
        cd "$INT_WORKTREE"
        export REPO="$PWD" REPO_ROOT="$PWD"
        "$SCRIPT_DIR/polylane-memory.sh" "$STATE_FILE" check-accept \
          --cycle "$CYCLE" --only-terminal
      ) || { report_acceptance_failures; return 1; }
      jq -e 'all((.accept // [])[]; .status=="pass")' "$STATE_FILE" >/dev/null || return 1
    fi
  fi
}

# merge_gate : returns 0 for verified engineering outcomes. External evidence is a
# routing state, not a reason to discard verified code or end the autonomous loop.
merge_gate() {
  local f="$INT_WORKTREE/docs/verify-integration.md" v
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would read integrator verdict from $f (proceed only on GO)"
    VERDICT_RESULT="GO"
    return 0
  fi
  v=$(parse_verdict "$f")
  VERDICT_REPAIRABLE=$(parse_repairability "$f")
  if [ "$v" = "GO" ] || [ "$v" = "EXTERNAL-EVIDENCE-OPEN" ]; then
    if ! contract_acceptance_gate "$v"; then
      printf '\nACCEPTANCE-GATE: frozen focused/terminal checks failed; repair autonomously.\n' >> "$f"
      v="NO-GO"
      VERDICT_REPAIRABLE="YES"
    fi
  fi
  VERDICT_RESULT="$v"
  case "$v" in
    GO|EXTERNAL-EVIDENCE-OPEN)
      echo "Integrator verdict: $v — engineering gate passed; proceeding."
      notify_event go "integrator verdict $v — merging + cleanup"
      return 0
      ;;
    *)
      echo "Integrator verdict: $v — engineering gate did not pass. Nothing deleted." >&2
      [ -f "$f" ] && { echo "--- $f ---" >&2; cat "$f" >&2; }
      notify_event no-go "integrator verdict $v — nothing merged, worktrees intact"
      return 1
      ;;
  esac
}

# build_integrator_repair_prompt SRC ATTEMPT VERDICT EVIDENCE -> stdout.
# A council/integrator NO-GO is feedback for the next repair wave, not a cycle
# boundary. The original contract stays locked; only the failed evidence is added.
build_integrator_repair_prompt() {
  local src="$1" attempt="$2" verdict="$3" evidence="$4"
  local transcript="${REPO_ROOT:-.}/docs/lane-logs/${INT_NAME:-integrator}.log"
  cat "$src" 2>/dev/null
  printf '\n\n── INTEGRATION REPAIR %s (verdict was %s) ─────────────────────\n' "$attempt" "$verdict"
  printf 'The previous integration verdict is diagnostic feedback, NOT permission to stop.\n'
  printf 'Read %s, `%s`, and the lane verification files.\n' "$evidence" "$transcript"
  printf 'Fix every autonomous issue the preserved evidence names,\n'
  printf 're-run the focused failing checks first, then the full terminal gate once.\n'
  printf 'DELEGATION: forbidden. Do not spawn subagents, collaboration agents, or fan-out.\n'
  printf 'CHECK-CACHE: never rerun an expensive command on an unchanged source fingerprint;\n'
  printf 'route it through polylane-check.sh and reuse its recorded result.\n'
  printf 'Do not weaken frozen acceptance checks, scope, or product decisions. Write a fresh\n'
  printf 'docs/verify-integration.md and finish with exactly one run-tagged POLYLANE-VERDICT.\n'
  printf 'Use EXTERNAL-EVIDENCE-OPEN only when engineering is verified and the remaining\n'
  printf 'proof physically cannot be produced by the system; otherwise GO or NO-GO.\n'
}

# repair_integrator_verdict ATTEMPT : preserve the failed verdict as evidence,
# clear only terminal markers, then immediately respawn the same tmux Codex lane.
repair_integrator_verdict() {
  local attempt="$1" verdict="${VERDICT_RESULT:-UNKNOWN}" evidence archive prompt cmd
  evidence="$INT_WORKTREE/docs/verify-integration.md"
  archive="$INT_WORKTREE/docs/verify-integration-attempt-$attempt.md"
  prompt="$REPO_ROOT/.polylane/lanes/$INT_NAME.gate-repair-$attempt.txt"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would preserve verdict evidence and respawn integrator repair $attempt"
    return 0
  fi
  mkdir -p "$(dirname "$prompt")" "$INT_WORKTREE/docs"
  [ -f "$evidence" ] && cp "$evidence" "$archive"
  build_integrator_repair_prompt "$INT_PROMPT" "$attempt" "$verdict" \
    "docs/$(basename "$archive")" > "$prompt" || return 1
  checkpoint_lane "$INT_WORKTREE" "$INT_NAME"
  rm -f "$INT_WORKTREE/docs/status-$INT_NAME.md" "$evidence"
  INT_PROMPT="$prompt"
  retry_set "$INT_NAME" 0
  wedge_hash_set "$INT_NAME" ""; wedge_cnt_set "$INT_NAME" 0
  refresh_manifest_runtime_settings
  cmd=$(pane_cmd_for "$INT_NAME")
  echo "gate-repair: integrator verdict $verdict — autonomous repair $attempt"
  notify_event stall "integrator $verdict — repair wave $attempt"
  if ! run tmux respawn-pane -k -t "$TMUX_SESSION:0.$INT_PANE_IDX" "$cmd" 2>/dev/null; then
    run tmux send-keys -t "$TMUX_SESSION:0.$INT_PANE_IDX" C-c 2>/dev/null || true
    run tmux send-keys -t "$TMUX_SESSION:0.$INT_PANE_IDX" -l "$cmd" 2>/dev/null || true
    run tmux send-keys -t "$TMUX_SESSION:0.$INT_PANE_IDX" C-m 2>/dev/null || true
  fi
  repipe_pane_log "$INT_PANE_IDX" "$INT_NAME"
}

# gate_with_repairs : exhaust autonomous integration repair before exposing a
# terminal NO-GO. No report is written between attempts, so the supervisor cannot
# mistake council feedback for legitimate completion.
gate_with_repairs() {
  local attempt=0 max="${POLYLANE_INTEGRATOR_REPAIRS:-3}"
  while :; do
    graph_authority_require verifier "run verifier gate attempt $attempt" || return 1
    if merge_gate; then
      return 0
    fi
    graph_authority_record_ready_node verifier failed "$attempt" verifier-failed || return 1
    if [ "${VERDICT_REPAIRABLE:-YES}" = "NO" ]; then
      echo "Integrator proved this gate is not autonomously repairable on the current host; skipping model repair waves." >&2
      return 1
    fi
    [ "$attempt" -lt "$max" ] || {
      echo "Integrator repair budget exhausted ($max); verified promotion remains blocked." >&2
      return 1
    }
    attempt=$((attempt + 1))
    graph_authority_require repair "route verifier repair $attempt" || return 1
    repair_integrator_verdict "$attempt" || return 1
    if ! poll_done "$INT_NAME:$INT_WORKTREE"; then
      echo "Integrator repair $attempt failed before producing a verdict." >&2
      return 1
    fi
    graph_authority_record_ready_node repair succeeded "$attempt" verifier-repair || return 1
    capture_stats
  done
}

# finalize_cycle_state : promotion makes the verified target durable. Stamp its
# goal-tree state and regenerate progress immediately so the next cycle never
# starts from stale conversation memory.
finalize_cycle_state() {
  local sid targets route_text
  [ "${ORCHESTRATION_CONTRACT:-0}" -ge 2 ] 2>/dev/null || return 0
  # DRY-RUN MUST NOT MUTATE DURABLE STATE: the stubbed gate returns GO, so without
  # this guard a preview stamps the target subgoals done in state_file — and every
  # later REAL launch then dies at "target must be open" (bit a real marathon launch).
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would stamp target subgoals done + regenerate progress/route"
    return 0
  fi
  targets=$(jq -r '.target_subgoals[]' "$MANIFEST")
  for sid in $targets; do
    "$SCRIPT_DIR/polylane-memory.sh" "$STATE_FILE" set-status "$sid" "done" \
      "integrator ${VERDICT_RESULT:-GO}; promoted cycle $CYCLE" "$CYCLE"
  done
  "$SCRIPT_DIR/polylane-cycle.sh" progress "$STATE_FILE" "$CYCLE" >/dev/null
  route_text=$("$SCRIPT_DIR/polylane-cycle.sh" route "$STATE_FILE" 2>&1 || true)
  echo "CYCLE-ROUTE: $route_text"
}

# assert_no_conflict WORKTREE : abort (leaving worktrees intact) on unmerged paths.
assert_no_conflict() {
  local wt="$1" br
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would verify no merge conflict in $wt"
    return 0
  fi
  if git -C "$wt" ls-files --unmerged 2>/dev/null | grep -q .; then
    br=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    echo "ABORT: unresolved merge conflict in $wt (branch $br)." >&2
    echo "  Worktrees left intact; nothing deleted. Resolve, then re-run." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# promote — on a verified engineering verdict, advance base to the integrator branch
# ---------------------------------------------------------------------------

# promote_to_main : the integrator merges the lanes into its OWN branch and
# verifies THERE — it never touches the base branch. So a NO-GO can't pollute
# the base. On GO the runner fast-forwards the base ($BASE) to the integrator
# branch, which already contains base + every lane + the integrator's evidence.
# A fast-forward keeps history linear; if the base moved meanwhile, fall back to
# a real merge. Runs on the base worktree ($REPO_ROOT), which is on $BASE.
promote_to_main() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would fast-forward $BASE to $INT_BRANCH after a verified engineering verdict"
    return 0
  fi
  local cur
  cur=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
  if [ "$cur" != "$BASE" ]; then
    echo "promote: base worktree is on '$cur', not '$BASE' — merging $INT_BRANCH into '$cur'" >&2
  fi
  if run git -C "$REPO_ROOT" merge --ff-only "$INT_BRANCH"; then
    echo "promote: $BASE fast-forwarded to $INT_BRANCH (verified)"
  else
    echo "promote: $cur diverged from $INT_BRANCH — non-ff merge" >&2
    run git -C "$REPO_ROOT" merge --no-ff -m "polylane: integrate verified lanes" "$INT_BRANCH" || {
      echo "promote: merge FAILED — base left as-is, nothing deleted. Resolve manually." >&2
      return 1
    }
  fi
}

# ---------------------------------------------------------------------------
# cleanup — one confirm, then remove worktrees + merged branches + scratch
# ---------------------------------------------------------------------------

cleanup() {
  local n i
  n=$(( ${#LANE_NAMES[@]} + 1 ))  # lanes + integrator
  if [ "${YES:-0}" != "1" ] && [ "${DRY_RUN:-0}" != "1" ]; then
    printf 'Delete %d worktrees + branches + .polylane scratch? [y/N] ' "$n"
    local ans; read -r ans
    case "$ans" in
      y|Y|yes|YES) ;;
      *) echo "Aborted. Nothing deleted."; exit 0 ;;
    esac
  fi

  # PRESERVE the integrator's evidence at the repo root before its worktree is
  # gone. If the integrator merged its branch the file is already on main; if it
  # only wrote-but-didn't-commit (seen in real runs), this copy is the only save.
  if [ "${DRY_RUN:-0}" != "1" ]; then
    local ivf="$INT_WORKTREE/docs/verify-integration.md"
    [ -f "$ivf" ] && { mkdir -p "$REPO_ROOT/docs"; cp "$ivf" "$REPO_ROOT/docs/verify-integration.md" 2>/dev/null || true; }
  else
    echo "+ (dry-run) would copy integrator verify-integration.md to repo docs/ before removal"
  fi

  # The tmux session is runtime scratch too. Kill it before removing worktrees so
  # no completed Codex process/shell keeps a deleted worktree as its cwd, and so a
  # finished pipeline never leaves an apparently active watch command behind.
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would kill tmux session $TMUX_SESSION"
  elif tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || {
      echo "cleanup: could not terminate tmux session $TMUX_SESSION" >&2
      return 1
    }
  fi

  # remove worktrees (never a raw rm on a worktree dir)
  for i in "${!LANE_NAMES[@]}"; do
    run git worktree remove --force "${LANE_WORKTREES[$i]}"
  done
  run git worktree remove --force "$INT_WORKTREE"

  # delete only merged branches — `git branch -d` refuses unmerged (never -D)
  for i in "${!LANE_NAMES[@]}"; do
    run git branch -d "${LANE_BRANCHES[$i]}"
  done
  run git branch -d "$INT_BRANCH"

  # remove scratch — .polylane and the DONE status files only
  safe_rm "$REPO_ROOT/.polylane"
  # .polylane/ is scratch EXCEPT git-tracked files (e.g. SCHEMA.md); restore those
  # from HEAD so cleanup never deletes committed content.
  run git -C "$REPO_ROOT" checkout -q -- .polylane || true
  for i in "${!LANE_NAMES[@]}"; do
    run rm -f "$REPO_ROOT/docs/status-${LANE_NAMES[$i]}.md"
  done
  run rm -f "$REPO_ROOT/docs/status-$INT_NAME.md"

  echo "Cleanup complete. Kept: docs/verify-*.md, docs/parallel-status.md, docs/polylane-report.md"
}

# ---------------------------------------------------------------------------
# report — plain-terms rollup the chat surfaces after the run
# ---------------------------------------------------------------------------

# capture_stats : best-effort grab Claude's "Goal achieved" line or Codex exec's
# JSON turn.completed usage while panes/logs still exist.
capture_stats() {
  LANE_STATS=()
  [ "${DRY_RUN:-0}" = "1" ] && return 0
  local i idx line tok log
  for i in "${!LANE_NAMES[@]}"; do
    if lane_resumed "$i"; then
      LANE_STATS+=("DONE (resumed — prior run)")
      continue
    fi
    idx="${LANE_PANE_IDX[$i]:--1}"
    line=""
    if [ "$idx" -ge 0 ] 2>/dev/null; then
      line=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p 2>/dev/null \
             | grep -oE 'Goal achieved \([^)]*\)' | tail -1 || true)
    fi
    if [ -z "$line" ]; then
      log="$REPO_ROOT/docs/lane-logs/${LANE_NAMES[$i]}.log"
      tok=$(grep '"type":"turn.completed"' "$log" 2>/dev/null | tail -1 |
        jq -r '(.usage.input_tokens // 0) + (.usage.output_tokens // 0)' 2>/dev/null || true)
      [ -n "$tok" ] && [ "$tok" != "0" ] && line="Codex completed ($tok tokens)"
    fi
    LANE_STATS+=("${line:-completed}")
  done
  return 0
}

# parse_tokens STAT : token count (integer) from a "Goal achieved (…)" stats
# line — accepts "32.5k tokens", "1.2M tokens", "4567 tokens". Empty if absent.
parse_tokens() {
  printf '%s' "$1" | awk '
    match(tolower($0), /[0-9]+(\.[0-9]+)?[km]? *tokens/) {
      s = substr(tolower($0), RSTART, RLENGTH)
      sub(/ *tokens/, "", s)
      mult = 1
      if (s ~ /k$/) { mult = 1000;    sub(/k$/, "", s) }
      else if (s ~ /m$/) { mult = 1000000; sub(/m$/, "", s) }
      printf "%d", s * mult
      exit
    }'
}

# model_out_price MODEL : $ per 1M OUTPUT tokens. Price table cached from
# references/model-selection.md (confirmed 2026-07): Fable 5 $10/$50,
# Opus 4.8 $5/$25, Sonnet 5 $3/$15, Haiku 4.5 $1/$5 (in/out per 1M).
# Estimates use the OUTPUT rate — builder panes report a single token count
# and lanes are output-dominated, so this is a rough upper-band figure.
# Unknown model -> empty (reported as "?").
model_out_price() {
  case "$1" in
    claude-fable-5*)   echo 50 ;;
    claude-opus-4-8*)  echo 25 ;;
    claude-sonnet-5*)  echo 15 ;;
    claude-haiku-4-5*) echo 5 ;;
    *)                 echo "" ;;
  esac
}

# est_cost TOKENS PRICE_PER_MTOK : dollars, two decimals (awk — bash has no floats).
est_cost() { LC_ALL=C awk -v t="$1" -v p="$2" 'BEGIN{printf "%.2f", t * p / 1000000}'; }

# write_report VERDICT : write docs/polylane-report.md — a plain-language digest of
# what happened + suggested next steps. Written on BOTH GO and NO-GO.
write_report() {
  local verdict="$1" f="$REPO_ROOT/docs/polylane-report.md" i when steps subdone=0 subtotal=0
  # dry-run must never touch the tree — print the intent, write nothing.
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf '+ would write run report (%s) to %s\n' "$verdict" "$f"
    return 0
  fi
  when=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || echo "?")
  mkdir -p "$REPO_ROOT/docs" 2>/dev/null || true
  if [ -n "${STATE_FILE:-}" ] && [ -f "$STATE_FILE" ]; then
    subdone=$(jq '[.milestones[].subgoals[] | select(.status=="done")] | length' "$STATE_FILE" 2>/dev/null || echo 0)
    subtotal=$(jq '[.milestones[].subgoals[]] | length' "$STATE_FILE" 2>/dev/null || echo 0)
  fi

  # next steps: surface anything the lanes flagged as open (kept files only).
  steps=$(grep -hiE 'NEEDS DECISION|unverified|half-satisf|follow-up|not (yet|tested)|TODO|manual (verif|test)|out of scope|NO-GO' \
            "$REPO_ROOT"/docs/verify-*.md "$REPO_ROOT/docs/parallel-status.md" 2>/dev/null \
          | sed 's/^[[:space:]]*//; s/^[-*#> ]*//' | grep -v '^$' | sort -u | head -8 || true)

  {
    echo "# polylane run report"
    echo
    echo "**Outcome:** ${verdict}  ·  **When:** ${when}  ·  **Base branch:** ${BASE}  ·  **Lanes:** ${#LANE_NAMES[@]}"
    echo
    echo "## Lanes"
    echo
    echo "| Lane | Model | Branch | Result | Tokens | Est. \$ |"
    echo "|---|---|---|---|---|---|"
    local _total="0.00" _tokens_total=0 _tok _price _cost
    for i in "${!LANE_NAMES[@]}"; do
      local _r="${LANE_STATS[$i]:-completed}"
      lane_failed "${LANE_NAMES[$i]}" && _r="FAILED — errored after retries"
      lane_stalled "${LANE_NAMES[$i]}" && _r="STALLED — usage limit (human decision needed)"
      _tok=$(parse_tokens "$_r"); _price=$(model_out_price "${LANE_MODELS[$i]}")
      _cost="?"
      if [ -n "$_tok" ] && [ -n "$_price" ]; then
        _cost=$(est_cost "$_tok" "$_price")
        _total=$(LC_ALL=C awk -v a="$_total" -v b="$_cost" 'BEGIN{printf "%.2f", a + b}')
        _cost="\$$_cost"
      fi
      [ -n "$_tok" ] && _tokens_total=$(( _tokens_total + _tok ))
      printf '| %s | %s | %s | %s | %s | %s |\n' \
        "${LANE_NAMES[$i]}" "${LANE_MODELS[$i]}" "${LANE_BRANCHES[$i]}" "$_r" \
        "${_tok:-?}" "$_cost"
    done
    echo
    echo "**Estimated total: \$${_total}** — rough, output-rate pricing from \`references/model-selection.md\`; lanes without a token count are excluded."
    # durable spend ledger (best-effort; never fails the report).
    if [ -x "$SCRIPT_DIR/polylane-ledger.sh" ]; then
      "$SCRIPT_DIR/polylane-ledger.sh" record --file "$REPO_ROOT/docs/polylane/spend-ledger.jsonl" \
        --cycle "${CYCLE:-${POLYLANE_CYCLE:-0}}" --verdict "$verdict" --tokens "$_tokens_total" --cost "${_total:-0}" \
        --subdone "$subdone" --subtotal "$subtotal" --nogo "$([ "$verdict" = GO ] || [ "$verdict" = EXTERNAL-EVIDENCE-OPEN ]; echo $?)" \
        --lanes "${#LANE_NAMES[@]}" --wall "${SECONDS:-0}" >/dev/null 2>&1 || true
    fi
    echo
    echo "## Integrator verdict"
    echo
    if [ "$verdict" = "GO" ] || [ "$verdict" = "EXTERNAL-EVIDENCE-OPEN" ]; then
      if [ "$verdict" = "GO" ]; then
        echo "**GO** — all lanes merged into \`${BASE}\`; worktrees, branches, and scratch removed. Kept the \`docs/verify-*.md\` evidence."
      else
        echo "**EXTERNAL-EVIDENCE-OPEN** — verified engineering work merged into \`${BASE}\`; worktrees, branches, and scratch removed."
        echo "Only physical/manual evidence remains open; continue routing any other autonomous subgoals."
      fi
    else
      echo "**${verdict}** — integrator withheld GO. Nothing merged, nothing deleted; the lane worktrees are left intact so you can fix and re-run. See \`docs/verify-integration.md\`."
    fi
    echo
    echo "## Recent commits on ${BASE}"
    echo '```'
    git -C "$REPO_ROOT" log --oneline -n "$(( ${#LANE_NAMES[@]} + 3 ))" "$BASE" 2>/dev/null || echo "(git log unavailable)"
    echo '```'
    echo
    echo "## Suggested next steps"
    echo
    if [ "$verdict" = "GO" ] || [ "$verdict" = "EXTERNAL-EVIDENCE-OPEN" ]; then
      echo "- Review the merged result, then \`git push\` to back it up."
    elif [ -n "${FAILED_LANES:-}" ]; then
      echo "- Lane(s) errored out and could not recover after retries: **${FAILED_LANES}**."
      echo "  A transient API/network error (e.g. 500 / overloaded) kept firing. Their"
      echo "  worktrees are left intact — re-run the runner to resume just those, or wait"
      echo "  for https://status.claude.com to clear and re-run."
    else
      echo "- Read \`docs/verify-integration.md\` for why the integrator said ${verdict}; fix the flagged lane(s) and re-run."
    fi
    if [ -n "${STALLED_LANES:-}" ]; then
      echo "- Lane(s) stalled on a usage limit: **${STALLED_LANES}** — a paywall/credits"
      echo "  prompt is waiting in their pane. That's a money decision, so nothing was"
      echo "  auto-answered or respawned: attach (\`tmux attach -t ${TMUX_SESSION}\`), answer it,"
      echo "  and the lane resumes."
    fi
    if [ -n "$steps" ]; then
      echo "- Open items the lanes flagged:"
      printf '%s\n' "$steps" | sed 's/^/  - /'
    else
      echo "- No open items were flagged by the lanes."
    fi
  } > "$f" 2>/dev/null || echo "write_report: could not write $f" >&2
  return 0
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
  set -euo pipefail
  parse_args "$@"
  preflight_basic
  load_manifest
  preflight_agent
  apply_overrides   # --intensity / --model remap BEFORE any worktree/pane exists
  preflight_contract
  graph_shadow_init || exit 1
  mark_resumed      # --resume: flag already-DONE lanes BEFORE split/launch
  graph_authority_start || exit 1
  graph_shadow_record_resumes || exit 1

  echo "== split: ${#LANE_NAMES[@]} lane worktrees =="
  split_worktrees
  adopt_existing_session

  # announce the resolved agent — a manifest with no `agent` field silently selected
  # claude before, so a codex run misconfigured this way looked identical to a good one.
  if [ -n "${POLYLANE_AGENT_CMD:-}" ]; then
    echo "== agent: custom POLYLANE_AGENT_CMD =="
  else
    if jq -e '.agent' "$MANIFEST" >/dev/null 2>&1; then
      echo "== agent: $(agent_selected) =="
    else
      echo "== agent: $(agent_selected) (manifest has no 'agent' field — defaulted) =="
    fi
  fi
  echo "== launch: tmux session '$TMUX_SESSION' =="
  launch_panes
  echo "Launched ${LAUNCHED:-0} of ${#LANE_NAMES[@]} lane(s). Watch: $(tmux_watch_command)"
  verify_seeds

  echo "== poll: waiting for builders (auto-retry on transient errors) =="
  if poll_done "${LANE_POLLSPEC[@]}"; then
    graph_authority_record_builders succeeded || exit 1
    echo "All builders DONE."
    notify_event "done" "all ${#LANE_NAMES[@]} lane(s) DONE — starting integrator"
  else
    poll_rc=$?
    [ "$poll_rc" = 75 ] && exit 75
    graph_authority_record_builders failed || exit 1
    echo "Halt: lane(s) failed after retries: ${FAILED_LANES:-?}. Not integrating." >&2
    notify_event halt "lane(s) failed after retries: ${FAILED_LANES:-?}"
    capture_stats
    write_report "HALTED" || true
    echo "Report written: $REPO_ROOT/docs/polylane-report.md"
    exit 1
  fi

  echo "== integrator: $INT_NAME =="
  if [ "${RESUME:-0}" = "1" ] && lane_done "$INT_WORKTREE" "$INT_NAME"; then
    echo "resume: integrator already DONE — skipping launch"
    graph_shadow_record_resume integrator || exit 1
  elif adopt_integrator; then
    :
  else
    run_integrator
  fi
  if poll_done "$INT_NAME:$INT_WORKTREE"; then
    :
  else
    poll_rc=$?
    [ "$poll_rc" = 75 ] && exit 75
    graph_authority_halt_node integrator || exit 1
    echo "Halt: integrator failed after retries. Nothing merged." >&2
    notify_event halt "integrator failed after retries — nothing merged"
    capture_stats
    write_report "HALTED" || true
    echo "Report written: $REPO_ROOT/docs/polylane-report.md"
    exit 1
  fi
  graph_authority_record_ready_node integrator succeeded 0 integrator-done || exit 1

  echo "== gate: integrator verdict =="
  capture_stats                        # panes still alive — grab per-lane tokens/time
  graph_authority_require verifier "run verifier gate" || exit 1
  if gate_with_repairs; then
    assert_no_conflict "$INT_WORKTREE"
    if graph_authority_enabled; then
      graph_authority_record_ready_node verifier succeeded 0 "${VERDICT_RESULT:-GO}" || exit 1
    else
      graph_shadow_record_decision "${VERDICT_RESULT:-GO}" || exit 1
    fi
    graph_authority_require promote "promote verified integration" || exit 1
    echo "== promote: base -> integrator branch (verified outcome) =="
    if ! promote_to_main; then
      write_report "${VERDICT_RESULT:-GO}" || true
      echo "Promote failed — base intact, worktrees kept. See report." >&2
      exit 1
    fi
    graph_authority_record_ready_node promote succeeded 0 "${VERDICT_RESULT:-GO}" || exit 1
    finalize_cycle_state
    graph_authority_require complete "complete verified run" || exit 1
    graph_authority_record_ready_node complete succeeded 0 "${VERDICT_RESULT:-GO}" || exit 1
    echo "== cleanup =="
    cleanup
    if [ "${PUSH:-0}" = "1" ]; then
      echo "== push: current branch =="
      run git -C "$REPO_ROOT" push
    fi
  else
    graph_authority_no_go || exit 1
  fi

  echo "== report =="
  write_report "${VERDICT_RESULT:-UNKNOWN}" || true
  echo "Report written: $REPO_ROOT/docs/polylane-report.md"
  [ "${VERDICT_RESULT:-}" = "GO" ] || [ "${VERDICT_RESULT:-}" = "EXTERNAL-EVIDENCE-OPEN" ] || exit 1
}

# Only run main when executed directly (so tests can source the functions).
if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  main "$@"
fi
