#!/usr/bin/env bash
# polylane-notify.sh — macOS banner + sound for run events. Exercised as a CLI.
#
# Non-vacuous by construction: the REAL notification path is driven with a stub
# `osascript` on PATH that RECORDS its args (so we assert what would have been
# displayed) and fires no real banner; the no-op path is driven with osascript
# genuinely absent. Both branches are actually executed. bash-3.2 safe.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
NOTIFY="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-notify.sh"

make_tmpdir
STUB="$TEST_TMPDIR/bin"; mkdir -p "$STUB"
LOG="$TEST_TMPDIR/osascript.log"

# a fake osascript that records its args and stays silent (no real notification)
cat > "$STUB/osascript" <<EOF
#!/bin/sh
printf '%s ' "\$@" >> "$LOG"
printf '\n' >> "$LOG"
exit 0
EOF
chmod +x "$STUB/osascript"

# fires NOTIFY with our stub osascript first on PATH; echoes what it recorded
fire() { : > "$LOG"; PATH="$STUB:$PATH" "$NOTIFY" "$@" >/dev/null 2>&1; cat "$LOG"; }

# --- help: usage on stdout, exit 0 (reached before the osascript check) -------
HELP=$("$NOTIFY" -h 2>&1)
assert_contains "notify-help-usage"        "USAGE:"                     "$HELP"
assert_contains "notify-help-lists-events" "no-go"                      "$HELP"
assert_rc       "notify-help-exit-0"       0 "$NOTIFY" -h
assert_contains "notify-help-long-flag"    "polylane-notify.sh" "$("$NOTIFY" --help 2>&1)"

# --- REAL path (stub osascript present): builds the right notification, silent -
GO=$(fire go "verdict GO")
assert_contains "notify-go-title"     'title "polylane"'   "$GO"
assert_contains "notify-go-subtitle"  'subtitle "go"'      "$GO"
assert_contains "notify-go-message"   'verdict GO'         "$GO"
assert_contains "notify-go-sound"     'sound name "Glass"' "$GO"
assert_eq       "notify-go-silent"    "" "$(PATH="$STUB:$PATH" "$NOTIFY" go "verdict GO" 2>&1)"

# per-event sound mapping is real, not vacuous
assert_contains "notify-halt-sound-basso"  'sound name "Basso"'  "$(fire halt "x")"
assert_contains "notify-done-sound-ping"   'sound name "Ping"'   "$(fire done "x")"
assert_contains "notify-stall-sound-sosumi" 'sound name "Sosumi"' "$(fire stall "x")"
# unknown event → banner, NO sound line
UNK=$(fire bogus "x")
assert_contains "notify-unknown-banner"    'title "polylane"' "$UNK"
if printf '%s' "$UNK" | grep -q 'sound name'; then fail "notify-unknown-no-sound" "unknown event added a sound"; else pass "notify-unknown-no-sound"; fi
# message with a double-quote is escaped, not broken
assert_contains "notify-escapes-quote" '\"' "$(fire go 'a "quoted" msg')"

# --- NO-OP path (osascript genuinely absent): silent, exit 0 ------------------
BASH_BIN="${BASH:-$(command -v bash)}"; case "$BASH_BIN" in /*) ;; *) BASH_BIN=$(command -v "$BASH_BIN") ;; esac
noop() { env -i "$BASH_BIN" "$NOTIFY" "$@"; }   # empty env → command -v osascript misses
assert_rc "notify-noop-exit-0"   0 noop go "no osascript here"
assert_eq "notify-noop-silent"   "" "$(noop go "no osascript here" 2>&1)"

# --- frozen contract: EVERY event exits 0 (never breaks a set -e caller) ------
for ev in go no-go halt stall done bogus; do
  assert_rc "notify-exit0-$ev" 0 env "PATH=$STUB:$PATH" "$NOTIFY" "$ev" "msg"
done
assert_rc "notify-exit0-empty" 0 env "PATH=$STUB:$PATH" "$NOTIFY"

finish
