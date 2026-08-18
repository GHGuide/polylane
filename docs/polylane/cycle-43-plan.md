# Cycle 43 plan — c42a recovery (m32.6)

RUN_ID: `c43-recovery-20260818-a1` · target: `m32.6` · authority:
`docs/polylane/cycle-42a-outcome.md` + `docs/polylane/c42a-recovery-runbook.md`.

One builder + integrator. The cycle imports the frozen v3 contract work from the
immutable c42a handoff `4851bc1` (local+origin ref `archive/c42a-taste-contract-integrator`),
reconciles it with main's post-outage fixes, and certifies against m32.6's frozen
focused acceptance. The 2026-08-13 `PRECHECK_ONLY` suite pass at `1e89f4f` proves
feasibility only; nothing is promoted without this cycle's fresh verdict.

## Lane: contract-import (builder)

Import set (content-addressed, from `4851bc1`):
- `docs/polylane/taste-certification/contracts/` — CONTRACT-LOCK.v3.json,
  EVIDENCE-CLAIM-REGISTRY.v3.json, execution/source-calibration v3 schemas +
  examples, evidence-dag-v3.schema.json, evidence-policy-v3.json
- `bin/polylane-evidence-dag.sh`, `bin/polylane-finalize.sh`,
  `bin/polylane-taste-execution-contract.sh`, `bin/polylane-taste-source-contract.sh`
- `tests/test-taste-execution-contract-v3.sh`, `tests/test-evidence-dag.sh`,
  `tests/test-taste-source-contract-v3.sh`, `tests/test-finalization-watchdog.sh`
- the `--evidence-kind` extension inside `bin/polylane-memory.sh` and the extended
  `tests/test-contract-acceptance.sh`
- the c42a deltas inside `bin/polylane-run.sh` / `bin/polylane-supervisor.sh`
  (~436/59 changed lines vs main) — PORTED onto main's current files, never a
  wholesale overwrite: main gained check_auth, auth-park, supervisor dying-words,
  and model-detection fixes after the handoff, and those must survive.

## Integrator

Merges the builder branch, runs seams + the m32.6 frozen focused acceptance +
full suite once via check-cache + shellcheck, then `READY-FOR-HOST-GATE`
(m32.6's terminal gate is host-owned). NO-GO names repairs.

## Frozen facts

- handoff commit `4851bc1`; status SHA-256 `52c99513054a658f30277856ab04f7d810b672af870717721c86a80a4e93a033`;
  integration-evidence SHA-256 `4eb179e6c543b04e181efa996815b8623821c8bb2a678ab720889e3d98e5fee2`.
- WIP checkpoints above the handoff (`5e0066a`, `1e89f4f`) are auto-retry state,
  not part of the import.
