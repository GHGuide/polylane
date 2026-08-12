#!/usr/bin/env bash
# tests/test-taste-source-campaign-e2e.sh — hermetic end-to-end rehearsal of the
# source → split → calibration campaign chain, plus adversarial replays against
# the completed run (lane: source-adversary, run c41-source-calibration).
#
# The rehearsal drives the real chain end to end on deterministic fixtures:
#   1. content-addressed cache with three domains (8 calibration + 8 holdout
#      stimuli per domain) and a pinned acquisition plan;
#   2. bin/polylane-taste-source.sh verify-cache/build → manifest + receipt;
#   3. bin/polylane-taste-corpus.sh validate on the built manifest;
#   4. a 24-unit held-out mirrored calibration campaign whose unit images ARE
#      the cache objects selected as holdout by the manifest (real binding);
#   5. bin/polylane-taste-calibration-live.sh → eligible production receipt;
#   6. adversarial replays against the finished campaign: split leakage,
#      post-result replacement, receipt replay, answer-key rewrite, fixture
#      demotion, human-certification escalation.
#
# No network, no providers. Missing Cycle-41 sibling stages are recorded as
# SEAM-OPEN (never faked); POLYLANE_ADVERSARY_REQUIRE_SEAMS_CLOSED=1 makes any
# open seam fatal for the integrator.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
SRC="$ROOT/bin/polylane-taste-source.sh"
CORPUS="$ROOT/bin/polylane-taste-corpus.sh"
CAL="$ROOT/bin/polylane-taste-calibration-live.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-e2e.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
ASSERTIONS=0
SEAMS=0

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required" >&2; exit 1; }
for t in "$SRC" "$CORPUS" "$CAL"; do
  [ -x "$t" ] || { echo "FAIL missing tool $t" >&2; exit 1; }
done

fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }
ok() { ASSERTIONS=$((ASSERTIONS + 1)); }
h()  { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }
hf() { shasum -a 256 "$1" | awk '{print $1}'; }
rep64() { printf '%*s' 64 '' | tr ' ' "$1"; }

seam() { # NAME DESCRIPTION GLOB...
  name=$1; desc=$2; shift 2
  found=""
  for pat in "$@"; do
    # shellcheck disable=SC2086
    for f in $pat; do [ -e "$f" ] && found="$f" && break; done
    [ -n "$found" ] && break
  done
  SEAMS=$((SEAMS + 1))
  if [ -n "$found" ]; then
    printf 'SEAM-CANDIDATE-PRESENT %s: %s — candidate %s exists; integrator must wire the recorded stage\n' "$name" "$desc" "$found"
  else
    printf 'SEAM-OPEN %s: %s\n' "$name" "$desc"
  fi
}

# ===========================================================================
# Stage 1 — content-addressed cache + pinned plan (3 domains × 10 stimuli)
# ===========================================================================
CACHE="$TMP/cache"
mkdir -p "$CACHE/objects" "$TMP/campaign"

mk_obj() {
  printf '%s' "$1" >"$TMP/blob"
  s=$(hf "$TMP/blob")
  d="$CACHE/objects/${s:0:2}"; mkdir -p "$d"; cp "$TMP/blob" "$d/$s"
  printf '%s' "$s"
}

SRC_ID="miniukovich-e2e"
PID="doi:10.7910/DVN/9FKSQI"
VER="4.0"
DS_URL="https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/9FKSQI"
LIC_URL="https://creativecommons.org/publicdomain/zero/1.0/legalcode"
LIC_SHA=$(h 'CC0-1.0 legalcode')
# NOTE (interface mismatch, recorded for the integrator): the frozen Cycle-41
# split is 60 calibration / 24 holdout per domain, but the cycle-40
# polylane-taste-corpus.sh validator requires calibration == holdout per
# domain. The rehearsal uses a balanced 8/8 split so both frozen validators can
# run; the corpus-select lane must reconcile the unbalanced production quota
# (see SEAM corpus-select-unbalanced-quota below and the verify doc).
CAL_PER_DOMAIN=8
HOLD_PER_DOMAIN=8

