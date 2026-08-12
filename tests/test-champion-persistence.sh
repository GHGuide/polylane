#!/usr/bin/env bash
# test-champion-persistence.sh — durable event log, replay, bounded repair, CAS.
#
# The controller's authority is its append-only hash-chained event log and its
# compare-and-swap champion registry, NOT caller JSON. This exercises: real-PNG
# zero/first/second-repair promotion, previous-pointer chaining, repair-token
# reservation before work (restart cannot reset the budget), and every tamper:
# skipped event, chain mutation, interrupted projection, stale parent, attempt
# gap, third repair, unchanged repair, oscillation, concurrent/stale CAS, and
# losing-repair champion immutability.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
TC="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-visual-tournament.sh"
CAPTURE="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-visual-capture.sh"

command -v jq  >/dev/null 2>&1 || { pass "champion-skipped-no-jq"; finish; exit 0; }
command -v sips >/dev/null 2>&1 || { pass "champion-skipped-no-sips"; finish; exit 0; }
[ -x "$CAPTURE" ] || { pass "champion-skipped-no-capture-helper"; finish; exit 0; }
make_tmpdir
EVID="$TEST_TMPDIR/evid"; mkdir -p "$EVID/tools"
h64() { printf 'seed-%s' "$1" | shasum -a 256 | awk '{print $1}'; }
BRIEF=$(h64 brief); CAPMAN=$(h64 capman)
CRIT='["color","craftsmanship","hierarchy","originality","product_fit","spatial_rhythm","state_coherence","typography"]'

git -C "$EVID" init -q; git -C "$EVID" config user.email t@e.test; git -C "$EVID" config user.name t
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

