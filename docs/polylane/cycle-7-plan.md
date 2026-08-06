# Cycle 7 plan — fresh run-ID-scoped proof

## Locked outcome

Prove `m7.5` with a new run ID and no implementation churn: two low-effort audit builders, one
medium-effort integrator, exactly three initial launches, zero restarts, one host terminal gate,
at most 900 seconds, truthful token state, and final cleanup complete. The terminal suite must run
through its worktree-local durable cache and any failure must end this run without model repair.

## Lanes

- `fresh-stats`: verify new-run reset, same-run resume accumulation, stale-proof rejection, and
  truthful known/unknown tokens. Own only `docs/verify-fresh-stats.md` and its status marker.
- `single-gate`: verify terminal failure is final for a run and GO/NO-GO report evidence remains
  exact after cleanup/retention. Own only `docs/verify-single-gate.md` and its status marker.

Builders run named focused tests only and make no source changes. The integrator merges the two
evidence commits, checks their commands once, and writes READY-FOR-HOST-GATE. The coordinator owns
the one full terminal gate, promotion, state finalization, cleanup, and final certificate.
