#!/usr/bin/env bash
# polylane-doctor.sh — preflight diagnostics CLI. It RUNS on invocation (its main
# is guarded by BASH_SOURCE), so we exercise it as a CLI: invoke it, then assert
# its rendered table + exit code. We never source it.
#
# Frozen contract under test:
#   exit 0 = no FAIL row (WARNs allowed) · exit 1 = any FAIL row.
# Checks covered here: deps, manifest validity, disk, tmux-collision, plus the
# PASS/WARN/FAIL table lines and the usage/option surface.
#
# Environment-dependent checks (jq-gated manifest parsing, tmux session probing)
# are guarded with a skip-pass, same shape as test-memory.sh, so the file stays
# green on hosts missing those tools.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
DOCTOR="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-doctor.sh"

make_tmpdir

# --- fixtures (built regardless of jq; only doctor's PARSE needs jq) -----------
# Absolute prompt_file/worktree paths so we don't depend on the manifest's
# project_root resolution. worktrees point at NON-existent dirs => no collision.
BR="lane/doctest-unlikely-$$"
mkdir -p "$TEST_TMPDIR/best"
printf 'lane A prompt\n'     > "$TEST_TMPDIR/best/pA.md"
printf 'integrator prompt\n' > "$TEST_TMPDIR/best/pI.md"
GOOD="$TEST_TMPDIR/best/run.json"
cat > "$GOOD" <<EOF
{"lanes":[{"name":"laneA","prompt_file":"$TEST_TMPDIR/best/pA.md","worktree":"$TEST_TMPDIR/best/wtA","branch":"$BR"}],"integrator":{"name":"integrator","prompt_file":"$TEST_TMPDIR/best/pI.md","worktree":"$TEST_TMPDIR/best/wtI"}}
EOF

# invalid JSON
BADJSON="$TEST_TMPDIR/bad.json"
printf '{ not json\n' > "$BADJSON"

# valid JSON but a lane prompt_file that does not exist
BADPF="$TEST_TMPDIR/badpf.json"
cat > "$BADPF" <<EOF
{"lanes":[{"name":"laneA","prompt_file":"$TEST_TMPDIR/nope/missing.md","worktree":"$TEST_TMPDIR/best/wtA"}],"integrator":{"name":"integrator","prompt_file":"$TEST_TMPDIR/best/pI.md","worktree":"$TEST_TMPDIR/best/wtI"}}
EOF

# valid JSON but an insane worktree path ("/")
INSANE="$TEST_TMPDIR/insane.json"
cat > "$INSANE" <<EOF
{"lanes":[{"name":"laneA","prompt_file":"$TEST_TMPDIR/best/pA.md","worktree":"/"}],"integrator":{"name":"integrator","prompt_file":"$TEST_TMPDIR/best/pI.md","worktree":"$TEST_TMPDIR/best/wtI"}}
EOF

# valid JSON but a lane worktree that DOES exist -> collision WARN (not a FAIL)
mkdir -p "$TEST_TMPDIR/warn/existing"
WARNM="$TEST_TMPDIR/warn/run.json"
cat > "$WARNM" <<EOF
{"lanes":[{"name":"laneA","prompt_file":"$TEST_TMPDIR/best/pA.md","worktree":"$TEST_TMPDIR/warn/existing","branch":"$BR"}],"integrator":{"name":"integrator","prompt_file":"$TEST_TMPDIR/best/pI.md","worktree":"$TEST_TMPDIR/best/wtI"}}
EOF

UNIQ="pl-doctest-none-$$"   # a tmux session name that cannot collide

# =============================================================================
# usage / option surface (fully deterministic, no environment coupling)
# =============================================================================
help_out=$("$DOCTOR" --help 2>&1)
assert_rc       "help-exit0"        0 "$DOCTOR" --help
assert_contains "help-shows-usage"  "USAGE:" "$help_out"

badopt_out=$("$DOCTOR" --bogus 2>&1)
assert_rc       "unknown-opt-exit1"  1 "$DOCTOR" --bogus
assert_contains "unknown-opt-msg"    "unknown option" "$badopt_out"

# =============================================================================
# an explicitly-passed manifest that is absent is a FAIL -> exit 1 (any-fail).
# This needs no jq: doctor fails at the file-existence gate. Its output also
# carries the always-rendered table so we assert the render surface off it.
# =============================================================================
miss_out=$("$DOCTOR" "$TEST_TMPDIR/does-not-exist.json" 2>&1)
assert_contains "manifest-missing-fail-row" "not found:" "$miss_out"
assert_rc       "manifest-missing-exit1"    1 "$DOCTOR" "$TEST_TMPDIR/does-not-exist.json"

