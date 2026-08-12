#!/usr/bin/env bash
# Package boundary smoke test: Codex and Claude Code installers assemble separate
# repo-scoped skill dirs while copying the identical shared core scripts.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

# Repo-scoped installation must not mutate the checkout running the test. A
# fresh copied checkout also proves both installers derive every artifact from the
# repository rather than ambient repo-local state.
SOURCE_REPO="$(cd "$TESTS_DIR/.." && pwd)"
make_tmpdir
REPO="$TEST_TMPDIR/repo"
mkdir -p "$REPO"
cp -R "$SOURCE_REPO/." "$REPO/"
mkdir -p "$REPO/benchmarks"
printf 'cycle-9 benchmark fixture\n' > "$REPO/benchmarks/install-sentinel.txt"

# Reinstall over a legacy/full-package shape. The current package must replace
# this directory atomically enough that no obsolete root or duplicate engine is
# left discoverable after a successful install.
CODEX_DEST="$REPO/.codex/skills/polylane"
mkdir -p "$CODEX_DEST/bin"
printf 'obsolete codex root artifact\n' > "$CODEX_DEST/LEGACY-PACKAGE.txt"
printf '#!/usr/bin/env bash\necho obsolete codex engine\n' > "$CODEX_DEST/bin/polylane-run.sh"
chmod +x "$CODEX_DEST/bin/polylane-run.sh"

(cd "$REPO" && ./codex/install.sh --repo) >/dev/null 2>&1
assert_ok "install-codex-skill" test -f "$REPO/.codex/skills/polylane/SKILL.md"
assert_ok "install-codex-runner" test -x "$REPO/.codex/skills/polylane/scripts/polylane-run.sh"
assert_ok "install-codex-tmux-runtime" test -x "$REPO/.codex/skills/polylane/scripts/polylane-tmux.sh"
assert_ok "install-codex-coordination-helper" test -x "$REPO/.codex/skills/polylane/scripts/polylane-coordinate.sh"
assert_ok "install-codex-cycle-guard" test -x "$REPO/.codex/skills/polylane/scripts/polylane-cycle.sh"
assert_ok "install-codex-control-reference" test -f "$REPO/.codex/skills/polylane/references/cycle-9-control-room.md"
assert_ok "install-codex-benchmark-artifact" test -f "$REPO/.codex/skills/polylane/benchmarks/install-sentinel.txt"
assert_ok "install-codex-skill-evolution" test -x "$REPO/.codex/skills/polylane/scripts/polylane-skill-evolve.sh"
assert_ok "install-codex-prime-harness" test -x "$REPO/.codex/skills/polylane/scripts/polylane-harness.sh"
assert_ok "install-codex-retained-workers" test -x "$REPO/.codex/skills/polylane/scripts/polylane-workers.sh"
assert_ok "install-codex-bounded-context" test -x "$REPO/.codex/skills/polylane/scripts/polylane-context.sh"
assert_ok "install-codex-refinement" test -x "$REPO/.codex/skills/polylane/scripts/polylane-refine.sh"
assert_ok "install-codex-certification" test -x "$REPO/.codex/skills/polylane/scripts/polylane-certify.sh"
assert_ok "install-codex-skill-catalog" test -x "$REPO/.codex/skills/polylane/scripts/polylane-skill-catalog.sh"
assert_ok "install-codex-domain-runtime" test -x "$REPO/.codex/skills/polylane/scripts/polylane-domain.sh"
assert_ok "install-codex-action-preview" test -x "$REPO/.codex/skills/polylane/scripts/polylane-action-preview.sh"
assert_ok "install-codex-economy" test -x "$REPO/.codex/skills/polylane/scripts/polylane-optimize.sh"
assert_ok "install-codex-skill-benchmark" test -x "$REPO/.codex/skills/polylane/scripts/polylane-skill-benchmark.sh"
assert_ok "install-codex-domain-trials" test -x "$REPO/.codex/skills/polylane/scripts/polylane-domain-trials.sh"
assert_ok "install-codex-soak" test -x "$REPO/.codex/skills/polylane/scripts/polylane-soak.sh"
assert_ok "install-codex-domain-reference" test -s "$REPO/.codex/skills/polylane/references/evidence-driven-domain-autonomy.md"
assert_ok "install-codex-lifecycle-helper" test -x "$REPO/.codex/skills/polylane/scripts/polylane-hooks.sh"
assert_ok "install-codex-lifecycle-fragment" test -f "$REPO/.codex/skills/polylane/assets/hooks/codex-hooks.json"
assert_ok "install-codex-no-legacy-root" test '!' -e "$CODEX_DEST/LEGACY-PACKAGE.txt"
assert_ok "install-codex-no-legacy-engine" test '!' -e "$CODEX_DEST/bin/polylane-run.sh"
assert_ok "install-codex-skill-eval-corpus" test -f "$REPO/.codex/skills/polylane/benchmarks/skill-evolution/polylane/evals.json"
assert_ok "install-codex-skill-evals-runnable" \
  "$REPO/.codex/skills/polylane/scripts/polylane-skill-evolve.sh" validate \
  "$REPO/.codex/skills/polylane/benchmarks/skill-evolution/polylane/evals.json"
