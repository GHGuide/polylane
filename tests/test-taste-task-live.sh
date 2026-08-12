#!/usr/bin/env bash
# test-taste-task-live.sh — adversarial acceptance for the functional-task hard
# gate. The gate consumes a verified capture manifest + a coordinator-pinned task
# plan, invokes a pinned browser task adapter, and recomputes PASS/FAIL/EXTERNAL
# from exact replayed traces. The success ORACLE lives in the plan; the adapter
# reports only OBSERVED measured evidence; the validator DERIVES every verdict.
# Caller-authored pass, missing/skipped coverage, unsafe or non-deterministic
# traces, and a generic (non-brief-specific) product signature can never
# authorize a PASS.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

TASK="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-taste-task.sh"
SCHEMA="$(cd "$(dirname "$0")/.." && pwd)/benchmarks/taste-live/task-schema.json"
task() { bash "$TASK" "$@"; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
sha_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }
canon_sha() { sha_text "$(printf '%s' "$1" | jq -cS .)"; }

make_tmpdir
ROOT="$TEST_TMPDIR/project"
mkdir -p "$ROOT/evidence" "$ROOT/tools"
git -C "$ROOT" init -q
git -C "$ROOT" config user.email task@example.test
git -C "$ROOT" config user.name task
printf 'source revision\n' > "$ROOT/app.txt"
git -C "$ROOT" add app.txt
git -C "$ROOT" commit -qm source
REVISION=$(git -C "$ROOT" rev-parse HEAD)
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
export POLYLANE_TASK_NOW="$NOW"

# --- content that is content-addressed by the manifest -----------------------
DOM_EMPTY=$(sha_text "dom-empty-state")
DOM_POP=$(sha_text "dom-populated-state")
TRACE_EMPTY='[{"type":"navigate","route":"/"},{"type":"wait_for","selector":"[data-testid=empty-cta]"}]'
TRACE_POP='[{"type":"navigate","route":"/"},{"type":"fill","selector":"input[name=item]","value":"Milk"},{"type":"click","selector":"[data-testid=add-btn]"},{"type":"wait_for","selector":"[data-testid=item-row]"}]'
PIN_EMPTY=$(canon_sha "$TRACE_EMPTY")
PIN_POP=$(canon_sha "$TRACE_POP")
PROFILE_SHA=$(sha_text "task-replay-profile-v1")

# --- pinned browser task adapter (fixture) -----------------------------------
# A real adapter drives a browser and measures the live DOM. This fixture reads a
# test-authored world (TASK_FIXTURE) — the replayed traces + observed measured
# evidence — echoes the request identity, and emits result.json + a bound
# receipt.json. Environment knobs inject each attack so the trust boundary can be
# probed without a browser. It authors NO verdict: measured evidence only.
cat > "$ROOT/tools/task-adapter" <<'PY'
#!/usr/bin/env python3
import copy, hashlib, json, os, sys, time
req = json.load(open(os.environ["POLYLANE_TASK_REQUEST"]))
out = os.environ["POLYLANE_TASK_OUTPUT"]
world = json.load(open(os.environ["TASK_FIXTURE"]))
sleep = float(os.environ.get("TASK_SLEEP", "0"))
if sleep:
    time.sleep(sleep)

captures = copy.deepcopy(world["captures"])
signature = copy.deepcopy(world["signature"])

def find_cap(cid):
    return next(c for c in captures if c["capture_id"] == cid)

# --- attack injections -------------------------------------------------------
if os.environ.get("TASK_DROP_TASK"):
    tid = os.environ["TASK_DROP_TASK"]
    for c in captures:
        c["tasks"] = [t for t in c["tasks"] if t["task_id"] != tid]
    captures = [c for c in captures if c["tasks"]]
if os.environ.get("TASK_DROP_ASSERT"):
    cid, tid, aid = os.environ["TASK_DROP_ASSERT"].split("|")
    for t in find_cap(cid)["tasks"]:
        if t["task_id"] == tid:
            t["assertions"] = [a for a in t["assertions"] if a["assertion_id"] != aid]
