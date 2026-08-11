#!/usr/bin/env bash
# polylane-visual-capture.sh — fail-closed live-browser capture evidence.
# This file is intentionally executable: callers invoke the declared adapter boundary directly.
set -euo pipefail
CAPTURE_TEMP=""
CAPTURE_BACKUP=""
CAPTURE_OUT=""

usage() {
  echo "usage: polylane-visual-capture.sh capture <candidate.json> <capture-plan.json> <out-dir> -- <browser-adapter> [args...]" >&2
}

die() { echo "VISUAL-CAPTURE: $*" >&2; return 2; }

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }

sha256_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

rfc3339_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

safe_relative_file() {
  case "$1" in ''|/*|*'..'*|*'/'*) return 1 ;; *) return 0 ;; esac
}

png_dimensions() {
  local image b1 b2 b3 b4 b5 b6 b7 b8
  image="$1"
  [ -s "$image" ] || return 1
  # shellcheck disable=SC2046 # decimal byte fields deliberately become positional parameters.
  set -- $(LC_ALL=C od -An -N24 -t u1 "$image" 2>/dev/null) || return 1
  [ "$#" -eq 24 ] || return 1
  b1="$1"; b2="$2"; b3="$3"; b4="$4"; b5="$5"; b6="$6"; b7="$7"; b8="$8"
  [ "$b1" = 137 ] && [ "$b2" = 80 ] && [ "$b3" = 78 ] && [ "$b4" = 71 ] || return 1
  [ "$b5" = 13 ] && [ "$b6" = 10 ] && [ "$b7" = 26 ] && [ "$b8" = 10 ] || return 1
  shift 8
  [ "$5" = 73 ] && [ "$6" = 72 ] && [ "$7" = 68 ] && [ "$8" = 82 ] || return 1
  printf '%s %s\n' "$(( ${9} * 16777216 + ${10} * 65536 + ${11} * 256 + ${12} ))" \
    "$(( ${13} * 16777216 + ${14} * 65536 + ${15} * 256 + ${16} ))"
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
    keys == ["browser","decoder","environment","routes","run_id","schema_version","states"]
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
  local candidate="$1" plan="$2" work="$3" rows="$4" adapter_sha="$5" candidate_sha="$6" plan_sha="$7"
  local route="$8" state="$9" width="${10}" height="${11}" ordinal="${12}"
  local id request result screen pixels dom action captured requested_view actual_view actual_width actual_height dimensions expected_bytes actual_bytes viewport
  local screen_sha pixels_sha dom_sha action_sha result_sha request_sha receipt candidate_created
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
  [ "$captured" \> "$candidate_created" ] || [ "$captured" = "$candidate_created" ] || {
    die "adapter result is stale for $id"; return 1; }
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
  dimensions=$(png_dimensions "$work/adapter-$id/$screen") || { die "screenshot is not a decodable PNG for $id"; return 1; }
  actual_width=${dimensions%% *}; actual_height=${dimensions#* }
  [ "$actual_width" = "$width" ] && [ "$actual_height" = "$height" ] || { die "PNG dimensions mismatch for $id"; return 1; }
  expected_bytes=$((width * height * 4)); actual_bytes=$(wc -c < "$work/adapter-$id/$pixels" | tr -d ' ')
  [ "$actual_bytes" = "$expected_bytes" ] || { die "decoded pixels size mismatch for $id"; return 1; }
  jq -e --arg route "$route" --arg state "$state" '.route == $route and .state == $state and (.actions | type == "array" and length > 0)' "$work/adapter-$id/$action" >/dev/null 2>&1 || {
    die "action trace is not replayable for $id"; return 1; }
  screen_sha=$(sha256_file "$work/adapter-$id/$screen"); pixels_sha=$(sha256_file "$work/adapter-$id/$pixels")
  dom_sha=$(sha256_file "$work/adapter-$id/$dom"); action_sha=$(sha256_file "$work/adapter-$id/$action")
  result_sha=$(sha256_file "$result"); request_sha=$(sha256_file "$request")
  cp "$work/adapter-$id/$screen" "$work/publish/captures/$id/screenshot.png"
  cp "$work/adapter-$id/$pixels" "$work/publish/captures/$id/pixels.rgba"
  cp "$work/adapter-$id/$dom" "$work/publish/captures/$id/dom.html"
  cp "$work/adapter-$id/$action" "$work/publish/captures/$id/action-trace.json"
  receipt="$work/publish/adapter-receipts/$id.json"
  jq -n --arg adapter_id "$(jq -r '.browser.adapter_id' "$plan")" --arg adapter_version "$(jq -r '.browser.adapter_version' "$plan")" \
    --arg command_sha "$adapter_sha" --arg candidate_sha "$candidate_sha" --arg plan_sha "$plan_sha" --arg request_sha "$request_sha" \
    --arg screen_sha "$screen_sha" --arg pixels_sha "$pixels_sha" --arg dom_sha "$dom_sha" --arg action_sha "$action_sha" --arg result_sha "$result_sha" \
    --arg executed_at "$(rfc3339_utc)" \
    '{schema_version:"taste-adapter-receipt/v1",adapter_id:$adapter_id,adapter_version:$adapter_version,command_sha256:$command_sha,input_sha256:[$candidate_sha,$plan_sha,$request_sha],output_sha256:[$screen_sha,$pixels_sha,$dom_sha,$action_sha,$result_sha],exit_status:0,executed_at:$executed_at}' > "$receipt"
  case "$width" in 1440) viewport=desktop ;; 390) viewport=mobile ;; *) die "unsupported viewport for $id"; return 1 ;; esac
  jq -nc --arg id "$id" --arg route "$route" --arg state "$state" --arg screenshot_path "captures/$id/screenshot.png" --arg screen_sha "$screen_sha" --arg pixels_sha "$pixels_sha" \
    --arg dom_sha "$dom_sha" --arg action_sha "$action_sha" --arg captured "$captured" --arg viewport "$viewport" \
    --argjson width "$width" --argjson height "$height" --argjson actual_width "$actual_width" --argjson actual_height "$actual_height" \
    '{capture_id:$id,route:$route,state:$state,viewport:$viewport,action_trace_sha256:$action_sha,viewport_css_px:{width:$width,height:$height},screenshot_path:$screenshot_path,screenshot_png_sha256:$screen_sha,decoded_pixel_sha256:$pixels_sha,decoded_width:$actual_width,decoded_height:$actual_height,dom_sha256:$dom_sha,captured_at:$captured}' >> "$rows"
}

capture() {
  local candidate="$1" plan="$2" out="$3"; shift 3
  local adapter candidate_sha plan_sha adapter_sha source_input_sha temp rows route state ordinal=0 out_parent out_name backup="" browser_receipt browser_outputs
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
      ordinal=$((ordinal + 1)); capture_one "$candidate" "$plan" "$temp" "$rows" "$adapter_sha" "$candidate_sha" "$plan_sha" "$route" "$state" 1440 900 "$ordinal" "$@" || return 1
      ordinal=$((ordinal + 1)); capture_one "$candidate" "$plan" "$temp" "$rows" "$adapter_sha" "$candidate_sha" "$plan_sha" "$route" "$state" 390 844 "$ordinal" "$@" || return 1
    done < <(jq -r '.states[].id' "$plan")
  done < <(jq -r '.routes[]' "$plan")
  [ "$ordinal" -gt 0 ] && [ "$(wc -l < "$rows" | tr -d ' ')" = "$ordinal" ] || { die "capture matrix is incomplete"; return 1; }
  source_input_sha=$(sha256_text "$(jq -r .source_revision "$candidate")")
  browser_outputs=$(jq -s '[.[].screenshot_png_sha256]' "$rows")
  browser_receipt="$temp/publish/adapter-receipts/browser.json"
  jq -n --arg adapter_id "$(jq -r .browser.adapter_id "$plan")" --arg adapter_version "$(jq -r .browser.adapter_version "$plan")" \
    --arg command_sha "$adapter_sha" --arg source_input_sha "$source_input_sha" --argjson outputs "$browser_outputs" --arg executed_at "$(rfc3339_utc)" \
    '{schema_version:"taste-adapter-receipt/v1",adapter_id:$adapter_id,adapter_version:$adapter_version,command_sha256:$command_sha,input_sha256:[$source_input_sha],output_sha256:$outputs,exit_status:0,executed_at:$executed_at}' > "$browser_receipt"
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
