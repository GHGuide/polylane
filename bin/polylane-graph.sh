#!/usr/bin/env bash
# polylane-graph.sh — compile contract-v2 manifests into immutable schema-v1
# execution graphs, validate those graphs, and route currently ready work.
# Bash 3.2 + jq only.  Functions are main-guarded so tests may source helpers.

usage() {
  cat <<'EOF'
usage:
  polylane-graph.sh compile <manifest> <graph-out>
  polylane-graph.sh validate <graph>
  polylane-graph.sh ready <graph> <state-json>
EOF
}

GRAPH_ERROR=""

invalid() {
  GRAPH_ERROR="$1"
  return 1
}

is_integer() {
  jq -e 'type == "number" and floor == .' >/dev/null 2>&1
}

validate_graph() {
  local graph="$1"
  GRAPH_ERROR=""
  [ -f "$graph" ] || invalid "graph file does not exist: $graph" || return 1
  jq -e . "$graph" >/dev/null 2>&1 || invalid "graph is not valid JSON" || return 1

  jq -e '
    type == "object"
    and .graph_schema == 1
    and (.graph_id | type == "string" and length > 0)
    and (.run_id | type == "string" and length > 0)
    and (.cycle | type == "number" and floor == . and . >= 1)
    and .immutable == true
    and (.nodes | type == "array" and length > 0)
    and (.edges | type == "array")
    and (.loops | type == "array")
  ' "$graph" >/dev/null 2>&1 || invalid "schema-v1 header is malformed" || return 1

  jq -e '
    [.nodes[].id] as $ids |
    ($ids | length) == ($ids | unique | length)
    and all(.nodes[]; (.id | type == "string" and length > 0))
  ' "$graph" >/dev/null 2>&1 || invalid "node ids must be unique non-empty strings" || return 1

  jq -e '
    ["agent", "command", "fanout", "join", "verifier", "repair", "human", "checkpoint", "terminal"] as $kinds |
    all(.nodes[]; . as $node |
      ($kinds | index($node.kind)) != null
      and $node.state == "pending"
      and ($node.outcomes | type == "array"
           and all(.[]; type == "string" and length > 0))
    )
  ' "$graph" >/dev/null 2>&1 || invalid "nodes need allowed kind, pending state, and outcomes" || return 1

  jq -e '
    all(.nodes[] | select(.kind == "agent");
      (.model | type == "string" and length > 0)
      and (.effort | type == "string" and length > 0)
      and (.target_subgoals | type == "array")
      and (.write_globs | type == "array")
      and (.timeout_s | type == "number" and floor == . and . >= 1)
      and (.retry_budget | type == "number" and floor == . and . >= 0)
      and (.evidence | type == "object" and (.required | type == "array" and length > 0))
    )
  ' "$graph" >/dev/null 2>&1 || invalid "agent node contract is malformed" || return 1

  jq -e '
    [.nodes[].id] as $ids | .nodes as $nodes |
    all(.edges[]; . as $edge |
      ($ids | index($edge.from)) != null
      and ($ids | index($edge.to)) != null
      and any($nodes[]; .id == $edge.from and (.outcomes | index($edge.outcome)) != null)
    )
  ' "$graph" >/dev/null 2>&1 || invalid "edge endpoint or outcome is undeclared" || return 1

  jq -e '
    [.nodes[].id] as $ids | .nodes as $nodes |
    all(.loops[]; . as $loop |
      ($loop.from | type == "string") and ($loop.to | type == "string")
      and ($loop.outcome | type == "string")
      and ($loop.max_iterations | type == "number" and floor == . and . >= 1)
      and ($ids | index($loop.from)) != null and ($ids | index($loop.to)) != null
      and any($nodes[]; .id == $loop.from and (.outcomes | index($loop.outcome)) != null)
    )
  ' "$graph" >/dev/null 2>&1 || invalid "loop endpoint, outcome, or max_iterations is invalid" || return 1

  jq -e '
    . as $graph | $graph.nodes as $nodes |
    all($nodes[]; . as $node |
      if $node.kind == "terminal" then
        ([$graph.edges[] | select(.from == $node.id)] | length) == 0
        and ([$graph.loops[] | select(.from == $node.id)] | length) == 0
      else
        ([$graph.edges[] | select(.from == $node.id)] | length) > 0
        or ([$graph.loops[] | select(.from == $node.id)] | length) > 0
      end
    )
  ' "$graph" >/dev/null 2>&1 || invalid "terminal routing or nonterminal route is invalid" || return 1

  jq -e '
    . as $graph |
    def outgoing($id): [$graph.edges[] | select(.from == $id) | .to];
    def visit($id; $path):
      if ($path | index($id)) != null then true
      else any(outgoing($id)[]; visit(.; $path + [$id])) end;
    any($graph.nodes[].id; visit(.; [])) | not
  ' "$graph" >/dev/null 2>&1 || invalid "ordinary edges must be acyclic" || return 1

  jq -e '
    . as $graph |
    [.nodes[] | select(.kind == "terminal") | .id] as $terminals |
    def next($id): [
      ($graph.edges[] | select(.from == $id) | .to),
      ($graph.loops[] | select(.from == $id) | .to)
    ];
    def reaches_terminal($id; $seen):
      if ($terminals | index($id)) != null then true
      elif ($seen | index($id)) != null then false
      else any(next($id)[]; reaches_terminal(.; $seen + [$id])) end;
    all($graph.nodes[].id; reaches_terminal(.; []))
  ' "$graph" >/dev/null 2>&1 || invalid "a node has no path to a terminal" || return 1
}

