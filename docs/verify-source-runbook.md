# Verification — source-runbook lane (c41-source-calibration-20260812-a1)

Scope: `docs/polylane/taste-certification/SOURCE-RUNBOOK.md`. All checks run
2026-08-13 on this checkout (branch `lane/c41-source-runbook`). Evidence
classes: everything below is REAL local execution over the current tree;
no network was touched; no fixture is presented as production evidence.

## 1. File-existence checks (every path the runbook labels REAL)

All PASS:

```
PASS exists: bin/polylane-taste-source.sh
PASS exists: benchmarks/taste-live/tools/dataverse-acquire.mjs
PASS exists: bin/polylane-taste-judge-run.sh
PASS exists: bin/polylane-taste-judge-parse.sh
PASS exists: bin/polylane-taste-calibration-live.sh
PASS exists: bin/polylane-taste-calibrate.sh
PASS exists: bin/polylane-taste-corpus.sh
PASS exists: bin/polylane-check.sh
PASS exists: tests/test-taste-source-live.sh
PASS exists: tests/test-taste-judge-run.sh
PASS exists: tests/test-taste-calibration-live.sh
PASS exists: tests/test-taste-calibrate.sh
PASS exists: docs/polylane/taste-certification/PROTOCOL.md
PASS exists: docs/polylane/cycle-41-plan.md
PASS exists: docs/polylane/cycle-41-research.md
PASS exists: docs/polylane/taste-certification/live-harness/source-canary-receipt.json
```

## 2. PLANNED-label honesty (paths the runbook labels PLANNED must be absent)

All 11 absent as claimed: `dataone-metadata`, `source-freeze`,
`download-campaign`, `cache-integrity`, `ratings-normalize`, `corpus-select`,
`pair-builder`, `calibration-campaign`, `calibration-audit`, `panel-freeze`,
`benchmark-preflight` — no matching `bin/*` or `tests/*` file exists in this
tree. (These are sibling-lane deliverables; when the integrator merges them,
the runbook's §1 labels must be re-verified.)

## 3. Command-surface checks (usage lines exercised, no network)

```
polylane-taste-source.sh no-args           rc=2  usage printed        PASS
dataverse-acquire.mjs --selftest           rc=0  (hermetic)           PASS
polylane-taste-judge-run.sh no-args        rc=2  usage printed        PASS
polylane-taste-calibration-live.sh parser-sha =
  a00e1dfa9348670c1bad680912fc49caf89be332ecc67508de3b54ccf4972514   PASS
polylane-taste-calibrate.sh no-args        rc=64 usage printed        PASS
polylane-check.sh no-args                  usage printed              PASS
```

## 4. Hermetic tests named in the runbook (run via check-cache wrapper)

```
bin/polylane-check.sh "$PWD/.polylane/check-cache/" -- bash tests/test-taste-source-live.sh        PASS
bin/polylane-check.sh "$PWD/.polylane/check-cache/" -- bash tests/test-taste-calibration-live.sh   PASS
```

These are fixture-grade hermetic tests (no network, no model); they verify
the tooling the runbook documents, not the external campaign.

## 5. Stale-claim grep results (over the runbook)

- `human_certified` appears twice, both asserting it stays `false`; no text
  asserts or promises `human_certified:true`. PASS.
- Success-promise grep (`guarantee|will succeed|always succeeds|promise…success`):
  the only hit is line 6, "This runbook never promises success." PASS.
- Credential grep (`cookie|credential|api key|profile`): every hit is a
  prohibition (never copy/import/log); no instruction to copy or reuse
  credentials exists. PASS.
- Env-var cross-check: `POLYLANE_SOURCE_LIVE`, `POLYLANE_SOURCE_CANARY_FILE`,
  `POLYLANE_SOURCE_CANARY_TIMEOUT_MS`, `CHROME_BIN` each appear in the
  runbook and in the corresponding script/adapter source. PASS.
- Frozen-constants cross-check: runbook's eligibility row (24 pairs, ≥17
  correct, Wilson ≥0.50, side-probe p ≥0.05, <2 mirror contradictions)
  matches `bin/polylane-taste-calibration-live.sh` lines 549–552 and
  `docs/polylane/cycle-41-research.md`. Split 180+72 / 60-24 matches the
  research lock. DOIs match the research-lock table. PASS.

## 6. Known limits of this verification

- The disk-estimate `jq` path (`.data.latestVersion.files[].dataFile.filesize`)
  is documented with an explicit "verify against the actual envelope" caveat;
  no real Dataverse envelope exists locally to test it against (EXTERNAL).
- No live canary, download, or provider call was executed in this lane; the
  runbook's EXTERNAL/PLANNED phases remain `EXTERNAL-EVIDENCE-OPEN` exactly
  as the cycle plan requires.

## Skill receipts

SKILL-READ: deep-research | /Users/leonardo/.agents/skills/deep-research/SKILL.md | 3883242303-4343
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: operations:risk-assessment — helped: runbook §§8–13 (interruption recovery, challenge rule, provider failures, stop conditions) were structured as controllable-risk → mitigation → owner-action pairs per the register format.
SKILL-EVIDENCE: engineering:testing-strategy — helped: verification separates hermetic-unit (selftest), integration (focused lane tests), and external layers, and §6 records the coverage gap explicitly.
SKILL-EVIDENCE: superpowers:test-driven-development — helped: label checks (§§1–2) were designed to fail first (a PLANNED file appearing or a REAL file missing flips a PASS to FAIL), keeping the runbook's claims falsifiable; no production code was written in this docs-only lane.
SKILL-EVIDENCE: deep-research — unused: primary-source reconciliation is owned by the `source-protocol` lane; this lane only cited the already-locked research file.
