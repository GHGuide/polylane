#!/usr/bin/env bash
# Contract tests for the frozen live taste-study compiler and the certificate
# compiler's LIVE production mode.
#
# The live study is provider-neutral and hash-closed: production calibration-v2,
# production ballot-v2 with unique isolated session ids, and a production threat
# receipt are mandatory in the deciding roles, the manifest must match every
# frozen constant, and the subject may only advance by declared-evidence-only
# linear commits.  A fixture/v1 receipt in any deciding role fails closed.
#
# Every positive case is a production-SHAPED chain: it proves the compiler will
# accept a real study once producers emit these receipts.  It never asserts that
# a live study occurred — live_study_executed stays false and the real external
# prerequisites are recorded.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TASTE="$ROOT/bin/polylane-taste.sh"
STUDY="$ROOT/bin/polylane-taste-study.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-study.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_json() { jq -e "$2" "$1" >/dev/null || fail "assertion failed on $1: $2"; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
sha_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }
hex() { sha_text "$1"; }
write_json() { local p=$1 j=$2; mkdir -p "$(dirname "$p")"; printf '%s\n' "$j" >"$p"; }
jqi() { local f=$1; shift; jq "$@" "$f" >"$f.jqi" && mv "$f.jqi" "$f"; }

ZERO64=$(printf '%064d' 0)
HEX1=$(printf '1%.0s' $(seq 1 64))   # a fixed valid hex64 for unbound binding fields
GOAL_SHA=$(hex "literal goal: current-subject taste promotion")
DESIGN_SHA=$(hex "design lock v2")
ESCROW_SHA=$(hex "candidate escrow")
ATTEST_SHA=$(hex "independence attestation")

# --- a hermetic integrator repo: subject + one declared-evidence commit -------
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

# repo where the subject advanced by an undeclared *source* commit (drift).
REPO_DRIFT="$WORK/repo-drift"
cp -R "$REPO" "$REPO_DRIFT"
printf 'undeclared drift\n' >>"$REPO_DRIFT/src/app.txt"
git -C "$REPO_DRIFT" add src/app.txt
git -C "$REPO_DRIFT" -c user.email=t@t -c user.name=t commit -qm drift

