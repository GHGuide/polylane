#!/usr/bin/env bash
# polylane-cycle.sh — durable cycle-boundary guard. A cycle may close only after
# state, acceptance, progress, artifacts, and the next route agree.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

CYCLE="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-cycle.sh"
MEM="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-memory.sh"

if ! command -v jq >/dev/null 2>&1; then pass "cycle-skipped-no-jq"; finish; exit 0; fi

make_tmpdir
ROOT="$TEST_TMPDIR/project"
STATE="$ROOT/docs/polylane/max-state.json"
mkdir -p "$ROOT/docs/polylane"

"$MEM" "$STATE" init "ship it" >/dev/null
"$MEM" "$STATE" add-criterion c1 "works" >/dev/null
"$MEM" "$STATE" add-milestone m1 "build" >/dev/null
"$MEM" "$STATE" add-subgoal m1 s1 "autonomous work" 10 >/dev/null
"$MEM" "$STATE" add-subgoal m1 s2 "physical proof" 5 >/dev/null

assert_contains "route-continues-open" "CONTINUE s1" "$("$CYCLE" route "$STATE")"

"$MEM" "$STATE" set-status s1 done "proof" 1 >/dev/null
"$MEM" "$STATE" set-status s2 external "needs a person" 1 >/dev/null
assert_contains "route-needs-user-only-when-no-work" "NEEDS-USER" "$("$CYCLE" route "$STATE")"

"$MEM" "$STATE" set-status s2 done "physical proof" 2 >/dev/null
"$MEM" "$STATE" set-status c1 done >/dev/null
assert_fail "route-not-complete-without-check" "$CYCLE" route "$STATE"

# A passing frozen grader turns the mechanically complete tree into COMPLETE.
STATE2="$ROOT/docs/polylane/complete.json"
"$MEM" "$STATE2" init "ship it" >/dev/null
"$MEM" "$STATE2" add-criterion c1 "works" >/dev/null
"$MEM" "$STATE2" add-milestone m1 "build" >/dev/null
"$MEM" "$STATE2" add-subgoal m1 s1 "feature" >/dev/null
"$MEM" "$STATE2" add-accept s1 "true" >/dev/null
"$MEM" "$STATE2" set-status s1 done >/dev/null
"$MEM" "$STATE2" set-status c1 done >/dev/null
"$MEM" "$STATE2" check-accept --cycle 2 >/dev/null
assert_eq "route-complete" "COMPLETE" "$("$CYCLE" route "$STATE2")"

# A criterion with no actionable subgoal is a dead end, never a silent stop.
STATE3="$ROOT/docs/polylane/dead.json"
"$MEM" "$STATE3" init "ship it" >/dev/null
"$MEM" "$STATE3" add-criterion c1 "still open" >/dev/null
assert_rc "route-dead-end-rc6" 6 "$CYCLE" route "$STATE3"

# Progress is generated from current state, not an old conversation summary.
"$CYCLE" progress "$STATE" 9 >/dev/null
PROGRESS="$ROOT/docs/polylane/progress.md"
assert_ok "progress-written" test -f "$PROGRESS"
assert_contains "progress-current-cycle" "Cycle 9" "$(cat "$PROGRESS")"
assert_contains "progress-external-section" "External/user evidence" "$(cat "$PROGRESS")"
assert_contains "progress-acceptance-summary" "Acceptance checks" "$(cat "$PROGRESS")"

# A closed cycle requires every durable artifact and the next plan when routing on.
for kind in digest research council questions; do
  printf '# %s\n' "$kind" > "$ROOT/docs/polylane/cycle-9-$kind.md"
done
printf '# next\n' > "$ROOT/docs/polylane/cycle-10-plan.md"
printf '# index\n' > "$ROOT/docs/polylane/INDEX.md"
assert_ok "artifacts-complete" "$CYCLE" artifacts "$ROOT" 9 "$STATE"
rm "$ROOT/docs/polylane/cycle-9-council.md"
assert_rc "artifacts-missing-rc7" 7 "$CYCLE" artifacts "$ROOT" 9 "$STATE"

