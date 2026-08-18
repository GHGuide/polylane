#!/usr/bin/env bash
# Adversarial contract tests for the evidence-policy v3 trust engine.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
ENGINE="$ROOT/bin/polylane-evidence-dag.sh"
POLICY="$ROOT/docs/polylane/taste-certification/contracts/evidence-policy-v3.json"
SCHEMA="$ROOT/docs/polylane/taste-certification/contracts/evidence-dag-v3.schema.json"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-evidence-dag.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
ASSERTIONS=0

fail_test() { echo "FAIL: $*" >&2; exit 1; }

assert_ok() {
  "$@" >/dev/null || fail_test "expected success: $*"
  ASSERTIONS=$((ASSERTIONS + 1))
}

assert_fail() {
  if "$@" >/dev/null 2>&1; then
    fail_test "expected failure: $*"
  fi
  ASSERTIONS=$((ASSERTIONS + 1))
}

expect_eq() {
  [ "$1" = "$2" ] || fail_test "${3:-value}: expected [$1], got [$2]"
  ASSERTIONS=$((ASSERTIONS + 1))
}

fake_sha() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

mutate() {
  file=$1; filter=$2
  jq "$filter" "$file" >"$file.tmp"
  mv "$file.tmp" "$file"
}

# Revision digests bind the canonical node body; policy_digest binds the exact
# frozen policy bytes. Tests that target a deeper rule reseal after mutation.
seal_graph() {
  graph=$1
  count=$(jq '.nodes | length' "$graph")
  i=0
  while [ "$i" -lt "$count" ]; do
    revision=$(jq -cS ".nodes[$i] | del(.revision_digest)" "$graph" |
      shasum -a 256 | awk '{print $1}')
    jq --arg revision "$revision" ".nodes[$i].revision_digest = \$revision" \
      "$graph" >"$graph.tmp"
    mv "$graph.tmp" "$graph"
    i=$((i + 1))
  done
  policy_digest=$(shasum -a 256 "$POLICY" | awk '{print $1}')
  jq --arg digest "$policy_digest" '.policy_digest = $digest' "$graph" >"$graph.tmp"
  mv "$graph.tmp" "$graph"
}

