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
assert_contains "panecmd-model"   "gpt-5-codex"       "$CMD"
assert_contains "panecmd-prompt"  '$(cat /tmp/p.txt)' "$CMD"
assert_contains "panecmd-no-claude" "codex exec"      "$CMD"

# --- pane_dead process set follows the agent --------------------------------
AGENT=codex;  assert_contains "procs-codex"  "codex" "$(agent_procs)"
AGENT=aider;  assert_contains "procs-aider"  "python" "$(agent_procs)"
AGENT=claude; assert_contains "procs-claude" "claude" "$(agent_procs)"

# --- env POLYLANE_AGENT overrides the manifest AGENT ------------------------
AGENT=claude POLYLANE_AGENT=codex
assert_eq "select-env-overrides" "codex" "$(agent_selected)"
unset POLYLANE_AGENT

finish
