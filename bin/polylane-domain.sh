#!/usr/bin/env bash
# Declarative, deterministic domain execution contracts.
set -euo pipefail

usage() {
  echo "usage: polylane-domain.sh contract <kind> | questions <kind> [--json] | bundle <profile.json> <artifact-root> <bundle.json> | grade <profile.json> <bundle.json> [--json]" >&2
  exit 2
}

die() { echo "polylane-domain: $*" >&2; exit 2; }

valid_kind() {
  case "$1" in software|trading|research|operations|content|data|custom|mixed) ;; *) die "unknown domain kind: $1" ;; esac
}

contract() {
  local kind="$1" grader capabilities
  valid_kind "$kind"
  case "$kind" in
    trading) grader='["chronological-split","holdout-or-walk-forward","costs-and-slippage","leakage","robustness","drawdown-limits","selection-bias","simulation-only"]'; capabilities='["local-fixture","read-only-source-metadata","simulation"]' ;;
    research) grader='["query-source-ledger","inclusion-exclusion","citation-coverage","synthesis","uncertainty-limitations"]'; capabilities='["local-fixture","read-only-source-metadata"]' ;;
    operations) grader='["owner","controls","tabletop-or-dry-run","kpi","rollback-recovery","approval-boundaries"]'; capabilities='["local-fixture","simulation","read-only-source-metadata"]' ;;
    content) grader='["audience","factual-source-audit","editorial-brand-rubric","declared-variants","publication-approval"]'; capabilities='["local-fixture","read-only-source-metadata"]' ;;
    data) grader='["schema","provenance","quality-report","deterministic-transform","idempotence","sample-output","monitoring","rollback"]'; capabilities='["local-fixture","simulation","read-only-source-metadata"]' ;;
    software) grader='["build-evidence","test-evidence","user-path-evidence","source-seams-when-applicable"]'; capabilities='["local-fixture","simulation"]' ;;
    *) grader='["declared-artifacts","declared-evidence-modes","risk-action-policy"]'; capabilities='["local-fixture","simulation","read-only-source-metadata"]' ;;
  esac
  jq -n --arg kind "$kind" --argjson grader "$grader" --argjson capabilities "$capabilities" '
    {version:"domain-runtime/v1", kind:$kind, capabilities:$capabilities,
     dependencies:[{name:"jq", required:true}], side_effect_class:"read-only-or-simulation",
     input:{public_source:"read-only-metadata", local_input:true},
     offline:{fixture_required:true, fallback:"deterministic-local-fixture"},
     provenance:{required_fields:["source_id","input_hash","collected_at","method","fixture_or_public"]},
     grader:{required_checks:$grader, no_vacuous_pass:true},
     question_tree:{min_questions:4, max_questions:8, adaptive_paths:["recommended","deep","bold","custom"], stopping_rule:"stop only when answers no longer change deliverables, evidence, risk, or action boundaries"},
     deliverable_requirements:{manifest:"checksum-bearing", evidence:true, provenance:true},
     action_policy:{autonomous:["read-only","simulation"], consequential:"approval-required", execution:"forbidden"}}
  ' | jq -S .
}

questions_json() {
  local kind="$1" focus
  valid_kind "$kind"
  case "$kind" in
    trading) focus='evaluation|What time split, costs, and paper-only boundary make this strategy credible?|Specify chronological train/holdout and walk-forward windows|Stress slippage, drawdown, and selection-bias assumptions' ;;
    research) focus='sources|Which sources and inclusion rules make the conclusion reproducible?|Record query strings, source identities, and exclusion reasons|Challenge the leading conclusion with disconfirming sources' ;;
    operations) focus='controls|Which owner, controls, and rollback path protect the operation?|Name the accountable owner and dry-run/tabletop evidence|Design for the worst credible outage and recovery exercise' ;;
    content) focus='audience|Who is the audience and how will factual/editorial quality be audited?|Define audience, sources, and brand rubric|Test a distinct angle or variant before publication approval' ;;
    data) focus='pipeline|What schema, provenance, and rollback make this data pipeline safe?|Specify schema, deterministic transform, and idempotence test|Probe failure monitoring and recovery with a hostile input' ;;
    software) focus='user-path|Which user path and source seam prove the software outcome?|Name the build, tests, and first user path|Challenge the smallest safe architecture boundary' ;;
    *) focus='outcome|Which declared artifact and evidence mode define success?|Make every artifact, provenance record, and action boundary explicit|Reframe the risk policy for the most consequential credible outcome' ;;
  esac
  IFS='|' read -r id question recommended bold <<EOF
