#!/usr/bin/env bash
# test-taste-a11y.sh — adversarial acceptance for the trusted accessibility
# evidence runner. The runner consumes a verified capture manifest plus a
# pinned, receipted accessibility adapter and recomputes PASS/FAIL/EXTERNAL from
# exact per-check results. Caller-authored pass booleans, missing coverage,
# forged/stale adapters, and baseline regressions can never authorize promotion.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

A11Y="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-taste-a11y.sh"
a11y() { bash "$A11Y" "$@"; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
sha_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

make_tmpdir
ROOT="$TEST_TMPDIR/project"
mkdir -p "$ROOT/evidence" "$ROOT/tools"
git -C "$ROOT" init -q
git -C "$ROOT" config user.email a11y@example.test
git -C "$ROOT" config user.name a11y
printf 'source revision\n' > "$ROOT/app.txt"
git -C "$ROOT" add app.txt
git -C "$ROOT" commit -qm source
REVISION=$(git -C "$ROOT" rev-parse HEAD)
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# --- pinned accessibility adapter (fixture) ---------------------------------
# Real adapters examine the captured DOM/action-trace and measure evidence. This
# fixture is generic: it echoes the request identity and hashes, and reports one
# check per required criterion. A per-capture verdict file (A11Y_VERDICT) injects
# violations, omissions, duplicates, unknown criteria, and relabeling so the
# runner's trust boundary can be attacked without a browser.
cat > "$ROOT/tools/a11y-adapter" <<'PY'
#!/usr/bin/env python3
import hashlib, json, os, sys
req = json.load(open(os.environ["POLYLANE_A11Y_REQUEST"]))
out = os.environ["POLYLANE_A11Y_OUTPUT"]
vp = os.environ.get("A11Y_VERDICT", "")
v = json.load(open(vp)) if vp and os.path.exists(vp) else {}
empty = os.environ.get("A11Y_EMPTY_MEASURE") == "1"
crit = req["required_criteria"]
captures = []
for c in req["captures"]:
    cid = c["capture_id"]
    fails = set(v.get("fail", {}).get(cid, []))
    nas = set(v.get("na", {}).get(cid, []))
    omit = set(v.get("omit", {}).get(cid, []))
    checks = []
    for k in crit:
        if k in omit:
            continue
        status = "fail" if k in fails else ("not-applicable" if k in nas else "pass")
        if empty:
            measured = {}
        elif status == "not-applicable":
            measured = {"reason": "no such element on this route/state"}
        elif status == "fail":
            measured = {"observed": "1.9:1", "required": "4.5:1", "selector": "#x"}
        else:
            measured = {"observed": "6.1:1", "required": "4.5:1", "selector": "#x"}
        checks.append({"criterion": k, "check_id": k + "-1", "region": "main", "status": status, "measured": measured})
    if v.get("dup") == cid:
        checks.append(dict(checks[0]))
    if v.get("unknown") == cid:
        checks.append({"criterion": "totally-made-up", "check_id": "u1", "region": "main", "status": "pass", "measured": {"x": 1}})
    if v.get("manual") == cid:
        checks.append({"criterion": "screen-reader-usability", "check_id": "m1", "region": "main", "status": "pass", "measured": {"x": 1}})
    captures.append({"capture_id": cid, "dom_sha256": c["dom_sha256"], "action_trace_sha256": c["action_trace_sha256"], "checks": checks})
result = {
    "schema_version": "taste-a11y-adapter-result/v1",
    "adapter_id": req["adapter"]["adapter_id"],
    "adapter_version": req["adapter"]["adapter_version"],
    "profile_sha256": req["adapter"]["profile_sha256"],
    "evidence_class": os.environ.get("A11Y_RELABEL", req["evidence_class"]),
    "captures": captures,
}
rp = os.path.join(out, "result.json")
open(rp, "w").write(json.dumps(result, sort_keys=True))
result_bytes = open(rp, "rb").read()
req_bytes = open(os.environ["POLYLANE_A11Y_REQUEST"], "rb").read()
command_sha = hashlib.sha256(open(sys.argv[0], "rb").read()).hexdigest()
receipt = {
    "schema_version": "taste-adapter-receipt/v1",
    "adapter_id": req["adapter"]["adapter_id"],
    "adapter_version": req["adapter"]["adapter_version"],
    "command_sha256": command_sha,
    "input_sha256": [hashlib.sha256(req_bytes).hexdigest()] + [c["dom_sha256"] for c in req["captures"]],
    "output_sha256": [hashlib.sha256(result_bytes).hexdigest()],
    "exit_status": 0,
    "executed_at": os.environ.get("A11Y_EXECUTED", os.environ["A11Y_NOW"]),
}
open(os.path.join(out, "receipt.json"), "w").write(json.dumps(receipt, sort_keys=True))
PY
chmod +x "$ROOT/tools/a11y-adapter"
ADAPTER_SHA=$(sha "$ROOT/tools/a11y-adapter")
PROFILE_SHA=$(sha_text "wcag21aa-profile-v1")
export A11Y_NOW="$NOW"

MANIFEST="$ROOT/evidence/captures.json"
PLAN="$ROOT/evidence/a11y-plan.json"
RECEIPT="$ROOT/evidence/a11y-receipt.json"
VERDICT="$ROOT/evidence/verdict.json"
BASELINE="$ROOT/evidence/baseline-receipt.json"

write_manifest() {
  local rows="" id route state viewport w h
  for route in /app; do
    for state in default error; do
      for viewport in desktop mobile; do
        case "$viewport" in desktop) w=1440; h=900 ;; *) w=390; h=844 ;; esac
        id="cap-${state}-${viewport}"
        rows="$rows$(jq -nc --arg id "$id" --arg route "$route" --arg state "$state" --arg viewport "$viewport" \
          --argjson w "$w" --argjson h "$h" --arg dom "$(sha_text "dom-$id")" --arg act "$(sha_text "act-$id")" --arg now "$NOW" \
          '{capture_id:$id,route:$route,state:$state,viewport:$viewport,viewport_css_px:{width:$w,height:$h},screenshot_path:("captures/"+$id+"/screenshot.png"),screenshot_png_sha256:($dom|.[0:64]),decoded_pixel_sha256:($act|.[0:64]),decoded_width:$w,decoded_height:$h,action_trace_sha256:$act,dom_sha256:$dom,captured_at:$now}')"$'\n'
      done
    done
  done
  jq -n --arg rev "$REVISION" --argjson captures "$(printf '%s' "$rows" | jq -s .)" '
    {schema_version:"taste-capture-manifest/v1",candidate_id:"cand-opaque-a",candidate_source_revision:$rev,
     required_routes:["/app"],required_states:["default","error"],mobile_only_states:[],
     browser:{adapter_id:"browser-capture",adapter_receipt_path:"browser-receipt.json"},
     decoder:{adapter_id:"png-decoder",adapter_version:"fixture-v1",command_path:"tools/decode-png",command_sha256:("d"*64)},
     captures:$captures}' > "$MANIFEST"
}

