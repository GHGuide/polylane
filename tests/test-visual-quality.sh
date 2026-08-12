#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

QUALITY="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-visual-quality.sh"
make_tmpdir

# ===========================================================================
# Legacy modes (old-mode compatibility). certify must not disturb these.
# ===========================================================================
ROOT="$TEST_TMPDIR/project"; mkdir -p "$ROOT/shots"
for state in desktop mobile empty loading error hover focus; do printf '\211PNG\r\n\032\n' > "$ROOT/shots/$state.png"; done
EVIDENCE="$TEST_TMPDIR/evidence.json"; CONTRACT="$TEST_TMPDIR/contract.json"; OUT="$TEST_TMPDIR/visual-verdict.json"
cat > "$EVIDENCE" <<'JSON'
{"schema":1,"root":"PROJECT_ROOT","anonymized":true,"screenshots":[
 {"surface":"home","viewport":"desktop","state":"default","path":"shots/desktop.png"},
 {"surface":"home","viewport":"mobile","state":"default","path":"shots/mobile.png"},
 {"surface":"home","viewport":"desktop","state":"empty","path":"shots/empty.png"},
 {"surface":"home","viewport":"desktop","state":"loading","path":"shots/loading.png"},
 {"surface":"home","viewport":"desktop","state":"error","path":"shots/error.png"},
 {"surface":"home","viewport":"desktop","state":"hover","path":"shots/hover.png"},
 {"surface":"home","viewport":"desktop","state":"focus","path":"shots/focus.png"}],
 "flow":[{"surface":"home","action":"open","result":"detail"}],"texts":["Original copy"],"assets":["own.svg"],"generic_patterns":[],
 "lenses":[{"lens":"originality","status":"passed","findings":[]},{"lens":"fit_polish","status":"passed","findings":[]},{"lens":"accessibility","status":"passed","findings":[]}]}
JSON
sed "s|PROJECT_ROOT|$ROOT|" "$EVIDENCE" > "$EVIDENCE.tmp" && mv "$EVIDENCE.tmp" "$EVIDENCE"
printf '%s\n' '{"prohibited_text":["Copied launch copy"],"prohibited_assets":["brand-logo.svg"]}' > "$CONTRACT"

assert_eq "visual-quality-all-lenses-must-pass" "passed" "$("$QUALITY" run "$EVIDENCE" "$CONTRACT" "$OUT" 2>/dev/null && jq -r .status "$OUT")"
assert_ok "visual-quality-writes-promotion-verdict" test -s "$OUT"
printf '%s' 'not an image' > "$ROOT/shots/error.png"
assert_fail "visual-quality-rejects-nonimage-evidence" "$QUALITY" run "$EVIDENCE" "$CONTRACT" "$OUT"
printf '\211PNG\r\n\032\n' > "$ROOT/shots/error.png"

jq '.anonymized = false' "$EVIDENCE" > "$EVIDENCE.tmp" && mv "$EVIDENCE.tmp" "$EVIDENCE"
assert_fail "visual-quality-rejects-non-anonymized-evidence" "$QUALITY" run "$EVIDENCE" "$CONTRACT" "$OUT"

CORPUS="$TEST_TMPDIR/corpus.json"; BENCHMARK_OUT="$TEST_TMPDIR/benchmark.json"
cat > "$CORPUS" <<'JSON'
{"schema":1,"prompts":[
 {"id":"p1","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p2","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p3","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p4","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p5","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p6","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p7","old":{"distinction":4,"polish":4,"accessibility":9},"new":{"distinction":7,"polish":7,"accessibility":9}},
 {"id":"p8","old":{"distinction":7,"polish":7,"accessibility":9},"new":{"distinction":4,"polish":4,"accessibility":9}},
 {"id":"p9","old":{"distinction":7,"polish":7,"accessibility":9},"new":{"distinction":4,"polish":4,"accessibility":9}},
 {"id":"p10","old":{"distinction":7,"polish":7,"accessibility":9},"new":{"distinction":4,"polish":4,"accessibility":9}}]}
