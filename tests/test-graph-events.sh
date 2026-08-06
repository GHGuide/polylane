#!/usr/bin/env bash
# Append-only graph execution events: transition validation, replay, locking,
# and deterministic fixture generation all exercise the real command boundary.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

EVENTS="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-events.sh"
BENCH="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-graph-bench.sh"
make_tmpdir

event() {
  "$EVENTS" append "$1" run-a graph-a "$2" "$3" "$4" "$5" "$6" "${7:-}"
}

# A legal chain records immutable, contiguous events and replays canonically.
LEGAL="$TEST_TMPDIR/legal.jsonl"
assert_ok "events-legal-pending-ready"       event "$LEGAL" alpha pending ready 0 alpha-1
assert_ok "events-legal-ready-running"       event "$LEGAL" alpha ready running 1 alpha-2
assert_ok "events-legal-running-succeeded"   event "$LEGAL" alpha running succeeded 1 alpha-3 complete
assert_ok "events-legal-verify" "$EVENTS" verify "$LEGAL" run-a graph-a
assert_eq "events-legal-row-count" "3" "$(wc -l < "$LEGAL" | tr -d ' ')"
assert_eq "events-replay-canonical" \
  '{"graph_id":"graph-a","last_seq":3,"nodes":{"alpha":{"attempt":1,"state":"succeeded"}},"run_id":"run-a"}' \
  "$("$EVENTS" replay "$LEGAL" run-a graph-a)"
if [ -x /usr/bin/jq ]; then
  SYSTEM_JQ_LEDGER="$TEST_TMPDIR/system-jq.jsonl"
  assert_rc "events-append-with-system-jq" 0 env PATH=/usr/bin:/bin \
    "$EVENTS" append "$SYSTEM_JQ_LEDGER" run-a graph-a alpha pending ready 0 system-jq-1
fi

# Disposable checkpoint corruption must never change replayed state.  A valid
# but stale checkpoint is also rejected when the ledger inode changes, and a
# complete-row ledger truncation strictly replays the shorter JSONL history.
cp "$LEGAL.checkpoint" "$TEST_TMPDIR/legal-valid.checkpoint"
printf '{malformed checkpoint\n' > "$LEGAL.checkpoint"
assert_eq "events-malformed-checkpoint-exact-replay" \
  '{"graph_id":"graph-a","last_seq":3,"nodes":{"alpha":{"attempt":1,"state":"succeeded"}},"run_id":"run-a"}' \
  "$("$EVENTS" replay "$LEGAL" run-a graph-a)"
cp "$TEST_TMPDIR/legal-valid.checkpoint" "$LEGAL.checkpoint"
cp "$LEGAL" "$TEST_TMPDIR/legal-replaced.jsonl"
mv "$TEST_TMPDIR/legal-replaced.jsonl" "$LEGAL"
assert_eq "events-replaced-ledger-strict-replay" \
  '{"graph_id":"graph-a","last_seq":3,"nodes":{"alpha":{"attempt":1,"state":"succeeded"}},"run_id":"run-a"}' \
  "$("$EVENTS" replay "$LEGAL" run-a graph-a)"
sed '$d' "$LEGAL" > "$TEST_TMPDIR/legal-truncated.jsonl"
mv "$TEST_TMPDIR/legal-truncated.jsonl" "$LEGAL"
assert_eq "events-complete-row-truncation-strict-replay" \
  '{"graph_id":"graph-a","last_seq":2,"nodes":{"alpha":{"attempt":1,"state":"running"}},"run_id":"run-a"}' \
  "$("$EVENTS" replay "$LEGAL" run-a graph-a)"

# Each rejection names the mutable behavior it protects.
ILLEGAL="$TEST_TMPDIR/illegal.jsonl"
assert_fail "events-illegal-transition" event "$ILLEGAL" alpha pending running 0 illegal-1
assert_ok   "events-illegal-setup" event "$ILLEGAL" alpha pending ready 0 illegal-2
assert_fail "events-wrong-from-state" event "$ILLEGAL" alpha pending blocked 0 illegal-3
assert_fail "events-malformed-node-id" event "$ILLEGAL" 'alpha/bad' ready blocked 0 illegal-4
assert_fail "events-malformed-leading-node-id" event "$ILLEGAL" '.alpha' pending ready 0 illegal-4a
assert_fail "events-wrong-graph" "$EVENTS" append "$ILLEGAL" run-a graph-other alpha ready blocked 0 illegal-5

TERMINAL="$TEST_TMPDIR/terminal.jsonl"
assert_ok "events-terminal-ready" event "$TERMINAL" alpha pending ready 0 terminal-1
assert_ok "events-terminal-running" event "$TERMINAL" alpha ready running 1 terminal-2
assert_ok "events-terminal-succeeded" event "$TERMINAL" alpha running succeeded 1 terminal-3
assert_fail "events-terminal-mutation" event "$TERMINAL" alpha succeeded blocked 1 terminal-4

IDEM="$TEST_TMPDIR/idempotent.jsonl"
assert_ok "events-idempotent-first" event "$IDEM" alpha pending ready 0 idem-1 same
assert_ok "events-idempotent-duplicate" event "$IDEM" alpha pending ready 0 idem-1 same
assert_eq "events-idempotent-one-row" "1" "$(wc -l < "$IDEM" | tr -d ' ')"
assert_fail "events-idempotency-conflict" event "$IDEM" alpha ready running 1 idem-1 changed

