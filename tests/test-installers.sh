#!/usr/bin/env bash
# Package boundary smoke test: Codex and Claude Code installers assemble separate
# repo-scoped skill dirs while copying the identical shared core scripts.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

REPO="$(cd "$TESTS_DIR/.." && pwd)"
trap 'rm -rf "$REPO/.codex/skills/polylane" "$REPO/.claude/skills/polylane"; cleanup_tmpdirs' EXIT

(cd "$REPO" && ./codex/install.sh --repo) >/dev/null 2>&1
assert_ok "install-codex-skill" test -f "$REPO/.codex/skills/polylane/SKILL.md"
assert_ok "install-codex-runner" test -x "$REPO/.codex/skills/polylane/scripts/polylane-run.sh"
assert_contains "install-codex-agent" '"agent": "codex"' "$(grep -m1 '"agent": "codex"' "$REPO/.codex/skills/polylane/SKILL.md" || true)"

(cd "$REPO" && ./claude-code/install.sh --repo) >/dev/null 2>&1
assert_ok "install-claude-skill" test -f "$REPO/.claude/skills/polylane/SKILL.md"
assert_ok "install-claude-runner" test -x "$REPO/.claude/skills/polylane/bin/polylane-run.sh"

C_CORE=$(cksum "$REPO/.codex/skills/polylane/scripts/polylane-run.sh" | awk '{print $1 ":" $2}')
CL_CORE=$(cksum "$REPO/.claude/skills/polylane/bin/polylane-run.sh" | awk '{print $1 ":" $2}')
assert_eq "install-shared-core-identical" "$C_CORE" "$CL_CORE"

finish
