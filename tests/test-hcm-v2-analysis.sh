#!/usr/bin/env bash
# HCM-v2 analysis maths.  Every expectation in this file is derived by hand from
# a synthetic dataset with a known answer (the derivations live in
# docs/verify-hcm-stats.md); nothing here is copied from the implementation's
# own output.  No human judgment or study result is simulated: these fixtures
# exist only to prove the arithmetic.
set -euo pipefail
export LC_ALL=C

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
QUALIFY="$ROOT/bin/polylane-taste-qualify.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-hcm-analysis.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
trap 'printf "FAIL: aborted at line %s\n" "$LINENO" >&2' ERR
assert_eq() { [ "$2" = "$3" ] || fail "$1: expected '$2', got '$3'"; }

# assert_close LABEL EXPECTED ACTUAL TOLERANCE
assert_close() {
  awk -v l="$1" -v e="$2" -v a="$3" -v t="$4" 'BEGIN{
    d = e - a; if (d < 0) d = -d;
    if (d > t) { printf "FAIL: %s: expected %.12g, got %.12g (tol %g)\n", l, e, a, t; exit 1 }
  }' || exit 1
}

m() { printf '%s' "$1" | jq -r "$2"; }

# ---------------------------------------------------------------------------
# Target user: Brier skill on a zero-variance set (skill exactly 0.75)
#
# 8 resolved items, 4 outcomes of 1 and 4 of 0, so the reference base rate is
# 0.5 and every reference squared error is (0.5 - o)^2 = 0.25.  Forecasts are
# 0.75 on the ones and 0.25 on the zeros, so every squared error is 0.0625 and
# every per-item skill contribution d_i = 0.25 - 0.0625 = 0.1875.  sd(d) = 0, so
# the lower 95% bound equals the point estimate: 0.1875 / 0.25 = 0.75.
# ---------------------------------------------------------------------------
tu_flat=$(jq -nc '{schema:"polylane.hcm-v2.target-user.v1", judge_id:"tu-flat",
  judgments: [range(0;8) as $i | {
    item_id:"i\($i)",
    stratum:(if $i < 4 then "s1" else "s2" end),
    class:"c1",
    orientation:(if ($i % 2) == 0 then "ab" else "ba" end),
    resolved:true,
    p:(if $i < 4 then 0.75 else 0.25 end),
    outcome:(if $i < 4 then 1 else 0 end)}]}')

out=$(printf '%s' "$tu_flat" | "$QUALIFY" target-user)
assert_eq "schema" "polylane.hcm-v2.metrics.v1" "$(m "$out" .schema)"
assert_eq "kind" "target_user" "$(m "$out" .kind)"
assert_eq "judge_id" "tu-flat" "$(m "$out" .judge_id)"
assert_close "coverage" 1 "$(m "$out" .metrics.coverage)" 1e-12
assert_close "base_rate" 0.5 "$(m "$out" .metrics.base_rate)" 1e-12
assert_close "brier_score" 0.0625 "$(m "$out" .metrics.brier_score)" 1e-12
assert_close "brier_reference" 0.25 "$(m "$out" .metrics.brier_reference)" 1e-12
assert_close "brier_skill" 0.75 "$(m "$out" .metrics.brier_skill)" 1e-12
assert_close "brier_skill_lower_95" 0.75 "$(m "$out" .metrics.brier_skill_lower_95)" 1e-12
assert_eq "strata count" "2" "$(m "$out" '.metrics.strata | length')"
assert_close "stratum s1 skill" 0.75 "$(m "$out" '.metrics.strata[] | select(.stratum=="s1") | .brier_skill')" 1e-12
assert_close "stratum s1 lower" 0.75 "$(m "$out" '.metrics.strata[] | select(.stratum=="s1") | .brier_skill_lower_95')" 1e-12
assert_close "strata min lower" 0.75 "$(m "$out" .metrics.strata_brier_skill_lower_95_min)" 1e-12
assert_close "orientation_effect" 0 "$(m "$out" .metrics.orientation_effect)" 1e-12
assert_close "calibration_in_large c1" 0 "$(m "$out" '.metrics.calibration_in_large[] | select(.class=="c1") | .value')" 1e-12
assert_eq "repeat_stability absent" "null" "$(m "$out" .metrics.repeat_stability)"

