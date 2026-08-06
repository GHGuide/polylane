#!/usr/bin/env bash
# Production graph/event benchmark contract.  It intentionally uses only the
# public CLIs and a deterministic 64-lane, 10,000-event fixture.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRAPH="$ROOT/bin/polylane-graph.sh"
EVENTS="$ROOT/bin/polylane-events.sh"
BENCH="$ROOT/bin/polylane-graph-bench.sh"

make_tmpdir
FIXTURE="$TEST_TMPDIR/fixture"

# Break caught: the benchmark fixture must be accepted by the same production
# graph and ledger validators used by scheduling; otherwise timing it proves
# nothing about the real execution path.
assert_ok "benchmark-fixture-build" "$BENCH" fixture "$FIXTURE" 64 10000
GRAPH_ID="$(jq -r '.graph_id' "$FIXTURE/graph.json")"
assert_ok "benchmark-fixture-graph-valid" "$GRAPH" validate "$FIXTURE/graph.json"
assert_eq "benchmark-fixture-has-64-lanes" "64" "$(jq '[.nodes[] | select(.id | startswith("lane:"))] | length' "$FIXTURE/graph.json")"
assert_ok "benchmark-fixture-ledger-valid" "$EVENTS" verify "$FIXTURE/events.jsonl" fixture-run "$GRAPH_ID"
assert_eq "benchmark-fixture-ledger-nodes-declared" "0" "$(
  jq -s --slurpfile graph "$FIXTURE/graph.json" '
    reduce $graph[0].nodes[].id as $id ({}; .[$id] = true) as $declared
    | [.[] | select($declared[.node] != true)] | length
  ' "$FIXTURE/events.jsonl"
)"

# Break caught: the frozen packet must drive the public production CLIs over
# the valid fixture, including a warm ready query and append.
assert_ok "benchmark-ready-query" "$GRAPH" ready "$FIXTURE/graph.json" "$FIXTURE/state.json"
assert_ok "benchmark-warm-append" "$EVENTS" append "$FIXTURE/events.jsonl" fixture-run "$GRAPH_ID" start pending ready 0 fixture-start-ready synthetic
assert_ok "benchmark-replay" "$EVENTS" replay "$FIXTURE/events.jsonl" fixture-run "$GRAPH_ID"

# Break caught: a successful append records only a disposable, exact-ledger
# checkpoint.  The sidecar is an optimization, never an alternate audit log.
assert_ok "benchmark-checkpoint-created" test -f "$FIXTURE/events.jsonl.checkpoint"

# Bash 3.2 has no monotonic millisecond clock.  Its `time` keyword still emits
# a fractional real-time value, which is enough for behavior-focused ceilings.
elapsed_ms() {
  local result rc
  TIMEFORMAT='%3R'
  result=$({ time "$@"; } 2>&1 >/dev/null)
  rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  awk -v seconds="$result" 'BEGIN { printf "%.0f\n", seconds * 1000 }'
}

assert_under_ms() {
  local name="$1" limit="$2" elapsed within="false"
  shift 2
  if ! elapsed=$(elapsed_ms "$@"); then
    assert_eq "$name" "true" "false"
    return
  fi
  case "$elapsed" in
    ''|*[!0-9]*) within="false" ;;
    *) [ "$elapsed" -le "$limit" ] && within="true" ;;
  esac
  assert_eq "$name" "true" "$within"
  printf 'TIMING %s=%sms\n' "$name" "$elapsed"
}

# Break caught: repeated scheduling must use the validated checkpoint.  This
# is deliberately a warm measurement; setup and strict first replay are not
# hidden inside the timing assertion.
assert_under_ms "benchmark-warm-ready-under-250ms" 250 "$GRAPH" ready "$FIXTURE/graph.json" "$FIXTURE/state.json"
assert_under_ms "benchmark-warm-append-under-250ms" 250 "$EVENTS" append "$FIXTURE/events.jsonl" fixture-run "$GRAPH_ID" builders-joined pending ready 0 fixture-join-ready synthetic

# Cache-corruption safety: malformed derived data must be discarded and rebuilt
# from JSONL, while replacing or truncating JSONL must never inherit a stale
# successful checkpoint.
printf '{malformed checkpoint\n' > "$FIXTURE/events.jsonl.checkpoint"
assert_ok "benchmark-malformed-checkpoint-strict-replay" "$EVENTS" replay "$FIXTURE/events.jsonl" fixture-run "$GRAPH_ID"
assert_ok "benchmark-checkpoint-rebuilt" "$EVENTS" append "$FIXTURE/events.jsonl" fixture-run "$GRAPH_ID" integrator pending ready 0 fixture-integrator-ready synthetic
cp "$FIXTURE/events.jsonl" "$TEST_TMPDIR/replaced-events.jsonl"
printf '{truncated' >> "$TEST_TMPDIR/replaced-events.jsonl"
mv "$TEST_TMPDIR/replaced-events.jsonl" "$FIXTURE/events.jsonl"
assert_rc "benchmark-replaced-truncated-ledger-fails-closed" 2 "$EVENTS" replay "$FIXTURE/events.jsonl" fixture-run "$GRAPH_ID"

packet() {
  local dir="$1" packet_graph_id
  "$BENCH" fixture "$dir" 64 10000 || return $?
  packet_graph_id=$(jq -r '.graph_id' "$dir/graph.json") || return 1
  "$GRAPH" validate "$dir/graph.json" || return $?
  "$EVENTS" verify "$dir/events.jsonl" fixture-run "$packet_graph_id" || return $?
  "$GRAPH" ready "$dir/graph.json" "$dir/state.json" >/dev/null || return $?
  "$EVENTS" append "$dir/events.jsonl" fixture-run "$packet_graph_id" start pending ready 0 fixture-packet-ready synthetic || return $?
  "$EVENTS" verify "$dir/events.jsonl" fixture-run "$packet_graph_id" || return $?
  "$EVENTS" replay "$dir/events.jsonl" fixture-run "$packet_graph_id" >/dev/null
}

PACKET_LIMIT_MS=10000
[ -n "${CI:-}" ] && PACKET_LIMIT_MS=20000
assert_under_ms "benchmark-packet-sample-1" "$PACKET_LIMIT_MS" packet "$TEST_TMPDIR/packet-1"
assert_under_ms "benchmark-packet-sample-2" "$PACKET_LIMIT_MS" packet "$TEST_TMPDIR/packet-2"
assert_under_ms "benchmark-packet-sample-3" "$PACKET_LIMIT_MS" packet "$TEST_TMPDIR/packet-3"

finish
