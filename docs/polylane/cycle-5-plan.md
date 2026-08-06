# Cycle 5 plan — remove measured orchestration waste

## Locked outcome

Implement `m7.1`, `m7.2`, and `m7.3` without weakening contract v2. Recovery must recreate a
missing pane and remap it, detect a live-but-inactive Codex process from durable activity, and
accept a committed `READY-FOR-HOST-GATE` handoff whose terminal checks run exactly once in the
outer runner. Prompts must contain the ultimate goal and exact sub-goal, use a worktree-local
check cache, and name only the selected installed skills. Run statistics must survive supervisor
restarts and report cumulative wall time, launches/restarts, terminal-gate count, cleanup state,
and token usage as a number or `unknown`—never a fabricated zero.

## Frozen acceptance

- `tests/test-runtime-recovery.sh`, `tests/test-verdict-repair.sh`, and `tests/test-wedge.sh`.
- `tests/test-prompt-economy.sh`, `tests/test-promptlint.sh`, and `tests/test-skill-parity.sh`.
- `tests/test-run-stats.sh`, `tests/test-cleanup.sh`, and `tests/test-write-report.sh`.
- Full suite, ShellCheck, seam scan, marker-doc contract, and both jq graph benchmarks.
- Every lane status and verdict is committed with the cycle-5 nonce before DONE.

## Lane carving and selected installed skills

### `recovery-runtime`

Owns `bin/polylane-run.sh`, `tests/test-runtime-recovery.sh`, and narrowly related recovery tests.
Implement pane recreation/remapping, activity-aware dead-agent recovery, and the host-gate
candidate protocol. Use `superpowers:systematic-debugging` to trace the observed states and
`superpowers:test-driven-development` for each regression. Do not read unrelated skills.

### `prompt-economy`

Owns `references/prompt-blocks.md`, `references/planning.md`, `references/skill-scout.md`,
`bin/polylane-promptlint.sh`, and `tests/test-prompt-economy.sh`. Bake only the already-selected
lane skills, prohibit post-launch skill inventory browsing, make cache paths worktree-local, and
state terminal-gate ownership explicitly. Use `superpowers:writing-skills` and
`ponytail:ponytail`; both directly grade instruction quality and unnecessary complexity.

### `telemetry-core`

Owns a new `bin/polylane-run-stats.sh`, `tests/test-run-stats.sh`, and its verification evidence.
Build an atomic append/update interface that preserves original start time and cumulative
launch/restart/gate/token evidence across process death. It must distinguish unknown from zero.
Use `superpowers:test-driven-development` and `engineering:testing-strategy` for crash-boundary
fixtures. The integrator may add the minimal runner/supervisor/report wiring after lane merge.

### Integrator

Merge exact tips and wire cross-file seams. Use `engineering:code-review` and
`superpowers:verification-before-completion`. Query Graphify once for affected call paths; do not
rebuild or broadly reread the repository. Run focused failures while integrating, then hand the
single full terminal gate to the outer coordinator.

## Efficiency budget

Use `gpt-5.6-terra` medium for builders and high for integration. No lane delegation. Maximum one
initial launch plus one recovery launch per lane. No builder runs the full suite. No worker reads
an unselected skill. The outer terminal suite runs exactly once. If source/evidence does not
change for 60 seconds after a terminal Codex error, recover instead of waiting on PID existence.
