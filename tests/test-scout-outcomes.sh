#!/usr/bin/env bash
# Skill resolution and recommendations remain local, installed, and outcome-led.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
SCOUT="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-scout.sh"

make_tmpdir
ROOT="$TEST_TMPDIR/skills"
HOME_FIXTURE="$TEST_TMPDIR/home"
LEDGER="$TEST_TMPDIR/outcomes.jsonl"
mkdir -p "$ROOT/local" "$ROOT/design/design-critique" "$ROOT/superpowers/test-driven-development" \
  "$ROOT/engineering/testing-strategy" \
  "$HOME_FIXTURE/.codex/plugins/cache/market/superpowers/1.0/skills/cache-only"
cat > "$ROOT/local/SKILL.md" <<'EOF'
---
name: local
EOF
cat > "$ROOT/design/design-critique/SKILL.md" <<'EOF'
---
name: critique
EOF
cat > "$ROOT/superpowers/test-driven-development/SKILL.md" <<'EOF'
---
name: tdd
EOF
cat > "$ROOT/engineering/testing-strategy/SKILL.md" <<'EOF'
---
name: testing
EOF
cat > "$HOME_FIXTURE/.codex/plugins/cache/market/superpowers/1.0/skills/cache-only/SKILL.md" <<'EOF'
---
name: tdd
EOF

assert_eq "scout-resolve-unqualified-root" "$ROOT/local/SKILL.md" \
  "$(POLYLANE_SKILLS_DIRS="$ROOT" HOME="$HOME_FIXTURE" "$SCOUT" resolve local)"
assert_eq "scout-resolve-qualified-root" "$ROOT/design/design-critique/SKILL.md" \
  "$(POLYLANE_SKILLS_DIRS="$ROOT" HOME="$HOME_FIXTURE" "$SCOUT" resolve design:design-critique)"
assert_eq "scout-resolve-qualified-codex-cache" \
  "$HOME_FIXTURE/.codex/plugins/cache/market/superpowers/1.0/skills/cache-only/SKILL.md" \
  "$(POLYLANE_SKILLS_DIRS="$ROOT" HOME="$HOME_FIXTURE" "$SCOUT" resolve superpowers:cache-only)"

assert_ok "scout-record-helped" "$SCOUT" record-outcome "$LEDGER" lane-a ui design:design-critique helped useful
assert_ok "scout-record-unused" "$SCOUT" record-outcome "$LEDGER" lane-b ui local unused irrelevant
assert_ok "scout-record-unused-repeat" "$SCOUT" record-outcome "$LEDGER" lane-c ui local unused irrelevant
assert_ok "scout-record-hurt" "$SCOUT" record-outcome "$LEDGER" lane-d ui local hurt harmful

RECOMMEND=$(POLYLANE_SKILLS_DIRS="$ROOT" HOME="$HOME_FIXTURE" POLYLANE_OUTCOMES_FILE="$LEDGER" \
  "$SCOUT" recommend ui critique)
assert_ok "scout-recommend-json" jq -e '.domain == "ui" and .activity == "critique" and (.skills | type == "array")' <<<"$RECOMMEND"
assert_eq "scout-recommend-helped-first" "design:design-critique" "$(jq -r '.skills[0].skill' <<<"$RECOMMEND")"
assert_eq "scout-recommend-hurt-excluded" "false" "$(jq -e '[.skills[].skill] | index("local") != null' <<<"$RECOMMEND" >/dev/null && echo true || echo false)"

assert_ok "scout-record-test-helped" "$SCOUT" record-outcome "$LEDGER" lane-e test superpowers:test-driven-development helped useful
assert_ok "scout-record-test-unused" "$SCOUT" record-outcome "$LEDGER" lane-f test engineering:testing-strategy unused duplicate
assert_ok "scout-record-test-unused-repeat" "$SCOUT" record-outcome "$LEDGER" lane-g test engineering:testing-strategy unused duplicate
TEST_RECOMMEND=$(POLYLANE_SKILLS_DIRS="$ROOT" HOME="$HOME_FIXTURE" POLYLANE_OUTCOMES_FILE="$LEDGER" \
  "$SCOUT" recommend test verify)
assert_eq "scout-recommend-helped-wins" "superpowers:test-driven-development" "$(jq -r '.skills[0].skill' <<<"$TEST_RECOMMEND")"
assert_eq "scout-recommend-repeated-unused-demoted" "2" "$(jq -r '.skills[1].unused' <<<"$TEST_RECOMMEND")"
assert_ok "scout-record-test-hurt" "$SCOUT" record-outcome "$LEDGER" lane-h test engineering:testing-strategy hurt harmful
HURT_RECOMMEND=$(POLYLANE_SKILLS_DIRS="$ROOT" HOME="$HOME_FIXTURE" POLYLANE_OUTCOMES_FILE="$LEDGER" \
  "$SCOUT" recommend test verify)
assert_eq "scout-recommend-hurt-excluded-candidate" "1" "$(jq -r '.skills | length' <<<"$HURT_RECOMMEND")"

finish
