#!/usr/bin/env bash
# Hermetic contract-v2 rehearsal.  It drives the real supervised runner with a
# bounded local mock and proves both promote and withheld-verdict lifecycles.
set -euo pipefail
BIN="$(cd "$(dirname "$0")" && pwd)"
RUN="$BIN/polylane-run.sh"; MARK="$BIN/polylane-markers.sh"

command -v tmux >/dev/null 2>&1 || { echo "rehearse: tmux required (skipping)"; exit 77; }
command -v git >/dev/null 2>&1 || { echo "rehearse: git required" >&2; exit 2; }

rehearse() {
  local want="${1:-go}" root sess nonce rc=0 report evidence promoted cleaned leaks=0 calls graph_hash events_hash
  root=$(mktemp -d "${TMPDIR:-/tmp}/polylane-rehearse.XXXXXX")
  sess="plrh-$$"; nonce="rh-$$-$(date +%s)"
  # shellcheck disable=SC2064 # expand root/session now
  trap "tmux kill-session -t '$sess' 2>/dev/null || true; rm -rf '$root'" RETURN

  (
    cd "$root"
    git init -q -b main .; git config user.email t@t; git config user.name t
    mkdir -p .polylane/lanes .polylane/skills/codex docs/polylane
    printf '%s\n' '# Goal' 'Contract-v2 rehearsal must prove supervised GO/NO-GO.' > docs/polylane/GOAL.md
    printf '%s\n' '# Acceptance' '- GO promotes.' '- NO-GO retains evidence and stops.' > docs/polylane/ACCEPTANCE.md
    printf '%s\n' '# INDEX' '- [Goal](GOAL.md)' '- [Acceptance](ACCEPTANCE.md)' '- [Cycle](cycle-plan.md)' > docs/polylane/INDEX.md
    printf '%s\n' '# Cycle plan' 'Supervisor owns lifecycle; lanes own disjoint paths.' > docs/polylane/cycle-plan.md
    printf '%s\n' '{"kit":"codex","contract":"v2","skills":["test-driven-development","verification-before-completion"]}' > .polylane/skills/codex/kit.json
    printf '%s\n' '{"graph":"authoritative","version":2}' > .polylane/graph.jsonl
    printf '%s\n' '{"event":"fixture-created","version":2}' > .polylane/events.jsonl
    chmod 444 .polylane/graph.jsonl .polylane/events.jsonl
    printf '%s\n' "CONTRACT-V2 nonce=$nonce lane=lane-a owner=a/**" "Read docs/polylane/GOAL.md and docs/polylane/ACCEPTANCE.md." "Use installed kit .polylane/skills/codex/kit.json." "Write only a/x. Supervisor owns lifecycle." > .polylane/lanes/lane-a.txt
    printf '%s\n' "CONTRACT-V2 nonce=$nonce lane=lane-b owner=b/**" "Read docs/polylane/GOAL.md and docs/polylane/ACCEPTANCE.md." "Use installed kit .polylane/skills/codex/kit.json." "Write only b/y. Supervisor owns lifecycle." > .polylane/lanes/lane-b.txt
    printf '%s\n' "CONTRACT-V2 nonce=$nonce lane=integrator owner=docs/**" "Read docs/polylane/INDEX.md and docs/polylane/cycle-plan.md." "Verify immutable .polylane/graph.jsonl and .polylane/events.jsonl. Supervisor owns lifecycle." > .polylane/lanes/integrator.txt
    printf '%s\n' seed > seed.txt
    git add -A; git commit -qm seed
  )

  cat > "$root/mockagent" <<MOCK
#!/usr/bin/env bash
set -eu
prompt="\$*"; file="\${prompt##* }"; text="\$(cat "\$file")"
case "\$text" in *"CONTRACT-V2 nonce=$nonce"*"Supervisor owns lifecycle."*) ;; *) exit 20;; esac
for required in docs/polylane/GOAL.md docs/polylane/ACCEPTANCE.md docs/polylane/INDEX.md docs/polylane/cycle-plan.md .polylane/skills/codex/kit.json .polylane/graph.jsonl .polylane/events.jsonl; do [ -f "\$required" ] || exit 21; done
printf '%s\n' "\$PWD" >> "$root/.polylane/mock-invocations"
mkdir -p docs
case "\$text" in
  *"lane=lane-a"*) mkdir -p a; printf '%s\n' a > a/x; git add a/x; git commit -qm lane-a; { "$MARK" done lane-a "$nonce"; echo; } > docs/status-lane-a.md ;;
  *"lane=lane-b"*) mkdir -p b; printf '%s\n' b > b/y; git add b/y; git commit -qm lane-b; { "$MARK" done lane-b "$nonce"; echo; } > docs/status-lane-b.md ;;
  *"lane=integrator"*) { "$MARK" done integrator "$nonce"; echo; } > docs/status-integrator.md; if [ "$want" = go ]; then { "$MARK" verdict GO "$nonce"; echo; } > docs/verify-integration.md; else { "$MARK" verdict NO-GO "$nonce"; echo; } > docs/verify-integration.md; fi ;;
  *) exit 22 ;;
