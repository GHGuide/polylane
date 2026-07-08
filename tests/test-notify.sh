#!/usr/bin/env bash
# polylane-notify.sh — macOS banner + sound for polylane run events. Exercised
# as a CLI (it runs on invocation), asserting output + exit codes.
#
# It never fires a real notification: every event path is tested with osascript
# hidden (a cleared environment via `env -i`), which drives the documented quiet
# no-op / "non-macOS" branch. The only path exercised while osascript is present
# is the empty-args usage path, which returns before any notification is built.
# bash-3.2 safe.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
NOTIFY="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-notify.sh"

# Absolute bash to relaunch the CLI under a cleared environment (env -i), so the
# script's `command -v osascript` misses and we deterministically hit the quiet
# no-op path regardless of the host platform.
BASH_BIN="${BASH:-$(command -v bash)}"
case "$BASH_BIN" in
  /*) ;;
  *)  BASH_BIN=$(command -v "$BASH_BIN") ;;
esac

# Run the CLI with no osascript reachable (simulated non-macOS). Only shell
# builtins are used on the no-op path, so an empty environment is enough.
noop() { env -i "$BASH_BIN" "$NOTIFY" "$@"; }

# --- help: usage on stdout, exit 0 (reached before the osascript check) -------
HELP=$("$NOTIFY" -h 2>&1)
assert_contains "notify-help-usage"        "USAGE:"                    "$HELP"
assert_contains "notify-help-lists-events" "no-go"                     "$HELP"
assert_rc       "notify-help-exit-0"       0 "$NOTIFY" -h
assert_contains "notify-help-long-flag"    "polylane-notify.sh" "$("$NOTIFY" --help 2>&1)"

# --- quiet no-op when osascript is absent: exit 0 and completely silent -------
assert_rc "notify-noop-done-exit-0" 0 noop done "lane finished"
assert_eq "notify-noop-done-silent" "" "$(noop done "lane finished" 2>&1)"

# --- frozen contract: EVERY event exits 0 (never breaks a set -e caller) ------
assert_rc "notify-noop-go-exit-0"         0 noop go    "verdict GO"
assert_rc "notify-noop-no-go-exit-0"      0 noop no-go "verdict NO-GO"
assert_rc "notify-noop-halt-exit-0"       0 noop halt  "run halted"
assert_rc "notify-noop-stall-exit-0"      0 noop stall "lane stuck"
assert_rc "notify-noop-unknown-exit-0"    0 noop bogus "unknown event"
assert_rc "notify-noop-empty-exit-0"      0 noop
assert_rc "notify-noop-extra-args-exit-0" 0 noop go "msg" extra ignored

# --- osascript present: empty args prints usage to STDERR, still exit 0 -------
# Safe: the empty-event branch returns before any notification is fired.
if command -v osascript >/dev/null 2>&1; then
  ERR=$("$NOTIFY" 2>&1 1>/dev/null)
  assert_contains "notify-empty-usage-stderr" "USAGE:" "$ERR"
  assert_rc       "notify-empty-usage-exit-0" 0 "$NOTIFY"
else
  pass "notify-osascript-skipped"
fi

finish
