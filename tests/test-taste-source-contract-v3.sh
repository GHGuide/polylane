#!/usr/bin/env bash
# Hermetic adversarial tests for the Cycle 42A multi-source/calibration v3 lock.
# All records are fixture-grade. No network, provider, or human evidence is created.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
VALIDATOR="$ROOT/bin/polylane-taste-source-contract.sh"
SCHEMA="$ROOT/docs/polylane/taste-certification/contracts/source-calibration-v3.schema.json"
EXAMPLE="$ROOT/docs/polylane/taste-certification/contracts/source-calibration-v3.example.json"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/taste-source-contract-v3.XXXXXX")
cleanup() {
  if [ "${POLYLANE_KEEP_TEST_TMP:-0}" = 1 ]; then
    echo "kept test fixture: $TMP" >&2
  else
    rm -rf "$TMP"
  fi
}
trap cleanup EXIT HUP INT TERM
ASSERTIONS=0

sha_file() { shasum -a 256 "$1" | awk '{print $1}'; }
sha_json() { jq -cS . "$1" | shasum -a 256 | awk '{print $1}'; }

assert_ok() {
  if "$@" >"$TMP/stdout" 2>"$TMP/stderr"; then
    ASSERTIONS=$((ASSERTIONS + 1))
  else
    echo "expected success: $*" >&2
    cat "$TMP/stderr" >&2
    exit 1
  fi
}

assert_fail() {
  if "$@" >"$TMP/stdout" 2>"$TMP/stderr"; then
    echo "expected failure: $*" >&2
    exit 1
  fi
  ASSERTIONS=$((ASSERTIONS + 1))
}

rehash_contract() {
  input_file=$1
  output_file=$2
  scratch_file="$TMP/rehash.json"
  jq 'del(.freeze_sha256)' "$input_file" >"$scratch_file"
  body_sha=$(sha_json "$scratch_file")
  jq --arg sha "$body_sha" '. + {freeze_sha256: $sha}' "$scratch_file" >"$output_file"
}

rehash_all() {
  input_file=$1
  output_file=$2
  scratch_a="$TMP/rehash-all-a.json"
  scratch_b="$TMP/rehash-all-b.json"
  static_sha=$(jq -cS '.static_homepage.selection.records' "$input_file" | shasum -a 256 | awk '{print $1}')
  taste_sha=$(jq -cS '.taste.selection.pairs' "$input_file" | shasum -a 256 | awk '{print $1}')
  hcm_sha=$(jq -cS '.hcm_v2 | {natural_pairs,anchors}' "$input_file" | shasum -a 256 | awk '{print $1}')
  jq --arg ss "$static_sha" --arg ts "$taste_sha" --arg hs "$hcm_sha" '
    .static_homepage.selection.plan_sha256 = $ss
    | .taste.selection.plan_sha256 = $ts
    | .hcm_v2.split_sha256 = $hs
    | del(.freeze_sha256)
  ' "$input_file" >"$scratch_a"
  body_sha=$(sha_json "$scratch_a")
  jq --arg sha "$body_sha" '. + {freeze_sha256: $sha}' "$scratch_a" >"$scratch_b"
  mv "$scratch_b" "$output_file"
}

mutate_rehash() {
  case_name=$1
  jq_filter=$2
  target_file="$TMP/$case_name.json"
  jq "$jq_filter" "$GOOD" >"$TMP/$case_name.body.json"
  rehash_contract "$TMP/$case_name.body.json" "$target_file"
  assert_fail "$VALIDATOR" validate "$target_file"
}

