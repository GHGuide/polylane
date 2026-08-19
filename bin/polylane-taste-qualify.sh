#!/usr/bin/env bash
# HCM-v2 analysis and judge qualification.
#
# Computes the frozen HCM-v2 statistics from judgment records, applies the
# frozen qualification gates, and refuses a ballot from a judge that failed any
# gate.  Every threshold is read from
# docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json at runtime
# (`source_calibration.judge_qualification_thresholds`); no threshold is
# compiled into this file.
#
#   target-user       < records.json   -> metrics
#   designer          < records.json   -> metrics
#   correlation       < records.json   -> metrics (10,000-replicate bootstrap)
#   position-bias     < records.json   -> metrics
#   equivalence-bias  < records.json   -> metrics
#   gate KIND         < metrics.json   -> gate verdict (pass + reason codes)
#   qualify           < gates.json     -> qualification receipt
#   vote QUALIFICATION < ballot.json   -> admitted ballot, or a refusal
#
# This tool never produces a study result.  It scores records that a real study
# would have collected; it cannot create a human judgment, and it emits no
# certification status or claim label of any kind.
set -euo pipefail
export LC_ALL=C

HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
LOCK_DEFAULT="$HERE/../docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json"
LOCK=${POLYLANE_CONTRACT_LOCK:-$LOCK_DEFAULT}
# Every frozen acceptance level lives under this one block of the lock.
THRESHOLDS='.source_calibration.judge_qualification_thresholds'

# Method constants.  These describe the estimator, not a frozen threshold: the
# lock fixes the acceptance levels, the analyst fixes how the interval is built.
Z95=1.96              # two-sided 95% normal quantile
CALIBRATION_BINS=10   # fixed 0.1-wide reliability bins over [0,1]
BIN_EPSILON=1e-9      # keeps 0.7*10 from falling into bin 6
# Inclusive thresholds are compared with this slack so that a metric which is
# exactly on the frozen boundary is not rejected by binary rounding: the mean of
# three ratios of 28/40 is 0.6999999999999998, not 0.7.  It is nine orders of
# magnitude below any difference the study could resolve, and it is NEVER
# applied to the strict inequalities (Brier skill lower bound, Wilson lower
# bound), where the lock demands a value strictly beyond the threshold.
COMPARE_TOLERANCE=1e-9

usage() {
  printf '%s\n' \
    'usage: polylane-taste-qualify.sh target-user       < records.json' \
    '       polylane-taste-qualify.sh designer          < records.json' \
    '       polylane-taste-qualify.sh correlation       < records.json' \
    '       polylane-taste-qualify.sh position-bias     < records.json' \
    '       polylane-taste-qualify.sh equivalence-bias  < records.json' \
    '       polylane-taste-qualify.sh gate KIND         < metrics.json' \
    '       polylane-taste-qualify.sh qualify           < gates.json' \
    '       polylane-taste-qualify.sh vote QUALIFICATION < ballot.json' >&2
}

die_invalid() {
  jq -nc --arg reason "${1:-}" \
    '{schema:"polylane.hcm-v2.error.v1", valid:false, error:"invalid_input",
      reason:$reason, reason_codes:["INVALID_INPUT"]}'
  exit 1
}

require_jq() {
  command -v jq >/dev/null 2>&1 || {
    printf '%s\n' 'polylane-taste-qualify.sh: jq is required' >&2
    exit 127
  }
}

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else return 1; fi
}

# read_input: canonical stdin JSON with no duplicate keys.  Duplicate keys are a
# replay surface (the last one silently wins), never a merge.  It runs inside a
# command substitution and so can only report failure by return code; the
# caller emits the receipt.
read_input() {
  local raw dup
  raw=$(cat) || return 1
  jq -e . >/dev/null 2>&1 <<<"$raw" || return 1
  dup=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' <<<"$raw" 2>/dev/null |
        LC_ALL=C sort | uniq -d) || return 1
  [ -z "$dup" ] || return 1
  printf '%s' "$raw"
}

# lock_json FILTER: read a frozen value from the contract lock.  A missing lock
# or a missing key is a hard failure, never a default.
lock_json() {
  local v
  [ -f "$LOCK" ] || { printf 'polylane-taste-qualify.sh: contract lock not found: %s\n' "$LOCK" >&2; exit 1; }
  v=$(jq -ce "$1" "$LOCK" 2>/dev/null) || {
    printf 'polylane-taste-qualify.sh: contract lock missing %s\n' "$1" >&2
    exit 1
  }
  [ "$v" != null ] || {
    printf 'polylane-taste-qualify.sh: contract lock missing %s\n' "$1" >&2
    exit 1
  }
  printf '%s' "$v"
}

lock_sha256() { sha256_stdin < "$LOCK"; }

emit_metrics() {
  local kind=$1 judge=$2 metrics=$3
  jq -nc --arg kind "$kind" --arg judge "$judge" --argjson metrics "$metrics" \
    '{schema:"polylane.hcm-v2.metrics.v1", kind:$kind, judge_id:$judge, metrics:$metrics}'
}