build_candidate() { # CID TAG
  local cid="$1" tag="$2" cj pj man mansha
  cj="$EVID/cand-$cid.json"; pj="$EVID/plan-$cid.json"
  jq -n --arg id "$cid" --arg rev "$REV" --arg b "$BRIEF" '{schema_version:"taste-candidate/v1",candidate_id:$id,brief_sha256:$b,design_lock_sha256:$b,direction_id:"d1",source_revision:$rev,dependency_lock_sha256:$b,build_receipt_sha256:$b,created_at:"2020-01-01T00:00:00Z"}' > "$cj"
  jq -n --arg dsha "$DECODER_SHA" '{schema_version:"taste-capture-plan/v1",run_id:"r",browser:{adapter_id:"browser-capture",adapter_version:"1.0.0",command:"fixture --capture",profile_sha256:"0000000000000000000000000000000000000000000000000000000000000000"},decoder:{adapter_id:"png-decoder",adapter_version:"fixture",command_path:"tools/decode-png",command_sha256:$dsha},environment:{locale:"en-US",timezone:"UTC",color_scheme:"light",device_scale_factor:1},routes:["/checkout"],states:[{id:"default"}]}' > "$pj"
  CAND_TAG="$tag" POLYLANE_CAPTURE_NOW="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$CAPTURE" capture "$cj" "$pj" "$EVID/evidence-$cid" -- "$EVID/adapter.sh" >/dev/null
  man="$EVID/evidence-$cid/capture-manifest.json"; mansha=$(shasum -a 256 "$man" | awk '{print $1}')
  jq -n --arg id "cand-$cid" --arg man "$mansha" '{schema_version:"taste-hard-gate/v1",candidate_id:$id,capture_manifest_sha256:$man,task_results:[{task_id:"t1",capture_id:"cap-001",status:"pass"}],accessibility:[{capture_id:"cap-001",ruleset:"WCAG-2.2",status:"pass"}],state_coverage:[{capture_id:"cap-001",status:"pass"}],product_specificity:{signature_test_sha256:"'"$BRIEF"'",status:"pass"},overall:"PASS"}' > "$EVID/hard-$cid.json"
}
cand_entry() { jq -nc --arg id "cand-$1" --argjson i "$2" '{candidate_id:$id,index:$i,capture_root:".",capture_manifest:"evidence-\($id|ltrimstr("cand-"))/capture-manifest.json",hard_gate:"hard-\($id|ltrimstr("cand-")).json"}'; }
stimid() { printf 'stim-%s' "$(printf '%s' "$1" | shasum -a 256 | cut -c1-12)"; }
mint_pointwise() {
  local d="$1" id="$2" judge="$3" stim="$4" f body rh
  f="$d/$id.json"
  jq -n --arg id "$id" --arg j "$judge" --arg s "$stim" --arg b "$BRIEF" --arg cap "$CAPMAN" --argjson crit "$CRIT" '{schema_version:"taste-pointwise/v1",ballot_id:$id,judge_id:$j,candidate_id:$s,brief_sha256:$b,capture_manifest_sha256:$cap,scores_1_to_7:{color:5,craftsmanship:5,hierarchy:5,originality:5,product_fit:5,spatial_rhythm:5,state_coherence:5,typography:5},observations:($crit|map({criterion:.,capture_id:"cap-001",region_or_state:"header",brief_clause:"task-1",reason:"observable brief-specific"})),identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,sealed_at:"2026-08-11T00:00:05Z",record_sha256:""}' > "$f.t"
  body=$(jq -cS 'del(.record_sha256)' "$f.t"); rh=$(printf '%s' "$body" | shasum -a 256 | awk '{print $1}')
  jq --arg rh "$rh" '.record_sha256=$rh' "$f.t" > "$f"; rm -f "$f.t"
  shasum -a 256 "$f" | awk '{print $1}'
}
mint_match() { # MATCHDIR PAIR CAND_A CAND_B WINNER_CAND JUDGE_NS
  local md="$1" pair="$2" ca="$3" cb="$4" winc="$5" ns="$6" stim_a stim_b esha winstim g j1 j2 pa pb gid
  mkdir -p "$md/pointwise"; stim_a=$(stimid "$ns-a"); stim_b=$(stimid "$ns-b")
  jq -n --arg p "$pair" --arg sa "$stim_a" --arg ca "$ca" --arg sb "$stim_b" --arg cb "$cb" '{schema_version:"taste-tournament-escrow/v1",pair:$p,reveal:{($sa):$ca,($sb):$cb}}' > "$md/escrow.json"
  esha=$(shasum -a 256 "$md/escrow.json" | awk '{print $1}')
  if [ "$winc" = "$ca" ]; then winstim="$stim_a"; else winstim="$stim_b"; fi
  : > "$md/judges.txt"
  for g in 1 2 3 4 5; do
    gid="$ns-g$g"; j1="judge-$ns-g${g}a"; j2="judge-$ns-g${g}b"
    printf '%s\n%s\n' "$j1" "$j2" >> "$md/judges.txt"
    pa=$(mint_pointwise "$md/pointwise" "pointwise-$gid-a" "$j1" "$stim_a")
    pb=$(mint_pointwise "$md/pointwise" "pointwise-$gid-b" "$j2" "$stim_b")
    jq -n --arg gid "mg-$gid" --arg b "$BRIEF" --arg sa "$stim_a" --arg sb "$stim_b" --arg esha "$esha" --arg pa "pointwise-$gid-a" --arg pb "pointwise-$gid-b" --arg pasha "$pa" --arg pbsha "$pb" --arg j1 "$j1" --arg j2 "$j2" --arg win "$winstim" --arg r "$BRIEF" '{schema_version:"taste-mirrored-group/v1",mirror_group_id:$gid,brief_sha256:$b,candidate_ids:[$sa,$sb],candidate_ids_escrow_sha256:$esha,pointwise_ballot_ids:[$pa,$pb],pointwise_sha256:{($pa):$pasha,($pb):$pbsha},exposures:[{schema_version:"taste-pairwise/v1",ballot_id:"pair-\($gid)-1",judge_id:$j1,display_order:"A/B",choice:"A",canonical_choice:$win,response_sha256:$r,sealed_at:"2026-08-11T00:00:09Z",identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,abstain_reason:null},{schema_version:"taste-pairwise/v1",ballot_id:"pair-\($gid)-2",judge_id:$j2,display_order:"B/A",choice:"A",canonical_choice:$win,response_sha256:$r,sealed_at:"2026-08-11T00:00:09Z",identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,abstain_reason:null}],outcome:"resolved-\($win)"}' > "$md/mg-$g.json"
  done
  jq -n --slurpfile j <(jq -R . "$md/judges.txt") '{schema_version:"taste-ballot-calibration/v1",judge_eligibility:($j|map({judge_id:.,eligible:true,abstention_policy:"pass",independent:true,no_candidate_identity:true,no_shared_ballot_channel:true}))}' > "$md/calibration.json"
}
groups_json() { local d="$1"; jq -nc --arg d "$d" '{escrow:"\($d)/escrow.json",groups:[range(1;6)|{group:"\($d)/mg-\(.).json",pointwise_dir:"\($d)/pointwise",calibration:"\($d)/calibration.json"}]}'; }
write_initial() { # FILE MATCHNS12 MATCHNS13 MATCHNS23
  jq -n --arg b "$BRIEF" --arg rev "$REV" --argjson c1 "$(cand_entry aaa 1)" --argjson c2 "$(cand_entry bbb 2)" --argjson c3 "$(cand_entry ccc 3)" \
    --argjson m12 "$(groups_json "$2" | jq --arg p 1-2 '.pair=$p')" --argjson m13 "$(groups_json "$3" | jq --arg p 1-3 '.pair=$p')" --argjson m23 "$(groups_json "$4" | jq --arg p 2-3 '.pair=$p')" \
    '{schema_version:"taste-tournament/v1",run_id:"c39-visual-loop",base_revision:$rev,goal_sha256:$b,design_lock_sha256:$b,candidates:[$c1,$c2,$c3],matches:[$m12,$m13,$m23]}' > "$1"
}
write_repair() { # FILE INC CHAL MATCHNS
  jq -n --arg b "$BRIEF" --arg rev "$REV" --argjson c1 "$(cand_entry "$2" 1)" --argjson c2 "$(cand_entry "$3" 2)" --argjson m "$(groups_json "$4" | jq --arg p 1-2 '.pair=$p')" \
    '{schema_version:"taste-tournament/v1",run_id:"c39-visual-loop",base_revision:$rev,goal_sha256:$b,design_lock_sha256:$b,candidates:[$c1,$c2],matches:[$m]}' > "$1"
}
lockfile() { # DIR CIDS_JSON
  jq -n --arg rev "$REV" --arg b "$BRIEF" --argjson cids "$2" '{schema_version:"taste-tournament-lock/v1",run_id:"c39-visual-loop",scope_id:"scope-tournament",base_revision:$rev,goal_sha256:$b,brief_sha256:$b,reference_sha256:$b,direction_sha256:$b,design_lock_sha256:$b,capture_plan_sha256:$b,candidate_ids:$cids,pairs:["1-2","1-3","2-3"],min_groups:5,repair_budget:2,locked_at:"2026-08-12T00:00:00Z"}' > "$1"
}
reservefile() { # FILE ATTEMPT INCUMBENT
  jq -n --argjson a "$2" --arg i "$3" --arg b "$BRIEF" '{attempt:$a,incumbent_candidate_id:$i,design_lock_sha256:$b,failed_states:["validation-error"],started_before_work:true}' > "$1"
}

