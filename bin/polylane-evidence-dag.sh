#!/usr/bin/env bash
# polylane-evidence-dag.sh — executable evidence-policy v3 trust engine.
#
# The engine is hermetic. It validates content-addressed evidence DAGs, derives
# least-trusted transitive grades, applies scoped claim ceilings, and checks the
# frozen final-benchmark, prompt-promotion, and genericness contracts. It never
# upgrades fixtures or public diagnostics and never emits human certification.
# Bash 3.2 safe: no associative arrays and no process substitution.
set -euo pipefail

POLICY_SHA256="8ff293fa72cc32ae52c3bf40a82fd4e67d06a2e24b534b0a323b97bd1cc5d7ee"

usage() {
  cat <<'USAGE'
usage:
  polylane-evidence-dag.sh validate POLICY.json DAG.json [REPORT.json]
  polylane-evidence-dag.sh check-final-benchmark POLICY.json STUDY.json [REPORT.json]
  polylane-evidence-dag.sh check-prompt-promotion POLICY.json STUDY.json [REPORT.json]
  polylane-evidence-dag.sh check-genericness POLICY.json REVIEW.json [REPORT.json]
USAGE
}

fail() { echo "EVIDENCE-POLICY-V3-INVALID: $*" >&2; exit 1; }

require_tools() {
  command -v jq >/dev/null 2>&1 || fail "jq is required"
  command -v shasum >/dev/null 2>&1 || fail "shasum is required"
}

require_json_file() {
  file=$1
  [ -f "$file" ] && [ ! -L "$file" ] || fail "not a regular JSON file: $file"
  jq -e . "$file" >/dev/null 2>&1 || fail "invalid JSON: $file"
}

validate_policy() {
  policy=$1
  require_json_file "$policy"
  actual=$(shasum -a 256 "$policy" | awk '{print $1}')
  [ "$actual" = "$POLICY_SHA256" ] || fail "policy bytes do not match frozen evidence-policy/v3"
  jq -e '
    .policy_version == "evidence-policy/v3"
    and .human_certification.enabled == false
    and .human_certification.taste_certification_enabled == false
    and .final_benchmark == {
      schema_version:"final-benchmark/v3",briefs:1000,categories:10,briefs_per_category:100,
      null_probability:0.70,alternative:"greater",alpha:0.025,minimum_wins:729,
      denominator_policy:"all-retained",
      non_win_outcomes:["tie","abstention","missing_evidence","invalid_evidence"],
      task_regressions:0,accessibility_regressions:0,
      boundary_vectors:[{wins:728,passes:false},{wins:729,passes:true}]
    }
    and .prompt_promotion == {
      schema_version:"prompt-promotion/v3",smoke_briefs:12,development_briefs:192,
      validation_briefs:300,null_probability:0.55,alternative:"greater",alpha:0.025,
      minimum_wins:183,result_release:"one-bit",equal_compute:true,
      paired_build_replicates:3,repairs:0,hard_gate_regressions:0,
      non_win_outcomes:["tie","abstention","missing_evidence","invalid_candidate_build"],
      boundary_vectors:[{wins:182,passes:false},{wins:183,passes:true}]
    }
    and .diagnostic_sources.public_taste_authority == "diagnostic_only"
    and .diagnostic_sources.static_aesthetics_authority == "diagnostic_only"
    and .diagnostic_sources.genericness_authority == "review_only_until_sealed_human_qualification"
    and .diagnostic_sources.genericness_verdicts == ["NO_REVIEW","REVIEW_REQUIRED","UNKNOWN"]
    and .lifecycle == {closed_studies_immutable:true,threshold_changes_after_open:false,
      validation_labels_visible_to_optimization:false,repeated_measure_unit:"brief"}
  ' "$policy" >/dev/null || fail "policy constants are not the frozen v3 contract"
}

emit_report() {
  report_tmp=$1; destination=${2:-}
  if [ -n "$destination" ]; then
    [ ! -L "$destination" ] || fail "report destination is a symlink"
    destination_tmp=$(mktemp "${destination}.tmp.XXXXXX") || fail "cannot create report temp file"
    cp "$report_tmp" "$destination_tmp"
    mv -f "$destination_tmp" "$destination"
  else
    cat "$report_tmp"
  fi
}

