#!/usr/bin/env bash
# Hermetic contract-v3 rehearsal. It drives the real supervised runner with a
# bounded local mock and proves coordinator-owned promotion and withholding.
set -euo pipefail
BIN="$(cd "$(dirname "$0")" && pwd)"
RUN="$BIN/polylane-run.sh"; MARK="$BIN/polylane-markers.sh"

command -v tmux >/dev/null 2>&1 || { echo "rehearse: tmux required (skipping)"; exit 77; }
command -v git >/dev/null 2>&1 || { echo "rehearse: git required" >&2; exit 2; }

rehearse_create_fixture_skills() {
  local skills_root="$1" skill
  for skill in fixture-test fixture-debug fixture-review fixture-check; do
    mkdir -p "$skills_root/$skill"
    printf '%s\n' '---' "name: $skill" '---' > "$skills_root/$skill/SKILL.md"
  done
}

rehearse_fixture_runtime_path() {
  local runtime_root="$1" name="$2"
  case "$name" in
    mock-invocations|graph-witness|mockagent|rehearse.log) ;;
    *) return 2 ;;
  esac
  printf '%s/rehearse/%s\n' "$runtime_root" "$name"
}

rehearse_fixture_counter_path() {
  rehearse_fixture_runtime_path "$@"
}

rehearse_promoted_tree_clean() {
  local repo="$1" marker
  git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  # Goal finalization deliberately advances durable max-state.json before the
  # cycle report. Clean here means runtime markers are gone, not that durable
  # orchestration state was forbidden from changing.
  for marker in docs/status-lane-a.md docs/status-lane-b.md docs/status-integrator.md; do
    [ ! -e "$repo/$marker" ] || return 1
    ! git -C "$repo" ls-files --error-unmatch -- "$marker" >/dev/null 2>&1 || return 1
  done
}

