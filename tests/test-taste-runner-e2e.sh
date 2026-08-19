#!/usr/bin/env bash
# test-taste-runner-e2e.sh — hermetic promotion-path canary for the runner.
#
# Sources bin/polylane-run.sh (its main is BASH_SOURCE-guarded) and drives the
# end-to-end current-UI promotion decision with hermetic doubles: a fake
# authoritative visual-quality helper and a fake project taste-memory helper.
# No tmux, no real agents, no browser, no human panel. Nothing here converts
# unavailable browser/human evidence into a PASS: every gate result is produced
# by an explicit hermetic helper that the runner treats as the authority.
#
# Proves, in one ordered scenario per case:
#   A. Promotion path: valid preflight -> authoritative PASS -> memory records the
#      promoted receipt exactly once; a stale/blocked/caller-GO result promotes
#      nothing and never records to memory (incumbent preserved).
#   B. coordinator seq28 auto-quiesce: a clean, committed, scope-valid,
#      current-run DONE whose pane is still live at its input is sent exactly one
#      tracked /exit and then completes; a dirty, marker-mismatched, or
#      already-quiesced pane is never sent /exit.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

if ! command -v jq >/dev/null 2>&1; then pass "taste-runner-e2e-skipped-no-jq"; finish; exit 0; fi

. "$RUNNER"

make_tmpdir

# --- hermetic runtime seams (redefined AFTER sourcing so these win) -----------
poll_done() { return 0; }
merge_gate() { return 0; }
graph_authority_require() { return 0; }
graph_authority_record_ready_node() { return 0; }
graph_authority_enabled() { return 1; }
notify_event() { :; }
run_stats() { :; }
REPAIR_LOG="$TEST_TMPDIR/repair.log"; : > "$REPAIR_LOG"
repair_integrator_verdict() { printf '%s %s\n' "$1" "${2:-}" >> "$REPAIR_LOG"; return 0; }

# =============================================================================
# A. PROMOTION PATH — preflight -> authoritative gate -> memory record
# =============================================================================
AUTH="$TEST_TMPDIR/fake-authority.sh"
cat > "$AUTH" <<'SH'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$AUTH_ARGS_LOG"
rec=""
while [ $# -gt 0 ]; do case "$1" in --record) rec="$2"; shift 2 ;; *) shift ;; esac; done
i=$(cat "$AUTH_IDX" 2>/dev/null || echo 0); i=$((i + 1)); printf '%s' "$i" > "$AUTH_IDX"
line=$(sed -n "${i}p" "$AUTH_PLAN")
IFS='|' read -r ex st rsha asha receipt crit region state prior incumbent <<EOF
$line
EOF
jq -n --arg st "$st" --arg rsha "$rsha" --arg asha "$asha" --arg receipt "$receipt" \
  --arg crit "$crit" --arg region "$region" --arg state "$state" --arg prior "$prior" \
  --arg incumbent "$incumbent" \
  '{status:$st,record_sha256:$rsha,promoted_receipt_sha256:$receipt,artifact_sha256:[$asha],
    repair:{criterion:$crit,region:$region,state:$state,prior_evidence_sha256:$prior,incumbent_id:$incumbent}}' \
  > "$rec"
exit "$ex"
SH
chmod +x "$AUTH"

MEM="$TEST_TMPDIR/fake-memory.sh"
cat > "$MEM" <<'SH'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$MEM_ARGS_LOG"
exit "${FAKE_MEMORY_EXIT:-0}"
SH
chmod +x "$MEM"

export AUTH_ARGS_LOG="$TEST_TMPDIR/auth.log"
export AUTH_IDX="$TEST_TMPDIR/auth.idx"
export AUTH_PLAN="$TEST_TMPDIR/auth.plan"
export MEM_ARGS_LOG="$TEST_TMPDIR/mem.log"
reset_auth() { : > "$AUTH_ARGS_LOG"; printf 0 > "$AUTH_IDX"; : > "$AUTH_PLAN"; }
plan() { printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$@" >> "$AUTH_PLAN"; }

PROJ="$TEST_TMPDIR/proj"; mkdir -p "$PROJ/.polylane"
INT_WORKTREE="$PROJ/int"; mkdir -p "$INT_WORKTREE/docs/polylane/design"
INT_NAME="integrator"
REPO_ROOT="$PROJ"
SCRIPT_DIR="$TEST_TMPDIR"
DRY_RUN=0; CYCLE=39; STATE_FILE="$PROJ/state.json"
POLYLANE_VISUAL_CONTRACT_VERSION=2
POLYLANE_VISUAL_AUTHORITY_CMD="$AUTH"
POLYLANE_TASTE_MEMORY_CMD="$MEM"
POLYLANE_PROMPT_UI_VERSION_CMD="$TEST_TMPDIR/no-promptopt"
INT_PROMPT="$PROJ/int.prompt"
printf 'lane work\nUI-CONTRACT: surface=ui ui_contract=2\n' > "$INT_PROMPT"

CUR="$TEST_TMPDIR/current.json"
printf '%s\n' '{"visual_quality":{"contract_version":"2",
 "authority":{"record":"docs/polylane/design/record.json","tournament":"docs/polylane/design/tournament.json","memory":"docs/polylane/taste/memory.jsonl"},
 "adapters":["browser-capture","image-decode"],"repair_cap":2,
 "evidence":"docs/polylane/design/visual-evidence.json","contract":"docs/polylane/design/visual-contract.json","verdict":"docs/polylane/design/visual-verdict.json"}}' > "$CUR"
