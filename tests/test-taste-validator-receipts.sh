#!/usr/bin/env bash
# Cross-validator receipt chain: every producer emits a hash-bound receipt that
# exposes a deterministic (input_sha256, status, classification) binding and a
# validator fingerprint, and a forged shape-compatible receipt cannot close the
# chain.  This is the seam a certificate compiler consumes; it is exercised here
# without the compiler so the producer contract stands on its own.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

BIN="$(cd "$(dirname "$0")/.." && pwd)/bin"
make_tmpdir
RCPT="$TEST_TMPDIR/receipts"; mkdir -p "$RCPT"
sha() { shasum -a 256 "$1" | awk '{print $1}'; }

# Recompute a validator's declared input hash from its actual input artifact.
# stats binds the canonical JSON; every other producer binds the input file.
recompute_input() {
  case "$1" in
    stats) jq -cS . "$2" | shasum -a 256 | awk '{print $1}' ;;
    *)     shasum -a 256 "$2" | awk '{print $1}' ;;
  esac
}

# ---------------------------------------------------------------------------
# Produce one real receipt from each of the six validators over hermetic input.
# ---------------------------------------------------------------------------

# stats -----------------------------------------------------------------------
STATS_IN="$RCPT/stats-input.json"
cat > "$STATS_IN" <<'JSON'
{"schema":"polylane.taste.ballots.v1","ballots":[
{"brief_id":"b1","vote":"candidate","judge_ids":["judge-1","judge-2"]},
{"brief_id":"b2","vote":"candidate"},
{"brief_id":"b3","vote":"baseline"}]}
JSON
STATS_RCPT="$RCPT/stats-receipt.json"
"$BIN/polylane-taste-stats.sh" aggregate "$STATS_RCPT" < "$STATS_IN"

