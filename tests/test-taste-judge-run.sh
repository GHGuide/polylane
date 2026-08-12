#!/usr/bin/env bash
# Judge-runner contract: provider-neutral visual-judge campaign orchestration and
# deterministic parsing. Fixture adapters only — this never mints a live receipt.
#
# Cadence (red-first): partial completion, crash/resume, duplicate worker, alias,
# timeout, parse failure, stale response, changed orientation, retry exhaustion.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$ROOT/bin/polylane-taste-judge-run.sh"
PARSE="$ROOT/bin/polylane-taste-judge-parse.sh"
export POLYLANE_TASTE_NOW="2026-08-12T00:00:00Z"

make_tmpdir
W="$TEST_TMPDIR"
IMG_A="$W/a.png"; IMG_B="$W/b.png"; printf 'PNG-A\n' > "$IMG_A"; printf 'PNG-B\n' > "$IMG_B"
CAND_A="stim-a1b2c3d4e5f6"; CAND_B="stim-0f1e2d3c4b5a"
H64_BRIEF=$(printf 'brief' | shasum -a 256 | awk '{print $1}')
H64_CAP=$(printf 'capture' | shasum -a 256 | awk '{print $1}')
H64_PROMPT=$(printf 'prompt' | shasum -a 256 | awk '{print $1}')
sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

CRIT='["color","craftsmanship","hierarchy","originality","product_fit","spatial_rhythm","state_coherence","typography"]'

# make_adapter PATH CALLLOG BEHAVIOR — writes a fixture judge adapter.
make_adapter() {
  local path="$1" calllog="$2" behavior="$3"
  : > "$calllog"
  cat > "$path" <<ADAPTER
#!/usr/bin/env bash
set -euo pipefail
printf 'call\n' >> "$calllog"
req="\${1:-/dev/stdin}"
wu=\$(jq -r .work_unit_id "\$req")
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
    leak)    printf 'emit A null | jq ".observations.A[0].reason=\"prefer '"$CAND_A"'\"\n"' >> "$path" ;;
    empty)   printf 'exit 0\n' >> "$path" ;;
    timeout) printf 'sleep 3\nemit A null\n' >> "$path" ;;
    flaky)   cat >> "$path" <<'FLK'
n=$(( $(cat "$calllog" | wc -l | tr -d ' ') ))
if [ "$n" -le 1 ]; then echo "transient infra fault" >&2; exit 7; fi
emit A null
FLK
             # flaky references $calllog; re-embed with expanded value
             sed -i.bak "s#\"\$calllog\"#\"$calllog\"#g" "$path"; rm -f "$path.bak" ;;
    *) echo "unknown behavior $behavior" >&2; return 1 ;;
  esac
  chmod +x "$path"
}

# make_manifest FILE ADAPTER FINGERPRINT WU SESSION ROLE DISPLAY [deadline]
make_manifest() {
  local file="$1" adapter="$2" fp="$3" wu="$4" sess="$5" role="$6" disp="$7" deadline="${8:-30}"
  jq -n --arg wu "$wu" --arg sess "$sess" --arg role "$role" --arg disp "$disp" \
    --arg adapter "$adapter" --arg fp "$fp" --arg imgA "$IMG_A" --arg imgB "$IMG_B" \
    --arg brief "$H64_BRIEF" --arg cap "$H64_CAP" --arg prompt "$H64_PROMPT" \
    --arg ca "$CAND_A" --arg cb "$CAND_B" --argjson deadline "$deadline" '
    {schema_version:"taste-judge-workunit/v1",work_unit_id:$wu,mirror_group_id:"mg-c40demo",
     role:$role,session_id:$sess,judge_id:"judge-alpha01",
     adapter:{command:[$adapter],fingerprint:$fp},
     candidate_ids:[$ca,$cb],display_order:$disp,images:{A:$imgA,B:$imgB},
     brief_sha256:$brief,capture_manifest_sha256:$cap,prompt_sha256:$prompt,
     response_schema:"taste-judge-response/v1",deadline_s:$deadline}' > "$file"
}