MANIFEST="$CUR"

# Preflight must accept a valid current-UI manifest before any side effect.
assert_ok "e2e-preflight-valid-current-ok" visual_taste_preflight

# Full promotion: authoritative PASS -> gate rc0 -> then memory records once.
RUN_ID="e2e-promote"; VERDICT_RESULT="GO"
VISUAL_TASTE_RECORD=""; VISUAL_TASTE_RECEIPT_SHA=""
reset_auth; plan 0 pass RP AP receipt-promote "" "" "" "" ""
rc=0; visual_taste_authoritative_gate || rc=$?
assert_eq "e2e-authoritative-pass-rc0" 0 "$rc"
assert_contains "e2e-gate-called-at-int-worktree" "--worktree $INT_WORKTREE" "$(cat "$AUTH_ARGS_LOG")"
assert_eq "e2e-pass-captures-promoted-receipt" "receipt-promote" "$VISUAL_TASTE_RECEIPT_SHA"

: > "$MEM_ARGS_LOG"; PROMOTION_STATE="promoted"
VISUAL_TASTE_RECORD="$TEST_TMPDIR/promoted-record.json"
printf '{"status":"pass","promoted_receipt_sha256":"receipt-promote"}' > "$VISUAL_TASTE_RECORD"
VISUAL_TASTE_RECEIPT_SHA="receipt-promote"
rc=0; visual_taste_memory_record || rc=$?
assert_eq "e2e-memory-records-after-verified-promotion" 0 "$rc"
assert_contains "e2e-memory-binds-promoted-receipt" "receipt-promote" "$(cat "$MEM_ARGS_LOG")"

# Blocked authority despite a prose GO promotes nothing and records nothing.
RUN_ID="e2e-block"; VERDICT_RESULT="GO"
reset_auth; plan 1 block BB YY "" "" "" "" "" ""
assert_fail "e2e-block-despite-prose-go" visual_taste_authoritative_gate
: > "$MEM_ARGS_LOG"; PROMOTION_STATE="failed"
rc=0; visual_taste_memory_record || rc=$?
assert_eq "e2e-blocked-run-no-memory-rc0" 0 "$rc"
assert_eq "e2e-blocked-run-incumbent-preserved" "" "$(cat "$MEM_ARGS_LOG")"

# =============================================================================
# B. coordinator seq28 — auto-quiesce a committed, clean, DONE, still-live pane
# =============================================================================
# Real git worktree + hermetic pane seams. lane_completion_worker_live's three
# lookups (pane_index_for / pane_for_worktree / pane_agent_live) and the exit
# keystroke (pane_send_exit) are the only stubbed seams; every git/marker/clean
# check runs for real against the worktree.
ORCHESTRATION_CONTRACT=2
QWT="$TEST_TMPDIR/lanewt"; mkdir -p "$QWT/docs"
git -c init.defaultBranch=main init -q "$QWT"
git -C "$QWT" config user.email e2e@example.test
git -C "$QWT" config user.name e2e
QRUN="e2e-quiesce-1"
printf 'STATUS: builder DONE run=%s\n' "$QRUN" > "$QWT/docs/status-builder.md"
printf 'work\n' > "$QWT/src.txt" 2>/dev/null || true
mkdir -p "$QWT/src" && printf 'work\n' > "$QWT/src/app.txt"
git -C "$QWT" add -A
git -C "$QWT" commit -qm 'builder DONE'

EXIT_LOG="$TEST_TMPDIR/exit.log"; : > "$EXIT_LOG"
STUB_LIVE=1
pane_index_for() { printf '0'; }
pane_for_worktree() { printf '0'; }
pane_agent_live() { [ "${STUB_LIVE:-0}" = "1" ]; }
pane_send_exit() { printf '%s\n' "$1" >> "$EXIT_LOG"; }
# Scope validation is proven exhaustively in test-taste-runner-gate.sh; stub it
# here so this canary isolates the quiesce decision, not the scope grader.
lane_completion_scope_valid() { return 0; }

