#!/usr/bin/env bash
# agent adapter — the pluggable launch layer that lets a lane run GPT (codex),
# aider, or a custom CLI instead of Claude. The rest of the pipeline is agent-
# agnostic (file-based done-signal + verdict), so this is the only Claude-specific
# seam. Tests template resolution, {model}/{prompt} substitution, pane_dead procs,
# selection precedence, and validation.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

# --- template selection by profile ------------------------------------------
AGENT=claude; unset POLYLANE_AGENT POLYLANE_AGENT_CMD
assert_contains "tmpl-claude"     "claude --permission-mode" "$(agent_template)"
assert_contains "tmpl-claude-ph"  '{model}'                  "$(agent_template)"
# effort must reach the CLI mechanically (--effort), not just as an env var the CLI
# ignores — otherwise a Claude lane's effort is pure prompt-discretion.
assert_contains "tmpl-claude-effort" '--effort {effort}'      "$(agent_template)"
CCMD=$(pane_cmd /tmp/wt claude-opus-4-8 /tmp/p.txt xhigh)
assert_contains "panecmd-claude-effort-applied" "--effort xhigh" "$CCMD"
assert_contains "panecmd-claude-effort-default" "--effort medium" "$(pane_cmd /tmp/wt claude-opus-4-8 /tmp/p.txt '')"
# respawn resumes the lane's session (keeps its worked-out context) and still delivers
# the prompt; a COLD first launch must never carry --continue.
assert_contains "panecmd-claude-resume"      "claude --continue" "$(pane_cmd /tmp/wt claude-opus-4-8 /tmp/p.txt high resume)"
assert_contains "panecmd-claude-resume-prompt" 'cat /tmp/p.txt'   "$(pane_cmd /tmp/wt claude-opus-4-8 /tmp/p.txt high resume)"
if printf '%s' "$(pane_cmd /tmp/wt claude-opus-4-8 /tmp/p.txt high)" | grep -q -- '--continue'; then
  fail "panecmd-cold-has-no-continue" "cold launch carried --continue"
else pass "panecmd-cold-has-no-continue"; fi
AGENT=codex
assert_contains "tmpl-codex"      "codex exec"               "$(agent_template)"
AGENT=gpt
assert_contains "tmpl-gpt-alias"  "codex exec"               "$(agent_template)"   # gpt -> codex
AGENT=aider
assert_contains "tmpl-aider"      "aider --model"            "$(agent_template)"

# --- custom command template wins over profile ------------------------------
AGENT=claude POLYLANE_AGENT_CMD='mycli --m {model} --f {prompt}'
assert_eq "tmpl-custom" "mycli --m {model} --f {prompt}" "$(agent_template)"
unset POLYLANE_AGENT_CMD

# --- unknown profile errors (no silent claude fallback in the template) ------
AGENT=bogus
assert_fail "tmpl-unknown-fails" agent_template

# --- pane_cmd substitutes model+prompt into the selected template ------------
AGENT=codex
CMD=$(pane_cmd /tmp/wt gpt-5-codex /tmp/p.txt high)
assert_contains "panecmd-cd"      "cd /tmp/wt"        "$CMD"
assert_contains "panecmd-effort"  "POLYLANE_EFFORT=high" "$CMD"
assert_contains "panecmd-effort-config" "model_reasoning_effort=high" "$CMD"
assert_contains "panecmd-model"   "gpt-5-codex"       "$CMD"
assert_contains "panecmd-prompt"  "< /tmp/p.txt" "$CMD"
assert_contains "panecmd-no-claude" "codex exec"      "$CMD"
assert_contains "panecmd-json" "--json" "$CMD"
assert_contains "panecmd-approval-never" "approval_policy=never" "$CMD"

# --- pane_dead process set follows the agent --------------------------------
AGENT=codex;  assert_contains "procs-codex"  "codex" "$(agent_procs)"
AGENT=aider;  assert_contains "procs-aider"  "python" "$(agent_procs)"
AGENT=claude; assert_contains "procs-claude" "claude" "$(agent_procs)"

# --- env POLYLANE_AGENT overrides the manifest AGENT ------------------------
AGENT=claude POLYLANE_AGENT=codex
assert_eq "select-env-overrides" "codex" "$(agent_selected)"
unset POLYLANE_AGENT

# --- agent-aware preflight: codex manifests require codex, not claude --------
make_tmpdir
TOOLBIN="$TEST_TMPDIR/tools"; mkdir -p "$TOOLBIN"
for t in tmux git jq codex; do
  printf '#!/usr/bin/env sh\nexit 0\n' > "$TOOLBIN/$t"
  chmod +x "$TOOLBIN/$t"
done
AGENT=codex REPO_ROOT="$TEST_TMPDIR" MANIFEST="$TEST_TMPDIR/run.json" PATH="$TOOLBIN" \
  assert_ok "preflight-codex-does-not-require-claude" preflight_agent
rm -f "$TOOLBIN/codex"
AGENT=codex REPO_ROOT="$TEST_TMPDIR" MANIFEST="$TEST_TMPDIR/run.json" PATH="$TOOLBIN" \
  assert_rc "preflight-codex-requires-codex" 1 preflight_agent

# custom templates own their CLI deps; the runner only checks shared mechanics.
AGENT=codex POLYLANE_AGENT_CMD='custom --m {model} --p {prompt}' REPO_ROOT="$TEST_TMPDIR" MANIFEST="$TEST_TMPDIR/run.json" PATH="$TOOLBIN" \
  assert_ok "preflight-custom-template-skips-agent-cli" preflight_agent
unset POLYLANE_AGENT_CMD

TMUX_SESSION=polylane-c42
assert_eq "watch-command" "tmux attach -t polylane-c42" "$(tmux_watch_command)"

finish
