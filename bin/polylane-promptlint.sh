#!/usr/bin/env bash
# polylane-promptlint.sh — deterministic gate on a GENERATED lane prompt before launch.
# The orchestrator writes each .polylane/lanes/<lane>.txt with an LLM, so a block can be
# dropped (the marker-drift + missing-OWN/FORBIDDEN bugs were exactly this). This lints
# for the empirically-validated structure — objective, tool/file boundaries, the nonce
# DONE contract, verify evidence — the way DSPy/promptfoo enforce prompt quality, but
# cheap and offline (the prompts are generated fresh per lane, so there's nothing to
# compile). Reports PROMPT-LINT: <lane> missing <what>; exit 6 if any lane fails.
#   lint <lane-prompt-file> [<lane-name>]     one prompt
#   lint-run <manifest>                        every lane's prompt in a run.json
# Pure bash-3.2 + jq (jq only for lint-run); main-guarded.
set -euo pipefail

# required token -> human label. A prompt must contain each (case-insensitive).
lint_one() {
  local f="$1" lane="${2:-$(basename "$1" .txt)}" prime_hybrid="${3:-false}" role="${4:-builder}" agent="${5:-${POLYLANE_LINT_AGENT:-claude}}" ui="${6:-0}" miss="" planned_count
  [ -s "$f" ] || { echo "PROMPT-LINT: $lane empty-or-missing $f"; return 6; }
  grep -qiE 'GOAL|/goal' "$f"        || miss="$miss objective(GOAL)"
  grep -q   'ULTIMATE-GOAL:' "$f"    || miss="$miss ultimate-goal"
  grep -q   'CURRENT-SUBGOAL:' "$f"  || miss="$miss current-subgoal"
  grep -qi  'OWN'  "$f"              || miss="$miss ownership(OWN)"
  grep -qi  'FORBIDDEN' "$f"         || miss="$miss boundaries(FORBIDDEN)"
  grep -qE  'STATUS:.*DONE'  "$f"    || miss="$miss done-marker(STATUS:..DONE)"
  grep -q   'run='  "$f"             || miss="$miss nonce(run=<RUN_ID>)"
  grep -qi  'verify' "$f"            || miss="$miss verify-evidence"
  if [ "${POLYLANE_STRICT_PROMPTS:-0}" = "1" ]; then
    grep -qE '^[[:space:]]*GOAL:' "$f" || miss="$miss goal-contract"
    grep -qi 'PREDEFINED-SKILLS:' "$f"    || miss="$miss predefined-skills"
    grep -qi 'LANE-SPECIFIC-SKILLS:' "$f" || miss="$miss lane-specific-skills"
    grep -qi 'TEST-CADENCE:' "$f"         || miss="$miss test-cadence"
    grep -qi 'DELEGATION:' "$f"           || miss="$miss delegation-policy"
    grep -qi 'CHECK-CACHE:' "$f"          || miss="$miss check-cache"
    grep -qF '$PWD/.polylane/check-cache/' "$f" || miss="$miss worktree-local-check-cache"
    grep -qi 'Read only the named kit once' "$f" || miss="$miss selected-kit-once"
    grep -qiE '^[[:space:]]*(browse|list|find) .*skill' "$f" && miss="$miss skill-inventory-dump"
    grep -qi 'EXTERNAL-EVIDENCE:' "$f"    || miss="$miss external-evidence-routing"
    exact_once_labels "$f" || miss="$miss duplicate-exact-once-label"
  fi
  if [ "${POLYLANE_RUNTIME_COMPILED:-0}" = "1" ]; then
    grep -qF 'POLYLANE-RUNTIME-RELAY:' "$f" || miss="$miss runtime-relay-contract"
    grep -qF 'POLYLANE-RUNTIME-ROOTS: source edits/tests/Graphify use "$POLYLANE_SOURCE_ROOT"' "$f" || miss="$miss runtime-roots-contract"
    grep -qF '${POLYLANE_SOURCE_ROOT:-$PWD}/graphify-out/q.py' "$f" || miss="$miss runtime-source-graphify-command"
    grep -qF 'coordination/workers/harness use "$POLYLANE_PROJECT_ROOT".' "$f" || miss="$miss runtime-control-root-contract"
    grep -qF 'COORD="$POLYLANE_PROJECT_ROOT/bin/polylane-coordinate.sh"; "$COORD" pending "$POLYLANE_COORDINATION_FILE"' "$f" || miss="$miss runtime-relay-command"
    grep -qF 'docs/parallel-status.md is post-cycle evidence only, never the live relay.' "$f" || miss="$miss runtime-relay-boundary"
    if [ "$role" = integrator ]; then
      grep -qF "POLYLANE-RUNTIME-DONE: write docs/status-$lane.md" "$f" || miss="$miss runtime-done-path"
      grep -qF 'never write a POLYLANE-VERDICT line in docs/status-' "$f" || miss="$miss runtime-status-forbids-verdict"
      grep -qF 'only verdict sentinel as the final line of docs/verify-integration.md' "$f" || miss="$miss runtime-verdict-path"
      integrator_verdict_boundary_canonical "$f" || miss="$miss contradictory-verdict-boundary"
    else
      grep -qF "POLYLANE-RUNTIME-DONE: write only docs/status-$lane.md;" "$f" || miss="$miss runtime-done-path"
    fi
    grep -qF "STATUS: $lane DONE run=" "$f" || miss="$miss runtime-done-marker"
    runtime_finalize_contract "$f" "$role" || miss="$miss runtime-finalize-contract"
    runtime_exact_once "$f" || miss="$miss duplicate-runtime-contract"
    if [ "${POLYLANE_WRITE_PLAN_CONTRACT:-0}" = "1" ] && [ "$role" = builder ]; then
      planned_count=$(grep -c '^PLANNED-WRITES:' "$f" || true)
      [ "$planned_count" -eq 1 ] && grep -qE '^PLANNED-WRITES: [^[:space:]]' "$f" ||
        miss="$miss planned-write-boundary-exact-once"
    fi
    grep -qiE 'polylane-refine\.sh[^[:alnum:]_-]+propose-or-decline' "$f" && miss="$miss fictional-refine-subcommand"
    if [ "$role" = builder ]; then
      builder_status_paths_canonical "$f" "$lane" || miss="$miss conflicting-status-path"
    fi
  fi
  if [ "$prime_hybrid" = true ]; then
    grep -q 'POLYLANE_CONTEXT_PACKET' "$f" || miss="$miss prime-hybrid-context-packet"
    grep -qF '"$POLYLANE_PROJECT_ROOT/bin/polylane-workers.sh" inbox "$POLYLANE_PROJECT_ROOT" "$POLYLANE_WORKER_ID"' "$f" || miss="$miss prime-hybrid-exact-inbox-command"
    if [ "$role" = integrator ]; then
      grep -qF '"$POLYLANE_PROJECT_ROOT/bin/polylane-refine.sh" queue "$POLYLANE_HARNESS_DIR"' "$f" || miss="$miss prime-hybrid-refinement-queue"
      grep -qF 'exactly one real `propose` or `decline`' "$f" || miss="$miss prime-hybrid-refinement-decision"
      grep -qF '`propose-or-decline` is NOT a subcommand' "$f" || miss="$miss prime-hybrid-refinement-not-subcommand"
    fi
  fi
  # Manifest-derived UI profile: a surface:"ui" lane's compiled prompt must carry
  # all five UI-* scalars and keep the verdict with the coordinator. A UI scalar
  # appearing on a non-UI lane is still exact-once, but is never required there.
  if [ "$ui" = 1 ]; then
    local uilbl
    for uilbl in UI-CONTRACT UI-IMPLEMENT UI-CONTENT UI-EVIDENCE UI-REVIEW-BOUNDARY; do
      grep -qE "^[[:space:]]*$uilbl:" "$f" || miss="$miss ui-scalar($uilbl)"
    done
    if grep -qE '^[[:space:]]*UI-REVIEW-BOUNDARY:' "$f"; then
      grep -iE '^[[:space:]]*UI-REVIEW-BOUNDARY:' "$f" | grep -qi 'coordinator' || miss="$miss ui-verdict-not-coordinator-owned"
    fi
  fi
  if grep -qiE '^[[:space:]]*UI-REVIEW-BOUNDARY:.*builder (may|can|is allowed to) (self-certify|grade)' "$f"; then
    miss="$miss builder-owned-verdict"
  fi
  provider_syntax_leakage "$f" "$agent" && miss="$miss provider-syntax-leakage"
  if [ -n "$miss" ]; then echo "PROMPT-LINT: $lane missing$miss"; return 6; fi
  return 0
}

