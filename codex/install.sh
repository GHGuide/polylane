#!/usr/bin/env bash
# codex/install.sh — assemble the polylane Codex skill from this repo.
# Installs to every existing user skill root Codex may scan: $HOME/.codex/skills
# and $HOME/.agents/skills. Keeping both synchronized avoids a stale duplicate
# winning skill discovery when desktop and CLI builds prefer different roots.
# The bash engine is agent-agnostic, so the SAME helpers run Codex lanes; this just
# lays them out as a Codex skill dir (SKILL.md + scripts/ + references/ + assets/).
#   ./codex/install.sh          -> user scope (auto: ~/.codex/skills else ~/.agents/skills)
#   ./codex/install.sh --agents -> force ~/.agents/skills/polylane only
#   ./codex/install.sh --repo   -> repo scope (./.codex/skills/polylane)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
DESTS=()

case "${1:-}" in
  --repo) DESTS=("$REPO/.codex/skills/polylane") ;;
  --agents) DESTS=("$HOME/.agents/skills/polylane") ;;
  ""|--user)
    [ -d "$HOME/.codex/skills" ] && DESTS+=("$HOME/.codex/skills/polylane")
    [ -d "$HOME/.agents/skills" ] && DESTS+=("$HOME/.agents/skills/polylane")
    [ "${#DESTS[@]}" -gt 0 ] || DESTS=("$HOME/.codex/skills/polylane")
    ;;
  *) echo "usage: install.sh [--user|--agents|--repo]" >&2; exit 2 ;;
esac

install_one() {
  local dest="$1"
  mkdir -p "$dest/scripts"
  # Codex owns a standalone product contract. The runner remains shared, but Codex
  # never inherits Claude-only prompt syntax, models, memory, or stop conditions.
  cp "$REPO/codex/SKILL.md" "$dest/SKILL.md"
  cp "$REPO"/bin/*.sh "$dest/scripts/" && chmod +x "$dest/scripts/"*.sh
  # rm first: `cp -R dir existing-dir` NESTS (references/references) and leaves the
  # top level STALE — every reinstall after the first shipped old references.
  rm -rf "$dest/references" "$dest/assets" "$dest/benchmarks"
  cp -R "$REPO/references" "$dest/references"
  cp -R "$REPO/assets" "$dest/assets"
  if [ -d "$REPO/benchmarks" ]; then cp -R "$REPO/benchmarks" "$dest/benchmarks"; fi
  mkdir -p "$dest/agents"
  cp "$REPO/codex/openai.yaml" "$dest/agents/openai.yaml"

  grep -q '^name: polylane' "$dest/SKILL.md" || { echo "install: bad SKILL.md" >&2; exit 1; }
  test -x "$dest/scripts/polylane-run.sh" || { echo "install: helpers missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-coordinate.sh" || { echo "install: coordination helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-harness.sh" || { echo "install: prime harness helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-workers.sh" || { echo "install: retained worker helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-context.sh" || { echo "install: bounded context helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-refine.sh" || { echo "install: refinement helper missing" >&2; exit 1; }
  echo "installed Codex skill -> $dest"
}

for DEST in "${DESTS[@]}"; do install_one "$DEST"; done
echo "deps: tmux + jq + codex on PATH. Invoke in Codex with: \$polylane  (or /skills)"
