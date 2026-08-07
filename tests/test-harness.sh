#!/usr/bin/env bash
# Versioned typed harness contract.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HARNESS="$ROOT/bin/polylane-harness.sh"
make_tmpdir
STORE="$TEST_TMPDIR/harness"

assert_ok "harness-initializes-store" "$HARNESS" init "$STORE"
assert_eq "harness-schema-is-versioned" "polylane-harness/v1" \
  "$(jq -r '.schema' "$STORE/state.json")"
assert_ok "harness-creates-local-prompt" "$HARNESS" create "$STORE" local prompt build-guide "run focused tests" 11
assert_eq "harness-local-entry-is-active" "true" \
  "$("$HARNESS" read "$STORE" local build-guide --json | jq -r '.active')"
assert_eq "harness-stable-id" "build-guide" \
  "$("$HARNESS" read "$STORE" local build-guide --json | jq -r '.id')"
assert_eq "harness-first-version" "1" \
  "$("$HARNESS" read "$STORE" local build-guide --json | jq -r '.version')"
assert_rc "harness-rejects-stale-cas" 6 "$HARNESS" update "$STORE" local build-guide 0 "stale edit" 12
assert_ok "harness-updates-current-version" "$HARNESS" update "$STORE" local build-guide 1 "run focused tests first" 12
assert_eq "harness-version-monotonic" "2" \
  "$("$HARNESS" read "$STORE" local build-guide --json | jq -r '.version')"
assert_eq "harness-history-has-before-after" "2" \
  "$("$HARNESS" history "$STORE" local build-guide --json | jq -s 'length')"
assert_ok "harness-rolls-back-snapshot" "$HARNESS" rollback "$STORE" local build-guide 2 1 13
assert_eq "harness-rollback-restores-content" "run focused tests" \
  "$("$HARNESS" read "$STORE" local build-guide --json | jq -r '.content')"
assert_eq "harness-rollback-creates-new-version" "3" \
  "$("$HARNESS" read "$STORE" local build-guide --json | jq -r '.version')"
assert_ok "harness-lists-typed-scope" "$HARNESS" list "$STORE" local prompt --json
assert_eq "harness-list-filter" "1" \
  "$("$HARNESS" list "$STORE" local prompt --json | jq 'length')"
assert_ok "harness-creates-global-skill-proposal" "$HARNESS" create "$STORE" global skill reviewer "proposed change" 11
GLOBAL=$("$HARNESS" read "$STORE" global reviewer --json)
assert_eq "harness-global-skill-never-active" "false" "$(printf '%s' "$GLOBAL" | jq -r '.active')"
assert_eq "harness-global-skill-names-handoff" "bin/polylane-skill-evolve.sh" \
  "$(printf '%s' "$GLOBAL" | jq -r '.handoff')"
assert_ok "harness-allows-safe-global-memory" "$HARNESS" create "$STORE" global memory run-notes "keep verifier result" 11
assert_eq "harness-global-memory-active" "true" \
  "$("$HARNESS" read "$STORE" global run-notes --json | jq -r '.active')"
assert_rc "harness-protects-base-instructions" 2 "$HARNESS" create "$STORE" local skill base "mutate base" 11
assert_ok "harness-deletes-with-cas" "$HARNESS" delete "$STORE" global run-notes 1 12
assert_rc "harness-deleted-entry-is-unreadable" 4 "$HARNESS" read "$STORE" global run-notes --json

finish