# ---------------------------------------------------------------------------
# Target user: Brier skill with non-zero variance
#
# outcomes 1,1,0,0 (base rate 0.5, reference error 0.25 each); forecasts
# 0.9, 0.7, 0.1, 0.5.  Squared errors 0.01, 0.09, 0.01, 0.25 -> Brier 0.09.
# d = 0.24, 0.16, 0.24, 0.00 -> mean 0.16, sample sd sqrt(0.0128) = 0.11313708,
# se = 0.05656854, lower mean = 0.16 - 1.96*se = 0.04912566.
# skill = 0.16/0.25 = 0.64; lower = 0.04912566/0.25 = 0.19650263.
# ---------------------------------------------------------------------------
tu_var=$(jq -nc '{schema:"polylane.hcm-v2.target-user.v1", judge_id:"tu-var",
  judgments: [
    {item_id:"a", stratum:"s1", class:"c1", orientation:"ab", resolved:true, p:0.9, outcome:1},
    {item_id:"b", stratum:"s1", class:"c1", orientation:"ab", resolved:true, p:0.7, outcome:1},
    {item_id:"c", stratum:"s1", class:"c1", orientation:"ba", resolved:true, p:0.1, outcome:0},
    {item_id:"d", stratum:"s1", class:"c1", orientation:"ba", resolved:true, p:0.5, outcome:0}]}')

out=$(printf '%s' "$tu_var" | "$QUALIFY" target-user)
assert_close "var brier_score" 0.09 "$(m "$out" .metrics.brier_score)" 1e-12
assert_close "var brier_skill" 0.64 "$(m "$out" .metrics.brier_skill)" 1e-12
assert_close "var brier_skill_lower_95" 0.196502626840 "$(m "$out" .metrics.brier_skill_lower_95)" 1e-9
# orientation: ab items both correct (1.0); ba items -> 0.1 correct, 0.5 wrong
# because a forecast of exactly 0.5 decides for outcome 1.  Effect 1.0-0.5=0.5.
assert_close "var orientation_effect" 0.5 "$(m "$out" .metrics.orientation_effect)" 1e-12

# ---------------------------------------------------------------------------
# Coverage: 8 resolved of 10 judgments is exactly 0.80; unresolved judgments
# never enter the Brier arithmetic.
# ---------------------------------------------------------------------------
tu_cov=$(jq -nc '{schema:"polylane.hcm-v2.target-user.v1", judge_id:"tu-cov",
  judgments: ([range(0;8) as $i | {item_id:"r\($i)", stratum:"s1", class:"c1",
      orientation:(if ($i % 2) == 0 then "ab" else "ba" end), resolved:true,
      p:(if $i < 4 then 0.75 else 0.25 end), outcome:(if $i < 4 then 1 else 0 end)}]
    + [range(0;2) as $i | {item_id:"u\($i)", resolved:false}])}')
out=$(printf '%s' "$tu_cov" | "$QUALIFY" target-user)
assert_close "coverage 0.80" 0.80 "$(m "$out" .metrics.coverage)" 1e-12
assert_eq "resolved count" "8" "$(m "$out" .metrics.resolved)"
assert_eq "judgment count" "10" "$(m "$out" .metrics.judgments)"
assert_close "coverage brier_skill" 0.75 "$(m "$out" .metrics.brier_skill)" 1e-12

# ---------------------------------------------------------------------------
# Repeat stability: 20 repeat groups of 2, 19 consistent -> exactly 0.95.
# Groups with a single exposure are not repeats and never enter the ratio.
# Half the groups carry outcome 1 and half outcome 0 so the base rate stays 0.5.
# ---------------------------------------------------------------------------
tu_rep=$(jq -nc '{schema:"polylane.hcm-v2.target-user.v1", judge_id:"tu-rep",
  judgments: [range(0;20) as $g | (range(0;2) as $k
    | (if $g < 10 then 1 else 0 end) as $o | {
      item_id:"g\($g)-\($k)", stratum:"s1", class:"c1",
      orientation:(if $k == 0 then "ab" else "ba" end), resolved:true,
      repeat_group:"g\($g)",
      p:(if ($g == 0 and $k == 1) then 0.25 elif $o == 1 then 0.75 else 0.25 end),
      outcome:$o})]}')
out=$(printf '%s' "$tu_rep" | "$QUALIFY" target-user)
assert_eq "repeat groups" "20" "$(m "$out" .metrics.repeat_groups)"
assert_close "repeat_stability 0.95" 0.95 "$(m "$out" .metrics.repeat_stability)" 1e-12