JSON
assert_eq "visual-benchmark-requires-seventy-percent-decisive-wins" "passed" "$("$QUALITY" benchmark "$CORPUS" "$BENCHMARK_OUT" 2>/dev/null && jq -r .status "$BENCHMARK_OUT")"
jq '.prompts[0].old={"distinction":4,"polish":9,"accessibility":9} | .prompts[0].new={"distinction":9,"polish":5,"accessibility":9}' "$CORPUS" > "$CORPUS.tmp" && mv "$CORPUS.tmp" "$CORPUS"
assert_fail "visual-benchmark-rejects-tradeoff-that-loses-polish" "$QUALITY" benchmark "$CORPUS" "$BENCHMARK_OUT"
jq '.prompts[0].new.accessibility = 8' "$CORPUS" > "$CORPUS.tmp" && mv "$CORPUS.tmp" "$CORPUS"
assert_fail "visual-benchmark-rejects-accessibility-regression" "$QUALITY" benchmark "$CORPUS" "$BENCHMARK_OUT"

# ===========================================================================
# certify — Cycle 39 authoritative adapter over real receipts.
# ===========================================================================
if ! command -v python3 >/dev/null 2>&1; then
  echo "PASS certify-suite-skipped-no-python3"
  finish
fi

CROOT="$TEST_TMPDIR/cert"; EV="$CROOT/evidence"
mkdir -p "$EV" "$CROOT/tools"
git -C "$CROOT" init -q
git -C "$CROOT" config user.email cert@example.test
git -C "$CROOT" config user.name cert
printf 'candidate source\n' > "$CROOT/app.txt"
git -C "$CROOT" add app.txt
git -C "$CROOT" commit -qm source
REV=$(git -C "$CROOT" rev-parse HEAD)
SRC_INPUT_SHA=$(printf '%s' "$REV" | shasum -a 256 | awk '{print $1}')
REV_B=$(printf 'candidate-b-%s' "$REV" | shasum -a 256 | awk '{print substr($1,1,40)}')
REV_C=$(printf 'candidate-c-%s' "$REV" | shasum -a 256 | awk '{print substr($1,1,40)}')

make_png() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import binascii, struct, sys, zlib
path, width, height, seed = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
rows = []
for y in range(height):
    row = bytearray()
    for x in range(width):
        row.extend(((x + seed) % 251, (y * 3 + seed) % 251, (x + y + seed * 11) % 251))
    rows.append(b'\x00' + bytes(row))
raw = b''.join(rows)
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', binascii.crc32(kind + data) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
open(path, 'wb').write(png)
PY
}

cat > "$CROOT/tools/decode-png" <<'PY'
#!/usr/bin/env python3
import binascii, hashlib, json, os, struct, sys, zlib
data = open(sys.argv[1], 'rb').read()
if data[:8] != b'\x89PNG\r\n\x1a\n': raise SystemExit('not png')
pos = 8; chunks = []
while pos < len(data):
    size = struct.unpack('>I', data[pos:pos+4])[0]; kind = data[pos+4:pos+8]; body = data[pos+8:pos+8+size]
    if len(kind) != 4 or len(body) != size or pos + 12 + size > len(data): raise SystemExit('bad chunk')
    if struct.unpack('>I', data[pos+8+size:pos+12+size])[0] != binascii.crc32(kind + body) & 0xffffffff: raise SystemExit('bad crc')
    chunks.append((kind, body)); pos += 12 + size
if pos != len(data) or chunks[0][0] != b'IHDR' or chunks[-1][0] != b'IEND': raise SystemExit('bad structure')
w,h,depth,kind,comp,flt,interlace = struct.unpack('>IIBBBBB', chunks[0][1])
if (depth,kind,comp,flt,interlace) != (8,2,0,0,0): raise SystemExit('unsupported fixture format')
raw = zlib.decompress(b''.join(body for tag, body in chunks if tag == b'IDAT'))
stride = w * 3
if len(raw) != h * (stride + 1) or any(raw[y * (stride + 1)] != 0 for y in range(h)): raise SystemExit('bad pixels')
pixels = b''.join(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)] for y in range(h))
colors = {pixels[i:i+3] for i in range(0, len(pixels), 3)}
receipt = {"schema_version":"taste-adapter-receipt/v1","adapter_id":"png-decoder","adapter_version":"fixture-v1","command_sha256":hashlib.sha256(open(sys.argv[0], 'rb').read()).hexdigest(),"input_sha256":[hashlib.sha256(data).hexdigest()],"output_sha256":[hashlib.sha256(pixels).hexdigest()],"exit_status":0,"executed_at":os.environ["TASTE_NOW"]}
print(json.dumps({"schema_version":"taste-png-decoder/v1","decoded_width":w,"decoded_height":h,"decoded_pixel_sha256":hashlib.sha256(pixels).hexdigest(),"pixel_payload_bytes":len(pixels),"distinct_pixel_values":len(colors),"non_background_pixel_count":sum(pixel != b'\xff\xff\xff' for pixel in colors),"adapter_receipt":receipt}, sort_keys=True))
PY
chmod +x "$CROOT/tools/decode-png"
DECODER_SHA=$(shasum -a 256 "$CROOT/tools/decode-png" | awk '{print $1}')
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ'); export TASTE_NOW="$NOW"
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
sha_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

