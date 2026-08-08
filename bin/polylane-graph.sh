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
    (reduce .nodes[] as $node ({};
      .[$node.id] = (reduce $node.outcomes[] as $outcome ({}; .[$outcome] = true))
    )) as $outcomes_by_node |
    all(.edges[];
      (.from | type == "string") and (.to | type == "string")
      and (.outcome | type == "string")
      and ($outcomes_by_node[.from] != null)
      and ($outcomes_by_node[.to] != null)
      and ($outcomes_by_node[.from][.outcome] == true)
    )
  ' "$graph" >/dev/null 2>&1 || invalid "edge endpoint or outcome is undeclared" || return 1

  jq -e '
    (reduce .nodes[] as $node ({};
      .[$node.id] = (reduce $node.outcomes[] as $outcome ({}; .[$outcome] = true))
    )) as $outcomes_by_node |
    all(.loops[];
      (.from | type == "string") and (.to | type == "string")
      and (.outcome | type == "string")
      and (.max_iterations | type == "number" and floor == . and . >= 1)
      and ($outcomes_by_node[.from] != null)
      and ($outcomes_by_node[.to] != null)
      and ($outcomes_by_node[.from][.outcome] == true)
    )
  ' "$graph" >/dev/null 2>&1 || invalid "loop endpoint, outcome, or max_iterations is invalid" || return 1

  jq -e '
    (reduce (.edges[], .loops[]) as $route ({}; .[$route.from] = true)) as $has_outgoing |
    all(.nodes[]; . as $node |
      if $node.kind == "terminal" then
        ($has_outgoing[$node.id] // false) == false
      else
        ($has_outgoing[$node.id] // false) == true
      end
    )
  ' "$graph" >/dev/null 2>&1 || invalid "terminal routing or nonterminal route is invalid" || return 1

  jq -e '
    . as $graph |
    def visit($adjacency; $queue; $head; $tail; $indegree; $visited):
      if $head >= $tail then $visited
      else $queue[($head | tostring)] as $node
      | (reduce (($adjacency[$node] | keys_unsorted)[]) as $next (
          {queue: $queue, tail: $tail, indegree: $indegree};
          .indegree[$next] -= $adjacency[$node][$next]
          | if .indegree[$next] == 0 then
              .queue[(.tail | tostring)] = $next | .tail += 1
            else . end
        )) as $step
      | visit($adjacency; $step.queue; $head + 1; $step.tail; $step.indegree; $visited + 1)
      end;
    # Compiler output is already topologically ordered. Prove that in one
    # linear edge scan; retain Kahn as the compatibility fallback for valid
    # hand-authored graphs whose node array uses a different order.
    (reduce ($graph.nodes | to_entries[]) as $entry ({};
      .[$entry.value.id] = $entry.key
    )) as $rank |
    if all($graph.edges[]; $rank[.from] < $rank[.to]) then true
    else
      (reduce $graph.nodes[] as $node (
        {indegree: {}, adjacency: {}};
        .indegree[$node.id] = 0 | .adjacency[$node.id] = {}
      ) |
      reduce $graph.edges[] as $edge (.;
        .indegree[$edge.to] += 1
        | .adjacency[$edge.from][$edge.to] = ((.adjacency[$edge.from][$edge.to] // 0) + 1)
      )) as $topology |
      (reduce ($topology.indegree | keys_unsorted)[] as $node (
        {queue: {}, tail: 0};
        if $topology.indegree[$node] == 0 then
          .queue[(.tail | tostring)] = $node | .tail += 1
        else . end
      )) as $initial |
      visit($topology.adjacency; $initial.queue; 0; $initial.tail; $topology.indegree; 0)
        == ($graph.nodes | length)
    end
  ' "$graph" >/dev/null 2>&1 || invalid "ordinary edges must be acyclic" || return 1

  jq -e '
    . as $graph |
    def visit($reverse; $queue; $head; $tail; $seen):
      if $head >= $tail then $seen
      else $queue[($head | tostring)] as $node
      | (reduce (($reverse[$node] | keys_unsorted)[]) as $previous (
          {queue: $queue, tail: $tail, seen: $seen};
          if .seen[$previous] == true then .
          else
            .seen[$previous] = true
            | .queue[(.tail | tostring)] = $previous
            | .tail += 1
          end
        )) as $step
      | visit($reverse; $step.queue; $head + 1; $step.tail; $step.seen)
      end;
    (reduce $graph.nodes[] as $node ({reverse: {}}; .reverse[$node.id] = {}) |
    reduce ($graph.edges[], $graph.loops[]) as $route (.;
      .reverse[$route.to][$route.from] = true
    )) as $topology |
    (reduce ($graph.nodes[] | select(.kind == "terminal") | .id) as $terminal (
      {queue: {}, tail: 0, seen: {}};
      .queue[(.tail | tostring)] = $terminal
      | .tail += 1 | .seen[$terminal] = true
    )) as $initial |
    visit($topology.reverse; $initial.queue; 0; $initial.tail; $initial.seen)
      | length == ($graph.nodes | length)
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
    (.quality_judges // null) as $quality_judges |
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
    and (if $quality_judges != null then
      ($quality_judges | type == "array" and length == 3
       and all(.[]; type == "object"
         and (.name | type == "string" and length > 0)
         and (.lens | type == "string" and length > 0)
         and (.command | type == "string" and length > 0)
         and (.timeout_s | type == "number" and floor == . and . >= 1 and . <= 300))
       and ([$quality_judges[].name] | unique | length == 3)
       and ([$quality_judges[].lens] | unique | length == 3))
     else true end)
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
    (.quality_judges? | type == "array" and length > 0) as $has_judges |
    (.visual_quality? | if . == true then true elif type == "object" then ((.enabled // true) == true) else false end) as $has_visual_quality |
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
          (if $has_visual_quality then node("visual-quality"; "verifier"; ["passed", "failed"]) else empty end),
          (if $has_visual_quality then node("visual-repair"; "repair"; ["repaired", "failed"]) else empty end),
          (if $has_judges then node("judges"; "verifier"; ["passed", "failed"]) else empty end),
          (if $has_judges then node("judge-repair"; "repair"; ["repaired", "failed"]) else empty end),
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
          {from:"verifier", to:(if $has_visual_quality then "visual-quality" elif $has_judges then "judges" else "promote" end), outcome:"passed"},
          {from:"verifier", to:"repair", outcome:"failed"},
          {from:"verifier", to:"halt", outcome:"failed"},
           {from:"repair", to:"halt", outcome:"failed"},
          (if $has_visual_quality then {from:"visual-quality", to:(if $has_judges then "judges" else "promote" end), outcome:"passed"} else empty end),
          (if $has_visual_quality then {from:"visual-quality", to:"visual-repair", outcome:"failed"} else empty end),
          (if $has_visual_quality then {from:"visual-quality", to:"halt", outcome:"failed"} else empty end),
          (if $has_visual_quality then {from:"visual-repair", to:"halt", outcome:"failed"} else empty end),
          (if $has_judges then {from:"judges", to:"promote", outcome:"passed"} else empty end),
          (if $has_judges then {from:"judges", to:"judge-repair", outcome:"failed"} else empty end),
          (if $has_judges then {from:"judges", to:"halt", outcome:"failed"} else empty end),
          (if $has_judges then {from:"judge-repair", to:"halt", outcome:"failed"} else empty end),
          {from:"promote", to:"complete", outcome:"succeeded"}
        ]
      ),
      loops: ([{from:"repair", to:"verifier", outcome:"repaired", max_iterations:1}]
        + (if $has_visual_quality then [{from:"visual-repair", to:"visual-quality", outcome:"repaired", max_iterations:2}] else [] end)
        + (if $has_judges then [{from:"judge-repair", to:"judges", outcome:"repaired", max_iterations:1}] else [] end))
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
    def node_state($id):
      ($states[$id] // "pending")
      | if type == "object" then (.state // "pending") else . end;
    def node_attempt($id):
      ($states[$id] // {})
      | if type == "object" then (.attempt // 0) else 0 end;
    def incoming($id): [($graph.edges[]), ($graph.loops[]) | select(.to == $id)];
    def incoming_loops($id): [$graph.loops[] | select(.to == $id)];
    def route_matches:
      (node_state(.from) | execution_state) == (.outcome | execution_state);
    [ $graph.nodes[]
      | . as $node
      | node_state($node.id) as $current
      | select(
          $current == "pending"
          or ($current == "failed" and (
            ($node.kind == "agent"
             and node_attempt($node.id) < ($node.retry_budget // 0))
            or any(incoming_loops($node.id)[];
              route_matches and node_attempt($node.id) < .max_iterations)
          ))
        )
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
