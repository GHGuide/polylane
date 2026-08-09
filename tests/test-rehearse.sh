#!/usr/bin/env bash
# polylane-rehearse.sh — the canary itself must reach promote-on-GO and gate on NO-GO.
# Drives the REAL runner with real tmux, so it's SLOW + gated behind POLYLANE_REHEARSE=1
# to keep the default suite fast/hermetic. Run on demand: POLYLANE_REHEARSE=1 tests/run.sh
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
RH="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-rehearse.sh"
DOCTOR="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-doctor.sh"

assert_contains "rehearse-doctor-reports-current-contract" "both contract-v3 cases passed" \
  "$(grep 'both contract-' "$DOCTOR" 2>/dev/null || true)"
assert_eq "rehearse-fixture-has-verify-for-prompt-compiler" "3" \
  "$(grep -c "'VERIFY:" "$RH" 2>/dev/null || true)"
assert_contains "rehearse-isolates-inherited-tmux-client" "unset TMUX" \
  "$(sed -n '/^rehearse()/,/^}/p' "$RH")"
assert_contains "rehearse-uses-private-tmux-server-dir" 'TMUX_TMPDIR="$tmux_root"' \
  "$(sed -n '/^rehearse()/,/^}/p' "$RH")"
assert_contains "rehearse-keeps-tmux-socket-parent-short" 'plr-tmux.XXXXXX' \
  "$(sed -n '/^rehearse()/,/^}/p' "$RH")"
assert_contains "rehearse-lane-a-owns-canonical-status-marker" \
  '"own_globs":["a/**","docs/status-lane-a.md"]' "$(cat "$RH")"
assert_contains "rehearse-lane-b-owns-canonical-status-marker" \
  '"own_globs":["b/**","docs/status-lane-b.md"]' "$(cat "$RH")"

# Invocation counters, graph witnesses, the mock executable, and its run log
# must live outside the Git worktree so successful runner cleanup cannot erase
# them before grading. Fixture worktrees remain under runner-owned scratch.
make_tmpdir
fixture_runtime_paths_check='source "$1"; repo="$2"; runtime="$3"; for name in mock-invocations graph-witness mockagent rehearse.log; do path=$(rehearse_fixture_runtime_path "$runtime" "$name") || exit 1; [ "$path" = "$runtime/rehearse/$name" ] || exit 1; case "$path" in "$repo"/*) exit 1;; esac; done; grep -qF '\''worktrees_root="$root/.polylane/rehearse/worktrees"'\'' "$1"; ! grep -qE '\''\$root/(mockagent|rehearse\.log|wt-(a|b|int))'\'' "$1"'
assert_ok "rehearse-separates-grading-runtime-from-runner-scratch" bash -c "$fixture_runtime_paths_check" _ "$RH" "$TEST_TMPDIR/repo" "$TEST_TMPDIR/runtime"

# The live fixture advances durable state before writing reports. Cleanup must
# remove tracked and untracked current-run status markers without rejecting
# that intended durable state change.
REHEARSE_REPO="$TEST_TMPDIR/repo"
REHEARSE_SKILLS="$TEST_TMPDIR/skills"
fixture_skills_check='source "$1"; rehearse_create_fixture_skills "$2"; for skill in fixture-test fixture-debug fixture-review fixture-check; do test -f "$2/$skill/SKILL.md" || exit 1; done'
assert_ok "rehearse-creates-resolvable-skill-fixtures" bash -c "$fixture_skills_check" _ "$RH" "$REHEARSE_SKILLS"
mkdir -p "$REHEARSE_REPO"
git -C "$REHEARSE_REPO" init -q
git -C "$REHEARSE_REPO" config user.email t@t
git -C "$REHEARSE_REPO" config user.name t
printf '%s\n' seed > "$REHEARSE_REPO/seed.txt"
git -C "$REHEARSE_REPO" add seed.txt
git -C "$REHEARSE_REPO" commit -qm seed
clean_check='source "$1"; rehearse_promoted_tree_clean "$2"'
assert_ok "rehearse-clean-promoted-tree" bash -c "$clean_check" _ "$RH" "$REHEARSE_REPO"
assert_fail "rehearse-rejects-non-repository" bash -c "$clean_check" _ "$RH" "$TEST_TMPDIR/missing"
mkdir -p "$REHEARSE_REPO/docs"
printf '%s\n' stale > "$REHEARSE_REPO/docs/status-lane-a.md"
assert_fail "rehearse-rejects-untracked-status" bash -c "$clean_check" _ "$RH" "$REHEARSE_REPO"
git -C "$REHEARSE_REPO" add docs/status-lane-a.md
git -C "$REHEARSE_REPO" commit -qm marker
assert_fail "rehearse-rejects-tracked-status" bash -c "$clean_check" _ "$RH" "$REHEARSE_REPO"

if [ "${POLYLANE_REHEARSE:-0}" != "1" ]; then
  pass "rehearse-gated-off (set POLYLANE_REHEARSE=1 to run the live canary)"; finish; exit $?
fi
if ! command -v tmux >/dev/null 2>&1; then
  pass "rehearse-skipped-no-tmux"; finish; exit $?
fi

out=$("$RH" go 2>&1); rc=$?
if [ "$rc" = 77 ]; then pass "rehearse-skipped-no-tmux"; finish; exit $?; fi
assert_eq "rehearse-go-reaches-promote" "0" "$rc"
assert_contains "rehearse-go-host-gate-candidate" \
  "REHEARSE-GO contract-v3=1 ready=1 promoted=1 terminal_gates=1 cleaned=1 leaks=0" "$out"

out=$("$RH" nogo 2>&1); rc=$?
assert_eq "rehearse-nogo-gate-holds" "0" "$rc"
assert_contains "rehearse-nogo-contract-v3" "REHEARSE-NOGO contract-v3=1 promoted=0 evidence=1 retained=1 bounded=1 cleaned=1" "$out"
finish
