STATUS: precheck DONE run=c43d-recovery-20260819-a1

Evidence: `docs/verify-precheck.md` (commit `2d3824f`). Five read-only checks, run
fresh in this worktree. No merge, no source edit, no test, no external action.

## Result: 4 PASS, 1 FAIL

| # | check | result |
|---|---|---|
| 1 | `b6772b1` ancestor of `lane/c43c-integrator` | PASS (rc=0) — but `7e4e35e` is not (rc=1) |
| 2 | candidate SHA + READY sentinel | PASS on `9b0f8cb973b5f6b646a9724c7e6823479f22817a`; sentinel present, nonce `c43c-recovery-20260819-a1` |
| 3 | conflict-free merge onto `main` | **FAIL** — 1 conflict in `bin/polylane-run.sh` |
| 4 | v3 contract SHA-256s | PASS — `689ab890…` / `00b2dc07…`, both cross-checked |
| 5 | free disk ≥ 2 GB | PASS — 29 GB |

## For the integrator

The candidate is intact and content-addressed; the frozen v3 contracts hash
identically to the integrator's own independent derivation. It is **not** zero-touch
mergeable. `main` advanced to `7e4e35e` (tool-child wedge immunity) after the
candidate branched from `37079b3`, and both sides edited the opening of
`pane_wedged()`. Both the trivial and `ort` merge engines report the same single
conflict: `bin/polylane-run.sh`, one hunk, lines 3816–3833 of the ort-merged blob.
21 files add cleanly, 5 merge cleanly, 0 deletions.

The two sides are additive, not contradictory. Dropping `main`'s side would
reintroduce the wedge-kill-during-tool-subprocess bug that cost the prior run its
restart — the same `restarts=1>0` that failed the host gate. Resolving is the
integrator's call and requires a test run to prove; this lane only read the diff.

Two brief inputs are stale, and neither is a defect in the candidate: the pinned
ancestor `b6772b1` is two commits behind `main`, and the expected sentinel nonce
`c43-recovery-20260818-a1` names the run before last (its evidence remains at
`lane/c43-integrator:docs/verify-integration.md`). Expect
`c43c-recovery-20260819-a1`. One named input,
`docs/polylane/host-gate-failures/c43-recovery-20260818-a1.md`, does not exist on
any ref; the prior failure mode was read from the integrator's verify file instead.

Full verbatim outputs, root-cause trace, seven limitations, and both SKILL-EVIDENCE
records are in `docs/verify-precheck.md`.

## Relay

Only pending request is `contract-import → integrator` seq=1, addressed elsewhere
and already resolved in a prior run. Nothing addressed to `precheck` at lane start
or at the final read.