make_fixture() {
  base_file=$1
  zero_sha=0000000000000000000000000000000000000000000000000000000000000000
  jq -n --arg z "$zero_sha" '
    def source_meta($id; $doi; $version; $prefix): {
      source_id:$id, doi:$doi, version:$version,
      image_archive:{file_id:($prefix+"-images"),name:($prefix+"-images.zip"),size:1000,upstream_checksum:{algorithm:"MD5",value:"0123456789abcdef0123456789abcdef"}},
      raw_ratings:{file_id:($prefix+"-raw"),name:($prefix+"-raw.txt"),size:200,upstream_checksum:{algorithm:"MD5",value:"0123456789abcdef0123456789abcdef"},local_sha256:$z},
      compliant_sessions:{file_id:($prefix+"-sessions"),name:($prefix+"-sessions.txt"),size:100,sha256:$z}
    };
    def static_record($i):
      ($i / 84 | floor) as $d
      | ($i % 84) as $within
      | {id:("static-"+($i|tostring)),source_file_id:("file-"+($i|tostring)),
         content_sha256: (("0000000000000000000000000000000000000000000000000000000000000000" + (($i + 1)|tostring))[-64:]),
         declared_size:10,upstream_checksum:{algorithm:"MD5",value:"0123456789abcdef0123456789abcdef"},
         domain:(if $d==0 then "e-commerce" elif $d==1 then "universities" else "commercial-banks" end),
         split:(if $within < 60 then "development" else "holdout" end)};
    def taste_pair($c; $p): {
      pair_id:("taste-pair-"+($c|tostring)+"-"+($p|tostring)), criterion:("criterion-"+($c|tostring)),
      scene_id: (("0000000000000000000000000000000000000000000000000000000000000000" + ((1000 + $c*8 + $p)|tostring))[-64:]), agreement_numerator:4, agreement_denominator:5,
      left:{asset_id:("taste-"+($c|tostring)+"-"+($p|tostring)+"-left"),size:10,upstream_sha256:$z},
      right:{asset_id:("taste-"+($c|tostring)+"-"+($p|tostring)+"-right"),size:11,upstream_sha256:$z}
    };
    def hcm_pair($split; $i; $families): {
      pair_id:("hcm-"+$split+"-"+($i|tostring)), split:$split,
      family_id:($split+"-family-"+(($i % $families)|tostring)),
      brief_lineage:($split+"-brief-"+($i|tostring)), template_id:($split+"-template-"+($i|tostring)),
      asset_pack_id:($split+"-assets-"+($i|tostring)), generation_run_id:($split+"-run-"+($i|tostring)),
      generation_seed:($split+"-seed-"+($i|tostring)), source_example_id:($split+"-example-"+($i|tostring)),
      near_duplicate_cluster_id:($split+"-cluster-"+($i|tostring)),
      gates:{equivalent_content:"required",task:"required",accessibility:"required",provenance:"required"}
    };
    def qualification: {
      position:{unique_pairs:240,calls:480,reversals:6},
      equivalence:{probes:300,self_lineage_selections:150,verbose_candidate_selections:150},
      designer:{decisive_pairs:120,both_mirror_correct:84,wilson_lower_95:0.61,macro_agreement:0.70,
        strata:[range(0;6)|{stratum_id:("stratum-"+(.|tostring)),agreement:0.70}]},
      target_user:{coverage:0.80,brier_skill_lower_95:0.01,calibration_in_large_abs:{A:0.05,TIE:0.05,B:0.05},
        weighted_calibration_error:0.08,weighted_calibration_upper_95:0.12,repeat_stability:0.95,
        orientation_effect_abs:0.05,strata_brier_skill_lower_95:[0.01,0.02,0.03]}
    };
    {
      contract_version:"polylane-source-calibration/v3",
      evidence:{kind:"fixture",claim_ceiling:"AUDIT_ONLY",human_calibrated:false,human_certified:false,taste_certified:false},
      static_homepage:{
        source_id:"STATIC_HOMEPAGE_AE_SANITY_CALIBRATION",authority_ceiling:"STATIC_TRANSFER_ONLY",
        metadata_first:true,bytes_before_freeze:0,outcomes_before_freeze:0,
        releases:[
          source_meta("fashion-homeware";"doi:10.7910/DVN/9FKSQI";"4";"ecom"),
          source_meta("universities";"doi:10.7910/DVN/XOI0HI";"3";"unis"),
          source_meta("commercial-banks";"doi:10.7910/DVN/Z7KLIH";"2.1";"banks")],
        sessions:{filter_version:"publisher-compliance-v1",filtered_before_normalization:true,reassignments:0,raw_ids_sha256:$z,compliant_ids_sha256:$z},
        normalization:{method:"within-source-z-score",clip_valid_z_scores:false,preserve_negative_z_scores:true,probe_z_scores:[-1.25,0,1.5]},
        duplicates:{resolved_before_split:true,banks_b889_b952:{left:"b889.jpg",right:"b952.jpg",decision:"retain_distinct",basis:"distinct-content"},
          unexplained_residual:{status:"UNEXPLAINED",cells:72,max_abs:0.004141}},
        observed:{source_files:3180,jpeg_screenshots:3156,normalized_ratings:{fashion:262,homeware:443,universities:340,commercial_banks:510}},
        selection:{frozen_before_bytes_or_outcomes:true,development_count:180,holdout_count:72,records:[range(0;252)|static_record(.)],plan_sha256:$z}
      },
      taste:{
        source_id:"designer_axis_public_audit/v1",authority_ceiling:"AUDIT_ONLY",can_activate_hcm:false,
        huggingface_revision:"731a7f588d433214c6d864d2e9f47978d91aed6b",github_commit:"e37f02d2e79125bb692b432214928101f026fcc9",
        license:{spdx:"MIT",receipt_sha256:$z},
        observed:{files:654,images:644,total_bytes:1598746498,ranking_rows:14460,prompts:721,evaluators:10},
        metadata_catalog:[
          {name:"assets.parquet",sha256:"326e9300bac89f5ed884de7a9a59dccfc7d5aa203f6d2844f604000dc4e32bf1",stage_a:true},
          {name:"evaluators.parquet",sha256:"1136892daada59c9dc0e54508c1ef6892e60eab12dc492c4ecc19ac27e5c4c7d",stage_a:true},
          {name:"prompts.parquet",sha256:"12c3d2782c61d9ed7a5c84e4615145aa1688c79392c42974b9616b0b2cd1c1b9",stage_a:true},
          {name:"rankings.parquet",sha256:"7a9b57e442577dc296d48321c3cc165da25c59326bd7e5401e13008d475e0ffa",stage_a:true},
          {name:"hallucinations.parquet",sha256:"2f1ed706c1a0ff2cb101afd7c2f47cf0d21fdc0e2a2ef59719e97ae4f1e3efc6",stage_a:true},
          {name:"rankings_with_images.parquet",sha256:"e8719b3b5d4240de0466a6ff3d889d778f65ef179c5abc66859efd2c91797428",stage_a:false},
          {name:"hallucinations_with_images.parquet",sha256:"b48e6c988847372d40400981542ea36f484877dd33cc8f6cf88a388d5c56bf26",stage_a:false}],
        stage_a:{metadata_only:true,download_file_count:5,with_images_downloads:0},
        quarantine:{whole_leakage_units:true,source_613_collision:{prompt_id_src:613,scene_count:2,quarantined:true},
          malformed_eight_asset:{evaluator_cells:10,prompt_criterion_groups:2,quarantined:true},null_linked_rows:{count:20,quarantined:true}},
        scene_identity:{algorithm:"sha256",canonical_expression:"sha256(track || sorted(content_sha256 of all four scene assets))"},
        selection:{outcome_blind:true,frozen_before_stage_b_or_outcomes:true,criteria:[range(0;9)|"criterion-"+(.|tostring)],
          pairs:[range(0;9) as $c|range(0;8)|taste_pair($c;.)],plan_sha256:$z,max_stage_b_images:144}
      },
      ui_judge_source:{status:"UI-JUDGE-SOURCE-UNAVAILABLE",substitution_allowed:false,required_release:"official licensed hash-pinnable release"},
      hcm_v2:{
        source_id:"HCM-v2",authority:"EXTERNAL_TARGET_MATCHED",status:"EXTERNAL-EVIDENCE-OPEN",split_sha256:$z,
        natural_pairs:([range(0;120)|hcm_pair("development";.;15)] + [range(0;40)|hcm_pair("validation";.;5)] + [range(0;160)|hcm_pair("confirmatory";.;20)]),
        anchors:[range(0;32)|{anchor_id:("anchor-"+(.|tostring)),excluded_from_metrics:true}],
        target_users:{judgments_per_pair:80,cells:{desktop_AB:20,desktop_BA:20,mobile_AB:20,mobile_BA:20},min_completed_participants:3200,
          max_natural_pairs_per_participant:8,max_anchors_per_participant:2,pair_repeat_exposures:0,viewports:["1440x900","390x844"]},
        designers:{judgments_per_pair:12,min_credentialed_designers:96,max_pairs_per_designer:40,separate_from_target_user_ballots:true},
        tasks:{routes_per_candidate_min:1,routes_per_candidate_max:3,visawi_s_unmodified:true,choice:"A/B/TIE"},
        governance:{ethics_privacy_determination:"external-required",consent:"external-required",compensation:"external-required",population_frame:"external-required",
          locale_quotas:"external-required",tasks:"external-required",viewports:"external-required",randomization:"external-required",exclusions:"external-required",
          retention:"external-required",withdrawal:"external-required",ballots:"external-required",analysis:"external-required",governance_owner:"external-required"}
      },
      judge_panel:{
        primary_count:5,reserve_count:1,availability_replacement_before_substantive_output_only:true,
        probability_output:{fields:["p_A","p_tie","p_B","abstain"],probabilities_sum_to_one:true},
        configurations:[range(0;6)|{config_id:("config-"+(.|tostring)),role:(if .<5 then "primary" else "availability-reserve" end),
          provider_organization_id:("provider-"+((./2|floor)|tostring)),base_lineage_id:("lineage-"+((./2|floor)|tostring)),
          endpoint_fingerprint:(("0000000000000000000000000000000000000000000000000000000000000000" + ((5000+.)|tostring))[-64:]),verified_base_lineage:true,qualification:qualification}],
        identity_audit:{fresh_instance_ids:true,fresh_session_ids:true,fresh_invocation_ids:true,reused_instance_ids:0,reused_session_ids:0,reused_invocation_ids:0},
        self_lineage_exclusion:{required:true,violations:0},retry_policy:{infrastructure_retry_max:1,infrastructure_retries_used:1,fresh_session_on_retry:true,both_attempt_receipts:true,substantive_retries:0},
        correlation:{method:"empirical-error-clustering",bootstrap_replicates:10000,merge_identical_error_vectors:true,capa_lower_95_threshold:0.75,
          double_fault_independence_multiplier:2,holm_p_max:0.01,phi_bound:"upper-95",n_eff:3.0,eligible_nonabstaining_clusters:3,strict_majority_min:3}
      },
      resources:{
        external_calls:{planned:10000,manifest_derived_ceiling:10000,used:9999,infrastructure_retries_used:5,infrastructure_retry_ceiling:6,substantive_retries_used:0},
        storage:{capacity_bytes:10737418240,retained_cas_bytes:1073741824,remaining_selected_bound_bytes:1073741824,max_active_stage_bytes:1073741824,
          safety_floor_bytes:5368709120,source_bytes:1000,source_bytes_ceiling:1000,staging_bytes:500,staging_bytes_ceiling:500,
          quarantine_bytes:100,quarantine_bytes_ceiling:100,retained_bytes:1073741824,retained_bytes_ceiling:1073741824},
        immutable_cas:{content_addressed_original_bytes:true,orientations_reference_not_copy:true,pixels_byte_exact:true,deterministic_gzip_only:true,
          decompression_digest_required:true,atomic_read_only_publication:true,cleanup_unreferenced_staging_only:true,claim_ancestors_pinned:true}
      }
    }
  ' >"$base_file"
}

