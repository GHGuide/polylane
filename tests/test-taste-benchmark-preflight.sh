#!/usr/bin/env bash
# Regression tests for the deterministic generation-wave preflight gate
# (bin/polylane-taste-benchmark-preflight.sh).  Red-first: one happy fixture
# world, then one attack per omitted/tampered/unavailable boundary.  The gate
# must emit READY with a closure hash only when every frozen prerequisite
# holds, and explicit reason codes otherwise — never a partial pass.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
BIN="$ROOT/bin/polylane-taste-benchmark-preflight.sh"
TMPDIR_TEST=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-benchmark-preflight.XXXXXX")
trap 'rm -rf "$TMPDIR_TEST"' EXIT HUP INT TERM

BASELINE_REV=0b802ad13ada13a0dc7cc702a526ed17d3348851
ASSERTIONS=0

fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }
ok() { ASSERTIONS=$((ASSERTIONS + 1)); }
hf() { shasum -a 256 "$1" | awk '{print $1}'; }
h() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

wilson() {
  awk -v correct="$1" -v total="$2" 'BEGIN {
    z = 1.959963984540054
    p = correct / total
    z2 = z * z
    lower = (p + z2 / (2 * total) - z * sqrt((p * (1 - p) + z2 / (4 * total)) / total)) / (1 + z2 / total)
    printf "%.6f", lower
  }'
}

jq_edit() { # jq_edit FILE FILTER [jq args...]
  local file=$1 filter=$2 tmp
  shift 2
  tmp=$(mktemp "$file.tmp.XXXXXX")
  jq "$@" "$filter" "$file" >"$tmp" && mv -f "$tmp" "$file"
}

obj_write() { # obj_write CACHE CONTENT -> echoes sha
  local sha dir
  sha=$(h "$1_content_$2")
  dir="$3/objects/${sha:0:2}"
  mkdir -p "$dir"
  printf '%s' "$1_content_$2" >"$dir/$sha"
  printf '%s' "$sha"
}

mk_panel_receipt() { # mk_panel_receipt OUT PROVIDER MODEL CORRECT
  local out=$1 provider=$2 model=$3 correct=$4 w
  w=$(wilson "$correct" 24)
  jq -n \
    --arg provider "$provider" --arg model "$model" \
    --argjson correct "$correct" --argjson wilson "$w" \
    --arg sp "$(h "system-prompt-$provider")" --arg samp "$(h "sampling-$provider")" \
    --arg corpus "$CORPUS_RECEIPT_SHA" --arg labels "$LABELS_SHA" '
    {schema_version: "taste-calibration/v2",
     status: "eligible", eligible: true,
     classification: "production", production: true, fixture_only: false,
     human_certified: false, machine_not_human: true,
     machine_panel_claim: "HUMAN_CALIBRATED_MACHINE",
     sample_units: 24, correct_units: $correct,
     wilson_lower_bound: $wilson,
     side_probe_n: 24, side_probe_exact_binomial_p: 0.31,
     mirror_probe_n: 24, mirror_contradictions: 0,
     corpus_holdout_receipt_sha256: $corpus,
     holdout_labels_sha256: $labels,
     judge_configuration: {kind: "machine", provider: $provider, model: $model,
       model_version: "2026.08", system_prompt_sha256: $sp, sampling_sha256: $samp}}' \
    >"$out"
}

# ---------------------------------------------------------------------------
# pristine happy world: 252 cached images, 180+72 split, 24 pairs, 5-judge
# panel, frozen hash targets, stub CLIs, 1-byte disk budget.
# ---------------------------------------------------------------------------
PRISTINE="$TMPDIR_TEST/pristine"
mkdir -p "$PRISTINE/cache" "$PRISTINE/panel" "$PRISTINE/frozen" "$PRISTINE/clis"

CORPUS_RECEIPT_SHA=$(h corpus-holdout-receipt)
LABELS_SHA=$(h holdout-labels)

RECORDS_TSV="$PRISTINE/records.tsv"
: >"$RECORDS_TSV"
for domain in alpha beta gamma; do
  i=0
  while [ "$i" -lt 84 ]; do
    split=calibration
    [ "$i" -lt 60 ] || split=holdout
    sha=$(obj_write "$domain" "$i" "$PRISTINE/cache")
    printf '%s-%s\t%s\t%s\t%s\n' "$domain" "$i" "$domain" "$split" "$sha" >>"$RECORDS_TSV"
    i=$((i + 1))
  done
done

jq -Rn '
  {format_version: 1,
   sources: [{id: "src-alpha"}, {id: "src-beta"}, {id: "src-gamma"}],
   records: [inputs | split("\t")
     | {id: .[0], source_id: ("src-" + .[1]), domain: .[1], split: .[2],
        asset_sha256: .[3], human_rating: 3.2}]}' \
  <"$RECORDS_TSV" >"$PRISTINE/split-manifest.json"

