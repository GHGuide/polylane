#!/usr/bin/env bash
# test-visual-tournament.sh — end-to-end fail-closed visual tournament.
#
# Real decoded-PNG fixtures drive a complete blind three-candidate round-robin.
# The controller COMPOSES the frozen pixel + ballot validators; the winner is
# derived from evidence, never from a caller-supplied winner/pass/score/prose.
# Positive: zero-repair Condorcet selection. Negative: two/four candidates,
# cross-candidate-identical pixels, stale source, lock mismatch, missing match,
# 1-1-1 cycle, failed hard gate, and caller-authored winner/pass/score injection.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
TC="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-visual-tournament.sh"
CAPTURE="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-visual-capture.sh"

command -v jq  >/dev/null 2>&1 || { pass "visual-tournament-skipped-no-jq"; finish; exit 0; }
command -v sips >/dev/null 2>&1 || { pass "visual-tournament-skipped-no-sips"; finish; exit 0; }
[ -x "$CAPTURE" ] || { pass "visual-tournament-skipped-no-capture-helper"; finish; exit 0; }
make_tmpdir
EVID="$TEST_TMPDIR/evid"; mkdir -p "$EVID/tools"
h64() { printf 'seed-%s' "$1" | shasum -a 256 | awk '{print $1}'; }
BRIEF=$(h64 brief); CAPMAN=$(h64 capman)
CRIT='["color","craftsmanship","hierarchy","originality","product_fit","spatial_rhythm","state_coherence","typography"]'

# --- git-backed source + declared decoder (mirrors the capture contract) ------
git -C "$EVID" init -q
git -C "$EVID" config user.email t@e.test; git -C "$EVID" config user.name t
printf 'app\n' > "$EVID/app.txt"; git -C "$EVID" add app.txt; git -C "$EVID" commit -qm src
REV=$(git -C "$EVID" rev-parse HEAD)
cat > "$EVID/tools/decode-png" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
image=$1; pixels="$(dirname "$image")/pixels.rgba"
dims=$(od -An -j16 -N8 -t u1 "$image"); set -- $dims
width=$(( $1*16777216 + $2*65536 + $3*256 + $4 ))
height=$(( $5*16777216 + $6*65536 + $7*256 + $8 ))
isha=$(shasum -a 256 "$image" | awk '{print $1}'); psha=$(shasum -a 256 "$pixels" | awk '{print $1}')
pbytes=$(wc -c < "$pixels" | tr -d ' '); csha=$(shasum -a 256 "$0" | awk '{print $1}')
jq -n --arg isha "$isha" --arg psha "$psha" --arg csha "$csha" --arg now "$TASTE_NOW" --argjson w "$width" --argjson hh "$height" --argjson b "$pbytes" \
  '{schema_version:"taste-png-decoder/v1",decoded_width:$w,decoded_height:$hh,decoded_pixel_sha256:$psha,pixel_payload_bytes:$b,distinct_pixel_values:2,non_background_pixel_count:1,adapter_receipt:{schema_version:"taste-adapter-receipt/v1",adapter_id:"png-decoder",adapter_version:"fixture",command_sha256:$csha,input_sha256:[$isha],output_sha256:[$psha],exit_status:0,executed_at:$now}}'
EOF
chmod +x "$EVID/tools/decode-png"
DECODER_SHA=$(shasum -a 256 "$EVID/tools/decode-png" | awk '{print $1}')
# The browser adapter mixes CAND_TAG into decoded pixels so every candidate
# renders genuinely divergent bytes (identical tags => cross-candidate duplicate).
cat > "$EVID/adapter.sh" <<'EOF'
#!/usr/bin/env bash
set -eu
req="$POLYLANE_CAPTURE_REQUEST"; out="$POLYLANE_CAPTURE_OUTPUT"
route=$(jq -r .route "$req"); state=$(jq -r .state "$req")
w=$(jq -r .viewport_css_px.width "$req"); hh=$(jq -r .viewport_css_px.height "$req")
mkdir -p "$out"
case "$state" in default) c='0 0 255';; validation-error) c='255 0 0';; *) c='0 255 0';; esac
printf 'P3\n1 1\n255\n%s\n' "$c" > "$out/source.ppm"
sips -s format png -z "$hh" "$w" "$out/source.ppm" --out "$out/screenshot.png" >/dev/null
dd if=/dev/zero of="$out/pixels.rgba" bs=4 count=$((w * hh)) 2>/dev/null
printf '%s|%s' "${CAND_TAG:-x}" "$state" | dd of="$out/pixels.rgba" bs=1 conv=notrunc 2>/dev/null
printf '<main data-route="%s" data-state="%s"></main>\n' "$route" "$state" > "$out/dom.html"
printf '{"route":%s,"state":%s,"actions":["navigate","settle"]}\n' "$(printf '%s' "$route" | jq -R .)" "$(printf '%s' "$state" | jq -R .)" > "$out/action-trace.json"
jq -n --arg route "$route" --arg state "$state" --arg cap "${POLYLANE_CAPTURE_NOW}" --argjson w "$w" --argjson hh "$hh" \
  '{schema_version:"taste-browser-capture-result/v1",route:$route,state:$state,navigation_status:"ok",viewport_css_px:{width:$w,height:$hh},screenshot:"screenshot.png",decoded_pixels:"pixels.rgba",dom:"dom.html",action_trace:"action-trace.json",captured_at:$cap}'  > "$out/result.json"
