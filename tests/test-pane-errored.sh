#!/usr/bin/env bash
# pane_errored IDX — 0 iff the pane text shows a transient error signature.
# tmux is mocked with a PATH shim that prints $FAKE_PANE_TEXT_FILE, so this
# exercises the real function (capture + grep), not just the regex.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
mkdir -p "$TEST_TMPDIR/bin"
cat > "$TEST_TMPDIR/bin/tmux" <<'SHIM'
#!/bin/sh
cat "$FAKE_PANE_TEXT_FILE"
SHIM
chmod +x "$TEST_TMPDIR/bin/tmux"
PATH="$TEST_TMPDIR/bin:$PATH"
export FAKE_PANE_TEXT_FILE="$TEST_TMPDIR/pane.txt"

# errored NAME TEXT — write TEXT as the pane capture, expect pane_errored 0
errored()     { printf '%s\n' "$2" > "$FAKE_PANE_TEXT_FILE"; assert_ok   "$1" pane_errored 0; }
not_errored() { printf '%s\n' "$2" > "$FAKE_PANE_TEXT_FILE"; assert_fail "$1" pane_errored 0; }

errored "err-api-error"          "API Error: Request failed"
errored "err-500-internal"       "500 Internal server error"
errored "err-503-error"          "upstream returned 503 error"
errored "err-overloaded"         "overloaded_error: try again later"
errored "err-rate-limit-space"   "You have hit a rate limit"
errored "err-rate-limit-hyphen"  "rate-limited by upstream"
errored "err-ratelimit-joined"   "ratelimit exceeded"
errored "err-connection"         "Connection error while streaming"
errored "err-network"            "network error: unreachable"
errored "err-status-page"        "check status.claude.com for incidents"
errored "err-case-insensitive"   "OVERLOADED — API BUSY"

not_errored "ok-clean-pane"      "Goal achieved (12k tokens) — writing status file"
not_errored "ok-benign-noise"    "compiling module 3 of 7"

# negative index = unknown lane -> never errored
printf 'API Error\n' > "$FAKE_PANE_TEXT_FILE"
assert_fail "err-negative-index" pane_errored -1

finish