if os.environ.get("TASK_WRONG_VALUE"):
    # break the text_present oracle: observed text no longer contains expected
    for c in captures:
        for t in c["tasks"]:
            for a in t["assertions"]:
                if a["assertion_id"] == "assert-title-present":
                    a["measured"]["text"] = "Untitled"
if os.environ.get("TASK_AMBIGUOUS"):
    # count expected 1 but two rows matched -> derived fail
    for c in captures:
        for t in c["tasks"]:
            for a in t["assertions"]:
                if a["assertion_id"] == "assert-row-count":
                    a["measured"]["match_count"] = 2
if os.environ.get("TASK_STALE_DOM"):
    for c in captures:
        for t in c["tasks"]:
            for a in t["assertions"]:
                a["measured"]["dom_sha256"] = "f" * 64
if os.environ.get("TASK_WRONG_STATE"):
    # the sole reacher of "empty" now claims "populated" -> "empty" uncovered
    for t in find_cap("cap-empty")["tasks"]:
        if t["task_id"] == "task-empty-state":
            t["reaches_state"] = "populated"
if os.environ.get("TASK_ARBITRARY"):
    find_cap("cap-populated")["action_trace"].append({"type": "eval", "value": "fetch('/steal')"})
if os.environ.get("TASK_NETWORK"):
    find_cap("cap-populated")["action_trace"][0] = {"type": "navigate", "route": "https://evil.example/x"}
if os.environ.get("TASK_UNSAFE_SELECTOR"):
    find_cap("cap-populated")["tasks"][0]["assertions"][0]["selector"] = "img onerror=<script>"
if os.environ.get("TASK_NONDET"):
    # a safe extra action -> canonical hash no longer reproduces the pinned digest
    find_cap("cap-populated")["action_trace"].append({"type": "click", "selector": "[data-testid=extra]"})
if os.environ.get("TASK_FORGE_DOM"):
    find_cap("cap-populated")["dom_sha256"] = "a" * 64
if os.environ.get("TASK_TAMPER_SELECTOR"):
    # swap an assertion selector to an easier one the plan never pinned
    find_cap("cap-populated")["tasks"][0]["assertions"][0]["selector"] = "body"
if os.environ.get("TASK_SIG_GENERIC"):
    signature["counterfactual"]["measured"]["match_count"] = 1
if os.environ.get("TASK_SIG_UNPROVEN"):
    for c in captures:
        for t in c["tasks"]:
            for a in t["assertions"]:
                if a["assertion_id"] == "assert-title-present":
                    a["measured"]["text"] = "nothing here"

result = {
    "schema_version": "taste-task-adapter-result/v1",
    "adapter_id": req["adapter"]["adapter_id"],
    "adapter_version": req["adapter"]["adapter_version"],
    "profile_sha256": req["adapter"]["profile_sha256"],
    "evidence_class": os.environ.get("TASK_RELABEL", req["evidence_class"]),
    "captures": captures,
    "signature": signature,
}
if os.environ.get("TASK_CALLER_PASS"):
    result["captures"][0]["tasks"][0]["assertions"][0]["measured"]["status"] = "pass"

rp = os.path.join(out, "result.json")
open(rp, "w").write(json.dumps(result, sort_keys=True))
result_bytes = open(rp, "rb").read()
req_bytes = open(os.environ["POLYLANE_TASK_REQUEST"], "rb").read()
command_sha = hashlib.sha256(open(sys.argv[0], "rb").read()).hexdigest()
receipt = {
    "schema_version": "taste-adapter-receipt/v1",
    "adapter_id": req["adapter"]["adapter_id"],
    "adapter_version": req["adapter"]["adapter_version"],
    "command_sha256": command_sha,
    "input_sha256": [hashlib.sha256(req_bytes).hexdigest()] + [c["dom_sha256"] for c in req["captures"]],
    "output_sha256": [hashlib.sha256(result_bytes).hexdigest()],
    "exit_status": 0,
    "executed_at": os.environ.get("TASK_EXECUTED", os.environ["TASK_NOW_ENV"]),
}
open(os.path.join(out, "receipt.json"), "w").write(json.dumps(receipt, sort_keys=True))
PY
chmod +x "$ROOT/tools/task-adapter"
ADAPTER_SHA=$(sha "$ROOT/tools/task-adapter")
export TASK_NOW_ENV="$NOW"