BASE="$TMP/base.json"
GOOD="$TMP/good.json"
make_fixture "$BASE"
rehash_all "$BASE" "$GOOD"

# Happy path and the statistical requirement that legitimate negative z-scores survive.
assert_ok "$VALIDATOR" validate "$GOOD"
assert_ok jq -e '."$schema" == "https://json-schema.org/draft/2020-12/schema" and ."$id" == "https://polylane.local/contracts/source-calibration-v3.schema.json"' "$SCHEMA"
assert_ok "$VALIDATOR" validate "$EXAMPLE"
jq -e '.static_homepage.normalization.probe_z_scores | any(. < 0)' "$GOOD" >/dev/null
ASSERTIONS=$((ASSERTIONS + 1))

# Static-source provenance, session, normalization, duplicate, quota, and freeze locks.
mutate_rehash sessions-laundering '.static_homepage.sessions.reassignments = 1'
mutate_rehash zscore-clipping '.static_homepage.normalization.clip_valid_z_scores = true'
mutate_rehash duplicate-leakage '.static_homepage.selection.records[1].content_sha256 = .static_homepage.selection.records[0].content_sha256'
mutate_rehash source-quota-shortage '.static_homepage.selection.records |= .[0:251]'
mutate_rehash observed-pin-drift '.static_homepage.observed.jpeg_screenshots = 3155'
mutate_rehash duplicate-decision-drift '.static_homepage.duplicates.banks_b889_b952.decision = "merge"'