# ---------------------------------------------------------------------------
# Calibration-in-large: per class, mean(p) - mean(outcome).  Class "hi" has
# mean p 0.55 against a base rate of 0.5 -> exactly +0.05.  Class "lo" has mean
# p 0.40 against 0.5 -> exactly -0.10.  The reported abs-max is 0.10.
# ---------------------------------------------------------------------------
tu_cil=$(jq -nc '{schema:"polylane.hcm-v2.target-user.v1", judge_id:"tu-cil",
  judgments: ([range(0;4) as $i | {item_id:"h\($i)", stratum:"s1", class:"hi",
      orientation:"ab", resolved:true, p:0.55, outcome:(if $i < 2 then 1 else 0 end)}]
    + [range(0;4) as $i | {item_id:"l\($i)", stratum:"s2", class:"lo",
      orientation:"ba", resolved:true, p:0.40, outcome:(if $i < 2 then 1 else 0 end)}])}')
out=$(printf '%s' "$tu_cil" | "$QUALIFY" target-user)
assert_close "cil hi" 0.05 "$(m "$out" '.metrics.calibration_in_large[] | select(.class=="hi") | .value')" 1e-12
assert_close "cil lo" -0.10 "$(m "$out" '.metrics.calibration_in_large[] | select(.class=="lo") | .value')" 1e-12
assert_close "cil abs max" 0.10 "$(m "$out" .metrics.calibration_in_large_abs_max)" 1e-12

# ---------------------------------------------------------------------------
# Weighted calibration error: fixed 0.1-wide bins.  200 items at p=0.8 with 140
# ones (bin mean outcome 0.7, gap 0.1) and 200 items at p=0.3 with 60 ones (bin
# mean outcome 0.3, gap 0.0).  ECE = 0.5*0.1 + 0.5*0.0 = 0.05.
# se = sqrt(0.5^2 * 0.7*0.3/200 + 0.5^2 * 0.3*0.7/200) = 0.02291288
# upper 95 = 0.05 + 1.96*0.02291288 = 0.09490924.
# ---------------------------------------------------------------------------
tu_wce=$(jq -nc '{schema:"polylane.hcm-v2.target-user.v1", judge_id:"tu-wce",
  judgments: ([range(0;200) as $i | {item_id:"a\($i)", stratum:"s1", class:"c1",
      orientation:(if ($i % 2) == 0 then "ab" else "ba" end), resolved:true,
      p:0.8, outcome:(if $i < 140 then 1 else 0 end)}]
    + [range(0;200) as $i | {item_id:"b\($i)", stratum:"s2", class:"c1",
      orientation:(if ($i % 2) == 0 then "ab" else "ba" end), resolved:true,
      p:0.3, outcome:(if $i < 60 then 1 else 0 end)}])}')
out=$(printf '%s' "$tu_wce" | "$QUALIFY" target-user)
assert_eq "calibration bins" "2" "$(m "$out" '.metrics.calibration_bins | length')"
assert_close "weighted_calibration_error" 0.05 "$(m "$out" .metrics.weighted_calibration_error)" 1e-12
assert_close "weighted_calibration_upper_95" 0.094909241811 "$(m "$out" .metrics.weighted_calibration_upper_95)" 1e-9

# ---------------------------------------------------------------------------
# Designer: 120 decisive pairs over 3 strata of 40, 28 both-mirror-correct per
# stratum -> 84 total, every stratum agreement 0.70, macro 0.70, and the Wilson
# lower 95 bound for 84/120 is 0.612846904964 (z = 1.96).
# ---------------------------------------------------------------------------
designer_even=$(jq -nc '{schema:"polylane.hcm-v2.designer.v1", judge_id:"d-even",
  judgments: [range(0;120) as $i | ($i % 40) as $k | {
    pair_id:"p\($i)", stratum:"s\(($i / 40) | floor)", decisive:true,
    mirror_ab_correct:($k < 28), mirror_ba_correct:($k < 28)}]}')
out=$(printf '%s' "$designer_even" | "$QUALIFY" designer)
assert_eq "designer kind" "designer" "$(m "$out" .kind)"
assert_eq "decisive_pairs" "120" "$(m "$out" .metrics.decisive_pairs)"
assert_eq "both_mirror_correct" "84" "$(m "$out" .metrics.both_mirror_correct)"
assert_close "macro_agreement" 0.70 "$(m "$out" .metrics.macro_agreement)" 1e-12
assert_close "stratum_agreement_min" 0.70 "$(m "$out" .metrics.stratum_agreement_min)" 1e-12
assert_close "wilson_lower_95" 0.612846904964 "$(m "$out" .metrics.wilson_lower_95)" 1e-9

