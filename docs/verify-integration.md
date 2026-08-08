# Cycle 12 integration verification

Run: `c12-visual-20260808`
Integrator branch: `lane/c12-integrator`

## Merge and review

- Merged the initial `lane/c12-visual-mechanisms` tip at `91ddd5b`, then
  incorporated its final runtime/graph tip `93aa17b` as `59e28e9`.
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
  **7 pass, 0 fail**. This verifies file type only, not browser capture
  provenance.
- The existing session-loss test was isolated from the host disk floor with
  `POLYLANE_MIN_DISK_GB=0`; it retains the production disk guard and now proves
  the intended lost-session path. `bash tests/test-runtime-survival.sh`:
  **2 pass, 0 fail**.
- Fixed startup seed recovery accounting. A lost `send-keys` seed is documented
  as a free launch correction, but `respawn_lane` counted it as a model restart
  and made the efficiency canary reject its own successful recovery. The new
  `test-seed-recovery-accounting.sh` proves startup reseeds cost zero restarts
  while real runtime respawns still cost one.
- Repaired frozen acceptance commands so regular `test-*.sh` files run through
  Bash. The terminal command isolates the known host disk-floor condition, and
  the regression test prevents both command-contract failures from returning.
- A manual terminal probe initially omitted `--targets m12.4` and began replaying
  historical terminal checks. A red regression reproduced the same behavior in
  the runner, which now executes terminal checks only for the current cycle's
  targets. The target-scoped host gate is the authoritative terminal result.
- The first target-scoped host gate exposed the strict 10,000-node fixture at
  **12s** against its frozen 10s ceiling. Same-host comparison measured old
  `main` at **12.27s** and this branch at **10.40s**, disproving a visual-loop
  regression. Profiling isolated about seven seconds in the immutable-map Kahn
  traversal. Ordered compiler output now takes a linear rank-check fast path,
  while arbitrary-order graphs retain the original Kahn fallback. The focused
  fixture is now **5s**, and the cycle/compatibility suite remains green.
- Frozen acceptance previously discarded both command streams, making that
  failure impossible to diagnose from durable evidence. Failed commands now
  emit their return code, command, and a bounded output tail. Passing checks
  remain quiet.

## Focused and compatibility checks

All commands used `bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" --`.

- `bash tests/test-visual-intelligence.sh`: **9 pass, 0 fail**.
- `bash tests/test-skill-acquire.sh`: **13 pass, 0 fail**.
- `bash tests/test-visual-quality.sh`: **7 pass, 0 fail**.
- `bash tests/test-visual-loop-integration.sh`: **28 pass, 0 fail**.
- `bash tests/test-scout.sh`: **25 pass, 0 fail**.
- `bash tests/test-orchestration-contract.sh`: **11 pass, 0 fail**.

The initial integrator did not consume late durable messages naming the final
`93aa17b` tip, so its stale-source NO-GO was retained as evidence but not used
for promotion. The bounded repair merged that exact tip and proved it is an
ancestor of the final branch. The refinement queue contained the duplicated
`context`/`compaction` observation (count 2, cycle 12, evidence `bounded packets
built for run c12-visual-20260808`). **Declined:** it records bounded-packet
construction, not a demonstrated context-loss regression; there is no scoped,
check-backed refinement to promote.

## Final certification

- Before the acceptance-command repair,
  `POLYLANE_MIN_DISK_GB=0 tests/run.sh`: **1,633 passed, 0 failed, 91 test
  files**. Strict graph timings passed unchanged: warm append **224ms** under
  250ms; the 10,000-event fixture **10s** at its 10s ceiling.
- `shellcheck -S warning bin/*.sh`: clean.
- `bash tests/test-skill-parity.sh`: **38 pass, 0 fail**.
- Fresh Codex installation/parity via `bash tests/test-installers.sh`: **26
  pass, 0 fail**; it verifies the installed shared core and visual contract.
- `POLYLANE_MIN_DISK_GB=0 bin/polylane-doctor.sh --rehearse`: both contract-v3
  cases passed. GO reached READY, promoted through exactly one terminal gate,
  cleaned with zero leaks; NO-GO withheld promotion, retained bounded evidence,
  and cleaned the rehearsal fixture.
- The resumed runner must rerun the target-scoped frozen terminal check on this
  exact repair commit before promotion; this document does not self-authorize it.

## External evidence boundary

This repository is the orchestration skill, not a UI product, so this cycle did
not fabricate browser screenshots, live reference fetches, or visual-model
judgements. Deterministic and live orchestration evidence proves the mechanism,
image signatures, repair bounds, installation safety, parity, and complete
supervised lifecycle. A separate old-vs-new UI corpus with real rendered
products and blind visual judges remains external product-quality evidence.

POLYLANE-VERDICT: EXTERNAL-EVIDENCE-OPEN run=c12-visual-20260808
