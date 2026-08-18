# Runtime finality verification

## Root cause and boundary

`lane_done` previously treated a nonce-correct, committed clean marker (or
integrator READY handoff) as terminal without checking the corresponding live
agent process.  A still-running worker could therefore mutate its handoff after
the runner advanced.  The recovery builders independently appended new
`DELEGATION` and `CHECK-CACHE` scalars, which strict prompt compilation rejects
as duplicate/conflicting exact-once contracts.

The fix adds a contract-v2-only `lane_completion_worker_live` seam.  It blocks
completion only when the lane's explicit mapping and nonce-bound worktree lookup
agree and `pane_agent_live` confirms the selected agent process.  Missing,
unmapped, legacy, and non-tmux callers keep their existing marker semantics.
No polling or mutation occurs in `lane_done`.

`POLYLANE-RUNTIME-FINALIZE` now gives every compiled prompt one copy-paste-safe,
ordered final transaction: relay/inbox, addressed work, focused verification,
scoped stage/commit, permitted-scratch clean check, status/verdict-last with
force-add when needed, final commit, immediate exit.  Repair and churn addenda
now preserve source strict scalars rather than duplicate them.

## Red/green evidence

Initial focused invocation of the requested new live test was red because
`tests/test-lane-done-live.sh` did not yet exist.  The first implementation run
then exposed the real READY-path defect: its early return bypassed the liveness
gate.  After routing READY through the shared gate, the final cached focused
matrix was green:

- `test-lane-done-live.sh`: 8 pass (committed marker and READY rejected while
  mapped live; same evidence accepted after exit; unmapped seam remains pure;
  runtime finalization passes strict promptopt and promptlint).
- `test-lane-done.sh`: 27 pass.
- `test-runtime-recovery.sh`: 15 pass.
- `test-progress-guard.sh`: 16 pass.
- `test-promptopt.sh`: 9 pass.
- `test-reflexion.sh`: 12 pass.

Focused total: 87 pass, 0 fail.  `shellcheck -S warning
bin/polylane-run.sh` passed through the required check cache.

## Compatibility boundaries

- Contract v2 requires marker/verdict validity, clean tree, exact HEAD, nonce,
  and existing symlink/runner-owned-scratch rules before the liveness gate.
- A mapped pane blocks only when `pane_for_worktree` authoritatively resolves it
  for the current run and its selected agent is live; unknown/unmapped fixtures
  do not falsely fail closed.
- A worker that is live with a valid marker remains working.  Health recovery
  neither marks it dead nor restarts it; after process exit normal acceptance
  resumes without altering the marker.

## Exact changed set

- `bin/polylane-run.sh`: runtime finalization protocol; authoritative
  completion-liveness helper; READY path gate; scalar-safe repair/replan text.
- `tests/test-lane-done-live.sh`: live marker/READY, exit, unmapped, and strict
  runtime-finalize regression coverage.
- `tests/test-progress-guard.sh`: strict scalar preservation regression.
- `tests/test-reflexion.sh`: strict scalar preservation regression.
- `docs/verify-runtime-finality.md`: this evidence record.

## Skill receipts

SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | e50bb92cbcb2715139f3a3cb9ff282a8f0f9ae794f8f35d81338654e2601d32a

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 808fc5717aa88ad65efff312b11c186294d3e6ee301afb584e2f86599b137787

SKILL-EVIDENCE: engineering:debug — helped: reproduced the missing live test,
isolated the READY early return, and verified the controlled live/dead seam.

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: traced marker,
checkpoint, pane identity, and process-liveness separately before changing the
completion path.
