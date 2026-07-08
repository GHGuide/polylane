#!/usr/bin/env bash
#
# polylane-dashboard.sh — live tmux-pane dashboard for a polylane run
#
# Renders one row per lane (plus the integrator): lane · model · state
# (waiting/working/DONE/FAILED/STALL) · elapsed since launch · last-seen
# tokens. State comes from the runner's DONE files plus best-effort tmux
# pane captures; the error signature matches bin/polylane-run.sh's
# pane_errored() so both tools agree on what "errored" looks like.
#
# READ-ONLY: reads the manifest, <worktree>/docs/status-<lane>.md,
# docs/lane-logs/*.log (if present) and `tmux capture-pane`. Writes NOTHING
# except its own screen.
#
# CLI:
#   bin/polylane-dashboard.sh <manifest.json> [--interval N]   # default 5s
#   bin/polylane-dashboard.sh --demo [--interval N]            # default 1s
#
# DEPS: jq (manifest parse). tmux is optional — without a live session the
#       tokens column shows '-' and state falls back to DONE files + logs.
#
# ENV:
#   POLYLANE_SESSION     tmux session to inspect (default: polylane)
#   POLYLANE_STALL_SECS  pane output unchanged this long -> STALL (default 120)
#
# bash-3.2 safe: indexed arrays only, no mapfile, no associative arrays.
# `set -e` is deliberately NOT used: a monitor must survive transient grep/
# tmux/stat failures instead of dying mid-run.

TMUX_SESSION="${POLYLANE_SESSION:-polylane}"
STALL_SECS="${POLYLANE_STALL_SECS:-120}"

# Same transient-error signature the runner's pane_errored() scans for.
ERR_RE='API Error|Internal server error|overloaded|rate.?limit|Connection error|network error|5[0-9][0-9] (Internal|error)|status\.claude\.com'

RULE='----------------------------------------------------------------------'

