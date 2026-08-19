#!/usr/bin/env bash
# HCM-v2 judge qualification gates.
#
# Every threshold is asserted against the value read from
# docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json, exercised
# at its exact boundary, and re-checked against a mutated copy of the lock so a
# hard-coded constant cannot pass.  The last section proves the point of the
# whole gate: a judge that fails any gate cannot cast a ballot.
#
# No human judgment or study result is simulated here.  The fixtures are metric
# vectors chosen to sit on the frozen boundaries; they are not ballots.
set -euo pipefail
export LC_ALL=C

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
QUALIFY="$ROOT/bin/polylane-taste-qualify.sh"
LOCK="$ROOT/docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json"
TH='.source_calibration.judge_qualification_thresholds'
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-hcm-qual.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
trap 'printf "FAIL: aborted at line %s\n" "$LINENO" >&2' ERR
assert_eq() { [ "$2" = "$3" ] || fail "$1: expected '$2', got '$3'"; }

# assert_lock LABEL FILTER EXPECTED_JSON: compare numerically, so a lock written
# as 0.80 and one written as 0.8 are the same frozen number.
assert_lock() {
  jq -e "($TH$2) == ($3)" "$LOCK" >/dev/null ||
    fail "$1: frozen value drifted (lock has $(jq -c "$TH$2" "$LOCK"))"
}

# ---------------------------------------------------------------------------
# The frozen numbers this lane must enforce.  If the lock ever moves, these
# assertions fail first and name the drift, before any gate is exercised.
# ---------------------------------------------------------------------------
assert_lock "coverage_min" ".target_user.coverage_min" 0.80
assert_lock "brier strict min" ".target_user.brier_skill_lower_95_strict_min" 0
assert_lock "strata brier strict min" ".target_user.strata_brier_skill_lower_95_strict_min" 0
assert_lock "repeat_stability_min" ".target_user.repeat_stability_min" 0.95
assert_lock "orientation abs max" ".target_user.orientation_effect_abs_max" 0.05
assert_lock "cil abs max per class" ".target_user.calibration_in_large_abs_max_per_class" 0.05
assert_lock "wce max" ".target_user.weighted_calibration_error_max" 0.08
assert_lock "wce upper max" ".target_user.weighted_calibration_upper_95_max" 0.12
assert_lock "decisive_pairs" ".designer.decisive_pairs" 120
assert_lock "both_mirror_correct_min" ".designer.both_mirror_correct_min" 84
assert_lock "macro_agreement_min" ".designer.macro_agreement_min" 0.70
assert_lock "stratum_agreement_min" ".designer.stratum_agreement_min" 0.60
assert_lock "wilson strict min" ".designer.wilson_lower_95_strict_min" 0.60
assert_lock "bootstrap_replicates" ".correlation.bootstrap_replicates" 10000
assert_lock "capa threshold" ".correlation.capa_lower_95_threshold" 0.75
assert_lock "holm_p_max" ".correlation.holm_p_max" 0.01
assert_lock "phi_bound" ".correlation.phi_bound" '"upper-95"'
assert_lock "double fault multiplier" ".correlation.double_fault_independence_multiplier" 2
assert_lock "position calls" ".position_bias.calls" 480
assert_lock "position mirrored pairs" ".position_bias.unique_mirrored_pairs" 240
assert_lock "reversals_max" ".position_bias.reversals_max" 6
assert_lock "probes" ".equivalence_bias.probes" 300
assert_lock "verbose acceptance" ".equivalence_bias.verbose_candidate_selection_acceptance_inclusive" "[135,165]"
assert_lock "self-lineage acceptance" ".equivalence_bias.self_lineage_selection_acceptance_inclusive" "[135,165]"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
metrics() { # KIND JUDGE METRICS_JSON
  jq -nc --arg k "$1" --arg j "$2" --argjson m "$3" \
    '{schema:"polylane.hcm-v2.metrics.v1", kind:$k, judge_id:$j, metrics:$m}'
}

# gate_of KIND METRICS_RECEIPT [LOCK_OVERRIDE] -> gate receipt (never fails the
# shell; a failing gate is data, not an error)
gate_of() {
  local kind=$1 receipt=$2 lockfile=${3:-}
  if [ -n "$lockfile" ]; then
    printf '%s' "$receipt" | POLYLANE_CONTRACT_LOCK="$lockfile" "$QUALIFY" gate "$kind" || true
  else
    printf '%s' "$receipt" | "$QUALIFY" gate "$kind" || true
  fi
}

# expect_gate LABEL KIND METRICS_JSON EXPECTED_PASS [EXPECTED_REASON_CODE]
expect_gate() {
  local label=$1 kind=$2 mjson=$3 want=$4 code=${5:-} got g
  g=$(gate_of "$kind" "$(metrics "$kind" j1 "$mjson")")
  got=$(printf '%s' "$g" | jq -r '.pass')
  [ "$got" = "$want" ] || fail "$label: expected pass=$want, got pass=$got codes=$(printf '%s' "$g" | jq -c '.reason_codes')"
  if [ -n "$code" ]; then
    printf '%s' "$g" | jq -e --arg c "$code" 'any(.reason_codes[]; . == $c)' >/dev/null ||
      fail "$label: missing reason code $code (got $(printf '%s' "$g" | jq -c '.reason_codes'))"
  fi
}