build_candidate aaa TAG-AAA
build_candidate bbb TAG-BBB
build_candidate ccc TAG-CCC
build_candidate rep1 TAG-REP1
build_candidate rep2 TAG-REP2
build_candidate unch TAG-AAA   # identical render to aaa
# initial-run matches (aaa Condorcet winner)
mint_match "$EVID/i12" 1-2 cand-aaa cand-bbb cand-aaa i12
mint_match "$EVID/i13" 1-3 cand-aaa cand-ccc cand-aaa i13
mint_match "$EVID/i23" 2-3 cand-bbb cand-ccc cand-bbb i23
write_initial "$EVID/init.json" i12 i13 i23
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# The initial 3-way run is the expensive step; do it once and clone the durable
# gen0 state for every scenario that needs a standing champion.
T0="$TEST_TMPDIR/T0"
lockfile "$EVID/t0.lock" '["cand-aaa","cand-bbb","cand-ccc"]'
"$TC" lock "$T0" "$EVID/t0.lock" "$NOW" >/dev/null
"$TC" run "$T0" "$EVID/init.json" "$NOW" >/dev/null 2>&1
new_run() { rm -rf "$1"; cp -r "$T0" "$1"; }

# ============ Scenario A: real-PNG zero/first/second-repair promotion ========
A="$TEST_TMPDIR/A"; new_run "$A"
assert_eq "champ-gen0-initial" "0" "$("$TC" champion "$A" | jq -r .generation)"
assert_eq "champ-gen0-winner" "cand-aaa" "$("$TC" champion "$A" | jq -r .champion_candidate_id)"
assert_eq "champ-gen0-prev-pointer-zero" "$(printf '%064d' 0)" "$("$TC" champion "$A" | jq -r .previous_generation_sha256)"
GEN0_SHA=$(shasum -a 256 "$A/champion.json" | awk '{print $1}')
reservefile "$EVID/r1.json" 1 cand-aaa; "$TC" reserve "$A" "$EVID/r1.json" "$NOW" >/dev/null
mint_match "$EVID/rep1m" 1-2 cand-aaa cand-rep1 cand-rep1 rep1m
write_repair "$EVID/rep1.json" aaa rep1 rep1m
"$TC" repair "$A" "$EVID/rep1.json" "$NOW" >/dev/null 2>&1
assert_eq "champ-first-repair-gen1" "1" "$("$TC" champion "$A" | jq -r .generation)"
assert_eq "champ-first-repair-winner" "cand-rep1" "$("$TC" champion "$A" | jq -r .champion_candidate_id)"
assert_eq "champ-first-repair-prev-points-at-gen0" "$GEN0_SHA" "$("$TC" champion "$A" | jq -r .previous_generation_sha256)"
reservefile "$EVID/r2.json" 2 cand-rep1; "$TC" reserve "$A" "$EVID/r2.json" "$NOW" >/dev/null
mint_match "$EVID/rep2m" 1-2 cand-rep1 cand-rep2 cand-rep2 rep2m
write_repair "$EVID/rep2.json" rep1 rep2 rep2m
"$TC" repair "$A" "$EVID/rep2.json" "$NOW" >/dev/null 2>&1
assert_eq "champ-second-repair-gen2" "2" "$("$TC" champion "$A" | jq -r .generation)"
assert_eq "champ-second-repair-winner" "cand-rep2" "$("$TC" champion "$A" | jq -r .champion_candidate_id)"
assert_ok "champ-log-intact-after-two-repairs" "$TC" verify-log "$A"
# Third repair is refused: the durable budget cannot be reset.
reservefile "$EVID/r3.json" 3 cand-rep2
R3=$("$TC" reserve "$A" "$EVID/r3.json" "$NOW" 2>&1) || true
assert_contains "champ-third-repair-refused" "budget exhausted" "$R3"