EOF
chmod +x "$EVID/adapter.sh"

# build_candidate CID TAG PASS_GATE  -> evidence-<CID>/ + hard-<CID>.json
build_candidate() {
  local cid="$1" tag="$2" gate="$3" cj pj man mansha now
  cj="$EVID/cand-$cid.json"; pj="$EVID/plan-$cid.json"
  now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  jq -n --arg id "$cid" --arg rev "$REV" --arg now "2020-01-01T00:00:00Z" --arg b "$BRIEF" \
    '{schema_version:"taste-candidate/v1",candidate_id:$id,brief_sha256:$b,design_lock_sha256:$b,direction_id:"d1",source_revision:$rev,dependency_lock_sha256:$b,build_receipt_sha256:$b,created_at:$now}' > "$cj"
  jq -n --arg dsha "$DECODER_SHA" \
    '{schema_version:"taste-capture-plan/v1",run_id:"r",browser:{adapter_id:"browser-capture",adapter_version:"1.0.0",command:"fixture --capture",profile_sha256:"0000000000000000000000000000000000000000000000000000000000000000"},decoder:{adapter_id:"png-decoder",adapter_version:"fixture",command_path:"tools/decode-png",command_sha256:$dsha},environment:{locale:"en-US",timezone:"UTC",color_scheme:"light",device_scale_factor:1},routes:["/checkout"],states:[{id:"default"},{id:"validation-error"}]}' > "$pj"
  CAND_TAG="$tag" POLYLANE_CAPTURE_NOW="$now" "$CAPTURE" capture "$cj" "$pj" "$EVID/evidence-$cid" -- "$EVID/adapter.sh" >/dev/null
  man="$EVID/evidence-$cid/capture-manifest.json"; mansha=$(shasum -a 256 "$man" | awk '{print $1}')
  jq -n --arg id "cand-$cid" --arg man "$mansha" --arg st "$gate" '
    {schema_version:"taste-hard-gate/v1",candidate_id:$id,capture_manifest_sha256:$man,
     task_results:[{task_id:"t1",capture_id:"cap-001",status:"pass"}],
     accessibility:[{capture_id:"cap-001",ruleset:"WCAG-2.2",status:$st}],
     state_coverage:[{capture_id:"cap-001",status:"pass"}],
     product_specificity:{signature_test_sha256:"'"$BRIEF"'",status:"pass"},overall:(if $st=="pass" then "PASS" else "FAIL" end)}' > "$EVID/hard-$cid.json"
}

# --- ballot minting: real groups the frozen validator accepts -----------------
stimid() { printf 'stim-%s' "$(printf '%s' "$1" | shasum -a 256 | cut -c1-12)"; }

