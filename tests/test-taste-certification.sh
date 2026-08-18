#!/usr/bin/env bash
# Contract tests for the taste certificate compiler.
# v1 `certify` stays available but is fixture-marked; the production path is the
# taste-evidence-manifest/v2 compiler, exercised here against a hermetic,
# hash-closed validator chain plus one adversarial mutation per trust boundary.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TASTE="$ROOT/bin/polylane-taste.sh"
CALIBRATE="$ROOT/bin/polylane-taste-calibrate.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-cert.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected $2, got $1 ($3)"; }
assert_json() { jq -e "$2" "$1" >/dev/null || fail "assertion failed on $1: $2"; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
sha_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

write_json() {
  local path=$1 json=$2
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$json" >"$path"
}

jqi() { # in-place jq edit
  local file=$1; shift
  jq "$@" "$file" >"$file.jqi" && mv "$file.jqi" "$file"
}

ALT_REVISION="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
ZERO64=$(printf '%064d' 0)

# ---------------------------------------------------------------------------
# v1 compatibility: still compiles, but the certificate is fixture-marked so a
# current runner gate can never accept shape-only v1 evidence as production.
# ---------------------------------------------------------------------------
make_v1_fixture() {
  local dir=$1 n b a b2 digest candidate=cand-new
  mkdir -p "$dir/receipts"
  for n in $(seq 1 10); do
    digest=$(printf '%064d' "$n")
    write_json "$dir/receipts/brief-$n-lock.json" "{\"schema_version\":\"taste-brief/v1\",\"brief_id\":\"brief-$n\",\"brief_sha256\":\"$digest\",\"target_population\":{\"role\":\"role-$n\"},\"core_task\":{\"id\":\"task-$n\"},\"required_routes\":[\"/r-$n\"],\"required_states\":[\"default\"],\"acceptance_facts_sha256\":\"$digest\",\"rubric_version\":\"taste-rubric/v1\",\"locked_at\":\"2026-08-11T00:00:00Z\"}"
    write_json "$dir/receipts/brief-$n-candidate.json" "{\"schema_version\":\"taste-candidate/v1\",\"candidate_id\":\"$candidate\",\"brief_sha256\":\"$digest\",\"design_lock_sha256\":\"$digest\",\"direction_id\":\"d-$n\",\"source_revision\":\"$digest\",\"dependency_lock_sha256\":\"$digest\",\"build_receipt_sha256\":\"$digest\",\"created_at\":\"2026-08-11T00:00:00Z\"}"
    write_json "$dir/receipts/brief-$n-capture.json" "{\"schema_version\":\"taste-capture-manifest/v1\",\"candidate_id\":\"$candidate\",\"candidate_source_revision\":\"$digest\",\"browser\":{\"adapter_id\":\"browser-capture\",\"adapter_receipt_path\":\"fixture\"},\"decoder\":{\"adapter_id\":\"png-decoder\",\"adapter_version\":\"fixture\",\"command_path\":\"fixture\",\"command_sha256\":\"$digest\"},\"required_routes\":[\"/r-$n\"],\"required_states\":[\"default\"],\"mobile_only_states\":[],\"captures\":[{\"capture_id\":\"cap-$n\",\"route\":\"/r-$n\",\"state\":\"default\",\"viewport\":\"desktop\",\"action_trace_sha256\":\"$digest\",\"viewport_css_px\":{\"width\":1440,\"height\":900},\"screenshot_path\":\"fixture\",\"screenshot_png_sha256\":\"$digest\",\"decoded_pixel_sha256\":\"$digest\",\"decoded_width\":1440,\"decoded_height\":900,\"dom_sha256\":\"$digest\",\"captured_at\":\"2026-08-11T00:00:00Z\"}]}"
    write_json "$dir/receipts/brief-$n-hard.json" "{\"schema_version\":\"taste-hard-gate/v1\",\"candidate_id\":\"$candidate\",\"capture_manifest_sha256\":\"$digest\",\"task_results\":[{\"task_id\":\"task-$n\",\"capture_id\":\"cap-$n\",\"status\":\"pass\",\"trace_sha256\":\"$digest\"}],\"accessibility\":[{\"capture_id\":\"cap-$n\",\"ruleset\":\"fixture\",\"adapter_receipt_sha256\":\"$digest\",\"status\":\"pass\",\"manual_exception_ids\":[]}],\"state_coverage\":[{\"capture_id\":\"cap-$n\",\"status\":\"pass\"}],\"product_specificity\":{\"signature_test_sha256\":\"$digest\",\"status\":\"pass\"},\"overall\":\"PASS\"}"
    for b in $(seq 1 5); do
      a="machine-$n-$b-a"; b2="machine-$n-$b-b"
      write_json "$dir/receipts/cal-$a.json" "{\"schema_version\":\"taste-calibration/v1\",\"calibration_set_id\":\"human-ui-calibration/v1\",\"human_label_source\":\"pinned\",\"human_labelled_pairs\":24,\"calibration_manifest_sha256\":\"$digest\",\"judge_id\":\"$a\",\"judge\":{\"id\":\"$a\",\"provider\":\"fixture\",\"model\":\"fixture\"},\"judge_configuration\":{\"kind\":\"machine\",\"provider\":\"fixture\",\"model\":\"fixture\",\"model_version\":\"1\",\"system_prompt_sha256\":\"$digest\",\"sampling_sha256\":\"$digest\"},\"correct\":17,\"accuracy\":0.708333,\"wilson_lcb_95\":0.50,\"side_probe_n\":12,\"side_probe_exact_binomial_p\":0.05,\"mirror_probe_n\":8,\"mirror_contradictions\":0,\"result\":\"eligible\"}"
      jq --arg id "$b2" '.judge_id=$id | .judge.id=$id' "$dir/receipts/cal-$a.json" >"$dir/receipts/cal-$b2.json"
      write_json "$dir/receipts/brief-$n-group-$b.json" "{\"schema_version\":\"taste-mirrored-group/v1\",\"mirror_group_id\":\"mg-$n-$b\",\"brief_sha256\":\"$digest\",\"candidate_ids_escrow_sha256\":\"$digest\",\"pointwise_ballot_ids\":[\"pw-$n-$b-a\",\"pw-$n-$b-b\"],\"exposures\":[{\"ballot_id\":\"pair-$n-$b-a\",\"judge_id\":\"$a\",\"display_order\":\"A/B\",\"choice\":\"A\",\"canonical_choice\":\"$candidate\",\"independence_attestation_sha256\":\"$digest\",\"sealed_at\":\"2026-08-11T00:01:00Z\"},{\"ballot_id\":\"pair-$n-$b-b\",\"judge_id\":\"$b2\",\"display_order\":\"B/A\",\"choice\":\"B\",\"canonical_choice\":\"$candidate\",\"independence_attestation_sha256\":\"$digest\",\"sealed_at\":\"2026-08-11T00:01:00Z\"}],\"outcome\":\"resolved-$candidate\"}"
    done
    write_json "$dir/receipts/brief-$n-review.json" "{\"schema_version\":\"taste-cross-brief-review/v1\",\"brief_id\":\"brief-$n\",\"status\":\"resolved\",\"determination\":\"clear\"}"
  done
  write_json "$dir/receipts/threat.json" '{"schema_version":"taste-threat-receipt/v1","status":"clean","axis_results":{"genericness_review":"pass","quality_risk":"pass","context_fit":"pass","provenance_integrity":"pass"},"review":{"status":"not-required","scope":null,"attribution_claim":false},"reason_codes":[]}'
  write_json "$dir/receipts/repair.json" '{"schema_version":"taste-repair-ledger/v1","status":"valid","sha256":"ledger-fixture"}'
  {
    printf '%s' '{"schema_version":"taste-evidence-manifest/v1","run_id":"fixture-run","protocol_version":"taste-protocol/v1","candidate_id":"cand-new","briefs":['
    for n in $(seq 1 10); do
      [ "$n" -eq 1 ] || printf ','
      printf '{"brief_lock":"receipts/brief-%s-lock.json","candidate":"receipts/brief-%s-candidate.json","capture":"receipts/brief-%s-capture.json","hard_gate":"receipts/brief-%s-hard.json","groups":[' "$n" "$n" "$n" "$n"
      for b in $(seq 1 5); do [ "$b" -eq 1 ] || printf ','; printf '"receipts/brief-%s-group-%s.json"' "$n" "$b"; done
      printf '],"review":"receipts/brief-%s-review.json"}' "$n"
    done
    printf '],"calibrations":['
    local first=1 side
    for n in $(seq 1 10); do for b in $(seq 1 5); do for side in a b; do [ "$first" = 1 ] || printf ','; first=0; printf '"receipts/cal-machine-%s-%s-%s.json"' "$n" "$b" "$side"; done; done; done
    printf '],"threat_report":"receipts/threat.json","repair_ledger":"receipts/repair.json"}\n'
  } >"$dir/manifest.json"
}

V1DIR="$WORK/v1"
make_v1_fixture "$V1DIR"
"$TASTE" certify "$V1DIR/manifest.json" "$V1DIR/certificate.json"
assert_json "$V1DIR/certificate.json" '.schema_version == "taste-certificate/v1" and .status == "TASTE-CERTIFIED"'
# v1 output is explicitly fixture/non-production evidence.
assert_json "$V1DIR/certificate.json" '.fixture_only == true and .production == false'

jq '.status="TASTE-CERTIFIED" | .briefs[0].score=1' "$V1DIR/manifest.json" >"$WORK/v1-caller-status.json"
if "$TASTE" certify "$WORK/v1-caller-status.json" "$WORK/v1-caller-cert.json"; then fail "v1 caller status certified"; fi
assert_json "$WORK/v1-caller-cert.json" '.status == "NOT-CERTIFIED" and .fixture_only == true'
sed 's/"run_id":"fixture-run"/"run_id":"fixture-run","run_id":"replayed"/' "$V1DIR/manifest.json" >"$WORK/v1-dup.json"
if "$TASTE" certify "$WORK/v1-dup.json" "$WORK/v1-dup-cert.json"; then fail "v1 duplicate key certified"; fi

# ---------------------------------------------------------------------------
# v2 hermetic chain builder.
# Every referenced artifact exists on disk with a recomputed SHA-256; every
# validator receipt is hash-bound to its raw input.  Calibration receipts are
# cloned from receipts genuinely produced by bin/polylane-taste-calibrate.sh.
# ---------------------------------------------------------------------------
REPO="$WORK/repo"
mkdir -p "$REPO/src"
git -c init.defaultBranch=main init -q "$REPO"
printf 'subject source\n' >"$REPO/src/app.txt"
git -C "$REPO" add src/app.txt
git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm subject
SUBJECT=$(git -C "$REPO" rev-parse HEAD)
mkdir -p "$REPO/docs"
printf 'evidence commit\n' >"$REPO/docs/status-taste.md"
git -C "$REPO" add docs/status-taste.md
git -C "$REPO" -c user.email=t@t -c user.name=t commit -qm evidence

# A sibling repo with an undeclared source commit after the subject revision.
REPO_DRIFT="$WORK/repo-drift"
cp -R "$REPO" "$REPO_DRIFT"
printf 'undeclared drift\n' >>"$REPO_DRIFT/src/app.txt"
git -C "$REPO_DRIFT" add src/app.txt
git -C "$REPO_DRIFT" -c user.email=t@t -c user.name=t commit -qm drift

# An unrelated repo that does not contain the subject revision at all.
REPO_ALIEN="$WORK/repo-alien"
mkdir -p "$REPO_ALIEN"
git -c init.defaultBranch=main init -q "$REPO_ALIEN"
printf 'alien\n' >"$REPO_ALIEN/alien.txt"
git -C "$REPO_ALIEN" add alien.txt
git -C "$REPO_ALIEN" -c user.email=t@t -c user.name=t commit -qm alien

GOAL_SHA=$(sha_text "literal goal: current-subject taste promotion")
DESIGN_SHA=$(sha_text "design lock v2")
ESCROW_SHA=$(sha_text "candidate escrow")
ATTEST_SHA=$(sha_text "independence attestation")

CAL_TPL_A="$WORK/cal-template-a.json"
CAL_TPL_B="$WORK/cal-template-b.json"

cal_units() { # model -> canonical 24-unit held-out array
  jq -nc --arg m "$1" '[range(0;24) | . as $u | (if $u % 2 == 0 then 1 else 2 end) as $g |
    {prompt: ("p-" + ($u|tostring)), brief: ("b-" + ($u|tostring)), gold_vote: $g,
     primary: {provider: "fixture-provider", model: $m, vote: $g, request: {prompt: ("p-" + ($u|tostring)), brief: ("b-" + ($u|tostring))}},
     mirror: {provider: "fixture-provider", model: $m, vote: (3 - $g), request: {prompt: ("p-" + ($u|tostring)), brief: ("b-" + ($u|tostring))}}}]'
}
UNITS_A=$(cal_units m-one)
UNITS_B=$(cal_units m-two)