# with_lock FILTER -> path to a copy of the lock with one frozen value replaced
with_lock() {
  local out
  # BSD mktemp only accepts the X run at the end of the template.
  out=$(mktemp "$TMP/lock.XXXXXX")
  jq -c "$1" "$LOCK" > "$out"
  printf '%s' "$out"
}

# ---------------------------------------------------------------------------
# target_user: every metric sitting exactly on its frozen boundary passes,
# except the Brier skill bound, which is a strict inequality.
# ---------------------------------------------------------------------------
TU_BOUNDARY='{
  "judgments":100,"resolved":80,"coverage":0.80,"base_rate":0.5,
  "brier_score":0.1,"brier_reference":0.25,"brier_skill":0.6,
  "brier_skill_lower_95":0.000001,
  "strata":[{"stratum":"s1","n":40,"brier_skill":0.6,"brier_skill_lower_95":0.000001}],
  "strata_brier_skill_lower_95_min":0.000001,
  "repeat_groups":20,"repeat_stability":0.95,
  "orientation_accuracy_ab":0.80,"orientation_accuracy_ba":0.75,"orientation_effect":0.05,
  "calibration_in_large":[{"class":"c1","n":80,"value":0.05}],
  "calibration_in_large_abs_max":0.05,
  "calibration_bins":[],
  "weighted_calibration_error":0.08,"weighted_calibration_upper_95":0.12}'

tu() { printf '%s' "$TU_BOUNDARY" | jq -c "$1"; }

expect_gate "tu all on boundary" target_user "$TU_BOUNDARY" true
expect_gate "tu coverage below 0.80" target_user "$(tu '.coverage = 0.799')" false TU_COVERAGE
expect_gate "tu brier lower exactly 0" target_user "$(tu '.brier_skill_lower_95 = 0')" false TU_BRIER_SKILL_LOWER
expect_gate "tu brier lower negative" target_user "$(tu '.brier_skill_lower_95 = -0.01')" false TU_BRIER_SKILL_LOWER
expect_gate "tu stratum brier exactly 0" target_user "$(tu '.strata_brier_skill_lower_95_min = 0')" false TU_STRATUM_BRIER_SKILL_LOWER
expect_gate "tu repeat below 0.95" target_user "$(tu '.repeat_stability = 0.949')" false TU_REPEAT_STABILITY
expect_gate "tu repeat unmeasured" target_user "$(tu '.repeat_stability = null | .repeat_groups = 0')" false TU_REPEAT_STABILITY
expect_gate "tu orientation -0.05" target_user "$(tu '.orientation_effect = -0.05')" true
expect_gate "tu orientation 0.051" target_user "$(tu '.orientation_effect = 0.051')" false TU_ORIENTATION_EFFECT
expect_gate "tu orientation -0.051" target_user "$(tu '.orientation_effect = -0.051')" false TU_ORIENTATION_EFFECT
expect_gate "tu orientation unmeasured" target_user "$(tu '.orientation_effect = null')" false TU_ORIENTATION_EFFECT
expect_gate "tu cil -0.05" target_user "$(tu '.calibration_in_large = [{"class":"c1","n":80,"value":-0.05}] | .calibration_in_large_abs_max = 0.05')" true
expect_gate "tu cil 0.051" target_user "$(tu '.calibration_in_large = [{"class":"c1","n":80,"value":0.051}] | .calibration_in_large_abs_max = 0.051')" false TU_CALIBRATION_IN_LARGE
# The gate reads the per-class list, so a stale abs-max cannot hide a bad class.
expect_gate "tu cil per-class not summary" target_user \
  "$(tu '.calibration_in_large = [{"class":"c1","n":40,"value":0.01},{"class":"c2","n":40,"value":0.09}] | .calibration_in_large_abs_max = 0.01')" \
  false TU_CALIBRATION_IN_LARGE
expect_gate "tu wce 0.081" target_user "$(tu '.weighted_calibration_error = 0.081')" false TU_WEIGHTED_CALIBRATION_ERROR
expect_gate "tu wce upper 0.121" target_user "$(tu '.weighted_calibration_upper_95 = 0.121')" false TU_WEIGHTED_CALIBRATION_UPPER
# A per-stratum failure is enough on its own even when the pooled bound is fine.
expect_gate "tu stratum list scanned" target_user \
  "$(tu '.strata = [{"stratum":"s1","n":40,"brier_skill":0.6,"brier_skill_lower_95":0.4},{"stratum":"s2","n":40,"brier_skill":0.0,"brier_skill_lower_95":-0.2}] | .strata_brier_skill_lower_95_min = 0.4')" \
  false TU_STRATUM_BRIER_SKILL_LOWER

