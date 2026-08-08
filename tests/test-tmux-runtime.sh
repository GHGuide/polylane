#!/usr/bin/env bash
# Every nonce-bound run owns one deterministic tmux server, and fresh workers
# start through tmux's shell-command rather than racing send-keys into a shell.
# shellcheck disable=SC1090,SC2034
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
POLYLANE_TMUX_PARENT=/tmp
export POLYLANE_TMUX_PARENT
unset POLYLANE_TMUX_TMPDIR TMUX_TMPDIR
TMUX=foreign-client
export TMUX
RUN_ONE="run-one-$$"
RUN_TWO="run-two-$$"

polylane_tmux_configure "$RUN_ONE" ensure
ROOT_ONE="$TMUX_TMPDIR"
assert_eq "tmux-config-drops-inherited-client" "" "${TMUX:-}"
assert_ok "tmux-config-creates-private-root" test -d "$ROOT_ONE"
assert_eq "tmux-config-root-mode" "700" "$(stat -f '%Lp' "$ROOT_ONE" 2>/dev/null || stat -c '%a' "$ROOT_ONE")"

unset POLYLANE_TMUX_TMPDIR POLYLANE_TMUX_AUTO TMUX_TMPDIR
polylane_tmux_configure "$RUN_TWO" ensure
ROOT_TWO="$TMUX_TMPDIR"
if [ "$ROOT_ONE" != "$ROOT_TWO" ]; then pass "tmux-runs-use-separate-roots"; else fail "tmux-runs-use-separate-roots" "same root"; fi

unset POLYLANE_TMUX_TMPDIR POLYLANE_TMUX_AUTO TMUX_TMPDIR
polylane_tmux_configure "$RUN_ONE" ensure
assert_eq "tmux-run-root-is-deterministic" "$ROOT_ONE" "$TMUX_TMPDIR"
assert_eq "tmux-watch-is-reconnectable" \
  "env -u TMUX TMUX_TMPDIR=$ROOT_ONE tmux attach -t isolated-session" \
  "$(polylane_tmux_watch_command isolated-session)"

# An inner Polylane invocation inherits the outer environment. Auto-derived
# roots must follow the inner nonce instead of silently reusing the outer server.
OUTER_ROOT="$TMUX_TMPDIR"
polylane_tmux_configure "nested-$RUN_TWO" ensure
if [ "$TMUX_TMPDIR" != "$OUTER_ROOT" ]; then pass "tmux-nested-run-rederives-root"; else fail "tmux-nested-run-rederives-root" "inherited outer root"; fi
ROOT_NESTED="$TMUX_TMPDIR"

if ! command -v tmux >/dev/null 2>&1; then
  pass "tmux-atomic-launch-skipped-no-tmux"
  finish
  exit 0
fi

TMUX_SESSION="polylane-atomic-$$"
DRY_RUN=0; SESSION_STARTED=0; NEXT_PANE_IDX=0
RUN_ID="$RUN_ONE"; PROJECT_ROOT="$TEST_TMPDIR/project"
mkdir -p "$PROJECT_ROOT"
trap 'tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true; rm -rf "$ROOT_ONE" "$ROOT_TWO" "$ROOT_NESTED"; cleanup_tmpdirs' EXIT

# A payload longer than the command that exposed the old seed race must arrive
# byte-for-byte through one fresh-server pane launch without send-keys.
PAYLOAD=$(awk 'BEGIN { for (i=0; i<4096; i++) printf "x" }')
OUT="$TEST_TMPDIR/atomic-output"
CMD="printf '%s' '$PAYLOAD' > $(printf '%q' "$OUT")"
if new_pane atomic "$CMD" >/dev/null 2>&1; then
  i=0
  while [ ! -f "$OUT" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
  assert_ok "tmux-atomic-launch-created-output" test -f "$OUT"
  assert_eq "tmux-atomic-launch-preserves-long-command" "4096" "$(wc -c < "$OUT" | tr -d ' ')"
else
  pass "tmux-atomic-launch-skipped-unusable-tmux"
fi

finish
