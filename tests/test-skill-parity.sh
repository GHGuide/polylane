#!/usr/bin/env bash
# SKILL PARITY — codex/SKILL.md is standalone (it stopped being "overlay + the Claude
# loop appended verbatim"), so every behavior change must now be written TWICE. That is
# exactly the drift that produced the effort bug and the marker bug. This test pins the
# behaviors that MUST exist in BOTH skills; adding one to a single skill turns red here
# instead of silently diverging.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
CLAUDE="$ROOT/SKILL.md"
CODEX="$ROOT/codex/SKILL.md"

assert_ok "claude-skill-exists" test -s "$CLAUDE"
assert_ok "codex-skill-exists"  test -s "$CODEX"

# behavior -> a grep pattern that must match in BOTH skills
both() {
  local name="$1" pat="$2"
  # -e: a pattern may legitimately start with "--" (e.g. --tier), which grep would
  # otherwise parse as a flag.
  grep -qiE -e "$pat" "$CLAUDE" || { fail "parity-$name" "missing from Claude SKILL.md"; return; }
  grep -qiE -e "$pat" "$CODEX"  || { fail "parity-$name" "missing from codex/SKILL.md"; return; }
  pass "parity-$name"
}

both cycle-helper      'polylane-cycle\.sh'
both check-cache       'polylane-check\.sh'
both contract-v2       'orchestration_contract'
both council-advisory  'cannot (declare completion|stop)|advisory'
both terminal-tier     '--tier terminal|terminal check'
both suggestions-30    '30 concise|exactly 30'
both perfection        'perfection'
both regressions-gate  'regressions'
both tmux-watch        'tmux attach'
both frozen-acceptance 'add-accept'

finish