mint_pointwise() { # PWDIR ID JUDGE STIM SEALED -> writes file, echoes file sha
  local d="$1" id="$2" judge="$3" stim="$4" sealed="$5" f body rh
  f="$d/$id.json"
  jq -n --arg id "$id" --arg j "$judge" --arg s "$stim" --arg b "$BRIEF" --arg cap "$CAPMAN" --arg sealed "$sealed" --argjson crit "$CRIT" '
    {schema_version:"taste-pointwise/v1",ballot_id:$id,judge_id:$j,candidate_id:$s,brief_sha256:$b,capture_manifest_sha256:$cap,
     scores_1_to_7:{color:5,craftsmanship:5,hierarchy:5,originality:5,product_fit:5,spatial_rhythm:5,state_coherence:5,typography:5},
     observations:($crit|map({criterion:.,capture_id:"cap-001",region_or_state:"header",brief_clause:"task-1",reason:"observable brief-specific"})),
     identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,sealed_at:$sealed,record_sha256:""}' > "$f.t"
  body=$(jq -cS 'del(.record_sha256)' "$f.t"); rh=$(printf '%s' "$body" | shasum -a 256 | awk '{print $1}')
  jq --arg rh "$rh" '.record_sha256=$rh' "$f.t" > "$f"; rm -f "$f.t"
  shasum -a 256 "$f" | awk '{print $1}'
}

# mint_match MATCHDIR PAIR CAND_A CAND_B WINNER_CAND  (5 groups, 10 distinct judges)
mint_match() {
  local md="$1" pair="$2" ca="$3" cb="$4" winc="$5" stim_a stim_b esha winstim g j1 j2 pa pb gid
  mkdir -p "$md/pointwise"
  stim_a=$(stimid "$pair-a"); stim_b=$(stimid "$pair-b")
  jq -n --arg p "$pair" --arg sa "$stim_a" --arg ca "$ca" --arg sb "$stim_b" --arg cb "$cb" \
    '{schema_version:"taste-tournament-escrow/v1",pair:$p,reveal:{($sa):$ca,($sb):$cb}}' > "$md/escrow.json"
  esha=$(shasum -a 256 "$md/escrow.json" | awk '{print $1}')
  if [ "$winc" = "$ca" ]; then winstim="$stim_a"; else winstim="$stim_b"; fi
  : > "$md/judges.txt"
  for g in 1 2 3 4 5; do
    gid="$pair-g$g"; j1="judge-$pair-g${g}a"; j2="judge-$pair-g${g}b"
    printf '%s\n%s\n' "$j1" "$j2" >> "$md/judges.txt"
    pa=$(mint_pointwise "$md/pointwise" "pointwise-$gid-a" "$j1" "$stim_a" "2026-08-11T00:00:05Z")
    pb=$(mint_pointwise "$md/pointwise" "pointwise-$gid-b" "$j2" "$stim_b" "2026-08-11T00:00:05Z")
    jq -n --arg gid "mg-$gid" --arg b "$BRIEF" --arg sa "$stim_a" --arg sb "$stim_b" --arg esha "$esha" \
      --arg pa "pointwise-$gid-a" --arg pb "pointwise-$gid-b" --arg pasha "$pa" --arg pbsha "$pb" \
      --arg j1 "$j1" --arg j2 "$j2" --arg win "$winstim" --arg r "$BRIEF" '
      {schema_version:"taste-mirrored-group/v1",mirror_group_id:$gid,brief_sha256:$b,
       candidate_ids:[$sa,$sb],candidate_ids_escrow_sha256:$esha,
       pointwise_ballot_ids:[$pa,$pb],pointwise_sha256:{($pa):$pasha,($pb):$pbsha},
       exposures:[
         {schema_version:"taste-pairwise/v1",ballot_id:"pair-\($gid)-1",judge_id:$j1,display_order:"A/B",choice:"A",canonical_choice:$win,response_sha256:$r,sealed_at:"2026-08-11T00:00:09Z",identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,abstain_reason:null},
         {schema_version:"taste-pairwise/v1",ballot_id:"pair-\($gid)-2",judge_id:$j2,display_order:"B/A",choice:"A",canonical_choice:$win,response_sha256:$r,sealed_at:"2026-08-11T00:00:09Z",identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,abstain_reason:null}],
       outcome:"resolved-\($win)"}' > "$md/mg-$g.json"
  done
  jq -n --slurpfile j <(jq -R . "$md/judges.txt") '{schema_version:"taste-ballot-calibration/v1",judge_eligibility:($j|map({judge_id:.,eligible:true,abstention_policy:"pass",independent:true,no_candidate_identity:true,no_shared_ballot_channel:true}))}' > "$md/calibration.json"
}

# match_json PAIR -> a matches[] entry pointing at match-<PAIR>/
match_json() {
  local pair="$1"
  jq -nc --arg p "$pair" '{pair:$p,escrow:"match-\($p)/escrow.json",
    groups:[range(1;6)|{group:"match-\($p)/mg-\(.).json",pointwise_dir:"match-\($p)/pointwise",calibration:"match-\($p)/calibration.json"}]}'
}