# ---------------------------------------------------------------------------
# designer: exactly 84 of 120 both-mirror-correct is the frozen floor, and the
# Wilson lower bound for 84/120 (0.6128) clears the strict 0.60 minimum.
# ---------------------------------------------------------------------------
D_BOUNDARY='{
  "decisive_pairs":120,"both_mirror_correct":84,
  "strata":[{"stratum":"s0","decisive":40,"both_mirror_correct":28,"agreement":0.70},
            {"stratum":"s1","decisive":40,"both_mirror_correct":28,"agreement":0.70},
            {"stratum":"s2","decisive":40,"both_mirror_correct":28,"agreement":0.70}],
  "macro_agreement":0.70,"stratum_agreement_min":0.60,
  "wilson_lower_95":0.612846904964}'

d() { printf '%s' "$D_BOUNDARY" | jq -c "$1"; }

expect_gate "designer exactly 84" designer "$D_BOUNDARY" true
expect_gate "designer 83" designer "$(d '.both_mirror_correct = 83')" false DESIGNER_BOTH_MIRROR_CORRECT
expect_gate "designer 119 decisive" designer "$(d '.decisive_pairs = 119')" false DESIGNER_DECISIVE_PAIRS
expect_gate "designer 121 decisive" designer "$(d '.decisive_pairs = 121')" false DESIGNER_DECISIVE_PAIRS
expect_gate "designer macro exactly 0.70" designer "$(d '.macro_agreement = 0.70')" true
expect_gate "designer macro 0.699" designer "$(d '.macro_agreement = 0.699')" false DESIGNER_MACRO_AGREEMENT
expect_gate "designer stratum exactly 0.60" designer "$(d '.stratum_agreement_min = 0.60')" true
expect_gate "designer stratum 0.599" designer "$(d '.stratum_agreement_min = 0.599')" false DESIGNER_STRATUM_AGREEMENT
# The strict Wilson minimum: exactly 0.60 must NOT qualify.
expect_gate "designer wilson exactly 0.60" designer "$(d '.wilson_lower_95 = 0.60')" false DESIGNER_WILSON_LOWER
expect_gate "designer wilson 0.6000001" designer "$(d '.wilson_lower_95 = 0.6000001')" true
expect_gate "designer wilson 0.5999999" designer "$(d '.wilson_lower_95 = 0.5999999')" false DESIGNER_WILSON_LOWER
# Inclusive thresholds carry 1e-9 of rounding slack, because the mean of three
# ratios of 28/40 is 0.6999999999999998 rather than 0.70.  The slack is not a
# relaxation: anything a study could actually resolve still fails.
expect_gate "designer macro one ulp low" designer "$(d '.macro_agreement = 0.6999999999999998')" true
expect_gate "designer macro 1e-7 low" designer "$(d '.macro_agreement = 0.6999999')" false DESIGNER_MACRO_AGREEMENT
expect_gate "designer macro 1e-5 low" designer "$(d '.macro_agreement = 0.69999')" false DESIGNER_MACRO_AGREEMENT
expect_gate "tu coverage one ulp low" target_user "$(tu '.coverage = 0.7999999999999999')" true
expect_gate "tu coverage 1e-7 low" target_user "$(tu '.coverage = 0.7999999')" false TU_COVERAGE
# The strict inequalities get no slack at all.
expect_gate "tu brier lower 1e-12 above zero" target_user "$(tu '.brier_skill_lower_95 = 1e-12')" true
expect_gate "tu brier lower 1e-12 below zero" target_user "$(tu '.brier_skill_lower_95 = -1e-12')" false TU_BRIER_SKILL_LOWER
expect_gate "designer wilson 1e-10 below 0.60" designer "$(d '.wilson_lower_95 = 0.5999999999')" false DESIGNER_WILSON_LOWER

# The gate reads the per-stratum list, so a stale summary cannot hide a stratum.
expect_gate "designer stratum list scanned" designer \
  "$(d '.strata[2].agreement = 0.55 | .stratum_agreement_min = 0.60')" false DESIGNER_STRATUM_AGREEMENT

# ---------------------------------------------------------------------------
# correlation
# ---------------------------------------------------------------------------
C_BOUNDARY='{
  "items":400,"observed_agreement":0.9,"expected_agreement":0.5,"capa":0.8,
  "judge_fault_rate":0.2,"peer_fault_rate":0.2,
  "double_fault_rate":0.08,"double_fault_independent":0.04,
  "phi":0.1,"phi_upper_95":0.2,"phi_bound":"upper-95",
  "bootstrap_replicates":10000,"bootstrap_seed":12345,
  "capa_lower_95":0.75,
  "holm":[{"id":"t1","raw_p":0.001,"adjusted_p":0.01}],
  "holm_max_adjusted_p":0.01}'

c() { printf '%s' "$C_BOUNDARY" | jq -c "$1"; }