# 24 pairs from the alpha+beta holdout rows (12 disjoint pairs per domain).
awk -F'\t' '$3 == "holdout" && ($2 == "alpha" || $2 == "beta")' "$RECORDS_TSV" |
  jq -Rn '
    [inputs | split("\t")] as $rows
    | {schema_version: "taste-pair-manifest/v1",
       pairs: [range(0; 24) as $k
         | {pair_id: ("pair-" + ($k | tostring)),
            a: {id: $rows[2 * $k][0], asset_sha256: $rows[2 * $k][3]},
            b: {id: $rows[2 * $k + 1][0], asset_sha256: $rows[2 * $k + 1][3]}}]}' \
  >"$PRISTINE/pairs.json"

mk_panel_receipt "$PRISTINE/panel/judge-1.json" prov-a model-a 17
mk_panel_receipt "$PRISTINE/panel/judge-2.json" prov-b model-b 19
mk_panel_receipt "$PRISTINE/panel/judge-3.json" prov-c model-c 21
mk_panel_receipt "$PRISTINE/panel/judge-4.json" prov-d model-d 18
mk_panel_receipt "$PRISTINE/panel/judge-5.json" prov-e model-e 24

printf 'frozen protocol body\n' >"$PRISTINE/frozen/protocol.md"
printf 'frozen prompt bundle\n' >"$PRISTINE/frozen/prompts.json"
printf 'frozen twenty briefs\n' >"$PRISTINE/frozen/briefs.json"

jq -n --arg msha "$(hf "$PRISTINE/split-manifest.json")" '
  {schema_version: "taste-source-acquisition/v1", status: "BUILT",
   classification: "production",
   sources: [{id: "src-alpha", dataset_pid: "doi:10.7910/DVN/9FKSQI"},
             {id: "src-beta", dataset_pid: "doi:10.7910/DVN/XOI0HI"},
             {id: "src-gamma", dataset_pid: "doi:10.7910/DVN/Z7KLIH"}],
   manifest_sha256: $msha, reason_codes: []}' >"$PRISTINE/source-receipt.json"

for cli in fixchrome fixnode fixclaude; do
  printf '#!/bin/sh\nexit 0\n' >"$PRISTINE/clis/$cli"
  chmod +x "$PRISTINE/clis/$cli"
done

write_config() { # write_config WORLD [MIN_FREE_BYTES]
  local w=$1 min=${2:-1}
  jq -n \
    --arg w "$w" --argjson min "$min" --arg baseline "$BASELINE_REV" \
    --arg psha "$(hf "$w/frozen/protocol.md")" \
    --arg prsha "$(hf "$w/frozen/prompts.json")" \
    --arg bsha "$(hf "$w/frozen/briefs.json")" '
    {schema_version: "taste-benchmark-preflight/v1",
     run_id: "c41-source-calibration-20260812-a1",
     source_receipts: [($w + "/source-receipt.json")],
     split_manifest: ($w + "/split-manifest.json"),
     cache_dir: ($w + "/cache"),
     pair_manifests: [($w + "/pairs.json")],
     panel_receipts: [($w + "/panel/judge-1.json"), ($w + "/panel/judge-2.json"),
                      ($w + "/panel/judge-3.json"), ($w + "/panel/judge-4.json"),
                      ($w + "/panel/judge-5.json")],
     frozen: {protocol_path: ($w + "/frozen/protocol.md"), protocol_sha256: $psha,
              prompt_path: ($w + "/frozen/prompts.json"), prompt_sha256: $prsha,
              brief_path: ($w + "/frozen/briefs.json"), brief_sha256: $bsha,
              baseline_revision: $baseline},
     required_clis: ["fixchrome", "fixnode", "fixclaude"],
     min_free_disk_bytes: $min}' >"$w/config.json"
}

rebind_source() { # recompute the split-manifest binding after a manifest edit
  jq_edit "$1/source-receipt.json" '.manifest_sha256 = $msha' \
    --arg msha "$(hf "$1/split-manifest.json")"
}

mk_world() { # mk_world NAME -> echoes world dir
  local w="$TMPDIR_TEST/$1"
  rm -rf "$w"
  cp -R "$PRISTINE" "$w"
  write_config "$w"
  printf '%s' "$w"
}

RC=0
OUT=''
run_pf() { # run_pf WORLD
  RC=0
  OUT=$(PATH="$1/clis:$PATH" "$BIN" run "$1/config.json" "$1/receipt.json" 2>&1) || RC=$?
}