write_hcm_graph() {
  out=$1
  trust_out=$(fake_sha hcm-trust-root-output)
  study_out=$(fake_sha hcm-study-output)
  final_out=$(fake_sha final-benchmark-output)
  trust_source=$(fake_sha private-roster-source)
  study_source=$(fake_sha hcm-study-source)
  final_source=$(fake_sha final-study-source)
  config=$(fake_sha execution-config)
  scope_revision=$(fake_sha hcm-acquisition-revision)
  jq -n \
    --arg trust_out "$trust_out" --arg study_out "$study_out" --arg final_out "$final_out" \
    --arg trust_source "$trust_source" --arg study_source "$study_source" \
    --arg final_source "$final_source" --arg config "$config" \
    --arg scope_revision "$scope_revision" '
    {
      schema_version: "evidence-dag/v3",
      graph_id: "hcm-release-evidence",
      policy_digest: "UNSEALED",
      nodes: [
        {
          id: "human-trust-root", node_type: "private-human-trust-root",
          schema_version: "private-human-trust-root/v3",
          producer_id: "hcm-v2-trust-root", producer_revision: "hcm-v2-trust-root/r1",
          inputs: [], output_digest: $trust_out, execution_digest: $config,
          source: {classification:"private_target_human", revision:"hcm-roster/r1", digest:$trust_source},
          declared_grade: "private_human_calibration", revision_digest: "UNSEALED",
          payload: {protocol_id:"HCM-v2", private:true, sealed:true, target_matched:true,
            roster_bound:true, consent_receipted:true, deciding_humans:false}
        },
        {
          id: "hcm-study", node_type: "hcm-v2-study",
          schema_version: "hcm-v2-study/v2",
          producer_id: "hcm-v2-study-auditor", producer_revision: "hcm-v2-study-auditor/r1",
          inputs: [{node_id:"human-trust-root", output_digest:$trust_out}],
          output_digest: $study_out, execution_digest: $config,
          source: {classification:"private_target_human", revision:"hcm-study/r1", digest:$study_source},
          declared_grade: "private_human_calibration", revision_digest: "UNSEALED",
          payload: {
            protocol_id:"HCM-v2", private:true, sealed:true, target_matched:true,
            confirmatory_holdout:true, passed:true,
            provider_configurations:[
              {config_id:"a1",provider_id:"provider-a",lineage_id:"lineage-a",role:"primary"},
              {config_id:"a2",provider_id:"provider-a",lineage_id:"lineage-a",role:"primary"},
              {config_id:"b1",provider_id:"provider-b",lineage_id:"lineage-b",role:"primary"},
              {config_id:"b2",provider_id:"provider-b",lineage_id:"lineage-b",role:"primary"},
              {config_id:"c1",provider_id:"provider-c",lineage_id:"lineage-c",role:"primary"},
              {config_id:"c2",provider_id:"provider-c",lineage_id:"lineage-c",role:"reserve"}
            ],
            calibration_scope:{
              population:"target users in the preregistered HCM-v2 frame",
              tasks:["brief-specific routes"], domains:["product-ui"],
              states:["initial","task-complete"], viewports:["1440x900","390x844"],
              criteria:["visual-design","task","accessibility"], split:"confirmatory-160-pair",
              acquisition_revision:$scope_revision
            }
          }
        },
        {
          id: "final-benchmark", node_type: "final-benchmark-result",
          schema_version: "final-benchmark-result/v3",
          producer_id: "final-benchmark-auditor", producer_revision: "final-benchmark-auditor/r1",
          inputs: [{node_id:"hcm-study", output_digest:$study_out}],
          output_digest: $final_out, execution_digest: $config,
          source: {classification:"private_target_human", revision:"final-benchmark/r1", digest:$final_source},
          declared_grade: "private_human_calibration", revision_digest: "UNSEALED",
          payload: {protocol_id:"FINAL-1000-v3", passed:true,
            statistics_receipt_digest:$final_source, released_artifact_digest:$final_out}
        }
      ],
      claims: [{
        id:"release-claim", subject_node_id:"final-benchmark",
        prerequisite_node_ids:["human-trust-root","hcm-study","final-benchmark"],
        status:"MACHINE-EVALUATED", claim_label:"HUMAN_CALIBRATED_MACHINE",
        human_calibrated:true, human_certified:false, taste_certified:false,
        calibration_scope:{
          population:"target users in the preregistered HCM-v2 frame",
          tasks:["brief-specific routes"], domains:["product-ui"],
          states:["initial","task-complete"], viewports:["1440x900","390x844"],
          criteria:["visual-design","task","accessibility"], split:"confirmatory-160-pair",
          acquisition_revision:$scope_revision
        }
      }]
    }' >"$out"
  seal_graph "$out"
}

make_safe_claim() {
  graph=$1; label=$2; status=$3
  jq --arg label "$label" --arg status "$status" '
    .claims[0].status=$status
    | .claims[0].claim_label=$label
    | .claims[0].human_calibrated=false
    | .claims[0].human_certified=false
    | .claims[0].taste_certified=false
    | .claims[0].calibration_scope=null
    | .claims[0].prerequisite_node_ids=[.claims[0].subject_node_id]
  ' "$graph" >"$graph.tmp"
  mv "$graph.tmp" "$graph"
}

write_final_benchmark() {
  wins=$1; out=$2
  jq -n --argjson wins "$wins" '
    ["commerce","education","finance","health","media","nonprofit","productivity","public-sector","travel","utilities"] as $cats
    | {
      schema_version:"final-benchmark/v3",
      design:{briefs:1000,per_category:100,categories:$cats,null_probability:0.70,
        alternative:"greater",alpha:0.025,minimum_wins:729,independent_unit:"brief",
        denominator_policy:"all-retained",one_shot:true,optimizer_access:false},
      lifecycle:{state:"CLOSED",preregistered_at:"2026-01-01T00:00:00Z",
        opened_at:"2026-02-01T00:00:00Z",closed_at:"2026-03-01T00:00:00Z",
        labels_released_at:"2026-03-02T00:00:00Z"},
      hard_gates:{task_regressions:0,accessibility_regressions:0},
      briefs:[range(0;1000) as $i | {
        brief_id:("brief-"+($i|tostring)), family_id:("family-"+($i|tostring)),
        category:$cats[($i/100|floor)],
        outcome:(if $i < $wins then "win" else "tie" end),
        mirrors:["A/B","B/A"], build_replicates:["r1","r2","r3"],
        judge_ids:["j1","j2","j3"], ballot_ids:["b1","b2","b3"],
        states:["initial","complete"], viewports:["1440x900","390x844"]
      }]
    }' >"$out"
}

