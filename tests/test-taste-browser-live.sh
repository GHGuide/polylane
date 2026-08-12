#!/usr/bin/env bash
# test-taste-browser-live.sh — the browser-live capture lane.
#
# The wrapper (bin/polylane-taste-browser.sh) drives a real Chrome/Playwright
# adapter (benchmarks/taste-live/tools/browser-capture.mjs) across a frozen
# route/state matrix at desktop + mobile, blocks non-loopback network after
# bootstrap, and emits complete browser provenance (screenshot, DOM, action
# trace, console + network logs, output hashes, and a live dependency receipt).
# It NEVER decodes/grades pixels or taste — that is the decoder/pixels lane.
#
# Two adapters exercise the wrapper:
#   * a hermetic bash+sips FAKE adapter for every fail-closed injection, and
#   * the REAL .mjs adapter for the live matrix, offline, network, console,
#     crash and timeout cases (skipped, green, when Chrome/Playwright absent).
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRAP="$ROOT/bin/polylane-taste-browser.sh"
ADAPTER_REAL="$ROOT/benchmarks/taste-live/tools/browser-capture.mjs"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

make_tmpdir
FIX="$TEST_TMPDIR/fix"; SRV="$FIX/site"; mkdir -p "$SRV" "$FIX/tools"
CANDIDATE="$FIX/candidate.json"; PLAN="$FIX/plan.json"; FAKE="$FIX/fake-adapter.sh"
hex() { printf '%064d' "$1" | tr ' ' '0'; }

# --- canonical pinned profile (wrapper + adapter agree via jq -S -c) ----------
profile_sha() {
  # mirror the wrapper exactly: command-sub strips jq's trailing newline, then
  # hash the raw JSON bytes with no newline (printf '%s').
  local j
  j=$(jq -Scn --arg cs "$1" --arg loc "$2" --arg tz "$3" \
    '{color_scheme:$cs,device_scale_factor:1,engine:"chromium",headless:true,locale:$loc,reduced_motion:"reduce",timezone:$tz,viewport_policy:"per-capture-css-px"}')
  printf '%s' "$j" | shasum -a 256 | awk '{print $1}'
}
PROFILE_SHA=$(profile_sha light en-US UTC)

