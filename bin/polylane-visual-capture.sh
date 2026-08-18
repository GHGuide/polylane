#!/usr/bin/env bash
# polylane-visual-capture.sh — fail-closed live-browser capture evidence.
# This file is intentionally executable: callers invoke the declared adapter boundary directly.
#
# Trust model: a fixture adapter can never become a production oracle by
# flipping a flag. Production authorization comes only from a coordinator-owned
# allowlist that pins the canonical adapter path, version, command SHA-256,
# browser profile SHA-256, decoder command SHA-256, environment, and source
# revision. Every screenshot is independently decoded by the pinned decoder and
# bound to the browser-declared RGBA, dimensions, and complete PNG structure.
set -euo pipefail
CAPTURE_TEMP=""
CAPTURE_BACKUP=""
CAPTURE_OUT=""

# Required rendered states for a production capture lock. The real user flow is
# any additional declared state beyond these six.
REQUIRED_PROD_STATES='["default","empty","loading","error","hover","focus"]'
# Frozen near-duplicate threshold: two equal-dimension captures must differ in
# more than one RGBA pixel. One pixel = 4 bytes, so >=5 differing bytes required.
NEAR_DUP_MIN_BYTES=5

usage() {
  echo "usage: polylane-visual-capture.sh capture <candidate.json> <capture-plan.json> <out-dir> -- <browser-adapter> [args...]" >&2
}

die() { echo "VISUAL-CAPTURE: $*" >&2; return 2; }

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }

sha256_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

