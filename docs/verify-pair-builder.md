# Verify — deterministic held-out calibration pair builder

Lane: `pair-builder` · Run: `c41-source-calibration-20260812-a1` · Target: `m32.4`

## What this lane built

`bin/polylane-taste-pairs.sh` compiles the frozen judge-calibration pair set for
Cycle 41 from a held-out selection manifest (`taste-pair-input/v1`) that carries
native-scale human aesthetics ratings per image. It is a pure deterministic
compiler: it never invokes, scores, or names a judge, and it emits no network
traffic.

```
polylane-taste-pairs.sh build INPUT.json SEED OUTDIR
polylane-taste-pairs.sh verify OUTDIR
```

### Frozen contract (constants in the script header)

- Exactly **24 mirrored pairs** (`pair_quota`), each pair also serving as a side
  probe and a mirror probe (`side_probe_n = mirror_probe_n = 24`, quotas ≥ 12
  and ≥ 8 respectively).
- **Same-domain members only**; cross-domain items can never pair.
- **Unique source images**: each of the 48 items appears in at most one pair
  (unique ids and unique `asset_sha256` enforced).
- **Unambiguous pairs only**: native-scale mean delta ≥ **1.00** AND a seeded
  1000-resample **95% bootstrap interval of the mean difference that excludes
  zero** (percentile order statistics 25/976; Park–Miller PRNG seeded from
  `sha256(seed|bootstrap|high|low)` — fully deterministic, no wall clock, no
  `$RANDOM`).
- **Balanced sides**: the gold (higher-rated) stimulus sits left in exactly 12
  of 24 primary presentations; every mirror presentation is the exact flip.
- **Sealed separation**: side assignment (`side-assignment.sealed.json`) and the
  answer key (`answer-key.sealed.json`) are two separate files, individually
  hash-bound by `pair-receipt.json`. The judge-visible `pair-manifest.json`
  carries only opaque stimulus ids and asset digests — no item ids, ratings,
  deltas, gold markers, or judge/provider identity (regex gate, fail-closed).
- **Fail-closed**: schema violation, quota shortfall, ambiguity, stimulus
  identity leakage, or duplicate digests abort before any output directory is
  created; publication is atomic (temp dir + rename).
- `human_certified` is `false` in every receipt; this compiler cannot raise it.

### Input contract (`taste-pair-input/v1`)

Produced upstream from the frozen corpus selection (corpus-select lane):
`run_id`, `corpus_receipt_sha256` (binds the held-out corpus receipt),
`partition: "held_out"` (anything else is rejected), `scale {min,max}`, and
`items[]` of `{id, domain, asset_sha256, ratings[]}` with ≥ 5 raters per item,
ratings on the native scale, unique ids and unique asset digests, and no trust
booleans anywhere in the document.

### Output artifacts

| File | Audience | Content |
|---|---|---|
| `pair-manifest.json` | judge runner | 24 pairs: `pair_id`, domain, primary/mirror left–right opaque stimulus ids, per-stimulus `asset_sha256` |
| `side-assignment.sealed.json` | audit only | stimulus → item/asset/domain bindings, per-pair left/right item ids |
| `answer-key.sealed.json` | audit only | gold stimulus per pair, means, delta, bootstrap CI, probe id lists |
| `pair-receipt.json` | everyone | frozen thresholds, counts, sha256 bindings of all three artifacts + input + corpus receipt |

## How to verify

```bash
bash tests/test-taste-pair-builder.sh        # 46 assertions, hermetic, ~15 s
shellcheck -S warning bin/polylane-taste-pairs.sh
```

Observed on 2026-08-13: `test-taste-pair-builder.sh: 46 pass, 0 fail`;
ShellCheck emits nothing at `-S warning` for both the script and the test.

The test covers, in the lane's mandated cadence: ambiguity (delta floor and
bootstrap-zero rejection), stimulus leakage (provider identity fails closed),
pair reuse (48 unique stimuli/assets/items), cross-domain pairing (never
selected), side imbalance (exact 12/12), answer exposure (no forbidden keys or
item ids in the judge-visible manifest; three distinct sealed artifacts),
byte-level determinism (same seed → identical bytes; different seed diverges),
quota enforcement (exactly 24 pairs; probes ≥ 12/≥ 8), fail-closed input
validation, receipt hash bindings, and tamper detection via `verify`.

## Risk register (residual)

| Risk | L×I | Mitigation | Status |
|---|---|---|---|
| Upstream selection manifest disagrees with this input contract | M×M | schema is fail-closed; integrator wires corpus-select output and reruns focused test | Open (integrator seam) |
| jq float formatting differs across jq versions, breaking cross-host byte determinism | L×L | receipts bind content by sha256 per host; determinism is guaranteed per host/toolchain, audited via receipt hashes | Accepted |
| Sealed files committed next to judge-visible manifest could be read by a careless judge harness | L×H | `.sealed.` naming, separate hashes in receipt, calibration-campaign lane must ship only `pair-manifest.json` to judges | Open (campaign lane) |
| Bootstrap order-statistic convention (25/976) misread as exact 2.5%/97.5% | L×L | convention documented here and frozen in receipt (`bootstrap_n`, `bootstrap_alpha`) | Mitigated |

## Skill evidence

- SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
- SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