# Macro can pass while a single stratum collapses: 36/28/20 of 40 is still 84
# and still macro 0.70, but the weakest stratum is 0.50.
designer_skew=$(jq -nc '{schema:"polylane.hcm-v2.designer.v1", judge_id:"d-skew",
  judgments: [range(0;120) as $i | ($i % 40) as $k | (($i / 40) | floor) as $s | {
    pair_id:"p\($i)", stratum:"s\($s)", decisive:true,
    mirror_ab_correct:($k < ([36,28,20][$s])), mirror_ba_correct:($k < ([36,28,20][$s]))}]}')
out=$(printf '%s' "$designer_skew" | "$QUALIFY" designer)
assert_eq "skew both_mirror_correct" "84" "$(m "$out" .metrics.both_mirror_correct)"
assert_close "skew macro_agreement" 0.70 "$(m "$out" .metrics.macro_agreement)" 1e-12
assert_close "skew stratum_agreement_min" 0.50 "$(m "$out" .metrics.stratum_agreement_min)" 1e-12

# One mirror right and the other wrong is not both-mirror-correct.
designer_half=$(jq -nc '{schema:"polylane.hcm-v2.designer.v1", judge_id:"d-half",
  judgments: [range(0;120) as $i | {
    pair_id:"p\($i)", stratum:"s0", decisive:true,
    mirror_ab_correct:true, mirror_ba_correct:($i < 84)}]}')
out=$(printf '%s' "$designer_half" | "$QUALIFY" designer)
assert_eq "half both_mirror_correct" "84" "$(m "$out" .metrics.both_mirror_correct)"

# Indecisive pairs leave the denominator entirely.
designer_indecisive=$(jq -nc '{schema:"polylane.hcm-v2.designer.v1", judge_id:"d-ind",
  judgments: [range(0;130) as $i | {
    pair_id:"p\($i)", stratum:"s0", decisive:($i < 120),
    mirror_ab_correct:($i < 84), mirror_ba_correct:($i < 84)}]}')
out=$(printf '%s' "$designer_indecisive" | "$QUALIFY" designer)
assert_eq "indecisive decisive_pairs" "120" "$(m "$out" .metrics.decisive_pairs)"
assert_eq "indecisive both_mirror_correct" "84" "$(m "$out" .metrics.both_mirror_correct)"

# ---------------------------------------------------------------------------
# Correlation: a perfectly agreeing set makes every bootstrap replicate produce
# CAPA = (1 - pe)/(1 - pe) = 1, so the lower 95 bound is exactly 1 whatever the
# resampling draws.  That is the one bootstrap answer that is knowable without
# reimplementing the generator.
# ---------------------------------------------------------------------------
corr_perfect=$(jq -nc '{schema:"polylane.hcm-v2.correlation.v1", judge_id:"c-perfect",
  items: [range(0;100) as $i | (if $i < 50 then "A" else "B" end) as $c | {
    item_id:"i\($i)", consensus_label:$c, judge_label:$c, peer_label:$c}],
  tests: [{id:"t1", p:0.0001}]}')
out=$(printf '%s' "$corr_perfect" | "$QUALIFY" correlation)
assert_eq "correlation kind" "correlation" "$(m "$out" .kind)"
assert_close "perfect capa" 1 "$(m "$out" .metrics.capa)" 1e-12
assert_close "perfect capa_lower_95" 1 "$(m "$out" .metrics.capa_lower_95)" 1e-12
assert_eq "bootstrap_replicates" "10000" "$(m "$out" .metrics.bootstrap_replicates)"
assert_eq "phi_bound" "upper-95" "$(m "$out" .metrics.phi_bound)"
assert_close "perfect double_fault_rate" 0 "$(m "$out" .metrics.double_fault_rate)" 1e-12

# Determinism: the same input must yield the same bootstrap bound twice.
out2=$(printf '%s' "$corr_perfect" | "$QUALIFY" correlation)
assert_eq "correlation deterministic" "$out" "$out2"

