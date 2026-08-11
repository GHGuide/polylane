# Calibration corpus verification

`bin/polylane-taste-corpus.sh` is hermetic: it reads only a supplied local JSON
manifest and never fetches or claims to acquire a corpus or human labels.

## Contract

`validate MANIFEST.json` accepts format version 1 only when every source has a
stable ID, pinned source reference and SHA-256, and an explicit allow-listed SPDX
license receipt with URL and SHA-256. Every record has a stable ID, source join,
asset SHA-256, human rating, domain, and either `calibration` or `holdout` split.
It requires at least three domains, equal nonzero calibration/holdout counts in
each domain, no duplicate record IDs or asset hashes, and no boolean fields. The
last condition prevents a caller from substituting a trust/verification assertion
for independently checkable evidence.

`sample MANIFEST.json SPLIT COUNT SEED` validates first, then orders eligible stable
IDs by SHA-256 of `SEED|ID`; ties resolve by ID. It therefore returns the same IDs
for the same manifest, split, count, and seed regardless of manifest record order.

## Focused verification

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/calibration-corpus" -- bash tests/test-taste-corpus.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/calibration-corpus" -- shellcheck -S warning bin/polylane-taste-corpus.sh tests/test-taste-corpus.sh
```

Observed: `PASS test-taste-corpus assertions=7`; ShellCheck emitted no warnings.
The test invokes `sample` twice with the same seed and requires byte-identical
two-ID output. It also proves rejection of an unbalanced split, a duplicate asset
hash, an ambiguous `OPEN` license, and a `trusted: true` caller assertion.

## Skill receipts

SKILL-READ: data:validate-data | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/validate-data/SKILL.md | 1311249913-14916

SKILL-READ: design:research-synthesis | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/research-synthesis/SKILL.md | 335799056-3014

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

## Skill evidence

SKILL-EVIDENCE: data:validate-data — helped: explicit source, deduplication, split-balance, and reproducibility checks became fail-closed manifest assertions.

SKILL-EVIDENCE: design:research-synthesis — helped: the schema separates rated human observations from interpretations and keeps acquisition/label limitations explicit.

SKILL-EVIDENCE: engineering:testing-strategy — helped: focused tests cover the valid path, deterministic sampler, integrity boundaries, and rights boundary.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the focused test failed first because the command did not exist, then passed after the minimal implementation.

## DEFERRED

No corpus download, source acquisition, rendering, or human labels were created in
this cycle. A later approved acquisition step must provide real pinned manifests and
license receipts before this validator can certify any external dataset.
