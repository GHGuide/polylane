#!/usr/bin/env bash
# claude-code/install.sh — assemble the Polylane Claude Code skill from this repo.
# The shared engine stays in bin/; this installer packages the current core plus
# the Claude Code SKILL.md entrypoint without copying core implementation in source.
#   ./claude-code/install.sh          -> user scope (~/.claude/skills/polylane)
#   ./claude-code/install.sh --repo   -> repo scope (./.claude/skills/polylane)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-}" in
  --repo) DEST="$REPO/.claude/skills/polylane" ;;
  ""|--user) DEST="$HOME/.claude/skills/polylane" ;;
  *) echo "usage: install.sh [--user|--repo]" >&2; exit 2 ;;
esac

mkdir -p "$DEST/bin"
cp "$REPO/SKILL.md" "$DEST/SKILL.md"
cp "$REPO"/bin/*.sh "$DEST/bin/" && chmod +x "$DEST/bin/"*.sh
cp -R "$REPO/references" "$DEST/references"
cp -R "$REPO/assets" "$DEST/assets"

grep -q '^name: polylane' "$DEST/SKILL.md" || { echo "install: bad SKILL.md" >&2; exit 1; }
test -x "$DEST/bin/polylane-run.sh" || { echo "install: helpers missing" >&2; exit 1; }

echo "installed Claude Code skill -> $DEST"
echo "deps: tmux + jq + claude on PATH. Invoke in Claude Code with: /polylane"