write_prompt_promotion() {
  wins=$1; out=$2
  jq -n --argjson wins "$wins" '
    {
      schema_version:"prompt-promotion/v3",
      design:{smoke_briefs:12,development_briefs:192,validation_briefs:300,
        null_probability:0.55,alternative:"greater",alpha:0.025,minimum_wins:183,
        result_release:"one-bit",equal_compute:true,paired_build_replicates:3,
        repairs:0,hard_gate_regressions:0,untouched_validation:true,
        final_benchmark_access:false},
      lifecycle:{state:"CLOSED",smoke_closed_at:"2026-01-01T00:00:00Z",
        development_closed_at:"2026-02-01T00:00:00Z",finalist_frozen_at:"2026-02-02T00:00:00Z",
        validation_opened_at:"2026-03-01T00:00:00Z",validation_closed_at:"2026-03-02T00:00:00Z"},
      smoke:[range(0;12) as $i | {brief_id:("smoke-"+($i|tostring)),family_id:("smoke-family-"+($i|tostring))}],
      development:[range(0;192) as $i | {brief_id:("dev-"+($i|tostring)),family_id:("dev-family-"+($i|tostring))}],
      validation:[range(0;300) as $i | {
        brief_id:("test-"+($i|tostring)),family_id:("test-family-"+($i|tostring)),
        outcome:(if $i < $wins then "win" else "abstention" end),
        candidate_builds:["c-r1","c-r2","c-r3"],baseline_builds:["b-r1","b-r2","b-r3"],
        mirrors:["A/B","B/A"],judge_ids:["j1","j2","j3"],ballot_ids:["b1","b2","b3"]
      }]
    }' >"$out"
}

# RED checkpoint: these are the production artifacts whose absence must fail
# before any implementation is written.
[ -x "$ENGINE" ] || fail_test "v3 evidence engine is not implemented"
[ -f "$POLICY" ] || fail_test "v3 evidence policy is not implemented"
[ -f "$SCHEMA" ] || fail_test "v3 evidence schema is not implemented"

# --- policy and happy HCM chain -------------------------------------------

jq -e . "$POLICY" "$SCHEMA" >/dev/null || fail_test "contracts are not valid JSON"
HCM="$TMP/hcm.json"
write_hcm_graph "$HCM"
REPORT="$TMP/hcm-report.json"
assert_ok "$ENGINE" validate "$POLICY" "$HCM" "$REPORT"
expect_eq "VALID" "$(jq -r '.status' "$REPORT")" hcm-status
expect_eq "private_human_calibration" "$(jq -r '.claims[0].effective_grade' "$REPORT")" hcm-grade
expect_eq "MACHINE-EVALUATED" "$(jq -r '.claims[0].status' "$REPORT")" hcm-machine-status
expect_eq "HUMAN_CALIBRATED_MACHINE" "$(jq -r '.claims[0].claim_label' "$REPORT")" hcm-label
expect_eq "true false false" "$(jq -r '.claims[0] | "\(.human_calibrated) \(.human_certified) \(.taste_certified)"' "$REPORT")" honest-flags
expect_eq "target users in the preregistered HCM-v2 frame" \
  "$(jq -r '.claims[0].calibration_scope.population' "$REPORT")" exact-scope

# Deterministic byte-for-byte report replay.
REPORT2="$TMP/hcm-report-2.json"
assert_ok "$ENGINE" validate "$POLICY" "$HCM" "$REPORT2"
cmp -s "$REPORT" "$REPORT2" || fail_test "DAG report is not deterministic"
ASSERTIONS=$((ASSERTIONS + 1))

# --- ancestry, provenance, registration, immutability --------------------

case_graph() { cp "$HCM" "$TMP/$1.json"; printf '%s' "$TMP/$1.json"; }