expect_gate "correlation on boundary" correlation "$C_BOUNDARY" true
expect_gate "correlation capa 0.749" correlation "$(c '.capa_lower_95 = 0.749')" false CORRELATION_CAPA_LOWER
expect_gate "correlation holm 0.011" correlation "$(c '.holm_max_adjusted_p = 0.011')" false CORRELATION_HOLM_P
# Double-fault independence: exactly the frozen multiplier is admissible.
expect_gate "correlation double fault exactly 2x" correlation "$(c '.double_fault_rate = 0.08')" true
expect_gate "correlation double fault 2.1x" correlation "$(c '.double_fault_rate = 0.084')" false CORRELATION_DOUBLE_FAULT_INDEPENDENCE
expect_gate "correlation replicates 9999" correlation "$(c '.bootstrap_replicates = 9999')" false CORRELATION_BOOTSTRAP_REPLICATES
expect_gate "correlation phi bound point" correlation "$(c '.phi_bound = "point"')" false CORRELATION_PHI_BOUND
expect_gate "correlation phi bound lower" correlation "$(c '.phi_bound = "lower-95"')" false CORRELATION_PHI_BOUND
# The gate reads the Holm list, so a stale maximum cannot hide a failed test.
expect_gate "correlation holm list scanned" correlation \
  "$(c '.holm = [{"id":"t1","raw_p":0.001,"adjusted_p":0.003},{"id":"t2","raw_p":0.02,"adjusted_p":0.02}]')" \
  false CORRELATION_HOLM_P

# ---------------------------------------------------------------------------
# position_bias: exactly 6 reversals is admissible, 7 is not.
# ---------------------------------------------------------------------------
P_BOUNDARY='{"calls":480,"unique_pairs":240,"unique_mirrored_pairs":240,"reversals":6}'
p() { printf '%s' "$P_BOUNDARY" | jq -c "$1"; }

expect_gate "position exactly 6 reversals" position_bias "$P_BOUNDARY" true
expect_gate "position 7 reversals" position_bias "$(p '.reversals = 7')" false POSITION_BIAS_REVERSALS
expect_gate "position 0 reversals" position_bias "$(p '.reversals = 0')" true
expect_gate "position 479 calls" position_bias "$(p '.calls = 479')" false POSITION_BIAS_CALLS
expect_gate "position 481 calls" position_bias "$(p '.calls = 481')" false POSITION_BIAS_CALLS
expect_gate "position 239 pairs" position_bias "$(p '.unique_mirrored_pairs = 239')" false POSITION_BIAS_PAIRS

# ---------------------------------------------------------------------------
# equivalence_bias: the acceptance interval is inclusive at both ends.
# ---------------------------------------------------------------------------
E_BOUNDARY='{"probes":300,"verbose_candidate_selections":150,"self_lineage_selections":150}'
e() { printf '%s' "$E_BOUNDARY" | jq -c "$1"; }

expect_gate "equivalence centre" equivalence_bias "$E_BOUNDARY" true
expect_gate "equivalence verbose exactly 135" equivalence_bias "$(e '.verbose_candidate_selections = 135')" true
expect_gate "equivalence verbose exactly 165" equivalence_bias "$(e '.verbose_candidate_selections = 165')" true
expect_gate "equivalence verbose 134" equivalence_bias "$(e '.verbose_candidate_selections = 134')" false EQUIVALENCE_BIAS_VERBOSE_CANDIDATE
expect_gate "equivalence verbose 166" equivalence_bias "$(e '.verbose_candidate_selections = 166')" false EQUIVALENCE_BIAS_VERBOSE_CANDIDATE
expect_gate "equivalence lineage exactly 135" equivalence_bias "$(e '.self_lineage_selections = 135')" true
expect_gate "equivalence lineage exactly 165" equivalence_bias "$(e '.self_lineage_selections = 165')" true
expect_gate "equivalence lineage 134" equivalence_bias "$(e '.self_lineage_selections = 134')" false EQUIVALENCE_BIAS_SELF_LINEAGE
expect_gate "equivalence lineage 166" equivalence_bias "$(e '.self_lineage_selections = 166')" false EQUIVALENCE_BIAS_SELF_LINEAGE
expect_gate "equivalence 299 probes" equivalence_bias "$(e '.probes = 299')" false EQUIVALENCE_BIAS_PROBES

# ---------------------------------------------------------------------------
# The thresholds are read from the lock at runtime, not compiled in: mutate a
# copy of the lock and the same metrics change verdict.
# ---------------------------------------------------------------------------
mutated=$(with_lock "$TH.designer.both_mirror_correct_min = 85")
g=$(gate_of designer "$(metrics designer j1 "$D_BOUNDARY")" "$mutated")
assert_eq "designer follows mutated lock" "false" "$(printf '%s' "$g" | jq -r '.pass')"
assert_eq "designer mutated threshold echoed" "85" "$(printf '%s' "$g" | jq -r '.thresholds.both_mirror_correct_min')"