# ---------------------------------------------------------------------------
# Shared jq helpers.  lower95 is the one-sided normal bound on the mean of the
# per-item skill contributions, scaled by the reference Brier score; the sign of
# the bound is the sign of the numerator because the reference score is > 0.
JQ_LIB='
  def mean: add / length;
  def samplevar: mean as $m | (map(pow(. - $m; 2)) | add) / (length - 1);
  def lower95_mean($z): mean as $m | ($m - ($z * ((samplevar / length) | sqrt)));
  def absv: if . < 0 then - . else . end;
  def wilson_lower($k; $n; $z):
    ($k / $n) as $p
    | (1 + (($z * $z) / $n)) as $den
    | ($p + (($z * $z) / (2 * $n))) as $ctr
    | ($z * (((($p * (1 - $p)) + (($z * $z) / (4 * $n))) / $n) | sqrt)) as $mar
    | (($ctr - $mar) / $den);
'

# ---------------------------------------------------------------------------
# target-user
TARGET_USER_FILTER='
  def valid_judgment:
    type == "object"
    and (.item_id | type == "string" and length > 0)
    and (.resolved | type == "boolean")
    and (if .resolved then
           ((keys - ["class","item_id","orientation","outcome","p","repeat_group","resolved","stratum"]) == [])
           and (.stratum | type == "string" and length > 0)
           and (.class | type == "string" and length > 0)
           and (.orientation | IN("ab","ba"))
           and (.p | type == "number" and . >= 0 and . <= 1)
           and (.outcome | type == "number" and (. == 0 or . == 1))
           and (if has("repeat_group") then (.repeat_group | type == "string" and length > 0) else true end)
         else
           ((keys - ["item_id","resolved"]) == [])
         end);
  if (type == "object"
      and ((keys | sort) == ["judge_id","judgments","schema"])
      and .schema == "polylane.hcm-v2.target-user.v1"
      and (.judge_id | type == "string" and length > 0)
      and (.judgments | type == "array" and length > 0)
      and all(.judgments[]; valid_judgment)
      and ((.judgments | map(.item_id)) | length == (unique | length)))
  then . else error("shape") end
  | (.judgments | length) as $total
  | (.judgments | map(select(.resolved))) as $r
  | ($r | length) as $n
  | if $n >= 2 then . else error("fewer than two resolved judgments") end
  | ($r | map(.outcome) | mean) as $base
  | if ($base > 0 and $base < 1) then . else error("degenerate base rate: reference Brier score is zero") end
  | ($r | map(pow(.p - .outcome; 2)) | mean) as $brier
  | ($r | map(pow($base - .outcome; 2)) | mean) as $brier_ref
  | ($r | map(pow($base - .outcome; 2) - pow(.p - .outcome; 2))) as $d
  | ($d | mean / $brier_ref) as $skill
  | ($d | lower95_mean($z) / $brier_ref) as $skill_lo
  | ([$r | group_by(.stratum)[]
      | if (length >= 2) then . else error("stratum with fewer than two resolved judgments") end
      | {stratum: .[0].stratum, n: length,
         brier_skill: (map(pow($base - .outcome; 2) - pow(.p - .outcome; 2)) | mean / $brier_ref),
         brier_skill_lower_95: (map(pow($base - .outcome; 2) - pow(.p - .outcome; 2)) | lower95_mean($z) / $brier_ref)}]
     | sort_by(.stratum)) as $strata
  | ([$r | group_by(.class)[]
      | {class: .[0].class, n: length, value: ((map(.p) | mean) - (map(.outcome) | mean))}]
     | sort_by(.class)) as $cil
  | ([$r[] | select(has("repeat_group"))] | group_by(.repeat_group)
     | map(select(length >= 2))) as $groups
  | ([$r[] | select(.orientation == "ab")]) as $ab
  | ([$r[] | select(.orientation == "ba")]) as $ba
  | def correct: ((.p >= 0.5) == (.outcome == 1));
    ([$r | group_by((.p * 10 + $eps) | floor | if . > ($bins - 1) then ($bins - 1) elif . < 0 then 0 else . end)[]
      | {bin: (((.[0].p * 10 + $eps) | floor) | if . > ($bins - 1) then ($bins - 1) elif . < 0 then 0 else . end),
         n: length, p_mean: (map(.p) | mean), outcome_mean: (map(.outcome) | mean)}
      | . + {gap: ((.p_mean - .outcome_mean) | if . < 0 then -. else . end)}]
     | sort_by(.bin)) as $bins_out
  | ($bins_out | map((.n / $n) * .gap) | add) as $wce
  | ($bins_out | map(pow(.n / $n; 2) * (.outcome_mean * (1 - .outcome_mean)) / .n) | add | sqrt) as $wce_se
  | {
      judgments: $total,
      resolved: $n,
      coverage: ($n / $total),
      base_rate: $base,
      brier_score: $brier,
      brier_reference: $brier_ref,
      brier_skill: $skill,
      brier_skill_lower_95: $skill_lo,
      strata: $strata,
      strata_brier_skill_lower_95_min: ($strata | map(.brier_skill_lower_95) | min),
      repeat_groups: ($groups | length),
      repeat_stability: (if ($groups | length) == 0 then null
                         else ($groups | map(select((map((.p >= 0.5)) | unique | length) == 1)) | length)
                              / ($groups | length) end),
      orientation_accuracy_ab: (if ($ab | length) == 0 then null else ($ab | map(if correct then 1 else 0 end) | mean) end),
      orientation_accuracy_ba: (if ($ba | length) == 0 then null else ($ba | map(if correct then 1 else 0 end) | mean) end),
      orientation_effect: (if ($ab | length) == 0 or ($ba | length) == 0 then null
                           else ($ab | map(if correct then 1 else 0 end) | mean)
                                - ($ba | map(if correct then 1 else 0 end) | mean) end),
      calibration_in_large: $cil,
      calibration_in_large_abs_max: ($cil | map(.value | if . < 0 then -. else . end) | max),
      calibration_bins: $bins_out,
      weighted_calibration_error: $wce,
      weighted_calibration_upper_95: ($wce + ($z * $wce_se))
    }