# The initial-goal suggestion packet is exactly 30 concise bullets.
SUG="$ROOT/docs/polylane/next-suggestions.md"
i=1; while [ "$i" -le 30 ]; do printf -- '- Suggestion %s\n' "$i" >> "$SUG"; i=$((i+1)); done
assert_ok "suggestions-exactly-30" "$CYCLE" suggestions "$SUG"
printf -- '- Suggestion 31\n' >> "$SUG"
assert_rc "suggestions-31-rejected" 8 "$CYCLE" suggestions "$SUG"

# A live supervisor heartbeat + active tmux yields exactly one attach command.
mkdir -p "$ROOT/.polylane" "$TEST_TMPDIR/bin"
cat > "$ROOT/.polylane/run.json" <<JSON
{"base":"main","run_id":"runtime-test","integrator":{"name":"int","branch":"lane/int","worktree":"$ROOT/int"},
 "lanes":[{"name":"a","branch":"lane/a","worktree":"$ROOT/a"}]}
JSON
printf '%s runner=alive restarts=0\n' "$(date '+%F %T')" > "$ROOT/.polylane/supervisor-heartbeat"
cat > "$TEST_TMPDIR/bin/tmux" <<'TMUX'
#!/usr/bin/env bash
case "$1" in
  has-session) [ "${FAKE_TMUX_ACTIVE:-0}" = "1" ] ;;
  list-sessions)
    [ "${FAKE_TMUX_DISCOVERY:-0}" = "1" ] &&
      printf '%s|%s|%s\n' "${FAKE_TMUX_SESSION:-discovered-live}" \
        "${FAKE_TMUX_RUN_ID:-}" "${FAKE_TMUX_PROJECT:-}" ;;
  list-panes) exit 0 ;;
  *) exit 1 ;;
esac
TMUX
chmod +x "$TEST_TMPDIR/bin/tmux"
old_path="$PATH"; PATH="$TEST_TMPDIR/bin:$PATH"; export PATH
watch=$(FAKE_TMUX_ACTIVE=1 POLYLANE_SESSION=cycle-live "$CYCLE" runtime "$ROOT/.polylane/run.json" 0)
assert_eq "runtime-exact-attach-line" "tmux attach -t cycle-live" "$watch"
assert_eq "runtime-one-line" "1" "$(printf '%s\n' "$watch" | wc -l | tr -d ' ')"
assert_rc "runtime-inactive-rc9" 9 env FAKE_TMUX_ACTIVE=0 POLYLANE_SESSION=cycle-live \
  "$CYCLE" runtime "$ROOT/.polylane/run.json" 0

# Persisted manifest session works without an observer remembering the env var.
jq '.session="manifest-live"' "$ROOT/.polylane/run.json" > "$ROOT/.polylane/run-session.json"
watch=$(unset POLYLANE_SESSION; FAKE_TMUX_ACTIVE=1 "$CYCLE" runtime "$ROOT/.polylane/run-session.json" 0)
assert_eq "runtime-manifest-session" "tmux attach -t manifest-live" "$watch"

# Legacy active runs are recovered from runner-owned tmux tags.
watch=$(unset POLYLANE_SESSION; FAKE_TMUX_ACTIVE=1 FAKE_TMUX_DISCOVERY=1 \
  FAKE_TMUX_SESSION=discovered-live FAKE_TMUX_RUN_ID=runtime-test \
  FAKE_TMUX_PROJECT="$(cd "$ROOT" && pwd -P)" \
  "$CYCLE" runtime "$ROOT/.polylane/run.json" 0)
assert_eq "runtime-discovers-owned-session" "tmux attach -t discovered-live" "$watch"
PATH="$old_path"; export PATH

finish
