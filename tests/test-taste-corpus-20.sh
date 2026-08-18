#!/usr/bin/env bash
# Validator for the frozen Cycle 40 twenty-brief taste study corpus (lane corpus-20).
# CORPUS_20_EXPECT=<n> lets strata land incrementally; the default demands the
# full frozen corpus of 20 plus the study manifest with reproducible digests.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
BRIEFS_DIR="$ROOT/benchmarks/taste-live/briefs"
STUDY="$ROOT/benchmarks/taste-live/study-v1.json"
SCHEMA_V1_DIR="$ROOT/benchmarks/schema-v1"
EXPECT="${CORPUS_20_EXPECT:-20}"
ASSERTIONS=0

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { ASSERTIONS=$((ASSERTIONS + 1)); }

check() { # file jq-filter message
  jq -e "$2" "$1" >/dev/null 2>&1 || fail "$3 [$(basename "$1")]"
  pass
}

sha_file() { shasum -a 256 "$1" | awk '{print $1}'; }

EXPECTED_IDS="dog-walk-route pantry-planner repair-reminder shift-handoff study-circle \
bookstore-events climate-data-explorer neighborhood-bulk-order field-recording-catalog \
makerspace-booking pediatric-appointment art-residency-portfolio freight-dispatch \
farmers-market-portal cash-runway urban-tree-census fermentation-tracker \
live-music-calendar language-exchange tabletop-atlas"
ORIGINAL_IDS="dog-walk-route pantry-planner repair-reminder shift-handoff study-circle"

COMMON_STATES='["default","loading","empty","validation-error","success","focus","mobile"]'
STRATA='["consumer","collaboration","operations","health","finance","data","culture","logistics","education","creative"]'
ALLOWLIST='["goto","click","fill","select","press","assert_text","assert_visible","assert_count","assert_value"]'
LICENSES='["owned","public-domain","CC0","OFL","MIT","BSD","Apache"]'
BRIEF_KEYS='["acceptance_facts","action_oracle","anti_goals","asset_license_policy","brief","brief_id","category","content_seed","core_task","locked_at","not_applicable_states","offline","origin","product_shape","product_signature","required_routes","required_states","safety","schema_version","state_recipes","stratum","target_population","title"]'

[ -d "$BRIEFS_DIR" ] || fail "missing briefs dir $BRIEFS_DIR"

