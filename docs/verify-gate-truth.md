# Cycle 30 gate-truth verification

Run: `c30-gate-truth-20260811-a1`

## Witness and root cause

Cycle 29's retained tip was `9df16a33c51ccbb210247c51fc9bbb1207d256ed`.
Every outer focused check passed, but `tests/test-memory.sh` inherited
`POLYLANE_ACCEPT_FAILURE_ROOT`, `POLYLANE_ACCEPT_FAILURE_RUN_ID`, and
`POLYLANE_ACCEPT_FAILURE_PHASE`. Its intentional nested fixture failure wrote
`docs/polylane/host-gate-failures/c29-active-scope-20260811-a1.acceptance.jsonl`
at the canonical root. Promotion then correctly rejected that untracked user-data
path, yet the HALTED report omitted the exact blocker.

## Red then green evidence

- RED: `test-memory.sh` proved a nested acceptance fixture could create outer
  canonical evidence and that a passing current phase retained stale evidence.
  GREEN: 62 checks; child commands run with all three authority variables absent,
  while the parent retains them to write its own bounded failure record.
- RED: `test-contract-acceptance.sh` showed a focused-only target incremented
  `terminal_gates`. GREEN: 31 checks; it promotes focused work with zero terminal
  events and proves a clean committed focused proof is reused once, while a dirty
  integrator tree invalidates it and reruns focused acceptance.
- RED: `test-promotion-transaction.sh` lacked exact user-dirt/merge reasons and
  `test-write-report.sh` lacked a promotion-recovery explanation. GREEN: 29 and
  54 checks respectively; promotion preserves its guard, records a bounded reason,
  and reports it as data (including literal `$(...)`, never executed).

## Lifecycle semantics

- Terminal eligibility requires a terminal-tier acceptance on the current target
  and no open/doing autonomous subgoal outside that target. Focused-only READY
  completes focused host verification and promotes GO without terminal mode,
  terminal proof, or `terminal_gates` telemetry.
- A terminal target is counted once before its terminal proof/checks. The focused
  proof is an in-process, one-use receipt keyed to exact integrator `HEAD`, clean
  worktree state, target set, and immutable selected acceptance definitions.
  HEAD, dirt, target, command, tier, key, or dependency changes invalidate it.
- `_accept_run` clears authority variables only in its child environment. A fresh
  top-level run clears stale current-run/current-phase records first; a genuine
  failure atomically retains one current-run bounded JSON record. Nonces, regular
  file/symlink checks, and atomic replacement remain fail-closed.
- Promotion never broadens the user-dirt allowlist. Tracked/untracked rejection
  and merge-transaction failure retain verified worktrees/branches and surface
  their bounded reason in the HALTED report and recovery step.

## Focused verification

All commands used the lane-local cache:

- `bash tests/test-memory.sh` — 62 pass
- `bash tests/test-contract-acceptance.sh` — 31 pass
- `bash tests/test-run-stats.sh` — pass
- `bash tests/test-promotion-transaction.sh` — 29 pass
- `bash tests/test-write-report.sh` — 54 pass
- `bash tests/test-efficiency-canary.sh` — 25 pass
- `bash tests/test-verdict-repair.sh` — 57 pass
- `bash -n bin/polylane-run.sh bin/polylane-memory.sh`
- `shellcheck -S warning bin/polylane-run.sh bin/polylane-memory.sh`
- `git diff --check`

Focused count: all Cycle 30 matrices and affected inherited runner/memory,
promotion, reporting, efficiency, telemetry, and verdict-repair matrices passed.
No full suite, installer, doctor rehearsal, deployment, publication, or external
action was run.

## Skill receipts

SKILL-READ: superpowers:systematic-debugging | `/Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md` | `4111822586-9465`

SKILL-READ: superpowers:test-driven-development | `/Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md` | `1657109997-9015`

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: tracing the canonical
failure variables through `_accept_run` isolated nested authority leakage rather
than weakening promotion.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the smallest red
fixtures captured nested evidence, phantom terminal counting, and missing promotion
attribution before their production repairs.
