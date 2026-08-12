#!/usr/bin/env bash
# test-taste-a11y-live.sh — adversarial acceptance for the LIVE accessibility
# evidence runner (bin/polylane-taste-a11y-live.sh) and its pinned engine
# (benchmarks/taste-live/tools/accessibility.mjs).
#
# The runner recomputes PASS/FAIL/EXTERNAL/UNKNOWN from exact per-capture,
# per-criterion rule outcomes plus scripted keyboard/reflow/motion checks. It
# never trusts a caller verdict. This suite drives every branch from local DOM /
# action / reflow / motion fixtures (no browser): a clean pass, a red-first
# broken-engine build, evidence gaps, real violations (contrast, keyboard trap,
# lost focus, overflow), baseline regressions (contrast/target/motion), a
# pre-existing violation, a pre-registered exception, and the forgeries the trust
# boundary must reject — caller pass, forged/tampered capture, stale capture,
# exception drift, partial matrix, missing/mismatched engine, ineligible
# baseline, and a stale engine receipt.
set -u

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
A11Y_LIVE="$REPO_ROOT/bin/polylane-taste-a11y-live.sh"
ENGINE_SRC="$REPO_ROOT/benchmarks/taste-live/tools/accessibility.mjs"

for tool in jq node shasum git; do
  command -v "$tool" >/dev/null 2>&1 || { echo "SKIP: $tool unavailable"; exit 0; }
done

sha_file() { shasum -a 256 "$1" | awk '{print $1}'; }
sha_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }
canon_sha() { jq -Sc . | shasum -a 256 | awk '{print $1}'; }   # reads stdin
epoch_to_utc() {                                                # BSD then GNU
  date -u -r "$1" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null ||
    date -u -d "@$1" '+%Y-%m-%dT%H:%M:%SZ'
}

# --- subject repo + pinned engine -------------------------------------------
make_tmpdir
ROOT="$TEST_TMPDIR/subject"
mkdir -p "$ROOT/tools" "$ROOT/evidence"
git -C "$ROOT" init -q
git -C "$ROOT" config user.email a11y-live@example.test
git -C "$ROOT" config user.name a11y-live
cp "$ENGINE_SRC" "$ROOT/tools/accessibility.mjs"
printf 'source revision\n' > "$ROOT/app.txt"
git -C "$ROOT" add app.txt tools/accessibility.mjs
git -C "$ROOT" commit -qm source
REV=$(git -C "$ROOT" rev-parse HEAD)
SRC_EPOCH=$(git -C "$ROOT" log -1 --format=%ct HEAD)
EARLIER=$(epoch_to_utc "$SRC_EPOCH")
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

CID="cand-a11y-live"
ENGINE_PATH="$ROOT/tools/accessibility.mjs"; export ENGINE_PATH
ENGINE_SHA=$(sha_file "$ENGINE_PATH")
ENGINE_ID="taste-live-a11y"
ENGINE_PKG="polylane-taste-live-accessibility"
ENGINE_VER="1.0.0"
BROWSER_SHA=$(sha_text browser-live)
DESIGN_LOCK=$(sha_text design-lock)
SCOPE_SHA=$(sha_text scope-frozen)

CLEAN_REFLOW='{"viewport_css_px":{"w":320},"content_width_px":300,"horizontal_scroll":false}'
CLEAN_MOTION='{"has_motion":false}'

# clean DOM/action: one button, good contrast, reachable, focus-visible, no trap.
cat > "$TEST_TMPDIR/clean-dom.json" <<'JSON'
{
  "landmarks": ["main"],
  "headings": [{"level": 1}, {"level": 2}],
  "controls": [{"id": "go", "role": "button", "name": "Go", "focusable": true, "label": "Go", "target_px": {"w": 48, "h": 48}}],
  "text_nodes": [{"id": "t", "fg": "#000000", "bg": "#ffffff", "font_px": 16}],
  "state_indicators": [],
  "status_regions": [],
  "error_fields": []
}
JSON
cat > "$TEST_TMPDIR/clean-act.json" <<'JSON'
{"reachable": ["go"], "dom_order": ["go"], "focus_order": ["go"], "trap": false, "escape_returns_focus": null, "focus_visible": {"go": true}}
JSON
CLEAN_DOM="$TEST_TMPDIR/clean-dom.json"
CLEAN_ACT="$TEST_TMPDIR/clean-act.json"

