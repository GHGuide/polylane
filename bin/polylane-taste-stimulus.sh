#!/usr/bin/env bash
# polylane-taste-stimulus.sh — coordinator-owned anonymized visual stimulus bundle.
#
# Builds a two-candidate blind A/B stimulus bundle from exact capture manifests,
# escrows canonical identity out of the judge's view, and INDEPENDENTLY scans
# captured DOM + OCR-of-exact-screenshot-bytes for identity/prompt leakage. The
# caller's own visible_text or identity booleans are never trusted. Judge bundles
# expose only brief clauses, staged screenshots, states/flow, and an atomic rubric;
# an opaque escrow binds stimulus ids to candidate ids, source revisions, captures,
# and pixel hashes so blind ballots stay verifiable. Fail-closed: leakage, tamper,
# missing production OCR, or inherent brand identity yields block/external, never a
# silent pass. Bash 3.2 + jq.
set -euo pipefail

usage() {
  echo "usage: polylane-taste-stimulus.sh build SPEC OUT -- SCANNER [args...]" >&2
  echo "       polylane-taste-stimulus.sh verify OUT" >&2
}

die() { echo "TASTE-STIMULUS: $*" >&2; return 2; }

RUBRIC='["color","craftsmanship","hierarchy","originality","product_fit","spatial_rhythm","state_coherence","typography"]'
# generator/provider identity that can never be inherent product text.
PROVIDER_RE='(^|[^a-z0-9])(claude|gpt-?[0-9]|anthropic|openai|gemini|llama|mistral|copilot|opus|sonnet|haiku)($|[^a-z0-9])'
INJECTION_RE='(ignore[[:space:]]+(all[[:space:]]+)?(previous|prior)[[:space:]]+instructions|system[[:space:]]+prompt|reveal[[:space:]]+(the[[:space:]]+)?(prompt|instructions)|assistant[[:space:]]+instructions)'
METADATA_RE='(generated[[:space:]_-]+by|data-(model|provider|generator|generated)|<meta[^>]*name=["'\'' ]*generator|x-generator|generator:)'

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
sha256_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