# Internal selection hash catches late replacement even if the outer body is rehashed.
mutate_rehash late-replacement '.static_homepage.selection.records[0].id = "replacement-after-results"'

# Outer hash catches ordinary post-result mutation.
jq '.taste.observed.images = 643' "$GOOD" >"$TMP/post-result.json"
assert_fail "$VALIDATOR" validate "$TMP/post-result.json"

# TASTE source pins, quarantine, selection quota, scene disjointness, and authority ceiling.
mutate_rehash taste-source-613 '.taste.quarantine.source_613_collision.quarantined = false'
mutate_rehash taste-malformed-cell '.taste.quarantine.malformed_eight_asset.evaluator_cells = 9'
mutate_rehash taste-null-linked '.taste.quarantine.null_linked_rows.count = 19'
mutate_rehash taste-quota '.taste.selection.pairs |= .[0:71]'
mutate_rehash taste-scene-leakage '.taste.selection.pairs[1].scene_id = .taste.selection.pairs[0].scene_id'
mutate_rehash taste-with-images-stage-a '.taste.metadata_catalog[5].stage_a = true | .taste.stage_a.download_file_count = 6 | .taste.stage_a.with_images_downloads = 1'
mutate_rehash public-authority-escalation '.taste.authority_ceiling = "HUMAN_CALIBRATED_MACHINE" | .taste.can_activate_hcm = true'
mutate_rehash ui-judge-substitution '.ui_judge_source.substitution_allowed = true'