G=$(case_graph unknown-producer); mutate "$G" '.nodes[1].producer_id="unregistered"'; seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"
G=$(case_graph producer-revision); mutate "$G" '.nodes[1].producer_revision="hcm-v2-study-auditor/r0"'; seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"
G=$(case_graph unknown-schema); mutate "$G" '.nodes[1].schema_version="unknown/v99"'; seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"
G=$(case_graph schema-downgrade); mutate "$G" '.nodes[1].schema_version="hcm-v2-study/v1"'; seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"
G=$(case_graph missing-parent); mutate "$G" '.nodes[1].inputs[0].node_id="missing"'; seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"
G=$(case_graph stale-input); mutate "$G" '.nodes[0].output_digest="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'; seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"
G=$(case_graph bad-output); mutate "$G" '.nodes[2].output_digest="not-a-digest"'; seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"
G=$(case_graph immutable-revision); mutate "$G" '.nodes[1].payload.passed=false'
assert_fail "$ENGINE" validate "$POLICY" "$G"
G=$(case_graph stale-policy); mutate "$G" '.policy_digest="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"'
assert_fail "$ENGINE" validate "$POLICY" "$G"

# Cycle with otherwise exact input digests and resealed revisions.
G=$(case_graph cycle)
ROOT_OUT=$(jq -r '.nodes[0].output_digest' "$G")
FINAL_OUT=$(jq -r '.nodes[2].output_digest' "$G")
jq --arg root "$ROOT_OUT" --arg final "$FINAL_OUT" \
  '.nodes[0].inputs=[{node_id:"final-benchmark",output_digest:$final}]
   | .nodes[1].inputs[0].output_digest=$root' "$G" >"$G.tmp" && mv "$G.tmp" "$G"
seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"

# A valid but unused receipt is disconnected and therefore invalid.
G=$(case_graph disconnected)
jq --arg out "$(fake_sha orphan-output)" --arg cfg "$(fake_sha orphan-config)" \
  --arg src "$(fake_sha orphan-source)" '.nodes += [{
    id:"orphan",node_type:"machine-evaluation",schema_version:"machine-evaluation/v3",
    producer_id:"machine-evaluator",producer_revision:"machine-evaluator/r1",inputs:[],
    output_digest:$out,execution_digest:$cfg,
    source:{classification:"machine_only",revision:"machine/r1",digest:$src},
    declared_grade:"machine_only",revision_digest:"UNSEALED",payload:{passed:true}
  }]' "$G" >"$G.tmp" && mv "$G.tmp" "$G"
seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"

G=$(case_graph duplicate-node); mutate "$G" '.nodes[1].id=.nodes[0].id'; seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"
G=$(case_graph wrong-grade); mutate "$G" '.nodes[1].declared_grade="released_artifact_human_ballot"'; seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"
G=$(case_graph source-mismatch); mutate "$G" '.nodes[1].source.classification="public_corpus"'; seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"
G=$(case_graph missing-prereq); mutate "$G" '.claims[0].prerequisite_node_ids=["hcm-study","final-benchmark"]'
assert_fail "$ENGINE" validate "$POLICY" "$G"

# --- trust lattice and laundering ----------------------------------------

# Fixture ancestry is absorbing even through otherwise private HCM nodes.
G=$(case_graph fixture-safe)
mutate "$G" '.nodes[0].node_type="fixture-root"
  | .nodes[0].schema_version="fixture-evidence/v3"
  | .nodes[0].producer_id="fixture-generator"
  | .nodes[0].producer_revision="fixture-generator/r1"
  | .nodes[0].source.classification="fixture"
  | .nodes[0].declared_grade="fixture"'
make_safe_claim "$G" FIXTURE_ONLY EVIDENCE-ONLY
seal_graph "$G"
FIXTURE_REPORT="$TMP/fixture-report.json"
assert_ok "$ENGINE" validate "$POLICY" "$G" "$FIXTURE_REPORT"
expect_eq "fixture" "$(jq -r '.claims[0].effective_grade' "$FIXTURE_REPORT")" fixture-absorbing

G=$(case_graph fixture-launder)
mutate "$G" '.nodes[0].node_type="fixture-root"
  | .nodes[0].schema_version="fixture-evidence/v3"
  | .nodes[0].producer_id="fixture-generator"
  | .nodes[0].producer_revision="fixture-generator/r1"
  | .nodes[0].source.classification="fixture"
  | .nodes[0].declared_grade="fixture"'
seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"

# Public-corpus ancestry may remain diagnostic but can never activate HCM.
G=$(case_graph public-safe)
mutate "$G" '.nodes[0].node_type="public-corpus-root"
  | .nodes[0].schema_version="public-corpus/v3"
  | .nodes[0].producer_id="public-corpus-loader"
  | .nodes[0].producer_revision="public-corpus-loader/r1"
  | .nodes[0].source.classification="public_corpus"
  | .nodes[0].declared_grade="diagnostic_public"'
