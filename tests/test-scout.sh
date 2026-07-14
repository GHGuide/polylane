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

finish
