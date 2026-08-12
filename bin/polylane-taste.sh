#!/usr/bin/env bash
# Compile fail-closed taste certificates.
#   v1 manifests (taste-evidence-manifest/v1) keep compiling for compatibility,
#   but every v1 certificate is marked fixture_only/non-production evidence.
#   v2 manifests (taste-evidence-manifest/v2) run the production compiler: every
#   referenced artifact is a safe, regular, duplicate-key-free, SHA-256-matched
#   file, every validator receipt is hash-bound to its raw input, and the
#   subject revision must be the integrator HEAD or a proven ancestor with only
#   declared evidence commits after it.
set -euo pipefail

usage() { printf '%s\n' 'usage: polylane-taste.sh certify MANIFEST CERTIFICATE [SUBJECT_ROOT]' >&2; }
reasons=''
add_reason() { case "|$reasons|" in *"|$1|"*) ;; *) reasons="${reasons:+$reasons|}$1" ;; esac; }
seen_add() { local name=$1 value=$2 current; eval "current=\${$name}"; case "|$current|" in *"|$value|"*) return 1;; *) eval "$name=\${$name:+\${$name}|}$value";; esac; }
is_sha() { [[ $1 =~ ^[0-9a-f]{64}$ ]]; }
is_revision() { [[ $1 =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]]; }

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | awk '{print $1}'
  else return 1; fi
}

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else return 1; fi
}

