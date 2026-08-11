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

build_one() {
  local dest="$1"
  mkdir -p "$dest/bin"
  cp "$REPO/SKILL.md" "$dest/SKILL.md"
  cp "$REPO"/bin/*.sh "$dest/bin/" && chmod +x "$dest/bin/"*.sh
  cp -R "$REPO/references" "$dest/references"
  cp -R "$REPO/assets" "$dest/assets"
  if [ -d "$REPO/benchmarks" ]; then cp -R "$REPO/benchmarks" "$dest/benchmarks"; fi

  grep -q '^name: polylane' "$dest/SKILL.md" || { echo "install: bad SKILL.md" >&2; exit 1; }
  test -x "$dest/bin/polylane-run.sh" || { echo "install: helpers missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-tmux.sh" || { echo "install: isolated tmux runtime missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-harness.sh" || { echo "install: prime harness helper missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-workers.sh" || { echo "install: retained worker helper missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-context.sh" || { echo "install: bounded context helper missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-refine.sh" || { echo "install: refinement helper missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-skill-catalog.sh" || { echo "install: metadata skill catalog missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-domain.sh" || { echo "install: domain adapter/grader missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-action-preview.sh" || { echo "install: action preview helper missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-optimize.sh" || { echo "install: accepted-outcome optimizer missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-skill-benchmark.sh" || { echo "install: skill benchmark helper missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-domain-trials.sh" || { echo "install: domain trials helper missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-soak.sh" || { echo "install: soak helper missing" >&2; exit 1; }
  test -x "$dest/bin/polylane-hooks.sh" || { echo "install: lifecycle hook helper missing" >&2; exit 1; }
  test -s "$dest/references/cycle-13-integration.md" || { echo "install: cycle 13 integration reference missing" >&2; exit 1; }
  test -s "$dest/references/evidence-driven-domain-autonomy.md" || { echo "install: domain autonomy reference missing" >&2; exit 1; }
  test -s "$dest/assets/hooks/claude-settings.json" || { echo "install: Claude lifecycle fragment missing" >&2; exit 1; }
}

install_one() {
  local dest="$1" parent name stage backup
  parent="$(dirname "$dest")"
  name="$(basename "$dest")"
  backup=""
  mkdir -p "$parent"
  stage="$(mktemp -d "$parent/.${name}.staging.XXXXXX")" || {
    echo "install: could not create staging package for $dest" >&2
    return 1
  }

  # Build and validate before touching an existing package. This also supports
  # a full clone whose source checkout is the destination being reinstalled.
  if ! build_one "$stage"; then
    rm -rf "$stage"
    return 1
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup="$(mktemp -d "$parent/.${name}.backup.XXXXXX")" || {
      rm -rf "$stage"
      echo "install: could not reserve rollback path for $dest" >&2
      return 1
    }
    rmdir "$backup"
    if ! mv "$dest" "$backup"; then
      rm -rf "$stage"
      echo "install: could not preserve existing package at $dest" >&2
      return 1
    fi
  fi

  if ! mv "$stage" "$dest"; then
    rm -rf "$stage"
    if [ -n "$backup" ] && ! mv "$backup" "$dest"; then
      echo "install: replacement failed and rollback failed; preserved package is $backup" >&2
    fi
    return 1
  fi
  [ -z "$backup" ] || rm -rf "$backup"
}

install_one "$DEST"

echo "installed Claude Code skill -> $DEST"
echo "deps: tmux + jq + claude on PATH. Invoke in Claude Code with: /polylane"
