#!/usr/bin/env bash
# polylane-corpus.sh — rolling "STORY SO FAR" compaction. Bounds what the Phase-4
# council + Phase-3 research read: recent W cycles verbatim, older one-lined, whole
# file hard-capped (oldest dropped first). jq-free, pure file I/O.
#   compact [W]   (re)build docs/polylane/corpus.md ; W = verbatim window (default 3)
#   path          print the corpus path
# Env: POLYLANE_CORPUS_DIR (default docs/polylane), POLYLANE_CORPUS_WINDOW (3),
#      POLYLANE_CORPUS_MAX_BYTES (20000).
set -euo pipefail
DIR="${POLYLANE_CORPUS_DIR:-docs/polylane}"
OUT="$DIR/corpus.md"
WINDOW="${POLYLANE_CORPUS_WINDOW:-3}"
CAP="${POLYLANE_CORPUS_MAX_BYTES:-20000}"

usage() { echo "usage: polylane-corpus.sh compact [W] | path" >&2; exit 2; }

_cycles() {   # sorted (numeric) cycle numbers that have a digest file
  local f n
  for f in "$DIR"/cycle-*-digest.md; do
    [ -f "$f" ] || continue
    n="${f##*/cycle-}"; n="${n%-digest.md}"
    case "$n" in ''|*[!0-9]*) continue ;; esac
    echo "$n"
  done | sort -n
}

_oneline() {  # one-line summary: first non-blank, de-#'d, trimmed line of a digest
  local line
  line=$(grep -m1 -v '^[[:space:]]*$' "$1" 2>/dev/null || true)
  line="${line#\#}"; line="${line#\#}"; line="${line# }"
  printf 'cycle %s: %s' "$2" "$line"
}

_bytes() { wc -c < "$1" | tr -d ' '; }

_render() {   # reads $recent / $early / $WINDOW from caller scope
  local latest c
  latest=$(printf '%s\n' $recent $early | sort -n | tail -1)
  printf '# STORY SO FAR — corpus through cycle %s\n\n' "${latest:-0}"
  printf '## Earlier (one line each)\n'
  if [ -n "$early" ]; then
    for c in $early; do _oneline "$DIR/cycle-$c-digest.md" "$c"; printf '\n'; done
  else
    printf '(none)\n'
  fi
  printf '\n## Recent (verbatim, last %s cycles)\n\n' "$WINDOW"
  for c in $recent; do
    printf '===== cycle %s =====\n' "$c"
    cat "$DIR/cycle-$c-digest.md"
    printf '\n'
  done
}

cmd_compact() {
  [ "${1:-}" ] && WINDOW="$1"
  mkdir -p "$DIR"
  local all recent early n cutoff rn
  all=$(_cycles); [ -z "$all" ] && { : > "$OUT"; echo "corpus: no digests"; return 0; }
  n=$(printf '%s\n' "$all" | grep -c .)
  cutoff=$(( n - WINDOW )); [ "$cutoff" -lt 0 ] && cutoff=0
  early=$(printf '%s\n' "$all" | head -n "$cutoff")
  recent=$(printf '%s\n' "$all" | tail -n +"$((cutoff + 1))")
  _render > "$OUT"
  # cap: drop oldest EARLY one-liners first, then oldest RECENT blocks; keep >=1 recent
  while [ "$(_bytes "$OUT")" -gt "$CAP" ]; do
    if [ -n "$early" ]; then
      early=$(printf '%s\n' "$early" | tail -n +2)
    else
      rn=$(printf '%s\n' "$recent" | grep -c .)
      [ "$rn" -le 1 ] && break
      recent=$(printf '%s\n' "$recent" | tail -n +2)
    fi
    _render > "$OUT"
  done
  echo "corpus: $OUT ($(_bytes "$OUT") bytes)"
}

case "${1:-}" in
  compact) shift; cmd_compact "$@" ;;
  path)    echo "$OUT" ;;
  *) usage ;;
esac