# --- fixture builders --------------------------------------------------------
# mk_capture OUT ID ROUTE STATE VIEWPORT DOMFILE ACTFILE REFLOW MOTION CAPTURED_AT
mk_capture() {
  local out="$1" id="$2" route="$3" state="$4" vp="$5" domf="$6" actf="$7" reflow="$8" motion="$9" at="${10}"
  local dsha asha
  dsha=$(canon_sha < "$domf")
  asha=$(canon_sha < "$actf")
  jq -n --arg id "$id" --arg route "$route" --arg state "$state" --arg vp "$vp" \
    --arg at "$at" --arg dsha "$dsha" --arg asha "$asha" \
    --slurpfile dom "$domf" --slurpfile act "$actf" \
    --argjson reflow "$reflow" --argjson motion "$motion" \
    '{capture_id:$id,route:$route,state:$state,viewport:$vp,captured_at:$at,
      dom_sha256:$dsha,action_trace_sha256:$asha,
      payload:{dom:$dom[0],actions:$act[0],reflow:$reflow,motion:$motion}}' > "$out"
}

# mk_manifest OUT CANDIDATE_ID REV CAPTURE_FILE...
mk_manifest() {
  local out="$1" cid="$2" rev="$3"; shift 3
  jq -s '.' "$@" > "$out.caps"
  jq -n --arg cid "$cid" --arg rev "$rev" --arg brsha "$BROWSER_SHA" \
    --slurpfile caps "$out.caps" \
    '{schema_version:"taste-a11y-live-capture/v1",candidate_id:$cid,candidate_source_revision:$rev,
      browser:{adapter_id:"browser-live",adapter_receipt_sha256:$brsha},
      captures:$caps[0]}' > "$out"
  rm -f "$out.caps"
}

# base_plan — clean plan (no baseline, no manual, no exceptions), study pre-dated.
base_plan() {
  jq -n --arg cid "$CID" --arg rev "$REV" --arg lock "$DESIGN_LOCK" \
    --arg study "$EARLIER" --arg esha "$ENGINE_SHA" \
    --arg eid "$ENGINE_ID" --arg epkg "$ENGINE_PKG" --arg ever "$ENGINE_VER" \
    '{schema_version:"taste-a11y-live-plan/v1",candidate_id:$cid,source_revision:$rev,
      design_lock_sha256:$lock,evidence_class:"fixture",study_started_at:$study,
      baseline_receipt_path:"",
      engine:{engine_id:$eid,engine_package:$epkg,engine_version:$ever,source_path:"tools/accessibility.mjs",source_sha256:$esha},
      manual_external_criteria:[],scoped_exceptions:[]}'
}

# mk_baseline OUT RESULTS_JSON [EVIDENCE_CLASS]
mk_baseline() {
  jq -n --argjson r "$2" --arg cls "${3:-fixture}" \
    '{schema_version:"taste-a11y-live-receipt/v1",evidence_class:$cls,results:$r}' > "$1"
}

# build_single DIR DOMFILTER ACTFILTER REFLOW MOTION CAPTURED_AT — one clean-
# derived capture, mutated by jq filters, written to DIR/manifest.json.
build_single() {
  local dir="$1" domf="$2" actf="$3" reflow="$4" motion="$5" at="$6"
  mkdir -p "$dir"
  jq "$domf" "$CLEAN_DOM" > "$dir/dom.json"
  jq "$actf" "$CLEAN_ACT" > "$dir/act.json"
  mk_capture "$dir/cap.json" c1 "/" default desktop "$dir/dom.json" "$dir/act.json" "$reflow" "$motion" "$at"
  mk_manifest "$dir/manifest.json" "$CID" "$REV" "$dir/cap.json"
}

# --- audit runner (captures rc / stdout / stderr) ---------------------------
RC=0; OUT=""; ERR=""; RCPT=""
run_audit() {
  local root="$1" manifest="$2" plan="$3" out="$4"; shift 4
  local outf errf
  outf=$(mktemp); errf=$(mktemp)
  RC=0
  if bash "$A11Y_LIVE" audit "$root" "$manifest" "$plan" "$out" -- "$@" >"$outf" 2>"$errf"; then RC=0; else RC=$?; fi
  OUT=$(cat "$outf"); ERR=$(cat "$errf"); RCPT="$out"
  rm -f "$outf" "$errf"
}