make_cal_templates() {
  local hold_sha sys_sha samp_sha
  hold_sha=$(printf '0%.0s' $(seq 1 64))
  sys_sha=$(printf '1%.0s' $(seq 1 64))
  samp_sha=$(printf '2%.0s' $(seq 1 64))
  write_json "$WORK/cal-tpl-a-input.json" "{\"schema_version\":1,\"calibration\":{\"partition\":\"held_out\",\"label_provenance\":\"human-labeled\",\"holdout_corpus_receipt_sha256\":\"$hold_sha\"},\"judge\":{\"id\":\"judge-tpl-a\",\"provider\":\"fixture-provider\",\"model\":\"m-one\",\"model_version\":\"2026.08\",\"system_prompt_sha256\":\"$sys_sha\",\"sampling_sha256\":\"$samp_sha\"},\"units\":$UNITS_A}"
  write_json "$WORK/cal-tpl-b-input.json" "{\"schema_version\":1,\"calibration\":{\"partition\":\"held_out\",\"label_provenance\":\"human-labeled\",\"holdout_corpus_receipt_sha256\":\"$hold_sha\"},\"judge\":{\"id\":\"judge-tpl-b\",\"provider\":\"fixture-provider\",\"model\":\"m-two\",\"model_version\":\"2026.08\",\"system_prompt_sha256\":\"$sys_sha\",\"sampling_sha256\":\"$samp_sha\"},\"units\":$UNITS_B}"
  "$CALIBRATE" "$WORK/cal-tpl-a-input.json" "$CAL_TPL_A" || fail "calibration producer rejected template input"
  "$CALIBRATE" "$WORK/cal-tpl-b-input.json" "$CAL_TPL_B" || fail "calibration producer rejected template input"
  assert_json "$CAL_TPL_A" '.schema_version == "taste-calibration/v1" and .eligible == true and .judge_configuration.kind == "machine"'
}
make_cal_templates

