#!/usr/bin/env bash
# claude-code/install.sh — assemble the Polylane Claude Code skill from this repo.
# The shared engine stays in bin/; this installer packages the current core plus
# the Claude Code SKILL.md entrypoint without copying core implementation in source.
#   ./claude-code/install.sh          -> user scope (~/.claude/skills/polylane)
#   ./claude-code/install.sh --repo   -> repo scope (./.claude/skills/polylane)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else echo "install: no SHA-256 command available" >&2; return 1; fi
}

STAGE_TO_CLEAN=""
cleanup_stage() { [ -n "$STAGE_TO_CLEAN" ] && rm -rf "$STAGE_TO_CLEAN"; }

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

  # Package the authoritative visual-taste protocol into a stable installed
  # reference path with a checksum/provenance sidecar. A stranger's install
  # carries the exact protocol the runtime references, verifiably unmodified.
  local proto_src proto_dst proto_sum
  proto_src="$REPO/docs/polylane/taste-certification/PROTOCOL.md"
  proto_dst="$dest/references/taste-certification-protocol.md"
  test -s "$proto_src" || { echo "install: authoritative taste protocol missing at $proto_src" >&2; exit 1; }
  cp "$proto_src" "$proto_dst"
  proto_sum="$(sha256_of "$proto_dst")" || exit 1
  {
    echo "source=docs/polylane/taste-certification/PROTOCOL.md"
    echo "sha256=$proto_sum"
    echo "packaged-by=claude-code/install.sh"
  } > "$dest/references/taste-certification-protocol.provenance"

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
  local vh
  for vh in polylane-taste polylane-taste-ballot polylane-taste-calibrate polylane-taste-corpus \
            polylane-taste-pixels polylane-taste-stats polylane-taste-threat \
            polylane-visual polylane-visual-capture polylane-visual-quality; do
    test -x "$dest/bin/$vh.sh" || { echo "install: visual/taste helper missing: $vh.sh" >&2; exit 1; }
  done
  test -s "$dest/references/visual-intelligence.md" || { echo "install: visual intelligence contract missing" >&2; exit 1; }
  test -s "$dest/references/taste-certification-protocol.md" || { echo "install: packaged taste protocol missing" >&2; exit 1; }
  test -s "$dest/references/taste-certification-protocol.provenance" || { echo "install: taste protocol provenance missing" >&2; exit 1; }
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
  # build_one aborts with `exit` on any validation failure, which would leave the
  # staging dir as discoverable litter beside the real package. Clean it on every
  # exit path until the atomic swap succeeds; the existing package is untouched.
  STAGE_TO_CLEAN="$stage"
  trap cleanup_stage EXIT

  # Build and validate before touching an existing package. This also supports
  # a full clone whose source checkout is the destination being reinstalled.
  if ! build_one "$stage"; then
    rm -rf "$stage"
    STAGE_TO_CLEAN=""; trap - EXIT
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
    STAGE_TO_CLEAN=""; trap - EXIT
    if [ -n "$backup" ] && ! mv "$backup" "$dest"; then
      echo "install: replacement failed and rollback failed; preserved package is $backup" >&2
    fi
    return 1
  fi
  STAGE_TO_CLEAN=""; trap - EXIT
  [ -z "$backup" ] || rm -rf "$backup"
}

install_one "$DEST"

echo "installed Claude Code skill -> $DEST"
echo "deps: tmux + jq + claude on PATH. Invoke in Claude Code with: /polylane"