assert_reject() {   # NAME EXPECTED_REASON
  if [ "$RC" = "2" ] && printf '%s' "$ERR" | grep -qF "TASTE-A11Y-LIVE: $2"; then
    pass "$1"
  else
    fail "$1" "want rc2/$2, got rc=$RC err=[$(printf '%s' "$ERR" | tail -1)]"
  fi
}
assert_status() {   # NAME EXPECTED_STATUS
  local got; got=$(jq -r '.derived_status' "$RCPT" 2>/dev/null || echo '<none>')
  if [ "$RC" = "0" ] && [ "$got" = "$2" ]; then pass "$1"; else fail "$1" "want rc0/$2, got rc=$RC status=$got"; fi
}
assert_reason() {   # NAME REASON_CODE
  if jq -e --arg r "$2" '.reason_codes | index($r) != null' "$RCPT" >/dev/null 2>&1; then
    pass "$1"
  else
    fail "$1" "reason $2 not in $(jq -c '.reason_codes' "$RCPT" 2>/dev/null)"
  fi
}
assert_violation() {   # NAME CRITERION
  if jq -e --arg c "$2" 'any(.violations[]?; .criterion==$c)' "$RCPT" >/dev/null 2>&1; then
    pass "$1"
  else
    fail "$1" "no violation for $2"
  fi
}

# ============================================================================
# A. clean pass — every required criterion measured, no gap/violation/manual.
# ============================================================================
C="$TEST_TMPDIR/A"; build_single "$C" '.' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
base_plan > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_status "clean_pass_status" PASS
assert_reason "clean_pass_reason_clean" CLEAN
assert_contains "clean_pass_marker" "TASTE-A11Y-LIVE: PASS" "$OUT"
assert_eq "clean_pass_checks" "15" "$(jq -r '.coverage.checks' "$C/receipt.json")"
assert_eq "clean_pass_gaps" "0" "$(jq -r '.coverage.evidence_gaps' "$C/receipt.json")"
assert_eq "clean_pass_schema" "taste-a11y-live-receipt/v1" "$(jq -r '.schema_version' "$C/receipt.json")"
assert_eq "clean_pass_engine_pin" "$ENGINE_SHA" "$(jq -r '.engine.source_sha256' "$C/receipt.json")"

# ============================================================================
# B. RED-FIRST: a broken engine build (the resText bug) fails closed as
#    ENGINE_FAILED; the SAME inputs on the pinned engine go green (PASS).
# ============================================================================
BROKEN="$TEST_TMPDIR/broken-engine.mjs"
# A broken engine build: reproduces the historical run() crash (an undefined
# reference) so the runner must fail closed (ENGINE_FAILED), not trust it.
cat > "$BROKEN" <<'MJS'
#!/usr/bin/env node
void resText; // ReferenceError: resText is not defined
MJS
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$TEST_TMPDIR/B-red.json" node "$BROKEN"
assert_reject "red_first_broken_engine" ENGINE_FAILED
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$TEST_TMPDIR/B-green.json" node "$ENGINE_PATH"
assert_status "red_first_pinned_green" PASS

# ============================================================================
# C. evidence gap — a rule the engine cannot measure is UNKNOWN, never PASS.
# ============================================================================
C="$TEST_TMPDIR/C"; build_single "$C" '.' '.' 'null' "$CLEAN_MOTION" "$NOW"
base_plan > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_status "gap_unknown_status" UNKNOWN
assert_reason "gap_unknown_reason" EVIDENCE_GAP

# ============================================================================
# D–G. real violations without a baseline → FAIL / NEW_VIOLATION.
# ============================================================================
C="$TEST_TMPDIR/D"; build_single "$C" '.text_nodes[0].fg="#bbbbbb"' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
base_plan > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_status "violation_contrast_status" FAIL
assert_reason "violation_contrast_reason" NEW_VIOLATION
assert_violation "violation_contrast_criterion" contrast

C="$TEST_TMPDIR/E"; build_single "$C" '.' '.trap=true' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
base_plan > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_status "keyboard_trap_status" FAIL
assert_violation "keyboard_trap_criterion" no-keyboard-trap

C="$TEST_TMPDIR/F"; build_single "$C" '.' '.focus_visible.go=false' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
base_plan > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_status "lost_focus_status" FAIL
assert_violation "lost_focus_criterion" focus-visible

C="$TEST_TMPDIR/G"; build_single "$C" '.' '.' '{"viewport_css_px":{"w":320},"content_width_px":900,"horizontal_scroll":true}' "$CLEAN_MOTION" "$NOW"
base_plan > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_status "overflow_status" FAIL
assert_violation "overflow_criterion" reflow-zoom-overflow

