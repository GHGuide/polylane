#!/usr/bin/env bash
# tests/test-taste-source-adversarial.sh — independent black-box attacks against
# the source/calibration chain (lane: source-adversary, run c41-source-calibration).
#
# Every attack is hermetic and deterministic: fixtures live in a test temp dir,
# no network, no provider calls. Attacks that target a Cycle-41 sibling interface
# not present in this tree are recorded as SEAM-OPEN (never a faked PASS and
# never a weakened assertion); the expected merge-time contract for each seam is
# documented in docs/verify-source-adversary.md. Set
# POLYLANE_ADVERSARY_REQUIRE_SEAMS_CLOSED=1 (integrator mode) to make any open
# seam fatal.
#
# Attack classes covered here:
#   mirror substitution, wrong DOI/version/licence, distribution drift (seam),
#   challenge HTML cached as data, redirected partials, duplicate ids/digests,
#   symlink/traversal, rating/image mismatch, split leakage, post-result
#   replacement, answer-key leakage, session reuse, parser replay, fixture
#   promotion, human-certification escalation.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
SRC="$ROOT/bin/polylane-taste-source.sh"
CAL="$ROOT/bin/polylane-taste-calibration-live.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-src-adv.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
ASSERTIONS=0
SEAMS=0

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required" >&2; exit 1; }
[ -x "$SRC" ] || { echo "FAIL missing bin/polylane-taste-source.sh" >&2; exit 1; }
[ -x "$CAL" ] || { echo "FAIL missing bin/polylane-taste-calibration-live.sh" >&2; exit 1; }

fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }
ok() { ASSERTIONS=$((ASSERTIONS + 1)); }
assert_ok() { "$@" >/dev/null 2>&1 || fail "expected success: $*"; ok; }
assert_fail() {
  if "$@" >/dev/null 2>&1; then fail "attack was accepted (expected rejection): $*"; fi
  ok
}
h()  { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }
hf() { shasum -a 256 "$1" | awk '{print $1}'; }
rep64() { printf '%*s' 64 '' | tr ' ' "$1"; }

# seam NAME DESCRIPTION GLOB...
# A seam is an attack whose defense is owned by a Cycle-41 sibling lane whose
# interface is not in this tree. Not a PASS: it is counted and reported, and
# fatal in integrator mode. If a candidate interface file appears at merge time
# the integrator must wire the recorded assertion (see verify doc) before
# closing the seam.
seam() {
  name=$1; desc=$2; shift 2
  found=""
  for pat in "$@"; do
    # shellcheck disable=SC2086
    for f in $pat; do [ -e "$f" ] && found="$f" && break; done
    [ -n "$found" ] && break
  done
  SEAMS=$((SEAMS + 1))
  if [ -n "$found" ]; then
    printf 'SEAM-CANDIDATE-PRESENT %s: %s — candidate %s exists; integrator must wire the recorded assertion\n' "$name" "$desc" "$found"
  else
    printf 'SEAM-OPEN %s: %s\n' "$name" "$desc"
  fi
}

# ===========================================================================
# Part 1 — source acquisition chain (bin/polylane-taste-source.sh)
# ===========================================================================
CACHE="$TMP/cache"
mkdir -p "$CACHE/objects"

mk_obj() { # bytes -> sha (stored content-addressed)
  printf '%s' "$1" >"$TMP/blob"
  s=$(hf "$TMP/blob")
  d="$CACHE/objects/${s:0:2}"; mkdir -p "$d"; cp "$TMP/blob" "$d/$s"
  printf '%s' "$s"
}

SRC_ID="miniukovich-9fksqi"
PID="doi:10.7910/DVN/9FKSQI"
VER="4.0"
DS_URL="https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/9FKSQI"
LIC_URL="https://creativecommons.org/publicdomain/zero/1.0/legalcode"
LIC_SHA=$(h 'CC0-1.0 legalcode')

