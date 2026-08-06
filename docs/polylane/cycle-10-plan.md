# Cycle 10 plan — walk-away truth and economy

## Goal

Close only the four regressions observed during cycle 9. Preserve every cycle-9 product,
discovery, model, prompt, skill, graph, judge, and control-room contract.

## Frozen contracts

### m9.1 — keyed acceptance dedupe

- `add-accept` accepts optional `--key <safe-id>` metadata.
- During one `check-accept` invocation, the first selected check for a non-empty key executes.
- Later selected entries with that key reuse its pass/fail result and update their own status.
- An empty key retains current always-run behavior; no result survives into another invocation.
- Invalid keys fail before state mutation.
- Provide a supported way to tag existing frozen acceptances without changing their commands.

Acceptance: `bash tests/test-accept-dedupe.sh`.

### m9.2 — state and dashboard truth parity

- `polylane-state` loads the manifest orchestration contract and canonical project root before
  calling runner helpers.
- A committed current-nonce marker with any non-allowed dirty path is not DONE in state or runner.
- Manifest/session ownership wins over an observer's stale environment.
- The control-room snapshot carries `session` and `watch`; text renders its hint from the snapshot.

Acceptance: `bash tests/test-state.sh && bash tests/test-dashboard.sh`.

### m9.3 — canonical outcome rooting

- `polylane-advanced` derives the run project from the manifest and passes explicit outcome/hub
  paths to all outcome operations unless the caller overrides them.
- Running the adapter from another cwd cannot create `docs/polylane/outcomes.jsonl` there.
- Real runner outcomes remain durable under the canonical project.

Acceptance: `bash tests/test-outcome-rooting.sh && bash tests/test-advanced-runtime.sh`.

### m9.4 — shared coordination relay

- Add a Bash-3.2-safe append-only JSONL helper for request, decision, claim, release, pending,
  and snapshot operations.
- Use an atomic directory lock; stale-lock recovery must reacquire before writing.
- Runner panes receive the canonical project root/coordination file without prompt interpolation.
- Prompts use the helper for live cross-lane work and summarize durable outcomes later in
  `docs/parallel-status.md`.
- Codex installation and parity tests include the helper and contract.

Acceptance: `bash tests/test-coordination.sh && bash tests/test-agent-adapter.sh && bash tests/test-prompt-economy.sh && bash tests/test-installers.sh && bash tests/test-skill-parity.sh`.

## Lane carve

- `acceptance-economy`: memory helper, acceptance-dedupe tests, memory docs.
- `state-truth`: state, dashboard, advanced outcome rooting, focused tests.
- `coordination-relay`: new helper, runner pane environment, prompt/docs/install parity.
- `integrator`: merge, run all frozen checks, live rehearsal, full suite once, ShellCheck once.

All lanes receive the verbatim ultimate goal and exact subgoal. No lane may broaden product scope.