# build_v2 DIR SPEC KIND
#   SPEC: ten space-separated candidate group-win counts out of five.
#   KIND: judge kind recorded in calibration receipts and escrow (machine|human).
build_v2() {
  local dir=$1 spec=$2 kind=$3
  local n g w winner lock_sha cand_sha cap_sha pix_sha hard_sha side_sha revr_sha
  local group_sha grpr_sha cal_in_sha cal_rc_sha ss_d ss_m dp_d dp_m brief_sha
  local ja jb tpl units wins=0 ballots first manifest_briefs manifest_cals
  mkdir -p "$dir/receipts" "$dir/shots"
  : >"$dir/esc-judges.jsonl"
  manifest_briefs=""
  manifest_cals=""
  ballots=""
  set -- $spec
  for n in $(seq 1 10); do
    w=$1; shift
    brief_sha=$(sha_text "brief-body-$n")
    write_json "$dir/receipts/brief-$n-lock.json" "{\"schema_version\":\"taste-brief/v1\",\"brief_id\":\"brief-$n\",\"brief_sha256\":\"$brief_sha\",\"target_population\":{\"category\":\"cat-$n\",\"role\":\"role-$n\"},\"core_task\":{\"id\":\"task-$n\"},\"required_routes\":[\"/r-$n\"],\"required_states\":[\"default\"],\"acceptance_facts_sha256\":\"$ZERO64\",\"rubric_version\":\"taste-rubric/v1\",\"locked_at\":\"2026-08-12T00:00:00Z\"}"
    lock_sha=$(sha "$dir/receipts/brief-$n-lock.json")
    write_json "$dir/receipts/brief-$n-candidate.json" "{\"schema_version\":\"taste-candidate/v1\",\"candidate_id\":\"cand-new\",\"brief_sha256\":\"$brief_sha\",\"design_lock_sha256\":\"$DESIGN_SHA\",\"direction_id\":\"d1\",\"source_revision\":\"$SUBJECT\",\"dependency_lock_sha256\":\"$ZERO64\",\"build_receipt_sha256\":\"$ZERO64\",\"created_at\":\"2026-08-12T00:00:00Z\"}"
    cand_sha=$(sha "$dir/receipts/brief-$n-candidate.json")
    printf 'rendered-bytes-%s-desktop\n' "$n" >"$dir/shots/b$n-d.bin"
    printf 'rendered-bytes-%s-mobile\n' "$n" >"$dir/shots/b$n-m.bin"
    ss_d=$(sha "$dir/shots/b$n-d.bin"); ss_m=$(sha "$dir/shots/b$n-m.bin")
    dp_d=$(sha_text "decoded-pixels-$n-desktop"); dp_m=$(sha_text "decoded-pixels-$n-mobile")
    write_json "$dir/receipts/brief-$n-capture.json" "{\"schema_version\":\"taste-capture-manifest/v1\",\"candidate_id\":\"cand-new\",\"candidate_source_revision\":\"$SUBJECT\",\"browser\":{\"adapter_id\":\"browser-capture\",\"adapter_receipt_path\":\"receipts/browser-receipt.json\"},\"decoder\":{\"adapter_id\":\"png-decoder\",\"adapter_version\":\"1\",\"command_path\":\"bin/decoder\",\"command_sha256\":\"$ZERO64\"},\"required_routes\":[\"/r-$n\"],\"required_states\":[\"default\"],\"mobile_only_states\":[],\"captures\":[{\"capture_id\":\"cap-$n-d\",\"route\":\"/r-$n\",\"state\":\"default\",\"viewport\":\"desktop\",\"viewport_css_px\":{\"width\":1440,\"height\":900},\"screenshot_path\":\"shots/b$n-d.bin\",\"screenshot_png_sha256\":\"$ss_d\",\"decoded_pixel_sha256\":\"$dp_d\",\"decoded_width\":1440,\"decoded_height\":900,\"action_trace_sha256\":\"$ZERO64\",\"dom_sha256\":\"$ZERO64\",\"captured_at\":\"2026-08-12T00:00:00Z\"},{\"capture_id\":\"cap-$n-m\",\"route\":\"/r-$n\",\"state\":\"default\",\"viewport\":\"mobile\",\"viewport_css_px\":{\"width\":390,\"height\":844},\"screenshot_path\":\"shots/b$n-m.bin\",\"screenshot_png_sha256\":\"$ss_m\",\"decoded_pixel_sha256\":\"$dp_m\",\"decoded_width\":390,\"decoded_height\":844,\"action_trace_sha256\":\"$ZERO64\",\"dom_sha256\":\"$ZERO64\",\"captured_at\":\"2026-08-12T00:00:00Z\"}]}"
    cap_sha=$(sha "$dir/receipts/brief-$n-capture.json")
    write_json "$dir/receipts/brief-$n-pixel-receipt.json" "{\"schema_version\":\"taste-pixels-receipt/v1\",\"status\":\"VERIFIED\",\"classification\":\"fixture\",\"validator\":{\"id\":\"taste-pixels\",\"fingerprint\":\"$ZERO64\"},\"output\":{\"capture_count\":2},\"input_sha256\":\"$cap_sha\"}"
    pix_sha=$(sha "$dir/receipts/brief-$n-pixel-receipt.json")
    write_json "$dir/receipts/brief-$n-hard.json" "{\"schema_version\":\"taste-hard-gate/v1\",\"candidate_id\":\"cand-new\",\"capture_manifest_sha256\":\"$cap_sha\",\"task_results\":[{\"task_id\":\"task-$n\",\"capture_id\":\"cap-$n-d\",\"status\":\"pass\",\"trace_sha256\":\"$ZERO64\"}],\"accessibility\":[{\"capture_id\":\"cap-$n-d\",\"ruleset\":\"WCAG-2.2-declared-scope\",\"adapter_receipt_sha256\":\"$ZERO64\",\"status\":\"pass\",\"manual_exception_ids\":[]},{\"capture_id\":\"cap-$n-m\",\"ruleset\":\"WCAG-2.2-declared-scope\",\"adapter_receipt_sha256\":\"$ZERO64\",\"status\":\"pass\",\"manual_exception_ids\":[]}],\"state_coverage\":[{\"capture_id\":\"cap-$n-d\",\"status\":\"pass\"},{\"capture_id\":\"cap-$n-m\",\"status\":\"pass\"}],\"product_specificity\":{\"signature_test_sha256\":\"$ZERO64\",\"status\":\"pass\"},\"overall\":\"PASS\"}"
    hard_sha=$(sha "$dir/receipts/brief-$n-hard.json")
    write_json "$dir/receipts/brief-$n-sidecar.json" "{\"schema_version\":\"taste-sameness-sidecar/v1\",\"brief_id\":\"brief-$n\",\"candidate_id\":\"cand-new\"}"
    side_sha=$(sha "$dir/receipts/brief-$n-sidecar.json")
    write_json "$dir/receipts/brief-$n-review.json" "{\"schema_version\":\"taste-cross-brief-review/v2\",\"status\":\"resolved\",\"determination\":\"clear\",\"brief_id\":\"brief-$n\",\"input_sha256\":\"$side_sha\"}"
    revr_sha=$(sha "$dir/receipts/brief-$n-review.json")
    [ "$n" -eq 1 ] || manifest_briefs="$manifest_briefs,"
    manifest_briefs="$manifest_briefs{\"brief_lock\":{\"path\":\"receipts/brief-$n-lock.json\",\"sha256\":\"$lock_sha\"},\"candidate\":{\"path\":\"receipts/brief-$n-candidate.json\",\"sha256\":\"$cand_sha\"},\"capture\":{\"input\":{\"path\":\"receipts/brief-$n-capture.json\",\"sha256\":\"$cap_sha\"},\"receipt\":{\"path\":\"receipts/brief-$n-pixel-receipt.json\",\"sha256\":\"$pix_sha\"}},\"hard_gate\":{\"path\":\"receipts/brief-$n-hard.json\",\"sha256\":\"$hard_sha\"},\"review\":{\"input\":{\"path\":\"receipts/brief-$n-sidecar.json\",\"sha256\":\"$side_sha\"},\"receipt\":{\"path\":\"receipts/brief-$n-review.json\",\"sha256\":\"$revr_sha\"}},\"groups\":["
    for g in $(seq 1 5); do
      ja="judge-$n-$g-a"; jb="judge-$n-$g-b"
      if [ "$g" -le "$w" ]; then winner=cand-new; else winner=cand-old; fi
      write_json "$dir/receipts/cal-$ja-input.json" "{\"schema_version\":1,\"calibration\":{\"partition\":\"held_out\",\"label_provenance\":\"human-labeled\"},\"judge\":{\"id\":\"$ja\",\"provider\":\"fixture-provider\",\"model\":\"m-one\"},\"units\":$UNITS_A}"
      write_json "$dir/receipts/cal-$jb-input.json" "{\"schema_version\":1,\"calibration\":{\"partition\":\"held_out\",\"label_provenance\":\"human-labeled\"},\"judge\":{\"id\":\"$jb\",\"provider\":\"fixture-provider\",\"model\":\"m-two\"},\"units\":$UNITS_B}"
      for tpl in a b; do
        if [ "$tpl" = a ]; then units=$ja; else units=$jb; fi
        cal_in_sha=$(sha "$dir/receipts/cal-$units-input.json")
        jq --arg id "$units" --arg is "$cal_in_sha" --arg kind "$kind" \
          '.judge_id=$id | .judge.id=$id | .input_sha256=$is | .judge_configuration.kind=$kind' \
          "$WORK/cal-template-$tpl.json" >"$dir/receipts/cal-$units-receipt.json"
        cal_rc_sha=$(sha "$dir/receipts/cal-$units-receipt.json")
        [ -z "$manifest_cals" ] || manifest_cals="$manifest_cals,"
        manifest_cals="$manifest_cals{\"input\":{\"path\":\"receipts/cal-$units-input.json\",\"sha256\":\"$cal_in_sha\"},\"receipt\":{\"path\":\"receipts/cal-$units-receipt.json\",\"sha256\":\"$cal_rc_sha\"}}"
        if [ "$tpl" = a ]; then
          printf '{"judge_id":"%s","kind":"%s","provider":"fixture-provider","model":"m-one"}\n' "$units" "$kind" >>"$dir/esc-judges.jsonl"
        else
          printf '{"judge_id":"%s","kind":"%s","provider":"fixture-provider","model":"m-two"}\n' "$units" "$kind" >>"$dir/esc-judges.jsonl"
        fi
      done
      write_json "$dir/receipts/brief-$n-group-$g.json" "{\"schema_version\":\"taste-mirrored-group/v1\",\"mirror_group_id\":\"mg-$n-$g\",\"brief_sha256\":\"$brief_sha\",\"candidate_ids_escrow_sha256\":\"$ESCROW_SHA\",\"pointwise_ballot_ids\":[\"pw-$n-$g-a\",\"pw-$n-$g-b\"],\"exposures\":[{\"ballot_id\":\"pair-$n-$g-a\",\"judge_id\":\"$ja\",\"display_order\":\"A/B\",\"choice\":\"A\",\"canonical_choice\":\"$winner\",\"independence_attestation_sha256\":\"$ATTEST_SHA\",\"sealed_at\":\"2026-08-12T00:01:00Z\"},{\"ballot_id\":\"pair-$n-$g-b\",\"judge_id\":\"$jb\",\"display_order\":\"B/A\",\"choice\":\"B\",\"canonical_choice\":\"$winner\",\"independence_attestation_sha256\":\"$ATTEST_SHA\",\"sealed_at\":\"2026-08-12T00:01:00Z\"}],\"outcome\":\"resolved-$winner\"}"
      group_sha=$(sha "$dir/receipts/brief-$n-group-$g.json")
      write_json "$dir/receipts/brief-$n-group-$g-receipt.json" "{\"schema_version\":\"taste-ballot-validation/v2\",\"status\":\"eligible\",\"fixture_only\":false,\"human_certified\":false,\"mirror_group_id\":\"mg-$n-$g\",\"brief_sha256\":\"$brief_sha\",\"winner\":\"$winner\",\"group_sha256\":\"$group_sha\"}"
      grpr_sha=$(sha "$dir/receipts/brief-$n-group-$g-receipt.json")
      [ "$g" -eq 1 ] || manifest_briefs="$manifest_briefs,"
      manifest_briefs="$manifest_briefs{\"input\":{\"path\":\"receipts/brief-$n-group-$g.json\",\"sha256\":\"$group_sha\"},\"receipt\":{\"path\":\"receipts/brief-$n-group-$g-receipt.json\",\"sha256\":\"$grpr_sha\"}}"
    done
    manifest_briefs="$manifest_briefs]}"
    [ "$n" -eq 1 ] || ballots="$ballots,"
    if [ "$w" -ge 3 ]; then
      wins=$((wins + 1)); ballots="$ballots{\"brief_id\":\"brief-$n\",\"vote\":\"candidate\"}"
    else
      ballots="$ballots{\"brief_id\":\"brief-$n\",\"vote\":\"baseline\"}"
    fi
  done

  jq -s "{schema_version:\"taste-provenance-escrow/v1\",run_id:\"run-v2\",candidate_id:\"cand-new\",generation:{provider:\"gen-provider\",model:\"gen-model\"},judges:.}" \
    "$dir/esc-judges.jsonl" >"$dir/receipts/escrow.json"
  rm -f "$dir/esc-judges.jsonl"
  write_json "$dir/receipts/reference.json" "{\"schema_version\":\"taste-reference-packet/v1\",\"same_category_references\":[{\"reference_id\":\"r1\"},{\"reference_id\":\"r2\"},{\"reference_id\":\"r3\"}],\"wildcard_reference\":{\"reference_id\":\"w1\"},\"pattern_matrix_sha256\":\"$ZERO64\"}"
  write_json "$dir/receipts/directions.json" '{"schema_version":"taste-direction/v1","directions":[{"direction_id":"d1"},{"direction_id":"d2"},{"direction_id":"d3"}]}'
  write_json "$dir/receipts/corpus-input.json" '{"format_version":1,"sources":[{"id":"s1"}],"records":[{"id":"rec-1"},{"id":"rec-2"}]}'
  local corpus_in_sha; corpus_in_sha=$(sha "$dir/receipts/corpus-input.json")
  write_json "$dir/receipts/corpus-receipt.json" "{\"schema_version\":\"taste-corpus-receipt/v1\",\"status\":\"VALIDATED\",\"classification\":\"fixture\",\"output\":{\"record_count\":2},\"input_sha256\":\"$corpus_in_sha\"}"
  write_json "$dir/receipts/ballots.json" "{\"schema\":\"polylane.taste.ballots.v1\",\"ballots\":[$ballots]}"
  # The statistics receipt binds the SHA-256 of the canonical (jq -cS) ballots
  # document INCLUDING the trailing newline, per the coordinator byte-rule
  # resolution on the relay.
  local ballots_sha ballots_canon_sha rate
  ballots_sha=$(sha "$dir/receipts/ballots.json")
  ballots_canon_sha=$(jq -cS . "$dir/receipts/ballots.json" | shasum -a 256 | awk '{print $1}')
  rate=$(awk -v w="$wins" 'BEGIN{printf "%.2f", w/10}')
  write_json "$dir/receipts/stats-receipt.json" "{\"schema\":\"polylane.taste.stats.v1\",\"valid\":true,\"sample_unit\":\"brief\",\"brief_count\":10,\"candidate_wins\":$wins,\"baseline_wins\":$((10 - wins)),\"ties\":0,\"preference_rate\":$rate,\"wilson_lower_bound\":0.40,\"input_sha256\":\"$ballots_canon_sha\"}"
  write_json "$dir/receipts/threat-input.json" '{"schema_version":"taste-threat/v1","source_root":"/","hard_gates":{"function_pass":true,"accessibility_pass":true},"context":{"status":"pass"},"captures":[],"receipts":[],"sidecars":[]}'
  local threat_in_sha; threat_in_sha=$(sha "$dir/receipts/threat-input.json")
  write_json "$dir/receipts/threat-receipt.json" "{\"schema_version\":\"taste-threat-receipt/v2\",\"status\":\"clean\",\"axis_results\":{\"genericness_review\":\"pass\",\"quality_risk\":\"pass\",\"context_fit\":\"pass\",\"provenance_integrity\":\"pass\"},\"review\":{\"status\":\"not-required\",\"scope\":null,\"attribution_claim\":false},\"reason_codes\":[],\"input_sha256\":\"$threat_in_sha\"}"
  write_json "$dir/receipts/repair-ledger.json" '{"schema_version":"taste-repair-ledger/v1","entries":[{"repair_id":"repair-1"}]}'
  local ledger_sha; ledger_sha=$(sha "$dir/receipts/repair-ledger.json")
  write_json "$dir/receipts/repair-receipt.json" "{\"schema_version\":\"taste-repair-ledger/v2\",\"status\":\"valid\",\"repair_count\":1,\"input_sha256\":\"$ledger_sha\"}"

  local required_claim=HUMAN_CALIBRATED_MACHINE
  [ "$kind" = human ] && required_claim=HUMAN_CERTIFIED
  {
    printf '%s' "{\"schema_version\":\"taste-evidence-manifest/v2\",\"run_id\":\"run-v2\",\"protocol_version\":\"taste-protocol/v1\",\"candidate_id\":\"cand-new\",\"subject_revision\":\"$SUBJECT\",\"goal_sha256\":\"$GOAL_SHA\",\"design_lock_sha256\":\"$DESIGN_SHA\",\"fixture\":false,\"required_claim\":\"$required_claim\",\"declared_evidence_paths\":[\"docs/\"]"
    printf ',"escrow":{"path":"receipts/escrow.json","sha256":"%s"}' "$(sha "$dir/receipts/escrow.json")"
    printf ',"reference_packet":{"path":"receipts/reference.json","sha256":"%s"}' "$(sha "$dir/receipts/reference.json")"
    printf ',"directions":{"path":"receipts/directions.json","sha256":"%s"}' "$(sha "$dir/receipts/directions.json")"
    printf ',"corpus":{"input":{"path":"receipts/corpus-input.json","sha256":"%s"},"receipt":{"path":"receipts/corpus-receipt.json","sha256":"%s"}}' "$corpus_in_sha" "$(sha "$dir/receipts/corpus-receipt.json")"
    printf ',"stats":{"input":{"path":"receipts/ballots.json","sha256":"%s"},"receipt":{"path":"receipts/stats-receipt.json","sha256":"%s"}}' "$ballots_sha" "$(sha "$dir/receipts/stats-receipt.json")"
    printf ',"threat":{"input":{"path":"receipts/threat-input.json","sha256":"%s"},"receipt":{"path":"receipts/threat-receipt.json","sha256":"%s"}}' "$threat_in_sha" "$(sha "$dir/receipts/threat-receipt.json")"
    printf ',"repair":{"input":{"path":"receipts/repair-ledger.json","sha256":"%s"},"receipt":{"path":"receipts/repair-receipt.json","sha256":"%s"}}' "$ledger_sha" "$(sha "$dir/receipts/repair-receipt.json")"
    printf ',"briefs":[%s],"calibrations":[%s]}\n' "$manifest_briefs" "$manifest_cals"
  } >"$dir/manifest.json"
}

