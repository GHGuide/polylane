#!/usr/bin/env bash
# Skill delivery is a typed, preflight-validated path contract, never a name list.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

SCOUT="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-scout.sh"
CATALOG="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-skill-catalog.sh"
PROMPTOPT="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-promptopt.sh"
BENCHMARK="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-skill-benchmark.sh"

make_tmpdir
ROOT="$TEST_TMPDIR/trusted-skills"
OUTSIDE="$TEST_TMPDIR/outside"
KIT="$TEST_TMPDIR/lane-skills.json"
MANIFEST="$TEST_TMPDIR/run.json"
VERIFY="$TEST_TMPDIR/verify.md"
LEDGER="$TEST_TMPDIR/outcomes.jsonl"
PROMPT="$TEST_TMPDIR/prompt.txt"
COMPILED="$TEST_TMPDIR/compiled.txt"
mkdir -p "$ROOT/superpowers/test-driven-development" "$ROOT/ui/visual-regression" "$OUTSIDE"
cat > "$ROOT/superpowers/test-driven-development/SKILL.md" <<'EOF'
---
name: test-driven-development
description: behavior-first tests
---
EOF
cat > "$ROOT/ui/visual-regression/SKILL.md" <<'EOF'
---
name: visual-regression
description: browser state comparison
---
EOF
printf '%s\n' 'outside trusted roots' > "$OUTSIDE/SKILL.md"
printf '%s\n' '{"lanes":[{"name":"builder"}]}' > "$MANIFEST"

LEGACY="$TEST_TMPDIR/legacy-v2.json"
printf '%s\n' '{"version":2,"lanes":{"builder":{"predefined":["superpowers:test-driven-development"],"specific":["ui:visual-regression"],"github_suggestions":[]}}}' > "$LEGACY"
assert_ok "delivery-migrates-v2-before-preflight" env POLYLANE_SKILLS_DIRS="$ROOT" "$SCOUT" validate "$LEGACY" "$MANIFEST"
assert_eq "delivery-migration-writes-v3" "3" "$(jq -r .version "$LEGACY")"
assert_eq "delivery-migration-resolves-v2-path" "ui:visual-regression" "$(jq -r '.lanes.builder.selected.specific[0].id' "$LEGACY")"

