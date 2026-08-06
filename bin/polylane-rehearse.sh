#!/usr/bin/env bash
# Hermetic contract-v2 rehearsal.  It drives the real supervised runner with a
# bounded local mock and proves both promote and withheld-verdict lifecycles.
set -euo pipefail
BIN="$(cd "$(dirname "$0")" && pwd)"
RUN="$BIN/polylane-run.sh"; MARK="$BIN/polylane-markers.sh"

command -v tmux >/dev/null 2>&1 || { echo "rehearse: tmux required (skipping)"; exit 77; }
command -v git >/dev/null 2>&1 || { echo "rehearse: git required" >&2; exit 2; }

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
  local want="${1:-go}" root sess nonce rc=0 report evidence promoted cleaned leaks=0 calls graph_witnesses retained=0 tree_clean=0
  root=$(mktemp -d "${TMPDIR:-/tmp}/polylane-rehearse.XXXXXX")
  root=$(cd "$root" && pwd -P)
  sess="plrh-$$"; nonce="rh-$$-$(date +%s)"
  # shellcheck disable=SC2064 # expand root/session now
  trap "tmux kill-session -t '$sess' 2>/dev/null || true; rm -rf '$root'" RETURN

  (
    cd "$root"
    git init -q -b main .; git config user.email t@t; git config user.name t
    mkdir -p .polylane/lanes docs/polylane "$root/skills/fixture-test" \
      "$root/skills/fixture-debug" "$root/skills/fixture-review" "$root/skills/fixture-check"
    printf '%s\n' '# Goal' 'Contract-v2 rehearsal must prove supervised GO/NO-GO.' > docs/polylane/GOAL.md
    printf '%s\n' '# Acceptance' '- GO promotes.' '- NO-GO retains evidence and stops.' > docs/polylane/ACCEPTANCE.md
    printf '%s\n' '# INDEX' '- [Goal](GOAL.md)' '- [Acceptance](ACCEPTANCE.md)' '- [Cycle](cycle-plan.md)' > docs/polylane/INDEX.md
    printf '%s\n' '# Cycle plan' 'Supervisor owns lifecycle; lanes own disjoint paths.' > docs/polylane/cycle-plan.md
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json init "Contract-v2 rehearsal" >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json add-criterion c1 "GO promotes and NO-GO gates" 10 >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json add-milestone m1 "rehearsal" >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json add-subgoal m1 s1 "exercise the contract-v2 lifecycle" 10 >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json add-accept s1 'test -f a/x && test -f b/y' >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-memory.sh" docs/polylane/max-state.json add-accept s1 'test -f a/x && test -f b/y' --tier terminal >/dev/null
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-scout.sh" arm-role .polylane/lane-skills.json lane-a predefined fixture-test fixture-debug
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-scout.sh" arm-role .polylane/lane-skills.json lane-a specific fixture-review fixture-check
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-scout.sh" arm-role .polylane/lane-skills.json lane-b predefined fixture-test fixture-debug
    CODEX_SKILLS_DIR="$root/skills" "$BIN/polylane-scout.sh" arm-role .polylane/lane-skills.json lane-b specific fixture-review fixture-check
    printf '%s\n' "GOAL: CONTRACT-V2 nonce=$nonce lane=lane-a writes a/x." 'OWN: a/** and lane status evidence.' 'FORBIDDEN: b/**, main, and orchestration files.' 'PREDEFINED-SKILLS: fixture-test fixture-debug' 'LANE-SPECIFIC-SKILLS: fixture-review fixture-check' 'TEST-CADENCE: focused check before DONE.' 'DELEGATION: forbidden; no subagents or fan-out.' 'CHECK-CACHE: use polylane-check.sh for expensive checks.' 'EXTERNAL-EVIDENCE: none.' 'Verify owned output before DONE.' 'Supervisor owns lifecycle.' "Write docs/status-lane-a.md with STATUS: lane-a DONE run=$nonce." > .polylane/lanes/lane-a.txt
    printf '%s\n' "GOAL: CONTRACT-V2 nonce=$nonce lane=lane-b writes b/y." 'OWN: b/** and lane status evidence.' 'FORBIDDEN: a/**, main, and orchestration files.' 'PREDEFINED-SKILLS: fixture-test fixture-debug' 'LANE-SPECIFIC-SKILLS: fixture-review fixture-check' 'TEST-CADENCE: focused check before DONE.' 'DELEGATION: forbidden; no subagents or fan-out.' 'CHECK-CACHE: use polylane-check.sh for expensive checks.' 'EXTERNAL-EVIDENCE: none.' 'Verify owned output before DONE.' 'Supervisor owns lifecycle.' "Write docs/status-lane-b.md with STATUS: lane-b DONE run=$nonce." > .polylane/lanes/lane-b.txt
    printf '%s\n' "GOAL: CONTRACT-V2 nonce=$nonce integrator verifies GO or NO-GO." 'OWN: integrator branch and integration evidence.' 'FORBIDDEN: main and builder-owned paths before merge.' 'PREDEFINED-SKILLS: fixture-test fixture-debug' 'LANE-SPECIFIC-SKILLS: fixture-review fixture-check' 'TEST-CADENCE: focused acceptance then terminal acceptance.' 'DELEGATION: forbidden; no subagents or fan-out.' 'CHECK-CACHE: use polylane-check.sh for expensive checks.' 'EXTERNAL-EVIDENCE: none.' 'Supervisor owns lifecycle.' "Write docs/status-integrator.md with STATUS: integrator DONE run=$nonce." "End docs/verify-integration.md with POLYLANE-VERDICT: GO run=$nonce or POLYLANE-VERDICT: NO-GO run=$nonce." > .polylane/lanes/integrator.txt
    printf '%s\n' seed > seed.txt
    git add -A; git commit -qm seed
  )

  cat > "$root/mockagent" <<MOCK