# corpus ----------------------------------------------------------------------
CORPUS_IN="$RCPT/corpus-input.json"
cat > "$CORPUS_IN" <<'JSON'
{
  "format_version": 1,
  "sources": [
    {"id":"source-a","url":"https://example.test/source-a","source_ref":"v1","source_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","license_receipt":{"spdx":"CC0-1.0","url":"https://creativecommons.org/publicdomain/zero/1.0/","sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}
  ],
  "records": [
    {"id":"analytics-cal-1","source_id":"source-a","domain":"analytics","split":"calibration","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000001","human_rating":4},
    {"id":"analytics-hold-1","source_id":"source-a","domain":"analytics","split":"holdout","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000002","human_rating":3},
    {"id":"commerce-cal-1","source_id":"source-a","domain":"commerce","split":"calibration","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000003","human_rating":5},
    {"id":"commerce-hold-1","source_id":"source-a","domain":"commerce","split":"holdout","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000004","human_rating":2},
    {"id":"productivity-cal-1","source_id":"source-a","domain":"productivity","split":"calibration","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000005","human_rating":1},
    {"id":"productivity-hold-1","source_id":"source-a","domain":"productivity","split":"holdout","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000006","human_rating":4}
  ]
}
JSON
CORPUS_RCPT="$RCPT/corpus-receipt.json"
"$BIN/polylane-taste-corpus.sh" receipt "$CORPUS_IN" holdout 2 fixed-seed "$CORPUS_RCPT"

# calibrate -------------------------------------------------------------------
CAL_IN="$RCPT/calibrate-input.json"
jq -n --argjson correct 20 '
  {
    schema_version: 1,
    calibration: {dataset_id: "human-ui-holdout-v1", partition: "held_out", label_provenance: "human-labeled", holdout_corpus_receipt_sha256: ("f" * 64)},
    judge: {id: "judge-cross-001", provider: "example-provider", model: "example-model", model_version: "2026.08", system_prompt_sha256: ("1" * 64), sampling_sha256: ("2" * 64)},
    units: [range(0; 24) | . as $i | (if ($i % 2) == 0 then 1 else 2 end) as $g | {
      prompt: ("prompt-" + ($i|tostring)), brief: ("brief-" + ($i|tostring)), gold_vote: $g,
      primary: {provider:"example-provider", model:"example-model", vote:(if $i < $correct then $g else (3 - $g) end), request:{prompt:("prompt-" + ($i|tostring)), brief:("brief-" + ($i|tostring))}},
      mirror:  {provider:"example-provider", model:"example-model", vote:(if $i < $correct then (3 - $g) else $g end), request:{prompt:("prompt-" + ($i|tostring)), brief:("brief-" + ($i|tostring))}}
    }]
  }' > "$CAL_IN"
CAL_RCPT="$RCPT/calibrate-receipt.json"
"$BIN/polylane-taste-calibrate.sh" "$CAL_IN" "$CAL_RCPT"

# threat ----------------------------------------------------------------------
TROOT="$TEST_TMPDIR/threat-project"; mkdir -p "$TROOT/shots"
printf 'candidate-a desktop' > "$TROOT/shots/a-desktop.png"
printf 'candidate-b desktop' > "$TROOT/shots/b-desktop.png"
printf 'candidate-c desktop' > "$TROOT/shots/c-desktop.png"
THREAT_IN="$RCPT/threat-input.json"
jq -n --arg root "$TROOT" \
  --arg a "$(sha "$TROOT/shots/a-desktop.png")" \
  --arg b "$(sha "$TROOT/shots/b-desktop.png")" \
  --arg c "$(sha "$TROOT/shots/c-desktop.png")" '
  {schema_version:"taste-threat/v1", source_root:$root,
   hard_gates:{function_pass:true, accessibility_pass:true}, context:{status:"pass"},
   captures:[
     {capture_id:"capture-0000000000000001",brief_id:"brief-001",candidate_id:"cand-0000000000000001",viewport:"1440x900",state:"default",path:"shots/a-desktop.png",sha256:$a,visible_text:["Welcome"]},
     {capture_id:"capture-0000000000000002",brief_id:"brief-002",candidate_id:"cand-0000000000000002",viewport:"1440x900",state:"default",path:"shots/b-desktop.png",sha256:$b,visible_text:["Welcome"]},
     {capture_id:"capture-0000000000000003",brief_id:"brief-003",candidate_id:"cand-0000000000000003",viewport:"1440x900",state:"default",path:"shots/c-desktop.png",sha256:$c,visible_text:["Welcome"]}],
   receipts:[{receipt_id:"receipt-0000000000000001",payload:{adapter:"browser",source_revision:"abc123"},payload_sha256:"placeholder"}],
   sidecars:[
     {brief_id:"brief-001",candidate_id:"cand-0000000000000001",unrelated_group:"retail",render:{capture_id:"capture-0000000000000001",viewport:"1440x900",screenshot_sha256:$a},visual:{layout_family:"grid",primary_information_unit:"card",density_band:"medium",navigation_archetype:"tabs",palette_family:"neutral",accent_hue_bin:"blue",type_pair_class:"sans",shape_language:"rounded"},signature:{mechanism:"task-specific",anchor:"hero"},axis_results:{genericness_review:"unknown",quality_risk:"pass",context_fit:"pass",provenance_integrity:"unknown"}},
     {brief_id:"brief-002",candidate_id:"cand-0000000000000002",unrelated_group:"finance",render:{capture_id:"capture-0000000000000002",viewport:"1440x900",screenshot_sha256:$b},visual:{layout_family:"list",primary_information_unit:"row",density_band:"dense",navigation_archetype:"sidebar",palette_family:"warm",accent_hue_bin:"orange",type_pair_class:"serif",shape_language:"square"},signature:{mechanism:"task-specific",anchor:"summary"},axis_results:{genericness_review:"unknown",quality_risk:"pass",context_fit:"pass",provenance_integrity:"unknown"}},
     {brief_id:"brief-003",candidate_id:"cand-0000000000000003",unrelated_group:"travel",render:{capture_id:"capture-0000000000000003",viewport:"1440x900",screenshot_sha256:$c},visual:{layout_family:"split",primary_information_unit:"map",density_band:"sparse",navigation_archetype:"top",palette_family:"cool",accent_hue_bin:"green",type_pair_class:"display",shape_language:"sharp"},signature:{mechanism:"task-specific",anchor:"route"},axis_results:{genericness_review:"unknown",quality_risk:"pass",context_fit:"pass",provenance_integrity:"unknown"}}]}' > "$THREAT_IN"
receipt_payload=$(jq -c '.receipts[0].payload' "$THREAT_IN")
receipt_hash=$(printf '%s' "$receipt_payload" | shasum -a 256 | awk '{print $1}')
jq --arg hash "$receipt_hash" '.receipts[0].payload_sha256 = $hash' "$THREAT_IN" > "$THREAT_IN.tmp" && mv "$THREAT_IN.tmp" "$THREAT_IN"
THREAT_RCPT="$RCPT/threat-receipt.json"
"$BIN/polylane-taste-threat.sh" check "$THREAT_IN" "$THREAT_RCPT"

# ballot ----------------------------------------------------------------------
BROOT="$TEST_TMPDIR/ballot"; mkdir -p "$BROOT/pointwise"
write_pointwise() { # ballot-id judge-id stimulus-id path
  jq -n --arg ballot_id "$1" --arg judge_id "$2" --arg stimulus_id "$3" '
    {schema_version:"taste-pointwise/v1",ballot_id:$ballot_id,judge_id:$judge_id,
     candidate_id:$stimulus_id,brief_sha256:("a" * 64),capture_manifest_sha256:("b" * 64),
     scores_1_to_7:{product_fit:5,hierarchy:5,typography:5,color:5,spatial_rhythm:5,craftsmanship:5,originality:5,state_coherence:5},
     observations:(["product_fit","hierarchy","typography","color","spatial_rhythm","craftsmanship","originality","state_coherence"] | map({criterion:.,capture_id:"cap-001",region_or_state:"header",brief_clause:"task-1",reason:"observable brief-specific evidence"})),
     identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,
     sealed_at:"2026-08-11T00:00:00Z"}' > "$4"
  body=$(jq -cS . "$4"); digest=$(printf '%s' "$body" | shasum -a 256 | awk '{print $1}')
  jq --arg digest "$digest" '. + {record_sha256:$digest}' "$4" > "$4.tmp" && mv "$4.tmp" "$4"
}
write_pointwise pointwise-a judge-001 stim-a1b2c3d4e5f6 "$BROOT/pointwise/pointwise-a.json"
write_pointwise pointwise-b judge-002 stim-0f1e2d3c4b5a "$BROOT/pointwise/pointwise-b.json"
cat > "$BROOT/calibration.json" <<'JSON'
{"schema_version":"taste-ballot-calibration/v1","judge_eligibility":[
 {"judge_id":"judge-001","eligible":true,"abstention_policy":"pass","independent":true,"no_candidate_identity":true,"no_shared_ballot_channel":true},
 {"judge_id":"judge-002","eligible":true,"abstention_policy":"pass","independent":true,"no_candidate_identity":true,"no_shared_ballot_channel":true}]}
JSON
BALLOT_IN="$BROOT/group.json"
jq -n --arg hash_a "$(sha "$BROOT/pointwise/pointwise-a.json")" --arg hash_b "$(sha "$BROOT/pointwise/pointwise-b.json")" '
  {schema_version:"taste-mirrored-group/v1",mirror_group_id:"mg-001",brief_sha256:("a" * 64),candidate_ids:["stim-a1b2c3d4e5f6","stim-0f1e2d3c4b5a"],candidate_ids_escrow_sha256:("c" * 64),
   pointwise_ballot_ids:["pointwise-a","pointwise-b"],pointwise_sha256:{"pointwise-a":$hash_a,"pointwise-b":$hash_b},
   exposures:[
    {schema_version:"taste-pairwise/v1",ballot_id:"pair-001",judge_id:"judge-001",display_order:"A/B",choice:"A",canonical_choice:"stim-a1b2c3d4e5f6",sealed_at:"2026-08-11T00:01:00Z",response_sha256:("d" * 64),identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,abstain_reason:null},
    {schema_version:"taste-pairwise/v1",ballot_id:"pair-002",judge_id:"judge-002",display_order:"B/A",choice:"B",canonical_choice:"stim-a1b2c3d4e5f6",sealed_at:"2026-08-11T00:01:01Z",response_sha256:("e" * 64),identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,abstain_reason:null}],
   outcome:"resolved-stim-a1b2c3d4e5f6"}' > "$BALLOT_IN"
BALLOT_RCPT="$RCPT/ballot-receipt.json"
"$BIN/polylane-taste-ballot.sh" validate "$BALLOT_IN" "$BROOT/pointwise" "$BROOT/calibration.json" "$BALLOT_RCPT"

# pixels ----------------------------------------------------------------------
PROOT="$TEST_TMPDIR/pixels-project"; mkdir -p "$PROOT/evidence" "$PROOT/tools"
git -C "$PROOT" init -q
git -C "$PROOT" config user.email px@example.test; git -C "$PROOT" config user.name px
printf 'source\n' > "$PROOT/app.txt"; git -C "$PROOT" add app.txt; git -C "$PROOT" commit -qm src
REVISION=$(git -C "$PROOT" rev-parse HEAD)
SOURCE_INPUT_SHA=$(printf '%s' "$REVISION" | shasum -a 256 | awk '{print $1}')
COMMIT_EPOCH=$(git -C "$PROOT" log -1 --format=%ct HEAD)
iso_from_epoch() { date -u -r "$1" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d "@$1" '+%Y-%m-%dT%H:%M:%SZ'; }
NOW=$(iso_from_epoch $((COMMIT_EPOCH + 3600))); export TASTE_NOW="$NOW"
make_png() { python3 - "$1" "$2" "$3" "$4" <<'PY'
import binascii, struct, sys, zlib
path, w, h, seed = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
rows = []
for y in range(h):
    row = bytearray()
    for x in range(w):
        row.extend(((x + seed) % 251, (y * 3 + seed) % 251, (x + y + seed * 11) % 251))
    rows.append(b'\x00' + bytes(row))
raw = b''.join(rows)
def chunk(k, d): return struct.pack('>I', len(d)) + k + d + struct.pack('>I', binascii.crc32(k + d) & 0xffffffff)
open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
PY
}
cat > "$PROOT/tools/decode-png" <<'PY'
#!/usr/bin/env python3
import binascii, hashlib, json, os, struct, sys, zlib
data=open(sys.argv[1],'rb').read()
if data[:8]!=b'\x89PNG\r\n\x1a\n': raise SystemExit('not png')
pos=8; chunks=[]
while pos<len(data):
    size=struct.unpack('>I',data[pos:pos+4])[0]; kind=data[pos+4:pos+8]; body=data[pos+8:pos+8+size]
    if len(kind)!=4 or len(body)!=size or pos+12+size>len(data): raise SystemExit('bad chunk')
    if struct.unpack('>I',data[pos+8+size:pos+12+size])[0]!=binascii.crc32(kind+body)&0xffffffff: raise SystemExit('bad crc')
    chunks.append((kind,body)); pos+=12+size
w,h,depth,kind,comp,flt,interlace=struct.unpack('>IIBBBBB',chunks[0][1])
raw=zlib.decompress(b''.join(b for t,b in chunks if t==b'IDAT')); stride=w*3
pixels=b''.join(raw[y*(stride+1)+1:(y+1)*(stride+1)] for y in range(h))
colors={pixels[i:i+3] for i in range(0,len(pixels),3)}
receipt={"schema_version":"taste-adapter-receipt/v1","adapter_id":"png-decoder","adapter_version":"fixture-v1","command_sha256":hashlib.sha256(open(sys.argv[0],'rb').read()).hexdigest(),"input_sha256":[hashlib.sha256(data).hexdigest()],"output_sha256":[hashlib.sha256(pixels).hexdigest()],"exit_status":0,"executed_at":os.environ["TASTE_NOW"]}
print(json.dumps({"schema_version":"taste-png-decoder/v1","decoded_width":w,"decoded_height":h,"decoded_pixel_sha256":hashlib.sha256(pixels).hexdigest(),"pixel_payload_bytes":len(pixels),"distinct_pixel_values":len(colors),"non_background_pixel_count":sum(p!=b'\xff\xff\xff' for p in colors),"adapter_receipt":receipt},sort_keys=True))
PY
chmod +x "$PROOT/tools/decode-png"
DECODER_SHA=$(sha "$PROOT/tools/decode-png")
make_png "$PROOT/evidence/default-desktop.png" 1440 900 1
make_png "$PROOT/evidence/default-mobile.png" 390 844 2
capture_json() { # id route state viewport w h path
  local result; result=$("$PROOT/tools/decode-png" "$PROOT/evidence/$7")
  jq -n --arg id "$1" --arg route "$2" --arg state "$3" --arg viewport "$4" --argjson width "$5" --argjson height "$6" \
    --arg path "$7" --arg s "$(sha "$PROOT/evidence/$7")" --arg decoded "$(printf '%s' "$result" | jq -r .decoded_pixel_sha256)" --arg now "$NOW" \
    '{capture_id:$id,route:$route,state:$state,viewport:$viewport,viewport_css_px:{width:$width,height:$height},screenshot_path:$path,screenshot_png_sha256:$s,decoded_pixel_sha256:$decoded,decoded_width:$width,decoded_height:$height,action_trace_sha256:("a" * 64),dom_sha256:("c" * 64),captured_at:$now}'
}
PIXELS_IN="$PROOT/evidence/captures.json"
captures=$(printf '%s\n' "$(capture_json cap-dd /declared default desktop 1440 900 default-desktop.png)" "$(capture_json cap-dm /declared default mobile 390 844 default-mobile.png)" | jq -s .)
jq -n --arg rev "$REVISION" --arg decoder "$DECODER_SHA" --argjson captures "$captures" '
  {schema_version:"taste-capture-manifest/v1",candidate_id:"cand-opaque-a",candidate_source_revision:$rev,
   required_routes:["/declared"],required_states:["default"],mobile_only_states:[],
   browser:{adapter_id:"browser-capture",adapter_receipt_path:"browser-receipt.json"},
   decoder:{adapter_id:"png-decoder",adapter_version:"fixture-v1",command_path:"tools/decode-png",command_sha256:$decoder},
   captures:$captures}' > "$PIXELS_IN"
jq -n --arg now "$NOW" --arg source_input "$SOURCE_INPUT_SHA" --argjson outputs "$(jq '[.captures[].screenshot_png_sha256]' "$PIXELS_IN")" \
  '{schema_version:"taste-adapter-receipt/v1",adapter_id:"browser-capture",adapter_version:"fixture-v1",command_sha256:("b" * 64),input_sha256:[$source_input],output_sha256:$outputs,exit_status:0,executed_at:$now}' > "$PROOT/evidence/browser-receipt.json"
PIXELS_RCPT="$RCPT/pixels-receipt.json"
"$BIN/polylane-taste-pixels.sh" verify "$PROOT" "$PIXELS_IN" "$NOW" "$PIXELS_RCPT" >/dev/null

# ---------------------------------------------------------------------------
# Chain bundle: name  input  receipt  helper
# ---------------------------------------------------------------------------
BUNDLE="$TEST_TMPDIR/bundle.tsv"
{
  printf 'pixels\t%s\t%s\t%s\n'    "$PIXELS_IN"  "$PIXELS_RCPT"  "$BIN/polylane-taste-pixels.sh"
  printf 'corpus\t%s\t%s\t%s\n'    "$CORPUS_IN"  "$CORPUS_RCPT"  "$BIN/polylane-taste-corpus.sh"
  printf 'calibrate\t%s\t%s\t%s\n' "$CAL_IN"     "$CAL_RCPT"     "$BIN/polylane-taste-calibrate.sh"
  printf 'stats\t%s\t%s\t%s\n'     "$STATS_IN"   "$STATS_RCPT"   "$BIN/polylane-taste-stats.sh"
  printf 'ballot\t%s\t%s\t%s\n'    "$BALLOT_IN"  "$BALLOT_RCPT"  "$BIN/polylane-taste-ballot.sh"
  printf 'threat\t%s\t%s\t%s\n'    "$THREAT_IN"  "$THREAT_RCPT"  "$BIN/polylane-taste-threat.sh"
} > "$BUNDLE"

# verify_receipt: the minimal closure predicate a certificate compiler applies
# to one producer receipt.  Returns 0 iff the receipt is a genuine, fixture-
# classified, content-addressed validator output.
verify_receipt() { # name input receipt helper
  local name="$1" input="$2" receipt="$3" helper="$4" declared cls fp
  # duplicate keys / invalid JSON fail closed
  jq -e . "$receipt" >/dev/null 2>&1 || return 1
  [ -z "$(jq --stream -r 'select(length==2)|.[0]|map(tostring)|join(".")' "$receipt" | LC_ALL=C sort | uniq -d)" ] || return 1
  # common envelope must be present
  jq -e 'has("input_sha256") and has("status") and has("classification") and (.validator|type=="object" and has("fingerprint") and has("id"))' "$receipt" >/dev/null || return 1
  # deterministic input binding recomputed from the real artifact
  declared=$(jq -r '.input_sha256' "$receipt")
  [ "$declared" = "$(recompute_input "$name" "$input")" ] || return 1
  # fixture/production binding: a production claim needs production_bindings
  cls=$(jq -r '.classification' "$receipt")
  case "$cls" in
    fixture) ;;
    production) jq -e '.production_bindings|type=="object"' "$receipt" >/dev/null || return 1 ;;
    *) return 1 ;;
  esac
  # validator fingerprint must match the real tool
  fp=$(jq -r '.validator.fingerprint' "$receipt")
  [ "$fp" = "$(sha "$helper")" ] || return 1
}

