#!/usr/bin/env bash
# test-tournament-capture-seam.sh — the capture-evidence seam.
#
# The controller does not re-implement pixel validation: it COMPOSES the frozen
# polylane-taste-pixels.sh verifier and adds the tournament-level bindings
# (safe repository-relative paths, source-revision binding, hard-gate provenance,
# cross-candidate divergence). This proves the seam rejects missing, symlinked,
# traversal, stale, tampered/placeholder, and cross-candidate-identical evidence,
# and accepts a complete real desktop/mobile matrix.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
TC="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-visual-tournament.sh"
CAPTURE="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-visual-capture.sh"

command -v jq  >/dev/null 2>&1 || { pass "capture-seam-skipped-no-jq"; finish; exit 0; }
command -v sips >/dev/null 2>&1 || { pass "capture-seam-skipped-no-sips"; finish; exit 0; }
[ -x "$CAPTURE" ] || { pass "capture-seam-skipped-no-capture-helper"; finish; exit 0; }
make_tmpdir
EVID="$TEST_TMPDIR/evid"; mkdir -p "$EVID/tools"
h64() { printf 'seed-%s' "$1" | shasum -a 256 | awk '{print $1}'; }
BRIEF=$(h64 brief)

git -C "$EVID" init -q; git -C "$EVID" config user.email t@e.test; git -C "$EVID" config user.name t
printf 'app\n' > "$EVID/app.txt"; git -C "$EVID" add app.txt; git -C "$EVID" commit -qm src
REV=$(git -C "$EVID" rev-parse HEAD)
cat > "$EVID/tools/decode-png" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
image=$1; pixels="$(dirname "$image")/pixels.rgba"
dims=$(od -An -j16 -N8 -t u1 "$image"); set -- $dims
width=$(( $1*16777216 + $2*65536 + $3*256 + $4 )); height=$(( $5*16777216 + $6*65536 + $7*256 + $8 ))
isha=$(shasum -a 256 "$image" | awk '{print $1}'); psha=$(shasum -a 256 "$pixels" | awk '{print $1}')
pbytes=$(wc -c < "$pixels" | tr -d ' '); csha=$(shasum -a 256 "$0" | awk '{print $1}')
jq -n --arg isha "$isha" --arg psha "$psha" --arg csha "$csha" --arg now "$TASTE_NOW" --argjson w "$width" --argjson hh "$height" --argjson b "$pbytes" \
  '{schema_version:"taste-png-decoder/v1",decoded_width:$w,decoded_height:$hh,decoded_pixel_sha256:$psha,pixel_payload_bytes:$b,distinct_pixel_values:2,non_background_pixel_count:1,adapter_receipt:{schema_version:"taste-adapter-receipt/v1",adapter_id:"png-decoder",adapter_version:"fixture",command_sha256:$csha,input_sha256:[$isha],output_sha256:[$psha],exit_status:0,executed_at:$now}}'
EOF
chmod +x "$EVID/tools/decode-png"
DECODER_SHA=$(shasum -a 256 "$EVID/tools/decode-png" | awk '{print $1}')
cat > "$EVID/adapter.sh" <<'EOF'
#!/usr/bin/env bash
set -eu
req="$POLYLANE_CAPTURE_REQUEST"; out="$POLYLANE_CAPTURE_OUTPUT"
route=$(jq -r .route "$req"); state=$(jq -r .state "$req")
w=$(jq -r .viewport_css_px.width "$req"); hh=$(jq -r .viewport_css_px.height "$req")
mkdir -p "$out"; printf 'P3\n1 1\n255\n0 0 255\n' > "$out/source.ppm"
sips -s format png -z "$hh" "$w" "$out/source.ppm" --out "$out/screenshot.png" >/dev/null
dd if=/dev/zero of="$out/pixels.rgba" bs=4 count=$((w * hh)) 2>/dev/null
printf '%s|%s' "${CAND_TAG:-x}" "$state" | dd of="$out/pixels.rgba" bs=1 conv=notrunc 2>/dev/null
printf '<main data-route="%s" data-state="%s"></main>\n' "$route" "$state" > "$out/dom.html"
printf '{"route":%s,"state":%s,"actions":["navigate","settle"]}\n' "$(printf '%s' "$route" | jq -R .)" "$(printf '%s' "$state" | jq -R .)" > "$out/action-trace.json"
jq -n --arg route "$route" --arg state "$state" --arg cap "${POLYLANE_CAPTURE_NOW}" --argjson w "$w" --argjson hh "$hh" \
  '{schema_version:"taste-browser-capture-result/v1",route:$route,state:$state,navigation_status:"ok",viewport_css_px:{width:$w,height:$hh},screenshot:"screenshot.png",decoded_pixels:"pixels.rgba",dom:"dom.html",action_trace:"action-trace.json",captured_at:$cap}' > "$out/result.json"
