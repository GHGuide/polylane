#!/usr/bin/env bash
# Shared coordination relay: append-only events, mutex replay, atomic writers.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
RELAY="$ROOT/bin/polylane-coordinate.sh"
command -v jq >/dev/null 2>&1 || { pass "coordination-skipped-no-jq"; finish; exit 0; }
make_tmpdir

F="$TEST_TMPDIR/project/.polylane/coordination.jsonl"
mkdir -p "$(dirname "$F")"

assert_ok "coordination-request" "$RELAY" request "$F" alpha beta 'need public API update'
assert_ok "coordination-decision" "$RELAY" decision "$F" alpha 'keep API stable' 'compatibility'
assert_ok "coordination-claim" "$RELAY" claim "$F" alpha device-1
assert_rc "coordination-claim-conflict" 75 "$RELAY" claim "$F" beta device-1
assert_ok "coordination-release" "$RELAY" release "$F" alpha device-1
assert_ok "coordination-claim-after-release" "$RELAY" claim "$F" beta device-1

assert_eq "coordination-events-append-only" 5 "$(wc -l < "$F" | tr -d ' ')"
assert_eq "coordination-request-type" request "$(sed -n '1p' "$F" | jq -r .event)"
assert_contains "coordination-pending-request" '"to":"beta"' "$("$RELAY" pending "$F")"
assert_contains "coordination-pending-claim" '"resource":"device-1"' "$("$RELAY" pending "$F")"
SNAP=$("$RELAY" snapshot "$F")
assert_eq "coordination-snapshot-events" 5 "$(printf '%s' "$SNAP" | jq '.events | length')"
assert_eq "coordination-snapshot-current-owner" beta "$(printf '%s' "$SNAP" | jq -r '.claims["device-1"].lane')"

# Stale recovery removes only an expired lock and reacquires before append.
mkdir "$F.lock"
printf '0\n' > "$F.lock/created_at"
POLYLANE_COORDINATION_LOCK_TTL=1 assert_ok "coordination-stale-lock-recovered" "$RELAY" decision "$F" beta 'use device-1' 'claim acquired'
assert_eq "coordination-stale-lock-event-kept" 6 "$(wc -l < "$F" | tr -d ' ')"

# Two writers contend for one lock; each valid append is retained.
F2="$TEST_TMPDIR/project/.polylane/concurrent.jsonl"
( "$RELAY" decision "$F2" alpha one x ) & p1=$!
( "$RELAY" decision "$F2" beta two y ) & p2=$!
wait "$p1"; r1=$?
wait "$p2"; r2=$?
assert_eq "coordination-concurrent-first" 0 "$r1"
assert_eq "coordination-concurrent-second" 0 "$r2"
assert_eq "coordination-concurrent-no-loss" 2 "$(wc -l < "$F2" | tr -d ' ')"

finish
