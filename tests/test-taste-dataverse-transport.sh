#!/usr/bin/env bash
# Focused hermetic test for the dataverse-transport lane: observed JSON readiness
# (no magic sleep), CDP download path for redirected data files, failure-class
# taxonomy (challenge/timeout/redirect/transport/checksum), bounded operations,
# and resumable content-addressed fetches. No network, no real Chrome required.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
ADAPTER="$ROOT/benchmarks/taste-live/tools/dataverse-acquire.mjs"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-dv.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
ASSERTIONS=0

expect_eq() {
  if [ "$1" = "$2" ]; then ASSERTIONS=$((ASSERTIONS + 1));
  else echo "FAIL ${3:-assertion}: expected [$1] got [$2]" >&2; exit 1; fi
}
expect_contains() {
  if printf '%s' "$2" | grep -qF -- "$1"; then ASSERTIONS=$((ASSERTIONS + 1));
  else echo "FAIL ${3:-assertion}: [$2] does not contain [$1]" >&2; exit 1; fi
}
expect_absent() {
  if printf '%s' "$2" | grep -qF -- "$1"; then
    echo "FAIL ${3:-assertion}: [$2] must not contain [$1]" >&2; exit 1
  fi
  ASSERTIONS=$((ASSERTIONS + 1))
}

command -v node >/dev/null 2>&1 || { echo "SKIP: node unavailable" >&2; exit 0; }

# --- 1. hermetic selftest covers the pure transport helpers ------------------
SELFTEST=$(node "$ADAPTER" --selftest)
case "$SELFTEST" in SELFTEST-OK*) ASSERTIONS=$((ASSERTIONS + 1)) ;; *) echo "FAIL adapter selftest: $SELFTEST" >&2; exit 1 ;; esac

# --- 2. no magic sleep; observed readiness is the contract -------------------
if grep -Eq 'sleep\(1500\)|sleep\(10000\)' "$ADAPTER"; then
  echo "FAIL: adapter still contains a magic warm-up sleep" >&2; exit 1
fi
ASSERTIONS=$((ASSERTIONS + 1))
grep -q 'waitForReadiness' "$ADAPTER" || { echo "FAIL: adapter lacks observed-readiness wait" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))
grep -q 'api/info/version' "$ADAPTER" || { echo "FAIL: readiness must probe a JSON endpoint" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# --- 3. CDP download path exists for redirected data files -------------------
grep -q 'Browser.setDownloadBehavior' "$ADAPTER" || { echo "FAIL: no CDP download behavior for redirected files" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))
grep -q 'Browser.downloadProgress' "$ADAPTER" || { echo "FAIL: no bounded download completion wait" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# --- 4. session hygiene: ephemeral context only, never a personal profile ----
grep -q -- '--user-data-dir' "$ADAPTER" || { echo "FAIL: adapter must pin an ephemeral user-data-dir" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))
if grep -Eq 'document\.cookie|Network\.getAllCookies|Network\.getCookies|Application Support/Google' "$ADAPTER"; then
  echo "FAIL: adapter must never inspect cookies or a personal profile" >&2; exit 1
fi
ASSERTIONS=$((ASSERTIONS + 1))

# --- 5. usage / argument failure shapes --------------------------------------
RC=0; node "$ADAPTER" >/dev/null 2>&1 || RC=$?
expect_eq 2 "$RC" usage-rc

RC=0; OUT=$(node "$ADAPTER" discover --cache "$TMP/cache" 2>/dev/null) || RC=$?
expect_eq 3 "$RC" discover-missing-pid-rc
expect_contains '"status":"UNKNOWN"' "$OUT" discover-missing-pid-unknown

# --- 6. transport class: unusable Chrome binary is UNKNOWN/transport ---------
RC=0; OUT=$(CHROME_BIN="$TMP/no-such-chrome" POLYLANE_SOURCE_CANARY_TIMEOUT_MS=4000 \
  node "$ADAPTER" discover --pid doi:10.7910/DVN/9FKSQI --cache "$TMP/cache" 2>/dev/null) || RC=$?
expect_eq 3 "$RC" no-chrome-rc
expect_contains '"status":"UNKNOWN"' "$OUT" no-chrome-unknown
expect_contains '"class":"transport"' "$OUT" no-chrome-class

# --- 7. timeout class: bounded deadline fires, never hangs -------------------
# /usr/bin/true "launches" instantly and exits; the DevTools port never appears,
# so the operation must end at the deadline with class=timeout.
START=$(date +%s)
RC=0; OUT=$(CHROME_BIN=/usr/bin/true POLYLANE_SOURCE_CANARY_TIMEOUT_MS=1500 \
  node "$ADAPTER" discover --pid doi:10.7910/DVN/9FKSQI --cache "$TMP/cache" 2>/dev/null) || RC=$?
ELAPSED=$(( $(date +%s) - START ))
expect_eq 3 "$RC" timeout-rc
expect_contains '"class":"timeout"' "$OUT" timeout-class
[ "$ELAPSED" -le 30 ] || { echo "FAIL: bounded op took ${ELAPSED}s" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# --- 8. resumable fetch: expected object already cached => OK, no network ----
CACHE="$TMP/cache-resume"
printf 'resumable-bytes' >"$TMP/blob"
SHA=$(shasum -a 256 "$TMP/blob" | awk '{print $1}')
mkdir -p "$CACHE/objects/${SHA:0:2}"
cp "$TMP/blob" "$CACHE/objects/${SHA:0:2}/$SHA"
RC=0; OUT=$(CHROME_BIN="$TMP/no-such-chrome" \
  node "$ADAPTER" fetch --pid doi:10.7910/DVN/9FKSQI --file 424242 --cache "$CACHE" --sha256 "$SHA" 2>/dev/null) || RC=$?
expect_eq 0 "$RC" resume-rc
expect_contains '"status":"OK"' "$OUT" resume-ok
expect_contains '"resumed":true' "$OUT" resume-flag
expect_contains "\"sha256\":\"$SHA\"" "$OUT" resume-sha

# A quarantined-size (empty) cached object must NOT satisfy resume.
: >"$CACHE/objects/${SHA:0:2}/$SHA"
RC=0; OUT=$(CHROME_BIN="$TMP/no-such-chrome" POLYLANE_SOURCE_CANARY_TIMEOUT_MS=1500 \
  node "$ADAPTER" fetch --pid doi:10.7910/DVN/9FKSQI --file 424242 --cache "$CACHE" --sha256 "$SHA" 2>/dev/null) || RC=$?
expect_eq 3 "$RC" tampered-resume-rc
expect_contains '"status":"UNKNOWN"' "$OUT" tampered-resume-unknown

# --- 9. receipts never leak session material ---------------------------------
expect_absent 'cookie' "$OUT" receipt-no-cookie
expect_absent 'Cookie' "$OUT" receipt-no-cookie-cap

# --- 10. full failure taxonomy exists: challenge/timeout/redirect/transport/checksum
grep -q 'classifyFailure' "$ADAPTER" || { echo "FAIL: adapter lacks classifyFailure taxonomy" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))
for c in challenge timeout redirect transport checksum; do
  grep -q "'$c'" "$ADAPTER" || { echo "FAIL: missing failure class $c" >&2; exit 1; }
  ASSERTIONS=$((ASSERTIONS + 1))
done

echo "PASS test-taste-dataverse-transport assertions=$ASSERTIONS"
