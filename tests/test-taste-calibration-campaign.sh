#!/usr/bin/env bash
# Calibration-campaign controller contract: executes frozen work units through the
# Cycle 40 isolated judge runner with pointwise-before-pairwise ordering, unique
# sessions, blind identity, mirrored orientations, bounded retries, abstention,
# hash-chained raw-response ledgers, provider pinning, and no shared ballot
# channel. Fake provider adapters only — it never decides eligibility.
#
# Cadence (red-first): order, isolation, duplicate session, retry class, timeout,
# malformed output, leak, partial resume, abstention.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAMPAIGN="$ROOT/bin/polylane-taste-calibration-campaign.sh"
export POLYLANE_TASTE_NOW="2026-08-12T00:00:00Z"

make_tmpdir
W="$TEST_TMPDIR"
IMG_A="$W/a.png"; IMG_B="$W/b.png"; printf 'PNG-A\n' > "$IMG_A"; printf 'PNG-B\n' > "$IMG_B"
CAND_A="stim-a1b2c3d4e5f6"; CAND_B="stim-0f1e2d3c4b5a"
H64_BRIEF=$(printf 'brief' | shasum -a 256 | awk '{print $1}')
H64_CAP=$(printf 'capture' | shasum -a 256 | awk '{print $1}')
H64_PROMPT=$(printf 'prompt' | shasum -a 256 | awk '{print $1}')
H64_CONFIG=$(printf 'pinned-config' | shasum -a 256 | awk '{print $1}')
sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

CRIT='["color","craftsmanship","hierarchy","originality","product_fit","spatial_rhythm","state_coherence","typography"]'

# make_adapter PATH CALLLOG BEHAVIOR — fixture judge adapter; logs work_unit_id per call.
make_adapter() {
  local path="$1" calllog="$2" behavior="$3"
  : > "$calllog"
  cat > "$path" <<ADAPTER
#!/usr/bin/env bash
set -euo pipefail
req="\${1:-/dev/stdin}"
wu=\$(jq -r .work_unit_id "\$req")
printf '%s\n' "\$wu" >> "$calllog"
crit='$CRIT'
scores_a='{"color":5,"craftsmanship":5,"hierarchy":5,"originality":5,"product_fit":6,"spatial_rhythm":5,"state_coherence":5,"typography":5}'
scores_b='{"color":4,"craftsmanship":4,"hierarchy":4,"originality":4,"product_fit":3,"spatial_rhythm":4,"state_coherence":4,"typography":4}'
obs() { jq -cn --arg p "\$1" --argjson crit "\$crit" '\$crit | map({criterion:.,capture_id:("cap-"+\$p),region_or_state:"header",brief_clause:"clause-1",reason:("position "+\$p+" evidence")})'; }
emit() { # choice reason
  jq -n --arg wu "\$wu" --arg choice "\$1" --argjson ra "\$2" --argjson sa "\$scores_a" --argjson sb "\$scores_b" --argjson oa "\$(obs A)" --argjson ob "\$(obs B)" \
    '{schema_version:"taste-judge-response/v1",work_unit_id:\$wu,positions:{A:\$sa,B:\$sb},observations:{A:\$oa,B:\$ob},choice:\$choice,abstain_reason:\$ra}'
}
ADAPTER
  case "$behavior" in
    vote)    printf 'emit A null\n' >> "$path" ;;
    abstain) printf '%s\n' "emit abstain '\"positions too close to separate\"'" >> "$path" ;;
    badkey)  printf 'emit A null | jq ".rogue=1"\n' >> "$path" ;;
    timeout) printf 'sleep 3\nemit A null\n' >> "$path" ;;
    flaky)   cat >> "$path" <<FLK
n=\$(wc -l < "$calllog" | tr -d ' ')
if [ "\$n" -le 1 ]; then echo "transient infra fault" >&2; exit 7; fi
emit A null
FLK
             ;;
    *) echo "unknown behavior $behavior" >&2; return 1 ;;
  esac
  chmod +x "$path"
}

