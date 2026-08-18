#!/usr/bin/env bash
# Fail-closed validator for the Cycle 42A source/calibration v3 trust boundary.
# It is hermetic: validation consumes caller-supplied JSON and local Stage B bytes;
# it never downloads a source, calls a provider, recruits a participant, or upgrades
# fixture/public evidence into HUMAN_CALIBRATED_MACHINE or human certification.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage:
  polylane-taste-source-contract.sh validate CONTRACT.json
  polylane-taste-source-contract.sh verify-stage-b CONTRACT.json RECEIPT.json

validate verifies the immutable multi-source, HCM-v2, judge-calibration, and
resource contract. verify-stage-b first validates the contract, then verifies
that every receipted local byte is reachable from the frozen selected plan and
matches declared size, upstream checksum, local SHA-256, and split identity.
USAGE
}

invalid() { echo "SOURCE-CONTRACT-V3-INVALID: $*" >&2; exit 1; }

require_tools() {
  command -v jq >/dev/null 2>&1 || invalid "jq is required"
  command -v shasum >/dev/null 2>&1 || invalid "shasum is required"
}

sha_file() { shasum -a 256 "$1" | awk '{print $1}'; }
sha_json_filter() { jq -cS "$2" "$1" | shasum -a 256 | awk '{print $1}'; }

regular_json() {
  input_file=$1
  label=$2
  [ -f "$input_file" ] && [ ! -L "$input_file" ] || invalid "$label is not a regular non-symlink file: $input_file"
  jq -e . "$input_file" >/dev/null 2>&1 || invalid "$label is not valid JSON: $input_file"
  duplicate_paths=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("/")' "$input_file" 2>/dev/null \
    | LC_ALL=C sort | uniq -d)
  [ -z "$duplicate_paths" ] || invalid "$label contains duplicate JSON keys"
}

validate_envelope() {
  contract_file=$1
  jq -e '
    def exact($ks): (keys | sort) == ($ks | sort);
    def sha: type == "string" and test("^[0-9a-f]{64}$");
    type == "object"
    and exact(["contract_version","evidence","freeze_sha256","hcm_v2","judge_panel","resources","static_homepage","taste","ui_judge_source"])
    and .contract_version == "polylane-source-calibration/v3"
    and (.freeze_sha256 | sha)
    and (.evidence | type == "object"
      and exact(["claim_ceiling","human_calibrated","human_certified","kind","taste_certified"])
      and .kind == "fixture"
      and .claim_ceiling == "AUDIT_ONLY"
      and .human_calibrated == false
      and .human_certified == false
      and .taste_certified == false)
  ' "$contract_file" >/dev/null 2>&1 || invalid "envelope or fixture authority ceiling drift"

  claimed_sha=$(jq -r '.freeze_sha256' "$contract_file")
  actual_sha=$(sha_json_filter "$contract_file" 'del(.freeze_sha256)')
  [ "$claimed_sha" = "$actual_sha" ] || invalid "post-result mutation: freeze_sha256 does not bind the canonical contract body"
}