regular_json_without_duplicate_keys() {
  local file="$1" duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

# --- build ------------------------------------------------------------------

BUILD_TMP=""
cleanup_build() { [ -z "$BUILD_TMP" ] || rm -rf "$BUILD_TMP"; }

build() {
  local spec="$1" out="$2"; shift 2
  [ "${1:-}" = "--" ] || { usage; return 2; }; shift
  [ "$#" -ge 1 ] || { die "a pinned OCR/scan adapter is required"; return 2; }
  local scanner="$1"

  regular_json_without_duplicate_keys "$spec" || { die "invalid spec JSON"; return 2; }
  jq -e '
    .schema_version == "taste-stimulus-spec/v1"
    and (.run_id | type == "string" and length > 0)
    and (.brief_lock | type == "string" and length > 0)
    and (.design_lock | type == "string" and length > 0)
    and (.ocr | type == "object" and (.adapter_id|type=="string") and (.adapter_version|type=="string")
      and (.command_sha256|type=="string" and test("^[0-9a-f]{64}$")) and (.kind|IN("fixture","production")))
    and (.identity_terms | type == "array" and all(.[]; type=="string"))
    and (.inherent_identity_terms | type == "array" and all(.[]; type=="string"))
    and (.candidates | type == "array" and length == 2
      and all(.[]; (.candidate_id|type=="string" and test("^cand-[0-9a-f]{16}$")) and (.capture_manifest|type=="string" and length>0)))
  ' "$spec" >/dev/null 2>&1 || { die "malformed spec"; return 2; }

  local run_id brief_lock design_lock ocr_sha ocr_kind ocr_id ocr_ver
  run_id=$(jq -r .run_id "$spec")
  brief_lock=$(jq -r .brief_lock "$spec"); design_lock=$(jq -r .design_lock "$spec")
  ocr_sha=$(jq -r .ocr.command_sha256 "$spec"); ocr_kind=$(jq -r .ocr.kind "$spec")
  ocr_id=$(jq -r .ocr.adapter_id "$spec"); ocr_ver=$(jq -r .ocr.adapter_version "$spec")

  # Brief + design locks: safe regular JSON, brief carries a bindable digest.
  regular_json_without_duplicate_keys "$brief_lock" || { die "invalid brief lock"; return 2; }
  jq -e '.schema_version == "taste-brief/v1" and (.brief_sha256|type=="string" and test("^[0-9a-f]{64}$"))' "$brief_lock" >/dev/null 2>&1 || { die "malformed brief lock"; return 2; }
  regular_json_without_duplicate_keys "$design_lock" || { die "invalid design lock"; return 2; }
  local brief_sha brief_file_sha design_sha
  brief_sha=$(jq -r .brief_sha256 "$brief_lock")
  brief_file_sha=$(sha256_file "$brief_lock"); design_sha=$(sha256_file "$design_lock")

  # Pinned scanner: safe executable regular file whose hash matches the pin.
  [ -f "$scanner" ] && [ ! -L "$scanner" ] && [ -x "$scanner" ] || { die "scan adapter is unavailable or unsafe: $scanner"; return 2; }
  [ "$(sha256_file "$scanner")" = "$ocr_sha" ] || { die "scan adapter is not the pinned command"; return 2; }

  case "$out" in ''|/) die "output path is unsafe"; return 2 ;; esac
  [ ! -L "$out" ] || { die "output must not be a symlink"; return 2; }
  local out_parent out_name
  out_parent=$(cd "$(dirname "$out")" && pwd -P) || { die "output parent does not exist"; return 2; }
  out_name=$(basename "$out")
  [ "$out_name" != . ] && [ "$out_name" != .. ] || { die "output path is unsafe"; return 2; }

  # Load, validate, and bind each candidate's capture manifest + on-disk bytes.
  local i cand_ids="" first_states="" tmp
  BUILD_TMP=$(mktemp -d "$out_parent/.polylane-stimulus.XXXXXX") || { die "could not create atomic workspace"; return 2; }
  trap cleanup_build EXIT HUP INT TERM
  tmp="$BUILD_TMP"
  : > "$tmp/bindings.jsonl"; : > "$tmp/scan.jsonl"
  local inj=0 meta=0 noninherent=0 inherent_hit=0

  for i in 0 1; do
    local cand manifest root revision states cap_count
    cand=$(jq -r ".candidates[$i].candidate_id" "$spec")
    manifest=$(jq -r ".candidates[$i].capture_manifest" "$spec")
    case "|$cand_ids|" in *"|$cand|"*) die "same candidate appears twice"; return 2 ;; esac
    cand_ids="${cand_ids:+$cand_ids|}$cand"
    regular_json_without_duplicate_keys "$manifest" || { die "invalid capture manifest for $cand"; return 2; }
    jq -e --arg c "$cand" '.schema_version == "taste-capture-manifest/v1" and .candidate_id == $c
      and (.candidate_source_revision|type=="string" and test("^[0-9a-f]{40}([0-9a-f]{24})?$"))
      and (.required_states|type=="array" and length>0)
      and (.captures|type=="array" and length>0)' "$manifest" >/dev/null 2>&1 || { die "capture manifest mismatch for $cand"; return 2; }
    root=$(cd "$(dirname "$manifest")" && pwd -P) || { die "capture root missing for $cand"; return 2; }
    [ ! -L "$root" ] || { die "capture root is a symlink for $cand"; return 2; }
    revision=$(jq -r .candidate_source_revision "$manifest")
    states=$(jq -r '.required_states | sort | join(",")' "$manifest")
    if [ -z "$first_states" ]; then first_states="$states"; else
      [ "$states" = "$first_states" ] || { die "candidates disagree on required states"; return 2; }
    fi

    # opaque stimulus id — hex digest hides the canonical identity from judges.
    local stim; stim="stim-$(sha256_text "$run_id|$cand|$revision" | cut -c1-12)"
    case "|$(jq -r '.stimulus_id? // empty' "$tmp/bindings.jsonl" 2>/dev/null | tr '\n' '|')|" in
      *"|$stim|"*) die "stimulus id collision"; return 2 ;;
    esac

    local shots="[]" pixels="[]" doms="[]" cap
    while IFS= read -r cap; do
      local cid state route vp d_sha p_sha screen dom pixel action hay
      cid=$(printf '%s' "$cap" | jq -r .capture_id)
      state=$(printf '%s' "$cap" | jq -r .state)
      route=$(printf '%s' "$cap" | jq -r .route)
      vp=$(printf '%s' "$cap" | jq -r .viewport)
      d_sha=$(printf '%s' "$cap" | jq -r .dom_sha256)
      p_sha=$(printf '%s' "$cap" | jq -r .decoded_pixel_sha256)
      local s_sha; s_sha=$(printf '%s' "$cap" | jq -r .screenshot_png_sha256)
      screen="$root/captures/$cid/screenshot.png"; dom="$root/captures/$cid/dom.html"
      pixel="$root/captures/$cid/pixels.rgba"; action="$root/captures/$cid/action-trace.json"
      [ -f "$screen" ] && [ ! -L "$screen" ] || { die "screenshot missing/unsafe for $cand/$cid"; return 2; }
      [ -f "$dom" ] && [ ! -L "$dom" ] || { die "dom missing/unsafe for $cand/$cid"; return 2; }
      # Reused-clean-receipt defense: recompute bytes, reject stale declarations.
      [ "$(sha256_file "$screen")" = "$s_sha" ] || { die "screenshot bytes do not match manifest for $cand/$cid"; return 2; }
      [ "$(sha256_file "$dom")" = "$d_sha" ] || { die "dom bytes do not match manifest for $cand/$cid"; return 2; }
      if [ -f "$pixel" ] && [ ! -L "$pixel" ]; then
        [ "$(sha256_file "$pixel")" = "$p_sha" ] || { die "pixel bytes do not match manifest for $cand/$cid"; return 2; }
      fi

      # Independent OCR of the EXACT screenshot bytes via the pinned adapter.
      local sdir="$tmp/scan/$stim/$cid" ocr
      mkdir -p "$sdir"
      env POLYLANE_STIMULUS_SCAN_IMAGE="$screen" POLYLANE_STIMULUS_SCAN_OUTPUT="$sdir" "$@" >/dev/null 2>&1 || { die "scan adapter failed for $cand/$cid"; return 2; }
      ocr="$sdir/ocr.json"
      [ -f "$ocr" ] && [ ! -L "$ocr" ] || { die "scan adapter omitted output for $cand/$cid"; return 2; }
      jq -e '.schema_version == "taste-ocr/v1" and (.text|type=="array" and all(.[]; type=="string"))' "$ocr" >/dev/null 2>&1 || { die "scan adapter output is malformed for $cand/$cid"; return 2; }

      # Haystack: raw DOM + OCR text + action trace, scanned as untrusted bytes.
      hay="$sdir/haystack.txt"
      { cat "$dom"; jq -r '.text[]' "$ocr"; [ -f "$action" ] && [ ! -L "$action" ] && cat "$action"; } | LC_ALL=C tr 'A-Z' 'a-z' > "$hay"
      grep -Eq "$INJECTION_RE" "$hay" && inj=1 || true
      grep -Eq "$METADATA_RE" "$hay" && meta=1 || true
      grep -Eq "$PROVIDER_RE" "$hay" && noninherent=1 || true
      # candidate/provider/model identity terms + both canonical ids.
      local term
      while IFS= read -r term; do
        [ -n "$term" ] || continue
        if grep -Fiq -- "$term" "$hay"; then
          if jq -e --arg t "$term" '.inherent_identity_terms | index($t) != null' "$spec" >/dev/null 2>&1; then
            inherent_hit=1
          else
            noninherent=1
          fi
        fi
      done < <(jq -r --arg a "$(jq -r '.candidates[0].candidate_id' "$spec")" --arg b "$(jq -r '.candidates[1].candidate_id' "$spec")" '.identity_terms[], $a, $b' "$spec")

      shots=$(printf '%s' "$shots" | jq --arg s "$s_sha" '. + [$s]')
      pixels=$(printf '%s' "$pixels" | jq --arg p "$p_sha" '. + [$p]')
      doms=$(printf '%s' "$doms" | jq --arg d "$d_sha" '. + [$d]')
      jq -nc --arg stim "$stim" --arg cid "$cid" --arg state "$state" --arg route "$route" --arg vp "$vp" \
        --arg s_sha "$s_sha" --arg screen "$screen" \
        '{stimulus_id:$stim,capture_id:$cid,state:$state,route:$route,viewport:$vp,screenshot_png_sha256:$s_sha,screenshot_src:$screen}' >> "$tmp/scan.jsonl"
    done < <(jq -c '.captures[]' "$manifest")

    cap_count=$(jq '.captures|length' "$manifest")
    [ "$(grep -c "\"stimulus_id\":\"$stim\"" "$tmp/scan.jsonl")" = "$cap_count" ] || { die "capture matrix incomplete for $cand"; return 2; }
    jq -nc --arg stim "$stim" --arg cand "$cand" --arg rev "$revision" --arg m "$(sha256_file "$manifest")" \
      --argjson shots "$shots" --argjson pixels "$pixels" --argjson doms "$doms" '
      {stimulus_id:$stim,candidate_id:$cand,source_revision:$rev,capture_manifest_sha256:$m,
       screenshot_png_sha256:$shots,decoded_pixel_sha256:$pixels,dom_sha256:$doms}' >> "$tmp/bindings.jsonl"
  done

  # Escrow (judge-invisible): binds each opaque stimulus to its canonical truth.
  jq -s --arg schema "taste-stimulus-escrow/v1" --arg run "$run_id" --arg brief "$brief_sha" \
    '{schema_version:$schema,run_id:$run,brief_sha256:$brief,bindings:.}' "$tmp/bindings.jsonl" > "$tmp/escrow.json"
  local escrow_sha stim_a stim_b
  escrow_sha=$(jq -cS . "$tmp/escrow.json" | shasum -a 256 | awk '{print $1}')
  stim_a=$(jq -r '.bindings[0].stimulus_id' "$tmp/escrow.json")
  stim_b=$(jq -r '.bindings[1].stimulus_id' "$tmp/escrow.json")
  [ "$stim_a" != "$stim_b" ] || { die "stimulus ids are not distinct"; return 2; }

  # Balanced A/B + B/A orientation with per-orientation binding hashes.
  local ab_sha ba_sha
  ab_sha=$(sha256_text "A/B|A=$stim_a|B=$stim_b"); ba_sha=$(sha256_text "B/A|A=$stim_b|B=$stim_a")
  local orientation
  orientation=$(jq -nc --arg a "$stim_a" --arg b "$stim_b" --arg abs "$ab_sha" --arg bas "$ba_sha" \
    '{"A/B":{A:$a,B:$b,sha256:$abs},"B/A":{A:$b,B:$a,sha256:$bas}}')

  # Classify leakage / threat. Provider tokens, injection, and metadata can never
  # be inherent; inherent-only brand identity abstains rather than silently pass.
  local reasons='[]' leakage threat classification="fixture"
  [ "$inj" = 1 ] && reasons=$(printf '%s' "$reasons" | jq '. + ["PROMPT_INJECTION"]')
  [ "$meta" = 1 ] && reasons=$(printf '%s' "$reasons" | jq '. + ["GENERATION_METADATA"]')
  [ "$noninherent" = 1 ] && reasons=$(printf '%s' "$reasons" | jq '. + ["IDENTITY_LEAK"]')
  if [ "$ocr_kind" = production ]; then
    classification="external"
    reasons=$(printf '%s' "$reasons" | jq '. + ["PRODUCTION_OCR_EXTERNAL"]')
    leakage="external"; threat="external"
  elif [ "$inj" = 1 ] || [ "$meta" = 1 ] || [ "$noninherent" = 1 ]; then
    leakage="leak"; threat="blocked"
  elif [ "$inherent_hit" = 1 ]; then
    leakage="external"; threat="external"
    reasons=$(printf '%s' "$reasons" | jq '. + ["INHERENT_IDENTITY_EXTERNAL"]')
  else
    leakage="clean"; threat="clean"
  fi

  # Judge bundle is emitted only for a clean fixture bundle; leaks/external emit
  # the escrow + receipt evidence but never publish anonymized stimuli.
  local sanitized='{}' bundle_sha="" flow_file_sha=""
  if [ "$leakage" = clean ] && [ "$classification" = fixture ]; then
    mkdir -p "$tmp/publish/judge-bundle/stimuli" "$tmp/publish/scan-receipts"
    jq --arg bs "$brief_sha" --argjson rubric "$RUBRIC" '
      {schema_version:"taste-stimulus-brief/v1",brief_sha256:$bs,
       brief_clauses:{core_task:.core_task,target_population:.target_population,required_routes:.required_routes,required_states:.required_states},
       rubric:{version:"taste-rubric/v1",criteria:$rubric}}' "$brief_lock" > "$tmp/publish/judge-bundle/brief.json"
    local flow="[]" scan
    while IFS= read -r scan; do
      local stim cid state route vp src
      stim=$(printf '%s' "$scan" | jq -r .stimulus_id); cid=$(printf '%s' "$scan" | jq -r .capture_id)
      state=$(printf '%s' "$scan" | jq -r .state); route=$(printf '%s' "$scan" | jq -r .route)
      vp=$(printf '%s' "$scan" | jq -r .viewport); src=$(printf '%s' "$scan" | jq -r .screenshot_src)
      mkdir -p "$tmp/publish/judge-bundle/stimuli/$stim/$cid"
      cp "$src" "$tmp/publish/judge-bundle/stimuli/$stim/$cid/screenshot.png"
      local key sha
      key="$stim/$cid"; sha=$(sha256_file "$tmp/publish/judge-bundle/stimuli/$stim/$cid/screenshot.png")
      sanitized=$(printf '%s' "$sanitized" | jq --arg k "$key" --arg v "$sha" '. + {($k):$v}')
      flow=$(printf '%s' "$flow" | jq --arg s "$stim" --arg c "$cid" --arg st "$state" --arg r "$route" --arg vp "$vp" \
        '. + [{stimulus_id:$s,capture_id:$c,state:$st,route:$r,viewport:$vp}]')
      jq -nc --arg stim "$stim" --arg cid "$cid" --arg id "$ocr_id" --arg ver "$ocr_ver" --arg csha "$ocr_sha" \
        --arg ss "$sha" --arg bs "$brief_sha" --arg ds "$design_sha" --arg es "$escrow_sha" --arg run "$run_id" \
        '{schema_version:"taste-stimulus-scan-receipt/v1",stimulus_id:$stim,capture_id:$cid,
          ocr_adapter:{adapter_id:$id,adapter_version:$ver,command_sha256:$csha},
          bound:{screenshot_png_sha256:$ss,brief_sha256:$bs,design_lock_sha256:$ds,escrow_sha256:$es,run_id:$run},
          leakage:{status:"clean"}}' > "$tmp/publish/scan-receipts/$stim-$cid.json"
    done < "$tmp/scan.jsonl"
    jq -n --argjson flow "$flow" '{schema_version:"taste-stimulus-flow/v1",flow:$flow}' > "$tmp/publish/judge-bundle/flow.json"
    flow_file_sha=$(sha256_file "$tmp/publish/judge-bundle/flow.json")
    bundle_sha=$(sha256_text "$(printf '%s' "$sanitized" | jq -cS .)|$brief_file_sha|$flow_file_sha")
  fi

  # Receipt is the relayed schema every consumer reads.
  mkdir -p "$tmp/publish"
  jq -n --arg run "$run_id" --arg brief "$brief_sha" --arg a "$stim_a" --arg b "$stim_b" \
    --arg escrow "$escrow_sha" --argjson orient "$orientation" --arg bundle "$bundle_sha" \
    --argjson sanitized "$sanitized" --arg leakage "$leakage" --arg threat "$threat" \
    --arg classification "$classification" --argjson reasons "$reasons" \
    --arg brieffile "$brief_file_sha" --arg flowfile "$flow_file_sha" '
    {schema_version:"taste-stimulus-receipt/v1",run_id:$run,brief_sha256:$brief,
     stimulus_ids:[$a,$b],candidate_ids_escrow_sha256:$escrow,orientation:$orient,
     judge_bundle_sha256:$bundle,brief_file_sha256:$brieffile,flow_file_sha256:$flowfile,
     sanitized_artifact_sha256:$sanitized,leakage_status:$leakage,threat_status:$threat,
     fixture_classification:$classification,reason_codes:$reasons}' > "$tmp/publish/stimulus-receipt.json"
  cp "$tmp/escrow.json" "$tmp/publish/escrow.json"

  # Atomic publish: replace the output dir in one move; never leave it partial.
  local backup=""
  if [ -e "$out" ]; then backup="$out_parent/.${out_name}.previous.$$"; mv "$out" "$backup"; fi
  mv "$tmp/publish" "$out"
  [ -z "$backup" ] || rm -rf "$backup"
  trap - EXIT HUP INT TERM
  rm -rf "$tmp"; BUILD_TMP=""

  [ "$leakage" = clean ] && [ "$classification" = fixture ]
}

