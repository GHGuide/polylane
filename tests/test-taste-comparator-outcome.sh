#!/usr/bin/env bash
# Comparator outcome control — defect c42b-comparator-pseudo-win.
# Required v3 control: "Only a validated outcome equal to win increments wins;
# ties, abstentions, missing evidence, and invalid evidence remain non-wins in
# the fixed denominator."  The fixed denominator and the repeated-measure unit
# ("brief") are frozen by CONTRACT-LOCK.v3.json statistics.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

BALLOT="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-taste-ballot.sh"
make_tmpdir
WORK="$TEST_TMPDIR"
CALIBRATION="$WORK/calibration.json"
RCPT="$WORK/receipts"; mkdir -p "$RCPT"
TALLY="$WORK/tally.json"
STIM_A="stim-a1b2c3d4e5f6"
STIM_B="stim-0f1e2d3c4b5a"

sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
rep64() { local c="$1" s=""; while [ ${#s} -lt 64 ]; do s="$s$c"; done; printf '%s' "$s"; }

BRIEF1=$(rep64 1); BRIEF2=$(rep64 2); BRIEF3=$(rep64 3); BRIEF4=$(rep64 4)

cat > "$CALIBRATION" <<'JSON'
{"schema_version":"taste-ballot-calibration/v1","judge_eligibility":[
 {"judge_id":"judge-001","eligible":true,"abstention_policy":"pass","independent":true,"no_candidate_identity":true,"no_shared_ballot_channel":true},
 {"judge_id":"judge-002","eligible":true,"abstention_policy":"pass","independent":true,"no_candidate_identity":true,"no_shared_ballot_channel":true}]}
JSON

write_pointwise() { # ballot-id judge-id stimulus-id brief path
  local ballot_id="$1" judge_id="$2" stimulus_id="$3" brief="$4" path="$5" body digest
  jq -n --arg ballot_id "$ballot_id" --arg judge_id "$judge_id" --arg stimulus_id "$stimulus_id" --arg brief "$brief" '
    {schema_version:"taste-pointwise/v1",ballot_id:$ballot_id,judge_id:$judge_id,
     candidate_id:$stimulus_id,brief_sha256:$brief,capture_manifest_sha256:("b" * 64),
     scores_1_to_7:{product_fit:5,hierarchy:5,typography:5,color:5,spatial_rhythm:5,craftsmanship:5,originality:5,state_coherence:5},
     observations:(["product_fit","hierarchy","typography","color","spatial_rhythm","craftsmanship","originality","state_coherence"] | map({criterion:.,capture_id:"cap-001",region_or_state:"header",brief_clause:"task-1",reason:"observable brief-specific evidence"})),
     identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,
     sealed_at:"2026-08-11T00:00:00Z"}' > "$path"
  body=$(jq -cS . "$path")
  digest=$(printf '%s' "$body" | shasum -a 256 | awk '{print $1}')
  jq --arg digest "$digest" '. + {record_sha256:$digest}' "$path" > "$path.tmp" && mv "$path.tmp" "$path"
}

# build_group SLUG BRIEF KIND — writes $WORK/$SLUG/{group.json,pointwise/}
# KIND: win | tie | abstention | win-b (win resolved to the other candidate)
build_group() {
  local slug="$1" brief="$2" kind="$3"
  local dir pw hash_a hash_b outcome c1 c2 ch1 ch2
  dir="$WORK/$slug"
  rm -rf "$dir"; pw="$dir/pointwise"; mkdir -p "$pw"
  write_pointwise "pointwise-$slug-a" judge-001 "$STIM_A" "$brief" "$pw/pointwise-$slug-a.json"
  write_pointwise "pointwise-$slug-b" judge-002 "$STIM_B" "$brief" "$pw/pointwise-$slug-b.json"
  hash_a=$(sha256 "$pw/pointwise-$slug-a.json"); hash_b=$(sha256 "$pw/pointwise-$slug-b.json")
  case "$kind" in
    win)        outcome="resolved-$STIM_A"; c1="$STIM_A"; c2="$STIM_A"; ch1=A; ch2=B ;;
    win-b)      outcome="resolved-$STIM_B"; c1="$STIM_B"; c2="$STIM_B"; ch1=B; ch2=A ;;
    tie)        outcome="tie";              c1="$STIM_A"; c2="$STIM_B"; ch1=A; ch2=A ;;
    abstention) outcome="abstention";       c1="$STIM_A"; c2="$STIM_A"; ch1=A; ch2=abstain ;;
    *) return 1 ;;
  esac
  jq -n --arg gid "mg-$slug" --arg brief "$brief" --arg sa "$STIM_A" --arg sb "$STIM_B" \
        --arg pa "pointwise-$slug-a" --arg pb "pointwise-$slug-b" --arg ha "$hash_a" --arg hb "$hash_b" \
        --arg outcome "$outcome" --arg c1 "$c1" --arg c2 "$c2" --arg ch1 "$ch1" --arg ch2 "$ch2" --arg slug "$slug" '
    {schema_version:"taste-mirrored-group/v1",mirror_group_id:$gid,brief_sha256:$brief,
     candidate_ids:[$sa,$sb],candidate_ids_escrow_sha256:("c" * 64),
     pointwise_ballot_ids:[$pa,$pb],pointwise_sha256:{($pa):$ha,($pb):$hb},
     exposures:[
      {schema_version:"taste-pairwise/v1",ballot_id:("pair-" + $slug + "-1"),judge_id:"judge-001",display_order:"A/B",
       choice:$ch1,canonical_choice:$c1,sealed_at:"2026-08-11T00:01:00Z",response_sha256:("d" * 64),
       identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,
       abstain_reason:(if $ch1 == "abstain" then "no legible difference" else null end)},
      {schema_version:"taste-pairwise/v1",ballot_id:("pair-" + $slug + "-2"),judge_id:"judge-002",display_order:"B/A",
       choice:$ch2,canonical_choice:$c2,sealed_at:"2026-08-11T00:01:01Z",response_sha256:("e" * 64),
       identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,
       abstain_reason:(if $ch2 == "abstain" then "no legible difference" else null end)}],
     outcome:$outcome}' > "$dir/group.json"
}