validate_static() {
  contract_file=$1
  jq -e '
    def exact($ks): (keys | sort) == ($ks | sort);
    def sha: type == "string" and test("^[0-9a-f]{64}$");
    def stable: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    def posint: type == "number" and . == floor and . > 0;
    def checksum:
      type == "object" and exact(["algorithm","value"])
      and ((.algorithm == "MD5" and (.value | test("^[0-9a-f]{32}$")))
        or (.algorithm == "SHA-256" and (.value | sha)));
    .static_homepage as $s
    | ($s | type == "object"
      and exact(["authority_ceiling","bytes_before_freeze","duplicates","metadata_first","normalization","observed","outcomes_before_freeze","releases","selection","sessions","source_id"])
      and .source_id == "STATIC_HOMEPAGE_AE_SANITY_CALIBRATION"
      and .authority_ceiling == "STATIC_TRANSFER_ONLY"
      and .metadata_first == true and .bytes_before_freeze == 0 and .outcomes_before_freeze == 0
      and (.releases | type == "array" and length == 3)
      and ([.releases[] | [.doi,.version]] | sort == ([
        ["doi:10.7910/DVN/9FKSQI","4"],
        ["doi:10.7910/DVN/XOI0HI","3"],
        ["doi:10.7910/DVN/Z7KLIH","2.1"]] | sort))
      and all(.releases[];
        type == "object" and exact(["compliant_sessions","doi","image_archive","raw_ratings","source_id","version"])
        and (.source_id | stable) and (.doi | type == "string" and startswith("doi:")) and (.version | type == "string" and length > 0)
        and (.image_archive | type == "object" and exact(["file_id","name","size","upstream_checksum"])
          and (.file_id | stable) and (.name | stable) and (.size | posint) and (.upstream_checksum | checksum))
        and (.raw_ratings | type == "object" and exact(["file_id","local_sha256","name","size","upstream_checksum"])
          and (.file_id | stable) and (.name | stable) and (.size | posint) and (.upstream_checksum | checksum) and (.local_sha256 | sha))
        and (.compliant_sessions | type == "object" and exact(["file_id","name","sha256","size"])
          and (.file_id | stable) and (.name | stable) and (.size | posint) and (.sha256 | sha)))
      and (.sessions | type == "object" and exact(["compliant_ids_sha256","filter_version","filtered_before_normalization","raw_ids_sha256","reassignments"])
        and (.filter_version | stable) and .filtered_before_normalization == true and .reassignments == 0
        and (.raw_ids_sha256 | sha) and (.compliant_ids_sha256 | sha))
      and (.normalization | type == "object" and exact(["clip_valid_z_scores","method","preserve_negative_z_scores","probe_z_scores"])
        and .method == "within-source-z-score" and .clip_valid_z_scores == false and .preserve_negative_z_scores == true
        and (.probe_z_scores | type == "array" and length > 0 and all(.[]; type == "number") and any(.[]; . < 0)))
      and (.duplicates | type == "object" and exact(["banks_b889_b952","resolved_before_split","unexplained_residual"])
        and .resolved_before_split == true
        and (.banks_b889_b952 == {left:"b889.jpg",right:"b952.jpg",decision:"retain_distinct",basis:"distinct-content"})
        and (.unexplained_residual == {status:"UNEXPLAINED",cells:72,max_abs:0.004141}))
      and (.observed == {source_files:3180,jpeg_screenshots:3156,normalized_ratings:{fashion:262,homeware:443,universities:340,commercial_banks:510}})
      and (.selection | type == "object" and exact(["development_count","frozen_before_bytes_or_outcomes","holdout_count","plan_sha256","records"])
        and .frozen_before_bytes_or_outcomes == true and .development_count == 180 and .holdout_count == 72 and (.plan_sha256 | sha)
        and (.records | type == "array" and length == 252)
        and all(.records[]; . as $record
          | type == "object" and exact(["content_sha256","declared_size","domain","id","source_file_id","split","upstream_checksum"])
          and (.id | stable) and (.source_file_id | stable) and (.content_sha256 | sha) and (.declared_size | posint)
          and (.upstream_checksum | checksum)
          and (["e-commerce","universities","commercial-banks"] | index($record.domain) != null)
          and (["development","holdout"] | index($record.split) != null))
        and ([.records[].id] | length == (unique | length))
        and ([.records[].source_file_id] | length == (unique | length))
        and ([.records[].content_sha256] | length == (unique | length))
        and ([.records[] | select(.split == "development")] | length == 180)
        and ([.records[] | select(.split == "holdout")] | length == 72)))
    and all(["e-commerce","universities","commercial-banks"][]; . as $domain
      | ([$s.selection.records[] | select(.domain == $domain and .split == "development")] | length == 60)
      and ([$s.selection.records[] | select(.domain == $domain and .split == "holdout")] | length == 24))
  ' "$contract_file" >/dev/null 2>&1 || invalid "STATIC_HOMEPAGE_AE_SANITY_CALIBRATION provenance, session, normalization, anomaly, or 252-record split contract drift"

  claimed_plan=$(jq -r '.static_homepage.selection.plan_sha256' "$contract_file")
  actual_plan=$(sha_json_filter "$contract_file" '.static_homepage.selection.records')
  [ "$claimed_plan" = "$actual_plan" ] || invalid "static selection was replaced after its identities were frozen"
}