# CAPA with a known point value: 100 items, 80 agreements, both marginals split
# 50/50 so pe = 0.5 and CAPA = (0.8 - 0.5)/(1 - 0.5) = 0.6.  The judge and the
# peer each fault 20 times with 4 joint faults, so the observed double-fault
# rate is 0.04 and the independent product is 0.2*0.2 = 0.04 (phi exactly 0).
corr_known=$(jq -nc '{schema:"polylane.hcm-v2.correlation.v1", judge_id:"c-known",
  items: [range(0;100) as $i | ($i % 50) as $k
    | (if $i < 50 then "A" else "B" end) as $c
    | (if $c == "A" then "B" else "A" end) as $o
    | {item_id:"i\($i)", consensus_label:$c,
       judge_label:(if $k < 10 then $o else $c end),
       peer_label:(if ($k < 2 or ($k >= 10 and $k < 18)) then $o else $c end)}],
  tests: [{id:"t1", p:0.0001}]}')
out=$(printf '%s' "$corr_known" | "$QUALIFY" correlation)
assert_close "known observed_agreement" 0.8 "$(m "$out" .metrics.observed_agreement)" 1e-12
assert_close "known expected_agreement" 0.5 "$(m "$out" .metrics.expected_agreement)" 1e-12
assert_close "known capa" 0.6 "$(m "$out" .metrics.capa)" 1e-12
assert_close "known judge_fault_rate" 0.2 "$(m "$out" .metrics.judge_fault_rate)" 1e-12
assert_close "known peer_fault_rate" 0.2 "$(m "$out" .metrics.peer_fault_rate)" 1e-12
assert_close "known double_fault_rate" 0.04 "$(m "$out" .metrics.double_fault_rate)" 1e-12
assert_close "known double_fault_independent" 0.04 "$(m "$out" .metrics.double_fault_independent)" 1e-12
assert_close "known phi" 0 "$(m "$out" .metrics.phi)" 1e-12
# The bootstrap lower bound must sit below the point estimate and inside the
# normal-approximation band: sd(capa) ~ 2*sqrt(0.8*0.2/100) = 0.08, so the
# 2.5th percentile lands near 0.6 - 1.96*0.08 = 0.443.
assert_eq "known capa_lower below point" "true" "$(m "$out" '.metrics.capa_lower_95 < .metrics.capa')"
assert_eq "known capa_lower in band" "true" "$(m "$out" '.metrics.capa_lower_95 > 0.38 and .metrics.capa_lower_95 < 0.50')"
assert_eq "known phi_upper above point" "true" "$(m "$out" '.metrics.phi_upper_95 > .metrics.phi')"

# Holm step-down: raw p 0.001, 0.004, 0.02 with k=3 gives adjusted
# 0.003, max(0.003, 0.008) = 0.008, max(0.008, 0.02) = 0.02 -> max 0.02.
holm=$(jq -nc '{schema:"polylane.hcm-v2.correlation.v1", judge_id:"c-holm",
  items: [range(0;100) as $i | (if $i < 50 then "A" else "B" end) as $c | {
    item_id:"i\($i)", consensus_label:$c, judge_label:$c, peer_label:$c}],
  tests: [{id:"t1", p:0.001},{id:"t2", p:0.004},{id:"t3", p:0.02}]}')
out=$(printf '%s' "$holm" | "$QUALIFY" correlation)
assert_close "holm t1" 0.003 "$(m "$out" '.metrics.holm[] | select(.id=="t1") | .adjusted_p')" 1e-12
assert_close "holm t2" 0.008 "$(m "$out" '.metrics.holm[] | select(.id=="t2") | .adjusted_p')" 1e-12
assert_close "holm t3" 0.02 "$(m "$out" '.metrics.holm[] | select(.id=="t3") | .adjusted_p')" 1e-12
assert_close "holm max" 0.02 "$(m "$out" .metrics.holm_max_adjusted_p)" 1e-12

# Holm is monotone: a small raw p later in the sorted order can never adjust
# below an earlier one.  Raw 0.001, 0.002, 0.003 -> 0.003, 0.004, 0.004.
holm2=$(printf '%s' "$holm" | jq -c '.tests = [{id:"t1",p:0.001},{id:"t2",p:0.002},{id:"t3",p:0.003}]')
out=$(printf '%s' "$holm2" | "$QUALIFY" correlation)
assert_close "holm2 t2" 0.004 "$(m "$out" '.metrics.holm[] | select(.id=="t2") | .adjusted_p')" 1e-12
assert_close "holm2 t3" 0.004 "$(m "$out" '.metrics.holm[] | select(.id=="t3") | .adjusted_p')" 1e-12
assert_close "holm2 max" 0.004 "$(m "$out" .metrics.holm_max_adjusted_p)" 1e-12

