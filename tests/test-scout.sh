#!/usr/bin/env bash
# polylane-scout.sh — mechanical per-lane skill scout: domain inference, installed
# gating, validated bake into lane-skills.json, and a prompt-lint that the picked
# skill actually landed.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
SCOUT="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-scout.sh"
. "$SCOUT"

# --- domain inference (deterministic, not LLM guess) ------------------------
assert_eq "domain-ui"     "ui"      "$(domain 'src/components/**' 'app/x.tsx')"
assert_eq "domain-api"    "api"     "$(domain 'server/routes/**')"
assert_eq "domain-data"   "data"    "$(domain 'db/migrations/*.sql')"
assert_eq "domain-test"   "test"    "$(domain 'tests/**.spec.ts')"
assert_eq "domain-report" "report"  "$(domain 'docs/out.pdf')"
assert_eq "domain-none"   "unknown" "$(domain 'lib/util.rs')"

# --- installed gating: a fake skills dir ------------------------------------
command -v jq >/dev/null 2>&1 || { pass "scout-skipped-no-jq"; finish; exit 0; }
make_tmpdir
export HOME="$TEST_TMPDIR/home"
export CLAUDE_SKILLS_DIR="$TEST_TMPDIR/skills"
mkdir -p "$CLAUDE_SKILLS_DIR/dataviz"          # only dataviz is "installed"
mkdir -p "$CLAUDE_SKILLS_DIR/testing-strategy" "$CLAUDE_SKILLS_DIR/design-critique"
mkdir -p "$HOME"
for skill in dataviz testing-strategy design-critique; do
  printf '%s\n' '---' "name: $skill" > "$CLAUDE_SKILLS_DIR/$skill/SKILL.md"
done
assert_ok   "installed-yes" installed dataviz
assert_fail "installed-no"  installed nonesuch
# design:design-critique -> checks the 'design' plugin dir; not present -> not installed
assert_fail "installed-plugin-missing" installed "design:design-critique"

# --- bake only installed skills, write lane-skills.json ----------------------
F="$TEST_TMPDIR/lane-skills.json"
bake "$F" ui-lane dataviz nonesuch 2>/dev/null    # nonesuch dropped (not installed)
assert_eq "bake-keeps-installed-only" "dataviz" "$(armed "$F" ui-lane)"
assert_eq "bake-per-lane-isolation"   ""        "$(armed "$F" other-lane)"

# --- lint: baked skill must appear in the lane prompt -----------------------
GOODP="$TEST_TMPDIR/good.txt"; printf 'invoke dataviz for the charts\n' > "$GOODP"
assert_ok   "lint-skill-present" lint "$F" ui-lane "$GOODP"
BADP="$TEST_TMPDIR/bad.txt";  printf 'no skills mentioned here\n' > "$BADP"
assert_rc   "lint-skill-missing-rc5" 5 lint "$F" ui-lane "$BADP"
# a lane with no baked skills lints clean
assert_ok   "lint-empty-lane-ok" lint "$F" other-lane "$BADP"

# --- strict structured kits: a bounded selected kit (1-2 skills per role) ----
KIT="$TEST_TMPDIR/lane-kits.json"
arm_role "$KIT" ui-lane predefined testing-strategy
arm_role "$KIT" ui-lane specific dataviz
record_github "$KIT" ui-lane "owner/repo-skill" "informational only"
assert_eq "kit-predefined" "testing-strategy" "$(armed_role "$KIT" ui-lane predefined)"
assert_eq "kit-specific" "dataviz" "$(armed_role "$KIT" ui-lane specific)"

MANIFEST="$TEST_TMPDIR/run.json"
cat > "$MANIFEST" <<'JSON'
{"lanes":[{"name":"ui-lane"}],"integrator":{"name":"integrator"}}
JSON
assert_ok "kit-valid-bounded" validate_kits "$KIT" "$MANIFEST"

# Integrator kits are optional: an absent or structurally empty entry is a
# compatibility no-op. Once any role is armed, it inherits the full builder
# cardinality, selected-record, and fingerprint contract.
jq '.lanes.integrator = {}' "$KIT" > "$TEST_TMPDIR/empty-integrator-kits.json"
assert_ok "kit-empty-integrator-is-noop" \
  validate_kits "$TEST_TMPDIR/empty-integrator-kits.json" "$MANIFEST"
