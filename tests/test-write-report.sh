#!/usr/bin/env bash
# write_report VERDICT — writes docs/polylane-report.md on BOTH GO and non-GO.
# Frozen: report exists, carries the verdict line, and one lanes-table row per
# lane. Runs against a tmpdir REPO_ROOT (non-git -> git-log fallback path).

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

BASE="main"
LANE_NAMES=(alpha beta)
LANE_MODELS=(claude-sonnet-5 claude-haiku-4-5)
LANE_BRANCHES=(lane/alpha lane/beta)
LANE_STATS=("Goal achieved (42k tokens)" "completed")

# --- GO report ---------------------------------------------------------------
make_tmpdir
REPO_ROOT="$TEST_TMPDIR"
FAILED_LANES=""
write_report GO
R="$TEST_TMPDIR/docs/polylane-report.md"

if [ -f "$R" ]; then pass "go-report-exists"; else fail "go-report-exists" "missing $R"; fi
go=$(cat "$R")
assert_contains "go-verdict-line"   "**Outcome:** GO"        "$go"
assert_contains "go-base-branch"    "**Base branch:** main"  "$go"
assert_contains "go-lane-row-alpha" "| alpha | claude-sonnet-5 | lane/alpha | Goal achieved (42k tokens) |" "$go"
assert_contains "go-lane-row-beta"  "| beta | claude-haiku-4-5 | lane/beta | completed |" "$go"
assert_contains "go-merged-text"    "all lanes merged"       "$go"
assert_contains "go-push-step"      "git push"               "$go"
assert_contains "go-no-open-items"  "No open items"          "$go"

# --- NO-GO report ------------------------------------------------------------
make_tmpdir
REPO_ROOT="$TEST_TMPDIR"
mkdir -p "$TEST_TMPDIR/docs"
printf -- '- NEEDS DECISION: who owns schema v2?\n' > "$TEST_TMPDIR/docs/verify-alpha.md"
write_report NO-GO
R="$TEST_TMPDIR/docs/polylane-report.md"

if [ -f "$R" ]; then pass "nogo-report-exists"; else fail "nogo-report-exists" "missing $R"; fi
nogo=$(cat "$R")
assert_contains "nogo-verdict-line"   "**Outcome:** NO-GO"  "$nogo"
assert_contains "nogo-withheld-text"  "withheld GO"         "$nogo"
assert_contains "nogo-nothing-merged" "Nothing merged"      "$nogo"
assert_contains "nogo-open-item"      "NEEDS DECISION: who owns schema v2?" "$nogo"

# --- HALTED report with a failed lane -----------------------------------------
make_tmpdir
REPO_ROOT="$TEST_TMPDIR"
FAILED_LANES="beta"
write_report HALTED
halted=$(cat "$TEST_TMPDIR/docs/polylane-report.md")
assert_contains "halted-verdict-line" "**Outcome:** HALTED" "$halted"
assert_contains "halted-failed-row"   "| beta | claude-haiku-4-5 | lane/beta | FAILED — errored after retries |" "$halted"
assert_contains "halted-retry-hint"   "could not recover after retries: **beta**" "$halted"
FAILED_LANES=""

finish
