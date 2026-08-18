STATUS: precheck DONE run=c43c-recovery-20260819-a1

All five read-only checks ran fresh. Evidence: `docs/verify-precheck.md`.

| # | Check | Result |
|---|---|---|
| 1 | `b6772b1` ancestor of `lane/c43-integrator` | PASS (exit 0) |
| 2 | candidate hash + READY sentinel | PASS |
| 3 | merge onto current `main` | PASS — conflict-free |
| 4 | SHA-256 of both v3 contracts | RECORDED |
| 5 | free disk vs 2 GB floor | PASS — 29 GB |

Candidate: `f16e19649557042ecf242c4c22d4371c050514b0`.
Merge-base with `main` (`37079b303115a8f3bd6460ce061632731aa909fe`) is
`b6772b17a964f4bd82415409d77f1dfddfaf58b6`; merged tree
`23ac1bae9c059187ab4f6ce9b16f226f5bbf01d3`, no conflicts.

Contract addresses (SHA-256 of file content at the candidate ref):
- `CONTRACT-LOCK.v3.json` — `689ab890c339966b15f32a22f309a564f92d1ff34b354184425ffef0f8e41c34`
- `EVIDENCE-CLAIM-REGISTRY.v3.json` — `00b2dc076bf74c2b511ef780f1cda796730ad4704a9d1ccb1f397f4d025864da`

Bounds on the above, restated so the verdict is not over-read: no test, suite,
shellcheck, or acceptance ran in this lane — engineering correctness still rests
on the prior run's `docs/verify-integration.md`. Check 4 records addresses and
does not compare them to the frozen `4851bc1` handoff (no expected values were
supplied and the cadence forbade a sixth check). Check 3 proves textual
mergeability only; `bin/polylane-run.sh` is edited on both sides, so semantic
interaction is closed by post-merge tests, not by this lane. The prior run's
actual failure, `restarts=1>0`, is a property of the next run and is untouched
here. Full limitations in `docs/verify-precheck.md`.

Relay: coordination checked at start and before completion; the only pending
request is `contract-import -> integrator` from run `c43-recovery-20260818-a1`.
Nothing addressed to `precheck`. No merge, no source, test, or state file
touched.