AGG='{}'; RAW='{}'
: >"$TMP/images.tsv"
for dom in consumer collaboration operations; do
  case "$dom" in
    consumer) pre=cons ;; collaboration) pre=coll ;; operations) pre=ops ;;
  esac
  for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do
    stim="$pre-$n"
    rating=$(( (n % 5) + 1 ))   # 1..5, deterministic
    AGG=$(printf '%s' "$AGG" | jq --arg s "$stim" --arg d "$dom" --argjson r "$rating" \
      '. + {($s): {domain:$d, mean_rating:$r}}')
    RAW=$(printf '%s' "$RAW" | jq --arg s "$stim" --argjson r "$rating" \
      '. + {($s): [$r,$r,$r,$r,$r]}')
    isha=$(mk_obj "e2e-image-bytes-$stim")
    printf '%s\t%s\n' "$stim" "$isha" >>"$TMP/images.tsv"
  done
done
AGG_SHA=$(mk_obj "$AGG")
RAW_SHA=$(mk_obj "$RAW")
META_SHA=$(mk_obj "{\"pid\":\"$PID\",\"version\":\"$VER\",\"license\":\"CC0-1.0\"}")
IMAGES=$(jq -Rn --arg src "$SRC_ID" '[inputs|split("\t")|{stimulus_id:.[0],source_id:$src,sha256:.[1]}]' "$TMP/images.tsv")

PLAN="$TMP/plan.json"
jq -n \
  --arg src "$SRC_ID" --arg pid "$PID" --arg ver "$VER" --arg dsurl "$DS_URL" \
  --arg licurl "$LIC_URL" --arg licsha "$LIC_SHA" \
  --arg meta "$META_SHA" --arg agg "$AGG_SHA" --arg raw "$RAW_SHA" \
  --argjson cal "$CAL_PER_DOMAIN" --argjson hold "$HOLD_PER_DOMAIN" \
  --argjson images "$IMAGES" '
  {
    plan_version:"taste-source-plan/v1",
    classification:"fixture",
    reproduction:"bash tests/test-taste-source-campaign-e2e.sh",
    split:{seed:"c41-e2e-seed", calibration_per_domain:$cal, holdout_per_domain:$hold},
    domains:["consumer","collaboration","operations"],
    sources:[{
      id:$src, dataset_pid:$pid, dataset_version:$ver, url:$dsurl,
      license:{spdx:"CC0-1.0", url:$licurl, sha256:$licsha},
      metadata:{sha256:$meta}, aggregate:{sha256:$agg}, raw:{sha256:$raw}
    }],
    images:$images
  }' >"$PLAN"

# ===========================================================================
# Stage 2 — acquisition build: verify, manifest, receipt, corpus validation
# ===========================================================================
MANIFEST="$TMP/manifest.json"
RECEIPT="$TMP/receipt.json"
"$SRC" verify-cache "$CACHE" "$PLAN" >/dev/null || fail "stage2: verify-cache"
ok
"$SRC" build "$CACHE" "$PLAN" "$MANIFEST" "$RECEIPT" >/dev/null || fail "stage2: build"
ok
"$CORPUS" validate "$MANIFEST" >/dev/null || fail "stage2: corpus validate"
ok

[ "$(jq -r '.records|length' "$MANIFEST")" = 48 ] || fail "stage2: 48 records expected"
[ "$(jq -r '[.records[]|select(.split=="holdout")]|length' "$MANIFEST")" = 24 ] || fail "stage2: 24 holdout"
[ "$(jq -r '[.records[]|select(.split=="calibration")]|length' "$MANIFEST")" = 24 ] || fail "stage2: 24 calibration"
ok
jq -e '
  ([.records[]|select(.split=="calibration")|.asset_sha256]) as $c
  | ([.records[]|select(.split=="holdout")|.asset_sha256]) as $h
  | (($c - ($c - $h)) == []) and (($c+$h|length) == ($c+$h|unique|length))
' "$MANIFEST" >/dev/null || fail "stage2: split not disjoint by digest"
ok
MANIFEST_SHA=$(hf "$MANIFEST")
[ "$(jq -r '.manifest_sha256' "$RECEIPT")" = "$MANIFEST_SHA" ] || fail "stage2: receipt binds manifest sha"
[ "$(jq -r '.classification' "$RECEIPT")" = fixture ] || fail "stage2: rehearsal receipt stays fixture-classified"
ok