rehearse() {
  local want="${1:-go}" root tmux_root tmux_parent sess nonce rc=0 report evidence stats promoted cleaned leaks=0 calls calls_path graph_witnesses graph_witness_path mockagent_path rehearse_log_path worktrees_root retained=0 tree_clean=0 terminal_gates=0 ready=0
  # A rehearse run owns a fresh tmux server.  An inherited client socket or
  # default server can belong to another host/session (for example a remote
  # Codex parent) and makes even `tmux new-session` fail before the canary.
  unset TMUX
  root=$(mktemp -d "${TMPDIR:-/tmp}/polylane-rehearse.XXXXXX")
  root=$(cd "$root" && pwd -P)
  # tmux appends /tmux-<uid>/default, so keep this socket parent short enough
  # for macOS's UNIX-domain socket length limit even when TMPDIR is long.
  tmux_parent="${TMPDIR:-/tmp}"
  tmux_parent=${tmux_parent%/}
  tmux_root=$(mktemp -d "$tmux_parent/plr-tmux.XXXXXX")
  calls_path=$(rehearse_fixture_counter_path "$tmux_root" mock-invocations)
  graph_witness_path=$(rehearse_fixture_counter_path "$tmux_root" graph-witness)
  mockagent_path=$(rehearse_fixture_runtime_path "$tmux_root" mockagent)
  rehearse_log_path=$(rehearse_fixture_runtime_path "$tmux_root" rehearse.log)
  worktrees_root="$root/.polylane/rehearse/worktrees"
  mkdir -p "$(dirname "$calls_path")"
  TMUX_TMPDIR="$tmux_root"
  export TMUX_TMPDIR
  sess="plrh-$$"; nonce="rh-$$-$(date +%s)"
  # shellcheck disable=SC2064 # expand root/session now
  trap "tmux kill-session -t '$sess' 2>/dev/null || true; rm -rf '$root' '$tmux_root'" RETURN

  (
    cd "$root"
    git init -q -b main .; git config user.email t@t; git config user.name t
    mkdir -p .polylane/lanes docs/polylane
    rehearse_create_fixture_skills "$root/skills"
    printf '%s\n' '# Goal' 'Contract-v3 rehearsal must prove supervised GO/NO-GO.' > docs/polylane/GOAL.md
    printf '%s\n' '# Acceptance' '- GO promotes.' '- NO-GO retains evidence and stops.' > docs/polylane/ACCEPTANCE.md
    printf '%s\n' '# INDEX' '- [Goal](GOAL.md)' '- [Acceptance](ACCEPTANCE.md)' '- [Cycle](cycle-plan.md)' > docs/polylane/INDEX.md
    printf '%s\n' '# Cycle plan' 'Supervisor owns lifecycle; lanes own disjoint paths.' > docs/polylane/cycle-plan.md
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json init "Contract-v3 rehearsal" >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json add-criterion c1 "GO promotes and NO-GO gates" 10 >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json add-milestone m1 "rehearsal" >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json add-subgoal m1 s1 "exercise the contract-v3 lifecycle" 10 >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json add-accept s1 'test -f a/x && test -f b/y' >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json add-accept s1 'test -f a/x && test -f b/y' --tier terminal >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-scout.sh" arm-role .polylane/lane-skills.json lane-a predefined fixture-test fixture-debug
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-scout.sh" arm-role .polylane/lane-skills.json lane-a specific fixture-review fixture-check
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-scout.sh" arm-role .polylane/lane-skills.json lane-b predefined fixture-test fixture-debug
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-scout.sh" arm-role .polylane/lane-skills.json lane-b specific fixture-review fixture-check
    printf '%s\n' 'ULTIMATE-GOAL: prove the unattended supervised lifecycle.' 'CURRENT-SUBGOAL: exercise the contract-v3 lifecycle.' "GOAL: CONTRACT-V3 nonce=$nonce lane=lane-a writes a/x." 'OWN: a/** and lane status evidence.' 'FORBIDDEN: b/**, main, and orchestration files.' 'PREDEFINED-SKILLS: fixture-test fixture-debug' 'LANE-SPECIFIC-SKILLS: fixture-review fixture-check' 'Read only the named kit once; do not enumerate or rediscover skills.' 'TEST-CADENCE: focused check before DONE.' 'DELEGATION: forbidden; no subagents or fan-out.' 'CHECK-CACHE: use polylane-check.sh with $PWD/.polylane/check-cache/ for expensive checks.' 'EXTERNAL-EVIDENCE: none.' 'VERIFY: write owned status evidence with the exact current-run DONE marker.' 'Verify owned output before DONE.' 'Supervisor owns lifecycle.' "Write docs/status-lane-a.md with STATUS: lane-a DONE run=$nonce." > .polylane/lanes/lane-a.txt
    printf '%s\n' 'ULTIMATE-GOAL: prove the unattended supervised lifecycle.' 'CURRENT-SUBGOAL: exercise the contract-v3 lifecycle.' "GOAL: CONTRACT-V3 nonce=$nonce lane=lane-b writes b/y." 'OWN: b/** and lane status evidence.' 'FORBIDDEN: a/**, main, and orchestration files.' 'PREDEFINED-SKILLS: fixture-test fixture-debug' 'LANE-SPECIFIC-SKILLS: fixture-review fixture-check' 'Read only the named kit once; do not enumerate or rediscover skills.' 'TEST-CADENCE: focused check before DONE.' 'DELEGATION: forbidden; no subagents or fan-out.' 'CHECK-CACHE: use polylane-check.sh with $PWD/.polylane/check-cache/ for expensive checks.' 'EXTERNAL-EVIDENCE: none.' 'VERIFY: write owned status evidence with the exact current-run DONE marker.' 'Verify owned output before DONE.' 'Supervisor owns lifecycle.' "Write docs/status-lane-b.md with STATUS: lane-b DONE run=$nonce." > .polylane/lanes/lane-b.txt
    printf '%s\n' 'ULTIMATE-GOAL: prove the unattended supervised lifecycle.' 'CURRENT-SUBGOAL: exercise the contract-v3 lifecycle.' "GOAL: CONTRACT-V3 nonce=$nonce integrator verifies the candidate or NO-GO." 'OWN: integrator branch and integration evidence.' 'FORBIDDEN: main and builder-owned paths before merge.' 'PREDEFINED-SKILLS: fixture-test fixture-debug' 'LANE-SPECIFIC-SKILLS: fixture-review fixture-check' 'Read only the named kit once; do not enumerate or rediscover skills.' 'TEST-CADENCE: focused acceptance then terminal acceptance.' 'DELEGATION: forbidden; no subagents or fan-out.' 'CHECK-CACHE: use polylane-check.sh with $PWD/.polylane/check-cache/ for expensive checks.' 'EXTERNAL-EVIDENCE: none.' 'VERIFY: write current-run integration evidence and one verdict sentinel.' 'Supervisor owns lifecycle.' "Write docs/status-integrator.md with STATUS: integrator DONE run=$nonce." "End docs/verify-integration.md with POLYLANE-VERDICT: READY-FOR-HOST-GATE run=$nonce or POLYLANE-VERDICT: NO-GO run=$nonce." > .polylane/lanes/integrator.txt
    printf '%s\n' seed > seed.txt
    git add -A; git commit -qm seed
  )

  cat > "$mockagent_path" <<MOCK
#!/usr/bin/env bash
set -eu
prompt="\$*"; file="\${prompt##* }"; text="\$(cat "\$file")"
case "\$text" in *"CONTRACT-V3 nonce=$nonce"*"Supervisor owns lifecycle."*) ;; *) exit 20;; esac
for required in docs/polylane/GOAL.md docs/polylane/ACCEPTANCE.md docs/polylane/INDEX.md docs/polylane/cycle-plan.md docs/polylane/max-state.json .polylane/lane-skills.json; do [ -f "\$required" ] || exit 21; done
for required in "$root/.polylane/graph.json" "$root/.polylane/events.jsonl"; do [ -f "\$required" ] || exit 21; done
graph_id="\$(jq -r '.graph_id // empty' "$root/.polylane/graph.json")"
jq -e --arg run "$nonce" '.immutable == true and .run_id == \$run' "$root/.polylane/graph.json" >/dev/null || exit 23
"$BIN/polylane-events.sh" verify "$root/.polylane/events.jsonl" "$nonce" "\$graph_id" >/dev/null || exit 24
printf '%s\n' "\$PWD" >> "$calls_path"
printf '%s\n' "\$graph_id" >> "$graph_witness_path"
mkdir -p docs
case "\$text" in
  *"lane=lane-a"*) mkdir -p a; printf '%s\n' a > a/x; { "$MARK" done lane-a "$nonce"; echo; } > docs/status-lane-a.md; git add a/x docs/status-lane-a.md; git commit -qm lane-a ;;
  *"lane=lane-b"*) mkdir -p b; printf '%s\n' b > b/y; { "$MARK" done lane-b "$nonce"; echo; } > docs/status-lane-b.md; git add b/y docs/status-lane-b.md; git commit -qm lane-b ;;
  *"integrator verifies"*) if [ "$want" = go ]; then git merge --no-edit pl/a pl/b; fi; { "$MARK" done integrator "$nonce"; echo; } > docs/status-integrator.md; if [ "$want" = go ]; then { "$MARK" verdict READY-FOR-HOST-GATE "$nonce"; echo; } > docs/verify-integration.md; else { "$MARK" verdict NO-GO "$nonce"; echo; } > docs/verify-integration.md; fi; git add docs/status-integrator.md docs/verify-integration.md; git commit -qm integrator ;;
  *) exit 22 ;;
