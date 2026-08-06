#!/usr/bin/env bash
# schema-v1 graph compiler and admission-routing contract.  Each assertion
# exercises the CLI against concrete JSON, rather than inspecting source text.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

GRAPH="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-graph.sh"

make_tmpdir
MANIFEST="$TEST_TMPDIR/manifest.json"
GRAPH_OUT="$TEST_TMPDIR/graph.json"

cat > "$MANIFEST" <<'JSON'
{
  "orchestration_contract": 2,
  "run_id": "graph-c2-1786031267",
  "cycle": 2,
  "target_subgoals": ["g1", "g2"],
  "integrator": {
    "name": "integrator",
    "model": "gpt-strong",
    "effort": "xhigh"
  },
  "lanes": [
    {
      "name": "beta",
      "model": "gpt-fast",
      "effort": "high",
      "own_globs": ["lib/beta/**"],
      "target_subgoals": ["g2"]
    },
    {
      "name": "alpha",
      "model": "gpt-fast",
      "effort": "high",
      "own_globs": ["lib/alpha/**"],
      "target_subgoals": ["g1"]
    }
  ]
}
JSON

# Break caught: compiling a v2 manifest omits a required graph invariant or is
# nondeterministic for identical bytes.
assert_rc "graph-compile-rc0" 0 "$GRAPH" compile "$MANIFEST" "$GRAPH_OUT"
assert_ok "graph-compile-json" jq -e . "$GRAPH_OUT"
assert_eq "graph-schema" "1" "$(jq -r '.graph_schema' "$GRAPH_OUT")"
assert_eq "graph-run-id" "graph-c2-1786031267" "$(jq -r '.run_id' "$GRAPH_OUT")"
assert_eq "graph-cycle" "2" "$(jq -r '.cycle' "$GRAPH_OUT")"
assert_eq "graph-immutable" "true" "$(jq -r '.immutable' "$GRAPH_OUT")"
assert_eq "graph-all-node-ids-unique" "10" "$(jq '[.nodes[].id] | unique | length' "$GRAPH_OUT")"
assert_eq "graph-lane-node-ids-sorted" $'lane:alpha\nlane:beta' \
  "$(jq -r '.nodes[] | select(.id | startswith("lane:")) | .id' "$GRAPH_OUT")"
assert_eq "graph-lane-alpha-globs" "lib/alpha/**" \
  "$(jq -r '.nodes[] | select(.id=="lane:alpha") | .write_globs[]' "$GRAPH_OUT")"
assert_eq "graph-integrator-merge-owner" "0" \
  "$(jq '.nodes[] | select(.id=="integrator") | .write_globs | length' "$GRAPH_OUT")"
assert_eq "graph-agents-have-contract" "0" \
  "$(jq '[.nodes[] | select(.kind=="agent") | select((.model|type)!="string" or (.effort|type)!="string" or (.target_subgoals|type)!="array" or (.write_globs|type)!="array" or (.timeout_s|type)!="number" or (.retry_budget|type)!="number" or (.evidence|type)!="object")] | length' "$GRAPH_OUT")"
assert_eq "graph-bounded-repair-loop" "1" "$(jq '.loops | length' "$GRAPH_OUT")"
assert_ok "graph-compile-valid" "$GRAPH" validate "$GRAPH_OUT"

cp "$GRAPH_OUT" "$TEST_TMPDIR/first.json"
assert_rc "graph-compile-repeat-rc0" 0 "$GRAPH" compile "$MANIFEST" "$GRAPH_OUT"
assert_ok "graph-compile-deterministic" cmp -s "$TEST_TMPDIR/first.json" "$GRAPH_OUT"

# Break caught: independent fan-out builders are serialized or a blocked
# successor is admitted before all ordinary predecessors have succeeded.
cat > "$TEST_TMPDIR/start-succeeded.json" <<'JSON'
{"nodes":{"start":"succeeded"}}
JSON
assert_eq "ready-parallel-builders" $'lane:alpha\nlane:beta' \
  "$("$GRAPH" ready "$GRAPH_OUT" "$TEST_TMPDIR/start-succeeded.json")"