MANIFEST="$ROOT/evidence/captures.json"
PLAN="$ROOT/evidence/task-plan.json"
RECEIPT="$ROOT/evidence/task-receipt.json"
FIXTURE="$ROOT/evidence/world.json"
export TASK_FIXTURE="$FIXTURE"

write_manifest() {
  jq -n --arg rev "$REVISION" --arg de "$DOM_EMPTY" --arg dp "$DOM_POP" \
    --arg pe "$PIN_EMPTY" --arg pp "$PIN_POP" --arg now "$NOW" '
    {schema_version:"taste-capture-manifest/v1",candidate_id:"cand-grocery-a",candidate_source_revision:$rev,
     required_routes:["/"],required_states:["empty","populated"],mobile_only_states:[],
     browser:{adapter_id:"browser-capture",adapter_receipt_path:"browser-receipt.json"},
     decoder:{adapter_id:"png-decoder",adapter_version:"fixture-v1",command_path:"tools/decode-png",command_sha256:("d"*64)},
     captures:[
       {capture_id:"cap-empty",route:"/",state:"empty",viewport:"desktop",dom_sha256:$de,action_trace_sha256:$pe},
       {capture_id:"cap-populated",route:"/",state:"populated",viewport:"desktop",dom_sha256:$dp,action_trace_sha256:$pp}
     ]}' > "$MANIFEST"
}

# write_plan MANUAL_JSON BASELINE_PATH EVIDENCE_CLASS
write_plan() {
  jq -n --arg rev "$REVISION" --arg cmd "$ADAPTER_SHA" --arg prof "$PROFILE_SHA" \
    --argjson manual "${1:-[]}" --arg baseline "${2:-}" --arg cls "${3:-fixture}" '
    {schema_version:"taste-task-plan/v1",candidate_id:"cand-grocery-a",source_revision:$rev,
     brief_sha256:("b"*64),design_lock_sha256:("e"*64),evidence_class:$cls,baseline_receipt_path:$baseline,
     adapter:{adapter_id:"task-replay",adapter_version:"fixture-v1",command_path:"tools/task-adapter",command_sha256:$cmd,profile_sha256:$prof},
     required_states:["empty","populated"],
     tasks:[
       {task_id:"task-empty-state",brief_clause:"An empty list shows a call to action",reaches_state:"empty",
        assertions:[{assertion_id:"assert-empty-cta",kind:"exists",selector:"[data-testid=empty-cta]",expected:null}]},
       {task_id:"task-add-item",brief_clause:"Users can add an item to the list",reaches_state:"populated",
        assertions:[
          {assertion_id:"assert-row-count",kind:"count",selector:"[data-testid=item-row]",expected:1},
          {assertion_id:"assert-add-visible",kind:"exists",selector:"[data-testid=add-btn]",expected:null}]},
       {task_id:"task-title",brief_clause:"The header shows the grocery list name",reaches_state:"populated",
        assertions:[{assertion_id:"assert-title-present",kind:"text_present",selector:"h1",expected:"Grocery List"}]}
     ],
     product_signature:{mechanism:"add-to-list-appends-row-and-titles-count",
       clause_trace:["Users can add an item to the list"],
       rendered_anchor:{capture_id:"cap-populated",task_id:"task-title",assertion_id:"assert-title-present"},
       task_proof:["task-add-item"],
       counterfactual:{unrelated_brief_id:"brief-flight-booker",selector:"[data-testid=flight-search]"}},
     manual_external_tasks:$manual}' > "$PLAN"
}

