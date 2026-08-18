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
assert_ok "install-claude-skill-eval-corpus" test -f "$REPO/.claude/skills/polylane/benchmarks/skill-evolution/polylane/evals.json"
assert_ok "install-claude-skill-evals-runnable" \
  "$REPO/.claude/skills/polylane/bin/polylane-skill-evolve.sh" validate \
  "$REPO/.claude/skills/polylane/benchmarks/skill-evolution/polylane/evals.json"

C_CORE=$(cksum "$REPO/.codex/skills/polylane/scripts/polylane-run.sh" | awk '{print $1 ":" $2}')
CL_CORE=$(cksum "$REPO/.claude/skills/polylane/bin/polylane-run.sh" | awk '{print $1 ":" $2}')
assert_eq "install-shared-core-identical" "$C_CORE" "$CL_CORE"

finish
