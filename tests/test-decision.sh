#!/usr/bin/env bash
# polylane-decision.sh — durable ADR trail (the north-star records) for /polylane-max.
# Exercised as a CLI: auto-numbering, index, settled-decisions digest.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
DEC="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-decision.sh"

make_tmpdir
D="$TEST_TMPDIR/decisions"

# new: auto-numbers, writes a file, prints its path
f1=$("$DEC" "$D" new "Concept: AI-native" "build the AI fork" "defensible wedge" "no social feed" 1)
assert_contains "new-numbered-001" "001-concept-ai-native.md" "$f1"
assert_ok "new-file-exists" test -f "$f1"
assert_contains "file-has-why" "defensible wedge" "$(cat "$f1")"

f2=$("$DEC" "$D" new "Stack: local-first" "vanilla JS + localStorage")
assert_contains "new-numbered-002" "002-stack-local-first.md" "$f2"

# index lists both, in order
IDXOUT=$("$DEC" "$D" list)
assert_contains "index-001" "001 Concept: AI-native" "$IDXOUT"
assert_contains "index-002" "002 Stack: local-first" "$IDXOUT"

# context digest = the "do not contradict" block a lane re-reads
CTX=$("$DEC" "$D" context)
assert_contains "context-header"  "SETTLED DECISIONS" "$CTX"
assert_contains "context-has-dec" "build the AI fork" "$CTX"

# empty dir → graceful, not an error
assert_contains "context-empty" "no decisions" "$("$DEC" "$TEST_TMPDIR/empty" context)"

# unknown command → rc 2
assert_rc "unknown-cmd" 2 "$DEC" "$D" bogus

finish