'

cmd_target_user() {
  local input metrics judge
  input=$(read_input) || die_invalid "malformed input JSON"
  metrics=$(jq -ce --argjson z "$Z95" --argjson bins "$CALIBRATION_BINS" --argjson eps "$BIN_EPSILON" \
    "$JQ_LIB $TARGET_USER_FILTER" <<<"$input" 2>/dev/null) || die_invalid "target-user records rejected"
  judge=$(jq -r '.judge_id' <<<"$input")
  emit_metrics target_user "$judge" "$metrics"
}

# ---------------------------------------------------------------------------
# designer
DESIGNER_FILTER='
  def valid_judgment:
    type == "object"
    and ((keys - ["decisive","mirror_ab_correct","mirror_ba_correct","pair_id","stratum"]) == [])
    and (.pair_id | type == "string" and length > 0)
    and (.stratum | type == "string" and length > 0)
    and (.decisive | type == "boolean")
    and (.mirror_ab_correct | type == "boolean")
    and (.mirror_ba_correct | type == "boolean");
  if (type == "object"
      and ((keys | sort) == ["judge_id","judgments","schema"])
      and .schema == "polylane.hcm-v2.designer.v1"
      and (.judge_id | type == "string" and length > 0)
      and (.judgments | type == "array" and length > 0)
      and all(.judgments[]; valid_judgment)
      and ((.judgments | map(.pair_id)) | length == (unique | length)))
  then . else error("shape") end
  | (.judgments | map(select(.decisive))) as $d
  | ($d | length) as $n
  | if $n >= 1 then . else error("no decisive pairs") end
  | ($d | map(select(.mirror_ab_correct and .mirror_ba_correct)) | length) as $both
  | ([$d | group_by(.stratum)[]
      | {stratum: .[0].stratum, decisive: length,
         both_mirror_correct: (map(select(.mirror_ab_correct and .mirror_ba_correct)) | length)}
      | . + {agreement: (.both_mirror_correct / .decisive)}]
     | sort_by(.stratum)) as $strata
  | {
      decisive_pairs: $n,
      both_mirror_correct: $both,
      strata: $strata,
      macro_agreement: ($strata | map(.agreement) | mean),
      stratum_agreement_min: ($strata | map(.agreement) | min),
      wilson_lower_95: wilson_lower($both; $n; $z)
    }
'

cmd_designer() {
  local input metrics judge
  input=$(read_input) || die_invalid "malformed input JSON"
  metrics=$(jq -ce --argjson z "$Z95" "$JQ_LIB $DESIGNER_FILTER" <<<"$input" 2>/dev/null) ||
    die_invalid "designer records rejected"
  judge=$(jq -r '.judge_id' <<<"$input")
  emit_metrics designer "$judge" "$metrics"
}

