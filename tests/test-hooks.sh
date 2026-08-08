#!/usr/bin/env bash
# Lifecycle-hook helper: bounded restore and current-run completion truth.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS="$ROOT/bin/polylane-hooks.sh"
FIXTURES="$ROOT/assets/hooks/fixtures"
command -v jq >/dev/null 2>&1 || { pass "hooks-skipped-no-jq"; finish; exit 0; }
make_tmpdir

PROJECT="$TEST_TMPDIR/project"
mkdir -p "$PROJECT/.polylane" "$PROJECT/docs"
STATE="$PROJECT/.polylane/lifecycle-hooks.json"
cat > "$STATE" <<'JSON'
{
  "memory_brief":"Keep the hook helper portable and limited to context and completion truth.",
  "north_star":"A stranger's first unattended Polylane run is truthful and verified.",
  "settled_decisions":["Hooks are optional project-scoped defense in depth.","The supervisor remains runtime authority.","Never silently grant broad permissions."],
  "transcript":"This unbounded field must never be restored.",
  "byte_cap":420
}
JSON

input_for() {
  sed "s|PROJECT|$PROJECT|g" "$FIXTURES/$1"
}

run_hook() {
  local provider="$1" event="$2" fixture="$3"
  input_for "$fixture" | "$HOOKS" "$provider" "$event" --project "$PROJECT"
}

assert_ok "hooks-helper-present" test -x "$HOOKS"

CODEX_START=$(run_hook codex SessionStart codex-session-start.json)
assert_ok "hooks-codex-session-start-json" sh -c 'printf %s "$1" | jq -e . >/dev/null' sh "$CODEX_START"
assert_eq "hooks-codex-session-start-continue" true "$(printf '%s' "$CODEX_START" | jq -r .continue)"
assert_eq "hooks-codex-session-start-event" SessionStart "$(printf '%s' "$CODEX_START" | jq -r .hookSpecificOutput.hookEventName)"
assert_contains "hooks-codex-session-start-memory-source" "[memory-brief]" "$(printf '%s' "$CODEX_START" | jq -r .hookSpecificOutput.additionalContext)"
assert_contains "hooks-codex-session-start-north-star-source" "[north-star]" "$(printf '%s' "$CODEX_START" | jq -r .hookSpecificOutput.additionalContext)"
assert_contains "hooks-codex-session-start-decisions-source" "[settled-decisions]" "$(printf '%s' "$CODEX_START" | jq -r .hookSpecificOutput.additionalContext)"
assert_eq "hooks-restore-excludes-unbounded-state" false "$(printf '%s' "$CODEX_START" | jq -r '.hookSpecificOutput.additionalContext | contains("unbounded field")')"
assert_ok "hooks-codex-session-start-bounded" sh -c '[ "$(printf %s "$1" | jq -r .hookSpecificOutput.additionalContext | wc -c | tr -d " ")" -le 420 ]' sh "$CODEX_START"

CLAUDE_START=$(run_hook claude SessionStart claude-session-start.json)
assert_ok "hooks-claude-session-start-json" sh -c 'printf %s "$1" | jq -e . >/dev/null' sh "$CLAUDE_START"
assert_eq "hooks-claude-session-start-event" SessionStart "$(printf '%s' "$CLAUDE_START" | jq -r .hookSpecificOutput.hookEventName)"
assert_eq "hooks-restore-semantic-parity" "$(printf '%s' "$CODEX_START" | jq -r .hookSpecificOutput.additionalContext)" "$(printf '%s' "$CLAUDE_START" | jq -r .hookSpecificOutput.additionalContext)"

PRE=$(run_hook codex PreCompact codex-pre-compact.json)
POST=$(run_hook codex PostCompact codex-post-compact.json)
assert_contains "hooks-precompact-restores-context" "[north-star]" "$(printf '%s' "$PRE" | jq -r .systemMessage)"
assert_contains "hooks-postcompact-restores-context" "[settled-decisions]" "$(printf '%s' "$POST" | jq -r .systemMessage)"