expect_code() { # expect_code WORLD CODE LABEL
  run_pf "$1"
  [ "$RC" -eq 1 ] || fail "$3: expected rc 1, got $RC ($OUT)"
  jq -e --arg c "$2" '.status == "NOT-READY" and .closure_sha256 == null
    and ([.reason_codes[] | select(startswith($c))] | length > 0)' \
    "$1/receipt.json" >/dev/null || fail "$3: missing code $2 in $(cat "$1/receipt.json")"
  ok
}

# --- happy path -----------------------------------------------------------
W=$(mk_world happy)
run_pf "$W"
[ "$RC" -eq 0 ] || fail "happy: expected rc 0, got $RC ($OUT)"
case "$OUT" in READY\ *) ;; *) fail "happy: stdout not READY: $OUT" ;; esac
ok

jq -e '
  .schema_version == "taste-benchmark-preflight/v1"
  and .status == "READY" and .ready == true
  and .run_id == "c41-source-calibration-20260812-a1"
  and .reason_codes == []
  and .human_certified == false
  and (.closure_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
  and .checks.split_records == 252
  and .checks.calibration_records == 180
  and .checks.holdout_records == 72
  and .checks.cache_objects == 252
  and (.checks.cache_bytes | type == "number" and . > 0)
  and .checks.pairs == 24
  and .checks.panel_eligible == 5
  and (.tool.fingerprint | test("^[0-9a-f]{64}$"))' \
  "$W/receipt.json" >/dev/null || fail "happy: receipt shape: $(cat "$W/receipt.json")"
ok

CLOSURE_1=$(jq -r '.closure_sha256' "$W/receipt.json")
run_pf "$W"
[ "$RC" -eq 0 ] || fail "determinism: rerun failed"
[ "$(jq -r '.closure_sha256' "$W/receipt.json")" = "$CLOSURE_1" ] ||
  fail "determinism: closure changed across identical reruns"
ok

W=$(mk_world closure-shift)
printf 'different frozen briefs\n' >"$W/frozen/briefs.json"
write_config "$W"
run_pf "$W"
[ "$RC" -eq 0 ] || fail "closure-shift: expected READY, got $RC ($OUT)"
[ "$(jq -r '.closure_sha256' "$W/receipt.json")" != "$CLOSURE_1" ] ||
  fail "closure-shift: closure did not track changed evidence"
ok

# --- usage / config attacks ----------------------------------------------
RC=0; "$BIN" >/dev/null 2>&1 || RC=$?
[ "$RC" -eq 2 ] || fail "usage: expected rc 2, got $RC"
ok

W=$(mk_world config-not-json)
printf 'not json' >"$W/config.json"
expect_code "$W" CONFIG_INVALID config-not-json

W=$(mk_world config-unknown-key)
jq_edit "$W/config.json" '. + {surprise: 1}'
expect_code "$W" CONFIG_INVALID config-unknown-key

# --- source receipt attacks -----------------------------------------------
W=$(mk_world source-fixture)
jq_edit "$W/source-receipt.json" '.classification = "fixture"'
expect_code "$W" SOURCE_RECEIPT_FIXTURE source-fixture

W=$(mk_world source-doi-missing)
jq_edit "$W/source-receipt.json" '.sources |= .[0:2]'
expect_code "$W" SOURCE_DOI_MISSING source-doi-missing

W=$(mk_world source-unbound)
jq_edit "$W/source-receipt.json" '.manifest_sha256 = ("ab" * 32)'
expect_code "$W" SOURCE_SPLIT_UNBOUND source-unbound

W=$(mk_world source-not-json)
printf '{' >"$W/source-receipt.json"
expect_code "$W" SOURCE_RECEIPT_INVALID source-not-json

# --- split attacks --------------------------------------------------------
W=$(mk_world split-quota)
jq_edit "$W/split-manifest.json" 'del(.records[0])'
rebind_source "$W"
expect_code "$W" SPLIT_QUOTA split-quota

W=$(mk_world split-duplicate-id)
jq_edit "$W/split-manifest.json" '.records[1].id = .records[0].id'
rebind_source "$W"
expect_code "$W" SPLIT_INVALID split-duplicate-id

# --- cache attacks --------------------------------------------------------
SHA0=$(awk -F'\t' 'NR == 1 {print $4}' "$PRISTINE/records.tsv")

W=$(mk_world cache-missing)
rm "$W/cache/objects/${SHA0:0:2}/$SHA0"
expect_code "$W" CACHE_OBJECT_INVALID cache-missing

W=$(mk_world cache-tampered)
printf 'x' >>"$W/cache/objects/${SHA0:0:2}/$SHA0"
expect_code "$W" CACHE_OBJECT_INVALID cache-tampered

W=$(mk_world cache-symlink)
rm "$W/cache/objects/${SHA0:0:2}/$SHA0"
ln -s /etc/hosts "$W/cache/objects/${SHA0:0:2}/$SHA0"
expect_code "$W" CACHE_OBJECT_INVALID cache-symlink

# --- pair attacks ---------------------------------------------------------
W=$(mk_world pairs-short)
jq_edit "$W/pairs.json" '.pairs |= .[0:23]'
expect_code "$W" PAIRS_INVALID pairs-short

W=$(mk_world pairs-leakage)
CAL_SHA=$(jq -r '.records[] | select(.id == "alpha-0") | .asset_sha256' "$W/split-manifest.json")
jq_edit "$W/pairs.json" '.pairs[0].a = {id: "alpha-0", asset_sha256: $s}' --arg s "$CAL_SHA"
expect_code "$W" PAIRS_INVALID pairs-leakage

W=$(mk_world pairs-unknown-id)
jq_edit "$W/pairs.json" '.pairs[0].a.id = "ghost-1"'
expect_code "$W" PAIRS_INVALID pairs-unknown-id

W=$(mk_world pairs-sha-mismatch)
jq_edit "$W/pairs.json" '.pairs[0].a.asset_sha256 = ("ee" * 32)'
expect_code "$W" PAIRS_INVALID pairs-sha-mismatch

# --- panel attacks --------------------------------------------------------
W=$(mk_world panel-insufficient)
jq_edit "$W/config.json" '.panel_receipts |= .[0:4]'
expect_code "$W" PANEL_INSUFFICIENT panel-insufficient

W=$(mk_world panel-duplicate-config)
cp "$W/panel/judge-4.json" "$W/panel/judge-5.json"
expect_code "$W" PANEL_DUPLICATE_CONFIG panel-duplicate-config

W=$(mk_world panel-audit-correct)
mk_panel_receipt "$W/panel/judge-5.json" prov-e model-e 16
jq_edit "$W/panel/judge-5.json" '.eligible = true | .status = "eligible"'
expect_code "$W" PANEL_AUDIT_MISMATCH panel-audit-correct

W=$(mk_world panel-audit-wilson)
jq_edit "$W/panel/judge-5.json" '.wilson_lower_bound = 0.9'
expect_code "$W" PANEL_AUDIT_MISMATCH panel-audit-wilson

W=$(mk_world panel-audit-side)
jq_edit "$W/panel/judge-5.json" '.side_probe_exact_binomial_p = 0.01'
expect_code "$W" PANEL_AUDIT_MISMATCH panel-audit-side

W=$(mk_world panel-audit-mirror)
jq_edit "$W/panel/judge-5.json" '.mirror_contradictions = 2'
expect_code "$W" PANEL_AUDIT_MISMATCH panel-audit-mirror

W=$(mk_world panel-overclaim)
jq_edit "$W/panel/judge-5.json" '.human_certified = true'
expect_code "$W" HUMAN_OVERCLAIM panel-overclaim

W=$(mk_world panel-incoherent)
jq_edit "$W/panel/judge-5.json" '.holdout_labels_sha256 = ("cd" * 32)'
expect_code "$W" PANEL_INCOHERENT panel-incoherent

W=$(mk_world panel-not-json)
printf '[' >"$W/panel/judge-5.json"
expect_code "$W" PANEL_RECEIPT_INVALID panel-not-json

# --- frozen hash / baseline attacks ---------------------------------------
W=$(mk_world frozen-protocol-drift)
printf 'tampered protocol\n' >"$W/frozen/protocol.md"
expect_code "$W" FROZEN_HASH_MISMATCH frozen-protocol-drift

W=$(mk_world baseline-drift)
jq_edit "$W/config.json" '.frozen.baseline_revision = ("f" * 40)'
expect_code "$W" BASELINE_REVISION_MISMATCH baseline-drift

# --- CLI / disk attacks ---------------------------------------------------
W=$(mk_world cli-missing)
rm "$W/clis/fixclaude"
expect_code "$W" CLI_MISSING cli-missing

W=$(mk_world disk-budget)
write_config "$W" 888888888888888888
expect_code "$W" DISK_BUDGET disk-budget

# --- never partially pass: independent failures accumulate ----------------
W=$(mk_world multi-fail)
rm "$W/clis/fixclaude"
write_config "$W" 888888888888888888
run_pf "$W"
[ "$RC" -eq 1 ] || fail "multi-fail: expected rc 1, got $RC"
jq -e '.status == "NOT-READY" and .closure_sha256 == null
  and ([.reason_codes[] | select(startswith("CLI_MISSING"))] | length > 0)
  and ([.reason_codes[] | select(startswith("DISK_BUDGET"))] | length > 0)' \
  "$W/receipt.json" >/dev/null || fail "multi-fail: codes did not accumulate"
ok

printf 'PASS test-taste-benchmark-preflight assertions=%s\n' "$ASSERTIONS"