make_safe_claim "$G" DIAGNOSTIC_ONLY MACHINE-EVALUATED
seal_graph "$G"
PUBLIC_REPORT="$TMP/public-report.json"
assert_ok "$ENGINE" validate "$POLICY" "$G" "$PUBLIC_REPORT"
expect_eq "diagnostic_public" "$(jq -r '.claims[0].effective_grade' "$PUBLIC_REPORT")" public-ceiling
expect_eq "false" "$(jq -r '.claims[0].human_calibrated' "$PUBLIC_REPORT")" public-not-human-calibrated

G=$(case_graph public-to-hcm)
mutate "$G" '.nodes[0].node_type="public-corpus-root"
  | .nodes[0].schema_version="public-corpus/v3"
  | .nodes[0].producer_id="public-corpus-loader"
  | .nodes[0].producer_revision="public-corpus-loader/r1"
  | .nodes[0].source.classification="public_corpus"
  | .nodes[0].declared_grade="diagnostic_public"'
seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"

# Machine-only ancestry also keeps every human flag false.
G=$(case_graph machine-safe)
mutate "$G" '.nodes[0].node_type="machine-evaluation"
  | .nodes[0].schema_version="machine-evaluation/v3"
  | .nodes[0].producer_id="machine-evaluator"
  | .nodes[0].producer_revision="machine-evaluator/r1"
  | .nodes[0].source.classification="machine_only"
  | .nodes[0].declared_grade="machine_only"'
make_safe_claim "$G" MACHINE_ONLY MACHINE-EVALUATED
seal_graph "$G"
MACHINE_REPORT="$TMP/machine-report.json"
assert_ok "$ENGINE" validate "$POLICY" "$G" "$MACHINE_REPORT"
expect_eq "machine_only false" \
  "$(jq -r '.claims[0] | "\(.effective_grade) \(.human_calibrated)"' "$MACHINE_REPORT")" machine-ceiling

