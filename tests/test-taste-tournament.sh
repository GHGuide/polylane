#!/usr/bin/env bash
# test-taste-tournament.sh — blind, escrow-bound match aggregation.
#
# Deterministic vetoes precede taste and taste is decided only by eligible,
# independent, human-calibrated, isolated, mirrored ballots. The controller
# COMPOSES polylane-taste-ballot.sh per group and adds escrow binding, judge
# independence across the match, quorum, and strict-majority resolution. Attacks:
# weak/ineligible judge, aliased/reused judge, reused ballot, A/B order flip,
# identity leakage, prompt injection, shared-channel discussion, escrow mismatch,
# quorum gap, and a tie (no strict majority).
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
TC="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-visual-tournament.sh"

command -v jq >/dev/null 2>&1 || { pass "taste-tournament-skipped-no-jq"; finish; exit 0; }
make_tmpdir
W="$TEST_TMPDIR"
BRIEF=$(printf 'brief' | shasum -a 256 | awk '{print $1}')
CAPMAN=$(printf 'capman' | shasum -a 256 | awk '{print $1}')
CRIT='["color","craftsmanship","hierarchy","originality","product_fit","spatial_rhythm","state_coherence","typography"]'
stimid() { printf 'stim-%s' "$(printf '%s' "$1" | shasum -a 256 | cut -c1-12)"; }
STIM_A=$(stimid A); STIM_B=$(stimid B)

mint_pointwise() { # PWDIR ID JUDGE STIM -> file sha
  local d="$1" id="$2" j="$3" s="$4" f body rh
  f="$d/$id.json"
  jq -n --arg id "$id" --arg j "$j" --arg s "$s" --arg b "$BRIEF" --arg cap "$CAPMAN" --argjson crit "$CRIT" '{schema_version:"taste-pointwise/v1",ballot_id:$id,judge_id:$j,candidate_id:$s,brief_sha256:$b,capture_manifest_sha256:$cap,scores_1_to_7:{color:5,craftsmanship:5,hierarchy:5,originality:5,product_fit:5,spatial_rhythm:5,state_coherence:5,typography:5},observations:($crit|map({criterion:.,capture_id:"cap-001",region_or_state:"header",brief_clause:"task-1",reason:"observable brief-specific"})),identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,sealed_at:"2026-08-11T00:00:05Z",record_sha256:""}' > "$f.t"
  body=$(jq -cS 'del(.record_sha256)' "$f.t"); rh=$(printf '%s' "$body" | shasum -a 256 | awk '{print $1}')
  jq --arg rh "$rh" '.record_sha256=$rh' "$f.t" > "$f"; rm -f "$f.t"
  shasum -a 256 "$f" | awk '{print $1}'
}
# mint a full valid match dir. WINSTIM chooses the group winner; NG groups.
mint_match() { # DIR WINSTIM NG
  local md="$1" winstim="$2" ng="$3" esha g j1 j2 pa pb gid
  rm -rf "$md"; mkdir -p "$md/pointwise"
  jq -n --arg p "1-2" --arg sa "$STIM_A" --arg sb "$STIM_B" '{schema_version:"taste-tournament-escrow/v1",pair:$p,reveal:{($sa):"cand-a",($sb):"cand-b"}}' > "$md/escrow.json"
  esha=$(shasum -a 256 "$md/escrow.json" | awk '{print $1}')
  : > "$md/judges.txt"
  g=1
  while [ "$g" -le "$ng" ]; do
    gid="grp$g"; j1="judge-grp${g}a"; j2="judge-grp${g}b"
    printf '%s\n%s\n' "$j1" "$j2" >> "$md/judges.txt"
    pa=$(mint_pointwise "$md/pointwise" "pointwise-$gid-a" "$j1" "$STIM_A")
    pb=$(mint_pointwise "$md/pointwise" "pointwise-$gid-b" "$j2" "$STIM_B")
    jq -n --arg gid "mg-$gid" --arg b "$BRIEF" --arg sa "$STIM_A" --arg sb "$STIM_B" --arg esha "$esha" --arg pa "pointwise-$gid-a" --arg pb "pointwise-$gid-b" --arg pasha "$pa" --arg pbsha "$pb" --arg j1 "$j1" --arg j2 "$j2" --arg win "$winstim" --arg r "$BRIEF" '{schema_version:"taste-mirrored-group/v1",mirror_group_id:$gid,brief_sha256:$b,candidate_ids:[$sa,$sb],candidate_ids_escrow_sha256:$esha,pointwise_ballot_ids:[$pa,$pb],pointwise_sha256:{($pa):$pasha,($pb):$pbsha},exposures:[{schema_version:"taste-pairwise/v1",ballot_id:"pair-\($gid)-1",judge_id:$j1,display_order:"A/B",choice:"A",canonical_choice:$win,response_sha256:$r,sealed_at:"2026-08-11T00:00:09Z",identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,abstain_reason:null},{schema_version:"taste-pairwise/v1",ballot_id:"pair-\($gid)-2",judge_id:$j2,display_order:"B/A",choice:"A",canonical_choice:$win,response_sha256:$r,sealed_at:"2026-08-11T00:00:09Z",identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,abstain_reason:null}],outcome:"resolved-\($win)"}' > "$md/mg-$g.json"
    g=$((g + 1))
  done
  jq -n --slurpfile j <(jq -R . "$md/judges.txt") '{schema_version:"taste-ballot-calibration/v1",judge_eligibility:($j|map({judge_id:.,eligible:true,abstention_policy:"pass",independent:true,no_candidate_identity:true,no_shared_ballot_channel:true}))}' > "$md/calibration.json"
}
# build the aggregate-match arg list (group pointwise_dir calibration) for a dir.
agg() { # DIR NG CAND_A CAND_B -- runs aggregate-match, echoes result, sets AGG_RC
  local md="$1" ng="$2" min="$3"; local -a a=(); local g=1
  while [ "$g" -le "$ng" ]; do a+=("$md/mg-$g.json" "$md/pointwise" "$md/calibration.json"); g=$((g + 1)); done
  AGG_OUT=$("$TC" aggregate-match "$md/escrow.json" "$min" "1-2" cand-a cand-b -- "${a[@]}" 2>&1); AGG_RC=$?
}

