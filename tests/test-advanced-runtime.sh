#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ADVANCED="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-advanced.sh"
. "$RUNNER"
make_tmpdir
M="$TEST_TMPDIR/manifest.json"
cat > "$M" <<'JSON'
{"base":"main","lanes":[{"name":"alpha","model":"gpt","own_globs":["src/**"]},{"name":"beta","model":"gpt","own_globs":["lib/**"]},{"name":"gamma","model":"gpt","own_globs":["docs/**"]}]}
JSON
OUT="$TEST_TMPDIR/outcomes.jsonl"
POLYLANE_OUTCOMES="$OUT" assert_ok "advanced-preflight-risk-admitted" "$ADVANCED" preflight "$M"
MANIFEST="$M"; SCRIPT_DIR="$(dirname "$ADVANCED")"
POLYLANE_OUTCOMES="$OUT" assert_ok "runner-calls-advanced-preflight-adapter" advanced_runtime preflight
preflight=$(POLYLANE_OUTCOMES="$OUT" "$ADVANCED" preflight "$M")
assert_contains "advanced-preflight-selection-not-requested" "selection=not-requested" "$preflight"
assert_contains "advanced-preflight-salvage-not-requested" "salvage=not-requested" "$preflight"
POLYLANE_OUTCOMES="$OUT" assert_ok "advanced-records-every-lane" "$ADVANCED" record "$M" GO
assert_eq "advanced-record-count" "3" "$(jq -s 'length' "$OUT")"

jq '.champion_candidates=["a|/no-score|1"]' "$M" > "$TEST_TMPDIR/select.json"
select_out=$("$ADVANCED" select "$TEST_TMPDIR/select.json")
assert_contains "advanced-select-explicit-config" "selection=" "$select_out"
salvage_out=$("$ADVANCED" salvage "$M")
assert_contains "advanced-salvage-not-requested" "salvage=not-requested" "$salvage_out"

SEAM_TREE="$TEST_TMPDIR/seam-tree"; mkdir -p "$SEAM_TREE"
printf '%s\n' '<button id="save">Save</button>' > "$SEAM_TREE/index.html"
printf '%s\n' "document.getElementById('save')" > "$SEAM_TREE/app.js"
assert_contains "advanced-seams-passed" "seams=passed" "$("$ADVANCED" seams "$M" "$SEAM_TREE" "$TEST_TMPDIR/seams.md")"
printf '%s\n' "document.getElementById('missing')" >> "$SEAM_TREE/app.js"
assert_fail "advanced-seams-block-dangling" "$ADVANCED" seams "$M" "$SEAM_TREE" "$TEST_TMPDIR/seams.md"
assert_contains "advanced-seams-actionable-evidence" "SEAM-DANGLING: dom-id missing" "$(cat "$TEST_TMPDIR/seams.md")"

BASE_PROMPT="$TEST_TMPDIR/integrator.txt"
printf '%s\n' 'GOAL: repair only evidenced failures.' > "$BASE_PROMPT"
judge_prompt=$(build_judge_repair_prompt "$BASE_PROMPT" 1 \
  'docs/polylane/judges/judges.json' 'docs/verify-integration-judge-attempt-1.md')
assert_contains "judge-repair-prompt-is-typed" "JUDGE-REPAIR: attempt=1 max=1" "$judge_prompt"
assert_contains "judge-repair-prompt-points-aggregate" "docs/polylane/judges/judges.json" "$judge_prompt"
assert_contains "judge-repair-prompt-preserves-prior-verdict" "docs/verify-integration-judge-attempt-1.md" "$judge_prompt"

FAKE_RUNTIME="$TEST_TMPDIR/runtime-bin"; mkdir -p "$FAKE_RUNTIME"
JUDGE_RUNS="$TEST_TMPDIR/judge-runs"; REPAIR_CALL="$TEST_TMPDIR/repair-call"
export JUDGE_RUNS REPAIR_CALL
cat > "$FAKE_RUNTIME/polylane-judges.sh" <<'EOF'
#!/usr/bin/env bash
printf x >> "$JUDGE_RUNS"
exit 1
EOF
chmod +x "$FAKE_RUNTIME/polylane-judges.sh"
SCRIPT_DIR="$FAKE_RUNTIME"; MANIFEST="$M"; INT_WORKTREE="$TREE"; INT_NAME=integrator
graph_authority_record_ready_node() { :; }
graph_authority_require() { :; }
repair_integrator_verdict() { printf '%s %s\n' "$1" "${2:-}" > "$REPAIR_CALL"; }
poll_done() { :; }
merge_gate() { :; }
assert_fail "judge-gate-stops-after-one-repair" quality_judge_gate
assert_eq "judge-gate-routes-typed-repair" "1 judge" "$(cat "$REPAIR_CALL")"
assert_eq "judge-gate-runs-exactly-twice" "2" "$(wc -c < "$JUDGE_RUNS" | tr -d ' ')"
finish
