#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034 # sourced runner consumes fixture globals
# RESUME AFTER AN INTERRUPTED PROMOTION — a run whose verifier gate already
# PASSED, then failed to promote for an unrelated reason (dirty base), must
# resume straight into promotion. The graph's `ready` query correctly never
# re-offers a succeeded node, so requiring readiness unconditionally deadlocked
# the run: c43e halted with 10 restarts on 2026-08-19 with nothing wrong.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

REQUIRE_CALLS=0
graph_authority_require() { REQUIRE_CALLS=$((REQUIRE_CALLS + 1)); [ "$FAKE_READY" = 1 ]; }

# NOTE: assert_* run in a subshell, so counter-mutating calls must run directly
# and be asserted on their captured rc (same convention as test-wedge.sh).

# --- already succeeded this run -> admit without consulting readiness --------
graph_authority_node_state() { printf 'succeeded'; }
FAKE_READY=0
REQUIRE_CALLS=0
verifier_gate_admits; rcSucceeded=$?
assert_eq "succeeded-verifier-resumes"   "0" "$rcSucceeded"
assert_eq "succeeded-skips-ready-query"  "0" "$REQUIRE_CALLS"

# --- ready node -> admitted normally ----------------------------------------
graph_authority_node_state() { printf 'pending'; }
FAKE_READY=1
REQUIRE_CALLS=0
verifier_gate_admits; rcReady=$?
assert_eq "ready-verifier-admitted" "0" "$rcReady"
assert_eq "ready-consults-graph"    "1" "$REQUIRE_CALLS"

# --- every other state still fails closed ------------------------------------
FAKE_READY=0
for st in pending running failed unknown; do
  eval "graph_authority_node_state() { printf '%s' $st; }"
  assert_fail "state-$st-fails-closed" verifier_gate_admits
done

# --- authority off / unreadable replay -> falls through to the normal gate ---
graph_authority_node_state() { return 1; }
FAKE_READY=1
assert_ok "unreadable-state-defers-to-graph" verifier_gate_admits

finish