# -------------------- POSITIVE: five eligible groups, cand-a wins -----------
mint_match "$W/ok" "$STIM_A" 5
agg "$W/ok" 5 5
assert_eq "taste-positive-selects-majority-candidate" "cand-a" "$AGG_OUT"
assert_eq "taste-positive-rc-zero" "0" "$AGG_RC"

# -------------------- quorum gap: only four groups -------------------------
mint_match "$W/quorum" "$STIM_A" 4
agg "$W/quorum" 4 5
assert_contains "taste-rejects-quorum-gap" "quorum failure" "$AGG_OUT"

# -------------------- tie: no strict majority ------------------------------
mint_match "$W/tie" "$STIM_A" 4
# flip two groups to cand-b (2-2 split) with min 4
jq --arg w "$STIM_B" '.exposures[].canonical_choice=$w | .outcome="resolved-\($w)"' "$W/tie/mg-3.json" > "$W/tie/mg-3.json.t" && mv "$W/tie/mg-3.json.t" "$W/tie/mg-3.json"
jq --arg w "$STIM_B" '.exposures[].canonical_choice=$w | .outcome="resolved-\($w)"' "$W/tie/mg-4.json" > "$W/tie/mg-4.json.t" && mv "$W/tie/mg-4.json.t" "$W/tie/mg-4.json"
agg "$W/tie" 4 4
assert_contains "taste-rejects-tie-no-strict-majority" "no strict majority" "$AGG_OUT"

# -------------------- weak / ineligible judge ------------------------------
mint_match "$W/weak" "$STIM_A" 5
jq '(.judge_eligibility[0].eligible)=false' "$W/weak/calibration.json" > "$W/weak/calibration.json.t" && mv "$W/weak/calibration.json.t" "$W/weak/calibration.json"
agg "$W/weak" 5 5
assert_contains "taste-rejects-ineligible-judge" "ballot group invalid" "$AGG_OUT"

# -------------------- A/B order flip (mirror contradiction) ----------------
mint_match "$W/flip" "$STIM_A" 5
jq --arg w "$STIM_B" '.exposures[1].canonical_choice=$w' "$W/flip/mg-1.json" > "$W/flip/mg-1.json.t" && mv "$W/flip/mg-1.json.t" "$W/flip/mg-1.json"
agg "$W/flip" 5 5
assert_contains "taste-rejects-ab-order-flip" "ballot group invalid" "$AGG_OUT"

# -------------------- candidate identity leakage ---------------------------
mint_match "$W/leak" "$STIM_A" 5
jq '(.exposures[0].identity_visible)=true' "$W/leak/mg-2.json" > "$W/leak/mg-2.json.t" && mv "$W/leak/mg-2.json.t" "$W/leak/mg-2.json"
agg "$W/leak" 5 5
assert_contains "taste-rejects-identity-leakage" "ballot group invalid" "$AGG_OUT"

