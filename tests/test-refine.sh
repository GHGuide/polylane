#!/usr/bin/env bash
# Evidence-gated refinement lifecycle contract.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HARNESS="$ROOT/bin/polylane-harness.sh"
REFINE="$ROOT/bin/polylane-refine.sh"
make_tmpdir
STORE="$TEST_TMPDIR/harness"

assert_ok "refine-initializes-harness-state" "$HARNESS" init "$STORE"
assert_ok "refine-creates-baseline" "$HARNESS" create "$STORE" local memory retry-policy "retry once" 11
assert_ok "refine-records-first-failure" "$REFINE" observe "$STORE" 11 failure retry-policy "tests/test-api.sh failed"
assert_ok "refine-records-compaction-observation" "$REFINE" observe "$STORE" 11 compaction context-packet "packet lost verifier context"
assert_rc "refine-one-off-is-not-eligible" 3 "$REFINE" eligible "$STORE" retry-policy
assert_ok "refine-records-repeated-failure" "$REFINE" observe "$STORE" 12 failure retry-policy "tests/test-api.sh failed again"
assert_ok "refine-repeated-signal-is-eligible" "$REFINE" eligible "$STORE" retry-policy
assert_ok "refine-proposes-versioned-change" "$REFINE" propose "$STORE" retry-2 12 14 local memory retry-policy 1 "retry with backoff" "two failures" -- test -f "$STORE/state.json"
assert_eq "refine-proposal-has-evidence" "two failures" \
  "$(jq -r '.proposals["retry-2"].evidence' "$STORE/refinements.json")"
assert_eq "refine-proposal-has-executable-outcome" "test" \
  "$(jq -r '.proposals["retry-2"].expected_check[0]' "$STORE/refinements.json")"
assert_eq "refine-proposal-created-cycle" "12" \
  "$(jq -r '.proposals["retry-2"].created_cycle' "$STORE/refinements.json")"
assert_rc "refine-cannot-validate-same-cycle" 3 "$REFINE" validate "$STORE" 12 retry-2
assert_ok "refine-validates-later-cycle" "$REFINE" validate "$STORE" 13 retry-2
assert_eq "refine-pass-is-validated" "validated" \
  "$(jq -r '.proposals["retry-2"].status' "$STORE/refinements.json")"

assert_ok "refine-records-stall" "$REFINE" observe "$STORE" 13 stall retry-policy "worker stalled"
assert_ok "refine-records-second-stall" "$REFINE" observe "$STORE" 14 stall retry-policy "worker stalled again"
assert_ok "refine-proposes-failing-change" "$REFINE" propose "$STORE" retry-fail 14 16 local memory retry-policy 2 "bad retry" "repeated stalls" -- false
assert_rc "refine-failing-check-rolls-back" 7 "$REFINE" validate "$STORE" 15 retry-fail
assert_eq "refine-failure-restores-snapshot" "retry with backoff" \
  "$("$HARNESS" read "$STORE" local retry-policy --json | jq -r '.content')"
assert_eq "refine-failure-is-recorded" "rolled_back" \
  "$(jq -r '.proposals["retry-fail"].status' "$STORE/refinements.json")"

assert_ok "refine-records-no-go" "$REFINE" observe "$STORE" 15 no-go prompt-note "NO-GO verifier"
assert_ok "refine-records-second-no-go" "$REFINE" observe "$STORE" 16 no-go prompt-note "NO-GO verifier again"
assert_ok "refine-proposes-global-prompt-only" "$REFINE" propose "$STORE" global-prompt 16 17 global prompt prompt-note 0 "never direct" "two NO-GOs" -- true
assert_eq "refine-never-promotes-global-prompt" "false" \
  "$("$HARNESS" read "$STORE" global prompt-note --json | jq -r '.active')"
assert_eq "refine-global-prompt-handoff" "bin/polylane-skill-evolve.sh" \
  "$("$HARNESS" read "$STORE" global prompt-note --json | jq -r '.handoff')"
assert_rc "refine-expired-proposal-rolls-back" 7 "$REFINE" validate "$STORE" 18 global-prompt
assert_rc "refine-expired-created-entry-is-removed" 4 "$HARNESS" read "$STORE" global prompt-note --json
assert_eq "refine-decisions-append-only" "3" "$(wc -l < "$STORE/refinement-decisions.jsonl" | tr -d ' ')"

finish