assert_ok "delivery-arms-trusted-predefined-record" env POLYLANE_SKILLS_DIRS="$ROOT" "$SCOUT" arm-role "$KIT" builder predefined superpowers:test-driven-development
REC_PATH="$ROOT/ui/visual-regression/SKILL.md"
REC_FP="$(cksum "$REC_PATH" | awk '{print $1 "-" $2}')"
RECOMMEND="$TEST_TMPDIR/recommendation.json"
BENCH_LEDGER="$TEST_TMPDIR/benchmark.jsonl"
make_recommendation() {
  local fingerprint="$1"
  jq -cn --arg path "$REC_PATH" --arg fingerprint "$fingerprint" '{candidates:[{id:"ui:visual-regression",path:$path,source:"trusted-root",fingerprint:$fingerprint,domain:"ui",lane_shape:"builder",status:"recommended",safe_to_apply:true,reason:"activities:capture screenshots — capability: browser state comparison"}]}' > "$RECOMMEND"
}
record_receipt() {
  local receipt="$TEST_TMPDIR/receipt-$1.json"
  jq -cn --arg receipt_id "delivery-$1" --arg fingerprint "$REC_FP" '{schema:"polylane-skill-benchmark/v1",receipt_id:$receipt_id,lane_shape:"builder",domain:"ui",acceptance_status:"accepted",verdict:"GO",skill:{id:"ui:visual-regression",fingerprint:$fingerprint},quality_adjusted_delta:1,hard_checks:true,hurt:false,synthetic:true,synthetic_label:"deterministic delivery fixture"}' > "$receipt"
  assert_ok "delivery-records-benchmark-receipt-$1" "$BENCHMARK" record "$BENCH_LEDGER" "$receipt"
}
make_recommendation "$REC_FP"
record_receipt 1
record_receipt 2
assert_fail "delivery-rejects-thin-benchmark-evidence" env POLYLANE_SKILLS_DIRS="$ROOT" POLYLANE_SKILL_BENCHMARK_LEDGER="$BENCH_LEDGER" "$SCOUT" arm-recommendation "$KIT" builder specific "$RECOMMEND" ui:visual-regression
record_receipt 3
assert_ok "delivery-arms-recommended-typed-record" env POLYLANE_SKILLS_DIRS="$ROOT" POLYLANE_SKILL_BENCHMARK_LEDGER="$BENCH_LEDGER" "$SCOUT" arm-recommendation "$KIT" builder specific "$RECOMMEND" ui:visual-regression
assert_eq "delivery-stores-selected-schema" "3" "$(jq -r .version "$KIT")"
assert_eq "delivery-stores-selected-id" "ui:visual-regression" "$(jq -r '.lanes.builder.selected.specific[0].id' "$KIT")"
assert_eq "delivery-stores-selected-source" "trusted-root" "$(jq -r '.lanes.builder.selected.specific[0].source' "$KIT")"
assert_contains "delivery-carries-recommendation-reason" "activities:capture screenshots" "$(jq -r '.lanes.builder.selected.specific[0].reason' "$KIT")"
assert_ok "delivery-stores-immutable-fingerprint" jq -e '.lanes.builder.selected.specific[0].fingerprint | test("^[0-9]+-[0-9]+$")' "$KIT"
assert_ok "delivery-validates-typed-records" env POLYLANE_SKILLS_DIRS="$ROOT" "$SCOUT" validate "$KIT" "$MANIFEST"

printf '%s\n' 'fingerprint changed after benchmark receipts' >> "$REC_PATH"
REC_FP="$(cksum "$REC_PATH" | awk '{print $1 "-" $2}')"
make_recommendation "$REC_FP"
assert_fail "delivery-rejects-stale-benchmark-evidence" env POLYLANE_SKILLS_DIRS="$ROOT" POLYLANE_SKILL_BENCHMARK_LEDGER="$BENCH_LEDGER" "$SCOUT" arm-recommendation "$KIT" builder specific "$RECOMMEND" ui:visual-regression

jq '(.lanes.builder.selected.specific[0].path) = "/missing/SKILL.md"' "$KIT" > "$KIT.bad" && mv "$KIT.bad" "$KIT"
assert_fail "delivery-rejects-missing-runtime-path" env POLYLANE_SKILLS_DIRS="$ROOT" "$SCOUT" validate "$KIT" "$MANIFEST"
assert_ok "delivery-restores-missing-fixture" env POLYLANE_SKILLS_DIRS="$ROOT" "$SCOUT" arm-role "$KIT" builder specific ui:visual-regression

mkdir -p "$ROOT/ui/unreadable"
printf '%s\n' 'unreadable fixture' > "$ROOT/ui/unreadable/SKILL.md"
chmod 000 "$ROOT/ui/unreadable/SKILL.md"
jq --arg path "$ROOT/ui/unreadable/SKILL.md" '(.lanes.builder.selected.specific[0].path) = $path' "$KIT" > "$KIT.bad" && mv "$KIT.bad" "$KIT"
assert_fail "delivery-rejects-unreadable-runtime-path" env POLYLANE_SKILLS_DIRS="$ROOT" "$SCOUT" validate "$KIT" "$MANIFEST"
chmod 644 "$ROOT/ui/unreadable/SKILL.md"
assert_ok "delivery-restores-unreadable-fixture" env POLYLANE_SKILLS_DIRS="$ROOT" "$SCOUT" arm-role "$KIT" builder specific ui:visual-regression

