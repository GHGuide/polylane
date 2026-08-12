#!/usr/bin/env bash
# test-taste-runner-gate.sh — current-UI visual-contract wiring in the runner.
#
# Sources bin/polylane-run.sh (its main is BASH_SOURCE-guarded) and drives the
# new current-UI functions with hermetic doubles: a fake authoritative
# visual-quality helper (POLYLANE_VISUAL_AUTHORITY_CMD), a fake project taste
# memory helper (POLYLANE_TASTE_MEMORY_CMD), and stubbed runtime seams
# (repair_integrator_verdict/poll_done/merge_gate/graph events). No tmux, no git.
#
# Proves: non-UI unchanged; legacy unchanged; current-UI preflight fails closed
# on missing/unsafe config before any side effect; the v2 helper is called at the
# integrator-worktree boundary; a prose GO cannot bypass it; a safe PASS promotes;
# repair receives ONLY grounded data; unchanged/third repair blocks; resume
# preserves the durable attempt; memory records only after a verified promotion
# and never on a non-promoted/NO-GO run.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

if ! command -v jq >/dev/null 2>&1; then pass "taste-runner-gate-skipped-no-jq"; finish; exit 0; fi

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

# --- fake authoritative visual-quality helper --------------------------------
# Pops one directive line per call from $AUTH_PLAN:
#   exit|status|record_sha|artifact_sha|receipt|criterion|region|state|prior|incumbent
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

# --- shared globals the runner functions read --------------------------------
PROJ="$TEST_TMPDIR/proj"; mkdir -p "$PROJ/.polylane"
INT_WORKTREE="$PROJ/int"; mkdir -p "$INT_WORKTREE/docs/polylane/design"
INT_NAME="integrator"
REPO_ROOT="$PROJ"
SCRIPT_DIR="$TEST_TMPDIR"
DRY_RUN=0; CYCLE=39; STATE_FILE="$PROJ/state.json"
POLYLANE_VISUAL_CONTRACT_VERSION=2
POLYLANE_VISUAL_AUTHORITY_CMD="$AUTH"
POLYLANE_TASTE_MEMORY_CMD="$MEM"
# Force the grep fallback in visual_taste_prompt_ui_version (no real promptopt).
POLYLANE_PROMPT_UI_VERSION_CMD="$TEST_TMPDIR/no-promptopt"
INT_PROMPT="$PROJ/int.prompt"
# prompt-contract's frozen format: exact-once UI-CONTRACT: scalar carrying ui_contract=.
printf 'lane work\nUI-CONTRACT: surface=ui ui_contract=2\n' > "$INT_PROMPT"

mk_manifest() { printf '%s\n' "$2" > "$1"; }

CURRENT_JSON='{"visual_quality":{"contract_version":"2",
 "authority":{"record":"docs/polylane/design/record.json","tournament":"docs/polylane/design/tournament.json","memory":"docs/polylane/taste/memory.jsonl"},
 "adapters":["browser-capture","image-decode"],"repair_cap":2,
 "evidence":"docs/polylane/design/visual-evidence.json","contract":"docs/polylane/design/visual-contract.json","verdict":"docs/polylane/design/visual-verdict.json"}}'

# =============================================================================
# 1) NON-UI runs are unchanged
# =============================================================================
NOUI="$TEST_TMPDIR/noui.json"; mk_manifest "$NOUI" '{"lanes":[]}'
MANIFEST="$NOUI"
assert_fail "noui-not-current-mode"        visual_contract_current_requested
assert_fail "noui-legacy-predicate-false"  visual_quality_requested
assert_ok   "noui-preflight-noop"          visual_taste_preflight

# =============================================================================
# 2) LEGACY visual runs are unchanged (object without contract_version, or bool)
# =============================================================================
LEGACY="$TEST_TMPDIR/legacy.json"; mk_manifest "$LEGACY" '{"visual_quality":true}'
MANIFEST="$LEGACY"
assert_fail "legacy-not-current-mode"      visual_contract_current_requested
assert_ok   "legacy-still-visual-requested" visual_quality_requested
assert_ok   "legacy-preflight-noop"        visual_taste_preflight
LEGACY2="$TEST_TMPDIR/legacy2.json"; mk_manifest "$LEGACY2" '{"visual_quality":{"enabled":true}}'
MANIFEST="$LEGACY2"
assert_fail "legacy-obj-not-current-mode"  visual_contract_current_requested

# =============================================================================
# 3) CURRENT-UI detection + preflight
# =============================================================================
CUR="$TEST_TMPDIR/current.json"; mk_manifest "$CUR" "$CURRENT_JSON"
MANIFEST="$CUR"
assert_ok   "current-mode-detected"        visual_contract_current_requested
assert_ok   "preflight-valid-current-ok"   visual_taste_preflight