EOF
chmod +x "$EVID/adapter.sh"

build_candidate() { # CID TAG
  local cid="$1" tag="$2" man mansha
  jq -n --arg id "$cid" --arg rev "$REV" --arg b "$BRIEF" '{schema_version:"taste-candidate/v1",candidate_id:$id,brief_sha256:$b,design_lock_sha256:$b,direction_id:"d1",source_revision:$rev,dependency_lock_sha256:$b,build_receipt_sha256:$b,created_at:"2020-01-01T00:00:00Z"}' > "$EVID/cand-$cid.json"
  jq -n --arg dsha "$DECODER_SHA" '{schema_version:"taste-capture-plan/v1",run_id:"r",browser:{adapter_id:"browser-capture",adapter_version:"1.0.0",command:"fixture --capture",profile_sha256:"0000000000000000000000000000000000000000000000000000000000000000"},decoder:{adapter_id:"png-decoder",adapter_version:"fixture",command_path:"tools/decode-png",command_sha256:$dsha},environment:{locale:"en-US",timezone:"UTC",color_scheme:"light",device_scale_factor:1},routes:["/checkout"],states:[{id:"default"}]}' > "$EVID/plan-$cid.json"
  CAND_TAG="$tag" POLYLANE_CAPTURE_NOW="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$CAPTURE" capture "$EVID/cand-$cid.json" "$EVID/plan-$cid.json" "$EVID/evidence-$cid" -- "$EVID/adapter.sh" >/dev/null
  man="$EVID/evidence-$cid/capture-manifest.json"; mansha=$(shasum -a 256 "$man" | awk '{print $1}')
  jq -n --arg id "cand-$cid" --arg man "$mansha" '{schema_version:"taste-hard-gate/v1",candidate_id:$id,capture_manifest_sha256:$man,task_results:[{task_id:"t1",capture_id:"cap-001",status:"pass"}],accessibility:[{capture_id:"cap-001",ruleset:"WCAG-2.2",status:"pass"}],state_coverage:[{capture_id:"cap-001",status:"pass"}],product_specificity:{signature_test_sha256:"'"$BRIEF"'",status:"pass"},overall:"PASS"}' > "$EVID/hard-$cid.json"
}
entry() { jq -nc --arg id "cand-$1" --argjson i "$2" --arg man "$3" --arg gate "$4" '{candidate_id:$id,index:$i,capture_root:".",capture_manifest:$man,hard_gate:$gate}'; }
seam_tj() { # FILE E1 E2 E3
  jq -n --arg b "$BRIEF" --arg rev "$REV" --argjson c1 "$2" --argjson c2 "$3" --argjson c3 "$4" \
    '{schema_version:"taste-tournament/v1",run_id:"c39",base_revision:$rev,goal_sha256:$b,design_lock_sha256:$b,candidates:[$c1,$c2,$c3]}' > "$1"
}

build_candidate aaa TAG-AAA
build_candidate bbb TAG-BBB
build_candidate ccc TAG-CCC
build_candidate dup TAG-AAA   # identical render to aaa
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
E_AAA=$(entry aaa 1 "evidence-aaa/capture-manifest.json" "hard-aaa.json")
E_BBB=$(entry bbb 2 "evidence-bbb/capture-manifest.json" "hard-bbb.json")
E_CCC=$(entry ccc 3 "evidence-ccc/capture-manifest.json" "hard-ccc.json")

# ---------------- POSITIVE: complete real desktop/mobile matrix --------------
seam_tj "$EVID/ok.json" "$E_AAA" "$E_BBB" "$E_CCC"
OKOUT=$("$TC" check-captures "$EVID/ok.json" "$NOW" 2>&1) || true
assert_contains "seam-accepts-complete-real-captures" "CAPTURES-OK candidates=3" "$OKOUT"

# ---------------- cross-candidate identical rendered evidence ---------------
seam_tj "$EVID/dup.json" "$E_AAA" "$(entry dup 2 "evidence-dup/capture-manifest.json" "hard-dup.json")" "$E_CCC"
DUPOUT=$("$TC" check-captures "$EVID/dup.json" "$NOW" 2>&1) || true
assert_contains "seam-rejects-cross-candidate-identical" "cross-candidate-identical" "$DUPOUT"