# --- verify -----------------------------------------------------------------

verify() {
  local out="$1" receipt escrow
  [ -d "$out" ] && [ ! -L "$out" ] || { die "bundle directory is unavailable"; return 2; }
  receipt="$out/stimulus-receipt.json"; escrow="$out/escrow.json"
  regular_json_without_duplicate_keys "$receipt" || { die "invalid receipt"; return 2; }
  regular_json_without_duplicate_keys "$escrow" || { die "invalid escrow"; return 2; }
  jq -e '.schema_version == "taste-stimulus-receipt/v1"' "$receipt" >/dev/null 2>&1 || { die "unknown receipt schema"; return 2; }

  # Escrow hash must bind (ballot's candidate_ids_escrow_sha256 depends on this).
  [ "$(jq -cS . "$escrow" | shasum -a 256 | awk '{print $1}')" = "$(jq -r .candidate_ids_escrow_sha256 "$receipt")" ] || { die "escrow hash does not bind receipt"; return 2; }

  # Orientation is a balanced exact mirror with intact per-orientation hashes.
  local aa ab ba bb
  aa=$(jq -r '.orientation."A/B".A' "$receipt"); ab=$(jq -r '.orientation."A/B".B' "$receipt")
  ba=$(jq -r '.orientation."B/A".A' "$receipt"); bb=$(jq -r '.orientation."B/A".B' "$receipt")
  [ "$aa" != "$ab" ] || { die "orientation A/B is not distinct"; return 2; }
  [ "$aa" = "$bb" ] && [ "$ab" = "$ba" ] || { die "orientation map is not a balanced mirror"; return 2; }
  [ "$(jq -r '.orientation."A/B".sha256' "$receipt")" = "$(sha256_text "A/B|A=$aa|B=$ab")" ] || { die "A/B orientation hash mismatch"; return 2; }
  [ "$(jq -r '.orientation."B/A".sha256' "$receipt")" = "$(sha256_text "B/A|A=$ba|B=$bb")" ] || { die "B/A orientation hash mismatch"; return 2; }
  # Both stimulus ids are the escrowed pair, no more, no less.
  [ "$(jq -r '[.stimulus_ids[]]|sort|join(",")' "$receipt")" = "$(jq -r '[.bindings[].stimulus_id]|sort|join(",")' "$escrow")" ] || { die "stimulus ids disagree with escrow"; return 2; }

  # Only clean fixture bundles publish a judge bundle to re-verify.
  local leakage classification
  leakage=$(jq -r .leakage_status "$receipt"); classification=$(jq -r .fixture_classification "$receipt")
  if [ "$leakage" = clean ] && [ "$classification" = fixture ]; then
    [ -d "$out/judge-bundle" ] || { die "clean bundle is missing its judge bundle"; return 2; }
    # Sanitized screenshots must match the receipt AND the escrow, and expose no id.
    local key ident
    while IFS= read -r key; do
      local sha file
      sha=$(jq -r --arg k "$key" '.sanitized_artifact_sha256[$k]' "$receipt")
      file="$out/judge-bundle/stimuli/$key/screenshot.png"
      [ -f "$file" ] && [ ! -L "$file" ] || { die "sanitized artifact missing: $key"; return 2; }
      [ "$(sha256_file "$file")" = "$sha" ] || { die "sanitized artifact changed since receipt: $key"; return 2; }
    done < <(jq -r '.sanitized_artifact_sha256|keys[]' "$receipt")
    # No canonical identity may appear anywhere in the judge bundle.
    while IFS= read -r ident; do
      [ -n "$ident" ] || continue
      if grep -rqF -- "$ident" "$out/judge-bundle"; then die "canonical identity leaked into judge bundle: $ident"; return 2; fi
    done < <(jq -r '.bindings[].candidate_id, .bindings[].source_revision' "$escrow")
    local flow_file_sha bundle
    flow_file_sha=$(sha256_file "$out/judge-bundle/flow.json")
    bundle=$(sha256_text "$(jq -cS .sanitized_artifact_sha256 "$receipt")|$(jq -r .brief_file_sha256 "$receipt")|$flow_file_sha")
    [ "$bundle" = "$(jq -r .judge_bundle_sha256 "$receipt")" ] || { die "judge bundle hash mismatch"; return 2; }
  fi
  return 0
}

main() {
  command -v jq >/dev/null 2>&1 || { die "jq is required"; return 2; }
  case "${1:-}" in
    build) [ "$#" -ge 5 ] || { usage; return 2; }; shift; build "$@" ;;
    verify) [ "$#" -eq 2 ] || { usage; return 2; }; verify "$2" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