BASE="$WORK/v2-base"
build_v2 "$BASE" "5 5 5 5 5 5 5 5 5 5" machine

certify_v2() { "$TASTE" certify "$1/manifest.json" "$2" "$3"; }

CERT="$WORK/v2-cert.json"
certify_v2 "$BASE" "$CERT" "$REPO" || fail "v2 base fixture did not certify: $(cat "$CERT" 2>/dev/null || echo no-cert)"
assert_json "$CERT" '.schema_version == "taste-certificate/v2" and .status == "TASTE-CERTIFIED"'
assert_json "$CERT" '.claim_label == "HUMAN_CALIBRATED_MACHINE" and .human_calibrated == true and .human_certified == false'
assert_json "$CERT" '.fixture_only == false and .candidate_id == "cand-new" and (.verdict_reason_codes | length == 0)'
assert_json "$CERT" ".subject_revision == \"$SUBJECT\" and .goal_sha256 == \"$GOAL_SHA\" and .design_lock_sha256 == \"$DESIGN_SHA\""
assert_json "$CERT" '.briefs == 10 and .brief_wins == 10 and (.briefs_lost | length == 0)'
assert_json "$CERT" '.eligible_judges == 100 and .unique_judge_configurations == 2'
assert_json "$CERT" '.preference_rate >= 0.99 and .wilson_lower_bound > 0.90'
assert_json "$CERT" '.accessibility_regressions == 0 and .repair_count == 1 and (.repair_ledger_sha256 | test("^[0-9a-f]{64}$"))'
assert_json "$CERT" '(.evidence_chain_sha256 | test("^[0-9a-f]{64}$")) and (.validator_chain_sha256 | test("^[0-9a-f]{64}$"))'
assert_json "$CERT" '(.external_limitations | length > 0) and .run_id == "run-v2" and .protocol_version == "taste-protocol/v1"'