# valid_response FILE WU CHOICE — a schema-valid raw judge response.
valid_response() {
  local file="$1" wu="$2" choice="$3" reason=null
  [ "$choice" = abstain ] && reason='"too close"'
  jq -n --arg wu "$wu" --arg choice "$choice" --argjson reason "$reason" --argjson crit "$CRIT" '
    ($crit | map({criterion:.,capture_id:"cap-x",region_or_state:"header",brief_clause:"c1",reason:"ev"})) as $o |
    {schema_version:"taste-judge-response/v1",work_unit_id:$wu,
     positions:{A:{color:5,craftsmanship:5,hierarchy:5,originality:5,product_fit:6,spatial_rhythm:5,state_coherence:5,typography:5},
                B:{color:4,craftsmanship:4,hierarchy:4,originality:4,product_fit:3,spatial_rhythm:4,state_coherence:4,typography:4}},
     observations:{A:$o,B:$o},choice:$choice,abstain_reason:$reason}' > "$file"
}

# =====================================================================
# A. Parser happy path — emit pointwise+pairwise, bindings, mapping.
# =====================================================================
MF="$W/mf.json"; ADP="$W/adp-ok"; LOG="$W/log-ok"
make_adapter "$ADP" "$LOG" vote
make_manifest "$MF" "$ADP" "$(sha256 "$ADP")" wu-alpha sess-primary primary "A/B"
RESP="$W/resp.json"; valid_response "$RESP" wu-alpha A
POUT="$W/pout"; rm -rf "$POUT"
prc=0; "$PARSE" emit "$MF" "$RESP" "$POUT" || prc=$?
assert_eq "parse-emit-ok" "0" "$prc"
assert_eq "parse-emit-pointwise-a-schema" "taste-pointwise/v1" "$(jq -r .schema_version "$POUT/pointwise-wu-alpha-a.json" 2>/dev/null)"
assert_eq "parse-emit-pairwise-schema" "taste-pairwise/v1" "$(jq -r .schema_version "$POUT/pairwise-wu-alpha.json" 2>/dev/null)"
# display A/B: posA -> candidate_ids[0]=CAND_A, posB -> CAND_B
assert_eq "parse-map-posA-candidate" "$CAND_A" "$(jq -r .candidate_id "$POUT/pointwise-wu-alpha-a.json")"
assert_eq "parse-map-posB-candidate" "$CAND_B" "$(jq -r .candidate_id "$POUT/pointwise-wu-alpha-b.json")"
assert_eq "parse-pairwise-choice" "A" "$(jq -r .choice "$POUT/pairwise-wu-alpha.json")"
assert_eq "parse-pairwise-winner" "$CAND_A" "$(jq -r .canonical_choice "$POUT/pairwise-wu-alpha.json")"
assert_eq "parse-request-binding-brief" "$H64_BRIEF" "$(jq -r .brief_sha256 "$POUT/pointwise-wu-alpha-a.json")"
assert_eq "parse-request-binding-capture" "$H64_CAP" "$(jq -r .capture_manifest_sha256 "$POUT/pointwise-wu-alpha-a.json")"
assert_eq "parse-request-binding-judge" "judge-alpha01" "$(jq -r .judge_id "$POUT/pairwise-wu-alpha.json")"
assert_eq "parse-response-sha-binding" "$(sha256 "$RESP")" "$(jq -r .response_sha256 "$POUT/pairwise-wu-alpha.json")"
# record_sha256 must equal ballot's recomputation: shasum of jq -cS (del record_sha256)
rec_body=$(jq -cS 'del(.record_sha256)' "$POUT/pointwise-wu-alpha-a.json")
rec_hash=$(printf '%s' "$rec_body" | shasum -a 256 | awk '{print $1}')
assert_eq "parse-pointwise-record-sha-recomputes" "$rec_hash" "$(jq -r .record_sha256 "$POUT/pointwise-wu-alpha-a.json")"
# temporal ordering: pairwise sealed_at strictly after pointwise
pw_at=$(jq -r .sealed_at "$POUT/pointwise-wu-alpha-a.json"); pr_at=$(jq -r .sealed_at "$POUT/pairwise-wu-alpha.json")
assert_eq "parse-pairwise-after-pointwise" "true" "$( [ "$pr_at" \> "$pw_at" ] && echo true || echo false )"
# no candidate provenance leaked (no baseline/current/provenance keys anywhere)
assert_eq "parse-no-provenance-pointwise" "" "$(jq -r 'paths(scalars) as $p | $p | join(".")' "$POUT/pointwise-wu-alpha-a.json" | grep -iE 'baseline|current|provenance|is_baseline' || true)"
assert_eq "parse-all-flags-false" "false false false false" "$(jq -r '[.identity_visible,.prior_ballots_visible,.injection_detected,.judge_discussion]|map(tostring)|join(" ")' "$POUT/pointwise-wu-alpha-a.json")"

