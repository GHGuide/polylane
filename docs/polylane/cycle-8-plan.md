# Cycle 8 plan — hostile-environment final certificate

## Locked outcome

Prove `m7.5` with a new run ID: two low-effort audit builders, one medium-effort integrator,
exactly three initial launches, zero restarts, one host terminal gate, at most 900 seconds,
truthful unknown/known token state, a green full suite under `POLYLANE_SUP_MAX_RESTARTS=0`,
and final cleanup complete.

## Lanes

- `supervisor-hermetic`: run the supervisor fixture under both hostile and normal retry budgets and
  verify run-ID-scoped telemetry. Own only its verification document and status marker.
- `terminal-contract`: verify the one-shot host gate, stale-proof rejection, and exact GO/NO-GO
  report evidence. Own only its verification document and status marker.

Builders make no source changes and run only named focused checks. The integrator merges their
evidence, rechecks those focused commands once, and emits READY-FOR-HOST-GATE. The coordinator owns
the single full suite, frozen acceptance, promotion, cleanup, and final efficiency certificate.
