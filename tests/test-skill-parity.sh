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
both runtime-finalize 'POLYLANE-RUNTIME-FINALIZE'
both refinement-queue-command 'polylane-refine\.sh"? queue'
both visual-intelligence-contract 'references/visual-intelligence\.md'
both visual-literal-goal 'ULTIMATE-GOAL'
both visual-safe-fallback 'best installed kit|never execute.*rejected'
both visual-state-evidence 'desktop/mobile|empty/loading/error/hover/focus'
both visual-three-lenses 'three independent visual lenses'
both visual-repair-cap 'at most two targeted repairs'
both visual-asset-copy 'emoji-as-product-art|default-font sameness'
both visual-champion-certification '>=10 varied prompts|70% creative/polish'
both visual-accessibility-gate 'no accessibility regression'
both visual-certification-record 'visual certification record|VISUAL-CERTIFICATION'
both cycle13-model-policy 'model policy|effective model policy|intensity'
both cycle13-skill-catalog 'catalog-index|metadata-only'
both cycle13-prompt-compiler 'compiled launch|compiled prompt|cycle-13-integration'
both cycle13-lifecycle-hooks 'lifecycle hooks|lifecycle.*hook|cycle-13-integration'
both cycle13-certification 'polylane-certify\.sh'
both project-profile-record 'PROJECT_PROFILE\.md'
both project-profile-machine-form 'PROJECT_PROFILE\.json'
both project-profile-gate 'polylane-project\.sh gate'
both project-profile-routes 'trading.*research|research.*operations.*content.*data.*custom.*software'
both trading-safety 'trading.*(backtest|paper)|backtest.*trading'
both cycle16-typed-discovery 'typed adapter tree|domain-specific'
both cycle16-material-emergence 'deliverables, evidence, risk, or next focus'
both cycle16-bundle-grader 'executable bundle grader|profile-incomplete deliverable bundle'
both cycle16-real-trials 'source-pinned real-domain trials|source-pinned.*completion evidence'
both cycle16-live-skip '`?SKIP`?.*(not|never).*`?PASS`?|SKIP.*never.*PASS'
both cycle16-economy 'empirical optimizer|accepted-outcome receipt'
both cycle16-skill-admission 'changed fingerprint|never recommended, armed, or auto-installed'
both cycle16-action-receipt 'action-preview|receipt hash|altered payload'
both cycle16-handoff 'Profile-specific final handoffs|bundle-grade'

# --- Codex-native authoritative taste contract ------------------------------
# The cycle-39 rendered-tournament / taste-memory obligations are added to the
# shared reference + Claude skill by other lanes (visual-doc-contract,
# taste-memory, tournament-engine, claude-contract). Codex is a STANDALONE
# contract, so it must carry them natively NOW and never regress. These assert on
# codex/SKILL.md only; the integrator promotes each to both() once the frozen
# Claude skill lands the matching clause (see docs/verify-codex-parity.md).
# Prose wraps across lines, so match a whitespace-flattened copy.
CODEX_FLAT="$(tr '\n' ' ' < "$CODEX" | tr -s ' ')"
codex_only() {
  local name="$1" pat="$2"
  printf '%s' "$CODEX_FLAT" | grep -qiE -e "$pat" || { fail "codex-authoritative-$name" "missing from codex/SKILL.md"; return; }
  pass "codex-authoritative-$name"
}
codex_only candidate-count 'at least three divergent candidates|three divergent candidates'
codex_only locked-base      'from one locked base'
codex_only hard-gates       'deterministic hard gates'
codex_only calibrated-blind 'calibrated blind mirrored judging'
codex_only incumbent        'incumbent best-so-far'
codex_only machine-label    'SELECTED_NOT_CERTIFIED'
codex_only human-label      'TASTE-CERTIFIED|human_certified'
codex_only global-benchmark '>=10 varied-brief|10 varied-brief global'
codex_only taste-memory     'bounded, evidence-scoped taste memory|bounded .*taste memory'

# Provider-native command rules: Codex must forbid importing Claude launch syntax,
# model ids, or memory helpers, and must name its own native surface. A red here
# means the Codex skill drifted toward Claude assumptions.
codex_only native-syntax    'Codex-native launch syntax'
codex_only native-no-claude 'do not import Claude|never import Claude'
codex_only native-model     'Codex-supported model ids|Codex-only model'
# Leak guard: a Claude slash command as a standalone token, a claude-* model id, or
# the ~/.claude memory root. Path helpers like scripts/polylane-*.sh are legitimate,
# so the slash-command form must be whitespace-delimited (not preceded by a path).
if grep -qiE '(^|[[:space:]])/(polylane|lanes)([[:space:]]|$)|claude-(opus|sonnet|haiku|fable|[0-9])|~/\.claude' "$CODEX"; then
  fail "codex-no-claude-launch" "codex/SKILL.md leaked a Claude slash command, model id, or memory root"
else
  pass "codex-no-claude-launch"
fi

finish
