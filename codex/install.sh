#!/usr/bin/env bash
# codex/install.sh — assemble the polylane Codex skill from this repo.
# Codex discovers skills under .agents/skills (repo) or $HOME/.agents/skills (user).
# The bash engine is agent-agnostic, so the SAME helpers run Codex lanes; this just
# lays them out as a Codex skill dir (SKILL.md + scripts/ + references/ + assets/).
#   ./codex/install.sh          -> user scope  ($HOME/.agents/skills/polylane)
#   ./codex/install.sh --repo   -> repo scope  (./.agents/skills/polylane)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-}" in
  --repo) DEST="$REPO/.agents/skills/polylane" ;;
  ""|--user) DEST="$HOME/.agents/skills/polylane" ;;
  *) echo "usage: install.sh [--user|--repo]" >&2; exit 2 ;;
esac

mkdir -p "$DEST/scripts"
# installed SKILL.md = the Codex overlay (frontmatter + deltas) + the FULL Claude loop
# verbatim (its frontmatter stripped, bin/ -> scripts/). Single source of truth: the
# real SKILL.md — the Codex skill can never drift from the Claude one.
{
  cat "$REPO/codex/SKILL.md"
  echo
  awk 'f; /^---$/{c++; if (c==2) f=1}' "$REPO/SKILL.md" | sed 's#bin/polylane-#scripts/polylane-#g'
} > "$DEST/SKILL.md"
cp "$REPO"/bin/*.sh        "$DEST/scripts/" && chmod +x "$DEST/scripts/"*.sh
cp -R "$REPO/references"   "$DEST/references"
cp -R "$REPO/assets"       "$DEST/assets"

# sanity: SKILL.md frontmatter present + helpers landed
grep -q '^name: polylane' "$DEST/SKILL.md" || { echo "install: bad SKILL.md" >&2; exit 1; }
test -x "$DEST/scripts/polylane-run.sh" || { echo "install: helpers missing" >&2; exit 1; }

echo "installed Codex skill -> $DEST"
echo "deps: tmux + jq + codex on PATH. Invoke in Codex with: \$polylane  (or /skills)"