# ============================================================================
# H–J. baseline regressions — a criterion that PASSED on the baseline now
#      FAILS on the challenger → FAIL / REGRESSION (the veto).
# ============================================================================
regression_case() {   # NAME DOMFILTER ACTFILTER REFLOW MOTION CRITERION
  local name="$1" domf="$2" actf="$3" reflow="$4" motion="$5" crit="$6"
  local dir="$TEST_TMPDIR/reg-$name"
  build_single "$dir" "$domf" "$actf" "$reflow" "$motion" "$NOW"
  mk_baseline "$dir/baseline.json" \
    "$(jq -n --arg c "$crit" '[{route:"/",state:"default",viewport:"desktop",criterion:$c,status:"pass"}]')"
  base_plan | jq '.baseline_receipt_path="baseline.json"' > "$dir/plan.json"
  run_audit "$ROOT" "$dir/manifest.json" "$dir/plan.json" "$dir/receipt.json" node "$ENGINE_PATH"
  assert_status "regression_${name}_status" FAIL
  assert_reason "regression_${name}_reason" REGRESSION
  assert_violation "regression_${name}_criterion" "$crit"
}
regression_case contrast '.text_nodes[0].fg="#bbbbbb"' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" contrast
regression_case target '.controls[0].target_px={"w":20,"h":20}' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" target-size
regression_case motion '.' '.' "$CLEAN_REFLOW" '{"has_motion":true,"prefers_reduced_motion_respected":false}' reduced-motion

# ============================================================================
# K. un-waived pre-existing violation still vetoes → FAIL / PREEXISTING_VIOLATION.
# ============================================================================
C="$TEST_TMPDIR/K"; build_single "$C" '.text_nodes[0].fg="#bbbbbb"' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
mk_baseline "$C/baseline.json" '[{"route":"/","state":"default","viewport":"desktop","criterion":"contrast","status":"fail"}]'
base_plan | jq '.baseline_receipt_path="baseline.json"' > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_status "preexisting_status" FAIL
assert_reason "preexisting_reason" PREEXISTING_VIOLATION

# ============================================================================
# L. a pre-registered (frozen, pre-study) exception waives a baseline violation
#    → PASS / ACCEPTED_EXCEPTION. Automation never mints one; it only honours it.
# ============================================================================
C="$TEST_TMPDIR/L"; build_single "$C" '.text_nodes[0].fg="#bbbbbb"' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
mk_baseline "$C/baseline.json" '[{"route":"/","state":"default","viewport":"desktop","criterion":"contrast","status":"fail"}]'
base_plan | jq --arg study "$NOW" --arg created "$EARLIER" --arg scope "$SCOPE_SHA" '
  .study_started_at=$study | .baseline_receipt_path="baseline.json"
  | .scoped_exceptions=[{capture_id:"c1",created_at:$created,criterion:"contrast",frozen_id:"EXC-1",
      rationale:"legacy brand mark contrast, remediation tracked",reviewer_boundary:"a11y-lead@example.test",scope_sha256:$scope}]' \
  > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_status "accepted_exception_status" PASS
assert_reason "accepted_exception_reason" ACCEPTED_EXCEPTION
assert_eq "accepted_exception_count" "1" "$(jq -r '.accepted_exceptions | length' "$C/receipt.json")"

# ============================================================================
# M. exception drift — an exception created AFTER the study cutoff is rejected.
# ============================================================================
C="$TEST_TMPDIR/M"; build_single "$C" '.' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
base_plan | jq --arg scope "$SCOPE_SHA" '
  .scoped_exceptions=[{capture_id:"c1",created_at:"2099-01-01T00:00:00Z",criterion:"contrast",frozen_id:"EXC-9",
      rationale:"minted after the fact",reviewer_boundary:"nobody",scope_sha256:$scope}]' > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_reject "exception_drift" EXCEPTION_DRIFT

# ============================================================================
# N. caller pass — a verdict word smuggled into the engine output (nested, not
#    the last path) is rejected as CALLER_PASS by the hardened any(paths) guard.
# ============================================================================
FORGER="$TEST_TMPDIR/forger.sh"
cat > "$FORGER" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
node "$ENGINE_PATH"
out="$POLYLANE_A11Y_OUTPUT/result.json"
rcp="$POLYLANE_A11Y_OUTPUT/receipt.json"
if [ -n "${FORGE:-}" ]; then tmp=$(mktemp); jq "$FORGE" "$out" > "$tmp"; mv "$tmp" "$out"; fi
if [ -n "${RECEIPT_FORGE:-}" ]; then tmp=$(mktemp); jq "$RECEIPT_FORGE" "$rcp" > "$tmp"; mv "$tmp" "$rcp"; fi
SH
chmod +x "$FORGER"
C="$TEST_TMPDIR/N"; build_single "$C" '.' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
base_plan > "$C/plan.json"
FORGE='.captures[0].checks[0].measured += {verdict:"pass"}' \
  run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" bash "$FORGER"
assert_reject "forged_caller_pass" CALLER_PASS

