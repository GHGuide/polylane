#!/usr/bin/env bash
# validate_manifest — fail LOUD (rc 2) on a malformed plan BEFORE any git/tmux side
# effect. jq -r maps a missing key to the literal "null", so an under-specified lane
# would otherwise `git worktree add null`; a 0-lane plan would poll forever; a
# duplicate/unsafe name would collide status files or inject into shell commands.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

if ! command -v jq >/dev/null 2>&1; then pass "manifest-skipped-no-jq"; finish; exit 0; fi

RUN="$RUNNER"
make_tmpdir
INT='"integrator":{"name":"i","model":"m","effort":"x","branch":"lane/i","worktree":"/tmp/i","prompt_file":"p"}'

# writes $1 as manifest, dry-runs, asserts it dies rc 2 with $2 in stderr
dies() {
  local json="$1" want="$2" name="$3" f="$TEST_TMPDIR/m.json" out rc
  printf '%s' "$json" > "$f"
  out=$(POLYLANE_MIN_DISK_GB=0 POLYLANE_SESSION=vtest "$RUN" "$f" --dry-run 2>&1); rc=$?
  assert_eq "$name-rc2" "2" "$rc"
  assert_contains "$name-msg" "$want" "$out"
}

dies "{\"base\":\"main\",$INT,\"lanes\":[]}" "no lanes" "empty-lanes"
dies "{\"base\":\"main\",$INT,\"lanes\":[{\"name\":\"a\"}]}" "missing a required field" "null-fields"
dies "{\"base\":\"main\",$INT,\"lanes\":[{\"name\":\"a\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/a\",\"prompt_file\":\"p\",\"own_globs\":[\"x\"]}]}" "missing a required field" "missing-lane-worktree"
dies '{"base":"main","integrator":{"name":"i","model":"m","effort":"x","branch":"lane/i","prompt_file":"p"},"lanes":[{"name":"a","model":"m","effort":"h","branch":"lane/a","worktree":"/tmp/a","prompt_file":"p","own_globs":["x"]}]}' "is missing in the manifest" "missing-integrator-worktree"
dies "{\"base\":\"main\",$INT,\"lanes\":[{\"name\":\"a\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/a\",\"worktree\":\"/tmp/a\",\"prompt_file\":\"p\",\"own_globs\":[\"x\"]},{\"name\":\"a\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/b\",\"worktree\":\"/tmp/b\",\"prompt_file\":\"p\",\"own_globs\":[\"y\"]}]}" "duplicate lane name" "dup-name"
dies "{\"base\":\"main\",$INT,\"lanes\":[{\"name\":\"a; touch /tmp/x\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/a\",\"worktree\":\"/tmp/a\",\"prompt_file\":\"p\",\"own_globs\":[\"x\"]}]}" "unsafe chars" "unsafe-name"
dies "{\"base\":\"main\",\"session\":\"bad session;name\",$INT,\"lanes\":[{\"name\":\"a\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/a\",\"worktree\":\"/tmp/a\",\"prompt_file\":\"p\",\"own_globs\":[\"x\"]}]}" "session has unsafe chars" "unsafe-session"
dies "{\"base\":\"main\",\"agent\":\"codex\",\"codex_sandbox\":\"unconfined-ish\",$INT,\"lanes\":[{\"name\":\"a\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/a\",\"worktree\":\"/tmp/a\",\"prompt_file\":\"p\",\"own_globs\":[\"x\"]}]}" "invalid Codex sandbox" "unsafe-codex-sandbox"
dies "{\"base\":\"main\",\"write_plan_contract\":1,$INT,\"lanes\":[{\"name\":\"a\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/a\",\"worktree\":\"/tmp/a\",\"prompt_file\":\"p\",\"own_globs\":[\"x\"],\"planned_writes\":[\"/tmp/a\"]}]}" "planned-write contract failed" "unsafe-planned-write-before-side-effects"

# a WELL-FORMED manifest still dry-runs clean (rc 0) — validation isn't over-eager
GOOD="{\"base\":\"main\",$INT,\"lanes\":[{\"name\":\"a\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/a\",\"worktree\":\"/tmp/a\",\"prompt_file\":\"p\",\"own_globs\":[\"x\"]}]}"
printf '%s' "$GOOD" > "$TEST_TMPDIR/good.json"
POLYLANE_MIN_DISK_GB=0 POLYLANE_SESSION=vtest POLYLANE_AGENT_CMD=true \
  "$RUN" "$TEST_TMPDIR/good.json" --dry-run >/dev/null 2>&1
assert_eq "good-manifest-rc0" "0" "$?"

# Efficiency configuration is validated at the certificate helper boundary so a
# malformed focused contract cannot be coerced into a passing proof.
EFF="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-efficiency.sh"
EFF_STATS="$TEST_TMPDIR/eff-stats.json"
printf '%s\n' '{"run_id":"eff-config","wall_s":1,"lanes":{},"supervisor_restarts":0,"terminal_gates":1,"tokens":1,"token_state":"known","cleanup":"complete"}' > "$EFF_STATS"
efficiency_dies() {
  local value="$1" name="$2" manifest="$TEST_TMPDIR/eff-$2.json" out rc
  printf '{"run_id":"eff-config","lanes":[],"efficiency_canary":{"expected_terminal_gates":%s}}' "$value" > "$manifest"
  out=$("$EFF" capture --manifest "$manifest" --stats "$EFF_STATS" --proof "$TEST_TMPDIR/eff-$2-proof.md" --phase final 2>&1); rc=$?
  assert_eq "$name-rc2" "2" "$rc"
  assert_contains "$name-msg" "invalid expected_terminal_gates" "$out"
}

efficiency_dies '"0"' "expected-terminal-gates-string"
efficiency_dies '-1' "expected-terminal-gates-negative"
efficiency_dies '1.5' "expected-terminal-gates-fraction"
efficiency_dies 'true' "expected-terminal-gates-boolean"
efficiency_dies 'null' "expected-terminal-gates-null"

finish
