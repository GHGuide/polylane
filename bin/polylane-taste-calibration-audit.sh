#!/usr/bin/env bash
# polylane-taste-calibration-audit.sh
#
# Independent panel calibration auditor (taste-calibration-audit/v1).
#
# Input is a panel manifest binding, per judge configuration, three artifacts
# by path + sha256: the taste-calibration/v2 calibration input, the emitted
# judge-eligibility receipt, and the campaign session ledger.  The auditor
# trusts none of them.  For every configuration it independently recomputes,
# from the raw evidence on disk:
#
#   * 24-pair correctness (gold from the hash-bound human holdout labels,
#     votes re-parsed from hash-verified raw responses with the pinned parser);
#   * the Wilson 95% lower bound and the two-sided exact binomial side probe;
#   * mirror contradictions, raw-response closure, and session uniqueness;
#   * parser / invocation / configuration hash identity and holdout binding;
#   * the fixture/production classification (hash-matched regular files only).
#
# It then cross-checks the configuration's emitted receipt against the
# recomputed values: any divergence is RECEIPT_MISMATCH; a receipt bound to a
# different input or frozen configuration is STALE_CONFIG; a receipt that
# claims human certification is HUMAN_CLAIM and poisons the whole panel.
#
# Eligibility requires every frozen gate.  The HUMAN_CALIBRATED_MACHINE claim
# is emitted only at panel level -- never per configuration -- and only when at
# least PANEL_MIN eligible *production* configurations survive the audit with
# no session reuse and no human-claim escalation anywhere.  The audit output
# is always human_certified:false.
#
# Pure verifier: bash 3.2 + jq + awk.  It never invokes a model, never repairs
# evidence, and never re-runs a judge.
set -euo pipefail

# Pinned response parser -- byte-identical to the frozen contract used by the
# upstream validator; its digest is recomputed here, never imported.
PARSER_SPEC='polylane.taste.response-parser/v1
Read the raw judge response as UTF-8 text.
Consider only lines that exactly match the regular expression: ^FINAL: (FIRST|SECOND|ABSTAIN)$
The parsed verdict is the token from the LAST such matching line.
FIRST maps to position 1, SECOND maps to position 2, ABSTAIN maps to position 0 (abstention).
If no line matches, the response is unparseable and the unit is rejected.'

# Frozen gates.  Constants, never inputs.
UNITS_MIN=24; CORRECT_MIN=17; WILSON_MIN=0.50
SIDE_N_MIN=12; SIDE_P_MIN=0.05; MIRROR_N_MIN=8; CONTRA_MAX=1
PANEL_MIN=5

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else return 1; fi
}
sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else return 1; fi
}
parser_sha() { printf '%s' "$PARSER_SPEC" | sha256_stdin; }

usage() {
  printf 'usage: %s <audit-input.json> <audit-receipt.json> [artifact-root]\n' "${0##*/}" >&2
  printf '       %s parser-sha\n' "${0##*/}" >&2
}

parse_final() {
  awk '
    /^FINAL: FIRST$/   { t = "FIRST" }
    /^FINAL: SECOND$/  { t = "SECOND" }
    /^FINAL: ABSTAIN$/ { t = "ABSTAIN" }
    END { print (t == "" ? "NONE" : t) }
  ' "$1"
}

