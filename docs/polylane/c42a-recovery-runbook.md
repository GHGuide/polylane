# Cycle 42A recovery runbook

Target: `m32.6` — freeze executable v3 execution, provenance, source-calibration,
statistics, and lifecycle contracts. Authority: `docs/polylane/cycle-42a-outcome.md`
(immutable NO-GO; recovery contract). Blocked on: a live provider
(`claude /login`, or codex quota reset 2026-08-20 15:03 — doctor's `check_auth`
now gates this automatically).

## What the recovery imports

The c42a implementation artifacts are content-addressed and archived in the
canonical repo (pushed to origin):

- `archive/c42a-taste-contract-integrator` — integrator tree; the immutable
  handoff is commit `4851bc1` (status SHA-256 `52c99513…`, integration-evidence
  SHA-256 `4eb179e6…` per the outcome doc). The two `WIP checkpoint` commits
  above it are auto-retry state, NOT part of the handoff.
- `archive/c42a-execution-contract-freeze`, `archive/c42a-source-contract-freeze`,
  `archive/c42a-evidence-policy-freeze`, `archive/c42a-lifecycle-external-routing`
  — the four builder lanes.
- Contract payloads live at `docs/polylane/taste-certification/contracts/` in
  those trees: `CONTRACT-LOCK.v3.json`, `EVIDENCE-CLAIM-REGISTRY.v3.json`,
  `execution-v3.schema.json` (+ example), `source-calibration-v3.schema.json`
  (+ example), `evidence-dag-v3.schema.json`, `evidence-policy-v3.json`, plus
  `bin/polylane-taste-execution-contract.sh` and
  `bin/polylane-taste-source-contract.sh`.
- The `--evidence-kind` extension to `bin/polylane-memory.sh` and the extended
  `tests/test-contract-acceptance.sh` exist only in these archives — they land
  through this recovery, never by piecemeal copy.

## Rules the fresh run must obey (from the outcome doc)

1. New run ID; `orchestration_contract: 2` manifest ("contract v3" in the outcome
   names the frozen taste-contract set above, not a runner manifest version).
2. Import only content-addressed artifacts from `4851bc1` and the four lane
   tips; create fresh worker-owned handoffs (no reuse of old status files).
3. Execute the frozen host gate at the exact assembled candidate; archive
   finalization receipts; promote only on a fresh `GO`.
4. The 2026-08-13 `PRECHECK_ONLY` full-suite pass at `1e89f4f` explains the
   sandbox NO-GO; it does not authorize promotion of any commit.

## Launch steps (when a provider is live)

```bash
cd /Users/leonardo/Downloads/polylane
bin/polylane-doctor.sh              # must show 'auth' PASS for the chosen agent
bin/polylane-models.sh codex        # or: bin/polylane-models.sh claude
```

Then plan the run from this repo's current main (the archives are local refs):
one import/assembly lane per frozen contract group is unnecessary — a single
integrator-style recovery lane that cherry-imports the artifact paths from the
archive refs, plus the standard integrator, matches the outcome doc's "import
only content-addressed implementation artifacts" instruction. Register the run
with `target_subgoals: ["m32.6"]`, session `polylane-c42b-recovery`, and let the
runner's host gate certify. On GO, `docs/polylane/taste-certification/contracts/`
lands on main and `m32.6` closes; on NO-GO, preserve evidence exactly as cycle
42A did.

## Host inventory kept for this recovery

- `/Users/leonardo/Downloads/polylane-c32` — origin clone of the archives
  (now redundant with the canonical `archive/*` refs; deletable once the
  recovery promotes).
- `/Users/leonardo/Downloads/polylane-c41-*`, `/Users/leonardo/Downloads/polylane-c42a-*`
  — worktrees of that clone; same status.