validate_node_revisions() {
  dag=$1
  count=$(jq '.nodes | length' "$dag")
  i=0
  while [ "$i" -lt "$count" ]; do
    expected=$(jq -cS ".nodes[$i] | del(.revision_digest)" "$dag" |
      shasum -a 256 | awk '{print $1}')
    actual=$(jq -r ".nodes[$i].revision_digest // empty" "$dag")
    [ "$actual" = "$expected" ] || fail "immutable node revision mismatch at index $i"
    i=$((i + 1))
  done
}

validate_dag() {
  policy=$1; dag=$2; destination=${3:-}
  validate_policy "$policy"
  require_json_file "$dag"

  expected_policy=$(shasum -a 256 "$policy" | awk '{print $1}')
  actual_policy=$(jq -r '.policy_digest // empty' "$dag")
  [ "$actual_policy" = "$expected_policy" ] || fail "DAG policy digest is stale or unknown"
  validate_node_revisions "$dag"

  report_tmp=$(mktemp "${TMPDIR:-/tmp}/polylane-evidence-dag-report.XXXXXX") || fail "mktemp failed"
  if ! jq -e --slurpfile policy "$policy" '
    def exactkeys($want): type == "object" and ((keys | sort) == ($want | sort));
    def stable: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    def revision: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*$");
    def digest: type == "string" and test("^[0-9a-f]{64}$");
    def strings: type == "array" and length > 0 and all(.[]; type == "string" and length > 0);
    def scope:
      exactkeys(["population","tasks","domains","states","viewports","criteria","split","acquisition_revision"])
      and (.population | type == "string" and length > 0)
      and (.tasks | strings) and (.domains | strings) and (.states | strings)
      and (.viewports | strings) and (.criteria | strings)
      and (.split | type == "string" and length > 0)
      and (.acquisition_revision | digest);
    def node($nodes; $id): ([$nodes[] | select(.id == $id)][0] // null);
    def producer($producers; $id): ([$producers[] | select(.id == $id)][0] // null);
    def grade_rank($p; $grade): ([$p.trust_lattice[] | select(.grade == $grade) | .rank][0] // null);
    def topo($nodes; $done):
      if ($done | length) == ($nodes | length) then $done
      else
        [$nodes[]
          | select(.id as $id | ($done | index($id)) == null)
          | select(all(.inputs[]; .node_id as $parent | ($done | index($parent)) != null))
          | .id] as $ready
        | if ($ready | length) == 0 then error("cycle")
          else topo($nodes; ($done + $ready | unique)) end
      end;
    def ancestors($nodes; $id):
      $id, (node($nodes; $id).inputs[]?.node_id | ancestors($nodes; .));
    def effective_rank($nodes; $p; $id):
      node($nodes; $id) as $n
      | ([grade_rank($p; $n.declared_grade)]
          + [$n.inputs[]?.node_id | effective_rank($nodes; $p; .)])
      | min;
    def grade_for_rank($p; $rank): ([$p.trust_lattice[] | select(.rank == $rank) | .grade][0] // null);
    def hcm_payload:
      exactkeys(["protocol_id","private","sealed","target_matched","confirmatory_holdout","passed","provider_configurations","calibration_scope"])
      and .protocol_id == "HCM-v2" and .private == true and .sealed == true
      and .target_matched == true and .confirmatory_holdout == true and .passed == true
      and (.calibration_scope | scope)
      and (.provider_configurations | type == "array" and length == 6
        and all(.[]; exactkeys(["config_id","provider_id","lineage_id","role"])
          and (.config_id | stable) and (.provider_id | stable) and (.lineage_id | stable)
          and (.role == "primary" or .role == "reserve"))
        and ([.[].config_id] | length == (unique | length))
        and ([.[] | select(.role == "primary")] | length == 5)
        and ([.[] | select(.role == "reserve")] | length == 1)
        and ([.[].provider_id] | unique | length >= 3)
        and ([.[].lineage_id] | unique | length >= 3)
        and (group_by(.lineage_id) | all(.[]; length <= 2)));

    ($policy[0]) as $p | . as $dag | .nodes as $nodes
    | if (exactkeys(["schema_version","graph_id","policy_digest","nodes","claims"])
        and .schema_version == "evidence-dag/v3"
        and (.graph_id | stable) and (.policy_digest | digest)
        and (.nodes | type == "array" and length > 0)
        and (.claims | type == "array" and length > 0)) then . else error("dag-shape") end
    | if ([.nodes[].id] | length == (unique | length)) then . else error("duplicate-node") end
    | if ([.claims[].id] | length == (unique | length)) then . else error("duplicate-claim") end
    | if all(.nodes[];
        exactkeys(["id","node_type","schema_version","producer_id","producer_revision","inputs","output_digest","execution_digest","source","declared_grade","revision_digest","payload"])
        and (.id | stable) and (.node_type | stable)
        and (.schema_version as $schema | ($schema | type == "string") and ($p.schemas | index($schema)) != null)
        and (.producer_id | stable) and (.producer_revision | revision)
        and (.inputs | type == "array"
          and all(.[]; exactkeys(["node_id","output_digest"])
            and (.node_id | stable) and (.output_digest | digest))
          and ([.[].node_id] | length == (unique | length)))
        and (.output_digest | digest) and (.execution_digest | digest) and (.revision_digest | digest)
        and (.source | exactkeys(["classification","revision","digest"])
          and (.classification | type == "string") and (.revision | revision) and (.digest | digest))
        and (.declared_grade as $grade | ($grade | type == "string")
          and ([ $p.trust_lattice[].grade ] | index($grade)) != null)
        and (.payload | type == "object")) then . else error("node-shape") end
    | if all(.nodes[]; . as $n
        | producer($p.producers; $n.producer_id) as $prod
        | $prod != null
        and $n.producer_revision == $prod.revision
        and $n.schema_version == $prod.schema_version
        and $n.node_type == $prod.node_type
        and $n.declared_grade == $prod.evidence_grade
        and ($prod.source_classifications | index($n.source.classification)) != null)
      then . else error("unregistered-producer-schema-grade") end
    | if all(.nodes[]; . as $n | all($n.inputs[];
        . as $input | node($nodes; $input.node_id) as $parent
        | $parent != null and $input.output_digest == $parent.output_digest))
      then . else error("missing-or-stale-input") end
    | topo($nodes; []) as $order
    | if ($order | length) == ($nodes | length) then . else error("cycle") end
    | if all(.nodes[];
        if .node_type == "private-human-trust-root" then
          (.payload | exactkeys(["protocol_id","private","sealed","target_matched","roster_bound","consent_receipted","deciding_humans"])
            and .protocol_id == "HCM-v2" and .private == true and .sealed == true
            and .target_matched == true and .roster_bound == true
            and .consent_receipted == true and .deciding_humans == false)
        elif .node_type == "hcm-v2-study" then (.payload | hcm_payload)
        elif .node_type == "final-benchmark-result" then
          (.payload | exactkeys(["protocol_id","passed","statistics_receipt_digest","released_artifact_digest"])
            and .protocol_id == "FINAL-1000-v3" and .passed == true
            and (.statistics_receipt_digest | digest) and (.released_artifact_digest | digest))
        else true end)
      then . else error("typed-payload") end
    # The final-result payload must bind the node output, expressed separately
    # because jq input_filename is not the artifact digest.
    | if all(.nodes[]; .node_type != "final-benchmark-result"
        or .payload.released_artifact_digest == .output_digest)
      then . else error("released-artifact-digest") end
    | if all(.claims[]; . as $claim
        | exactkeys(["id","subject_node_id","prerequisite_node_ids","status","claim_label","human_calibrated","human_certified","taste_certified","calibration_scope"])
        and ($claim.id | stable) and ($claim.subject_node_id | stable)
        and ($claim.prerequisite_node_ids | type == "array" and length > 0
          and all(.[]; stable) and (length == (unique | length)))
        and ($claim.status | type == "string") and ($claim.claim_label | type == "string")
        and ($claim.human_calibrated | type == "boolean")
        and ($claim.human_certified | type == "boolean") and $claim.human_certified == false
        and ($claim.taste_certified | type == "boolean") and $claim.taste_certified == false
        and (node($nodes; $claim.subject_node_id) != null)
        and all($claim.prerequisite_node_ids[]; . as $prereq |
          node($nodes; $prereq) != null
          and ([ancestors($nodes; $claim.subject_node_id)] | index($prereq)) != null))
      then . else error("claim-shape-prerequisite") end
    | if ([.claims[] | .subject_node_id, .prerequisite_node_ids[] | ancestors($nodes; .)] | unique) as $connected
        | ([.nodes[].id] | sort) == ($connected | sort)
      then . else error("disconnected-node") end
    | if all(.claims[]; . as $claim
        | effective_rank($nodes; $p; $claim.subject_node_id) as $rank
        | grade_for_rank($p; $rank) as $grade
        | if $grade == "fixture" then
            $claim.status == "EVIDENCE-ONLY" and $claim.claim_label == "FIXTURE_ONLY"
            and $claim.human_calibrated == false and $claim.calibration_scope == null
          elif $grade == "diagnostic_public" then
            $claim.status == "MACHINE-EVALUATED" and $claim.claim_label == "DIAGNOSTIC_ONLY"
            and $claim.human_calibrated == false and $claim.calibration_scope == null
          elif $grade == "machine_only" then
            $claim.status == "MACHINE-EVALUATED" and $claim.claim_label == "MACHINE_ONLY"
            and $claim.human_calibrated == false and $claim.calibration_scope == null
          elif $grade == "private_human_calibration" then
            $claim.status == "MACHINE-EVALUATED"
            and $claim.claim_label == "HUMAN_CALIBRATED_MACHINE"
            and $claim.human_calibrated == true
            and ($claim.calibration_scope | scope)
            and (node($nodes; $claim.subject_node_id).node_type == "final-benchmark-result")
            and ([ancestors($nodes; $claim.subject_node_id) as $aid
                  | node($nodes; $aid) | select(.node_type == "private-human-trust-root")] | length == 1)
            and ([ancestors($nodes; $claim.subject_node_id) as $aid
                  | node($nodes; $aid) | select(.node_type == "hcm-v2-study")] | length == 1)
            and ([ancestors($nodes; $claim.subject_node_id) as $aid
                  | node($nodes; $aid) | select(.node_type == "hcm-v2-study")
                  | .payload.calibration_scope] | first) == $claim.calibration_scope
            and (["private-human-trust-root","hcm-v2-study","final-benchmark-result"]
              | all(.[]; . as $required | any($claim.prerequisite_node_ids[];
                  . as $pid | node($nodes; $pid).node_type == $required)))
          else false end)
      then . else error("claim-ceiling") end
    | {
        schema_version:"evidence-dag-report/v3",status:"VALID",graph_id:.graph_id,
        policy_digest:.policy_digest,node_count:(.nodes|length),claim_count:(.claims|length),
        claims:[.claims[] as $claim
          | effective_rank($nodes; $p; $claim.subject_node_id) as $rank
          | {id:$claim.id,subject_node_id:$claim.subject_node_id,
             effective_grade:grade_for_rank($p;$rank),status:$claim.status,
             claim_label:$claim.claim_label,human_calibrated:$claim.human_calibrated,
             human_certified:false,taste_certified:false,calibration_scope:$claim.calibration_scope}]
      }
  ' "$dag" >"$report_tmp"; then
    rm -f "$report_tmp"
    fail "DAG structure, ancestry, provenance, or claim ceiling failed"
  fi
  emit_report "$report_tmp" "$destination"
  rm -f "$report_tmp"
}

check_final_benchmark() {
  policy=$1; study=$2; destination=${3:-}
  validate_policy "$policy"
  require_json_file "$study"
  report_tmp=$(mktemp "${TMPDIR:-/tmp}/polylane-final-benchmark-report.XXXXXX") || fail "mktemp failed"
  if ! jq -e '
    def exactkeys($want): type == "object" and ((keys | sort) == ($want | sort));
    def stable: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    def strings: type == "array" and length > 0 and all(.[]; type == "string" and length > 0);
    def timestamp: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
    . as $s
    | if exactkeys(["schema_version","design","lifecycle","hard_gates","briefs"])
      and .schema_version == "final-benchmark/v3"
      and (.design | exactkeys(["briefs","per_category","categories","null_probability","alternative","alpha","minimum_wins","independent_unit","denominator_policy","one_shot","optimizer_access"])
        and .briefs == 1000 and .per_category == 100
        and (.categories | type == "array" and length == 10 and all(.[]; stable) and length == (unique|length))
        and .null_probability == 0.70 and .alternative == "greater" and .alpha == 0.025
        and .minimum_wins == 729 and .independent_unit == "brief"
        and .denominator_policy == "all-retained" and .one_shot == true and .optimizer_access == false)
      and (.lifecycle | exactkeys(["state","preregistered_at","opened_at","closed_at","labels_released_at"])
        and .state == "CLOSED" and (.preregistered_at|timestamp) and (.opened_at|timestamp)
        and (.closed_at|timestamp) and (.labels_released_at|timestamp)
        and .preregistered_at < .opened_at and .opened_at < .closed_at and .closed_at < .labels_released_at)
      and .hard_gates == {task_regressions:0,accessibility_regressions:0}
      and (.briefs | type == "array" and length == 1000
        and all(.[]; exactkeys(["brief_id","family_id","category","outcome","mirrors","build_replicates","judge_ids","ballot_ids","states","viewports"])
          and (.brief_id|stable) and (.family_id|stable)
          and (.category as $cat | $s.design.categories | index($cat) != null)
          and (.outcome as $outcome
            | (["win","tie","abstention","missing_evidence","invalid_evidence"] | index($outcome)) != null)
          and (.mirrors|strings) and (.build_replicates|strings) and (.judge_ids|strings)
          and (.ballot_ids|strings) and (.states|strings) and (.viewports|strings))
        and ([.[].brief_id] | length == (unique|length))
        and ([.[].family_id] | length == (unique|length))
        and (group_by(.category) | length == 10 and all(.[]; length == 100)))
      then . else error("final-benchmark-contract") end
    | ([.briefs[] | select(.outcome == "win")] | length) as $wins
    | if $wins >= 729 then . else error("final-boundary") end
    | {schema_version:"final-benchmark-report/v3",status:"VALID",wins:$wins,
       n:(.briefs|length),non_wins:((.briefs|length)-$wins),passed:true,
       task_regressions:.hard_gates.task_regressions,
       accessibility_regressions:.hard_gates.accessibility_regressions}
  ' "$study" >"$report_tmp"; then
    rm -f "$report_tmp"
    fail "final benchmark violates the exact 1,000-brief contract"
  fi
  emit_report "$report_tmp" "$destination"
  rm -f "$report_tmp"
}

check_prompt_promotion() {
  policy=$1; study=$2; destination=${3:-}
  validate_policy "$policy"
  require_json_file "$study"
  report_tmp=$(mktemp "${TMPDIR:-/tmp}/polylane-prompt-promotion-report.XXXXXX") || fail "mktemp failed"
  if ! jq -e '
    def exactkeys($want): type == "object" and ((keys | sort) == ($want | sort));
    def stable: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    def strings: type == "array" and length > 0 and all(.[]; type == "string" and length > 0);
    def timestamp: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
    . as $s
    | if exactkeys(["schema_version","design","lifecycle","smoke","development","validation"])
      and .schema_version == "prompt-promotion/v3"
      and .design == {smoke_briefs:12,development_briefs:192,validation_briefs:300,
        null_probability:0.55,alternative:"greater",alpha:0.025,minimum_wins:183,
        result_release:"one-bit",equal_compute:true,paired_build_replicates:3,
        repairs:0,hard_gate_regressions:0,untouched_validation:true,final_benchmark_access:false}
      and (.lifecycle | exactkeys(["state","smoke_closed_at","development_closed_at","finalist_frozen_at","validation_opened_at","validation_closed_at"])
        and .state == "CLOSED" and (.smoke_closed_at|timestamp) and (.development_closed_at|timestamp)
        and (.finalist_frozen_at|timestamp) and (.validation_opened_at|timestamp) and (.validation_closed_at|timestamp)
        and .smoke_closed_at < .development_closed_at
        and .development_closed_at < .finalist_frozen_at
        and .finalist_frozen_at < .validation_opened_at
        and .validation_opened_at < .validation_closed_at)
      and (.smoke | type == "array" and length == 12
        and all(.[]; exactkeys(["brief_id","family_id"]) and (.brief_id|stable) and (.family_id|stable)))
      and (.development | type == "array" and length == 192
        and all(.[]; exactkeys(["brief_id","family_id"]) and (.brief_id|stable) and (.family_id|stable)))
      and (.validation | type == "array" and length == 300
        and all(.[]; exactkeys(["brief_id","family_id","outcome","candidate_builds","baseline_builds","mirrors","judge_ids","ballot_ids"])
          and (.brief_id|stable) and (.family_id|stable)
          and (.outcome as $outcome
            | (["win","tie","abstention","missing_evidence","invalid_candidate_build"] | index($outcome)) != null)
          and (.candidate_builds|strings) and ([.candidate_builds[]] | unique | length) == 3
          and (.baseline_builds|strings) and ([.baseline_builds[]] | unique | length) == 3
          and (.mirrors|strings) and (.judge_ids|strings) and (.ballot_ids|strings)))
      and ([$s.smoke[].brief_id,$s.development[].brief_id,$s.validation[].brief_id]
        | length == (unique|length))
      and ([$s.smoke[].family_id,$s.development[].family_id,$s.validation[].family_id]
        | length == (unique|length))
      then . else error("prompt-promotion-contract") end
    | ([.validation[] | select(.outcome == "win")] | length) as $wins
    | if $wins >= 183 then . else error("prompt-boundary") end
    | {schema_version:"prompt-promotion-report/v3",status:"VALID",wins:$wins,
       n:(.validation|length),non_wins:((.validation|length)-$wins),passed:true,
       claim_ceiling:"PROMPT_OPTIMIZER_SELECTED_NOT_CERTIFIED"}
  ' "$study" >"$report_tmp"; then
    rm -f "$report_tmp"
    fail "prompt promotion violates the exact 12/192/300 contract"
  fi
  emit_report "$report_tmp" "$destination"
  rm -f "$report_tmp"
}

check_genericness() {
  policy=$1; review=$2; destination=${3:-}
  validate_policy "$policy"
  require_json_file "$review"
  report_tmp=$(mktemp "${TMPDIR:-/tmp}/polylane-genericness-report.XXXXXX") || fail "mktemp failed"
  if ! jq -e '
    . as $review
    | (type == "object" and (keys | sort) == (["qualified","schema_version","verdict"] | sort)
      and .schema_version == "genericness-review/v3" and .qualified == false
      and (["NO_REVIEW","REVIEW_REQUIRED","UNKNOWN"] | index($review.verdict)) != null)
    | if . then {schema_version:"genericness-review-report/v3",status:"VALID",
        authority:"REVIEW_ONLY",verdict:$review.verdict} else error("genericness-auto-verdict") end
  ' "$review" >"$report_tmp"; then
    rm -f "$report_tmp"
    fail "genericness heuristics are review-only until sealed human qualification"
  fi
  emit_report "$report_tmp" "$destination"
  rm -f "$report_tmp"
}

main() {
  require_tools
  [ $# -ge 1 ] || { usage >&2; exit 2; }
  command_name=$1
  shift
  case "$command_name" in
    validate)
      [ $# -ge 2 ] && [ $# -le 3 ] || { usage >&2; exit 2; }
      validate_dag "$@"
      ;;
    check-final-benchmark)
      [ $# -ge 2 ] && [ $# -le 3 ] || { usage >&2; exit 2; }
      check_final_benchmark "$@"
      ;;
    check-prompt-promotion)
      [ $# -ge 2 ] && [ $# -le 3 ] || { usage >&2; exit 2; }
      check_prompt_promotion "$@"
      ;;
    check-genericness)
      [ $# -ge 2 ] && [ $# -le 3 ] || { usage >&2; exit 2; }
      check_genericness "$@"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