validate_group() { # slug out
  local slug="$1" out="$2"
  "$BALLOT" validate "$WORK/$slug/group.json" "$WORK/$slug/pointwise" "$CALIBRATION" "$out"
}

# --- 1. every validated group carries a typed comparator outcome ------------
build_group win1 "$BRIEF1" win
rc=0; out=$(validate_group win1 "$RCPT/win1.json" 2>&1) || rc=$?
[ "$rc" = 0 ] || printf '%s\n' "$out" >&2
assert_eq "comparator-accepts-win-group" "0" "$rc"
assert_eq "comparator-win-outcome-typed" "win" "$(jq -r '.comparator_outcome // "MISSING"' "$RCPT/win1.json")"
assert_eq "comparator-win-carries-winner" "$STIM_A" "$(jq -r '.winner' "$RCPT/win1.json")"
assert_eq "comparator-win-unit-is-brief" "brief" "$(jq -r '.repeated_measure_unit // "MISSING"' "$RCPT/win1.json")"
assert_eq "comparator-win-unit-id-is-brief-sha" "$BRIEF1" "$(jq -r '.unit_id // "MISSING"' "$RCPT/win1.json")"

# --- 2. a tie is retained as a validated non-win, never dropped -------------
build_group tie1 "$BRIEF2" tie
rc=0; out=$(validate_group tie1 "$RCPT/tie1.json" 2>&1) || rc=$?
[ "$rc" = 0 ] || printf '%s\n' "$out" >&2
assert_eq "comparator-retains-tie" "0" "$rc"
assert_eq "comparator-tie-outcome-typed" "tie" "$(jq -r '.comparator_outcome // "MISSING"' "$RCPT/tie1.json")"
assert_eq "comparator-tie-has-no-winner" "null" "$(jq -r '.winner' "$RCPT/tie1.json")"

