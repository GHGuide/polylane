#!/usr/bin/env bash
# Expensive checks execute once per source fingerprint; unchanged pass/fail
# results are reused instead of consuming another model/tool cycle.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

CHECK="$(dirname "$RUNNER")/polylane-check.sh"
make_tmpdir
REPO="$TEST_TMPDIR/repo"
CACHE="$TEST_TMPDIR/cache"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email test@example.invalid
git -C "$REPO" config user.name test
printf 'one\n' > "$REPO/source.txt"
git -C "$REPO" add source.txt
git -C "$REPO" commit -qm init

COUNT="$TEST_TMPDIR/count"
PROBE="$TEST_TMPDIR/probe.sh"
printf '0\n' > "$COUNT"
printf '#!/usr/bin/env bash\nn=$(cat "$1"); n=$((n+1)); printf "%%s\\n" "$n" > "$1"; exit "${2:-0}"\n' > "$PROBE"
chmod +x "$PROBE"

(cd "$REPO" && "$CHECK" "$CACHE" -- "$PROBE" "$COUNT" 0) >/dev/null
(cd "$REPO" && "$CHECK" "$CACHE" -- "$PROBE" "$COUNT" 0) > "$TEST_TMPDIR/hit"
assert_eq "cache-pass-runs-once" "1" "$(cat "$COUNT")"
assert_contains "cache-pass-hit" "CHECK-CACHE: HIT PASS" "$(cat "$TEST_TMPDIR/hit")"

printf 'two\n' >> "$REPO/source.txt"
(cd "$REPO" && "$CHECK" "$CACHE" -- "$PROBE" "$COUNT" 0) >/dev/null
assert_eq "cache-source-change-reruns" "2" "$(cat "$COUNT")"

printf '0\n' > "$COUNT"
(cd "$REPO" && "$CHECK" "$CACHE" -- "$PROBE" "$COUNT" 7) >/dev/null 2>&1 || true
(cd "$REPO" && "$CHECK" "$CACHE" -- "$PROBE" "$COUNT" 7) > "$TEST_TMPDIR/fail-hit" 2>&1 || rc=$?
assert_eq "cache-fail-rc-preserved" "7" "${rc:-0}"
assert_eq "cache-fail-runs-once" "1" "$(cat "$COUNT")"
assert_contains "cache-fail-hit" "CHECK-CACHE: HIT FAIL" "$(cat "$TEST_TMPDIR/fail-hit")"

finish