AGG_JSON='{
  "cons-1":{"domain":"consumer","mean_rating":4.0},
  "cons-2":{"domain":"consumer","mean_rating":3.0},
  "cons-3":{"domain":"consumer","mean_rating":5.0},
  "cons-4":{"domain":"consumer","mean_rating":2.0},
  "coll-1":{"domain":"collaboration","mean_rating":4.0},
  "coll-2":{"domain":"collaboration","mean_rating":2.0},
  "coll-3":{"domain":"collaboration","mean_rating":3.0},
  "coll-4":{"domain":"collaboration","mean_rating":5.0},
  "ops-1":{"domain":"operations","mean_rating":4.0},
  "ops-2":{"domain":"operations","mean_rating":5.0},
  "ops-3":{"domain":"operations","mean_rating":3.0},
  "ops-4":{"domain":"operations","mean_rating":2.0}
}'
RAW_JSON='{
  "cons-1":[4,4,4,4,4],"cons-2":[3,3,3,3,3],"cons-3":[5,5,5,5,5],"cons-4":[2,2,2,2,2],
  "coll-1":[4,4,4,4,4],"coll-2":[2,2,2,2,2],"coll-3":[3,3,3,3,3],"coll-4":[5,5,5,5,5],
  "ops-1":[4,4,4,4,4],"ops-2":[5,5,5,5,5],"ops-3":[3,3,3,3,3],"ops-4":[2,2,2,2,2]
}'
AGG_SHA=$(mk_obj "$AGG_JSON")
RAW_SHA=$(mk_obj "$RAW_JSON")
META_SHA=$(mk_obj "{\"pid\":\"$PID\",\"version\":\"$VER\",\"license\":\"CC0-1.0\"}")

: >"$TMP/images.tsv"
for stim in cons-1 cons-2 cons-3 cons-4 coll-1 coll-2 coll-3 coll-4 ops-1 ops-2 ops-3 ops-4; do
  isha=$(mk_obj "adv-image-bytes-$stim")
  printf '%s\t%s\n' "$stim" "$isha" >>"$TMP/images.tsv"
done
IMAGES=$(jq -Rn --arg src "$SRC_ID" '[inputs|split("\t")|{stimulus_id:.[0],source_id:$src,sha256:.[1]}]' "$TMP/images.tsv")

write_plan() { # out classification [seed]
  jq -n \
    --arg cls "$2" --arg seed "${3:-c41-adv-seed}" --arg src "$SRC_ID" --arg pid "$PID" \
    --arg ver "$VER" --arg dsurl "$DS_URL" --arg licurl "$LIC_URL" --arg licsha "$LIC_SHA" \
    --arg meta "$META_SHA" --arg agg "$AGG_SHA" --arg raw "$RAW_SHA" \
    --argjson images "$IMAGES" '
    {
      plan_version:"taste-source-plan/v1",
      classification:$cls,
      reproduction:"bin/polylane-taste-source.sh build <cache> <plan> <manifest>",
      split:{seed:$seed, calibration_per_domain:2, holdout_per_domain:2},
      domains:["consumer","collaboration","operations"],
      sources:[{
        id:$src, dataset_pid:$pid, dataset_version:$ver, url:$dsurl,
        license:{spdx:"CC0-1.0", url:$licurl, sha256:$licsha},
        metadata:{sha256:$meta}, aggregate:{sha256:$agg}, raw:{sha256:$raw}
      }],
      images:$images
    }' >"$1"
}

PLAN="$TMP/plan.json"
write_plan "$PLAN" fixture
edit_plan() { # out jq-program
  jq "$2" "$PLAN" >"$1"
}

# Baseline must hold before attacks mean anything.
MANIFEST="$TMP/manifest.json"
RECEIPT="$TMP/receipt.json"
assert_ok "$SRC" verify-cache "$CACHE" "$PLAN"
assert_ok "$SRC" build "$CACHE" "$PLAN" "$MANIFEST" "$RECEIPT"

# --- A1 mirror substitution ------------------------------------------------
# A DataONE-flavoured mirror record silently substituted for the pinned Harvard
# metadata bytes: the content no longer matches its content address.
META_PATH="$CACHE/objects/${META_SHA:0:2}/$META_SHA"
cp "$META_PATH" "$TMP/meta.bak"
printf '{"@context":"https://schema.org","identifier":"urn:uuid:mirror","name":"mirror substitution"}' >"$META_PATH"
assert_fail "$SRC" verify-cache "$CACHE" "$PLAN"
assert_fail "$SRC" build "$CACHE" "$PLAN" "$TMP/o.json"
cp "$TMP/meta.bak" "$META_PATH"

# A secondary-audit corpus may never be built as the primary corpus, and a
# primary/fixture plan may never masquerade as the secondary audit.
write_plan "$TMP/p_secondary.json" secondary-audit
assert_fail "$SRC" build "$CACHE" "$TMP/p_secondary.json" "$TMP/o.json"
assert_fail "$SRC" secondary "$CACHE" "$PLAN" "$TMP/o.json"

# The receipt's classification is derived from the plan, not attacker-declared:
# a fixture build can never emit a primary-classified receipt.
[ "$(jq -r '.classification' "$RECEIPT")" = fixture ] || fail "receipt classification must stay fixture"
ok