# write a tournament JSON with three candidates and three declared matches.
write_tournament() { # FILE C1 C2 C3 [extra_jq]
  local f="$1" c1="$2" c2="$3" c4="$4"
  jq -n --arg b "$BRIEF" --arg rev "$REV" \
    --arg c1 "cand-$c1" --arg c2 "cand-$c2" --arg c3 "cand-$c4" \
    --argjson m12 "$(match_json 1-2)" --argjson m13 "$(match_json 1-3)" --argjson m23 "$(match_json 2-3)" '
    {schema_version:"taste-tournament/v1",run_id:"c39-visual-loop",base_revision:$rev,goal_sha256:$b,design_lock_sha256:$b,
     candidates:[{candidate_id:$c1,index:1,capture_root:".",capture_manifest:"evidence-\($c1|ltrimstr("cand-"))/capture-manifest.json",hard_gate:"hard-\($c1|ltrimstr("cand-")).json"},
                 {candidate_id:$c2,index:2,capture_root:".",capture_manifest:"evidence-\($c2|ltrimstr("cand-"))/capture-manifest.json",hard_gate:"hard-\($c2|ltrimstr("cand-")).json"},
                 {candidate_id:$c3,index:3,capture_root:".",capture_manifest:"evidence-\($c3|ltrimstr("cand-"))/capture-manifest.json",hard_gate:"hard-\($c3|ltrimstr("cand-")).json"}],
     matches:[$m12,$m13,$m23]}' > "$f"
}

# write a lock file + lock a fresh state dir. CIDS is a JSON array of candidate ids.
fresh_lock() { # DIR CIDS_JSON [design_lock_override]
  local dir="$1" cids="$2" dl="${3:-$BRIEF}"
  jq -n --arg rev "$REV" --arg b "$BRIEF" --arg dl "$dl" --argjson cids "$cids" \
    '{schema_version:"taste-tournament-lock/v1",run_id:"c39-visual-loop",scope_id:"scope-tournament",base_revision:$rev,goal_sha256:$b,brief_sha256:$b,reference_sha256:$b,direction_sha256:$b,design_lock_sha256:$dl,capture_plan_sha256:$b,candidate_ids:$cids,pairs:["1-2","1-3","2-3"],min_groups:5,repair_budget:2,locked_at:"2026-08-12T00:00:00Z"}' > "$dir.lock.json"
  "$TC" lock "$dir" "$dir.lock.json" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >/dev/null
}

# Build three genuinely divergent candidates and one duplicate of aaa.
build_candidate aaa TAG-AAA pass
build_candidate bbb TAG-BBB pass
build_candidate ccc TAG-CCC pass
build_candidate dup TAG-AAA pass    # identical rendered bytes to aaa

# Matches: aaa wins 1-2 and 1-3 (Condorcet winner); bbb wins 2-3.
mint_match "$EVID/match-1-2" 1-2 cand-aaa cand-bbb cand-aaa
mint_match "$EVID/match-1-3" 1-3 cand-aaa cand-ccc cand-aaa
mint_match "$EVID/match-2-3" 2-3 cand-bbb cand-ccc cand-bbb

# ============================ POSITIVE: zero-repair ==========================
write_tournament "$EVID/tournament.json" aaa bbb ccc
fresh_lock "$EVID/st-pos" '["cand-aaa","cand-bbb","cand-ccc"]'
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
POS_OUT=$("$TC" run "$EVID/st-pos" "$EVID/tournament.json" "$NOW" 2>&1) || true
assert_contains "visual-zero-repair-selects-condorcet-winner" "winner=cand-aaa" "$POS_OUT"
assert_contains "visual-zero-repair-label-not-certified" "SELECTED_NOT_CERTIFIED" "$POS_OUT"
assert_eq "visual-champion-generation-zero" "0" "$("$TC" champion "$EVID/st-pos" | jq -r .generation)"
assert_eq "visual-champion-is-winner" "cand-aaa" "$("$TC" champion "$EVID/st-pos" | jq -r .champion_candidate_id)"
assert_eq "visual-champion-label" "SELECTED_NOT_CERTIFIED" "$("$TC" champion "$EVID/st-pos" | jq -r .label)"
assert_ok "visual-event-log-intact" "$TC" verify-log "$EVID/st-pos"
assert_eq "visual-no-separate-certified-registry" "absent" "$([ -e "$EVID/st-pos/certified.json" ] && echo present || echo absent)"