# Hand-authored bad rows prove verify identifies history corruption, not merely
# failures at the append boundary.
GAP="$TEST_TMPDIR/gap.jsonl"
printf '%s\n' '{"event_schema":1,"seq":2,"timestamp":1700000001,"run_id":"run-a","graph_id":"graph-a","node":"alpha","from":"pending","to":"ready","attempt":0,"idempotency_key":"gap-1","reason":"","artifact_hash":""}' > "$GAP"
gap_out=$("$EVENTS" verify "$GAP" run-a graph-a 2>&1); gap_rc=$?
assert_eq "events-sequence-gap-rc" "2" "$gap_rc"
assert_contains "events-sequence-gap-message" "EVENT-INVALID:" "$gap_out"
assert_eq "events-sequence-gap-one-message" "1" "$(printf '%s\n' "$gap_out" | grep -c '^EVENT-INVALID:')"

MIXED="$TEST_TMPDIR/mixed.jsonl"
printf '%s\n' '{"event_schema":1,"seq":1,"timestamp":1700000001,"run_id":"other-run","graph_id":"graph-a","node":"alpha","from":"pending","to":"ready","attempt":0,"idempotency_key":"mixed-1","reason":"","artifact_hash":""}' > "$MIXED"
assert_rc "events-mixed-run-id" 2 "$EVENTS" verify "$MIXED" run-a graph-a

CORRUPT="$TEST_TMPDIR/corrupt.jsonl"
printf '%s\n' '{not-json' > "$CORRUPT"
corrupt_out=$("$EVENTS" verify "$CORRUPT" run-a graph-a 2>&1); corrupt_rc=$?
assert_eq "events-corrupt-line-rc" "2" "$corrupt_rc"
assert_contains "events-corrupt-line-message" "EVENT-INVALID:" "$corrupt_out"

# Identical histories yield byte-identical canonical replay, including node key order.
REPLAY_A="$TEST_TMPDIR/replay-a.jsonl"
REPLAY_B="$TEST_TMPDIR/replay-b.jsonl"
for ledger in "$REPLAY_A" "$REPLAY_B"; do
  event "$ledger" zeta pending ready 0 replay-z >/dev/null
  event "$ledger" beta pending blocked 0 replay-b waiting >/dev/null
done
assert_eq "events-deterministic-replay" "$("$EVENTS" replay "$REPLAY_A" run-a graph-a)" "$("$EVENTS" replay "$REPLAY_B" run-a graph-a)"
assert_eq "events-empty-replay" \
  '{"graph_id":"graph-a","last_seq":0,"nodes":{},"run_id":"run-a"}' \
  "$("$EVENTS" replay "$TEST_TMPDIR/empty.jsonl" run-a graph-a)"

# Simultaneous appends must serialize without losing either complete JSONL row.
CONCURRENT="$TEST_TMPDIR/concurrent.jsonl"
event "$CONCURRENT" alpha pending ready 0 concurrent-alpha >/dev/null 2>&1 & first_pid=$!
event "$CONCURRENT" beta pending ready 0 concurrent-beta >/dev/null 2>&1 & second_pid=$!
wait "$first_pid"; first_rc=$?
wait "$second_pid"; second_rc=$?
assert_eq "events-concurrent-first-rc" "0" "$first_rc"
assert_eq "events-concurrent-second-rc" "0" "$second_rc"
assert_eq "events-concurrent-two-rows" "2" "$(wc -l < "$CONCURRENT" | tr -d ' ')"
assert_ok "events-concurrent-verify" "$EVENTS" verify "$CONCURRENT" run-a graph-a

# Break caught: compiling the production-schema 10,000-lane fixture regresses
# to superlinear graph validation and wedges this focused suite for minutes.
# Keep the full fixture, but bound one real public-CLI build.  The CPU limit
# ensures a pathological jq child cannot leave the suite stuck indefinitely;
# the wall assertion catches equivalent multi-process regressions.
FIXTURE="$TEST_TMPDIR/fixture"
FIXTURE_COPY="$TEST_TMPDIR/fixture-copy"
FIXTURE_LIMIT_SECONDS=10
[ -n "${CI:-}" ] && FIXTURE_LIMIT_SECONDS=20
fixture_bounded() (
  ulimit -t "$FIXTURE_LIMIT_SECONDS"
  "$BENCH" fixture "$1" 10000 10000
)
fixture_started=$(date +%s)
fixture_bounded "$FIXTURE"
fixture_rc=$?
fixture_elapsed=$(( $(date +%s) - fixture_started ))
assert_eq "events-fixture-10000-linear-time-rc" "0" "$fixture_rc"
case "$fixture_elapsed" in
  ''|*[!0-9]*) fixture_within_limit=false ;;
  *) [ "$fixture_elapsed" -le "$FIXTURE_LIMIT_SECONDS" ] && fixture_within_limit=true || fixture_within_limit=false ;;
esac
assert_eq "events-fixture-10000-linear-time" "true" "$fixture_within_limit"
printf 'TIMING events-fixture-10000=%ss\n' "$fixture_elapsed"
assert_eq "events-fixture-10000-rows" "10000" "$(wc -l < "$FIXTURE/events.jsonl" | tr -d ' ')"
assert_eq "events-fixture-lane-count" "10000" \
  "$(jq '[.nodes[] | select(.id | startswith("lane:"))] | length' "$FIXTURE/graph.json")"
FIXTURE_GRAPH_ID=$(jq -r '.graph_id' "$FIXTURE/graph.json")
assert_ok "events-fixture-10000-valid" "$EVENTS" verify "$FIXTURE/events.jsonl" fixture-run "$FIXTURE_GRAPH_ID"
assert_ok "events-fixture-copy-create" fixture_bounded "$FIXTURE_COPY"
assert_ok "events-fixture-deterministic" cmp "$FIXTURE/events.jsonl" "$FIXTURE_COPY/events.jsonl"

finish
