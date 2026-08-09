#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034 # sourced runner consumes fixture globals
# write_report VERDICT — writes docs/polylane-report.md on BOTH GO and non-GO.
# Frozen: report exists, carries the verdict line, and one lanes-table row per
# lane. Runs against a tmpdir REPO_ROOT (non-git -> git-log fallback path).

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

BASE="main"
CYCLE=7
LANE_NAMES=(alpha beta)
LANE_MODELS=(claude-sonnet-5 claude-haiku-4-5)
LANE_BRANCHES=(lane/alpha lane/beta)
LANE_STATS=("Goal achieved (42k tokens)" "completed")

# --- GO report ---------------------------------------------------------------
make_tmpdir
REPO_ROOT="$TEST_TMPDIR"
PROJECT_ROOT="$TEST_TMPDIR"
LANE_WORKTREES=("$TEST_TMPDIR/wt-alpha" "$TEST_TMPDIR/wt-beta")
INT_WORKTREE="$TEST_TMPDIR/wt-integrator"
FAILED_LANES=""
PROMOTION_STATE=promoted
CLEANUP_STATE=complete
mkdir -p "$TEST_TMPDIR/docs"
cat > "$TEST_TMPDIR/docs/verify-alpha.md" <<'EOF'
## Deferred
- Confirm promoted evidence survives cleanup
EOF
run_stats init
run_stats lane-launch --lane alpha
run_stats lane-restart --lane alpha
run_stats terminal-gate
run_stats cleanup --state complete
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
assert_contains "go-current-root-open-item" "Confirm promoted evidence survives cleanup" "$go"
assert_contains "go-telemetry" "Run telemetry:" "$go"
assert_contains "go-telemetry-tokens-unknown" "tokens=unknown" "$go"
assert_eq "go-ledger-cycle" "7" "$(jq -r '.cycle' "$TEST_TMPDIR/docs/polylane/spend-ledger.jsonl")"
assert_eq "go-ledger-tokens" "42000" "$(jq -r '.tokens' "$TEST_TMPDIR/docs/polylane/spend-ledger.jsonl")"

# A favorable integrator verdict is evidence for attempting promotion, not
# proof it happened. A failed transaction retains every runtime artifact and
# the report must say so even when the candidate verdict was GO.
PROMOTION_STATE=failed
CLEANUP_STATE=retained
write_report GO
promotion_failed=$(cat "$TEST_TMPDIR/docs/polylane-report.md")
assert_contains "failed-promotion-report-does-not-claim-merge" "promotion did not complete" "$promotion_failed"
assert_contains "failed-promotion-report-retains-worktrees" "Nothing merged, nothing cleaned" "$promotion_failed"
if printf '%s' "$promotion_failed" | grep -qF -- "all lanes merged"; then fail "failed-promotion-report-no-false-success" "merge success was inferred from GO"; else pass "failed-promotion-report-no-false-success"; fi
assert_eq "failed-promotion-ledger-is-nogo" "1" "$(jq -s '.[-1].nogo' "$TEST_TMPDIR/docs/polylane/spend-ledger.jsonl")"

# Promotion and cleanup are separate observed states: a durable promotion with
# incomplete cleanup must never claim the worktrees and scratch were removed.
PROMOTION_STATE=promoted
CLEANUP_STATE=warning
CLEANUP_WARNING='worktree remove failed'
write_report GO
cleanup_warning=$(cat "$TEST_TMPDIR/docs/polylane-report.md")
assert_contains "cleanup-warning-report-is-observed" "Post-merge cleanup was incomplete" "$cleanup_warning"
if printf '%s' "$cleanup_warning" | grep -qF -- "worktrees, merged branches, and scratch removed"; then fail "cleanup-warning-report-no-false-clean" "cleanup success was inferred"; else pass "cleanup-warning-report-no-false-clean"; fi
CLEANUP_WARNING=""