$focus
EOF
  jq -n --arg kind "$kind" --arg id "$id" --arg question "$question" --arg recommended "$recommended" --arg bold "$bold" '
    def paths($recommended; $bold): {
      recommended:{answer:$recommended},
      deep:{answer:("Investigate the highest-impact assumption behind: " + $recommended), follow_up:{id:(.id + "-deep"), question:"What evidence would change this decision?", paths:{recommended:{answer:"Use a representative local fixture"},deep:{answer:"Examine edge cases"},bold:{answer:"Try a contrary hypothesis"},custom:{answer:"Provide a specific answer"}}}},
      bold:{answer:$bold, follow_up:{id:(.id + "-bold"), question:"What new action boundary follows?", paths:{recommended:{answer:"Keep simulation only"},deep:{answer:"Model worst credible impact"},bold:{answer:"Narrow the scope"},custom:{answer:"Provide a specific answer"}}}},
      custom:{answer:"Provide a specific answer"}
    };
    [
      {id:($kind + "-" + $id), impact:100, question:$question},
      {id:($kind + "-deliverable"), impact:90, question:"Which deliverable will make the result independently checkable?"},
      {id:($kind + "-evidence"), impact:85, question:"What evidence and provenance must accompany it?"},
      {id:($kind + "-risk"), impact:80, question:"What risk or action boundary could change the plan?"}
    ] | map(. + {kind:$kind, paths:(. | paths($recommended; $bold)), stopping:{deliverable_change:true,evidence_change:true,risk_change:true,action_boundary_change:true, stop_when:"answers no longer change any declared boundary"}})
  ' | jq -S .
}

cmd_questions() {
  local kind="$1" format="text"
  [ "${2:-}" = "--json" ] && format="json"
  questions_json "$kind" > /tmp/polylane-domain-questions.$$
  if [ "$format" = "json" ]; then cat /tmp/polylane-domain-questions.$$; else jq -r '.[] | "[\(.id)] \(.question)"' /tmp/polylane-domain-questions.$$; fi
  rm -f /tmp/polylane-domain-questions.$$
}

project_validate() {
  local profile="$1" project
  project="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/polylane-project.sh"
  "$project" validate "$profile" >/dev/null
}

require_provenance() {
  jq -e '
    .domain_runtime.provenance | type == "object" and
    (.source_id | type == "string" and length > 0) and
    (.input_hash | type == "string" and length > 0) and
    (.collected_at | type == "string" and length > 0) and
    (.method | type == "string" and length > 0) and
    (.fixture_or_public | IN("fixture", "public"))
  ' "$1" >/dev/null
}

cmd_bundle() {
  local profile="$1" artifact_root="$2" output="$3" root entries tmp provenance
  project_validate "$profile"
  require_provenance "$profile" || die "profile is missing required provenance"
  [ -d "$artifact_root" ] || die "artifact root does not exist: $artifact_root"
  root=$(cd "$artifact_root" && pwd -P)
  entries=$(mktemp "${TMPDIR:-/tmp}/polylane-domain-entries.XXXXXX")
  tmp=$(mktemp "${output}.tmp.XXXXXX")
  trap 'rm -f "$entries" "$tmp"' RETURN
  while IFS= read -r path; do
    [ -f "$root/$path" ] || die "declared deliverable is missing: $path"
    jq -cn --arg path "$path" --arg checksum "$(cksum "$root/$path" | awk '{print $1 ":" $2}')" \
      '{path:$path, checksum:$checksum}' >> "$entries"
  done <<EOF
$(jq -r '.deliverables[].path' "$profile")
EOF
  provenance=$(jq -c '.domain_runtime.provenance' "$profile")
  jq -s --arg root "$root" --arg kind "$(jq -r '.kind' "$profile")" --argjson provenance "$provenance" '
    {version:"domain-runtime/bundle-v1", kind:$kind, artifact_root:$root,
     provenance:$provenance, entries:., bundle_id:(. | tojson | @base64)}
  ' "$entries" | jq -S . > "$tmp"
  mv "$tmp" "$output"
  rm -f "$entries"
  trap - RETURN
}

grade_add() {
  local file="$1" name="$2" passed="$3" detail="$4"
  jq -cn --arg name "$name" --arg detail "$detail" --argjson passed "$passed" \
    '{name:$name, passed:$passed, detail:$detail}' >> "$file"
}

grade_profile_check() {
  local file="$1" profile="$2" name="$3" expression="$4"
  if jq -e "$expression" "$profile" >/dev/null; then
    grade_add "$file" "$name" true "declared"
  else
    grade_add "$file" "$name" false "missing or invalid"
  fi
}

