# Cycle 6 plan — fresh-process efficiency canary

## Locked outcome

Complete `m7.5` under a manifest-enforced canary budget: two builder launches and one integrator
launch, zero restarts, exactly one coordinator terminal gate, at most 1,200 seconds, truthful token
state, and complete cleanup. The integrator must hand off `READY-FOR-HOST-GATE`; it cannot declare
GO itself. The coordinator writes and verifies `docs/polylane/efficiency-proof.md` from durable
telemetry before finalizing the goal.

## Lanes

### `host-canary`

Own `bin/polylane-rehearse.sh` and `tests/test-rehearse.sh`. Make the GO rehearsal use the
nonce-bound READY handoff and assert that the outer runner executes exactly one terminal gate.
Keep NO-GO behavior and hermetic cleanup intact. Use systematic debugging, test-driven
development, and testing strategy; no unrelated skill discovery.

### `report-truth`

Own a narrow report-item helper and its tests. Extract only explicit bullet items under current
run `Deferred`, `External`, or `Open items` sections; exclude wrapped explanatory prose, status
sentinels, verdict sentinels, commands, and historical evidence. The integrator may wire the
helper into the runner after merge. Use test-driven development, code review, and documentation;
no unrelated skill discovery.

## Integrator and terminal gate

Merge exact lane tips, wire only the cross-file report seam, run focused changed tests, and write
the run-tagged READY sentinel. Do not run the full suite inside the integration worktree. The
outer coordinator runs frozen terminal acceptance exactly once, promotes only on success, and
finalizes the telemetry certificate after clean teardown.