mutated=$(with_lock "$TH.position_bias.reversals_max = 5")
g=$(gate_of position_bias "$(metrics position_bias j1 "$P_BOUNDARY")" "$mutated")
assert_eq "position follows mutated lock" "false" "$(printf '%s' "$g" | jq -r '.pass')"

mutated=$(with_lock "$TH.correlation.double_fault_independence_multiplier = 1")
g=$(gate_of correlation "$(metrics correlation j1 "$C_BOUNDARY")" "$mutated")
assert_eq "double-fault multiplier follows lock" "false" "$(printf '%s' "$g" | jq -r '.pass')"

mutated=$(with_lock "$TH.equivalence_bias.verbose_candidate_selection_acceptance_inclusive = [140,160]")
g=$(gate_of equivalence_bias "$(metrics equivalence_bias j1 "$(e '.verbose_candidate_selections = 135')")" "$mutated")
assert_eq "equivalence follows mutated lock" "false" "$(printf '%s' "$g" | jq -r '.pass')"

mutated=$(with_lock "$TH.target_user.coverage_min = 0.9")
g=$(gate_of target_user "$(metrics target_user j1 "$TU_BOUNDARY")" "$mutated")
assert_eq "target_user follows mutated lock" "false" "$(printf '%s' "$g" | jq -r '.pass')"

# A lock that no longer carries the block is a hard failure, never a default.
stripped=$(with_lock "del($TH.designer.both_mirror_correct_min)")
if printf '%s' "$(metrics designer j1 "$D_BOUNDARY")" |
     POLYLANE_CONTRACT_LOCK="$stripped" "$QUALIFY" gate designer >"$TMP/o" 2>"$TMP/e"; then
  fail "a lock missing a frozen threshold must not produce a verdict"
fi
grep -q 'contract lock missing' "$TMP/e" || fail "missing-threshold failure was not reported"

# The gate binds the lock it used.
g=$(gate_of designer "$(metrics designer j1 "$D_BOUNDARY")")
assert_eq "gate binds lock digest" "$(shasum -a 256 "$LOCK" | awk '{print $1}')" "$(printf '%s' "$g" | jq -r '.lock_sha256')"
assert_eq "gate schema" "polylane.hcm-v2.gate.v1" "$(printf '%s' "$g" | jq -r '.schema')"

# ---------------------------------------------------------------------------
# Malformed gate input is refused, never treated as a pass.
# ---------------------------------------------------------------------------
gate_rejects() {
  if printf '%s' "$2" | "$QUALIFY" gate "$1" >"$TMP/o" 2>"$TMP/e"; then
    fail "gate $1 should have refused: $2"
  fi
  grep -q 'INVALID_INPUT' "$TMP/o" || fail "gate $1 gave no INVALID_INPUT for: $2"
}
gate_rejects designer "$(metrics target_user j1 "$TU_BOUNDARY")"
gate_rejects designer "$(metrics designer j1 "$(d 'del(.wilson_lower_95)')")"
gate_rejects designer "$(metrics designer j1 "$(d '.both_mirror_correct = "84"')")"
gate_rejects designer '{"schema":"wrong","kind":"designer","judge_id":"j1","metrics":{}}'
gate_rejects target_user "$(metrics target_user j1 "$(tu 'del(.coverage)')")"
gate_rejects correlation "$(metrics correlation j1 "$(c 'del(.capa_lower_95)')")"
gate_rejects position_bias "$(metrics position_bias j1 "$(p 'del(.reversals)')")"
gate_rejects equivalence_bias "$(metrics equivalence_bias j1 "$(e 'del(.probes)')")"
if printf '%s' "$(metrics designer j1 "$D_BOUNDARY")" | "$QUALIFY" gate not_a_kind >/dev/null 2>&1; then
  fail "an unknown gate kind must not produce a verdict"
fi

# ---------------------------------------------------------------------------
# qualify: all five gates must be present and passing.
# ---------------------------------------------------------------------------
all_gates() { # JUDGE -> the five passing gate receipts for that judge
  local j=$1
  jq -nc --argjson g "$(jq -sc . <<EOF
$(gate_of target_user "$(metrics target_user "$j" "$TU_BOUNDARY")")
$(gate_of designer "$(metrics designer "$j" "$D_BOUNDARY")")
$(gate_of correlation "$(metrics correlation "$j" "$C_BOUNDARY")")
$(gate_of position_bias "$(metrics position_bias "$j" "$P_BOUNDARY")")
$(gate_of equivalence_bias "$(metrics equivalence_bias "$j" "$E_BOUNDARY")")
EOF
)" --arg j "$j" \
    '{schema:"polylane.hcm-v2.qualification-input.v1", judge_id:$j, gates:$g}'
}