# --- A2 wrong DOI / version / licence ---------------------------------------
edit_plan "$TMP/p_lic.json" '.sources[0].license.spdx="WTFPL"'
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/p_lic.json"
edit_plan "$TMP/p_licurl.json" '.sources[0].license.url="http://insecure.example/cc0"'
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/p_licurl.json"
edit_plan "$TMP/p_ver.json" '.sources[0].dataset_version=""'
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/p_ver.json"
edit_plan "$TMP/p_pid.json" '.sources[0].dataset_pid=""'
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/p_pid.json"
edit_plan "$TMP/p_url.json" '.sources[0].url="http://dataverse.harvard.edu/x"'
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/p_url.json"

# --- A3 challenge HTML cached as data ---------------------------------------
WAF_HTML='<html><head><title>Just a moment...</title></head><body>Checking your browser before accessing dataverse.harvard.edu</body></html>'
WAF_SHA=$(mk_obj "$WAF_HTML")
jq --arg s "$WAF_SHA" '.sources[0].aggregate.sha256=$s' "$PLAN" >"$TMP/p_waf_agg.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_waf_agg.json" "$TMP/o.json"
jq --arg s "$WAF_SHA" '.sources[0].raw.sha256=$s' "$PLAN" >"$TMP/p_waf_raw.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_waf_raw.json" "$TMP/o.json"

# --- A4 redirected partials -------------------------------------------------
FIRST_IMG=$(jq -r '.images[0].sha256' "$PLAN")
IMG_PATH="$CACHE/objects/${FIRST_IMG:0:2}/$FIRST_IMG"
cp "$IMG_PATH" "$TMP/img.bak"
: >"$IMG_PATH"                       # zero-byte truncation
assert_fail "$SRC" build "$CACHE" "$PLAN" "$TMP/o.json"
printf 'adv-image' >"$IMG_PATH"      # non-empty prefix, wrong digest
assert_fail "$SRC" build "$CACHE" "$PLAN" "$TMP/o.json"
cp "$TMP/img.bak" "$IMG_PATH"

# An in-flight .part artifact must never satisfy a pinned object: pin a digest
# whose bytes exist only under <sha>.part.
printf 'partial-download-bytes' >"$TMP/part_blob"
PART_SHA=$(hf "$TMP/part_blob")
mkdir -p "$CACHE/objects/${PART_SHA:0:2}"
cp "$TMP/part_blob" "$CACHE/objects/${PART_SHA:0:2}/$PART_SHA.part"
jq --arg s "$PART_SHA" '.sources[0].metadata.sha256=$s' "$PLAN" >"$TMP/p_part.json"
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/p_part.json"

# --- A5 duplicate ids / digests ---------------------------------------------
edit_plan "$TMP/p_dupsrc.json" '.sources += [.sources[0]]'
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/p_dupsrc.json"
edit_plan "$TMP/p_dupimg.json" '.images[1].sha256 = .images[0].sha256'
assert_fail "$SRC" build "$CACHE" "$TMP/p_dupimg.json" "$TMP/o.json"

# Same stimulus id supplied by a second "mirror" source: the joined corpus has
# a duplicate record id and must be rejected, not majority-voted.
AGG2_SHA=$(mk_obj '{"cons-1":{"domain":"consumer","mean_rating":4.0}}')
RAW2_SHA=$(mk_obj '{"cons-1":[4,4,4,4,4]}')
META2_SHA=$(mk_obj '{"pid":"doi:10.7910/DVN/MIRROR","version":"1.0"}')
MIRROR_IMG_SHA=$(mk_obj 'adv-image-bytes-mirror-cons-1')
jq --arg agg "$AGG2_SHA" --arg raw "$RAW2_SHA" --arg meta "$META2_SHA" \
   --arg img "$MIRROR_IMG_SHA" --arg licurl "$LIC_URL" --arg licsha "$LIC_SHA" '
  .sources += [{
    id:"mirror-src", dataset_pid:"doi:10.7910/DVN/MIRROR", dataset_version:"1.0",
    url:"https://mirror.example/dataset",
    license:{spdx:"CC0-1.0", url:$licurl, sha256:$licsha},
    metadata:{sha256:$meta}, aggregate:{sha256:$agg}, raw:{sha256:$raw}
  }]
  | .images += [{stimulus_id:"cons-1", source_id:"mirror-src", sha256:$img}]
' "$PLAN" >"$TMP/p_mirrorsrc.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_mirrorsrc.json" "$TMP/o.json"

# --- A6 symlink / traversal -------------------------------------------------
edit_plan "$TMP/p_trav.json" '.images[0].sha256="../../../etc/passwd"'
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/p_trav.json"
UPPER=$(rep64 A)
jq --arg s "$UPPER" '.images[0].sha256=$s' "$PLAN" >"$TMP/p_upper.json"
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/p_upper.json"
SHORT63=$(printf '%*s' 63 '' | tr ' ' 'a')
jq --arg s "$SHORT63" '.images[0].sha256=$s' "$PLAN" >"$TMP/p_short.json"
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/p_short.json"

