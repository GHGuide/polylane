#!/usr/bin/env bash
# polylane-graph-bench.sh — deterministic synthetic graph/event fixtures.

usage() {
  cat <<'EOF'
USAGE:
  polylane-graph-bench.sh fixture <dir> <nodes> <events>
EOF
}

valid_integer() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

fixture() {
  local dir="$1" nodes="$2" events="$3"
  valid_integer "$nodes" && [ "$nodes" -gt 0 ] || {
    printf 'polylane-graph-bench: nodes must be a positive integer\n' >&2
    return 2
  }
  valid_integer "$events" || {
    printf 'polylane-graph-bench: events must be a non-negative integer\n' >&2
    return 2
  }
  mkdir -p "$dir" || return 1
  jq -cnc --argjson nodes "$nodes" '
    {graph_schema: 1, run_id: "fixture-run", graph_id: "fixture-graph",
     nodes: [range(1; $nodes + 1) | {id: ("node-" + tostring), state: "pending"}]}
  ' > "$dir/graph.json"
  jq -cnc --argjson nodes "$nodes" --argjson events "$events" '
    range(1; $events + 1) as $seq
    | (($seq - 1) % $nodes + 1) as $node_number
    | ((($seq - 1) / $nodes) | floor) as $turn
    | (if $turn == 0 then {from: "pending", to: "ready"}
       elif (($turn - 1) % 3) == 0 then {from: "ready", to: "running"}
       elif (($turn - 1) % 3) == 1 then {from: "running", to: "failed"}
       else {from: "failed", to: "ready"}
       end) as $transition
    | {event_schema: 1, seq: $seq, timestamp: (1700000000 + $seq),
       run_id: "fixture-run", graph_id: "fixture-graph",
       node: ("node-" + ($node_number | tostring)),
       from: $transition.from, to: $transition.to, attempt: $turn,
       idempotency_key: ("fixture-" + ($seq | tostring)), reason: "synthetic",
       artifact_hash: ""}
  ' > "$dir/events.jsonl"
}

main() {
  set -euo pipefail
  [ "$#" -ge 1 ] || { usage >&2; exit 2; }
  case "$1" in
    fixture)
      [ "$#" -eq 4 ] || { usage >&2; exit 2; }
      fixture "$2" "$3" "$4"
      ;;
    -h|--help) usage ;;
    *) usage >&2; exit 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