#!/usr/bin/env bash
set -eu
prompt="\$*"; file="\${prompt##* }"; text="\$(cat "\$file")"
case "\$text" in *"CONTRACT-V2 nonce=$nonce"*"Supervisor owns lifecycle."*) ;; *) exit 20;; esac
for required in docs/polylane/GOAL.md docs/polylane/ACCEPTANCE.md docs/polylane/INDEX.md docs/polylane/cycle-plan.md docs/polylane/max-state.json .polylane/lane-skills.json; do [ -f "\$required" ] || exit 21; done
for required in "$root/.polylane/graph.json" "$root/.polylane/events.jsonl"; do [ -f "\$required" ] || exit 21; done
graph_id="\$(jq -r '.graph_id // empty' "$root/.polylane/graph.json")"
jq -e --arg run "$nonce" '.immutable == true and .run_id == \$run' "$root/.polylane/graph.json" >/dev/null || exit 23
"$BIN/polylane-events.sh" verify "$root/.polylane/events.jsonl" "$nonce" "\$graph_id" >/dev/null || exit 24
printf '%s\n' "\$PWD" >> "$root/mock-invocations"
printf '%s\n' "\$graph_id" >> "$root/graph-witness"
mkdir -p docs
case "\$text" in
  *"lane=lane-a"*) mkdir -p a; printf '%s\n' a > a/x; { "$MARK" done lane-a "$nonce"; echo; } > docs/status-lane-a.md; git add a/x docs/status-lane-a.md; git commit -qm lane-a ;;
  *"lane=lane-b"*) mkdir -p b; printf '%s\n' b > b/y; { "$MARK" done lane-b "$nonce"; echo; } > docs/status-lane-b.md; git add b/y docs/status-lane-b.md; git commit -qm lane-b ;;
  *"integrator verifies"*) if [ "$want" = go ]; then git merge --no-edit pl/a pl/b; fi; { "$MARK" done integrator "$nonce"; echo; } > docs/status-integrator.md; if [ "$want" = go ]; then { "$MARK" verdict GO "$nonce"; echo; } > docs/verify-integration.md; else { "$MARK" verdict NO-GO "$nonce"; echo; } > docs/verify-integration.md; fi; git add docs/status-integrator.md docs/verify-integration.md; git commit -qm integrator ;;
  *) exit 22 ;;