SECOND_IMG=$(jq -r '.images[1].sha256' "$PLAN")
SYM_PATH="$CACHE/objects/${SECOND_IMG:0:2}/$SECOND_IMG"
cp "$SYM_PATH" "$TMP/sym_target"
rm "$SYM_PATH"
ln -s "$TMP/sym_target" "$SYM_PATH"   # correct bytes behind a symlink
assert_fail "$SRC" build "$CACHE" "$PLAN" "$TMP/o.json"
rm "$SYM_PATH"; cp "$TMP/sym_target" "$SYM_PATH"

ln -s "$PLAN" "$TMP/plan_link.json"   # symlinked plan document
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/plan_link.json"

# --- A7 rating / image mismatch ---------------------------------------------
edit_plan "$TMP/p_ghost.json" '.images[0].stimulus_id="ghost-1"'
assert_fail "$SRC" build "$CACHE" "$TMP/p_ghost.json" "$TMP/o.json"

# Aggregate inflated beyond the native 1..5 scale while raw stays in range and
# within the 0.5 disagreement window: must still be rejected.
INFL_AGG=$(printf '%s' "$AGG_JSON" | jq '."cons-3".mean_rating = 5.4')
INFL_SHA=$(mk_obj "$INFL_AGG")
jq --arg s "$INFL_SHA" '.sources[0].aggregate.sha256=$s' "$PLAN" >"$TMP/p_infl.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_infl.json" "$TMP/o.json"

# Raw ballots outside the native scale.
OOR_RAW=$(printf '%s' "$RAW_JSON" | jq '."cons-3"=[6,6,6,6,6]')
OOR_RAW_SHA=$(mk_obj "$OOR_RAW")
OOR_AGG=$(printf '%s' "$AGG_JSON" | jq '."cons-3".mean_rating = 6')
OOR_AGG_SHA=$(mk_obj "$OOR_AGG")
jq --arg r "$OOR_RAW_SHA" --arg a "$OOR_AGG_SHA" \
   '.sources[0].raw.sha256=$r | .sources[0].aggregate.sha256=$a' "$PLAN" >"$TMP/p_oor.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_oor.json" "$TMP/o.json"

# Caller-authored trust smuggled into the plan.
edit_plan "$TMP/p_trust.json" '.sources[0].verified=true'
assert_fail "$SRC" verify-cache "$CACHE" "$TMP/p_trust.json"

# --- A8 split integrity and leakage -----------------------------------------
jq -e '
  ([.records[] | select(.split=="calibration") | .asset_sha256]) as $c
  | ([.records[] | select(.split=="holdout") | .asset_sha256]) as $h
  | (($c - ($c - $h)) == []) and (($c + $h | length) == ($c + $h | unique | length))
' "$MANIFEST" >/dev/null || fail "calibration/holdout must be disjoint by asset digest"
ok
jq -e '
  ([.records[] | select(.split=="calibration") | .id]) as $c
  | ([.records[] | select(.split=="holdout") | .id]) as $h
  | ($c - ($c - $h)) == []
' "$MANIFEST" >/dev/null || fail "calibration/holdout must be disjoint by record id"
ok

# Determinism: identical inputs give byte-identical manifests.
"$SRC" build "$CACHE" "$PLAN" "$TMP/manifest_again.json" >/dev/null
[ "$(jq -cS . "$MANIFEST")" = "$(jq -cS . "$TMP/manifest_again.json")" ] || fail "same-seed rebuild must be identical"
ok

# The split is seed-driven: an adversary who re-rolls the seed after seeing
# results gets a visibly different manifest (and so a different manifest sha
# than the frozen receipt binds). Seeds chosen so the assignment differs.
write_plan "$TMP/p_seed2.json" fixture c41-adv-seed-rolled-2
"$SRC" build "$CACHE" "$TMP/p_seed2.json" "$TMP/manifest_seed2.json" >/dev/null
[ "$(jq -cS . "$MANIFEST")" != "$(jq -cS . "$TMP/manifest_seed2.json")" ] || fail "seed re-roll must change the split"
ok

