#!/usr/bin/env bash
# polylane-state.sh — the single authoritative state surface. Exercised as a CLI
# on a fake run: lane status precedence (done / likely-done / no-pane), verdict
# from the integrator sentinel, valid --json, and per-project runner detection
# (a runner in ANOTHER project must not read as "alive" here).

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
STATE="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-state.sh"

if ! command -v jq >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
  pass "state-skipped-no-deps"; finish; exit 0
fi

make_tmpdir
G="$TEST_TMPDIR/proj"
mkdir -p "$G"
(
  cd "$G"
  git init -q -b main; git config user.email t@t; git config user.name t
  echo x > f; git add f; git commit -qm base
  mkdir -p .polylane docs
  git worktree add .polylane/wt/a  -b lane/a  >/dev/null 2>&1
  git worktree add .polylane/wt/b  -b lane/b  >/dev/null 2>&1
  git worktree add .polylane/wt/int -b lane/int >/dev/null 2>&1
  # lane a: DONE file; lane b: commit but NO signal; integrator: GO sentinel
  mkdir -p .polylane/wt/a/docs .polylane/wt/int/docs
  printf 'STATUS: a DONE\n' > .polylane/wt/a/docs/status-a.md
  ( cd .polylane/wt/b && echo w > w.txt && git add w.txt && git commit -qm work )
  printf 'ev\nPOLYLANE-VERDICT: GO\n' > .polylane/wt/int/docs/verify-integration.md
) >/dev/null 2>&1
cat > "$G/.polylane/run.json" <<EOF
{"base":"main","integrator":{"name":"int","model":"m","effort":"x","branch":"lane/int","worktree":"$G/.polylane/wt/int","prompt_file":"p"},
"lanes":[{"name":"a","model":"m","effort":"h","branch":"lane/a","worktree":"$G/.polylane/wt/a","prompt_file":"p","own_globs":["x"]},
{"name":"b","model":"m","effort":"h","branch":"lane/b","worktree":"$G/.polylane/wt/b","prompt_file":"p","own_globs":["y"]}]}
EOF

OUT=$(cd "$G" && POLYLANE_SESSION=state-test-nosuch "$STATE" .polylane/run.json)
assert_contains "state-lane-done"        "done"                   "$(printf '%s' "$OUT" | grep '^  a ')"
assert_contains "state-lane-likely-done" "likely-done"            "$(printf '%s' "$OUT" | grep '^  b ')"
assert_contains "state-lane-commits"     "+1"                     "$(printf '%s' "$OUT" | grep '^  b ')"
assert_contains "state-verdict-go"       "verdict: GO"            "$OUT"
assert_contains "state-report-absent"    "report: absent"         "$OUT"
assert_contains "state-watch-inactive"    "watch: -"               "$OUT"
# no runner drives THIS temp project (others may run elsewhere on the machine)
assert_contains "state-runner-dead"      "runner: dead"           "$OUT"

# --json is valid and carries the same facts
J=$(cd "$G" && POLYLANE_SESSION=state-test-nosuch "$STATE" .polylane/run.json --json)
assert_ok "state-json-valid" sh -c "printf '%s' '$(printf '%s' "$J" | tr -d "'")' | jq -e . >/dev/null"
assert_eq "state-json-verdict" "GO" "$(printf '%s' "$J" | jq -r .verdict)"
assert_eq "state-json-lane-a"  "done" "$(printf '%s' "$J" | jq -r '.lanes[] | select(.name=="a") | .status')"
assert_eq "state-json-watch-inactive" "-" "$(printf '%s' "$J" | jq -r .watch)"
assert_eq "state-json-session-explicit" "state-test-nosuch" "$(printf '%s' "$J" | jq -r .session)"

# A preserved tmux session with only idle shells is not a live supervised
# runtime and must not advertise an attach command.
mkdir -p "$TEST_TMPDIR/bin"
cat > "$TEST_TMPDIR/bin/tmux" <<'TMUX'
#!/usr/bin/env bash
case "$1" in
  has-session) exit 0 ;;
  list-panes) exit 0 ;;
  list-sessions) exit 0 ;;
  *) exit 1 ;;
esac
TMUX
chmod +x "$TEST_TMPDIR/bin/tmux"
old_path="$PATH"; PATH="$TEST_TMPDIR/bin:$PATH"; export PATH
J_IDLE=$(cd "$G" && POLYLANE_SESSION=idle-state "$STATE" .polylane/run.json --json)
assert_eq "state-idle-session-runner-dead" "dead" "$(printf '%s' "$J_IDLE" | jq -r .runner)"
assert_eq "state-idle-session-hides-watch" "-" "$(printf '%s' "$J_IDLE" | jq -r .watch)"

# a fresh supervisor heartbeat is enough to report this run alive without ps/lsof
printf '%s runner=alive restarts=0\n' "$(date '+%F %T')" > "$G/.polylane/supervisor-heartbeat"
OUT_HB=$(cd "$G" && POLYLANE_SESSION=idle-state "$STATE" .polylane/run.json)
assert_contains "state-heartbeat-alive" "runner: alive" "$OUT_HB"
assert_contains "state-live-session-shows-watch" "watch: tmux attach -t idle-state" "$OUT_HB"
PATH="$old_path"; export PATH

# report present flips the field
echo "Outcome: GO" > "$G/docs/polylane-report.md"
OUT2=$(cd "$G" && POLYLANE_SESSION=state-test-nosuch "$STATE" .polylane/run.json)
assert_contains "state-report-present" "report: present" "$OUT2"

finish