# Holm never exceeds 1.
holm3=$(printf '%s' "$holm" | jq -c '.tests = [{id:"t1",p:0.6},{id:"t2",p:0.7},{id:"t3",p:0.8}]')
out=$(printf '%s' "$holm3" | "$QUALIFY" correlation)
assert_close "holm3 max capped at 1" 1 "$(m "$out" .metrics.holm_max_adjusted_p)" 1e-12

# ---------------------------------------------------------------------------
# Position bias: 240 mirrored pairs presented in both orders is 480 calls; a
# reversal is a pair whose chosen item changes with presentation order.
# ---------------------------------------------------------------------------
pos() {
  jq -nc --argjson rev "$1" '{schema:"polylane.hcm-v2.position-bias.v1", judge_id:"pb",
    calls: [range(0;240) as $j | ({pair_id:"p\($j)", order:"ab", choice:"X"},
      {pair_id:"p\($j)", order:"ba", choice:(if $j < $rev then "Y" else "X" end)})]}'
}
out=$(pos 6 | "$QUALIFY" position-bias)
assert_eq "position kind" "position_bias" "$(m "$out" .kind)"
assert_eq "calls" "480" "$(m "$out" .metrics.calls)"
assert_eq "unique_mirrored_pairs" "240" "$(m "$out" .metrics.unique_mirrored_pairs)"
assert_eq "reversals 6" "6" "$(m "$out" .metrics.reversals)"
out=$(pos 0 | "$QUALIFY" position-bias)
assert_eq "reversals 0" "0" "$(m "$out" .metrics.reversals)"
out=$(pos 240 | "$QUALIFY" position-bias)
assert_eq "reversals 240" "240" "$(m "$out" .metrics.reversals)"

# A pair missing its mirror is not a mirrored pair.
out=$(jq -nc '{schema:"polylane.hcm-v2.position-bias.v1", judge_id:"pb",
  calls: [{pair_id:"p0", order:"ab", choice:"X"},
          {pair_id:"p0", order:"ba", choice:"X"},
          {pair_id:"p1", order:"ab", choice:"X"}]}' | "$QUALIFY" position-bias)
assert_eq "unmirrored calls" "3" "$(m "$out" .metrics.calls)"
assert_eq "unmirrored pairs" "1" "$(m "$out" .metrics.unique_mirrored_pairs)"

# ---------------------------------------------------------------------------
# Equivalence bias: 300 probes; count how often the verbose candidate and the
# judge's own lineage were selected.
# ---------------------------------------------------------------------------
eqb() {
  jq -nc --argjson v "$1" --argjson s "$2" '{schema:"polylane.hcm-v2.equivalence-bias.v1",
    judge_id:"eb",
    probes: [range(0;300) as $i | {probe_id:"e\($i)",
      verbose_selected:($i < $v), self_lineage_selected:($i < $s)}]}'
}
out=$(eqb 150 150 | "$QUALIFY" equivalence-bias)
assert_eq "equivalence kind" "equivalence_bias" "$(m "$out" .kind)"
assert_eq "probes" "300" "$(m "$out" .metrics.probes)"
assert_eq "verbose 150" "150" "$(m "$out" .metrics.verbose_candidate_selections)"
assert_eq "self lineage 150" "150" "$(m "$out" .metrics.self_lineage_selections)"
out=$(eqb 135 165 | "$QUALIFY" equivalence-bias)
assert_eq "verbose 135" "135" "$(m "$out" .metrics.verbose_candidate_selections)"
assert_eq "self lineage 165" "165" "$(m "$out" .metrics.self_lineage_selections)"