# Deterministic: recompiling the same chain yields an identical certificate.
certify_v2 "$BASE" "$WORK/v2-cert-again.json" "$REPO" || fail "v2 recompile failed"
[ "$(jq -cS . "$CERT")" = "$(jq -cS . "$WORK/v2-cert-again.json")" ] || fail "v2 certificate is not deterministic"

# --- attack harness ---------------------------------------------------------
clone_fixture() { rm -rf "$2"; cp -R "$1" "$2"; }
mani() { jqi "$1/manifest.json" "${@:2}"; }
redeclare() { # redeclare DIR JQPATH REL: refresh a declared sha after editing REL
  local dir=$1 jqpath=$2 rel=$3
  jqi "$dir/manifest.json" --arg s "$(sha "$dir/$rel")" "$jqpath = \$s"
}

expect_blocked_v2() { # name dir root code [extra-cert-assertion]
  local name=$1 dir=$2 root=$3 code=$4 extra=${5:-true}
  local cert="$WORK/$name-cert.json"
  printf 'prior-not-a-certificate' >"$cert"
  if certify_v2 "$dir" "$cert" "$root"; then fail "$name unexpectedly certified"; fi
  assert_json "$cert" '.schema_version == "taste-certificate/v2" and .status == "NOT-CERTIFIED"'
  assert_json "$cert" "(.verdict_reason_codes | index(\"$code\")) != null"
  assert_json "$cert" '(.verdict_reason_codes | sort) == .verdict_reason_codes'
  assert_json "$cert" "$extra"
  [ -z "$(find "$WORK" -name "$name-cert.json.tmp.*" -print -quit)" ] || fail "$name left a partial certificate"
}