# ============ Scenario: reservation before work cannot reset the budget ======
RB="$TEST_TMPDIR/RB"; new_run "$RB"
reservefile "$EVID/rb1.json" 1 cand-aaa; "$TC" reserve "$RB" "$EVID/rb1.json" "$NOW" >/dev/null
assert_eq "champ-reservation-is-durable" "1" "$("$TC" state "$RB" | jq -r .repairs_reserved)"
# Re-reserving with a token already pending is refused; the durable budget cannot
# be reset by replaying the reservation.
assert_fail "champ-cannot-re-reserve-with-pending-token" "$TC" reserve "$RB" "$EVID/rb1.json" "$NOW"
assert_eq "champ-budget-not-reset-by-re-reserve" "1" "$("$TC" state "$RB" | jq -r .repairs_reserved)"

# ============ Scenario: stale repair parent =================================
SP="$TEST_TMPDIR/SP"; new_run "$SP"
reservefile "$EVID/sp.json" 1 cand-bbb   # not the champion
SPOUT=$("$TC" reserve "$SP" "$EVID/sp.json" "$NOW" 2>&1) || true
assert_contains "champ-rejects-stale-parent" "stale repair parent" "$SPOUT"

# ============ Scenario: attempt gap ========================================
AG="$TEST_TMPDIR/AG"; new_run "$AG"
reservefile "$EVID/ag.json" 2 cand-aaa   # attempt 2 before attempt 1
AGOUT=$("$TC" reserve "$AG" "$EVID/ag.json" "$NOW" 2>&1) || true
assert_contains "champ-rejects-attempt-gap" "attempt gap" "$AGOUT"

# ============ Scenario: losing repair — champion immutable ==================
LR="$TEST_TMPDIR/LR"; new_run "$LR"
LR_SHA=$(shasum -a 256 "$LR/champion.json" | awk '{print $1}')
reservefile "$EVID/lr.json" 1 cand-aaa; "$TC" reserve "$LR" "$EVID/lr.json" "$NOW" >/dev/null
mint_match "$EVID/lrm" 1-2 cand-aaa cand-rep1 cand-aaa lrm   # incumbent wins
write_repair "$EVID/lrrep.json" aaa rep1 lrm
"$TC" repair "$LR" "$EVID/lrrep.json" "$NOW" >/dev/null 2>&1 || true
assert_eq "champ-losing-repair-generation-unchanged" "0" "$("$TC" champion "$LR" | jq -r .generation)"
assert_eq "champ-losing-repair-registry-byte-identical" "$LR_SHA" "$(shasum -a 256 "$LR/champion.json" | awk '{print $1}')"
assert_eq "champ-losing-repair-no-certified-registry" "absent" "$([ -e "$LR/certified.json" ] && echo present || echo absent)"
# A material loss is RETAINED, so a second attempt is still allowed.
assert_eq "champ-losing-repair-retains-not-terminal" "SELECTED" "$("$TC" state "$LR" | jq -r .phase)"

