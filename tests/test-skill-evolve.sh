#!/usr/bin/env bash
# polylane-skill-evolve.sh — evidence-gated skill champion/challenger lifecycle.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVOLVE="$ROOT/bin/polylane-skill-evolve.sh"

make_tmpdir
ACTIVE="$TEST_TMPDIR/active-skill"
WS="$TEST_TMPDIR/evolution"
mkdir -p "$ACTIVE" "$TEST_TMPDIR/adapters"
printf '%s\n' '---' 'name: demo' 'description: Use when testing evolution.' '---' '' '# Demo' '' 'quality: 40' > "$ACTIVE/SKILL.md"

EVAL_ADAPTER="$TEST_TMPDIR/adapters/eval.sh"
cat > "$EVAL_ADAPTER" <<'EOF'
#!/usr/bin/env bash
set -eu
quality=$(sed -n 's/^quality: *//p' "$POLYLANE_SKILL_PATH/SKILL.md" | tail -1)
case_id=$(jq -r '.id' "$POLYLANE_SKILL_EVAL_CASE")
score=$(awk -v q="$quality" -v id="$case_id" 'BEGIN {
  if (id == "hidden-regression" && q == 65) print 0.20;
  else printf "%.2f\n", q / 100;
}')
tokens=$((200 - quality))
[ "${POLYLANE_TEST_TOKEN_REGRESSION:-0}" = 1 ] && [ "$POLYLANE_SKILL_EVAL_VARIANT" != champion ] && tokens=999
hard=false
[ "${POLYLANE_TEST_CANARY_FAIL:-0}" = 1 ] && [ "$POLYLANE_SKILL_EVAL_VARIANT" = canary ] && hard=true
jq -cn --argjson score "$score" --argjson hard "$hard" --argjson tokens "$tokens" \
  '{score:$score,hard_fail:$hard,tokens:$tokens,duration_ms:10,interventions:0}' \
  > "$POLYLANE_SKILL_EVAL_RESULT"
EOF
chmod +x "$EVAL_ADAPTER"

make_judge() {
  local name="$1" file
  file="$TEST_TMPDIR/adapters/judge-$name.sh"
  cat > "$file" <<'EOF'
#!/usr/bin/env bash
set -eu
qa=$(sed -n 's/^quality: *//p' "$POLYLANE_SKILL_BLIND_A_PATH/SKILL.md" | tail -1)
qb=$(sed -n 's/^quality: *//p' "$POLYLANE_SKILL_BLIND_B_PATH/SKILL.md" | tail -1)
winner=tie
[ "$qa" -gt "$qb" ] && winner=A
[ "$qb" -gt "$qa" ] && winner=B
jq -cn --arg winner "$winner" \
  '{winner:$winner,confidence:0.9,hard_fail:false,tokens:25,duration_ms:5}' \
  > "$POLYLANE_SKILL_JUDGE_RESULT"
EOF
  chmod +x "$file"
}
make_judge product
make_judge reliability
make_judge efficiency

EVALS="$TEST_TMPDIR/evals.json"
jq -n \
  --arg eval "$EVAL_ADAPTER" \
  --arg j1 "$TEST_TMPDIR/adapters/judge-product.sh" \
  --arg j2 "$TEST_TMPDIR/adapters/judge-reliability.sh" \
  --arg j3 "$TEST_TMPDIR/adapters/judge-efficiency.sh" \
  '{schema:"polylane-skill-evals/v1",skill_name:"demo",model:"gpt-test",effort:"high",
    thresholds:{min_dev_delta:0.05,min_hidden_delta:0.0,max_token_regression_pct:25,
      max_duration_regression_pct:25,max_intervention_regression:0,hurt_recurrence:2,unused_recurrence:3},
    cases:[
      {id:"train-basic",split:"train",weight:1,min_score:0.3,hard:true,repeats:1,timeout_s:2,adapter:$eval},
      {id:"dev-basic",split:"dev",weight:1,min_score:0.3,hard:true,repeats:1,timeout_s:2,adapter:$eval},
      {id:"hidden-regression",split:"hidden",weight:1,min_score:0.3,hard:true,repeats:1,timeout_s:2,adapter:$eval}],
    judges:[
      {name:"product",timeout_s:2,adapter:$j1},{name:"reliability",timeout_s:2,adapter:$j2},{name:"efficiency",timeout_s:2,adapter:$j3}]}' > "$EVALS"