A="$WORK/atk"

# Missing validator receipt.
clone_fixture "$BASE" "$A"; rm "$A/receipts/brief-3-pixel-receipt.json"
expect_blocked_v2 missing-receipt "$A" "$REPO" RECEIPT_MISSING

# Forged receipt: shape-compatible but contradicting its own raw input.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/brief-1-group-1-receipt.json" '.winner = "cand-old"'
redeclare "$A" '.briefs[0].groups[0].receipt.sha256' receipts/brief-1-group-1-receipt.json
expect_blocked_v2 forged-receipt "$A" "$REPO" RECEIPT_BINDING

# Raw artifact edited without redeclaring: recomputed hash must mismatch.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/brief-1-group-1.json" '.mirror_group_id = "mg-tampered"'
expect_blocked_v2 hash-mismatch "$A" "$REPO" HASH_MISMATCH

# Fixture-only producer evidence can never authorize production promotion.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/brief-2-group-2-receipt.json" '.fixture_only = true'
redeclare "$A" '.briefs[1].groups[1].receipt.sha256' receipts/brief-2-group-2-receipt.json
expect_blocked_v2 fixture-evidence "$A" "$REPO" FIXTURE_EVIDENCE '.fixture_only == true'

# A manifest relabeled as fixture cannot emit a production certificate.
clone_fixture "$BASE" "$A"; mani "$A" '.fixture = true'
expect_blocked_v2 fixture-manifest "$A" "$REPO" FIXTURE_EVIDENCE '.fixture_only == true'

