# Prompt economy verification

Focused checks were run through the worktree-local cache:

- `bash tests/test-prompt-economy.sh` — red on absent `ULTIMATE-GOAL`/`CURRENT-SUBGOAL`, canonical cache paths, generic skill stacking, missing local-kit-once instruction, absent host-gate handoff, and non-native Codex wording; green: 17 pass.
- `bash tests/test-promptlint.sh` — red on a missing locked goal, non-local cache, or imperative skill-inventory discovery; green: 18 pass.
- `bash tests/test-scout.sh` — red under the old 2+2 contract and on a three-skill role inventory dump; green: 22 pass with 1–2 installed skills per role.
- `bash tests/test-skill-parity.sh` — green: 12 pass; shared prompt references remain the common Claude/Codex source and Codex-specific wording is native.

Builders now run focused/subsystem checks only. Integrators hand off `READY-FOR-HOST-GATE run=<RUN_ID>` when coordinator-owned terminal checks remain.

## DEFERRED

DEFERRED: live platform prompt behavior — no external platform evidence was needed or claimed; deterministic source and prompt-contract tests cover this lane.
