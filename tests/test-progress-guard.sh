#!/usr/bin/env bash
# A busy-looking Codex pane cannot burn an unbounded command loop without source
# progress: it is narrowed, downgraded, then stopped only as NEEDS-USER.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
REPO_ROOT="$TEST_TMPDIR/repo"
WT="$TEST_TMPDIR/wt"
mkdir -p "$REPO_ROOT/docs/lane-logs" "$REPO_ROOT/.polylane/lanes" "$WT"
git -C "$WT" init -q
git -C "$WT" config user.email test@example.invalid
git -C "$WT" config user.name test
printf 'source\n' > "$WT/source.txt"
git -C "$WT" add source.txt
git -C "$WT" commit -qm init

LANE_NAMES=(builder)
LANE_WORKTREES=("$WT")
LANE_MODELS=(gpt-5.6-sol)
LANE_EFFORTS=(xhigh)
LANE_PROMPTS=("$TEST_TMPDIR/prompt.txt")
LANE_PANE_IDX=(0)
LANE_PHASH=()
LANE_PCNT=()
LANE_PCOMMANDS=()
LANE_PREPLANS=()
LANE_WHASH=()
LANE_WCNT=()
LANE_RETRIES=()
LANE_REPAIRS=()
INT_NAME=integrator
AVAILABLE_MODELS=(gpt-5.6-sol gpt-5.6-terra)
AGENT=codex
cat > "${LANE_PROMPTS[0]}" <<'EOF'
ULTIMATE-GOAL: ship builder.
CURRENT-SUBGOAL: finish builder.
GOAL: finish builder.
OWN: builder files.
FORBIDDEN: unrelated files.
PREDEFINED-SKILLS: engineering:debug
LANE-SPECIFIC-SKILLS: engineering:debug
Read only the named kit once.
TEST-CADENCE: focused first.
DELEGATION: forbidden.
CHECK-CACHE: use $PWD/.polylane/check-cache/builder.
EXTERNAL-EVIDENCE: none.
VERIFY: write evidence then STATUS: builder DONE run=progress-run.
EOF

: > "$REPO_ROOT/docs/lane-logs/builder.log"

POLYLANE_PROGRESS_CHECKS=2
POLYLANE_PROGRESS_MIN_COMMANDS=20
material_progress_stalled builder "$WT"; rc1=$?
for i in $(seq 1 20); do
  printf '{"type":"item.started","item":{"type":"command_execution"}}\n'
done > "$REPO_ROOT/docs/lane-logs/builder.log"
material_progress_stalled builder "$WT"; rc2=$?
material_progress_stalled builder "$WT"; rc3=$?
assert_eq "progress-first-baselines" "1" "$rc1"
assert_eq "progress-before-threshold" "1" "$rc2"
assert_eq "progress-command-churn-fires" "0" "$rc3"

printf 'change\n' >> "$WT/source.txt"
material_progress_stalled builder "$WT"; rc4=$?
assert_eq "progress-source-change-resets" "1" "$rc4"

# Evidence/certification lanes can make real progress without touching source.
# A completed agent milestone or file change in the durable lane log must reset
# the churn window; otherwise long live UI passes are destroyed mid-journey.
LANE_PHASH=()
LANE_PCNT=()
LANE_PCOMMANDS=()
: > "$REPO_ROOT/docs/lane-logs/builder.log"
material_progress_stalled builder "$WT"
for i in $(seq 1 20); do
  printf '{"type":"item.started","item":{"type":"command_execution"}}\n'
done >> "$REPO_ROOT/docs/lane-logs/builder.log"
printf '{"type":"item.completed","item":{"type":"agent_message","text":"verified playback and stop"}}\n' \
  >> "$REPO_ROOT/docs/lane-logs/builder.log"
material_progress_stalled builder "$WT"; rc5=$?
assert_eq "progress-evidence-milestone-resets" "1" "$rc5"
material_progress_stalled builder "$WT"; rc5b=$?
assert_eq "progress-evidence-reset-persists" "1" "$rc5b"
for i in $(seq 1 20); do
  printf '{"type":"item.started","item":{"type":"command_execution"}}\n'
done >> "$REPO_ROOT/docs/lane-logs/builder.log"
material_progress_stalled builder "$WT"; rc6=$?
assert_eq "progress-post-evidence-churn-still-fires" "0" "$rc6"