validate_taste() {
  contract_file=$1
  jq -e '
    def exact($ks): (keys | sort) == ($ks | sort);
    def sha: type == "string" and test("^[0-9a-f]{64}$");
    def stable: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    def posint: type == "number" and . == floor and . > 0;
    [
      {name:"assets.parquet",sha256:"326e9300bac89f5ed884de7a9a59dccfc7d5aa203f6d2844f604000dc4e32bf1",stage_a:true},
      {name:"evaluators.parquet",sha256:"1136892daada59c9dc0e54508c1ef6892e60eab12dc492c4ecc19ac27e5c4c7d",stage_a:true},
      {name:"prompts.parquet",sha256:"12c3d2782c61d9ed7a5c84e4615145aa1688c79392c42974b9616b0b2cd1c1b9",stage_a:true},
      {name:"rankings.parquet",sha256:"7a9b57e442577dc296d48321c3cc165da25c59326bd7e5401e13008d475e0ffa",stage_a:true},
      {name:"hallucinations.parquet",sha256:"2f1ed706c1a0ff2cb101afd7c2f47cf0d21fdc0e2a2ef59719e97ae4f1e3efc6",stage_a:true},
      {name:"rankings_with_images.parquet",sha256:"e8719b3b5d4240de0466a6ff3d889d778f65ef179c5abc66859efd2c91797428",stage_a:false},
      {name:"hallucinations_with_images.parquet",sha256:"b48e6c988847372d40400981542ea36f484877dd33cc8f6cf88a388d5c56bf26",stage_a:false}
    ] as $catalog
    | .taste as $t
    | ($t | type == "object"
      and exact(["authority_ceiling","can_activate_hcm","github_commit","huggingface_revision","license","metadata_catalog","observed","quarantine","scene_identity","selection","source_id","stage_a"])
      and .source_id == "designer_axis_public_audit/v1"
      and .authority_ceiling == "AUDIT_ONLY" and .can_activate_hcm == false
      and .huggingface_revision == "731a7f588d433214c6d864d2e9f47978d91aed6b"
      and .github_commit == "e37f02d2e79125bb692b432214928101f026fcc9"
      and (.license | type == "object" and exact(["receipt_sha256","spdx"]) and .spdx == "MIT" and (.receipt_sha256 | sha))
      and (.observed == {files:654,images:644,total_bytes:1598746498,ranking_rows:14460,prompts:721,evaluators:10})
      and (.metadata_catalog | sort_by(.name) == ($catalog | sort_by(.name)))
      and (.stage_a == {metadata_only:true,download_file_count:5,with_images_downloads:0})
      and (.quarantine | type == "object" and exact(["malformed_eight_asset","null_linked_rows","source_613_collision","whole_leakage_units"])
        and .whole_leakage_units == true
        and .source_613_collision == {prompt_id_src:613,scene_count:2,quarantined:true}
        and .malformed_eight_asset == {evaluator_cells:10,prompt_criterion_groups:2,quarantined:true}
        and .null_linked_rows == {count:20,quarantined:true})
      and (.scene_identity == {algorithm:"sha256",canonical_expression:"sha256(track || sorted(content_sha256 of all four scene assets))"})
      and (.selection | type == "object" and exact(["criteria","frozen_before_stage_b_or_outcomes","max_stage_b_images","outcome_blind","pairs","plan_sha256"])
        and .outcome_blind == true and .frozen_before_stage_b_or_outcomes == true and .max_stage_b_images == 144 and (.plan_sha256 | sha)
        and (.criteria | type == "array" and length == 9 and length == (unique | length) and all(.[]; stable))
        and (.pairs | type == "array" and length == 72)
        and (.criteria as $criteria | all(.pairs[]; . as $pair
          | type == "object" and exact(["agreement_denominator","agreement_numerator","criterion","left","pair_id","right","scene_id"])
          and (.pair_id | stable) and (.scene_id | sha) and ($criteria | index($pair.criterion) != null)
          and .agreement_denominator == 5 and .agreement_numerator >= 4 and .agreement_numerator <= 5
          and all([.left,.right][];
            type == "object" and exact(["asset_id","size","upstream_sha256"])
            and (.asset_id | stable) and (.size | posint) and (.upstream_sha256 | sha))))
        and ([.pairs[].pair_id] | length == (unique | length))
        and ([.pairs[].scene_id] | length == (unique | length))
        and ([.pairs[] | .left.asset_id,.right.asset_id] | length == 144 and length == (unique | length))))
    and all($t.selection.criteria[]; . as $criterion
      | ([$t.selection.pairs[] | select(.criterion == $criterion)] | length == 8))
  ' "$contract_file" >/dev/null 2>&1 || invalid "TASTE revision, metadata-only Stage A, quarantine, scene, 9x8 quota, or audit-only authority drift"

  claimed_plan=$(jq -r '.taste.selection.plan_sha256' "$contract_file")
  actual_plan=$(sha_json_filter "$contract_file" '.taste.selection.pairs')
  [ "$claimed_plan" = "$actual_plan" ] || invalid "TASTE selected pair plan was replaced after freeze"
}

