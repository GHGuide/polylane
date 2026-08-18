#!/usr/bin/env bash
# polylane-supervisor.sh — crash-proof outer loop. Proven with a FAKE runner:
#   crash (no report)  -> revived with --resume
#   GO/external report -> legitimate cycle end
#   HALTED report      -> recoverable; supervisor resumes rather than stopping
#   NO-GO report       -> clean end after runner-level repair is exhausted
#   restart cap        -> halts rc1

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
SUP_SRC="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-supervisor.sh"

if ! command -v jq >/dev/null 2>&1; then pass "supervisor-skipped-no-jq"; finish; exit 0; fi

# Keep the fake-runner recovery fixtures hermetic. A real outer efficiency canary
# intentionally sets this to 0, but that policy must not leak into the nested
# supervisor-under-test and disable the recovery behavior these cases exercise.
export POLYLANE_SUP_MAX_RESTARTS=10

make_tmpdir
BIN="$TEST_TMPDIR/bin"; PROJ="$TEST_TMPDIR/proj"
mkdir -p "$BIN" "$PROJ/.polylane" "$PROJ/docs"
cp "$SUP_SRC" "$BIN/polylane-supervisor.sh"
cp "$(cd "$(dirname "$RUNNER")" && pwd)/polylane-tmux.sh" "$BIN/polylane-tmux.sh"

# fake runner: behavior file .polylane/mode drives it —
#   crash-then-go : crash rc137 first, then report+rc0   (revive path)
#   nogo          : write report, exit 1                  (legit NO-GO end)
#   halted-then-go: HALTED report first, then GO           (boundary recovery)
#   external      : write external-open report, exit 0     (clean cycle end)
#   preflight-error: deterministic configuration rc2        (never retry)
#   always-crash  : crash rc137 every time                 (cap path)
#   halted-needs-user: HALTED + needs-user marker           (do not relaunch)
#   slow-go       : stay alive briefly, then GO             (lock contention)
cat > "$BIN/polylane-run.sh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
lane_done(){ return 1; }; pane_awaiting_approval(){ [ "${POLYLANE_TEST_AWAITING:-0}" = 1 ]; }
approval_is_critical(){ return 1; }; notify_event(){ :; }
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  M="$1"; shift; D=$(cd "$(dirname "$M")" && pwd); ROOT=$(cd "$D/.." && pwd)
  echo "ARGS: $*" >> "$D/calls.log"
  case "$(cat "$D/mode")" in
    crash-then-go) if [ -f "$D/crashed" ]; then printf '**Outcome:** GO\n**Run:** current-nonce\n' > "$ROOT/docs/polylane-report.md"; exit 0
                   else touch "$D/crashed"; exit 137; fi ;;
    halted-then-go) if [ -f "$D/halted" ]; then printf '**Outcome:** GO\n**Run:** current-nonce\n' > "$ROOT/docs/polylane-report.md"; exit 0
                    else touch "$D/halted"; printf '**Outcome:** HALTED\n**Run:** current-nonce\n' > "$ROOT/docs/polylane-report.md"; exit 1; fi ;;
    external)      printf '**Outcome:** EXTERNAL-EVIDENCE-OPEN\n**Run:** current-nonce\n' > "$ROOT/docs/polylane-report.md"; exit 0 ;;
    preflight-error) exit 2 ;;
    nogo)          printf '**Outcome:** NO-GO\n**Run:** current-nonce\n' > "$ROOT/docs/polylane-report.md"; exit 1 ;;
    halted-needs-user) echo lane-a > "$D/needs-user"; printf '**Outcome:** HALTED\n**Run:** current-nonce\n' > "$ROOT/docs/polylane-report.md"; exit 1 ;;
    slow-go)       trap 'echo term > "$D/child-term"; exit 143' TERM
                   sleep 2; printf '**Outcome:** GO\n**Run:** current-nonce\n' > "$ROOT/docs/polylane-report.md"; exit 0 ;;
    always-crash)  exit 137 ;;
  esac