write_fixture() {
  jq -n --arg de "$DOM_EMPTY" --arg dp "$DOM_POP" \
    --argjson te "$TRACE_EMPTY" --argjson tp "$TRACE_POP" --arg pe "$PIN_EMPTY" --arg pp "$PIN_POP" '
    {captures:[
       {capture_id:"cap-empty",dom_sha256:$de,action_trace_sha256:$pe,action_trace:$te,
        tasks:[{task_id:"task-empty-state",reaches_state:"empty",
          assertions:[{assertion_id:"assert-empty-cta",kind:"exists",selector:"[data-testid=empty-cta]",measured:{dom_sha256:$de,match_count:1}}]}]},
       {capture_id:"cap-populated",dom_sha256:$dp,action_trace_sha256:$pp,action_trace:$tp,
        tasks:[
          {task_id:"task-add-item",reaches_state:"populated",
           assertions:[
             {assertion_id:"assert-row-count",kind:"count",selector:"[data-testid=item-row]",measured:{dom_sha256:$dp,match_count:1}},
             {assertion_id:"assert-add-visible",kind:"exists",selector:"[data-testid=add-btn]",measured:{dom_sha256:$dp,match_count:1}}]},
          {task_id:"task-title",reaches_state:"populated",
           assertions:[{assertion_id:"assert-title-present",kind:"text_present",selector:"h1",measured:{dom_sha256:$dp,text:"Grocery List — 1 item"}}]}]}
     ],
     signature:{anchor:{capture_id:"cap-populated",task_id:"task-title",assertion_id:"assert-title-present"},
       counterfactual:{selector:"[data-testid=flight-search]",measured:{dom_sha256:$dp,match_count:0}}}}' > "$FIXTURE"
}

STDERR="$ROOT/evidence/stderr.txt"
run() {  # extra KEY=VAL env pairs passed as args
  rm -f "$RECEIPT"
  local rc=0
  env "$@" bash "$TASK" gate "$ROOT" "$MANIFEST" "$PLAN" "$RECEIPT" -- "$ROOT/tools/task-adapter" 2>"$STDERR" || rc=$?
  return $rc
}
status() { jq -r '.derived_status' "$RECEIPT" 2>/dev/null; }
has_receipt() { [ -f "$RECEIPT" ] && echo true || echo false; }

write_manifest; write_plan; write_fixture

# === allowlist ⇄ schema non-drift (deterministic oracle, not prose) ==========
SCHEMA_ACTIONS=$(jq -r '.allowlists.actions | join(" ")' "$SCHEMA")
SCHEMA_ASSERTS=$(jq -r '.allowlists.assertions | join(" ")' "$SCHEMA")
CODE_ACTIONS=$(grep '^ALLOWED_ACTIONS=' "$TASK" | sed 's/.*="//;s/"$//')
CODE_ASSERTS=$(grep '^ALLOWED_ASSERTIONS=' "$TASK" | sed 's/.*="//;s/"$//')
assert_eq "schema-actions-match-code" "$SCHEMA_ACTIONS" "$CODE_ACTIONS"
assert_eq "schema-assertions-match-code" "$SCHEMA_ASSERTS" "$CODE_ASSERTS"
assert_ok "task-schema-valid-json" jq -e . "$SCHEMA"