close_chain() { # bundle
  local name input receipt helper
  while IFS=$'\t' read -r name input receipt helper; do
    verify_receipt "$name" "$input" "$receipt" "$helper" || return 1
  done < "$1"
}

# ---------------------------------------------------------------------------
# 1. Every real receipt exposes a deterministic input/status/fixture binding.
# ---------------------------------------------------------------------------
while IFS=$'\t' read -r name input receipt helper; do
  assert_eq "receipt-$name-input-hash-deterministic" "$(recompute_input "$name" "$input")" "$(jq -r '.input_sha256' "$receipt")"
  assert_eq "receipt-$name-classified-fixture" "fixture" "$(jq -r '.classification' "$receipt")"
  assert_eq "receipt-$name-status-nonempty" "true" "$(jq -r '(.status|type=="string" and length>0)' "$receipt")"
  assert_eq "receipt-$name-input-hash-is-sha256" "true" "$(jq -r '.input_sha256|test("^[0-9a-f]{64}$")' "$receipt")"
  assert_eq "receipt-$name-validator-fingerprint" "$(sha "$helper")" "$(jq -r '.validator.fingerprint' "$receipt")"
done < "$BUNDLE"

# The full producer chain closes.
assert_ok "chain-closes-with-real-receipts" close_chain "$BUNDLE"