# mirror orientation B/A flips the mapping
MF_BA="$W/mf-ba.json"; make_manifest "$MF_BA" "$ADP" "$(sha256 "$ADP")" wu-mirror sess-mirror mirror "B/A"
RESP_BA="$W/resp-ba.json"; valid_response "$RESP_BA" wu-mirror A
POUT_BA="$W/pout-ba"; rm -rf "$POUT_BA"; "$PARSE" emit "$MF_BA" "$RESP_BA" "$POUT_BA"
assert_eq "parse-mirror-posA-flipped" "$CAND_B" "$(jq -r .candidate_id "$POUT_BA/pointwise-wu-mirror-a.json")"
assert_eq "parse-mirror-winner-flipped" "$CAND_B" "$(jq -r .canonical_choice "$POUT_BA/pairwise-wu-mirror.json")"

# =====================================================================
# B. Parser rejections — one exact schema, fail-closed, no inferred choice.
# =====================================================================
reject() { # name mutation
  local name="$1" mut="$2" f="$W/bad.json" o="$W/bad-out"; rm -rf "$o"
  jq "$mut" "$RESP" > "$f"
  assert_fail "$name" "$PARSE" emit "$MF" "$f" "$o"
  [ ! -e "$o/pairwise-wu-alpha.json" ] && pass "$name-no-partial" || fail "$name-no-partial" "emitted a record on reject"
}
reject "parse-rejects-unknown-key"        '.rogue=1'
reject "parse-rejects-numeric-coercion"   '.positions.A.color="5"'
reject "parse-rejects-out-of-range"       '.positions.A.color=8'
reject "parse-rejects-noninteger"         '.positions.A.color=5.5'
reject "parse-rejects-extra-criterion"    '.positions.A.sparkle=5'
reject "parse-rejects-missing-criterion"  '.positions.A|=del(.color)'
reject "parse-rejects-bad-choice"         '.choice="C"'
reject "parse-rejects-obs-count"          '.observations.A|=.[1:]'
reject "parse-rejects-obs-extra-key"      '.observations.A[0].flag=true'
reject "parse-rejects-empty-obs-string"   '.observations.A[0].reason=""'
reject "parse-rejects-injection-flag"     '.injection_detected=true'
reject "parse-rejects-identity-key"       '.candidate_id="stim-a1b2c3d4e5f6"'
reject "parse-rejects-abstain-no-reason"  '.choice="abstain"|.abstain_reason=null'
reject "parse-rejects-reason-on-vote"     '.abstain_reason="x"'
# work_unit_id echo binding
jq '.work_unit_id="wu-forgery"' "$RESP" > "$W/echo.json"
assert_fail "parse-rejects-echo-mismatch" "$PARSE" emit "$MF" "$W/echo.json" "$W/echo-out"
# identity leakage in free text (candidate id embedded in reason)
jq --arg c "$CAND_A" '.observations.A[0].reason=("prefer "+$c)' "$RESP" > "$W/leak.json"
assert_fail "parse-rejects-text-identity-leak" "$PARSE" emit "$MF" "$W/leak.json" "$W/leak-out"
# duplicate JSON keys (raw) must be rejected
printf '{"schema_version":"taste-judge-response/v1","schema_version":"x"}\n' > "$W/dup.json"
assert_fail "parse-rejects-duplicate-keys" "$PARSE" emit "$MF" "$W/dup.json" "$W/dup-out"

