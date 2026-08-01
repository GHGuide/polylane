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
printf 'GOAL: finish builder\n' > "${LANE_PROMPTS[0]}"

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

RESPAWNS=0
respawn_lane() { RESPAWNS=$((RESPAWNS + 1)); }
notify_event() { :; }
POLYLANE_PROGRESS_REPLANS=2
replan_churning_lane builder "$WT" 0
assert_eq "progress-replan-respawns" "1" "$RESPAWNS"
assert_eq "progress-replan-model-downgrade" "gpt-5.6-terra" "${LANE_MODELS[0]}"
assert_eq "progress-replan-effort-downgrade" "high" "${LANE_EFFORTS[0]}"
assert_contains "progress-replan-forbids-delegation" "DELEGATION: forbidden" "$(cat "${LANE_PROMPTS[0]}")"
assert_contains "progress-replan-enforces-cache" "polylane-check.sh" "$(cat "${LANE_PROMPTS[0]}")"

replan_churning_lane builder "$WT" 0
assert_eq "progress-second-replan-respawns" "2" "$RESPAWNS"
assert_fail "progress-third-replan-needs-user" replan_churning_lane builder "$WT" 0
assert_ok "progress-needs-user-file" test -s "$REPO_ROOT/.polylane/needs-user"

finish