# 12 real captures: six states x desktop/mobile, all with distinct pixels.
STATES="default empty error focus hover loading"
seed=1
for st in $STATES; do
  make_png "$EV/$st-desktop.png" 1440 900 "$seed"; seed=$((seed + 1))
  make_png "$EV/$st-mobile.png" 390 844 "$seed"; seed=$((seed + 1))
done

capture_json() {
  local id="$1" state="$2" viewport="$3" width="$4" height="$5" path="$6" result
  result=$("$CROOT/tools/decode-png" "$EV/$path")
  jq -n --arg id "$id" --arg state "$state" --arg viewport "$viewport" \
    --argjson width "$width" --argjson height "$height" --arg path "$path" --arg sha "$(sha "$EV/$path")" \
    --arg decoded "$(printf '%s' "$result" | jq -r .decoded_pixel_sha256)" --arg now "$NOW" \
    '{capture_id:$id,route:"/app",state:$state,viewport:$viewport,viewport_css_px:{width:$width,height:$height},screenshot_path:$path,screenshot_png_sha256:$sha,decoded_pixel_sha256:$decoded,decoded_width:$width,decoded_height:$height,action_trace_sha256:("a" * 64),dom_sha256:("c" * 64),captured_at:$now}'
}

MANIFEST="$EV/captures.json"
write_manifest() {
  local include="${1:-$STATES}" caps=()
  for st in $include; do
    caps+=("$(capture_json "cap-$st-desktop" "$st" desktop 1440 900 "$st-desktop.png")")
    caps+=("$(capture_json "cap-$st-mobile" "$st" mobile 390 844 "$st-mobile.png")")
  done
  local states_json; states_json=$(printf '%s\n' $include | jq -R . | jq -s .)
  jq -n --arg rev "$REV" --arg decoder "$DECODER_SHA" --argjson caps "$(printf '%s\n' "${caps[@]}" | jq -s .)" --argjson states "$states_json" '
    {schema_version:"taste-capture-manifest/v1",candidate_id:"cand-a",candidate_source_revision:$rev,
     required_routes:["/app"],required_states:$states,mobile_only_states:[],
     browser:{adapter_id:"browser-capture",adapter_receipt_path:"browser-receipt.json"},
     decoder:{adapter_id:"png-decoder",adapter_version:"fixture-v1",command_path:"tools/decode-png",command_sha256:$decoder},
     captures:$caps}' > "$2"
  jq -n --arg now "$NOW" --arg src "$SRC_INPUT_SHA" --argjson outs "$(jq '[.captures[].screenshot_png_sha256]' "$2")" \
    '{schema_version:"taste-adapter-receipt/v1",adapter_id:"browser-capture",adapter_version:"fixture-v1",command_sha256:("b" * 64),input_sha256:[$src],output_sha256:$outs,exit_status:0,executed_at:$now}' > "$EV/browser-receipt.json"
}
write_manifest "$STATES" "$MANIFEST"

# Producer receipts (hard gate, threat, repair ledger, tournament).
HARD="$EV/hard-gate.json"
cat > "$HARD" <<JSON
{"schema_version":"taste-hard-gate/v1","candidate_id":"cand-a","capture_manifest_sha256":"$(sha "$MANIFEST")","overall":"PASS",
 "task_results":[{"task_id":"t1","capture_id":"cap-default-desktop","status":"pass","trace_sha256":"$(printf 0 | shasum -a 256 | awk '{print $1}')"}],
 "accessibility":[{"capture_id":"cap-default-desktop","ruleset":"WCAG-2.2","adapter_receipt_sha256":"$(printf 1 | shasum -a 256 | awk '{print $1}')","status":"pass","manual_exception_ids":[]}],
 "state_coverage":[{"capture_id":"cap-default-desktop","status":"pass"}]}
