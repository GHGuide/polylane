#!/usr/bin/env bash
# durable, bounded product-discovery graph and transcript-free lock artifacts.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
DISCOVERY="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-discovery.sh"

make_tmpdir
STATE="$TEST_TMPDIR/discovery.json"; DOCS="$TEST_TMPDIR/docs"
assert_ok "discovery-init" "$DISCOVERY" init "$STATE" "Make team shift handoffs less error-prone"
assert_eq "discovery-state-version" "schema-v1" "$(jq -r '.version' "$STATE")"
assert_eq "discovery-has-typed-nodes" "question" "$(jq -r '.nodes[0].type' "$STATE")"
assert_eq "discovery-next-default-bound" "3" "$("$DISCOVERY" next "$STATE" | jq -s 'length')"
assert_fail "discovery-rejects-too-large-next-limit" "$DISCOVERY" next "$STATE" 6
assert_fail "discovery-rejects-invalid-answer-kind" "$DISCOVERY" answer "$STATE" q-user invalid
assert_fail "discovery-requires-custom-text" "$DISCOVERY" answer "$STATE" q-user custom

assert_ok "discovery-accepts-recommended" "$DISCOVERY" answer "$STATE" q-user recommended
assert_ok "discovery-deep-activates-child" "$DISCOVERY" answer "$STATE" q-workflow deep
assert_eq "discovery-deep-created-child" "1" "$(jq '[.nodes[] | select(.parent == "q-workflow" and .active == true)] | length' "$STATE")"
assert_ok "discovery-bold-activates-child" "$DISCOVERY" answer "$STATE" q-success bold
assert_eq "discovery-answers-typed" "3" "$(jq '[.answers[] | select(.type == "answer")] | length' "$STATE")"
assert_contains "discovery-summary-strategy" "Strategy packet" "$("$DISCOVERY" summary "$STATE")"

assert_ok "discovery-lock-resolved" "$DISCOVERY" lock "$STATE" "$DOCS"
assert_ok "discovery-lock-strategy-artifact" test -s "$DOCS/strategy.md"
assert_ok "discovery-lock-north-star-artifact" test -s "$DOCS/north-star.md"
assert_ok "discovery-lock-goal-artifact" test -s "$DOCS/goal.md"

finish
