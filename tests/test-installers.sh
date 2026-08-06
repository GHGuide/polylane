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

(cd "$REPO" && ./codex/install.sh --repo) >/dev/null 2>&1
assert_ok "install-codex-skill" test -f "$REPO/.codex/skills/polylane/SKILL.md"
assert_ok "install-codex-runner" test -x "$REPO/.codex/skills/polylane/scripts/polylane-run.sh"
assert_ok "install-codex-coordination-helper" test -x "$REPO/.codex/skills/polylane/scripts/polylane-coordinate.sh"
assert_ok "install-codex-cycle-guard" test -x "$REPO/.codex/skills/polylane/scripts/polylane-cycle.sh"
assert_ok "install-codex-control-reference" test -f "$REPO/.codex/skills/polylane/references/cycle-9-control-room.md"
assert_ok "install-codex-benchmark-artifact" test -f "$REPO/.codex/skills/polylane/benchmarks/install-sentinel.txt"
assert_contains "install-codex-agent" '"agent": "codex"' "$(grep -m1 '"agent": "codex"' "$REPO/.codex/skills/polylane/SKILL.md" || true)"
assert_eq "install-codex-standalone-source" \
  "$(cksum "$REPO/codex/SKILL.md" | awk '{print $1 ":" $2}')" \
  "$(cksum "$REPO/.codex/skills/polylane/SKILL.md" | awk '{print $1 ":" $2}')"
if grep -qE 'claude --model|AskUserQuestion|Claude memory' "$REPO/.codex/skills/polylane/SKILL.md"; then
  fail "install-codex-no-claude-contract" "Claude-only instructions leaked into Codex package"
else
  pass "install-codex-no-claude-contract"
fi

(cd "$REPO" && ./claude-code/install.sh --repo) >/dev/null 2>&1
assert_ok "install-claude-skill" test -f "$REPO/.claude/skills/polylane/SKILL.md"
assert_ok "install-claude-runner" test -x "$REPO/.claude/skills/polylane/bin/polylane-run.sh"

C_CORE=$(cksum "$REPO/.codex/skills/polylane/scripts/polylane-run.sh" | awk '{print $1 ":" $2}')
CL_CORE=$(cksum "$REPO/.claude/skills/polylane/bin/polylane-run.sh" | awk '{print $1 ":" $2}')
assert_eq "install-shared-core-identical" "$C_CORE" "$CL_CORE"

finish
