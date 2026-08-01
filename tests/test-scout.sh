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
export CLAUDE_SKILLS_DIR="$TEST_TMPDIR/skills"
mkdir -p "$CLAUDE_SKILLS_DIR/dataviz"          # only dataviz is "installed"
mkdir -p "$CLAUDE_SKILLS_DIR/testing-strategy" "$CLAUDE_SKILLS_DIR/design-critique"
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

# --- strict structured kits: >=2 predefined + >=2 lane-specific installed skills
KIT="$TEST_TMPDIR/lane-kits.json"
arm_role "$KIT" ui-lane predefined testing-strategy dataviz
arm_role "$KIT" ui-lane specific design-critique dataviz
record_github "$KIT" ui-lane "owner/repo-skill" "informational only"
assert_eq "kit-predefined" "testing-strategy dataviz" "$(armed_role "$KIT" ui-lane predefined)"
assert_eq "kit-specific" "design-critique dataviz" "$(armed_role "$KIT" ui-lane specific)"

MANIFEST="$TEST_TMPDIR/run.json"
cat > "$MANIFEST" <<'JSON'
{"lanes":[{"name":"ui-lane"}],"integrator":{"name":"integrator"}}
JSON
assert_ok "kit-valid-two-plus-two" validate_kits "$KIT" "$MANIFEST"
arm_role "$KIT" ui-lane specific dataviz
assert_rc "kit-rejects-too-few-specific" 7 validate_kits "$KIT" "$MANIFEST"

P2="$TEST_TMPDIR/kit-prompt.txt"
printf 'PREDEFINED-SKILLS: testing-strategy dataviz\nLANE-SPECIFIC-SKILLS: design-critique dataviz\n' > "$P2"
arm_role "$KIT" ui-lane specific design-critique dataviz
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

finish
