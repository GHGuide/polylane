#!/usr/bin/env bash
# Prime hybrid integration: canonical learning state is prepared only for an
# opted-in manifest, survives lane worktrees, and can never bypass frozen gates.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

command -v jq >/dev/null 2>&1 || { pass "prime-hybrid-skipped-no-jq"; finish; exit 0; }

make_tmpdir
PROJECT="$TEST_TMPDIR/project"
mkdir -p "$PROJECT/.polylane" "$PROJECT/docs/polylane/decisions"
printf '# North star\nShip safely.\n' > "$PROJECT/docs/polylane/NORTHSTAR.md"
printf '# Strategy\nBounded learning.\n' > "$PROJECT/docs/polylane/STRATEGY.md"
printf '# Goal\nA stranger succeeds unattended.\n' > "$PROJECT/docs/polylane/ULTIMATE_GOAL.md"
printf '# Decisions\nNo direct skill overwrite.\n' > "$PROJECT/docs/polylane/decisions/INDEX.md"
printf '# Cycle 11 digest\nPrior work.\n' > "$PROJECT/docs/polylane/cycle-11-digest.md"
printf '{"ultimate":"Ship safely","criteria":[],"log":[]}' > "$PROJECT/docs/polylane/max-state.json"
printf '%s\n' '{"event":"request","lane":"alpha","to":"beta","message":"review bounded packet","seq":1,"at":"2026-08-07T10:39:30Z"}' > "$PROJECT/.polylane/coordination.jsonl"

# Make the fixture a Git project and deliberately inherit another valid worker
# contract.  Prime-hybrid helpers must explicitly bind their own canonical root
# instead of redirecting this run's worker ledger to the ambient project.
git -C "$PROJECT" init -q
AMBIENT_PROJECT="$TEST_TMPDIR/ambient-project"
git init -q "$AMBIENT_PROJECT"

PROJECT_ROOT="$PROJECT"
REPO_ROOT="$PROJECT"
COORDINATION_PROJECT_ROOT="$PROJECT"
COORDINATION_FILE="$PROJECT/.polylane/coordination.jsonl"
RUN_ID=prime-c11-20260807T103930Z
CYCLE=11
DRY_RUN=0
PRIME_HYBRID=1
LANE_NAMES=(alpha beta)
LANE_WORKTREES=("$TEST_TMPDIR/alpha" "$TEST_TMPDIR/beta")
LANE_MODELS=(gpt-test gpt-test)
LANE_PROMPTS=("$TEST_TMPDIR/alpha-prompt" "$TEST_TMPDIR/beta-prompt")
LANE_EFFORTS=(high high)
INT_NAME=integrator
INT_WORKTREE="$TEST_TMPDIR/integrator"
INT_MODEL=gpt-test
INT_PROMPT="$TEST_TMPDIR/integrator-prompt"
INT_EFFORT=xhigh
printf 'alpha prompt\n' > "$TEST_TMPDIR/alpha-prompt"
printf 'beta prompt\n' > "$TEST_TMPDIR/beta-prompt"
printf 'integrator prompt\n' > "$TEST_TMPDIR/integrator-prompt"

export POLYLANE_PROJECT_ROOT="$AMBIENT_PROJECT"
export POLYLANE_WORKERS_DIR="$AMBIENT_PROJECT/docs/polylane/workers"

# A previously activated local refinement may only survive when its declared
# expected check passes in the next cycle. This fixture forces the rollback.
HARNESS="$PROJECT/docs/polylane/harness"
"$SCRIPT_DIR/polylane-harness.sh" init "$HARNESS" >/dev/null
"$SCRIPT_DIR/polylane-harness.sh" create "$HARNESS" local prompt alpha-focus baseline 10 >/dev/null
"$SCRIPT_DIR/polylane-refine.sh" observe "$HARNESS" 10 failure alpha-focus first >/dev/null
"$SCRIPT_DIR/polylane-refine.sh" observe "$HARNESS" 11 failure alpha-focus second >/dev/null
"$SCRIPT_DIR/polylane-refine.sh" propose "$HARNESS" alpha-rollback 11 13 local prompt alpha-focus 1 tuned repeated -- false >/dev/null