# write_plan EVIDENCE_CLASS BASELINE_PATH EXCEPTIONS_JSON MANUAL_JSON
write_plan() {
  jq -n --arg rev "$REVISION" --arg cmd_sha "$ADAPTER_SHA" --arg prof "$PROFILE_SHA" \
    --arg cls "${1:-fixture}" --arg baseline "${2:-}" --argjson exc "${3:-[]}" --argjson man "${4:-[\"screen-reader-usability\",\"cognitive-accessibility\"]}" '
    {schema_version:"taste-a11y-plan/v1",candidate_id:"cand-opaque-a",source_revision:$rev,
     design_lock_sha256:("e"*64),evidence_class:$cls,baseline_receipt_path:$baseline,
     adapter:{adapter_id:"a11y-axe",adapter_version:"fixture-v1",command_path:"tools/a11y-adapter",command_sha256:$cmd_sha,profile_sha256:$prof},
     scoped_exceptions:$exc,manual_external_criteria:$man}' > "$PLAN"
}

# run VERDICT_JSON — returns rc, leaves receipt at $RECEIPT, stderr in $STDERR
STDERR="$ROOT/evidence/stderr.txt"
run() {
  printf '%s' "${1:-{\}}" > "$VERDICT"
  rm -f "$RECEIPT"
  local rc=0
  A11Y_VERDICT="$VERDICT" a11y audit "$ROOT" "$MANIFEST" "$PLAN" "$RECEIPT" -- "$ROOT/tools/a11y-adapter" 2>"$STDERR" || rc=$?
  return $rc
}
status() { jq -r '.derived_status' "$RECEIPT" 2>/dev/null; }