validate_hcm() {
  contract_file=$1
  jq -e '
    def exact($ks): (keys | sort) == ($ks | sort);
    def sha: type == "string" and test("^[0-9a-f]{64}$");
    def stable: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    .ui_judge_source == {status:"UI-JUDGE-SOURCE-UNAVAILABLE",substitution_allowed:false,required_release:"official licensed hash-pinnable release"}
    and (.hcm_v2 as $h
      | ($h | type == "object"
        and exact(["anchors","authority","designers","governance","natural_pairs","source_id","split_sha256","status","target_users","tasks"])
        and .source_id == "HCM-v2" and .authority == "EXTERNAL_TARGET_MATCHED" and .status == "EXTERNAL-EVIDENCE-OPEN" and (.split_sha256 | sha)
        and (.natural_pairs | type == "array" and length == 320)
        and all(.natural_pairs[]; . as $pair
          | type == "object" and exact(["asset_pack_id","brief_lineage","family_id","gates","generation_run_id","generation_seed","near_duplicate_cluster_id","pair_id","source_example_id","split","template_id"])
          and (.pair_id | stable) and (.family_id | stable)
          and all([.brief_lineage,.template_id,.asset_pack_id,.generation_run_id,.generation_seed,.source_example_id,.near_duplicate_cluster_id][]; stable)
          and (["development","validation","confirmatory"] | index($pair.split) != null)
          and .gates == {equivalent_content:"required",task:"required",accessibility:"required",provenance:"required"})
        and ([.natural_pairs[].pair_id] | length == (unique | length))
        and ([.natural_pairs[].brief_lineage] | length == (unique | length))
        and ([.natural_pairs[].template_id] | length == (unique | length))
        and ([.natural_pairs[].asset_pack_id] | length == (unique | length))
        and ([.natural_pairs[].generation_run_id] | length == (unique | length))
        and ([.natural_pairs[].generation_seed] | length == (unique | length))
        and ([.natural_pairs[].source_example_id] | length == (unique | length))
        and ([.natural_pairs[].near_duplicate_cluster_id] | length == (unique | length))
        and ([.natural_pairs[] | select(.split == "development")] | length == 120)
        and ([.natural_pairs[] | select(.split == "validation")] | length == 40)
        and ([.natural_pairs[] | select(.split == "confirmatory")] | length == 160)
        and ([.natural_pairs[] | select(.split == "development") | .family_id] | unique | length == 15)
        and ([.natural_pairs[] | select(.split == "validation") | .family_id] | unique | length == 5)
        and ([.natural_pairs[] | select(.split == "confirmatory") | .family_id] | unique | length == 20)
        and ([.natural_pairs | group_by(.family_id)[] | ([.[].split] | unique | length)] | all(. == 1))
        and (.anchors | type == "array" and length == 32 and all(.[];
          type == "object" and exact(["anchor_id","excluded_from_metrics"]) and (.anchor_id | stable) and .excluded_from_metrics == true))
        and ([.anchors[].anchor_id] | length == (unique | length))
        and (.target_users | type == "object"
          and exact(["cells","judgments_per_pair","max_anchors_per_participant","max_natural_pairs_per_participant","min_completed_participants","pair_repeat_exposures","viewports"])
          and .judgments_per_pair == 80 and .cells == {desktop_AB:20,desktop_BA:20,mobile_AB:20,mobile_BA:20}
          and .min_completed_participants >= 3200 and .max_natural_pairs_per_participant == 8 and .max_anchors_per_participant == 2
          and .pair_repeat_exposures == 0 and (.viewports | sort == (["1440x900","390x844"] | sort)))
        and (.designers == {judgments_per_pair:12,min_credentialed_designers:96,max_pairs_per_designer:40,separate_from_target_user_ballots:true})
        and (.tasks == {routes_per_candidate_min:1,routes_per_candidate_max:3,visawi_s_unmodified:true,choice:"A/B/TIE"})
        and (.governance | type == "object"
          and exact(["analysis","ballots","compensation","consent","ethics_privacy_determination","exclusions","governance_owner","locale_quotas","population_frame","randomization","retention","tasks","viewports","withdrawal"])
          and all(.[]; type == "string" and length > 0))))
  ' "$contract_file" >/dev/null 2>&1 || invalid "UI-JUDGE unavailable marker or HCM-v2 320+32 target-user/designer/governance contract drift"

  claimed_split=$(jq -r '.hcm_v2.split_sha256' "$contract_file")
  actual_split=$(sha_json_filter "$contract_file" '.hcm_v2 | {natural_pairs,anchors}')
  [ "$claimed_split" = "$actual_split" ] || invalid "HCM-v2 split identities changed after reservation"
}