# =====================================================================
# C. Parser abstain — valid vote of no-confidence, pointwise still emitted.
# =====================================================================
RA="$W/resp-abstain.json"; valid_response "$RA" wu-alpha abstain
AO="$W/abstain-out"; rm -rf "$AO"; "$PARSE" emit "$MF" "$RA" "$AO"
assert_eq "parse-abstain-choice" "abstain" "$(jq -r .choice "$AO/pairwise-wu-alpha.json")"
assert_eq "parse-abstain-reason-kept" "too close" "$(jq -r .abstain_reason "$AO/pairwise-wu-alpha.json")"
assert_eq "parse-abstain-canonical-null" "null" "$(jq -r .canonical_choice "$AO/pairwise-wu-alpha.json")"
assert_eq "parse-abstain-still-scores-pointwise" "taste-pointwise/v1" "$(jq -r .schema_version "$AO/pointwise-wu-alpha-a.json")"
# check mode classifies
assert_eq "parse-check-vote"    "vote"    "$("$PARSE" check "$MF" "$RESP" || true)"
assert_eq "parse-check-abstain" "abstain" "$("$PARSE" check "$MF" "$RA" || true)"
assert_eq "parse-check-invalid" "invalid" "$("$PARSE" check "$MF" "$W/dup.json" || true)"

# =====================================================================
# D. Runner happy vote — isolated session, immutable receipts.
# =====================================================================
RD="$W/run-ok"; rc=0; "$RUN" run "$MF" "$RD" || rc=$?
assert_eq "run-vote-exit0" "0" "$rc"
assert_eq "run-vote-status" "voted" "$(jq -r .terminal_status "$RD/summary.json")"
assert_eq "run-vote-decision" "A" "$(jq -r .decision "$RD/summary.json")"
assert_eq "run-vote-session" "sess-primary" "$(jq -r .session_id "$RD/summary.json")"
assert_eq "run-vote-retry-unused" "false" "$(jq -r .retry_used "$RD/summary.json")"
assert_eq "run-vote-one-call" "1" "$(wc -l < "$LOG" | tr -d ' ')"
assert_eq "run-vote-response-sha" "$(sha256 "$RD/attempts/1/response.json")" "$(jq -r .response_sha256 "$RD/summary.json")"
# raw-response receipt is complete and immutable
assert_eq "run-receipt-adapter-fp" "$(sha256 "$ADP")" "$(jq -r .adapter_fingerprint "$RD/attempts/1/capture.json")"
if : > "$RD/attempts/1/response.json" 2>/dev/null; then fail "run-receipt-immutable" "response.json was writable"; else pass "run-receipt-immutable"; fi
# append-only events present
assert_eq "run-events-appendonly" "true" "$( [ -s "$RD/events.jsonl" ] && echo true || echo false )"
# parse the runner's own captured response into ballot records end-to-end
E2E="$W/e2e-out"; "$PARSE" emit "$MF" "$RD/attempts/1/response.json" "$E2E"
assert_eq "run-parse-e2e-winner" "$CAND_A" "$(jq -r .canonical_choice "$E2E/pairwise-wu-alpha.json")"

# =====================================================================
# E. Runner deliberate abstain (substantive vote of no confidence).
# =====================================================================
ADP_AB="$W/adp-ab"; LOG_AB="$W/log-ab"; make_adapter "$ADP_AB" "$LOG_AB" abstain
MF_AB="$W/mf-ab.json"; make_manifest "$MF_AB" "$ADP_AB" "$(sha256 "$ADP_AB")" wu-ab sess-ab primary "A/B"
RD_AB="$W/run-ab"; rc=0; "$RUN" run "$MF_AB" "$RD_AB" || rc=$?
assert_eq "run-abstain-exit0" "0" "$rc"
assert_eq "run-abstain-status" "abstained" "$(jq -r .terminal_status "$RD_AB/summary.json")"
assert_eq "run-abstain-no-retry" "1" "$(wc -l < "$LOG_AB" | tr -d ' ')"

# =====================================================================
# F. Parse failure -> abstention/failure, never inferred choice, no retry.
# =====================================================================
ADP_BK="$W/adp-bk"; LOG_BK="$W/log-bk"; make_adapter "$ADP_BK" "$LOG_BK" badkey
MF_BK="$W/mf-bk.json"; make_manifest "$MF_BK" "$ADP_BK" "$(sha256 "$ADP_BK")" wu-bk sess-bk primary "A/B"
RD_BK="$W/run-bk"; rc=0; "$RUN" run "$MF_BK" "$RD_BK" || rc=$?
assert_eq "run-parsefail-exit2" "2" "$rc"
assert_eq "run-parsefail-status" "failed-parse" "$(jq -r .terminal_status "$RD_BK/summary.json")"
assert_eq "run-parsefail-no-decision" "null" "$(jq -r .decision "$RD_BK/summary.json")"
assert_eq "run-parsefail-no-retry" "1" "$(wc -l < "$LOG_BK" | tr -d ' ')"
[ ! -e "$RD_BK/pairwise-wu-bk.json" ] && pass "run-parsefail-no-inferred-choice" || fail "run-parsefail-no-inferred-choice" "record emitted"

