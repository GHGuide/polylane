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
both cycle9-control-room 'cycle-9-control-room'
both cycle9-product-benchmark 'polylane-product-benchmark\.sh'
both cycle9-discovery 'polylane-discovery\.sh'
both cycle9-codex-profile 'codex_profile.*lean|lean.*codex_profile'
both cycle9-prompt-budget 'polylane-promptopt\.sh'
both cycle9-judges 'polylane-judges\.sh'
both coordination-relay 'POLYLANE_COORDINATION_FILE|polylane-coordinate\.sh'
both skill-evolution-runtime 'polylane-skill-evolve\.sh'
both skill-challenger-gate 'champion.*challenger|challenger.*champion'
both skill-canary-rollback 'canary.*(rollback|rolls? back)|(rollback|rolls? back).*canary'
both prime-hybrid 'prime_hybrid'
both retained-worker-context 'POLYLANE_CONTEXT_PACKET'
both worker-inbox 'polylane-workers\.sh'
both refinement-runtime 'polylane-refine\.sh'
both refinement-rollback 'roll.?back'
both refinement-auto-queue 'propose-or-decline'
both visual-intelligence-contract 'references/visual-intelligence\.md'
both visual-literal-goal 'ULTIMATE-GOAL'
both visual-safe-fallback 'best installed kit|never execute.*rejected'
both visual-state-evidence 'desktop/mobile|empty/loading/error/hover/focus'
both visual-three-lenses 'three independent visual lenses'
both visual-repair-cap 'at most two targeted repairs'
both visual-asset-copy 'emoji-as-product-art|default-font sameness'
both visual-champion-certification '>=10 varied prompts|70% creative/polish'
both visual-accessibility-gate 'no accessibility regression'

finish