# missing authority block fails closed
BAD="$TEST_TMPDIR/bad-authority.json"
mk_manifest "$BAD" "$(printf '%s' "$CURRENT_JSON" | jq 'del(.visual_quality.authority)')"
MANIFEST="$BAD"
assert_fail "preflight-missing-authority-fails" visual_taste_preflight

# missing adapter declarations fails closed
mk_manifest "$BAD" "$(printf '%s' "$CURRENT_JSON" | jq 'del(.visual_quality.adapters)')"
MANIFEST="$BAD"
assert_fail "preflight-missing-adapters-fails" visual_taste_preflight

# repair cap over the protocol maximum fails closed
mk_manifest "$BAD" "$(printf '%s' "$CURRENT_JSON" | jq '.visual_quality.repair_cap=3')"
MANIFEST="$BAD"
assert_fail "preflight-repaircap-over-two-fails" visual_taste_preflight

# unsafe absolute authority path rejected
mk_manifest "$BAD" "$(printf '%s' "$CURRENT_JSON" | jq '.visual_quality.authority.record="/etc/passwd"')"
MANIFEST="$BAD"
assert_fail "preflight-unsafe-abs-path-fails" visual_taste_preflight

# unsafe parent-escape authority path rejected
mk_manifest "$BAD" "$(printf '%s' "$CURRENT_JSON" | jq '.visual_quality.authority.tournament="../../secrets"')"
MANIFEST="$BAD"
assert_fail "preflight-unsafe-dotdot-path-fails" visual_taste_preflight

# non-executable authoritative helper fails closed
MANIFEST="$CUR"
( POLYLANE_VISUAL_AUTHORITY_CMD="$TEST_TMPDIR/nope"; export POLYLANE_VISUAL_AUTHORITY_CMD
  visual_taste_preflight ) >/dev/null 2>&1 \
  && fail "preflight-nonexec-helper-fails" "expected nonzero" \
  || pass "preflight-nonexec-helper-fails"

# prompt / manifest visual-contract disagreement fails closed
printf 'lane work\nUI-CONTRACT: surface=ui ui_contract=9\n' > "$PROJ/int.mismatch.prompt"
( INT_PROMPT="$PROJ/int.mismatch.prompt"; visual_taste_preflight ) >/dev/null 2>&1 \
  && fail "preflight-prompt-version-mismatch-fails" "expected nonzero" \
  || pass "preflight-prompt-version-mismatch-fails"
# a prompt with no UI-CONTRACT scalar at all also fails closed
printf 'lane work\nno contract line here\n' > "$PROJ/int.nomarker.prompt"
( INT_PROMPT="$PROJ/int.nomarker.prompt"; visual_taste_preflight ) >/dev/null 2>&1 \
  && fail "preflight-prompt-missing-marker-fails" "expected nonzero" \
  || pass "preflight-prompt-missing-marker-fails"

# =============================================================================
# 4) Authoritative gate — boundary, PASS, prose-GO cannot bypass
# =============================================================================
MANIFEST="$CUR"; RUN_ID="gate-pass"; VERDICT_RESULT="GO"
VISUAL_TASTE_RECORD=""; VISUAL_TASTE_RECEIPT_SHA=""
reset_auth; plan 0 pass RP AP receipt-pass "" "" "" "" ""
rc=0; visual_taste_authoritative_gate || rc=$?
assert_eq   "gate-safe-pass-rc0" 0 "$rc"
assert_contains "gate-helper-called-authoritative" "authoritative" "$(cat "$AUTH_ARGS_LOG")"
assert_contains "gate-helper-called-at-worktree" "--worktree $INT_WORKTREE" "$(cat "$AUTH_ARGS_LOG")"
assert_eq   "gate-pass-captures-receipt" "receipt-pass" "$VISUAL_TASTE_RECEIPT_SHA"

# prose GO must not bypass a BLOCK verdict from the host gate
MANIFEST="$CUR"; RUN_ID="gate-block"; VERDICT_RESULT="GO"
reset_auth; plan 1 block BB YY "" "" "" "" "" ""
assert_fail "gate-block-despite-prose-go" visual_taste_authoritative_gate

# =============================================================================
# 5) Bounded repair — grounded data only, then PASS
# =============================================================================
MANIFEST="$CUR"; RUN_ID="gate-repair"; : > "$REPAIR_LOG"
VERDICT="$INT_WORKTREE/docs/polylane/design/visual-verdict.json"; rm -f "$VERDICT"
reset_auth
plan 10 repair R1 A1 "" hierarchy header default prior-ev-1 cand-a
plan 0  pass   RP AP receipt-2 "" "" "" "" ""
rc=0; visual_taste_authoritative_gate || rc=$?
assert_eq   "gate-repair-then-pass-rc0" 0 "$rc"
assert_ok   "gate-repair-wrote-verdict" test -s "$VERDICT"
assert_eq   "gate-repair-verdict-keys-are-exactly-grounded" \
  "attempt,criterion,incumbent_id,prior_evidence_sha256,region,state" \
  "$(jq -rc '. as $v | ($v|keys) | sort | join(",")' "$VERDICT")"
