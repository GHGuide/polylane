# Cycle 22 research — primary evidence and failure boundary

## Confirmed Cycle 21 behavior

The Cycle 21 audit lane and integrator both completed from exact committed markers.  The
runner recorded two launches, zero restarts, and a clean READY handoff, then stopped with
`terminal_gates=0`.  Its focused acceptance failed only the nested
`efficiency-canonical-proof` assertion.  The host report correctly attributed that
failure to the runner-owned gate and withheld promotion and cleanup.

The defect was an invalid environment pair.  `contract_focused_acceptance_gate` ran
before `write_efficiency_proof gate`, but exported `POLYLANE_EXPECTED_RUN_ID` while
`POLYLANE_EFFICIENCY_PROOF` was empty.  The nested canary therefore selected an inherited
or default proof and compared it with the new nonce.  Normal worker execution lacked
that half-context, explaining why the integrator's same canary passed.

## Repair evidence

Commit `870bce6` explicitly clears both variables only in the cheap precheck.  The full
acceptance function still exports the run-scoped proof and nonce together after the host
creates the proof.  A red-first regression observed `|pre-gate-run|` before the fix and
now requires `||`; it also proves terminal acceptance exports the matching pair twice
for focused and terminal checks.  The repair tree passed 84 focused checks, whole-tree
ShellCheck, and the complete 2,210-test suite.

These checks establish a credible candidate, not final certification.  Only a new nonce,
new process, authoritative graph run, untouched terminal boundary, live GO/NO-GO
rehearsal, promotion, cleanup, and final proof can close the remaining targets and
criterion.  Internet research and new installations would add no evidence to this
narrow process-boundary trial.