# --- NO-GO report ------------------------------------------------------------
make_tmpdir
REPO_ROOT="$TEST_TMPDIR"
LANE_WORKTREES=("$TEST_TMPDIR/wt-alpha" "$TEST_TMPDIR/wt-beta")
INT_WORKTREE="$TEST_TMPDIR/wt-integrator"
PROMOTION_STATE=not-attempted
CLEANUP_STATE=retained
mkdir -p "$TEST_TMPDIR/wt-alpha/docs" "$TEST_TMPDIR/wt-beta/docs" "$TEST_TMPDIR/wt-integrator/docs" "$TEST_TMPDIR/docs"
cat > "$TEST_TMPDIR/wt-alpha/docs/verify-alpha.md" <<'EOF'
## Deferred
- NEEDS DECISION: who owns schema v2?

## Notes
- TODO: arbitrary lane prose must not leak
EOF
cat > "$TEST_TMPDIR/wt-beta/docs/verify-beta.md" <<'EOF'
## External
- Physical proof still needed
EOF
cat > "$TEST_TMPDIR/wt-integrator/docs/verify-integration.md" <<'EOF'
## Open items
- Re-run after credentials arrive
EOF
cat > "$TEST_TMPDIR/docs/verify-historical.md" <<'EOF'
## DEFERRED
- Historical deferred item must not leak
EOF
printf -- 'TODO: shell output must not leak\n' > "$TEST_TMPDIR/docs/parallel-status.md"
write_report NO-GO
R="$TEST_TMPDIR/docs/polylane-report.md"

if [ -f "$R" ]; then pass "nogo-report-exists"; else fail "nogo-report-exists" "missing $R"; fi
nogo=$(cat "$R")
assert_contains "nogo-verdict-line"   "**Outcome:** NO-GO"  "$nogo"
assert_contains "nogo-withheld-text"  "withheld GO"         "$nogo"
assert_contains "nogo-nothing-merged" "Nothing merged"      "$nogo"
assert_contains "nogo-open-item"      "NEEDS DECISION: who owns schema v2?" "$nogo"
assert_contains "nogo-external-item" "Physical proof still needed" "$nogo"
assert_contains "nogo-integration-open-item" "Re-run after credentials arrive" "$nogo"
if printf '%s' "$nogo" | grep -qF -- "arbitrary lane prose"; then fail "nogo-arbitrary-prose-excluded" "arbitrary prose leaked"; else pass "nogo-arbitrary-prose-excluded"; fi
if printf '%s' "$nogo" | grep -qF -- "Historical deferred item"; then fail "nogo-historical-evidence-excluded" "historical evidence leaked"; else pass "nogo-historical-evidence-excluded"; fi
if printf '%s' "$nogo" | grep -qF -- "shell output must not leak"; then fail "nogo-shell-output-excluded" "shell output leaked"; else pass "nogo-shell-output-excluded"; fi

# --- HALTED report with a failed lane -----------------------------------------
make_tmpdir
REPO_ROOT="$TEST_TMPDIR"
FAILED_LANES="beta"
PROMOTION_STATE=not-attempted
CLEANUP_STATE=retained
write_report HALTED
halted=$(cat "$TEST_TMPDIR/docs/polylane-report.md")
assert_contains "halted-verdict-line" "**Outcome:** HALTED" "$halted"
assert_contains "halted-failed-row"   "| beta | claude-haiku-4-5 | lane/beta | FAILED — errored after retries |" "$halted"
assert_contains "halted-retry-hint"   "could not recover after retries: **beta**" "$halted"
FAILED_LANES=""

# ENOSPC/failing output must not tear or replace a prior truthful report, and
# callers need a non-zero result to avoid announcing a report that was not made.
printf 'OLD VALID REPORT\n' > "$TEST_TMPDIR/docs/polylane-report.md"
POLYLANE_TEST_REPORT_WRITE_FAIL=1
write_report HALTED >/dev/null 2>&1
report_fail_rc=$?
unset POLYLANE_TEST_REPORT_WRITE_FAIL
assert_eq "report-write-fail-returns-nonzero" "1" "$report_fail_rc"
assert_eq "report-write-fail-preserves-old-report" "OLD VALID REPORT" "$(cat "$TEST_TMPDIR/docs/polylane-report.md")"

finish