JSON
THREAT="$EV/threat.json"
cat > "$THREAT" <<'JSON'
{"schema_version":"taste-threat-receipt/v1","status":"clean","axis_results":{"genericness_review":"pass","quality_risk":"pass","context_fit":"pass","provenance_integrity":"pass"},"review":{"status":"not-required","attribution_claim":false},"reason_codes":[]}
JSON
LEDGER="$EV/repair-ledger.json"
cat > "$LEDGER" <<JSON
{"schema_version":"taste-repair-ledger/v1","status":"valid","brief_id":"brief-1","design_lock_sha256":"$(printf lock | shasum -a 256 | awk '{print $1}')","attempts":0,"sha256":"$(printf ledger | shasum -a 256 | awk '{print $1}')"}
JSON

LOCK_SHA=$(printf 'design-lock' | shasum -a 256 | awk '{print $1}')
GOAL_SHA=$(printf 'literal-goal' | shasum -a 256 | awk '{print $1}')
PACKET_SHA=$(printf 'packet' | shasum -a 256 | awk '{print $1}')
INPUT_SHA=$(printf 'tournament-input' | shasum -a 256 | awk '{print $1}')

TOURNAMENT="$EV/tournament.json"
write_tournament() {
  # $1 output path, $2 = jq post-filter (default identity)
  jq -n --arg run "cert-run-1" --arg lock "$LOCK_SHA" --arg reva "$REV" --arg revb "$REV_B" --arg revc "$REV_C" \
    --arg evlog "$(printf evlog | shasum -a 256 | awk '{print $1}')" '
    {schema_version:"taste-tournament-receipt/v1",run_id:$run,design_lock_sha256:$lock,selection_label:"SELECTED_NOT_CERTIFIED",
     candidates:[{candidate_id:"cand-a",source_revision:$reva,direction_id:"d1"},
                 {candidate_id:"cand-b",source_revision:$revb,direction_id:"d2"},
                 {candidate_id:"cand-c",source_revision:$revc,direction_id:"d3"}],
     pairs:[
       {pair:"1-2",canonical_winner:"cand-a",exposures:[{display_order:"A/B",judge_id:"j1",canonical_choice:"cand-a"},{display_order:"B/A",judge_id:"j2",canonical_choice:"cand-a"}]},
       {pair:"1-3",canonical_winner:"cand-a",exposures:[{display_order:"A/B",judge_id:"j2",canonical_choice:"cand-a"},{display_order:"B/A",judge_id:"j1",canonical_choice:"cand-a"}]},
       {pair:"2-3",canonical_winner:"cand-b",exposures:[{display_order:"A/B",judge_id:"j1",canonical_choice:"cand-b"},{display_order:"B/A",judge_id:"j2",canonical_choice:"cand-b"}]}],
     judges:[{judge_id:"j1",calibration:"eligible"},{judge_id:"j2",calibration:"eligible"}],
     event_log_sha256:$evlog,previous_event_sha256:null}
  ' | jq "${2:-.}" > "$1"
}
write_tournament "$TOURNAMENT"

# Canonical record.
RECORD="$EV/record.json"
write_record() {
  # $1 output path; $2 jq post-filter; $3 tournament path (default TOURNAMENT); $4 capture manifest rel (default captures.json)
  local out="$1" filter="${2:-.}" tpath="${3:-$TOURNAMENT}" caprel="${4:-captures.json}"
  jq -n --arg run "cert-run-1" --arg goal "$GOAL_SHA" --arg packet "$PACKET_SHA" --arg lock "$LOCK_SHA" \
    --arg input "$INPUT_SHA" --arg trec "$(basename "$tpath")" --arg tsha "$(sha "$tpath")" --arg rev "$REV" \
    --arg caprel "$caprel" --argjson states "$(printf '%s\n' $STATES | jq -R . | jq -s .)" '
    {schema_version:"visual-quality-record/v2",run_id:$run,literal_goal_sha256:$goal,packet_sha256:$packet,design_lock_sha256:$lock,
     capture_manifest:$caprel,hard_gate:"hard-gate.json",threat_receipt:"threat.json",repair_ledger:"repair-ledger.json",
     required_states:$states,generic_patterns:["centered-card"],outstanding_findings:[],taste_memory_proposal:null,repair:null,
     tournament:{input_sha256:$input,receipt:$trec,receipt_sha256:$tsha,selected_candidate_id:"cand-a",selected_source_revision:$rev},
     champion:{decision:"promote",generation:1,incumbent_candidate_id:null,previous_champion_sha256:null}}
  ' | jq "$filter" > "$out"
}
write_record "$RECORD"

certify() { bash "$QUALITY" certify "$CROOT" "$1" "$2" "${3:-0}"; }
VOUT="$EV/verdict.json"

