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

build_one() {
  local dest="$1"
  mkdir -p "$dest/scripts"
  # Codex owns a standalone product contract. The runner remains shared, but Codex
  # never inherits Claude-only prompt syntax, models, memory, or stop conditions.
  # codex/SKILL.md links are package-root-relative (references/…), so install is a
  # pure copy and installed bytes equal source. SKILL.md and references/ are SIBLINGS
  # under $dest; a `../` link would escape the package and 404 — the guard below.
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
  test -x "$dest/scripts/polylane-tmux.sh" || { echo "install: isolated tmux runtime missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-coordinate.sh" || { echo "install: coordination helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-harness.sh" || { echo "install: prime harness helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-workers.sh" || { echo "install: retained worker helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-context.sh" || { echo "install: bounded context helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-refine.sh" || { echo "install: refinement helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-certify.sh" || { echo "install: certification helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-skill-catalog.sh" || { echo "install: metadata skill catalog missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-domain.sh" || { echo "install: domain adapter/grader missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-action-preview.sh" || { echo "install: action preview helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-optimize.sh" || { echo "install: accepted-outcome optimizer missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-skill-benchmark.sh" || { echo "install: skill benchmark helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-domain-trials.sh" || { echo "install: domain trials helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-soak.sh" || { echo "install: soak helper missing" >&2; exit 1; }
  test -x "$dest/scripts/polylane-hooks.sh" || { echo "install: lifecycle hook helper missing" >&2; exit 1; }
  # Visual/taste executables: the rendered-tournament, capture, judging, pixel, and
  # prompt-gate helpers must land executable, or a UI lane silently loses the taste loop.
  for v in polylane-visual polylane-visual-capture polylane-visual-quality \
           polylane-taste polylane-taste-pixels polylane-taste-ballot \
           polylane-taste-calibrate polylane-taste-corpus polylane-taste-stats \
           polylane-taste-threat polylane-graph polylane-graph-bench \
           polylane-promptlint polylane-promptopt; do
    test -x "$dest/scripts/$v.sh" || { echo "install: visual/taste helper $v.sh missing or non-executable" >&2; exit 1; }
  done
  test -s "$dest/references/visual-intelligence.md" || { echo "install: visual intelligence contract missing" >&2; exit 1; }
  test -s "$dest/references/prompt-blocks.md" || { echo "install: prompt-block protocol reference missing" >&2; exit 1; }
  # Doc links must resolve from the package root: no `../` escape survives install.
  ! grep -q '](\.\./' "$dest/SKILL.md" || { echo "install: SKILL.md has an unresolved ../ doc link" >&2; exit 1; }
  test -s "$dest/references/cycle-13-integration.md" || { echo "install: cycle 13 integration reference missing" >&2; exit 1; }
  test -s "$dest/references/evidence-driven-domain-autonomy.md" || { echo "install: domain autonomy reference missing" >&2; exit 1; }
  test -s "$dest/assets/hooks/codex-hooks.json" || { echo "install: Codex lifecycle fragment missing" >&2; exit 1; }
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

  # Build and validate away from the active package. This keeps a legacy install
  # usable if copying any current artifact fails, including source == destination.
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
  echo "installed Codex skill -> $dest"
}

for DEST in "${DESTS[@]}"; do install_one "$DEST"; done
echo "deps: tmux + jq + codex on PATH. Invoke in Codex with: \$polylane  (or /skills)"
