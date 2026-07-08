#!/usr/bin/env bash
#
# polylane-run.sh — parallel-lane build engine (worktrees · tmux · git · claude)
#
# Splits a manifest of lanes into git worktrees, launches one seeded `claude`
# pane per lane in a tmux session, polls each lane's DONE file, auto-runs the
# integrator, gates on the integrator's GO verdict, then deletes scratch after
# one confirmation. See .polylane/SCHEMA.md for the manifest + conventions.
#
# CONTRACTS (frozen — other lanes depend on these):
#   manifest .polylane/run.json:
#     {base, integrator:{name,model,branch,worktree,prompt_file},
#      lanes:[{name,model,branch,worktree,prompt_file,own_globs}]}
#   CLI:  bin/polylane-run.sh <manifest.json> [--dry-run] [--yes]
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
  split worktrees -> launch seeded claude panes (tmux session 'polylane')
  -> poll each <worktree>/docs/status-<name>.md for DONE
  -> run integrator -> gate on GO in <int-worktree>/docs/verify-integration.md
  -> one confirm -> remove worktrees + merged branches + .polylane scratch
     (keeps docs/verify-*.md and docs/parallel-status.md)

DEPS: tmux, claude, jq, git

ENV:
  POLYLANE_POLL_INTERVAL    seconds between DONE-file polls (default 15)
  POLYLANE_HEALTH_INTERVAL  seconds between error-scans that auto-retry a lane
                            stuck on a transient API/network error (default 300 = 5 min)
  POLYLANE_MAX_RETRIES      retries per lane before it is marked failed (default 3)
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

preflight() {
  local missing=() d
  for d in tmux claude jq git; do
    command -v "$d" >/dev/null 2>&1 || missing+=("$d")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "polylane-run: missing required dependencies: ${missing[*]}" >&2
    echo "  tmux = pane management, claude = builders, jq = manifest parse, git = worktrees" >&2
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

load_manifest() {
  BASE=$(jq -r '.base' "$MANIFEST")
  # PROJECT_ROOT = parent of the manifest's own dir (.polylane) = the project root
  # where .polylane/lanes/*.txt actually live. Robust even outside a git checkout.
  local _mdir
  _mdir=$(cd "$(dirname "$MANIFEST")" && pwd)
  PROJECT_ROOT=$(cd "$_mdir/.." && pwd)
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
  LANE_PANE_IDX=(); LANE_RESUMED=()
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
    LANE_PANE_IDX+=(-1); LANE_RESUMED+=(0)
  done

  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  # shellcheck disable=SC2034  # kept for sourcers (tests source this file's functions)
  BASE_WT="$REPO_ROOT"
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
  case "$1" in
    economy)     echo low ;;
    balanced)    echo medium ;;
    performance) echo high ;;
    max)         echo max ;;
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
    INT_MODEL="$mdl"; INT_EFFORT="$eff"
    echo "== intensity '$INTENSITY' -> model=$mdl effort=$eff (all lanes + integrator) =="
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
}