esac
exec sleep 30
MOCK
  chmod +x "$root/mockagent"
  cat > "$root/.polylane/run.json" <<JSON
{"contract_version":2,"base":"main","run_id":"$nonce","supervisor":{"owner":"supervisor","lifecycle":"authoritative"},"state":{"goal":"docs/polylane/GOAL.md","acceptance":"docs/polylane/ACCEPTANCE.md","index":"docs/polylane/INDEX.md","plan":"docs/polylane/cycle-plan.md","graph":".polylane/graph.jsonl","events":".polylane/events.jsonl"},"integrator":{"name":"integrator","model":"gpt-5.6-terra","effort":"medium","branch":"pl/int","worktree":"$root/wt-int","prompt_file":"$root/.polylane/lanes/integrator.txt"},"lanes":[{"name":"lane-a","model":"gpt-5.6-terra","effort":"medium","branch":"pl/a","worktree":"$root/wt-a","prompt_file":"$root/.polylane/lanes/lane-a.txt","own_globs":["a/**"]},{"name":"lane-b","model":"gpt-5.6-terra","effort":"medium","branch":"pl/b","worktree":"$root/wt-b","prompt_file":"$root/.polylane/lanes/lane-b.txt","own_globs":["b/**"]}]}
JSON
  graph_hash=$(cksum "$root/.polylane/graph.jsonl")
  events_hash=$(cksum "$root/.polylane/events.jsonl")

  (
    cd "$root"
    PATH="$root:$PATH" POLYLANE_AGENT_CMD="$root/mockagent {model} {prompt}" \
      POLYLANE_SESSION="$sess" POLYLANE_POLL_INTERVAL=1 POLYLANE_HEALTH_INTERVAL=9999 \
      "$RUN" "$root/.polylane/run.json" --yes > "$root/rehearse.log" 2>&1 || true
  )

  report="$root/docs/polylane-report.md"; evidence="$root/docs/verify-integration.md"
  calls=$([ -f "$root/.polylane/mock-invocations" ] && wc -l < "$root/.polylane/mock-invocations" || echo 0)
  if tmux has-session -t "$sess" 2>/dev/null || git -C "$root" worktree list --porcelain | grep -q "worktree $root/wt"; then leaks=1; fi
  [ "$graph_hash" = "$(cksum "$root/.polylane/graph.jsonl")" ] || rc=1
  [ "$events_hash" = "$(cksum "$root/.polylane/events.jsonl")" ] || rc=1
  if [ "$want" = go ]; then
    git -C "$root" show main:a/x >/dev/null 2>&1 && git -C "$root" show main:b/y >/dev/null 2>&1 || rc=1
    grep -qE 'Outcome:\*\*[[:space:]]*GO|^\*\*GO\*\*' "$report" 2>/dev/null || rc=1
    [ "$calls" = 3 ] || rc=1
    [ "$leaks" = 0 ] || rc=1
    [ "$rc" = 0 ] && promoted=1 || promoted=0
    [ "$leaks" = 0 ] && cleaned=1 || cleaned=0
    tmux kill-session -t "$sess" 2>/dev/null || true; rm -rf "$root"; trap - RETURN
    [ ! -e "$root" ] || { leaks=1; rc=1; }
    echo "REHEARSE-GO contract-v2=1 promoted=$promoted cleaned=$cleaned leaks=$leaks"
  else
    [ -f "$evidence" ] && grep -q 'NO-GO' "$evidence" && ! git -C "$root" show main:a/x >/dev/null 2>&1 || rc=1
    [ "$calls" = 3 ] || rc=1
    [ "$leaks" = 0 ] || rc=1
    [ "$rc" = 0 ] && evidence=1 || evidence=0
    [ "$calls" = 3 ] && bounded=1 || bounded=0
    tmux kill-session -t "$sess" 2>/dev/null || true; rm -rf "$root"; trap - RETURN
    [ ! -e "$root" ] || { leaks=1; rc=1; }
    echo "REHEARSE-NOGO contract-v2=1 promoted=0 evidence=$evidence bounded=$bounded leaks=$leaks"
  fi
  return "$rc"
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  case "${1:-go}" in go|nogo) rehearse "$1" ;; *) echo "usage: polylane-rehearse.sh [go|nogo]" >&2; exit 2 ;; esac
fi