# --- File inventory -------------------------------------------------------
count=0
for f in "$BRIEFS_DIR"/*.json; do
  [ -e "$f" ] || fail "no brief files present"
  id=$(basename "$f" .json)
  case " $EXPECTED_IDS " in
    *" $id "*) ;;
    *) fail "unexpected brief file $id" ;;
  esac
  count=$((count + 1))
done
[ "$count" -eq "$EXPECT" ] || fail "expected $EXPECT briefs, found $count"
pass

TMP=$(mktemp -d "${TMPDIR:-/tmp}/corpus-20.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
: >"$TMP/categories"; : >"$TMP/titles"; : >"$TMP/tasks"; : >"$TMP/task-summaries"
: >"$TMP/mechanisms"; : >"$TMP/roles"; : >"$TMP/facts"; : >"$TMP/shas"; : >"$TMP/briefs-prose"

for f in "$BRIEFS_DIR"/*.json; do
  id=$(basename "$f" .json)

  jq -e . "$f" >/dev/null || fail "unparsable JSON [$id]"
  pass
  dupes=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$f" | sort | uniq -d)
  [ -z "$dupes" ] || fail "duplicate JSON key path [$id]"
  pass

  # Frozen schema: exact top-level key set, no unknown fields.
  check "$f" "keys | sort == ($BRIEF_KEYS)" "top-level keys must match frozen schema"
  check "$f" '.schema_version == "taste-study-brief/v1"' "schema_version"
  check "$f" ".brief_id == \"$id\"" "brief_id must match filename"
  check "$f" '.locked_at | test("^2026-08-12T[0-9:]+Z$")' "locked_at frozen UTC timestamp"
  check "$f" ".stratum as \$s | ($STRATA) | index(\$s) != null" "stratum in frozen strata"
  check "$f" '(.category | length) > 3 and (.title | length) > 5 and (.brief | length) > 40' "category/title/brief substance"
  check "$f" '.origin == "schema-v1" or .origin == "cycle-40-plan"' "origin enum"

  # Audience
  check "$f" '.target_population | keys | sort == ["coverage_limit","locale","role"]' "target_population shape"
  check "$f" '.target_population | (.role|length) > 8 and (.locale|length) >= 5 and (.coverage_limit|length) > 10' "target_population substance"

  # Core task
  check "$f" '.core_task | keys | sort == ["id","success_oracle","summary"]' "core_task shape"
  check "$f" ".core_task.id == \"task-$id\"" "core_task id convention"
  check "$f" '(.core_task.summary | length) > 20 and (.core_task.success_oracle | length) > 30' "core_task substance"

  # Routes
  check "$f" '.required_routes | length >= 1 and (map(startswith("/")) | all) and (length == (unique | length))' "required_routes"

  # State applicability: partition of the common seven, default+mobile required,
  # every omission carries a substantive brief-linked reason.
  check "$f" ".required_states as \$r | ($COMMON_STATES) as \$c | (\$r - \$c) == [] and (\$r | index(\"default\") != null) and (\$r | index(\"mobile\") != null)" "required_states subset with default+mobile"
  check "$f" ".required_states + (.not_applicable_states | keys) | sort == (($COMMON_STATES) | sort)" "states partition the common seven"
  check "$f" '(.required_states | length) == (.required_states | unique | length)' "required_states unique"
  check "$f" '.not_applicable_states | to_entries | map(.value | length >= 40) | all' "not-applicable reasons substantive"
  jq -e '.required_states as $r | .state_recipes | keys | sort == ([$r[] | select(. != "default")] | sort)' "$f" >/dev/null \
    || fail "state_recipes must cover every non-default required state [$id]"
  pass
  check "$f" '.state_recipes | to_entries | map(.value | length >= 20) | all' "state recipes substantive"

  # Action/assertion oracle
  check "$f" '.action_oracle | keys | sort == ["allowlist","assertions","steps","target_convention"]' "action_oracle shape"
  check "$f" '.action_oracle.target_convention == "data-testid"' "oracle target convention"
  check "$f" ".action_oracle.allowlist == ($ALLOWLIST)" "oracle allowlist frozen"
  check "$f" '.action_oracle.steps | length >= 2' "oracle needs >= 2 steps"
  check "$f" '.action_oracle.assertions | length >= 2' "oracle needs >= 2 assertions"
  check "$f" ".action_oracle.steps | map(.op) | map(. as \$o | ($ALLOWLIST) | index(\$o) != null) | all" "step ops allowlisted"
  check "$f" '.action_oracle.steps | map(.op | startswith("assert_") | not) | all' "steps are actions, not assertions"
  check "$f" '.action_oracle.assertions | map(.op | startswith("assert_")) | all' "assertions use assert_ ops"
  check "$f" ".action_oracle.assertions | map(.op) | map(. as \$o | ($ALLOWLIST) | index(\$o) != null) | all" "assertion ops allowlisted"
  check "$f" '.required_routes as $r | .action_oracle.steps[0] as $s | $s.op == "goto" and ($r | index($s.route) != null)' "first step is goto on a required route"
  check "$f" '.action_oracle.steps | map(if .op == "goto" then (.route | length) > 0 else (.target | length) > 0 end) | all' "every non-goto step names a target"
  check "$f" '.action_oracle.steps | map(if .op == "fill" then (.value | tostring | length) > 0 else true end) | all' "fill steps carry a value"
  check "$f" '.action_oracle.assertions | map((.target | length) > 0) | all' "assertions name a target"

  # Acceptance facts: exactly three, substantive.
  check "$f" '.acceptance_facts | length == 3 and (map(length >= 30) | all) and (length == (unique | length))' "exactly three substantive acceptance facts"

  # Five-part product signature
  check "$f" '.product_signature | keys | sort == ["anchor","brief_trace","counterfactual","mechanism","task_proof"]' "five-part signature shape"
  check "$f" '.product_signature | to_entries | map(.value | length >= 15) | all' "signature parts substantive"

  # Anti-goals, content seed, offline, licences, safety
  check "$f" '.anti_goals | length >= 2 and (map(length >= 15) | all)' "anti_goals"
  check "$f" '.content_seed | keys | sort == ["data_notes","entities","fictional"]' "content_seed shape"
  check "$f" '.content_seed.fictional == true and (.content_seed.entities | length >= 3) and (.content_seed.data_notes | length >= 20)' "fictional offline content seed"
  check "$f" '.offline == true' "offline"
  check "$f" '.asset_license_policy | keys | sort == ["allowed","remote_assets_forbidden"]' "licence policy shape"
  check "$f" ".asset_license_policy.allowed == ($LICENSES)" "licence allowlist frozen to protocol set"
  check "$f" '.asset_license_policy.remote_assets_forbidden == true' "remote assets forbidden"
  check "$f" '.safety | keys | sort == ["disclaimer_required","fictional_data_required","no_financial_claim","no_live_transaction","no_medical_claim"]' "safety shape"
  check "$f" '.safety.no_medical_claim == true and .safety.no_financial_claim == true and .safety.no_live_transaction == true and .safety.fictional_data_required == true' "safety booleans"

  # Cross-file uniqueness inputs
  jq -r '.category' "$f" >>"$TMP/categories"
  jq -r '.title' "$f" >>"$TMP/titles"
  jq -r '.core_task.id' "$f" >>"$TMP/tasks"
  jq -r '.core_task.summary' "$f" >>"$TMP/task-summaries"
  jq -r '.product_signature.mechanism' "$f" >>"$TMP/mechanisms"
  jq -r '.target_population.role' "$f" >>"$TMP/roles"
  jq -r '.acceptance_facts[]' "$f" >>"$TMP/facts"
  jq -r '.brief' "$f" >>"$TMP/briefs-prose"
  sha_file "$f" >>"$TMP/shas"
done

# --- Decision-support disclaimers on the sensitive units ------------------
for id in pediatric-appointment cash-runway; do
  f="$BRIEFS_DIR/$id.json"
  if [ -e "$f" ]; then
    check "$f" '.safety.disclaimer_required | type == "string" and length >= 40 and (test("decision support"; "i"))' "decision-support disclaimer required"
  fi
done

# --- Originals preserved verbatim from schema-v1 --------------------------
for id in $ORIGINAL_IDS; do
  f="$BRIEFS_DIR/$id.json"
  [ -e "$f" ] || continue
  check "$f" '.origin == "schema-v1"' "original marked schema-v1"
  for field in title brief; do
    old=$(jq -r ".$field" "$SCHEMA_V1_DIR/$id.json")
    new=$(jq -r ".$field" "$f")
    [ "$old" = "$new" ] || fail "original $field drifted [$id]"
    pass
  done
done
for f in "$BRIEFS_DIR"/*.json; do
  id=$(basename "$f" .json)
  case " $ORIGINAL_IDS " in
    *" $id "*) ;;
    *) check "$f" '.origin == "cycle-40-plan"' "addition marked cycle-40-plan" ;;
  esac
done

# --- Corpus-wide uniqueness and copy checks --------------------------------
for list in categories titles tasks task-summaries mechanisms roles facts shas briefs-prose; do
  dupes=$(sort "$TMP/$list" | uniq -d)
  [ -z "$dupes" ] || fail "duplicate $list across corpus: $dupes"
  pass
done

# --- Full-corpus gates ------------------------------------------------------
if [ "$EXPECT" -eq 20 ]; then
  # Every expected id present and all ten strata covered.
  for id in $EXPECTED_IDS; do
    [ -e "$BRIEFS_DIR/$id.json" ] || fail "missing frozen brief $id"
  done
  pass
  covered=$(jq -rs 'map(.stratum) | unique | length' "$BRIEFS_DIR"/*.json)
  [ "$covered" -eq 10 ] || fail "expected all 10 strata covered, got $covered"
  pass

  [ -e "$STUDY" ] || fail "missing study manifest $STUDY"
  jq -e . "$STUDY" >/dev/null || fail "unparsable study manifest"
  pass
  dupes=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$STUDY" | sort | uniq -d)
  [ -z "$dupes" ] || fail "duplicate JSON key path in study manifest"
  pass

  check "$STUDY" 'keys | sort == ["arms","baseline","brief_floor","brief_order","brief_sampling","briefs","builder","compiler_capacity","created_at","current_subject","executable_core","optional_audits","rules","run_id","schema_version","seed","strata","study_digest_sha256","study_id","target_locked_briefs","thresholds","tracks"]' "study top-level keys frozen"
  check "$STUDY" '.schema_version == "taste-study-manifest/v1"' "study schema_version"
  check "$STUDY" '.run_id == "c40-live-harness-20260812-a3"' "study run_id"
  check "$STUDY" '.brief_floor == 10 and .target_locked_briefs == 20 and .compiler_capacity == 100' "floor/target/capacity frozen"
  check "$STUDY" '.baseline.skill_revision == "0b802ad13ada13a0dc7cc702a526ed17d3348851"' "baseline revision frozen"
  check "$STUDY" '.current_subject.placeholder == "PENDING-CYCLE-40-GO"' "current subject is pre-generation placeholder"
  check "$STUDY" '.current_subject.resolution | test("Cycle 40 GO") and test("frozen before generation")' "subject resolution rule"
  check "$STUDY" '.builder.provider == "anthropic" and .builder.model == "claude-fable-5"' "builder provider/model frozen"
  check "$STUDY" '.rules == {"current_directions":3,"repair_cap":2,"target_briefs":20,"brief_floor":10}' "3-directions/2-repair/20-target/10-floor rules"
  check "$STUDY" '.thresholds == {"pooled_preference_min":0.70,"wilson_lcb_95_exclusive_min":0.50,"brief_wins_min":7,"mirrored_groups_per_brief_min":5,"accessibility_regressions_max":0,"calibration_pairs":24,"calibration_correct_min":17,"calibration_wilson_lcb_min":0.50,"side_probe_p_min":0.05,"mirror_contradictions_max":1}' "thresholds unchanged"
  check "$STUDY" '.seed | length >= 12' "frozen seed"
  check "$STUDY" '.arms.baseline | test("one prompt") and test("one build")' "baseline arm"
  check "$STUDY" '.arms.current | test("three structurally divergent") and test("two evidence-targeted repairs")' "current arm"
  check "$STUDY" '.tracks == ["render_fidelity","human_taste","grounding","functional_success"]' "four tracks"
  check "$STUDY" '.executable_core.offline == true' "executable core offline"
  check "$STUDY" ".executable_core.asset_licenses == ($LICENSES)" "study licences frozen"
  check "$STUDY" '.brief_order | length == 20 and (unique | length) == 20' "frozen order of 20"

  # Order covers exactly the expected ids; strata map is consistent.
  for id in $(jq -r '.brief_order[]' "$STUDY"); do
    [ -e "$BRIEFS_DIR/$id.json" ] || fail "brief_order names unknown brief $id"
  done
  pass
  jq -r '.strata | to_entries[] | .key as $k | .value[] | "\($k) \(.)"' "$STUDY" | while read -r stratum id; do
    actual=$(jq -r '.stratum' "$BRIEFS_DIR/$id.json")
    [ "$stratum" = "$actual" ] || { echo "FAIL: strata map wrong for $id ($stratum vs $actual)" >&2; exit 1; }
  done
  pass
  n_strata=$(jq -r '[.strata[] | length] | add' "$STUDY")
  [ "$n_strata" -eq 20 ] || fail "strata map must place all 20 briefs"
  pass

  # Reproducible digests: per-brief hashes, task-script hashes, study digest.
  : >"$TMP/manifest-lines"; : >"$TMP/task-lines"
  for id in $(jq -r '.brief_order[]' "$STUDY"); do
    f="$BRIEFS_DIR/$id.json"
    sha=$(sha_file "$f")
    printf '%s %s\n' "$id" "$sha" >>"$TMP/manifest-lines"
    task_sha=$(jq -cS '.action_oracle' "$f" | shasum -a 256 | awk '{print $1}')
    printf '%s %s\n' "$id" "$task_sha" >>"$TMP/task-lines"
    rec=$(jq -r --arg id "$id" '.briefs[] | select(.brief_id == $id) | .sha256' "$STUDY")
    [ "$rec" = "$sha" ] || fail "study brief sha256 stale for $id"
  done
  pass
  manifest_sha=$(shasum -a 256 <"$TMP/manifest-lines" | awk '{print $1}')
  task_sha=$(shasum -a 256 <"$TMP/task-lines" | awk '{print $1}')
  [ "$(jq -r '.brief_sampling.manifest_sha256' "$STUDY")" = "$manifest_sha" ] || fail "brief_sampling.manifest_sha256 mismatch"
  pass
  [ "$(jq -r '.executable_core.task_scripts_sha256' "$STUDY")" = "$task_sha" ] || fail "executable_core.task_scripts_sha256 mismatch"
  pass
  study_digest=$(printf '%s\n%s\n%s\n%s\n' "$manifest_sha" "$task_sha" \
    "$(jq -r '.baseline.skill_revision' "$STUDY")" "$(jq -r '.seed' "$STUDY")" | shasum -a 256 | awk '{print $1}')
  [ "$(jq -r '.study_digest_sha256' "$STUDY")" = "$study_digest" ] || fail "study_digest_sha256 not reproducible"
  pass
  check "$STUDY" '.briefs | length == 20' "study briefs receipt count"
fi

echo "ok test-taste-corpus-20 ($ASSERTIONS assertions, $count briefs)"