# Native preambles come from manifest.agent. A compiled Codex prompt must not
# carry Claude-only launch idioms (`/model`, `ultrathink`, a Claude model id, or
# a CLAUDE.md memory assumption); a compiled Claude prompt must not carry
# Codex-only launch syntax. Returns 0 (true) when leakage is found.
provider_syntax_leakage() {
  local f="$1" agent="$2"
  case "$agent" in
    codex|gpt|openai)
      grep -qiE '(^|[^a-z])/model([^a-z]|$)|ultrathink|claude-(opus|sonnet|haiku|fable)|CLAUDE\.md' "$f" && return 0
      ;;
    *)  # claude and anything Claude-native
      grep -qiE 'codex exec|--dangerously-bypass-approvals|--sandbox[= ]|codex_sandbox' "$f" && return 0
      ;;
  esac
  return 1
}

builder_status_paths_canonical() {
  local f="$1" lane="$2" canonical="docs/status-$2.md" path paths
  paths=$(grep -oE 'docs/status-[A-Za-z0-9._-]+\.md' "$f" 2>/dev/null | LC_ALL=C sort -u || true)
  [ -n "$paths" ] || return 1
  for path in $paths; do
    [ "$path" = "$canonical" ] || return 1
  done
}

# The status handoff is intentionally verdict-free.  Reject both the historical
# generic wording and an explicit second sentinel destination before launch.
integrator_verdict_boundary_canonical() {
  local f="$1"
  grep -qiE '(current-run )?status( file)? and (its |the )?integrator verdict' "$f" && return 1
  if grep -ivE 'never write a POLYLANE-VERDICT line in docs/status-' "$f" |
    grep -qiE 'write[^.]*POLYLANE-VERDICT[^.]*in docs/status-'; then
    return 1
  fi
  return 0
}

