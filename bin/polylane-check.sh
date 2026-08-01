#!/usr/bin/env bash
#
# polylane-check.sh <cache-dir> -- <command> [args...]
#
# Run an expensive verification command at most once for the same source,
# command, cwd, and build environment. Successful and failed results are cached:
# an unchanged failure is evidence to repair source, not permission to burn usage
# by rerunning the same command. The cache directory should live in the canonical
# project's .polylane/check-cache/, outside lane worktrees.

set -u

usage() {
  echo "usage: polylane-check.sh <cache-dir> -- <command> [args...]" >&2
  exit 2
}

[ $# -ge 3 ] || usage
CACHE_DIR="$1"
shift
[ "${1:-}" = "--" ] || usage
shift
[ $# -gt 0 ] || usage

command_text() {
  local arg
  for arg in "$@"; do printf '%q ' "$arg"; done
}

source_fingerprint() {
  local root file
  root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    printf 'nogit:%s\n' "$(pwd -P)"
    return
  }
  {
    printf 'root=%s\n' "$root"
    git rev-parse HEAD 2>/dev/null || true
    git diff --no-ext-diff --binary 2>/dev/null || true
    git diff --cached --no-ext-diff --binary 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null | LC_ALL=C sort |
      while IFS= read -r file; do
        [ -f "$file" ] || continue
        printf 'untracked=%s ' "$file"
        cksum "$file" 2>/dev/null || true
      done
  } | cksum | awk '{print $1 ":" $2}'
}

mkdir -p "$CACHE_DIR" || exit 2
CMD_TEXT=$(command_text "$@")
COMMAND_PATH=$(command -v "$1" 2>/dev/null || printf '%s' "$1")
ENV_FP=$(printf '%s\n' "$(uname -srm 2>/dev/null)" "${DEVELOPER_DIR:-}" \
  "${SDKROOT:-}" "$COMMAND_PATH" | cksum | awk '{print $1 ":" $2}')
KEY=$(printf '%s\n%s\n%s\n' "$(pwd -P)" "$CMD_TEXT" "$ENV_FP" |
  cksum | awk '{print $1 "-" $2}')
SOURCE_FP=$(source_fingerprint)
ENTRY="$CACHE_DIR/$KEY.result"
OUTPUT="$CACHE_DIR/$KEY.output"

OLD_SOURCE=""
OLD_RC=""
if [ -f "$ENTRY" ]; then
  IFS='|' read -r OLD_SOURCE OLD_RC < "$ENTRY" || true
fi
if [ "$OLD_SOURCE" = "$SOURCE_FP" ] && [ -n "$OLD_RC" ]; then
  if [ "$OLD_RC" = "0" ]; then
    printf 'CHECK-CACHE: HIT PASS source=%s command=%s log=%s\n' "$SOURCE_FP" "$CMD_TEXT" "$OUTPUT"
  else
    printf 'CHECK-CACHE: HIT FAIL rc=%s source=%s command=%s log=%s — change source before retry\n' \
      "$OLD_RC" "$SOURCE_FP" "$CMD_TEXT" "$OUTPUT" >&2
  fi
  exit "$OLD_RC"
fi

TMP_OUT="$OUTPUT.$$"
printf 'CHECK-CACHE: RUN source=%s command=%s\n' "$SOURCE_FP" "$CMD_TEXT"
"$@" > "$TMP_OUT" 2>&1
RC=$?
sed -n '1,240p' "$TMP_OUT"
[ "$(wc -l < "$TMP_OUT" | tr -d ' ')" -le 240 ] ||
  printf 'CHECK-CACHE: output truncated; full log=%s\n' "$OUTPUT"
mv "$TMP_OUT" "$OUTPUT"
TMP_ENTRY="$ENTRY.$$"
printf '%s|%s\n' "$SOURCE_FP" "$RC" > "$TMP_ENTRY"
mv "$TMP_ENTRY" "$ENTRY"
if [ "$RC" = "0" ]; then
  printf 'CHECK-CACHE: PASS source=%s log=%s\n' "$SOURCE_FP" "$OUTPUT"
else
  printf 'CHECK-CACHE: FAIL rc=%s source=%s log=%s — repair source before retry\n' \
    "$RC" "$SOURCE_FP" "$OUTPUT" >&2
fi
exit "$RC"