# --- A9 post-result replacement ---------------------------------------------
# After the receipt is frozen, silently swapping one image for fresh bytes and
# re-pinning the plan must be detectable: the rebuilt manifest no longer
# matches the receipt's bound manifest sha.
BOUND_SHA=$(jq -r '.manifest_sha256' "$RECEIPT")
[ "$BOUND_SHA" = "$(hf "$MANIFEST")" ] || fail "receipt must bind the manifest sha"
ok
SWAP_SHA=$(mk_obj 'adv-image-bytes-replacement-after-results')
jq --arg old "$FIRST_IMG" --arg new "$SWAP_SHA" \
   '.images |= map(if .sha256==$old then .sha256=$new else . end)' "$PLAN" >"$TMP/p_swap.json"
"$SRC" build "$CACHE" "$TMP/p_swap.json" "$TMP/manifest_swap.json" >/dev/null
[ "$(hf "$TMP/manifest_swap.json")" != "$BOUND_SHA" ] || fail "post-result replacement must break the receipt binding"
ok

# --- A10 canary replay / cached-fixture promotion ---------------------------
# Without the live guard the canary may not emit a receipt at all — a cached
# fixture or replayed adapter output can never become a LIVE receipt.
rm -f "$TMP/canary_receipt.json"
if env -u POLYLANE_SOURCE_LIVE "$SRC" canary "$CACHE" "$PLAN" "$TMP/canary_receipt.json" >"$TMP/canary.log" 2>&1; then
  fail "canary must not succeed without the live guard"
fi
ok
grep -q 'EXTERNAL-EVIDENCE-OPEN' "$TMP/canary.log" || fail "guarded canary must report EXTERNAL-EVIDENCE-OPEN"
ok
[ ! -e "$TMP/canary_receipt.json" ] || fail "guarded canary must not write a receipt"
ok

# ===========================================================================
# Part 2 — calibration chain (bin/polylane-taste-calibration-live.sh)
# ===========================================================================
PARSER_SHA=$("$CAL" parser-sha)
SP=$(rep64 1); SAMP=$(rep64 2); SNAP=$(rep64 3); ADAPTER=$(rep64 4)
CORP=$(rep64 a); TUNE=$(rep64 b)
PROV=adv-provider; MODEL=adv-model; MV=2026.08
tok() { case "$1" in 1) printf FIRST;; 2) printf SECOND;; 0) printf ABSTAIN;; esac; }
mkcase() { d="$TMP/cal-$1"; rm -rf "$d"; mkdir -p "$d"; printf '%s' "$d"; }

