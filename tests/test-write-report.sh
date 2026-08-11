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
PROMOTION_FAILURE_REASON='untracked path blocked promotion: literal $(touch promotion-reason-never-runs) and `touch promotion-backtick-never-runs`'
write_report HALTED
promotion_reason=$(cat "$TEST_TMPDIR/docs/polylane-report.md")
assert_contains "failed-promotion-report-names-bounded-blocker" "untracked path blocked promotion" "$promotion_reason"
assert_contains "failed-promotion-report-guides-blocker-recovery" "Resolve the promotion blocker" "$promotion_reason"
assert_fail "failed-promotion-report-never-executes-blocker-text" test -e promotion-reason-never-runs
assert_fail "failed-promotion-report-never-executes-backtick-text" test -e promotion-backtick-never-runs
PROMOTION_FAILURE_REASON=""
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
assert_contains "nogo-does-not-present-unknown-cost-as-zero" "total unavailable" "$nogo"
if printf '%s' "$nogo" | grep -qF -- "arbitrary lane prose"; then fail "nogo-arbitrary-prose-excluded" "arbitrary prose leaked"; else pass "nogo-arbitrary-prose-excluded"; fi
if printf '%s' "$nogo" | grep -qF -- "Historical deferred item"; then fail "nogo-historical-evidence-excluded" "historical evidence leaked"; else pass "nogo-historical-evidence-excluded"; fi
if printf '%s' "$nogo" | grep -qF -- "shell output must not leak"; then fail "nogo-shell-output-excluded" "shell output leaked"; else pass "nogo-shell-output-excluded"; fi

# A READY integrator can be rejected by a runner-owned host gate. The durable
# report must attribute that NO-GO to the host check and point at its evidence,
# not falsely claim that the integrator withheld GO.
RUN_ID=host-report-stale
mkdir -p "$TEST_TMPDIR/docs/polylane/host-gate-failures"
printf '%s\n' '[{"run":"older-run","phase":"terminal","command":"false","return_code":1,"timestamp":"2026-08-10T00:00:00Z","output_tail":"stale"}]' \
  > "$TEST_TMPDIR/docs/polylane/host-gate-failures/host-report-stale.acceptance.jsonl"
POLYLANE_MIN_DISK_GB=0 host_gate_failure "stale acceptance output must not be attributed"
stale_host_failure=$(cat "$TEST_TMPDIR/docs/polylane/host-gate-failures/host-report-stale.md")
if printf '%s' "$stale_host_failure" | grep -qF -- "acceptance_output="; then fail "host-nogo-rejects-stale-acceptance-output" "stale output was linked"; else pass "host-nogo-rejects-stale-acceptance-output"; fi

RUN_ID=host-report-run
mkdir -p "$TEST_TMPDIR/docs/polylane/host-gate-failures"
printf '%s\n' '[{"run":"host-report-run","phase":"terminal","command":"false","return_code":1,"timestamp":"2026-08-10T00:00:00Z","output_tail":"failure"}]' \
  > "$TEST_TMPDIR/docs/polylane/host-gate-failures/host-report-run.acceptance.jsonl"
POLYLANE_MIN_DISK_GB=0 host_gate_failure "efficiency proof failed because restarts=1 exceeds max_restarts=0"
write_report NO-GO
host_nogo=$(cat "$TEST_TMPDIR/docs/polylane-report.md")
assert_contains "host-nogo-attributed-to-runner-gate" "runner-owned host gate rejected the READY handoff" "$host_nogo"
assert_contains "host-nogo-carries-real-reason" "restarts=1 exceeds max_restarts=0" "$host_nogo"
assert_contains "host-nogo-points-to-canonical-evidence" "docs/polylane/host-gate-failures/host-report-run.md" "$host_nogo"
assert_contains "host-nogo-points-to-acceptance-output" "docs/polylane/host-gate-failures/host-report-run.acceptance.jsonl" "$host_nogo"
if printf '%s' "$host_nogo" | grep -qF -- "integrator withheld GO"; then fail "host-nogo-does-not-blame-integrator" "host failure was attributed to integrator"; else pass "host-nogo-does-not-blame-integrator"; fi
unset RUN_ID