assert_contains "install-codex-agent" '"agent": "codex"' "$(grep -m1 '"agent": "codex"' "$REPO/.codex/skills/polylane/SKILL.md" || true)"
assert_eq "install-codex-standalone-source" \
  "$(cksum "$REPO/codex/SKILL.md" | awk '{print $1 ":" $2}')" \
  "$(cksum "$REPO/.codex/skills/polylane/SKILL.md" | awk '{print $1 ":" $2}')"
if grep -qE 'claude --model|AskUserQuestion|Claude memory' "$REPO/.codex/skills/polylane/SKILL.md"; then
  fail "install-codex-no-claude-contract" "Claude-only instructions leaked into Codex package"
else
  pass "install-codex-no-claude-contract"
fi

CLAUDE_DEST="$REPO/.claude/skills/polylane"
mkdir -p "$CLAUDE_DEST/scripts"
printf 'obsolete claude root artifact\n' > "$CLAUDE_DEST/LEGACY-PACKAGE.txt"
printf '#!/usr/bin/env bash\necho obsolete claude engine\n' > "$CLAUDE_DEST/scripts/polylane-run.sh"
chmod +x "$CLAUDE_DEST/scripts/polylane-run.sh"

(cd "$REPO" && ./claude-code/install.sh --repo) >/dev/null 2>&1
assert_ok "install-claude-skill" test -f "$REPO/.claude/skills/polylane/SKILL.md"
assert_ok "install-claude-runner" test -x "$REPO/.claude/skills/polylane/bin/polylane-run.sh"
assert_ok "install-claude-tmux-runtime" test -x "$REPO/.claude/skills/polylane/bin/polylane-tmux.sh"
assert_ok "install-claude-skill-evolution" test -x "$REPO/.claude/skills/polylane/bin/polylane-skill-evolve.sh"
assert_ok "install-claude-prime-harness" test -x "$REPO/.claude/skills/polylane/bin/polylane-harness.sh"
assert_ok "install-claude-retained-workers" test -x "$REPO/.claude/skills/polylane/bin/polylane-workers.sh"
assert_ok "install-claude-bounded-context" test -x "$REPO/.claude/skills/polylane/bin/polylane-context.sh"
assert_ok "install-claude-refinement" test -x "$REPO/.claude/skills/polylane/bin/polylane-refine.sh"
assert_ok "install-claude-certification" test -x "$REPO/.claude/skills/polylane/bin/polylane-certify.sh"
assert_ok "install-claude-skill-catalog" test -x "$REPO/.claude/skills/polylane/bin/polylane-skill-catalog.sh"
assert_ok "install-claude-domain-runtime" test -x "$REPO/.claude/skills/polylane/bin/polylane-domain.sh"
assert_ok "install-claude-action-preview" test -x "$REPO/.claude/skills/polylane/bin/polylane-action-preview.sh"
assert_ok "install-claude-economy" test -x "$REPO/.claude/skills/polylane/bin/polylane-optimize.sh"
assert_ok "install-claude-skill-benchmark" test -x "$REPO/.claude/skills/polylane/bin/polylane-skill-benchmark.sh"
assert_ok "install-claude-domain-trials" test -x "$REPO/.claude/skills/polylane/bin/polylane-domain-trials.sh"
assert_ok "install-claude-soak" test -x "$REPO/.claude/skills/polylane/bin/polylane-soak.sh"
assert_ok "install-claude-domain-reference" test -s "$REPO/.claude/skills/polylane/references/evidence-driven-domain-autonomy.md"
assert_ok "install-claude-lifecycle-helper" test -x "$REPO/.claude/skills/polylane/bin/polylane-hooks.sh"
assert_ok "install-claude-lifecycle-fragment" test -f "$REPO/.claude/skills/polylane/assets/hooks/claude-settings.json"
assert_ok "install-claude-no-legacy-root" test '!' -e "$CLAUDE_DEST/LEGACY-PACKAGE.txt"
assert_ok "install-claude-no-legacy-engine" test '!' -e "$CLAUDE_DEST/scripts/polylane-run.sh"
assert_ok "install-claude-skill-eval-corpus" test -f "$REPO/.claude/skills/polylane/benchmarks/skill-evolution/polylane/evals.json"
assert_ok "install-claude-skill-evals-runnable" \
  "$REPO/.claude/skills/polylane/bin/polylane-skill-evolve.sh" validate \
  "$REPO/.claude/skills/polylane/benchmarks/skill-evolution/polylane/evals.json"

C_CORE=$(cksum "$REPO/.codex/skills/polylane/scripts/polylane-run.sh" | awk '{print $1 ":" $2}')
CL_CORE=$(cksum "$REPO/.claude/skills/polylane/bin/polylane-run.sh" | awk '{print $1 ":" $2}')
assert_eq "install-shared-core-identical" "$C_CORE" "$CL_CORE"