# ---------------------------------------------------------------------------
# correlation.  jq validates, computes the point estimates and the Holm
# step-down adjustment, and emits one integer row per item; awk runs the
# bootstrap (a deterministic Lehmer generator seeded from the canonical input
# digest, so the same records always yield the same interval).
CORRELATION_FILTER='
  def valid_item:
    type == "object"
    and ((keys - ["consensus_label","item_id","judge_label","peer_label"]) == [])
    and all(.item_id, .consensus_label, .judge_label, .peer_label; type == "string" and length > 0);
  def valid_test:
    type == "object"
    and ((keys - ["id","p"]) == [])
    and (.id | type == "string" and length > 0)
    and (.p | type == "number" and . >= 0 and . <= 1);
  if (type == "object"
      and ((keys | sort) == ["items","judge_id","schema","tests"])
      and .schema == "polylane.hcm-v2.correlation.v1"
      and (.judge_id | type == "string" and length > 0)
      and (.items | type == "array" and length >= 2)
      and all(.items[]; valid_item)
      and ((.items | map(.item_id)) | length == (unique | length))
      and (.tests | type == "array" and length > 0)
      and all(.tests[]; valid_test)
      and ((.tests | map(.id)) | length == (unique | length)))
  then . else error("shape") end
  | .items as $items
  | ($items | length) as $n
  | (($items | map(.judge_label)) + ($items | map(.consensus_label)) | unique) as $labels
  | ($items | map(select(.judge_label == .consensus_label)) | length / $n) as $po
  | ([$labels[] as $l
      | (($items | map(select(.judge_label == $l)) | length) / $n)
        * (($items | map(select(.consensus_label == $l)) | length) / $n)] | add) as $pe
  | ([$items[] | if .judge_label == .consensus_label then 0 else 1 end]) as $jf
  | ([$items[] | if .peer_label == .consensus_label then 0 else 1 end]) as $pf
  | ($jf | add / $n) as $jfr
  | ($pf | add / $n) as $pfr
  | ([range(0; $n) | if ($jf[.] == 1 and $pf[.] == 1) then 1 else 0 end] | add) as $n11
  | ([range(0; $n) | if ($jf[.] == 1 and $pf[.] == 0) then 1 else 0 end] | add) as $n10
  | ([range(0; $n) | if ($jf[.] == 0 and $pf[.] == 1) then 1 else 0 end] | add) as $n01
  | ([range(0; $n) | if ($jf[.] == 0 and $pf[.] == 0) then 1 else 0 end] | add) as $n00
  | (($n11 + $n10) * ($n01 + $n00) * ($n11 + $n01) * ($n10 + $n00)) as $phidenom
  | (.tests | sort_by(.p)) as $ts
  | ($ts | length) as $k
  | (reduce range(0; $k) as $i ([];
        . as $acc | $acc + [[($acc[-1] // 0), (($k - $i) * $ts[$i].p)] | max])
     | map(if . > 1 then 1 else . end)) as $adj
  | {
      rows: [range(0; $n) as $i
             | ($labels | index($items[$i].judge_label)) as $ji
             | ($labels | index($items[$i].consensus_label)) as $ci
             | "\($ji) \($ci) \($jf[$i]) \($pf[$i])"],
      label_count: ($labels | length),
      point: {
        items: $n,
        observed_agreement: $po,
        expected_agreement: $pe,
        capa: (if $pe >= 1 then (if $po >= 1 then 1 else 0 end) else (($po - $pe) / (1 - $pe)) end),
        judge_fault_rate: $jfr,
        peer_fault_rate: $pfr,
        double_fault_rate: ($n11 / $n),
        double_fault_independent: ($jfr * $pfr),
        phi: (if $phidenom <= 0 then 0 else ((($n11 * $n00) - ($n10 * $n01)) / ($phidenom | sqrt)) end),
        holm: [range(0; $k) | {id: $ts[.].id, raw_p: $ts[.].p, adjusted_p: $adj[.]}],
        holm_max_adjusted_p: ($adj | max)
      }
    }
'

BOOTSTRAP_AWK='
{ j[NR] = $1 + 0; c[NR] = $2 + 0; jf[NR] = $3 + 0; pf[NR] = $4 + 0 }
END {
  n = NR; x = seed % 2147483647; if (x <= 0) x = 1;
  for (r = 0; r < reps; r++) {
    for (a = 0; a < labels; a++) { jm[a] = 0; cm[a] = 0 }
    agree = 0; n11 = 0; n10 = 0; n01 = 0; n00 = 0;
    for (i = 0; i < n; i++) {
      x = (16807 * x) % 2147483647;
      k = int(x / 2147483647 * n) + 1; if (k > n) k = n;
      jm[j[k]]++; cm[c[k]]++;
      if (j[k] == c[k]) agree++;
      if (jf[k] == 1 && pf[k] == 1) n11++;
      else if (jf[k] == 1) n10++;
      else if (pf[k] == 1) n01++;
      else n00++;
    }
    po = agree / n; pe = 0;
    for (a = 0; a < labels; a++) pe += (jm[a] / n) * (cm[a] / n);
    if (pe >= 1) capa = (po >= 1) ? 1 : 0; else capa = (po - pe) / (1 - pe);
    d = (n11 + n10) * (n01 + n00) * (n11 + n01) * (n10 + n00);
    phi = (d <= 0) ? 0 : ((n11 * n00) - (n10 * n01)) / sqrt(d);
    printf "%.17g\n", capa > capafile;
    printf "%.17g\n", phi > phifile;
  }
}
'

cmd_correlation() {
  local input prepared reps seed digest work capa_lo phi_hi lo_idx hi_idx metrics judge
  input=$(read_input) || die_invalid "malformed input JSON"
  prepared=$(jq -ce "$CORRELATION_FILTER" <<<"$input" 2>/dev/null) ||
    die_invalid "correlation records rejected"
  reps=$(lock_json "$THRESHOLDS.correlation.bootstrap_replicates")
  case "$reps" in ''|*[!0-9]*) die_invalid "bootstrap_replicates is not a positive integer";; esac
  [ "$reps" -ge 100 ] || die_invalid "bootstrap_replicates below 100"

  digest=$(jq -cS . <<<"$input" | sha256_stdin)
  seed=$(( 0x${digest:0:8} % 2147483646 + 1 ))

  work=$(mktemp -d "${TMPDIR:-/tmp}/polylane-hcm-boot.XXXXXX") || die_invalid "no temp dir"
  jq -r '.rows[]' <<<"$prepared" |
    awk -v seed="$seed" -v reps="$reps" -v labels="$(jq -r '.label_count' <<<"$prepared")" \
        -v capafile="$work/capa" -v phifile="$work/phi" "$BOOTSTRAP_AWK"

  # Order statistics: the ceil(0.025 R)-th and ceil(0.975 R)-th replicate.
  lo_idx=$(( (reps * 25 + 999) / 1000 ))
  hi_idx=$(( (reps * 975 + 999) / 1000 ))
  [ "$lo_idx" -ge 1 ] || lo_idx=1
  capa_lo=$(sort -n "$work/capa" | sed -n "${lo_idx}p")
  phi_hi=$(sort -n "$work/phi" | sed -n "${hi_idx}p")
  rm -rf "$work"
  [ -n "$capa_lo" ] && [ -n "$phi_hi" ] || die_invalid "bootstrap produced no replicates"

  metrics=$(jq -ce --argjson lo "$capa_lo" --argjson hi "$phi_hi" --argjson reps "$reps" \
    --arg seed "$seed" --arg phibound "$(lock_json "$THRESHOLDS.correlation.phi_bound" | jq -r .)" '
      .point + {
        bootstrap_replicates: $reps,
        bootstrap_seed: ($seed | tonumber),
        capa_lower_95: $lo,
        phi_upper_95: $hi,
        phi_bound: $phibound
      }' <<<"$prepared")
  judge=$(jq -r '.judge_id' <<<"$input")
  emit_metrics correlation "$judge" "$metrics"
}

# ---------------------------------------------------------------------------
# position-bias
POSITION_FILTER='
  def valid_call:
    type == "object"
    and ((keys - ["choice","order","pair_id"]) == [])
    and (.pair_id | type == "string" and length > 0)
    and (.order | IN("ab","ba"))
    and (.choice | type == "string" and length > 0);
  if (type == "object"
      and ((keys | sort) == ["calls","judge_id","schema"])
      and .schema == "polylane.hcm-v2.position-bias.v1"
      and (.judge_id | type == "string" and length > 0)
      and (.calls | type == "array" and length > 0)
      and all(.calls[]; valid_call)
      and ((.calls | map("\(.pair_id)|\(.order)")) | length == (unique | length)))
  then . else error("shape") end
  | (.calls | group_by(.pair_id)
     | map(select((map(.order) | sort) == ["ab","ba"]))) as $mirrored
  | {
      calls: (.calls | length),
      unique_pairs: (.calls | map(.pair_id) | unique | length),
      unique_mirrored_pairs: ($mirrored | length),
      reversals: ($mirrored | map(select((map(.choice) | unique | length) > 1)) | length)
    }
'

cmd_position_bias() {
  local input metrics judge
  input=$(read_input) || die_invalid "malformed input JSON"
  metrics=$(jq -ce "$POSITION_FILTER" <<<"$input" 2>/dev/null) || die_invalid "position-bias records rejected"
  judge=$(jq -r '.judge_id' <<<"$input")
  emit_metrics position_bias "$judge" "$metrics"
}

# ---------------------------------------------------------------------------
# equivalence-bias
EQUIVALENCE_FILTER='
  def valid_probe:
    type == "object"
    and ((keys - ["probe_id","self_lineage_selected","verbose_selected"]) == [])
    and (.probe_id | type == "string" and length > 0)
    and (.verbose_selected | type == "boolean")
    and (.self_lineage_selected | type == "boolean");
  if (type == "object"
      and ((keys | sort) == ["judge_id","probes","schema"])
      and .schema == "polylane.hcm-v2.equivalence-bias.v1"
      and (.judge_id | type == "string" and length > 0)
      and (.probes | type == "array" and length > 0)
      and all(.probes[]; valid_probe)
      and ((.probes | map(.probe_id)) | length == (unique | length)))
  then . else error("shape") end
  | {
      probes: (.probes | length),
      verbose_candidate_selections: (.probes | map(select(.verbose_selected)) | length),
      self_lineage_selections: (.probes | map(select(.self_lineage_selected)) | length)
    }
'

cmd_equivalence_bias() {
  local input metrics judge
  input=$(read_input) || die_invalid "malformed input JSON"
  metrics=$(jq -ce "$EQUIVALENCE_FILTER" <<<"$input" 2>/dev/null) || die_invalid "equivalence-bias records rejected"
  judge=$(jq -r '.judge_id' <<<"$input")
  emit_metrics equivalence_bias "$judge" "$metrics"
}

# ---------------------------------------------------------------------------
# gate: apply the frozen thresholds.  Nothing here decides what "good" means;
# every acceptance level comes from the lock, and a lock that has lost one of
# them is a hard failure rather than a silently permissive comparison.

# lock_block KIND KEY...: the frozen threshold object for KIND, with every key
# this gate needs proven present.
lock_block() {
  local kind=$1 block key
  shift
  block=$(lock_json "$THRESHOLDS.$kind")
  for key in "$@"; do
    jq -e --arg k "$key" 'has($k) and (.[$k] != null)' >/dev/null 2>&1 <<<"$block" || {
      printf 'polylane-taste-qualify.sh: contract lock missing %s.%s.%s\n' "$THRESHOLDS" "$kind" "$key" >&2
      exit 1
    }
  done
  printf '%s' "$block"
}

GATE_TARGET_USER='
  if (type == "object"
      and (.coverage | type == "number")
      and (.brier_skill_lower_95 | type == "number")
      and (.strata_brier_skill_lower_95_min | type == "number")
      and (.strata | type == "array" and length > 0
           and all(.[]; .brier_skill_lower_95 | type == "number"))
      and has("repeat_stability") and has("orientation_effect")
      and (.calibration_in_large | type == "array" and length > 0
           and all(.[]; .value | type == "number"))
      and (.calibration_in_large_abs_max | type == "number")
      and (.weighted_calibration_error | type == "number")
      and (.weighted_calibration_upper_95 | type == "number"))
  then . else error("metrics") end
  | [ (if .coverage >= ($t.coverage_min - $tol) then empty else "TU_COVERAGE" end),
      (if .brier_skill_lower_95 > $t.brier_skill_lower_95_strict_min then empty else "TU_BRIER_SKILL_LOWER" end),
      (if (.strata_brier_skill_lower_95_min > $t.strata_brier_skill_lower_95_strict_min)
          and all(.strata[]; .brier_skill_lower_95 > $t.strata_brier_skill_lower_95_strict_min)
       then empty else "TU_STRATUM_BRIER_SKILL_LOWER" end),
      (if (.repeat_stability | type == "number") and (.repeat_stability >= ($t.repeat_stability_min - $tol))
       then empty else "TU_REPEAT_STABILITY" end),
      (if (.orientation_effect | type == "number")
          and ((.orientation_effect | absv) <= ($t.orientation_effect_abs_max + $tol))
       then empty else "TU_ORIENTATION_EFFECT" end),
      (if all(.calibration_in_large[]; (.value | absv) <= ($t.calibration_in_large_abs_max_per_class + $tol))
          and ((.calibration_in_large_abs_max | absv) <= ($t.calibration_in_large_abs_max_per_class + $tol))
       then empty else "TU_CALIBRATION_IN_LARGE" end),
      (if .weighted_calibration_error <= ($t.weighted_calibration_error_max + $tol)
       then empty else "TU_WEIGHTED_CALIBRATION_ERROR" end),
      (if .weighted_calibration_upper_95 <= ($t.weighted_calibration_upper_95_max + $tol)
       then empty else "TU_WEIGHTED_CALIBRATION_UPPER" end) ]
'

GATE_DESIGNER='
  if (type == "object"
      and (.decisive_pairs | type == "number")
      and (.both_mirror_correct | type == "number")
      and (.macro_agreement | type == "number")
      and (.stratum_agreement_min | type == "number")
      and (.wilson_lower_95 | type == "number")
      and (.strata | type == "array" and length > 0 and all(.[]; .agreement | type == "number")))
  then . else error("metrics") end
  | [ (if .decisive_pairs == $t.decisive_pairs then empty else "DESIGNER_DECISIVE_PAIRS" end),
      (if .both_mirror_correct >= $t.both_mirror_correct_min then empty else "DESIGNER_BOTH_MIRROR_CORRECT" end),
      (if .macro_agreement >= ($t.macro_agreement_min - $tol) then empty else "DESIGNER_MACRO_AGREEMENT" end),
      (if (.stratum_agreement_min >= ($t.stratum_agreement_min - $tol))
          and all(.strata[]; .agreement >= ($t.stratum_agreement_min - $tol))
       then empty else "DESIGNER_STRATUM_AGREEMENT" end),
      (if .wilson_lower_95 > $t.wilson_lower_95_strict_min then empty else "DESIGNER_WILSON_LOWER" end) ]
'

GATE_CORRELATION='
  if (type == "object"
      and (.bootstrap_replicates | type == "number")
      and (.capa_lower_95 | type == "number")
      and (.holm_max_adjusted_p | type == "number")
      and (.holm | type == "array" and length > 0 and all(.[]; .adjusted_p | type == "number"))
      and (.double_fault_rate | type == "number")
      and (.double_fault_independent | type == "number")
      and (.phi_bound | type == "string"))
  then . else error("metrics") end
  | [ (if .bootstrap_replicates == $t.bootstrap_replicates then empty else "CORRELATION_BOOTSTRAP_REPLICATES" end),
      (if .capa_lower_95 >= ($t.capa_lower_95_threshold - $tol) then empty else "CORRELATION_CAPA_LOWER" end),
      (if (.holm_max_adjusted_p <= ($t.holm_p_max + $tol)) and all(.holm[]; .adjusted_p <= ($t.holm_p_max + $tol))
       then empty else "CORRELATION_HOLM_P" end),
      (if .double_fault_rate <= (($t.double_fault_independence_multiplier * .double_fault_independent) + $tol)
       then empty else "CORRELATION_DOUBLE_FAULT_INDEPENDENCE" end),
      (if .phi_bound == $t.phi_bound then empty else "CORRELATION_PHI_BOUND" end) ]
'

GATE_POSITION_BIAS='
  if (type == "object"
      and (.calls | type == "number")
      and (.unique_mirrored_pairs | type == "number")
      and (.reversals | type == "number"))
  then . else error("metrics") end
  | [ (if .calls == $t.calls then empty else "POSITION_BIAS_CALLS" end),
      (if .unique_mirrored_pairs == $t.unique_mirrored_pairs then empty else "POSITION_BIAS_PAIRS" end),
      (if .reversals <= $t.reversals_max then empty else "POSITION_BIAS_REVERSALS" end) ]
'

GATE_EQUIVALENCE_BIAS='
  if (type == "object"
      and (.probes | type == "number")
      and (.verbose_candidate_selections | type == "number")
      and (.self_lineage_selections | type == "number"))
  then . else error("metrics") end
  | ($t.verbose_candidate_selection_acceptance_inclusive) as $v
  | ($t.self_lineage_selection_acceptance_inclusive) as $s
  | if (($v | type == "array" and length == 2) and ($s | type == "array" and length == 2))
    then . else error("acceptance interval") end
  | [ (if .probes == $t.probes then empty else "EQUIVALENCE_BIAS_PROBES" end),
      (if (.verbose_candidate_selections >= $v[0]) and (.verbose_candidate_selections <= $v[1])
       then empty else "EQUIVALENCE_BIAS_VERBOSE_CANDIDATE" end),
      (if (.self_lineage_selections >= $s[0]) and (.self_lineage_selections <= $s[1])
       then empty else "EQUIVALENCE_BIAS_SELF_LINEAGE" end) ]
'

cmd_gate() {
  local kind=$1 input thresholds filter codes receipt judge msha
  case "$kind" in
    target_user)
      filter=$GATE_TARGET_USER
      thresholds=$(lock_block target_user coverage_min brier_skill_lower_95_strict_min \
        strata_brier_skill_lower_95_strict_min repeat_stability_min orientation_effect_abs_max \
        calibration_in_large_abs_max_per_class weighted_calibration_error_max \
        weighted_calibration_upper_95_max);;
    designer)
      filter=$GATE_DESIGNER
      thresholds=$(lock_block designer decisive_pairs both_mirror_correct_min \
        macro_agreement_min stratum_agreement_min wilson_lower_95_strict_min);;
    correlation)
      filter=$GATE_CORRELATION
      thresholds=$(lock_block correlation bootstrap_replicates capa_lower_95_threshold \
        holm_p_max double_fault_independence_multiplier phi_bound);;
    position_bias)
      filter=$GATE_POSITION_BIAS
      thresholds=$(lock_block position_bias calls unique_mirrored_pairs reversals_max);;
    equivalence_bias)
      filter=$GATE_EQUIVALENCE_BIAS
      thresholds=$(lock_block equivalence_bias probes \
        verbose_candidate_selection_acceptance_inclusive self_lineage_selection_acceptance_inclusive);;
    *) usage; exit 64;;
  esac

  input=$(read_input) || die_invalid "malformed input JSON"
  jq -e --arg k "$kind" '
      type == "object"
      and ((keys | sort) == ["judge_id","kind","metrics","schema"])
      and .schema == "polylane.hcm-v2.metrics.v1"
      and .kind == $k
      and (.judge_id | type == "string" and length > 0)
      and (.metrics | type == "object")' >/dev/null 2>&1 <<<"$input" ||
    die_invalid "not a $kind metrics receipt"

  codes=$(jq -ce --argjson t "$thresholds" --argjson tol "$COMPARE_TOLERANCE" \
    "$JQ_LIB .metrics | $filter" <<<"$input" 2>/dev/null) ||
    die_invalid "$kind metrics are incomplete"

  judge=$(jq -r '.judge_id' <<<"$input")
  msha=$(jq -cS '.metrics' <<<"$input" | sha256_stdin)
  receipt=$(jq -nc --arg kind "$kind" --arg judge "$judge" --argjson codes "$codes" \
    --argjson t "$thresholds" --arg lock "$(lock_sha256)" --arg msha "$msha" '
      {schema:"polylane.hcm-v2.gate.v1", kind:$kind, judge_id:$judge,
       pass: (($codes | length) == 0), reason_codes: ($codes | unique | sort),
       thresholds: $t, metrics_sha256: $msha, lock_sha256: $lock}')
  printf '%s\n' "$receipt"
  jq -e '.pass' >/dev/null <<<"$receipt" || return 1
}

