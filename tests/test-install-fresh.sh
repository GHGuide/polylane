#!/usr/bin/env bash
# test-install-fresh.sh — hermetic proof a fresh clone installs BOTH documented
# skill layouts correctly. Everything happens under $TEST_TMPDIR fake HOMEs; the
# real ~/.claude and ~/.codex are never touched.
#
#   1. CLAUDE layout  — the documented `cp -R . ~/.claude/skills/polylane/` yields
#      SKILL.md + executable bin/*.sh + references/ + assets/.
#   2. CODEX layout   — HOME=<fake> codex/install.sh lays out ~/.codex/skills/polylane
#      with a valid `name:` frontmatter, >=20 executable scripts/*.sh,
#      references/prompt-blocks.md + assets/; a reinstall must NOT nest
#      references/references (the fixed `cp -R dir existing-dir` bug — pinned here).
#   3. Both layouts   — polylane-memory.sh runs standalone from where it was
#      installed (init succeeds; a fresh state is not `met`, so met exits 1).
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

REPO="$(cd "$TESTS_DIR/.." && pwd)"
make_tmpdir

sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

# real_sig PATH — absent-safe signature: file content hash, or an existence tag.
# Used to prove the hermetic installs never touch a real user root or settings.
real_sig() {
  if [ -f "$1" ]; then sha256_hex "$1"
  elif [ -e "$1" ]; then echo "exists-nonfile"
  else echo "absent"; fi
}
REAL_CLAUDE_SETTINGS_BEFORE=$(real_sig "$HOME/.claude/settings.json")
REAL_CLAUDE_LOCAL_BEFORE=$(real_sig "$HOME/.claude/settings.local.json")
REAL_CODEX_CONFIG_BEFORE=$(real_sig "$HOME/.codex/config.toml")
REAL_CLAUDE_SKILL_BEFORE=$(real_sig "$HOME/.claude/skills/polylane")
REAL_CODEX_SKILL_BEFORE=$(real_sig "$HOME/.codex/skills/polylane")

