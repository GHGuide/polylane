#!/usr/bin/env bash
# VISUAL LOOP INTEGRATION — install a Codex skill fixture and assert that both
# platform contracts ship the same executable visual-intelligence obligations.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"

make_tmpdir
FIXTURE="$TEST_TMPDIR/polylane"
mkdir -p "$FIXTURE"
cp "$ROOT/SKILL.md" "$FIXTURE/SKILL.md"
cp -R "$ROOT/codex" "$FIXTURE/codex"
cp -R "$ROOT/references" "$FIXTURE/references"
cp -R "$ROOT/bin" "$FIXTURE/bin"
cp -R "$ROOT/assets" "$FIXTURE/assets"

assert_ok "visual-install-codex-fixture" sh -c "cd '$FIXTURE' && ./codex/install.sh --repo"

CLAUDE="$FIXTURE/SKILL.md"
CODEX="$FIXTURE/.codex/skills/polylane/SKILL.md"
VISUAL="$FIXTURE/.codex/skills/polylane/references/visual-intelligence.md"

assert_ok "visual-installed-reference" test -s "$VISUAL"

both() {
  local name="$1" pattern="$2"
  grep -qiE -e "$pattern" "$CLAUDE" || { fail "visual-claude-$name" "missing installed contract"; return; }
  grep -qiE -e "$pattern" "$CODEX" || { fail "visual-codex-$name" "missing generated contract"; return; }
  pass "visual-parity-$name"
}

reference() {
  local name="$1" pattern="$2"
  grep -qiE -e "$pattern" "$VISUAL" || { fail "visual-reference-$name" "missing installed evidence contract"; return; }
  pass "visual-reference-$name"
}

both visual-reference 'references/visual-intelligence\.md'
both literal-ultimate-goal 'ULTIMATE-GOAL'
both reference-evidence 'reference packet|reference.*evidence'
both locked-design 'design lock|locked.*(token|layout|motion|signature)'
both safe-admission 'quarantine.*audit.*benchmark.*pinned.*arm|automatic.*discover.*quarantine'
both failed-admission 'best installed kit|never execute.*rejected'
both evidence-states 'desktop.*mobile.*(empty|loading|error).*(hover|focus)|empty.*loading.*error.*hover.*focus'
both three-lenses 'three independent.*(visual )?(lenses|judges)|three.*(visual )?(lenses|judges)'
both repair-cap 'at most two.*(targeted )?repairs|two.*targeted repairs'
both automatic-council 'council.*automatic|automatic.*council'
both asset-copy 'product-specific.*(typography|imagery|copy)|humanized UX copy'
both anti-generic 'emoji-as-product-art|nested-card soup|default-font sameness'
both certification '10 varied prompts|>=10 varied prompts|at least 10 varied prompts'
both blind-comparison 'anonymized screenshots.*blind|blind.*anonymized screenshots'
both champion-gate '70%.*(creative|polish)|current champion'
both accessibility 'no accessibility regression'

reference ui-detection 'UI.*(cycle|surface)|visual'
reference research '3-5 relevant references|three to five relevant references'
reference wildcard 'wildcard'
reference directions 'three directions'
reference lock 'tokens.*layout.*motion.*signature'
reference staged-evidence 'desktop.*mobile'
reference originality 'emoji-as-product-art|generic stock gradients'
reference certification '70%'
reference certification-record 'visual certification record|VISUAL-CERTIFICATION'

# The installed reference is the executable consumer boundary: a UI lane must be
# able to leave one durable record that joins the lock, state captures, independent
# verdicts, bounded repairs, and champion comparison.  This keeps the evidence
# contract usable after Codex installation rather than merely present in source.
if tr '\n' ' ' < "$VISUAL" | grep -qiE -e 'design lock.*(capture|screenshot).*(three|3).*(verdict|lens).*repair.*(champion|old-vs-new)|VISUAL-CERTIFICATION.*design.*capture.*verdict.*repair.*champion'; then
  pass "visual-reference-certification-artifacts"
else
  fail "visual-reference-certification-artifacts" "missing installed evidence contract"
fi

finish