# Active command executions are not command churn.  Cycle 28 had twenty command
# starts across the old 12-check threshold while one long matrix was still live;
# suppress every churn tick until the final structured completion arrives, then
# retain the same bounded replan policy for the settled transcript.
LANE_PHASH=()
LANE_PCNT=()
LANE_PCOMMANDS=()
LANE_PREPLANS=()
: > "$REPO_ROOT/docs/lane-logs/builder.log"
POLYLANE_PROGRESS_CHECKS=12
POLYLANE_PROGRESS_MIN_COMMANDS=20
material_progress_stalled builder "$WT"
for i in $(seq 1 20); do
  printf '{"type":"item.started","item":{"id":"cmd-%s","type":"command_execution","status":"in_progress"}}\n' "$i"
done >> "$REPO_ROOT/docs/lane-logs/builder.log"
for i in $(seq 1 19); do
  printf '{"type":"item.completed","item":{"id":"cmd-%s","type":"command_execution","status":"completed"}}\n' "$i"
done >> "$REPO_ROOT/docs/lane-logs/builder.log"
printf '%s\n' 'provider warning: retained raw pane line' >> "$REPO_ROOT/docs/lane-logs/builder.log"
printf '%s\n' '{"type":"provider.warning","item":"retained structured warning"}' >> "$REPO_ROOT/docs/lane-logs/builder.log"
assert_ok "progress-mixed-log-keeps-active-command" lane_active_command builder
# A stale command from an interrupted turn must not suppress a later turn
# forever. The next turn starts fresh and contributes only its own command ID.
printf '%s\n' '{"type":"turn.completed"}' >> "$REPO_ROOT/docs/lane-logs/builder.log"
assert_fail "progress-terminal-turn-clears-stale-active-command" lane_active_command builder
printf '%s\n' '{"type":"turn.started"}' >> "$REPO_ROOT/docs/lane-logs/builder.log"
printf '%s\n' '{"type":"item.started","item":{"id":"cmd-current","type":"command_execution","status":"in_progress"}}' \
  >> "$REPO_ROOT/docs/lane-logs/builder.log"
for i in $(seq 1 12); do
  material_progress_stalled builder "$WT" || true
done
assert_eq "progress-active-commands-do-not-advance-churn" "0" "${LANE_PCNT[0]:-0}"
assert_eq "progress-active-commands-do-not-replan" "0" "${LANE_PREPLANS[0]:-0}"
printf '{"type":"item.completed","item":{"id":"cmd-20","type":"command_execution","status":"completed"}}\n' \
  >> "$REPO_ROOT/docs/lane-logs/builder.log"
printf '%s\n' '{"type":"item.completed","item":{"id":"cmd-current","type":"command_execution","status":"completed"}}' \
  >> "$REPO_ROOT/docs/lane-logs/builder.log"
for i in $(seq 1 11); do
  material_progress_stalled builder "$WT" || true
done
material_progress_stalled builder "$WT"; settled_rc=$?
assert_eq "progress-settled-command-churn-still-fires" "0" "$settled_rc"

RESPAWNS=0
respawn_lane() { RESPAWNS=$((RESPAWNS + 1)); }
notify_event() { :; }
POLYLANE_PROGRESS_REPLANS=2
replan_churning_lane builder "$WT" 0
assert_eq "progress-replan-respawns" "1" "$RESPAWNS"
assert_eq "progress-replan-model-downgrade" "gpt-5.6-terra" "${LANE_MODELS[0]}"
assert_eq "progress-replan-effort-downgrade" "high" "${LANE_EFFORTS[0]}"
assert_contains "progress-replan-forbids-delegation" "DELEGATION: forbidden" "$(cat "${LANE_PROMPTS[0]}")"
assert_contains "progress-replan-preserves-cache" "CHECK-CACHE: use \$PWD/.polylane/check-cache/builder." "$(cat "${LANE_PROMPTS[0]}")"
assert_ok "progress-replan-preserves-strict-scalar-contract" \
  "$SCRIPT_DIR/../bin/polylane-promptopt.sh" check "${LANE_PROMPTS[0]}"

replan_churning_lane builder "$WT" 0
assert_eq "progress-second-replan-respawns" "2" "$RESPAWNS"
assert_fail "progress-third-replan-needs-user" replan_churning_lane builder "$WT" 0
assert_ok "progress-needs-user-file" test -s "$REPO_ROOT/.polylane/needs-user"

finish
