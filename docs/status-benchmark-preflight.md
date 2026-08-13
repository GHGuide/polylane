STATUS: benchmark-preflight DONE run=c41-source-calibration-20260812-a1

Implementation: `415742f` (`polylane: add deterministic benchmark preflight gate`).

Delivered `bin/polylane-taste-benchmark-preflight.sh`: one deterministic fail-closed
gate before the 20-brief generation wave. Verifies the three live production source
receipts (frozen DOIs, split-manifest byte binding), the complete 180+72 split
(60/24 per domain, unique ids/digests), every cached image against its content
address (batched shasum), the frozen 24-pair holdout mirrored manifests, at least
five audited eligible unique `taste-calibration/v2` configurations (floors recomputed
locally: 24 units, ≥17 correct, Wilson ≥0.50 within 0.0005 of recompute, side p ≥0.05,
<2 mirror contradictions, one shared holdout binding), exact frozen
protocol/prompt/brief hashes plus the constant baseline revision
`0b802ad13ada13a0dc7cc702a526ed17d3348851`, declared browser/build/provider CLIs,
the disk budget, and `human_certified:false` across every input. Emits `READY` with a
content-only closure hash or explicit reason codes; never a partial pass; exit 0/1/2.

Verified: `bash tests/test-taste-benchmark-preflight.sh` →
`PASS test-taste-benchmark-preflight assertions=34`;
`shellcheck -S warning bin/polylane-taste-benchmark-preflight.sh` clean (both via the
lane check cache). Seam contracts for corpus-select / source-freeze / pair-builder /
calibration lanes documented in `docs/verify-benchmark-preflight.md`.

Relay: no pending requests addressed to benchmark-preflight at start or finalize;
durable inbox empty.

SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the suite was written
first and watched fail (rc 127, then a real fixture off-by-one), which caught the
pairs TSV column bug before the gate logic was ever trusted.
SKILL-EVIDENCE: engineering:testing-strategy — helped: drove the one-happy-world plus
per-boundary attack matrix (34 assertions across all nine check families) instead of
redundant unit noise.
SKILL-EVIDENCE: engineering:debug — helped: reproduce→isolate on the 2-minute timeout
(profiled 252 shasum spawns at 4s/run vs 0s batched) led to the xargs batched cache
verification fix.
SKILL-EVIDENCE: operations:risk-assessment — helped: boundary inventory (tampered
cache, symlinks, fabricated Wilson, duplicate judge configs, human overclaim, silent
partial pass) shaped the reason-code set and the fail-closed accumulate-all design.