# =================== NEGATIVE: caller cannot inject a winner =================
# An extra winner/pass/score key must be rejected outright (exact-key schema);
# there is no code path that reads a caller verdict.
jq '. + {winner:"cand-bbb"}' "$EVID/tournament.json" > "$EVID/t-winner.json"
fresh_lock "$EVID/st-win" '["cand-aaa","cand-bbb","cand-ccc"]'
assert_fail "visual-rejects-caller-supplied-winner" "$TC" run "$EVID/st-win" "$EVID/t-winner.json" "$NOW"
jq '. + {pass:true,verdict:"looks great"}' "$EVID/tournament.json" > "$EVID/t-prose.json"
fresh_lock "$EVID/st-prose" '["cand-aaa","cand-bbb","cand-ccc"]'
assert_fail "visual-rejects-caller-prose-pass" "$TC" run "$EVID/st-prose" "$EVID/t-prose.json" "$NOW"
jq '.candidates[0] += {score:9,loc:12}' "$EVID/tournament.json" > "$EVID/t-score.json"
fresh_lock "$EVID/st-score" '["cand-aaa","cand-bbb","cand-ccc"]'
assert_fail "visual-rejects-caller-score-loc-bypass" "$TC" run "$EVID/st-score" "$EVID/t-score.json" "$NOW"

# =================== NEGATIVE: candidate count must be three =================
jq '.candidates = .candidates[0:2] | .matches = [.matches[0]]' "$EVID/tournament.json" > "$EVID/t-two.json"
fresh_lock "$EVID/st-two" '["cand-aaa","cand-bbb","cand-ccc"]'
assert_fail "visual-rejects-two-candidates" "$TC" run "$EVID/st-two" "$EVID/t-two.json" "$NOW"
jq '.candidates += [{candidate_id:"cand-ddd",index:4,capture_root:".",capture_manifest:"evidence-ddd/capture-manifest.json",hard_gate:"hard-ddd.json"}]' "$EVID/tournament.json" > "$EVID/t-four.json"
fresh_lock "$EVID/st-four" '["cand-aaa","cand-bbb","cand-ccc"]'
assert_fail "visual-rejects-four-candidates" "$TC" run "$EVID/st-four" "$EVID/t-four.json" "$NOW"

# =================== NEGATIVE: cross-candidate identical pixels ==============
write_tournament "$EVID/t-dup.json" aaa dup ccc
fresh_lock "$EVID/st-dup" '["cand-aaa","cand-dup","cand-ccc"]'
DUP_OUT=$("$TC" run "$EVID/st-dup" "$EVID/t-dup.json" "$NOW" 2>&1) || true
assert_contains "visual-rejects-cross-candidate-identical-pixels" "cross-candidate-identical" "$DUP_OUT"

# =================== NEGATIVE: stale source revision ========================
FAKE=0000000000000000000000000000000000000009
jq --arg r "$FAKE" '.base_revision=$r' "$EVID/tournament.json" > "$EVID/t-stale.json"
fresh_lock "$EVID/st-stale" '["cand-aaa","cand-bbb","cand-ccc"]' "$BRIEF"
# lock must carry the same (fake) base so bind passes and the source check fires.
jq --arg r "$FAKE" '.base_revision=$r' "$EVID/st-stale.lock.json" > "$EVID/st-stale.lock.json.t" && mv "$EVID/st-stale.lock.json.t" "$EVID/st-stale.lock.json"
rm -rf "$EVID/st-stale"; "$TC" lock "$EVID/st-stale" "$EVID/st-stale.lock.json" "$NOW" >/dev/null
STALE_OUT=$("$TC" run "$EVID/st-stale" "$EVID/t-stale.json" "$NOW" 2>&1) || true
assert_contains "visual-rejects-stale-source" "source != frozen base" "$STALE_OUT"