# ---------------------------------------------------------------------------
# build_live DIR "w1..w10": a production-shaped live evidence chain.
#   Each wN in 0..5 is the candidate's group wins out of five for brief N.
# ---------------------------------------------------------------------------
build_live() {
  local dir=$1; shift
  local wins_spec="$*"
  local n g w winner brief_sha lock_sha cand_sha cap_sha pix_sha hard_sha side_sha revr_sha
  local group_sha grpr_sha cal_in_sha cal_rc_sha ss_d ss_m dp_d dp_m ja jb prov model
  local manifest_briefs="" manifest_cals="" ballots="" wins=0
  mkdir -p "$dir/receipts" "$dir/shots"
  : >"$dir/esc-judges.jsonl"
  set -- $wins_spec
  for n in $(seq 1 10); do
    w=$1; shift
    brief_sha=$(hex "brief-body-$n")
    write_json "$dir/receipts/brief-$n-lock.json" "{\"schema_version\":\"taste-brief/v1\",\"brief_id\":\"brief-$n\",\"brief_sha256\":\"$brief_sha\",\"target_population\":{\"category\":\"cat-$n\",\"role\":\"role-$n\"},\"core_task\":{\"id\":\"task-$n\"},\"required_routes\":[\"/r-$n\"],\"required_states\":[\"default\"],\"acceptance_facts_sha256\":\"$ZERO64\",\"rubric_version\":\"taste-rubric/v1\",\"locked_at\":\"2026-08-12T00:00:00Z\"}"
    lock_sha=$(sha "$dir/receipts/brief-$n-lock.json")
    write_json "$dir/receipts/brief-$n-candidate.json" "{\"schema_version\":\"taste-candidate/v1\",\"candidate_id\":\"cand-new\",\"brief_sha256\":\"$brief_sha\",\"design_lock_sha256\":\"$DESIGN_SHA\",\"direction_id\":\"d1\",\"source_revision\":\"$SUBJECT\",\"dependency_lock_sha256\":\"$ZERO64\",\"build_receipt_sha256\":\"$ZERO64\",\"created_at\":\"2026-08-12T00:00:00Z\"}"
    cand_sha=$(sha "$dir/receipts/brief-$n-candidate.json")
    printf 'rendered-bytes-%s-desktop\n' "$n" >"$dir/shots/b$n-d.bin"
    printf 'rendered-bytes-%s-mobile\n' "$n" >"$dir/shots/b$n-m.bin"
    ss_d=$(sha "$dir/shots/b$n-d.bin"); ss_m=$(sha "$dir/shots/b$n-m.bin")
    dp_d=$(hex "decoded-pixels-$n-desktop"); dp_m=$(hex "decoded-pixels-$n-mobile")
    write_json "$dir/receipts/brief-$n-capture.json" "{\"schema_version\":\"taste-capture-manifest/v1\",\"candidate_id\":\"cand-new\",\"candidate_source_revision\":\"$SUBJECT\",\"browser\":{\"adapter_id\":\"browser-capture\",\"adapter_receipt_path\":\"receipts/browser-receipt.json\"},\"decoder\":{\"adapter_id\":\"png-decoder\",\"adapter_version\":\"1\",\"command_path\":\"bin/decoder\",\"command_sha256\":\"$ZERO64\"},\"required_routes\":[\"/r-$n\"],\"required_states\":[\"default\"],\"mobile_only_states\":[],\"captures\":[{\"capture_id\":\"cap-$n-d\",\"route\":\"/r-$n\",\"state\":\"default\",\"viewport\":\"desktop\",\"viewport_css_px\":{\"width\":1440,\"height\":900},\"screenshot_path\":\"shots/b$n-d.bin\",\"screenshot_png_sha256\":\"$ss_d\",\"decoded_pixel_sha256\":\"$dp_d\",\"decoded_width\":1440,\"decoded_height\":900,\"action_trace_sha256\":\"$ZERO64\",\"dom_sha256\":\"$ZERO64\",\"captured_at\":\"2026-08-12T00:00:00Z\"},{\"capture_id\":\"cap-$n-m\",\"route\":\"/r-$n\",\"state\":\"default\",\"viewport\":\"mobile\",\"viewport_css_px\":{\"width\":390,\"height\":844},\"screenshot_path\":\"shots/b$n-m.bin\",\"screenshot_png_sha256\":\"$ss_m\",\"decoded_pixel_sha256\":\"$dp_m\",\"decoded_width\":390,\"decoded_height\":844,\"action_trace_sha256\":\"$ZERO64\",\"dom_sha256\":\"$ZERO64\",\"captured_at\":\"2026-08-12T00:00:00Z\"}]}"
    cap_sha=$(sha "$dir/receipts/brief-$n-capture.json")
    write_json "$dir/receipts/brief-$n-pixel-receipt.json" "{\"schema_version\":\"taste-pixels-receipt/v1\",\"status\":\"VERIFIED\",\"classification\":\"production\",\"validator\":{\"id\":\"taste-pixels\",\"fingerprint\":\"$ZERO64\"},\"output\":{\"capture_count\":2},\"input_sha256\":\"$cap_sha\"}"
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
      # two divergent provider/model configurations decide each group
      for side in a b; do
        if [ "$side" = a ]; then prov="prov-claude"; model="m-one"; else prov="prov-codex"; model="m-two"; fi
        local jid; [ "$side" = a ] && jid=$ja || jid=$jb
        write_json "$dir/receipts/cal-$jid-input.json" "{\"schema_version\":1,\"judge\":{\"id\":\"$jid\",\"provider\":\"$prov\",\"model\":\"$model\"},\"partition\":\"held_out\"}"
        cal_in_sha=$(sha "$dir/receipts/cal-$jid-input.json")
        write_json "$dir/receipts/cal-$jid-receipt.json" "{\"schema_version\":\"taste-calibration/v2\",\"classification\":\"production\",\"calibration_set_id\":\"human-ui-calibration/v1\",\"human_label_source\":\"pinned\",\"eligible\":true,\"result\":\"eligible\",\"judge_id\":\"$jid\",\"judge\":{\"id\":\"$jid\"},\"judge_configuration\":{\"kind\":\"machine\",\"provider\":\"$prov\",\"model\":\"$model\",\"model_version\":\"2026.08\",\"system_prompt_sha256\":\"$ZERO64\",\"sampling_sha256\":\"$ZERO64\"},\"human_labelled_pairs\":24,\"correct\":17,\"accuracy\":0.708333,\"wilson_lcb_95\":0.50,\"side_probe_n\":12,\"side_probe_exact_binomial_p\":0.05,\"mirror_probe_n\":8,\"mirror_contradictions\":0,\"corpus_holdout_receipt_sha256\":\"$HEX1\",\"image_manifest_sha256\":\"$HEX1\",\"raw_responses_sha256\":\"$HEX1\",\"invocation_sha256\":\"$HEX1\",\"parser_sha256\":\"$HEX1\",\"session_id\":\"cs-$n-$g-$side\",\"input_sha256\":\"$cal_in_sha\"}"
        cal_rc_sha=$(sha "$dir/receipts/cal-$jid-receipt.json")
        [ -z "$manifest_cals" ] || manifest_cals="$manifest_cals,"
        manifest_cals="$manifest_cals{\"input\":{\"path\":\"receipts/cal-$jid-input.json\",\"sha256\":\"$cal_in_sha\"},\"receipt\":{\"path\":\"receipts/cal-$jid-receipt.json\",\"sha256\":\"$cal_rc_sha\"}}"
        printf '{"judge_id":"%s","kind":"machine","provider":"%s","model":"%s"}\n' "$jid" "$prov" "$model" >>"$dir/esc-judges.jsonl"
      done
      write_json "$dir/receipts/brief-$n-group-$g.json" "{\"schema_version\":\"taste-mirrored-group/v1\",\"mirror_group_id\":\"mg-$n-$g\",\"brief_sha256\":\"$brief_sha\",\"candidate_ids_escrow_sha256\":\"$ESCROW_SHA\",\"pointwise_ballot_ids\":[\"pw-$n-$g-a\",\"pw-$n-$g-b\"],\"exposures\":[{\"ballot_id\":\"pair-$n-$g-a\",\"judge_id\":\"$ja\",\"display_order\":\"A/B\",\"choice\":\"A\",\"canonical_choice\":\"$winner\",\"independence_attestation_sha256\":\"$ATTEST_SHA\",\"sealed_at\":\"2026-08-12T00:01:00Z\"},{\"ballot_id\":\"pair-$n-$g-b\",\"judge_id\":\"$jb\",\"display_order\":\"B/A\",\"choice\":\"B\",\"canonical_choice\":\"$winner\",\"independence_attestation_sha256\":\"$ATTEST_SHA\",\"sealed_at\":\"2026-08-12T00:01:00Z\"}],\"outcome\":\"resolved-$winner\"}"
      group_sha=$(sha "$dir/receipts/brief-$n-group-$g.json")
      write_json "$dir/receipts/brief-$n-group-$g-receipt.json" "{\"schema_version\":\"taste-ballot-validation/v2\",\"classification\":\"production\",\"status\":\"eligible\",\"fixture_only\":false,\"human_certified\":false,\"mirror_group_id\":\"mg-$n-$g\",\"brief_sha256\":\"$brief_sha\",\"winner\":\"$winner\",\"group_sha256\":\"$group_sha\",\"session_ids\":[\"bs-$n-$g-a\",\"bs-$n-$g-b\"]}"
      grpr_sha=$(sha "$dir/receipts/brief-$n-group-$g-receipt.json")
      [ "$g" -eq 1 ] || manifest_briefs="$manifest_briefs,"
      manifest_briefs="$manifest_briefs{\"input\":{\"path\":\"receipts/brief-$n-group-$g.json\",\"sha256\":\"$group_sha\"},\"receipt\":{\"path\":\"receipts/brief-$n-group-$g-receipt.json\",\"sha256\":\"$grpr_sha\"}}"
    done
    manifest_briefs="$manifest_briefs]}"
    [ "$n" -eq 1 ] || ballots="$ballots,"
    if [ "$w" -ge 3 ]; then wins=$((wins + 1)); ballots="$ballots{\"brief_id\":\"brief-$n\",\"vote\":\"candidate\"}"
    else ballots="$ballots{\"brief_id\":\"brief-$n\",\"vote\":\"baseline\"}"; fi
  done

  jq -s "{schema_version:\"taste-provenance-escrow/v1\",run_id:\"run-live\",candidate_id:\"cand-new\",generation:{provider:\"gen-provider\",model:\"gen-model\"},judges:.}" \
    "$dir/esc-judges.jsonl" >"$dir/receipts/escrow.json"
  rm -f "$dir/esc-judges.jsonl"
  write_json "$dir/receipts/reference.json" "{\"schema_version\":\"taste-reference-packet/v1\",\"same_category_references\":[{\"reference_id\":\"r1\"},{\"reference_id\":\"r2\"},{\"reference_id\":\"r3\"}],\"wildcard_reference\":{\"reference_id\":\"w1\"},\"pattern_matrix_sha256\":\"$ZERO64\"}"
  write_json "$dir/receipts/directions.json" '{"schema_version":"taste-direction/v1","directions":[{"direction_id":"d1"},{"direction_id":"d2"},{"direction_id":"d3"}]}'
  write_json "$dir/receipts/corpus-input.json" '{"format_version":1,"sources":[{"id":"s1"}],"records":[{"id":"rec-1"},{"id":"rec-2"}]}'
  local corpus_in_sha; corpus_in_sha=$(sha "$dir/receipts/corpus-input.json")
  write_json "$dir/receipts/corpus-receipt.json" "{\"schema_version\":\"taste-corpus-receipt/v1\",\"status\":\"VALIDATED\",\"classification\":\"production\",\"output\":{\"record_count\":2},\"input_sha256\":\"$corpus_in_sha\"}"
  write_json "$dir/receipts/ballots.json" "{\"schema\":\"polylane.taste.ballots.v1\",\"ballots\":[$ballots]}"
  local ballots_sha ballots_canon_sha rate
  ballots_sha=$(sha "$dir/receipts/ballots.json")
  ballots_canon_sha=$(jq -cS . "$dir/receipts/ballots.json" | shasum -a 256 | awk '{print $1}')
  rate=$(awk -v w="$wins" 'BEGIN{printf "%.2f", w/10}')
  write_json "$dir/receipts/stats-receipt.json" "{\"schema\":\"polylane.taste.stats.v1\",\"valid\":true,\"sample_unit\":\"brief\",\"brief_count\":10,\"candidate_wins\":$wins,\"baseline_wins\":$((10 - wins)),\"ties\":0,\"preference_rate\":$rate,\"wilson_lower_bound\":0.40,\"input_sha256\":\"$ballots_canon_sha\"}"
  write_json "$dir/receipts/threat-input.json" '{"schema_version":"taste-threat/v1","source_root":"/","hard_gates":{"function_pass":true,"accessibility_pass":true},"context":{"status":"pass"},"captures":[],"receipts":[],"sidecars":[]}'
  local threat_in_sha; threat_in_sha=$(sha "$dir/receipts/threat-input.json")
  write_json "$dir/receipts/threat-receipt.json" "{\"schema_version\":\"taste-threat-receipt/v2\",\"classification\":\"production\",\"status\":\"clean\",\"axis_results\":{\"genericness_review\":\"pass\",\"quality_risk\":\"pass\",\"context_fit\":\"pass\",\"provenance_integrity\":\"pass\"},\"review\":{\"status\":\"not-required\",\"scope\":null,\"attribution_claim\":false},\"reason_codes\":[],\"input_sha256\":\"$threat_in_sha\"}"
  write_json "$dir/receipts/repair-ledger.json" '{"schema_version":"taste-repair-ledger/v1","entries":[{"repair_id":"repair-1"}]}'
  local ledger_sha; ledger_sha=$(sha "$dir/receipts/repair-ledger.json")
  write_json "$dir/receipts/repair-receipt.json" "{\"schema_version\":\"taste-repair-ledger/v2\",\"status\":\"valid\",\"repair_count\":1,\"input_sha256\":\"$ledger_sha\"}"

  {
    printf '%s' "{\"schema_version\":\"taste-evidence-manifest/v2\",\"run_id\":\"run-live\",\"protocol_version\":\"taste-protocol/v1\",\"candidate_id\":\"cand-new\",\"subject_revision\":\"$SUBJECT\",\"goal_sha256\":\"$GOAL_SHA\",\"design_lock_sha256\":\"$DESIGN_SHA\",\"fixture\":false,\"required_claim\":\"HUMAN_CALIBRATED_MACHINE\",\"declared_evidence_paths\":[\"docs/\"]"
    printf ',"escrow":{"path":"receipts/escrow.json","sha256":"%s"}' "$(sha "$dir/receipts/escrow.json")"
    printf ',"reference_packet":{"path":"receipts/reference.json","sha256":"%s"}' "$(sha "$dir/receipts/reference.json")"
    printf ',"directions":{"path":"receipts/directions.json","sha256":"%s"}' "$(sha "$dir/receipts/directions.json")"
    printf ',"corpus":{"input":{"path":"receipts/corpus-input.json","sha256":"%s"},"receipt":{"path":"receipts/corpus-receipt.json","sha256":"%s"}}' "$corpus_in_sha" "$(sha "$dir/receipts/corpus-receipt.json")"
    printf ',"stats":{"input":{"path":"receipts/ballots.json","sha256":"%s"},"receipt":{"path":"receipts/stats-receipt.json","sha256":"%s"}}' "$ballots_sha" "$(sha "$dir/receipts/stats-receipt.json")"
    printf ',"threat":{"input":{"path":"receipts/threat-input.json","sha256":"%s"},"receipt":{"path":"receipts/threat-receipt.json","sha256":"%s"}}' "$threat_in_sha" "$(sha "$dir/receipts/threat-receipt.json")"
    printf ',"repair":{"input":{"path":"receipts/repair-ledger.json","sha256":"%s"},"receipt":{"path":"receipts/repair-receipt.json","sha256":"%s"}}' "$ledger_sha" "$(sha "$dir/receipts/repair-receipt.json")"
    printf ',"briefs":[%s],"calibrations":[%s]}\n' "$manifest_briefs" "$manifest_cals"
  } >"$dir/manifest.json"
  printf '%s' "$corpus_in_sha" >"$dir/corpus.sha"
}