# HCM-v2 population, governance, family leakage, and repeat-exposure locks.
mutate_rehash missing-consent '.hcm_v2.governance.consent = ""'
mutate_rehash missing-governance '.hcm_v2.governance.governance_owner = ""'
mutate_rehash participant-repeat '.hcm_v2.target_users.pair_repeat_exposures = 1'
mutate_rehash hcm-family-leakage '.hcm_v2.natural_pairs[120].brief_lineage = .hcm_v2.natural_pairs[0].brief_lineage'
mutate_rehash hcm-count '.hcm_v2.natural_pairs |= .[0:319]'

# Provider/lineage independence, identities, retry, position/equivalence, and designer gates.
mutate_rehash provider-alias '.judge_panel.configurations[1].provider_alias = "provider-1"'
mutate_rehash lineage-alias '.judge_panel.configurations[1].lineage_alias = "lineage-1"'
mutate_rehash lineage-cap '.judge_panel.configurations[4].base_lineage_id = "lineage-0"'
mutate_rehash provider-count '.judge_panel.configurations[4].provider_organization_id = "provider-0" | .judge_panel.configurations[5].provider_organization_id = "provider-0"'
mutate_rehash neff-shortfall '.judge_panel.correlation.n_eff = 2.99'
mutate_rehash position-seven '.judge_panel.configurations[0].qualification.position.reversals = 7'
mutate_rehash equivalence-self-low '.judge_panel.configurations[0].qualification.equivalence.self_lineage_selections = 134'
mutate_rehash equivalence-verbose-high '.judge_panel.configurations[0].qualification.equivalence.verbose_candidate_selections = 166'
mutate_rehash designer-83 '.judge_panel.configurations[0].qualification.designer.both_mirror_correct = 83'
mutate_rehash id-reuse '.judge_panel.identity_audit.reused_session_ids = 1'
mutate_rehash self-lineage '.judge_panel.self_lineage_exclusion.violations = 1'
mutate_rehash substantive-retry '.judge_panel.retry_policy.substantive_retries = 1'

# Target-user probabilistic boundaries from the research lock.
mutate_rehash coverage-shortfall '.judge_panel.configurations[0].qualification.target_user.coverage = 0.799'
mutate_rehash brier-nonpositive '.judge_panel.configurations[0].qualification.target_user.brier_skill_lower_95 = 0'
mutate_rehash calibration-large '.judge_panel.configurations[0].qualification.target_user.calibration_in_large_abs.A = 0.051'
mutate_rehash weighted-calibration '.judge_panel.configurations[0].qualification.target_user.weighted_calibration_error = 0.081'
mutate_rehash weighted-upper '.judge_panel.configurations[0].qualification.target_user.weighted_calibration_upper_95 = 0.121'
mutate_rehash repeat-stability '.judge_panel.configurations[0].qualification.target_user.repeat_stability = 0.949'
mutate_rehash orientation-effect '.judge_panel.configurations[0].qualification.target_user.orientation_effect_abs = 0.051'
mutate_rehash stratum-brier '.judge_panel.configurations[0].qualification.target_user.strata_brier_skill_lower_95[0] = 0'