# ---------------- missing capture manifest ---------------------------------
seam_tj "$EVID/missing.json" "$E_AAA" "$(entry bbb 2 "evidence-nope/capture-manifest.json" "hard-bbb.json")" "$E_CCC"
assert_fail "seam-rejects-missing-manifest" "$TC" check-captures "$EVID/missing.json" "$NOW"

# ---------------- symlinked capture manifest -------------------------------
mkdir -p "$EVID/evidence-link"; ln -s "../evidence-bbb/capture-manifest.json" "$EVID/evidence-link/capture-manifest.json"
seam_tj "$EVID/link.json" "$E_AAA" "$(entry bbb 2 "evidence-link/capture-manifest.json" "hard-bbb.json")" "$E_CCC"
LINKOUT=$("$TC" check-captures "$EVID/link.json" "$NOW" 2>&1) || true
assert_contains "seam-rejects-symlinked-manifest" "unsafe capture_manifest" "$LINKOUT"

# ---------------- path traversal -------------------------------------------
seam_tj "$EVID/trav.json" "$E_AAA" "$(entry bbb 2 "../evidence-bbb/capture-manifest.json" "hard-bbb.json")" "$E_CCC"
TRAVOUT=$("$TC" check-captures "$EVID/trav.json" "$NOW" 2>&1) || true
assert_contains "seam-rejects-path-traversal" "unsafe capture_manifest" "$TRAVOUT"

# ---------------- stale source revision ------------------------------------
FAKE=0000000000000000000000000000000000000009
jq --arg r "$FAKE" '.base_revision=$r' "$EVID/ok.json" > "$EVID/stale.json"
STALEOUT=$("$TC" check-captures "$EVID/stale.json" "$NOW" 2>&1) || true
assert_contains "seam-rejects-stale-source" "source != frozen base" "$STALEOUT"

# ---------------- tampered / placeholder screenshot ------------------------
# Corrupt a real screenshot in place: the composed pixel verifier recomputes the
# digest and rejects the mismatch. (A header-only or synthetic placeholder fails
# the same delegated check.)
cp -r "$EVID/evidence-aaa" "$EVID/evidence-tamper"
printf 'junk-bytes-appended' >> "$EVID/evidence-tamper/captures/cap-001/screenshot.png"
seam_tj "$EVID/tamper.json" "$(entry tamper 1 "evidence-tamper/capture-manifest.json" "hard-aaa.json")" "$E_BBB" "$E_CCC"
# hard gate for the tamper candidate must name cand-tamper; reuse aaa's manifest sha (unchanged manifest file).
jq '.candidate_id="cand-tamper"' "$EVID/hard-aaa.json" > "$EVID/hard-tamper.json"
jq '.candidates[0].hard_gate="hard-tamper.json" | .candidates[0].candidate_id="cand-tamper"' "$EVID/tamper.json" > "$EVID/tamper2.json"
TAMPEROUT=$("$TC" check-captures "$EVID/tamper2.json" "$NOW" 2>&1) || true
assert_contains "seam-rejects-tampered-screenshot" "capture evidence rejected" "$TAMPEROUT"

# ---------------- hard-gate provenance mismatch ----------------------------
# A hard gate bound to the wrong capture manifest is rejected before any taste.
jq '.capture_manifest_sha256="'"$(h64 wrong)"'"' "$EVID/hard-bbb.json" > "$EVID/hard-badbind.json"
seam_tj "$EVID/badbind.json" "$E_AAA" "$(entry bbb 2 "evidence-bbb/capture-manifest.json" "hard-badbind.json")" "$E_CCC"
BBOUT=$("$TC" check-captures "$EVID/badbind.json" "$NOW" 2>&1) || true
assert_contains "seam-rejects-hardgate-manifest-mismatch" "hard-gate veto failed" "$BBOUT"

# ---------------- capture_root must be a real (non-symlink) git tree -------
ln -s "$EVID" "$EVID/rootlink"
seam_tj "$EVID/rootlink.json" "$(entry aaa 1 "evidence-aaa/capture-manifest.json" "hard-aaa.json")" "$E_BBB" "$E_CCC"
jq '.candidates[0].capture_root="rootlink"' "$EVID/rootlink.json" > "$EVID/rootlink2.json"
RLOUT=$("$TC" check-captures "$EVID/rootlink2.json" "$NOW" 2>&1) || true
assert_contains "seam-rejects-symlinked-capture-root" "unsafe capture_root" "$RLOUT"

finish
