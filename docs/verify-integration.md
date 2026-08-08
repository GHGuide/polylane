# Cycle 12 integration verification

Run: `c12-visual-20260808`
Integrator branch: `lane/c12-integrator`

## Merge and review

- Merged `lane/c12-visual-mechanisms` at `91ddd5b` as `bea5f20`.
- Merged `lane/c12-shared-contract` at `cb3597f` as `220807f`.
- `git diff --check c9f1bbb..HEAD`: clean; the two lane file lists had no
  ownership overlap.
- The direct seam review confirmed: reference directions need at least two
  source IDs and no source can feed all three directions; only one wildcard is
  allowed; an admitted skill must pass quarantine/audit/benchmark and have a
  project lock before it can be armed; desktop, mobile, empty, loading, error,
  hover, and focus states are required; all three lenses must pass; repairs cap
  at two; and champion replacement requires ten prompts, >=70% wins, and no
  accessibility regression.

## Integration repairs

- Added `skill-benchmark-rejects-zero-threshold`: an unchanged challenger with
  `minimum_improvement: 0` was initially accepted. The admission boundary now
  requires a strictly positive threshold. `bash tests/test-skill-acquire.sh`:
  **13 pass, 0 fail**.
- Added `visual-quality-rejects-nonimage-evidence`: arbitrary nonempty files
  were initially accepted as screenshots. The deterministic gate now requires
  PNG, JPEG, or WebP magic bytes. `bash tests/test-visual-quality.sh`:
  **5 pass, 0 fail**. This verifies file type only, not browser capture
  provenance.
- The existing session-loss test was isolated from the host disk floor with
  `POLYLANE_MIN_DISK_GB=0`; it retains the production disk guard and now proves
  the intended lost-session path. `bash tests/test-runtime-survival.sh`:
  **2 pass, 0 fail**.

## Focused and compatibility checks

All commands used `bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" --`.

- `bash tests/test-visual-intelligence.sh`: **9 pass, 0 fail**.
- `bash tests/test-skill-acquire.sh`: **13 pass, 0 fail**.
- `bash tests/test-visual-quality.sh`: **5 pass, 0 fail**.
- `bash tests/test-visual-loop-integration.sh`: **28 pass, 0 fail**.
- `bash tests/test-scout.sh`: **25 pass, 0 fail**.
- `bash tests/test-orchestration-contract.sh`: **11 pass, 0 fail**.

The durable integrator inbox was empty. The refinement queue contained the
duplicated `context`/`compaction` observation (count 2, cycle 12, evidence
`bounded packets built for run c12-visual-20260808`). **Declined:** it records
the bounded-packet construction, not a demonstrated context-loss regression;
there is no scoped, check-backed refinement to promote. This branch records the
decision without directly mutating the canonical `main` worktree.

## Final certification

- `tests/run.sh`: **1,612 passed, 2 failed, 90 test files**. The failures were
  `benchmark-warm-append-under-250ms` (**332ms**) and
  `events-fixture-10000-linear-time` (**11s**, ceiling 10s). Thresholds were
  not weakened and unrelated graph code was not changed.
- `shellcheck -S warning bin/*.sh`: clean.
- `bash tests/test-skill-parity.sh`: **38 pass, 0 fail**.
- Fresh Codex installation/parity via `bash tests/test-installers.sh`: **26
  pass, 0 fail**; it verifies the installed shared core and visual contract.
- `bin/polylane-doctor.sh --rehearse`: **failed**. Its single GO rehearsal
  reported `contract-v3=1 ready=0 promoted=0 terminal_gates=0 cleaned=1
  leaks=0` and `REHEARSE GO FAILED`.

## External evidence boundary

No browser session, live reference fetch, or visual-model judgement was
available in this run. Deterministic fixtures verify mechanisms and image file
signatures only; they do not claim live screenshots, network research, blind
model comparison, or product-quality proof. Those evidence categories remain
open and are not substituted with a pass.

The two deterministic graph benchmark failures and the failed GO rehearsal
block certification before those external items can determine a promotion.

POLYLANE-VERDICT: NO-GO run=c12-visual-20260808
