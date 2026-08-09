# Handoff-contract verification

## Red/green evidence

- Red: `tests/test-handoff-contract.sh` failed for all five advertised surfaces because they lacked explicit builder/integrator handoff forms; `tests/test-promptlint.sh` accepted a fictional `polylane-refine.sh propose-or-decline` command.
- Green: the focused handoff test passed 43 assertions and prompt lint passed 28 assertions after the contract and executable refinement guidance were added.

## Executable command audit

Prime-hybrid prompts now require the executable queue command
`"$POLYLANE_PROJECT_ROOT/bin/polylane-refine.sh" queue "$POLYLANE_HARNESS_DIR"`, followed by exactly one real `propose` or `decline` for each eligible item. `propose-or-decline` remains a conceptual phrase only; runtime strict lint rejects it when presented as a subcommand.

## Claude/Codex parity

Both provider skills advertise the same marker-last protocol and refinement syntax.
`tests/test-skill-parity.sh` passed 59 assertions.

## Focused checks

- `tests/test-handoff-contract.sh`: 43 pass, 0 fail.
- `tests/test-promptlint.sh`: 28 pass, 0 fail.
- `tests/test-orchestration-contract.sh`: 14 pass, 0 fail.
- `tests/test-prime-hybrid-integration.sh`: 60 pass, 0 fail.
- `tests/test-refine.sh`: 40 pass, 0 fail.
- `tests/test-skill-parity.sh`: 59 pass, 0 fail.
- `shellcheck -S warning bin/polylane-promptlint.sh`: pass.
- `git diff --check`: pass.

## Exact diff scope

Only the owned prompt lint, Claude/Codex skills, prompt/planning references, listed focused tests, and this verification record changed. No runner, tmux, supervisor, state, or base-branch implementation was modified.

## Skill receipts

SKILL-READ: engineering:documentation | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/documentation/SKILL.md | 1d469418f786a05be83d2a05f04d68788aeed584d13863a650f5ad73c6c4cf50

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | bf1b8216e523851a411e91d429a7c1c2a173e79d88957bc78e348218d50edd54

SKILL-EVIDENCE: engineering:documentation — helped: kept the Claude/Codex and reference wording aligned while making the executable sequence explicit.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the new advertised-surface and fictional-subcommand tests were run red before the matching lint and documentation changes.