# --- 3. an abstention is retained as a validated non-win -------------------
build_group abst1 "$BRIEF3" abstention
rc=0; out=$(validate_group abst1 "$RCPT/abst1.json" 2>&1) || rc=$?
[ "$rc" = 0 ] || printf '%s\n' "$out" >&2
assert_eq "comparator-retains-abstention" "0" "$rc"
assert_eq "comparator-abstention-outcome-typed" "abstention" "$(jq -r '.comparator_outcome // "MISSING"' "$RCPT/abst1.json")"
assert_eq "comparator-abstention-has-no-winner" "null" "$(jq -r '.winner' "$RCPT/abst1.json")"

# --- 4. the outcome vocabulary is closed and cannot be laundered ------------
mutate() { # slug jq-program name
  local slug="$1" prog="$2" name="$3"
  local g
  g="$WORK/$slug/group.json"
  cp "$g" "$g.orig"
  jq "$prog" "$g.orig" > "$g"
  assert_fail "$name" "$BALLOT" validate "$g" "$WORK/$slug/pointwise" "$CALIBRATION" "$WORK/reject.json"
  mv "$g.orig" "$g"
}
build_group win2 "$BRIEF4" win
mutate win2 '.outcome="win"' "comparator-rejects-bare-win-literal"
mutate win2 '.outcome="resolved"' "comparator-rejects-winnerless-resolution"
mutate win2 '.outcome="tie"' "comparator-rejects-unanimous-group-declared-tie"
mutate win2 '.outcome="abstention"' "comparator-rejects-abstention-without-abstainer"
mutate win2 '.exposures[1].choice="abstain" | .exposures[1].abstain_reason="unsure"' "comparator-rejects-win-with-abstainer"
build_group tie2 "$BRIEF4" tie
mutate tie2 ".outcome=\"resolved-$STIM_A\"" "comparator-rejects-tie-declared-as-win"
build_group abst2 "$BRIEF4" abstention
mutate abst2 ".outcome=\"resolved-$STIM_A\"" "comparator-rejects-abstention-declared-as-win"
[ -e "$WORK/reject.json" ] && rejected=present || rejected=absent
assert_eq "comparator-rejection-leaves-no-receipt" "absent" "$rejected"

# --- 5. the tally counts only validated wins, inside a fixed denominator ----
# Three units observed (win, tie, abstention) against a fixed denominator of 5:
# the two unmeasured briefs stay in the denominator as missing evidence.
rc=0; out=$("$BALLOT" tally "$RCPT" 5 "$TALLY" 2>&1) || rc=$?
[ "$rc" = 0 ] || printf '%s\n' "$out" >&2
assert_eq "tally-accepts-mixed-outcomes" "0" "$rc"
assert_eq "tally-counts-only-validated-wins" "1" "$(jq -r '.wins' "$TALLY")"
assert_eq "tally-denominator-is-fixed" "5" "$(jq -r '.denominator' "$TALLY")"
assert_eq "tally-tie-is-non-win" "1" "$(jq -r '.non_wins.tie' "$TALLY")"
assert_eq "tally-abstention-is-non-win" "1" "$(jq -r '.non_wins.abstention' "$TALLY")"
assert_eq "tally-missing-evidence-is-non-win" "2" "$(jq -r '.non_wins.missing_evidence' "$TALLY")"
assert_eq "tally-invalid-evidence-is-non-win" "0" "$(jq -r '.non_wins.invalid_evidence' "$TALLY")"
assert_eq "tally-unit-is-brief" "brief" "$(jq -r '.repeated_measure_unit' "$TALLY")"
assert_eq "tally-partition-exhausts-denominator" "5" \
  "$(jq -r '.wins + (.non_wins | to_entries | map(.value) | add)' "$TALLY")"

# --- 6. repeated measures on one brief cannot inflate wins ------------------
INFL="$WORK/inflated"; mkdir -p "$INFL"
cp "$RCPT/win1.json" "$INFL/replicate-1.json"
cp "$RCPT/win1.json" "$INFL/replicate-2.json"
cp "$RCPT/win1.json" "$INFL/replicate-3.json"
assert_ok "tally-accepts-replicates" "$BALLOT" tally "$INFL" 3 "$TALLY"
assert_eq "tally-collapses-replicates-to-one-brief" "1" "$(jq -r '.wins' "$TALLY")"
assert_eq "tally-replicates-do-not-shrink-denominator" "2" "$(jq -r '.non_wins.missing_evidence' "$TALLY")"