# Determinism: a rebuild of the same frozen inputs is byte-identical.
"$SRC" build "$CACHE" "$PLAN" "$TMP/manifest2.json" >/dev/null
[ "$(hf "$TMP/manifest2.json")" = "$MANIFEST_SHA" ] || fail "stage2: rebuild must be byte-identical"
ok

# ===========================================================================
# Stage 3 — campaign fixture: 24 held-out units whose images ARE the cache
# objects the manifest selected as holdout; labels bound to the manifest sha.
# ===========================================================================
PARSER_SHA=$("$CAL" parser-sha)
SP=$(rep64 1); SAMP=$(rep64 2); ADAPTER=$(rep64 4)
PROV=e2e-provider; MODEL=e2e-model; MV=2026.08
CORP_SHA=$(hf "$RECEIPT")   # holdout corpus receipt: the stage-2 receipt
TUNE_SHA=$(hf "$PLAN")      # tuning corpus receipt: distinct real artifact
CORRECT=20
tok() { case "$1" in 1) printf FIRST;; 2) printf SECOND;; esac; }

jq -r '[.records[]|select(.split=="holdout")]|sort_by(.id)[]|[.id,.asset_sha256]|@tsv' "$MANIFEST" >"$TMP/holdout.tsv"
[ "$(wc -l <"$TMP/holdout.tsv" | tr -d ' ')" = 24 ] || fail "stage3: holdout extraction"
ok
jq -r '[.records[]|select(.split=="calibration")]|sort_by(.id)[]|.asset_sha256' "$MANIFEST" >"$TMP/caldigests.txt"