validate_or_report() {
  if ! validate_graph "$1"; then
    printf 'GRAPH-INVALID: %s\n' "$GRAPH_ERROR" >&2
    return 2
  fi
}

compile_graph() {
  local manifest="$1" graph_out="$2" graph_id tmp_dir tmp
  [ -f "$manifest" ] || { printf 'GRAPH-INVALID: manifest file does not exist: %s\n' "$manifest" >&2; return 2; }
  jq -e '
    .orchestration_contract == 2
    and (.run_id | type == "string" and length > 0)
    and (.cycle | type == "number" and floor == . and . >= 1)
    and (.target_subgoals | type == "array")
    and (.integrator.name | type == "string" and length > 0)
    and (.integrator.model | type == "string" and length > 0)
    and (.integrator.effort | type == "string" and length > 0)
    and (.lanes | type == "array" and length > 0)
    and all(.lanes[];
      (.name | type == "string" and length > 0)
      and (.model | type == "string" and length > 0)
      and (.effort | type == "string" and length > 0)
      and (.own_globs | type == "array")
      and (.target_subgoals | type == "array")
    )
  ' "$manifest" >/dev/null 2>&1 || {
    printf 'GRAPH-INVALID: contract-v2 manifest lacks graph compiler fields\n' >&2
    return 2
  }

  graph_id="graph-v1-$(cksum "$manifest" | awk '{print $1 "-" $2}')"
  tmp_dir=$(dirname "$graph_out")
  [ -d "$tmp_dir" ] || { printf 'GRAPH-INVALID: graph output directory does not exist: %s\n' "$tmp_dir" >&2; return 2; }
  tmp=$(mktemp "$tmp_dir/.polylane-graph.XXXXXX") || return 1
  trap 'rm -f "$tmp"' RETURN

  jq --arg graph_id "$graph_id" '
    def node($id; $kind; $outcomes): {id:$id, kind:$kind, state:"pending", outcomes:$outcomes};
    def agent($id; $model; $effort; $targets; $globs):
      node($id; "agent"; ["succeeded", "failed"]) + {
        model:$model, effort:$effort, target_subgoals:$targets, write_globs:$globs,
        timeout_s:1800, retry_budget:1, evidence:{required:["status", "verification"]}
      };
    {
      graph_schema: 1,
      graph_id: $graph_id,
      run_id: .run_id,
      cycle: .cycle,
      immutable: true,
      nodes: (
        [node("start"; "checkpoint"; ["succeeded"])]
        + ([.lanes[] | agent("lane:" + .name; .model; .effort; .target_subgoals; .own_globs)] | sort_by(.id))
        + [
          node("builders-joined"; "join"; ["succeeded"]),
          agent("integrator"; .integrator.model; .integrator.effort; .target_subgoals; []),
          node("verifier"; "verifier"; ["passed", "failed"]),
          node("repair"; "repair"; ["repaired", "failed"]),
          node("promote"; "checkpoint"; ["succeeded"]),
          node("complete"; "terminal"; []),
          node("halt"; "terminal"; [])
        ]
      ),
      edges: (
        ([.lanes[] | {from:"start", to:("lane:" + .name), outcome:"succeeded"}] | sort_by(.to))
        + ([.lanes[] | {from:("lane:" + .name), to:"builders-joined", outcome:"succeeded"}] | sort_by(.from))
        + ([.lanes[] | {from:("lane:" + .name), to:"halt", outcome:"failed"}] | sort_by(.from))
        + [
          {from:"builders-joined", to:"integrator", outcome:"succeeded"},
          {from:"integrator", to:"verifier", outcome:"succeeded"},
          {from:"integrator", to:"halt", outcome:"failed"},
          {from:"verifier", to:"promote", outcome:"passed"},
          {from:"verifier", to:"repair", outcome:"failed"},
          {from:"repair", to:"halt", outcome:"failed"},
          {from:"promote", to:"complete", outcome:"succeeded"}
        ]
      ),
      loops: [{from:"repair", to:"verifier", outcome:"repaired", max_iterations:1}]
    }
  ' "$manifest" > "$tmp" || { rm -f "$tmp"; trap - RETURN; return 1; }
  if ! validate_graph "$tmp"; then
    printf 'GRAPH-INVALID: compiler emitted invalid graph: %s\n' "$GRAPH_ERROR" >&2
    rm -f "$tmp"
    trap - RETURN
    return 2
  fi
  mv "$tmp" "$graph_out"
  trap - RETURN
}