assert_ok "prime-hybrid-prelaunch" prime_hybrid_prepare
unset POLYLANE_PROJECT_ROOT POLYLANE_WORKERS_DIR
assert_ok "prime-hybrid-harness-canonical" test -f "$HARNESS/state.json"
assert_ok "prime-hybrid-workers-canonical" test -d "$PROJECT/docs/polylane/workers/capsules"
assert_ok "prime-hybrid-alpha-packet" test -s "$PROJECT/.polylane/context/alpha.md"
assert_ok "prime-hybrid-beta-packet" test -s "$PROJECT/.polylane/context/beta.md"
assert_ok "prime-hybrid-integrator-packet" test -s "$PROJECT/.polylane/context/integrator.md"
assert_ok "prime-hybrid-packet-bounded" test "$(wc -c < "$PROJECT/.polylane/context/alpha.md" | tr -d ' ')" -le 12000
assert_contains "prime-hybrid-packet-goal" "A stranger succeeds unattended" "$(cat "$PROJECT/.polylane/context/alpha.md" 2>/dev/null || true)"
assert_contains "prime-hybrid-integrator-receives-pending-refinement" "alpha-rollback" \
  "$(cat "$PROJECT/.polylane/context/integrator.md" 2>/dev/null || true)"
assert_eq "prime-hybrid-alpha-identity-stable" "alpha" "$("$SCRIPT_DIR/polylane-workers.sh" show "$PROJECT" alpha 2>/dev/null | jq -r .name 2>/dev/null)"
assert_eq "prime-hybrid-beta-identity-stable" "beta" "$("$SCRIPT_DIR/polylane-workers.sh" show "$PROJECT" beta 2>/dev/null | jq -r .name 2>/dev/null)"
assert_eq "prime-hybrid-relay-imported" "1" "$(jq -s '[.[] | select(.event == "relay-import")] | length' "$PROJECT/docs/polylane/workers/history.jsonl" 2>/dev/null)"
assert_eq "prime-hybrid-compaction-observed" "1" "$(jq -s '[.[] | select(.kind == "compaction" and .subject == "context")] | length' "$HARNESS/refinement-observations.jsonl")"

CMD=$(pane_cmd "$TEST_TMPDIR/alpha" gpt-test "$TEST_TMPDIR/alpha-prompt" high)
assert_contains "prime-hybrid-export-alpha-harness" "POLYLANE_HARNESS_DIR=$PROJECT/docs/polylane/harness" "$CMD"
assert_contains "prime-hybrid-export-alpha-workers" "POLYLANE_WORKERS_DIR=$PROJECT/docs/polylane/workers" "$CMD"
assert_contains "prime-hybrid-export-alpha-worker-id" "POLYLANE_WORKER_ID=alpha" "$CMD"
assert_contains "prime-hybrid-export-alpha-context-packet" "POLYLANE_CONTEXT_PACKET=$PROJECT/.polylane/context/alpha.md" "$CMD"
CMD=$(pane_cmd "$TEST_TMPDIR/beta" gpt-test "$TEST_TMPDIR/beta-prompt" high)
assert_contains "prime-hybrid-export-beta-harness" "POLYLANE_HARNESS_DIR=$PROJECT/docs/polylane/harness" "$CMD"
assert_contains "prime-hybrid-export-beta-workers" "POLYLANE_WORKERS_DIR=$PROJECT/docs/polylane/workers" "$CMD"
assert_contains "prime-hybrid-export-beta-worker-id" "POLYLANE_WORKER_ID=beta" "$CMD"
assert_contains "prime-hybrid-export-beta-context-packet" "POLYLANE_CONTEXT_PACKET=$PROJECT/.polylane/context/beta.md" "$CMD"
CMD=$(pane_cmd "$TEST_TMPDIR/integrator" gpt-test "$TEST_TMPDIR/integrator-prompt" xhigh)
assert_contains "prime-hybrid-export-integrator-harness" "POLYLANE_HARNESS_DIR=$PROJECT/docs/polylane/harness" "$CMD"
assert_contains "prime-hybrid-export-integrator-workers" "POLYLANE_WORKERS_DIR=$PROJECT/docs/polylane/workers" "$CMD"
assert_contains "prime-hybrid-export-integrator-worker-id" "POLYLANE_WORKER_ID=integrator" "$CMD"
assert_contains "prime-hybrid-export-integrator-context-packet" "POLYLANE_CONTEXT_PACKET=$PROJECT/.polylane/context/integrator.md" "$CMD"

