#!/usr/bin/env bash
#
# polylane-claudemem.sh <memory-dir> <cmd> [args...]
#
# Bridge between a polylane run and Claude Code's CROSS-SESSION memory. polylane's
# max-state.json is per-run; this persists DURABLE learnings into the user's Claude
# memory dir so knowledge compounds across runs (and projects): a project's real
# build/test command, a carving rule that caused a NO-GO, a recurring gotcha. Every
# fact is written in Claude's memory format (frontmatter + body) and indexed in
# MEMORY.md, namespaced with a `polylane-` slug so it never clobbers user memories.
#
# Commands:
#   add <slug> <description> <body> [type]   write/replace a fact + index it
#                                            (type: project|reference|feedback; default project)
#   relevant <query>                         print facts whose text matches <query> (recall)
#   list                                     list all polylane facts (slug — description)
#   read <slug>                              print one fact's body
#
# Only DURABLE, cross-run-useful, NON-secret learnings belong here — never a
# one-off run detail, never a token/key/password. bash-3.2 safe; no jq needed.

set -euo pipefail

DIR="${1:?usage: polylane-claudemem.sh <memory-dir> <cmd> [args]}"
CMD="${2:?usage: polylane-claudemem.sh <memory-dir> <cmd> [args]}"
shift 2
IDX="$DIR/MEMORY.md"

# normalize a slug to filesystem-safe kebab, always polylane-prefixed
_slug() {
  local s; s=$(printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')
  case "$s" in polylane-*) printf '%s' "$s" ;; *) printf 'polylane-%s' "$s" ;; esac
}

case "$CMD" in
  add)
    slug=$(_slug "${1:?slug required}"); desc="${2:?description required}"; body="${3:?body required}"; type="${4:-project}"
    mkdir -p "$DIR"
    f="$DIR/$slug.md"
    # a secrets tripwire — refuse to persist anything that looks sensitive
    if printf '%s %s' "$desc" "$body" | grep -qiE 'api[_-]?key|secret|password|token|-----BEGIN|bearer '; then
      echo "polylane-claudemem: REFUSED — content looks sensitive; memory must stay secret-free" >&2; exit 2
    fi
    {
      printf -- '---\n'
      printf 'name: %s\n' "$slug"
      printf 'description: %s\n' "$desc"
      printf 'metadata:\n  type: %s\n' "$type"
      printf -- '---\n\n'
      printf '%s\n' "$body"
    } > "$f"
    # ensure exactly one index line for this slug in MEMORY.md
    [ -f "$IDX" ] || printf '# Memory index\n\n' > "$IDX"
    grep -v "]($slug.md)" "$IDX" > "$IDX.tmp" 2>/dev/null || cp "$IDX" "$IDX.tmp"
    mv "$IDX.tmp" "$IDX"
    printf -- '- [%s](%s.md) — %s\n' "$slug" "$slug" "$desc" >> "$IDX"
    echo "$f"
    ;;

  relevant)
    q="${1:?query required}"
    [ -d "$DIR" ] || { echo "(no memory dir yet)"; exit 0; }
    found=0
    for f in "$DIR"/polylane-*.md; do
      [ -f "$f" ] || continue
      if grep -qiE "$q" "$f" 2>/dev/null; then
        found=1
        printf '### %s\n' "$(basename "$f" .md)"
        # print the body (everything after the frontmatter), trimmed
        awk 'f{print} /^---$/{c++} c==2 && !f{f=1}' "$f" | sed '/^[[:space:]]*$/d' | head -8
        printf '\n'
      fi
    done
    [ "$found" = 1 ] || echo "(no matching polylane memory for '$q')"
    ;;

  list)
    [ -d "$DIR" ] || { echo "(no memory dir yet)"; exit 0; }
    for f in "$DIR"/polylane-*.md; do
      [ -f "$f" ] || continue
      d=$(grep -m1 '^description:' "$f" | sed 's/^description:[[:space:]]*//')
      printf '%s — %s\n' "$(basename "$f" .md)" "$d"
    done
    ;;

  read)
    f="$DIR/$(_slug "${1:?slug required}").md"
    [ -f "$f" ] && cat "$f" || { echo "polylane-claudemem: no fact '$1'" >&2; exit 1; }
    ;;

  *)
    echo "polylane-claudemem: unknown command '$CMD' (add|relevant|list|read)" >&2
    exit 2
    ;;
esac
