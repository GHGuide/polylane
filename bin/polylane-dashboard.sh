#!/usr/bin/env bash
# polylane-dashboard.sh — read-only control-room projection for one run.
#
# The dashboard deliberately has no state machine.  polylane-state is the
# authority for nonce-qualified lane status; this script joins that snapshot
# with durable run records for people and automation to consume.

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RULE='----------------------------------------------------------------------'

usage() {
  cat <<'EOF'
polylane-dashboard.sh — read-only canonical control-room snapshot

USAGE:
  bin/polylane-dashboard.sh <manifest.json> [--once] [--json] [--interval N]
  bin/polylane-dashboard.sh --demo [--interval N]

OPTIONS:
  --once         print one canonical snapshot and exit
  --json         emit the snapshot JSON (requires --once)
  --interval N   refresh interval for the interactive view (default 5)
  --demo         render fabricated preview rows; never reads run state
  -h, --help     show this help and exit 0

The JSON snapshot contains: schema, goal, cycle, run_id, route, graph, lanes,
spend, verdict, heartbeat, cleanup, and next_action. Unknown durable facts are
null, never fabricated as zero or success. Lane completion comes only from
polylane-state's current-run nonce-qualified marker semantics.
EOF
}

parse_args() {
  MANIFEST='' INTERVAL='' DEMO=0 ONCE=0 JSON=0
  [ $# -gt 0 ] || { usage >&2; exit 2; }
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --demo) DEMO=1 ;;
      --once) ONCE=1 ;;
      --json) JSON=1 ;;
      --interval) shift; [ $# -gt 0 ] || { echo 'polylane-dashboard: --interval requires a value' >&2; exit 2; }; INTERVAL=$1 ;;
      --interval=*) INTERVAL=${1#*=} ;;
      -*) echo "polylane-dashboard: unknown option: $1" >&2; usage >&2; exit 2 ;;
      *) [ -z "$MANIFEST" ] || { echo "polylane-dashboard: unexpected extra argument: $1" >&2; exit 2; }; MANIFEST=$1 ;;
    esac
    shift
  done
  if [ -n "$INTERVAL" ]; then
    case "$INTERVAL" in ''|*[!0-9]*) echo "polylane-dashboard: --interval wants a positive integer, got '$INTERVAL'" >&2; exit 2 ;; esac
    [ "$INTERVAL" -ge 1 ] || { echo 'polylane-dashboard: --interval must be >= 1' >&2; exit 2; }
  elif [ "$DEMO" = 1 ]; then INTERVAL=1
  else INTERVAL=5; fi
  [ "$JSON" = 0 ] || [ "$ONCE" = 1 ] || { echo 'polylane-dashboard: --json requires --once' >&2; exit 2; }
  [ "$DEMO" = 0 ] || { [ "$ONCE" = 0 ] && [ "$JSON" = 0 ] || { echo 'polylane-dashboard: --demo cannot use --once or --json' >&2; exit 2; }; return; }
  [ -n "$MANIFEST" ] || { echo 'polylane-dashboard: manifest argument required' >&2; usage >&2; exit 2; }
  [ -f "$MANIFEST" ] || { echo "polylane-dashboard: manifest not found: $MANIFEST" >&2; exit 2; }
  command -v jq >/dev/null 2>&1 || { echo 'polylane-dashboard: jq is required' >&2; exit 1; }
  jq empty "$MANIFEST" 2>/dev/null || { echo 'polylane-dashboard: manifest is not valid JSON' >&2; exit 2; }
}