regular_json_without_duplicate_keys() {
  local file=$1 duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("\u001f")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

safe_receipt() {
  local rel=$1 expected=$2 path part prefix old_ifs
  case "$rel" in ''|/*|*'..'*|*'//'*) return 1;; esac
  path="$manifest_dir/$rel"
  prefix="$manifest_dir"; old_ifs=$IFS; IFS='/'
  for part in $rel; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
    prefix="$prefix/$part"
    [ ! -L "$prefix" ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
  regular_json_without_duplicate_keys "$path" || return 1
  jq -e --arg expected "$expected" 'type == "object" and .schema_version == $expected' "$path" >/dev/null 2>&1 || return 1
  jq -c . "$path"
}

write_certificate() {
  local status=$1 calibrated=$2 human=$3 label=$4 tmp manifest_sha code_json
  manifest_sha=$(sha256_file "$manifest")
  code_json=$(printf '%s' "$reasons" | tr '|' '\n' | sed '/^$/d' | jq -R . | jq -s .)
  tmp=$(mktemp "${certificate}.tmp.XXXXXX") || return 1
  jq -n --arg run_id "$run_id" --arg protocol "$protocol_version" --arg manifest_sha "$manifest_sha" --arg status "$status" --arg label "$label" --arg repair "$repair_sha" --argjson calibrated "$calibrated" --argjson human "$human" --argjson briefs "$brief_count" --argjson wins "$brief_wins" --argjson preference "$preference" --argjson confidence "$confidence" --argjson groups "$groups_per_brief" --argjson codes "$code_json" '
    {schema_version:"taste-certificate/v1",run_id:$run_id,protocol_version:$protocol,evidence_manifest_sha256:$manifest_sha,status:$status,claim_label:$label,fixture_only:true,production:false,human_calibrated:$calibrated,human_certified:$human,briefs:$briefs,eligible_human_mirrored_groups_per_brief:$groups,brief_wins:$wins,preference_rate:$preference,confidence_lower:$confidence,accessibility_regressions:0,repair_ledger_sha256:$repair,external_limitations:["panel identity and host assurance remain externally scoped","v1 shape-only evidence is fixture-grade and can never satisfy a production runner gate"],verdict_reason_codes:$codes}' >"$tmp" && mv -f "$tmp" "$certificate" || { rm -f "$tmp"; return 1; }
}

# --------------------------------------------------------------------------
# v2 production compiler
# --------------------------------------------------------------------------
SCRATCH_V2=''
cleanup_v2() { [ -z "$SCRATCH_V2" ] || rm -rf "$SCRATCH_V2"; }
trap cleanup_v2 EXIT HUP INT TERM

v2_safe_path() {
  local root=$1 rel=$2 part prefix old_ifs
  case "$rel" in ''|/*|*'//'*|*'\'*) return 1;; esac
  prefix="$root"; old_ifs=$IFS; IFS='/'
  for part in $rel; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
    prefix="$prefix/$part"
    [ ! -L "$prefix" ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
  [ ! -e "$root/$rel" ] || [ -f "$root/$rel" ]
}

# Closed manifest schema.  The caller never supplies a status, score, or winner:
# any unknown key anywhere in the manifest envelope is MANIFEST_INVALID.
V2_MANIFEST_FILTER='
  def single: type == "object" and (keys | sort) == ["path","sha256"]
    and (.path | type == "string" and length > 0)
    and (.sha256 | type == "string" and test("^[0-9a-f]{64}$"));
  def pair: type == "object" and (keys | sort) == ["input","receipt"]
    and (.input | single) and (.receipt | single);
  type == "object"
  and (keys | sort) == ["briefs","calibrations","candidate_id","corpus","declared_evidence_paths","design_lock_sha256","directions","escrow","fixture","goal_sha256","protocol_version","reference_packet","repair","required_claim","run_id","schema_version","stats","subject_revision","threat"]
  and .schema_version == "taste-evidence-manifest/v2"
  and (.run_id | type == "string" and length > 0)
  and .protocol_version == "taste-protocol/v1"
  and (.candidate_id | type == "string" and length > 0)
  and (.subject_revision | type == "string" and test("^[0-9a-f]{40}([0-9a-f]{24})?$"))
  and (.goal_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
  and (.design_lock_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
  and (.fixture | type == "boolean")
  and (.required_claim | IN("HUMAN_CALIBRATED_MACHINE","HUMAN_CERTIFIED"))
  and (.declared_evidence_paths | type == "array"
       and all(.[]; type == "string" and length > 0 and (startswith("/") | not) and (contains("..") | not)))
  and (.escrow | single) and (.reference_packet | single) and (.directions | single)
  and (.corpus | pair) and (.stats | pair) and (.threat | pair) and (.repair | pair)
  and (.briefs | type == "array" and all(.[]; type == "object"
    and (keys | sort) == ["brief_lock","candidate","capture","groups","hard_gate","review"]
    and (.brief_lock | single) and (.candidate | single) and (.hard_gate | single)
    and (.capture | pair) and (.review | pair)
    and (.groups | type == "array" and length > 0 and all(.[]; pair))))
  and (.calibrations | type == "array" and length > 0 and all(.[]; pair))
'

V2_ROLES_FILTER='
  def entry($r): [$r, .path, .sha256] | @tsv;
  ([ (.escrow | entry("escrow")),
     (.reference_packet | entry("reference")),
     (.directions | entry("directions")),
     (.corpus.input | entry("corpus.in")), (.corpus.receipt | entry("corpus.rc")),
     (.stats.input | entry("stats.in")), (.stats.receipt | entry("stats.rc")),
     (.threat.input | entry("threat.in")), (.threat.receipt | entry("threat.rc")),
     (.repair.input | entry("repair.in")), (.repair.receipt | entry("repair.rc")) ]
   + [ .briefs | to_entries[] | .key as $i | .value
       | (.brief_lock | entry("brief.\($i).lock")),
         (.candidate | entry("brief.\($i).cand")),
         (.capture.input | entry("brief.\($i).cap.in")),
         (.capture.receipt | entry("brief.\($i).cap.rc")),
         (.hard_gate | entry("brief.\($i).hard")),
         (.review.input | entry("brief.\($i).rev.in")),
         (.review.receipt | entry("brief.\($i).rev.rc")),
         (.groups | to_entries[] | .key as $j | .value
          | (.input | entry("brief.\($i).grp.\($j).in")),
            (.receipt | entry("brief.\($i).grp.\($j).rc"))) ]
   + [ .calibrations | to_entries[] | .key as $k | .value
       | (.input | entry("cal.\($k).in")), (.receipt | entry("cal.\($k).rc")) ])
  | .[]
'

V2_ART_FILTER='
  def lines($x): $x | split("\n") | map(select(length > 0));
  (lines($actual) | map({key: .[66:], value: .[0:64]}) | from_entries) as $sha
  | (lines($unsafe)) as $bad_roles
  | (lines($bad)) as $bad_json
  | (lines($dup)) as $dup_json
  | (lines($roles) | map(split("\t"))) as $entries
  | ($loaded[0] // {}) as $L
  | reduce $entries[] as $e ({};
      $e[0] as $role | $e[1] as $p | $e[2] as $d |
      (if ($bad_roles | index($role)) != null then ["UNSAFE_PATH"]
       elif ($sha[$p] // "") == "" then ["RECEIPT_MISSING"]
       elif $sha[$p] != $d then ["HASH_MISMATCH"]
       elif (($bad_json | index($p)) != null) or (($dup_json | index($p)) != null) then ["RECEIPT_SCHEMA"]
       else [] end) as $codes
      | . + {($role): {path: $p, actual: ($sha[$p] // ""), codes: $codes,
                       body: (if $codes == [] then ($L[$p] // null) else null end)}})
'

V2_CERT_FILTER='
  def E(r): ($A[0][r] // {path: "", actual: "", codes: ["RECEIPT_MISSING"], body: null});
  def B(r): E(r).body;
  def S(r): E(r).actual;
  def hex64: type == "string" and test("^[0-9a-f]{64}$");
  def nonempty: type == "string" and length > 0;
  def r8: (. * 100000000 | round) / 100000000;
  def wilson($w; $n): ($w / $n) as $p | 1.959964 as $z
    | (1 + $z * $z / $n) as $d
    | (($p + $z * $z / (2 * $n)) / $d) as $c
    | ($z * ((($p * (1 - $p) + $z * $z / (4 * $n)) / $n) | sqrt) / $d) as $mg
    | ($c - $mg);
  $mm[0] as $m
  | ([$A[0][] | .codes[]]) as $transport

  # -- calibrations: production judge-eligibility receipts, hash-bound --------
  | ([range(0; ($m.calibrations | length))] | map(. as $k
      | B("cal.\($k).in") as $cin | B("cal.\($k).rc") as $c
      | if $cin == null or ($c | type) != "object" then {codes: ["CALIBRATION_INVALID"], judge: null}
        else
          ($c.schema_version == "taste-calibration/v1"
           and $c.eligible == true and $c.result == "eligible"
           and ($c.judge_id | nonempty)
           and ($c.judge | type == "object" and .id == $c.judge_id)
           and ($c.judge_configuration | type == "object"
                and (.kind | IN("human","machine")) and (.provider | nonempty) and (.model | nonempty))
           and ([$c.human_labelled_pairs, $c.correct, $c.wilson_lcb_95, $c.side_probe_n,
                 $c.side_probe_exact_binomial_p, $c.mirror_probe_n, $c.mirror_contradictions]
                | all(type == "number"))
           and $c.human_labelled_pairs >= 24 and $c.correct >= 17 and $c.wilson_lcb_95 >= 0.50
           and $c.side_probe_n >= 12 and $c.side_probe_exact_binomial_p >= 0.05
           and $c.mirror_probe_n >= 8 and $c.mirror_contradictions < 2) as $shape
          | ($c.input_sha256 == S("cal.\($k).in")) as $bound
          | {codes: ((if $shape then [] else ["CALIBRATION_INVALID"] end)
                   + (if $bound then [] else ["RECEIPT_BINDING"] end)),
             judge: (if $shape and $bound
                     then {id: $c.judge_id, kind: $c.judge_configuration.kind,
                           provider: $c.judge_configuration.provider, model: $c.judge_configuration.model}
                     else null end)}
        end)) as $cals
  | ([$cals[].judge | select(. != null)]) as $judgerecs
  | (if ([$judgerecs[].id] | length) == ([$judgerecs[].id] | unique | length)
     then [] else ["CALIBRATION_INVALID"] end) as $caldup_codes
  | (reduce $judgerecs[] as $j ({}; . + {($j.id): $j})) as $calmap

  # -- coordinator escrow: provenance bound here, hidden from ballots ---------
  | B("escrow") as $esc
  | (if ($esc | type) == "object"
        and (($esc | keys | sort) == ["candidate_id","generation","judges","run_id","schema_version"])
        and $esc.schema_version == "taste-provenance-escrow/v1"
        and $esc.run_id == $m.run_id and $esc.candidate_id == $m.candidate_id
        and ($esc.generation | type == "object" and (keys | sort) == ["model","provider"]
             and (.model | nonempty) and (.provider | nonempty))
        and ($esc.judges | type == "array"
             and all(.[]; type == "object" and (keys | sort) == ["judge_id","kind","model","provider"]
                     and (.judge_id | nonempty) and (.kind | IN("human","machine"))
                     and (.model | nonempty) and (.provider | nonempty)))
        and ([$esc.judges[].judge_id] | length == (unique | length))
     then [] else ["ESCROW_BINDING"] end) as $escrow_codes
  | (if ($esc | type) == "object" and (($esc.judges? | type) == "array")
     then (reduce ($esc.judges[] | select(type == "object" and (.judge_id | type) == "string")) as $j
             ({}; . + {($j.judge_id): $j}))
     else {} end) as $escmap

  # -- candidate-group bundles -------------------------------------------------
  | B("reference") as $ref
  | (if ($ref | type) == "object" and $ref.schema_version == "taste-reference-packet/v1"
        and ($ref.same_category_references | type == "array" and length >= 3 and length <= 5)
        and ($ref.wildcard_reference | type) == "object"
     then [] else ["REFERENCE_BUNDLE"] end) as $ref_codes
  | B("directions") as $dir
  | (if ($dir | type) == "object" and $dir.schema_version == "taste-direction/v1"
        and ($dir.directions | type == "array" and length == 3
             and ([.[] | (.direction_id? // "")] | (length == (unique | length)) and all(.[]; length > 0)))
     then [] else ["DIRECTION_BUNDLE"] end) as $dir_codes

  # -- corpus validation --------------------------------------------------------
  | B("corpus.in") as $cor
  | B("corpus.rc") as $corr
  | ((if ($cor | type) == "object" and $cor.format_version == 1
         and ($cor.records | type == "array" and length > 0)
      then [] else ["CORPUS_INVALID"] end)
   + (if ($corr | type) == "object"
         and $corr.schema_version == "taste-corpus-receipt/v1" and $corr.status == "VALIDATED"
         and (($corr.output? | type) == "object")
         and ($corr.output.record_count | type == "number")
         and (($cor | type) == "object" and ($cor.records? | type) == "array"
              and $corr.output.record_count == ($cor.records | length))
      then (if $corr.input_sha256 == S("corpus.in") then [] else ["RECEIPT_BINDING"] end)
      else ["CORPUS_INVALID"] end)) as $corpus_codes

  # -- threat scan ---------------------------------------------------------------
  | B("threat.in") as $tin
  | B("threat.rc") as $trc
  | ((if ($tin | type) == "object" and $tin.schema_version == "taste-threat/v1"
      then [] else ["THREAT_GATE"] end)
   + (if ($trc | type) == "object"
      then ((if (($trc.schema_version | IN("taste-threat-receipt/v1","taste-threat-receipt/v2"))
                and $trc.status == "clean"
                and ($trc.axis_results | type == "object"
                     and .genericness_review == "pass" and .quality_risk == "pass"
                     and .context_fit == "pass" and .provenance_integrity == "pass")
                and ($trc.review | type == "object"
                     and .status == "not-required" and .attribution_claim == false)
                and ($trc.reason_codes | type == "array" and length == 0))
             then [] else ["THREAT_GATE"] end)
          + (if $trc.input_sha256 == S("threat.in") then [] else ["RECEIPT_BINDING"] end))
      else ["THREAT_GATE"] end)) as $threat_codes

  # -- repair validation -----------------------------------------------------------
  | B("repair.in") as $rin
  | B("repair.rc") as $rrc
  | (if ($rin | type) != "object" or $rin.schema_version != "taste-repair-ledger/v1"
        or (($rin.entries? | type) != "array") or ($rrc | type) != "object"
     then {codes: ["REPAIR_LEDGER"], count: 0}
     else
       ((if ($rrc.schema_version == "taste-repair-ledger/v2" and $rrc.status == "valid"
            and ($rrc.repair_count | type == "number" and floor == . and . >= 0)
            and $rrc.repair_count == ($rin.entries | length))
         then [] else ["REPAIR_LEDGER"] end)
      + (if $rrc.input_sha256 == S("repair.in") then [] else ["RECEIPT_BINDING"] end)) as $codes
       | {codes: ($codes + (if ($rrc.repair_count | type) == "number" and $rrc.repair_count > 2
                            then ["REPAIR_BUDGET"] else [] end)),
          count: (if ($rrc.repair_count | type) == "number" then $rrc.repair_count else 0 end)}
     end) as $repair

  # -- briefs, captures, hard gates, reviews, mirrored groups -----------------------
  | ($m.briefs | length) as $bn
  | ([range(0; $bn)] | map(. as $i
      | B("brief.\($i).lock") as $lock
      | B("brief.\($i).cand") as $cand
      | B("brief.\($i).cap.in") as $cap
      | B("brief.\($i).cap.rc") as $pix
      | B("brief.\($i).hard") as $hard
      | B("brief.\($i).rev.in") as $side
      | B("brief.\($i).rev.rc") as $rev
      | ($m.briefs[$i].groups | length) as $gn
      | (if ($lock | type) == "object"
            and (($lock | keys | sort) == ["acceptance_facts_sha256","brief_id","brief_sha256","core_task","locked_at","required_routes","required_states","rubric_version","schema_version","target_population"])
            and $lock.schema_version == "taste-brief/v1"
            and ($lock.brief_id | nonempty) and ($lock.brief_sha256 | hex64)
            and ($lock.target_population | type) == "object"
            and (($lock.target_population.category // $lock.target_population.role // "") | nonempty)
            and ($lock.core_task | type) == "object" and (($lock.core_task.id? // "") | nonempty)
         then {id: $lock.brief_id, sha: $lock.brief_sha256,
               cat: ($lock.target_population.category // $lock.target_population.role),
               task: $lock.core_task.id, codes: []}
         else {id: "brief-index-\($i)", sha: "invalid-\($i)", cat: "invalid-\($i)",
               task: "invalid-\($i)", codes: ["BRIEF_INVALID"]} end) as $L
      | (if ($cand | type) == "object"
            and (($cand | keys | sort) == ["brief_sha256","build_receipt_sha256","candidate_id","created_at","dependency_lock_sha256","design_lock_sha256","direction_id","schema_version","source_revision"])
            and $cand.schema_version == "taste-candidate/v1"
            and $cand.candidate_id == $m.candidate_id
            and $cand.brief_sha256 == $L.sha
            and $cand.design_lock_sha256 == $m.design_lock_sha256
         then (if $cand.source_revision == $m.subject_revision then [] else ["STALE_REVISION"] end)
         else ["CANDIDATE_PROVENANCE"] end) as $cand_codes
      | (if ($cap | type) == "object"
            and (($cap | keys | sort) == ["browser","candidate_id","candidate_source_revision","captures","decoder","mobile_only_states","required_routes","required_states","schema_version"])
            and $cap.schema_version == "taste-capture-manifest/v1"
            and $cap.candidate_id == $m.candidate_id
            and ($cap.captures | type == "array" and length > 0
                 and all(.[]; type == "object"
                   and (keys | sort) == ["action_trace_sha256","capture_id","captured_at","decoded_height","decoded_pixel_sha256","decoded_width","dom_sha256","route","screenshot_path","screenshot_png_sha256","state","viewport","viewport_css_px"]
                   and (.capture_id | nonempty)
                   and (.decoded_pixel_sha256 | hex64) and (.screenshot_png_sha256 | hex64)
                   and (.action_trace_sha256 | hex64) and (.dom_sha256 | hex64)
                   and (.decoded_width | type == "number" and . > 0)
                   and (.decoded_height | type == "number" and . > 0))
                 and ([.[].capture_id] | length == (unique | length)))
         then {codes: (if $cap.candidate_source_revision == $m.subject_revision then [] else ["STALE_REVISION"] end),
               pixels: [$cap.captures[].decoded_pixel_sha256],
               screens: [$cap.captures[].screenshot_png_sha256],
               count: ($cap.captures | length)}
         else {codes: ["CAPTURE_INVALID"], pixels: [], screens: [], count: -1} end) as $C
      | (if ($pix | type) == "object"
            and $pix.schema_version == "taste-pixels-receipt/v1" and $pix.status == "VERIFIED"
            and (($pix.output? | type) == "object")
            and ($pix.output.capture_count | type == "number") and $pix.output.capture_count == $C.count
         then (if $pix.input_sha256 == S("brief.\($i).cap.in") then [] else ["RECEIPT_BINDING"] end)
         else ["CAPTURE_INVALID"] end) as $pix_codes
      | (if ($hard | type) == "object"
            and $hard.schema_version == "taste-hard-gate/v1"
            and $hard.candidate_id == $m.candidate_id
            and ($hard.task_results | type == "array" and length > 0)
            and ($hard.accessibility | type == "array" and length > 0)
            and ($hard.state_coverage | type == "array" and length > 0)
            and ($hard.product_specificity | type) == "object"
         then ([$hard.accessibility[] | select((type == "object" and .status == "pass") | not)] | length) as $acc
           | {codes: ((if $hard.capture_manifest_sha256 == S("brief.\($i).cap.in") then [] else ["RECEIPT_BINDING"] end)
                    + (if $hard.overall == "PASS" then [] else ["HARD_GATE_INVALID"] end)
                    + (if ($hard.task_results | all(.[]; type == "object" and .status == "pass")) then [] else ["TASK_GATE_VETO"] end)
                    + (if $acc == 0 then [] else ["ACCESSIBILITY_VETO"] end)
                    + (if ($hard.state_coverage | all(.[]; type == "object" and .status == "pass")) then [] else ["STATE_COVERAGE_VETO"] end)
                    + (if $hard.product_specificity.status == "pass" then [] else ["PRODUCT_SPECIFICITY_VETO"] end)),
              acc: $acc}
         else {codes: ["HARD_GATE_INVALID"], acc: 0} end) as $H
      | (if ($side | type) == "object" and $side.schema_version == "taste-sameness-sidecar/v1"
            and ($side.brief_id? // "") == $L.id
         then [] else ["CROSS_BRIEF_REVIEW"] end) as $side_codes
      | (if ($rev | type) == "object"
            and $rev.schema_version == "taste-cross-brief-review/v2"
            and $rev.status == "resolved" and $rev.determination == "clear"
            and $rev.brief_id == $L.id
         then (if $rev.input_sha256 == S("brief.\($i).rev.in") then [] else ["RECEIPT_BINDING"] end)
         else ["CROSS_BRIEF_REVIEW"] end) as $rev_codes
      | ([range(0; $gn)] | map(. as $j
          | B("brief.\($i).grp.\($j).in") as $g
          | B("brief.\($i).grp.\($j).rc") as $r
          | S("brief.\($i).grp.\($j).in") as $gsha
          | if ($g | type) != "object" then {codes: ["BALLOT_INVALID"], winner: null, judges: [], fixture: false}
            else
              ((($g | keys | sort) == ["brief_sha256","candidate_ids_escrow_sha256","exposures","mirror_group_id","outcome","pointwise_ballot_ids","schema_version"])
               and $g.schema_version == "taste-mirrored-group/v1"
               and ($g.mirror_group_id | nonempty)
               and ($g.brief_sha256 | hex64) and ($g.candidate_ids_escrow_sha256 | hex64)
               and ($g.pointwise_ballot_ids | type == "array" and length == 2)
               and ($g.exposures | type == "array" and length == 2
                    and all(.[]; type == "object"
                      and (keys | sort) == ["ballot_id","canonical_choice","choice","display_order","independence_attestation_sha256","judge_id","sealed_at"]
                      and (.ballot_id | nonempty) and (.judge_id | nonempty)
                      and (.canonical_choice | nonempty) and (.choice | IN("A","B"))
                      and (.independence_attestation_sha256 | hex64)
                      and (.sealed_at | type == "string")))
               and (($g.exposures | [.[].display_order] | sort) == ["A/B","B/A"])) as $shape
              | if $shape | not then {codes: ["BALLOT_INVALID"], winner: null, judges: [], fixture: false}
                else
                  ([$g | .. | objects | keys[]]
                   | map(select(IN("provider","model","provider_id","model_id","generator","author","candidate_name","candidate_label")))
                   | length > 0) as $leak
                  | ($g.exposures[0].judge_id == $g.exposures[1].judge_id) as $samejudge
                  | ($g.exposures[0].canonical_choice != $g.exposures[1].canonical_choice) as $contradict
                  | ($g.brief_sha256 != $L.sha) as $wrongbrief
                  | ($g.outcome != ("resolved-" + $g.exposures[0].canonical_choice)) as $badoutcome
                  | (if ($r | type) != "object" then {c: ["BALLOT_INVALID"], fixture: false}
                     else
                       # Cycle-39 producers emit taste-ballot-validation/v1 with
                       # fixture_only:true; only a future production v2 receipt
                       # with fixture_only:false can count as promotion evidence.
                       {c: ((if (($r.schema_version | IN("taste-ballot-validation/v1","taste-ballot-validation/v2"))
                                and $r.status == "eligible" and $r.human_certified == false
                                and $r.mirror_group_id == $g.mirror_group_id
                                and $r.brief_sha256 == $g.brief_sha256)
                             then [] else ["BALLOT_INVALID"] end)
                          + (if $r.schema_version == "taste-ballot-validation/v2" and $r.fixture_only == false
                             then [] else ["FIXTURE_EVIDENCE"] end)
                          + (if $r.group_sha256 == $gsha and $r.winner == $g.exposures[0].canonical_choice
                             then [] else ["RECEIPT_BINDING"] end)),
                        fixture: (($r.schema_version != "taste-ballot-validation/v2") or ($r.fixture_only != false))}
                     end) as $R
                  | {codes: ((if $leak then ["IDENTITY_LEAK"] else [] end)
                           + (if $samejudge then ["JUDGE_NOT_INDEPENDENT"] else [] end)
                           + (if $contradict then ["SIDE_ORDER_CONTRADICTION"] else [] end)
                           + (if $wrongbrief or $badoutcome then ["BALLOT_INVALID"] else [] end)
                           + $R.c),
                     winner: (if $contradict then null else $g.exposures[0].canonical_choice end),
                     judges: [$g.exposures[].judge_id], fixture: $R.fixture}
                end
            end)) as $G
      | ([$G[] | select(.winner != null and .codes == [])]) as $valid_groups
      | ([$valid_groups[] | select(.winner == $m.candidate_id)] | length) as $wins
      | ($valid_groups | length) as $resolved
      | {codes: ($L.codes + $cand_codes + $C.codes + $pix_codes + $H.codes + $side_codes + $rev_codes
                 + [$G[].codes[]]
                 + (if $resolved >= 5 then [] else ["BALLOT_QUORUM"] end)),
         id: $L.id, sha: $L.sha, cat: $L.cat, task: $L.task,
         pixels: $C.pixels, screens: $C.screens,
         judges: [$G[].judges[]],
         pairs: [$G[] | .judges | select(length == 2)],
         groups: $resolved, wins: $wins,
         won: ($resolved > 0 and ($wins * 2) > $resolved),
         acc: $H.acc,
         fixture: ([$G[].fixture] | any)}
    )) as $BR

  # -- corpus-level floors and independence -------------------------------------
  | (if $bn >= 10 and $bn <= 100 then [] else ["BRIEF_QUORUM"] end) as $quorum_codes
  | (if (([$BR[].id] | length) == ([$BR[].id] | unique | length))
        and (([$BR[].cat] | length) == ([$BR[].cat] | unique | length))
        and (([$BR[].task] | length) == ([$BR[].task] | unique | length))
        and (([$BR[].sha] | length) == ([$BR[].sha] | unique | length))
     then [] else ["BRIEF_VARIETY"] end) as $variety_codes
  | ([$BR[].pixels[]]) as $pixels
  | ([$BR[].screens[]]) as $screens
  | (if ($pixels | length == (unique | length)) and ($screens | length == (unique | length))
     then [] else ["DUPLICATE_RENDER"] end) as $dup_codes
  | ([$BR[].judges[]]) as $alljudges
  | (if ($alljudges | length) == ($alljudges | unique | length)
     then [] else ["JUDGE_NOT_INDEPENDENT"] end) as $indep_codes
  | (if ($alljudges | all(($calmap[.] // null) != null))
     then [] else ["JUDGE_NOT_CALIBRATED"] end) as $uncal_codes
  | (if ($alljudges | all(. as $id
          | ($escmap[$id] // null) as $e | ($calmap[$id] // null) as $c
          | $e != null and ($c == null
              or ($e.kind == $c.kind and $e.provider == $c.provider and $e.model == $c.model))))
     then [] else ["ESCROW_BINDING"] end) as $escrow_match_codes
  | ([$BR[].pairs[]]) as $pairs
  | (if ($pairs | all(. as $pr
          | ($calmap[$pr[0]] // null) as $a | ($calmap[$pr[1]] // null) as $b
          | $a == null or $b == null
            or ([$a.kind, $a.provider, $a.model] != [$b.kind, $b.provider, $b.model])))
     then [] else ["JUDGE_ALIAS"] end) as $alias_codes
  | ([$alljudges[] | ($calmap[.] // null) | select(. != null) | [.kind, .provider, .model]] | unique) as $cfgs
  | (if ($cfgs | length) >= 2 then [] else ["JUDGE_DIVERSITY"] end) as $diversity_codes
  | ([$alljudges | unique | .[] | select(($calmap[.] // null) != null)] | length) as $eligible_judges
  | (($cfgs | length) > 0 and ([$cfgs[] | .[0]] | all(. == "human"))) as $all_human

  # -- aggregation ---------------------------------------------------------------
  | ([$BR[].wins] | add // 0) as $total_wins
  | ([$BR[].groups] | add // 0) as $total_groups
  | ([$BR[] | select(.won)] | length) as $brief_wins
  | ([$BR[] | select(.won | not) | .id] | sort) as $briefs_lost
  | (if $brief_wins >= 7 then [] else ["BRIEF_WIN_FLOOR"] end) as $winfloor_codes
  | (if $total_groups > 0 then [] else ["NO_RESOLVED_GROUPS"] end) as $groups_codes
  | (if $total_groups > 0 then (($total_wins / $total_groups) | r8) else 0 end) as $preference
  | (if $total_groups > 0 then (wilson($total_wins; $total_groups) | r8) else 0 end) as $wlb
  | (if $total_groups > 0 and $preference < 0.70 then ["PREFERENCE_FLOOR"] else [] end) as $pref_codes
  | (if $total_groups > 0 and $wlb <= 0.50 then ["WILSON_FLOOR"] else [] end) as $wilson_codes
  | ([$BR[].acc] | add // 0) as $acc_total

  # -- statistics aggregation cross-check ------------------------------------------
  | B("stats.in") as $sin
  | B("stats.rc") as $src
  | (reduce $BR[] as $b ({}; . + {($b.id): (if $b.won then "candidate" else "baseline" end)})) as $expected_votes
  | (if ($sin | type) != "object" or $sin.schema != "polylane.taste.ballots.v1"
        or (($sin | keys | sort) != ["ballots","schema"]) or (($sin.ballots? | type) != "array")
     then ["STATS_MISMATCH"]
     else (if ($sin.ballots | all(type == "object" and (keys | sort) == ["brief_id","vote"]))
              and (($sin.ballots | length) == $bn)
              and (([$sin.ballots[].brief_id] | sort) == ([$BR[].id] | sort))
              and ($sin.ballots | all(.vote == ($expected_votes[.brief_id] // "missing")))
           then [] else ["STATS_MISMATCH"] end)
     end) as $ballots_codes
  | (if ($src | type) != "object" then ["RECEIPT_SCHEMA"]
     elif ($src.schema == "polylane.taste.stats.v1"
          and $src.valid == true and $src.sample_unit == "brief"
          and ($src.input_sha256 | type == "string")
          and ([$src.brief_count, $src.candidate_wins, $src.baseline_wins, $src.ties,
                $src.preference_rate, $src.wilson_lower_bound] | all(type == "number")))
     then ((if $src.brief_count == $bn and $src.candidate_wins == $brief_wins
               and $src.baseline_wins == ($bn - $brief_wins) and $src.ties == 0
            then [] else ["STATS_MISMATCH"] end)
         # Statistics receipts bind the canonical (jq -cS) ballots document.
         + (if $src.input_sha256 == $stats_canon and ($stats_canon | length) == 64
            then [] else ["RECEIPT_BINDING"] end))
     else ["RECEIPT_SCHEMA"] end) as $stats_codes

  # -- fixture boundary, claim ladder, subject ancestry ------------------------------
  | (($m.fixture == true) or ([$BR[].fixture] | any)) as $fixture_out
  | (if $m.fixture == true then ["FIXTURE_EVIDENCE"] else [] end) as $fixture_codes
  | (if $all_human then "HUMAN_CERTIFIED" else "HUMAN_CALIBRATED_MACHINE" end) as $achieved
  | (if $m.required_claim == "HUMAN_CERTIFIED" and $achieved != "HUMAN_CERTIFIED"
     then ["CLAIM_NOT_MET"] else [] end) as $claim_codes
  | ((if $git.subject_valid then [] else ["SUBJECT_REVISION_INVALID"] end)
   + (if $git.subject_valid and ($git.ancestor | not) then ["SUBJECT_NOT_ANCESTOR"] else [] end)
   + (if $git.subject_valid and $git.ancestor and ($git.clean | not)
      then ["UNDECLARED_POST_EVIDENCE_COMMIT"] else [] end)) as $git_codes

  | (($transport + $pre + $git_codes + $escrow_codes + $ref_codes + $dir_codes + $corpus_codes
      + $threat_codes + $repair.codes + $caldup_codes + [$cals[].codes[]]
      + [$BR[].codes[]] + $quorum_codes + $variety_codes + $dup_codes + $indep_codes
      + $uncal_codes + $escrow_match_codes + $alias_codes + $diversity_codes
      + $winfloor_codes + $groups_codes + $pref_codes + $wilson_codes
      + $ballots_codes + $stats_codes + $fixture_codes + $claim_codes) | unique) as $reasons
  | ($reasons | length == 0) as $certified
  | {schema_version: "taste-certificate/v2",
     run_id: $m.run_id,
     protocol_version: $m.protocol_version,
     candidate_id: $m.candidate_id,
     subject_revision: $m.subject_revision,
     goal_sha256: $m.goal_sha256,
     design_lock_sha256: $m.design_lock_sha256,
     evidence_manifest_sha256: $msha,
     evidence_chain_sha256: $chain_e,
     validator_chain_sha256: $chain_v,
     status: (if $certified then "TASTE-CERTIFIED" else "NOT-CERTIFIED" end),
     required_claim: $m.required_claim,
     claim_label: (if $certified then $achieved else "NOT-CERTIFIED" end),
     fixture_only: $fixture_out,
     human_calibrated: $certified,
     human_certified: ($certified and $achieved == "HUMAN_CERTIFIED"),
     briefs: $bn,
     brief_wins: $brief_wins,
     briefs_lost: $briefs_lost,
     groups_per_brief: (reduce $BR[] as $b ({}; . + {($b.id): $b.groups})),
     eligible_judges: $eligible_judges,
     unique_judge_configurations: ($cfgs | length),
     preference_rate: $preference,
     wilson_lower_bound: $wlb,
     accessibility_regressions: $acc_total,
     repair_count: $repair.count,
     repair_ledger_sha256: S("repair.in"),
     external_limitations: ["panel identity, host integrity, and population coverage remain externally scoped",
                            "validator receipts prove hash-bound chain closure, not a live rendered benchmark"],
     verdict_reason_codes: $reasons}
'

write_v2_failure() {
  local codes=$1 tmp
  tmp=$(mktemp "${certificate}.tmp.XXXXXX") || return 1
  jq -n --arg msha "${manifest_sha_v2:-}" --argjson codes "$codes" '
    {schema_version: "taste-certificate/v2", run_id: "unknown", protocol_version: "taste-protocol/v1",
     candidate_id: "unknown", subject_revision: "", goal_sha256: "", design_lock_sha256: "",
     evidence_manifest_sha256: $msha, evidence_chain_sha256: "", validator_chain_sha256: "",
     status: "NOT-CERTIFIED", required_claim: "", claim_label: "NOT-CERTIFIED", fixture_only: true,
     human_calibrated: false, human_certified: false, briefs: 0, brief_wins: 0, briefs_lost: [],
     groups_per_brief: {}, eligible_judges: 0, unique_judge_configurations: 0,
     preference_rate: 0, wilson_lower_bound: 0, accessibility_regressions: 0, repair_count: 0,
     repair_ledger_sha256: "", external_limitations: ["manifest failed closed-schema validation"],
     verdict_reason_codes: ($codes | unique)}' >"$tmp" && mv -f "$tmp" "$certificate" || { rm -f "$tmp"; return 1; }
}

certify_v2() {
  local role path dsha line commit cfile prefix match head_rev subject declared stats_rel stats_canon
  local git_subject=false git_ancestor=false git_clean=false
  local pre_codes='' pre_json evidence_chain validator_chain tmp status spath ssha actual_shot
  manifest_sha_v2=$(sha256_file "$manifest")
  SCRATCH_V2=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-v2.XXXXXX") || exit 1

  if ! regular_json_without_duplicate_keys "$manifest" ||
     ! jq -e "$V2_MANIFEST_FILTER" "$manifest" >/dev/null 2>&1; then
    write_v2_failure '["MANIFEST_INVALID"]' || true
    exit 1
  fi

  jq -r "$V2_ROLES_FILTER" "$manifest" >"$SCRATCH_V2/roles.tsv"
  : >"$SCRATCH_V2/unsafe.list"
  : >"$SCRATCH_V2/files.list"
  while IFS=$'\t' read -r role path dsha; do
    : "$dsha"
    if v2_safe_path "$manifest_dir" "$path"; then
      printf '%s\n' "$path" >>"$SCRATCH_V2/files.list"
    else
      printf '%s\n' "$role" >>"$SCRATCH_V2/unsafe.list"
    fi
  done <"$SCRATCH_V2/roles.tsv"

  local files=()
  while IFS= read -r line; do files+=("$line"); done <"$SCRATCH_V2/files.list"
  : >"$SCRATCH_V2/actual.tsv"
  if [ "${#files[@]}" -gt 0 ]; then
    (cd "$manifest_dir" && shasum -a 256 -- "${files[@]}" 2>/dev/null) >"$SCRATCH_V2/actual.tsv" || true
  fi

  local present=()
  while IFS= read -r line; do present+=("$line"); done < <(awk '{print substr($0, 67)}' "$SCRATCH_V2/actual.tsv")
  local good=()
  : >"$SCRATCH_V2/bad.list"
  printf '{}\n' >"$SCRATCH_V2/loaded.json"
  if [ "${#present[@]}" -gt 0 ]; then
    if (cd "$manifest_dir" && jq -n 'reduce inputs as $v ({}; .[input_filename] = $v)' -- "${present[@]}" 2>/dev/null) >"$SCRATCH_V2/loaded.batch" 2>/dev/null; then
      mv "$SCRATCH_V2/loaded.batch" "$SCRATCH_V2/loaded.json"
      good=("${present[@]}")
    else
      for line in "${present[@]}"; do
        if (cd "$manifest_dir" && jq -e . "$line" >/dev/null 2>&1); then
          good+=("$line")
        else
          printf '%s\n' "$line" >>"$SCRATCH_V2/bad.list"
        fi
      done
      if [ "${#good[@]}" -gt 0 ]; then
        (cd "$manifest_dir" && jq -n 'reduce inputs as $v ({}; .[input_filename] = $v)' -- "${good[@]}") >"$SCRATCH_V2/loaded.json"
      fi
    fi
  fi

  : >"$SCRATCH_V2/dup.list"
  if [ "${#good[@]}" -gt 0 ]; then
    local sep; sep=$(printf '\037')
    (cd "$manifest_dir" && jq --stream -r 'select(length == 2) | [input_filename, (.[0] | map(tostring) | join("\u001f"))] | join("\u001f")' -- "${good[@]}" 2>/dev/null) |
      LC_ALL=C sort | uniq -d | awk -F "$sep" '{print $1}' | LC_ALL=C sort -u >"$SCRATCH_V2/dup.list" || true
  fi

  # Screenshots referenced by capture manifests are part of the closure: safe
  # relative regular files whose recomputed digest matches the declared one.
  jq -r '[.[] | select(type == "object" and .schema_version == "taste-capture-manifest/v1")
          | .captures[]? | select(type == "object")
          | [((.screenshot_path // "") | tostring), ((.screenshot_png_sha256 // "") | tostring)] | @tsv] | .[]' \
    "$SCRATCH_V2/loaded.json" >"$SCRATCH_V2/shots.tsv" 2>/dev/null || : >"$SCRATCH_V2/shots.tsv"
  while IFS=$'\t' read -r spath ssha; do
    [ -n "$spath" ] || { pre_codes="$pre_codes CAPTURE_INVALID"; continue; }
    if ! v2_safe_path "$manifest_dir" "$spath"; then pre_codes="$pre_codes UNSAFE_PATH"; continue; fi
    actual_shot=$(cd "$manifest_dir" && sha256_file "$spath")
    if [ -z "$actual_shot" ]; then pre_codes="$pre_codes RECEIPT_MISSING"
    elif [ "$actual_shot" != "$ssha" ]; then pre_codes="$pre_codes HASH_MISMATCH"; fi
  done <"$SCRATCH_V2/shots.tsv"

  subject=$(jq -r '.subject_revision' "$manifest")
  if [ -n "$subject_root" ] && [ -d "$subject_root" ] && [ ! -L "$subject_root" ] &&
     git -C "$subject_root" rev-parse --verify --quiet "${subject}^{commit}" >/dev/null 2>&1; then
    git_subject=true
    head_rev=$(git -C "$subject_root" rev-parse HEAD 2>/dev/null || printf '')
    if [ "$head_rev" = "$subject" ] ||
       git -C "$subject_root" merge-base --is-ancestor "$subject" "$head_rev" 2>/dev/null; then
      git_ancestor=true
      git_clean=true
      if [ -n "$(git -C "$subject_root" rev-list --merges "$subject..$head_rev" 2>/dev/null)" ]; then
        git_clean=false
      fi
      if [ "$git_clean" = true ]; then
        declared=$(jq -r '.declared_evidence_paths[]' "$manifest")
        while IFS= read -r commit; do
          [ -n "$commit" ] || continue
          while IFS= read -r cfile; do
            [ -n "$cfile" ] || continue
            match=false
            while IFS= read -r prefix; do
              [ -n "$prefix" ] || continue
              case "$cfile" in "$prefix"*) match=true; break;; esac
            done <<<"$declared"
            [ "$match" = true ] || git_clean=false
          done < <(git -C "$subject_root" diff-tree --no-commit-id --name-only -r "$commit" 2>/dev/null)
        done < <(git -C "$subject_root" rev-list --no-merges "$subject..$head_rev" 2>/dev/null)
      fi
    fi
  fi

  # shellcheck disable=SC2086 # pre_codes is a space-separated list of fixed enum tokens.
  pre_json=$(printf '%s\n' $pre_codes | sed '/^$/d' | jq -R . | jq -cs 'unique')
  # Statistics receipts bind the canonical (jq -cS, no trailing newline) ballots
  # document rather than the raw file bytes; recompute that digest here.
  stats_rel=$(jq -r '.stats.input.path' "$manifest")
  stats_canon=''
  if v2_safe_path "$manifest_dir" "$stats_rel" && [ -f "$manifest_dir/$stats_rel" ]; then
    stats_canon=$(printf '%s' "$(cd "$manifest_dir" && jq -cS . "$stats_rel" 2>/dev/null)" | sha256_stdin) || stats_canon=''
  fi
  evidence_chain=$(LC_ALL=C sort "$SCRATCH_V2/roles.tsv" | sha256_stdin)
  validator_chain=$(awk -F '\t' '$1 ~ /(\.rc|\.hard)$/' "$SCRATCH_V2/roles.tsv" | LC_ALL=C sort | sha256_stdin)

  jq -n --rawfile roles "$SCRATCH_V2/roles.tsv" --rawfile actual "$SCRATCH_V2/actual.tsv" \
     --rawfile unsafe "$SCRATCH_V2/unsafe.list" --rawfile bad "$SCRATCH_V2/bad.list" \
     --rawfile dup "$SCRATCH_V2/dup.list" --slurpfile loaded "$SCRATCH_V2/loaded.json" \
     "$V2_ART_FILTER" >"$SCRATCH_V2/art.json" || { write_v2_failure '["COMPILER_ERROR"]' || true; exit 1; }

  if ! jq -n --slurpfile A "$SCRATCH_V2/art.json" --slurpfile mm "$manifest" \
       --argjson git "{\"subject_valid\":$git_subject,\"ancestor\":$git_ancestor,\"clean\":$git_clean}" \
       --argjson pre "$pre_json" --arg stats_canon "$stats_canon" \
       --arg msha "$manifest_sha_v2" --arg chain_e "$evidence_chain" --arg chain_v "$validator_chain" \
       "$V2_CERT_FILTER" >"$SCRATCH_V2/cert.json" || ! jq -e . "$SCRATCH_V2/cert.json" >/dev/null 2>&1; then
    write_v2_failure '["COMPILER_ERROR"]' || true
    exit 1
  fi

  tmp=$(mktemp "${certificate}.tmp.XXXXXX") || exit 1
  cat "$SCRATCH_V2/cert.json" >"$tmp" && mv -f "$tmp" "$certificate" || { rm -f "$tmp"; exit 1; }
  status=$(jq -r '.status' "$certificate")
  [ "$status" = TASTE-CERTIFIED ] && exit 0 || exit 1
}

# --------------------------------------------------------------------------
# dispatch
# --------------------------------------------------------------------------
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ] || [ "$1" != certify ]; then usage; exit 64; fi
manifest=$2; certificate=$3; subject_root=${4:-}
manifest_dir=$(CDPATH='' cd -- "$(dirname -- "$manifest")" 2>/dev/null && pwd) || exit 64
manifest="$manifest_dir/$(basename -- "$manifest")"
manifest_schema=$(jq -r '.schema_version // ""' "$manifest" 2>/dev/null || printf '')

if [ "$manifest_schema" = taste-evidence-manifest/v2 ]; then
  [ "$#" -eq 4 ] || { usage; exit 64; }
  certify_v2
fi

# ----- v1 compatibility path (fixture-grade evidence only) -----------------
[ "$#" -eq 3 ] || { usage; exit 64; }
run_id=unknown; protocol_version=taste-protocol/v1; brief_count=0; brief_wins=0; preference=0; confidence=0; groups_per_brief='{}'; repair_sha=''
if ! regular_json_without_duplicate_keys "$manifest" || ! jq -e 'type == "object" and ([keys[]] | all(. == "schema_version" or . == "run_id" or . == "protocol_version" or . == "candidate_id" or . == "briefs" or . == "calibrations" or . == "threat_report" or . == "repair_ledger")) and .schema_version == "taste-evidence-manifest/v1" and (.run_id|type == "string" and length > 0) and .protocol_version == "taste-protocol/v1" and (.candidate_id|type == "string" and length > 0) and (.briefs|type == "array") and (.calibrations|type == "array") and (.threat_report|type == "string") and (.repair_ledger|type == "string")' "$manifest" >/dev/null 2>&1; then
  add_reason MANIFEST_INVALID; write_certificate NOT-CERTIFIED false false NOT-CERTIFIED || true; exit 1
fi
run_id=$(jq -r .run_id "$manifest"); protocol_version=$(jq -r .protocol_version "$manifest"); candidate_id=$(jq -r .candidate_id "$manifest"); brief_count=$(jq '.briefs|length' "$manifest")
[ "$brief_count" -ge 10 ] && [ "$brief_count" -le 100 ] || add_reason BRIEF_QUORUM
# shellcheck disable=SC2034 # seen_add accesses these Bash 3.2 scalar sets indirectly.
brief_ids=''; categories=''; tasks=''; revisions=''; pixels=''; judges=''; all_human=true; total_groups=0; total_wins=0; index=0
: "$brief_ids" "$categories" "$tasks" "$revisions" "$pixels" "$judges"
while [ "$index" -lt "$brief_count" ]; do
  brief=$(jq -c ".briefs[$index]" "$manifest")
  if ! jq -e 'type == "object" and (.groups|type == "array") and (.brief_lock|type == "string") and (.candidate|type == "string") and (.capture|type == "string") and (.hard_gate|type == "string") and (.review|type == "string")' >/dev/null <<<"$brief"; then add_reason BRIEF_INDEX_INVALID; index=$((index + 1)); continue; fi
  lock=$(safe_receipt "$(jq -r .brief_lock <<<"$brief")" taste-brief/v1) || { add_reason BRIEF_LOCK_INVALID; index=$((index + 1)); continue; }
  brief_id=$(jq -r '.brief_id // empty' <<<"$lock"); brief_sha=$(jq -r '.brief_sha256 // empty' <<<"$lock"); category=$(jq -r '.target_population.category // .target_population.role // empty' <<<"$lock"); task=$(jq -r '.core_task.id // empty' <<<"$lock")
  if [ -z "$brief_id" ] || ! is_sha "$brief_sha" || [ -z "$category" ] || [ -z "$task" ] || ! seen_add brief_ids "$brief_id" || ! seen_add categories "$category" || ! seen_add tasks "$task"; then add_reason BRIEF_VARIETY; fi
  candidate=$(safe_receipt "$(jq -r .candidate <<<"$brief")" taste-candidate/v1) || { add_reason CANDIDATE_INVALID; index=$((index + 1)); continue; }
  revision=$(jq -r '.source_revision // empty' <<<"$candidate")
  if [ "$(jq -r '.candidate_id // empty' <<<"$candidate")" != "$candidate_id" ] || [ "$(jq -r '.brief_sha256 // empty' <<<"$candidate")" != "$brief_sha" ] || ! is_revision "$revision" || ! seen_add revisions "$revision"; then add_reason CANDIDATE_PROVENANCE; fi
  capture=$(safe_receipt "$(jq -r .capture <<<"$brief")" taste-capture-manifest/v1) || { add_reason CAPTURE_INVALID; index=$((index + 1)); continue; }
  if [ "$(jq -r '.candidate_id // empty' <<<"$capture")" != "$candidate_id" ] || [ "$(jq -r '.candidate_source_revision // empty' <<<"$capture")" != "$revision" ] || ! jq -e '.captures|type == "array" and length > 0 and all(.[]; (.decoded_pixel_sha256|type == "string" and test("^[0-9a-f]{64}$")) and (.decoded_width|type == "number" and floor == . and . > 0) and (.decoded_height|type == "number" and floor == . and . > 0))' >/dev/null <<<"$capture"; then add_reason CAPTURE_INVALID; fi
  while IFS= read -r pixel; do seen_add pixels "$pixel" || add_reason DUPLICATE_RENDER; done < <(jq -r '.captures[].decoded_pixel_sha256' <<<"$capture" 2>/dev/null || true)
  hard=$(safe_receipt "$(jq -r .hard_gate <<<"$brief")" taste-hard-gate/v1) || { add_reason HARD_GATE_MISSING; index=$((index + 1)); continue; }
  if ! jq -e --arg c "$candidate_id" '.candidate_id == $c and .overall == "PASS" and (.task_results|type == "array" and length > 0 and all(.[]; .status == "pass")) and (.accessibility|type == "array" and length > 0 and all(.[]; .status == "pass")) and (.state_coverage|type == "array" and length > 0 and all(.[]; .status == "pass"))' >/dev/null <<<"$hard"; then add_reason FUNCTION_OR_ACCESSIBILITY_VETO; fi
  group_count=0; target_wins=0; group_index=0; group_total=$(jq '.groups|length' <<<"$brief")
  while [ "$group_index" -lt "$group_total" ]; do
    group=$(safe_receipt "$(jq -r ".groups[$group_index]" <<<"$brief")" taste-mirrored-group/v1) || { add_reason BALLOT_INVALID; group_index=$((group_index + 1)); continue; }
    if ! jq -e --arg sha "$brief_sha" '.brief_sha256 == $sha and (.exposures|type == "array" and length == 2) and ([.exposures[].display_order]|sort == ["A/B","B/A"]) and (.exposures[0].judge_id != .exposures[1].judge_id) and all(.exposures[]; (.judge_id|type == "string" and length > 0) and (.canonical_choice|type == "string" and length > 0) and (.independence_attestation_sha256|type == "string" and length > 0)) and (.exposures[0].canonical_choice == .exposures[1].canonical_choice) and (.outcome == ("resolved-" + .exposures[0].canonical_choice))' >/dev/null <<<"$group"; then add_reason BALLOT_INVALID; else
      winner=$(jq -r '.exposures[0].canonical_choice' <<<"$group"); group_count=$((group_count + 1)); total_groups=$((total_groups + 1)); [ "$winner" = "$candidate_id" ] && { target_wins=$((target_wins + 1)); total_wins=$((total_wins + 1)); }
      while IFS= read -r judge; do seen_add judges "$judge" || add_reason JUDGE_NOT_INDEPENDENT; done < <(jq -r '.exposures[].judge_id' <<<"$group")
    fi
    group_index=$((group_index + 1))
  done
  [ "$group_count" -ge 5 ] || add_reason BALLOT_QUORUM
  [ "$target_wins" -gt $((group_count - target_wins)) ] && brief_wins=$((brief_wins + 1)) || add_reason BRIEF_NOT_WON
  groups_per_brief=$(jq -c --arg id "$brief_id" --argjson count "$group_count" '. + {($id):$count}' <<<"$groups_per_brief")
  review=$(safe_receipt "$(jq -r .review <<<"$brief")" taste-cross-brief-review/v1) || add_reason CROSS_BRIEF_REVIEW
  if [ -n "${review:-}" ] && ! jq -e --arg id "$brief_id" '.brief_id == $id and .status == "resolved" and .determination == "clear"' >/dev/null <<<"$review"; then add_reason CROSS_BRIEF_REVIEW; fi
  index=$((index + 1))
done
[ "$brief_wins" -ge 7 ] || add_reason BRIEF_WIN_FLOOR
if [ "$total_groups" -gt 0 ]; then preference=$(awk -v w="$total_wins" -v n="$total_groups" 'BEGIN{printf "%.8f",w/n}'); confidence=$(awk -v w="$total_wins" -v n="$total_groups" 'BEGIN{z=1.959964;p=w/n;d=1+z*z/n;c=(p+z*z/(2*n))/d;m=z*sqrt((p*(1-p)+z*z/(4*n))/n)/d;printf "%.8f",c-m}'); else add_reason NO_RESOLVED_GROUPS; fi
awk -v p="$preference" 'BEGIN{exit !(p>=.70)}' || add_reason PREFERENCE_FLOOR
awk -v l="$confidence" 'BEGIN{exit !(l>.50)}' || add_reason WILSON_FLOOR

calibrated_judges=''; cal_index=0; cal_total=$(jq '.calibrations|length' "$manifest")
while [ "$cal_index" -lt "$cal_total" ]; do
  cal=$(safe_receipt "$(jq -r ".calibrations[$cal_index]" "$manifest")" taste-calibration/v1) || { add_reason CALIBRATION_INVALID; cal_index=$((cal_index + 1)); continue; }
  judge=$(jq -r '.judge_id // empty' <<<"$cal")
  if [ -z "$judge" ] || ! seen_add calibrated_judges "$judge" || ! jq -e --arg judge "$judge" '.result == "eligible" and .judge_id == $judge and .judge.id == $judge and .human_labelled_pairs >= 24 and .correct >= 17 and .wilson_lcb_95 >= .50 and .side_probe_n >= 12 and .side_probe_exact_binomial_p >= .05 and .mirror_probe_n >= 8 and .mirror_contradictions < 2 and (.judge_configuration.kind == "human" or .judge_configuration.kind == "machine")' >/dev/null <<<"$cal"; then add_reason CALIBRATION_INVALID; fi
  [ "$(jq -r '.judge_configuration.kind // empty' <<<"$cal")" = human ] || all_human=false
  cal_index=$((cal_index + 1))
done
OLDIFS=$IFS; IFS='|'; for judge in $judges; do case "|$calibrated_judges|" in *"|$judge|"*) ;; *) add_reason JUDGE_NOT_CALIBRATED;; esac; done; IFS=$OLDIFS
threat=$(safe_receipt "$(jq -r .threat_report "$manifest")" taste-threat-receipt/v1) || add_reason THREAT_GATE
if [ -n "${threat:-}" ] && ! jq -e '.status == "clean" and .axis_results.genericness_review == "pass" and .axis_results.quality_risk == "pass" and .axis_results.context_fit == "pass" and .axis_results.provenance_integrity == "pass" and .review.status == "not-required" and .review.attribution_claim == false and (.reason_codes | type == "array" and length == 0)' >/dev/null <<<"$threat"; then add_reason THREAT_GATE; fi
repair=$(safe_receipt "$(jq -r .repair_ledger "$manifest")" taste-repair-ledger/v1) || add_reason REPAIR_LEDGER
if [ -n "${repair:-}" ] && jq -e '.status == "valid" and (.sha256|type == "string" and length > 0)' >/dev/null <<<"$repair"; then repair_sha=$(jq -r .sha256 <<<"$repair"); else add_reason REPAIR_LEDGER; fi
if [ -n "$reasons" ]; then write_certificate NOT-CERTIFIED false false NOT-CERTIFIED || true; exit 1; fi
if [ "$all_human" = true ]; then write_certificate TASTE-CERTIFIED true true HUMAN_CERTIFIED; else write_certificate TASTE-CERTIFIED true false HUMAN_CALIBRATED_MACHINE; fi