# freeze_spec DIR OUT [jq-overrides...] : a spec matching the built chain.
freeze_spec() {
  local dir=$1 out=$2; shift 2
  local corpus_sha; corpus_sha=$(cat "$dir/corpus.sha")
  jq -n --arg subject "$SUBJECT" --arg goal "$GOAL_SHA" --arg design "$DESIGN_SHA" \
     --arg corpus "$corpus_sha" '
    {schema_version:"taste-study-spec/v1", study_id:"study-c40", run_id:"run-live",
     frozen_at:"2026-08-12T00:00:00Z",
     baseline_revision:"0b802ad13ada13a0dc7cc702a526ed17d3348851",
     current_revision:$subject, goal_sha256:$goal, design_lock_sha256:$design,
     corpus_sha256:$corpus,
     brief_order:["brief-1","brief-2","brief-3","brief-4","brief-5","brief-6","brief-7","brief-8","brief-9","brief-10"],
     provider_configs:[{provider:"prov-claude",model:"m-one"},{provider:"prov-codex",model:"m-two"}],
     calibration_sources:["DVN/9FKSQI","DVN/XOI0HI","DVN/Z7KLIH"],
     calibration_split:{calibration:180, holdout:72, per_domain:"60/24"},
     panel_cohorts:["machine-claude","machine-codex"],
     thresholds:{brief_floor:10, brief_wins:7, preference:0.70, wilson:0.50, groups_per_brief:5, accessibility_regressions:0},
     repair_budget:2,
     evidence_prefixes:["docs/"],
     claim:"HUMAN_CALIBRATED_MACHINE",
     analysis:{confirmatory:"tie-aware hierarchical Davidson-Bradley-Terry by track"}}' \
    | jq "$@" >"$out"
}