jq --arg path "$OUTSIDE/SKILL.md" '(.lanes.builder.selected.specific[0].path) = $path' "$KIT" > "$KIT.bad" && mv "$KIT.bad" "$KIT"
assert_fail "delivery-rejects-out-of-root-runtime-path" env POLYLANE_SKILLS_DIRS="$ROOT" "$SCOUT" validate "$KIT" "$MANIFEST"
assert_ok "delivery-restores-outside-fixture" env POLYLANE_SKILLS_DIRS="$ROOT" "$SCOUT" arm-role "$KIT" builder specific ui:visual-regression

cat > "$PROMPT" <<'EOF'
ULTIMATE-GOAL: Deliver a verified product from one vague idea.
CURRENT-SUBGOAL: Deliver trusted selected skills.
GOAL: Keep selected skill paths exact.
OWN: bin/polylane-scout.sh.
FORBIDDEN: runner policy.
PREDEFINED-SKILLS: superpowers:test-driven-development
LANE-SPECIFIC-SKILLS: ui:visual-regression
Read only the named kit once from its resolved SKILL.md paths and use it.
SELECTED-SKILL: duplicated stale record
SELECTED-SKILL: duplicated stale record
TEST-CADENCE: focused tests first.
DELEGATION: forbidden.
CHECK-CACHE: use bin/polylane-check.sh "$PWD/.polylane/check-cache/skill-delivery" -- <command>.
EXTERNAL-EVIDENCE: external comparisons remain external.
VERIFY: STATUS: skill-delivery DONE run=fixture.
EOF
assert_ok "delivery-compiles-selected-paths" env POLYLANE_SKILLS_DIRS="$ROOT" "$PROMPTOPT" compile-selected "$PROMPT" "$KIT" builder "$COMPILED"
assert_eq "delivery-emits-each-selected-record-once" "2" "$(grep -c '^SELECTED-SKILL:' "$COMPILED")"
assert_eq "delivery-removes-duplicate-prompt-record" "0" "$(grep -c 'duplicated stale record' "$COMPILED" || true)"
assert_contains "delivery-instructs-exact-file-reads" "Read only these exact selected SKILL.md files; do not rediscover or inventory skills." "$(cat "$COMPILED")"

printf '%s\n' 'SKILL-EVIDENCE: ui:visual-regression — helped: fake receipt without a read.' > "$VERIFY"
AUDIT="$TEST_TMPDIR/audit.json"
assert_ok "delivery-audits-fake-receipt" bash -c '"$1" use-audit "$2" "$3" "$4" "$5" "$6" > "$7"' _ "$CATALOG" "$KIT" builder "$VERIFY" ui "$LEDGER" "$AUDIT"
assert_eq "delivery-fake-receipt-is-unused" "ui:visual-regression" "$(jq -r '.unused[]' "$AUDIT" | tail -1)"
assert_contains "delivery-fake-receipt-explains-missing-read" "missing matching SKILL-READ evidence" "$(jq -r 'select(.skill == "ui:visual-regression") | .why' "$LEDGER" | tail -1)"

SPEC_PATH="$(jq -r '.lanes.builder.selected.specific[0].path' "$KIT")"
SPEC_FP="$(jq -r '.lanes.builder.selected.specific[0].fingerprint' "$KIT")"
printf 'SKILL-READ: ui:visual-regression | %s | %s\nSKILL-EVIDENCE: ui:visual-regression — helped: comparison fixture changed the test decision.\n' "$SPEC_PATH" "$SPEC_FP" > "$VERIFY"
assert_ok "delivery-audits-observable-read-and-effect" bash -c '"$1" use-audit "$2" "$3" "$4" "$5" "$6" > "$7"' _ "$CATALOG" "$KIT" builder "$VERIFY" ui "$LEDGER" "$AUDIT"
assert_eq "delivery-observable-read-can-help" "ui:visual-regression" "$(jq -r '.helped[0].id' "$AUDIT")"

finish
