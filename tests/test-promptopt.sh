#!/usr/bin/env bash
# Prompt optimization must retain each mandatory block and report deterministic
# machine-readable size metrics without mutating the source prompt.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
PROMPTOPT="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-promptopt.sh"

make_tmpdir
PROMPT="$TEST_TMPDIR/valid.md"
cat > "$PROMPT" <<'EOF'
## GOAL
Build the requested product.

## CONTEXT
The input is intentionally vague.

## CONSTRAINTS
Use Bash 3.2 and do not rewrite this file.

## VERIFICATION
Run focused checks.
EOF
ORIGINAL=$(cksum "$PROMPT")

METRICS=$("$PROMPTOPT" metrics "$PROMPT")
assert_ok "promptopt-metrics-json" jq -e '.bytes > 0 and .tokens > 0' <<<"$METRICS"
assert_ok "promptopt-check-valid" "$PROMPTOPT" check "$PROMPT" 500
assert_eq "promptopt-check-never-rewrites-source" "$ORIGINAL" "$(cksum "$PROMPT")"

MISSING="$TEST_TMPDIR/missing.md"
cat > "$MISSING" <<'EOF'
## GOAL
Build the requested product.

## CONTEXT
The input is intentionally vague.

## CONSTRAINTS
Use Bash 3.2.
EOF
assert_fail "promptopt-check-rejects-missing-strict-block" "$PROMPTOPT" check "$MISSING"
assert_fail "promptopt-check-rejects-over-budget" "$PROMPTOPT" check "$PROMPT" 1

finish
