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
rm -rf "$DEST/references" "$DEST/assets" "$DEST/benchmarks"
cp -R "$REPO/references" "$DEST/references"
cp -R "$REPO/assets" "$DEST/assets"
if [ -d "$REPO/benchmarks" ]; then cp -R "$REPO/benchmarks" "$DEST/benchmarks"; fi

grep -q '^name: polylane' "$DEST/SKILL.md" || { echo "install: bad SKILL.md" >&2; exit 1; }
test -x "$DEST/bin/polylane-run.sh" || { echo "install: helpers missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-tmux.sh" || { echo "install: isolated tmux runtime missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-harness.sh" || { echo "install: prime harness helper missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-workers.sh" || { echo "install: retained worker helper missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-context.sh" || { echo "install: bounded context helper missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-refine.sh" || { echo "install: refinement helper missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-certify.sh" || { echo "install: certification helper missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-skill-catalog.sh" || { echo "install: metadata skill catalog missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-domain.sh" || { echo "install: domain adapter/grader missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-action-preview.sh" || { echo "install: action preview helper missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-optimize.sh" || { echo "install: accepted-outcome optimizer missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-skill-benchmark.sh" || { echo "install: skill benchmark helper missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-domain-trials.sh" || { echo "install: domain trials helper missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-soak.sh" || { echo "install: soak helper missing" >&2; exit 1; }
test -x "$DEST/bin/polylane-hooks.sh" || { echo "install: lifecycle hook helper missing" >&2; exit 1; }
test -s "$DEST/references/cycle-13-integration.md" || { echo "install: cycle 13 integration reference missing" >&2; exit 1; }
test -s "$DEST/references/evidence-driven-domain-autonomy.md" || { echo "install: domain autonomy reference missing" >&2; exit 1; }
test -s "$DEST/assets/hooks/claude-settings.json" || { echo "install: Claude lifecycle fragment missing" >&2; exit 1; }

echo "installed Claude Code skill -> $DEST"
echo "deps: tmux + jq + claude on PATH. Invoke in Claude Code with: /polylane"
