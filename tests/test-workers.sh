#!/usr/bin/env bash
# polylane-workers.sh — durable worker capsules, inbox, acknowledgements, relay import.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
WORKERS="$ROOT/bin/polylane-workers.sh"
command -v jq >/dev/null 2>&1 || { pass "workers-skipped-no-jq"; finish; exit 0; }
make_tmpdir

# This is an ordinary standalone-project fixture, not a runner-launched lane.
unset POLYLANE_PROJECT_ROOT POLYLANE_WORKERS_DIR

PROJECT="$TEST_TMPDIR/project"
mkdir -p "$PROJECT/.polylane"

# Reads must not silently create an identity or runtime directory.
assert_rc "workers-missing-identity-explicit" 4 "$WORKERS" show "$PROJECT" alpha
assert_eq "workers-read-does-not-create-runtime" no "$( [ -e "$PROJECT/docs/polylane/workers" ] && printf yes || printf no )"

# Durable worker state is not a credential store.  Reject credential-shaped
# input before the runtime exists, so a failed write leaves no residue.
assert_fail "workers-capsule-rejects-secret" "$WORKERS" capsule "$PROJECT" secretless 0 builder 11 active 'api_key=sk-example-token' context evidence
assert_eq "workers-secret-rejects-write" no "$( [ -e "$PROJECT/docs/polylane/workers/capsules/secretless.json" ] && printf yes || printf no )"
assert_fail "workers-capsule-rejects-standalone-sk-token" "$WORKERS" capsule "$PROJECT" standalone-secret 0 builder 11 active 'sk-example-token' context evidence

# Ordinary hyphenated prose must not be rejected just because it contains the
# letters `sk-` inside a word. A real standalone sk- token remains covered by
# the standalone-token rejection immediately above.
assert_ok "workers-capsule-allows-risk-assessment" "$WORKERS" capsule "$PROJECT" assessment 0 builder 11 active 'complete the risk-assessment before release' context evidence

# A named capsule persists stable identity and bounded working context.
assert_ok "workers-create-alpha" "$WORKERS" capsule "$PROJECT" alpha 0 builder 11 active 'keeps the public API stable' 'inspect relay contract and tests' 'bash tests/test-workers.sh'
ALPHA=$("$WORKERS" show "$PROJECT" alpha)
assert_eq "workers-capsule-name-persistent" alpha "$(printf '%s' "$ALPHA" | jq -r .name)"
assert_eq "workers-capsule-role-persistent" builder "$(printf '%s' "$ALPHA" | jq -r .role)"
assert_eq "workers-capsule-cycle-persistent" 11 "$(printf '%s' "$ALPHA" | jq -r .last_cycle)"
assert_eq "workers-capsule-version-created" 1 "$(printf '%s' "$ALPHA" | jq -r .version)"

# Byte limits fail before a transcript-sized capsule is written.
assert_fail "workers-capsule-summary-bound" env POLYLANE_WORKER_SUMMARY_MAX_BYTES=8 "$WORKERS" capsule "$PROJECT" oversized 0 builder 11 active 'this is too long' context evidence
assert_eq "workers-bound-rejects-write" no "$( [ -e "$PROJECT/docs/polylane/workers/capsules/oversized.json" ] && printf yes || printf no )"

# Updates are compare-and-swap: only the expected current version may write.
assert_ok "workers-capsule-cas-update" "$WORKERS" capsule "$PROJECT" alpha 1 builder 12 waiting 'handoff ready' 'resume after cycle boundary' 'docs/verify-worker-continuity.md'
assert_rc "workers-capsule-stale-writer-rejected" 75 "$WORKERS" capsule "$PROJECT" alpha 1 builder 12 active stale context evidence
assert_eq "workers-capsule-version-incremented" 2 "$("$WORKERS" show "$PROJECT" alpha | jq -r .version)"
assert_eq "workers-capsule-history-append-only" 3 "$(jq -s '[.[] | select(.event == "capsule")] | length' "$PROJECT/docs/polylane/workers/history.jsonl")"

# Recipients are explicit identities; concurrent appenders retain both events.
assert_ok "workers-create-beta" "$WORKERS" capsule "$PROJECT" beta 0 reviewer 11 active summary context evidence
assert_fail "workers-message-rejects-secret" "$WORKERS" send "$PROJECT" alpha beta 12 'access_token=secret-value'
assert_eq "workers-secret-message-not-persisted" 0 "$("$WORKERS" inbox "$PROJECT" beta | jq length)"
assert_ok "workers-send-first" "$WORKERS" send "$PROJECT" alpha beta 12 'please review the worker API'
FIRST_ID=$("$WORKERS" send "$PROJECT" alpha beta 12 'a second review note' | jq -r .id)
INBOX=$("$WORKERS" inbox "$PROJECT" beta)
assert_eq "workers-inbox-unacknowledged" 2 "$(printf '%s' "$INBOX" | jq 'length')"
assert_eq "workers-inbox-recipient-filter" beta "$(printf '%s' "$INBOX" | jq -r '.[0].to')"
assert_eq "workers-inbox-other-recipient-empty" 0 "$("$WORKERS" inbox "$PROJECT" alpha | jq length)"

