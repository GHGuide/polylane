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

# count_exec_scripts DIR — how many *.sh under DIR carry the execute bit
count_exec_scripts() {
  local n=0 f
  for f in "$1"/*.sh; do [ -x "$f" ] && n=$((n + 1)); done
  echo "$n"
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
assert_ok "codex-install-both-roots" env HOME="$BOTH_HOME" bash "$REPO/codex/install.sh" --user
assert_ok "codex-both-codex-root" test -x "$BOTH_HOME/.codex/skills/polylane/scripts/polylane-run.sh"
assert_ok "codex-both-agents-root" test -x "$BOTH_HOME/.agents/skills/polylane/scripts/polylane-run.sh"
assert_eq "codex-both-skill-identical" \
  "$(cksum "$BOTH_HOME/.codex/skills/polylane/SKILL.md" | awk '{print $1 ":" $2}')" \
  "$(cksum "$BOTH_HOME/.agents/skills/polylane/SKILL.md" | awk '{print $1 ":" $2}')"

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

finish