validate_judges() {
  contract_file=$1
  jq -e '
    def exact($ks): (keys | sort) == ($ks | sort);
    def sha: type == "string" and test("^[0-9a-f]{64}$");
    def stable: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    .judge_panel as $j
    | ($j | type == "object"
      and exact(["availability_replacement_before_substantive_output_only","configurations","correlation","identity_audit","primary_count","probability_output","reserve_count","retry_policy","self_lineage_exclusion"])
      and .primary_count == 5 and .reserve_count == 1 and .availability_replacement_before_substantive_output_only == true
      and .probability_output == {fields:["p_A","p_tie","p_B","abstain"],probabilities_sum_to_one:true}
      and (.configurations | type == "array" and length == 6)
      and ([.configurations[] | select(.role == "primary")] | length == 5)
      and ([.configurations[] | select(.role == "availability-reserve")] | length == 1)
      and ([.configurations[].config_id] | length == (unique | length))
      and ([.configurations[].endpoint_fingerprint] | length == (unique | length))
      and ([.configurations[].provider_organization_id] | unique | length >= 3)
      and ([.configurations[].base_lineage_id] | unique | length >= 3)
      and ([.configurations | group_by(.base_lineage_id)[] | length] | all(. <= 2))
      and all(.configurations[];
        type == "object" and exact(["base_lineage_id","config_id","endpoint_fingerprint","provider_organization_id","qualification","role","verified_base_lineage"])
        and (.config_id | stable) and (.provider_organization_id | stable) and (.base_lineage_id | stable)
        and (.endpoint_fingerprint | sha) and .verified_base_lineage == true
        and (.qualification | type == "object" and exact(["designer","equivalence","position","target_user"])
          and (.position | type == "object" and exact(["calls","reversals","unique_pairs"])
            and .unique_pairs == 240 and .calls == 480 and .reversals >= 0 and .reversals <= 6)
          and (.equivalence | type == "object" and exact(["probes","self_lineage_selections","verbose_candidate_selections"])
            and .probes == 300 and .self_lineage_selections >= 135 and .self_lineage_selections <= 165
            and .verbose_candidate_selections >= 135 and .verbose_candidate_selections <= 165)
          and (.designer | type == "object" and exact(["both_mirror_correct","decisive_pairs","macro_agreement","strata","wilson_lower_95"])
            and .decisive_pairs == 120 and .both_mirror_correct >= 84 and .both_mirror_correct <= 120
            and .wilson_lower_95 > 0.60 and .macro_agreement >= 0.70
            and (.strata | type == "array" and length == 6 and all(.[];
              type == "object" and exact(["agreement","stratum_id"]) and (.stratum_id | stable) and .agreement >= 0.60))
            and ([.strata[].stratum_id] | length == (unique | length)))
          and (.target_user | type == "object"
            and exact(["brier_skill_lower_95","calibration_in_large_abs","coverage","orientation_effect_abs","repeat_stability","strata_brier_skill_lower_95","weighted_calibration_error","weighted_calibration_upper_95"])
            and .coverage >= 0.80 and .brier_skill_lower_95 > 0
            and (.calibration_in_large_abs | type == "object" and exact(["A","B","TIE"]) and all(.[]; type == "number" and . <= 0.05))
            and .weighted_calibration_error <= 0.08 and .weighted_calibration_upper_95 <= 0.12
            and .repeat_stability >= 0.95 and .orientation_effect_abs <= 0.05
            and (.strata_brier_skill_lower_95 | type == "array" and length > 0 and all(.[]; type == "number" and . > 0)))))
      and (.identity_audit == {fresh_instance_ids:true,fresh_session_ids:true,fresh_invocation_ids:true,reused_instance_ids:0,reused_session_ids:0,reused_invocation_ids:0})
      and (.self_lineage_exclusion == {required:true,violations:0})
      and (.retry_policy == {infrastructure_retry_max:1,infrastructure_retries_used:1,fresh_session_on_retry:true,both_attempt_receipts:true,substantive_retries:0})
      and (.correlation | type == "object"
        and exact(["bootstrap_replicates","capa_lower_95_threshold","double_fault_independence_multiplier","eligible_nonabstaining_clusters","holm_p_max","merge_identical_error_vectors","method","n_eff","phi_bound","strict_majority_min"])
        and .method == "empirical-error-clustering" and .bootstrap_replicates == 10000 and .merge_identical_error_vectors == true
        and .capa_lower_95_threshold == 0.75 and .double_fault_independence_multiplier == 2 and .holm_p_max == 0.01
        and .phi_bound == "upper-95" and .n_eff >= 3.0 and .eligible_nonabstaining_clusters >= 3 and .strict_majority_min >= 3))
  ' "$contract_file" >/dev/null 2>&1 || invalid "judge provider/lineage, identity, retry, bias, designer, probabilistic, or correlation contract drift"
}