runtime_exact_once() {
  local f="$1" label count
  for label in POLYLANE-RUNTIME-RELAY POLYLANE-RUNTIME-ROOTS POLYLANE-RUNTIME-DONE POLYLANE-RUNTIME-FINALIZE; do
    count=$(grep -cF "$label:" "$f" || true)
    [ "$count" -eq 1 ] || return 1
  done
}

# The finalization block is deliberately literal: this is a launch gate for a
# generated prompt, not advice that an agent may paraphrase or reorder.
runtime_finalize_contract() {
  local f="$1" role="$2" line
  line=$(grep -F 'POLYLANE-RUNTIME-FINALIZE:' "$f" || true)
  [ -n "$line" ] || return 1
  case "$line" in
    *'final relay and durable inbox read'*'handle all addressed autonomous work'*'run focused verification'*'scope-stage every owned changed or new file'*'commit implementation and evidence'*'git status --short'*'.polylane-prompt.txt'*'graphify-out'*'commit that final handoff, and immediately exit'*'No reads, tests, edits, relay decisions, or commits may follow the marker/verdict commit.') : ;;
    *) return 1 ;;
  esac
  printf '%s\n' "$line" | grep -qF 'final relay and durable inbox read' || return 1
  printf '%s\n' "$line" | grep -qF 'handle all addressed autonomous work' || return 1
  printf '%s\n' "$line" | grep -qF 'run focused verification' || return 1
  printf '%s\n' "$line" | grep -qF 'scope-stage every owned changed or new file' || return 1
  printf '%s\n' "$line" | grep -qF 'commit implementation and evidence' || return 1
  printf '%s\n' "$line" | grep -qF 'git status --short' || return 1
  printf '%s\n' "$line" | grep -qF '.polylane-prompt.txt' || return 1
  printf '%s\n' "$line" | grep -qF 'graphify-out' || return 1
  printf '%s\n' "$line" | grep -qF 'commit that final handoff, and immediately exit' || return 1
  printf '%s\n' "$line" | grep -qF 'No reads, tests, edits, relay decisions, or commits may follow the marker/verdict commit.' || return 1
  if [ "$role" = integrator ]; then
    printf '%s\n' "$line" | grep -qF 'only current-run POLYLANE-VERDICT sentinel as the final line of docs/verify-integration.md' || return 1
    printf '%s\n' "$line" | grep -qF 'with only its DONE marker and no verdict' || return 1
    printf '%s\n' "$line" | grep -qF 'force-add both handoff files with `git add -f`' || return 1
  else
    printf '%s\n' "$line" | grep -qF 'current-run status file' || return 1
    printf '%s\n' "$line" | grep -qF 'force-add the ignored status file with `git add -f`' || return 1
  fi
}