jq '.lanes.integrator = {"predefined":["testing-strategy"]}' "$KIT" \
  > "$TEST_TMPDIR/partial-integrator-kits.json"
assert_rc "kit-partial-integrator-is-rejected" 7 \
  validate_kits "$TEST_TMPDIR/partial-integrator-kits.json" "$MANIFEST"
arm_role "$KIT" integrator predefined testing-strategy
arm_role "$KIT" integrator specific dataviz
assert_ok "kit-valid-integrator-is-validated" validate_kits "$KIT" "$MANIFEST"
jq '.lanes.integrator.selected.predefined[0].fingerprint = "stale"' "$KIT" \
  > "$TEST_TMPDIR/stale-integrator-kits.json"
assert_rc "kit-stale-integrator-fingerprint-is-rejected" 7 \
  validate_kits "$TEST_TMPDIR/stale-integrator-kits.json" "$MANIFEST"
arm_role "$KIT" ui-lane specific
assert_rc "kit-rejects-missing-specific" 7 validate_kits "$KIT" "$MANIFEST"
arm_role "$KIT" ui-lane specific dataviz
arm_role "$KIT" ui-lane predefined testing-strategy dataviz design-critique
assert_rc "kit-rejects-predefined-inventory-dump" 7 validate_kits "$KIT" "$MANIFEST"
arm_role "$KIT" ui-lane predefined testing-strategy

P2="$TEST_TMPDIR/kit-prompt.txt"
printf 'PREDEFINED-SKILLS: testing-strategy\nLANE-SPECIFIC-SKILLS: dataviz\n' > "$P2"
assert_ok "kit-lint-structured-prompt" lint "$KIT" ui-lane "$P2"

# --- GitHub suggester is read-only/informational and ranked ------------------
FAKEBIN="$TEST_TMPDIR/bin"; mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' '[{"nameWithOwner":"low/skill","description":"low","stargazersCount":2,"updatedAt":"2026-01-01","url":"https://example/low"},{"nameWithOwner":"high/skill","description":"high","stargazersCount":20,"updatedAt":"2026-02-01","url":"https://example/high"}]'
GH
chmod +x "$FAKEBIN/gh"
old_path="$PATH"; PATH="$FAKEBIN:$PATH"
suggestions=$(github_suggest "visual regression" 2)
PATH="$old_path"
assert_contains "github-suggest-top-ranked" "high/skill" "$(printf '%s' "$suggestions" | head -1)"
assert_contains "github-suggest-informational" "★20" "$suggestions"

# Remote discovery remains inert until the acquisition gate admits project-local
# copied content; only that admitted content can be armed for a lane.
PROJECT="$TEST_TMPDIR/project"; CANDIDATE="$TEST_TMPDIR/acquire-candidate"
mkdir -p "$PROJECT" "$CANDIDATE"
printf '%s\n' '# admitted fixture' > "$CANDIDATE/SKILL.md"
printf '%s\n' MIT > "$CANDIDATE/LICENSE"
SOURCE="$TEST_TMPDIR/acquire-source.json"; BENCH="$TEST_TMPDIR/acquire-benchmark.json"
printf '%s\n' '{"id":"admitted-skill","repository":"https://example.test/admitted","revision":"abcdefabcdefabcdefabcdefabcdefabcdefabcd","license":"MIT","authorized":true}' > "$SOURCE"
printf '%s\n' '{"fixture_id":"same","without_candidate":{"score":1,"accessibility":1},"with_candidate":{"score":2,"accessibility":1},"minimum_improvement":1}' > "$BENCH"
assert_ok "scout-acquires-through-authorized-gate" "$SCOUT" acquire "$PROJECT" "$CANDIDATE" "$SOURCE" "$BENCH"
assert_ok "scout-arms-only-admitted-project-skill" "$SCOUT" arm-admitted "$PROJECT" "$TEST_TMPDIR/admitted-kits.json" ui-lane specific admitted-skill
assert_eq "scout-admitted-skill-is-armed" "admitted-skill" "$(armed_role "$TEST_TMPDIR/admitted-kits.json" ui-lane specific)"

SUGGESTIONS="$TEST_TMPDIR/suggestions.json"
record_github "$SUGGESTIONS" ui-lane 'owner/skill"quoted' 'because "quoted" metadata must remain JSON'
assert_ok "github-suggestion-write-remains-valid-json" jq -e '.lanes["ui-lane"].github_suggestions[0].why | contains("quoted")' "$SUGGESTIONS"

finish