expect_study_blocked() { # name freeze manifest root code
  local name=$1 fr=$2 dir=$3 root=$4 code=$5
  local cert="$WORK/$name-study-cert.json"
  printf 'prior-not-a-certificate' >"$cert"
  if "$STUDY" compile "$fr" "$dir/manifest.json" "$cert" "$root"; then fail "$name unexpectedly verified"; fi
  assert_json "$cert" '.schema_version == "taste-study-certificate/v1" and .status == "NOT-CERTIFIED"'
  assert_json "$cert" "(.verdict_reason_codes | index(\"$code\")) != null"
  assert_json "$cert" '.live_study_executed == false'
  [ -z "$(find "$WORK" -name "$name-study-cert.json.tmp.*" -print -quit)" ] || fail "$name left a partial cert"
}

# Sourced as a library (by the e2e harness) it exposes build_live/freeze_spec and
# the hermetic repo without running the assertions.
if [ "${TASTE_STUDY_LIB:-0}" = 1 ]; then return 0 2>/dev/null || exit 0; fi

# 1. LIVE MODE on the base compiler: the production-shaped chain certifies -----
BASE="$WORK/base"
build_live "$BASE" "5 5 5 5 5 5 5 5 5 5"
POLYLANE_TASTE_LIVE=1 "$TASTE" certify "$BASE/manifest.json" "$WORK/base-live-cert.json" "$REPO" \
  || fail "live-mode base compiler rejected the production-shaped chain: $(cat "$WORK/base-live-cert.json")"
