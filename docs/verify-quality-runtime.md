# Quality runtime verification

## Changed files

- `bin/polylane-advanced.sh`
- `bin/polylane-judges.sh`
- `bin/polylane-graph.sh`
- `bin/polylane-run.sh`
- `tests/test-codex-profile.sh`
- `tests/test-advanced-runtime.sh`
- `tests/test-graph-quality-loop.sh`
- `tests/test-judges.sh`

## Design

- Codex profiles default to `lean`; it preserves explicit sandbox, approval, effort, model, and common-Git-dir access while adding `--ephemeral --ignore-user-config`. Invalid profiles stop before launch side effects.
- The advanced adapter is the sole runner surface for risk admission, optional champion/salvage routes, and lane-outcome recording. Missing optional configuration reports `not-requested`.
- Judges validate exactly three unique lenses, execute in isolated evidence files with per-command deadlines, and produce aggregate JSON. Any failed or timed-out judge returns actionable evidence.
- Graphs without `quality_judges` retain their previous deterministic topology. Configured graphs add `judges` and one `judge-repair -> judges` loop, both bounded to one iteration.
- The runner calls advanced preflight before worktrees, runs the seam gate in the integration gate, invokes judges after integration, admits one judge repair, and records terminal outcomes.

## Verification

- `shellcheck -S warning bin/polylane-advanced.sh bin/polylane-judges.sh bin/polylane-graph.sh bin/polylane-run.sh` — exit 0.
- `bash -n bin/polylane-advanced.sh bin/polylane-judges.sh bin/polylane-graph.sh bin/polylane-run.sh` — exit 0.
- Cached required focused suite — exit 0:

  `bash tests/test-codex-profile.sh && bash tests/test-advanced-runtime.sh && bash tests/test-graph-quality-loop.sh && bash tests/test-judges.sh && bash tests/test-graph-contract.sh && bash tests/test-graph-authority.sh && bash tests/test-agent-adapter.sh && bash tests/test-orchestration-contract.sh`

  Results: 6 + 8 + 4 + 7 + 42 + 50 + 39 + 4 passing assertions; no failures.

## DEFERRED

DEFERRED: none