split_worktrees() {
  local i
  for i in "${!LANE_NAMES[@]}"; do
    lane_resumed "$i" && continue
    add_worktree "${LANE_WORKTREES[$i]}" "${LANE_BRANCHES[$i]}"
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
# launch — one seeded claude pane per lane
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
pane_cmd() {
  local wt="$1" model="$2" pf="$3" effort="${4:-}" pfx=""
  local qwt qmodel qpf
  qwt=$(printf '%q' "$wt"); qmodel=$(printf '%q' "$model"); qpf=$(printf '%q' "$pf")
  [ -n "$effort" ] && pfx="POLYLANE_EFFORT=$(printf '%q' "$effort") "
  # shellcheck disable=SC2016  # $(cat …) must expand in the PANE's shell, not here
  printf 'cd %s && %sclaude --model %s "$(cat %s)" || { pbcopy < %s 2>/dev/null || xclip -selection clipboard < %s 2>/dev/null; echo "SEED FAILED — prompt copied to clipboard; paste it into claude"; %sclaude --model %s; }' \
    "$qwt" "$pfx" "$qmodel" "$qpf" "$qpf" "$qpf" "$pfx" "$qmodel"
}

# assert_prompt PATH NAME : fail loudly (before any pane opens) if a lane's prompt
# file is missing or empty — the exact condition that otherwise launches an empty
# claude session that silently sits at a blank input.
assert_prompt() {
  local pf="$1" name="$2"
  if [ ! -f "$pf" ]; then
    echo "polylane-run: prompt file MISSING for lane '$name': $pf" >&2
    echo "  the planner (/polylane) must emit it before launch — nothing to seed." >&2
    exit 1
  fi
  if [ ! -s "$pf" ]; then
    echo "polylane-run: prompt file EMPTY for lane '$name': $pf" >&2
    exit 1
  fi
}

# pipe_pane_log IDX NAME : mirror pane IDX's full transcript to
# docs/lane-logs/<NAME>.log (repo root; dir created; cleanup KEEPS it).
# -o = only open a pipe if none exists, so re-issuing after a respawn is safe.
# The log path is %q-escaped — the pipe command runs through a shell.
pipe_pane_log() {
  local idx="$1" name="$2" dir="$REPO_ROOT/docs/lane-logs" qlog
  run mkdir -p "$dir"
  qlog=$(printf '%q' "$dir/$name.log")
  run tmux pipe-pane -o -t "$TMUX_SESSION:0.$idx" "cat >> $qlog"
}

# new_pane WINDOW_NAME : create the next pane (new-session for the first,
# split-window after) and set NEW_PANE_IDX. Panes are targeted by EXPLICIT
# index ($TMUX_SESSION:0.N) everywhere, so health-check/respawn/stats stay
# correct when --resume skips lanes (positional index != lane order then).
new_pane() {
  if [ "${SESSION_STARTED:-0}" != "1" ]; then
    run tmux new-session -d -s "$TMUX_SESSION" -n "${1:-lanes}"
    SESSION_STARTED=1
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
    assert_prompt "${LANE_PROMPTS[$i]}" "${LANE_NAMES[$i]}"
  done
  for i in "${!LANE_NAMES[@]}"; do
    lane_resumed "$i" && continue
    echo "lane ${LANE_NAMES[$i]}: model=${LANE_MODELS[$i]} effort=${LANE_EFFORTS[$i]:-(default)}"
    pc=$(pane_cmd "${LANE_WORKTREES[$i]}" "${LANE_MODELS[$i]}" "${LANE_PROMPTS[$i]}" "${LANE_EFFORTS[$i]:-}")
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

# lane_done WORKTREE NAME : 0 iff first line of the status file == the DONE line.
lane_done() {
  local wt="$1" name="$2" f="$1/docs/status-$2.md" first
  [ -f "$f" ] || return 1
  IFS= read -r first < "$f" || return 1
  [ "$first" = "STATUS: $name DONE" ]
}

# --- health-check + auto-retry (transient API/network errors) ----------------
# A lane that hits a 500 / overloaded / network error stops WITHOUT writing its
# DONE file, so a plain DONE-poll would hang forever. Every POLYLANE_HEALTH_INTERVAL
# (default 300s = 5 min) we scan each unfinished lane's pane for an error banner and
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
  local name="$1" i
  for i in "${!LANE_NAMES[@]}"; do
    [ "${LANE_NAMES[$i]}" = "$name" ] && {
      pane_cmd "${LANE_WORKTREES[$i]}" "${LANE_MODELS[$i]}" "${LANE_PROMPTS[$i]}" "${LANE_EFFORTS[$i]:-}"
      return
    }
  done
  [ "$name" = "${INT_NAME:-}" ] && pane_cmd "$INT_WORKTREE" "$INT_MODEL" "$INT_PROMPT" "${INT_EFFORT:-}"
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

lane_failed() { case " ${FAILED_LANES:-} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
retry_get()   { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && printf '%s' "${LANE_RETRIES[$i]:-0}" || printf '0'; }
retry_set()   { local i; i=$(pane_index_for "$1"); [ "$i" -ge 0 ] && LANE_RETRIES[i]="$2"; }

# health_check SPEC... : retry any errored, not-yet-done lane; mark failed past cap.
health_check() {
  local specs=("$@") s name wt idx max n cmd
  max="${POLYLANE_MAX_RETRIES:-3}"
  for s in "${specs[@]}"; do
    name="${s%%:*}"; wt="${s#*:}"
    lane_done "$wt" "$name" && continue
    lane_failed "$name" && continue
    idx=$(pane_index_for "$name")
    pane_errored "$idx" || continue
    n=$(retry_get "$name"); n=$((n + 1)); retry_set "$name" "$n"
    if [ "$n" -le "$max" ]; then
      echo "health: lane '$name' hit a transient error — retry $n/$max, respawning pane $idx"
      cmd=$(pane_cmd_for "$name")
      if ! run tmux respawn-pane -k -t "$TMUX_SESSION:0.$idx" "$cmd" 2>/dev/null; then
        run tmux send-keys -t "$TMUX_SESSION:0.$idx" C-c 2>/dev/null || true
        run tmux send-keys -t "$TMUX_SESSION:0.$idx" -l "$cmd" 2>/dev/null || true
        run tmux send-keys -t "$TMUX_SESSION:0.$idx" C-m 2>/dev/null || true
      fi
    else
      echo "health: lane '$name' still erroring after $max retries — marking failed." >&2
      FAILED_LANES="${FAILED_LANES:+$FAILED_LANES }$name"
    fi
  done
}

# poll_done SPEC... : each SPEC is "name:worktree". Returns 0 when all DONE, or 3
# if the only remaining lanes have failed past the retry cap (halt, don't hang).
poll_done() {
  local specs=("$@") interval="${POLYLANE_POLL_INTERVAL:-15}"
  local hinterval="${POLYLANE_HEALTH_INTERVAL:-300}" since=0
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would poll for DONE (auto-retry errored lanes every ${hinterval}s): ${specs[*]}"
    return 0
  fi
  while :; do
    local done=0 settled=0 total=${#specs[@]} s name wt
    for s in "${specs[@]}"; do
      name="${s%%:*}"; wt="${s#*:}"
      if lane_done "$wt" "$name"; then done=$((done + 1)); settled=$((settled + 1))
      elif lane_failed "$name"; then settled=$((settled + 1)); fi
    done
    echo "poll: $done/$total DONE${FAILED_LANES:+ (failed: $FAILED_LANES)}"
    [ "$done" -eq "$total" ] && return 0
    [ "$settled" -eq "$total" ] && return 3
    sleep "$interval"; since=$((since + interval))
    if [ "$since" -ge "$hinterval" ]; then health_check "${specs[@]}"; since=0; fi
  done
}

# ---------------------------------------------------------------------------
# integrator
# ---------------------------------------------------------------------------

run_integrator() {
  assert_prompt "$INT_PROMPT" "$INT_NAME"
  add_worktree "$INT_WORKTREE" "$INT_BRANCH"
  local pc
  echo "lane $INT_NAME: model=$INT_MODEL effort=${INT_EFFORT:-(default)}"
  pc=$(pane_cmd "$INT_WORKTREE" "$INT_MODEL" "$INT_PROMPT" "${INT_EFFORT:-}")
  # new_pane also handles the all-lanes-resumed case (no session yet).
  new_pane "$INT_NAME"
  INT_PANE_IDX="$NEW_PANE_IDX"
  seed_pane "$NEW_PANE_IDX" "$pc"
  pipe_pane_log "$NEW_PANE_IDX" "$INT_NAME"
}

# ---------------------------------------------------------------------------
# merge gate
# ---------------------------------------------------------------------------

# parse_verdict FILE : echo GO | NO-GO | UNKNOWN (NO-GO wins; safe default UNKNOWN).
parse_verdict() {
  local f="$1" line
  [ -f "$f" ] || { echo "UNKNOWN"; return; }
  line=$(grep -E 'NO-GO|GO' "$f" | tail -1)
  if printf '%s' "$line" | grep -q 'NO-GO'; then
    echo "NO-GO"
  elif printf '%s' "$line" | grep -qw 'GO'; then
    echo "GO"
  else
    echo "UNKNOWN"
  fi
}

# merge_gate : sets VERDICT_RESULT and returns 0 iff GO. Does NOT exit — the caller
# writes the run report on both paths, then decides. NO-GO keeps worktrees intact.
merge_gate() {
  local f="$INT_WORKTREE/docs/verify-integration.md" v
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would read integrator verdict from $f (proceed only on GO)"
    VERDICT_RESULT="GO"
    return 0
  fi
  v=$(parse_verdict "$f")
  VERDICT_RESULT="$v"
  case "$v" in
    GO)
      echo "Integrator verdict: GO — proceeding."
      notify_event go "integrator verdict GO — merging + cleanup"
      return 0
      ;;
    *)
      echo "Integrator verdict: $v — NOT a GO. Nothing deleted." >&2
      [ -f "$f" ] && { echo "--- $f ---" >&2; cat "$f" >&2; }
      notify_event no-go "integrator verdict $v — nothing merged, worktrees intact"
      return 1
      ;;
  esac
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
  for i in "${!LANE_NAMES[@]}"; do
    run rm -f "$REPO_ROOT/docs/status-${LANE_NAMES[$i]}.md"
  done
  run rm -f "$REPO_ROOT/docs/status-$INT_NAME.md"

  echo "Cleanup complete. Kept: docs/verify-*.md, docs/parallel-status.md, docs/polylane-report.md"
}

# ---------------------------------------------------------------------------
# report — plain-terms rollup the chat surfaces after the run
# ---------------------------------------------------------------------------

# capture_stats : best-effort grab each lane pane's "Goal achieved (…)" line while
# the tmux panes are still alive (call BEFORE cleanup). Fills LANE_STATS aligned
# with LANE_NAMES. Never fatal — a missing pane just yields "completed".
capture_stats() {
  LANE_STATS=()
  [ "${DRY_RUN:-0}" = "1" ] && return 0
  local i idx line
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
    LANE_STATS+=("${line:-completed}")
  done
  return 0
}

# write_report VERDICT : write docs/polylane-report.md — a plain-language digest of
# what happened + suggested next steps. Written on BOTH GO and NO-GO.
write_report() {
  local verdict="$1" f="$REPO_ROOT/docs/polylane-report.md" i when steps
  when=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || echo "?")
  mkdir -p "$REPO_ROOT/docs" 2>/dev/null || true

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
    echo "| Lane | Model | Branch | Result |"
    echo "|---|---|---|---|"
    for i in "${!LANE_NAMES[@]}"; do
      local _r="${LANE_STATS[$i]:-completed}"
      lane_failed "${LANE_NAMES[$i]}" && _r="FAILED — errored after retries"
      printf '| %s | %s | %s | %s |\n' \
        "${LANE_NAMES[$i]}" "${LANE_MODELS[$i]}" "${LANE_BRANCHES[$i]}" "$_r"
    done
    echo
    echo "## Integrator verdict"
    echo
    if [ "$verdict" = "GO" ]; then
      echo "**GO** — all lanes merged into \`${BASE}\`; worktrees, branches, and scratch removed. Kept the \`docs/verify-*.md\` evidence."
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
    if [ "$verdict" = "GO" ]; then
      echo "- Review the merged result, then \`git push\` to back it up."
    elif [ -n "${FAILED_LANES:-}" ]; then
      echo "- Lane(s) errored out and could not recover after retries: **${FAILED_LANES}**."
      echo "  A transient API/network error (e.g. 500 / overloaded) kept firing. Their"
      echo "  worktrees are left intact — re-run the runner to resume just those, or wait"
      echo "  for https://status.claude.com to clear and re-run."
    else
      echo "- Read \`docs/verify-integration.md\` for why the integrator said ${verdict}; fix the flagged lane(s) and re-run."
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
  preflight
  load_manifest
  apply_overrides   # --intensity / --model remap BEFORE any worktree/pane exists
  mark_resumed      # --resume: flag already-DONE lanes BEFORE split/launch

  echo "== split: ${#LANE_NAMES[@]} lane worktrees =="
  split_worktrees

  echo "== launch: tmux session '$TMUX_SESSION' =="
  launch_panes
  echo "Launched ${LAUNCHED:-0} of ${#LANE_NAMES[@]} lane(s). Attach with: tmux attach -t $TMUX_SESSION"

  echo "== poll: waiting for builders (auto-retry on transient errors) =="
  if poll_done "${LANE_POLLSPEC[@]}"; then
    echo "All builders DONE."
    notify_event "done" "all ${#LANE_NAMES[@]} lane(s) DONE — starting integrator"
  else
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
  else
    run_integrator
  fi
  if ! poll_done "$INT_NAME:$INT_WORKTREE"; then
    echo "Halt: integrator failed after retries. Nothing merged." >&2
    notify_event halt "integrator failed after retries — nothing merged"
    capture_stats
    write_report "HALTED" || true
    echo "Report written: $REPO_ROOT/docs/polylane-report.md"
    exit 1
  fi

  echo "== gate: integrator verdict =="
  capture_stats                        # panes still alive — grab per-lane tokens/time
  if merge_gate; then
    assert_no_conflict "$INT_WORKTREE"
    echo "== cleanup =="
    cleanup
    if [ "${PUSH:-0}" = "1" ]; then
      echo "== push: current branch =="
      run git -C "$REPO_ROOT" push
    fi
  fi

  echo "== report =="
  write_report "${VERDICT_RESULT:-UNKNOWN}" || true
  echo "Report written: $REPO_ROOT/docs/polylane-report.md"
  [ "${VERDICT_RESULT:-}" = "GO" ] || exit 1
}

# Only run main when executed directly (so tests can source the functions).
if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  main "$@"
fi