# ============ Scenario: unchanged repair -> REPLAN =========================
UR="$TEST_TMPDIR/UR"; new_run "$UR"
reservefile "$EVID/ur.json" 1 cand-aaa; "$TC" reserve "$UR" "$EVID/ur.json" "$NOW" >/dev/null
mint_match "$EVID/urm" 1-2 cand-aaa cand-unch cand-unch urm
write_repair "$EVID/urrep.json" aaa unch urm
UROUT=$("$TC" repair "$UR" "$EVID/urrep.json" "$NOW" 2>&1) || true
assert_contains "champ-unchanged-repair-replan" "unchanged repair evidence" "$UROUT"
assert_eq "champ-unchanged-repair-generation-unchanged" "0" "$("$TC" champion "$UR" | jq -r .generation)"

# ============ Scenario: oscillation -> REPLAN ==============================
OS="$TEST_TMPDIR/OS"; new_run "$OS"
reservefile "$EVID/os1.json" 1 cand-aaa; "$TC" reserve "$OS" "$EVID/os1.json" "$NOW" >/dev/null
mint_match "$EVID/osm1" 1-2 cand-aaa cand-rep1 cand-rep1 osm1
write_repair "$EVID/osr1.json" aaa rep1 osm1
"$TC" repair "$OS" "$EVID/osr1.json" "$NOW" >/dev/null 2>&1   # gen1 = rep1
reservefile "$EVID/os2.json" 2 cand-rep1; "$TC" reserve "$OS" "$EVID/os2.json" "$NOW" >/dev/null
mint_match "$EVID/osm2" 1-2 cand-rep1 cand-aaa cand-aaa osm2   # challenger = prior champion aaa
write_repair "$EVID/osr2.json" rep1 aaa osm2
OSOUT=$("$TC" repair "$OS" "$EVID/osr2.json" "$NOW" 2>&1) || true
assert_contains "champ-oscillation-replan" "oscillation" "$OSOUT"
assert_eq "champ-oscillation-generation-unchanged" "1" "$("$TC" champion "$OS" | jq -r .generation)"

# ============ Scenario: concurrent / stale CAS =============================
CC="$TEST_TMPDIR/CC"; new_run "$CC"
reservefile "$EVID/cc.json" 1 cand-aaa; "$TC" reserve "$CC" "$EVID/cc.json" "$NOW" >/dev/null
jq '.generation=9' "$CC/champion.json" > "$CC/champion.json.t" && mv "$CC/champion.json.t" "$CC/champion.json"  # concurrent advance
mint_match "$EVID/ccm" 1-2 cand-aaa cand-rep1 cand-rep1 ccm
write_repair "$EVID/ccrep.json" aaa rep1 ccm
CCOUT=$("$TC" repair "$CC" "$EVID/ccrep.json" "$NOW" 2>&1) || true
assert_contains "champ-concurrent-cas-fails" "CAS stale" "$CCOUT"

# ============ Scenario: log tamper — skip / mutate / interrupt =============
TM="$TEST_TMPDIR/TM"; new_run "$TM"
assert_ok "champ-clean-log-verifies" "$TC" verify-log "$TM"
cp "$TM/events.log" "$EVID/skip.log"; sed '3d' "$EVID/skip.log" > "$EVID/skip2.log"; cp "$EVID/skip2.log" "$TM/events.log"
assert_fail "champ-detects-skipped-event" "$TC" verify-log "$TM"
cp "$EVID/skip.log" "$TM/events.log"   # restore full
python3 - "$TM/events.log" <<'PY'
import json,sys
p=sys.argv[1]; L=open(p).read().splitlines()
o=json.loads(L[2]); o["payload"]["winner_candidate_id"]="cand-zzz"; L[2]=json.dumps(o)
open(p,"w").write("\n".join(L)+"\n")
PY
assert_fail "champ-detects-chain-mutation" "$TC" verify-log "$TM"
cp "$EVID/skip.log" "$TM/events.log"   # restore
# interrupted write: a truncated final line (partial JSON)
head -c $(( $(wc -c < "$TM/events.log") - 20 )) "$TM/events.log" > "$TM/events.log.t" && mv "$TM/events.log.t" "$TM/events.log"
assert_fail "champ-detects-interrupted-projection-verify" "$TC" verify-log "$TM"
assert_fail "champ-detects-interrupted-projection-state" "$TC" state "$TM"

finish