# --- Positive authoritative record.
prc=0; certify "$RECORD" "$VOUT" >/dev/null 2>&1 || prc=$?
assert_eq "certify-accepts-authoritative-record" 0 "$prc"
assert_eq "certify-positive-status-passed" "passed" "$(jq -r .status "$VOUT")"
assert_eq "certify-positive-label-selected-not-certified" "SELECTED_NOT_CERTIFIED" "$(jq -r .claim_label "$VOUT")"
assert_eq "certify-positive-never-claims-human" "false" "$(jq -r .human_claim "$VOUT")"
assert_eq "certify-positive-winner-is-cand-a" "cand-a" "$(jq -r .condorcet_winner "$VOUT")"
assert_eq "certify-positive-binds-capture-hash" "$(sha "$MANIFEST")" "$(jq -r .capture_manifest_sha256 "$VOUT")"
assert_eq "certify-positive-generic-pattern-is-signal-not-veto" "centered-card" "$(jq -r '.generic_pattern_signals[0]' "$VOUT")"

# --- v2 missing pixel/capture receipt.
write_record "$EV/rec-nocap.json" '.capture_manifest="missing.json"'
certify "$EV/rec-nocap.json" "$VOUT" >/dev/null 2>&1 || true
assert_eq "certify-missing-capture-receipt-blocks" "blocked" "$(jq -r .status "$VOUT")"

# --- Prose masquerading as proof (unknown key).
write_record "$EV/rec-prose.json" '. + {verdict:"looks great — pass it"}'
certify "$EV/rec-prose.json" "$VOUT" >/dev/null 2>&1 || true
assert_eq "certify-prose-field-rejected" "blocked" "$(jq -r .status "$VOUT")"
assert_contains "certify-prose-reason-record-invalid" "RECORD_INVALID" "$(jq -r '.reason_codes|join(",")' "$VOUT")"

# --- Caller-declared winner disagreeing with the derived Condorcet winner.
write_record "$EV/rec-winner.json" '.tournament.selected_candidate_id="cand-b"'
certify "$EV/rec-winner.json" "$VOUT" >/dev/null 2>&1 || true
assert_eq "certify-caller-winner-blocks" "blocked" "$(jq -r .status "$VOUT")"
assert_contains "certify-caller-winner-reason" "CALLER_WINNER_MISMATCH" "$(jq -r '.reason_codes|join(",")' "$VOUT")"

# --- Tournament receipt hash mismatch.
write_record "$EV/rec-hash.json" '.tournament.receipt_sha256="'"$(printf zzz | shasum -a 256 | awk '{print $1}')"'"'
certify "$EV/rec-hash.json" "$VOUT" >/dev/null 2>&1 || true
assert_eq "certify-hash-mismatch-blocks" "blocked" "$(jq -r .status "$VOUT")"
assert_contains "certify-hash-mismatch-reason" "TOURNAMENT_RECEIPT_INVALID" "$(jq -r '.reason_codes|join(",")' "$VOUT")"

# --- Weak (uncalibrated) judge in a deciding exposure.
write_tournament "$EV/tournament-weak.json" '.judges[0].calibration="pending"'
write_record "$EV/rec-weak.json" '.' "$EV/tournament-weak.json"
certify "$EV/rec-weak.json" "$VOUT" >/dev/null 2>&1 || true
assert_eq "certify-weak-judge-blocks" "blocked" "$(jq -r .status "$VOUT")"
assert_contains "certify-weak-judge-reason" "WEAK_JUDGE" "$(jq -r '.reason_codes|join(",")' "$VOUT")"

# --- Accessibility regression is a hard veto.
jq '.accessibility[0].status="fail"' "$HARD" > "$HARD.tmp" && mv "$HARD.tmp" "$HARD"
certify "$RECORD" "$VOUT" >/dev/null 2>&1 || true
assert_eq "certify-accessibility-regression-vetoes" "blocked" "$(jq -r .status "$VOUT")"
assert_contains "certify-accessibility-veto-reason" "ACCESSIBILITY_VETO" "$(jq -r '.reason_codes|join(",")' "$VOUT")"
cat > "$HARD" <<JSON
{"schema_version":"taste-hard-gate/v1","candidate_id":"cand-a","capture_manifest_sha256":"$(sha "$MANIFEST")","overall":"PASS",
 "task_results":[{"task_id":"t1","capture_id":"cap-default-desktop","status":"pass","trace_sha256":"$(printf 0 | shasum -a 256 | awk '{print $1}')"}],
 "accessibility":[{"capture_id":"cap-default-desktop","ruleset":"WCAG-2.2","adapter_receipt_sha256":"$(printf 1 | shasum -a 256 | awk '{print $1}')","status":"pass","manual_exception_ids":[]}],
 "state_coverage":[{"capture_id":"cap-default-desktop","status":"pass"}]}
