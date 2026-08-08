#!/usr/bin/env bash
# Metadata-only catalog indexing and explainable lane recommendations.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

CATALOG="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-skill-catalog.sh"
SCOUT="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-scout.sh"

make_tmpdir
ROOT="$TEST_TMPDIR/skills"
CACHE_HOME="$TEST_TMPDIR/home"
INDEX="$TEST_TMPDIR/catalog.json"
LEDGER="$TEST_TMPDIR/outcomes.jsonl"
mkdir -p "$ROOT/superpowers/test-driven-development" \
  "$ROOT/ui/visual-regression" "$ROOT/docs/test-writing" \
  "$ROOT/bad-frontmatter" \
  "$CACHE_HOME/.codex/plugins/cache/ui/1.0/skills/visual-regression" \
  "$CACHE_HOME/.codex/plugins/cache/ui/2.0/skills/visual-regression"

cat > "$ROOT/superpowers/test-driven-development/SKILL.md" <<'EOF'
---
name: tdd
description: Write behavior-first tests for shell commands and verification gates.
compatibility: codex, claude
allowed-tools: bash, jq
---
# body must not enter the catalog
EOF
cat > "$ROOT/ui/visual-regression/SKILL.md" <<'EOF'
---
name: visual regression
description: Capture browser screenshots and compare UI rendering across states.
compatibility: codex
allowed-tools: bash, playwright
---
EOF
cat > "$ROOT/docs/test-writing/SKILL.md" <<'EOF'
---
name: test writing
description: Write prose about tests for Markdown documentation and reports.
compatibility: codex
allowed-tools: bash
---
EOF
cat > "$ROOT/bad-frontmatter/SKILL.md" <<'EOF'
name: malformed
description: this must be skipped because opening frontmatter is absent
EOF
for version in 1.0 2.0; do
  cat > "$CACHE_HOME/.codex/plugins/cache/ui/$version/skills/visual-regression/SKILL.md" <<'EOF'
---
name: duplicate cache
description: stale duplicate cache copy that must lose to the trusted root.
---
EOF
done

assert_ok "catalog-index-builds-metadata" env POLYLANE_SKILLS_DIRS="$ROOT" HOME="$CACHE_HOME" "$CATALOG" index "$INDEX"
assert_ok "catalog-index-json-valid" jq -e '.schema == 1 and (.skills | type == "array")' "$INDEX"
assert_eq "catalog-index-qualified-id" "superpowers:test-driven-development" "$(jq -r '.skills[] | select(.id == "superpowers:test-driven-development") | .id' "$INDEX")"
assert_eq "catalog-index-captures-description" "Capture browser screenshots and compare UI rendering across states." "$(jq -r '.skills[] | select(.id == "ui:visual-regression") | .description' "$INDEX")"
assert_eq "catalog-index-captures-compatibility" "codex" "$(jq -r '.skills[] | select(.id == "ui:visual-regression") | .compatibility[0]' "$INDEX")"
assert_eq "catalog-index-captures-allowed-tools" "playwright" "$(jq -r '.skills[] | select(.id == "ui:visual-regression") | .allowed_tools[1]' "$INDEX")"
assert_ok "catalog-index-captures-fingerprint" jq -e '.skills[] | select(.id == "ui:visual-regression") | (.fingerprint | test("^[0-9]+-[0-9]+$"))' "$INDEX"
assert_eq "catalog-index-skips-malformed-frontmatter" "0" "$(jq '[.skills[] | select(.path | contains("bad-frontmatter"))] | length' "$INDEX")"
assert_eq "catalog-index-dedupes-cache-copies" "1" "$(jq '[.skills[] | select(.id == "ui:visual-regression")] | length' "$INDEX")"
assert_eq "catalog-index-prefers-trusted-root" "trusted-root" "$(jq -r '.skills[] | select(.id == "ui:visual-regression") | .source' "$INDEX")"

LANE="$TEST_TMPDIR/lane.json"
cat > "$LANE" <<'EOF'
{"role":"builder","goal":"add screenshot comparisons to the UI","activities":["capture screenshots","compare UI rendering"],"own_globs":["src/components/**/*.tsx","tests/ui/**/*.spec.ts"],"agent":"codex","required_tools":["bash","playwright"]}
EOF
RECOMMEND="$TEST_TMPDIR/recommend.json"
assert_ok "catalog-recommend-strong-match" bash -c '"$1" recommend "$2" "$3" "$4" > "$5"' _ "$CATALOG" "$INDEX" "$LANE" "$LEDGER" "$RECOMMEND"
assert_eq "catalog-recommend-strong-first" "ui:visual-regression" "$(jq -r '.candidates[0].id' "$RECOMMEND")"
assert_contains "catalog-recommend-explains-lane-evidence" "activities:capture screenshots" "$(jq -r '.candidates[0].reason' "$RECOMMEND")"
assert_contains "catalog-recommend-explains-capability" "browser screenshots" "$(jq -r '.candidates[0].reason' "$RECOMMEND")"
assert_eq "catalog-recommend-rejects-keyword-near-miss" "0" "$(jq '[.candidates[] | select(.id == "docs:test-writing")] | length' "$RECOMMEND")"

assert_ok "catalog-outcome-helped" "$SCOUT" record-outcome "$LEDGER" ui-lane ui ui:visual-regression helped used
assert_ok "catalog-outcome-hurt" "$SCOUT" record-outcome "$LEDGER" ui-lane ui superpowers:test-driven-development hurt wrong-domain
assert_ok "catalog-recommend-honors-outcomes" bash -c '"$1" recommend "$2" "$3" "$4" > "$5"' _ "$CATALOG" "$INDEX" "$LANE" "$LEDGER" "$RECOMMEND"
assert_eq "catalog-recommend-hurt-excluded" "0" "$(jq '[.candidates[] | select(.id == "superpowers:test-driven-development")] | length' "$RECOMMEND")"

KIT="$TEST_TMPDIR/kits.json"
VERIFY="$TEST_TMPDIR/verify.md"
printf '%s\n' '{"version":2,"lanes":{"ui-lane":{"predefined":["superpowers:test-driven-development"],"specific":["ui:visual-regression"],"github_suggestions":[]}}}' > "$KIT"
printf '%s\n' 'SKILL-EVIDENCE: ui:visual-regression — screenshot comparison caught a changed state.' > "$VERIFY"
AUDIT="$TEST_TMPDIR/audit.json"
assert_ok "catalog-use-audit-json" bash -c '"$1" use-audit "$2" "$3" "$4" "$5" "$6" > "$7"' _ "$CATALOG" "$KIT" ui-lane "$VERIFY" ui "$LEDGER" "$AUDIT"
assert_eq "catalog-use-audit-proves-armed-skill" "ui:visual-regression" "$(jq -r '.helped[0].id' "$AUDIT")"
assert_eq "catalog-use-audit-marks-missing-unused" "superpowers:test-driven-development" "$(jq -r '.unused[0]' "$AUDIT")"
assert_eq "catalog-use-audit-records-unused" "unused" "$(jq -r 'select(.skill == "superpowers:test-driven-development") | .outcome' "$LEDGER" | tail -1)"

finish
