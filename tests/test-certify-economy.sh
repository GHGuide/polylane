#!/usr/bin/env bash
# Terminal certification runs the complete suite once; tests already inside
# tests/run.sh must not be invoked again as separate layers.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

make_tmpdir
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CERTIFY="$ROOT/bin/polylane-certify.sh"
FAKEBIN="$TEST_TMPDIR/bin"
CALLS="$TEST_TMPDIR/calls"
mkdir -p "$FAKEBIN"
: > "$CALLS"

for tool in bash shellcheck; do
  printf '%s\n' '#!/bin/sh' 'printf "%s\\t%s\\n" "$(basename "$0")" "$*" >> "$CERT_CALLS"' 'exit 0' > "$FAKEBIN/$tool"
  chmod +x "$FAKEBIN/$tool"
done

CERT_CALLS="$CALLS" PATH="$FAKEBIN:$PATH" /bin/bash "$CERTIFY" terminal > "$TEST_TMPDIR/output"

assert_eq "certify-terminal-full-suite-once" "1" "$(grep -c 'tests/run.sh' "$CALLS")"
assert_eq "certify-terminal-no-direct-skill-parity-repeat" "0" "$(grep -c 'test-skill-parity.sh' "$CALLS" || true)"
assert_eq "certify-terminal-no-direct-installers-repeat" "0" "$(grep -c 'test-installers.sh' "$CALLS" || true)"
assert_eq "certify-terminal-no-direct-install-fresh-repeat" "0" "$(grep -c 'test-install-fresh.sh' "$CALLS" || true)"
assert_eq "certify-terminal-shellcheck-once" "1" "$(grep -c '^shellcheck' "$CALLS")"
assert_eq "certify-terminal-rehearsal-once" "1" "$(grep -c 'polylane-doctor.sh --rehearse' "$CALLS")"

finish