# ---------------------------------------------------------------------------
# 2. A forged shape-compatible receipt cannot close the chain.
# ---------------------------------------------------------------------------
FORGE="$TEST_TMPDIR/forge.json"

# (a) Tampered input_sha256: shape intact, binding lies about its input.
jq '.input_sha256 = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"' "$PIXELS_RCPT" > "$FORGE"
assert_fail "forged-input-hash-rejected" verify_receipt pixels "$PIXELS_IN" "$FORGE" "$BIN/polylane-taste-pixels.sh"

# (b) Fixture relabeled production without production bindings.
jq '.classification = "production"' "$THREAT_RCPT" > "$FORGE"
assert_fail "fixture-to-production-relabel-rejected" verify_receipt threat "$THREAT_IN" "$FORGE" "$BIN/polylane-taste-threat.sh"

# (c) Forged validator fingerprint (claims a different, trusted tool identity).
jq '.validator.fingerprint = "0000000000000000000000000000000000000000000000000000000000000000"' "$BALLOT_RCPT" > "$FORGE"
assert_fail "forged-validator-fingerprint-rejected" verify_receipt ballot "$BALLOT_IN" "$FORGE" "$BIN/polylane-taste-ballot.sh"

# (d) Cross-run: a real receipt cannot bind a different run's input artifact.
OTHER="$TEST_TMPDIR/other-stats-input.json"
cat > "$OTHER" <<'JSON'
{"schema":"polylane.taste.ballots.v1","ballots":[{"brief_id":"z1","vote":"baseline"}]}
JSON
assert_fail "cross-run-receipt-rejected" verify_receipt stats "$OTHER" "$STATS_RCPT" "$BIN/polylane-taste-stats.sh"