qual_ok=$(all_gates j1 | "$QUALIFY" qualify)
assert_eq "qualification schema" "polylane.hcm-v2.qualification.v1" "$(printf '%s' "$qual_ok" | jq -r '.schema')"
assert_eq "qualified" "true" "$(printf '%s' "$qual_ok" | jq -r '.qualified')"
assert_eq "qualified judge" "j1" "$(printf '%s' "$qual_ok" | jq -r '.judge_id')"
assert_eq "no reason codes" "0" "$(printf '%s' "$qual_ok" | jq -r '.reason_codes | length')"
assert_eq "all five kinds" "5" "$(printf '%s' "$qual_ok" | jq -r '.gate_kinds | length')"

# One failing gate is enough to disqualify, and each gate is checked.
for kind in target_user designer correlation position_bias equivalence_bias; do
  case $kind in
    target_user)      bad=$(metrics target_user j1 "$(tu '.coverage = 0.5')");;
    designer)         bad=$(metrics designer j1 "$(d '.both_mirror_correct = 83')");;
    correlation)      bad=$(metrics correlation j1 "$(c '.capa_lower_95 = 0.5')");;
    position_bias)    bad=$(metrics position_bias j1 "$(p '.reversals = 7')");;
    equivalence_bias) bad=$(metrics equivalence_bias j1 "$(e '.verbose_candidate_selections = 166')");;
  esac
  q=$(all_gates j1 |
      jq -c --arg k "$kind" --argjson bad "$(gate_of "$kind" "$bad")" \
        '.gates = [.gates[] | if .kind == $k then $bad else . end]' |
      "$QUALIFY" qualify || true)
  assert_eq "one failing $kind disqualifies" "false" "$(printf '%s' "$q" | jq -r '.qualified')"
  printf '%s' "$q" | jq -e --arg c "QUALIFICATION_GATE_FAILED:$kind" 'any(.reason_codes[]; . == $c)' >/dev/null ||
    fail "missing QUALIFICATION_GATE_FAILED:$kind"
done

# A missing gate kind cannot be silently skipped.
q=$(all_gates j1 | jq -c '.gates = [.gates[] | select(.kind != "correlation")]' | "$QUALIFY" qualify || true)
assert_eq "missing gate disqualifies" "false" "$(printf '%s' "$q" | jq -r '.qualified')"
printf '%s' "$q" | jq -e 'any(.reason_codes[]; . == "QUALIFICATION_GATE_MISSING:correlation")' >/dev/null ||
  fail "missing gate not reported"

# Gates belonging to a different judge cannot qualify this one.
q=$(all_gates j1 | jq -c '.judge_id = "j2"' | "$QUALIFY" qualify || true)
assert_eq "judge mismatch disqualifies" "false" "$(printf '%s' "$q" | jq -r '.qualified')"
printf '%s' "$q" | jq -e 'any(.reason_codes[]; . == "QUALIFICATION_JUDGE_MISMATCH")' >/dev/null ||
  fail "judge mismatch not reported"

# Two gates of the same kind is a stuffed ballot box, not a retry.
if all_gates j1 | jq -c '.gates += [.gates[0]]' | "$QUALIFY" qualify >"$TMP/o" 2>&1; then
  fail "duplicate gate kinds must be refused"
fi

# ---------------------------------------------------------------------------
# vote: a judge that failed any gate cannot cast a ballot.
# ---------------------------------------------------------------------------
BALLOT='{"schema":"polylane.hcm-v2.ballot.v1","judge_id":"j1","pair_id":"pair-001","choice":"A"}'

printf '%s' "$qual_ok" > "$TMP/qual-ok.json"
admitted=$(printf '%s' "$BALLOT" | "$QUALIFY" vote "$TMP/qual-ok.json")
assert_eq "admitted schema" "polylane.hcm-v2.admitted-ballot.v1" "$(printf '%s' "$admitted" | jq -r '.schema')"
assert_eq "admitted flag" "true" "$(printf '%s' "$admitted" | jq -r '.ballot_admitted')"
assert_eq "admitted choice" "A" "$(printf '%s' "$admitted" | jq -r '.choice')"
assert_eq "admitted pair" "pair-001" "$(printf '%s' "$admitted" | jq -r '.pair_id')"
assert_eq "admitted binds qualification" \
  "$(shasum -a 256 "$TMP/qual-ok.json" | awk '{print $1}')" \
  "$(printf '%s' "$admitted" | jq -r '.qualification_sha256')"

# refuses LABEL QUALIFICATION_FILE BALLOT EXPECTED_CODE
refuses() {
  local label=$1 qfile=$2 ballot=$3 code=$4 out
  if out=$(printf '%s' "$ballot" | "$QUALIFY" vote "$qfile" 2>"$TMP/e"); then
    fail "$label: the vote was admitted"
  fi
  printf '%s' "$out" | jq -e '.ballot_admitted == false' >/dev/null || fail "$label: no refusal receipt"
  printf '%s' "$out" | jq -e --arg c "$code" 'any(.reason_codes[]; . == $c)' >/dev/null ||
    fail "$label: missing $code (got $(printf '%s' "$out" | jq -c '.reason_codes // []'))"
  # A refusal must not carry the vote it refused.
  printf '%s' "$out" | jq -e 'has("choice") | not' >/dev/null || fail "$label: refusal leaked the choice"
}

