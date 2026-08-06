#!/usr/bin/env bash
# codex/install.sh — assemble the polylane Codex skill from this repo.
# Installs to the path THIS codex actually scans: $HOME/.codex/skills (verified on
# codex-cli 0.131.0) — falling back to $HOME/.agents/skills (the path in newer docs).
# The bash engine is agent-agnostic, so the SAME helpers run Codex lanes; this just
# lays them out as a Codex skill dir (SKILL.md + scripts/ + references/ + assets/).
#   ./codex/install.sh          -> user scope (auto: ~/.codex/skills else ~/.agents/skills)
#   ./codex/install.sh --repo   -> repo scope (./.codex/skills/polylane)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-}" in
  --repo) DEST="$REPO/.codex/skills/polylane" ;;
  ""|--user)
    if [ -d "$HOME/.codex/skills" ]; then DEST="$HOME/.codex/skills/polylane"
    else DEST="$HOME/.agents/skills/polylane"; fi ;;
  *) echo "usage: install.sh [--user|--repo]" >&2; exit 2 ;;
esac

mkdir -p "$DEST/scripts"
# Codex owns a standalone product contract. The runner remains shared, but Codex
# never inherits Claude-only prompt syntax, models, memory, or stop conditions.
cp "$REPO/codex/SKILL.md" "$DEST/SKILL.md"
cp "$REPO"/bin/*.sh        "$DEST/scripts/" && chmod +x "$DEST/scripts/"*.sh
# rm first: `cp -R dir existing-dir` NESTS (references/references) and leaves the
# top level STALE — every reinstall after the first shipped old references (real bug).
rm -rf "$DEST/references" "$DEST/assets" "$DEST/benchmarks"
cp -R "$REPO/references"   "$DEST/references"
cp -R "$REPO/assets"       "$DEST/assets"
# Product benchmark corpora are shipped when present. Keep this conditional so
# older checkouts install cleanly while a fresh cycle-9 checkout never omits it.
if [ -d "$REPO/benchmarks" ]; then cp -R "$REPO/benchmarks" "$DEST/benchmarks"; fi
mkdir -p "$DEST/agents"
cp "$REPO/codex/openai.yaml" "$DEST/agents/openai.yaml"   # interface metadata (how the working .system skills declare themselves)

# sanity: SKILL.md frontmatter present + helpers landed
grep -q '^name: polylane' "$DEST/SKILL.md" || { echo "install: bad SKILL.md" >&2; exit 1; }
test -x "$DEST/scripts/polylane-run.sh" || { echo "install: helpers missing" >&2; exit 1; }
test -x "$DEST/scripts/polylane-coordinate.sh" || { echo "install: coordination helper missing" >&2; exit 1; }

echo "installed Codex skill -> $DEST"
echo "deps: tmux + jq + codex on PATH. Invoke in Codex with: \$polylane  (or /skills)"