# === 1. positive: every task/state/assertion resolves, signature proven → PASS
rc=0; run || rc=$?
assert_eq "positive-rc0" 0 "$rc"
assert_eq "positive-derived-pass" "PASS" "$(status)"
assert_contains "positive-reason-clean" "CLEAN" "$(jq -c .reason_codes "$RECEIPT")"
assert_eq "positive-classification-fixture" "fixture" "$(jq -r .classification "$RECEIPT")"
assert_eq "positive-not-human-certified" "false" "$(jq -r .human_certified "$RECEIPT")"
assert_eq "positive-mechanism-proven" "true" "$(jq -r .product_signature.mechanism_proven "$RECEIPT")"
assert_eq "positive-counterfactual-absent" "true" "$(jq -r .product_signature.counterfactual_absent "$RECEIPT")"
assert_eq "positive-binds-brief" "$(printf b%.0s $(seq 64))" "$(jq -r .brief_sha256 "$RECEIPT")"
assert_eq "positive-binds-design-lock" "$(printf e%.0s $(seq 64))" "$(jq -r .design_lock_sha256 "$RECEIPT")"
assert_eq "positive-no-caller-pass-key" "false" "$(jq 'has("pass")' "$RECEIPT")"

# === 2. determinism: identical inputs → byte-identical receipt ================
cp "$RECEIPT" "$ROOT/evidence/receipt-a.json"
run || true
assert_eq "deterministic-replay-identical" \
  "$(sha "$ROOT/evidence/receipt-a.json")" "$(sha "$RECEIPT")"

# === 3. manual external task present → EXTERNAL (never auto-passed) ===========
write_plan '["task-empty-state"]'
run || true
assert_eq "manual-external-derived" "EXTERNAL" "$(status)"
assert_contains "manual-external-reason" "MANUAL_EXTERNAL" "$(jq -c .reason_codes "$RECEIPT")"
write_plan

# === ATTACK MATRIX ===========================================================
# valid task plus missing action/state (task omitted from result) → reject
run TASK_DROP_TASK=task-add-item || true
assert_contains "missing-task-rejected" "MISSING_TASK" "$(cat "$STDERR")"
assert_eq "missing-task-no-receipt" "false" "$(has_receipt)"

# missing required state (its task reaches a different state) → reject
run TASK_WRONG_STATE=1 || true
assert_contains "missing-state-rejected" "MISSING_STATE" "$(cat "$STDERR")"

# selector ambiguity — unique/count oracle matched 2 nodes → derived FAIL
run TASK_AMBIGUOUS=1 || true
assert_eq "ambiguous-selector-derived-fail" "FAIL" "$(status)"
assert_contains "ambiguous-selector-reason" "ASSERTION_FAILED" "$(jq -c .reason_codes "$RECEIPT")"
assert_contains "ambiguous-selector-evidence" '"match_count":2' "$(jq -c '.failed_assertions[0].measured' "$RECEIPT")"

# wrong value — text oracle no longer satisfied → derived FAIL
run TASK_WRONG_VALUE=1 || true
assert_eq "wrong-value-derived-fail" "FAIL" "$(status)"
assert_contains "wrong-value-reason" "ASSERTION_FAILED" "$(jq -c .reason_codes "$RECEIPT")"

# stale DOM — measured evidence not bound to the pinned render → reject
run TASK_STALE_DOM=1 || true
assert_contains "stale-dom-rejected" "STALE_DOM" "$(cat "$STDERR")"
assert_eq "stale-dom-no-receipt" "false" "$(has_receipt)"

# skipped assertion — required assertion omitted from a present task → reject
run TASK_DROP_ASSERT="cap-populated|task-add-item|assert-row-count" || true
assert_contains "skipped-assertion-rejected" "COVERAGE_INCOMPLETE" "$(cat "$STDERR")"

# caller pass — adapter injects a status field → reject
run TASK_CALLER_PASS=1 || true
assert_contains "caller-pass-rejected" "CALLER_PASS" "$(cat "$STDERR")"
assert_eq "caller-pass-no-receipt" "false" "$(has_receipt)"

# arbitrary script — non-allowlisted action type → reject
run TASK_ARBITRARY=1 || true
assert_contains "arbitrary-action-rejected" "ARBITRARY_ACTION" "$(cat "$STDERR")"