# =====================================================================
# G. Timeout -> infra -> one retry -> retry exhaustion -> failed-infra.
# =====================================================================
ADP_TO="$W/adp-to"; LOG_TO="$W/log-to"; make_adapter "$ADP_TO" "$LOG_TO" timeout
MF_TO="$W/mf-to.json"; make_manifest "$MF_TO" "$ADP_TO" "$(sha256 "$ADP_TO")" wu-to sess-to primary "A/B" 1
RD_TO="$W/run-to"; rc=0; "$RUN" run "$MF_TO" "$RD_TO" || rc=$?
assert_eq "run-timeout-exit1" "1" "$rc"
assert_eq "run-timeout-status" "failed-infra" "$(jq -r .terminal_status "$RD_TO/summary.json")"
assert_eq "run-timeout-retry-used" "true" "$(jq -r .retry_used "$RD_TO/summary.json")"
assert_eq "run-timeout-two-attempts" "2" "$(jq -r .attempts "$RD_TO/summary.json")"
assert_eq "run-timeout-invoked-twice" "2" "$(wc -l < "$LOG_TO" | tr -d ' ')"

# =====================================================================
# H. Flaky infra then vote -> retry succeeds, no retry after the vote.
# =====================================================================
ADP_FL="$W/adp-fl"; LOG_FL="$W/log-fl"; make_adapter "$ADP_FL" "$LOG_FL" flaky
MF_FL="$W/mf-fl.json"; make_manifest "$MF_FL" "$ADP_FL" "$(sha256 "$ADP_FL")" wu-fl sess-fl primary "A/B"
RD_FL="$W/run-fl"; rc=0; "$RUN" run "$MF_FL" "$RD_FL" || rc=$?
assert_eq "run-flaky-exit0" "0" "$rc"
assert_eq "run-flaky-status" "voted" "$(jq -r .terminal_status "$RD_FL/summary.json")"
assert_eq "run-flaky-retry-used" "true" "$(jq -r .retry_used "$RD_FL/summary.json")"
assert_eq "run-flaky-two-attempts" "2" "$(jq -r .attempts "$RD_FL/summary.json")"

# =====================================================================
# I. Adapter unavailable / fingerprint mismatch -> infra, never fabricated.
# =====================================================================
MF_HM="$W/mf-hm.json"; ADP_HM="$W/adp-hm"; LOG_HM="$W/log-hm"; make_adapter "$ADP_HM" "$LOG_HM" vote
make_manifest "$MF_HM" "$ADP_HM" "$(printf deadbeef | shasum -a 256 | awk '{print $1}')" wu-hm sess-hm primary "A/B" 1
RD_HM="$W/run-hm"; rc=0; "$RUN" run "$MF_HM" "$RD_HM" || rc=$?
assert_eq "run-hashmismatch-exit1" "1" "$rc"
assert_eq "run-hashmismatch-status" "failed-infra" "$(jq -r .terminal_status "$RD_HM/summary.json")"
# Fingerprint mismatch => the declared adapter is never invoked (its own call log
# stays empty) and no response is fabricated.
assert_eq "run-hashmismatch-never-invoked" "0" "$(wc -l < "$LOG_HM" | tr -d ' ')"
[ ! -s "$RD_HM/attempts/1/response.json" ] && pass "run-hashmismatch-no-fabrication" || fail "run-hashmismatch-no-fabrication" "response fabricated on fingerprint mismatch"

MF_MISS="$W/mf-miss.json"; make_manifest "$MF_MISS" "$W/nope-adapter" "$(printf x | shasum -a 256 | awk '{print $1}')" wu-miss sess-miss primary "A/B" 1
RD_MISS="$W/run-miss"; rc=0; "$RUN" run "$MF_MISS" "$RD_MISS" || rc=$?
assert_eq "run-missing-adapter-infra" "failed-infra" "$(jq -r .terminal_status "$RD_MISS/summary.json")"

