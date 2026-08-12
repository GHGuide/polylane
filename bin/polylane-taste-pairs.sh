#!/usr/bin/env bash
# polylane-taste-pairs.sh — deterministic held-out mirrored calibration pairs.
#
# Compiles the frozen c41 judge-calibration pair set from a held-out selection
# manifest carrying native-scale human aesthetics ratings. Eligible pairs are
# same-domain, use each source image at most once, and are unambiguous: mean
# delta >= 1.00 on the native scale AND a seeded 1000-resample 95% bootstrap
# interval of the mean difference that excludes zero. Exactly 24 mirrored pairs
# are frozen with a balanced 12/12 gold-left/gold-right side assignment; every
# pair doubles as a side probe and a mirror probe (>= 12 / >= 8 quotas). The
# judge-visible pair manifest exposes only opaque stimulus ids and asset
# digests; the side assignment and the answer key are sealed in two separate
# hash-bound files. This compiler never invokes or scores a judge.
# Fail-closed. Bash 3.2 + jq + shasum.
set -euo pipefail

PAIR_QUOTA=24
DELTA_MIN='1.0'
BOOT_N=1000
BOOT_ALPHA='0.05'
SIDE_PROBE_MIN=12
MIRROR_PROBE_MIN=8
MIN_RATERS=5
# judge/provider identity that may never reach judge-visible stimuli.
PROVIDER_RE='(^|[^a-z0-9])(claude|gpt-?[0-9]|anthropic|openai|gemini|llama|mistral|copilot|codex|opus|sonnet|haiku|fable)($|[^a-z0-9])'

usage() {
  echo "usage: polylane-taste-pairs.sh build INPUT.json SEED OUTDIR" >&2
  echo "       polylane-taste-pairs.sh verify OUTDIR" >&2
}

die() { echo "TASTE-PAIRS: $*" >&2; exit 2; }

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
sha256_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

regular_json_without_duplicate_keys() {
  local duplicates
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  jq -e . "$1" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$1" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

validate_input() {
  local input="$1"
  regular_json_without_duplicate_keys "$input" || die "input is not safe regular JSON"
  jq -e --argjson min_raters "$MIN_RATERS" '
    def hash64: type == "string" and test("^[0-9a-f]{64}$");
    def stable_id: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    type == "object"
    and ((keys - ["corpus_receipt_sha256", "items", "partition", "run_id", "scale", "schema_version"]) == [])
    and .schema_version == "taste-pair-input/v1"
    and (.run_id | type == "string" and length > 0)
    and (.corpus_receipt_sha256 | hash64)
    and .partition == "held_out"
    and (.scale | type == "object" and ((keys | sort) == ["max", "min"])
      and (.min | type == "number") and (.max | type == "number") and .max > .min)
    and (.scale.min as $lo | .scale.max as $hi
      | (.items | type == "array" and length >= 2)
      and all(.items[];
        type == "object"
        and ((keys - ["asset_sha256", "domain", "id", "ratings"]) == [])
        and (.id | stable_id)
        and (.domain | stable_id)
        and (.asset_sha256 | hash64)
        and (.ratings | type == "array" and length >= $min_raters
          and all(.[]; type == "number" and . >= $lo and . <= $hi))))
    and ([.items[].id] | length == (unique | length))
    and ([.items[].asset_sha256] | length == (unique | length))
    and ([paths(type == "boolean")] | length == 0)
  ' "$input" >/dev/null 2>&1 || die "input violates the held-out pair-input contract"
}

# bootstrap_ci RATINGS_HIGH_CSV RATINGS_LOW_CSV SEED_INT -> "ci_low ci_high"
# Seeded Park–Miller resampling; percentile interval at order statistics
# 25/976 of the 1000 sorted mean differences (frozen convention).
bootstrap_ci() {
  awk -v a="$1" -v b="$2" -v seed="$3" -v n="$BOOT_N" 'BEGIN {
    nA = split(a, A, ","); nB = split(b, B, ",")
    state = seed
    for (r = 0; r < n; r++) {
      sa = 0
      for (i = 0; i < nA; i++) { state = (16807 * state) % 2147483647; sa += A[(state % nA) + 1] }
      sb = 0
      for (i = 0; i < nB; i++) { state = (16807 * state) % 2147483647; sb += B[(state % nB) + 1] }
      printf "%.6f\n", sa / nA - sb / nB
    }
  }' | LC_ALL=C sort -g | awk 'NR == 25 { lo = $0 } NR == 976 { hi = $0 } END { printf "%s %s", lo, hi }'
}

