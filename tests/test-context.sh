#!/usr/bin/env bash
# polylane-context.sh — deterministic, bounded, source-attributed packets.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
CTX="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-context.sh"

if ! command -v jq >/dev/null 2>&1; then
  pass "context-skipped-no-jq"; finish; exit 0
fi

make_tmpdir
P="$TEST_TMPDIR/project"
OUT="$P/.polylane/context-packets/lane-a"
mkdir -p "$P/docs/polylane/decisions" "$P/docs/polylane/harness" \
  "$P/docs/polylane/workers/lane-a" "$P/.polylane/context-packets"

printf '# North star\nDurable product continuity matters.\n' > "$P/docs/polylane/NORTHSTAR.md"
printf '# Strategy\nContext query should select relevant deterministic passages.\n' > "$P/docs/polylane/STRATEGY.md"
printf '# Ultimate\nA stranger must get a flawless first run.\n' > "$P/docs/polylane/ULTIMATE_GOAL.md"
printf '{"ultimate":"Ship reliable packets","criteria":[{"id":"c1","text":"context packet bound","status":"open"}],"milestones":[],"log":[{"cycle":9,"kind":"decision","text":"old context"},{"cycle":11,"kind":"decision","text":"fresh context evidence"}]}' > "$P/docs/polylane/max-state.json"
printf '# Decisions\n' > "$P/docs/polylane/decisions/INDEX.md"
printf '# Decision 001\nbanana protocol is authoritative.\n' > "$P/docs/polylane/decisions/001-banana.md"
printf '# Story\nrecent cycle history and packet evidence.\n' > "$P/docs/polylane/corpus.md"
printf '# Cycle 10\nold banana notes.\n' > "$P/docs/polylane/cycle-10-digest.md"
printf '# Cycle 11\nbanana packet evidence is newest.\n' > "$P/docs/polylane/cycle-11-digest.md"
printf '# Cycle 12\nbanana packet evidence is newest of all.\n' > "$P/docs/polylane/cycle-12-digest.md"
for CYCLE in 4 5 6 7 8 9; do
  printf '# Cycle %s\nold banana notes.\n' "$CYCLE" > "$P/docs/polylane/cycle-$CYCLE-digest.md"
done
printf '# Harness\nbanana refinement evidence.\n' > "$P/docs/polylane/harness/local.md"
printf '# Capsule\nlane-a owns banana context.\n' > "$P/docs/polylane/workers/lane-a/capsule.md"
printf '{"id":"m0","body":"acknowledged banana inbox item","acknowledged":true}\n{"id":"m1","body":"pending banana inbox item","acknowledged":false}\n' > "$P/docs/polylane/workers/lane-a/inbox.jsonl"

assert_ok "packet-builds" "$CTX" packet "$P" "$OUT" 2200 banana --goal "LOCKED goal survives" --subgoal "CURRENT banana work" --worker lane-a
PACKET="$OUT/context.md"
MANIFEST="$OUT/manifest.json"
assert_ok "packet-written" test -s "$PACKET"
assert_contains "source-attribution" "Source: docs/polylane/decisions/001-banana.md" "$(cat "$PACKET")"
assert_contains "section-label" "Section:" "$(cat "$PACKET")"
assert_contains "goal-preserved" "LOCKED goal survives" "$(cat "$PACKET")"
assert_contains "subgoal-preserved" "CURRENT banana work" "$(cat "$PACKET")"
assert_contains "worker-capsule-included" "workers/lane-a/capsule.md" "$(cat "$PACKET")"
assert_contains "pending-inbox-included" "pending banana inbox item" "$(cat "$PACKET")"
if grep -qF 'acknowledged banana inbox item' "$PACKET"; then
  fail "acknowledged-inbox-excluded" "acknowledged inbox content was included"
else
  pass "acknowledged-inbox-excluded"
fi
assert_contains "numeric-recent-cycle-included" "cycle-12-digest.md" "$(cat "$PACKET")"

DECISION_LINE=$(grep -n 'banana protocol' "$PACKET" | cut -d: -f1)
STRATEGY_LINE=$(grep -n 'Context query should' "$PACKET" | cut -d: -f1)
if [ -n "$DECISION_LINE" ] && [ -n "$STRATEGY_LINE" ] && [ "$DECISION_LINE" -lt "$STRATEGY_LINE" ]; then
  pass "relevance-orders-matching-passages"
else
  fail "relevance-orders-matching-passages" "decision did not rank before generic strategy"
fi

BYTES=$(wc -c < "$PACKET" | tr -d ' ')
if [ "$BYTES" -le 2200 ]; then pass "packet-hard-byte-bound"; else fail "packet-hard-byte-bound" "$BYTES > 2200"; fi
assert_eq "manifest-byte-count" "$BYTES" "$(jq -r '.byte_count' "$MANIFEST")"
assert_contains "manifest-query" "banana" "$(jq -r '.query' "$MANIFEST")"
assert_contains "manifest-checksum" "cksum:" "$(jq -r '.content_checksum' "$MANIFEST")"
assert_contains "manifest-missing-optional" "docs/polylane/workers/lane-a/inbox.md" "$(jq -r '.missing_sources[]' "$MANIFEST")"

CHECKSUM_A=$(jq -r '.content_checksum' "$MANIFEST")
cp "$PACKET" "$TEST_TMPDIR/first.md"
assert_ok "packet-repeat-builds" "$CTX" query "$P" "$OUT" 2200 banana --goal "LOCKED goal survives" --subgoal "CURRENT banana work" --worker lane-a
assert_eq "packet-repeatable-content" "$(cat "$TEST_TMPDIR/first.md")" "$(cat "$PACKET")"
assert_eq "packet-repeatable-checksum" "$CHECKSUM_A" "$(jq -r '.content_checksum' "$MANIFEST")"

assert_ok "refresh-lists-allowlist" "$CTX" refresh "$P"
assert_contains "refresh-shows-missing" "missing" "$("$CTX" refresh "$P" --worker lane-a)"
assert_rc "malformed-budget-rc2" 2 "$CTX" packet "$P" "$OUT" nope banana
assert_rc "unsafe-root-rc2" 2 "$CTX" packet / "$OUT" 100 banana
assert_rc "outside-packet-dir-rc2" 2 "$CTX" packet "$P" "$P/outside" 100 banana
assert_rc "goal-too-large-hard-fails" 2 "$CTX" packet "$P" "$OUT" 25 banana --goal "this locked goal cannot fit in twenty five bytes"
printf 'PRIVATE_KEY=should-not-be-read\n' > "$P/docs/polylane/decisions/002-secret-token.md"
assert_rc "secret-like-source-rc2" 2 "$CTX" packet "$P" "$OUT" 2200 banana

finish