# =====================================================================
# J. Duplicate worker / idempotent resume — re-run is a no-op.
# =====================================================================
before_calls=$(wc -l < "$LOG" | tr -d ' ')
before_sum=$(cat "$RD/summary.json")
rc=0; "$RUN" run "$MF" "$RD" || rc=$?
assert_eq "run-resume-exit0" "0" "$rc"
assert_eq "run-resume-no-new-call" "$before_calls" "$(wc -l < "$LOG" | tr -d ' ')"
assert_eq "run-resume-attempts-stable" "1" "$(jq -r .attempts "$RD/summary.json")"
assert_eq "run-resume-summary-identical" "$before_sum" "$(cat "$RD/summary.json")"

# =====================================================================
# K. Partial completion — response captured but state not finalized.
#     Resume finalizes from the receipt without re-invoking the adapter.
# =====================================================================
RD_PC="$W/run-pc"; mkdir -p "$RD_PC/attempts/1"
LOG_PC="$W/log-pc"; ADP_PC="$W/adp-pc"; make_adapter "$ADP_PC" "$LOG_PC" vote
MF_PC="$W/mf-pc.json"; make_manifest "$MF_PC" "$ADP_PC" "$(sha256 "$ADP_PC")" wu-pc sess-pc primary "A/B"
valid_response "$RD_PC/attempts/1/response.json" wu-pc A
MSHA=$(sha256 "$MF_PC")
# simulate a crash after capture: request + state=running, no summary
jq -n --arg wu wu-pc '{work_unit_id:$wu}' > "$RD_PC/attempts/1/request.json"
jq -n --arg fp "$(sha256 "$ADP_PC")" --arg rs "$(sha256 "$RD_PC/attempts/1/response.json")" \
  '{schema_version:"taste-judge-capture/v1",attempt:1,adapter_fingerprint:$fp,exit_code:0,timed_out:false,response_sha256:$rs,response_bytes:1,started_at:"2026-08-12T00:00:00Z",ended_at:"2026-08-12T00:00:00Z"}' > "$RD_PC/attempts/1/capture.json"
jq -n --arg wu wu-pc --arg s sess-pc --arg m "$MSHA" \
  '{schema_version:"taste-judge-run-state/v1",work_unit_id:$wu,session_id:$s,manifest_sha256:$m,status:"running",attempts:1,retry_used:false,exit_code:null,started_at:"2026-08-12T00:00:00Z",updated_at:"2026-08-12T00:00:00Z"}' > "$RD_PC/state.json"
: > "$RD_PC/events.jsonl"
rc=0; "$RUN" run "$MF_PC" "$RD_PC" || rc=$?
assert_eq "run-partial-finalizes-exit0" "0" "$rc"
assert_eq "run-partial-status-voted" "voted" "$(jq -r .terminal_status "$RD_PC/summary.json")"
assert_eq "run-partial-no-reinvoke" "0" "$(wc -l < "$LOG_PC" | tr -d ' ')"

# =====================================================================
# L. Crash/resume — corrupt state.json, atomic backup restores.
# =====================================================================
RD_CR="$W/run-cr"; LOG_CR="$W/log-cr"; ADP_CR="$W/adp-cr"; make_adapter "$ADP_CR" "$LOG_CR" vote
MF_CR="$W/mf-cr.json"; make_manifest "$MF_CR" "$ADP_CR" "$(sha256 "$ADP_CR")" wu-cr sess-cr primary "A/B"
"$RUN" run "$MF_CR" "$RD_CR" >/dev/null 2>&1
cp "$RD_CR/state.json" "$RD_CR/state.json.bak"
printf '{ this is corrupt\n' > "$RD_CR/state.json"
calls_before=$(wc -l < "$LOG_CR" | tr -d ' ')
rc=0; "$RUN" run "$MF_CR" "$RD_CR" || rc=$?
assert_eq "run-crash-recovers-exit0" "0" "$rc"
assert_eq "run-crash-recovers-status" "voted" "$(jq -r .terminal_status "$RD_CR/summary.json")"
assert_eq "run-crash-no-reinvoke" "$calls_before" "$(wc -l < "$LOG_CR" | tr -d ' ')"