assert_ok "prime-hybrid-completion-capsule" prime_hybrid_record_completion alpha
assert_eq "prime-hybrid-completion-is-canonical" "complete" "$("$SCRIPT_DIR/polylane-workers.sh" show "$PROJECT" alpha | jq -r .status)"
assert_ok "prime-hybrid-completion-does-not-write-worktree" test ! -e "$TEST_TMPDIR/alpha/docs"

# The next cycle validates the declared check and restores the exact immutable
# snapshot. A repeated NO-GO is recorded as durable refinement evidence.
CYCLE=12
assert_ok "prime-hybrid-next-cycle-validation" prime_hybrid_validate_pending
assert_eq "prime-hybrid-failing-refinement-rolled-back" "rolled_back" "$(jq -r '.proposals["alpha-rollback"].status' "$HARNESS/refinements.json")"
assert_eq "prime-hybrid-rollback-restores-baseline" "baseline" "$("$SCRIPT_DIR/polylane-harness.sh" read "$HARNESS" local alpha-focus --json | jq -r .content)"
assert_ok "prime-hybrid-observe-no-go-first" prime_hybrid_observe no-go integrator first-no-go
assert_ok "prime-hybrid-observe-no-go-second" prime_hybrid_observe no-go integrator second-no-go
assert_ok "prime-hybrid-repeated-no-go-eligible" "$SCRIPT_DIR/polylane-refine.sh" eligible "$HARNESS" integrator
CYCLE=13
assert_ok "prime-hybrid-auto-refinement-refresh" prime_hybrid_prepare
assert_eq "prime-hybrid-auto-refinement-queued" "integrator" \
  "$(jq -r '.[0].subject' "$HARNESS/refinement-queue.json")"
assert_eq "prime-hybrid-auto-refinement-actionable" "propose-or-decline" \
  "$(jq -r '.[0].required_action' "$HARNESS/refinement-queue.json")"
assert_contains "prime-hybrid-auto-refinement-in-context" "propose-or-decline" \
  "$(cat "$PROJECT/.polylane/context/integrator.md")"

# A global prompt/skill is proposal-only. It names the real evolution gate and
# cannot become an active direct overwrite in the harness state.
mkdir -p "$PROJECT/.codex/skills/polylane"
printf 'installed skill baseline\n' > "$PROJECT/.codex/skills/polylane/SKILL.md"
GLOBAL=$("$SCRIPT_DIR/polylane-harness.sh" create "$HARNESS" global skill prompt-change staged 12)
assert_eq "prime-hybrid-global-gate-refusal" "false" "$(printf '%s' "$GLOBAL" | jq -r .active)"
assert_eq "prime-hybrid-global-gate-route" "bin/polylane-skill-evolve.sh" "$(printf '%s' "$GLOBAL" | jq -r .handoff)"
assert_ok "prime-hybrid-global-skill-not-written" test ! -e "$PROJECT/SKILL.md"
assert_eq "prime-hybrid-installed-skill-not-overwritten" "installed skill baseline" \
  "$(tr -d '\n' < "$PROJECT/.codex/skills/polylane/SKILL.md")"

# A repeat invocation is resume-idempotent: the workers retain identities and
# relay imports are deduplicated instead of mutating any lane worktree.
CYCLE=13
ALPHA_VERSION=$("$SCRIPT_DIR/polylane-workers.sh" show "$PROJECT" alpha | jq -r .version)
assert_ok "prime-hybrid-prelaunch-idempotent" prime_hybrid_prepare
assert_eq "prime-hybrid-identity-not-recreated" "$ALPHA_VERSION" "$("$SCRIPT_DIR/polylane-workers.sh" show "$PROJECT" alpha | jq -r .version)"
assert_eq "prime-hybrid-relay-import-idempotent" "1" "$(jq -s '[.[] | select(.event == "relay-import")] | length' "$PROJECT/docs/polylane/workers/history.jsonl")"

DRY_RUN=1
DRY_BEFORE=$(find "$PROJECT/docs/polylane" -type f -exec cksum {} \; | LC_ALL=C sort)
assert_ok "prime-hybrid-dryrun-pure" prime_hybrid_prepare
DRY_AFTER=$(find "$PROJECT/docs/polylane" -type f -exec cksum {} \; | LC_ALL=C sort)
assert_eq "prime-hybrid-dryrun-no-state-write" "$DRY_BEFORE" "$DRY_AFTER"

finish