grade_domain_checks() {
  local file="$1" profile="$2" kind="$3"
  case "$kind" in
    trading)
      grade_profile_check "$file" "$profile" chronological-split '.domain_runtime.checks.chronological_split == true'
      grade_profile_check "$file" "$profile" holdout-walk-forward '.domain_runtime.checks.holdout_or_walk_forward == true'
      grade_profile_check "$file" "$profile" costs-slippage '.domain_runtime.checks.costs_and_slippage == true'
      grade_profile_check "$file" "$profile" leakage-false '.domain_runtime.checks.leakage == false'
      grade_profile_check "$file" "$profile" robustness-sensitivity '.domain_runtime.checks.robustness_or_sensitivity == true'
      grade_profile_check "$file" "$profile" drawdown-risk-limits '.domain_runtime.checks.drawdown_or_risk_limits == true'
      grade_profile_check "$file" "$profile" trial-count-selection-bias '.domain_runtime.checks.trial_count_or_selection_bias_disclosure == true'
      grade_profile_check "$file" "$profile" paper-simulation-only '.domain_runtime.checks.paper_or_simulation_only == true'
      ;;
    research) for n in query_source_ledger inclusion_exclusion citation_coverage synthesis uncertainty_limitations; do grade_profile_check "$file" "$profile" "$n" ".domain_runtime.checks.$n == true"; done ;;
    operations) for n in owner controls tabletop_or_dry_run kpi rollback_recovery approval_boundaries; do grade_profile_check "$file" "$profile" "$n" ".domain_runtime.checks.$n == true"; done ;;
    content) for n in audience factual_source_audit editorial_brand_rubric declared_variants publication_approval; do grade_profile_check "$file" "$profile" "$n" ".domain_runtime.checks.$n == true"; done ;;
    data) for n in schema provenance quality_report deterministic_transform idempotence sample_output monitoring rollback; do grade_profile_check "$file" "$profile" "$n" ".domain_runtime.checks.$n == true"; done ;;
    software) for n in build_evidence test_evidence user_path_evidence; do grade_profile_check "$file" "$profile" "$n" ".domain_runtime.checks.$n == true"; done ;;
    *) grade_profile_check "$file" "$profile" declared-artifacts '.domain_runtime.checks.declared_artifacts == true'; grade_profile_check "$file" "$profile" declared-evidence '.domain_runtime.checks.declared_evidence_modes == true'; grade_profile_check "$file" "$profile" risk-action-policy '.domain_runtime.checks.risk_action_policy == true' ;;
  esac
}

cmd_grade() {
  local profile="$1" bundle="$2" checks kind root path checksum expected actual result
  project_validate "$profile"
  [ -f "$bundle" ] || die "bundle does not exist: $bundle"
  jq empty "$bundle" >/dev/null 2>&1 || die "bundle is not valid JSON: $bundle"
  checks=$(mktemp "${TMPDIR:-/tmp}/polylane-domain-grade.XXXXXX")
  trap 'rm -f "$checks"' RETURN
  kind=$(jq -r '.kind' "$profile")
  if require_provenance "$profile"; then grade_add "$checks" profile-provenance true "five provenance fields present"; else grade_add "$checks" profile-provenance false "missing required provenance"; fi
  if jq -e --argjson p "$(jq -c '.domain_runtime.provenance // {}' "$profile")" '.version == "domain-runtime/bundle-v1" and .provenance == $p' "$bundle" >/dev/null; then grade_add "$checks" bundle-provenance true "matches profile"; else grade_add "$checks" bundle-provenance false "missing or mismatched"; fi
  if jq -e --arg kind "$kind" '.kind == $kind and (.entries | type == "array" and length > 0)' "$bundle" >/dev/null; then grade_add "$checks" bundle-shape true "versioned manifest"; else grade_add "$checks" bundle-shape false "missing version, kind, or entries"; fi
  root=$(jq -r '.artifact_root // empty' "$bundle")
  if [ -n "$root" ] && [ -d "$root" ]; then
    actual=true
    while IFS= read -r path; do
      expected=$(jq -r --arg path "$path" '.entries[]? | select(.path == $path) | .checksum' "$bundle" | head -n 1)
      checksum=""
      [ -f "$root/$path" ] && checksum=$(cksum "$root/$path" | awk '{print $1 ":" $2}')
      [ -n "$expected" ] && [ "$expected" = "$checksum" ] || actual=false
    done <<EOF
$(jq -r '.deliverables[].path' "$profile")
EOF
    if [ "$actual" = true ]; then grade_add "$checks" declared-deliverables true "all declared paths match checksums"; else grade_add "$checks" declared-deliverables false "missing or checksum-mismatched artifact"; fi
  else
    grade_add "$checks" declared-deliverables false "artifact root unavailable"
  fi
  grade_domain_checks "$checks" "$profile" "$kind"
  result=$(jq -s '{version:"domain-runtime/grade-v1", kind:$ARGS.named.kind, checks:., verdict:(if all(.[]; .passed) then "PASS" else "FAIL" end)}' --arg kind "$kind" "$checks")
  printf '%s\n' "$result" | jq -S .
  rm -f "$checks"
  trap - RETURN
  [ "$(printf '%s' "$result" | jq -r '.verdict')" = PASS ]
}

main() {
  command -v jq >/dev/null 2>&1 || die "jq is required"
  case "${1:-}" in
    contract) [ "$#" = 2 ] || usage; contract "$2" ;;
    questions) [ "$#" = 2 ] || [ "$#" = 3 ] || usage; cmd_questions "$2" "${3:-}" ;;
    bundle) [ "$#" = 4 ] || usage; cmd_bundle "$2" "$3" "$4" ;;
    grade) [ "$#" = 3 ] || [ "$#" = 4 ] || usage; cmd_grade "$2" "$3" ;;
    *) usage ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