ready_nodes() {
  local graph="$1" state="$2"
  validate_or_report "$graph" || return $?
  [ -f "$state" ] || { printf 'GRAPH-INVALID: state file does not exist: %s\n' "$state" >&2; return 2; }
  jq -e 'type == "object" and ((.nodes? // .) | type == "object")' "$state" >/dev/null 2>&1 || {
    printf 'GRAPH-INVALID: state must be a JSON object or contain a nodes object\n' >&2
    return 2
  }
  jq -r --slurpfile state "$state" '
    . as $graph | ($state[0].nodes // $state[0]) as $states |
    def execution_state:
      if . == "passed" or . == "repaired" then "succeeded" else . end;
    def incoming($id): [($graph.edges[]), ($graph.loops[]) | select(.to == $id)];
    def route_matches:
      (($states[.from] // "pending") | execution_state) == (.outcome | execution_state);
    [ $graph.nodes[]
      | . as $node
      | select(($states[$node.id] // $node.state) == "pending")
      | incoming($node.id) as $routes
      | select(
          if ($routes | length) == 0 then true
          elif $node.kind == "join" then all($routes[]; route_matches)
          else any($routes[]; route_matches)
          end
        )
      | $node.id
    ] | sort[]
  ' "$graph"
}

main() {
  set -euo pipefail
  [ $# -ge 1 ] || { usage >&2; return 2; }
  case "$1" in
    compile) [ $# -eq 3 ] || { usage >&2; return 2; }; compile_graph "$2" "$3" ;;
    validate) [ $# -eq 2 ] || { usage >&2; return 2; }; validate_or_report "$2" ;;
    ready) [ $# -eq 3 ] || { usage >&2; return 2; }; ready_nodes "$2" "$3" ;;
    *) usage >&2; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  main "$@"
fi