# make_wu FILE ADAPTER FP WU SESSION MIRROR ROLE DISPLAY [deadline] [imgA] [imgB]
make_wu() {
  local file="$1" adapter="$2" fp="$3" wu="$4" sess="$5" mirror="$6" role="$7" disp="$8" deadline="${9:-30}"
  local imgA="${10:-$IMG_A}" imgB="${11:-$IMG_B}"
  jq -n --arg wu "$wu" --arg sess "$sess" --arg role "$role" --arg disp "$disp" \
    --arg mirror "$mirror" --arg adapter "$adapter" --arg fp "$fp" \
    --arg imgA "$imgA" --arg imgB "$imgB" \
    --arg brief "$H64_BRIEF" --arg cap "$H64_CAP" --arg prompt "$H64_PROMPT" \
    --arg ca "$CAND_A" --arg cb "$CAND_B" --argjson deadline "$deadline" '
    {schema_version:"taste-judge-workunit/v1",work_unit_id:$wu,mirror_group_id:$mirror,
     role:$role,session_id:$sess,judge_id:"judge-alpha01",
     adapter:{command:[$adapter],fingerprint:$fp},
     candidate_ids:[$ca,$cb],display_order:$disp,images:{A:$imgA,B:$imgB},
     brief_sha256:$brief,capture_manifest_sha256:$cap,prompt_sha256:$prompt,
     response_schema:"taste-judge-response/v1",deadline_s:$deadline}' > "$file"
}

