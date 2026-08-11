#!/usr/bin/env bash
# polylane-taste-pixels.sh — fail-closed verification of rendered PNG evidence.
set -euo pipefail

usage() {
  echo "usage: polylane-taste-pixels.sh verify <project-root> <capture-manifest.json> <now-utc>" >&2
}

reject() {
  printf 'TASTE-PIXELS: %s\n' "$1" >&2
  return 2
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    return 1
  fi
}

sha256_text() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    return 1
  fi
}

safe_relative_regular_file() {
  local root="$1" path="$2" part prefix local_old_ifs
  case "$path" in
    ""|/*|*'//'*) return 1 ;;
  esac
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

regular_json_without_duplicate_keys() {
  local file="$1" duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("\u001f")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

utc_epoch() {
  case "$1" in
    ????-??-??T??:??:??Z) ;;
    *) return 1 ;;
  esac
  date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" '+%s' 2>/dev/null ||
    date -u -d "$1" '+%s' 2>/dev/null
}

file_mtime_epoch() {
  stat -f '%m' "$1" 2>/dev/null || stat -c '%Y' "$1" 2>/dev/null
}

u32_at() {
  local file="$1" offset="$2" bytes a b c d
  bytes=$(od -An -v -j "$offset" -N 4 -t u1 "$file" 2>/dev/null) || return 1
  set -- $bytes
  [ $# -eq 4 ] || return 1
  a=$1 b=$2 c=$3 d=$4
  printf '%s\n' $((a * 16777216 + b * 65536 + c * 256 + d))
}

hex_at() {
  od -An -v -j "$2" -N "$3" -t x1 "$1" 2>/dev/null | tr -d ' \n'
}

# This is intentionally only a structural parser.  Full decompression is done
# by the declared decoder adapter and receipted against the image digest.
png_structure() {
  local image="$1" size signature pos length kind width height idat iend
  size=$(wc -c < "$image" | tr -d ' ') || return 1
  [ "$size" -ge 57 ] || return 1
  signature=$(hex_at "$image" 0 8) || return 1
  [ "$signature" = 89504e470d0a1a0a ] || return 1
  pos=8
  idat=0
  iend=0
  width=""
  height=""
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

receipt_shape_and_binding() {
  local receipt="$1" adapter_id="$2" command_sha="$3" input_sha="$4" output_sha="$5" source_epoch="$6" now_epoch="$7" executed epoch receipt_json duplicates
  receipt_json=$(cat "$receipt") || return 1
  printf '%s' "$receipt_json" | jq -e . >/dev/null 2>&1 || return 1
  duplicates=$(printf '%s' "$receipt_json" | jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("\u001f")' 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ] || return 1
  printf '%s' "$receipt_json" | jq -e --arg id "$adapter_id" --arg command "$command_sha" --arg input "$input_sha" --arg output "$output_sha" '
    (keys | sort) == ["adapter_id","adapter_version","command_sha256","executed_at","exit_status","input_sha256","output_sha256","schema_version"]
    and .schema_version == "taste-adapter-receipt/v1"
    and .adapter_id == $id
    and ((.adapter_version | type) == "string" and (.adapter_version | length) > 0)
    and .command_sha256 == $command
    and ((.input_sha256 | type) == "array")
    and (.input_sha256 | all(.[]; type == "string" and test("^[0-9a-f]{64}$")))
    and (.input_sha256 | index($input) != null)
    and ((.output_sha256 | type) == "array")
    and (.output_sha256 | all(.[]; type == "string" and test("^[0-9a-f]{64}$")))
    and (.output_sha256 | index($output) != null)
    and .exit_status == 0
    and ((.executed_at | type) == "string" and (.executed_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")))
  ' >/dev/null 2>&1 || return 1
  executed=$(printf '%s' "$receipt_json" | jq -r '.executed_at') || return 1
  epoch=$(utc_epoch "$executed") || return 1
  [ "$epoch" -ge "$source_epoch" ] && [ "$epoch" -le "$now_epoch" ]
}

manifest_shape() {
  jq -e '
    . as $m | (keys | sort) == ["browser","candidate_id","candidate_source_revision","captures","decoder","mobile_only_states","required_routes","required_states","schema_version"]
    and .schema_version == "taste-capture-manifest/v1"
    and (.candidate_id | type == "string" and length > 0)
    and (.candidate_source_revision | type == "string" and test("^[0-9a-f]{40,64}$"))
    and (.required_routes | type == "array" and length > 0 and (length == (unique | length)) and all(.[]; type == "string" and test("^/[^[:space:]]*$")))
    and (.required_states | type == "array" and length > 0 and (length == (unique | length)) and all(.[]; type == "string" and test("^[a-z0-9][a-z0-9-]*$")))
    and (.mobile_only_states | type == "array" and (length == (unique | length)) and all(.[]; type == "string"))
    and all(.mobile_only_states[]; . as $state | ($m.required_states | index($state)) != null)
    and (.browser | type == "object" and (keys | sort) == ["adapter_id","adapter_receipt_path"]
      and (.adapter_id | type == "string" and length > 0) and (.adapter_receipt_path | type == "string" and length > 0))
    and (.decoder | type == "object" and (keys | sort) == ["adapter_id","adapter_version","command_path","command_sha256"]
      and (.adapter_id == "png-decoder") and (.adapter_version | type == "string" and length > 0)
      and (.command_path | type == "string" and length > 0) and (.command_sha256 | type == "string" and test("^[0-9a-f]{64}$")))
    and (.captures | type == "array" and length > 0)
    and all(.captures[];
      type == "object" and (keys | sort) == ["action_trace_sha256","capture_id","captured_at","decoded_height","decoded_pixel_sha256","decoded_width","dom_sha256","route","screenshot_path","screenshot_png_sha256","state","viewport","viewport_css_px"]
      and (.capture_id | type == "string" and length > 0)
      and (.route | type == "string") and (.state | type == "string") and (.viewport | IN("desktop","mobile"))
      and (.viewport_css_px | type == "object" and (keys | sort) == ["height","width"] and (.width | type == "number" and floor == . and . > 0) and (.height | type == "number" and floor == . and . > 0))
      and (.screenshot_path | type == "string" and length > 0)
      and all([.screenshot_png_sha256,.decoded_pixel_sha256,.action_trace_sha256,.dom_sha256][]; type == "string" and test("^[0-9a-f]{64}$"))
      and (.decoded_width | type == "number" and floor == . and . > 0)
      and (.decoded_height | type == "number" and floor == . and . > 0)
      and (.captured_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
    )
  ' "$1" >/dev/null 2>&1
}

expected_matrix() {
  jq -r '
    . as $m
    | [$m.required_routes[] as $route | $m.required_states[] as $state |
       if ($m.mobile_only_states | index($state)) != null then "\($route)\u001f\($state)\u001fmobile"
       else "\($route)\u001f\($state)\u001fdesktop", "\($route)\u001f\($state)\u001fmobile" end] | sort[]
  ' "$1"
}

actual_matrix() {
  jq -r '[.captures[] | "\(.route)\u001f\(.state)\u001f\(.viewport)"] | sort[]' "$1"
}

verify() {
  local root="$1" manifest="$2" now="$3" manifest_dir source_revision source_input_sha source_epoch now_epoch browser_path browser_id browser_sha browser_receipt decoder_path decoder_sha actual expected viewport width height path image_sha decoded_sha captured captured_epoch image_mtime dimensions decoded_output pixel_sha pixel_bytes colors nonbackground receipt
  [ -d "$root" ] && [ ! -L "$root" ] || reject UNSAFE_ROOT
  [ -f "$manifest" ] && [ ! -L "$manifest" ] || reject MANIFEST_UNAVAILABLE
  command -v jq >/dev/null 2>&1 || reject JQ_UNAVAILABLE
  manifest_dir=$(CDPATH='' cd -- "$(dirname -- "$manifest")" 2>/dev/null && pwd -P) || reject MANIFEST_UNAVAILABLE
  regular_json_without_duplicate_keys "$manifest" || reject MANIFEST_SHAPE
  manifest_shape "$manifest" || reject MANIFEST_SHAPE
  now_epoch=$(utc_epoch "$now") || reject INVALID_NOW
  source_revision=$(git -C "$root" rev-parse HEAD 2>/dev/null) || reject SOURCE_REVISION_UNAVAILABLE
  [ "$source_revision" = "$(jq -r '.candidate_source_revision' "$manifest")" ] || reject STALE_SOURCE_REVISION
  source_input_sha=$(sha256_text "$source_revision" 2>/dev/null || true)
  [ -n "$source_input_sha" ] || reject SHA256_UNAVAILABLE
  source_epoch=$(git -C "$root" log -1 --format=%ct "$source_revision" 2>/dev/null) || reject SOURCE_TIME_UNAVAILABLE

  browser_path=$(jq -r '.browser.adapter_receipt_path' "$manifest")
  browser_id=$(jq -r '.browser.adapter_id' "$manifest")
  safe_relative_regular_file "$manifest_dir" "$browser_path" || reject UNSAFE_PATH
  browser_receipt="$manifest_dir/$browser_path"
  browser_sha=$(jq -r '.command_sha256 // empty' "$browser_receipt" 2>/dev/null || true)
  [ -n "$browser_sha" ] || reject BROWSER_RECEIPT
  receipt_shape_and_binding "$browser_receipt" "$browser_id" "$browser_sha" "$source_input_sha" "$(jq -r '.captures[0].screenshot_png_sha256' "$manifest")" "$source_epoch" "$now_epoch" || reject BROWSER_RECEIPT_SHAPE
  # Bind every browser output, not merely the first one used above.
  while IFS= read -r image_sha; do
    jq -e --arg hash "$image_sha" '.output_sha256 | index($hash) != null' "$browser_receipt" >/dev/null 2>&1 || reject BROWSER_OUTPUT_MISMATCH
  done < <(jq -r '.captures[].screenshot_png_sha256' "$manifest")

  decoder_path=$(jq -r '.decoder.command_path' "$manifest")
  safe_relative_regular_file "$root" "$decoder_path" && [ -x "$root/$decoder_path" ] || reject DECODER_UNAVAILABLE
  decoder_sha=$(jq -r '.decoder.command_sha256' "$manifest")
  [ "$(sha256_file "$root/$decoder_path" 2>/dev/null || true)" = "$decoder_sha" ] || reject DECODER_RECEIPT

  expected=$(expected_matrix "$manifest")
  actual=$(actual_matrix "$manifest")
  [ "$expected" = "$actual" ] || reject MATRIX_MISMATCH
  [ "$(jq '[.captures[].capture_id] | length == (unique | length)' "$manifest")" = true ] || reject MATRIX_MISMATCH

  while IFS=$'\t' read -r _capture_id _route _state viewport width height path image_sha decoded_sha captured; do
    safe_relative_regular_file "$manifest_dir" "$path" || reject UNSAFE_PATH
    [ "$(sha256_file "$manifest_dir/$path" 2>/dev/null || true)" = "$image_sha" ] || reject PNG_HASH_MISMATCH
    captured_epoch=$(utc_epoch "$captured") || reject STALE_CAPTURE
    [ "$captured_epoch" -ge "$source_epoch" ] && [ "$captured_epoch" -le "$now_epoch" ] || reject STALE_CAPTURE
    image_mtime=$(file_mtime_epoch "$manifest_dir/$path") || reject STALE_CAPTURE
    [ "$image_mtime" -ge "$source_epoch" ] && [ "$image_mtime" -le $((now_epoch + 5)) ] || reject STALE_CAPTURE
    dimensions=$(png_structure "$manifest_dir/$path") || reject PNG_STRUCTURE
    set -- $dimensions
    [ "$1" = "$width" ] && [ "$2" = "$height" ] || reject VIEWPORT_MISMATCH
    case "$viewport:$width:$height" in
      desktop:1440:900|mobile:390:844) ;;
      *) reject VIEWPORT_MISMATCH ;;
    esac
    decoded_output=$("$root/$decoder_path" "$manifest_dir/$path" 2>/dev/null) || reject DECODER_UNAVAILABLE
    printf '%s' "$decoded_output" | jq -e '
      (keys | sort) == ["adapter_receipt","decoded_height","decoded_pixel_sha256","decoded_width","distinct_pixel_values","non_background_pixel_count","pixel_payload_bytes","schema_version"]
      and .schema_version == "taste-png-decoder/v1"
      and (.decoded_width | type == "number" and floor == . and . > 0)
      and (.decoded_height | type == "number" and floor == . and . > 0)
      and (.decoded_pixel_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
      and (.pixel_payload_bytes | type == "number" and floor == . and . > 0)
      and (.distinct_pixel_values | type == "number" and floor == . and . > 0)
      and (.non_background_pixel_count | type == "number" and floor == . and . >= 0)
    ' >/dev/null 2>&1 || reject DECODER_RECEIPT
    pixel_sha=$(printf '%s' "$decoded_output" | jq -r '.decoded_pixel_sha256')
    pixel_bytes=$(printf '%s' "$decoded_output" | jq -r '.pixel_payload_bytes')
    colors=$(printf '%s' "$decoded_output" | jq -r '.distinct_pixel_values')
    nonbackground=$(printf '%s' "$decoded_output" | jq -r '.non_background_pixel_count')
    [ "$pixel_sha" = "$decoded_sha" ] || reject DECODED_HASH_MISMATCH
    [ "$(printf '%s' "$decoded_output" | jq -r '.decoded_width')" = "$width" ] && [ "$(printf '%s' "$decoded_output" | jq -r '.decoded_height')" = "$height" ] || reject DECODED_DIMENSIONS_MISMATCH
    [ "$pixel_bytes" -ge $((width * height)) ] && [ "$colors" -ge 2 ] && [ "$nonbackground" -gt 0 ] || reject SYNTHETIC_PLACEHOLDER
    receipt=$(printf '%s' "$decoded_output" | jq -c '.adapter_receipt')
    printf '%s\n' "$receipt" | receipt_shape_and_binding /dev/stdin png-decoder "$decoder_sha" "$image_sha" "$decoded_sha" "$source_epoch" "$now_epoch" || reject DECODER_RECEIPT
  done < <(jq -r '.captures[] | [.capture_id,.route,.state,.viewport,.viewport_css_px.width,.viewport_css_px.height,.screenshot_path,.screenshot_png_sha256,.decoded_pixel_sha256,.captured_at] | @tsv' "$manifest")

  [ "$(jq '[.captures[].screenshot_png_sha256] | length == (unique | length)' "$manifest")" = true ] || reject DUPLICATE_RENDER
  [ "$(jq '[.captures[].decoded_pixel_sha256] | length == (unique | length)' "$manifest")" = true ] || reject DUPLICATE_RENDER
  printf 'TASTE-PIXELS: VERIFIED captures=%s\n' "$(jq '.captures | length' "$manifest")"
}

main() {
  case "${1:-}" in
    verify) [ $# -eq 4 ] || { usage; return 2; }; verify "$2" "$3" "$4" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