write_manifest
write_plan

# 1. complete positive fixture — automatable clean, manual pending → EXTERNAL
rc=0; run '{}' || rc=$?
assert_eq "a11y-positive-complete-fixture-rc0" 0 "$rc"
assert_eq "a11y-positive-derived-external" "EXTERNAL" "$(status)"
assert_contains "a11y-positive-reason-clean" "CLEAN" "$(jq -c .reason_codes "$RECEIPT")"
assert_contains "a11y-positive-lists-manual-external" "screen-reader-usability" "$(jq -c .manual_external "$RECEIPT")"
assert_eq "a11y-positive-rejects-caller-pass-field" "false" "$(jq 'has("pass")' "$RECEIPT")"

# 2. no manual items → derived PASS
write_plan fixture "" "[]" "[]"
rc=0; run '{}' || rc=$?
assert_eq "a11y-no-manual-derived-pass" "PASS" "$(status)"
write_plan  # restore defaults

# 3-11. per-criterion automatable violations → FAIL
check_violation() {
  local name="$1" criterion="$2"
  run "$(jq -nc --arg c "$criterion" '{fail:{"cap-default-desktop":[$c]}}')" || true
  assert_eq "a11y-$name-derived-fail" "FAIL" "$(status)"
  assert_contains "a11y-$name-violation-listed" "$criterion" "$(jq -c '[.violations[].criterion]' "$RECEIPT")"
  assert_contains "a11y-$name-measured-not-bare-pass" "observed" "$(jq -c '.violations[0].measured' "$RECEIPT")"
}
check_violation "missing-label" "labels-instructions"
check_violation "duplicate-id" "semantics-name-role-value"
check_violation "unreachable-keyboard" "keyboard-reachable"
check_violation "keyboard-trap" "no-keyboard-trap"
check_violation "invisible-focus" "focus-visible"
check_violation "low-contrast" "contrast"
check_violation "color-only-error" "non-color-state"
check_violation "overflow-reflow" "reflow-zoom-overflow"
check_violation "motion-violation" "reduced-motion"

# 12. missing required check (omitted criterion) → reject, no receipt
run "$(jq -nc '{omit:{"cap-default-desktop":["contrast"]}}')" || true
assert_contains "a11y-missing-check-rejected" "COVERAGE_INCOMPLETE" "$(cat "$STDERR")"
assert_eq "a11y-missing-check-no-receipt" "false" "$([ -f "$RECEIPT" ] && echo true || echo false)"

# 13. duplicate check for one criterion → reject
run "$(jq -nc '{dup:"cap-default-desktop"}')" || true
assert_contains "a11y-duplicate-check-rejected" "DUPLICATE_CHECK" "$(cat "$STDERR")"

# 14. unknown criterion → reject
run "$(jq -nc '{unknown:"cap-default-desktop"}')" || true
assert_contains "a11y-unknown-criterion-rejected" "UNKNOWN_CRITERION" "$(cat "$STDERR")"

# 15. manual criterion auto-passed by adapter → reject
run "$(jq -nc '{manual:"cap-default-desktop"}')" || true
assert_contains "a11y-manual-auto-pass-rejected" "MANUAL_AUTO_PASS" "$(cat "$STDERR")"

# 16. bare pass without measured evidence → reject
A11Y_EMPTY_MEASURE=1 run '{}' || true
assert_contains "a11y-bare-pass-rejected" "MISSING_MEASURED_EVIDENCE" "$(cat "$STDERR")"
unset A11Y_EMPTY_MEASURE

# 17. stale adapter receipt → reject
A11Y_EXECUTED="2000-01-01T00:00:00Z" run '{}' || true
assert_contains "a11y-stale-adapter-rejected" "STALE_RECEIPT" "$(cat "$STDERR")"
unset A11Y_EXECUTED