# count_exec_scripts DIR — how many *.sh under DIR carry the execute bit
count_exec_scripts() {
  local n=0 f
  for f in "$1"/*.sh; do [ -x "$f" ] && n=$((n + 1)); done
  echo "$n"
}

# package_manifest DIR — deterministic relative-file inventory with content checksums.
# This catches both a stale file and a divergent duplicate discovery root.
package_manifest() {
  (
    cd "$1" || exit 1
    find . -type f -print | LC_ALL=C sort | while IFS= read -r f; do
      cksum "$f" | awk -v path="$f" '{print $1 ":" $2 " " path}'
    done
  )
}

# --- 1. CLAUDE layout: the documented cp -R install --------------------------
CLA="$TEST_TMPDIR/claude-home/.claude/skills/polylane"
mkdir -p "$CLA"
cp -R "$REPO/." "$CLA/" >/dev/null 2>&1

assert_ok "claude-skill-md"        test -f "$CLA/SKILL.md"
assert_ok "claude-run-executable"  test -x "$CLA/bin/polylane-run.sh"
assert_ok "claude-tmux-executable" test -x "$CLA/bin/polylane-tmux.sh"
assert_ok "claude-mem-executable"  test -x "$CLA/bin/polylane-memory.sh"
assert_ok "claude-references-dir"  test -d "$CLA/references"
assert_ok "claude-assets-dir"      test -d "$CLA/assets"
assert_ok "claude-skill-evals"     test -f "$CLA/benchmarks/skill-evolution/polylane/evals.json"
assert_ok "claude-prime-harness"   test -x "$CLA/bin/polylane-harness.sh"
assert_ok "claude-retained-workers" test -x "$CLA/bin/polylane-workers.sh"
assert_ok "claude-bounded-context" test -x "$CLA/bin/polylane-context.sh"
assert_ok "claude-refinement"      test -x "$CLA/bin/polylane-refine.sh"
assert_ok "claude-skill-evals-run" "$CLA/bin/polylane-skill-evolve.sh" validate \
  "$CLA/benchmarks/skill-evolution/polylane/evals.json"

# --- 2. CODEX layout: HOME=<fake> codex/install.sh ---------------------------
CODEX_HOME="$TEST_TMPDIR/codex-home"
mkdir -p "$CODEX_HOME/.codex/skills"          # makes install pick the .codex path
assert_ok "codex-install-ok"  env HOME="$CODEX_HOME" bash "$REPO/codex/install.sh"

DEST="$CODEX_HOME/.codex/skills/polylane"
assert_ok       "codex-skill-md"        test -f "$DEST/SKILL.md"
assert_ok       "codex-tmux-runtime"    test -x "$DEST/scripts/polylane-tmux.sh"
assert_contains "codex-skill-name"      "name: polylane" "$(grep -m1 '^name:' "$DEST/SKILL.md")"
assert_ok       "codex-20-scripts"      test "$(count_exec_scripts "$DEST/scripts")" -ge 20
assert_ok       "codex-prompt-blocks"   test -f "$DEST/references/prompt-blocks.md"
assert_ok       "codex-assets-dir"      test -d "$DEST/assets"
assert_ok       "codex-skill-evolve"    test -x "$DEST/scripts/polylane-skill-evolve.sh"
assert_ok       "codex-prime-harness"   test -x "$DEST/scripts/polylane-harness.sh"
assert_ok       "codex-retained-workers" test -x "$DEST/scripts/polylane-workers.sh"
assert_ok       "codex-bounded-context" test -x "$DEST/scripts/polylane-context.sh"
assert_ok       "codex-refinement"      test -x "$DEST/scripts/polylane-refine.sh"
assert_ok       "codex-skill-evals"     test -f "$DEST/benchmarks/skill-evolution/polylane/evals.json"
assert_ok       "codex-skill-evals-run" "$DEST/scripts/polylane-skill-evolve.sh" validate \
  "$DEST/benchmarks/skill-evolution/polylane/evals.json"

# reinstall must overwrite in place, not nest references/references (the fixed bug)
assert_ok "codex-reinstall-ok"  env HOME="$CODEX_HOME" bash "$REPO/codex/install.sh"
assert_ok "codex-no-nested-refs"  test '!' -e "$DEST/references/references"
assert_ok "codex-refs-still-flat" test -f "$DEST/references/prompt-blocks.md"

# When desktop and CLI skill roots both exist, --user must synchronize both so
# discovery cannot select an older duplicate.
BOTH_HOME="$TEST_TMPDIR/codex-both-home"
mkdir -p "$BOTH_HOME/.codex/skills" "$BOTH_HOME/.agents/skills"
# A historical install could be a full repository or older package layout. Seed
# root debris plus a duplicate executable engine in both discovery roots; a
# reinstall must replace the package as a whole, not overlay current files.
for ROOT in "$BOTH_HOME/.codex/skills" "$BOTH_HOME/.agents/skills"; do
  LEGACY="$ROOT/polylane"
  mkdir -p "$LEGACY/bin"
  printf 'obsolete root artifact\n' > "$LEGACY/LEGACY-PACKAGE.txt"
  printf '#!/usr/bin/env bash\necho obsolete engine\n' > "$LEGACY/bin/polylane-run.sh"
  chmod +x "$LEGACY/bin/polylane-run.sh"
done
assert_ok "codex-install-both-roots" env HOME="$BOTH_HOME" bash "$REPO/codex/install.sh" --user
assert_ok "codex-both-codex-root" test -x "$BOTH_HOME/.codex/skills/polylane/scripts/polylane-run.sh"
assert_ok "codex-both-agents-root" test -x "$BOTH_HOME/.agents/skills/polylane/scripts/polylane-run.sh"
assert_ok "codex-both-no-legacy-root" test '!' -e "$BOTH_HOME/.codex/skills/polylane/LEGACY-PACKAGE.txt"
assert_ok "codex-both-no-legacy-engine" test '!' -e "$BOTH_HOME/.agents/skills/polylane/bin/polylane-run.sh"
assert_eq "codex-both-skill-identical" \
  "$(cksum "$BOTH_HOME/.codex/skills/polylane/SKILL.md" | awk '{print $1 ":" $2}')" \
  "$(cksum "$BOTH_HOME/.agents/skills/polylane/SKILL.md" | awk '{print $1 ":" $2}')"
assert_eq "codex-both-package-identical" \
  "$(package_manifest "$BOTH_HOME/.codex/skills/polylane")" \
  "$(package_manifest "$BOTH_HOME/.agents/skills/polylane")"

# --- 3. Both layouts: polylane-memory.sh standalone from its installed spot ---
if command -v jq >/dev/null 2>&1; then
  for MEM in "$CLA/bin/polylane-memory.sh" "$DEST/scripts/polylane-memory.sh"; do
    case "$MEM" in *scripts*) tag=codex ;; *) tag=claude ;; esac
    SF="$TEST_TMPDIR/state-$tag.json"
    assert_ok "mem-init-$tag"    bash "$MEM" "$SF" init "install-test goal"
    assert_ok "mem-state-$tag"   test -f "$SF"
    assert_rc "mem-not-met-$tag" 1 bash "$MEM" "$SF" met
  done
else
  pass "mem-skipped-no-jq"
fi

# --- 4. Fresh Claude install.sh: packaged protocol + executable hook fragments -
# A stranger's fresh assembled Claude skill must package the authoritative taste
# protocol (verifiably unmodified) and be able to EXECUTE its optional hook
# fragments in a BLANK target repository via the render/locator contract.
CINST_HOME="$TEST_TMPDIR/claude-inst-home"
mkdir -p "$CINST_HOME/.claude/skills"
assert_ok "claude-install-sh-ok" env HOME="$CINST_HOME" bash "$REPO/claude-code/install.sh" --user
CIDEST="$CINST_HOME/.claude/skills/polylane"
assert_ok "claude-install-protocol-packaged" test -s "$CIDEST/references/taste-certification-protocol.md"
assert_ok "claude-install-visual-intelligence" test -s "$CIDEST/references/visual-intelligence.md"
CI_PKG_HASH=$(sha256_hex "$CIDEST/references/taste-certification-protocol.md")
CI_SRC_HASH=$(sha256_hex "$REPO/docs/polylane/taste-certification/PROTOCOL.md")
CI_PROV_HASH=$(sed -n 's/^sha256=//p' "$CIDEST/references/taste-certification-protocol.provenance")
assert_eq "claude-install-protocol-hash-authentic"  "$CI_SRC_HASH" "$CI_PKG_HASH"
assert_eq "claude-install-protocol-provenance-hash" "$CI_SRC_HASH" "$CI_PROV_HASH"

if command -v jq >/dev/null 2>&1; then
  BLANK="$TEST_TMPDIR/blank-target"
  mkdir -p "$BLANK/.claude" "$BLANK/.polylane" "$BLANK/docs"
  HAVE_GIT=0
  if command -v git >/dev/null 2>&1 && ( cd "$BLANK" && git init -q ) 2>/dev/null; then HAVE_GIT=1; fi
  cat > "$BLANK/.polylane/lifecycle-hooks.json" <<'JSON'
{
  "memory_brief":"Fresh-install target: hooks must resolve the installed helper.",
  "north_star":"A stranger's first unattended Polylane run is truthful and verified.",
  "settled_decisions":["Hooks are optional project-scoped defense in depth."],
  "byte_cap":512
}
JSON

  # Claude: render against the actually-installed helper, then execute every hook
  # command exactly as the provider would in the blank repo.
  CHK="$CIDEST/bin/polylane-hooks.sh"
  CFRAG=$("$CHK" render claude)
  printf '%s\n' "$CFRAG" > "$BLANK/.claude/settings.json"
  assert_eq "claude-fresh-render-no-placeholder" false \
    "$(printf '%s' "$CFRAG" | jq -r 'tostring | contains("__POLYLANE_HOOKS_HELPER__")')"
  for EV in SessionStart PreCompact PostCompact Stop; do
    CMD=$(printf '%s' "$CFRAG" | jq -r --arg e "$EV" '.hooks[$e][0].hooks[0].command')
    OUT=$(printf '{}' | env CLAUDE_PROJECT_DIR="$BLANK" sh -c "$CMD")
    assert_ok "claude-fresh-hook-exec-$EV" sh -c 'printf %s "$1" | jq -e . >/dev/null' sh "$OUT"
    assert_eq "claude-fresh-hook-continue-$EV" true "$(printf '%s' "$OUT" | jq -r '.continue // true')"
  done

  # Codex: render against the codex-installed helper and execute inside the git
  # repo (project resolved via git rev-parse), when git is available.
  CXHK="$DEST/scripts/polylane-hooks.sh"
  CXFRAG=$("$CXHK" render codex)
  assert_eq "codex-fresh-render-no-placeholder" false \
    "$(printf '%s' "$CXFRAG" | jq -r 'tostring | contains("__POLYLANE_HOOKS_HELPER__")')"
  if [ "$HAVE_GIT" = 1 ]; then
    cp "$BLANK/.polylane/lifecycle-hooks.json" "$BLANK/.polylane/lifecycle-hooks.json.keep" 2>/dev/null || true
    CXCMD=$(printf '%s' "$CXFRAG" | jq -r '.hooks.SessionStart[0].hooks[0].command')
    CXOUT=$(printf '{}' | ( cd "$BLANK" && sh -c "$CXCMD" ))
    assert_ok "codex-fresh-hook-exec-SessionStart" sh -c 'printf %s "$1" | jq -e . >/dev/null' sh "$CXOUT"
  else
    pass "codex-fresh-hook-exec-skipped-no-git"
  fi
else
  pass "fresh-hook-exec-skipped-no-jq"
fi

# --- 5. Prove no real user root or global settings changed -------------------
assert_eq "real-claude-settings-unchanged"  "$REAL_CLAUDE_SETTINGS_BEFORE" "$(real_sig "$HOME/.claude/settings.json")"
assert_eq "real-claude-local-unchanged"     "$REAL_CLAUDE_LOCAL_BEFORE"    "$(real_sig "$HOME/.claude/settings.local.json")"
assert_eq "real-codex-config-unchanged"     "$REAL_CODEX_CONFIG_BEFORE"    "$(real_sig "$HOME/.codex/config.toml")"
assert_eq "real-claude-skill-unchanged"     "$REAL_CLAUDE_SKILL_BEFORE"    "$(real_sig "$HOME/.claude/skills/polylane")"
assert_eq "real-codex-skill-unchanged"      "$REAL_CODEX_SKILL_BEFORE"     "$(real_sig "$HOME/.codex/skills/polylane")"

finish
