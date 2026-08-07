#!/usr/bin/env bash
# Frozen keyed acceptance checks: share only within one check-accept invocation.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
MEM="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-memory.sh"

if ! command -v jq >/dev/null 2>&1; then
  pass "accept-dedupe-skipped-no-jq"; finish; exit 0
fi

make_tmpdir

new_state() {
  local state="$1"
  "$MEM" "$state" init g >/dev/null
  "$MEM" "$state" add-milestone m1 m >/dev/null
  "$MEM" "$state" add-subgoal m1 s1 one >/dev/null
  "$MEM" "$state" add-subgoal m1 s2 two >/dev/null
  "$MEM" "$state" add-subgoal m1 s3 three >/dev/null
}

# A non-empty key executes its first selected check once; every later selected
# member receives that exact result without executing its own command.
S="$TEST_TMPDIR/pass.json"; LOG="$TEST_TMPDIR/pass.log"
new_state "$S"
"$MEM" "$S" add-accept s1 "echo key-first >> '$LOG'" --key shared-check >/dev/null
"$MEM" "$S" add-accept s2 "echo key-second >> '$LOG'; exit 1" --key shared-check >/dev/null
"$MEM" "$S" add-accept s3 "echo unkeyed >> '$LOG'" >/dev/null
assert_ok "keyed-pass-check" "$MEM" "$S" check-accept
assert_eq "keyed-runs-first-once" "1" "$(grep -c '^key-first$' "$LOG")"
assert_eq "keyed-skips-later-command" "0" "$(grep -c '^key-second$' "$LOG" || true)"
assert_eq "empty-key-always-runs" "1" "$(grep -c '^unkeyed$' "$LOG")"
assert_eq "keyed-pass-propagates-s1" "pass" "$(jq -r '.accept[0].status' "$S")"
assert_eq "keyed-pass-propagates-s2" "pass" "$(jq -r '.accept[1].status' "$S")"
assert_ok "keyed-reruns-next-invocation" "$MEM" "$S" check-accept
assert_eq "keyed-never-cross-invocation-cache" "2" "$(grep -c '^key-first$' "$LOG")"
assert_eq "empty-key-reruns-next-invocation" "2" "$(grep -c '^unkeyed$' "$LOG")"

# A shared failure is equally propagated, retaining truthful per-member status.
F="$TEST_TMPDIR/fail.json"; FAIL_LOG="$TEST_TMPDIR/fail.log"
new_state "$F"
"$MEM" "$F" add-accept s1 "echo key-fail >> '$FAIL_LOG'; exit 1" --key shared-failure >/dev/null
"$MEM" "$F" add-accept s2 "echo should-not-run >> '$FAIL_LOG'" --key shared-failure >/dev/null
assert_fail "keyed-fail-check" "$MEM" "$F" check-accept
assert_eq "keyed-failure-runs-first-once" "1" "$(grep -c '^key-fail$' "$FAIL_LOG")"
assert_eq "keyed-failure-skips-later-command" "0" "$(grep -c '^should-not-run$' "$FAIL_LOG" || true)"
assert_eq "keyed-fail-propagates-s1" "fail" "$(jq -r '.accept[0].status' "$F")"
assert_eq "keyed-fail-propagates-s2" "fail" "$(jq -r '.accept[1].status' "$F")"

# Selection determines which member is first: an unselected member neither runs nor
# changes, while the selected one still executes and is stamped.
T="$TEST_TMPDIR/targeted.json"; TARGET_LOG="$TEST_TMPDIR/targeted.log"
new_state "$T"
"$MEM" "$T" add-accept s1 "echo first-unselected >> '$TARGET_LOG'" --key targeted >/dev/null
"$MEM" "$T" add-accept s2 "echo second-selected >> '$TARGET_LOG'" --key targeted >/dev/null
assert_ok "targeted-keyed-check" "$MEM" "$T" check-accept --targets s2 --focused
assert_eq "targeted-first-selected-runs" "1" "$(grep -c '^second-selected$' "$TARGET_LOG")"
assert_eq "targeted-unselected-does-not-run" "0" "$(grep -c '^first-unselected$' "$TARGET_LOG" || true)"
assert_eq "targeted-unselected-status-kept" "unchecked" "$(jq -r '.accept[0].status' "$T")"
assert_eq "targeted-selected-status-updated" "pass" "$(jq -r '.accept[1].status' "$T")"

# Existing frozen commands can be keyed without changing them. Invalid keys fail
# before mutation for both registration and tagging.
K="$TEST_TMPDIR/tag.json"; new_state "$K"
"$MEM" "$K" add-accept s1 "true" >/dev/null
ORIGINAL_CMD="$(jq -r '.accept[0].cmd' "$K")"
assert_ok "tag-existing-key" "$MEM" "$K" tag-accept s1 --key retained-key
assert_eq "tag-preserves-command" "$ORIGINAL_CMD" "$(jq -r '.accept[0].cmd' "$K")"
assert_eq "tag-records-key" "retained-key" "$(jq -r '.accept[0].key' "$K")"

# A sub-goal can legitimately have focused and terminal graders. Retrofitting a
# shared terminal key must not also key the dissimilar focused command, or a plain
# check-accept could let the cheap check suppress the expensive certification.
"$MEM" "$K" add-accept s2 "true" --tier focused >/dev/null
"$MEM" "$K" add-accept s2 "true" --tier terminal >/dev/null
assert_ok "tag-existing-terminal-key" "$MEM" "$K" tag-accept s2 --tier terminal --key terminal-suite
assert_eq "tag-tier-keeps-focused-unkeyed" "" "$(jq -r '.accept[] | select(.sid=="s2" and .tier=="focused") | .key' "$K")"
assert_eq "tag-tier-keys-terminal-only" "terminal-suite" "$(jq -r '.accept[] | select(.sid=="s2" and .tier=="terminal") | .key' "$K")"
BEFORE="$(jq -c '.accept' "$K")"
assert_fail "add-rejects-unsafe-key" "$MEM" "$K" add-accept s2 true --key 'bad key'
assert_eq "add-invalid-key-no-mutation" "$BEFORE" "$(jq -c '.accept' "$K")"
assert_fail "tag-rejects-unsafe-key" "$MEM" "$K" tag-accept s1 --key 'bad/key'
assert_eq "tag-invalid-key-no-mutation" "$BEFORE" "$(jq -c '.accept' "$K")"

finish