# =================== NEGATIVE: design-lock mismatch =========================
OTHER=$(h64 other-lock)
jq --arg d "$OTHER" '.design_lock_sha256=$d' "$EVID/tournament.json" > "$EVID/t-lockmiss.json"
fresh_lock "$EVID/st-lockmiss" '["cand-aaa","cand-bbb","cand-ccc"]'   # lock keeps $BRIEF
LM_OUT=$("$TC" run "$EVID/st-lockmiss" "$EVID/t-lockmiss.json" "$NOW" 2>&1) || true
assert_contains "visual-rejects-design-lock-mismatch" "design-lock digest != frozen lock" "$LM_OUT"

# =================== NEGATIVE: missing match ================================
jq '.matches = [.matches[0], .matches[1]]' "$EVID/tournament.json" > "$EVID/t-missing.json"
fresh_lock "$EVID/st-missing" '["cand-aaa","cand-bbb","cand-ccc"]'
assert_fail "visual-rejects-missing-match" "$TC" run "$EVID/st-missing" "$EVID/t-missing.json" "$NOW"

# =================== NEGATIVE: 1-1-1 Condorcet cycle -> REPLAN ==============
mint_match "$EVID/cyc-1-2" 1-2 cand-aaa cand-bbb cand-aaa
mint_match "$EVID/cyc-1-3" 1-3 cand-aaa cand-ccc cand-ccc
mint_match "$EVID/cyc-2-3" 2-3 cand-bbb cand-ccc cand-bbb
jq -n --arg b "$BRIEF" --arg rev "$REV" \
  --argjson m12 "$(cd "$EVID" && jq -nc '{pair:"1-2",escrow:"cyc-1-2/escrow.json",groups:[range(1;6)|{group:"cyc-1-2/mg-\(.).json",pointwise_dir:"cyc-1-2/pointwise",calibration:"cyc-1-2/calibration.json"}]}')" \
  --argjson m13 "$(cd "$EVID" && jq -nc '{pair:"1-3",escrow:"cyc-1-3/escrow.json",groups:[range(1;6)|{group:"cyc-1-3/mg-\(.).json",pointwise_dir:"cyc-1-3/pointwise",calibration:"cyc-1-3/calibration.json"}]}')" \
  --argjson m23 "$(cd "$EVID" && jq -nc '{pair:"2-3",escrow:"cyc-2-3/escrow.json",groups:[range(1;6)|{group:"cyc-2-3/mg-\(.).json",pointwise_dir:"cyc-2-3/pointwise",calibration:"cyc-2-3/calibration.json"}]}')" '
  {schema_version:"taste-tournament/v1",run_id:"c39-visual-loop",base_revision:$rev,goal_sha256:$b,design_lock_sha256:$b,
   candidates:[{candidate_id:"cand-aaa",index:1,capture_root:".",capture_manifest:"evidence-aaa/capture-manifest.json",hard_gate:"hard-aaa.json"},
               {candidate_id:"cand-bbb",index:2,capture_root:".",capture_manifest:"evidence-bbb/capture-manifest.json",hard_gate:"hard-bbb.json"},
               {candidate_id:"cand-ccc",index:3,capture_root:".",capture_manifest:"evidence-ccc/capture-manifest.json",hard_gate:"hard-ccc.json"}],
   matches:[$m12,$m13,$m23]}' > "$EVID/t-cycle.json"
fresh_lock "$EVID/st-cycle" '["cand-aaa","cand-bbb","cand-ccc"]'
CYC_OUT=$("$TC" run "$EVID/st-cycle" "$EVID/t-cycle.json" "$NOW" 2>&1) || true
assert_contains "visual-cycle-yields-replan" "REPLAN" "$CYC_OUT"
assert_eq "visual-cycle-no-champion" "absent" "$([ -e "$EVID/st-cycle/champion.json" ] && echo present || echo absent)"

# =================== NEGATIVE: failed hard gate =============================
build_candidate bad TAG-BAD fail
write_tournament "$EVID/t-badgate.json" aaa bad ccc   # deterministic veto fires before any taste vote
fresh_lock "$EVID/st-badgate" '["cand-aaa","cand-bad","cand-ccc"]'
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')   # cand-bad was captured after the earlier NOW
BG_OUT=$("$TC" run "$EVID/st-badgate" "$EVID/t-badgate.json" "$NOW" 2>&1) || true
assert_contains "visual-rejects-failed-hard-gate" "hard-gate veto failed" "$BG_OUT"
assert_eq "visual-badgate-no-champion" "absent" "$([ -e "$EVID/st-badgate/champion.json" ] && echo present || echo absent)"

finish
