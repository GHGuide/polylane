STATUS: precheck DONE run=c43e-recovery-20260819-a1

Lane: precheck. Target m32.6. Evidence: docs/verify-precheck.md (commit 7816fe8).
Read-only throughout — no merge, no source edit, no test run, no network,
no subagent.

Five fresh checks against local refs: 4 PASS, 1 FAIL.

1. PASS — `git merge-base --is-ancestor b6772b1 lane/c43d-integrator` rc=0.
   Current `main` (`1ca5262afbe091eb44b55587f3448236d8f13e14`) is NOT an
   ancestor: exactly one commit, `1ca5262`, is ahead of the candidate and it
   touches `bin/polylane-run.sh`.
2. PASS — candidate tip `6579bc242811c7e1ccfe89deec6fc1a5bdf0f66f`; final line
   of its `docs/verify-integration.md` is
   `POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c43d-recovery-20260819-a1`.
   Two brief identifiers are stale: the brief's `6579bc29…` prefix (actual
   `6579bc24…`) and its `c43-recovery-20260818-a1` sentinel run-id (actual
   `c43d-recovery-20260819-a1`). The artifact is internally consistent.
3. FAIL — the merge is NOT conflict-free. Legacy
   `git merge-tree 7e4e35e main lane/c43d-integrator` rc=0 with zero conflict
   markers, but merge-ort (`git merge-tree --write-tree main
   lane/c43d-integrator`) returns rc=1:
   `CONFLICT (content): Merge conflict in bin/polylane-run.sh`, two hunks
   (`quiesce_done_pane` ~2672, `pane_wedged` ~3851). Cause is `1ca5262`.
   Both hunks quoted verbatim in the verify doc; both resolutions are additive
   (keep main's bounded quiesce retry and `pane_burning_cpu` work signal, keep
   the candidate's `ORCHESTRATION_CONTRACT >= 3` lifecycle gating).
4. PASS — frozen v3 contract blobs at the candidate, re-derived independently
   and matching the integrator's recorded values:
   CONTRACT-LOCK.v3.json
   `689ab890c339966b15f32a22f309a564f92d1ff34b354184425ffef0f8e41c34`
   EVIDENCE-CLAIM-REGISTRY.v3.json
   `00b2dc076bf74c2b511ef780f1cda796730ad4704a9d1ccb1f397f4d025864da`
5. PASS — `df -g .` shows 25 GiB available (25.21 GiB from `df -k`), above the
   2 GiB floor. Volume is 95% full, so the absolute margin is modest.

Candidate is intact and content-addressed. It is NOT mergeable onto current
main without an explicit resolution of `1ca5262` — a plan assuming a
zero-conflict merge will stall at the merge step. No engineering claim is made
here about the merged tree; the c43d integrator's 4077-pass total was read, not
re-run, and was measured before `1ca5262` existed.

Relay: start and final `pending` reads both show only the historical
`contract-import → integrator` seq=1 request. No durable `precheck` worker
identity exists this run. Nothing was addressed to this lane.

Skills read: superpowers:systematic-debugging (4111822586-9465),
superpowers:verification-before-completion (1896692335-3646). Both helped;
per-skill SKILL-EVIDENCE is in docs/verify-precheck.md.