# Cycle-39 producer ballots (taste-ballot-validation/v1, fixture_only:true) are
# fixture evidence by definition: they can never authorize production promotion.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/brief-3-group-4-receipt.json" '.schema_version = "taste-ballot-validation/v1" | .fixture_only = true'
redeclare "$A" '.briefs[2].groups[3].receipt.sha256' receipts/brief-3-group-4-receipt.json
expect_blocked_v2 ballot-v1-fixture "$A" "$REPO" FIXTURE_EVIDENCE '.fixture_only == true'

# Stale capture revision, with downstream receipts fully rebound to hide it.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/brief-2-capture.json" --arg r "$ALT_REVISION" '.candidate_source_revision = $r'
CAP2=$(sha "$A/receipts/brief-2-capture.json")
jqi "$A/receipts/brief-2-pixel-receipt.json" --arg s "$CAP2" '.input_sha256 = $s'
jqi "$A/receipts/brief-2-hard.json" --arg s "$CAP2" '.capture_manifest_sha256 = $s'
redeclare "$A" '.briefs[1].capture.input.sha256' receipts/brief-2-capture.json
redeclare "$A" '.briefs[1].capture.receipt.sha256' receipts/brief-2-pixel-receipt.json
redeclare "$A" '.briefs[1].hard_gate.sha256' receipts/brief-2-hard.json
expect_blocked_v2 stale-revision "$A" "$REPO" STALE_REVISION

# Subject revision unknown to the integrator repository.
clone_fixture "$BASE" "$A"
expect_blocked_v2 alien-subject "$A" "$REPO_ALIEN" SUBJECT_REVISION_INVALID

# Undeclared source commit after the subject revision.
clone_fixture "$BASE" "$A"
expect_blocked_v2 undeclared-commit "$A" "$REPO_DRIFT" UNDECLARED_POST_EVIDENCE_COMMIT

# Missing candidate identity and caller-authored status are closed-schema errors.
clone_fixture "$BASE" "$A"; mani "$A" 'del(.candidate_id)'
expect_blocked_v2 missing-candidate "$A" "$REPO" MANIFEST_INVALID
clone_fixture "$BASE" "$A"; mani "$A" '.status = "TASTE-CERTIFIED"'
expect_blocked_v2 caller-status "$A" "$REPO" MANIFEST_INVALID
clone_fixture "$BASE" "$A"; mani "$A" '.briefs[0].winner = "cand-new"'
expect_blocked_v2 caller-winner "$A" "$REPO" MANIFEST_INVALID

# Duplicate judge inside one mirrored group.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/brief-4-group-2.json" '.exposures[1].judge_id = .exposures[0].judge_id'
G42=$(sha "$A/receipts/brief-4-group-2.json")
jqi "$A/receipts/brief-4-group-2-receipt.json" --arg s "$G42" '.group_sha256 = $s'
redeclare "$A" '.briefs[3].groups[1].input.sha256' receipts/brief-4-group-2.json
redeclare "$A" '.briefs[3].groups[1].receipt.sha256' receipts/brief-4-group-2-receipt.json
expect_blocked_v2 duplicate-judge "$A" "$REPO" JUDGE_NOT_INDEPENDENT

# Judge identity reused across groups.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/brief-6-group-1.json" '.exposures[0].judge_id = "judge-6-2-a"'
G61=$(sha "$A/receipts/brief-6-group-1.json")
jqi "$A/receipts/brief-6-group-1-receipt.json" --arg s "$G61" '.group_sha256 = $s'
redeclare "$A" '.briefs[5].groups[0].input.sha256' receipts/brief-6-group-1.json
redeclare "$A" '.briefs[5].groups[0].receipt.sha256' receipts/brief-6-group-1-receipt.json
expect_blocked_v2 reused-judge "$A" "$REPO" JUDGE_NOT_INDEPENDENT

# Two aliases of one judge configuration deciding one mirrored group.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/cal-judge-5-1-b-receipt.json" '.judge.model = "m-one" | .judge_configuration.model = "m-one"'
redeclare "$A" '.calibrations[41].receipt.sha256' receipts/cal-judge-5-1-b-receipt.json
jqi "$A/receipts/escrow.json" '(.judges[] | select(.judge_id == "judge-5-1-b") | .model) = "m-one"'
redeclare "$A" '.escrow.sha256' receipts/escrow.json
assert_json "$A/manifest.json" '.calibrations[41].input.path == "receipts/cal-judge-5-1-b-input.json"'
expect_blocked_v2 judge-alias "$A" "$REPO" JUDGE_ALIAS

# A deciding judge without a calibration receipt.
clone_fixture "$BASE" "$A"; mani "$A" 'del(.calibrations[0])'
expect_blocked_v2 uncalibrated-judge "$A" "$REPO" JUDGE_NOT_CALIBRATED

