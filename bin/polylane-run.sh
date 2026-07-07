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
  bin/polylane-run.sh <manifest.json> [--dry-run] [--yes]
                      [--intensity <economy|balanced|performance|max>]
                      [--model <lane=model_id>]...

ARGS:
  <manifest.json>   path to a .polylane/run.json manifest (see .polylane/SCHEMA.md)

OPTIONS:
  --dry-run              print every git/tmux command without executing anything
  --yes                  skip the final delete-confirmation prompt
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
  POLYLANE_POLL_INTERVAL   seconds between DONE-file polls (default 15)
EOF
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
  MANIFEST=""
  INTENSITY=""
  MODEL_OVERRIDES=()
  [ $# -eq 0 ] && { usage >&2; exit 2; }
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --dry-run) DRY_RUN=1 ;;
      --yes)     YES=1 ;;
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
  done

  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
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
      LANE_MODELS[$i]="$mdl"; LANE_EFFORTS[$i]="$eff"
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
      if [ "${LANE_NAMES[$i]}" = "$name" ]; then LANE_MODELS[$i]="$id"; found=1; fi
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
    add_worktree "${LANE_WORKTREES[$i]}" "${LANE_BRANCHES[$i]}"
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
# prefix claude ignores if unused); an empty EFFORT reproduces the legacy
# command byte-for-byte, so behavior is unchanged when no effort is set.
pane_cmd() {
  local wt="$1" model="$2" pf="$3" effort="${4:-}" pfx=""
  [ -n "$effort" ] && pfx="POLYLANE_EFFORT='$effort' "
  printf "cd '%s' && %sclaude --model '%s' \"\$(cat '%s')\" || { pbcopy < '%s' 2>/dev/null || xclip -selection clipboard < '%s' 2>/dev/null; echo 'SEED FAILED — prompt copied to clipboard; paste it into claude'; %sclaude --model '%s'; }" \
    "$wt" "$pfx" "$model" "$pf" "$pf" "$pf" "$pfx" "$model"
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

launch_panes() {
  local i first=1 pc
  # Preflight ALL prompts first — better to abort before opening a single pane
  # than to leave half a tmux session of empty claude sessions.
  for i in "${!LANE_NAMES[@]}"; do
    assert_prompt "${LANE_PROMPTS[$i]}" "${LANE_NAMES[$i]}"
  done
  for i in "${!LANE_NAMES[@]}"; do
    echo "lane ${LANE_NAMES[$i]}: model=${LANE_MODELS[$i]} effort=${LANE_EFFORTS[$i]:-(default)}"
    pc=$(pane_cmd "${LANE_WORKTREES[$i]}" "${LANE_MODELS[$i]}" "${LANE_PROMPTS[$i]}" "${LANE_EFFORTS[$i]:-}")
    if [ "$first" = "1" ]; then
      run tmux new-session -d -s polylane -n "${LANE_NAMES[$i]}"
      first=0
    else
      run tmux split-window -t polylane
      run tmux select-layout -t polylane tiled
    fi
    run tmux send-keys -t polylane "$pc" C-m
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

# poll_done SPEC... : each SPEC is "name:worktree". Loops until all are DONE.
poll_done() {
  local specs=("$@") interval="${POLYLANE_POLL_INTERVAL:-15}"
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would poll for DONE: ${specs[*]}"
    return 0
  fi
  while :; do
    local done=0 total=${#specs[@]} s name wt
    for s in "${specs[@]}"; do
      name="${s%%:*}"; wt="${s#*:}"
      if lane_done "$wt" "$name"; then done=$((done + 1)); fi
    done
    echo "poll: $done/$total lanes DONE"
    [ "$done" -eq "$total" ] && return 0
    sleep "$interval"
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
  run tmux split-window -t polylane
  run tmux select-layout -t polylane tiled
  run tmux send-keys -t polylane "$pc" C-m
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

merge_gate() {
  local f="$INT_WORKTREE/docs/verify-integration.md" v
  if [ "${DRY_RUN:-0}" = "1" ]; then
    echo "+ (dry-run) would read integrator verdict from $f (proceed only on GO)"
    return 0
  fi
  v=$(parse_verdict "$f")
  case "$v" in
    GO) echo "Integrator verdict: GO — proceeding." ;;
    *)
      echo "Integrator verdict: $v — NOT a GO. Stopping. Nothing deleted." >&2
      [ -f "$f" ] && { echo "--- $f ---" >&2; cat "$f" >&2; }
      exit 1
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

  echo "Cleanup complete. Kept: docs/verify-*.md, docs/parallel-status.md"
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

  echo "== split: ${#LANE_NAMES[@]} lane worktrees =="
  split_worktrees

  echo "== launch: tmux session 'polylane' =="
  launch_panes
  echo "Launched ${#LANE_NAMES[@]} lane(s). Attach with: tmux attach -t polylane"

  echo "== poll: waiting for builders =="
  poll_done "${LANE_POLLSPEC[@]}"
  echo "All builders DONE."

  echo "== integrator: $INT_NAME =="
  run_integrator
  poll_done "$INT_NAME:$INT_WORKTREE"

  echo "== gate: integrator verdict =="
  merge_gate
  assert_no_conflict "$INT_WORKTREE"

  echo "== cleanup =="
  cleanup
}

# Only run main when executed directly (so tests can source the functions).
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