# (e) A hand-built receipt with the right schema string but no real binding.
cat > "$FORGE" <<'JSON'
{"schema_version":"taste-corpus-receipt/v1","status":"VALIDATED","classification":"fixture","input_sha256":"1111111111111111111111111111111111111111111111111111111111111111","validator":{"id":"polylane-taste-corpus","fingerprint":"2222222222222222222222222222222222222222222222222222222222222222"}}
JSON
assert_fail "hand-forged-shape-only-receipt-rejected" verify_receipt corpus "$CORPUS_IN" "$FORGE" "$BIN/polylane-taste-corpus.sh"

# (f) Duplicate JSON keys in a receipt fail closed.
printf '%s\n' '{"input_sha256":"x","input_sha256":"y","status":"VERIFIED","classification":"fixture","validator":{"id":"x","fingerprint":"y"}}' > "$FORGE"
assert_fail "duplicate-key-receipt-rejected" verify_receipt calibrate "$CAL_IN" "$FORGE" "$BIN/polylane-taste-calibrate.sh"

# A forged receipt swapped into the bundle breaks chain closure.
BAD_BUNDLE="$TEST_TMPDIR/bad-bundle.tsv"
jq '.input_sha256 = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"' "$PIXELS_RCPT" > "$RCPT/pixels-forged.json"
sed "s#$PIXELS_RCPT#$RCPT/pixels-forged.json#" "$BUNDLE" > "$BAD_BUNDLE"
assert_fail "chain-rejects-forged-member" close_chain "$BAD_BUNDLE"

finish