BUILD_TMP=""
cleanup_build() { [ -n "$BUILD_TMP" ] && rm -rf "$BUILD_TMP"; return 0; }

build() {
  local input="$1" seed="$2" out="$3"
  [ -n "$seed" ] || die "seed must not be empty"
  validate_input "$input"

  case "$out" in '' | /) die "output path is unsafe" ;; esac
  [ ! -L "$out" ] || die "output must not be a symlink"
  local out_parent out_name
  out_parent=$(cd "$(dirname "$out")" && pwd -P) || die "output parent does not exist"
  out_name=$(basename "$out")
  { [ "$out_name" != . ] && [ "$out_name" != .. ]; } || die "output path is unsafe"

  local run_id input_sha corpus_receipt items_available
  run_id=$(jq -r .run_id "$input")
  input_sha=$(sha256_file "$input")
  corpus_receipt=$(jq -r .corpus_receipt_sha256 "$input")
  items_available=$(jq '.items | length' "$input")

  BUILD_TMP=$(mktemp -d "$out_parent/.polylane-pairs.XXXXXX") || die "could not create atomic workspace"
  trap cleanup_build EXIT HUP INT TERM
  local tmp="$BUILD_TMP"

  # Same-domain candidates ordered high-mean first, above the delta floor.
  jq -r '
    [.items[] | . + {mean: ((.ratings | add) / (.ratings | length))}] as $it
    | [range(0; $it | length) as $i | range($i + 1; $it | length) as $j
       | $it[$i] as $a | $it[$j] as $b
       | select($a.domain == $b.domain)
       | (if $a.mean >= $b.mean then {h: $a, l: $b} else {h: $b, l: $a} end)
       | select(.h.mean - .l.mean >= 0.999999999)
       | [.h.id, .l.id, .h.domain] | @tsv]
    | .[]' "$input" > "$tmp/candidates.tsv"
  local candidates_considered
  candidates_considered=$(grep -c . "$tmp/candidates.tsv" || true)

  # Deterministic seed-keyed candidate order.
  : > "$tmp/ordered.tsv"
  local high low domain digest
  while IFS=$'\t' read -r high low domain; do
    digest=$(sha256_text "$seed|order|$high|$low")
    printf '%s\t%s\t%s\t%s\n' "$digest" "$high" "$low" "$domain" >> "$tmp/ordered.tsv"
  done < "$tmp/candidates.tsv"
  LC_ALL=C sort -k1,1 "$tmp/ordered.tsv" > "$tmp/sorted.tsv"

  # Greedy unique-image selection with the bootstrap ambiguity gate.
  local used='|' selected=0 pair_key pair_id boot_seed ci ci_low ci_high
  local ratings_high ratings_low mean_high mean_low delta
  : > "$tmp/pairs.jsonl"
  while IFS=$'\t' read -r digest high low domain; do
    [ "$selected" -lt "$PAIR_QUOTA" ] || break
    case "$used" in *"|$high|"*) continue ;; esac
    case "$used" in *"|$low|"*) continue ;; esac
    ratings_high=$(jq -r --arg id "$high" '.items[] | select(.id == $id) | .ratings | join(",")' "$input")
    ratings_low=$(jq -r --arg id "$low" '.items[] | select(.id == $id) | .ratings | join(",")' "$input")
    pair_key="$high|$low"
    boot_seed=$(( (16#$(sha256_text "$seed|bootstrap|$pair_key" | cut -c1-12) % 2147483646) + 1 ))
    ci=$(bootstrap_ci "$ratings_high" "$ratings_low" "$boot_seed")
    ci_low=${ci%% *}; ci_high=${ci##* }
    awk -v lo="$ci_low" 'BEGIN { exit !(lo > 0) }' || continue
    mean_high=$(printf '%s' "$ratings_high" | awk -F, '{ s = 0; for (i = 1; i <= NF; i++) s += $i; printf "%.6f", s / NF }')
    mean_low=$(printf '%s' "$ratings_low" | awk -F, '{ s = 0; for (i = 1; i <= NF; i++) s += $i; printf "%.6f", s / NF }')
    delta=$(awk -v h="$mean_high" -v l="$mean_low" 'BEGIN { printf "%.6f", h - l }')
    pair_id="pair-$(sha256_text "$seed|pair|$pair_key" | cut -c1-12)"
    jq -nc --arg pair_id "$pair_id" --arg domain "$domain" \
      --arg high "$high" --arg low "$low" \
      --argjson rank "$selected" \
      --argjson mean_high "$mean_high" --argjson mean_low "$mean_low" \
      --argjson delta "$delta" --argjson ci_low "$ci_low" --argjson ci_high "$ci_high" \
      '{pair_id: $pair_id, domain: $domain, high: $high, low: $low, rank: $rank,
        mean_high: $mean_high, mean_low: $mean_low, delta: $delta,
        ci_low: $ci_low, ci_high: $ci_high}' >> "$tmp/pairs.jsonl"
    used="$used$high|$low|"
    selected=$((selected + 1))
  done < "$tmp/sorted.tsv"
  [ "$selected" -eq "$PAIR_QUOTA" ] || \
    die "pair quota unmet: $selected of $PAIR_QUOTA unambiguous unique-image same-domain pairs"

  # Opaque stimulus ids for the 48 frozen items.
  jq -s --arg seed "$seed" --slurpfile input "$input" '
    ($input[0].items | map({key: .id, value: .}) | from_entries) as $items
    | map(. + {
        high_asset: $items[.high].asset_sha256,
        low_asset: $items[.low].asset_sha256
      })' "$tmp/pairs.jsonl" > "$tmp/enriched.json"
  local stim_map='{}' item_id asset stim
  while IFS=$'\t' read -r item_id asset; do
    stim="stim-$(sha256_text "$seed|stimulus|$item_id|$asset" | cut -c1-12)"
    stim_map=$(printf '%s' "$stim_map" | jq --arg k "$item_id" --arg v "$stim" '. + {($k): $v}')
  done < <(jq -r '.[] | [.high, .high_asset], [.low, .low_asset] | @tsv' "$tmp/enriched.json")
  [ "$(printf '%s' "$stim_map" | jq '[.[]] | length')" = \
    "$(printf '%s' "$stim_map" | jq '[.[]] | unique | length')" ] || die "stimulus id collision"

  # Sides: acceptance ranks 0..11 place gold left; 12..23 place gold right.
  jq --argjson stim "$stim_map" '
    map(. + {
      gold_stim: $stim[.high], low_stim: $stim[.low],
      left: (if .rank < 12 then $stim[.high] else $stim[.low] end),
      right: (if .rank < 12 then $stim[.low] else $stim[.high] end),
      left_item: (if .rank < 12 then .high else .low end),
      right_item: (if .rank < 12 then .low else .high end)
    }) | sort_by(.pair_id)' "$tmp/enriched.json" > "$tmp/final.json"

  mkdir -p "$tmp/publish"
  jq --arg schema 'taste-pair-manifest/v1' --arg run "$run_id" '
    {schema_version: $schema, run_id: $run, partition: "held_out",
     pair_count: length,
     pairs: map({
       pair_id, domain,
       primary: {left: .left, right: .right},
       mirror: {left: .right, right: .left},
       stimuli: {(.left): {asset_sha256: (if .left == .gold_stim then .high_asset else .low_asset end)},
                 (.right): {asset_sha256: (if .right == .gold_stim then .high_asset else .low_asset end)}}
     })}' "$tmp/final.json" > "$tmp/publish/pair-manifest.json"

  # Leakage gates on the judge-visible bytes: provider identity and item ids.
  LC_ALL=C tr '[:upper:]' '[:lower:]' < "$tmp/publish/pair-manifest.json" > "$tmp/manifest.lower"
  ! grep -Eq "$PROVIDER_RE" "$tmp/manifest.lower" || \
    die "judge/provider identity leaked into stimuli"
  while IFS= read -r item_id; do
    ! grep -qF -- "$item_id" "$tmp/publish/pair-manifest.json" || \
      die "source item identity leaked into stimuli: $item_id"
  done < <(jq -r '.items[].id' "$input")

  jq --arg schema 'taste-pair-sides/v1' --arg run "$run_id" '
    {schema_version: $schema, run_id: $run,
     bindings: (map(
       {stimulus_id: .gold_stim, item_id: .high, asset_sha256: .high_asset, domain},
       {stimulus_id: .low_stim, item_id: .low, asset_sha256: .low_asset, domain})
       | sort_by(.stimulus_id)),
     pairs: map({pair_id, left_item_id: .left_item, right_item_id: .right_item})}' \
    "$tmp/final.json" > "$tmp/publish/side-assignment.sealed.json"

  jq --arg schema 'taste-pair-answers/v1' --arg run "$run_id" \
    --argjson boot_n "$BOOT_N" --argjson alpha "$BOOT_ALPHA" '
    {schema_version: $schema, run_id: $run,
     pairs: map({pair_id, gold_stimulus_id: .gold_stim,
                 high_item_id: .high, low_item_id: .low,
                 mean_high, mean_low, delta,
                 bootstrap: {n: $boot_n, alpha: $alpha, ci_low, ci_high}}),
     probes: {side_probe_pair_ids: map(.pair_id),
              mirror_probe_pair_ids: map(.pair_id)}}' \
    "$tmp/final.json" > "$tmp/publish/answer-key.sealed.json"

  local manifest_sha sides_sha answers_sha validator_fp now
  manifest_sha=$(sha256_file "$tmp/publish/pair-manifest.json")
  sides_sha=$(sha256_file "$tmp/publish/side-assignment.sealed.json")
  answers_sha=$(sha256_file "$tmp/publish/answer-key.sealed.json")
  validator_fp=$(sha256_file "$0")
  now=${TASTE_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
  jq -n \
    --arg schema 'taste-pair-receipt/v1' --arg run "$run_id" --arg now "$now" \
    --arg seed "$seed" --arg vfp "$validator_fp" \
    --arg input_sha "$input_sha" --arg corpus "$corpus_receipt" \
    --arg manifest_sha "$manifest_sha" --arg sides_sha "$sides_sha" \
    --arg answers_sha "$answers_sha" \
    --argjson quota "$PAIR_QUOTA" --argjson delta_min "$DELTA_MIN" \
    --argjson boot_n "$BOOT_N" --argjson alpha "$BOOT_ALPHA" \
    --argjson side_min "$SIDE_PROBE_MIN" --argjson mirror_min "$MIRROR_PROBE_MIN" \
    --argjson min_raters "$MIN_RATERS" \
    --argjson items_available "$items_available" \
    --argjson candidates "$candidates_considered" '
    {schema_version: $schema,
     receipt_version: "polylane.taste.pair-builder.v1",
     status: "VALIDATED",
     run_id: $run,
     executed_at: $now,
     seed: $seed,
     validator: {id: "polylane-taste-pairs", fingerprint: $vfp},
     input_sha256: $input_sha,
     inputs: {pair_input_sha256: $input_sha, corpus_receipt_sha256: $corpus},
     thresholds: {pair_quota: $quota, delta_min: $delta_min,
                  bootstrap_n: $boot_n, bootstrap_alpha: $alpha,
                  side_probe_min: $side_min, mirror_probe_min: $mirror_min,
                  min_raters: $min_raters},
     counts: {pairs: $quota, side_left_gold: 12, side_right_gold: 12,
              side_probe_n: $quota, mirror_probe_n: $quota,
              unique_assets: ($quota * 2),
              items_available: $items_available,
              candidates_considered: $candidates},
     outputs: {pair_manifest_sha256: $manifest_sha,
               side_assignment_sha256: $sides_sha,
               answer_key_sha256: $answers_sha},
     human_certified: false,
     reason_codes: []}' > "$tmp/publish/pair-receipt.json"

  # Atomic publish.
  local backup=""
  if [ -e "$out" ]; then backup="$out_parent/.$out_name.previous.$$"; mv "$out" "$backup"; fi
  mv "$tmp/publish" "$out"
  [ -z "$backup" ] || rm -rf "$backup"
  trap - EXIT HUP INT TERM
  rm -rf "$tmp"; BUILD_TMP=""
}

verify() {
  local out="$1"
  [ -d "$out" ] && [ ! -L "$out" ] || die "pair bundle directory is unavailable"
  local manifest="$out/pair-manifest.json" sides="$out/side-assignment.sealed.json"
  local answers="$out/answer-key.sealed.json" receipt="$out/pair-receipt.json"
  local f
  for f in "$manifest" "$sides" "$answers" "$receipt"; do
    regular_json_without_duplicate_keys "$f" || die "invalid artifact JSON: $f"
  done
  jq -e '.schema_version == "taste-pair-receipt/v1"' "$receipt" >/dev/null 2>&1 || die "unknown receipt schema"

  # Hash bindings.
  [ "$(sha256_file "$manifest")" = "$(jq -r '.outputs.pair_manifest_sha256' "$receipt")" ] || die "pair manifest does not bind receipt"
  [ "$(sha256_file "$sides")" = "$(jq -r '.outputs.side_assignment_sha256' "$receipt")" ] || die "side assignment does not bind receipt"
  [ "$(sha256_file "$answers")" = "$(jq -r '.outputs.answer_key_sha256' "$receipt")" ] || die "answer key does not bind receipt"

  # Frozen thresholds and probe quotas.
  jq -e --argjson quota "$PAIR_QUOTA" --argjson delta_min "$DELTA_MIN" \
    --argjson boot_n "$BOOT_N" --argjson alpha "$BOOT_ALPHA" \
    --argjson side_min "$SIDE_PROBE_MIN" --argjson mirror_min "$MIRROR_PROBE_MIN" '
    .thresholds.pair_quota == $quota and .thresholds.delta_min == $delta_min
    and .thresholds.bootstrap_n == $boot_n and .thresholds.bootstrap_alpha == $alpha
    and .thresholds.side_probe_min == $side_min and .thresholds.mirror_probe_min == $mirror_min
    and .counts.side_probe_n >= $side_min and .counts.mirror_probe_n >= $mirror_min
    and .human_certified == false' "$receipt" >/dev/null 2>&1 || die "receipt thresholds drifted from the frozen contract"

  # Judge-visible manifest: quota, unique stimuli, exact mirror, no leakage.
  jq -e --argjson quota "$PAIR_QUOTA" '
    .schema_version == "taste-pair-manifest/v1"
    and .partition == "held_out"
    and .pair_count == $quota and (.pairs | length) == $quota
    and ([.pairs[].primary.left, .pairs[].primary.right] | length == (unique | length))
    and all(.pairs[];
      .primary.left != .primary.right
      and .mirror.left == .primary.right and .mirror.right == .primary.left
      and ((.stimuli | keys | sort) == ([.primary.left, .primary.right] | sort)))
    and ([paths | .[] | select(type == "string")
          | select(IN("gold_stimulus_id", "gold", "delta", "ratings", "mean", "human_rating", "item_id", "answer"))] | length == 0)
  ' "$manifest" >/dev/null 2>&1 || die "pair manifest violates the frozen judge-visible contract"
  LC_ALL=C tr '[:upper:]' '[:lower:]' < "$manifest" | { ! grep -Eq "$PROVIDER_RE"; } || die "judge/provider identity leaked into stimuli"
  local item_id
  while IFS= read -r item_id; do
    ! grep -qF -- "$item_id" "$manifest" || die "source item identity leaked into stimuli: $item_id"
  done < <(jq -r '.bindings[].item_id' "$sides")

  # Sealed files: separation, unique sources, same-domain pairs, side balance,
  # and the ambiguity floors on every frozen pair.
  jq -e -s --argjson quota "$PAIR_QUOTA" --argjson boot_n "$BOOT_N" --argjson alpha "$BOOT_ALPHA" '
    .[0] as $m | .[1] as $s | .[2] as $a |
    ($s.bindings | map({key: .stimulus_id, value: .}) | from_entries) as $bind |
    ($a.pairs | map({key: .pair_id, value: .}) | from_entries) as $gold |
    $s.schema_version == "taste-pair-sides/v1"
    and $a.schema_version == "taste-pair-answers/v1"
    and ($s.bindings | length == ($quota * 2))
    and ([$s.bindings[].item_id] | length == (unique | length))
    and ([$s.bindings[].asset_sha256] | length == (unique | length))
    and ([$s.bindings[].stimulus_id] | sort) == ([$m.pairs[].primary.left, $m.pairs[].primary.right] | sort)
    and ([$m.pairs[].pair_id] | sort) == ([$a.pairs[].pair_id] | sort)
    and ([$m.pairs[].pair_id] | sort) == ([$s.pairs[].pair_id] | sort)
    and all($m.pairs[]; $bind[.primary.left].domain == .domain and $bind[.primary.right].domain == .domain)
    and ([$m.pairs[] | select($gold[.pair_id].gold_stimulus_id == .primary.left)] | length) == ($quota / 2)
    and all($a.pairs[];
      .delta >= 1.0 and .bootstrap.ci_low > 0
      and .bootstrap.n == $boot_n and .bootstrap.alpha == $alpha
      and .mean_high > .mean_low)
    and ($a.probes.side_probe_pair_ids | length) >= 12
    and ($a.probes.mirror_probe_pair_ids | length) >= 8
  ' "$manifest" "$sides" "$answers" >/dev/null 2>&1 || die "sealed side/answer contract violated"
  return 0
}

main() {
  command -v jq >/dev/null 2>&1 || die "jq is required"
  command -v shasum >/dev/null 2>&1 || die "shasum is required"
  case "${1:-}" in
    build) [ "$#" -eq 4 ] || { usage; exit 2; }; build "$2" "$3" "$4" ;;
    verify) [ "$#" -eq 2 ] || { usage; exit 2; }; verify "$2" ;;
    *) usage; exit 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