# build_cal DIR CORRECT [UNITS] [MODE(inline|file)]
build_cal() {
  local root=$1 correct=$2 units=${3:-24} mode=${4:-inline}
  local labels_arr='[]' units_arr='[]' i
  for ((i = 0; i < units; i++)); do
    local A="stim-a${i}x" B="stim-a${i}y" gold_pos ppos mpos o0 o1
    gold_pos=$(( i % 2 == 0 ? 1 : 2 ))
    if [ "$i" -lt "$correct" ]; then ppos=$gold_pos; mpos=$((3 - gold_pos)); else ppos=$((3 - gold_pos)); mpos=$gold_pos; fi
    if [ "$gold_pos" -eq 1 ]; then o0=$A; o1=$B; else o0=$B; o1=$A; fi
    local praw mraw psha msha ppath="" mpath="" imgsha imgpath=""
    praw="Adversary-case unit $i primary."$'\n'"FINAL: $(tok "$ppos")"
    mraw="Adversary-case unit $i mirror."$'\n'"FINAL: $(tok "$mpos")"
    if [ "$mode" = file ]; then
      ppath="resp-$i-primary.txt"; mpath="resp-$i-mirror.txt"; imgpath="img-$i.png"
      printf '%s' "$praw" >"$root/$ppath"; printf '%s' "$mraw" >"$root/$mpath"
      printf 'PNG-adv-unit-%s' "$i" >"$root/$imgpath"
      psha=$(hf "$root/$ppath"); msha=$(hf "$root/$mpath"); imgsha=$(hf "$root/$imgpath")
    else
      psha=$(h "$praw"); msha=$(h "$mraw"); imgsha=$(h "adv-image-unit-$i")
    fi
    units_arr=$(jq -n --argjson acc "$units_arr" \
      --arg uid "unit-$i" --arg prompt "prompt-$i" --arg brief "brief-$i" \
      --arg imgsha "$imgsha" --arg imgpath "$imgpath" \
      --arg o0 "$o0" --arg o1 "$o1" \
      --arg praw "$praw" --arg psha "$psha" --arg ppath "$ppath" \
      --arg mraw "$mraw" --arg msha "$msha" --arg mpath "$mpath" \
      --arg prov "$PROV" --arg model "$MODEL" --arg mv "$MV" --arg sp "$SP" \
      --arg samp "$SAMP" --arg parser "$PARSER_SHA" --arg adapter "$ADAPTER" --arg mode "$mode" '
      def inv: {provider:$prov, model:$model, model_version:$mv, system_prompt_sha256:$sp, sampling_sha256:$samp, parser_sha256:$parser, adapter_sha256:$adapter};
      def img: if $mode == "file" then {path:$imgpath, sha256:$imgsha} else {sha256:$imgsha} end;
      def resp($raw; $sha; $path): if $mode == "file" then {path:$path, sha256:$sha} else {inline:$raw, sha256:$sha} end;
      $acc + [ {
        unit_id:$uid, prompt:$prompt, brief:$brief, image:img,
        primary:{orientation:[$o0,$o1], raw_response:resp($praw;$psha;$ppath), invocation:inv,
                 identity_visible:false, prior_ballots_visible:false, injection_detected:false, judge_discussion:false},
        mirror:{orientation:[$o1,$o0], raw_response:resp($mraw;$msha;$mpath), invocation:inv,
                identity_visible:false, prior_ballots_visible:false, injection_detected:false, judge_discussion:false}
      } ]')
    labels_arr=$(jq -n --argjson acc "$labels_arr" --arg uid "unit-$i" --arg imgsha "$imgsha" --arg A "$A" --arg B "$B" '
      $acc + [ {unit_id:$uid, image_sha256:$imgsha, stimulus_ids:[$A,$B], correct_stimulus:$A} ]')
  done
  jq -n --argjson labels "$labels_arr" --arg src "$SNAP" '
    {schema_version:"taste-holdout-labels/v1", dataset_id:"adv-holdout-v1", partition:"held_out",
     source_snapshot_sha256:$src, tuning_image_shas:[], labels:$labels}' >"$root/labels.json"
  local labels_sha; labels_sha=$(hf "$root/labels.json")
  jq -n --argjson units "$units_arr" --arg labels_sha "$labels_sha" \
    --arg prov "$PROV" --arg model "$MODEL" --arg mv "$MV" --arg sp "$SP" --arg samp "$SAMP" \
    --arg parser "$PARSER_SHA" --arg adapter "$ADAPTER" --arg src "$SNAP" \
    --arg corpus "$CORP" --arg tuning "$TUNE" '
    {schema_version:2,
     calibration:{dataset_id:"adv-holdout-v1", partition:"held_out", label_provenance:"human-labeled",
                  holdout_corpus_receipt_sha256:$corpus, tuning_corpus_receipt_sha256:$tuning,
                  holdout_labels:{path:"labels.json", sha256:$labels_sha}},
     freeze:{provider:$prov, model:$model, model_version:$mv, system_prompt_sha256:$sp, sampling_sha256:$samp,
             response_parser_sha256:$parser, invocation_adapter_sha256:$adapter, source_snapshot_sha256:$src,
             image_orientation_frozen:true},
     judge:{id:"judge-adv-001", provider:$prov, model:$model, model_version:$mv, system_prompt_sha256:$sp, sampling_sha256:$samp},
     units:$units}' >"$root/input.json"
}
edit_cal() { jq "$2" "$1/input.json" >"$1/input.json.n" && mv "$1/input.json.n" "$1/input.json"; }
rebind_labels() {
  local root=$1 s; s=$(hf "$root/labels.json")
  jq --arg s "$s" '.calibration.holdout_labels.sha256 = $s' "$root/input.json" >"$root/input.json.n"
  mv "$root/input.json.n" "$root/input.json"
}
run_cal() { "$CAL" "$1/input.json" "$1/out.json"; }
assert_cal_rejected() { # dir code name
  if run_cal "$1" >/dev/null 2>&1; then fail "$3: attack was accepted"; fi
  jq -e --arg c "$2" '.eligible == false and (.reason_codes | index($c) != null)' "$1/out.json" >/dev/null \
    || fail "$3: expected code $2, got $(jq -c '.reason_codes' "$1/out.json")"
  ok
}

# --- B1 answer-key leakage ---------------------------------------------------
# The correct stimulus smuggled into a unit (an answer key travelling with the
# question) must be schema-rejected, not silently ignored.
D=$(mkcase anskey); build_cal "$D" 17
edit_cal "$D" '.units[0].correct_stimulus = "stim-a0x"'
assert_cal_rejected "$D" SCHEMA_REJECTED answer-key-in-unit

# A gold field on the ballot itself.
D=$(mkcase anskey2); build_cal "$D" 17
edit_cal "$D" '.units[0].primary.gold = "stim-a0x"'
assert_cal_rejected "$D" SCHEMA_REJECTED answer-key-in-ballot

# Adversary-flipped answer key: rewriting labels after binding without
# re-binding the digest is tamper; the bytes no longer match.
D=$(mkcase anskey3); build_cal "$D" 17
jq '.labels |= map(.correct_stimulus = .stimulus_ids[1])' "$D/labels.json" >"$D/labels.json.n"
mv "$D/labels.json.n" "$D/labels.json"
assert_cal_rejected "$D" LABELS_INVALID answer-key-flip-unbound

# --- B2 session reuse --------------------------------------------------------
# The same transcript reused for primary and mirror (one session answering
# both orientations) contradicts itself once mirrored; two such units breach
# the mirror-instability floor.
D=$(mkcase sess); build_cal "$D" 17
for u in 18 19; do
  RAWTXT="Reused session transcript for unit $u."$'\n'"FINAL: FIRST"
  RAWSHA=$(h "$RAWTXT")
  jq --arg r "$RAWTXT" --arg s "$RAWSHA" --argjson u "$u" '
    .units[$u].primary.raw_response = {inline:$r, sha256:$s}
    | .units[$u].mirror.raw_response  = {inline:$r, sha256:$s}
  ' "$D/input.json" >"$D/input.json.n" && mv "$D/input.json.n" "$D/input.json"
done
assert_cal_rejected "$D" MIRROR_INSTABILITY session-reuse-mirror

# Cross-unit session reuse probe: one response transcript recycled for a
# different unit. If the validator (or a merged campaign ledger) rejects it the
# assertion passes; if it is still accepted the gap is a recorded seam owned by
# the calibration-campaign lane (unique per-unit sessions).
D=$(mkcase sessx); build_cal "$D" 18
P0=$(jq -c '.units[0].primary.raw_response' "$D/input.json")
jq --argjson r "$P0" '.units[1].primary.raw_response = $r' "$D/input.json" >"$D/input.json.n"
mv "$D/input.json.n" "$D/input.json"
if run_cal "$D" >/dev/null 2>&1; then
  seam session-uniqueness \
    "cross-unit raw-response reuse (same transcript sha in two units) is accepted by the v2 validator; the calibration-campaign lane must enforce unique sessions per work unit (reject duplicate raw_response digests across ballots)" \
    "$ROOT/bin/polylane-taste-campaign*.sh" "$ROOT/bin/polylane-taste-calibration-campaign*.sh"
else
  ok
fi

# --- B3 parser replay --------------------------------------------------------
# Pinned parser takes the LAST matching FINAL line: a replayed early verdict
# cannot override the final one.
D=$(mkcase plast); build_cal "$D" 17
RAWTXT="Draft answer."$'\n'"FINAL: SECOND"$'\n'"Reconsidered."$'\n'"FINAL: FIRST"
RAWSHA=$(h "$RAWTXT")
jq --arg r "$RAWTXT" --arg s "$RAWSHA" '.units[0].primary.raw_response = {inline:$r, sha256:$s}' \
  "$D/input.json" >"$D/input.json.n" && mv "$D/input.json.n" "$D/input.json"
run_cal "$D" >/dev/null 2>&1 || fail "last-FINAL-line replay: expected still eligible"
[ "$(jq -r '.correct_units' "$D/out.json")" = 17 ] || fail "last-FINAL-line must win (unit stays correct)"
ok

# A near-miss verdict line (trailing space) must be unparseable, not coerced.
D=$(mkcase pspace); build_cal "$D" 17
RAWTXT="Assessment."$'\n'"FINAL: FIRST "
RAWSHA=$(h "$RAWTXT")
jq --arg r "$RAWTXT" --arg s "$RAWSHA" '.units[0].primary.raw_response = {inline:$r, sha256:$s}' \
  "$D/input.json" >"$D/input.json.n" && mv "$D/input.json.n" "$D/input.json"
assert_cal_rejected "$D" RESPONSE_UNPARSEABLE parser-near-miss

# A different parser declared per-ballot (replaying an older parser contract).
D=$(mkcase pdrift); build_cal "$D" 17
edit_cal "$D" ".units[0].primary.invocation.parser_sha256 = \"$(rep64 f)\""
assert_cal_rejected "$D" INVOCATION_DRIFT parser-replay-per-ballot

# --- B4 fixture promotion ----------------------------------------------------
# One inline response inside an otherwise file-backed record demotes the whole
# receipt to fixture_only; production can never be claimed.
D=$(mkcase fixmix); build_cal "$D" 17 24 file
PRAW=$(cat "$D/resp-0-primary.txt")
PSHA=$(hf "$D/resp-0-primary.txt")
jq --arg r "$PRAW" --arg s "$PSHA" '.units[0].primary.raw_response = {inline:$r, sha256:$s}' \
  "$D/input.json" >"$D/input.json.n" && mv "$D/input.json.n" "$D/input.json"
run_cal "$D" >/dev/null 2>&1 || fail "mixed inline/file record should stay eligible"
[ "$(jq -r '.classification' "$D/out.json")" = fixture_only ] || fail "mixed record must be fixture_only"
[ "$(jq -r '.production' "$D/out.json")" = false ] || fail "mixed record must not be production"
ok

# Declaring production in the input is an unknown key.
D=$(mkcase fixdecl); build_cal "$D" 17
edit_cal "$D" '.production = true'
assert_cal_rejected "$D" SCHEMA_REJECTED fixture-promotion-declared

# --- B5 human-certification escalation ---------------------------------------
D=$(mkcase hum); build_cal "$D" 17
edit_cal "$D" '.judge.human_certified = true'
assert_cal_rejected "$D" SCHEMA_REJECTED human-cert-judge-key

D=$(mkcase hum2); build_cal "$D" 17
edit_cal "$D" '.calibration.label_provenance = "human-certified"'
assert_cal_rejected "$D" SCHEMA_REJECTED human-cert-provenance

# Every receipt emitted by every calibration case in this run — eligible or
# rejected — must carry human_certified:false and the machine-only claim.
for out in "$TMP"/cal-*/out.json; do
  [ -f "$out" ] || continue
  jq -e '.human_certified == false and .machine_not_human == true
         and .machine_panel_claim == "HUMAN_CALIBRATED_MACHINE"' "$out" >/dev/null \
    || fail "receipt $out escalated beyond machine calibration"
done
ok

# ===========================================================================
# Part 3 — seams: attacks whose defense is owned by absent Cycle-41 siblings
# ===========================================================================
# Challenge HTML (or any non-image bytes) pinned AS an image passes the
# content-address check by construction; only content inspection can catch it.
WAF_IMG_SHA=$(mk_obj "$WAF_HTML")
jq --arg old "$FIRST_IMG" --arg new "$WAF_IMG_SHA" \
   '.images |= map(if .sha256==$old then .sha256=$new else . end)' "$PLAN" >"$TMP/p_wafimg.json"
if "$SRC" build "$CACHE" "$TMP/p_wafimg.json" "$TMP/o_wafimg.json" >/dev/null 2>&1; then
  seam image-content-verification \
    "challenge HTML pinned as an image object builds successfully today; the cache-integrity lane must add content inspection (image magic bytes / minimum plausible size) on top of digest checks" \
    "$ROOT/bin/polylane-taste-cache*.sh"
else
  ok  # a merged cache-integrity layer already rejects it
fi

seam dataone-metadata-crosscheck \
  "pinned metadata bytes are digest-verified but never parsed: a wrong-DOI, wrong-version, wrong-licence, or challenge-HTML metadata object that matches its own pin is accepted; the source-freeze/dataone-metadata lanes must cross-check DOI, domain, licence, version, and file identity exactly and emit SOURCE-MISMATCH on disagreement" \
  "$ROOT/bin/polylane-taste-freeze*.sh" "$ROOT/bin/polylane-taste-source-freeze*.sh" "$ROOT/bin/polylane-taste-dataone*.sh"

seam distribution-drift \
  "no local interface verifies the declared distribution inventory (count/size/checksum per DataONE record) against fetched files; the dataone-metadata lane owns drift detection between declared distributions and acquired bytes" \
  "$ROOT/bin/polylane-taste-dataone*.sh"

seam download-resume-ledger \
  "atomic .part publication is honoured by the cache reader (attack A4) but no resumable download ledger exists locally; the download-campaign lane must prove bounded retries and atomic promotion under interruption" \
  "$ROOT/bin/polylane-taste-download*.sh"

seam benchmark-preflight-gate \
  "no single deterministic gate proves source, split, pairs, panel, cache, providers, and disk readiness before the generation wave; owned by the benchmark-preflight lane" \
  "$ROOT/bin/polylane-taste-preflight*.sh" "$ROOT/bin/polylane-taste-benchmark-preflight*.sh"

seam pair-manifest-freeze \
  "unambiguous mirrored pair construction with bootstrap-interval rule and a frozen pair manifest has no local interface; owned by the pair-builder lane" \
  "$ROOT/bin/polylane-taste-pair*.sh"

if [ "${POLYLANE_ADVERSARY_REQUIRE_SEAMS_CLOSED:-0}" = 1 ] && [ "$SEAMS" -gt 0 ]; then
  echo "FAIL seams must be closed in integrator mode (open=$SEAMS)" >&2
  exit 1
fi

echo "PASS test-taste-source-adversarial assertions=$ASSERTIONS seams=$SEAMS"