# network — navigate to an absolute/external target → reject
run TASK_NETWORK=1 || true
assert_contains "network-action-rejected" "NETWORK_ACTION" "$(cat "$STDERR")"

# unsafe selector — injection-shaped selector → reject
run TASK_UNSAFE_SELECTOR=1 || true
assert_contains "unsafe-selector-rejected" "UNSAFE_SELECTOR" "$(cat "$STDERR")"

# selector tamper — assertion selector swapped away from the pinned oracle → reject
run TASK_TAMPER_SELECTOR=1 || true
assert_contains "tamper-selector-rejected" "ASSERTION_TAMPERED" "$(cat "$STDERR")"

# timeout — adapter exceeds the bound → reject, no receipt
run TASK_SLEEP=3 POLYLANE_TASK_TIMEOUT=1 || true
assert_contains "timeout-rejected" "ADAPTER_TIMEOUT" "$(cat "$STDERR")"
assert_eq "timeout-no-receipt" "false" "$(has_receipt)"

# nondeterminism — trace bytes no longer reproduce the pinned digest → reject
run TASK_NONDET=1 || true
assert_contains "nondeterministic-rejected" "NONDETERMINISTIC" "$(cat "$STDERR")"

# forged capture — echoed DOM digest ≠ manifest pin → reject
run TASK_FORGE_DOM=1 || true
assert_contains "forged-capture-rejected" "FORGED_CAPTURE" "$(cat "$STDERR")"

# signature counterfactual — unrelated-brief marker PRESENT → generic → FAIL veto
run TASK_SIG_GENERIC=1 || true
assert_eq "signature-generic-derived-fail" "FAIL" "$(status)"
assert_contains "signature-generic-reason" "SIGNATURE_GENERIC" "$(jq -c .reason_codes "$RECEIPT")"
assert_eq "signature-generic-flag" "false" "$(jq -r .product_signature.counterfactual_absent "$RECEIPT")"

# signature unproven — anchor mechanism assertion fails in trace → FAIL veto
run TASK_SIG_UNPROVEN=1 || true
assert_eq "signature-unproven-derived-fail" "FAIL" "$(status)"
assert_contains "signature-unproven-reason" "SIGNATURE_UNPROVEN" "$(jq -c .reason_codes "$RECEIPT")"

# fixture→production relabel → reject
run TASK_RELABEL=production || true
assert_contains "relabel-rejected" "FIXTURE_RELABELED" "$(cat "$STDERR")"

# stale adapter receipt (executed before source) → reject
run TASK_EXECUTED="2000-01-01T00:00:00Z" || true
assert_contains "stale-receipt-rejected" "STALE_RECEIPT" "$(cat "$STDERR")"

# forged adapter — file mutated after the plan pin → reject
printf '# tamper\n' >> "$ROOT/tools/task-adapter"
run || true
assert_contains "forged-adapter-rejected" "ADAPTER_MISMATCH" "$(cat "$STDERR")"
sed -i.bak '/^# tamper$/d' "$ROOT/tools/task-adapter" && rm -f "$ROOT/tools/task-adapter.bak"
[ "$(sha "$ROOT/tools/task-adapter")" = "$ADAPTER_SHA" ] || echo "adapter restore failed" >&2

# stale source revision (manifest rev no longer HEAD) → reject
jq '.candidate_source_revision="0000000000000000000000000000000000000000"' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
run || true
assert_contains "stale-source-rejected" "STALE_SOURCE_REVISION" "$(cat "$STDERR")"
write_manifest

# candidate mismatch between manifest and plan → reject
jq '.candidate_id="cand-other"' "$PLAN" > "$PLAN.tmp" && mv "$PLAN.tmp" "$PLAN"
run || true
assert_contains "candidate-mismatch-rejected" "CANDIDATE_MISMATCH" "$(cat "$STDERR")"
write_plan

# signature counterfactual restored → PASS again (regression guard) ===========
run || true
assert_eq "post-attack-restored-pass" "PASS" "$(status)"

finish