validate_resources() {
  contract_file=$1
  jq -e '
    def exact($ks): (keys | sort) == ($ks | sort);
    def nonnegint: type == "number" and . == floor and . >= 0;
    .resources | type == "object" and exact(["external_calls","immutable_cas","storage"])
    and (.external_calls | type == "object"
      and exact(["infrastructure_retries_used","infrastructure_retry_ceiling","manifest_derived_ceiling","planned","substantive_retries_used","used"])
      and all([.planned,.manifest_derived_ceiling,.used,.infrastructure_retries_used,.infrastructure_retry_ceiling,.substantive_retries_used][]; nonnegint)
      and .planned <= .manifest_derived_ceiling and .used <= .manifest_derived_ceiling
      and .infrastructure_retries_used <= .infrastructure_retry_ceiling and .substantive_retries_used == 0)
    and (.storage | type == "object"
      and exact(["capacity_bytes","max_active_stage_bytes","quarantine_bytes","quarantine_bytes_ceiling","remaining_selected_bound_bytes","retained_bytes","retained_bytes_ceiling","retained_cas_bytes","safety_floor_bytes","source_bytes","source_bytes_ceiling","staging_bytes","staging_bytes_ceiling"])
      and all(.[]; nonnegint)
      and .safety_floor_bytes == 5368709120
      and (.retained_cas_bytes + .remaining_selected_bound_bytes + .max_active_stage_bytes + .safety_floor_bytes) <= .capacity_bytes
      and .source_bytes <= .source_bytes_ceiling
      and .staging_bytes <= .staging_bytes_ceiling
      and .quarantine_bytes <= .quarantine_bytes_ceiling
      and .retained_bytes <= .retained_bytes_ceiling)
    and (.immutable_cas == {content_addressed_original_bytes:true,orientations_reference_not_copy:true,pixels_byte_exact:true,deterministic_gzip_only:true,
      decompression_digest_required:true,atomic_read_only_publication:true,cleanup_unreferenced_staging_only:true,claim_ancestors_pinned:true})
  ' "$contract_file" >/dev/null 2>&1 || invalid "call, retry, storage, staging, quarantine, retention, or immutable-CAS ceiling exceeded"
}