fi
FAKE
chmod +x "$BIN"/*.sh
cat > "$PROJ/.polylane/run.json" <<EOF
{"base":"main","run_id":"current-nonce","integrator":{"name":"int","model":"m","effort":"x","branch":"lane/int","worktree":"$PROJ/.polylane/wt/int","prompt_file":"p"},
"lanes":[{"name":"a","model":"m","effort":"h","branch":"lane/a","worktree":"$PROJ/.polylane/wt/a","prompt_file":"p","own_globs":["x"]}]}
EOF
mkdir -p "$PROJ/.polylane/wt/a" "$PROJ/.polylane/wt/int"

reset_proj() {
  rm -f "$PROJ/.polylane/calls.log" "$PROJ/.polylane/crashed" \
    "$PROJ/.polylane/halted" "$PROJ/.polylane/needs-user" \
    "$PROJ/.polylane/child-term" \
    "$PROJ/docs/polylane-report.md"
}

# --- help is inert: no manifest parse, runner launch, or recovery loop ----------
mkdir -p "$TEST_TMPDIR/help-probe"
(
  cd "$TEST_TMPDIR/help-probe" || exit 1
  POLYLANE_SUP_MAX_RESTARTS=0 POLYLANE_SUP_INTERVAL=0 \
    "$BIN/polylane-supervisor.sh" --help > "$TEST_TMPDIR/out-help" 2>&1
)
assert_eq "sup-help-rc0" "0" "$?"
assert_contains "sup-help-usage" "USAGE:" "$(cat "$TEST_TMPDIR/out-help")"
assert_fail "sup-help-no-runner-log" test -e "$TEST_TMPDIR/help-probe/runner.log"

# --- crash -> revive with --resume -> rc0 -------------------------------------
reset_proj; echo crash-then-go > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out1" 2>&1
assert_eq "sup-revive-rc0" "0" "$?"
assert_contains "sup-revive-logged"  "reviving with --resume" "$(cat "$TEST_TMPDIR/out1")"
assert_contains "sup-watch-command"  "watch active tmux:" "$(cat "$TEST_TMPDIR/out1")"
assert_contains "sup-second-call-resumes" "yes --resume" "$(tail -1 "$PROJ/.polylane/calls.log")"
assert_contains "sup-finished" "finished legitimately" "$(cat "$TEST_TMPDIR/out1")"

# --- HALTED is recoverable even though a report was written --------------------
reset_proj; echo halted-then-go > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out-halted" 2>&1
assert_eq "sup-halted-recovers-rc0" "0" "$?"
assert_eq "sup-halted-two-launches" "2" "$(grep -c ARGS "$PROJ/.polylane/calls.log")"
assert_contains "sup-halted-resumes" "HALTED outcome is recoverable" "$(cat "$TEST_TMPDIR/out-halted")"

# --- external evidence is a clean engineering cycle end ------------------------
reset_proj; echo external > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out-external" 2>&1
assert_eq "sup-external-rc0" "0" "$?"
assert_eq "sup-external-single-launch" "1" "$(grep -c ARGS "$PROJ/.polylane/calls.log")"

# --- NO-GO is a clean end (rc1), NOT a crash to revive -------------------------
reset_proj; echo nogo > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out2" 2>&1
rc=$?
assert_eq "sup-nogo-rc1" "1" "$rc"
assert_eq "sup-nogo-single-launch" "1" "$(grep -c ARGS "$PROJ/.polylane/calls.log")"

# A newly written report for another run is not this runner's terminal handoff.
# It remains recoverable instead of suppressing the correct resume decision.
reset_proj; echo always-crash > "$PROJ/.polylane/mode"
printf '**Outcome:** NO-GO\n**Run:** stale-nonce\n' > "$PROJ/docs/polylane-report.md"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 POLYLANE_SUP_MAX_RESTARTS=0 \
  "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out-stale-run" 2>&1
stale_rc=$?
assert_eq "sup-stale-run-report-is-not-terminal" "1" "$stale_rc"
assert_contains "sup-stale-run-report-revives" "without a report" "$(cat "$TEST_TMPDIR/out-stale-run")"

# --- a durable no-progress blocker is not relaunched identically ----------------
reset_proj; echo halted-needs-user > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out-needs-user" 2>&1
rc=$?
assert_eq "sup-needs-user-rc1" "1" "$rc"
assert_eq "sup-needs-user-single-launch" "1" "$(grep -c ARGS "$PROJ/.polylane/calls.log")"
assert_contains "sup-needs-user-no-loop" "not relaunching identical work" "$(cat "$TEST_TMPDIR/out-needs-user")"

# A usage/manifest/contract preflight failure is deterministic. Retrying the
# same immutable manifest only burns restart budget and sends repeated failure
# notifications; stop after the first rc2 and preserve its diagnostic log.
reset_proj; echo preflight-error > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=0 POLYLANE_SUP_MAX_RESTARTS=2 \
  "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out-preflight" 2>&1
rc=$?
assert_eq "sup-preflight-rc2" "2" "$rc"
assert_eq "sup-preflight-single-launch" "1" "$(grep -c ARGS "$PROJ/.polylane/calls.log")"
assert_contains "sup-preflight-no-identical-retry" "deterministic preflight" "$(cat "$TEST_TMPDIR/out-preflight")"

# --- only one supervisor may own a manifest ------------------------------------
reset_proj; echo slow-go > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out-lock-owner" 2>&1 &
owner_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -d "$PROJ/.polylane/supervisor.lock" ] && break
  sleep 0.1
done
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out-lock-second" 2>&1
second_rc=$?
wait "$owner_pid"
assert_eq "sup-lock-second-refused" "1" "$second_rc"
assert_contains "sup-lock-names-owner" "another supervisor already owns" "$(cat "$TEST_TMPDIR/out-lock-second")"
assert_fail "sup-lock-cleaned-after-owner" test -d "$PROJ/.polylane/supervisor.lock"

# --- TERM stops the child and supervisor, then releases the lock ----------------
reset_proj; echo slow-go > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 \
  "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out-term" 2>&1 &
term_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -d "$PROJ/.polylane/supervisor.lock" ] && break
  sleep 0.1
done
kill -TERM "$term_pid"
wait "$term_pid"
term_rc=$?
assert_eq "sup-term-rc143" "143" "$term_rc"
assert_ok "sup-term-reaches-child" test -f "$PROJ/.polylane/child-term"
assert_fail "sup-term-cleans-lock" test -d "$PROJ/.polylane/supervisor.lock"

# --- restart cap: always-crash halts rc1 after cap ------------------------------
reset_proj; echo always-crash > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 POLYLANE_SUP_MAX_RESTARTS=2 \
  "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out3" 2>&1
rc=$?
assert_eq "sup-cap-rc1" "1" "$rc"
assert_contains "sup-cap-halt" "restart cap" "$(cat "$TEST_TMPDIR/out3")"
assert_eq "sup-cap-launches" "3" "$(grep -c ARGS "$PROJ/.polylane/calls.log")"   # 1 + 2 revives

# Resource pressure is a wait state, not a runner crash.  A deterministic probe
# returns low once then healthy; no real disk is consumed and no restart budget is used.
reset_proj; echo external > "$PROJ/.polylane/mode"
PROBE="$BIN/fake-disk-probe"
cat > "$PROBE" <<'PROBE'
#!/usr/bin/env bash
n=0; [ -f "$POLYLANE_PROBE_COUNT" ] && n=$(cat "$POLYLANE_PROBE_COUNT")
n=$((n + 1)); printf '%s\n' "$n" > "$POLYLANE_PROBE_COUNT"
[ "$n" -eq 1 ] && echo 0 || echo 10
PROBE
chmod +x "$PROBE"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 POLYLANE_SUP_DISK_BACKOFF=0 \
  POLYLANE_MIN_DISK_GB=2 POLYLANE_DISK_PROBE="$PROBE" POLYLANE_PROBE_COUNT="$TEST_TMPDIR/probe-count" \
  "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out-disk" 2>&1
assert_eq "sup-disk-wait-rc0" "0" "$?"
assert_eq "sup-disk-wait-probed-twice" "2" "$(cat "$TEST_TMPDIR/probe-count")"
assert_eq "sup-disk-wait-does-not-relaunch" "1" "$(grep -c ARGS "$PROJ/.polylane/calls.log")"
assert_contains "sup-disk-wait-logged" "disk headroom low — waiting" "$(cat "$TEST_TMPDIR/out-disk")"

# --- heartbeat written ----------------------------------------------------------
assert_ok "sup-heartbeat-exists" test -f "$PROJ/.polylane/supervisor-heartbeat"

finish
