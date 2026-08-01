#!/usr/bin/env bash
# A replacement pane must get a fresh transcript pipe. `tmux respawn-pane` can
# leave stale pipe metadata, so a plain `pipe-pane -o` may silently stop logging.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
CALLS="$TEST_TMPDIR/tmux-calls"
: > "$CALLS"

tmux() {
  printf '%s\n' "$*" >> "$CALLS"
}

REPO_ROOT="$TEST_TMPDIR/repo"
TMUX_SESSION="pane-log-test"
DRY_RUN=0
mkdir -p "$REPO_ROOT"

repipe_pane_log 2 integration

assert_eq "repipe-two-tmux-calls" "2" "$(wc -l < "$CALLS" | tr -d ' ')"
assert_eq "repipe-closes-stale-pipe" \
  "pipe-pane -t pane-log-test:0.2" \
  "$(sed -n '1p' "$CALLS")"
assert_contains "repipe-opens-fresh-pipe" \
  "pipe-pane -o -t pane-log-test:0.2 cat >>" \
  "$(sed -n '2p' "$CALLS")"
assert_contains "repipe-preserves-lane-log-path" \
  "docs/lane-logs/integration.log" \
  "$(sed -n '2p' "$CALLS")"

finish