validate_contract() {
  contract_file=$1
  regular_json "$contract_file" contract
  validate_envelope "$contract_file"
  validate_static "$contract_file"
  validate_taste "$contract_file"
  validate_hcm "$contract_file"
  validate_judges "$contract_file"
  validate_resources "$contract_file"
}

verify_stage_b_file() {
  contract_file=$1
  source_id=$2
  receipt_record=$3
  asset_id=$(jq -r '.asset_id' "$receipt_record")
  local_path=$(jq -r '.local_path' "$receipt_record")
  [ -f "$local_path" ] && [ ! -L "$local_path" ] || invalid "Stage B local_path is not a regular non-symlink file for $asset_id"

  if [ "$source_id" = "designer_axis_public_audit/v1" ]; then
    expected=$(jq -c --arg id "$asset_id" '
      [.taste.selection.pairs[] as $p
        | if $p.left.asset_id == $id then {size:$p.left.size,upstream_sha256:$p.left.upstream_sha256,split_identity:($p.criterion+"/"+$p.pair_id)}
          elif $p.right.asset_id == $id then {size:$p.right.size,upstream_sha256:$p.right.upstream_sha256,split_identity:($p.criterion+"/"+$p.pair_id)}
          else empty end]
      | if length == 1 then .[0] else empty end
    ' "$contract_file")
    [ -n "$expected" ] || invalid "unselected TASTE download: $asset_id"
    jq -e --argjson expected "$expected" '
      .declared_size == $expected.size
      and .upstream_sha256 == $expected.upstream_sha256
      and .local_sha256 == $expected.upstream_sha256
      and .split_identity == $expected.split_identity
    ' "$receipt_record" >/dev/null 2>&1 || invalid "TASTE Stage B size, checksum, or frozen split mismatch for $asset_id"
  else
    expected=$(jq -c --arg id "$asset_id" '
      [.static_homepage.selection.records[] | select(.id == $id)
        | {size:.declared_size,upstream_checksum:.upstream_checksum,local_sha256:.content_sha256,split_identity:(.domain+"/"+.split)}]
      | if length == 1 then .[0] else empty end
    ' "$contract_file")
    [ -n "$expected" ] || invalid "unselected static-source download: $asset_id"
    jq -e --argjson expected "$expected" '
      .declared_size == $expected.size
      and .upstream_checksum == $expected.upstream_checksum
      and .local_sha256 == $expected.local_sha256
      and .split_identity == $expected.split_identity
    ' "$receipt_record" >/dev/null 2>&1 || invalid "static Stage B size, checksum, or frozen split mismatch for $asset_id"
  fi

  declared_size=$(jq -r '.declared_size' "$receipt_record")
  actual_size=$(wc -c <"$local_path" | tr -d ' ')
  [ "$declared_size" = "$actual_size" ] || invalid "Stage B declared size drift for $asset_id"
  claimed_local=$(jq -r '.local_sha256' "$receipt_record")
  actual_local=$(sha_file "$local_path")
  [ "$claimed_local" = "$actual_local" ] || invalid "Stage B local SHA-256 drift for $asset_id"
}

verify_stage_b() {
  contract_file=$1
  receipt_file=$2
  validate_contract "$contract_file"
  regular_json "$receipt_file" "Stage B receipt"

  source_id=$(jq -r '.source_id // empty' "$receipt_file")
  case "$source_id" in
    designer_axis_public_audit/v1)
      expected_plan=$(jq -r '.taste.selection.plan_sha256' "$contract_file")
      file_keys='["asset_id","declared_size","local_path","local_sha256","split_identity","upstream_sha256"]'
      complete_count=144
      ;;
    STATIC_HOMEPAGE_AE_SANITY_CALIBRATION)
      expected_plan=$(jq -r '.static_homepage.selection.plan_sha256' "$contract_file")
      file_keys='["asset_id","declared_size","local_path","local_sha256","split_identity","upstream_checksum"]'
      complete_count=252
      ;;
    *) invalid "Stage B source_id is not a frozen selectable source" ;;
  esac

  jq -e --arg source "$source_id" --arg plan "$expected_plan" --argjson file_keys "$file_keys" --argjson complete_count "$complete_count" '
    def exact($ks): (keys | sort) == ($ks | sort);
    def sha: type == "string" and test("^[0-9a-f]{64}$");
    def stable: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    type == "object" and exact(["complete","files","receipt_version","selection_plan_sha256","source_id"])
    and .receipt_version == "taste-stage-b-receipt/v3" and .source_id == $source and .selection_plan_sha256 == $plan
    and (.complete | type == "boolean")
    and (.files | type == "array" and length > 0)
    and (if .complete then (.files | length == $complete_count) else true end)
    and all(.files[];
      type == "object" and exact($file_keys) and (.asset_id | stable)
      and (.declared_size | type == "number" and . == floor and . > 0)
      and (.local_path | type == "string" and length > 0 and test("^[^\\r\\n]+$"))
      and (.local_sha256 | sha) and (.split_identity | type == "string" and length > 0))
    and ([.files[].asset_id] | length == (unique | length))
    and ([.files[].local_path] | length == (unique | length))
  ' "$receipt_file" >/dev/null 2>&1 || invalid "Stage B receipt shape, selection plan, completeness, or identity uniqueness drift"

  records_file=$(mktemp "${TMPDIR:-/tmp}/taste-stage-b-records.XXXXXX")
  trap 'rm -f "$records_file"' EXIT HUP INT TERM
  jq -c '.files[]' "$receipt_file" >"$records_file"
  while IFS= read -r receipt_record; do
    record_file=$(mktemp "${TMPDIR:-/tmp}/taste-stage-b-record.XXXXXX")
    printf '%s\n' "$receipt_record" >"$record_file"
    verify_stage_b_file "$contract_file" "$source_id" "$record_file"
    rm -f "$record_file"
  done <"$records_file"
  rm -f "$records_file"
  trap - EXIT HUP INT TERM
}

main() {
  require_tools
  [ $# -ge 1 ] || { usage >&2; exit 2; }
  command_name=$1
  shift
  case "$command_name" in
    validate)
      [ $# -eq 1 ] || { usage >&2; exit 2; }
      validate_contract "$1"
      echo "SOURCE-CONTRACT-V3-OK: fixture-grade contract is structurally valid; no live evidence or certification was created"
      ;;
    verify-stage-b)
      [ $# -eq 2 ] || { usage >&2; exit 2; }
      verify_stage_b "$1" "$2"
      echo "SOURCE-CONTRACT-V3-STAGE-B-OK: selected local bytes match the frozen receipt; evidence authority is unchanged"
      ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
