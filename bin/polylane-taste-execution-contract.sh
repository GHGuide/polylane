#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s validate|fingerprint MANIFEST.json\n' "${0##*/}" >&2
  printf '       %s run-mode-vocabulary\n' "${0##*/}" >&2
  printf '       %s run-mode-transition FROM TO\n' "${0##*/}" >&2
  exit 64
}

reject() {
  printf 'INVALID %s\n' "$1" >&2
  exit 1
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    reject SHA256_UNAVAILABLE
  fi
}

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    reject SHA256_UNAVAILABLE
  fi
}

# c42b-run-mode-vocabulary-mismatch: one vocabulary means one source. The frozen
# CONTRACT-LOCK.v3.json lifecycle block is that source, so the run-mode states
# and transitions are read from it here and never restated in this file — a
# second copy is exactly how the producer, validator, storage, and lifecycle
# boundaries drifted apart.
contract_lock() {
  lock_dir=$(CDPATH="" cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
  printf '%s/docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json' "$lock_dir"
}

run_mode_vocabulary() {
  command -v jq >/dev/null 2>&1 || reject JQ_UNAVAILABLE
  lock=$(contract_lock)
  [ -f "$lock" ] && [ ! -L "$lock" ] || reject CONTRACT_LOCK_UNAVAILABLE
  states=$(jq -r '.lifecycle.authoritative_sequence[]?' "$lock" 2>/dev/null) || reject CONTRACT_LOCK_UNREADABLE
  [ -n "$states" ] || reject CONTRACT_LOCK_UNREADABLE
  printf '%s\n' "$states"
}

run_mode_transition() {
  from=$1
  to=$2
  vocabulary=$(run_mode_vocabulary)
  for state in "$from" "$to"; do
    grep -Fqx -- "$state" <<<"$vocabulary" || reject RUN_MODE_VOCABULARY
  done
  lock=$(contract_lock)
  transitions=$(jq -r '.lifecycle.allowed_transitions[]?' "$lock" 2>/dev/null) || reject CONTRACT_LOCK_UNREADABLE
  grep -Fqx -- "$from->$to" <<<"$transitions" || reject RUN_MODE_TRANSITION
  printf 'RUN-MODE-OK %s->%s\n' "$from" "$to"
}

check_jq() {
  code=$1
  filter=$2
  file=$3
  jq -e "$filter" "$file" >/dev/null 2>&1 || reject "$code"
}

validate() {
  file=$1
  [ -f "$file" ] && [ ! -L "$file" ] || reject UNSAFE_INPUT
  command -v jq >/dev/null 2>&1 || reject JQ_UNAVAILABLE
  jq -e . "$file" >/dev/null 2>&1 || reject INVALID_JSON

  canonical=$(mktemp "${TMPDIR:-/tmp}/polylane-execution-v3.XXXXXX")
  trap 'rm -f "$canonical"' EXIT HUP INT TERM
  jq -S -c . "$file" > "$canonical"
  cmp -s "$file" "$canonical" || reject NONCANONICAL_JSON

  check_jq SCHEMA_VERSION '.schema_version == "taste-execution-contract/v3" and .contract_id == "polylane-taste-execution-v3"' "$file"

  check_jq UNKNOWN_KEYS '
    def exact($wanted): (keys | sort) == ($wanted | sort);
    exact(["ancestry","arms","brief_units","builds","captures","consents","contract_id","directions","governance_receipts","human_ballots","human_studies","judge_responses","model_configs","participants","preregistration","prompt_policy","prompts","requests","schema_version","source_cohorts","stimuli"])
    and (.preregistration | exact(["frozen_at","independent_brief_count","independent_unit","preregistration_id","split_keys","split_manifest_sha256"]))
    and (.prompt_policy | exact(["compiled_to_delivered","consumed_proof","delivery_mode","mutation_after_lock","policy_id","policy_sha256","source_to_compiled"]))
    and all(.source_cohorts[]; exact(["cohort_id","immutable_revision","manifest_sha256","revision_sha256","source_id"]))
    and all(.brief_units[]; exact(["asset_pack_id","brief_bytes_sha256","brief_family_id","brief_id","category","generation_run_id","generation_seed_id","source_cohort_id","source_example_id","source_revision_sha256","split","template_id","visual_cluster_id"]))
    and all(.directions[]; exact(["brief_id","direction_bytes_sha256","direction_lock_id","locked_at","reference_packet_sha256","selected_direction_id"]))
    and all(.model_configs[]; exact(["base_lineage_id","capabilities_sha256","config_fingerprint_sha256","config_id","effort","endpoint_id","model_revision","model_snapshot","profile_sha256","provider_org_id","role"]))
    and all(.arms[]; exact(["arm_id","compute","label","model_config_id","prompt_id"]) and (.compute | exact(["browser_sha256","build_replicates","network","references_sha256","repairs","sandbox_sha256","seed_policy_sha256","skills_sha256","token_budget","tools_sha256"])))
    and all(.prompts[]; exact(["arm_id","compiled","consumed_stdin","delivered","prompt_id","source","stdin_adapter"])
      and (.source | exact(["byte_count","sha256"])) and (.compiled | exact(["byte_count","sha256"]))
      and (.delivered | exact(["byte_count","sha256"])) and (.consumed_stdin | exact(["byte_count","sha256"]))
      and (.stdin_adapter | exact(["adapter_binary_sha256","adapter_id","delivered_sha256","exit_status","invocation_id","proof_kind","receipt_sha256","request_receipt_sha256","stdin_byte_count","stdin_sha256"])))
    and all(.requests[]; exact(["arm_id","brief_id","consumed_prompt_sha256","contract_lock_sha256","direction_lock_id","input_assets_sha256","model_config_fingerprint_sha256","prompt_id","provider_receipt","replicate_id","request_bytes_sha256","request_id","source_revision_sha256","stdin_adapter_receipt_sha256"])
      and (.provider_receipt | exact(["endpoint_id","model_revision","model_snapshot","provider_org_id","receipt_sha256","signature_sha256"])))
    and all(.builds[]; exact(["arm_id","build_id","build_receipt_sha256","candidate_tree_sha256","generation_run_id","produced_artifact_sha256","replicate_id","request_id","request_receipt_sha256","seed_id","status"]))
    and all(.captures[]; exact(["action_trace_sha256","browser_adapter_receipt_sha256","browser_profile_sha256","build_id","candidate_tree_sha256","capture_id","captured_at","decoded_pixel_sha256","dom_sha256","route","screenshot_png_sha256","state_id","viewport","viewport_id"])
      and (.viewport | exact(["device_pixel_ratio","height","width"])))
    and all(.stimuli[]; exact(["blinding_map_sha256","brief_id","capture_a_ids","capture_b_ids","orientation","stimulus_bytes_sha256","stimulus_id"]))
    and all(.judge_responses[]; exact(["config_id","invocation_id","judge_instance_id","parser_sha256","probabilities","raw_response_sha256","receipt_sha256","response_id","session_id","stimulus_id","substantive"])
      and (.probabilities | exact(["a","abstain","b","tie"])))
    and all(.human_studies[]; exact(["analysis_plan_sha256","max_natural_pairs_per_participant","population_frame_sha256","protocol_sha256","required_orientations","required_viewports","split","study_id","study_revision","unique_pair_exposure"]))
    and all(.participants[]; exact(["eligibility_receipt_sha256","participant_id","pseudonym_sha256","roster_receipt_sha256","study_id","target_role"]))
    and all(.consents[]; exact(["consent_form_sha256","consent_receipt_id","consented_at","participant_id","signed_receipt_sha256","study_id","withdrawn"]))
    and all(.governance_receipts[]; exact(["approval_revision","approval_status","ethics_review_id","governance_receipt_id","receipt_sha256","study_id"]))
    and all(.human_ballots[]; exact(["ballot_bytes_sha256","ballot_id","brief_id","choice","confidence","orientation","participant_id","sealed_at","stimulus_id","study_id","viewport_id"]))
    and (.ancestry | exact(["edges","nodes","root_ids"]))
    and all(.ancestry.edges[]; exact(["child_id","parent_id"]))
  ' "$file"

  check_jq MISSING_HASH '
    def hex: type == "string" and test("^[0-9a-f]{64}$");
    [.. | objects | to_entries[] | select(.key | endswith("sha256")) | .value] as $hashes
    | ($hashes | length > 0) and all($hashes[]; hex)
  ' "$file"

  check_jq SCHEMA_SHAPE '
    def id: type == "string" and test("^[a-z][a-z0-9]*(?:-[a-z0-9]+)+$") and (contains("..") | not) and (contains("/") | not);
    (.preregistration.preregistration_id | id)
    and (.preregistration.frozen_at | type == "string" and test("Z$"))
    and (.preregistration.independent_unit == "brief-lineage")
    and (.preregistration.split_keys == ["brief_family_id","template_id","asset_pack_id","generation_run_id","generation_seed_id","source_example_id","visual_cluster_id"])
    and (.prompt_policy.policy_id | id)
    and (.prompt_policy.delivery_mode == "stdin")
    and (.prompt_policy.consumed_proof == "stdin-byte-counted-receipt")
    and (.prompt_policy.mutation_after_lock == "forbidden")
    and (.source_cohorts | type == "array" and length > 0 and all(.[]; (.cohort_id|id) and (.source_id|id)))
    and (.brief_units | type == "array" and length > 0 and all(.[]; (.brief_id|id) and (.split|IN("smoke","development","validation","confirmatory","hcm-development","hcm-validation","hcm-confirmatory"))))
    and all(.directions[]; (.direction_lock_id|id) and (.brief_id|id))
    and all(.model_configs[]; (.config_id|id) and (.role|IN("build","judge")) and (.effort|IN("low","medium","high","xhigh")))
    and (.arms | type == "array" and length == 2 and ([.[].label] | sort) == ["baseline","current"])
    and all(.arms[]; (.arm_id|id) and (.compute.build_replicates|type=="number") and (.compute.token_budget|type=="number") and (.compute.repairs|type=="number"))
    and all(.prompts[]; (.prompt_id|id) and all([.source.byte_count,.compiled.byte_count,.delivered.byte_count,.consumed_stdin.byte_count][]; type=="number" and .>0))
    and all(.requests[]; (.request_id|id) and (.replicate_id|id))
    and all(.builds[]; (.build_id|id) and (.status == "produced"))
    and all(.captures[]; (.capture_id|id) and (.route|type=="string" and startswith("/")) and (.viewport.width>0) and (.viewport.height>0) and (.viewport.device_pixel_ratio>0))
    and all(.stimuli[]; (.stimulus_id|id) and (.orientation|IN("AB","BA")) and (.capture_a_ids|length>0) and (.capture_b_ids|length>0))
    and all(.judge_responses[]; (.response_id|id) and (.config_id|id))
    and all(.human_studies[]; (.study_id|id) and .unique_pair_exposure == true and .max_natural_pairs_per_participant <= 8)
    and all(.participants[]; (.participant_id|id))
    and all(.consents[]; (.consent_receipt_id|id))
    and all(.governance_receipts[]; (.governance_receipt_id|id))
    and all(.human_ballots[]; (.ballot_id|id) and (.choice|IN("A","TIE","B")) and (.confidence>=0 and .confidence<=1))
  ' "$file"

  check_jq DUPLICATE_ID '
    ([.preregistration.preregistration_id,.prompt_policy.policy_id]
      + [.source_cohorts[].cohort_id,.brief_units[].brief_id,.directions[].direction_lock_id,.model_configs[].config_id,.arms[].arm_id,.prompts[].prompt_id,.requests[].request_id,.builds[].build_id,.captures[].capture_id,.stimuli[].stimulus_id,.judge_responses[].response_id,.human_studies[].study_id,.participants[].participant_id,.consents[].consent_receipt_id,.governance_receipts[].governance_receipt_id,.human_ballots[].ballot_id]) as $ids
    | ($ids | length) == ($ids | unique | length)
  ' "$file"

  check_jq INDEPENDENT_UNIT_COUNT '
    .preregistration.independent_brief_count == (.brief_units | length)
    and ([.brief_units[].brief_id] | length == (unique | length))
  ' "$file"

  check_jq SPLIT_LEAKAGE '
    . as $root | .brief_units as $b
    | [range(0; $b|length)] | all(.[]; . as $i |
        [range($i+1; $b|length)] | all(.[]; . as $j |
          ($b[$i].split == $b[$j].split)
          or all($root.preregistration.split_keys[]; . as $k | $b[$i][$k] != $b[$j][$k])))
  ' "$file"

  check_jq STALE_SOURCE_REVISION '
    .source_cohorts as $sources
    | all(.brief_units[]; . as $brief
        | any($sources[]; .cohort_id == $brief.source_cohort_id
          and .revision_sha256 == $brief.source_revision_sha256
          and (.immutable_revision | test("^[0-9a-f]{40,64}$"))))
  ' "$file"

  while IFS=$(printf '\t') read -r revision declared; do
    [ "$(printf '%s' "$revision" | sha256_stdin)" = "$declared" ] || reject SOURCE_REVISION_DIGEST
  done < <(jq -r '.source_cohorts[] | [.immutable_revision,.revision_sha256] | @tsv' "$file")

  check_jq STALE_MODEL_REVISION '
    . as $root | .model_configs as $configs
    | all(.requests[]; . as $request
        | (.arm_id as $arm | first($root.arms[] | select(.arm_id == $arm))) as $a
        | first($configs[] | select(.config_id == $a.model_config_id)) as $config
        | $request.model_config_fingerprint_sha256 == $config.config_fingerprint_sha256
          and $request.provider_receipt.model_revision == $config.model_revision
          and ($config.model_revision | test("^[0-9a-f]{16,64}$")))
  ' "$file"

  check_jq SELF_LINEAGE_JUDGE '
    . as $root
    | all(.judge_responses[]; . as $response
      | first($root.model_configs[] | select(.config_id==$response.config_id and .role=="judge")) as $judge
      | first($root.stimuli[] | select(.stimulus_id==$response.stimulus_id)) as $stimulus
      | all(($stimulus.capture_a_ids + $stimulus.capture_b_ids)[]; . as $capture_id |
          first($root.captures[] | select(.capture_id==$capture_id)) as $capture
          | first($root.builds[] | select(.build_id==$capture.build_id)) as $build
          | first($root.arms[] | select(.arm_id==$build.arm_id)) as $arm
          | first($root.model_configs[] | select(.config_id==$arm.model_config_id)) as $builder
          | $judge.base_lineage_id != $builder.base_lineage_id))
  ' "$file"

  while IFS= read -r config; do
    declared=$(printf '%s' "$config" | jq -r '.config_fingerprint_sha256')
    body=$(printf '%s' "$config" | jq -S -c 'del(.config_fingerprint_sha256)')
    [ "$(printf '%s' "$body" | sha256_stdin)" = "$declared" ] || reject MODEL_CONFIG_FINGERPRINT
  done < <(jq -c '.model_configs[]' "$file")

  check_jq ARM_INEQUALITY '
    (.arms[0].compute == .arms[1].compute)
    and (.arms[0].compute.build_replicates == 3)
    and (.arms[0].compute.repairs == 0)
    and (.arms[0].model_config_id == .arms[1].model_config_id)
  ' "$file"

  check_jq PROMPT_HASH_DISCONTINUITY '
    all(.prompts[]; .delivered.sha256 == .consumed_stdin.sha256
      and .delivered.byte_count == .consumed_stdin.byte_count
      and .stdin_adapter.delivered_sha256 == .delivered.sha256
      and .stdin_adapter.stdin_sha256 == .consumed_stdin.sha256
      and .stdin_adapter.stdin_byte_count == .consumed_stdin.byte_count)
  ' "$file"

  check_jq STDIN_PROOF_REQUIRED '
    all(.prompts[]; .stdin_adapter.proof_kind == "stdin-byte-counted"
      and .stdin_adapter.adapter_id == "polylane-stdin-adapter/v1")
  ' "$file"

  check_jq FORGED_RECEIPT '
    all(.prompts[]; .stdin_adapter.exit_status == 0)
    and all(.requests[]; .provider_receipt.receipt_sha256 != .provider_receipt.signature_sha256)
  ' "$file"

  # c42b-missing-consumed-stdin-proof: matching digests are only proof if the
  # receipt binding them is an independent, single-use attestation. A receipt
  # shared by two deliveries attests neither, and a receipt that merely restates
  # the bytes, the request receipt, or the adapter binary attests nothing.
  check_jq CONSUMED_STDIN_PROOF '
    ([.prompts[].stdin_adapter.invocation_id] | length == (unique | length))
    and ([.prompts[].stdin_adapter.receipt_sha256] | length == (unique | length))
    and all(.prompts[]; .stdin_adapter as $adapter
      | ([$adapter.delivered_sha256,$adapter.stdin_sha256,$adapter.request_receipt_sha256,$adapter.adapter_binary_sha256]
         | index($adapter.receipt_sha256)) == null)
  ' "$file"

  check_jq REQUEST_PROMPT_MISMATCH '
    .prompts as $prompts
    | all(.requests[]; . as $request
      | any($prompts[]; .prompt_id == $request.prompt_id and .arm_id == $request.arm_id
        and .consumed_stdin.sha256 == $request.consumed_prompt_sha256))
  ' "$file"

  check_jq REQUEST_ADAPTER_MISMATCH '
    .prompts as $prompts
    | all(.requests[]; . as $request
      | any($prompts[]; .prompt_id == $request.prompt_id
        and .stdin_adapter.receipt_sha256 == $request.stdin_adapter_receipt_sha256
        and .stdin_adapter.request_receipt_sha256 == $request.request_bytes_sha256))
  ' "$file"

  check_jq PROVIDER_SUBSTITUTION '
    . as $root | .model_configs as $configs
    | all(.requests[]; . as $request
      | (.arm_id as $arm | first($root.arms[] | select(.arm_id == $arm))) as $a
      | first($configs[] | select(.config_id == $a.model_config_id)) as $config
      | $request.provider_receipt.provider_org_id == $config.provider_org_id
        and $request.provider_receipt.endpoint_id == $config.endpoint_id
        and $request.provider_receipt.model_snapshot == $config.model_snapshot)
  ' "$file"

  check_jq SOURCE_REQUEST_MISMATCH '
    .brief_units as $briefs
    | all(.requests[]; . as $request
      | any($briefs[]; .brief_id==$request.brief_id and .source_revision_sha256==$request.source_revision_sha256))
  ' "$file"

  check_jq REFERENCE_MISMATCH '
    . as $root
    | all(.directions[]; . as $direction | any($root.brief_units[]; .brief_id==$direction.brief_id))
    and all(.arms[]; . as $arm
      | any($root.model_configs[]; .config_id==$arm.model_config_id and .role=="build")
      and any($root.prompts[]; .prompt_id==$arm.prompt_id and .arm_id==$arm.arm_id))
    and all(.requests[]; . as $request
      | any($root.brief_units[]; .brief_id==$request.brief_id)
      and any($root.arms[]; .arm_id==$request.arm_id and .prompt_id==$request.prompt_id)
      and any($root.directions[]; .direction_lock_id==$request.direction_lock_id and .brief_id==$request.brief_id))
    and all(.stimuli[]; . as $stimulus
      | all((.capture_a_ids + .capture_b_ids)[]; . as $capture_id
          | first($root.captures[] | select(.capture_id==$capture_id)) as $capture
          | first($root.builds[] | select(.build_id==$capture.build_id)) as $build
          | any($root.requests[]; .request_id==$build.request_id and .brief_id==$stimulus.brief_id)))
    and all(.judge_responses[]; . as $response
      | any($root.stimuli[]; .stimulus_id==$response.stimulus_id)
      and any($root.model_configs[]; .config_id==$response.config_id and .role=="judge"))
  ' "$file"

  check_jq BUILD_CARDINALITY '
    . as $root
    | all(.brief_units[].brief_id; . as $brief |
        all($root.arms[].arm_id; . as $arm |
          ([ $root.requests[] | select(.brief_id==$brief and .arm_id==$arm) ] | length) == 3
          and ([ $root.requests[] | select(.brief_id==$brief and .arm_id==$arm) | .replicate_id ] | unique | length) == 3
          and ([ $root.builds[] as $build | $root.requests[]
                  | select(.brief_id==$brief and .arm_id==$arm and .request_id==$build.request_id
                    and .replicate_id==$build.replicate_id and .arm_id==$build.arm_id) ] | length) == 3))
    and all(.builds[]; . as $build | any($root.requests[]; .request_id==$build.request_id
      and .request_bytes_sha256==$build.request_receipt_sha256 and .arm_id==$build.arm_id and .replicate_id==$build.replicate_id))
  ' "$file"

  check_jq ARTIFACT_CHAIN_MISMATCH '
    .builds as $builds
    | all(.captures[]; . as $capture | any($builds[]; .build_id==$capture.build_id
      and .candidate_tree_sha256==$capture.candidate_tree_sha256))
  ' "$file"

  check_jq MIRROR_MISMATCH '
    .stimuli | group_by(.brief_id)
    | all(.[]; . as $group
      | ($group | map(select(.orientation=="AB"))[0]) as $ab
      | ($group | map(select(.orientation=="BA"))[0]) as $ba
      | ($group|length) == 2 and ([$group[].orientation]|sort)==["AB","BA"]
      and ($ab.capture_a_ids|sort)==($ba.capture_b_ids|sort)
      and ($ab.capture_b_ids|sort)==($ba.capture_a_ids|sort))
  ' "$file"

  check_jq PROBABILITY_SUM '
    all(.judge_responses[]; .probabilities as $p
      | all([$p.a,$p.tie,$p.b,$p.abstain][]; type=="number" and .>=0 and .<=1)
      and ((([$p.a,$p.tie,$p.b,$p.abstain]|add) - 1) | fabs) < 0.000000001)
  ' "$file"

  check_jq DUPLICATE_MEASUREMENT_ID '
    ([.judge_responses[].judge_instance_id] | length == (unique|length))
    and ([.judge_responses[].session_id] | length == (unique|length))
    and ([.judge_responses[].invocation_id] | length == (unique|length))
  ' "$file"

  check_jq DUPLICATE_PARTICIPANT_EXPOSURE '
    [.human_ballots[] | [.participant_id,.brief_id] | join("|")] as $exposures
    | ($exposures|length) == ($exposures|unique|length)
  ' "$file"

  check_jq BALLOT_BINDING '
    . as $root
    | all(.human_ballots[]; . as $ballot
      | any($root.participants[]; .participant_id==$ballot.participant_id and .study_id==$ballot.study_id)
      and any($root.human_studies[]; .study_id==$ballot.study_id and (.required_viewports|index($ballot.viewport_id))!=null)
      and any($root.stimuli[]; .stimulus_id==$ballot.stimulus_id and .brief_id==$ballot.brief_id and .orientation==$ballot.orientation))
  ' "$file"

  check_jq CONSENT_REQUIRED '
    . as $root
    | all(.human_ballots[]; . as $ballot
      | any($root.consents[]; .participant_id==$ballot.participant_id and .study_id==$ballot.study_id and .withdrawn==false))
  ' "$file"

  check_jq GOVERNANCE_REQUIRED '
    . as $root
    | all(.human_ballots[]; . as $ballot
      | any($root.governance_receipts[]; .study_id==$ballot.study_id and .approval_status=="approved"))
  ' "$file"

  check_jq ANCESTRY_CYCLE '
    .ancestry.edges as $edges
    | def reaches($from;$target;$seen):
        if ($seen|index($from)) != null then false
        elif $from == $target then true
        else any($edges[] | select(.parent_id==$from); reaches(.child_id;$target;($seen+[$from]))) end;
      all($edges[]; (reaches(.child_id;.parent_id;[]) | not))
  ' "$file"

  check_jq INCOMPLETE_ANCESTRY '
    ([.preregistration.preregistration_id,.prompt_policy.policy_id]
      + [.source_cohorts[].cohort_id,.brief_units[].brief_id,.directions[].direction_lock_id,.model_configs[].config_id,.arms[].arm_id,.prompts[].prompt_id,.requests[].request_id,.builds[].build_id,.captures[].capture_id,.stimuli[].stimulus_id,.judge_responses[].response_id,.human_studies[].study_id,.participants[].participant_id,.consents[].consent_receipt_id,.governance_receipts[].governance_receipt_id,.human_ballots[].ballot_id] | sort) as $expected
    | (.ancestry.nodes|sort) == $expected
    and (.ancestry.nodes|length)==(.ancestry.nodes|unique|length)
    and all(.ancestry.edges[]; (.parent_id as $p | .child_id as $c | ($expected|index($p))!=null and ($expected|index($c))!=null))
    and ([.ancestry.edges[] | [.parent_id,.child_id]|join("|")] | length == (unique|length))
    and ([.ancestry.nodes[] as $n | select([.ancestry.edges[].child_id]|index($n)==null) | $n]|sort) == (.ancestry.root_ids|sort)
    and (. as $root | .ancestry.edges as $edges
      | def edge($parent;$child): any($edges[]; .parent_id==$parent and .child_id==$child);
        edge($root.preregistration.preregistration_id;$root.prompt_policy.policy_id)
        and all($root.source_cohorts[]; . as $source | edge($root.preregistration.preregistration_id;$source.cohort_id))
        and all($root.brief_units[]; . as $brief | edge($brief.source_cohort_id;$brief.brief_id))
        and all($root.directions[]; . as $direction | edge($direction.brief_id;$direction.direction_lock_id))
        and all($root.model_configs[]; . as $config | edge($root.preregistration.preregistration_id;$config.config_id))
        and all($root.arms[]; . as $arm | edge($arm.model_config_id;$arm.arm_id))
        and all($root.prompts[]; . as $prompt | edge($root.prompt_policy.policy_id;$prompt.prompt_id) and edge($prompt.arm_id;$prompt.prompt_id))
        and all($root.requests[]; . as $request
          | edge($request.brief_id;$request.request_id)
          and edge($request.arm_id;$request.request_id)
          and edge($request.prompt_id;$request.request_id)
          and edge($request.direction_lock_id;$request.request_id))
        and all($root.builds[]; . as $build | edge($build.request_id;$build.build_id))
        and all($root.captures[]; . as $capture | edge($capture.build_id;$capture.capture_id))
        and all($root.stimuli[]; . as $stimulus
          | all((.capture_a_ids + .capture_b_ids)[]; . as $capture_id | edge($capture_id;$stimulus.stimulus_id)))
        and all($root.judge_responses[]; . as $response | edge($response.config_id;$response.response_id) and edge($response.stimulus_id;$response.response_id))
        and all($root.human_studies[]; . as $study | edge($root.preregistration.preregistration_id;$study.study_id))
        and all($root.participants[]; . as $participant | edge($participant.study_id;$participant.participant_id))
        and all($root.consents[]; . as $consent | edge($consent.study_id;$consent.consent_receipt_id) and edge($consent.participant_id;$consent.consent_receipt_id))
        and all($root.governance_receipts[]; . as $governance | edge($governance.study_id;$governance.governance_receipt_id))
        and all($root.human_ballots[]; . as $ballot
          | edge($ballot.study_id;$ballot.ballot_id)
          and edge($ballot.participant_id;$ballot.ballot_id)
          and edge($ballot.brief_id;$ballot.ballot_id)
          and edge($ballot.stimulus_id;$ballot.ballot_id)
          and any($root.consents[]; .participant_id==$ballot.participant_id and edge(.consent_receipt_id;$ballot.ballot_id))
          and any($root.governance_receipts[]; .study_id==$ballot.study_id and edge(.governance_receipt_id;$ballot.ballot_id))))
  ' "$file"

  rm -f "$canonical"
  trap - EXIT HUP INT TERM
  printf 'VALID execution-v3 %s\n' "$(sha256_file "$file")"
}

main() {
  [ "$#" -ge 1 ] || usage
  command_name=$1
  shift
  case $command_name in
    validate)
      [ "$#" -eq 1 ] || usage
      validate "$1"
      ;;
    fingerprint)
      [ "$#" -eq 1 ] || usage
      validate "$1" >/dev/null
      sha256_file "$1"
      ;;
    run-mode-vocabulary)
      [ "$#" -eq 0 ] || usage
      run_mode_vocabulary
      ;;
    run-mode-transition)
      [ "$#" -eq 2 ] || usage
      run_mode_transition "$1" "$2"
      ;;
    *) usage ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