usage() {
  cat <<'EOF'
polylane-dashboard.sh — live tmux-pane dashboard for a polylane run (read-only)

USAGE:
  bin/polylane-dashboard.sh <manifest.json> [--interval N]
  bin/polylane-dashboard.sh --demo [--interval N]

ARGS:
  <manifest.json>   path to a .polylane/run.json manifest (see .polylane/SCHEMA.md)

OPTIONS:
  --interval N   seconds between refreshes (positive integer; default 5, demo 1)
  --demo         no manifest needed — fabricates 3 lanes + integrator cycling
                 waiting/working/STALL/FAILED/DONE to preview the dashboard
  -h, --help     show this help and exit 0

STATES:
  waiting  worktree or status file not there yet (lane not launched)
  working  lane launched, no DONE file, pane alive and changing
  DONE     <worktree>/docs/status-<lane>.md first line == "STATUS: <lane> DONE"
  FAILED   pane/log text shows the runner's transient-error signature
  STALL    pane output unchanged for POLYLANE_STALL_SECS (default 120s)

READS ONLY: manifest · status files · docs/lane-logs/*.log · tmux capture-pane.
WRITES NOTHING except its own screen.

ENV: POLYLANE_SESSION (default polylane) · POLYLANE_STALL_SECS (default 120)
EOF
}

# ---------------------------------------------------------------------------
# small helpers
# ---------------------------------------------------------------------------

# fmt_dur SECS : "42s" / "3m07s" / "1h03m"; '-' for empty/non-numeric input.
fmt_dur() {
  local s="$1"
  case "$s" in ''|*[!0-9]*) printf '%s' '-'; return 0 ;; esac
  if [ "$s" -ge 3600 ]; then
    printf '%dh%02dm' $((s / 3600)) $(((s % 3600) / 60))
  elif [ "$s" -ge 60 ]; then
    printf '%dm%02ds' $((s / 60)) $((s % 60))
  else
    printf '%ds' "$s"
  fi
}

# abs_path PATH : anchor a relative manifest path at PROJECT_ROOT (the dir
# that contains .polylane/) — same convention as the runner's abs_prompt.
abs_path() {
  case "$1" in
    /*|'') printf '%s' "$1" ;;
    *)     printf '%s/%s' "$PROJECT_ROOT" "$1" ;;
  esac
}

C_RESET='' C_DIM='' C_BLD='' C_GRN='' C_RED='' C_YLW='' C_CYN=''
init_colors() {
  [ -t 1 ] || return 0
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BLD=$'\033[1m'
  C_GRN=$'\033[32m'; C_RED=$'\033[31m'; C_YLW=$'\033[33m'; C_CYN=$'\033[36m'
}

state_color() {
  case "$1" in
    DONE)    printf '%s' "$C_GRN" ;;
    FAILED)  printf '%s' "$C_RED" ;;
    STALL)   printf '%s' "$C_YLW" ;;
    working) printf '%s' "$C_CYN" ;;
    *)       printf '%s' "$C_DIM" ;;
  esac
}

restore_cursor() {
  if [ -t 1 ]; then printf '\033[?25h'; fi
}

# ---------------------------------------------------------------------------
# arg parsing
# ---------------------------------------------------------------------------

parse_args() {
  MANIFEST=""
  INTERVAL=""
  DEMO=0
  [ $# -eq 0 ] && { usage >&2; exit 2; }
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --demo)    DEMO=1 ;;
      --interval)   shift; [ $# -gt 0 ] || { echo "polylane-dashboard: --interval requires a value" >&2; exit 2; }; INTERVAL="$1" ;;
      --interval=*) INTERVAL="${1#*=}" ;;
      --) shift; [ $# -gt 0 ] && MANIFEST="$1" ;;
      -*) echo "polylane-dashboard: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *)
        if [ -z "$MANIFEST" ]; then
          MANIFEST="$1"
        else
          echo "polylane-dashboard: unexpected extra argument: $1" >&2; exit 2
        fi
        ;;
    esac
    shift
  done
  if [ -n "$INTERVAL" ]; then
    case "$INTERVAL" in
      *[!0-9]*|'') echo "polylane-dashboard: --interval wants a positive integer, got '$INTERVAL'" >&2; exit 2 ;;
    esac
    [ "$INTERVAL" -ge 1 ] || { echo "polylane-dashboard: --interval must be >= 1" >&2; exit 2; }
  elif [ "$DEMO" = "1" ]; then
    INTERVAL=1
  else
    INTERVAL=5
  fi
  if [ "$DEMO" != "1" ]; then
    if [ -z "$MANIFEST" ]; then
      echo "polylane-dashboard: manifest argument required" >&2; usage >&2; exit 2
    fi
    if [ ! -f "$MANIFEST" ]; then
      echo "polylane-dashboard: manifest not found: $MANIFEST" >&2; usage >&2; exit 2
    fi
    if ! command -v jq >/dev/null 2>&1; then
      echo "polylane-dashboard: jq is required to parse the manifest" >&2; exit 1
    fi
    if ! jq empty "$MANIFEST" 2>/dev/null; then
      echo "polylane-dashboard: manifest is not valid JSON: $MANIFEST" >&2; usage >&2; exit 2
    fi
  fi
}

# ---------------------------------------------------------------------------
# manifest -> row globals (lanes in manifest order, integrator last — the
# exact pane order the runner creates in tmux window 0)
# ---------------------------------------------------------------------------

load_manifest() {
  local _mdir
  _mdir=$(cd "$(dirname "$MANIFEST")" && pwd)
  PROJECT_ROOT=$(cd "$_mdir/.." && pwd)

  L_NAMES=(); L_MODELS=(); L_WTS=()
  local n i iname
  n=$(jq '.lanes | length' "$MANIFEST")
  for ((i = 0; i < n; i++)); do
    L_NAMES+=("$(jq -r ".lanes[$i].name" "$MANIFEST")")
    L_MODELS+=("$(jq -r ".lanes[$i].model // \"?\"" "$MANIFEST")")
    L_WTS+=("$(abs_path "$(jq -r ".lanes[$i].worktree // \"\"" "$MANIFEST")")")
  done
  iname=$(jq -r '.integrator.name // ""' "$MANIFEST")
  if [ -n "$iname" ]; then
    L_NAMES+=("$iname")
    L_MODELS+=("$(jq -r '.integrator.model // "?"' "$MANIFEST")")
    L_WTS+=("$(abs_path "$(jq -r '.integrator.worktree // ""' "$MANIFEST")")")
  fi
  if [ "${#L_NAMES[@]}" -eq 0 ]; then
    echo "polylane-dashboard: manifest has no lanes: $MANIFEST" >&2
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# state engine
# ---------------------------------------------------------------------------

# lane_done WORKTREE NAME : same test as the runner — first line of the
# status file == "STATUS: <name> DONE".
lane_done() {
  local wt="$1" name="$2" f="$1/docs/status-$2.md" first
  [ -f "$f" ] || return 1
  IFS= read -r first < "$f" || return 1
  [ "$first" = "STATUS: $name DONE" ]
}

# pane_text IDX : the lane's tmux pane contents ('' if no tmux/session/pane).
pane_text() {
  tmux capture-pane -t "$TMUX_SESSION:0.$1" -p 2>/dev/null || true
}

# log_text NAME : tail of docs/lane-logs/<name>.log if present (fallback
# text source when there is no live pane).
log_text() {
  local f="$PROJECT_ROOT/docs/lane-logs/$1.log"
  if [ -f "$f" ]; then tail -n 40 "$f" 2>/dev/null || true; fi
}

# text_tokens TEXT : last "<count> tokens" seen (e.g. "45.2k"), or '-'.
text_tokens() {
  local t
  t=$(printf '%s' "$1" | grep -oiE '[0-9][0-9.,]*[km]?[[:space:]]?tokens' | tail -1)
  if [ -n "$t" ]; then
    printf '%s' "$t" | sed 's/[[:space:]]*[Tt]okens$//'
  else
    printf '%s' '-'
  fi
}

# launch_epoch IDX : best-effort lane launch time — tmux pane_start_time if
# the pane exists, else the worktree dir mtime, else the dashboard start.
launch_epoch() {
  local i="$1" t
  t=$(tmux display-message -p -t "$TMUX_SESSION:0.$i" '#{pane_start_time}' 2>/dev/null)
  case "$t" in *[!0-9]*|'') t="" ;; esac
  if [ -z "$t" ] && [ -d "${L_WTS[$i]}" ]; then
    t=$(stat -f %m "${L_WTS[$i]}" 2>/dev/null || stat -c %Y "${L_WTS[$i]}" 2>/dev/null)
    case "$t" in *[!0-9]*|'') t="" ;; esac
  fi
  [ -n "$t" ] || t="$DASH_START"
  printf '%s' "$t"
}

# state_for IDX : sets ROW_STATE + ROW_TOKENS for one row. Precedence:
# DONE > FAILED > STALL > working > waiting. Missing worktree/status with no
# pane signal -> waiting (lane not launched yet).
state_for() {
  local i="$1" name wt txt sig
  name="${L_NAMES[$i]}"; wt="${L_WTS[$i]}"
  ROW_TOKENS='-'

  txt=$(pane_text "$i")
  [ -n "$txt" ] || txt=$(log_text "$name")
  [ -n "$txt" ] && ROW_TOKENS=$(text_tokens "$txt")

  if lane_done "$wt" "$name"; then
    ROW_STATE="DONE"
    return 0
  fi

  if [ -n "$txt" ] && printf '%s' "$txt" | grep -qiE "$ERR_RE"; then
    ROW_STATE="FAILED"
    return 0
  fi

  if [ -n "$txt" ]; then
    sig=$(printf '%s' "$txt" | cksum 2>/dev/null | awk '{print $1}')
    if [ -n "$sig" ] && [ "${L_SIG[$i]:-}" = "$sig" ]; then
      if [ $((NOW - ${L_SIGAT[$i]:-$NOW})) -ge "$STALL_SECS" ]; then
        ROW_STATE="STALL"
        return 0
      fi
    else
      L_SIG[$i]="$sig"
      L_SIGAT[$i]="$NOW"
    fi
  fi

  if [ -d "$wt" ] && { [ -n "$txt" ] || [ -f "$wt/docs/status-$name.md" ]; }; then
    ROW_STATE="working"
  else
    ROW_STATE="waiting"
  fi
}

# ---------------------------------------------------------------------------
# render — consumes R_NAME/R_MODEL/R_STATE/R_ELAPSED/R_TOKENS + SRC_LABEL +
# TOTAL_ELAPSED, prints one frame
# ---------------------------------------------------------------------------

render() {
  local i done_n=0 total="${#R_NAME[@]}" color
  if [ -t 1 ]; then printf '\033[H\033[2J'; fi
  printf '%sPOLYLANE DASHBOARD%s  %s%s%s\n' "$C_BLD" "$C_RESET" "$C_DIM" "$SRC_LABEL" "$C_RESET"
  printf '%s\n' "$RULE"
  printf '%s%-16s %-22s %-9s %-9s %s%s\n' "$C_BLD" 'LANE' 'MODEL' 'STATE' 'ELAPSED' 'TOKENS' "$C_RESET"
  for i in "${!R_NAME[@]}"; do
    [ "${R_STATE[$i]}" = "DONE" ] && done_n=$((done_n + 1))
    color=$(state_color "${R_STATE[$i]}")
    printf '%-16s %-22s %s%-9s%s %-9s %s\n' \
      "${R_NAME[$i]}" "${R_MODEL[$i]}" \
      "$color" "${R_STATE[$i]}" "$C_RESET" \
      "${R_ELAPSED[$i]}" "${R_TOKENS[$i]}"
  done
  printf '%s\n' "$RULE"
  printf '%d/%d done · session %s · total %s · refresh %ss\n' \
    "$done_n" "$total" "$TMUX_SESSION" "$TOTAL_ELAPSED" "$INTERVAL"
  printf '%shint: tmux attach -t %s%s\n' "$C_DIM" "$TMUX_SESSION" "$C_RESET"
}

# ---------------------------------------------------------------------------
# live mode
# ---------------------------------------------------------------------------

live_loop() {
  local i epoch
  L_SIG=(); L_SIGAT=()
  RUN_START=""
  SRC_LABEL="$MANIFEST"
  while :; do
    NOW=$(date +%s)
    R_NAME=(); R_MODEL=(); R_STATE=(); R_ELAPSED=(); R_TOKENS=()
    for i in "${!L_NAMES[@]}"; do
      state_for "$i"
      if [ "$ROW_STATE" = "waiting" ]; then
        R_ELAPSED+=('-')
      else
        epoch=$(launch_epoch "$i")
        if [ -z "$RUN_START" ] || [ "$epoch" -lt "$RUN_START" ]; then
          RUN_START="$epoch"
        fi
        R_ELAPSED+=("$(fmt_dur $((NOW - epoch)))")
      fi
      R_NAME+=("${L_NAMES[$i]}")
      R_MODEL+=("${L_MODELS[$i]}")
      R_STATE+=("$ROW_STATE")
      R_TOKENS+=("$ROW_TOKENS")
    done
    TOTAL_ELAPSED=$(fmt_dur $((NOW - ${RUN_START:-$DASH_START})))
    render
    sleep "$INTERVAL"
  done
}

# ---------------------------------------------------------------------------
# demo mode — 3 fabricated lanes + integrator cycling through every state,
# so the dashboard can be previewed without a real run (16-frame cycle)
# ---------------------------------------------------------------------------

demo_row() {
  # demo_row STATE TOKENS : append one fabricated row (name/model set by caller)
  R_STATE+=("$1")
  R_TOKENS+=("$2")
  if [ "$1" = "waiting" ]; then
    R_ELAPSED+=('-')
  else
    R_ELAPSED+=("$(fmt_dur $((DEMO_T * INTERVAL)))")
  fi
}

demo_loop() {
  local p
  DEMO_T=0
  SRC_LABEL='(demo — fabricated lanes, no manifest)'
  while :; do
    p=$((DEMO_T % 16))
    R_NAME=(api ui docs integrate)
    R_MODEL=(claude-sonnet-5 claude-fable-5 claude-haiku-4-5 claude-opus-4-8)
    R_STATE=(); R_ELAPSED=(); R_TOKENS=()

    # api: waiting -> working -> DONE
    if   [ "$p" -lt 2 ];  then demo_row waiting '-'
    elif [ "$p" -lt 10 ]; then demo_row working "$((p * 4)).2k"
    else                       demo_row DONE '40.2k'; fi

    # ui: waiting -> working -> STALL -> working -> DONE
    if   [ "$p" -lt 1 ];  then demo_row waiting '-'
    elif [ "$p" -lt 6 ];  then demo_row working "$((p * 6)).0k"
    elif [ "$p" -lt 9 ];  then demo_row STALL '30.0k'
    elif [ "$p" -lt 14 ]; then demo_row working "$((p * 6)).0k"
    else                       demo_row DONE '78.0k'; fi

    # docs: working -> FAILED -> working (retried) -> DONE
    if   [ "$p" -lt 4 ];  then demo_row working "$((p * 2)).5k"
    elif [ "$p" -lt 7 ];  then demo_row FAILED '8.5k'
    elif [ "$p" -lt 12 ]; then demo_row working "$((p * 2)).5k"
    else                       demo_row DONE '22.5k'; fi

    # integrate: waiting until the lanes settle, then working -> DONE
    if   [ "$p" -lt 12 ]; then demo_row waiting '-'
    elif [ "$p" -lt 15 ]; then demo_row working "$((p)).3k"
    else                       demo_row DONE '14.3k'; fi

    TOTAL_ELAPSED=$(fmt_dur $((DEMO_T * INTERVAL)))
    render
    DEMO_T=$((DEMO_T + 1))
    sleep "$INTERVAL"
  done
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
  set -u
  parse_args "$@"
  init_colors
  DASH_START=$(date +%s)
  NOW="$DASH_START"
  if [ -t 1 ]; then printf '\033[?25l'; fi
  trap 'restore_cursor; exit 0' INT TERM
  trap 'restore_cursor' EXIT
  if [ "$DEMO" = "1" ]; then
    demo_loop
  else
    load_manifest
    live_loop
  fi
}

# Only run main when executed directly (so tests can source the functions).
if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  main "$@"
fi