# Every resource limit accepts equality and rejects one-unit overflow.
jq '.resources.external_calls.used = .resources.external_calls.manifest_derived_ceiling' "$GOOD" >"$TMP/calls-eq.body"
rehash_contract "$TMP/calls-eq.body" "$TMP/calls-eq.json"
assert_ok "$VALIDATOR" validate "$TMP/calls-eq.json"
mutate_rehash calls-over '.resources.external_calls.used = .resources.external_calls.manifest_derived_ceiling + 1'
jq '.resources.external_calls.infrastructure_retries_used = .resources.external_calls.infrastructure_retry_ceiling' "$GOOD" >"$TMP/retries-eq.body"
rehash_contract "$TMP/retries-eq.body" "$TMP/retries-eq.json"
assert_ok "$VALIDATOR" validate "$TMP/retries-eq.json"
mutate_rehash retries-over '.resources.external_calls.infrastructure_retries_used = .resources.external_calls.infrastructure_retry_ceiling + 1'
jq '.resources.storage.max_active_stage_bytes = (.resources.storage.capacity_bytes - .resources.storage.retained_cas_bytes - .resources.storage.remaining_selected_bound_bytes - .resources.storage.safety_floor_bytes)' "$GOOD" >"$TMP/storage-eq.body"
rehash_contract "$TMP/storage-eq.body" "$TMP/storage-eq.json"
assert_ok "$VALIDATOR" validate "$TMP/storage-eq.json"
mutate_rehash storage-over '.resources.storage.max_active_stage_bytes = (.resources.storage.capacity_bytes - .resources.storage.retained_cas_bytes - .resources.storage.remaining_selected_bound_bytes - .resources.storage.safety_floor_bytes + 1)'
mutate_rehash source-byte-over '.resources.storage.source_bytes = .resources.storage.source_bytes_ceiling + 1'
mutate_rehash staging-byte-over '.resources.storage.staging_bytes = .resources.storage.staging_bytes_ceiling + 1'
mutate_rehash quarantine-byte-over '.resources.storage.quarantine_bytes = .resources.storage.quarantine_bytes_ceiling + 1'
mutate_rehash retained-byte-over '.resources.storage.retained_bytes = .resources.storage.retained_bytes_ceiling + 1'

# Stage B validates selected reachability plus declared size, upstream checksum,
# local SHA-256, and frozen split identity; partial receipts never imply complete evidence.
printf '%s' 'selected-image-bytes' >"$TMP/selected-image.bin"
selected_size=$(wc -c <"$TMP/selected-image.bin" | tr -d ' ')
selected_sha=$(sha_file "$TMP/selected-image.bin")
jq --arg sha "$selected_sha" --argjson size "$selected_size" '
  .taste.selection.pairs[0].left.upstream_sha256 = $sha
  | .taste.selection.pairs[0].left.size = $size
' "$GOOD" >"$TMP/stage-contract.body"
rehash_all "$TMP/stage-contract.body" "$TMP/stage-contract.json"
selection_sha=$(jq -r '.taste.selection.plan_sha256' "$TMP/stage-contract.json")
jq -n --arg plan "$selection_sha" --arg sha "$selected_sha" --argjson size "$selected_size" --arg root "$TMP/selected-image.bin" '
  {receipt_version:"taste-stage-b-receipt/v3",source_id:"designer_axis_public_audit/v1",selection_plan_sha256:$plan,complete:false,
   files:[{asset_id:"taste-0-0-left",local_path:$root,declared_size:$size,upstream_sha256:$sha,local_sha256:$sha,split_identity:"criterion-0/taste-pair-0-0"}]}
' >"$TMP/stage-receipt.json"
assert_ok "$VALIDATOR" verify-stage-b "$TMP/stage-contract.json" "$TMP/stage-receipt.json"

jq '.files[0].asset_id = "unselected-asset"' "$TMP/stage-receipt.json" >"$TMP/unselected-receipt.json"
assert_fail "$VALIDATOR" verify-stage-b "$TMP/stage-contract.json" "$TMP/unselected-receipt.json"
jq '.files[0].local_sha256 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"' "$TMP/stage-receipt.json" >"$TMP/checksum-receipt.json"
assert_fail "$VALIDATOR" verify-stage-b "$TMP/stage-contract.json" "$TMP/checksum-receipt.json"
jq '.files[0].split_identity = "criterion-8/taste-pair-8-7"' "$TMP/stage-receipt.json" >"$TMP/split-receipt.json"
assert_fail "$VALIDATOR" verify-stage-b "$TMP/stage-contract.json" "$TMP/split-receipt.json"
jq '.selection_plan_sha256 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"' "$TMP/stage-receipt.json" >"$TMP/plan-receipt.json"
assert_fail "$VALIDATOR" verify-stage-b "$TMP/stage-contract.json" "$TMP/plan-receipt.json"

echo "ok - taste-source-contract-v3 ($ASSERTIONS assertions)"