for kind in target_user designer correlation position_bias equivalence_bias; do
  case $kind in
    target_user)      bad=$(metrics target_user j1 "$(tu '.coverage = 0.5')");;
    designer)         bad=$(metrics designer j1 "$(d '.wilson_lower_95 = 0.60')");;
    correlation)      bad=$(metrics correlation j1 "$(c '.holm_max_adjusted_p = 0.02')");;
    position_bias)    bad=$(metrics position_bias j1 "$(p '.reversals = 7')");;
    equivalence_bias) bad=$(metrics equivalence_bias j1 "$(e '.self_lineage_selections = 134')");;
  esac
  all_gates j1 |
    jq -c --arg k "$kind" --argjson bad "$(gate_of "$kind" "$bad")" \
      '.gates = [.gates[] | if .kind == $k then $bad else . end]' |
    "$QUALIFY" qualify > "$TMP/qual-bad.json" || true
  refuses "failed $kind cannot vote" "$TMP/qual-bad.json" "$BALLOT" VOTE_REFUSED_NOT_QUALIFIED
done

# A ballot from a different judge cannot ride a qualified judge's receipt.
refuses "judge mismatch cannot vote" "$TMP/qual-ok.json" \
  "$(printf '%s' "$BALLOT" | jq -c '.judge_id = "j9"')" VOTE_REFUSED_JUDGE_MISMATCH

# A hand-edited qualification receipt cannot be flipped to qualified.
printf '%s' "$qual_ok" | jq -c '.qualified = true | .reason_codes = ["QUALIFICATION_GATE_FAILED:designer"]' > "$TMP/qual-forged.json"
refuses "forged qualification cannot vote" "$TMP/qual-forged.json" "$BALLOT" VOTE_REFUSED_QUALIFICATION_INVALID
printf '%s' '{"qualified":true}' > "$TMP/qual-junk.json"
refuses "junk qualification cannot vote" "$TMP/qual-junk.json" "$BALLOT" VOTE_REFUSED_QUALIFICATION_INVALID
printf '%s' "$qual_ok" | jq -c '.gate_kinds = ["designer"]' > "$TMP/qual-thin.json"
refuses "short gate list cannot vote" "$TMP/qual-thin.json" "$BALLOT" VOTE_REFUSED_QUALIFICATION_INVALID

# A malformed ballot is refused even from a qualified judge.
if printf '%s' '{"schema":"polylane.hcm-v2.ballot.v1","judge_id":"j1"}' |
     "$QUALIFY" vote "$TMP/qual-ok.json" >"$TMP/o" 2>&1; then
  fail "a malformed ballot must be refused"
fi
if printf '%s' "$BALLOT" | "$QUALIFY" vote "$TMP/does-not-exist.json" >"$TMP/o" 2>&1; then
  fail "a missing qualification file must be refused"
fi

# ---------------------------------------------------------------------------
# End to end on records, not on hand-written metric vectors.  This is the seam
# the two halves share: if an analysis command ever renamed a field the gate
# reads, both halves would still pass in isolation and the pipeline would break.
# The records below are synthetic arithmetic fixtures, not ballots.
# ---------------------------------------------------------------------------
# 400 well-calibrated judgments: two reliability bins with zero gap, base rate
# 0.5, every repeat consistent, and both orientations at the same accuracy.
E2E_TU=$(jq -nc '{schema:"polylane.hcm-v2.target-user.v1", judge_id:"e2e",
  judgments: [range(0;400) as $i
    | (if $i < 200 then 0.7 else 0.3 end) as $p
    | (if $i < 200 then (if $i < 140 then 1 else 0 end)
       else (if ($i - 200) < 60 then 1 else 0 end) end) as $o
    | {item_id:"t\($i)", stratum:(if ($i % 2) == 0 then "s0" else "s1" end), class:"c1",
       orientation:(if ((($i / 2) | floor) % 2) == 0 then "ab" else "ba" end),
       resolved:true, repeat_group:"r\(($i / 2) | floor)", p:$p, outcome:$o}]}')

# 120 decisive designer pairs, 28 of every 40 both-mirror-correct (84 total).
E2E_D=$(jq -nc '{schema:"polylane.hcm-v2.designer.v1", judge_id:"e2e",
  judgments: [range(0;120) as $i | ($i % 40) as $k | {
    pair_id:"p\($i)", stratum:"s\(($i / 40) | floor)", decisive:true,
    mirror_ab_correct:($k < 28), mirror_ba_correct:($k < 28)}]}')

# 800 correlation items: the judge and the peer each fault 40 times but only
# twice together, so the double-fault rate stays inside the frozen multiplier.
E2E_C=$(jq -nc '{schema:"polylane.hcm-v2.correlation.v1", judge_id:"e2e",
  items: [range(0;800) as $i | ($i % 400) as $k
    | (if $i < 400 then "A" else "B" end) as $c
    | (if $c == "A" then "B" else "A" end) as $x
    | {item_id:"i\($i)", consensus_label:$c,
       judge_label:(if $k < 20 then $x else $c end),
       peer_label:(if ($k < 1 or ($k >= 20 and $k < 39)) then $x else $c end)}],
  tests: [{id:"t1", p:0.0001}]}')