# Reject symlinks and traversal; only a plain regular file under $root is safe.
safe_regular_file() {
  local root=$1 rel=$2 part prefix old_ifs
  case "$rel" in ''|/*|*'//'*|*'\'*) return 1;; esac
  prefix="$root"; old_ifs=$IFS; IFS='/'
  for part in $rel; do
    if [ -z "$part" ] || [ "$part" = . ] || [ "$part" = .. ]; then IFS=$old_ifs; return 1; fi
    prefix="$prefix/$part"
    if [ -L "$prefix" ]; then IFS=$old_ifs; return 1; fi
  done
  IFS=$old_ifs
  [ -f "$root/$rel" ]
}

regular_json_without_duplicate_keys() {
  local file=$1 duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

wilson_lcb() { # correct total -> %.6f
  awk -v correct="$1" -v total="$2" 'BEGIN {
    if (total + 0 <= 0) { printf "0"; exit }
    z = 1.959963984540054
    p = correct / total
    z2 = z * z
    lower = (p + z2 / (2 * total) - z * sqrt((p * (1 - p) + z2 / (4 * total)) / total)) / (1 + z2 / total)
    printf "%.6f", lower
  }'
}

side_probe_p() { # left total -> %.6f two-sided exact binomial at 0.5
  awk -v left="$1" -v total="$2" 'BEGIN {
    if (total + 0 <= 0) { printf "0.000000"; exit }
    lower_tail = left
    if (total - left < lower_tail) lower_tail = total - left
    probability = 0
    for (i = 0; i <= lower_tail; i++) {
      combinations = 1
      for (j = 1; j <= i; j++) combinations = combinations * (total - j + 1) / j
      probability += combinations / (2 ^ total)
    }
    probability *= 2
    if (probability > 1) probability = 1
    printf "%.6f", probability
  }'
}

if [ "${1:-}" = parser-sha ] && [ "$#" -eq 1 ]; then parser_sha; exit 0; fi
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then usage; exit 64; fi
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 64; }

INPUT_PATH=$1
OUTPUT_PATH=$2
ARTIFACT_ROOT=${3:-$(CDPATH='' cd -- "$(dirname -- "$INPUT_PATH")" 2>/dev/null && pwd)}
AUDITOR_FP=$(sha256_file "$0")
PINNED_PARSER_SHA=$(parser_sha)
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/polylane-calibration-audit.XXXXXX") || exit 1
RECEIPT_TMP=
umask 077
cleanup() {
  [ -z "$SCRATCH" ] || rm -rf "$SCRATCH"
  if [ -n "$RECEIPT_TMP" ] && [ -f "$RECEIPT_TMP" ]; then rm -f "$RECEIPT_TMP"; fi
}
trap cleanup EXIT HUP INT TERM

AUDIT_RUN=''
INPUT_HASH=''

# emit_receipt PANEL_ELIGIBLE PANEL_CODES(json) CONFIGS(json array)
emit_receipt() {
  local eligible=$1 codes=$2 configs=$3 claim
  claim=null
  if [ "$eligible" = true ]; then claim='"HUMAN_CALIBRATED_MACHINE"'; fi
  RECEIPT_TMP=$(mktemp "${OUTPUT_PATH}.tmp.XXXXXX")
  jq -n \
    --arg run "$AUDIT_RUN" \
    --arg parser "$PINNED_PARSER_SHA" \
    --arg fp "$AUDITOR_FP" \
    --arg input_sha "$INPUT_HASH" \
    --argjson eligible "$eligible" \
    --argjson claim "$claim" \
    --argjson codes "$codes" \
    --argjson configs "$configs" \
    --argjson panel_min "$PANEL_MIN" '
    ($configs | map(select(.eligible)) | length) as $elig
    | ($configs | map(select(.eligible and .classification == "production")) | length) as $prod
    | {
        schema_version: "taste-calibration-audit/v1",
        receipt_version: "polylane.taste.calibration-audit.v1",
        run: $run,
        status: (if $eligible then "eligible" else "ineligible" end),
        panel: {
          eligible: $eligible,
          claim: $claim,
          min_eligible_production_configurations: $panel_min,
          eligible_configurations: $elig,
          eligible_production_configurations: $prod,
          reason_codes: $codes
        },
        human_certified: false,
        machine_not_human: true,
        claim_semantics: "Panel eligibility means independently re-audited machine judges reproduced human held-out labels; it is never a human ballot and can never be represented as human certification.",
        configurations: $configs,
        response_parser_sha256: $parser,
        auditor: {id: "polylane-taste-calibration-audit", fingerprint: $fp},
        input_sha256: $input_sha
      }' > "$RECEIPT_TMP"
  mv -f "$RECEIPT_TMP" "$OUTPUT_PATH"
  RECEIPT_TMP=
}

fail_closed() { # panel-codes-json
  emit_receipt false "$1" '[]'
  exit 1
}

# --------------------------------------------------------------------------
# stage 0: the audit input itself
# --------------------------------------------------------------------------
if ! regular_json_without_duplicate_keys "$INPUT_PATH"; then
  fail_closed '["AUDIT_INPUT_INVALID"]'
fi
INPUT_HASH=$(sha256_file "$INPUT_PATH")
AUDIT_RUN=$(jq -r '.run // ""' "$INPUT_PATH")

if ! jq -e '
    type == "object"
    and (keys | sort) == ["configurations","run","schema_version"]
    and .schema_version == "taste-calibration-audit/v1"
    and (.run | type == "string" and length > 0)
    and (.configurations | type == "array")
    and (.configurations | all(.[];
          type == "object"
          and (keys | sort) == ["calibration_input","config_id","eligibility_receipt","sessions"]
          and (.config_id | type == "string" and length > 0)
          and ([.calibration_input, .eligibility_receipt, .sessions] | all(.[];
                type == "object" and (keys | sort) == ["path","sha256"]
                and (.path | type == "string" and length > 0)
                and (.sha256 | type == "string" and test("^[0-9a-f]{64}$"))))))
    and (.configurations | map(.config_id) | unique | length) == (.configurations | length)
  ' "$INPUT_PATH" >/dev/null 2>&1; then
  fail_closed '["AUDIT_INPUT_INVALID"]'
fi

CFG_COUNT=$(jq '.configurations | length' "$INPUT_PATH")

# --------------------------------------------------------------------------
# per-configuration audit
# --------------------------------------------------------------------------
: >"$SCRATCH/session-ids.tsv"   # cfg-index<TAB>session-id, for cross-config reuse

# write_cfg IDX CODES(json) ELIGIBLE CLASSIFICATION UNITS CORRECT WILSON
#           SIDE_N SIDE_P MIRROR_N CONTRA SESSIONS CAL_SHA RCP_SHA SES_SHA LAB_SHA JUDGE
write_cfg() {
  local idx=$1
  jq -n \
    --arg config_id "$(jq -r ".configurations[$idx].config_id" "$INPUT_PATH")" \
    --argjson codes "$2" --argjson eligible "$3" --arg classification "$4" \
    --argjson units "$5" --argjson correct "$6" --argjson wilson "$7" \
    --argjson side_n "$8" --argjson side_p "$9" --argjson mirror_n "${10}" \
    --argjson contra "${11}" --argjson sessions "${12}" \
    --arg cal_sha "${13}" --arg rcp_sha "${14}" --arg ses_sha "${15}" \
    --arg lab_sha "${16}" --arg judge "${17}" '
    {
      config_id: $config_id,
      judge_id: $judge,
      eligible: $eligible,
      production: ($eligible and $classification == "production"),
      classification: $classification,
      reason_codes: $codes,
      units: $units,
      correct: $correct,
      accuracy: (if $units > 0 then (($correct / $units) * 1000000 | round) / 1000000 else 0 end),
      wilson_lcb_95: $wilson,
      side_probe_n: $side_n,
      side_probe_exact_binomial_p: $side_p,
      mirror_probe_n: $mirror_n,
      mirror_contradictions: $contra,
      session_count: $sessions,
      calibration_input_sha256: $cal_sha,
      eligibility_receipt_sha256: $rcp_sha,
      sessions_sha256: $ses_sha,
      holdout_labels_sha256: $lab_sha
    }' > "$SCRATCH/cfg.$idx.json"
}

audit_config() {
  local idx=$1
  local cal_rel cal_decl rcp_rel rcp_decl ses_rel ses_decl
  cal_rel=$(jq -r ".configurations[$idx].calibration_input.path" "$INPUT_PATH")
  cal_decl=$(jq -r ".configurations[$idx].calibration_input.sha256" "$INPUT_PATH")
  rcp_rel=$(jq -r ".configurations[$idx].eligibility_receipt.path" "$INPUT_PATH")
  rcp_decl=$(jq -r ".configurations[$idx].eligibility_receipt.sha256" "$INPUT_PATH")
  ses_rel=$(jq -r ".configurations[$idx].sessions.path" "$INPUT_PATH")
  ses_decl=$(jq -r ".configurations[$idx].sessions.sha256" "$INPUT_PATH")

  # ---- binding: all three artifacts must be safe, clean, hash-matched ----
  local rel
  for rel in "$cal_rel" "$rcp_rel" "$ses_rel"; do
    if ! safe_regular_file "$ARTIFACT_ROOT" "$rel" \
       || ! regular_json_without_duplicate_keys "$ARTIFACT_ROOT/$rel"; then
      write_cfg "$idx" '["CONFIG_BINDING"]' false fixture_only 0 0 0 0 0 0 0 0 '' '' '' '' ''
      return 1
    fi
  done
  local cal_sha rcp_sha ses_sha
  cal_sha=$(sha256_file "$ARTIFACT_ROOT/$cal_rel")
  rcp_sha=$(sha256_file "$ARTIFACT_ROOT/$rcp_rel")
  ses_sha=$(sha256_file "$ARTIFACT_ROOT/$ses_rel")
  if [ "$cal_sha" != "$cal_decl" ] || [ "$rcp_sha" != "$rcp_decl" ] || [ "$ses_sha" != "$ses_decl" ]; then
    write_cfg "$idx" '["CONFIG_BINDING"]' false fixture_only 0 0 0 0 0 0 0 0 \
      "$cal_sha" "$rcp_sha" "$ses_sha" '' ''
    return 1
  fi

  local CAL="$ARTIFACT_ROOT/$cal_rel" RCP="$ARTIFACT_ROOT/$rcp_rel" SES="$ARTIFACT_ROOT/$ses_rel"
  # Unit artifacts inside the calibration input are relative to its own
  # directory -- identical semantics to the upstream validator.
  local CFG_ROOT; CFG_ROOT=$(CDPATH='' cd -- "$(dirname -- "$CAL")" && pwd)
  local JUDGE_ID; JUDGE_ID=$(jq -r '.judge.id // ""' "$CAL")

  # ---- holdout labels binding ----
  local lab_rel lab_decl lab_sha='' labels_ok=true
  lab_rel=$(jq -r '.calibration.holdout_labels.path // ""' "$CAL")
  lab_decl=$(jq -r '.calibration.holdout_labels.sha256 // ""' "$CAL")
  if [ -z "$lab_rel" ] || ! safe_regular_file "$CFG_ROOT" "$lab_rel" \
     || ! regular_json_without_duplicate_keys "$CFG_ROOT/$lab_rel"; then
    labels_ok=false
  else
    lab_sha=$(sha256_file "$CFG_ROOT/$lab_rel")
    [ "$lab_sha" = "$lab_decl" ] || labels_ok=false
  fi

  # ---- resolve every image and raw response; recompute digests + verdicts ----
  : >"$SCRATCH/resolved.tsv"
  # One extraction pass: idx, per-side path/inline-flag/declared-sha, image path/sha.
  jq -r '
    (.units | if type == "array" then . else [] end)
    | to_entries[]
    | [ .key,
        (.value.primary.raw_response.path // ""),
        (if (.value.primary.raw_response | type) == "object" and (.value.primary.raw_response | has("inline")) then "yes" else "no" end),
        (.value.primary.raw_response.sha256 // ""),
        (.value.mirror.raw_response.path // ""),
        (if (.value.mirror.raw_response | type) == "object" and (.value.mirror.raw_response | has("inline")) then "yes" else "no" end),
        (.value.mirror.raw_response.sha256 // ""),
        (.value.image.path // ""),
        (.value.image.sha256 // "") ]
    | map(tostring) | join("\u001f")
  ' "$CAL" >"$SCRATCH/units.tsv"

  # \x1f keeps empty fields intact: unlike tab, read does not collapse it.
  local i ppath pinline pdecl mpath minline mdecl ipath idecl
  while IFS=$'\x1f' read -r i ppath pinline pdecl mpath minline mdecl ipath idecl; do
    local side spath sinline sdecl src actual final cfile
    for side in primary mirror; do
      if [ "$side" = primary ]; then spath=$ppath; sinline=$pinline; sdecl=$pdecl
      else spath=$mpath; sinline=$minline; sdecl=$mdecl; fi
      cfile="$SCRATCH/resp.$i.$side"
      if [ -n "$spath" ]; then
        if safe_regular_file "$CFG_ROOT" "$spath"; then
          src='file'; actual=$(sha256_file "$CFG_ROOT/$spath"); final=$(parse_final "$CFG_ROOT/$spath")
        else
          src=badpath; actual=''; final=NONE
        fi
      elif [ "$sinline" = yes ]; then
        jq -j ".units[$i].$side.raw_response.inline" "$CAL" >"$cfile"
        src=inline; actual=$(sha256_file "$cfile"); final=$(parse_final "$cfile")
      else
        src=none; actual=''; final=NONE
      fi
      printf '%s\t%s\t%s\t%s\t%s\n' "$i:$side" "$src" "$sdecl" "$actual" "$final" >>"$SCRATCH/resolved.tsv"
    done
    if [ -n "$ipath" ]; then
      if safe_regular_file "$CFG_ROOT" "$ipath"; then
        src='file'; actual=$(sha256_file "$CFG_ROOT/$ipath")
      else
        src=badpath; actual=''
      fi
    else
      src=sha_only; actual=''
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$i:image" "$src" "$idecl" "$actual" '' >>"$SCRATCH/resolved.tsv"
  done <"$SCRATCH/units.tsv"

  jq -R -s '
    split("\n") | map(select(length > 0) | split("\t"))
    | map({key: .[0], value: {src: .[1], decl: .[2], actual: .[3], final: .[4]}})
    | from_entries
  ' "$SCRATCH/resolved.tsv" >"$SCRATCH/resolved.json"

  # ---- labels payload (null when the binding already failed) ----
  if [ "$labels_ok" = true ]; then
    cp "$CFG_ROOT/$lab_rel" "$SCRATCH/labels.json"
  else
    printf 'null' >"$SCRATCH/labels.json"
  fi

  # ---- independent structural + statistical recompute ----
  local STRUCT
  STRUCT=$(jq -n \
    --slurpfile input "$CAL" \
    --slurpfile labels "$SCRATCH/labels.json" \
    --slurpfile resolved "$SCRATCH/resolved.json" \
    --slurpfile sessions "$SES" \
    --arg pinned "$PINNED_PARSER_SHA" '
    def hex64: type == "string" and test("^[0-9a-f]{64}$");
    def nonempty: type == "string" and length > 0;
    def pos($tok): if $tok == "FIRST" then 1 elif $tok == "SECOND" then 2 elif $tok == "ABSTAIN" then 0 else -1 end;
    ($input[0]) as $in
    | ($labels[0]) as $lab
    | ($resolved[0]) as $res
    | ($sessions[0]) as $ses
    | (if ($in.freeze | type) == "object" then $in.freeze else {} end) as $fz
    | (if ($in.units | type) == "array" then $in.units else [] end) as $units

    # freeze identity + parser pin + judge/freeze binding
    | ([ if ($fz.response_parser_sha256 // "") != $pinned then "PARSER_CHANGED" else empty end,
         if ($fz.provider | nonempty) and ($fz.model | nonempty) and ($fz.model_version | nonempty)
            and ([$fz.system_prompt_sha256, $fz.sampling_sha256, $fz.source_snapshot_sha256, $fz.invocation_adapter_sha256] | all(hex64))
            and $fz.image_orientation_frozen == true
         then empty else "SCHEMA_REJECTED" end,
         if ($in.judge | type) == "object"
            and $in.judge.provider == $fz.provider and $in.judge.model == $fz.model
            and $in.judge.model_version == $fz.model_version
            and $in.judge.system_prompt_sha256 == $fz.system_prompt_sha256
            and $in.judge.sampling_sha256 == $fz.sampling_sha256
         then empty else "INVOCATION_DRIFT" end,
         if ($in.judge | type) == "object" and (($in.judge | has("eligible")) or ($in.judge | has("eligibility")) or ($in.judge | has("result")))
         then "SCHEMA_REJECTED" else empty end
       ]) as $fz_codes

    # calibration head
    | ([ if ($in.calibration | type) == "object" and $in.calibration.partition == "held_out"
            and $in.calibration.label_provenance == "human-labeled"
         then empty else "SCHEMA_REJECTED" end,
         if ($in.calibration | type) == "object"
            and $in.calibration.tuning_corpus_receipt_sha256 == $in.calibration.holdout_corpus_receipt_sha256
         then "TUNING_HOLDOUT_OVERLAP" else empty end
       ]) as $cal_codes

    # holdout labels
    | ([ if $lab == null then "HOLDOUT_BINDING" else empty end,
         if $lab != null and ($lab.schema_version != "taste-holdout-labels/v1" or $lab.partition != "held_out"
            or (($lab.labels | type) != "array") or (($lab.labels | length) == 0)
            or (($lab.tuning_image_shas | type) != "array"))
         then "LABELS_INVALID" else empty end,
         if $lab != null and ($lab.source_snapshot_sha256 // "") != ($fz.source_snapshot_sha256 // "unset")
         then "STALE_SOURCE" else empty end
       ]) as $lab_codes
    | (if $lab != null and (($lab.labels | type) == "array")
       then (reduce $lab.labels[] as $l ({}; . + {($l.unit_id // "" | tostring): $l})) else {} end) as $lmap
    | (if $lab != null and (($lab.tuning_image_shas | type) == "array") then $lab.tuning_image_shas else [] end) as $tun

    # session ledger
    | (if ($ses | type) == "object"
          and (($ses | keys | sort) == ["judge_id","schema_version","sessions"])
          and $ses.schema_version == "taste-calibration-sessions/v1"
          and $ses.judge_id == ($in.judge.id // "")
          and (($ses.sessions | type) == "array")
          and ($ses.sessions | all(.[];
                type == "object" and (keys | sort) == ["response_sha256","role","session_id","unit_id"]
                and (.role == "primary" or .role == "mirror")
                and (.session_id | nonempty) and (.unit_id | nonempty) and (.response_sha256 | hex64)))
       then {ok: true, list: $ses.sessions} else {ok: false, list: []} end) as $S
    | ([ if $S.ok then empty else "SESSION_UNBOUND" end,
         if $S.ok and (($S.list | length) != (($units | length) * 2)) then "SESSION_UNBOUND" else empty end,
         if $S.ok and (($S.list | map(.session_id) | unique | length) != ($S.list | length)) then "SESSION_REUSE" else empty end
       ]) as $ses_codes
    | (reduce $S.list[] as $s ({}; . + {("\($s.unit_id)|\($s.role)"): $s})) as $smap

    # units array
    | ([ if ($in.units | type) != "array" then "SCHEMA_REJECTED" else empty end,
         if (($units | map(.unit_id? // null) | unique | length) != ($units | length)) then "DUPLICATE_UNIT" else empty end
       ]) as $units_codes

    # per-unit recompute
    | ([ range(0; ($units | length)) as $i
         | $units[$i] as $u
         | ($res["\($i):primary"]) as $rp
         | ($res["\($i):mirror"]) as $rm
         | ($res["\($i):image"]) as $ri
         | ($lmap[$u.unit_id? // "" | tostring] // null) as $L
         | ($u.primary?) as $bp | ($u.mirror?) as $bm
         | (($u | type) == "object" and (($bp | type) == "object") and (($bm | type) == "object")
            and (($u.unit_id? // "") | nonempty)
            and (($u.image? | type) == "object") and (($u.image.sha256? // "") | hex64)
            and (($bp.orientation? | type) == "array") and (($bp.orientation | length) == 2)
            and (($bm.orientation? | type) == "array") and (($bm.orientation | length) == 2)
            and (($bp.invocation? | type) == "object") and (($bm.invocation? | type) == "object")) as $ushape
         | (if $ushape | not
            then {codes: ["SCHEMA_REJECTED"], correct: false, scored: false, side_left: 0, contradiction: 0}
            else
              (pos($rp.final)) as $pp | (pos($rm.final)) as $pm
              | (if $pp == 1 then $bp.orientation[0] elif $pp == 2 then $bp.orientation[1] else "abstain" end) as $cp
              | (if $pm == 1 then $bm.orientation[0] elif $pm == 2 then $bm.orientation[1] else "abstain" end) as $cm
              | def resp_code($r):
                  if $r == null then ["SCHEMA_REJECTED"]
                  elif $r.src == "badpath" then ["SYNTHETIC_RECEIPT"]
                  elif $r.src == "none" then ["SCHEMA_REJECTED"]
                  elif ($r.actual != $r.decl) then ["RESPONSE_HASH_MISMATCH"]
                  elif ($r.final == "NONE") then ["RESPONSE_UNPARSEABLE"]
                  else [] end;
                def blind($b): ($b.identity_visible == false and $b.prior_ballots_visible == false
                                and $b.injection_detected == false and $b.judge_discussion == false);
                def inv_ok($b): ($b.invocation.provider == $fz.provider and $b.invocation.model == $fz.model
                                 and $b.invocation.model_version == $fz.model_version
                                 and $b.invocation.system_prompt_sha256 == $fz.system_prompt_sha256
                                 and $b.invocation.sampling_sha256 == $fz.sampling_sha256
                                 and $b.invocation.parser_sha256 == $pinned
                                 and $b.invocation.adapter_sha256 == $fz.invocation_adapter_sha256);
                ($smap["\($u.unit_id)|primary"]) as $sp
              | ($smap["\($u.unit_id)|mirror"]) as $sm
              | ([ resp_code($rp), resp_code($rm),
                   (if ($ri == null) or ($ri.src == "badpath") then ["SYNTHETIC_RECEIPT"]
                    elif ($ri.src == "file") and ($ri.actual != $ri.decl) then ["IMAGE_BINDING"]
                    else [] end),
                   (if $L == null then ["HOLDOUT_BINDING"]
                    elif $L.image_sha256 != $u.image.sha256 then ["IMAGE_BINDING"] else [] end),
                   (if ($L != null) and (($tun | index($u.image.sha256)) != null) then ["TUNING_HOLDOUT_OVERLAP"] else [] end),
                   (if blind($bp) and blind($bm) then [] else ["IDENTITY_LEAK"] end),
                   (if inv_ok($bp) and inv_ok($bm) then [] else ["INVOCATION_DRIFT"] end),
                   (if ($bm.orientation == [$bp.orientation[1], $bp.orientation[0]]) then [] else ["ORIENTATION_NOT_MIRRORED"] end),
                   (if ($L != null) and (($bp.orientation | sort) != ($L.stimulus_ids | sort)) then ["IMAGE_BINDING"] else [] end),
                   (if ($pp == 0) or ($pm == 0)
                    then (if ($pp == 0 and $pm == 0
                              and ($bp.abstain_reason? | type == "string" and length > 0)
                              and ($bm.abstain_reason? | type == "string" and length > 0))
                          then [] else ["INVALID_ABSTENTION"] end)
                    else (if ($bp | has("abstain_reason")) or ($bm | has("abstain_reason")) then ["INVALID_ABSTENTION"] else [] end)
                    end),
                   (if ($ses_codes | length) > 0 then []
                    elif $sp == null or $sm == null then ["SESSION_UNBOUND"]
                    elif ($sp.response_sha256 != $rp.actual) or ($sm.response_sha256 != $rm.actual) then ["SESSION_UNBOUND"]
                    elif $sp.session_id == $sm.session_id then ["SESSION_REUSE"]
                    else [] end)
                 ] | add) as $ucodes
              | (($pp == 0) and ($pm == 0)) as $abstain
              | (($abstain | not) and ($pp > 0) and ($pm > 0)) as $scored
              | (if $L == null then false else ($cp == $L.correct_stimulus and $cm == $L.correct_stimulus) end) as $is_correct
              | {codes: $ucodes,
                 correct: ($is_correct and ($ucodes | length) == 0),
                 scored: $scored,
                 side_left: (if $scored and ($pp == 1) then 1 else 0 end),
                 contradiction: (if $scored and ($cp != $cm) then 1 else 0 end)}
            end)
       ]) as $per

    # classification: every image + both responses are hash-matched files
    | (($units | length) > 0
       and ([ range(0; ($units | length)) as $i
              | ($res["\($i):image"].src == "file") and ($res["\($i):image"].actual == $res["\($i):image"].decl)
                and ($res["\($i):primary"].src == "file")
                and ($res["\($i):mirror"].src == "file") ] | all)) as $all_file

    | {codes: (($fz_codes + $cal_codes + $lab_codes + $ses_codes + $units_codes + [$per[].codes[]]) | unique),
       units: ($units | length),
       correct: ([$per[] | select(.correct)] | length),
       scored: ([$per[] | select(.scored)] | length),
       side_left: ([$per[] | select(.scored) | .side_left] | add // 0),
       contradictions: ([$per[] | select(.scored) | .contradiction] | add // 0),
       all_file: $all_file,
       session_ids: ($S.list | map(.session_id))}
  ')

  local units correct scored side_left contra all_file
  units=$(printf '%s' "$STRUCT" | jq '.units')
  correct=$(printf '%s' "$STRUCT" | jq '.correct')
  scored=$(printf '%s' "$STRUCT" | jq '.scored')
  side_left=$(printf '%s' "$STRUCT" | jq '.side_left')
  contra=$(printf '%s' "$STRUCT" | jq '.contradictions')
  all_file=$(printf '%s' "$STRUCT" | jq '.all_file')
  printf '%s' "$STRUCT" | jq -r --arg idx "$idx" '.session_ids[] | "\($idx)\t\(.)"' >>"$SCRATCH/session-ids.tsv"

  local classification=fixture_only
  if [ "$all_file" = true ]; then classification=production; fi

  local wilson side_p
  wilson=$(wilson_lcb "$correct" "$units")
  side_p=$(side_probe_p "$side_left" "$scored")

  # ---- frozen threshold gates ----
  local threshold=''
  [ "$units" -ge "$UNITS_MIN" ] || threshold="$threshold ACCURACY_FLOOR"
  [ "$correct" -ge "$CORRECT_MIN" ] || threshold="$threshold ACCURACY_FLOOR"
  awk -v v="$wilson" -v m="$WILSON_MIN" 'BEGIN { exit !(v >= m) }' || threshold="$threshold WILSON_FLOOR"
  [ "$scored" -ge "$SIDE_N_MIN" ] || threshold="$threshold SIDE_BIAS"
  awk -v v="$side_p" -v m="$SIDE_P_MIN" 'BEGIN { exit !(v >= m) }' || threshold="$threshold SIDE_BIAS"
  [ "$scored" -ge "$MIRROR_N_MIN" ] || threshold="$threshold MIRROR_INSTABILITY"
  [ "$contra" -le "$CONTRA_MAX" ] || threshold="$threshold MIRROR_INSTABILITY"

  local struct_codes pre_codes pre_eligible=false
  struct_codes=$(printf '%s' "$STRUCT" | jq -c '.codes')
  pre_codes=$(jq -cn --argjson s "$struct_codes" --arg t "$threshold" '
    ($t | split(" ") | map(select(length > 0))) as $tc | ($s + $tc) | unique')
  if [ "$(printf '%s' "$pre_codes" | jq 'length')" -eq 0 ]; then pre_eligible=true; fi

  # ---- adversarial receipt cross-check: recomputed truth vs emitted claim ----
  local cross_codes
  cross_codes=$(jq -c \
    --slurpfile cal "$CAL" \
    --arg pinned "$PINNED_PARSER_SHA" \
    --arg cal_sha "$cal_sha" --arg lab_sha "$lab_sha" \
    --argjson units "$units" --argjson correct "$correct" \
    --argjson scored "$scored" --argjson contra "$contra" \
    --argjson wilson "$wilson" --argjson side_p "$side_p" \
    --arg classification "$classification" --argjson eligible "$pre_eligible" '
    def close($a; $b): (($a - $b) | if . < 0 then -. else . end) < 0.0000005;
    (($cal[0].freeze // {})) as $fz
    | [ if .schema_version == "taste-calibration/v2"
           and .receipt_version == "polylane.taste.judge-eligibility.v2"
        then empty else "RECEIPT_MISMATCH" end,
        if .human_certified == false and .machine_not_human == true
           and .machine_panel_claim == "HUMAN_CALIBRATED_MACHINE"
        then empty else "HUMAN_CLAIM" end,
        if .input_sha256 == $cal_sha then empty else "STALE_CONFIG" end,
        if (.judge_configuration | type) == "object"
           and .judge_configuration.provider == $fz.provider
           and .judge_configuration.model == $fz.model
           and .judge_configuration.model_version == $fz.model_version
           and .judge_configuration.system_prompt_sha256 == $fz.system_prompt_sha256
           and .judge_configuration.sampling_sha256 == $fz.sampling_sha256
           and .invocation_adapter_sha256 == $fz.invocation_adapter_sha256
           and .source_snapshot_sha256 == $fz.source_snapshot_sha256
           and .judge_id == ($cal[0].judge.id // "")
        then empty else "STALE_CONFIG" end,
        if .response_parser_sha256 == $pinned then empty else "PARSER_CHANGED" end,
        if .holdout_labels_sha256 == $lab_sha then empty else "HOLDOUT_BINDING" end,
        if .sample_units == $units and .correct_units == $correct
           and .side_probe_n == $scored and .mirror_probe_n == $scored
           and .mirror_contradictions == $contra
           and close(.wilson_lower_bound; $wilson)
           and close(.side_probe_exact_binomial_p; $side_p)
           and .classification == $classification
           and .eligible == $eligible
           and .production == ($eligible and $classification == "production")
        then empty else "RECEIPT_MISMATCH" end
      ] | unique' "$RCP")

  local all_codes eligible=false
  all_codes=$(jq -cn --argjson a "$pre_codes" --argjson b "$cross_codes" '($a + $b) | unique')
  if [ "$(printf '%s' "$all_codes" | jq 'length')" -eq 0 ]; then eligible=true; fi

  write_cfg "$idx" "$all_codes" "$eligible" "$classification" \
    "$units" "$correct" "$wilson" "$scored" "$side_p" "$scored" "$contra" \
    "$(printf '%s' "$STRUCT" | jq '.session_ids | length')" \
    "$cal_sha" "$rcp_sha" "$ses_sha" "$lab_sha" "$JUDGE_ID"
  [ "$eligible" = true ]
}

i=0
HUMAN_CLAIM_SEEN=false
while [ "$i" -lt "$CFG_COUNT" ]; do
  audit_config "$i" || true
  if jq -e '.reason_codes | index("HUMAN_CLAIM") != null' "$SCRATCH/cfg.$i.json" >/dev/null; then
    HUMAN_CLAIM_SEEN=true
  fi
  i=$((i + 1))
done

CONFIGS='[]'
if [ "$CFG_COUNT" -gt 0 ]; then
  CONFIGS=$(jq -cs '.' "$SCRATCH"/cfg.*.json | jq -c 'sort_by(.config_id)')
  # preserve manifest order, not lexical cfg.* glob order
  CONFIGS=$(jq -cn --slurpfile in "$INPUT_PATH" --argjson cfgs "$CONFIGS" '
    ($in[0].configurations | map(.config_id)) as $order
    | $order | map(. as $id | $cfgs[] | select(.config_id == $id))')
fi

# --------------------------------------------------------------------------
# panel aggregation: floor, cross-configuration session reuse, human claims
# --------------------------------------------------------------------------
PANEL_CODES=''
add_panel() { PANEL_CODES="$PANEL_CODES $1"; }

PROD_COUNT=$(printf '%s' "$CONFIGS" | jq '[.[] | select(.eligible and .classification == "production")] | length')
[ "$PROD_COUNT" -ge "$PANEL_MIN" ] || add_panel PANEL_FLOOR

# a session id used by more than one configuration is reuse even if each
# configuration is internally consistent
CROSS_DUP=$(awk -F'\t' '{ if (seen[$2] != "" && seen[$2] != $1) { print "dup"; exit } seen[$2] = $1 }' "$SCRATCH/session-ids.tsv")
[ -z "$CROSS_DUP" ] || add_panel SESSION_REUSE

[ "$HUMAN_CLAIM_SEEN" = false ] || add_panel HUMAN_CLAIM

PANEL_CODES_JSON=$(jq -cn --arg t "$PANEL_CODES" '$t | split(" ") | map(select(length > 0)) | unique')
if [ "$(printf '%s' "$PANEL_CODES_JSON" | jq 'length')" -eq 0 ]; then
  emit_receipt true '[]' "$CONFIGS"
  exit 0
fi
emit_receipt false "$PANEL_CODES_JSON" "$CONFIGS"
exit 1