rfc3339_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Single-segment artifact reference produced by an adapter (no directories).
safe_relative_file() {
  case "$1" in ''|/*|*'..'*|*'/'*) return 1 ;; *) return 0 ;; esac
}

# Multi-segment repository-relative regular file with no symlink component.
safe_relative_regular_file() {
  local root="$1" path="$2" part prefix local_old_ifs
  case "$path" in ""|/*|*'//'*) return 1 ;; esac
  prefix="$root"
  local_old_ifs=$IFS
  IFS='/'
  for part in $path; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$local_old_ifs; return 1; }
    prefix="$prefix/$part"
    [ ! -L "$prefix" ] || { IFS=$local_old_ifs; return 1; }
  done
  IFS=$local_old_ifs
  [ -f "$root/$path" ] && [ ! -L "$root/$path" ]
}

u32_at() {
  local file="$1" offset="$2" bytes
  bytes=$(od -An -v -j "$offset" -N 4 -t u1 "$file" 2>/dev/null) || return 1
  # shellcheck disable=SC2086 # deliberate word split of the four decimal bytes.
  set -- $bytes
  [ $# -eq 4 ] || return 1
  printf '%s\n' $(( $1 * 16777216 + $2 * 65536 + $3 * 256 + $4 ))
}

hex_at() { od -An -v -j "$2" -N "$3" -t x1 "$1" 2>/dev/null | tr -d ' \n'; }

# Complete PNG structure walk: signature, IHDR first, every chunk length/type
# accounted for, IEND exactly at end of file, and a real (>=64 byte) IDAT
# stream. Rejects text, magic-header-only, and IHDR-only truncations.
png_structure() {
  local image="$1" size signature pos length kind width height idat iend
  size=$(wc -c < "$image" | tr -d ' ') || return 1
  [ "$size" -ge 57 ] || return 1
  signature=$(hex_at "$image" 0 8) || return 1
  [ "$signature" = 89504e470d0a1a0a ] || return 1
  pos=8; idat=0; iend=0; width=""; height=""
  while [ $((pos + 12)) -le "$size" ]; do
    length=$(u32_at "$image" "$pos") || return 1
    kind=$(hex_at "$image" $((pos + 4)) 4) || return 1
    [ $((length + pos + 12)) -le "$size" ] || return 1
    if [ "$pos" -eq 8 ]; then
      [ "$kind" = 49484452 ] && [ "$length" -eq 13 ] || return 1
      width=$(u32_at "$image" $((pos + 8))) || return 1
      height=$(u32_at "$image" $((pos + 12))) || return 1
      [ "$width" -gt 0 ] && [ "$height" -gt 0 ] || return 1
    fi
    case "$kind" in
      49444154) idat=$((idat + length)) ;;
      49454e44)
        [ "$length" -eq 0 ] || return 1
        [ $((pos + 12)) -eq "$size" ] || return 1
        iend=1
        ;;
    esac
    pos=$((pos + length + 12))
  done
  [ "$iend" -eq 1 ] && [ "$idat" -ge 64 ] || return 1
  printf '%s %s\n' "$width" "$height"
}

candidate_shape() {
  jq -e '
    keys == ["brief_sha256","build_receipt_sha256","candidate_id","created_at","dependency_lock_sha256","design_lock_sha256","direction_id","schema_version","source_revision"]
    and .schema_version == "taste-candidate/v1"
    and all([.candidate_id,.direction_id][]; type == "string" and length > 0)
    and all([.brief_sha256,.design_lock_sha256,.dependency_lock_sha256,.build_receipt_sha256][]; type == "string" and test("^[0-9a-f]{64}$"))
    and (.source_revision | type == "string" and test("^[0-9a-f]{40}([0-9a-f]{24})?$"))
    and (.created_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
  ' "$1" >/dev/null 2>&1
}

plan_shape() {
  jq -e '
    (keys - ["fixture_only"]) == ["browser","decoder","environment","routes","run_id","schema_version","states"]
    and (.fixture_only // false | type == "boolean")
    and .schema_version == "taste-capture-plan/v1"
    and (.run_id | type == "string" and length > 0)
    and (.browser | type == "object" and keys == ["adapter_id","adapter_version","command","profile_sha256"]
      and all([.adapter_id,.adapter_version,.command][]; type == "string" and length > 0)
      and (.profile_sha256 | type == "string" and test("^[0-9a-f]{64}$")))
    and (.decoder | type == "object" and keys == ["adapter_id","adapter_version","command_path","command_sha256"]
      and .adapter_id == "png-decoder"
      and (.adapter_version | type == "string" and length > 0)
      and (.command_path | type == "string" and length > 0 and startswith("/") | not)
      and (.command_sha256 | type == "string" and test("^[0-9a-f]{64}$")))
    and (.environment | type == "object" and keys == ["color_scheme","device_scale_factor","locale","timezone"]
      and (.locale | type == "string" and length > 0)
      and (.timezone | type == "string" and length > 0)
      and (.color_scheme | IN("light","dark"))
      and (.device_scale_factor | type == "number" and . == 1))
    and (.routes | (type == "array") and (length > 0) and (length == (unique | length))
      and all(.[]; type == "string" and test("^/[^[:space:]]*$")))
    and (.states | type == "array" and length > 0
      and all(.[]; type == "object" and keys == ["id"] and (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$")))
      and ([.[] | .id] | length == (unique | length)))
  ' "$1" >/dev/null 2>&1
}

result_shape() {
  jq -e '
    keys == ["action_trace","captured_at","decoded_pixels","dom","navigation_status","route","schema_version","screenshot","state","viewport_css_px"]
    and .schema_version == "taste-browser-capture-result/v1"
    and (.route | type == "string") and (.state | type == "string")
    and .navigation_status == "ok"
    and (.viewport_css_px | type == "object" and keys == ["height","width"]
      and (.width | type == "number" and floor == . and . > 0)
      and (.height | type == "number" and floor == . and . > 0))
    and all([.screenshot,.decoded_pixels,.dom,.action_trace][]; type == "string" and length > 0)
    and (.captured_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
  ' "$1" >/dev/null 2>&1
}

capture_one() {
  local candidate="$1" plan="$2" work="$3" rows="$4" adapter_sha="$5" chain_inputs="$6" decoder_bin="$7"
  local route="$8" state="$9" width="${10}" height="${11}" ordinal="${12}"
  local id request result screen pixels dom action captured now requested_view actual_view dimensions actual_width actual_height expected_bytes actual_bytes viewport
  local screen_sha pixels_sha dom_sha action_sha result_sha request_sha receipt candidate_created
  local decoded dec_w dec_h dec_sha dec_bytes input_all
  id=$(printf 'cap-%03d' "$ordinal")
  shift 12
  request="$work/request-$id.json"; result="$work/adapter-$id/result.json"
  mkdir -p "$work/adapter-$id" "$work/publish/captures/$id" "$work/publish/adapter-receipts"
  jq -n --slurpfile candidate "$candidate" --slurpfile plan "$plan" \
    --arg route "$route" --arg state "$state" --arg id "$id" --argjson width "$width" --argjson height "$height" \
    '{schema_version:"taste-capture-request/v1",capture_id:$id,candidate:$candidate[0],browser:$plan[0].browser,environment:$plan[0].environment,route:$route,state:$state,viewport_css_px:{width:$width,height:$height}}' > "$request"
  if env POLYLANE_CAPTURE_REQUEST="$request" POLYLANE_CAPTURE_OUTPUT="$work/adapter-$id" "$@"; then :; else
    die "browser adapter failed for $route $state ${width}x${height}"; return 1
  fi
  [ -f "$result" ] && [ ! -L "$result" ] || { die "adapter omitted result for $id"; return 1; }
  result_shape "$result" || { die "adapter result is malformed for $id"; return 1; }
  [ "$(jq -r .route "$result")" = "$route" ] && [ "$(jq -r .state "$result")" = "$state" ] || {
    die "adapter result route/state mismatch for $id"; return 1; }
  requested_view="${width}x${height}"
  actual_view="$(jq -r '.viewport_css_px | "\(.width)x\(.height)"' "$result")"
  [ "$actual_view" = "$requested_view" ] || { die "adapter result dimensions mismatch for $id"; return 1; }
  candidate_created=$(jq -r .created_at "$candidate")
  captured=$(jq -r .captured_at "$result")
  now=$(rfc3339_utc)
  [ "$captured" \> "$candidate_created" ] || [ "$captured" = "$candidate_created" ] || {
    die "adapter result is stale for $id"; return 1; }
  [ "$captured" \> "$now" ] && { die "adapter result is future-dated for $id"; return 1; } || :
  screen=$(jq -r .screenshot "$result"); pixels=$(jq -r .decoded_pixels "$result")
  dom=$(jq -r .dom "$result"); action=$(jq -r .action_trace "$result")
  safe_relative_file "$screen" && safe_relative_file "$pixels" && safe_relative_file "$dom" && safe_relative_file "$action" || {
    die "adapter artifact path is unsafe for $id"; return 1; }
  [ "$screen" != "$pixels" ] && [ "$screen" != "$dom" ] && [ "$screen" != "$action" ] && \
    [ "$pixels" != "$dom" ] && [ "$pixels" != "$action" ] && [ "$dom" != "$action" ] || {
    die "adapter artifact paths are aliased for $id"; return 1; }
  for artifact in "$screen" "$pixels" "$dom" "$action"; do
    [ -f "$work/adapter-$id/$artifact" ] && [ ! -L "$work/adapter-$id/$artifact" ] || {
      die "adapter artifact is missing or unsafe for $id"; return 1; }
  done
  dimensions=$(png_structure "$work/adapter-$id/$screen") || { die "screenshot is not a complete PNG for $id"; return 1; }
  actual_width=${dimensions%% *}; actual_height=${dimensions#* }
  [ "$actual_width" = "$width" ] && [ "$actual_height" = "$height" ] || { die "PNG dimensions mismatch for $id"; return 1; }
  expected_bytes=$((width * height * 4)); actual_bytes=$(wc -c < "$work/adapter-$id/$pixels" | tr -d ' ')
  [ "$actual_bytes" = "$expected_bytes" ] || { die "decoded pixels size mismatch for $id"; return 1; }
  jq -e --arg route "$route" --arg state "$state" '.route == $route and .state == $state and (.actions | type == "array" and length > 0)' "$work/adapter-$id/$action" >/dev/null 2>&1 || {
    die "action trace is not replayable for $id"; return 1; }
  screen_sha=$(sha256_file "$work/adapter-$id/$screen"); pixels_sha=$(sha256_file "$work/adapter-$id/$pixels")
  dom_sha=$(sha256_file "$work/adapter-$id/$dom"); action_sha=$(sha256_file "$work/adapter-$id/$action")
  result_sha=$(sha256_file "$result"); request_sha=$(sha256_file "$request")
  # Independent decode: run the pinned decoder on the canonical screenshot and
  # bind its output to the browser-declared RGBA, the requested viewport, and
  # the structural size. A browser that lies about its pixels is rejected here.
  decoded=$(env TASTE_NOW="$now" "$decoder_bin" "$work/adapter-$id/$screen" 2>/dev/null) || { die "decoder failed for $id"; return 1; }
  printf '%s' "$decoded" | jq -e '
    .schema_version == "taste-png-decoder/v1"
    and (.decoded_width | type == "number" and floor == . and . > 0)
    and (.decoded_height | type == "number" and floor == . and . > 0)
    and (.decoded_pixel_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    and (.pixel_payload_bytes | type == "number" and floor == . and . > 0)' >/dev/null 2>&1 || { die "decoder output malformed for $id"; return 1; }
  dec_w=$(printf '%s' "$decoded" | jq -r .decoded_width)
  dec_h=$(printf '%s' "$decoded" | jq -r .decoded_height)
  dec_sha=$(printf '%s' "$decoded" | jq -r .decoded_pixel_sha256)
  dec_bytes=$(printf '%s' "$decoded" | jq -r .pixel_payload_bytes)
  [ "$dec_w" = "$width" ] && [ "$dec_h" = "$height" ] || { die "decoded dimensions mismatch for $id"; return 1; }
  [ "$dec_sha" = "$pixels_sha" ] || { die "screenshot/RGBA mismatch for $id"; return 1; }
  [ "$dec_bytes" = "$expected_bytes" ] || { die "decoded payload size mismatch for $id"; return 1; }
  cp "$work/adapter-$id/$screen" "$work/publish/captures/$id/screenshot.png"
  cp "$work/adapter-$id/$pixels" "$work/publish/captures/$id/pixels.rgba"
  cp "$work/adapter-$id/$dom" "$work/publish/captures/$id/dom.html"
  cp "$work/adapter-$id/$action" "$work/publish/captures/$id/action-trace.json"
  input_all=$(jq -cn --argjson base "$chain_inputs" --arg req "$request_sha" '$base + [$req] | unique')
  receipt="$work/publish/adapter-receipts/$id.json"
  jq -n --arg adapter_id "$(jq -r '.browser.adapter_id' "$plan")" --arg adapter_version "$(jq -r '.browser.adapter_version' "$plan")" \
    --arg command_sha "$adapter_sha" --argjson input "$input_all" \
    --arg screen_sha "$screen_sha" --arg pixels_sha "$pixels_sha" --arg dom_sha "$dom_sha" --arg action_sha "$action_sha" --arg result_sha "$result_sha" \
    --arg executed_at "$(rfc3339_utc)" \
    '{schema_version:"taste-adapter-receipt/v1",adapter_id:$adapter_id,adapter_version:$adapter_version,command_sha256:$command_sha,input_sha256:$input,output_sha256:[$screen_sha,$pixels_sha,$dom_sha,$action_sha,$result_sha],exit_status:0,executed_at:$executed_at}' > "$receipt"
  case "$width" in 1440) viewport=desktop ;; 390) viewport=mobile ;; *) die "unsupported viewport for $id"; return 1 ;; esac
  jq -nc --arg id "$id" --arg route "$route" --arg state "$state" --arg screenshot_path "captures/$id/screenshot.png" --arg screen_sha "$screen_sha" --arg pixels_sha "$pixels_sha" \
    --arg dom_sha "$dom_sha" --arg action_sha "$action_sha" --arg captured "$captured" --arg viewport "$viewport" \
    --argjson width "$width" --argjson height "$height" --argjson actual_width "$actual_width" --argjson actual_height "$actual_height" \
    '{capture_id:$id,route:$route,state:$state,viewport:$viewport,action_trace_sha256:$action_sha,viewport_css_px:{width:$width,height:$height},screenshot_path:$screenshot_path,screenshot_png_sha256:$screen_sha,decoded_pixel_sha256:$pixels_sha,decoded_width:$actual_width,decoded_height:$actual_height,dom_sha256:$dom_sha,captured_at:$captured}' >> "$rows"
}

# Reject exact, metadata-only, and one-pixel near-duplicate renders across the
# published matrix. Exact and metadata-only duplicates collapse to identical
# decoded-pixel SHAs; near-duplicates need a byte-level comparison.
reject_duplicate_pixels() {
  local publish="$1" files=() n i j a b sa sb diff
  while IFS= read -r f; do files+=("$f"); done < <(find "$publish/captures" -type f -name pixels.rgba | LC_ALL=C sort)
  n=${#files[@]}; i=0
  while [ "$i" -lt "$n" ]; do
    j=$((i + 1))
    while [ "$j" -lt "$n" ]; do
      a="${files[$i]}"; b="${files[$j]}"
      sa=$(wc -c < "$a" | tr -d ' '); sb=$(wc -c < "$b" | tr -d ' ')
      if [ "$sa" = "$sb" ]; then
        # ponytail: head caps cmp so a full-buffer diff stops after 5 bytes.
        diff=$( { cmp -l "$a" "$b" 2>/dev/null || true; } | head -n "$NEAR_DUP_MIN_BYTES" | wc -l | tr -d ' ')
        [ "$diff" -ge "$NEAR_DUP_MIN_BYTES" ] || return 1
      fi
      j=$((j + 1))
    done
    i=$((i + 1))
  done
}

capture() {
  local candidate="$1" plan="$2" out="$3"; shift 3
  local adapter candidate_sha plan_sha adapter_sha source_input_sha temp rows route state ordinal=0 out_parent out_name backup=""
  local browser_receipt browser_inputs browser_outputs chain_inputs
  local fixture_only plan_dir decoder_path decoder_sha_declared decoder_bin source_revision adapter_canon profile_sha adapter_version env_json
  local brief_sha design_sha allowlist entry entry_sha
  [ "${1:-}" = "--" ] || { usage; return 2; }; shift
  [ "$#" -gt 0 ] || { die "a declared browser adapter is required"; return 2; }
  adapter="$1"
  [ -f "$candidate" ] && [ ! -L "$candidate" ] && candidate_shape "$candidate" || { die "invalid candidate input"; return 2; }
  [ -f "$plan" ] && [ ! -L "$plan" ] && plan_shape "$plan" || { die "invalid capture plan"; return 2; }
  [ -x "$adapter" ] && [ ! -L "$adapter" ] || { die "browser adapter is unavailable: $adapter"; return 2; }
  case "$out" in ''|/) die "output directory is unsafe"; return 2 ;; esac
  [ ! -L "$out" ] || { die "output directory must not be a symlink"; return 2; }
  out_parent=$(cd "$(dirname "$out")" && pwd -P) || { die "output parent does not exist"; return 2; }
  out_name=$(basename "$out")
  [ "$out_name" != . ] && [ "$out_name" != .. ] || { die "output directory is unsafe"; return 2; }
  candidate_sha=$(sha256_file "$candidate"); plan_sha=$(sha256_file "$plan"); adapter_sha=$(sha256_file "$adapter")

  # Pin the declared decoder (resolved beside the coordinator-owned plan).
  plan_dir=$(cd "$(dirname "$plan")" && pwd -P) || { die "plan directory does not exist"; return 2; }
  decoder_path=$(jq -r '.decoder.command_path' "$plan")
  decoder_sha_declared=$(jq -r '.decoder.command_sha256' "$plan")
  safe_relative_regular_file "$plan_dir" "$decoder_path" && [ -x "$plan_dir/$decoder_path" ] || { die "declared decoder is unavailable"; return 2; }
  decoder_bin="$plan_dir/$decoder_path"
  [ "$(sha256_file "$decoder_bin")" = "$decoder_sha_declared" ] || { die "decoder command SHA-256 does not match the declared identity"; return 2; }

  source_revision=$(jq -r '.source_revision' "$candidate")
  source_input_sha=$(sha256_text "$source_revision")
  brief_sha=$(jq -r '.brief_sha256' "$candidate"); design_sha=$(jq -r '.design_lock_sha256' "$candidate")
  adapter_canon="$(cd "$(dirname "$adapter")" && pwd -P)/$(basename "$adapter")"
  profile_sha=$(jq -r '.browser.profile_sha256' "$plan")
  adapter_version=$(jq -r '.browser.adapter_version' "$plan")
  env_json=$(jq -c '.environment' "$plan")
  fixture_only=$(jq -r 'if has("fixture_only") then .fixture_only else true end' "$plan")

  entry_sha=null
  if [ "$fixture_only" = false ]; then
    # Production locks enforce the full rendered state matrix plus a real flow.
    jq -e --argjson req "$REQUIRED_PROD_STATES" '([.states[].id]) as $ids | (($req - $ids) | length == 0) and ($ids | length > ($req | length))' "$plan" >/dev/null 2>&1 || {
      die "production plan omits a required rendered state or the real flow"; return 2; }
    allowlist="${POLYLANE_CAPTURE_ALLOWLIST:-}"
    [ -n "$allowlist" ] && [ -f "$allowlist" ] && [ ! -L "$allowlist" ] || {
      die "production capture requires a coordinator-owned allowlist"; return 2; }
    jq -e '.schema_version == "taste-capture-allowlist/v1" and (.entries | type == "array")' "$allowlist" >/dev/null 2>&1 || {
      die "coordinator allowlist is malformed"; return 2; }
    entry=$(jq -c --arg path "$adapter_canon" --arg ver "$adapter_version" --arg csha "$adapter_sha" --arg psha "$profile_sha" --arg dsha "$decoder_sha_declared" --arg rev "$source_revision" --argjson env "$env_json" '
      first(.entries[] | select(
        .adapter_path == $path and .adapter_version == $ver and .command_sha256 == $csha
        and .profile_sha256 == $psha and .decoder_command_sha256 == $dsha
        and .source_revision == $rev and .environment == $env)) // empty' "$allowlist")
    [ -n "$entry" ] || { die "adapter is not coordinator-authorized for production"; return 2; }
    entry_sha=$(printf '"%s"' "$(sha256_text "$entry")")
  elif [ "$fixture_only" != true ]; then
    die "fixture_only must be a boolean"; return 2
  fi

  chain_inputs=$(jq -cn --arg c "$candidate_sha" --arg p "$plan_sha" --arg b "$brief_sha" --arg d "$design_sha" --arg dec "$decoder_sha_declared" --arg prof "$profile_sha" --arg s "$source_input_sha" '[$c,$p,$b,$d,$dec,$prof,$s] | unique')

  temp=$(mktemp -d "$out_parent/.polylane-capture.XXXXXX") || { die "could not create atomic workspace"; return 2; }
  cleanup_capture() {
    [ -z "$CAPTURE_TEMP" ] || rm -rf "$CAPTURE_TEMP"
    if [ -n "$CAPTURE_BACKUP" ] && [ -e "$CAPTURE_BACKUP" ] && [ ! -e "$CAPTURE_OUT" ]; then
      mv "$CAPTURE_BACKUP" "$CAPTURE_OUT"
    fi
  }
  CAPTURE_TEMP="$temp"; CAPTURE_OUT="$out"; CAPTURE_BACKUP=""
  trap cleanup_capture EXIT HUP INT TERM
  rows="$temp/rows.jsonl"; : > "$rows"; mkdir -p "$temp/publish"
  while IFS= read -r route; do
    while IFS= read -r state; do
      ordinal=$((ordinal + 1)); capture_one "$candidate" "$plan" "$temp" "$rows" "$adapter_sha" "$chain_inputs" "$decoder_bin" "$route" "$state" 1440 900 "$ordinal" "$@" || return 1
      ordinal=$((ordinal + 1)); capture_one "$candidate" "$plan" "$temp" "$rows" "$adapter_sha" "$chain_inputs" "$decoder_bin" "$route" "$state" 390 844 "$ordinal" "$@" || return 1
    done < <(jq -r '.states[].id' "$plan")
  done < <(jq -r '.routes[]' "$plan")
  [ "$ordinal" -gt 0 ] && [ "$(wc -l < "$rows" | tr -d ' ')" = "$ordinal" ] || { die "capture matrix is incomplete"; return 1; }
  [ "$(jq -s '[.[].screenshot_png_sha256] | length == (unique | length)' "$rows")" = true ] || { die "duplicate screenshot render in matrix"; return 1; }
  [ "$(jq -s '[.[].decoded_pixel_sha256] | length == (unique | length)' "$rows")" = true ] || { die "duplicate decoded pixels in matrix"; return 1; }
  reject_duplicate_pixels "$temp/publish" || { die "near-duplicate captures detected in matrix"; return 1; }

  browser_inputs=$(jq -cn --argjson base "$chain_inputs" '$base | unique')
  browser_outputs=$(jq -s '[.[] | .screenshot_png_sha256, .decoded_pixel_sha256, .dom_sha256, .action_trace_sha256] | unique' "$rows")
  browser_receipt="$temp/publish/adapter-receipts/browser.json"
  jq -n --arg adapter_id "$(jq -r .browser.adapter_id "$plan")" --arg adapter_version "$(jq -r .browser.adapter_version "$plan")" \
    --arg command_sha "$adapter_sha" --argjson inputs "$browser_inputs" --argjson outputs "$browser_outputs" --arg executed_at "$(rfc3339_utc)" \
    '{schema_version:"taste-adapter-receipt/v1",adapter_id:$adapter_id,adapter_version:$adapter_version,command_sha256:$command_sha,input_sha256:$inputs,output_sha256:$outputs,exit_status:0,executed_at:$executed_at}' > "$browser_receipt"

  jq -n --argjson fixture_only "$fixture_only" --arg path "$adapter_canon" --arg csha "$adapter_sha" --arg psha "$profile_sha" \
    --arg dsha "$decoder_sha_declared" --argjson env "$env_json" --arg rev "$source_revision" --argjson entry "$entry_sha" --arg at "$(rfc3339_utc)" \
    '{schema_version:"taste-capture-authorization/v1",fixture_only:$fixture_only,adapter_path:$path,adapter_command_sha256:$csha,browser_profile_sha256:$psha,decoder_command_sha256:$dsha,environment:$env,source_revision:$rev,allowlist_entry_sha256:$entry,authorized_at:$at}' > "$temp/publish/authorization.json"

  jq -n --slurpfile candidate "$candidate" --slurpfile plan "$plan" --slurpfile captures "$rows" \
    '{schema_version:"taste-capture-manifest/v1",candidate_id:$candidate[0].candidate_id,candidate_source_revision:$candidate[0].source_revision,required_routes:$plan[0].routes,required_states:[$plan[0].states[].id],mobile_only_states:[],browser:{adapter_id:$plan[0].browser.adapter_id,adapter_receipt_path:"adapter-receipts/browser.json"},decoder:$plan[0].decoder,captures:$captures}' > "$temp/publish/capture-manifest.json"

  if [ -e "$out" ]; then backup="$out_parent/.${out_name}.previous.$$"; CAPTURE_BACKUP="$backup"; mv "$out" "$backup"; fi
  mv "$temp/publish" "$out"
  [ -z "$backup" ] || rm -rf "$backup"
  trap - EXIT HUP INT TERM
  rm -rf "$temp"
  CAPTURE_TEMP=""; CAPTURE_BACKUP=""; CAPTURE_OUT=""
  return 0
}

main() {
  case "${1:-}" in
    capture) [ "$#" -ge 6 ] || { usage; return 2; }; shift; capture "$@" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