assert_rc "evolve-bounds-external-evaluators" 124 bash -c '. "$1"; run_bounded 1 sleep 3' _ "$EVOLVE"
assert_ok "evolve-validates-frozen-corpus" "$EVOLVE" validate "$EVALS"
jq 'del(.cases[] | select(.split == "hidden"))' "$EVALS" > "$TEST_TMPDIR/no-hidden.json"
assert_fail "evolve-requires-hidden-promotion-case" "$EVOLVE" validate "$TEST_TMPDIR/no-hidden.json"
jq '.judges |= .[0:2]' "$EVALS" > "$TEST_TMPDIR/two-judges.json"
assert_fail "evolve-requires-three-blind-judges" "$EVOLVE" validate "$TEST_TMPDIR/two-judges.json"
jq 'del(.cases[0].timeout_s)' "$EVALS" > "$TEST_TMPDIR/unbounded.json"
assert_fail "evolve-rejects-unbounded-evaluator" "$EVOLVE" validate "$TEST_TMPDIR/unbounded.json"

OVERLAP_ACTIVE="$TEST_TMPDIR/overlap-active"
mkdir -p "$OVERLAP_ACTIVE"
cp "$ACTIVE/SKILL.md" "$OVERLAP_ACTIVE/SKILL.md"
assert_rc "evolve-rejects-workspace-inside-active-skill" 2 "$EVOLVE" init \
  "$OVERLAP_ACTIVE/docs/polylane/skill-evolution" "$OVERLAP_ACTIVE" "$EVALS"
assert_ok "evolve-overlap-refusal-writes-no-state" test '!' -e \
  "$OVERLAP_ACTIVE/docs/polylane/skill-evolution/state.json"

assert_ok "evolve-initializes-champion-snapshot" "$EVOLVE" init "$WS" "$ACTIVE" "$EVALS"
STATUS=$($EVOLVE status "$WS" --json)
assert_eq "evolve-generation-zero" "0" "$(printf '%s' "$STATUS" | jq -r '.generation')"
assert_eq "evolve-champion-is-active-content" \
  "$(git -C "$ROOT" hash-object "$ACTIVE/SKILL.md")" \
  "$(git -C "$ROOT" hash-object "$WS/versions/generation-0000/skill/SKILL.md")"

NO_EVIDENCE_WS="$TEST_TMPDIR/evolution-no-evidence"
assert_ok "evolve-initializes-observation-fixture" "$EVOLVE" init "$NO_EVIDENCE_WS" "$ACTIVE" "$EVALS"
assert_rc "evolve-observation-evidence-is-optional" 3 "$EVOLVE" observe \
  "$NO_EVIDENCE_WS" 1 demo helped "verified clean cycle"
assert_eq "evolve-optional-evidence-records-empty" "" \
  "$(jq -r '.evidence' "$NO_EVIDENCE_WS/observations.jsonl")"

# Frozen adapters cannot be changed after initialization to move the gate.
printf '%s\n' '#!/usr/bin/env bash' 'exit 99' > "$EVAL_ADAPTER"
chmod +x "$EVAL_ADAPTER"
assert_ok "evolve-copies-evaluation-adapters" test -x "$WS/evals/adapters/case-train-basic"

assert_rc "evolve-one-hurt-not-yet-eligible" 3 "$EVOLVE" observe "$WS" 1 demo hurt "ignored required verifier" docs/verify-1.md
assert_ok "evolve-recurrence-becomes-eligible" "$EVOLVE" observe "$WS" 2 demo hurt "repeated verifier omission" docs/verify-2.md
assert_eq "evolve-observation-deduplicates" "2" "$(wc -l < "$WS/observations.jsonl" | tr -d ' ')"
assert_ok "evolve-eligible-reports-skill" "$EVOLVE" eligible "$WS" demo
PACKET=$($EVOLVE packet "$WS" demo)
assert_contains "evolve-packet-names-champion" "generation-0000" "$PACKET"
if printf '%s' "$PACKET" | grep -qF 'hidden-regression'; then
  fail "evolve-packet-hides-promotion-cases" "hidden case leaked into mutation packet"
else
  pass "evolve-packet-hides-promotion-cases"
fi

BETTER="$TEST_TMPDIR/better"; mkdir -p "$BETTER"
sed 's/quality: 40/quality: 80/' "$ACTIVE/SKILL.md" > "$BETTER/SKILL.md"
assert_ok "evolve-stages-immutable-challenger" "$EVOLVE" stage "$WS" better "$BETTER" "tighten execution contract"
sed 's/quality: 80/quality: 1/' "$BETTER/SKILL.md" > "$BETTER/changed.md"
assert_ok "evolve-better-challenger-passes" "$EVOLVE" compare "$WS" better
assert_eq "evolve-better-verdict-go" "GO" "$(jq -r '.verdict' "$WS/candidates/better/verdict.json")"
assert_eq "evolve-three-judges-recorded" "3" "$(jq -r '.judges.total' "$WS/candidates/better/verdict.json")"