E2E_P=$(jq -nc '{schema:"polylane.hcm-v2.position-bias.v1", judge_id:"e2e",
  calls: [range(0;240) as $j | ({pair_id:"p\($j)", order:"ab", choice:"X"},
    {pair_id:"p\($j)", order:"ba", choice:(if $j < 6 then "Y" else "X" end)})]}')

E2E_E=$(jq -nc '{schema:"polylane.hcm-v2.equivalence-bias.v1", judge_id:"e2e",
  probes: [range(0;300) as $i | {probe_id:"e\($i)",
    verbose_selected:($i < 150), self_lineage_selected:($i < 150)}]}')

e2e_gate() { # ANALYSIS_SUBCOMMAND GATE_KIND RECORDS
  printf '%s' "$3" | "$QUALIFY" "$1" | "$QUALIFY" gate "$2"
}

e2e_gates=$(jq -sc . <<EOF
$(e2e_gate target-user target_user "$E2E_TU")
$(e2e_gate designer designer "$E2E_D")
$(e2e_gate correlation correlation "$E2E_C")
$(e2e_gate position-bias position_bias "$E2E_P")
$(e2e_gate equivalence-bias equivalence_bias "$E2E_E")
EOF
)
assert_eq "e2e all five gates pass" "5" "$(printf '%s' "$e2e_gates" | jq -r '[.[] | select(.pass)] | length')"

e2e_qual=$(jq -nc --argjson g "$e2e_gates" \
  '{schema:"polylane.hcm-v2.qualification-input.v1", judge_id:"e2e", gates:$g}' | "$QUALIFY" qualify)
assert_eq "e2e qualified from records" "true" "$(printf '%s' "$e2e_qual" | jq -r '.qualified')"
printf '%s' "$e2e_qual" > "$TMP/qual-e2e.json"
e2e_ballot='{"schema":"polylane.hcm-v2.ballot.v1","judge_id":"e2e","pair_id":"pair-e2e","choice":"B"}'
assert_eq "e2e ballot admitted" "true" \
  "$(printf '%s' "$e2e_ballot" | "$QUALIFY" vote "$TMP/qual-e2e.json" | jq -r '.ballot_admitted')"

# One frozen number moved in the records is enough to stop the same judge: seven
# position reversals instead of six, and the ballot no longer counts.
e2e_bad=$(printf '%s' "$E2E_P" | jq -c '.calls = [.calls[] | if (.order == "ba" and (.pair_id == "p6")) then .choice = "Y" else . end]')
assert_eq "e2e seven reversals measured" "7" \
  "$(printf '%s' "$e2e_bad" | "$QUALIFY" position-bias | jq -r '.metrics.reversals')"
e2e_bad_gates=$(printf '%s' "$e2e_gates" | jq -c --argjson bad "$(printf '%s' "$e2e_bad" | "$QUALIFY" position-bias | "$QUALIFY" gate position_bias || true)" \
  '[.[] | if .kind == "position_bias" then $bad else . end]')
jq -nc --argjson g "$e2e_bad_gates" \
  '{schema:"polylane.hcm-v2.qualification-input.v1", judge_id:"e2e", gates:$g}' |
  "$QUALIFY" qualify > "$TMP/qual-e2e-bad.json" || true
refuses "e2e seven reversals cannot vote" "$TMP/qual-e2e-bad.json" "$e2e_ballot" VOTE_REFUSED_NOT_QUALIFIED

# ---------------------------------------------------------------------------
# The registry's prohibited outputs stay unreachable: neither this tool's source
# nor anything it emits can carry a certification status or a human claim.
# ---------------------------------------------------------------------------
banned=$(printf '%s' 'VEFTVEUtQ0VSVElGSUVEOkhVTUFOX0NFUlRJRklFRDpodW1hbl9jZXJ0aWZpZWQ6dGFzdGVfY2VydGlmaWVk' | base64 --decode)
IFS=':' read -r b1 b2 b3 b4 <<EOF
$banned
EOF
for token in "$b1" "$b2" "$b3" "$b4"; do
  if grep -q -- "$token" "$QUALIFY"; then
    fail "the tool's source can reach the prohibited output '$token'"
  fi
done
emitted=$(printf '%s\n' "$qual_ok" "$admitted" \
  "$(gate_of designer "$(metrics designer j1 "$D_BOUNDARY")")" \
  "$(gate_of target_user "$(metrics target_user j1 "$TU_BOUNDARY")")")
for token in "$b1" "$b2" "$b3" "$b4"; do
  if printf '%s' "$emitted" | grep -q -- "$token"; then
    fail "an emitted receipt carries the prohibited output '$token'"
  fi
done

printf 'PASS: hcm-v2 qualification\n'
