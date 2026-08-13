STATUS: source-freeze DONE run=c41-source-calibration-20260812-a1

# Lane source-freeze — Cycle 41 handoff

## Delivered

- `bin/polylane-taste-source-freeze.sh` — hermetic, Bash-3.2-safe compiler:
  `compile HARVARD_DIR DATAONE_DIR OUT.json` and
  `verify HARVARD_DIR DATAONE_DIR PLAN.json`. Reconciles
  `taste-harvard-receipt/v1` with `taste-dataone-receipt/v1` for exactly the
  three frozen DOIs (`9FKSQI`/`XOI0HI`/`Z7KLIH` with their immutable DataONE
  PIDs, hard-coded) and emits one canonical `taste-source-freeze-plan/v1`
  with source hashes and selected acquisition inputs (one raw + one
  aggregate + images per domain), sealed by `freeze_sha256`.
- Fail-closed on: DOI/PID/domain/licence/version/file-identity disagreement
  (`SOURCE-MISMATCH`), missing domain on either side, duplicate file id or
  name, caller-authored trust bits (any boolean or
  eligible/certified/trusted/verified/approved key), strict-key violations,
  non-CC0 licence, symlinked or invalid receipts, overwrite of an existing
  plan, and any post-freeze mutation of plan or inputs (byte-exact replay).
- `tests/test-taste-source-freeze.sh` — hermetic, 54 assertions covering
  strict keys, canonical serialization (byte-identical recompile),
  disagreement classes, replay, duplicates, licence drift, version drift,
  and the all-three-domain quota. No partial plan survives a failed compile.
- `docs/verify-source-freeze.md` — authoritative receipt/plan contract,
  frozen table, operator verification, ceilings and seam notes.

## Verification evidence

- `bash tests/test-taste-source-freeze.sh` → `ok - taste-source-freeze (54 assertions)` (CHECK-CACHE PASS `4096992923-107`).
- `shellcheck -S warning bin/polylane-taste-source-freeze.sh` → clean (CHECK-CACHE PASS `3755643666-126`).
- TDD: test written first and observed red (`No such file or directory` for
  the compiler), then green at 54 assertions, then trap-cleanup refactor
  stayed green with zero tmp leaks.
- Relay checked at start and finish: no requests addressed to source-freeze;
  worker inbox empty.

## Skill receipts

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630

SKILL-EVIDENCE: superpowers:test-driven-development — helped: red test observed failing before any compiler code existed; the failing-first cycle caught the verify-trap tmpfile leak during the refactor step while staying green.
SKILL-EVIDENCE: engineering:testing-strategy — helped: pyramid framing kept the suite one hermetic focused script (data-integrity/input-validation tier) instead of live-network E2E; drove the drift/duplicate/quota coverage matrix.
SKILL-EVIDENCE: engineering:debug — helped: reproduce→isolate loop on the tmp-leftover finding proved the two leaked replay files predated the trap refactor (timestamps), avoiding a wrong fix.
SKILL-EVIDENCE: operations:risk-assessment — helped: risk framing (mirror substitution, silent majority-vote, post-freeze tamper, trust-bit smuggling) selected the fail-closed set: hard-coded frozen table, byte-exact replay, overwrite refusal, no-partial-plan guarantee.

## Seam notes for the integrator

- Receipt schemas are the lane interface; `dataverse-transport` and
  `dataone-metadata` outputs must land as `HARVARD_DIR/<domain>.json` and
  `DATAONE_DIR/<domain>.json` per docs/verify-source-freeze.md. Field-name
  seams reconcile against that contract.
- Version normalization drops one trailing `.0` only (Harvard `4.0` ==
  DataONE `4`); anything else is drift and terminal.
- The 180+72 image quota stays downstream (`corpus-select`,
  `benchmark-preflight`); this lane freezes identity and acquisition inputs.