# =====================================================================
# M. Alias / isolation — a foreign session or work-unit on a claimed dir refuses.
# =====================================================================
MF_ALIAS="$W/mf-alias.json"; make_manifest "$MF_ALIAS" "$ADP" "$(sha256 "$ADP")" wu-alpha sess-INTRUDER primary "A/B"
assert_rc "run-alias-session-refused" "3" "$RUN" run "$MF_ALIAS" "$RD"
MF_FOREIGN="$W/mf-foreign.json"; make_manifest "$MF_FOREIGN" "$ADP" "$(sha256 "$ADP")" wu-OTHER sess-primary primary "A/B"
assert_rc "run-alias-workunit-refused" "3" "$RUN" run "$MF_FOREIGN" "$RD"
# the refused run leaves the incumbent terminal state untouched
assert_eq "run-alias-incumbent-intact" "voted" "$(jq -r .terminal_status "$RD/summary.json")"

# =====================================================================
# N. Changed orientation — immutable work unit; a mutated manifest refuses.
# =====================================================================
MF_ORI="$W/mf-ori.json"; make_manifest "$MF_ORI" "$ADP" "$(sha256 "$ADP")" wu-alpha sess-primary primary "B/A"
assert_rc "run-changed-orientation-refused" "3" "$RUN" run "$MF_ORI" "$RD"

# =====================================================================
# O. Stale response — a foreign-echo response in the attempt dir fails closed.
# =====================================================================
RD_ST="$W/run-st"; mkdir -p "$RD_ST/attempts/1"; LOG_ST="$W/log-st"; ADP_ST="$W/adp-st"; make_adapter "$ADP_ST" "$LOG_ST" vote
MF_ST="$W/mf-st.json"; make_manifest "$MF_ST" "$ADP_ST" "$(sha256 "$ADP_ST")" wu-st sess-st primary "A/B"
valid_response "$RD_ST/attempts/1/response.json" wu-STALEFORGERY A
jq -n --arg fp "$(sha256 "$ADP_ST")" --arg rs "$(sha256 "$RD_ST/attempts/1/response.json")" \
  '{schema_version:"taste-judge-capture/v1",attempt:1,adapter_fingerprint:$fp,exit_code:0,timed_out:false,response_sha256:$rs,response_bytes:1,started_at:"2026-08-12T00:00:00Z",ended_at:"2026-08-12T00:00:00Z"}' > "$RD_ST/attempts/1/capture.json"
jq -n --arg wu wu-st --arg s sess-st --arg m "$(sha256 "$MF_ST")" \
  '{schema_version:"taste-judge-run-state/v1",work_unit_id:$wu,session_id:$s,manifest_sha256:$m,status:"running",attempts:1,retry_used:false,exit_code:null,started_at:"2026-08-12T00:00:00Z",updated_at:"2026-08-12T00:00:00Z"}' > "$RD_ST/state.json"
: > "$RD_ST/events.jsonl"
rc=0; "$RUN" run "$MF_ST" "$RD_ST" || rc=$?
assert_eq "run-stale-response-failed-parse" "2" "$rc"
assert_eq "run-stale-status" "failed-parse" "$(jq -r .terminal_status "$RD_ST/summary.json")"

# =====================================================================
# P. Manifest validation — malformed work units are rejected before execution.
# =====================================================================
assert_fail "run-rejects-missing-manifest" "$RUN" run "$W/nope.json" "$W/run-nope"
jq '.deadline_s=999' "$MF" > "$W/mf-baddeadline.json"
assert_fail "run-rejects-deadline-range" "$RUN" run "$W/mf-baddeadline.json" "$W/run-bd"
jq '.display_order="sideways"' "$MF" > "$W/mf-badorder.json"
assert_fail "run-rejects-bad-order" "$RUN" run "$W/mf-badorder.json" "$W/run-bo"
jq '.candidate_ids=["stim-a1b2c3d4e5f6","stim-a1b2c3d4e5f6"]' "$MF" > "$W/mf-dupcand.json"
assert_fail "run-rejects-dup-candidates" "$RUN" run "$W/mf-dupcand.json" "$W/run-dc"

finish
