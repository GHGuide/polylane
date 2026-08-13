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

# The completion gate receives role and run explicitly. A custom-named
# integrator uses verify-integration.md; a builder with the same name does not.
VERIFY_GATE="$ROOT/assets/verify-gate.sh"
printf '%s\n' 'STATUS: verifier-x DONE run=explicit-run' > "$PROJECT/docs/status-verifier-x.md"
printf '%s\n' 'proof' 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=explicit-run' > "$PROJECT/docs/verify-integration.md"
assert_ok "verify-gate-explicit-integrator-role" "$VERIFY_GATE" \
  --project "$PROJECT" --lane verifier-x --run-id explicit-run --role integrator
assert_fail "verify-gate-role-is-not-inferred-from-name" "$VERIFY_GATE" \
  --project "$PROJECT" --lane verifier-x --run-id explicit-run --role builder
assert_contains "hooks-codex-stop-passes-explicit-role" 'POLYLANE_WORKER_ROLE' \
  "$(jq -r '.hooks.Stop[0].hooks[0].command' "$CODEX_FRAGMENT")"
assert_contains "hooks-claude-stop-passes-explicit-run" 'POLYLANE_WORKER_RUN_ID' \
  "$(jq -r '.hooks.Stop[0].hooks[0].command' "$CLAUDE_FRAGMENT")"

# --- installed-helper locator + project-scoped fragment rendering ------------
# The shipped fragments carry a placeholder helper path; a stranger renders a
# project-local fragment that resolves the ACTUAL installed helper, never the
# blank target repo's non-existent bin/polylane-hooks.sh.
SELF_EXPECT="$(cd "$(dirname "$HOOKS")" && pwd -P)/polylane-hooks.sh"
LOCATED=$("$HOOKS" locate)
assert_eq "hooks-locate-resolves-self" "$SELF_EXPECT" "$LOCATED"
assert_ok "hooks-locate-executable" test -x "$LOCATED"

# Raw fragments must NOT hardcode the blank target repo bin/ path and MUST carry
# the placeholder the renderer substitutes.
assert_eq "hooks-claude-fragment-no-target-bin" false \
  "$(jq -r 'tostring | contains("$CLAUDE_PROJECT_DIR/bin/polylane-hooks.sh")' "$CLAUDE_FRAGMENT")"
assert_eq "hooks-codex-fragment-no-target-bin" false \
  "$(jq -r 'tostring | contains("show-toplevel)/bin/polylane-hooks.sh")' "$CODEX_FRAGMENT")"
assert_contains "hooks-claude-fragment-placeholder" '__POLYLANE_HOOKS_HELPER__' "$(cat "$CLAUDE_FRAGMENT")"
assert_contains "hooks-codex-fragment-placeholder" '__POLYLANE_HOOKS_HELPER__' "$(cat "$CODEX_FRAGMENT")"

RENDERED_CLAUDE=$("$HOOKS" render claude)
assert_ok "hooks-render-claude-json" sh -c 'printf %s "$1" | jq -e . >/dev/null' sh "$RENDERED_CLAUDE"
assert_eq "hooks-render-claude-no-placeholder" false \
  "$(printf '%s' "$RENDERED_CLAUDE" | jq -r 'tostring | contains("__POLYLANE_HOOKS_HELPER__")')"
RC_CMD=$(printf '%s' "$RENDERED_CLAUDE" | jq -r '.hooks.SessionStart[0].hooks[0].command')
assert_contains "hooks-render-claude-resolves-helper" "$LOCATED" "$RC_CMD"
assert_ok "hooks-render-claude-provenance-sha" \
  sh -c 'printf %s "$1" | jq -r "._comment" | grep -Eq "sha256=[0-9a-f]{64}"' sh "$RENDERED_CLAUDE"

# Execute every rendered Claude command exactly as the provider would.
for EV in SessionStart PreCompact PostCompact Stop; do
  case "$EV" in
    SessionStart) FX=claude-session-start.json ;;
    PreCompact)   FX=claude-pre-compact.json ;;
    PostCompact)  FX=claude-post-compact.json ;;
    Stop)         FX=claude-stop.json ;;
  esac
  CMD=$(printf '%s' "$RENDERED_CLAUDE" | jq -r --arg e "$EV" '.hooks[$e][0].hooks[0].command')
  if [ "$EV" = Stop ]; then
    printf '%s\n' 'STATUS: fixture-lane DONE run=fixture-run' > "$PROJECT/docs/status-fixture-lane.md"
    printf '%s\n' 'fixture evidence run=fixture-run: PASS' > "$PROJECT/docs/verify-fixture-lane.md"
    OUT=$(input_for "$FX" | env CLAUDE_PROJECT_DIR="$PROJECT" \
      POLYLANE_WORKER_ID=fixture-lane POLYLANE_WORKER_RUN_ID=fixture-run \
      POLYLANE_WORKER_ROLE=builder sh -c "$CMD")
  else
    OUT=$(input_for "$FX" | env CLAUDE_PROJECT_DIR="$PROJECT" sh -c "$CMD")
  fi
  assert_ok "hooks-render-exec-json-$EV" sh -c 'printf %s "$1" | jq -e . >/dev/null' sh "$OUT"
  assert_eq "hooks-render-exec-continue-$EV" true "$(printf '%s' "$OUT" | jq -r '.continue // true')"
done

# Fail-safe: a rendered command whose helper has been removed is a silent no-op,
# never a crashing hook that stalls the session.
BOGUS_CMD=$(printf '%s' "$RC_CMD" | sed "s#$LOCATED#/no/such/polylane-hooks.sh#")
assert_rc "hooks-render-absent-failsafe" 0 env CLAUDE_PROJECT_DIR="$PROJECT" sh -c "$BOGUS_CMD"

RENDERED_CODEX=$("$HOOKS" render codex)
assert_ok "hooks-render-codex-json" sh -c 'printf %s "$1" | jq -e . >/dev/null' sh "$RENDERED_CODEX"
RX_CMD=$(printf '%s' "$RENDERED_CODEX" | jq -r '.hooks.SessionStart[0].hooks[0].command')
assert_contains "hooks-render-codex-resolves-helper" "$LOCATED" "$RX_CMD"
assert_ok "hooks-render-codex-provenance-sha" \
  sh -c 'printf %s "$1" | jq -r ".description" | grep -Eq "sha256=[0-9a-f]{64}"' sh "$RENDERED_CODEX"

# Tampering: rendering THROUGH a symlink (not the real installed regular file)
# must fail before emitting a fragment.
LINK="$TEST_TMPDIR/linked-hooks.sh"
ln -s "$HOOKS" "$LINK"
assert_fail "hooks-render-symlink-rejected" "$LINK" render claude
assert_fail "hooks-locate-symlink-rejected" "$LINK" locate

finish