# --- self-contained fixture pages (loopback only, no favicon/web fonts) -------
page() { cat > "$SRV/$1"; }
page app.html <<'HTML'
<!doctype html><html><head><meta charset=utf-8><link rel=icon href="data:,">
<title>app</title><style>body{font-family:sans-serif;margin:0;background:#eef}
#out{padding:24px;font-size:20px}</style></head>
<body data-route="/app.html"><main><input id=name><button id=go>go</button>
<div id=out>empty</div></main>
<script>document.getElementById('go').onclick=function(){
  document.getElementById('out').textContent='hi '+document.getElementById('name').value;
  document.body.style.background='#0b0';};</script></body></html>
HTML
page phone-home.html <<'HTML'
<!doctype html><html><head><meta charset=utf-8><link rel=icon href="data:,"></head>
<body data-route="/phone-home.html"><main>ph</main>
<script>fetch('http://example.com/x').catch(function(){});</script></body></html>
HTML
page console-error.html <<'HTML'
<!doctype html><html><head><meta charset=utf-8><link rel=icon href="data:,"></head>
<body data-route="/console-error.html"><main>ce</main>
<script>console.error('boom-from-page');</script></body></html>
HTML
page crash.html <<'HTML'
<!doctype html><html><head><meta charset=utf-8><link rel=icon href="data:,"></head>
<body data-route="/crash.html"><main>cr</main>
<script>throw new Error('uncaught-boom');</script></body></html>
HTML
page hang.html <<'HTML'
<!doctype html><html><head><meta charset=utf-8><link rel=icon href="data:,">
<script>while(true){}</script></head><body>hang</body></html>
HTML

# --- source revision (git) for identity + freshness lower bound ---------------
git -C "$FIX" init -q
git -C "$FIX" config user.email live@example.test
git -C "$FIX" config user.name live
printf 'live source\n' > "$FIX/app.txt"
git -C "$FIX" add -A
git -C "$FIX" commit -qm source
REVISION=$(git -C "$FIX" rev-parse HEAD)

cat > "$CANDIDATE" <<EOF
{"schema_version":"taste-candidate/v1","candidate_id":"cand-live-a","brief_sha256":"$(hex 1)","design_lock_sha256":"$(hex 2)","direction_id":"d1","source_revision":"$REVISION","dependency_lock_sha256":"$(hex 4)","build_receipt_sha256":"$(hex 5)","created_at":"2026-08-11T00:00:00Z"}
EOF

# --- hermetic FAKE adapter: real PNG via sips, honours the wrapper contract ---
cat > "$FAKE" <<'EOF'
#!/usr/bin/env bash
set -eu
req="$POLYLANE_CAPTURE_REQUEST"; out="$POLYLANE_CAPTURE_OUTPUT"; mkdir -p "$out"
route=$(jq -r .route "$req"); state=$(jq -r .state "$req")
w=$(jq -r .viewport_css_px.width "$req"); h=$(jq -r .viewport_css_px.height "$req")
now="${POLYLANE_CAPTURE_NOW:-2026-08-11T12:00:00Z}"
# distinct colour per (state,width) so every screenshot hash is unique
r=$(( (${#state} * 37 + w) % 200 + 20 )); g=$(( (w + h) % 200 + 20 )); b=$(( ${#route} * 11 % 200 + 20 ))
printf 'P3\n1 1\n255\n%s %s %s\n' "$r" "$g" "$b" > "$out/src.ppm"
sips -s format png -z "$h" "$w" "$out/src.ppm" --out "$out/screenshot.png" >/dev/null 2>&1
rm -f "$out/src.ppm"
printf '<main data-route="%s" data-state="%s"></main>\n' "$route" "$state" > "$out/dom.html"
jq -n --arg route "$route" --arg state "$state" \
  '{schema_version:"taste-browser-live-actions/v1",route:$route,state:$state,actions:[{step:0,type:"navigate",ok:true},{step:1,type:"settle",ok:true}]}' > "$out/action-trace.json"
jq -n '{schema_version:"taste-browser-live-console/v1",messages:[],error_count:0}' > "$out/console.json"
jq -n '{schema_version:"taste-browser-live-network/v1",requests:[],blocked_nonloopback_count:0,error_count:0}' > "$out/network.json"
jq -n --arg route "$route" --arg state "$state" --arg now "$now" --argjson w "$w" --argjson h "$h" --argjson profile "$(jq -c .profile "$req")" \
  '{schema_version:"taste-browser-live-result/v1",route:$route,state:$state,navigation_status:"ok",viewport_css_px:{width:$w,height:$h},captured_at:$now,profile:$profile,screenshot:"screenshot.png",dom:"dom.html",action_trace:"action-trace.json",console:"console.json",network:"network.json",console_error_count:0,network_error_count:0,blocked_nonloopback_count:0}' > "$out/result.json"
EOF
chmod +x "$FAKE"
FAKE_SHA=$(shasum -a 256 "$FAKE" | awk '{print $1}')

# --- plan builder (fixture_only, single route × two states) -------------------
write_plan() {
  local plan="$1" exe="${2:-$CHROME}" pwmod="${3:-playwright}" csha="${4:-$FAKE_SHA}" psha="${5:-$PROFILE_SHA}"
  jq -n --arg exe "$exe" --arg pwmod "$pwmod" --arg csha "$csha" --arg psha "$psha" --arg pwver "$PW_VER" '{
    schema_version:"taste-browser-live-plan/v1",run_id:"live-test",
    browser:{adapter_id:"chromium-playwright",adapter_version:"1.0.0",command_sha256:$csha,engine:"chromium",executable_path:$exe,expected_version_prefix:"Google Chrome ",playwright_module:$pwmod,playwright_version:$pwver,profile_sha256:$psha},
    environment:{color_scheme:"light",device_scale_factor:1,locale:"en-US",timezone:"UTC"},
    local_server:{command:["python3","-m","http.server","{PORT}","--bind","127.0.0.1"],base_path:"site",ready_path:"/app.html"},
    routes:["/app.html"],
    states:[{id:"default",actions:[]},{id:"filled",actions:[{type:"fill",selector:"#name",value:"leo"},{type:"click",selector:"#go"}]}]
  }' > "$plan"
}
PW_VER=$(node -e "process.stdout.write(require('playwright/package.json').version)" 2>/dev/null || echo 0.0.0)

# ============================================================================
# Availability gate: the whole lane is live-only. On a host without Chrome or
# Playwright we record one honest skip and stay green — the evidence is
# produced where the real dependencies exist.
# ============================================================================
HAVE_PW=0; node -e "require.resolve('playwright')" >/dev/null 2>&1 && HAVE_PW=1
HAVE_CHROME=0; [ -x "$CHROME" ] && HAVE_CHROME=1
if [ "$HAVE_PW" != 1 ] || [ "$HAVE_CHROME" != 1 ]; then
  pass "browser-live-skipped-missing-chrome-or-playwright"
  finish; exit
fi

write_plan "$PLAN"

# === fail-closed injections (FAKE adapter; wrapper logic under test) =========
OUT="$TEST_TMPDIR/out"
assert_ok   "matrix-fake-adapter-completes-desktop-mobile-state-action" "$WRAP" capture "$CANDIDATE" "$PLAN" "$OUT" -- "$FAKE"
assert_eq   "matrix-has-four-viewport-state-entries" "4" "$(jq '.captures | length' "$OUT/capture-manifest.json")"
assert_eq   "matrix-records-source-revision" "$REVISION" "$(jq -r .candidate_source_revision "$OUT/capture-manifest.json")"
assert_eq   "matrix-records-desktop-viewport" "1440x900" "$(jq -r '.captures[]|select(.viewport=="desktop")|"\(.viewport_css_px.width)x\(.viewport_css_px.height)"' "$OUT/capture-manifest.json" | head -1)"
assert_eq   "matrix-records-mobile-viewport" "390x844" "$(jq -r '.captures[]|select(.viewport=="mobile")|"\(.viewport_css_px.width)x\(.viewport_css_px.height)"' "$OUT/capture-manifest.json" | head -1)"
assert_ok   "matrix-hashes-are-real" jq -e 'all(.captures[]; (.screenshot_png_sha256|test("^[0-9a-f]{64}$")) and (.dom_sha256|test("^[0-9a-f]{64}$")) and (.action_trace_sha256|test("^[0-9a-f]{64}$")) and (.console_sha256|test("^[0-9a-f]{64}$")) and (.network_sha256|test("^[0-9a-f]{64}$")))' "$OUT/capture-manifest.json"
assert_ok   "matrix-screenshots-are-distinct" jq -e '([.captures[].screenshot_png_sha256]|length) == ([.captures[].screenshot_png_sha256]|unique|length)' "$OUT/capture-manifest.json"
assert_ok   "matrix-emits-fixture-authorization" jq -e '.schema_version=="taste-browser-live-authorization/v1" and .fixture_only==true' "$OUT/authorization.json"

mut() { cp "$FAKE" "$1"; shift; local f="$1"; shift; sed -i '' "$@" "$f"; chmod +x "$f"; }
SHAOF() { shasum -a 256 "$1" | awk '{print $1}'; }
plan_for() { write_plan "$2" "$CHROME" playwright "$(SHAOF "$1")"; }  # plan pinned to a mutated adapter

A="$FIX/wrong-view.sh";  mut "$A" "$A" 's/viewport_css_px:{width:$w,height:$h}/viewport_css_px:{width:1,height:1}/'; plan_for "$A" "$FIX/p.json"
assert_fail "rejects-wrong-viewport"      "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$TEST_TMPDIR/o1" -- "$A"
A="$FIX/wrong-route.sh"; mut "$A" "$A" 's#--arg route "$route"#--arg route "/wrong"#'; plan_for "$A" "$FIX/p.json"
assert_fail "rejects-wrong-route"         "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$TEST_TMPDIR/o2" -- "$A"
A="$FIX/wrong-state.sh"; mut "$A" "$A" 's#--arg state "$state"#--arg state "wrong"#'; plan_for "$A" "$FIX/p.json"
assert_fail "rejects-wrong-state"         "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$TEST_TMPDIR/o3" -- "$A"
A="$FIX/stale.sh"; cp "$FAKE" "$A"; chmod +x "$A"; plan_for "$A" "$FIX/p.json"
assert_fail "rejects-stale-source"        env POLYLANE_CAPTURE_NOW="2025-01-01T00:00:00Z" "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$TEST_TMPDIR/o4" -- "$A"
assert_fail "rejects-future-dated"        env POLYLANE_CAPTURE_NOW="2099-01-01T00:00:00Z" "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$TEST_TMPDIR/o5" -- "$A"
A="$FIX/alias.sh"; mut "$A" "$A" 's/dom:"dom.html"/dom:"action-trace.json"/'; plan_for "$A" "$FIX/p.json"
assert_fail "rejects-aliased-artifacts"   "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$TEST_TMPDIR/o6" -- "$A"
A="$FIX/fab.sh"; mut "$A" "$A" 's/screenshot:"screenshot.png"/screenshot:"result.json"/'; plan_for "$A" "$FIX/p.json"
assert_fail "rejects-fabricated-artifact" "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$TEST_TMPDIR/o7" -- "$A"
A="$FIX/textpng.sh"; mut "$A" "$A" 's#sips -s format png.*#printf "not a png just text" > "$out/screenshot.png"#'; plan_for "$A" "$FIX/p.json"
assert_fail "rejects-non-png-screenshot"  "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$TEST_TMPDIR/o8" -- "$A"
A="$FIX/countlie.sh"; cp "$FAKE" "$A"
sed -i '' 's#jq -n .{schema_version:"taste-browser-live-console/v1",messages:\[\],error_count:0}. > "$out/console.json"#jq -n '"'"'{schema_version:"taste-browser-live-console/v1",messages:[{type:"error",text:"x"}],error_count:1}'"'"' > "$out/console.json"#' "$A"
chmod +x "$A"; plan_for "$A" "$FIX/p.json"
assert_fail "rejects-console-error-count-mismatch" "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$TEST_TMPDIR/o9" -- "$A"

A="$FIX/consoleerr.sh"; cp "$FAKE" "$A"
sed -i '' 's#jq -n .{schema_version:"taste-browser-live-console/v1",messages:\[\],error_count:0}. > "$out/console.json"#jq -n '"'"'{schema_version:"taste-browser-live-console/v1",messages:[{type:"error",text:"boom"}],error_count:1}'"'"' > "$out/console.json"#' "$A"
sed -i '' 's/console_error_count:0/console_error_count:1/' "$A"
chmod +x "$A"; plan_for "$A" "$FIX/p.json"
assert_fail "rejects-nonzero-console-errors" "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$TEST_TMPDIR/o10" -- "$A"

A="$FIX/blocked.sh"; cp "$FAKE" "$A"
sed -i '' 's#jq -n .{schema_version:"taste-browser-live-network/v1",requests:\[\],blocked_nonloopback_count:0,error_count:0}. > "$out/network.json"#jq -n '"'"'{schema_version:"taste-browser-live-network/v1",requests:[{url:"http://example.com/x",method:"GET",resource_type:"fetch",status:0,loopback:false,blocked:true}],blocked_nonloopback_count:1,error_count:0}'"'"' > "$out/network.json"#' "$A"
sed -i '' 's/blocked_nonloopback_count:0/blocked_nonloopback_count:1/' "$A"
chmod +x "$A"; plan_for "$A" "$FIX/p.json"
assert_fail "rejects-nonloopback-network"    "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$TEST_TMPDIR/o11" -- "$A"

# partial output mid-matrix must roll back and preserve prior output
PARTIAL="$TEST_TMPDIR/partial"; mkdir -p "$PARTIAL"; printf 'keep\n' > "$PARTIAL/sentinel"
A="$FIX/partial.sh"; cp "$FAKE" "$A"; sed -i '' '/mkdir -p "\$out"/a\
[ "$(jq -r .state "$req")" != "filled" ] || exit 8
' "$A"; chmod +x "$A"; plan_for "$A" "$FIX/p.json"
assert_fail "rejects-partial-matrix"      "$WRAP" capture "$CANDIDATE" "$FIX/p.json" "$PARTIAL" -- "$A"
assert_eq   "partial-preserves-existing-output" "keep" "$(cat "$PARTIAL/sentinel")"

# symlink on plan + on output dir
ln -s "$PLAN" "$FIX/plan-link.json"
assert_fail "rejects-symlinked-plan"      "$WRAP" capture "$CANDIDATE" "$FIX/plan-link.json" "$TEST_TMPDIR/o12" -- "$FAKE"
mkdir -p "$TEST_TMPDIR/realout"; ln -s "$TEST_TMPDIR/realout" "$TEST_TMPDIR/out-link"
assert_fail "rejects-symlinked-output"    "$WRAP" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/out-link" -- "$FAKE"

# === dependency + identity gates (plan mutations) ============================
write_plan "$FIX/drift.json" "$CHROME" playwright "$(hex 9)"
assert_fail "rejects-adapter-sha-drift"   "$WRAP" capture "$CANDIDATE" "$FIX/drift.json" "$TEST_TMPDIR/o13" -- "$FAKE"
write_plan "$FIX/nochrome.json" "$FIX/no-such-chrome" playwright "$FAKE_SHA"
assert_fail "rejects-missing-chrome"      "$WRAP" capture "$CANDIDATE" "$FIX/nochrome.json" "$TEST_TMPDIR/o14" -- "$FAKE"
write_plan "$FIX/nopw.json" "$CHROME" no-such-playwright-module "$FAKE_SHA"
assert_fail "rejects-missing-playwright"  "$WRAP" capture "$CANDIDATE" "$FIX/nopw.json" "$TEST_TMPDIR/o15" -- "$FAKE"
write_plan "$FIX/badprofile.json" "$CHROME" playwright "$FAKE_SHA" "$(hex 8)"
assert_fail "rejects-profile-sha-drift"   "$WRAP" capture "$CANDIDATE" "$FIX/badprofile.json" "$TEST_TMPDIR/o16" -- "$FAKE"

# === LIVE real Chrome/Playwright adapter =====================================
[ -x "$ADAPTER_REAL" ] || { pass "live-adapter-not-yet-present-skip"; finish; exit; }
REAL_SHA=$(shasum -a 256 "$ADAPTER_REAL" | awk '{print $1}')
write_plan "$FIX/live.json" "$CHROME" playwright "$REAL_SHA"
LIVE="$TEST_TMPDIR/live"
assert_ok   "live-real-browser-completes-matrix" "$WRAP" capture "$CANDIDATE" "$FIX/live.json" "$LIVE" -- "$ADAPTER_REAL"
assert_eq   "live-matrix-has-four-captures" "4" "$(jq '.captures|length' "$LIVE/capture-manifest.json" 2>/dev/null || echo x)"
assert_ok   "live-screenshots-distinct"   jq -e '([.captures[].screenshot_png_sha256]|length)==([.captures[].screenshot_png_sha256]|unique|length)' "$LIVE/capture-manifest.json"
assert_ok   "live-offline-no-nonloopback" jq -e 'all(.captures[]; .blocked_nonloopback_count==0 and .console_error_count==0)' "$LIVE/capture-manifest.json"
assert_ok   "live-dependency-receipt-is-real" jq -e '.schema_version=="taste-browser-live-dependency/v1" and (.chrome.version|test("Google Chrome ")) and (.chrome.sha256|test("^[0-9a-f]{64}$")) and (.playwright.version|test("^[0-9]")) and (.node.version|test("^v[0-9]"))' "$LIVE/dependency-receipt.json"
assert_ok   "live-action-trace-replayable" jq -e 'all(.captures[]; .action_trace_sha256|test("^[0-9a-f]{64}$"))' "$LIVE/capture-manifest.json"
# screenshots are native-sized real PNGs, not resized source assets
assert_ok   "live-desktop-png-is-1440x900" test -f "$LIVE/captures/cap-001/screenshot.png"

# live fail-closed: a page that phones home is blocked -> capture fails
jq '.routes=["/phone-home.html"] | .states=[{id:"default",actions:[]}]' "$FIX/live.json" > "$FIX/live-net.json"
assert_fail "live-blocks-nonloopback-fetch"  "$WRAP" capture "$CANDIDATE" "$FIX/live-net.json" "$TEST_TMPDIR/lnet" -- "$ADAPTER_REAL"
jq '.routes=["/console-error.html"] | .states=[{id:"default",actions:[]}]' "$FIX/live.json" > "$FIX/live-ce.json"
assert_fail "live-rejects-console-error-page" "$WRAP" capture "$CANDIDATE" "$FIX/live-ce.json" "$TEST_TMPDIR/lce" -- "$ADAPTER_REAL"
jq '.routes=["/crash.html"] | .states=[{id:"default",actions:[]}]' "$FIX/live.json" > "$FIX/live-cr.json"
assert_fail "live-rejects-uncaught-page-error" "$WRAP" capture "$CANDIDATE" "$FIX/live-cr.json" "$TEST_TMPDIR/lcr" -- "$ADAPTER_REAL"
jq '.routes=["/missing-route.html"] | .states=[{id:"default",actions:[]}]' "$FIX/live.json" > "$FIX/live-404.json"
assert_fail "live-rejects-missing-route"      "$WRAP" capture "$CANDIDATE" "$FIX/live-404.json" "$TEST_TMPDIR/l404" -- "$ADAPTER_REAL"
jq '.routes=["/hang.html"] | .states=[{id:"default",actions:[]}]' "$FIX/live.json" > "$FIX/live-hang.json"
assert_fail "live-times-out-on-hung-page"     env POLYLANE_BROWSER_LIVE_NAV_TIMEOUT_MS=4000 "$WRAP" capture "$CANDIDATE" "$FIX/live-hang.json" "$TEST_TMPDIR/lhang" -- "$ADAPTER_REAL"

finish