# make_plan FILE FP POINTWISE... -- PAIRWISE...
make_plan() {
  local file="$1" fp="$2"; shift 2
  local -a pw=() pr=()
  local in_pair=0 p
  for p in "$@"; do
    if [ "$p" = "--" ]; then in_pair=1; continue; fi
    if [ "$in_pair" = 0 ]; then pw[${#pw[@]}]="$p"; else pr[${#pr[@]}]="$p"; fi
  done
  local pw_json pr_json
  pw_json=$( { [ "${#pw[@]}" -gt 0 ] && printf '%s\n' "${pw[@]}" || true; } | jq -R . | jq -cs .)
  pr_json=$( { [ "${#pr[@]}" -gt 0 ] && printf '%s\n' "${pr[@]}" || true; } | jq -R . | jq -cs .)
  jq -n --arg fp "$fp" --arg cfg "$H64_CONFIG" --argjson pw "$pw_json" --argjson pr "$pr_json" '
    {schema_version:"taste-calibration-campaign/v1",campaign_id:"camp-c41test",
     judge_id:"judge-alpha01",
     provider_pin:{provider:"fake-provider",model:"fake-model-1",adapter_fingerprint:$fp,config_sha256:$cfg},
     phases:{pointwise:$pw,pairwise:$pr}}' > "$file"
}

# ledger_field DIR WU FIELD — jq value of the ledger entry for one work unit.
ledger_field() {
  jq -rs --arg wu "$2" "map(select(.work_unit_id==\$wu)) | .[0].$3" "$1/ledger.jsonl"
}

# ---- happy path: order, ledger, mirrors, resume -----------------------------

ADP="$W/adapter-vote"; LOG="$W/calls-vote.log"
make_adapter "$ADP" "$LOG" vote
FP=$(sha256 "$ADP")
make_wu "$W/wu-p1.json" "$ADP" "$FP" wu-p1 sess-p1 mg-p1 primary "A/B"
make_wu "$W/wu-q1.json" "$ADP" "$FP" wu-q1 sess-q1 mg-q0 primary "A/B"
make_wu "$W/wu-q2.json" "$ADP" "$FP" wu-q2 sess-q2 mg-q0 mirror "B/A"
PLAN="$W/plan.json"
make_plan "$PLAN" "$FP" "$W/wu-p1.json" -- "$W/wu-q1.json" "$W/wu-q2.json"

assert_rc "plan-accepts-valid-campaign" 0 "$CAMPAIGN" plan "$PLAN"

D1="$W/camp1"
assert_rc "run-all-substantive-rc0" 0 "$CAMPAIGN" run "$PLAN" "$D1"
assert_eq "run-invokes-every-unit-once" 3 "$(wc -l < "$LOG" | tr -d ' ')"
assert_eq "pointwise-runs-before-pairwise" "wu-p1" "$(head -1 "$LOG")"
assert_eq "ledger-has-three-sealed-entries" 3 "$(wc -l < "$D1/ledger.jsonl" | tr -d ' ')"
assert_eq "ledger-status-voted" "voted" "$(ledger_field "$D1" wu-p1 terminal_status)"
hash_ok() { ledger_field "$1" "$2" "$3" | grep -qE '^[0-9a-f]{64}$'; }
assert_ok "ledger-response-hash-bound" hash_ok "$D1" wu-p1 response_sha256
assert_ok "ledger-invocation-hash-bound" hash_ok "$D1" wu-p1 request_sha256
assert_eq "no-shared-ballot-channel-isolated-run-dirs" 3 "$(ls "$D1/runs" | wc -l | tr -d ' ')"
assert_rc "ledger-hash-chain-verifies" 0 "$CAMPAIGN" verify-ledger "$D1"

# summary never decides eligibility
assert_eq "summary-decides-eligibility-false" "false" "$(jq -r .decides_eligibility "$D1/campaign-summary.json")"
assert_eq "summary-carries-no-eligible-field" "0" "$(jq -r '[paths|map(tostring)|join(".")|select(test("eligib";"i"))|select(. != "decides_eligibility")]|length' "$D1/campaign-summary.json")"
assert_eq "summary-counts-voted" 3 "$(jq -r .counts.voted "$D1/campaign-summary.json")"

# full-rerun resume: everything sealed, adapter never re-invoked
assert_rc "resume-full-rerun-rc0" 0 "$CAMPAIGN" run "$PLAN" "$D1"
assert_eq "resume-does-not-reinvoke-adapter" 3 "$(wc -l < "$LOG" | tr -d ' ')"
assert_eq "resume-does-not-grow-ledger" 3 "$(wc -l < "$D1/ledger.jsonl" | tr -d ' ')"

# partial resume: a crash left only the pointwise entry in the ledger
D2="$W/camp2"; mkdir -p "$D2"
cp "$D1/claim.json" "$D2/claim.json"
head -1 "$D1/ledger.jsonl" > "$D2/ledger.jsonl"
: > "$LOG"
assert_rc "partial-resume-completes-rc0" 0 "$CAMPAIGN" run "$PLAN" "$D2"
assert_eq "partial-resume-runs-only-unsealed-units" "wu-q1
wu-q2" "$(cat "$LOG")"
assert_eq "partial-resume-ledger-complete" 3 "$(wc -l < "$D2/ledger.jsonl" | tr -d ' ')"
assert_rc "partial-resume-chain-verifies" 0 "$CAMPAIGN" verify-ledger "$D2"

# tampered ledger: fail closed on resume and on verify
D3="$W/camp3"; mkdir -p "$D3"
cp "$D1/claim.json" "$D3/claim.json"
sed 's/"terminal_status":"voted"/"terminal_status":"abstained"/' "$D1/ledger.jsonl" > "$D3/ledger.jsonl"
assert_rc "verify-ledger-detects-tamper" 1 "$CAMPAIGN" verify-ledger "$D3"
assert_rc "resume-refuses-tampered-ledger" 3 "$CAMPAIGN" run "$PLAN" "$D3"

# foreign campaign dir: claimed by a different frozen plan
PLAN_B="$W/plan-b.json"
make_plan "$PLAN_B" "$FP" "$W/wu-p1.json" --
assert_rc "foreign-campaign-dir-refused" 3 "$CAMPAIGN" run "$PLAN_B" "$D1"

# ---- pre-invocation configuration violations (adapter must never run) -------

ADP_G="$W/adapter-guard"; LOG_G="$W/calls-guard.log"
make_adapter "$ADP_G" "$LOG_G" vote
FP_G=$(sha256 "$ADP_G")

# duplicate session across units
make_wu "$W/wu-d1.json" "$ADP_G" "$FP_G" wu-d1 sess-dup mg-d1 primary "A/B"
make_wu "$W/wu-d2.json" "$ADP_G" "$FP_G" wu-d2 sess-dup mg-d2 primary "A/B"
PLAN_DUP="$W/plan-dup.json"; make_plan "$PLAN_DUP" "$FP_G" "$W/wu-d1.json" "$W/wu-d2.json" --
assert_rc "duplicate-session-refused" 3 "$CAMPAIGN" run "$PLAN_DUP" "$W/camp-dup"

# duplicate work unit id
make_wu "$W/wu-i1.json" "$ADP_G" "$FP_G" wu-same sess-i1 mg-i1 primary "A/B"
make_wu "$W/wu-i2.json" "$ADP_G" "$FP_G" wu-same sess-i2 mg-i2 primary "A/B"
PLAN_ID="$W/plan-id.json"; make_plan "$PLAN_ID" "$FP_G" "$W/wu-i1.json" "$W/wu-i2.json" --
assert_rc "duplicate-work-unit-refused" 3 "$CAMPAIGN" run "$PLAN_ID" "$W/camp-id"

# mirror pair must flip orientation across its two sessions
make_wu "$W/wu-m1.json" "$ADP_G" "$FP_G" wu-m1 sess-m1 mg-m0 primary "A/B"
make_wu "$W/wu-m2.json" "$ADP_G" "$FP_G" wu-m2 sess-m2 mg-m0 mirror "A/B"
PLAN_MIR="$W/plan-mir.json"; make_plan "$PLAN_MIR" "$FP_G" -- "$W/wu-m1.json" "$W/wu-m2.json"
assert_rc "mirror-same-orientation-refused" 3 "$CAMPAIGN" run "$PLAN_MIR" "$W/camp-mir"

# provider pinning: unit adapter fingerprint differs from the pinned fingerprint
FP_OTHER=$(printf 'other-adapter' | shasum -a 256 | awk '{print $1}')
make_wu "$W/wu-f1.json" "$ADP_G" "$FP_OTHER" wu-f1 sess-f1 mg-f1 primary "A/B"
PLAN_FP="$W/plan-fp.json"; make_plan "$PLAN_FP" "$FP_G" "$W/wu-f1.json" --
assert_rc "unpinned-adapter-refused" 3 "$CAMPAIGN" run "$PLAN_FP" "$W/camp-fp"

# blindness: candidate identity leaked into an adapter-visible image path
LEAK_IMG="$W/$CAND_A-leak.png"; printf 'PNG-LEAK\n' > "$LEAK_IMG"
make_wu "$W/wu-l1.json" "$ADP_G" "$FP_G" wu-l1 sess-l1 mg-l1 primary "A/B" 30 "$LEAK_IMG" "$IMG_B"
PLAN_LEAK="$W/plan-leak.json"; make_plan "$PLAN_LEAK" "$FP_G" "$W/wu-l1.json" --
assert_rc "identity-leak-in-image-path-refused" 3 "$CAMPAIGN" run "$PLAN_LEAK" "$W/camp-leak"

assert_eq "guard-violations-never-invoke-adapter" 0 "$(wc -l < "$LOG_G" | tr -d ' ')"

# malformed plan shapes
printf 'not json\n' > "$W/plan-broken.json"
assert_rc "malformed-plan-refused" 4 "$CAMPAIGN" run "$W/plan-broken.json" "$W/camp-broken"
jq '. + {rogue:1}' "$PLAN" > "$W/plan-extra.json"
assert_rc "extra-plan-key-refused" 4 "$CAMPAIGN" run "$W/plan-extra.json" "$W/camp-extra"
jq 'del(.phases)' "$PLAN" > "$W/plan-nophases.json"
assert_rc "missing-phases-refused" 4 "$CAMPAIGN" plan "$W/plan-nophases.json"
PLAN_MISS="$W/plan-missing-unit.json"; make_plan "$PLAN_MISS" "$FP" "$W/wu-nope.json" --
assert_rc "missing-work-unit-file-refused" 4 "$CAMPAIGN" plan "$PLAN_MISS"

# ---- terminal outcome classes: retry, timeout, parse, abstain ---------------

# bounded retry: one infra retry then a substantive vote
ADP_FL="$W/adapter-flaky"; LOG_FL="$W/calls-flaky.log"
make_adapter "$ADP_FL" "$LOG_FL" flaky
FP_FL=$(sha256 "$ADP_FL")
make_wu "$W/wu-fl.json" "$ADP_FL" "$FP_FL" wu-fl sess-fl mg-fl primary "A/B"
PLAN_FL="$W/plan-fl.json"; make_plan "$PLAN_FL" "$FP_FL" "$W/wu-fl.json" --
D_FL="$W/camp-fl"
assert_rc "infra-retry-recovers-rc0" 0 "$CAMPAIGN" run "$PLAN_FL" "$D_FL"
assert_eq "infra-retry-bounded-two-calls" 2 "$(wc -l < "$LOG_FL" | tr -d ' ')"
assert_eq "infra-retry-recorded-in-ledger" "true" "$(ledger_field "$D_FL" wu-fl retry_used)"

# timeout: deadline enforced, sealed as failed-infra, campaign completes rc1
ADP_TO="$W/adapter-timeout"; LOG_TO="$W/calls-timeout.log"
make_adapter "$ADP_TO" "$LOG_TO" timeout
FP_TO=$(sha256 "$ADP_TO")
make_wu "$W/wu-to.json" "$ADP_TO" "$FP_TO" wu-to sess-to mg-to primary "A/B" 1
PLAN_TO="$W/plan-to.json"; make_plan "$PLAN_TO" "$FP_TO" "$W/wu-to.json" --
D_TO="$W/camp-to"
assert_rc "timeout-campaign-completes-rc1" 1 "$CAMPAIGN" run "$PLAN_TO" "$D_TO"
assert_eq "timeout-sealed-failed-infra" "failed-infra" "$(ledger_field "$D_TO" wu-to terminal_status)"

# malformed model output: failed-parse, exactly one call (never retried)
ADP_BK="$W/adapter-badkey"; LOG_BK="$W/calls-badkey.log"
make_adapter "$ADP_BK" "$LOG_BK" badkey
FP_BK=$(sha256 "$ADP_BK")
make_wu "$W/wu-bk.json" "$ADP_BK" "$FP_BK" wu-bk sess-bk mg-bk primary "A/B"
PLAN_BK="$W/plan-bk.json"; make_plan "$PLAN_BK" "$FP_BK" "$W/wu-bk.json" --
D_BK="$W/camp-bk"
assert_rc "malformed-output-campaign-rc1" 1 "$CAMPAIGN" run "$PLAN_BK" "$D_BK"
assert_eq "malformed-output-sealed-failed-parse" "failed-parse" "$(ledger_field "$D_BK" wu-bk terminal_status)"
assert_eq "parse-failure-never-retried" 1 "$(wc -l < "$LOG_BK" | tr -d ' ')"

# failed units stay sealed on resume: no retry storm
: > "$LOG_BK"
assert_rc "failed-unit-resume-replays-rc1" 1 "$CAMPAIGN" run "$PLAN_BK" "$D_BK"
assert_eq "failed-unit-not-reinvoked-on-resume" 0 "$(wc -l < "$LOG_BK" | tr -d ' ')"

# abstention is substantive, not failure
ADP_AB="$W/adapter-abstain"; LOG_AB="$W/calls-abstain.log"
make_adapter "$ADP_AB" "$LOG_AB" abstain
FP_AB=$(sha256 "$ADP_AB")
make_wu "$W/wu-ab.json" "$ADP_AB" "$FP_AB" wu-ab sess-ab mg-ab primary "A/B"
PLAN_AB="$W/plan-ab.json"; make_plan "$PLAN_AB" "$FP_AB" "$W/wu-ab.json" --
D_AB="$W/camp-ab"
assert_rc "abstention-substantive-rc0" 0 "$CAMPAIGN" run "$PLAN_AB" "$D_AB"
assert_eq "abstention-sealed" "abstained" "$(ledger_field "$D_AB" wu-ab terminal_status)"
assert_eq "abstention-decision-recorded" "abstain" "$(ledger_field "$D_AB" wu-ab decision)"
assert_eq "abstention-counted-not-failed" 1 "$(jq -r .counts.abstained "$D_AB/campaign-summary.json")"

finish