JSON

# --- Missing required state in the declared capture matrix.
write_manifest "default empty error focus hover" "$EV/cap-missing.json"
write_record "$EV/rec-missing.json" '.hard_gate="hard-gate.json"' "$TOURNAMENT" "cap-missing.json"
# hard gate binds capture_manifest_sha of the full manifest; realign candidate check only.
certify "$EV/rec-missing.json" "$VOUT" >/dev/null 2>&1 || true
assert_eq "certify-missing-state-blocks" "blocked" "$(jq -r .status "$VOUT")"
assert_contains "certify-missing-state-reason" "MISSING_STATE:loading" "$(jq -r '.reason_codes|join(",")' "$VOUT")"
write_manifest "$STATES" "$MANIFEST"

# --- Rendered prompt injection / provenance flag in threat receipt.
jq '.status="flagged" | .reason_codes=["INJECTION_SIGNAL"]' "$THREAT" > "$THREAT.tmp" && mv "$THREAT.tmp" "$THREAT"
certify "$RECORD" "$VOUT" >/dev/null 2>&1 || true
assert_eq "certify-prompt-injection-blocks" "blocked" "$(jq -r .status "$VOUT")"
assert_contains "certify-injection-reason" "PROVENANCE_VETO" "$(jq -r '.reason_codes|join(",")' "$VOUT")"
cat > "$THREAT" <<'JSON'
{"schema_version":"taste-threat-receipt/v1","status":"clean","axis_results":{"genericness_review":"pass","quality_risk":"pass","context_fit":"pass","provenance_integrity":"pass"},"review":{"status":"not-required","attribution_claim":false},"reason_codes":[]}
JSON

# --- Missing external browser/decoder adapter is external, never pass.
jq '.decoder.command_path="tools/missing-decoder"' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
certify "$RECORD" "$VOUT" >/dev/null 2>&1 || true
assert_eq "certify-missing-adapter-is-external" "external" "$(jq -r .status "$VOUT")"
write_manifest "$STATES" "$MANIFEST"

# --- Unchanged repair (attempt 1 with changed=false) halts, preserves incumbent.
write_record "$EV/rec-unchanged.json" '.repair={changed:false,failed_criterion:"hierarchy",region_or_state:"header/default",prior_evidence_sha256:"'"$(sha "$MANIFEST")"'"} | .outstanding_findings=[{criterion:"hierarchy",region_or_state:"header/default"}]'
certify "$EV/rec-unchanged.json" "$VOUT" 1 >/dev/null 2>&1 || true
assert_eq "certify-unchanged-repair-halts" "halted" "$(jq -r .status "$VOUT")"
assert_contains "certify-unchanged-repair-reason" "REPAIR_UNCHANGED" "$(jq -r '.reason_codes|join(",")' "$VOUT")"

# --- Third repair (attempt 3) halts on the frozen two-token budget.
certify "$RECORD" "$VOUT" 3 >/dev/null 2>&1 || true
assert_eq "certify-third-repair-halts" "halted" "$(jq -r .status "$VOUT")"
assert_contains "certify-third-repair-reason" "REPAIR_BUDGET_EXHAUSTED" "$(jq -r '.reason_codes|join(",")' "$VOUT")"

# --- A grounded, evidence-changed repair with an open finding requests a repair.
write_record "$EV/rec-repair.json" '.repair={changed:true,failed_criterion:"hierarchy",region_or_state:"header/default",prior_evidence_sha256:"'"$(printf stale | shasum -a 256 | awk '{print $1}')"'"} | .outstanding_findings=[{criterion:"hierarchy",region_or_state:"header/default"}]'
certify "$EV/rec-repair.json" "$VOUT" 1 >/dev/null 2>&1 || true
assert_eq "certify-grounded-repair-requests-repair" "repair" "$(jq -r .status "$VOUT")"
assert_eq "certify-repair-target-is-grounded" "hierarchy" "$(jq -r '.repair_targets[0].criterion' "$VOUT")"

# --- Caller-supplied status field can never coerce a pass (untrusted).
prc=0; certify "$RECORD" "$VOUT" >/dev/null 2>&1 || prc=$?
assert_eq "certify-final-positive-still-passes" 0 "$prc"

finish