# --- 7. a non-win replicate poisons its brief; it is never averaged away ----
MIX="$WORK/mixed"; mkdir -p "$MIX"
cp "$RCPT/win1.json" "$MIX/win.json"
jq --arg b "$BRIEF1" '.brief_sha256=$b | .unit_id=$b' "$RCPT/tie1.json" > "$MIX/tie.json"
assert_ok "tally-accepts-mixed-replicates" "$BALLOT" tally "$MIX" 1 "$TALLY"
assert_eq "tally-mixed-replicates-are-not-a-win" "0" "$(jq -r '.wins' "$TALLY")"
assert_eq "tally-mixed-replicates-count-as-tie" "1" "$(jq -r '.non_wins.tie' "$TALLY")"

# --- 8. contradictory wins on one brief are invalid, not a win -------------
CONTRA="$WORK/contradictory"; mkdir -p "$CONTRA"
build_group winb "$BRIEF1" win-b
validate_group winb "$CONTRA/win-b.json"
cp "$RCPT/win1.json" "$CONTRA/win-a.json"
assert_ok "tally-accepts-contradictory-replicates" "$BALLOT" tally "$CONTRA" 1 "$TALLY"
assert_eq "tally-contradictory-winners-are-not-a-win" "0" "$(jq -r '.wins' "$TALLY")"
assert_eq "tally-contradictory-winners-are-invalid" "1" "$(jq -r '.non_wins.invalid_evidence' "$TALLY")"

# --- 9. unreadable and forged receipts stay in the denominator as non-wins --
BAD="$WORK/bad"; mkdir -p "$BAD"
printf 'not json at all\n' > "$BAD/torn.json"
jq '.comparator_outcome="victory"' "$RCPT/win1.json" > "$BAD/forged-outcome.json"
jq --arg b "$(rep64 5)" '.brief_sha256=$b | .unit_id=$b | .winner=null' "$RCPT/win1.json" > "$BAD/win-without-winner.json"
jq --arg b "$(rep64 6)" '.brief_sha256=$b | .unit_id=$b | .status="rejected"' "$RCPT/win1.json" > "$BAD/not-eligible.json"
jq --arg b "$(rep64 7)" '.brief_sha256=$b | .unit_id=$b | .comparator_outcome="tie"' "$RCPT/win1.json" > "$BAD/non-win-with-winner.json"
assert_ok "tally-accepts-invalid-evidence" "$BALLOT" tally "$BAD" 6 "$TALLY"
assert_eq "tally-counts-invalid-evidence" "5" "$(jq -r '.non_wins.invalid_evidence' "$TALLY")"
assert_eq "tally-invalid-evidence-never-a-win" "0" "$(jq -r '.wins' "$TALLY")"
assert_eq "tally-invalid-evidence-keeps-denominator" "6" \
  "$(jq -r '.wins + (.non_wins | to_entries | map(.value) | add)' "$TALLY")"

# --- 10. the denominator cannot shrink, inflate, or be waived --------------
rm -f "$TALLY"
assert_fail "tally-rejects-more-units-than-denominator" "$BALLOT" tally "$RCPT" 2 "$TALLY"
[ -e "$TALLY" ] && tally_present=present || tally_present=absent
assert_eq "tally-fail-closed-no-partial" "absent" "$tally_present"
assert_fail "tally-rejects-zero-denominator" "$BALLOT" tally "$RCPT" 0 "$TALLY"
assert_fail "tally-rejects-non-numeric-denominator" "$BALLOT" tally "$RCPT" all "$TALLY"
assert_fail "tally-rejects-missing-directory" "$BALLOT" tally "$WORK/absent" 5 "$TALLY"

# --- 11. the tally never upgrades fixture evidence into a certified claim ---
"$BALLOT" tally "$RCPT" 5 "$TALLY"
assert_eq "tally-stays-fixture" "fixture" "$(jq -r '.classification' "$TALLY")"
assert_eq "tally-never-claims-human-panel" "false" "$(jq -r '.human_certified' "$TALLY")"
assert_eq "tally-binds-validator-fingerprint" "$(sha256 "$BALLOT")" "$(jq -r '.validator.fingerprint' "$TALLY")"
finish
