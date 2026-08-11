#!/usr/bin/env bash
# Focused contract tests for the public taste certificate compiler.
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TASTE="$ROOT/bin/polylane-taste.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-cert.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected $2, got $1"; }
assert_json() { jq -e "$2" "$1" >/dev/null || fail "assertion failed: $2"; }

write_json() {
  local path=$1 json=$2
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$json" >"$path"
}

make_fixture() {
  local n brief judge a b candidate digest
  candidate="cand-new"
  mkdir -p "$WORK/receipts"
  for n in $(seq 1 10); do
    brief="brief-$n"
    digest=$(printf '%064d' "$n")
    write_json "$WORK/receipts/$brief-lock.json" "{\"schema_version\":\"taste-brief/v1\",\"brief_id\":\"$brief\",\"brief_sha256\":\"$digest\",\"target_population\":{\"role\":\"role-$n\"},\"core_task\":{\"id\":\"task-$n\"},\"required_routes\":[\"/r-$n\"],\"required_states\":[\"default\"],\"acceptance_facts_sha256\":\"$digest\",\"rubric_version\":\"taste-rubric/v1\",\"locked_at\":\"2026-08-11T00:00:00Z\"}"
    write_json "$WORK/receipts/$brief-candidate.json" "{\"schema_version\":\"taste-candidate/v1\",\"candidate_id\":\"$candidate\",\"brief_sha256\":\"$digest\",\"design_lock_sha256\":\"$digest\",\"direction_id\":\"d-$n\",\"source_revision\":\"rev-$n\",\"dependency_lock_sha256\":\"$digest\",\"build_receipt_sha256\":\"$digest\",\"created_at\":\"2026-08-11T00:00:00Z\"}"
    write_json "$WORK/receipts/$brief-capture.json" "{\"schema_version\":\"taste-capture-manifest/v1\",\"candidate_id\":\"$candidate\",\"candidate_source_revision\":\"rev-$n\",\"browser\":{\"adapter_receipt_sha256\":\"$digest\",\"command\":\"fixture\",\"version\":\"1\",\"profile_sha256\":\"$digest\"},\"environment\":{\"locale\":\"en-US\",\"timezone\":\"UTC\",\"color_scheme\":\"light\",\"device_scale_factor\":1},\"captures\":[{\"capture_id\":\"cap-$n\",\"route\":\"/r-$n\",\"state\":\"default\",\"action_trace_sha256\":\"$digest\",\"viewport_css_px\":{\"width\":1440,\"height\":900},\"screenshot_png_sha256\":\"$digest\",\"decoded_pixel_sha256\":\"pixel-$n\",\"decoded_width\":1440,\"decoded_height\":900,\"dom_sha256\":\"$digest\",\"captured_at\":\"2026-08-11T00:00:00Z\"}]}"
    write_json "$WORK/receipts/$brief-hard.json" "{\"schema_version\":\"taste-hard-gate/v1\",\"candidate_id\":\"$candidate\",\"capture_manifest_sha256\":\"$digest\",\"task_results\":[{\"task_id\":\"task-$n\",\"capture_id\":\"cap-$n\",\"status\":\"pass\",\"trace_sha256\":\"$digest\"}],\"accessibility\":[{\"capture_id\":\"cap-$n\",\"ruleset\":\"fixture\",\"adapter_receipt_sha256\":\"$digest\",\"status\":\"pass\",\"manual_exception_ids\":[]}],\"state_coverage\":[{\"capture_id\":\"cap-$n\",\"status\":\"pass\"}],\"product_specificity\":{\"signature_test_sha256\":\"$digest\",\"status\":\"pass\"},\"overall\":\"PASS\"}"
    for b in $(seq 1 5); do
      a="machine-$n-$b-a"; b2="machine-$n-$b-b"
      write_json "$WORK/receipts/cal-$a.json" "{\"schema_version\":\"taste-calibration/v1\",\"calibration_set_id\":\"human-ui-calibration/v1\",\"human_label_source\":\"pinned\",\"human_labelled_pairs\":24,\"calibration_manifest_sha256\":\"$digest\",\"judge_id\":\"$a\",\"judge_configuration\":{\"kind\":\"machine\",\"provider\":\"fixture\",\"model\":\"fixture\",\"model_version\":\"1\",\"system_prompt_sha256\":\"$digest\",\"sampling_sha256\":\"$digest\"},\"correct\":17,\"accuracy\":0.708333,\"wilson_lcb_95\":0.50,\"side_probe_n\":12,\"side_probe_exact_binomial_p\":0.05,\"mirror_probe_n\":8,\"mirror_contradictions\":0,\"result\":\"eligible\"}"
      write_json "$WORK/receipts/cal-$b2.json" "$(cat "$WORK/receipts/cal-$a.json" | jq --arg id "$b2" '.judge_id=$id')"
      write_json "$WORK/receipts/$brief-group-$b.json" "{\"schema_version\":\"taste-mirrored-group/v1\",\"mirror_group_id\":\"mg-$n-$b\",\"brief_sha256\":\"$digest\",\"candidate_ids_escrow_sha256\":\"$digest\",\"pointwise_ballot_ids\":[\"pw-$n-$b-a\",\"pw-$n-$b-b\"],\"exposures\":[{\"ballot_id\":\"pair-$n-$b-a\",\"judge_id\":\"$a\",\"display_order\":\"A/B\",\"choice\":\"A\",\"canonical_choice\":\"$candidate\",\"independence_attestation_sha256\":\"$digest\",\"sealed_at\":\"2026-08-11T00:01:00Z\"},{\"ballot_id\":\"pair-$n-$b-b\",\"judge_id\":\"$b2\",\"display_order\":\"B/A\",\"choice\":\"B\",\"canonical_choice\":\"$candidate\",\"independence_attestation_sha256\":\"$digest\",\"sealed_at\":\"2026-08-11T00:01:00Z\"}],\"outcome\":\"resolved-$candidate\"}"
    done
    write_json "$WORK/receipts/$brief-review.json" "{\"schema_version\":\"taste-cross-brief-review/v1\",\"brief_id\":\"$brief\",\"status\":\"resolved\",\"determination\":\"clear\"}"
  done
  write_json "$WORK/receipts/threat.json" '{"schema_version":"taste-threat-receipt/v1","status":"clean","prompt_injection":"clean","receipt_integrity":"clean","provenance":"clean","axis_results":{"genericness_review":"clear","quality_risk":"pass","context_fit":"pass","provenance_integrity":"clear"}}'
  write_json "$WORK/receipts/repair.json" '{"schema_version":"taste-repair-ledger/v1","status":"valid","sha256":"ledger-fixture"}'
  jq -n --arg root "$WORK" --arg candidate "$candidate" '{schema_version:"taste-evidence-manifest/v1",run_id:"fixture-run",protocol_version:"taste-protocol/v1",candidate_id:$candidate,briefs:[range(1;11)|{brief_lock:("receipts/brief-"+tostring+"-lock.json"),candidate:("receipts/brief-"+tostring+"-candidate.json"),capture:("receipts/brief-"+tostring+"-capture.json"),hard_gate:("receipts/brief-"+tostring+"-hard.json"),groups:[range(1;6)|"receipts/brief-"+($root|split("/")|last|if . == "" then "" else "" end)+""]} ]}' >/dev/null
  # The manifest is intentionally an index only; all eligibility and outcomes stay in receipts.
  {
    printf '%s' '{"schema_version":"taste-evidence-manifest/v1","run_id":"fixture-run","protocol_version":"taste-protocol/v1","candidate_id":"cand-new","briefs":['
    for n in $(seq 1 10); do
      [ "$n" -eq 1 ] || printf ','
      printf '{"brief_lock":"receipts/brief-%s-lock.json","candidate":"receipts/brief-%s-candidate.json","capture":"receipts/brief-%s-capture.json","hard_gate":"receipts/brief-%s-hard.json","groups":[' "$n" "$n" "$n" "$n"
      for b in $(seq 1 5); do [ "$b" -eq 1 ] || printf ','; printf '"receipts/brief-%s-group-%s.json"' "$n" "$b"; done
      printf '],"review":"receipts/brief-%s-review.json"}' "$n"
    done
    printf '],"calibrations":['
    first=1; for n in $(seq 1 10); do for b in $(seq 1 5); do for side in a b; do [ "$first" = 1 ] || printf ','; first=0; printf '"receipts/cal-machine-%s-%s-%s.json"' "$n" "$b" "$side"; done; done; done
    printf '],"threat_report":"receipts/threat.json","repair_ledger":"receipts/repair.json"}\n'
  } >"$WORK/manifest.json"
}

