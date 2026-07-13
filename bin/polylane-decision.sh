#!/usr/bin/env bash
#
# polylane-decision.sh <decisions-dir> <cmd> [args...]
#
# Durable, readable records of the BIG decisions a /polylane run makes — the
# "north-star" trail. The blackboard (polylane-memory log) is a terse machine index;
# THIS writes one human-readable Markdown file per major decision (ADR-style), so
# every later cycle and every lane can re-read WHY a settled call was made and never
# silently contradict it. Files live under the caller-supplied decisions dir, e.g. docs/polylane/decisions/ (durable —
# the runner's cleanup never touches docs/).
#
# Commands:
#   new <title> <decision> [why] [consequences] [cycle]
#        write decisions/NNN-<slug>.md (auto-numbered) + append to INDEX.md; print path
#   list        print the index (all decisions, newest last)
#   context     print a compact digest of ALL decisions — feed this into a cycle/lane
#               so the build stays consistent with every prior call
#
# bash-3.2 safe. No jq — plain files, so it works even without the memory helper.

set -euo pipefail

DIR="${1:?usage: polylane-decision.sh <decisions-dir> <cmd> [args]}"
CMD="${2:?usage: polylane-decision.sh <decisions-dir> <cmd> [args]}"
shift 2
IDX="$DIR/INDEX.md"

slug() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-50; }

case "$CMD" in
  new)
    title="${1:?new needs a <title>}"; decision="${2:?new needs a <decision>}"
    why="${3:-}"; consequences="${4:-}"; cycle="${5:-}"
    mkdir -p "$DIR"
    # next number = 1 + highest existing NNN- prefix (bash-3.2 safe, no mapfile)
    n=0
    for f in "$DIR"/[0-9][0-9][0-9]-*.md; do
      [ -e "$f" ] || continue
      b=$(basename "$f"); cur=${b%%-*}
      cur=$((10#$cur)); [ "$cur" -gt "$n" ] && n=$cur
    done
    n=$((n + 1)); nnn=$(printf '%03d' "$n")
    file="$DIR/$nnn-$(slug "$title").md"
    {
      echo "# ADR $nnn — $title"
      echo
      echo "- **Status:** accepted"
      [ -n "$cycle" ] && echo "- **Cycle:** $cycle"
      echo
      echo "## Decision"
      echo "$decision"
      echo
      echo "## Why"
      echo "${why:-_(not recorded)_}"
      echo
      echo "## Consequences"
      echo "${consequences:-_(not recorded)_}"
    } > "$file"
    [ -f "$IDX" ] || { echo "# Decisions — the north-star trail"; echo; } > "$IDX"
    echo "- [$nnn $title]($(basename "$file")) — $decision" >> "$IDX"
    echo "$file"
    ;;

  list)
    [ -f "$IDX" ] && cat "$IDX" || echo "(no decisions recorded yet)"
    ;;

  context)
    # compact digest for injecting into a cycle prompt / lane preamble
    if [ ! -d "$DIR" ] || ! ls "$DIR"/[0-9][0-9][0-9]-*.md >/dev/null 2>&1; then
      echo "(no decisions recorded yet)"; exit 0
    fi
    echo "=== SETTLED DECISIONS (do not contradict; re-open only with a new ADR) ==="
    for f in "$DIR"/[0-9][0-9][0-9]-*.md; do
      [ -e "$f" ] || continue
      title=$(sed -n '1s/^# //p' "$f")
      dec=$(awk '/^## Decision/{getline; print; exit}' "$f")
      echo "- $title: $dec"
    done
    ;;

  *)
    echo "polylane-decision: unknown command '$CMD' (new|list|context)" >&2
    exit 2
    ;;
esac