# ---------------------------------------------------------------------------
# Malformed input is rejected, never defaulted.
# ---------------------------------------------------------------------------
reject() {
  if printf '%s' "$2" | "$QUALIFY" "$1" >"$TMP/out" 2>"$TMP/err"; then
    fail "expected rejection for $1: $2"
  fi
  grep -q 'INVALID_INPUT' "$TMP/out" || fail "no INVALID_INPUT for $1: $2"
}
reject target-user '{"schema":"polylane.hcm-v2.target-user.v1","judge_id":"x","judgments":[]}'
reject target-user '{"schema":"wrong","judge_id":"x","judgments":[{"item_id":"a","stratum":"s","class":"c","orientation":"ab","resolved":true,"p":0.5,"outcome":1}]}'
reject target-user '{"schema":"polylane.hcm-v2.target-user.v1","judge_id":"x","judgments":[{"item_id":"a","stratum":"s","class":"c","orientation":"ab","resolved":true,"p":1.5,"outcome":1},{"item_id":"b","stratum":"s","class":"c","orientation":"ab","resolved":true,"p":0.5,"outcome":0}]}'
reject target-user '{"schema":"polylane.hcm-v2.target-user.v1","judge_id":"x","judgments":[{"item_id":"a","stratum":"s","class":"c","orientation":"sideways","resolved":true,"p":0.5,"outcome":1},{"item_id":"b","stratum":"s","class":"c","orientation":"ab","resolved":true,"p":0.5,"outcome":0}]}'
# A single resolved judgment cannot carry a sample standard deviation.
reject target-user '{"schema":"polylane.hcm-v2.target-user.v1","judge_id":"x","judgments":[{"item_id":"a","stratum":"s","class":"c","orientation":"ab","resolved":true,"p":0.5,"outcome":1}]}'
# A degenerate base rate makes the reference Brier score zero (skill undefined).
reject target-user '{"schema":"polylane.hcm-v2.target-user.v1","judge_id":"x","judgments":[{"item_id":"a","stratum":"s","class":"c","orientation":"ab","resolved":true,"p":0.9,"outcome":1},{"item_id":"b","stratum":"s","class":"c","orientation":"ab","resolved":true,"p":0.9,"outcome":1}]}'
reject designer '{"schema":"polylane.hcm-v2.designer.v1","judge_id":"x","judgments":[]}'
reject designer '{"schema":"polylane.hcm-v2.designer.v1","judge_id":"x","judgments":[{"pair_id":"p","stratum":"s","decisive":false,"mirror_ab_correct":true,"mirror_ba_correct":true}]}'
reject designer '{"schema":"polylane.hcm-v2.designer.v1","judge_id":"x","judgments":[{"pair_id":"p","stratum":"s","decisive":true,"mirror_ab_correct":true,"mirror_ba_correct":true},{"pair_id":"p","stratum":"s","decisive":true,"mirror_ab_correct":true,"mirror_ba_correct":true}]}'
reject correlation '{"schema":"polylane.hcm-v2.correlation.v1","judge_id":"x","items":[],"tests":[{"id":"t","p":0.001}]}'
reject correlation '{"schema":"polylane.hcm-v2.correlation.v1","judge_id":"x","items":[{"item_id":"i","consensus_label":"A","judge_label":"A","peer_label":"A"}],"tests":[{"id":"t","p":1.5}]}'
reject position-bias '{"schema":"polylane.hcm-v2.position-bias.v1","judge_id":"x","calls":[]}'
reject position-bias '{"schema":"polylane.hcm-v2.position-bias.v1","judge_id":"x","calls":[{"pair_id":"p","order":"ab","choice":"X"},{"pair_id":"p","order":"ab","choice":"X"}]}'
reject equivalence-bias '{"schema":"polylane.hcm-v2.equivalence-bias.v1","judge_id":"x","probes":[]}'
reject equivalence-bias '{"schema":"polylane.hcm-v2.equivalence-bias.v1","judge_id":"x","probes":[{"probe_id":"e","verbose_selected":true,"self_lineage_selected":false},{"probe_id":"e","verbose_selected":true,"self_lineage_selected":false}]}'

# Duplicate JSON keys are a replay surface, not a merge.
reject target-user '{"schema":"polylane.hcm-v2.target-user.v1","schema":"polylane.hcm-v2.target-user.v1","judge_id":"x","judgments":[{"item_id":"a","stratum":"s","class":"c","orientation":"ab","resolved":true,"p":0.5,"outcome":1},{"item_id":"b","stratum":"s","class":"c","orientation":"ab","resolved":true,"p":0.5,"outcome":0}]}'

# Locale must not move a decimal point.
locale_out=$(printf '%s' "$tu_var" | LC_ALL=de_DE.UTF-8 "$QUALIFY" target-user 2>/dev/null || true)
assert_eq "locale stable" "$(printf '%s' "$tu_var" | "$QUALIFY" target-user)" "$locale_out"

printf 'PASS: hcm-v2 analysis\n'