cat > "$TEST_TMPDIR/one-builder-succeeded.json" <<'JSON'
{"nodes":{"start":"succeeded","lane:alpha":"succeeded"}}
JSON
assert_eq "ready-blocked-join" "lane:beta" \
  "$("$GRAPH" ready "$GRAPH_OUT" "$TEST_TMPDIR/one-builder-succeeded.json")"
cat > "$TEST_TMPDIR/builders-succeeded.json" <<'JSON'
{"nodes":{"start":"succeeded","lane:alpha":"succeeded","lane:beta":"succeeded"}}
JSON
assert_eq "ready-join-after-builders" "builders-joined" \
  "$("$GRAPH" ready "$GRAPH_OUT" "$TEST_TMPDIR/builders-succeeded.json")"

# Break caught: a fan-in join ignores a declared loop predecessor and can run
# before that route has reached its declared successful outcome.
jq '.loops += [{from:"repair", to:"builders-joined", outcome:"repaired", max_iterations:1}]' \
  "$GRAPH_OUT" > "$TEST_TMPDIR/join-loop-graph.json"
assert_ok "graph-join-loop-fixture-valid" "$GRAPH" validate "$TEST_TMPDIR/join-loop-graph.json"
assert_eq "ready-join-blocked-by-unmatched-loop-predecessor" "" \
  "$("$GRAPH" ready "$TEST_TMPDIR/join-loop-graph.json" "$TEST_TMPDIR/builders-succeeded.json")"

# Break caught: a join requires every declared predecessor to take its declared
# route, while an ordinary node is admitted by one matching route.  The graph
# outcomes `passed` and `repaired` are terminal successful execution states.
cat > "$TEST_TMPDIR/verifier-passed.json" <<'JSON'
{"nodes":{"start":"succeeded","lane:alpha":"succeeded","lane:beta":"succeeded","builders-joined":"succeeded","integrator":"succeeded","verifier":"passed"}}
JSON
assert_eq "ready-passed-route-normalizes-success" "promote" \
  "$("$GRAPH" ready "$GRAPH_OUT" "$TEST_TMPDIR/verifier-passed.json")"
cat > "$TEST_TMPDIR/failed-builder.json" <<'JSON'
{"nodes":{"start":"succeeded","lane:alpha":"succeeded","lane:beta":"failed"}}
JSON
assert_eq "ready-ordinary-failed-route" "halt" \
  "$("$GRAPH" ready "$GRAPH_OUT" "$TEST_TMPDIR/failed-builder.json")"

# Break caught: the validator accepts a structurally unsafe graph.  Every bad
# graph must have one actionable GRAPH-INVALID line and exit 2.
invalid_graph() {
  local filter="$1" out rc
  if ! jq "$filter" "$GRAPH_OUT" > "$TEST_TMPDIR/invalid.json"; then
    fail "invalid-fixture-$2" "could not create invalid graph"
    return
  fi
  out=$("$GRAPH" validate "$TEST_TMPDIR/invalid.json" 2>&1) || rc=$?
  assert_eq "invalid-rc-$2" "2" "${rc:-0}"
  assert_eq "invalid-line-$2" "1" "$(printf '%s\n' "$out" | grep -c '^GRAPH-INVALID:')"
}

invalid_graph '.nodes[1].id = .nodes[0].id' duplicate-id
invalid_graph '.edges[0].to = "missing"' missing-endpoint
invalid_graph '.nodes |= map(if .id=="promote" then .kind="terminal" else . end)' terminal-route
invalid_graph 'del(.edges[] | select(.from=="promote"))' missing-route
invalid_graph '.edges += [{from:"integrator",to:"builders-joined",outcome:"succeeded"}]' ordinary-cycle
invalid_graph '.loops[0].max_iterations = 0' loop-zero
invalid_graph 'del(.edges[] | select((.from=="verifier" and .to=="promote") or (.from=="repair" and .to=="halt")))' no-terminal-path
invalid_graph '(.nodes[] | select(.id=="lane:alpha")) |= del(.evidence)' malformed-agent
# Break caught: outcome names cease to be usable as deterministic routing keys.
invalid_graph '(.nodes[] | select(.id=="start")).outcomes = [1] | (.edges[] | select(.from=="start")).outcome = 1' non-string-outcome

finish