assert_json "$WORK/base-live-cert.json" '.status == "TASTE-CERTIFIED" and .live_mode == true'
assert_json "$WORK/base-live-cert.json" '.claim_label == "HUMAN_CALIBRATED_MACHINE" and .human_certified == false'
assert_json "$WORK/base-live-cert.json" '.unique_judge_configurations == 2 and .fixture_only == false'

# The SAME base compiler in default (non-live) mode certifies too (compat).
"$TASTE" certify "$BASE/manifest.json" "$WORK/base-default-cert.json" "$REPO" \
  || fail "default-mode base compiler rejected the chain"
assert_json "$WORK/base-default-cert.json" '.status == "TASTE-CERTIFIED" and .live_mode == false'

# 2. FREEZE is write-once and deterministic -----------------------------------
FREEZE="$WORK/freeze.json"
"$STUDY" freeze <(freeze_spec "$BASE" /dev/stdout) "$FREEZE" >/dev/null 2>&1 && fail "freeze accepted a process-sub spec path"
freeze_spec "$BASE" "$WORK/spec.json"
"$STUDY" freeze "$WORK/spec.json" "$FREEZE" >/dev/null || fail "freeze rejected a valid spec"
assert_json "$FREEZE" '.schema_version == "taste-study-freeze/v1" and (.freeze_sha256 | test("^[0-9a-f]{64}$"))'
if "$STUDY" freeze "$WORK/spec.json" "$FREEZE" >/dev/null 2>&1; then fail "freeze overwrote an existing preregistration"; fi
# an incomplete spec is a preregistration failure
freeze_spec "$BASE" "$WORK/spec-bad.json" 'del(.thresholds)'
if "$STUDY" freeze "$WORK/spec-bad.json" "$WORK/freeze-bad.json" >/dev/null 2>&1; then fail "freeze accepted an incomplete spec"; fi
# a spec that freezes a weaker-than-protocol threshold is rejected
freeze_spec "$BASE" "$WORK/spec-weak.json" '.thresholds.preference = 0.60'
if "$STUDY" freeze "$WORK/spec-weak.json" "$WORK/freeze-weak.json" >/dev/null 2>&1; then fail "freeze accepted a sub-protocol threshold"; fi