( "$WORKERS" send "$PROJECT" alpha beta 12 'concurrent one' ) & p1=$!
( "$WORKERS" send "$PROJECT" alpha beta 12 'concurrent two' ) & p2=$!
wait "$p1"; r1=$?
wait "$p2"; r2=$?
assert_eq "workers-concurrent-first" 0 "$r1"
assert_eq "workers-concurrent-second" 0 "$r2"
assert_eq "workers-concurrent-no-lost-writes" 4 "$("$WORKERS" inbox "$PROJECT" beta | jq length)"
assert_eq "workers-deterministic-message-ids-unique" 4 "$("$WORKERS" inbox "$PROJECT" beta | jq '[.[].id] | unique | length')"

# Ack is recipient-scoped, idempotent, and leaves an append-only audit event.
assert_ok "workers-ack-first" "$WORKERS" ack "$PROJECT" beta "$FIRST_ID"
assert_ok "workers-ack-idempotent" "$WORKERS" ack "$PROJECT" beta "$FIRST_ID"
assert_eq "workers-ack-removes-only-recipient-message" 3 "$("$WORKERS" inbox "$PROJECT" beta | jq length)"
assert_eq "workers-ack-audited-once" 1 "$(jq -s --arg id "$FIRST_ID" '[.[] | select(.event == "ack" and .message_id == $id and .recipient == "beta")] | length' "$PROJECT/docs/polylane/workers/history.jsonl")"
assert_rc "workers-ack-recipient-scoped" 4 "$WORKERS" ack "$PROJECT" alpha "$FIRST_ID"

# Import retains the public relay events as history; request remains a request
# and becomes a durable inbox item, while decisions do not become requests.
RELAY="$PROJECT/.polylane/coordination.jsonl"
printf '%s\n' \
  '{"event":"request","lane":"alpha","to":"beta","message":"need the capsule API","seq":1,"at":"2026-08-07T00:00:00Z"}' \
  '{"event":"decision","lane":"alpha","decision":"use JSONL","rationale":"append-only","seq":2,"at":"2026-08-07T00:00:01Z"}' \
  '{"event":"claim","lane":"beta","resource":"workers","seq":3,"at":"2026-08-07T00:00:02Z"}' > "$RELAY"
RELAY_BEFORE=$(cksum "$RELAY")
assert_ok "workers-import-relay" "$WORKERS" import-relay "$PROJECT" "$RELAY" 12
assert_ok "workers-import-relay-idempotent" "$WORKERS" import-relay "$PROJECT" "$RELAY" 12
assert_eq "workers-relay-never-edited" "$RELAY_BEFORE" "$(cksum "$RELAY")"
assert_eq "workers-relay-import-no-duplicates" 3 "$(jq -s '[.[] | select(.event == "relay-import")] | length' "$PROJECT/docs/polylane/workers/history.jsonl")"
assert_eq "workers-relay-request-inbox" 4 "$("$WORKERS" inbox "$PROJECT" beta | jq length)"
assert_eq "workers-relay-request-not-decision" 1 "$("$WORKERS" inbox "$PROJECT" beta | jq '[.[] | select(.source == "relay" and .relay.event == "request")] | length')"
BAD_RELAY="$PROJECT/.polylane/secret-relay.jsonl"
printf '%s\n' '{"event":"request","lane":"alpha","to":"beta","message":"api_key=not-for-history","seq":1,"at":"2026-08-07T00:00:00Z"}' > "$BAD_RELAY"
RELAY_HISTORY_BEFORE=$(wc -l < "$PROJECT/docs/polylane/workers/history.jsonl" | tr -d ' ')
assert_fail "workers-relay-secret-rejected" "$WORKERS" import-relay "$PROJECT" "$BAD_RELAY" 12
assert_eq "workers-relay-secret-not-persisted" "$RELAY_HISTORY_BEFORE" "$(wc -l < "$PROJECT/docs/polylane/workers/history.jsonl" | tr -d ' ')"

# Resume is cycle-safe and has source labels plus a hard packet limit.
RESUME=$("$WORKERS" resume "$PROJECT" beta 600)
assert_eq "workers-resume-capsule-label" capsule "$(printf '%s' "$RESUME" | jq -r .sources.capsule)"
assert_eq "workers-resume-inbox-label" durable-inbox "$(printf '%s' "$RESUME" | jq -r .sources.inbox)"
assert_ok "workers-resume-pending-present" sh -c '[ "$(printf %s "$1" | jq ".pending | length")" -ge 1 ]' sh "$RESUME"
assert_eq "workers-resume-truncation-explicit" true "$(printf '%s' "$RESUME" | jq -r .truncated)"
assert_ok "workers-resume-packet-bounded" sh -c '[ "$(printf %s "$1" | wc -c | tr -d " ")" -le 600 ]' sh "$RESUME"
assert_rc "workers-resume-missing-explicit" 4 "$WORKERS" resume "$PROJECT" missing 600

# A contender that catches another holder between mkdir and the created_at
# stamp must wait, not steal: aging that gap as epoch-0 stole live locks and
# killed their holders mid-append ("lost worker lock before history append").
GAP_LOCK="$PROJECT/docs/polylane/workers/.lock"
mkdir "$GAP_LOCK"
"$WORKERS" capsule "$PROJECT" gapwait 0 builder 12 active gap context evidence >/dev/null 2>&1 & GAP_PID=$!
sleep 2
if kill -0 "$GAP_PID" 2>/dev/null; then
  pass "workers-unstamped-fresh-lock-not-stolen"
else
  fail "workers-unstamped-fresh-lock-not-stolen" "contender finished instantly — stole a fresh unstamped lock"
fi
rm -rf "$GAP_LOCK"
wait "$GAP_PID"; GAP_RC=$?
assert_eq "workers-unstamped-lock-holder-proceeds-after-release" 0 "$GAP_RC"

finish