path_from_project() { # PROJECT_ROOT PATH
  case "$2" in /*) printf '%s' "$2" ;; *) printf '%s/%s' "$1" "$2" ;; esac
}

json_file_or_null() { # FILE
  if [ -f "$1" ] && jq empty "$1" 2>/dev/null; then cat "$1"; else printf 'null'; fi
}

event_count_or_null() { # JSONL
  if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else printf 'null'; fi
}

spend_snapshot() { # LEDGER
  local ledger="$1"
  if [ ! -f "$ledger" ]; then printf '{"entries":null,"total":null}'; return; fi
  jq -s 'map(select(type == "object")) as $rows |
    {entries: ($rows | length),
     total: ([ $rows[] | (.cost_usd // .spent // .amount // empty) | select(type == "number") ] | add // null)}' "$ledger" 2>/dev/null || printf '{"entries":null,"total":null}'
}

canonical_snapshot() {
  local mdir project max_path max graph_events ledger stats cleanup state_json max_json spend_json
  mdir=$(cd "$(dirname "$MANIFEST")" && pwd -P)
  project=$(cd "$mdir/.." && pwd -P)
  state_json=$("$SCRIPT_DIR/polylane-state.sh" "$MANIFEST" --json 2>/dev/null) || state_json='{}'
  jq empty >/dev/null 2>&1 <<<"$state_json" || state_json='{}'
  max=$(jq -r '.state_file // "docs/polylane/max-state.json"' "$MANIFEST")
  max_path=$(path_from_project "$project" "$max")
  max_json=$(json_file_or_null "$max_path")
  graph_events=$(event_count_or_null "$mdir/events.jsonl")
  ledger="$project/docs/polylane/spend-ledger.jsonl"
  spend_json=$(spend_snapshot "$ledger")
  stats="$mdir/run-stats.json"
  cleanup=$(jq -r '.cleanup // empty' "$stats" 2>/dev/null || true)
  [ -n "$cleanup" ] || cleanup=$(jq -r '.cleanup // empty' <<<"$max_json" 2>/dev/null || true)
  [ -n "$cleanup" ] || cleanup='unknown'

  jq -n --argjson manifest "$(cat "$MANIFEST")" --argjson state "$state_json" \
    --argjson max "$max_json" --argjson spend "$spend_json" --argjson events "$graph_events" --arg cleanup "$cleanup" '
      ($manifest.lanes + (if $manifest.integrator then [$manifest.integrator] else [] end)) as $declared |
      {schema:"polylane-control-room/v1",
       goal:($manifest.goal // $max.goal // null), cycle:($manifest.cycle // null),
       run_id:($manifest.run_id // null), route:{target_subgoals:($manifest.target_subgoals // []), state_file:($manifest.state_file // "docs/polylane/max-state.json")},
       graph:{id:($manifest.graph.id // $manifest.graph_id // null), events:$events},
       lanes:($state.lanes // [] | map(. as $lane | $lane + {model: ([ $declared[] | select(.name == $lane.name) | .model ][0] // null)})),
       spend:$spend, verdict:($state.verdict // "UNKNOWN"), heartbeat:($state.heartbeat_age // null),
       cleanup:$cleanup,
       next_action:(if ($state.verdict // "UNKNOWN") == "GO" then "review durable report and cleanup" elif ($state.runner // "dead") == "alive" then "observe current lanes" else "inspect canonical state before resuming" end),
       report:($state.report // "absent"), runner:($state.runner // "dead"), max_state:$max}'
}

render_snapshot() { # SNAPSHOT JSON
  local snapshot="$1" session done_count total
  session=$(jq -r '.runner as $r | if $r == "alive" then "active" else "idle" end' <<<"$snapshot")
  done_count=$(jq '[.lanes[]? | select(.status == "done")] | length' <<<"$snapshot")
  total=$(jq '.lanes | length' <<<"$snapshot")
  printf 'POLYLANE DASHBOARD  run=%s · cycle=%s · %s\n' "$(jq -r '.run_id // "unknown"' <<<"$snapshot")" "$(jq -r '.cycle // "unknown"' <<<"$snapshot")" "$session"
  printf '%s\n' "$RULE"
  printf '%-16s %-22s %-28s %s\n' 'LANE' 'MODEL' 'STATE' 'COMMITS'
  jq -r '.lanes[]? | [(.name // "unknown"), (.model // "-"), (.status // "unknown"), ((.commits_ahead // null) | if . == null then "-" else tostring end)] | @tsv' <<<"$snapshot" |
  while IFS=$'\t' read -r name model status commits; do
    printf '%-16s %-22s %-28s %s\n' "$name" "$model" "$status" "$commits"
  done
  printf '%s\n' "$RULE"
  printf '%s/%s done · verdict %s · heartbeat %s · cleanup %s\n' "$done_count" "$total" "$(jq -r '.verdict' <<<"$snapshot")" "$(jq -r '.heartbeat // "unknown"' <<<"$snapshot")" "$(jq -r '.cleanup' <<<"$snapshot")"
  printf 'hint: tmux attach -t %s\n' "${POLYLANE_SESSION:-polylane}"
}

live_loop() {
  local snapshot
  while :; do
    snapshot=$(canonical_snapshot)
    if [ -t 1 ]; then printf '\033[H\033[2J'; fi
    render_snapshot "$snapshot"
    sleep "$INTERVAL"
  done
}

demo_loop() {
  while :; do
    printf 'POLYLANE DASHBOARD  (demo — fabricated rows)\n%s\n' "$RULE"
    printf '%-16s %-22s %-28s %s\n' 'LANE' 'MODEL' 'STATE' 'COMMITS'
    printf '%-16s %-22s %-28s %s\n' api gpt-5.6-terra working -
    printf '%-16s %-22s %-28s %s\n' integrate gpt-5.6-terra waiting -
    printf '%s\n0/2 done · verdict UNKNOWN · heartbeat unknown · cleanup unknown\nhint: tmux attach -t %s\n' "$RULE" "${POLYLANE_SESSION:-polylane}"
    sleep "$INTERVAL"
  done
}

main() {
  parse_args "$@"
  if [ "$DEMO" = 1 ]; then demo_loop
  elif [ "$ONCE" = 1 ]; then
    snapshot=$(canonical_snapshot)
    if [ "$JSON" = 1 ]; then printf '%s\n' "$snapshot"; else render_snapshot "$snapshot"; fi
  else live_loop; fi
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