BEST="$TEST_TMPDIR/best"; mkdir -p "$BEST"
sed 's/quality: 40/quality: 85/' "$ACTIVE/SKILL.md" > "$BEST/SKILL.md"
assert_ok "evolve-stages-second-good-challenger" "$EVOLVE" stage "$WS" best "$BEST" "stronger candidate"
assert_ok "evolve-second-good-challenger-passes" "$EVOLVE" compare "$WS" best
assert_eq "evolve-selects-best-go-challenger" "best" "$($EVOLVE select "$WS" better best)"

REGRESS="$TEST_TMPDIR/regress"; mkdir -p "$REGRESS"
sed 's/quality: 40/quality: 20/' "$ACTIVE/SKILL.md" > "$REGRESS/SKILL.md"
assert_ok "evolve-stages-regressing-challenger" "$EVOLVE" stage "$WS" regress "$REGRESS" "bad mutation"
assert_rc "evolve-rejects-regressing-challenger" 5 "$EVOLVE" compare "$WS" regress
assert_rc "evolve-cannot-promote-no-go" 5 "$EVOLVE" promote "$WS" regress "$ACTIVE"

HIDDEN_BAD="$TEST_TMPDIR/hidden-bad"; mkdir -p "$HIDDEN_BAD"
sed 's/quality: 40/quality: 65/' "$ACTIVE/SKILL.md" > "$HIDDEN_BAD/SKILL.md"
assert_ok "evolve-stages-hidden-regression" "$EVOLVE" stage "$WS" hidden-bad "$HIDDEN_BAD" "overfit dev"
assert_rc "evolve-hidden-test-blocks-overfit" 5 "$EVOLVE" compare "$WS" hidden-bad

assert_ok "evolve-promotes-only-gated-challenger" "$EVOLVE" promote "$WS" best "$ACTIVE"
assert_eq "evolve-active-skill-updated" "85" "$(sed -n 's/^quality: *//p' "$ACTIVE/SKILL.md")"
assert_eq "evolve-generation-advanced" "1" "$($EVOLVE status "$WS" --json | jq -r '.generation')"
assert_eq "evolve-history-recorded" "promote" "$(tail -1 "$WS/history.jsonl" | jq -r '.event')"

# Compare must fail closed on spend regression even when output quality improves.
MORE="$TEST_TMPDIR/more"; mkdir -p "$MORE"
sed 's/quality: 85/quality: 90/' "$ACTIVE/SKILL.md" > "$MORE/SKILL.md"
assert_ok "evolve-stages-expensive-challenger" "$EVOLVE" stage "$WS" expensive "$MORE" "more capable but wasteful"
POLYLANE_TEST_TOKEN_REGRESSION=1 assert_rc "evolve-token-regression-blocks-promotion" 5 "$EVOLVE" compare "$WS" expensive

# Compare-and-swap protects user/concurrent edits to the installed skill.
DRIFT="$TEST_TMPDIR/drift"; mkdir -p "$DRIFT"
sed 's/quality: 85/quality: 90/' "$ACTIVE/SKILL.md" > "$DRIFT/SKILL.md"
assert_ok "evolve-stages-drift-candidate" "$EVOLVE" stage "$WS" drift "$DRIFT" "cas fixture"
assert_ok "evolve-drift-candidate-passes" "$EVOLVE" compare "$WS" drift
printf '\nmanual-user-edit\n' >> "$ACTIVE/SKILL.md"
assert_rc "evolve-refuses-concurrent-active-drift" 6 "$EVOLVE" promote "$WS" drift "$ACTIVE"
cp "$WS/versions/generation-0001/skill/SKILL.md" "$ACTIVE/SKILL.md"

# A failing post-promotion canary rolls back to the previous immutable champion.
POLYLANE_TEST_CANARY_FAIL=1 assert_rc "evolve-canary-failure-rolls-back" 7 "$EVOLVE" canary "$WS" "$ACTIVE"
assert_eq "evolve-rollback-restores-previous-skill" "40" "$(sed -n 's/^quality: *//p' "$ACTIVE/SKILL.md")"
assert_eq "evolve-rollback-restores-generation" "0" "$($EVOLVE status "$WS" --json | jq -r '.generation')"
assert_eq "evolve-rollback-recorded" "rollback" "$(tail -1 "$WS/history.jsonl" | jq -r '.event')"

finish
