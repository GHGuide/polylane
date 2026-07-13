#!/usr/bin/env bash
# polylane-corpus.sh — recent window verbatim, older one-lined, hard byte cap.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
CORPUS="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-corpus.sh"

make_tmpdir
D="$TEST_TMPDIR/docs/polylane"; mkdir -p "$D"
i=1; while [ "$i" -le 6 ]; do
  printf '# Cycle %s headline\n- did thing %s\n' "$i" "$i" > "$D/cycle-$i-digest.md"; i=$((i+1))
done

out=$(POLYLANE_CORPUS_DIR="$D" POLYLANE_CORPUS_MAX_BYTES=99999 "$CORPUS" compact 3)
C="$D/corpus.md"
assert_contains "corpus-recent-verbatim"  "===== cycle 6 ====="  "$(cat "$C")"
assert_contains "corpus-window-4-in"      "===== cycle 4 ====="  "$(cat "$C")"
assert_eq       "corpus-window-count"     "3" "$(grep -c '=====' "$C")"
assert_contains "corpus-old-oneline"      "cycle 1: Cycle 1 headline" "$(cat "$C")"
# cycle 3 is OUTSIDE the window -> must NOT be verbatim
if grep -q '===== cycle 3 =====' "$C"; then fail "corpus-3-not-verbatim" "cycle 3 leaked verbatim"; else pass "corpus-3-not-verbatim"; fi

# hard cap: 30 fat digests -> bytes under cap, newest intact, oldest dropped
i=1; while [ "$i" -le 30 ]; do
  head -c 800 /dev/zero | tr '\0' x > "$D/cycle-$i-digest.md"; printf '\n# Cycle %s\n' "$i" >> "$D/cycle-$i-digest.md"; i=$((i+1))
done
POLYLANE_CORPUS_DIR="$D" POLYLANE_CORPUS_MAX_BYTES=2500 "$CORPUS" compact 3 >/dev/null
bytes=$(wc -c < "$C" | tr -d ' ')
if [ "$bytes" -le 2500 ]; then pass "corpus-under-cap"; else fail "corpus-under-cap" "$bytes > 2500"; fi
assert_contains "corpus-newest-intact" "===== cycle 30 =====" "$(cat "$C")"
if grep -q 'cycle 1:' "$C"; then fail "corpus-oldest-dropped" "cycle 1 survived the cap"; else pass "corpus-oldest-dropped"; fi

finish