# 3. COMPILE the frozen production chain --------------------------------------
STUDY_CERT="$WORK/study-cert.json"
"$STUDY" compile "$FREEZE" "$BASE/manifest.json" "$STUDY_CERT" "$REPO" \
  || fail "study compile rejected the frozen production chain: $(cat "$STUDY_CERT")"
assert_json "$STUDY_CERT" '.schema_version == "taste-study-certificate/v1" and .status == "STUDY-CHAIN-VERIFIED"'
assert_json "$STUDY_CERT" '.claim_label == "HUMAN_CALIBRATED_MACHINE" and .human_certified == false'
assert_json "$STUDY_CERT" '.live_study_executed == false and (.external_prerequisites | length >= 3)'
assert_json "$STUDY_CERT" "(.certificate_sha256 | test(\"^[0-9a-f]{64}$\")) and .subject_revision == \"$SUBJECT\""
assert_json "$STUDY_CERT" '(.verdict_reason_codes | length) == 0'

# 4. NEGATIVE MATRIX — one mutation per trust boundary ------------------------
# (a) v1/fixture calibration in a live deciding role.
A="$WORK/atk"; rm -rf "$A"; cp -R "$BASE" "$A"
jqi "$A/receipts/cal-judge-3-2-a-receipt.json" '.schema_version = "taste-calibration/v1" | del(.session_id)'
jqi "$A/manifest.json" --arg s "$(sha "$A/receipts/cal-judge-3-2-a-receipt.json")" '(.calibrations[] | select(.receipt.path == "receipts/cal-judge-3-2-a-receipt.json") | .receipt.sha256) = $s'
expect_study_blocked cal-v1 "$FREEZE" "$A" "$REPO" CALIBRATION_NOT_PRODUCTION