make_fixture
"$TASTE" certify "$WORK/manifest.json" "$WORK/certificate.json"
assert_json "$WORK/certificate.json" '.status == "TASTE-CERTIFIED" and .human_calibrated == true and .human_certified == false'
assert_eq "$(jq -r '.briefs' "$WORK/certificate.json")" 10
assert_eq "$(jq -r '.brief_wins' "$WORK/certificate.json")" 10

# Each broken floor must write a valid honest failure certificate and return nonzero.
expect_blocked() {
  local name=$1 manifest=$2 cert
  cert="$WORK/$name.json"
  printf 'prior-not-a-certificate' >"$cert"
  if "$TASTE" certify "$manifest" "$cert"; then fail "$name unexpectedly certified"; fi
  assert_json "$cert" '.status == "NOT-CERTIFIED" and (.verdict_reason_codes | length > 0)'
  [ -z "$(find "$WORK" -name "$name.json.tmp.*" -print -quit)" ] || fail "$name left a partial certificate"
}

# Caller-owned status and score fields are not evidence and invalidate the index.
jq '.status="TASTE-CERTIFIED" | .briefs[0].score=1' "$WORK/manifest.json" >"$WORK/manifest-status.json"; expect_blocked caller-status "$WORK/manifest-status.json"

jq '.briefs = .briefs[0:9]' "$WORK/manifest.json" >"$WORK/few-briefs.json"; expect_blocked few-briefs "$WORK/few-briefs.json"
jq '.briefs[0].groups = .briefs[0].groups[0:4]' "$WORK/manifest.json" >"$WORK/few-groups.json"; expect_blocked few-groups "$WORK/few-groups.json"
jq 'del(.calibrations[0])' "$WORK/manifest.json" >"$WORK/missing-calibration.json"; expect_blocked missing-calibration "$WORK/missing-calibration.json"
jq '.briefs[0].hard_gate = "receipts/missing.json"' "$WORK/manifest.json" >"$WORK/missing-hard-gate.json"; expect_blocked missing-hard-gate "$WORK/missing-hard-gate.json"
jq '.threat_report = "receipts/missing-threat.json"' "$WORK/manifest.json" >"$WORK/missing-threat.json"; expect_blocked missing-threat "$WORK/missing-threat.json"

printf 'PASS: taste certification compiler\n'
