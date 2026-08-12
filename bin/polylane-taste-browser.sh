#!/usr/bin/env bash
# polylane-taste-browser.sh — fail-closed live-browser capture wrapper.
#
# Drives a declared Chrome/Playwright adapter across a frozen route/state matrix
# at desktop (1440x900) and mobile (390x844), starting a pinned loopback server,
# and emits complete browser provenance: screenshot PNG, serialized DOM,
# replayable action trace, console + network logs, output hashes, and a live
# dependency receipt (real Chrome binary + Playwright module + Node). It NEVER
# decodes or grades pixels or taste — the decoder/pixels lane consumes these
# captures downstream. Every artifact is bound by SHA-256; any breach fails
# closed and rolls the output back. A caller cannot claim success on partial,
# stale, resized, symlinked, aliased, or non-loopback-tainted output.
set -euo pipefail

CAPTURE_TEMP=""
CAPTURE_BACKUP=""
CAPTURE_OUT=""
SERVER_PID=""

usage() {
  echo "usage: polylane-taste-browser.sh capture <candidate.json> <plan.json> <out-dir> -- <browser-adapter> [args...]" >&2
}

die() { echo "TASTE-BROWSER: $*" >&2; return 2; }

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
sha256_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }
rfc3339_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Single-segment artifact reference produced by an adapter (no directories).
safe_relative_file() {
  case "$1" in ''|/*|*'..'*|*'/'*) return 1 ;; *) return 0 ;; esac
}

# Multi-segment repository-relative regular file with no symlink component.
safe_relative_regular_file() {
  local root="$1" path="$2" part prefix old_ifs
  case "$path" in ""|/*|*'//'*) return 1 ;; esac
  prefix="$root"
  old_ifs=$IFS; IFS='/'
  for part in $path; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
    prefix="$prefix/$part"
    [ ! -L "$prefix" ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
  [ -d "$root/$path" ] && [ ! -L "$root/$path" ]
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

# Complete PNG structure walk: signature, IHDR first, every chunk accounted for,
# IEND exactly at end of file, a real (>=64 byte) IDAT stream. Rejects text,
# magic-header-only, and IHDR-only truncations. Prints "<width> <height>".
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

# taste-candidate/v1 — same identity envelope as the visual-capture producer.
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

# taste-browser-live-plan/v1 — pinned browser identity, frozen environment,
# loopback server command, and an allowlisted route/state/action matrix.
plan_shape() {
  jq -e '
    keys == ["browser","environment","local_server","routes","run_id","schema_version","states"]
    and .schema_version == "taste-browser-live-plan/v1"
    and (.run_id | type == "string" and length > 0)
    and (.browser | type == "object"
      and keys == ["adapter_id","adapter_version","command_sha256","engine","executable_path","expected_version_prefix","playwright_module","playwright_version","profile_sha256"]
      and all([.adapter_id,.adapter_version,.engine,.executable_path,.expected_version_prefix,.playwright_module,.playwright_version][]; type == "string" and length > 0)
      and (.engine == "chromium")
      and (.command_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
      and (.profile_sha256 | type == "string" and test("^[0-9a-f]{64}$")))
    and (.environment | type == "object" and keys == ["color_scheme","device_scale_factor","locale","timezone"]
      and (.locale | type == "string" and length > 0)
      and (.timezone | type == "string" and length > 0)
      and (.color_scheme | IN("light","dark"))
      and (.device_scale_factor | type == "number" and . == 1))
    and (.local_server | type == "object" and keys == ["base_path","command","ready_path"]
      and (.base_path | type == "string" and length > 0 and (startswith("/") | not))
      and (.ready_path | type == "string" and test("^/[^[:space:]]*$"))
      and (.command | type == "array" and length > 0 and all(.[]; type == "string" and length > 0)))
    and (.routes | type == "array" and length > 0 and (length == (unique | length))
      and all(.[]; type == "string" and test("^/[^[:space:]]*$")))
    and (.states | type == "array" and length > 0
      and all(.[]; type == "object" and keys == ["actions","id"]
        and (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$"))
        and (.actions | type == "array"
          and all(.[]; type == "object"
            and (.type | IN("click","hover","focus","fill","press","wait_for"))
            and (if .type == "press" then (.key | type == "string" and length > 0)
                 elif .type == "fill" then (.selector | type == "string" and length > 0) and (.value | type == "string")
                 else (.selector | type == "string" and length > 0) end))))
      and ([.[].id] | length == (unique | length)))
  ' "$1" >/dev/null 2>&1
}

# taste-browser-live-result/v1 — the adapter's per-capture manifest.
result_shape() {
  jq -e '
    keys == ["action_trace","blocked_nonloopback_count","captured_at","console","console_error_count","dom","navigation_status","network","network_error_count","profile","route","schema_version","screenshot","state","viewport_css_px"]
    and .schema_version == "taste-browser-live-result/v1"
    and (.route | type == "string") and (.state | type == "string")
    and .navigation_status == "ok"
    and (.viewport_css_px | type == "object" and keys == ["height","width"]
      and (.width | type == "number" and floor == . and . > 0)
      and (.height | type == "number" and floor == . and . > 0))
    and all([.screenshot,.dom,.action_trace,.console,.network][]; type == "string" and length > 0)
    and all([.console_error_count,.network_error_count,.blocked_nonloopback_count][]; type == "number" and floor == . and . >= 0)
    and (.profile | type == "object")
    and (.captured_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
  ' "$1" >/dev/null 2>&1
}

capture_one() {
  local plan="$1" work="$2" rows="$3" profile_json="$4" profile_sha="$5" base_url="$6" env_json="$7"
  local candidate_created="$8" route="$9" state="${10}" actions="${11}" width="${12}" height="${13}" ordinal="${14}"
  shift 14
  local id request out result screen dom action console network captured now dims aw ah viewport
  local screen_sha dom_sha action_sha console_sha network_sha rp rp_sha ce ne bn artifact a
  id=$(printf 'cap-%03d' "$ordinal")
  request="$work/request-$id.json"; out="$work/adapter-$id"; result="$out/result.json"
  mkdir -p "$out" "$work/publish/captures/$id"
  jq -n --arg id "$id" --arg route "$route" --arg state "$state" --arg base "$base_url" \
    --argjson actions "$actions" --argjson env "$env_json" --argjson profile "$profile_json" \
    --argjson width "$width" --argjson height "$height" \
    --arg exe "$(jq -r .browser.executable_path "$plan")" --arg pwmod "$(jq -r .browser.playwright_module "$plan")" \
    '{schema_version:"taste-browser-live-request/v1",capture_id:$id,route:$route,state:$state,actions:$actions,base_url:$base,viewport_css_px:{width:$width,height:$height},environment:$env,browser:{engine:"chromium",executable_path:$exe,playwright_module:$pwmod},profile:$profile}' > "$request"

  if env POLYLANE_CAPTURE_REQUEST="$request" POLYLANE_CAPTURE_OUTPUT="$out" "$@"; then :; else
    die "browser adapter failed for $route $state ${width}x${height}"; return 1
  fi
  [ -f "$result" ] && [ ! -L "$result" ] || { die "adapter omitted result for $id"; return 1; }
  result_shape "$result" || { die "adapter result malformed for $id"; return 1; }
  [ "$(jq -r .route "$result")" = "$route" ] && [ "$(jq -r .state "$result")" = "$state" ] || {
    die "adapter result route/state mismatch for $id"; return 1; }
  [ "$(jq -r '.viewport_css_px | "\(.width)x\(.height)"' "$result")" = "${width}x${height}" ] || {
    die "adapter result dimensions mismatch for $id"; return 1; }

  captured=$(jq -r .captured_at "$result"); now=$(rfc3339_utc)
  { [ "$captured" \> "$candidate_created" ] || [ "$captured" = "$candidate_created" ]; } || { die "adapter output is stale for $id"; return 1; }
  [ "$captured" \> "$now" ] && { die "adapter output is future-dated for $id"; return 1; } || :

  rp=$(jq -Sc .profile "$result"); rp_sha=$(sha256_text "$rp")
  [ "$rp_sha" = "$profile_sha" ] || { die "adapter did not honor the pinned profile for $id"; return 1; }

  screen=$(jq -r .screenshot "$result"); dom=$(jq -r .dom "$result"); action=$(jq -r .action_trace "$result")
  console=$(jq -r .console "$result"); network=$(jq -r .network "$result")
  for a in "$screen" "$dom" "$action" "$console" "$network"; do
    safe_relative_file "$a" || { die "adapter artifact path is unsafe for $id"; return 1; }
  done
  # every artifact reference must be distinct (no aliasing one file as another)
  [ "$(printf '%s\n%s\n%s\n%s\n%s\n' "$screen" "$dom" "$action" "$console" "$network" | LC_ALL=C sort -u | wc -l | tr -d ' ')" = 5 ] || {
    die "adapter artifact paths are aliased for $id"; return 1; }
  for artifact in "$screen" "$dom" "$action" "$console" "$network"; do
    [ -f "$out/$artifact" ] && [ ! -L "$out/$artifact" ] || { die "adapter artifact missing or unsafe for $id"; return 1; }
  done

  dims=$(png_structure "$out/$screen") || { die "screenshot is not a complete PNG for $id"; return 1; }
  aw=${dims%% *}; ah=${dims#* }
  [ "$aw" = "$width" ] && [ "$ah" = "$height" ] || { die "screenshot is resized, not native ${width}x${height} for $id"; return 1; }

  jq -e --arg route "$route" --arg state "$state" '
    .route == $route and .state == $state and (.actions | type == "array" and length > 0)
    and ([.actions[].type] | (index("navigate") != null) and (index("settle") != null))
  ' "$out/$action" >/dev/null 2>&1 || { die "action trace is not replayable for $id"; return 1; }

  # console + network are provenance AND hard gates: recompute the counts the
  # adapter declared, reject a lying adapter, then reject any non-clean capture.
  jq -e '.messages | type == "array"' "$out/$console" >/dev/null 2>&1 || { die "console log malformed for $id"; return 1; }
  jq -e '.requests | type == "array"' "$out/$network" >/dev/null 2>&1 || { die "network log malformed for $id"; return 1; }
  ce=$(jq '[.messages[] | select(.type == "error")] | length' "$out/$console")
  bn=$(jq '[.requests[] | select(.blocked == true and (.loopback != true))] | length' "$out/$network")
  ne=$(jq '[.requests[] | select((.loopback == true) and ((.status // 0) >= 400))] | length' "$out/$network")
  [ "$ce" = "$(jq .console_error_count "$result")" ] || { die "console error count is falsified for $id"; return 1; }
  [ "$bn" = "$(jq .blocked_nonloopback_count "$result")" ] || { die "blocked-network count is falsified for $id"; return 1; }
  [ "$ne" = "$(jq .network_error_count "$result")" ] || { die "network error count is falsified for $id"; return 1; }
  # Contract order: the non-loopback block is the headline gate (an aborted
  # egress also surfaces as a browser console error; report the block first).
  [ "$bn" = 0 ] || { die "capture attempted $bn non-loopback request(s) for $id"; return 1; }
  [ "$ce" = 0 ] || { die "capture logged $ce console error(s) for $id"; return 1; }
  [ "$ne" = 0 ] || { die "capture had $ne failed loopback request(s) for $id"; return 1; }

  screen_sha=$(sha256_file "$out/$screen"); dom_sha=$(sha256_file "$out/$dom")
  action_sha=$(sha256_file "$out/$action"); console_sha=$(sha256_file "$out/$console"); network_sha=$(sha256_file "$out/$network")
  cp "$out/$screen" "$work/publish/captures/$id/screenshot.png"
  cp "$out/$dom" "$work/publish/captures/$id/dom.html"
  cp "$out/$action" "$work/publish/captures/$id/action-trace.json"
  cp "$out/$console" "$work/publish/captures/$id/console.json"
  cp "$out/$network" "$work/publish/captures/$id/network.json"
  case "$width" in 1440) viewport=desktop ;; 390) viewport=mobile ;; *) die "unsupported viewport for $id"; return 1 ;; esac
  jq -nc --arg id "$id" --arg route "$route" --arg state "$state" --arg viewport "$viewport" \
    --argjson width "$width" --argjson height "$height" \
    --arg sp "captures/$id/screenshot.png" --arg ss "$screen_sha" --arg ds "$dom_sha" --arg as "$action_sha" \
    --arg cs "$console_sha" --arg ns "$network_sha" --arg captured "$captured" \
    '{capture_id:$id,route:$route,state:$state,viewport:$viewport,viewport_css_px:{width:$width,height:$height},screenshot_path:$sp,screenshot_png_sha256:$ss,dom_sha256:$ds,action_trace_sha256:$as,console_sha256:$cs,network_sha256:$ns,console_error_count:0,network_error_count:0,blocked_nonloopback_count:0,captured_at:$captured}' >> "$rows"
}

start_server() {
  local plan="$1" plan_dir="$2" port_var="$3" url_var="$4" server_root base_path ready_path port cmd tok
  base_path=$(jq -r '.local_server.base_path' "$plan")
  ready_path=$(jq -r '.local_server.ready_path' "$plan")
  safe_relative_regular_file "$plan_dir" "$base_path" || { die "local server root is unsafe or missing"; return 2; }
  server_root="$plan_dir/$base_path"
  port=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));p=s.getsockname()[1];s.close();print(p)') || { die "could not allocate a loopback port"; return 2; }
  # ponytail: tiny bind-and-close TOCTOU on the port; fine for a local fixture server.
  cmd=()
  while IFS= read -r tok; do tok=${tok//\{PORT\}/$port}; cmd+=("$tok"); done < <(jq -r '.local_server.command[]' "$plan")
  ( cd "$server_root" && exec "${cmd[@]}" ) >/dev/null 2>&1 &
  SERVER_PID=$!
  # Readiness without a sleep loop: curl retries on connection-refused with a
  # 1s backoff until the frozen loopback server answers the pinned ready path.
  curl -sf --retry 40 --retry-delay 1 --retry-connrefused --max-time 45 "http://127.0.0.1:$port$ready_path" >/dev/null 2>&1 \
    || { die "loopback server did not become ready at $ready_path"; return 2; }
  eval "$port_var=$port"
  eval "$url_var=http://127.0.0.1:$port"
}

cleanup_capture() {
  [ -z "$SERVER_PID" ] || { kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; SERVER_PID=""; }
  [ -z "$CAPTURE_TEMP" ] || rm -rf "$CAPTURE_TEMP"
  if [ -n "$CAPTURE_BACKUP" ] && [ -e "$CAPTURE_BACKUP" ] && [ ! -e "$CAPTURE_OUT" ]; then
    mv "$CAPTURE_BACKUP" "$CAPTURE_OUT"
  fi
}

capture() {
  local candidate="$1" plan="$2" out="$3"; shift 3
  local adapter adapter_sha candidate_created source_revision plan_dir out_parent out_name backup=""
  local exe expected_prefix chrome_ver chrome_sha pwmod pwver_want pwver pw_dir node_ver
  local env_json profile_json profile_sha declared_profile temp rows route state actions ordinal=0 port base_url
  [ "${1:-}" = "--" ] || { usage; return 2; }; shift
  [ "$#" -gt 0 ] || { die "a declared browser adapter is required"; return 2; }
  adapter="$1"

  [ -f "$candidate" ] && [ ! -L "$candidate" ] && candidate_shape "$candidate" || { die "invalid candidate input"; return 2; }
  [ -f "$plan" ] && [ ! -L "$plan" ] && plan_shape "$plan" || { die "invalid capture plan"; return 2; }
  [ -f "$adapter" ] && [ -x "$adapter" ] && [ ! -L "$adapter" ] || { die "browser adapter is unavailable: $adapter"; return 2; }
  case "$out" in ''|/) die "output directory is unsafe"; return 2 ;; esac
  [ ! -L "$out" ] || { die "output directory must not be a symlink"; return 2; }
  out_parent=$(cd "$(dirname "$out")" && pwd -P) || { die "output parent does not exist"; return 2; }
  out_name=$(basename "$out")
  [ "$out_name" != . ] && [ "$out_name" != .. ] || { die "output directory is unsafe"; return 2; }

  # --- pin the adapter identity -------------------------------------------------
  adapter_sha=$(sha256_file "$adapter")
  [ "$adapter_sha" = "$(jq -r .browser.command_sha256 "$plan")" ] || { die "adapter does not match the plan-pinned command SHA-256"; return 2; }

  # --- external dependency receipt: real Chrome binary + Playwright + Node ------
  exe=$(jq -r .browser.executable_path "$plan"); expected_prefix=$(jq -r .browser.expected_version_prefix "$plan")
  [ -n "$exe" ] && [ -f "$exe" ] && [ -x "$exe" ] && [ ! -L "$exe" ] || { die "declared Chrome binary is unavailable: $exe"; return 2; }
  chrome_ver=$("$exe" --version 2>/dev/null | head -1 | tr -d '\r') || { die "declared Chrome binary would not report a version"; return 2; }
  case "$chrome_ver" in "$expected_prefix"*) : ;; *) die "Chrome version [$chrome_ver] does not match pinned prefix [$expected_prefix]"; return 2 ;; esac
  chrome_sha=$(sha256_file "$exe")
  pwmod=$(jq -r .browser.playwright_module "$plan"); pwver_want=$(jq -r .browser.playwright_version "$plan")
  pw_dir=$(POLY_PWMOD="$pwmod" node -e "const m=process.env.POLY_PWMOD;process.stdout.write(require('path').dirname(require.resolve(m+'/package.json')))" 2>/dev/null) || { die "declared Playwright module is unavailable: $pwmod"; return 2; }
  pwver=$(POLY_PWMOD="$pwmod" node -e "const m=process.env.POLY_PWMOD;process.stdout.write(require(m+'/package.json').version)" 2>/dev/null) || { die "could not read Playwright version"; return 2; }
  [ "$pwver" = "$pwver_want" ] || { die "Playwright version [$pwver] does not match pinned [$pwver_want]"; return 2; }
  node_ver=$(node --version 2>/dev/null) || { die "node is unavailable"; return 2; }

  # --- frozen profile: plan self-consistency + per-capture adapter binding ------
  env_json=$(jq -c .environment "$plan")
  profile_json=$(jq -Scn --argjson env "$env_json" '{color_scheme:$env.color_scheme,device_scale_factor:$env.device_scale_factor,engine:"chromium",headless:true,locale:$env.locale,reduced_motion:"reduce",timezone:$env.timezone,viewport_policy:"per-capture-css-px"}')
  profile_sha=$(sha256_text "$profile_json")
  declared_profile=$(jq -r .browser.profile_sha256 "$plan")
  [ "$declared_profile" = "$profile_sha" ] || { die "plan profile SHA-256 does not match its declared environment"; return 2; }

  candidate_created=$(jq -r .created_at "$candidate"); source_revision=$(jq -r .source_revision "$candidate")
  plan_dir=$(cd "$(dirname "$plan")" && pwd -P) || { die "plan directory does not exist"; return 2; }

  temp=$(mktemp -d "$out_parent/.polylane-browser.XXXXXX") || { die "could not create atomic workspace"; return 2; }
  CAPTURE_TEMP="$temp"; CAPTURE_OUT="$out"; CAPTURE_BACKUP=""
  trap cleanup_capture EXIT HUP INT TERM
  rows="$temp/rows.jsonl"; : > "$rows"; mkdir -p "$temp/publish/captures"

  start_server "$plan" "$plan_dir" port base_url || return $?

  while IFS= read -r route; do
    while IFS= read -r state; do
      actions=$(jq -c --arg s "$state" '.states[] | select(.id == $s) | .actions' "$plan")
      ordinal=$((ordinal + 1)); capture_one "$plan" "$temp" "$rows" "$profile_json" "$profile_sha" "$base_url" "$env_json" "$candidate_created" "$route" "$state" "$actions" 1440 900 "$ordinal" "$@" || return 1
      ordinal=$((ordinal + 1)); capture_one "$plan" "$temp" "$rows" "$profile_json" "$profile_sha" "$base_url" "$env_json" "$candidate_created" "$route" "$state" "$actions" 390 844 "$ordinal" "$@" || return 1
    done < <(jq -r '.states[].id' "$plan")
  done < <(jq -r '.routes[]' "$plan")

  [ "$ordinal" -gt 0 ] && [ "$(wc -l < "$rows" | tr -d ' ')" = "$ordinal" ] || { die "capture matrix is incomplete"; return 1; }
  [ "$(jq -s '[.[].screenshot_png_sha256] | length == (unique | length)' "$rows")" = true ] || { die "duplicate screenshot render in matrix"; return 1; }

  # stop the server before publishing; provenance is already captured.
  [ -z "$SERVER_PID" ] || { kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; SERVER_PID=""; }

  jq -n --arg exe "$exe" --arg cver "$chrome_ver" --arg csha "$chrome_sha" \
    --arg pwmod "$pwmod" --arg pwver "$pwver" --arg pwdir "$pw_dir" --arg nver "$node_ver" \
    --arg apath "$(cd "$(dirname "$adapter")" && pwd -P)/$(basename "$adapter")" --arg asha "$adapter_sha" \
    --argjson env "$env_json" --arg rev "$source_revision" --arg at "$(rfc3339_utc)" \
    '{schema_version:"taste-browser-live-dependency/v1",chrome:{executable_path:$exe,version:$cver,sha256:$csha},playwright:{module:$pwmod,version:$pwver,path:$pwdir},node:{version:$nver},adapter:{path:$apath,sha256:$asha},environment:$env,source_revision:$rev,captured_at:$at}' > "$temp/publish/dependency-receipt.json"

  jq -n --arg apath "$(cd "$(dirname "$adapter")" && pwd -P)/$(basename "$adapter")" --arg asha "$adapter_sha" \
    --arg exe "$exe" --arg cver "$chrome_ver" --arg pwver "$pwver" --arg psha "$profile_sha" \
    --argjson env "$env_json" --arg rev "$source_revision" --arg at "$(rfc3339_utc)" \
    '{schema_version:"taste-browser-live-authorization/v1",fixture_only:true,adapter_path:$apath,adapter_command_sha256:$asha,browser_executable_path:$exe,browser_version:$cver,playwright_version:$pwver,profile_sha256:$psha,source_revision:$rev,environment:$env,authorized_at:$at}' > "$temp/publish/authorization.json"

  jq -n --slurpfile candidate "$candidate" --slurpfile plan "$plan" --slurpfile captures "$rows" --arg psha "$profile_sha" \
    '{schema_version:"taste-browser-live-manifest/v1",candidate_id:$candidate[0].candidate_id,candidate_source_revision:$candidate[0].source_revision,run_id:$plan[0].run_id,browser:{adapter_id:$plan[0].browser.adapter_id,adapter_version:$plan[0].browser.adapter_version,engine:$plan[0].browser.engine,profile_sha256:$psha},required_routes:$plan[0].routes,required_states:[$plan[0].states[].id],dependency_receipt_path:"dependency-receipt.json",captures:$captures}' > "$temp/publish/capture-manifest.json"

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
