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
dies "{\"base\":\"main\",$INT,\"lanes\":[{\"name\":\"a\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/a\",\"worktree\":\"/tmp/a\",\"prompt_file\":\"p\",\"own_globs\":[\"x\"]},{\"name\":\"a\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/b\",\"worktree\":\"/tmp/b\",\"prompt_file\":\"p\",\"own_globs\":[\"y\"]}]}" "duplicate lane name" "dup-name"
dies "{\"base\":\"main\",$INT,\"lanes\":[{\"name\":\"a; touch /tmp/x\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/a\",\"worktree\":\"/tmp/a\",\"prompt_file\":\"p\",\"own_globs\":[\"x\"]}]}" "unsafe chars" "unsafe-name"

# a WELL-FORMED manifest still dry-runs clean (rc 0) — validation isn't over-eager
GOOD="{\"base\":\"main\",$INT,\"lanes\":[{\"name\":\"a\",\"model\":\"m\",\"effort\":\"h\",\"branch\":\"lane/a\",\"worktree\":\"/tmp/a\",\"prompt_file\":\"p\",\"own_globs\":[\"x\"]}]}"
printf '%s' "$GOOD" > "$TEST_TMPDIR/good.json"
POLYLANE_MIN_DISK_GB=0 POLYLANE_SESSION=vtest "$RUN" "$TEST_TMPDIR/good.json" --dry-run >/dev/null 2>&1
assert_eq "good-manifest-rc0" "0" "$?"

finish
