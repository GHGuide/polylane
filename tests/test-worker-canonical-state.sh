#!/usr/bin/env bash
# A lane may run from any worktree, but worker continuity has one authority.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
WORKERS="$ROOT/bin/polylane-workers.sh"
command -v jq >/dev/null 2>&1 || { pass "worker-canonical-skipped-no-jq"; finish; exit 0; }
command -v git >/dev/null 2>&1 || { pass "worker-canonical-skipped-no-git"; finish; exit 0; }
make_tmpdir

CANONICAL="$TEST_TMPDIR/canonical"
LANE_A="$TEST_TMPDIR/lane-a"
LANE_B="$TEST_TMPDIR/lane-b"
WORKERS_DIR="$CANONICAL/docs/polylane/workers"
mkdir -p "$CANONICAL"
git -C "$CANONICAL" init -q
git -C "$CANONICAL" config user.email workers@example.test
git -C "$CANONICAL" config user.name workers-test
printf 'worker ledger fixture\n' > "$CANONICAL/README.md"
git -C "$CANONICAL" add README.md
git -C "$CANONICAL" commit -qm fixture
git -C "$CANONICAL" worktree add -qb worker-ledger-a "$LANE_A"
git -C "$CANONICAL" worktree add -qb worker-ledger-b "$LANE_B"

# The runner supplies the canonical project root explicitly.  The caller's
# project argument is intentionally a worktree, so this test would reproduce
# independent lane-local histories without canonical-root resolution.
assert_ok "worker-canonical-create-alpha" env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" capsule "$LANE_A" alpha 0 builder 14 active alpha context evidence
assert_ok "worker-canonical-create-beta" env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" capsule "$LANE_B" beta 0 reviewer 14 active beta context evidence
assert_eq "worker-canonical-state-created-at-authority" yes "$( [ -f "$CANONICAL/docs/polylane/workers/history.jsonl" ] && printf yes || printf no )"
assert_eq "worker-canonical-state-not-created-in-lane-a" no "$( [ -e "$LANE_A/docs/polylane/workers" ] && printf yes || printf no )"
assert_eq "worker-canonical-state-not-created-in-lane-b" no "$( [ -e "$LANE_B/docs/polylane/workers" ] && printf yes || printf no )"

( env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" capsule "$LANE_A" alpha 1 builder 14 waiting alpha-update context evidence ) & p1=$!
( env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" capsule "$LANE_B" beta 1 reviewer 14 waiting beta-update context evidence ) & p2=$!
wait "$p1"; r1=$?
wait "$p2"; r2=$?
assert_eq "worker-canonical-concurrent-capsule-a" 0 "$r1"
assert_eq "worker-canonical-concurrent-capsule-b" 0 "$r2"

( env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" send "$LANE_A" alpha beta 14 message-from-a > "$TEST_TMPDIR/message-a.json" ) & p1=$!
( env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" send "$LANE_B" alpha beta 14 message-from-b > "$TEST_TMPDIR/message-b.json" ) & p2=$!
wait "$p1"; r1=$?
wait "$p2"; r2=$?
assert_eq "worker-canonical-concurrent-message-a" 0 "$r1"
assert_eq "worker-canonical-concurrent-message-b" 0 "$r2"
MESSAGE_A=$(jq -r .id "$TEST_TMPDIR/message-a.json")
MESSAGE_B=$(jq -r .id "$TEST_TMPDIR/message-b.json")
assert_eq "worker-canonical-message-ids-unique" 2 "$(printf '%s\n%s\n' "$MESSAGE_A" "$MESSAGE_B" | sort -u | wc -l | tr -d ' ')"
assert_eq "worker-canonical-message-ids-follow-history-order" true "$(jq -s '[.[] | select(.event == "message") | (.id | capture("^message:(?<seq>[0-9]+)$").seq | tonumber)] | reduce .[] as $seq ({last:0,ok:true}; .ok = (.ok and ($seq > .last)) | .last = $seq) | .ok' "$CANONICAL/docs/polylane/workers/history.jsonl")"
assert_eq "worker-canonical-read-from-authority" 2 "$(env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" inbox "$LANE_A" beta | jq length)"

( env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" ack "$LANE_A" beta "$MESSAGE_A" ) & p1=$!
( env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" ack "$LANE_B" beta "$MESSAGE_B" ) & p2=$!
wait "$p1"; r1=$?
wait "$p2"; r2=$?
assert_eq "worker-canonical-concurrent-ack-a" 0 "$r1"
assert_eq "worker-canonical-concurrent-ack-b" 0 "$r2"
assert_eq "worker-canonical-acknowledgements-retained" 2 "$(jq -s '[.[] | select(.event == "ack")] | length' "$CANONICAL/docs/polylane/workers/history.jsonl")"
assert_eq "worker-canonical-ack-read-from-authority" 0 "$(env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" inbox "$LANE_B" beta | jq length)"
assert_eq "worker-canonical-history-sequences-unique" true "$(jq -s '[.[].seq] | (length == (unique | length))' "$CANONICAL/docs/polylane/workers/history.jsonl")"
assert_eq "worker-canonical-history-sequences-monotonic" true "$(jq -s 'reduce .[] as $event ({last:0,ok:true}; .ok = (.ok and ($event.seq > .last)) | .last = $event.seq) | .ok' "$CANONICAL/docs/polylane/workers/history.jsonl")"

# A worktree path is accepted only as the caller location.  A mutable relay
# remains constrained to the declared canonical project, not the lane.
mkdir -p "$LANE_A/.polylane"
printf '%s\n' '{"event":"decision","lane":"alpha","decision":"lane-local","rationale":"must not import","seq":1,"at":"2026-08-08T00:00:00Z"}' > "$LANE_A/.polylane/coordination.jsonl"
assert_fail "worker-canonical-rejects-lane-relay" env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" import-relay "$LANE_A" "$LANE_A/.polylane/coordination.jsonl" 14

# A root alone is not the full launcher contract.  This prevents an inherited
# root from hijacking a normal standalone invocation or its local history.
UNTRUSTED="$TEST_TMPDIR/standalone"
mkdir -p "$UNTRUSTED/.polylane"
assert_ok "worker-canonical-root-alone-keeps-standalone" env -u POLYLANE_WORKERS_DIR POLYLANE_PROJECT_ROOT="$CANONICAL" "$WORKERS" capsule "$UNTRUSTED" standalone 0 builder 14 active local context evidence
assert_eq "worker-canonical-root-alone-local-state" yes "$( [ -f "$UNTRUSTED/docs/polylane/workers/capsules/standalone.json" ] && printf yes || printf no )"
assert_eq "worker-canonical-root-alone-does-not-write-authority" no "$( [ -f "$CANONICAL/docs/polylane/workers/capsules/standalone.json" ] && printf yes || printf no )"

# A separate Git repository is neither the canonical project nor one of its
# worktrees, so the runtime contract must reject it instead of redirecting it.
ROGUE="$TEST_TMPDIR/rogue"
mkdir -p "$ROGUE"
git -C "$ROGUE" init -q
git -C "$ROGUE" config user.email workers@example.test
git -C "$ROGUE" config user.name workers-test
printf 'rogue fixture\n' > "$ROGUE/README.md"
git -C "$ROGUE" add README.md
git -C "$ROGUE" commit -qm fixture
assert_rc "worker-canonical-rejects-unrelated-git-project" 2 env POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$WORKERS_DIR" "$WORKERS" capsule "$ROGUE" rogue 0 builder 14 active rogue context evidence

finish
