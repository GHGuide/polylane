#!/usr/bin/env bash
# Prompt sources must give each builder a lean, platform-native executable contract.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$RUNNER")/.." && pwd)"

for f in references/prompt-blocks.md references/planning.md references/skill-scout.md references/lane-template.md; do
  assert_contains "economy-goals-$f" "ULTIMATE-GOAL" "$(cat "$ROOT/$f")"
  assert_contains "economy-subgoal-$f" "CURRENT-SUBGOAL" "$(cat "$ROOT/$f")"
done

blocks=$(cat "$ROOT/references/prompt-blocks.md")
assert_contains "economy-local-cache" '$PWD/.polylane/check-cache/<lane>' "$blocks"
assert_contains "economy-selected-kit-once" "only the named kit once" "$blocks"
assert_contains "economy-no-full-builder-suite" "only coordinator-owned terminal checks remain" "$blocks"
assert_contains "economy-host-gate-handoff" "READY-FOR-HOST-GATE run=<RUN_ID>" "$blocks"
if printf '%s' "$blocks" | grep -qF '<CANONICAL_PROJECT>/.polylane/check-cache'; then fail "economy-no-canonical-cache" "canonical cache found"; else pass "economy-no-canonical-cache"; fi
if printf '%s' "$blocks" | grep -qF 'superpowers:using-superpowers'; then fail "economy-no-generic-stack" "generic stack found"; else pass "economy-no-generic-stack"; fi

template=$(cat "$ROOT/references/lane-template.md")
assert_contains "economy-codex-native" "Codex builder" "$template"
assert_contains "economy-codex-no-slash" "Codex builder: state the locked goals directly" "$template"
if printf '%s' "$template" | grep -qF 'superpowers:using-superpowers'; then fail "economy-template-no-generic-stack" "generic stack found"; else pass "economy-template-no-generic-stack"; fi

finish