esac
exec sleep 30
MOCK
  chmod +x "$mockagent_path"
  cat > "$root/.polylane/run.json" <<JSON
{"orchestration_contract":2,"run_id":"$nonce","cycle":1,"state_file":"docs/polylane/max-state.json","lane_skills_file":".polylane/lane-skills.json","cycle_plan_file":"docs/polylane/cycle-plan.md","target_subgoals":["s1"],"base":"main","session":"$sess","agent":"codex","codex_sandbox":"workspace-write","available_models":["gpt-5.6-terra"],"efficiency_canary":{"max_restarts":0,"max_wall_s":900},"integrator":{"name":"integrator","model":"gpt-5.6-terra","effort":"high","branch":"pl/int","worktree":"$worktrees_root/integrator","prompt_file":".polylane/lanes/integrator.txt"},"lanes":[{"name":"lane-a","model":"gpt-5.6-terra","effort":"medium","branch":"pl/a","worktree":"$worktrees_root/lane-a","prompt_file":".polylane/lanes/lane-a.txt","own_globs":["a/**"],"target_subgoals":["s1"]},{"name":"lane-b","model":"gpt-5.6-terra","effort":"medium","branch":"pl/b","worktree":"$worktrees_root/lane-b","prompt_file":".polylane/lanes/lane-b.txt","own_globs":["b/**"],"target_subgoals":["s1"]}]}
JSON

  (
    cd "$root"
    PATH="$root:$PATH" CODEX_SKILLS_DIR="$root/skills" POLYLANE_AGENT_CMD="$mockagent_path {model} {prompt}" \
      POLYLANE_SESSION="$sess" POLYLANE_POLL_INTERVAL=1 POLYLANE_HEALTH_INTERVAL=9999 POLYLANE_INTEGRATOR_REPAIRS=0 \
      "$RUN" "$root/.polylane/run.json" --yes > "$rehearse_log_path" 2>&1 || true
  )
  if [ "${POLYLANE_REHEARSE_DEBUG:-0}" = "1" ]; then
    sed -n '1,240p' "$rehearse_log_path" >&2
  fi
  report="$root/docs/polylane-report.md"
  stats="$root/docs/polylane/run-stats.json"
  if [ "$want" = go ]; then
    evidence="$root/docs/verify-integration.md"
  else
    evidence="$worktrees_root/integrator/docs/verify-integration.md"
  fi
  calls=$([ -f "$calls_path" ] && wc -l < "$calls_path" | tr -d ' ' || echo 0)
  graph_witnesses=$([ -f "$graph_witness_path" ] && wc -l < "$graph_witness_path" | tr -d ' ' || echo 0)
  terminal_gates=$(jq -r '.terminal_gates // 0' "$stats" 2>/dev/null || echo 0)
  if tmux has-session -t "$sess" 2>/dev/null || git -C "$root" worktree list --porcelain | grep -q "worktree $worktrees_root/"; then leaks=1; fi
  [ "$graph_witnesses" = 3 ] || rc=1
  if [ "$want" = go ]; then
    git -C "$root" show main:a/x >/dev/null 2>&1 && git -C "$root" show main:b/y >/dev/null 2>&1 || rc=1
    grep -qE 'Outcome:\*\*[[:space:]]*GO|^\*\*GO\*\*' "$report" 2>/dev/null || rc=1
    grep -qx "POLYLANE-VERDICT: READY-FOR-HOST-GATE run=$nonce" "$evidence" 2>/dev/null && ready=1 || rc=1
    [ "$terminal_gates" = 1 ] || rc=1
    [ "$calls" = 3 ] || rc=1
    [ "$leaks" = 0 ] || rc=1
    if rehearse_promoted_tree_clean "$root"; then tree_clean=1; else rc=1; fi
    [ "$rc" = 0 ] && promoted=1 || promoted=0
    [ "$leaks" = 0 ] && [ "$tree_clean" = 1 ] && cleaned=1 || cleaned=0
    tmux kill-session -t "$sess" 2>/dev/null || true; rm -rf "$root" "$tmux_root"; trap - RETURN
    [ ! -e "$root" ] && [ ! -e "$tmux_root" ] || { leaks=1; rc=1; }
    echo "REHEARSE-GO contract-v3=1 ready=$ready promoted=$promoted terminal_gates=$terminal_gates cleaned=$cleaned leaks=$leaks"
  else
    [ -f "$evidence" ] && grep -q 'NO-GO' "$evidence" && ! git -C "$root" show main:a/x >/dev/null 2>&1 || rc=1
    [ "$calls" = 3 ] || rc=1
    if tmux has-session -t "$sess" 2>/dev/null &&
       git -C "$root" worktree list --porcelain | grep -q "worktree $worktrees_root/"; then
      retained=1
    else
      rc=1
    fi
    [ "$rc" = 0 ] && evidence=1 || evidence=0
    [ "$calls" = 3 ] && bounded=1 || bounded=0
    tmux kill-session -t "$sess" 2>/dev/null || true; rm -rf "$root" "$tmux_root"; trap - RETURN
    [ ! -e "$root" ] && [ ! -e "$tmux_root" ] || { leaks=1; rc=1; }
    [ "$leaks" = 1 ] || rc=1
    [ ! -e "$root" ] && [ ! -e "$tmux_root" ] && cleaned=1 || cleaned=0
    echo "REHEARSE-NOGO contract-v3=1 promoted=0 evidence=$evidence retained=$retained bounded=$bounded cleaned=$cleaned"
  fi
  return "$rc"
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  case "${1:-go}" in go|nogo) rehearse "$1" ;; *) echo "usage: polylane-rehearse.sh [go|nogo]" >&2; exit 2 ;; esac
fi