# ============================================================================
# O. forged capture — DOM tampered after its digest is fixed → DOM_BINDING.
# ============================================================================
C="$TEST_TMPDIR/O"; build_single "$C" '.' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
jq '.captures[0].payload.dom.text_nodes[0].fg="#123456"' "$C/manifest.json" > "$C/manifest.tampered.json"
base_plan > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.tampered.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_reject "forged_dom_binding" DOM_BINDING

# ============================================================================
# P. stale capture — captured before the source revision it claims.
# ============================================================================
C="$TEST_TMPDIR/P"; build_single "$C" '.' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "2000-01-01T00:00:00Z"
base_plan > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_reject "stale_capture" STALE_CAPTURE

# ============================================================================
# Q. partial matrix (captures) — engine drops a capture from the result set.
# ============================================================================
C="$TEST_TMPDIR/Q"; mkdir -p "$C"
mk_capture "$C/c1.json" c1 "/" default desktop "$CLEAN_DOM" "$CLEAN_ACT" "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
mk_capture "$C/c2.json" c2 "/two" default mobile "$CLEAN_DOM" "$CLEAN_ACT" "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
mk_manifest "$C/manifest.json" "$CID" "$REV" "$C/c1.json" "$C/c2.json"
base_plan > "$C/plan.json"
FORGE='.captures |= .[1:]' \
  run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" bash "$FORGER"
assert_reject "partial_matrix_captures" MATRIX_MISMATCH

# ============================================================================
# R. partial matrix (criteria) — engine drops a required check.
# ============================================================================
C="$TEST_TMPDIR/R"; build_single "$C" '.' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
base_plan > "$C/plan.json"
FORGE='del(.captures[0].checks[0])' \
  run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" bash "$FORGER"
assert_reject "partial_matrix_coverage" COVERAGE_INCOMPLETE

# ============================================================================
# S. missing engine source — pinned source_path absent from the tree.
# ============================================================================
C="$TEST_TMPDIR/S"; build_single "$C" '.' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
base_plan | jq '.engine.source_path="tools/nonexistent.mjs"' > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_reject "engine_missing_source" ENGINE_MISSING

# ============================================================================
# T. engine identity — a different-version build is rejected against the pin.
# ============================================================================
# Keep the filename ending in accessibility.mjs so the engine's self-run guard
# fires; only the version constant differs from the pinned build.
mkdir -p "$ROOT/tools/v2"
cp "$ENGINE_PATH" "$ROOT/tools/v2/accessibility.mjs"
sed -i.bak 's/export const ENGINE_VERSION = "1.0.0";/export const ENGINE_VERSION = "9.9.9";/' "$ROOT/tools/v2/accessibility.mjs"
rm -f "$ROOT/tools/v2/accessibility.mjs.bak"
C="$TEST_TMPDIR/T"; build_single "$C" '.' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
base_plan > "$C/plan.json"   # plan still pins version 1.0.0 + real source hash
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ROOT/tools/v2/accessibility.mjs"
assert_reject "engine_identity_mismatch" ENGINE_IDENTITY_MISMATCH

# ============================================================================
# U. manual review required — automation reports EXTERNAL, never PASS.
# ============================================================================
C="$TEST_TMPDIR/U"; build_single "$C" '.' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
base_plan | jq '.manual_external_criteria=["screen-reader-usability"]' > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_status "manual_external_status" EXTERNAL
assert_reason "manual_external_reason" MANUAL_EXTERNAL

# ============================================================================
# V. ineligible baseline — a production baseline cannot gate a fixture study.
# ============================================================================
C="$TEST_TMPDIR/V"; build_single "$C" '.' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
mk_baseline "$C/baseline.json" '[{"route":"/","state":"default","viewport":"desktop","criterion":"contrast","status":"pass"}]' production
base_plan | jq '.baseline_receipt_path="baseline.json"' > "$C/plan.json"
run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" node "$ENGINE_PATH"
assert_reject "baseline_ineligible" BASELINE_INELIGIBLE

# ============================================================================
# W. stale engine receipt — executed_at outside the run window → STALE_RECEIPT.
# ============================================================================
C="$TEST_TMPDIR/W"; build_single "$C" '.' '.' "$CLEAN_REFLOW" "$CLEAN_MOTION" "$NOW"
base_plan > "$C/plan.json"
RECEIPT_FORGE='.executed_at="2000-01-01T00:00:00Z"' \
  run_audit "$ROOT" "$C/manifest.json" "$C/plan.json" "$C/receipt.json" bash "$FORGER"
assert_reject "stale_engine_receipt" STALE_RECEIPT

finish