# Hard scalar contracts are not ordinary repeatable prose. Keep the check local
# and Bash-3.2-safe so lint catches a generated prompt before launch.
exact_once_labels() {
  local f="$1" label count
  for label in ULTIMATE-GOAL CURRENT-SUBGOAL GOAL OWN FORBIDDEN PREDEFINED-SKILLS LANE-SPECIFIC-SKILLS TEST-CADENCE DELEGATION CHECK-CACHE EXTERNAL-EVIDENCE VERIFY UI-CONTRACT UI-IMPLEMENT UI-CONTENT UI-EVIDENCE UI-REVIEW-BOUNDARY; do
    count=$(grep -ciE "^[[:space:]]*$label:" "$f" || true)
    [ "$count" -le 1 ] || return 1
  done
}

lint_run() {
  local mf="$1" rc=0 lane pf dir prime_hybrid int_name role agent ui
  local contract run_id verdict verdict_ok
  command -v jq >/dev/null 2>&1 || { echo "polylane-promptlint: jq required for lint-run" >&2; return 2; }
  dir=$(cd "$(dirname "$mf")/.." && pwd)   # .polylane/ -> project root
  prime_hybrid=$(jq -r 'if .prime_hybrid == true then "true" else "false" end' "$mf")
  int_name=$(jq -r '.integrator.name // empty' "$mf")
  agent=$(jq -r '.agent // "claude"' "$mf")
  contract=$(jq -r '.orchestration_contract // 0' "$mf")
  case "$contract" in ''|*[!0-9]*) contract=0 ;; esac
  run_id=$(jq -r '.run_id // empty' "$mf")
  # `// empty`: a manifest with no integrator yields no phantom "null" lane
  for lane in $(jq -r '.lanes[].name, (.integrator.name // empty)' "$mf"); do
    pf=$(jq -r --arg n "$lane" '(.lanes[],.integrator) | select(.name==$n) | .prompt_file' "$mf" | head -1)
    [ -n "$pf" ] && [ "$pf" != "null" ] || { echo "PROMPT-LINT: $lane no prompt_file"; rc=6; continue; }
    case "$pf" in /*) : ;; *) pf="$dir/$pf" ;; esac
    role=builder; [ -n "$int_name" ] && [ "$lane" = "$int_name" ] && role=integrator
    # A lane is UI iff the manifest declares surface:"ui" AND a versioned
    # ui_contract. Classification never comes from prompt keywords or filenames.
    ui=$(jq -r --arg n "$lane" '(.lanes[],.integrator) | select(.name==$n)
      | if (.surface == "ui") and (.ui_contract | tostring | test("^v[0-9]+$")) then "1" else "0" end' "$mf" | head -1)
    lint_one "$pf" "$lane" "$prime_hybrid" "$role" "$agent" "${ui:-0}" || rc=6
    if [ "$role" = integrator ] && [ "$contract" -ge 2 ]; then
      verdict_ok=0
      for verdict in GO READY-FOR-HOST-GATE EXTERNAL-EVIDENCE-OPEN NO-GO; do
        grep -qF "POLYLANE-VERDICT: $verdict run=$run_id" "$pf" && verdict_ok=1
      done
      if [ "$verdict_ok" -ne 1 ]; then
        echo "PROMPT-LINT: $lane missing current-run integrator verdict(run=$run_id)"
        rc=6
      fi
    fi
  done
  return $rc
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  case "${1:-}" in
    lint)     shift; lint_one "$@" ;;
    lint-run) shift; lint_run "${1:?usage: lint-run <manifest>}" ;;
    *) echo "usage: polylane-promptlint.sh lint <prompt-file> [lane] | lint-run <manifest>" >&2; exit 2 ;;
  esac
fi
