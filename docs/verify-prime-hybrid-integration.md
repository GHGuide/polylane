# Prime hybrid integration verification

Run: `prime-c11-20260807T103930Z`
Branch: `lane/c11-integrator`

## Integrated commits

- `cf4f507` — merge of `lane/c11-harness-refine`,
  `lane/c11-worker-continuity`, and `lane/c11-context-query`.
- `291cc85` — versioned harness/refinement runtime.
- `3b64f89` — durable worker continuity runtime.
- `89eab02` — bounded context packet query runtime.

## TDD evidence

The integration intent test was run unchanged against pre-wiring merge
`cf4f507`: **7 passes, 27 failures**. The first failure was
`prime-hybrid-prelaunch` with exit 127 because the prime-hybrid API was absent;
the remaining failures cover the missing state, packets, exports, completion,
validation, observation, and dry-run seams. The runtime wiring is the
subsequent `f44885e` integration commit.

The green integration test is `bash tests/test-prime-hybrid-integration.sh`:
**43 passes, 0 failures**. It deterministically proves, with fake agents and local
fixtures:

- canonical harness and worker state, one bounded packet per lane, and all four
  pane exports for both builders and the integrator;
- stable retained identities, canonical-only completion capsules, idempotent
  relay import, and no worktree contamination;
- compaction and repeated NO-GO observation, next-cycle validation, and
  rollback to the recorded baseline on a failing declared check;
- refusal to activate a global proposal or overwrite either a source or an
  installed skill, plus the routed handoff; and
- idempotent prelaunch and dry-run purity.

The builder contracts remain independently green: harness 23/0, refinement
28/0, workers 45/0, and context 26/0. The post-integration full suite also
proved the portable timeout path: `test-skill-evolve.sh` is 45/0 after making
descendant discovery best-effort when a sandbox denies process-table access;
the direct child still receives TERM and the required timeout result remains
124.

## Runtime and distribution checks

The opt-in `prime_hybrid: true` manifest path requires orchestration contract
v2, initializes only canonical project state, validates prior-cycle pending
refinements, registers workers, imports the live relay, and creates the
packets before launch. It exports `POLYLANE_HARNESS_DIR`,
`POLYLANE_WORKERS_DIR`, `POLYLANE_WORKER_ID`, and
`POLYLANE_CONTEXT_PACKET`. Prompts require the bounded packet to be read once
and route follow-ups through the durable inbox.

Claude and Codex skills/installers include the same shared continuity contract
with their native invocation syntax. `bash tests/test-skill-parity.sh` is
27/0, `bash tests/test-installers.sh` is 26/0, and
`bash tests/test-install-fresh.sh` is 37/0.

## Reward-hacking guard

Local refinement has no path to activation until a declared expected check is
registered. A later cycle marks it validated only after that check passes, or
rolls back its versioned baseline. Global prompt and skill changes stay
proposal-only and are routed to `polylane-skill-evolve.sh`; neither the live
`SKILL.md` nor an installed skill is rewritten by the local loop. Immutable
acceptance and the final host promotion gate therefore remain outside the
reward signal being observed.

## Remaining risks

Prime hybrid is deliberately opt-in, so a long-running manifest must select it
and carry the D.1 prompt continuity language. Global proposals still need the
separate frozen evaluation and promotion process. No external evidence was
used or required for this local integration run.