assert_fail "gate-repair-verdict-has-no-screenshots" jq -e 'has("screenshots") or has("lenses") or has("evidence")' "$VERDICT"
assert_eq   "gate-repair-grounded-criterion" "hierarchy" "$(jq -r .criterion "$VERDICT")"
assert_eq   "gate-repair-grounded-incumbent" "cand-a" "$(jq -r .incumbent_id "$VERDICT")"
assert_eq   "gate-repair-grounded-prior-hash" "prior-ev-1" "$(jq -r .prior_evidence_sha256 "$VERDICT")"
assert_contains "gate-repair-route-called-visual-attempt1" "1 visual" "$(cat "$REPAIR_LOG")"

# =============================================================================
# 6) Unchanged repair blocks (record + artifact hashes did not change)
# =============================================================================
MANIFEST="$CUR"; RUN_ID="gate-unchanged"
reset_auth
plan 10 repair SAME AH "" hierarchy header default prior-x cand-a
plan 10 repair SAME AH "" hierarchy header default prior-x cand-a
assert_fail "gate-unchanged-repair-blocks" visual_taste_authoritative_gate

# =============================================================================
# 7) Third repair blocks (repair budget of two exhausted)
# =============================================================================
MANIFEST="$CUR"; RUN_ID="gate-third"
reset_auth
plan 10 repair A1 X1 "" c r default p1 cand-a
plan 10 repair B2 Y2 "" c r default p2 cand-a
plan 10 repair C3 Z3 "" c r default p3 cand-a
assert_fail "gate-third-repair-blocks" visual_taste_authoritative_gate

# =============================================================================
# 8) Resume preserves the durable attempt count
# =============================================================================
MANIFEST="$CUR"; RUN_ID="gate-resume"; : > "$REPAIR_LOG"
mkdir -p "$PROJ/.polylane/visual-taste"
printf 1 > "$PROJ/.polylane/visual-taste/$RUN_ID.attempt"   # one repair already spent pre-crash
reset_auth
plan 10 repair D1 W1 "" c r default p1 cand-a               # -> attempt 2 (last token)
plan 10 repair E2 W2 "" c r default p2 cand-a               # -> exhausted, block
assert_fail "gate-resume-blocks-after-preserved-attempt" visual_taste_authoritative_gate
assert_eq   "gate-resume-durable-attempt-is-two" "2" "$(cat "$PROJ/.polylane/visual-taste/$RUN_ID.attempt")"
assert_eq   "gate-resume-dispatched-one-repair" "1" "$(grep -c . "$REPAIR_LOG")"

# =============================================================================
# 9) Taste memory records ONLY after a verified promotion
# =============================================================================
MANIFEST="$CUR"
: > "$MEM_ARGS_LOG"
PROMOTION_STATE="promoted"
VISUAL_TASTE_RECORD="$TEST_TMPDIR/promoted-record.json"
printf '{"status":"pass","promoted_receipt_sha256":"receipt-final"}' > "$VISUAL_TASTE_RECORD"
VISUAL_TASTE_RECEIPT_SHA="receipt-final"
rc=0; visual_taste_memory_record || rc=$?
assert_eq   "memory-records-after-verified-promotion-rc0" 0 "$rc"
assert_contains "memory-records-with-promoted-receipt" "--receipt-sha256 receipt-final" "$(cat "$MEM_ARGS_LOG")"
assert_contains "memory-records-from-promoted-record" "$VISUAL_TASTE_RECORD" "$(cat "$MEM_ARGS_LOG")"

# never learns from a non-promoted run
: > "$MEM_ARGS_LOG"; PROMOTION_STATE="failed"
rc=0; visual_taste_memory_record || rc=$?
assert_eq   "memory-noop-when-not-promoted-rc0" 0 "$rc"
assert_eq   "memory-never-invoked-when-not-promoted" "" "$(cat "$MEM_ARGS_LOG")"

# memory helper failure after promotion is visible and fails closed
: > "$MEM_ARGS_LOG"; PROMOTION_STATE="promoted"
( FAKE_MEMORY_EXIT=1; export FAKE_MEMORY_EXIT; visual_taste_memory_record ) >/dev/null 2>&1 \
  && fail "memory-failclosed-on-helper-error" "expected nonzero" \
  || pass "memory-failclosed-on-helper-error"

# non-current runs never touch taste memory
: > "$MEM_ARGS_LOG"; MANIFEST="$LEGACY"; PROMOTION_STATE="promoted"
rc=0; visual_taste_memory_record || rc=$?
assert_eq   "memory-noop-for-legacy-run-rc0" 0 "$rc"
assert_eq   "memory-never-invoked-for-legacy-run" "" "$(cat "$MEM_ARGS_LOG")"

finish