# -------------------- visual prompt injection ------------------------------
mint_match "$W/inject" "$STIM_A" 5
jq '(.exposures[0].injection_detected)=true' "$W/inject/mg-3.json" > "$W/inject/mg-3.json.t" && mv "$W/inject/mg-3.json.t" "$W/inject/mg-3.json"
agg "$W/inject" 5 5
assert_contains "taste-rejects-prompt-injection" "ballot group invalid" "$AGG_OUT"

# -------------------- shared-channel discussion ----------------------------
mint_match "$W/disc" "$STIM_A" 5
jq '(.exposures[1].judge_discussion)=true' "$W/disc/mg-4.json" > "$W/disc/mg-4.json.t" && mv "$W/disc/mg-4.json.t" "$W/disc/mg-4.json"
agg "$W/disc" 5 5
assert_contains "taste-rejects-shared-channel-discussion" "ballot group invalid" "$AGG_OUT"

# -------------------- aliased / reused judge across groups -----------------
mint_match "$W/alias" "$STIM_A" 5
# make group 2's judges identical to group 1's -> not ten isolated exposures.
jq '.exposures[0].judge_id="judge-grp1a" | .exposures[1].judge_id="judge-grp1b"' "$W/alias/mg-2.json" > "$W/alias/mg-2.json.t" && mv "$W/alias/mg-2.json.t" "$W/alias/mg-2.json"
agg "$W/alias" 5 5
assert_contains "taste-rejects-aliased-judge-across-match" "reused/aliased judge" "$AGG_OUT"

# -------------------- reused ballot group (same group twice) ---------------
mint_match "$W/reuse" "$STIM_A" 5
# Pass mg-1 twice instead of mg-5: a reused ballot inflates quorum illegitimately.
REUSE_ARGS=("$W/reuse/mg-1.json" "$W/reuse/pointwise" "$W/reuse/calibration.json"
            "$W/reuse/mg-2.json" "$W/reuse/pointwise" "$W/reuse/calibration.json"
            "$W/reuse/mg-3.json" "$W/reuse/pointwise" "$W/reuse/calibration.json"
            "$W/reuse/mg-4.json" "$W/reuse/pointwise" "$W/reuse/calibration.json"
            "$W/reuse/mg-1.json" "$W/reuse/pointwise" "$W/reuse/calibration.json")
REUSE_OUT=$("$TC" aggregate-match "$W/reuse/escrow.json" 5 1-2 cand-a cand-b -- "${REUSE_ARGS[@]}" 2>&1) || true
assert_contains "taste-rejects-reused-ballot-group" "reused/aliased judge" "$REUSE_OUT"

# -------------------- escrow binding mismatch ------------------------------
mint_match "$W/escrow" "$STIM_A" 5
BAD=$(printf 'wrong' | shasum -a 256 | awk '{print $1}')
jq --arg s "$BAD" '.candidate_ids_escrow_sha256=$s' "$W/escrow/mg-1.json" > "$W/escrow/mg-1.json.t" && mv "$W/escrow/mg-1.json.t" "$W/escrow/mg-1.json"
agg "$W/escrow" 5 5
assert_contains "taste-rejects-escrow-mismatch" "group escrow mismatch" "$AGG_OUT"

# -------------------- escrow must reveal exactly the pair -------------------
mint_match "$W/wrongpair" "$STIM_A" 5
jq '.reveal |= (to_entries | .[0].value="cand-z" | from_entries)' "$W/wrongpair/escrow.json" > "$W/wrongpair/escrow.json.t" && mv "$W/wrongpair/escrow.json.t" "$W/wrongpair/escrow.json"
# recompute escrow sha into the groups so binding passes but reveal is wrong.
NEW_ESHA=$(shasum -a 256 "$W/wrongpair/escrow.json" | awk '{print $1}')
for g in 1 2 3 4 5; do jq --arg s "$NEW_ESHA" '.candidate_ids_escrow_sha256=$s' "$W/wrongpair/mg-$g.json" > "$W/wrongpair/mg-$g.json.t" && mv "$W/wrongpair/mg-$g.json.t" "$W/wrongpair/mg-$g.json"; done
agg "$W/wrongpair" 5 5
assert_contains "taste-rejects-escrow-not-revealing-pair" "escrow does not reveal exactly the pair" "$AGG_OUT"

finish