# HCM-v2 must remain private, sealed, target-matched, passed, and exactly scoped.
for spec in \
  'hcm-public|.nodes[1].payload.private=false' \
  'hcm-unsealed|.nodes[1].payload.sealed=false' \
  'hcm-not-target|.nodes[1].payload.target_matched=false' \
  'hcm-not-confirmatory|.nodes[1].payload.confirmatory_holdout=false' \
  'hcm-failed|.nodes[1].payload.passed=false' \
  'hcm-wrong-protocol|.nodes[1].payload.protocol_id="HCM-v1"' \
  'hcm-scope-launder|.claims[0].calibration_scope.population="everyone"'; do
  name=${spec%%|*}; filter=${spec#*|}; G=$(case_graph "$name"); mutate "$G" "$filter"; seal_graph "$G"
  assert_fail "$ENGINE" validate "$POLICY" "$G"
done

# Provider aliases do not create independent lineages.
G=$(case_graph provider-aliases)
mutate "$G" '.nodes[1].payload.provider_configurations |= map(.lineage_id="same-lineage")'
seal_graph "$G"
assert_fail "$ENGINE" validate "$POLICY" "$G"

# Every false human/taste-certified claim is unreachable in v3.
for spec in \
  'human-certified-flag|.claims[0].human_certified=true' \
  'human-certified-label|.claims[0].claim_label="HUMAN_CERTIFIED"' \
  'human-certified-status|.claims[0].status="HUMAN-CERTIFIED"' \
  'taste-certified-flag|.claims[0].taste_certified=true' \
  'taste-certified-label|.claims[0].claim_label="TASTE_CERTIFIED"' \
  'false-human-calibration|.claims[0].human_calibrated=true | .claims[0].claim_label="MACHINE_ONLY"'; do
  name=${spec%%|*}; filter=${spec#*|}; G=$(case_graph "$name"); mutate "$G" "$filter"
  assert_fail "$ENGINE" validate "$POLICY" "$G"
done

# --- exact final-benchmark statistics ------------------------------------

FINAL728="$TMP/final-728.json"; write_final_benchmark 728 "$FINAL728"
FINAL729="$TMP/final-729.json"; write_final_benchmark 729 "$FINAL729"
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$FINAL728"
FINAL_REPORT="$TMP/final-report.json"
assert_ok "$ENGINE" check-final-benchmark "$POLICY" "$FINAL729" "$FINAL_REPORT"
expect_eq "729 1000 true" "$(jq -r '"\(.wins) \(.n) \(.passed)"' "$FINAL_REPORT")" final-boundary

# All non-win reason codes stay in the denominator.
FINAL_NONWINS="$TMP/final-nonwins.json"; cp "$FINAL729" "$FINAL_NONWINS"
mutate "$FINAL_NONWINS" '.briefs[729].outcome="tie"
  | .briefs[730].outcome="abstention"
  | .briefs[731].outcome="missing_evidence"
  | .briefs[732].outcome="invalid_evidence"'
NONWIN_REPORT="$TMP/final-nonwins-report.json"
assert_ok "$ENGINE" check-final-benchmark "$POLICY" "$FINAL_NONWINS" "$NONWIN_REPORT"
expect_eq "729 1000 271" "$(jq -r '"\(.wins) \(.n) \(.non_wins)"' "$NONWIN_REPORT")" nonwins-retained

G="$TMP/final-shrink.json"; cp "$FINAL729" "$G"; mutate "$G" '.briefs |= .[0:999]'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"
G="$TMP/final-category.json"; cp "$FINAL729" "$G"; mutate "$G" '.briefs[0].category="utilities"'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"
G="$TMP/final-duplicate-brief.json"; cp "$FINAL729" "$G"; mutate "$G" '.briefs[1].brief_id=.briefs[0].brief_id'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"
G="$TMP/final-repeat-family.json"; cp "$FINAL729" "$G"; mutate "$G" '.briefs[1].family_id=.briefs[0].family_id'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"
G="$TMP/final-task-regression.json"; cp "$FINAL729" "$G"; mutate "$G" '.hard_gates.task_regressions=1'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"
G="$TMP/final-a11y-regression.json"; cp "$FINAL729" "$G"; mutate "$G" '.hard_gates.accessibility_regressions=1'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"
G="$TMP/final-alpha.json"; cp "$FINAL729" "$G"; mutate "$G" '.design.alpha=0.0250001'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"
G="$TMP/final-null.json"; cp "$FINAL729" "$G"; mutate "$G" '.design.null_probability=0.7000001'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"
G="$TMP/final-one-shot.json"; cp "$FINAL729" "$G"; mutate "$G" '.design.one_shot=false'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"
G="$TMP/final-optimizer-leak.json"; cp "$FINAL729" "$G"; mutate "$G" '.design.optimizer_access=true'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"

# Mirrors/builds/judges/ballots/states/viewports are repeated measures only.
G="$TMP/final-inflation.json"; cp "$FINAL729" "$G"
mutate "$G" '.briefs[0].mirrors += ["A/B-2"]
  | .briefs[0].build_replicates += ["r4"]
  | .briefs[0].judge_ids += ["j4"]
  | .briefs[0].ballot_ids += ["b4"]
  | .briefs[0].states += ["hover"]
  | .briefs[0].viewports += ["1024x768"]'
INFLATION_REPORT="$TMP/final-inflation-report.json"
assert_ok "$ENGINE" check-final-benchmark "$POLICY" "$G" "$INFLATION_REPORT"
expect_eq "1000" "$(jq -r '.n' "$INFLATION_REPORT")" repeated-measures-no-inflation

# Lifecycle order and immutable closed state are executable gates.
G="$TMP/final-lifecycle.json"; cp "$FINAL729" "$G"; mutate "$G" '.lifecycle.closed_at="2026-01-15T00:00:00Z"'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"
G="$TMP/final-open.json"; cp "$FINAL729" "$G"; mutate "$G" '.lifecycle.state="OPEN"'
assert_fail "$ENGINE" check-final-benchmark "$POLICY" "$G"

# --- exact prompt-promotion statistics -----------------------------------

PROMPT182="$TMP/prompt-182.json"; write_prompt_promotion 182 "$PROMPT182"
PROMPT183="$TMP/prompt-183.json"; write_prompt_promotion 183 "$PROMPT183"
assert_fail "$ENGINE" check-prompt-promotion "$POLICY" "$PROMPT182"
PROMPT_REPORT="$TMP/prompt-report.json"
assert_ok "$ENGINE" check-prompt-promotion "$POLICY" "$PROMPT183" "$PROMPT_REPORT"
expect_eq "183 300 true" "$(jq -r '"\(.wins) \(.n) \(.passed)"' "$PROMPT_REPORT")" prompt-boundary

for spec in \
  'smoke-shrink|.smoke |= .[0:11]' \
  'dev-shrink|.development |= .[0:191]' \
  'test-shrink|.validation |= .[0:299]' \
  'prompt-family-repeat|.validation[1].family_id=.validation[0].family_id' \
  'compute-unequal|.design.equal_compute=false' \
  'replicates-two|.design.paired_build_replicates=2' \
  'replicates-four|.design.paired_build_replicates=4' \
  'repairs-one|.design.repairs=1' \
  'prompt-regression|.design.hard_gate_regressions=1' \
  'prompt-touched|.design.untouched_validation=false' \
  'prompt-final-leak|.design.final_benchmark_access=true' \
  'prompt-alpha|.design.alpha=0.0249999' \
  'prompt-null|.design.null_probability=0.5500001' \
  'prompt-result-leak|.design.result_release="item-level"'; do
  name=${spec%%|*}; filter=${spec#*|}; G="$TMP/$name.json"; cp "$PROMPT183" "$G"; mutate "$G" "$filter"
  assert_fail "$ENGINE" check-prompt-promotion "$POLICY" "$G"
done

# Brief/family identity is disjoint across smoke, development, and validation.
G="$TMP/prompt-overlap.json"; cp "$PROMPT183" "$G"; mutate "$G" '.validation[0].brief_id=.development[0].brief_id'
assert_fail "$ENGINE" check-prompt-promotion "$POLICY" "$G"
G="$TMP/prompt-lifecycle.json"; cp "$PROMPT183" "$G"; mutate "$G" '.lifecycle.finalist_frozen_at="2026-03-01T01:00:00Z"'
assert_fail "$ENGINE" check-prompt-promotion "$POLICY" "$G"

# Ties, abstentions, missing evidence, and invalid builds are literal non-wins.
G="$TMP/prompt-nonwins.json"; cp "$PROMPT183" "$G"
mutate "$G" '.validation[183].outcome="tie"
  | .validation[184].outcome="abstention"
  | .validation[185].outcome="missing_evidence"
  | .validation[186].outcome="invalid_candidate_build"'
PROMPT_NONWIN_REPORT="$TMP/prompt-nonwins-report.json"
assert_ok "$ENGINE" check-prompt-promotion "$POLICY" "$G" "$PROMPT_NONWIN_REPORT"
expect_eq "183 300 117" "$(jq -r '"\(.wins) \(.n) \(.non_wins)"' "$PROMPT_NONWIN_REPORT")" prompt-nonwins

# Repeated judges, paired builds, mirrors, and ballots never increase n.
G="$TMP/prompt-inflation.json"; cp "$PROMPT183" "$G"
mutate "$G" '.validation[0].candidate_builds += ["c-r1"]
  | .validation[0].baseline_builds += ["b-r1"]
  | .validation[0].mirrors += ["A/B-2"]
  | .validation[0].judge_ids += ["j4"]
  | .validation[0].ballot_ids += ["b4"]'
PROMPT_INFLATION_REPORT="$TMP/prompt-inflation-report.json"
assert_ok "$ENGINE" check-prompt-promotion "$POLICY" "$G" "$PROMPT_INFLATION_REPORT"
expect_eq "300" "$(jq -r '.n' "$PROMPT_INFLATION_REPORT")" prompt-repeated-measures

# --- diagnostic-only genericness -----------------------------------------

jq -n '{schema_version:"genericness-review/v3",qualified:false,verdict:"REVIEW_REQUIRED"}' >"$TMP/generic-review.json"
assert_ok "$ENGINE" check-genericness "$POLICY" "$TMP/generic-review.json"
for verdict in GENERIC NON_GENERIC PASS FAIL; do
  jq -n --arg verdict "$verdict" '{schema_version:"genericness-review/v3",qualified:false,verdict:$verdict}' >"$TMP/generic-$verdict.json"
  assert_fail "$ENGINE" check-genericness "$POLICY" "$TMP/generic-$verdict.json"
done
jq -n '{schema_version:"genericness-review/v3",qualified:true,verdict:"NON_GENERIC"}' >"$TMP/generic-qualified.json"
assert_fail "$ENGINE" check-genericness "$POLICY" "$TMP/generic-qualified.json"

echo "ok - evidence-dag-v3 ($ASSERTIONS assertions)"