# --- Claude installer parity: visual/taste helpers, packaged protocol, hooks ---
sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
CLAUDE_GOOD="$REPO/.claude/skills/polylane"
for H in polylane-taste polylane-taste-ballot polylane-taste-calibrate polylane-taste-corpus \
         polylane-taste-pixels polylane-taste-stats polylane-taste-threat \
         polylane-visual polylane-visual-capture polylane-visual-quality; do
  assert_ok "install-claude-exec-$H" test -x "$CLAUDE_GOOD/bin/$H.sh"
done
assert_ok "install-claude-visual-intelligence" test -s "$CLAUDE_GOOD/references/visual-intelligence.md"

# Authoritative taste protocol packaged to a stable installed reference path with
# a checksum/provenance sidecar that authentically matches the repo source.
assert_ok "install-claude-protocol-packaged"   test -s "$CLAUDE_GOOD/references/taste-certification-protocol.md"
assert_ok "install-claude-protocol-provenance" test -s "$CLAUDE_GOOD/references/taste-certification-protocol.provenance"
PKG_HASH=$(sha256_hex "$CLAUDE_GOOD/references/taste-certification-protocol.md")
SRC_HASH=$(sha256_hex "$REPO/docs/polylane/taste-certification/PROTOCOL.md")
PROV_HASH=$(sed -n 's/^sha256=//p' "$CLAUDE_GOOD/references/taste-certification-protocol.provenance")
assert_eq "install-claude-protocol-hash-matches-package" "$PKG_HASH" "$PROV_HASH"
assert_eq "install-claude-protocol-hash-authentic"       "$SRC_HASH" "$PROV_HASH"

# The installed helper locates itself and renders a fragment resolving that exact
# path — never the blank target repo's non-existent bin/polylane-hooks.sh.
if command -v jq >/dev/null 2>&1; then
  INSTALLED_HOOKS="$CLAUDE_GOOD/bin/polylane-hooks.sh"
  RLOC=$("$INSTALLED_HOOKS" locate)
  assert_ok "install-claude-locate-executable" test -x "$RLOC"
  RFRAG=$("$INSTALLED_HOOKS" render claude)
  RCMD=$(printf '%s' "$RFRAG" | jq -r '.hooks.SessionStart[0].hooks[0].command')
  assert_contains "install-claude-render-resolves-installed" "$RLOC" "$RCMD"
  assert_eq "install-claude-render-no-placeholder" false \
    "$(printf '%s' "$RFRAG" | jq -r 'tostring | contains("__POLYLANE_HOOKS_HELPER__")')"
else
  pass "install-claude-render-skipped-no-jq"
fi

# Build/validate failure must never touch the already-installed package: the
# installer stages and validates before the atomic swap, so a missing required
# source aborts with the prior package fully intact and no staging litter left.
GOOD_HELPER_SUM=$(cksum "$CLAUDE_GOOD/bin/polylane-hooks.sh" | awk '{print $1 ":" $2}')
PROTO_SRC="$REPO/docs/polylane/taste-certification/PROTOCOL.md"
mv "$PROTO_SRC" "$PROTO_SRC.hidden"
assert_fail "install-claude-build-failure-nonzero" \
  env -i HOME="$HOME" PATH="$PATH" sh -c 'cd "$1" && ./claude-code/install.sh --repo' sh "$REPO"
mv "$PROTO_SRC.hidden" "$PROTO_SRC"
assert_ok "install-claude-failure-preserves-helper"   test -x "$CLAUDE_GOOD/bin/polylane-hooks.sh"
assert_ok "install-claude-failure-preserves-protocol" test -f "$CLAUDE_GOOD/references/taste-certification-protocol.md"
assert_eq "install-claude-failure-no-partial-swap" "$GOOD_HELPER_SUM" \
  "$(cksum "$CLAUDE_GOOD/bin/polylane-hooks.sh" | awk '{print $1 ":" $2}')"
assert_ok "install-claude-failure-no-staging-litter" \
  sh -c 'set -- "$1"/.claude/skills/.polylane.staging.* "$1"/.claude/skills/.polylane.backup.*; [ ! -e "$1" ] && [ ! -e "$2" ]' sh "$REPO"

# A supported full-clone Claude install may be run from its own destination.
# The installer must stage from that source before replacing it, never delete
# the running clone out from under itself.
CLONE_HOME="$TEST_TMPDIR/claude-clone-home"
CLONE_DEST="$CLONE_HOME/.claude/skills/polylane"
mkdir -p "$CLONE_DEST"
cp -R "$SOURCE_REPO/." "$CLONE_DEST/"
printf 'obsolete clone root artifact\n' > "$CLONE_DEST/LEGACY-PACKAGE.txt"
assert_ok "install-claude-source-equals-destination" \
  env HOME="$CLONE_HOME" bash "$CLONE_DEST/claude-code/install.sh" --user
assert_ok "install-claude-source-equals-destination-survives" test -x "$CLONE_DEST/bin/polylane-run.sh"
assert_ok "install-claude-source-equals-destination-clean" test '!' -e "$CLONE_DEST/LEGACY-PACKAGE.txt"

finish