# 18. forged adapter — file mutated after pin → reject
printf '# tamper\n' >> "$ROOT/tools/a11y-adapter"
run '{}' || true
assert_contains "a11y-forged-adapter-rejected" "ADAPTER_MISMATCH" "$(cat "$STDERR")"
# restore pinned adapter
git -C "$ROOT" >/dev/null 2>&1 || true
sed -i.bak '/^# tamper$/d' "$ROOT/tools/a11y-adapter" && rm -f "$ROOT/tools/a11y-adapter.bak"
[ "$(sha "$ROOT/tools/a11y-adapter")" = "$ADAPTER_SHA" ] || { echo "adapter restore failed" >&2; }

# 19. fixture-to-production relabeling → reject
A11Y_RELABEL="production" run '{}' || true
assert_contains "a11y-fixture-relabel-rejected" "FIXTURE_RELABELED" "$(cat "$STDERR")"
unset A11Y_RELABEL

# 20. stale source revision (manifest rev no longer HEAD) → reject
jq '.candidate_source_revision="0000000000000000000000000000000000000000"' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
run '{}' || true
assert_contains "a11y-stale-source-rejected" "STALE_SOURCE_REVISION" "$(cat "$STDERR")"
write_manifest

# 21. baseline regression — clean baseline, challenger fails contrast → FAIL veto
run '{}' && cp "$RECEIPT" "$BASELINE"
write_plan fixture "baseline-receipt.json" "[]"
run "$(jq -nc '{fail:{"cap-default-desktop":["contrast"]}}')" || true
assert_eq "a11y-baseline-regression-derived-fail" "FAIL" "$(status)"
assert_contains "a11y-baseline-regression-reason" "REGRESSION" "$(jq -c .reason_codes "$RECEIPT")"
assert_contains "a11y-baseline-regression-listed" "contrast" "$(jq -c '[.regressions[].criterion]' "$RECEIPT")"

# 22. pre-existing violation without a scoped exception → FAIL (cannot hide)
write_plan fixture "" "[]"
run "$(jq -nc '{fail:{"cap-default-desktop":["contrast"]}}')" && cp "$RECEIPT" "$BASELINE"
write_plan fixture "baseline-receipt.json" "[]"
run "$(jq -nc '{fail:{"cap-default-desktop":["contrast"]}}')" || true
assert_eq "a11y-preexisting-no-exception-fail" "FAIL" "$(status)"
assert_contains "a11y-preexisting-reason" "PREEXISTING_VIOLATION" "$(jq -c .reason_codes "$RECEIPT")"

# 23. pre-existing violation with a separately hashed scoped exception → not a veto
EXC=$(jq -nc --arg s "$(sha_text "contrast-exception-scope")" \
  '[{capture_id:"cap-default-desktop",criterion:"contrast",scope_sha256:$s,reason:"legacy brand token, tracked",manual_owner:"design-lead@example.test"}]')
write_plan fixture "baseline-receipt.json" "$EXC"
run "$(jq -nc '{fail:{"cap-default-desktop":["contrast"]}}')" || true
assert_eq "a11y-scoped-exception-not-fail" "EXTERNAL" "$(status)"
assert_eq "a11y-scoped-exception-recorded" "$(sha_text "contrast-exception-scope")" "$(jq -r '.accepted_exceptions[0].scope_sha256' "$RECEIPT")"
assert_contains "a11y-scoped-exception-criterion-recorded" "contrast" "$(jq -c '[.accepted_exceptions[].criterion]' "$RECEIPT")"
assert_contains "a11y-scoped-exception-owner-recorded" "design-lead@example.test" "$(jq -c '[.accepted_exceptions[].manual_owner]' "$RECEIPT")"

# 24. scoped exception cannot cover a MISSING required check
write_plan fixture "baseline-receipt.json" "$EXC"
run "$(jq -nc '{omit:{"cap-default-desktop":["contrast"]}}')" || true
assert_contains "a11y-exception-cannot-hide-missing" "COVERAGE_INCOMPLETE" "$(cat "$STDERR")"

finish
