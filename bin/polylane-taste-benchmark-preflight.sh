#!/usr/bin/env bash
# polylane-taste-benchmark-preflight.sh — the one deterministic gate that must
# pass before the expensive 20-brief generation wave is allowed to start.
#
# It verifies, fail-closed and in one run: the three live Dataverse source
# receipts (production classification, frozen DOIs, split-manifest binding),
# the complete 180+72 stratified split (60/24 per domain), every cached image
# byte-for-byte against its content address, the frozen 24-pair held-out
# mirrored pair manifests, at least five audited eligible machine-judge
# configurations (taste-calibration/v2, thresholds recomputed here, never
# trusted), the exact frozen protocol/prompt/brief hashes and baseline skill
# revision, the availability of the declared browser/build/provider CLIs, the
# free-disk budget, and that no input anywhere claims human certification.
#
# Output is a single receipt: READY with a closure hash over every verified
# artifact, or NOT-READY with explicit reason codes. There is no partial pass:
# every check runs, every failure is coded, and a closure hash exists only for
# a fully green world. This gate validates evidence; it never generates or
# improves it, never fetches, and never invokes a model.
#
# usage: polylane-taste-benchmark-preflight.sh run CONFIG.json RECEIPT_OUT.json
# exit:  0 READY · 1 NOT-READY · 2 usage error
#
# Bash 3.2 safe: no associative arrays, no process substitution.
set -euo pipefail

# Frozen protocol constants (cycle-40/41 preregistration; never configurable).
FROZEN_BASELINE_REVISION=0b802ad13ada13a0dc7cc702a526ed17d3348851
FROZEN_DOIS='10.7910/DVN/9FKSQI 10.7910/DVN/XOI0HI 10.7910/DVN/Z7KLIH'
CAL_PER_DOMAIN=60
HOLD_PER_DOMAIN=24
DOMAIN_COUNT=3
PAIRS_REQUIRED=24
PANEL_MIN=5
UNITS_REQUIRED=24
CORRECT_MIN=17
WILSON_MIN=0.50
WILSON_TOLERANCE=0.0005
SIDE_P_MIN=0.05
MIRROR_CONTRA_MAX=1

usage() {
  echo "usage: polylane-taste-benchmark-preflight.sh run CONFIG.json RECEIPT_OUT.json" >&2
  exit 2
}

[ "$#" -eq 3 ] && [ "$1" = run ] || usage
CONFIG=$2
RECEIPT_OUT=$3

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }
command -v shasum >/dev/null 2>&1 || { echo "shasum is required" >&2; exit 2; }

SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/polylane-benchmark-preflight.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT HUP INT TERM
CLOSURE_LINES="$SCRATCH/closure.lines"
: >"$CLOSURE_LINES"

CODES=''
scode() { case "|$CODES|" in *"|$1|"*) ;; *) CODES="${CODES:+$CODES|}$1" ;; esac; }

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }

# A verified artifact contributes "sha  role" to the closure; the closure hash
# is content-only, so the same evidence yields the same hash on any host.
add_closure() { printf '%s  %s\n' "$(sha256_file "$2")" "$1" >>"$CLOSURE_LINES"; }

# Regular non-symlink parseable JSON without duplicate keys, or code $2.
readable_json() {
  local file=$1 code=$2 duplicates
  [ -n "$file" ] && [ -f "$file" ] && [ ! -L "$file" ] || { scode "$code"; return 1; }
  jq -e . "$file" >/dev/null 2>&1 || { scode "$code"; return 1; }
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("/")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ] || { scode "$code"; return 1; }
}

# Observed check values for the receipt (0 until proven).
SOURCE_RECEIPT_COUNT=0
SPLIT_RECORDS=0
CAL_RECORDS=0
HOLD_RECORDS=0
CACHE_OBJECTS=0
CACHE_BYTES=0
PAIR_MANIFEST_COUNT=0
PAIRS_SEEN=0
PANEL_ELIGIBLE=0
CLI_COUNT=0
FREE_DISK_BYTES=0
RUN_ID=''

