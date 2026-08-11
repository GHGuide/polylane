# Cycle 29 active-scope verification

Run: `c29-active-scope-20260811-a1`  
Base evidence: recovered Cycle 28 tip `cf60d3c1646dc6a7ae3f76a636be423cef91e9a1`; Cycle 28 remains a truthful HALTED run with its eight recorded lane restarts unchanged.

## Witnesses, root causes, and red/green proof

1. **Active command churn.** Cycle 28 crossed the former 12-check / 20-command threshold while a long matrix was still active. The red regression recorded 20 structured starts, 19 matching completions, and one active ID; the old guard advanced its counter to 12. Green: `lane_active_command` ignores raw non-JSON log prose, reduces structured events into an ID-keyed active set, supports overlapping commands, and resets that set at new/terminal turn boundaries. `material_progress_stalled` returns not-stalled before touching fingerprint, count, command baseline, or replan state. After the final completion, the existing bounded 12-check / 20-command policy fires (`test-progress-guard.sh`: 21 pass).

2. **Absolute physical source roots.** The red relative-worktree adapter staged its prompt correctly but exported a relative `POLYLANE_SOURCE_ROOT`. Green: builder and integrator worktrees are anchored to `PROJECT_ROOT`, existing directories resolve through `pwd -P`, and that physical absolute path is used before shell escaping, staging, `cd`, and pane export. The adapter asserts the escaped exported value, staged path, and relative integrator normalization (`test-agent-adapter.sh`: 53 pass).

3. **Completed scope violations are terminal once.** The red runtime fixture committed an exact current-run DONE marker and `outside.txt`; the old health path treated that as unfinished and would retry. Green: only a clean, non-live, exact-HEAD current-run marker can become terminal scope evidence. The failure captures the bounded actual `SCOPE-VIOLATION` path, marks once, preserves the worktree, and consumes no retry/reflexion budget. Dirty or uncommitted state remains in-progress (`test-runtime-recovery.sh`: 26 pass).

4. **Planned-write preflight.** The red static scope cases accepted missing, absolute, traversal, glob, duplicate, and out-of-scope planned paths. Green: opt-in `write_plan_contract: 1` requires every builder's non-empty unique exact repository-relative `planned_writes`, mechanically checks ownership before worktree/tmux side effects, adds the compact current boundary to compiled builder prompts, and lints it only when enabled. Legacy manifests without the opt-in remain valid (`test-scope.sh`: 26 pass; `test-manifest-validation.sh`: 15 pass; `test-promptlint.sh`: 31 pass).

## Runtime semantics

- Structured command state is computed from `item.started` command IDs and their completed, failed, cancelled, or completed-status boundaries. Any unresolved command suppresses material-progress churn without advancing its counter; after all settle, completed command churn remains subject to the prior bounded replan policy.
- Pane source roots are absolute physical paths. `POLYLANE_PROJECT_ROOT` remains the canonical coordination root and is not repurposed as a source root.
- A terminal scope reason is emitted only for the clean committed handoff described above, is capped by the existing 160-character reason policy, and includes real offending paths. It does not respawn, repair, or alter the retained worktree.
- Low/medium/high/xhigh live-turn defaults remain 300/900/1800/3600 seconds. The finite hard ceiling now defaults to 14,400 seconds, while `POLYLANE_LIVE_WEDGE_HARD_SECONDS` remains an explicit operator override. A 7,200-second requested window is proven not to be silently clamped (`test-wedge.sh`: 31 pass).

## Focused cached verification

All commands used `bin/polylane-check.sh "$PWD/.polylane/check-cache/active-scope" -- …`.

- Inherited m24.1: 15 + 56 + 30 + 14 + 11 passing assertions.
- Inherited m24.2: 20 + 27 + 14 + 26 passing assertions.
- Inherited m24.3: 60 + 23 + 53 + 51 passing assertions.
- Inherited m25.1: 31 + 26 + 16 passing assertions.
- Inherited m25.2: 51 + 26 passing assertions.
- Inherited m25.3: `test-run-stats.sh`, `test-write-report.sh` (51), and `test-efficiency-canary.sh` (25) passed.
- Inherited m25.4: 53 + 16 + 14 + 31 passing assertions.
- Cycle 29 m26.1: 21 + 31 passing assertions.
- Cycle 29 m26.2: 53 + 16 + 31 passing assertions.
- Cycle 29 m26.3: 14 + 26 + 51 passing assertions.
- Cycle 29 m26.4: 26 + 15 + 14 passing assertions.

`bash -n bin/polylane-run.sh bin/polylane-scope.sh bin/polylane-promptlint.sh`, `shellcheck -S warning` on those scripts, and `git diff --check` all passed. Diff review confirmed only owned runtime, scope, lint, contract-doc, and named regression files changed. The terminal full suite, installers, doctor rehearsal, deployment, and publication were not run.

## Skill receipts

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: traced the disagreement between the active-command wedge exemption and material-progress counter to the start-only command parser.

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:test-driven-development — helped: focused regressions first reproduced active-command, relative-root, terminal-scope, planned-write, and hard-cap failures before runtime changes.