# (b) fixture-only ballot in a live deciding role.
rm -rf "$A"; cp -R "$BASE" "$A"
jqi "$A/receipts/brief-4-group-1-receipt.json" '.fixture_only = true'
jqi "$A/manifest.json" --arg s "$(sha "$A/receipts/brief-4-group-1-receipt.json")" '.briefs[3].groups[0].receipt.sha256 = $s'
expect_study_blocked ballot-fixture "$FREEZE" "$A" "$REPO" FIXTURE_EVIDENCE

# (c) ballot missing production classification / session ids.
rm -rf "$A"; cp -R "$BASE" "$A"
jqi "$A/receipts/brief-5-group-1-receipt.json" 'del(.classification) | del(.session_ids)'
jqi "$A/manifest.json" --arg s "$(sha "$A/receipts/brief-5-group-1-receipt.json")" '.briefs[4].groups[0].receipt.sha256 = $s'
expect_study_blocked ballot-nonprod "$FREEZE" "$A" "$REPO" BALLOT_NOT_PRODUCTION

# (d) duplicate session id (replayed / shared channel).
rm -rf "$A"; cp -R "$BASE" "$A"
jqi "$A/receipts/brief-2-group-2-receipt.json" '.session_ids = ["bs-1-1-a","bs-1-1-b"]'
jqi "$A/manifest.json" --arg s "$(sha "$A/receipts/brief-2-group-2-receipt.json")" '.briefs[1].groups[1].receipt.sha256 = $s'
expect_study_blocked session-dup "$FREEZE" "$A" "$REPO" LIVE_SESSION_NOT_UNIQUE

# (e) non-production (v1) threat receipt.
rm -rf "$A"; cp -R "$BASE" "$A"
jqi "$A/receipts/threat-receipt.json" '.schema_version = "taste-threat-receipt/v1" | del(.classification)'
jqi "$A/manifest.json" --arg s "$(sha "$A/receipts/threat-receipt.json")" '.threat.receipt.sha256 = $s'
expect_study_blocked threat-nonprod "$FREEZE" "$A" "$REPO" THREAT_NOT_PRODUCTION

# (f) subject drift: manifest subject != frozen current revision.
rm -rf "$A"; cp -R "$BASE" "$A"
jqi "$A/manifest.json" --arg r "$(git -C "$REPO_DRIFT" rev-parse HEAD)" '.subject_revision = $r'
expect_study_blocked subject-drift "$FREEZE" "$A" "$REPO" STUDY_SUBJECT_DRIFT

# (g) corpus drift: corpus content changed after freeze.
rm -rf "$A"; cp -R "$BASE" "$A"
jqi "$A/receipts/corpus-input.json" '.records += [{"id":"rec-3"}]'
jqi "$A/manifest.json" --arg s "$(sha "$A/receipts/corpus-input.json")" '.corpus.input.sha256 = $s'
jqi "$A/receipts/corpus-receipt.json" --arg s "$(sha "$A/receipts/corpus-input.json")" '.input_sha256 = $s | .output.record_count = 3'
jqi "$A/manifest.json" --arg s "$(sha "$A/receipts/corpus-receipt.json")" '.corpus.receipt.sha256 = $s'
expect_study_blocked corpus-drift "$FREEZE" "$A" "$REPO" STUDY_CORPUS_DRIFT

