# tests/helpers.sh — shared test assertions + tmpdir fixtures (bash-3.2 safe).
#
# Source this from each tests/test-*.sh, then source $RUNNER to get the
# functions under test (its main is guarded by BASH_SOURCE, so nothing runs).
# Every assertion prints exactly one "PASS <name>" or "FAIL <name> — <why>"
# line; tests/run.sh counts those lines. Call `finish` last: exits 0 iff no
# FAIL was recorded.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$TESTS_DIR/../bin/polylane-run.sh"
FIXTURES="$TESTS_DIR/fixtures"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL %s — %s\n' "$1" "${2:-assertion failed}"; }

# assert_eq NAME EXPECTED ACTUAL
assert_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected [$2] got [$3]"; fi
}

# assert_contains NAME NEEDLE HAYSTACK — fixed-string match
assert_contains() {
  if printf '%s' "$3" | grep -qF "$2"; then
    pass "$1"
  else
    fail "$1" "output does not contain [$2]"
  fi
}

# assert_ok NAME CMD... — expect exit 0 (CMD runs in a subshell, so functions
# that `exit` cannot kill the test file)
assert_ok() {
  local name="$1"; shift
  if ( "$@" ) >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "expected rc 0, got $?"
  fi
}

# assert_fail NAME CMD... — expect any non-zero exit
assert_fail() {
  local name="$1"; shift
  if ( "$@" ) >/dev/null 2>&1; then
    fail "$name" "expected non-zero rc, got 0"
  else
    pass "$name"
  fi
}

# assert_rc NAME WANT_RC CMD... — expect an exact exit code
assert_rc() {
  local name="$1" want="$2" rc=0; shift 2
  ( "$@" ) >/dev/null 2>&1 || rc=$?
  if [ "$rc" = "$want" ]; then pass "$name"; else fail "$name" "expected rc $want, got $rc"; fi
}

# --- tmpdir fixtures (auto-cleaned on exit) ---------------------------------

HELPER_TMPDIRS=""

# make_tmpdir — creates a fresh dir and puts its path in $TEST_TMPDIR.
# Deliberately NOT `d=$(make_tmpdir)`: a command substitution would register
# the dir for cleanup in a subshell and the registration would be lost.
make_tmpdir() {
  TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/polylane-tests.XXXXXX") || {
    echo "helpers: mktemp failed" >&2; exit 1
  }
  HELPER_TMPDIRS="$HELPER_TMPDIRS $TEST_TMPDIR"
}

cleanup_tmpdirs() {
  local d
  for d in $HELPER_TMPDIRS; do
    case "$d" in
      "${TMPDIR:-/tmp}"/polylane-tests.*) rm -rf "$d" ;;
    esac
  done
}
trap cleanup_tmpdirs EXIT

# finish — per-file summary; exit 0 iff all assertions passed
finish() {
  printf '%s: %d pass, %d fail\n' "$(basename "$0")" "$PASS_COUNT" "$FAIL_COUNT"
  [ "$FAIL_COUNT" -eq 0 ]
}
