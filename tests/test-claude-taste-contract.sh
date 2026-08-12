#!/usr/bin/env bash
# CLAUDE TASTE CONTRACT — the root Claude skill must REQUIRE the full executable
# rendered visual-taste workflow in its UI route, keep it Claude-native, and never let
# a builder self-judge or a prose verdict promote. Each dropped c39 semantic, a Codex
# command/model id leaking into the UI path, or a forgotten goal is the exact drift the
# tournament exists to stop — so it turns this file red instead of shipping silently.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"
SKILL="$ROOT/SKILL.md"

assert_ok "claude-skill-exists" test -s "$SKILL"

# SKILL.md is prose wrapped at ~80 cols; flatten whitespace so a required phrase that
# happens to straddle a line break still matches (grep is otherwise line-based).
FLAT="$(tr '\n' ' ' < "$SKILL" | tr -s ' ')"

# --- required UI-route semantics: absence or contradiction = red -------------
req() { # name  extended-regex-that-must-match
  printf '%s' "$FLAT" | grep -qiE -e "$2" && pass "req-$1" || fail "req-$1" "SKILL.md omits: $2"
}

# Lock + goal
req literal-goal        'ULTIMATE-GOAL'
req audience-context    'audience/task context'
req reference-packet    'reference packet'
req design-lock         'design lock'
req non-ui-autonomy     'non-UI projects skip it and keep full autonomy'
req vi-reference        'references/visual-intelligence\.md'
# Render + deterministic gates + real captures
req rendered-candidates 'three meaningfully divergent rendered candidates'
req deterministic-gates 'deterministic function, accessibility,? and provenance gates'
req desktop-mobile      'desktop/mobile'
req state-captures      'empty/loading/error/hover/focus'
req external-nogo       'external.*NO-GO|`external`/`NO-GO`'
# Blind mirrored, human-calibrated judging + no self-judge / prose pass
req three-lenses        'three independent visual lenses'
req human-calibrated    'human-calibrated'
req mirrored-judges     'mirrored judges|A/B-and-B/A'
req condorcet           'Condorcet'
req self-judge-ban      'never self-judge'
req prose-pass-ban      'prose or caller-authored .?pass.? never promotes'
req reject-generic      'emoji-as-product-art|default-font sameness'
# Bounded repair + incumbent preservation
req repair-cap          'at most two targeted repairs'
req incumbent           'incumbent champion|best-so-far'
req compare-and-swap    'compare-and-swap'
# Prompt contract + native syntax + quarantine chain
req promptlint          'polylane-promptlint\.sh'
req promptopt           'polylane-promptopt\.sh'
req manifest-fields     'manifest-derived UI contract fields'
req native-syntax       'native Claude skill syntax'
req quarantine-chain    'quarantine .*audit .*benchmark .*pinned arm'
req safe-fallback       'best installed kit|never execute.*rejected'
# Authoritative record before promotion + evidence-scoped bounded-untrusted memory
req authoritative-rec   'authoritative visual-quality and tournament record before promotion'
req taste-memory        'taste memory only after verified promotion'
req memory-untrusted    'bounded untrusted evidence|never inject executable'
req a11y-gate           'no accessibility regression'
req cert-record         'visual certification record'
# Honest claim boundary + global-vs-project separation
req claim-boundary      'only real eligible humans make a result human-certified'
req global-benchmark    '>=10 varied prompts'
req creative-wins       '70% creative/polish'
req global-not-fixture  'never claim it from fixtures'

# --- the UI route must stay Claude-native and self-judging-free ---------------
# Isolate the UI route (the "Profile safety gates" UI bullet) so a Codex command,
# model id, or self-judging permission elsewhere in the skill cannot mask a leak here.
UI="$(awk '/UI Visual Intelligence/{f=1} /^## Evidence-driven domain autonomy/{f=0} f' "$SKILL" | tr '\n' ' ' | tr -s ' ')"
[ -n "$UI" ] && pass "ui-region-isolated" || fail "ui-region-isolated" "could not isolate UI route"

if printf '%s' "$UI" | grep -qiE 'codex|claude-(opus|sonnet|haiku|fable)-'; then
  fail "ui-no-codex-or-models" "UI route names a Codex command or a Claude model id"
else
  pass "ui-no-codex-or-models"
fi

printf '%s' "$UI" | grep -q 'ULTIMATE-GOAL' \
  && pass "ui-carries-goal" || fail "ui-carries-goal" "UI route dropped the literal goal"
printf '%s' "$UI" | grep -qiE 'never self-judge' \
  && pass "ui-bans-self-judging" || fail "ui-bans-self-judging" "UI route permits self-judging"
printf '%s' "$UI" | grep -qiE 'three meaningfully divergent rendered candidates' \
  && pass "ui-requires-tournament" || fail "ui-requires-tournament" "UI route lost the rendered tournament"

finish