printf '%s\n' 'STATUS: fixture-lane DONE run=fixture-run' > "$PROJECT/docs/status-fixture-lane.md"
printf '%s\n' 'fixture evidence run=fixture-run: bash tests/test-hooks.sh PASS' > "$PROJECT/docs/verify-fixture-lane.md"
CODEX_STOP_ALLOW=$(run_hook codex Stop codex-stop.json)
CLAUDE_STOP_ALLOW=$(run_hook claude Stop claude-stop.json)
assert_eq "hooks-stop-current-marker-allows" true "$(printf '%s' "$CODEX_STOP_ALLOW" | jq -r .continue)"
assert_eq "hooks-stop-semantic-parity-allow" "$(printf '%s' "$CODEX_STOP_ALLOW" | jq -r .continue)" "$(printf '%s' "$CLAUDE_STOP_ALLOW" | jq -r .continue)"

printf '%s\n' 'STATUS: fixture-lane DONE run=stale-run' > "$PROJECT/docs/status-fixture-lane.md"
STOP_BLOCK=$(run_hook codex Stop codex-stop.json)
assert_eq "hooks-stop-stale-run-blocked" block "$(printf '%s' "$STOP_BLOCK" | jq -r .decision)"
assert_contains "hooks-stop-stale-run-reason" "current-run marker" "$(printf '%s' "$STOP_BLOCK" | jq -r .reason)"

ACTIVE_STOP=$(printf '%s' '{"session_id":"codex-fixture","cwd":"PROJECT","run_id":"fixture-run","lane":"fixture-lane","stop_hook_active":true}' | sed "s|PROJECT|$PROJECT|g" | "$HOOKS" codex Stop --project "$PROJECT")
assert_eq "hooks-stop-recursion-allows-recovery" true "$(printf '%s' "$ACTIVE_STOP" | jq -r .continue)"
assert_contains "hooks-stop-recursion-diagnostic" "continuation already active" "$(printf '%s' "$ACTIVE_STOP" | jq -r .systemMessage)"

MISSING=$(printf '%s' '{"run_id":"fixture-run","lane":"fixture-lane"}' | "$HOOKS" codex SessionStart --project "$TEST_TMPDIR/missing")
assert_eq "hooks-missing-state-fails-open" true "$(printf '%s' "$MISSING" | jq -r .continue)"
assert_contains "hooks-missing-state-diagnostic" "state unavailable" "$(printf '%s' "$MISSING" | jq -r .systemMessage)"

INVALID=$(printf '%s' '{not-json' | "$HOOKS" codex SessionStart --project "$PROJECT")
assert_eq "hooks-invalid-json-fails-open" true "$(printf '%s' "$INVALID" | jq -r .continue)"
assert_contains "hooks-invalid-json-diagnostic" "invalid lifecycle JSON" "$(printf '%s' "$INVALID" | jq -r .systemMessage)"

CODEX_FRAGMENT="$ROOT/assets/hooks/codex-hooks.json"
CLAUDE_FRAGMENT="$ROOT/assets/hooks/claude-settings.json"
assert_ok "hooks-codex-fragment-json" jq -e '.hooks.SessionStart and .hooks.PreCompact and .hooks.PostCompact and .hooks.Stop' "$CODEX_FRAGMENT"
assert_ok "hooks-claude-fragment-json" jq -e '.hooks.SessionStart and .hooks.PreCompact and .hooks.PostCompact and .hooks.Stop' "$CLAUDE_FRAGMENT"
assert_contains "hooks-codex-fragment-project-local" 'git rev-parse --show-toplevel' "$(cat "$CODEX_FRAGMENT")"
assert_contains "hooks-claude-fragment-project-local" 'CLAUDE_PROJECT_DIR' "$(cat "$CLAUDE_FRAGMENT")"
assert_ok "hooks-legacy-claude-snippet-json" jq -e '.hooks.Stop' "$ROOT/assets/settings-hook-snippet.json"

finish