# ---------------------------------------------------------------------------
# qualify: the required gate kinds are exactly the kinds the lock freezes
# thresholds for, so a new frozen gate cannot be skipped by omission.
cmd_qualify() {
  local input required receipt
  input=$(read_input) || die_invalid "malformed input JSON"
  required=$(lock_json "$THRESHOLDS" | jq -c 'keys')

  jq -e --argjson req "$required" '
      type == "object"
      and ((keys | sort) == ["gates","judge_id","schema"])
      and .schema == "polylane.hcm-v2.qualification-input.v1"
      and (.judge_id | type == "string" and length > 0)
      and (.gates | type == "array" and length > 0)
      and all(.gates[];
          type == "object"
          and .schema == "polylane.hcm-v2.gate.v1"
          and (.kind | IN($req[]))
          and (.pass | type == "boolean")
          and (.judge_id | type == "string" and length > 0)
          and (.reason_codes | type == "array"))
      and ((.gates | map(.kind)) | length == (unique | length))' >/dev/null 2>&1 <<<"$input" ||
    die_invalid "not a well-formed qualification input"

  receipt=$(jq -c --argjson req "$required" --arg lock "$(lock_sha256)" '
      . as $in
      | ([$req[] as $k
          | if ([$in.gates[] | select(.kind == $k)] | length) == 0
            then "QUALIFICATION_GATE_MISSING:\($k)"
            elif ([$in.gates[] | select(.kind == $k and .pass)] | length) == 0
            then "QUALIFICATION_GATE_FAILED:\($k)"
            else empty end]
         + [if all($in.gates[]; .judge_id == $in.judge_id) then empty
            else "QUALIFICATION_JUDGE_MISMATCH" end]
         + [if all($in.gates[]; .lock_sha256 == $lock) then empty
            else "QUALIFICATION_LOCK_DRIFT" end]) as $codes
      | {schema:"polylane.hcm-v2.qualification.v1", judge_id: $in.judge_id,
         qualified: (($codes | length) == 0),
         reason_codes: ($codes | unique | sort),
         gate_kinds: ($in.gates | map(.kind) | sort),
         lock_sha256: $lock}' <<<"$input")
  printf '%s\n' "$receipt"
  jq -e '.qualified' >/dev/null <<<"$receipt" || return 1
}

# ---------------------------------------------------------------------------
# vote: the only path from a qualification receipt to a countable ballot.  A
# judge that failed any gate, a receipt whose own verdict is self-contradictory,
# and a ballot from another judge are all refused without the vote.
refuse_vote() {
  jq -nc --argjson codes "$1" --arg judge "${2:-}" --arg pair "${3:-}" '
    {schema:"polylane.hcm-v2.vote-refusal.v1", ballot_admitted:false,
     judge_id: (if $judge == "" then null else $judge end),
     pair_id: (if $pair == "" then null else $pair end),
     reason_codes: ($codes | unique | sort)}'
  exit 1
}

cmd_vote() {
  local qfile=$1 qual required ballot judge pair qsha
  [ -f "$qfile" ] && [ ! -L "$qfile" ] || refuse_vote '["VOTE_REFUSED_QUALIFICATION_INVALID"]'
  qual=$(cat "$qfile") || refuse_vote '["VOTE_REFUSED_QUALIFICATION_INVALID"]'
  jq -e . >/dev/null 2>&1 <<<"$qual" || refuse_vote '["VOTE_REFUSED_QUALIFICATION_INVALID"]'

  ballot=$(read_input) || refuse_vote '["BALLOT_INVALID"]'
  jq -e '
      type == "object"
      and ((keys | sort) == ["choice","judge_id","pair_id","schema"])
      and .schema == "polylane.hcm-v2.ballot.v1"
      and all(.judge_id, .pair_id, .choice; type == "string" and length > 0)' \
    >/dev/null 2>&1 <<<"$ballot" || refuse_vote '["BALLOT_INVALID"]'
  judge=$(jq -r '.judge_id' <<<"$ballot")
  pair=$(jq -r '.pair_id' <<<"$ballot")

  # The receipt must be internally consistent before its verdict counts: a
  # "qualified" receipt carrying reason codes, a short gate list, or a stale
  # lock digest is a forgery, not a pass.
  required=$(lock_json "$THRESHOLDS" | jq -c 'keys')
  jq -e --argjson req "$required" --arg lock "$(lock_sha256)" '
      type == "object"
      and ((keys | sort) == ["gate_kinds","judge_id","lock_sha256","qualified","reason_codes","schema"])
      and .schema == "polylane.hcm-v2.qualification.v1"
      and (.judge_id | type == "string" and length > 0)
      and (.qualified | type == "boolean")
      and (.reason_codes | type == "array")
      and (.gate_kinds | type == "array")
      and (if .qualified then
             ((.reason_codes | length) == 0)
             and ((.gate_kinds | sort) == $req)
             and (.lock_sha256 == $lock)
           else true end)' >/dev/null 2>&1 <<<"$qual" ||
    refuse_vote '["VOTE_REFUSED_QUALIFICATION_INVALID"]' "$judge" "$pair"

  jq -e --arg j "$judge" '.judge_id == $j' >/dev/null 2>&1 <<<"$qual" ||
    refuse_vote '["VOTE_REFUSED_JUDGE_MISMATCH"]' "$judge" "$pair"
  jq -e '.qualified' >/dev/null 2>&1 <<<"$qual" ||
    refuse_vote '["VOTE_REFUSED_NOT_QUALIFIED"]' "$judge" "$pair"

  qsha=$(sha256_stdin < "$qfile")
  jq -nc --arg judge "$judge" --arg pair "$pair" --arg choice "$(jq -r '.choice' <<<"$ballot")" \
    --arg qsha "$qsha" '
      {schema:"polylane.hcm-v2.admitted-ballot.v1", ballot_admitted:true,
       judge_id:$judge, pair_id:$pair, choice:$choice, qualification_sha256:$qsha}'
}

# ---------------------------------------------------------------------------
require_jq
case "${1:-}" in
  target-user)      [ "$#" -eq 1 ] || { usage; exit 64; }; cmd_target_user;;
  designer)         [ "$#" -eq 1 ] || { usage; exit 64; }; cmd_designer;;
  correlation)      [ "$#" -eq 1 ] || { usage; exit 64; }; cmd_correlation;;
  position-bias)    [ "$#" -eq 1 ] || { usage; exit 64; }; cmd_position_bias;;
  equivalence-bias) [ "$#" -eq 1 ] || { usage; exit 64; }; cmd_equivalence_bias;;
  gate)             [ "$#" -eq 2 ] || { usage; exit 64; }; cmd_gate "$2";;
  qualify)          [ "$#" -eq 1 ] || { usage; exit 64; }; cmd_qualify;;
  vote)             [ "$#" -eq 2 ] || { usage; exit 64; }; cmd_vote "$2";;
  *) usage; exit 64;;
esac
