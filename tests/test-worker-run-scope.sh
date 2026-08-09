#!/usr/bin/env bash
# Worker inbox scope is opt-in: a nonce sees only its own durable history.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
WORKERS="$ROOT/bin/polylane-workers.sh"
command -v jq >/dev/null 2>&1 || { pass "worker-run-scope-skipped-no-jq"; finish; exit 0; }
make_tmpdir
unset POLYLANE_PROJECT_ROOT POLYLANE_WORKERS_DIR POLYLANE_WORKER_RUN_ID

PROJECT="$TEST_TMPDIR/project"
mkdir -p "$PROJECT/.polylane"
assert_ok "worker-run-scope-create-alpha" "$WORKERS" capsule "$PROJECT" alpha 0 builder 24 active alpha context evidence
assert_ok "worker-run-scope-create-beta" "$WORKERS" capsule "$PROJECT" beta 0 builder 24 active beta context evidence

OLD_ID=$(env POLYLANE_WORKER_RUN_ID=old-run "$WORKERS" send "$PROJECT" alpha beta 24 old-message | jq -r .id)
NEW_ID=$(env POLYLANE_WORKER_RUN_ID=new-run "$WORKERS" send "$PROJECT" alpha beta 24 new-message | jq -r .id)
LEGACY_ID=$("$WORKERS" send "$PROJECT" alpha beta 24 legacy-message | jq -r .id)

RELAY="$PROJECT/.polylane/coordination.jsonl"
printf '%s\n' '{"event":"request","lane":"alpha","to":"beta","message":"relay-request","seq":1,"at":"2026-08-10T00:00:00Z"}' > "$RELAY"
assert_ok "worker-run-scope-import-old-relay" env POLYLANE_WORKER_RUN_ID=old-run "$WORKERS" import-relay "$PROJECT" "$RELAY" 24
printf '%s\n' '{"event":"request","lane":"alpha","to":"beta","message":"relay-request-new","seq":2,"at":"2026-08-10T00:00:01Z"}' >> "$RELAY"
assert_ok "worker-run-scope-import-new-relay" env POLYLANE_WORKER_RUN_ID=new-run "$WORKERS" import-relay "$PROJECT" "$RELAY" 24

assert_eq "worker-run-scope-scoped-inbox-only-current" 2 "$(env POLYLANE_WORKER_RUN_ID=new-run "$WORKERS" inbox "$PROJECT" beta | jq length)"
assert_eq "worker-run-scope-scoped-inbox-events-carry-run" true "$(env POLYLANE_WORKER_RUN_ID=new-run "$WORKERS" inbox "$PROJECT" beta | jq 'all(.[]; .run_id == "new-run")')"
assert_eq "worker-run-scope-legacy-inbox-retains-history" 5 "$("$WORKERS" inbox "$PROJECT" beta | jq length)"
assert_rc "worker-run-scope-ack-rejects-old-event" 4 env POLYLANE_WORKER_RUN_ID=new-run "$WORKERS" ack "$PROJECT" beta "$OLD_ID"
assert_ok "worker-run-scope-ack-current-event" env POLYLANE_WORKER_RUN_ID=new-run "$WORKERS" ack "$PROJECT" beta "$NEW_ID"
assert_ok "worker-run-scope-legacy-ack-retains-all-history-api" "$WORKERS" ack "$PROJECT" beta "$OLD_ID"
assert_eq "worker-run-scope-legacy-message-is-unscoped" 1 "$("$WORKERS" inbox "$PROJECT" beta | jq --arg id "$LEGACY_ID" '[.[] | select(.id == $id)] | length')"
assert_fail "worker-run-scope-rejects-invalid-run-id" env POLYLANE_WORKER_RUN_ID='bad/run' "$WORKERS" inbox "$PROJECT" beta
LONG_RUN_ID=$(printf '%129s' '' | tr ' ' a)
assert_fail "worker-run-scope-rejects-overlong-run-id" env POLYLANE_WORKER_RUN_ID="$LONG_RUN_ID" "$WORKERS" inbox "$PROJECT" beta

finish