# ---------------------------------------------------------------------------
# config: closed schema; anything unexpected is CONFIG_INVALID, and no other
# check runs against an untrusted shape.
# ---------------------------------------------------------------------------
CONFIG_OK=false
if readable_json "$CONFIG" CONFIG_INVALID; then
  if jq -e '
      def nonempty: type == "string" and length > 0;
      def hex64: type == "string" and test("^[0-9a-f]{64}$");
      def patharr(min; max): type == "array" and length >= min and length <= max
        and all(.[]; nonempty);
      type == "object"
      and ((keys - ["schema_version","run_id","source_receipts","split_manifest",
                    "cache_dir","pair_manifests","panel_receipts","frozen",
                    "required_clis","min_free_disk_bytes"]) == [])
      and .schema_version == "taste-benchmark-preflight/v1"
      and (.run_id | nonempty)
      and (.source_receipts | patharr(1; 8))
      and (.split_manifest | nonempty)
      and (.cache_dir | nonempty)
      and (.pair_manifests | patharr(1; 16))
      and (.panel_receipts | patharr(1; 64))
      and (.frozen | type == "object"
        and ((keys - ["protocol_path","protocol_sha256","prompt_path","prompt_sha256",
                      "brief_path","brief_sha256","baseline_revision"]) == [])
        and (.protocol_path | nonempty) and (.protocol_sha256 | hex64)
        and (.prompt_path | nonempty) and (.prompt_sha256 | hex64)
        and (.brief_path | nonempty) and (.brief_sha256 | hex64)
        and (.baseline_revision | type == "string" and test("^[0-9a-f]{40}$")))
      and (.required_clis | type == "array" and length >= 1
        and all(.[]; type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$")))
      and (.min_free_disk_bytes | type == "number" and . >= 1 and floor == .)
    ' "$CONFIG" >/dev/null 2>&1; then
    CONFIG_OK=true
    RUN_ID=$(jq -r '.run_id' "$CONFIG")
    add_closure config "$CONFIG"
  else
    scode CONFIG_INVALID
  fi
fi

if [ "$CONFIG_OK" = true ]; then
  SPLIT_MANIFEST=$(jq -r '.split_manifest' "$CONFIG")
  CACHE_DIR=$(jq -r '.cache_dir' "$CONFIG")

  # -------------------------------------------------------------------------
  # 1. split manifest: exactly 180 calibration + 72 holdout, 60/24 per domain,
  #    unique ids and unique image digests across exactly three domains.
  # -------------------------------------------------------------------------
  SPLIT_OK=false
  if readable_json "$SPLIT_MANIFEST" SPLIT_INVALID; then
    if jq -e '
        def hex64: type == "string" and test("^[0-9a-f]{64}$");
        (.records | type == "array")
        and all(.records[]; type == "object"
          and (.id | type == "string" and length > 0)
          and (.domain | type == "string" and length > 0)
          and (.split | IN("calibration","holdout"))
          and (.asset_sha256 | hex64))
        and ([.records[].id] | length == (unique | length))
        and ([.records[].asset_sha256] | length == (unique | length))
      ' "$SPLIT_MANIFEST" >/dev/null 2>&1; then
      SPLIT_OK=true
      SPLIT_RECORDS=$(jq '.records | length' "$SPLIT_MANIFEST")
      CAL_RECORDS=$(jq '[.records[] | select(.split == "calibration")] | length' "$SPLIT_MANIFEST")
      HOLD_RECORDS=$(jq '[.records[] | select(.split == "holdout")] | length' "$SPLIT_MANIFEST")
      jq -e --argjson domains "$DOMAIN_COUNT" --argjson cal "$CAL_PER_DOMAIN" \
            --argjson hold "$HOLD_PER_DOMAIN" '
          ([.records[].domain] | unique | length) == $domains
          and ([.records | group_by(.domain)[]
                | [([.[] | select(.split == "calibration")] | length),
                   ([.[] | select(.split == "holdout")] | length)]]
              | all(.[]; . == [$cal, $hold]))
        ' "$SPLIT_MANIFEST" >/dev/null 2>&1 || scode SPLIT_QUOTA
      add_closure split_manifest "$SPLIT_MANIFEST"
    else
      scode SPLIT_INVALID
    fi
  fi

  # -------------------------------------------------------------------------
  # 2. source receipts: production-classified, jointly covering all three
  #    frozen DOIs, each byte-bound to this exact split manifest.
  # -------------------------------------------------------------------------
  SPLIT_SHA=''
  [ ! -f "$SPLIT_MANIFEST" ] || [ -L "$SPLIT_MANIFEST" ] || SPLIT_SHA=$(sha256_file "$SPLIT_MANIFEST")
  SOURCE_RECEIPT_COUNT=$(jq '.source_receipts | length' "$CONFIG")
  SEEN_DOIS="$SCRATCH/dois.seen"
  : >"$SEEN_DOIS"
  i=0
  while [ "$i" -lt "$SOURCE_RECEIPT_COUNT" ]; do
    receipt=$(jq -r ".source_receipts[$i]" "$CONFIG")
    if readable_json "$receipt" "SOURCE_RECEIPT_INVALID:$i"; then
      if jq -e '
          type == "object"
          and .schema_version == "taste-source-acquisition/v1"
          and (.classification | type == "string")
          and (.manifest_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
          and (.sources | type == "array" and length >= 1
            and all(.[]; type == "object" and (.dataset_pid | type == "string" and length > 0)))
          and (.fixture_only != true)
        ' "$receipt" >/dev/null 2>&1; then
        [ "$(jq -r '.classification' "$receipt")" = production ] ||
          scode "SOURCE_RECEIPT_FIXTURE:$i"
        [ -n "$SPLIT_SHA" ] && [ "$(jq -r '.manifest_sha256' "$receipt")" = "$SPLIT_SHA" ] ||
          scode "SOURCE_SPLIT_UNBOUND:$i"
        jq -r '.sources[].dataset_pid | sub("^doi:"; "")' "$receipt" >>"$SEEN_DOIS"
        add_closure "source_receipt:$i" "$receipt"
      else
        scode "SOURCE_RECEIPT_INVALID:$i"
      fi
    fi
    i=$((i + 1))
  done
  for doi in $FROZEN_DOIS; do
    grep -Fqx "$doi" "$SEEN_DOIS" || scode "SOURCE_DOI_MISSING:$doi"
  done

  # -------------------------------------------------------------------------
  # 3. cache bytes: every image the split manifest names must exist in the
  #    content-addressed cache as a regular non-symlink file whose recomputed
  #    SHA-256 equals its address. Bytes are summed for the receipt.
  # -------------------------------------------------------------------------
  if [ "$SPLIT_OK" = true ]; then
    if [ -d "$CACHE_DIR" ]; then
      OBJ_LIST="$SCRATCH/objects.list"
      : >"$OBJ_LIST"
      while IFS= read -r sha; do
        obj="$CACHE_DIR/objects/${sha:0:2}/$sha"
        if [ -L "$obj" ] || [ ! -f "$obj" ] || [ ! -s "$obj" ]; then
          scode "CACHE_OBJECT_INVALID:$sha"
        else
          printf '%s\n' "$obj" >>"$OBJ_LIST"
        fi
      done <<EOF_SHAS
$(jq -r '.records[].asset_sha256' "$SPLIT_MANIFEST")
EOF_SHAS
      # One batched shasum/wc pass over all objects instead of one process per
      # object; the content address is the basename, so each output line is
      # self-checking. Object names are hex, so newline-safe.
      if [ -s "$OBJ_LIST" ]; then
        while IFS= read -r line; do
          computed=${line%% *}
          name=${line##*/}
          if [ "$computed" = "$name" ]; then
            CACHE_OBJECTS=$((CACHE_OBJECTS + 1))
          else
            scode "CACHE_OBJECT_INVALID:$name"
          fi
        done <<EOF_HASHES
$(tr '\n' '\0' <"$OBJ_LIST" | xargs -0 shasum -a 256)
EOF_HASHES
        CACHE_BYTES=$(tr '\n' '\0' <"$OBJ_LIST" | xargs -0 wc -c |
          awk '$2 != "total" {s += $1} END {printf "%.0f", s}')
      fi
    else
      scode CACHE_DIR_MISSING
    fi
  fi

  # -------------------------------------------------------------------------
  # 4. pair manifests: exactly 24 unambiguous mirrored pairs each, every side
  #    a distinct holdout record with its exact image digest, no duplicate
  #    pair (in either orientation).
  # -------------------------------------------------------------------------
  PAIR_MANIFEST_COUNT=$(jq '.pair_manifests | length' "$CONFIG")
  i=0
  while [ "$i" -lt "$PAIR_MANIFEST_COUNT" ]; do
    pairs=$(jq -r ".pair_manifests[$i]" "$CONFIG")
    if readable_json "$pairs" "PAIRS_INVALID:$i"; then
      if [ "$SPLIT_OK" = true ] &&
        jq -e --slurpfile split "$SPLIT_MANIFEST" --argjson want "$PAIRS_REQUIRED" '
          def hex64: type == "string" and test("^[0-9a-f]{64}$");
          ([$split[0].records[] | select(.split == "holdout")
            | {(.id): .asset_sha256}] | add // {}) as $holdout
          | type == "object"
          and (.pairs | type == "array" and length == $want)
          and all(.pairs[]; type == "object"
            and (.pair_id | type == "string" and length > 0)
            and (.a | type == "object" and (.id | type == "string") and (.asset_sha256 | hex64))
            and (.b | type == "object" and (.id | type == "string") and (.asset_sha256 | hex64))
            and (.a.id != .b.id)
            and ($holdout[.a.id] == .a.asset_sha256)
            and ($holdout[.b.id] == .b.asset_sha256))
          and ([.pairs[].pair_id] | length == (unique | length))
          and ([.pairs[] | [.a.id, .b.id] | sort] | length == (unique | length))
        ' "$pairs" >/dev/null 2>&1; then
        PAIRS_SEEN=$(jq '.pairs | length' "$pairs")
        add_closure "pair_manifest:$i" "$pairs"
      else
        scode "PAIRS_INVALID:$i"
      fi
    fi
    i=$((i + 1))
  done

  # -------------------------------------------------------------------------
  # 5. panel: at least five audited eligible taste-calibration/v2 machine
  #    configurations. Thresholds are recomputed here from the receipt's own
  #    counts — a receipt that says "eligible" but fails the frozen floors is
  #    an audit mismatch, not a pass. All receipts must bind one holdout
  #    corpus and one label set, and none may claim human certification.
  # -------------------------------------------------------------------------
  PANEL_COUNT=$(jq '.panel_receipts | length' "$CONFIG")
  PANEL_FPS="$SCRATCH/panel.fps"
  PANEL_BINDINGS="$SCRATCH/panel.bindings"
  : >"$PANEL_FPS"
  : >"$PANEL_BINDINGS"
  i=0
  while [ "$i" -lt "$PANEL_COUNT" ]; do
    panel=$(jq -r ".panel_receipts[$i]" "$CONFIG")
    if readable_json "$panel" "PANEL_RECEIPT_INVALID:$i"; then
      if jq -e '
          def hex64: type == "string" and test("^[0-9a-f]{64}$");
          type == "object"
          and .schema_version == "taste-calibration/v2"
          and (.eligible | type == "boolean")
          and (.status | IN("eligible","ineligible"))
          and (.classification | type == "string")
          and (.human_certified | type == "boolean")
          and .machine_panel_claim == "HUMAN_CALIBRATED_MACHINE"
          and (.sample_units | type == "number" and floor == .)
          and (.correct_units | type == "number" and floor == .)
          and (.wilson_lower_bound | type == "number")
          and (.side_probe_exact_binomial_p | type == "number")
          and (.mirror_contradictions | type == "number" and floor == . and . >= 0)
          and (.corpus_holdout_receipt_sha256 | hex64)
          and (.holdout_labels_sha256 | hex64)
          and (.judge_configuration | type == "object"
            and .kind == "machine"
            and (.provider | type == "string" and length > 0)
            and (.model | type == "string" and length > 0)
            and (.model_version | type == "string" and length > 0)
            and (.system_prompt_sha256 | hex64)
            and (.sampling_sha256 | hex64))
        ' "$panel" >/dev/null 2>&1; then
        jq -e '.human_certified == false' "$panel" >/dev/null 2>&1 ||
          scode "HUMAN_OVERCLAIM:panel:$i"
        if jq -e '.eligible == true and .status == "eligible"
                  and .classification == "production" and .production == true
                  and .fixture_only == false' "$panel" >/dev/null 2>&1; then
          units=$(jq -r '.sample_units' "$panel")
          correct=$(jq -r '.correct_units' "$panel")
          claimed_wilson=$(jq -r '.wilson_lower_bound' "$panel")
          side_p=$(jq -r '.side_probe_exact_binomial_p' "$panel")
          contra=$(jq -r '.mirror_contradictions' "$panel")
          audit_ok=$(awk \
            -v units="$units" -v correct="$correct" -v claimed="$claimed_wilson" \
            -v side_p="$side_p" -v contra="$contra" \
            -v want_units="$UNITS_REQUIRED" -v min_correct="$CORRECT_MIN" \
            -v min_wilson="$WILSON_MIN" -v tolerance="$WILSON_TOLERANCE" \
            -v min_side="$SIDE_P_MIN" -v max_contra="$MIRROR_CONTRA_MAX" 'BEGIN {
              z = 1.959963984540054
              p = correct / units
              z2 = z * z
              lower = (p + z2 / (2 * units) - z * sqrt((p * (1 - p) + z2 / (4 * units)) / units)) / (1 + z2 / units)
              diff = claimed - lower; if (diff < 0) diff = -diff
              ok = (units == want_units && correct >= min_correct \
                    && diff <= tolerance && lower >= min_wilson \
                    && side_p >= min_side && contra <= max_contra)
              print (ok ? "yes" : "no")
            }')
          if [ "$audit_ok" = yes ]; then
            jq -r '.judge_configuration | [.provider, .model, .model_version,
              .system_prompt_sha256, .sampling_sha256] | join("|")' "$panel" >>"$PANEL_FPS"
            jq -r '[.corpus_holdout_receipt_sha256, .holdout_labels_sha256] | join("|")' \
              "$panel" >>"$PANEL_BINDINGS"
            add_closure "panel:$i" "$panel"
          else
            scode "PANEL_AUDIT_MISMATCH:$i"
          fi
        fi
      else
        scode "PANEL_RECEIPT_INVALID:$i"
      fi
    fi
    i=$((i + 1))
  done
  PANEL_ELIGIBLE=$(LC_ALL=C sort -u "$PANEL_FPS" | grep -c . || true)
  fp_total=$(grep -c . "$PANEL_FPS" || true)
  [ "$PANEL_ELIGIBLE" -eq "$fp_total" ] || scode PANEL_DUPLICATE_CONFIG
  [ "$(LC_ALL=C sort -u "$PANEL_BINDINGS" | grep -c . || true)" -le 1 ] || scode PANEL_INCOHERENT
  [ "$PANEL_ELIGIBLE" -ge "$PANEL_MIN" ] || scode "PANEL_INSUFFICIENT:$PANEL_ELIGIBLE"

  # -------------------------------------------------------------------------
  # 6. frozen hashes: protocol, prompt bundle, brief corpus byte-exact against
  #    the declared freeze; the baseline skill revision is a script constant
  #    and the config must agree with it.
  # -------------------------------------------------------------------------
  for role in protocol prompt brief; do
    fpath=$(jq -r ".frozen.${role}_path" "$CONFIG")
    fsha=$(jq -r ".frozen.${role}_sha256" "$CONFIG")
    if [ -f "$fpath" ] && [ ! -L "$fpath" ] && [ "$(sha256_file "$fpath")" = "$fsha" ]; then
      add_closure "frozen:$role" "$fpath"
    else
      scode "FROZEN_HASH_MISMATCH:$role"
    fi
  done
  [ "$(jq -r '.frozen.baseline_revision' "$CONFIG")" = "$FROZEN_BASELINE_REVISION" ] ||
    scode BASELINE_REVISION_MISMATCH

  # -------------------------------------------------------------------------
  # 7. CLIs: every declared browser/build/provider command must resolve now.
  # -------------------------------------------------------------------------
  CLI_COUNT=$(jq '.required_clis | length' "$CONFIG")
  i=0
  while [ "$i" -lt "$CLI_COUNT" ]; do
    cli=$(jq -r ".required_clis[$i]" "$CONFIG")
    command -v "$cli" >/dev/null 2>&1 || scode "CLI_MISSING:$cli"
    i=$((i + 1))
  done

  # -------------------------------------------------------------------------
  # 8. disk budget: free bytes on the cache filesystem must cover the wave.
  # -------------------------------------------------------------------------
  MIN_FREE=$(jq -r '.min_free_disk_bytes' "$CONFIG")
  disk_probe=$CACHE_DIR
  [ -d "$disk_probe" ] || disk_probe=$(dirname -- "$CACHE_DIR")
  FREE_DISK_BYTES=$(df -Pk "$disk_probe" 2>/dev/null | awk 'NR == 2 {printf "%.0f", $4 * 1024}')
  [ -n "$FREE_DISK_BYTES" ] || FREE_DISK_BYTES=0
  awk -v free="$FREE_DISK_BYTES" -v min="$MIN_FREE" \
    'BEGIN { exit (free + 0 >= min + 0 ? 0 : 1) }' || scode "DISK_BUDGET:$FREE_DISK_BYTES"

  # -------------------------------------------------------------------------
  # 9. human_certified:false everywhere — no configured JSON input may claim
  #    human certification, whatever its schema.
  # -------------------------------------------------------------------------
  while IFS= read -r input; do
    [ -f "$input" ] && [ ! -L "$input" ] || continue
    jq -e . "$input" >/dev/null 2>&1 || continue
    jq -e '[.. | objects | select(has("human_certified")) | .human_certified]
           | all(. == false)' "$input" >/dev/null 2>&1 ||
      scode "HUMAN_OVERCLAIM:$(basename "$input")"
  done <<EOF_INPUTS
$(jq -r '.source_receipts[], .split_manifest, .pair_manifests[], .panel_receipts[]' "$CONFIG")
EOF_INPUTS
fi

# ---------------------------------------------------------------------------
# verdict + receipt. The closure hash exists only for a fully green world.
# ---------------------------------------------------------------------------
CODES_JSON=$(printf '%s\n' "$CODES" | tr '|' '\n' | jq -Rn '[inputs | select(length > 0)] | sort')
STATUS=NOT-READY
READY=false
CLOSURE=null
if [ "$CODES_JSON" = '[]' ]; then
  STATUS=READY
  READY=true
  CLOSURE=$(LC_ALL=C sort "$CLOSURE_LINES" | shasum -a 256 | awk '{print $1}')
  CLOSURE=$(printf '"%s"' "$CLOSURE")
fi

TOOL_FP=$(sha256_file "$0")
RECEIPT_TMP=$(mktemp "${RECEIPT_OUT}.tmp.XXXXXX")
jq -n \
  --arg status "$STATUS" --argjson ready "$READY" --arg run_id "$RUN_ID" \
  --argjson codes "$CODES_JSON" --argjson closure "$CLOSURE" --arg tool_fp "$TOOL_FP" \
  --argjson source_receipts "$SOURCE_RECEIPT_COUNT" \
  --argjson split_records "$SPLIT_RECORDS" --argjson cal "$CAL_RECORDS" \
  --argjson hold "$HOLD_RECORDS" --argjson cache_objects "$CACHE_OBJECTS" \
  --argjson cache_bytes "$CACHE_BYTES" --argjson pair_manifests "$PAIR_MANIFEST_COUNT" \
  --argjson pairs "$PAIRS_SEEN" --argjson panel_eligible "$PANEL_ELIGIBLE" \
  --argjson clis "$CLI_COUNT" --argjson free_disk "$FREE_DISK_BYTES" '
  {schema_version: "taste-benchmark-preflight/v1",
   run_id: $run_id,
   status: $status,
   ready: $ready,
   reason_codes: $codes,
   human_certified: false,
   checks: {
     source_receipts: $source_receipts,
     split_records: $split_records,
     calibration_records: $cal,
     holdout_records: $hold,
     cache_objects: $cache_objects,
     cache_bytes: $cache_bytes,
     pair_manifests: $pair_manifests,
     pairs: $pairs,
     panel_eligible: $panel_eligible,
     required_clis: $clis,
     free_disk_bytes: $free_disk},
   closure_sha256: $closure,
   tool: {id: "polylane-taste-benchmark-preflight", fingerprint: $tool_fp}}' \
  >"$RECEIPT_TMP" || { rm -f "$RECEIPT_TMP"; exit 2; }
mv -f "$RECEIPT_TMP" "$RECEIPT_OUT"

if [ "$READY" = true ]; then
  printf 'READY %s\n' "$(printf '%s' "$CLOSURE" | tr -d '"')"
  exit 0
fi
printf 'NOT-READY %s\n' "$(printf '%s' "$CODES_JSON" | jq -r 'join(",")')"
exit 1
