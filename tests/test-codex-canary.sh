#!/usr/bin/env bash
# Opt-in real Codex/tmux forward test. It spends two tiny model calls.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
CANARY="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-codex-canary.sh"

if [ "${POLYLANE_CODEX_CANARY:-0}" != "1" ]; then
  pass "codex-canary-gated-off (set POLYLANE_CODEX_CANARY=1)"
  finish
  exit 0
fi
if ! command -v codex >/dev/null 2>&1 || ! command -v tmux >/dev/null 2>&1; then
  pass "codex-canary-skipped-missing-runtime"
  finish
  exit 0
fi

out=$("$CANARY" 2>&1); rc=$?
assert_eq "codex-canary-rc0" "0" "$rc"
assert_contains "codex-canary-watch" "tmux attach -t pl-codex-canary-" "$out"
assert_contains "codex-canary-pass" "CODEX-CANARY: PASS" "$out"
finish