# (h) evidence-prefix drift.
rm -rf "$A"; cp -R "$BASE" "$A"
jqi "$A/manifest.json" '.declared_evidence_paths = ["docs/","src/"]'
expect_study_blocked evidence-drift "$FREEZE" "$A" "$REPO" STUDY_EVIDENCE_DRIFT

# (i) brief-order drift: reorder the frozen brief sequence.
rm -rf "$A"; cp -R "$BASE" "$A"
jqi "$A/manifest.json" '.briefs = [.briefs[1], .briefs[0]] + .briefs[2:]'
expect_study_blocked brief-order "$FREEZE" "$A" "$REPO" STUDY_BRIEF_ORDER_DRIFT

# (j) claim drift: manifest asks for a stronger claim than frozen.
rm -rf "$A"; cp -R "$BASE" "$A"
jqi "$A/manifest.json" '.required_claim = "HUMAN_CERTIFIED"'
expect_study_blocked claim-drift "$FREEZE" "$A" "$REPO" STUDY_CLAIM_DRIFT

# (k) freeze tamper: constants edited after preregistration.
rm -rf "$A"; cp -R "$BASE" "$A"
cp "$FREEZE" "$WORK/freeze-tampered.json"
jqi "$WORK/freeze-tampered.json" '.constants.thresholds.preference = 0.71'
expect_study_blocked freeze-tamper "$WORK/freeze-tampered.json" "$A" "$REPO" FREEZE_BINDING

# (l) undeclared post-freeze *source* commit: subject matches the freeze, but the
# integrator HEAD advanced by a non-evidence commit — delegated ancestry rejects.
rm -rf "$A"; cp -R "$BASE" "$A"
expect_study_blocked undeclared-commit "$FREEZE" "$A" "$REPO_DRIFT" UNDECLARED_POST_EVIDENCE_COMMIT

# (m) threshold drift: a 7/10 chain under a freeze that demands 8 brief wins.
SEVEN="$WORK/seven"; build_live "$SEVEN" "5 5 5 5 5 5 5 2 2 2"
freeze_spec "$SEVEN" "$WORK/spec-eight.json" '.thresholds.brief_wins = 8'
"$STUDY" freeze "$WORK/spec-eight.json" "$WORK/freeze-eight.json" >/dev/null || fail "freeze rejected brief_wins=8"
expect_study_blocked threshold-drift "$WORK/freeze-eight.json" "$SEVEN" "$REPO" STUDY_THRESHOLD_DRIFT
# but the same 7/10 chain verifies under its own faithful freeze
freeze_spec "$SEVEN" "$WORK/spec-seven.json"
"$STUDY" freeze "$WORK/spec-seven.json" "$WORK/freeze-seven.json" >/dev/null || fail "freeze rejected 7/10 spec"
"$STUDY" compile "$WORK/freeze-seven.json" "$SEVEN/manifest.json" "$WORK/seven-study-cert.json" "$REPO" \
  || fail "7/10 frozen chain did not verify: $(cat "$WORK/seven-study-cert.json")"
assert_json "$WORK/seven-study-cert.json" '.status == "STUDY-CHAIN-VERIFIED"'

# (n) single-configuration monoculture fails the >=2 config floor: collapse every
# b-side judge onto the a-side provider/model and re-declare the edited digests.
MONO="$WORK/mono"; rm -rf "$MONO"; cp -R "$BASE" "$MONO"
for f in "$MONO"/receipts/cal-*-b-receipt.json; do
  jqi "$f" '.judge_configuration.provider = "prov-claude" | .judge_configuration.model = "m-one"'
  rel="receipts/$(basename "$f")"
  jqi "$MONO/manifest.json" --arg p "$rel" --arg s "$(sha "$f")" \
    '(.calibrations[] | select(.receipt.path == $p) | .receipt.sha256) = $s'
done
expect_study_blocked mono-config "$FREEZE" "$MONO" "$REPO" STUDY_CONFIG_FLOOR

printf 'PASS: taste study-live compiler\n'