# The project root is distinct from every lane worktree (as in a real run), so a
# quiesce marker under $PROJECT_ROOT/.polylane never dirties the lane worktree.
PROJROOT="$TEST_TMPDIR/projroot"; mkdir -p "$PROJROOT"
RUN_ID="$QRUN"; PROJECT_ROOT="$PROJROOT"; MANIFEST="$CUR"; BASE="HEAD~0"

# 1) live pane on a valid committed DONE: not-done this poll, exactly one /exit.
rc=0; lane_done "$QWT" builder || rc=$?
assert_eq "quiesce-live-pane-not-done-this-poll" 1 "$rc"
assert_ok "quiesce-marker-written" test -e "$PROJROOT/.polylane/quiesce/quiesce-$QRUN-builder"
assert_eq "quiesce-sent-exactly-one-exit" "1" "$(grep -c . "$EXIT_LOG")"
# coordinator seq29: the once-marker lives in coordinator scratch, so quiescing a
# live pane must leave the lane worktree itself byte-for-byte clean.
assert_eq "quiesce-does-not-dirty-lane-worktree" "" "$(git -C "$QWT" status --porcelain)"

# 2) still live on the next poll: RE-SEND on a bounded budget. A single /exit
#    swallowed by a mid-render CLI hung a finished run for nine hours (c43d,
#    2026-08-19); every send re-proves clean+committed+scope-valid first, so a
#    bounded retry can only ever close a genuinely finished agent.
rc=0; lane_done "$QWT" builder || rc=$?
assert_eq "quiesce-second-poll-still-not-done" 1 "$rc"
assert_eq "quiesce-resends-exit-when-swallowed" "2" "$(grep -c . "$EXIT_LOG")"

#    …but the budget is finite: past POLYLANE_QUIESCE_MAX it stops sending.
POLYLANE_QUIESCE_MAX=3
rc=0; lane_done "$QWT" builder || rc=$?   # send 3
assert_eq "quiesce-third-send" "3" "$(grep -c . "$EXIT_LOG")"
rc=0; lane_done "$QWT" builder || rc=$?   # budget exhausted
assert_eq "quiesce-budget-caps-resends" "3" "$(grep -c . "$EXIT_LOG")"
unset POLYLANE_QUIESCE_MAX

# 3) once the agent has exited, the same committed DONE completes normally.
STUB_LIVE=0
rc=0; lane_done "$QWT" builder || rc=$?
assert_eq "quiesce-then-done-after-exit" 0 "$rc"

# 4) a DIRTY worktree (uncommitted work) is rejected BEFORE worker-live, so it is
#    never sent /exit and never quiesced — a working agent is untouched.
: > "$EXIT_LOG"
DWT="$TEST_TMPDIR/dirtywt"; mkdir -p "$DWT/docs"
git -c init.defaultBranch=main init -q "$DWT"
git -C "$DWT" config user.email e2e@example.test
git -C "$DWT" config user.name e2e
printf 'STATUS: builder DONE run=%s\n' "$QRUN" > "$DWT/docs/status-builder.md"
git -C "$DWT" add -A && git -C "$DWT" commit -qm done
printf 'uncommitted\n' > "$DWT/uncommitted.txt"
STUB_LIVE=1; PROJECT_ROOT="$PROJROOT"
rc=0; lane_done "$DWT" builder || rc=$?
assert_eq "quiesce-dirty-pane-not-done" 1 "$rc"
assert_eq "quiesce-dirty-pane-never-exited" "0" "$(grep -c . "$EXIT_LOG")"
assert_fail "quiesce-dirty-pane-no-marker" test -e "$DWT/.polylane/quiesce/quiesce-$QRUN-builder"

# 5) a marker whose run nonce mismatches the current run is rejected BEFORE
#    worker-live, so a stale-run pane is never quiesced.
: > "$EXIT_LOG"
SWT="$TEST_TMPDIR/stalewt"; mkdir -p "$SWT/docs"
git -c init.defaultBranch=main init -q "$SWT"
git -C "$SWT" config user.email e2e@example.test
git -C "$SWT" config user.name e2e
printf 'STATUS: builder DONE run=some-other-run\n' > "$SWT/docs/status-builder.md"
git -C "$SWT" add -A && git -C "$SWT" commit -qm done
STUB_LIVE=1; PROJECT_ROOT="$PROJROOT"
rc=0; lane_done "$SWT" builder || rc=$?
assert_eq "quiesce-stale-marker-not-done" 1 "$rc"
assert_eq "quiesce-stale-marker-never-exited" "0" "$(grep -c . "$EXIT_LOG")"

finish