esac
exec sleep 30
MOCK
  chmod +x "$root/mockagent"
  cat > "$root/.polylane/run.json" <<JSON
{"orchestration_contract":2,"run_id":"$nonce","cycle":1,"state_file":"docs/polylane/max-state.json","lane_skills_file":".polylane/lane-skills.json","cycle_plan_file":"docs/polylane/cycle-plan.md","target_subgoals":["s1"],"base":"main","session":"$sess","agent":"codex","codex_sandbox":"workspace-write","available_models":["gpt-5.6-terra"],"integrator":{"name":"integrator","model":"gpt-5.6-terra","effort":"high","branch":"pl/int","worktree":"$root/wt-int","prompt_file":".polylane/lanes/integrator.txt"},"lanes":[{"name":"lane-a","model":"gpt-5.6-terra","effort":"medium","branch":"pl/a","worktree":"$root/wt-a","prompt_file":".polylane/lanes/lane-a.txt","own_globs":["a/**"],"target_subgoals":["s1"]},{"name":"lane-b","model":"gpt-5.6-terra","effort":"medium","branch":"pl/b","worktree":"$root/wt-b","prompt_file":".polylane/lanes/lane-b.txt","own_globs":["b/**"],"target_subgoals":["s1"]}]}
JSON

  (
    cd "$root"
    PATH="$root:$PATH" CODEX_SKILLS_DIR="$root/skills" POLYLANE_AGENT_CMD="$root/mockagent {model} {prompt}" \
      POLYLANE_SESSION="$sess" POLYLANE_POLL_INTERVAL=1 POLYLANE_HEALTH_INTERVAL=9999 POLYLANE_INTEGRATOR_REPAIRS=0 \
      "$RUN" "$root/.polylane/run.json" --yes > "$root/rehearse.log" 2>&1 || true
  )
  if [ "${POLYLANE_REHEARSE_DEBUG:-0}" = "1" ]; then
    sed -n '1,240p' "$root/rehearse.log" >&2
  fi
  report="$root/docs/polylane-report.md"; evidence="$root/docs/verify-integration.md"
  calls=$([ -f "$root/mock-invocations" ] && wc -l < "$root/mock-invocations" | tr -d ' ' || echo 0)
  graph_witnesses=$([ -f "$root/graph-witness" ] && wc -l < "$root/graph-witness" | tr -d ' ' || echo 0)
  if tmux has-session -t "$sess" 2>/dev/null || git -C "$root" worktree list --porcelain | grep -q "worktree $root/wt"; then leaks=1; fi
  [ "$graph_witnesses" = 3 ] || rc=1
  if [ "$want" = go ]; then
    git -C "$root" show main:a/x >/dev/null 2>&1 && git -C "$root" show main:b/y >/dev/null 2>&1 || rc=1
    grep -qE 'Outcome:\*\*[[:space:]]*GO|^\*\*GO\*\*' "$report" 2>/dev/null || rc=1
    [ "$calls" = 3 ] || rc=1
    [ "$leaks" = 0 ] || rc=1
    if rehearse_promoted_tree_clean "$root"; then tree_clean=1; else rc=1; fi
    [ "$rc" = 0 ] && promoted=1 || promoted=0
    [ "$leaks" = 0 ] && [ "$tree_clean" = 1 ] && cleaned=1 || cleaned=0
    tmux kill-session -t "$sess" 2>/dev/null || true; rm -rf "$root"; trap - RETURN
    [ ! -e "$root" ] || { leaks=1; rc=1; }
    echo "REHEARSE-GO contract-v2=1 promoted=$promoted cleaned=$cleaned leaks=$leaks"
  else
    [ -f "$evidence" ] && grep -q 'NO-GO' "$evidence" && ! git -C "$root" show main:a/x >/dev/null 2>&1 || rc=1
    [ "$calls" = 3 ] || rc=1
    if tmux has-session -t "$sess" 2>/dev/null &&
       git -C "$root" worktree list --porcelain | grep -q "worktree $root/wt"; then
      retained=1
    else
      rc=1
    fi
    [ "$rc" = 0 ] && evidence=1 || evidence=0
    [ "$calls" = 3 ] && bounded=1 || bounded=0
    tmux kill-session -t "$sess" 2>/dev/null || true; rm -rf "$root"; trap - RETURN
    [ ! -e "$root" ] || { leaks=1; rc=1; }
    [ "$leaks" = 1 ] || rc=1
    [ ! -e "$root" ] && cleaned=1 || cleaned=0
    echo "REHEARSE-NOGO contract-v2=1 promoted=0 evidence=$evidence retained=$retained bounded=$bounded cleaned=$cleaned"
  fi
  return "$rc"
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  case "${1:-go}" in go|nogo) rehearse "$1" ;; *) echo "usage: polylane-rehearse.sh [go|nogo]" >&2; exit 2 ;; esac
fi