# Quorum floors.
clone_fixture "$BASE" "$A"; mani "$A" '.briefs[0].groups = .briefs[0].groups[0:4]'
expect_blocked_v2 few-groups "$A" "$REPO" BALLOT_QUORUM
clone_fixture "$BASE" "$A"; mani "$A" '.briefs = .briefs[0:9]'
expect_blocked_v2 few-briefs "$A" "$REPO" BRIEF_QUORUM

# Duplicate rendered pixels across required captures.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/brief-7-capture.json" '.captures[1].decoded_pixel_sha256 = .captures[0].decoded_pixel_sha256'
CAP7=$(sha "$A/receipts/brief-7-capture.json")
jqi "$A/receipts/brief-7-pixel-receipt.json" --arg s "$CAP7" '.input_sha256 = $s'
jqi "$A/receipts/brief-7-hard.json" --arg s "$CAP7" '.capture_manifest_sha256 = $s'
redeclare "$A" '.briefs[6].capture.input.sha256' receipts/brief-7-capture.json
redeclare "$A" '.briefs[6].capture.receipt.sha256' receipts/brief-7-pixel-receipt.json
redeclare "$A" '.briefs[6].hard_gate.sha256' receipts/brief-7-hard.json
expect_blocked_v2 duplicate-render "$A" "$REPO" DUPLICATE_RENDER

# Side-order contradiction between the mirrored exposures.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/brief-8-group-3.json" '.exposures[1].canonical_choice = "cand-old"'
G83=$(sha "$A/receipts/brief-8-group-3.json")
jqi "$A/receipts/brief-8-group-3-receipt.json" --arg s "$G83" '.group_sha256 = $s'
redeclare "$A" '.briefs[7].groups[2].input.sha256' receipts/brief-8-group-3.json
redeclare "$A" '.briefs[7].groups[2].receipt.sha256' receipts/brief-8-group-3-receipt.json
expect_blocked_v2 side-order "$A" "$REPO" SIDE_ORDER_CONTRADICTION

# Accessibility regression is a non-compensatory veto.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/brief-9-hard.json" '.accessibility[0].status = "fail"'
redeclare "$A" '.briefs[8].hard_gate.sha256' receipts/brief-9-hard.json
expect_blocked_v2 a11y-veto "$A" "$REPO" ACCESSIBILITY_VETO '.accessibility_regressions == 1'

# More than two repairs exhaust the durable budget.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/repair-ledger.json" '.entries = [{"repair_id":"repair-1"},{"repair_id":"repair-2"},{"repair_id":"repair-3"}]'
LSHA=$(sha "$A/receipts/repair-ledger.json")
jqi "$A/receipts/repair-receipt.json" --arg s "$LSHA" '.repair_count = 3 | .input_sha256 = $s'
redeclare "$A" '.repair.input.sha256' receipts/repair-ledger.json
redeclare "$A" '.repair.receipt.sha256' receipts/repair-receipt.json
expect_blocked_v2 repair-budget "$A" "$REPO" REPAIR_BUDGET '.repair_count == 3'

# Dirty threat review blocks certification.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/threat-receipt.json" '.status = "unknown" | .reason_codes = ["cross-brief-template-review"]'
redeclare "$A" '.threat.receipt.sha256' receipts/threat-receipt.json
expect_blocked_v2 threat-dirty "$A" "$REPO" THREAT_GATE

# Machine-calibrated evidence cannot silently satisfy a required human claim.
clone_fixture "$BASE" "$A"; mani "$A" '.required_claim = "HUMAN_CERTIFIED"'
expect_blocked_v2 claim-downgrade "$A" "$REPO" CLAIM_NOT_MET

# Unknown numeric values are schema failures, not zeros.
clone_fixture "$BASE" "$A"
jqi "$A/receipts/stats-receipt.json" '.wilson_lower_bound = "0.99"'
redeclare "$A" '.stats.receipt.sha256' receipts/stats-receipt.json
expect_blocked_v2 unknown-numeric "$A" "$REPO" RECEIPT_SCHEMA

# --- threshold fixtures ------------------------------------------------------
SEVEN="$WORK/v2-seven"
build_v2 "$SEVEN" "5 5 5 5 5 5 5 2 2 2" machine
certify_v2 "$SEVEN" "$WORK/seven-cert.json" "$REPO" || fail "7/10 corpus with strong preference did not certify: $(cat "$WORK/seven-cert.json")"
assert_json "$WORK/seven-cert.json" '.status == "TASTE-CERTIFIED" and .brief_wins == 7 and (.briefs_lost | sort) == ["brief-10","brief-8","brief-9"]'
assert_json "$WORK/seven-cert.json" '.preference_rate == 0.82 and .wilson_lower_bound > 0.50 and (.verdict_reason_codes | length == 0)'

SIX="$WORK/v2-six"
build_v2 "$SIX" "5 5 5 5 5 5 2 2 2 2" machine
expect_blocked_v2 six-wins "$SIX" "$REPO" BRIEF_WIN_FLOOR '(.verdict_reason_codes | index("PREFERENCE_FLOOR")) == null and .brief_wins == 6'

# Threshold gaming: a stats receipt that claims more brief wins than the chain shows.
clone_fixture "$SIX" "$A"
jqi "$A/receipts/stats-receipt.json" '.candidate_wins = 10 | .baseline_wins = 0'
redeclare "$A" '.stats.receipt.sha256' receipts/stats-receipt.json
expect_blocked_v2 stats-gaming "$A" "$REPO" STATS_MISMATCH

PREF="$WORK/v2-pref"
build_v2 "$PREF" "3 3 3 3 3 3 3 3 1 1" machine
expect_blocked_v2 preference-floor "$PREF" "$REPO" PREFERENCE_FLOOR \
  '(.verdict_reason_codes | index("WILSON_FLOOR")) != null and (.verdict_reason_codes | index("BRIEF_WIN_FLOOR")) == null and .brief_wins == 8'

# --- human-certified path ----------------------------------------------------
HUMAN="$WORK/v2-human"
build_v2 "$HUMAN" "5 5 5 5 5 5 5 5 5 5" human
certify_v2 "$HUMAN" "$WORK/human-cert.json" "$REPO" || fail "human corpus did not certify: $(cat "$WORK/human-cert.json")"
assert_json "$WORK/human-cert.json" '.status == "TASTE-CERTIFIED" and .claim_label == "HUMAN_CERTIFIED" and .human_calibrated == true and .human_certified == true'

printf 'PASS: taste certification compiler\n'
