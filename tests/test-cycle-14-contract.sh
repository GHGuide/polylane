#!/usr/bin/env bash
# Cycle-14 self-hosting truth: runner promotion, recovery, canonical workers,
# and selected-skill delivery stay jointly true on the integration tree.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CERTIFY="$ROOT/bin/polylane-certify.sh"

assert_ok "cycle14-promotion-transaction" bash "$ROOT/tests/test-promotion-transaction.sh"
assert_ok "cycle14-failed-promotion-report-truth" bash "$ROOT/tests/test-write-report.sh"
assert_ok "cycle14-quiet-live-turn-grace" bash "$ROOT/tests/test-wedge.sh"
assert_ok "cycle14-dead-worker-recovery" bash "$ROOT/tests/test-runtime-recovery.sh"
assert_ok "cycle14-canonical-worker-api" bash "$ROOT/tests/test-workers.sh"
assert_ok "cycle14-cross-worktree-ledger" bash "$ROOT/tests/test-worker-canonical-state.sh"
assert_ok "cycle14-selected-skill-catalog" bash "$ROOT/tests/test-scout-catalog.sh"
assert_ok "cycle14-selected-skill-admission" bash "$ROOT/tests/test-skill-acquire.sh"
assert_ok "cycle14-selected-skill-prompt" bash "$ROOT/tests/test-prompt-compiler.sh"
assert_ok "cycle14-selected-skill-use-audit" bash "$ROOT/tests/test-skill-delivery.sh"
assert_ok "cycle14-legacy-skill-fixture-migrates" bash "$ROOT/tests/test-cycle-13-contract.sh"
assert_ok "cycle14-prime-hybrid-worker-root-is-hermetic" bash "$ROOT/tests/test-prime-hybrid-integration.sh"
assert_contains "cycle14-certify-names-self-hosting-truth" "tests self-hosting-truth test-cycle-14-contract.sh" "$(cat "$CERTIFY")"

finish