units_arr='[]'; labels_arr='[]'
i=0
while IFS=$(printf '\t') read -r rid asha; do
  A="stim-e2e-${i}a"; B="stim-e2e-${i}b"
  gold_pos=$(( i % 2 == 0 ? 1 : 2 ))
  if [ "$i" -lt "$CORRECT" ]; then ppos=$gold_pos; mpos=$((3 - gold_pos)); else ppos=$((3 - gold_pos)); mpos=$gold_pos; fi
  if [ "$gold_pos" -eq 1 ]; then o0=$A; o1=$B; else o0=$B; o1=$A; fi
  praw="E2E unit $i ($rid) primary."$'\n'"FINAL: $(tok "$ppos")"
  mraw="E2E unit $i ($rid) mirror."$'\n'"FINAL: $(tok "$mpos")"
  ppath="campaign/resp-$i-primary.txt"; mpath="campaign/resp-$i-mirror.txt"
  printf '%s' "$praw" >"$TMP/$ppath"; printf '%s' "$mraw" >"$TMP/$mpath"
  psha=$(hf "$TMP/$ppath"); msha=$(hf "$TMP/$mpath")
  ipath="cache/objects/${asha:0:2}/$asha"
  [ -f "$TMP/$ipath" ] || fail "stage3: holdout image object missing for $rid"
  units_arr=$(jq -n --argjson acc "$units_arr" \
    --arg uid "unit-$rid" --arg prompt "prompt-$rid" --arg brief "brief-$rid" \
    --arg imgsha "$asha" --arg imgpath "$ipath" \
    --arg o0 "$o0" --arg o1 "$o1" \
    --arg psha "$psha" --arg ppath "$ppath" --arg msha "$msha" --arg mpath "$mpath" \
    --arg prov "$PROV" --arg model "$MODEL" --arg mv "$MV" --arg sp "$SP" \
    --arg samp "$SAMP" --arg parser "$PARSER_SHA" --arg adapter "$ADAPTER" '
    def inv: {provider:$prov, model:$model, model_version:$mv, system_prompt_sha256:$sp, sampling_sha256:$samp, parser_sha256:$parser, adapter_sha256:$adapter};
    $acc + [ {
      unit_id:$uid, prompt:$prompt, brief:$brief,
      image:{path:$imgpath, sha256:$imgsha},
      primary:{orientation:[$o0,$o1], raw_response:{path:$ppath, sha256:$psha}, invocation:inv,
               identity_visible:false, prior_ballots_visible:false, injection_detected:false, judge_discussion:false},
      mirror:{orientation:[$o1,$o0], raw_response:{path:$mpath, sha256:$msha}, invocation:inv,
              identity_visible:false, prior_ballots_visible:false, injection_detected:false, judge_discussion:false}
    } ]')
  labels_arr=$(jq -n --argjson acc "$labels_arr" --arg uid "unit-$rid" --arg imgsha "$asha" --arg A "$A" --arg B "$B" '
    $acc + [ {unit_id:$uid, image_sha256:$imgsha, stimulus_ids:[$A,$B], correct_stimulus:$A} ]')
  i=$((i + 1))
done <"$TMP/holdout.tsv"

TUNING_SHAS=$(jq -Rn '[inputs|select(length>0)]' "$TMP/caldigests.txt")
jq -n --argjson labels "$labels_arr" --argjson tuning "$TUNING_SHAS" --arg src "$MANIFEST_SHA" '
  {schema_version:"taste-holdout-labels/v1", dataset_id:"e2e-holdout-v1", partition:"held_out",
   source_snapshot_sha256:$src, tuning_image_shas:$tuning, labels:$labels}' >"$TMP/campaign/labels.json"
LABELS_SHA=$(hf "$TMP/campaign/labels.json")

INPUT="$TMP/input.json"
jq -n --argjson units "$units_arr" --arg labels_sha "$LABELS_SHA" \
  --arg prov "$PROV" --arg model "$MODEL" --arg mv "$MV" --arg sp "$SP" --arg samp "$SAMP" \
  --arg parser "$PARSER_SHA" --arg adapter "$ADAPTER" --arg src "$MANIFEST_SHA" \
  --arg corpus "$CORP_SHA" --arg tuning "$TUNE_SHA" '
  {schema_version:2,
   calibration:{dataset_id:"e2e-holdout-v1", partition:"held_out", label_provenance:"human-labeled",
                holdout_corpus_receipt_sha256:$corpus, tuning_corpus_receipt_sha256:$tuning,
                holdout_labels:{path:"campaign/labels.json", sha256:$labels_sha}},
   freeze:{provider:$prov, model:$model, model_version:$mv, system_prompt_sha256:$sp, sampling_sha256:$samp,
           response_parser_sha256:$parser, invocation_adapter_sha256:$adapter, source_snapshot_sha256:$src,
           image_orientation_frozen:true},
   judge:{id:"judge-e2e-001", provider:$prov, model:$model, model_version:$mv, system_prompt_sha256:$sp, sampling_sha256:$samp},
   units:$units}' >"$INPUT"

# ===========================================================================
# Stage 4 — calibration verdict: eligible, production, machine-only claim
# ===========================================================================
OUT="$TMP/out.json"
"$CAL" "$INPUT" "$OUT" "$TMP" >/dev/null || fail "stage4: expected eligible production receipt"
ok
jq -e '
  .eligible == true and .classification == "production" and .production == true
  and .fixture_only == false and .bound_response_units == true
  and .human_certified == false and .machine_not_human == true
  and .machine_panel_claim == "HUMAN_CALIBRATED_MACHINE"
  and .sample_units == 24 and .correct_units == 20
  and (.wilson_lower_bound >= 0.5)
  and .mirror_contradictions == 0
' "$OUT" >/dev/null || fail "stage4: receipt invariants: $(jq -c '{eligible,classification,production,sample_units,correct_units,wilson_lower_bound}' "$OUT")"
ok
[ "$(jq -r '.source_snapshot_sha256' "$OUT")" = "$MANIFEST_SHA" ] || fail "stage4: receipt binds the stage-2 manifest sha"
[ "$(jq -r '.holdout_labels_sha256' "$OUT")" = "$LABELS_SHA" ] || fail "stage4: receipt binds the labels digest"
[ "$(jq -r '.input_sha256' "$OUT")" = "$(hf "$INPUT")" ] || fail "stage4: receipt binds the campaign input digest"
[ "$(jq -r '.corpus_holdout_receipt_sha256' "$OUT")" = "$CORP_SHA" ] || fail "stage4: receipt binds the stage-2 acquisition receipt"
ok

# ===========================================================================
# Stage 5 — adversarial replays against the completed campaign
# ===========================================================================
replay() { # name jq-mutation-on-input expected-code
  local name=$1 prog=$2 code=$3 d
  d="$TMP/replay-$name"
  mkdir -p "$d"
  jq "$prog" "$INPUT" >"$d/input.json"
  if "$CAL" "$d/input.json" "$d/out.json" "$TMP" >/dev/null 2>&1; then
    fail "replay $name: attack was accepted"
  fi
  jq -e --arg c "$code" '.eligible == false and (.reason_codes | index($c) != null)' "$d/out.json" >/dev/null \
    || fail "replay $name: expected $code, got $(jq -c '.reason_codes' "$d/out.json")"
  ok
}

# 5a split leakage: a CALIBRATION image smuggled into the held-out campaign.
CAL_ASSET=$(head -1 "$TMP/caldigests.txt")
CAL_PATH="cache/objects/${CAL_ASSET:0:2}/$CAL_ASSET"
D="$TMP/replay-leak"; mkdir -p "$D/campaign"
jq --arg p "$CAL_PATH" --arg s "$CAL_ASSET" \
  '.labels[0].image_sha256 = $s' "$TMP/campaign/labels.json" >"$D/campaign/labels.json"
LEAK_LABELS_SHA=$(hf "$D/campaign/labels.json")
jq --arg p "$CAL_PATH" --arg s "$CAL_ASSET" --arg ls "$LEAK_LABELS_SHA" '
  .units[0].image = {path:$p, sha256:$s}
  | .calibration.holdout_labels = {path:"replay-leak/campaign/labels.json", sha256:$ls}
' "$INPUT" >"$D/input.json"
if "$CAL" "$D/input.json" "$D/out.json" "$TMP" >/dev/null 2>&1; then
  fail "replay split-leakage: calibration image accepted in holdout campaign"
fi
jq -e '.reason_codes | index("TUNING_HOLDOUT_OVERLAP") != null' "$D/out.json" >/dev/null \
  || fail "replay split-leakage: expected TUNING_HOLDOUT_OVERLAP, got $(jq -c '.reason_codes' "$D/out.json")"
ok

# 5b post-result replacement: source bytes swapped after the verdict. Both the
# acquisition layer and the calibration layer must notice.
UNIT0_SHA=$(jq -r '.units[0].image.sha256' "$INPUT")
OBJ="$CACHE/objects/${UNIT0_SHA:0:2}/$UNIT0_SHA"
cp "$OBJ" "$TMP/obj.bak"
printf 'replaced-after-results' >"$OBJ"
if "$SRC" verify-cache "$CACHE" "$PLAN" >/dev/null 2>&1; then
  fail "replay post-result: acquisition layer accepted replaced bytes"
fi
ok
D="$TMP/replay-postresult"; mkdir -p "$D"
cp "$INPUT" "$D/input.json"
if "$CAL" "$D/input.json" "$D/out.json" "$TMP" >/dev/null 2>&1; then
  fail "replay post-result: calibration layer accepted replaced bytes"
fi
jq -e '.reason_codes | index("IMAGE_BINDING") != null' "$D/out.json" >/dev/null \
  || fail "replay post-result: expected IMAGE_BINDING, got $(jq -c '.reason_codes' "$D/out.json")"
ok
cp "$TMP/obj.bak" "$OBJ"

# 5c receipt replay: the frozen receipt binds the exact input digest; any
# post-hoc change to the campaign input is distinguishable from the original.
D="$TMP/replay-input"; mkdir -p "$D"
jq '.judge.id = "judge-e2e-002"' "$INPUT" >"$D/input.json"
"$CAL" "$D/input.json" "$D/out.json" "$TMP" >/dev/null || fail "replay receipt: variant run failed"
[ "$(jq -r '.input_sha256' "$D/out.json")" != "$(jq -r '.input_sha256' "$OUT")" ] \
  || fail "replay receipt: distinct inputs must yield distinct bound digests"
ok

# 5d answer-key rewrite: a re-bound adversarial answer key flips every gold
# label; the judge's real answers no longer match and the labels digest visibly
# departs from the one the frozen receipt bound.
D="$TMP/replay-anskey"; mkdir -p "$D/campaign"
jq '.labels |= map(.correct_stimulus = .stimulus_ids[1])' "$TMP/campaign/labels.json" >"$D/campaign/labels.json"
FLIP_SHA=$(hf "$D/campaign/labels.json")
jq --arg ls "$FLIP_SHA" '.calibration.holdout_labels = {path:"replay-anskey/campaign/labels.json", sha256:$ls}' \
  "$INPUT" >"$D/input.json"
if "$CAL" "$D/input.json" "$D/out.json" "$TMP" >/dev/null 2>&1; then
  fail "replay answer-key: flipped key still eligible"
fi
jq -e '.reason_codes | index("ACCURACY_FLOOR") != null' "$D/out.json" >/dev/null \
  || fail "replay answer-key: expected ACCURACY_FLOOR, got $(jq -c '.reason_codes' "$D/out.json")"
[ "$FLIP_SHA" != "$LABELS_SHA" ] || fail "replay answer-key: rewritten key must change the bound digest"
ok

# 5e fixture demotion: any inline response inside the production campaign
# demotes the receipt; production cannot be reclaimed with pasted transcripts.
D="$TMP/replay-inline"; mkdir -p "$D"
P0RAW=$(cat "$TMP/campaign/resp-0-primary.txt")
P0SHA=$(hf "$TMP/campaign/resp-0-primary.txt")
jq --arg r "$P0RAW" --arg s "$P0SHA" '.units[0].primary.raw_response = {inline:$r, sha256:$s}' \
  "$INPUT" >"$D/input.json"
"$CAL" "$D/input.json" "$D/out.json" "$TMP" >/dev/null || fail "replay fixture: inline variant should stay eligible"
jq -e '.classification == "fixture_only" and .production == false and .fixture_only == true' "$D/out.json" >/dev/null \
  || fail "replay fixture: inline response must demote production"
ok

# 5f human-certification escalation: declared certification is schema-rejected,
# and no receipt produced anywhere in this rehearsal ever carries it.
replay human-cert '.judge.human_certified = true' SCHEMA_REJECTED
for out in "$OUT" "$TMP"/replay-*/out.json; do
  [ -f "$out" ] || continue
  jq -e '.human_certified == false and .machine_panel_claim == "HUMAN_CALIBRATED_MACHINE"' "$out" >/dev/null \
    || fail "human-certification escalated in $out"
done
ok

# ===========================================================================
# Stage 6 — seams: rehearsal stages owned by absent Cycle-41 siblings
# ===========================================================================
seam corpus-select-unbalanced-quota \
  "the frozen production split is 60 calibration / 24 holdout per domain, but bin/polylane-taste-corpus.sh validate requires calibration == holdout per domain and rejects it; the corpus-select lane must reconcile the unbalanced quota with (or replace) that validator before the real 180+72 corpus can pass" \
  "$ROOT/bin/polylane-taste-select*.sh" "$ROOT/bin/polylane-taste-corpus-select*.sh"

seam dataverse-transport-rehearsal \
  "the rehearsal starts from a populated cache; the CDP/ephemeral-session transport (readiness poll, redirected data-file download, no personal profile) has no local interface to rehearse" \
  "$ROOT/bin/polylane-taste-transport*.sh" "$ROOT/benchmarks/taste-live/tools/dataverse-transport*.mjs"

seam ratings-normalize-schema \
  "fixtures use the cycle-40 normalized aggregate/raw shape; the ratings-normalize lane must parse the actual raw/aggregate source schemas without lossy guessing before this rehearsal binds real labels" \
  "$ROOT/bin/polylane-taste-ratings*.sh"

seam calibration-audit-recompute \
  "the independent recompute of correctness, Wilson, side-bias, mirror contradictions, and configuration identity over the campaign ledger has no local interface; owned by the calibration-audit lane" \
  "$ROOT/bin/polylane-taste-calibration-audit*.sh" "$ROOT/bin/polylane-taste-audit*.sh"

seam panel-freeze-claim-ceiling \
  "the frozen machine-panel configuration and claim ceiling (no fabricated model versions or human provenance) has no local interface; owned by the panel-freeze lane" \
  "$ROOT/bin/polylane-taste-panel*.sh"

if [ "${POLYLANE_ADVERSARY_REQUIRE_SEAMS_CLOSED:-0}" = 1 ] && [ "$SEAMS" -gt 0 ]; then
  echo "FAIL seams must be closed in integrator mode (open=$SEAMS)" >&2
  exit 1
fi

echo "PASS test-taste-source-campaign-e2e assertions=$ASSERTIONS seams=$SEAMS"