# --- HALTED report with a failed lane -----------------------------------------
make_tmpdir
REPO_ROOT="$TEST_TMPDIR"
FAILED_LANES="beta"
LANE_FAILURE_REASONS=()
lane_failure_reason_set beta "live turn silence cap exhausted after 900s"
PROMOTION_STATE=not-attempted
CLEANUP_STATE=retained
write_report HALTED
halted=$(cat "$TEST_TMPDIR/docs/polylane-report.md")
assert_contains "halted-verdict-line" "**Outcome:** HALTED" "$halted"
assert_contains "halted-failed-row"   "| beta | claude-haiku-4-5 | lane/beta | FAILED — live turn silence cap exhausted after 900s |" "$halted"
assert_contains "halted-live-turn-hint" "live turn silence cap" "$halted"
if printf '%s' "$halted" | grep -qF 'status.claude.com'; then fail "halted-live-turn-no-provider-status-hint" "live-turn halt was misattributed to provider"; else pass "halted-live-turn-no-provider-status-hint"; fi
FAILED_LANES=""

# The integrator is supervised by the same health loop. Its exact stored reason
# must reach the same report table and non-provider recovery guidance as a
# builder failure; otherwise Cycle 27's failed lane is silently misreported.
INT_NAME=integrator
INT_MODEL=codex
INT_BRANCH=lane/integrator
INT_FAILURE_REASON=""
FAILED_LANES="integrator"
lane_failure_reason_set integrator "live turn silence cap exhausted after 60s"
write_report HALTED
integrator_halted=$(cat "$TEST_TMPDIR/docs/polylane-report.md")
assert_contains "halted-integrator-failed-row" "| integrator | codex | lane/integrator | FAILED — live turn silence cap exhausted after 60s |" "$integrator_halted"
assert_contains "halted-integrator-live-turn-guidance" "Lane **integrator** halted: live turn silence cap exhausted after 60s." "$integrator_halted"
if printf '%s' "$integrator_halted" | grep -qF 'status.claude.com'; then fail "halted-integrator-no-provider-status-hint" "integrator live-turn halt was misattributed to provider"; else pass "halted-integrator-no-provider-status-hint"; fi
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

# A completed terminal branch may reach its common epilogue after reporting.
# The helper owns exactly one publication attempt, so that convergence never
# overwrites a truthful fresh handoff a second time.
REPORT_CALLS=0
write_report() { REPORT_CALLS=$((REPORT_CALLS + 1)); return 0; }
capture_stats() { :; }
TERMINAL_REPORT_ATTEMPTED=0
report_completed_terminal NO-GO; first_report_rc=$?
assert_eq "terminal-report-first-attempt" "0" "$first_report_rc"
report_completed_terminal NO-GO; second_report_rc=$?
assert_eq "terminal-report-second-call-is-idempotent" "0" "$second_report_rc"
assert_eq "terminal-report-attempted-exactly-once" "1" "$REPORT_CALLS"

# Once NO-GO is established, optional learning failures cannot preempt its one
# fresh report.  A graph bookkeeping failure still gets the same truthful report.
TERMINAL_REPORT_ATTEMPTED=0; REPORT_CALLS=0
graph_authority_no_go() { return 0; }
advanced_runtime() { return 1; }
publish_established_no_go; established_nogo_rc=$?
assert_eq "established-nogo-reports-before-optional-learning" "0" "$established_nogo_rc"
assert_eq "established-nogo-optional-failure-still-reports" "1" "$REPORT_CALLS"
TERMINAL_REPORT_ATTEMPTED=0; REPORT_CALLS=0
graph_authority_no_go() { return 1; }
publish_established_no_go; graph_nogo_rc=$?
assert_eq "established-nogo-graph-failure-remains-recoverable" "1" "$graph_nogo_rc"
assert_eq "established-nogo-graph-failure-still-reports" "1" "$REPORT_CALLS"

finish