# table render surface (always present regardless of environment)
assert_contains "table-header"        "== polylane doctor ==" "$miss_out"
assert_contains "table-column-header" "STAT" "$miss_out"
assert_contains "summary-line-format" "PASS · " "$miss_out"

# deps check rows are always emitted (both the present and missing branches
# render a row with the same name).
assert_contains "deps-required-row" "dep: jq" "$miss_out"
assert_contains "deps-optional-row" "dep: shellcheck (optional)" "$miss_out"

# disk check always renders a row.
assert_contains "disk-check-row" "disk: free space" "$miss_out"

# =============================================================================
# tmux session-collision check (guarded: only meaningful when tmux is present,
# since the check returns early otherwise — the dep FAIL then covers absence).
# =============================================================================
if command -v tmux >/dev/null 2>&1; then
  free_out=$(POLYLANE_SESSION="$UNIQ" "$DOCTOR" "$GOOD" 2>&1)
  assert_contains "tmux-check-runs"   "tmux: session '" "$free_out"
  assert_contains "tmux-session-free" "name free" "$free_out"

  COLL="pl-doctest-coll-$$"
  tmux kill-session -t "$COLL" 2>/dev/null
  if tmux new-session -d -s "$COLL" 2>/dev/null; then
    coll_out=$(POLYLANE_SESSION="$COLL" "$DOCTOR" "$GOOD" 2>&1)
    assert_contains "tmux-session-collision" "already exists" "$coll_out"
    assert_rc       "tmux-collision-exit1"   1 env POLYLANE_SESSION="$COLL" "$DOCTOR" "$GOOD"
    tmux kill-session -t "$COLL" 2>/dev/null
  else
    pass "tmux-collision-skipped-no-server"
  fi
else
  pass "tmux-skipped-no-tmux"
fi

# =============================================================================
# manifest-validity checks (guarded: the deep sub-checks only run when jq parses
# the manifest; without jq doctor emits a WARN and returns early).
# =============================================================================
if command -v jq >/dev/null 2>&1; then
  good_out=$(POLYLANE_SESSION="$UNIQ" "$DOCTOR" "$GOOD" 2>&1); good_rc=$?

  # a fully-valid manifest passes each manifest sub-check
  assert_contains "manifest-valid-json-pass"    "parses clean" "$good_out"
  assert_contains "manifest-prompt-files-pass"  "all 2 exist and are non-empty" "$good_out"
  assert_contains "manifest-worktree-sane-pass" "all 2 sane" "$good_out"

  # exit contract: (no FAIL row) iff (exit 0). Proves all-pass -> 0 wherever the
  # host is clean, and stays correct on a host that has its own FAILs.
  want=0
  printf '%s\n' "$good_out" | grep -q '^FAIL ' && want=1
  assert_eq "exit-code-tracks-fail-presence" "$want" "$good_rc"

  # a lane branch/worktree that pre-exists is a WARN, not a FAIL (needs git too)
  if command -v git >/dev/null 2>&1; then
    assert_contains "lane-collisions-clean-pass" "no pre-existing lane branches or worktrees" "$good_out"
    warn_out=$(POLYLANE_SESSION="$UNIQ" "$DOCTOR" "$WARNM" 2>&1)
    assert_contains "worktree-collision-warn" "runner skips add and reuses it" "$warn_out"
  else
    pass "collision-checks-skipped-no-git"
  fi

  # invalid JSON is a FAIL -> exit 1
  badjson_out=$("$DOCTOR" "$BADJSON" 2>&1)
  assert_contains "invalid-json-fail" "invalid JSON" "$badjson_out"
  assert_rc       "invalid-json-exit1" 1 "$DOCTOR" "$BADJSON"

  # a missing/empty prompt_file is a FAIL -> exit 1
  badpf_out=$("$DOCTOR" "$BADPF" 2>&1)
  assert_contains "bad-prompt-file-fail" "missing/empty:" "$badpf_out"
  assert_rc       "bad-prompt-file-exit1" 1 "$DOCTOR" "$BADPF"

  # an insane worktree path is a FAIL -> exit 1
  insane_out=$("$DOCTOR" "$INSANE" 2>&1)
  assert_contains "insane-worktree-fail" "insane path:" "$insane_out"
  assert_rc       "insane-worktree-exit1" 1 "$DOCTOR" "$INSANE"
else
  pass "manifest-checks-skipped-no-jq"
fi

finish
