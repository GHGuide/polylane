#!/usr/bin/env bash
# polylane-supervisor.sh — crash-proof outer loop. Proven with a FAKE runner:
#   crash (no report)  -> revived with --resume
#   report written     -> legitimate end, supervisor exits with runner's rc
#   NO-GO (rc1+report) -> clean end, NOT revived into a zombie
#   restart cap        -> halts rc1

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
SUP_SRC="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-supervisor.sh"

if ! command -v jq >/dev/null 2>&1; then pass "supervisor-skipped-no-jq"; finish; exit 0; fi

make_tmpdir
BIN="$TEST_TMPDIR/bin"; PROJ="$TEST_TMPDIR/proj"
mkdir -p "$BIN" "$PROJ/.polylane" "$PROJ/docs"
cp "$SUP_SRC" "$BIN/polylane-supervisor.sh"

# fake runner: behavior file .polylane/mode drives it —
#   crash-then-go : crash rc137 first, then report+rc0   (revive path)
#   nogo          : write report, exit 1                  (legit NO-GO end)
#   always-crash  : crash rc137 every time                (cap path)
cat > "$BIN/polylane-run.sh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
lane_done(){ return 1; }; pane_awaiting_approval(){ return 1; }
approval_is_critical(){ return 1; }; notify_event(){ :; }
if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  M="$1"; shift; D=$(cd "$(dirname "$M")" && pwd); ROOT=$(cd "$D/.." && pwd)
  echo "ARGS: $*" >> "$D/calls.log"
  case "$(cat "$D/mode")" in
    crash-then-go) if [ -f "$D/crashed" ]; then echo GO > "$ROOT/docs/polylane-report.md"; exit 0
                   else touch "$D/crashed"; exit 137; fi ;;
    nogo)          echo NO-GO > "$ROOT/docs/polylane-report.md"; exit 1 ;;
    always-crash)  exit 137 ;;
  esac
fi
FAKE
chmod +x "$BIN"/*.sh
cat > "$PROJ/.polylane/run.json" <<EOF
{"base":"main","integrator":{"name":"int","model":"m","effort":"x","branch":"lane/int","worktree":"$PROJ/.polylane/wt/int","prompt_file":"p"},
"lanes":[{"name":"a","model":"m","effort":"h","branch":"lane/a","worktree":"$PROJ/.polylane/wt/a","prompt_file":"p","own_globs":["x"]}]}
EOF

reset_proj() { rm -f "$PROJ/.polylane/calls.log" "$PROJ/.polylane/crashed" "$PROJ/docs/polylane-report.md"; }

# --- crash -> revive with --resume -> rc0 -------------------------------------
reset_proj; echo crash-then-go > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out1" 2>&1
assert_eq "sup-revive-rc0" "0" "$?"
assert_contains "sup-revive-logged"  "reviving with --resume" "$(cat "$TEST_TMPDIR/out1")"
assert_contains "sup-watch-command"  "watch active tmux: tmux attach -t sup-test-nosuch" "$(cat "$TEST_TMPDIR/out1")"
assert_contains "sup-second-call-resumes" "yes --resume" "$(tail -1 "$PROJ/.polylane/calls.log")"
assert_contains "sup-finished" "finished legitimately" "$(cat "$TEST_TMPDIR/out1")"

# --- NO-GO is a clean end (rc1), NOT a crash to revive -------------------------
reset_proj; echo nogo > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out2" 2>&1
rc=$?
assert_eq "sup-nogo-rc1" "1" "$rc"
assert_eq "sup-nogo-single-launch" "1" "$(grep -c ARGS "$PROJ/.polylane/calls.log")"

# --- restart cap: always-crash halts rc1 after cap ------------------------------
reset_proj; echo always-crash > "$PROJ/.polylane/mode"
POLYLANE_SESSION=sup-test-nosuch POLYLANE_SUP_INTERVAL=1 POLYLANE_SUP_MAX_RESTARTS=2 \
  "$BIN/polylane-supervisor.sh" "$PROJ/.polylane/run.json" > "$TEST_TMPDIR/out3" 2>&1
rc=$?
assert_eq "sup-cap-rc1" "1" "$rc"
assert_contains "sup-cap-halt" "restart cap" "$(cat "$TEST_TMPDIR/out3")"
assert_eq "sup-cap-launches" "3" "$(grep -c ARGS "$PROJ/.polylane/calls.log")"   # 1 + 2 revives

# --- heartbeat written ----------------------------------------------------------
assert_ok "sup-heartbeat-exists" test -f "$PROJ/.polylane/supervisor-heartbeat"

finish
