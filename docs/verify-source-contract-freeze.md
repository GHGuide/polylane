# Source/calibration v3 contract verification

Run: `c42a-taste-contracts-20260813-a2`
Subgoal: `m32.6`
Lane: `source-contract-freeze`

## Outcome

The owned validator, schema, and example now freeze the executable source and
human-calibration trust boundary. The example is deliberately `kind:fixture`, has
claim ceiling `AUDIT_ONLY`, and keeps `human_calibrated:false`,
`human_certified:false`, and `taste_certified:false`. Validation performs no
network access, provider call, recruitment, payment, or human study.

The executable interfaces are:

```text
bin/polylane-taste-source-contract.sh validate CONTRACT.json
bin/polylane-taste-source-contract.sh verify-stage-b CONTRACT.json RECEIPT.json
```

`validate` checks strict keys and pinned values, the canonical whole-contract
hash, three internal plan/split hashes, cross-record uniqueness and quotas,
authority ceilings, statistical boundaries, and resource inequalities.
`verify-stage-b` validates the contract first and then checks every receipted
local file against selected reachability, the selected-plan hash, frozen split
identity, declared size, upstream checksum, and locally recomputed SHA-256.
Partial Stage B receipts remain partial and do not imply source completion.

## Red-first evidence

The first runnable focused test failed at the expected missing-production edge:

```text
expected success: .../bin/polylane-taste-source-contract.sh validate .../good.json
.../bin/polylane-taste-source-contract.sh: No such file or directory
```

The fixture generator itself was corrected once before that red observation
because its initial jq numeric formatting expression errored; that parser error
was not counted as a valid RED. Production code was then added and iterated until
the same behavior-level suite passed.

## Frozen sources and observed pins

### STATIC_HOMEPAGE_AE_SANITY_CALIBRATION

- Metadata-first and zero bytes/outcomes before selection freeze.
- Releases pinned by DOI/version plus file ID, name, declared size, upstream
  checksum, raw-ratings local digest, and compliant-session digest:
  `10.7910/DVN/9FKSQI@4`, `10.7910/DVN/XOI0HI@3`, and
  `10.7910/DVN/Z7KLIH@2.1`.
- Sessions are filtered before normalization; reassignment is exactly zero.
- Within-source z-scores preserve valid negative values and forbid clipping.
- Duplicate resolution precedes splitting. `b889.jpg` and `b952.jpg` remain
  distinct on the pinned distinct-content decision.
- The publisher-basis residual stays explicitly unexplained: 72 cells, maximum
  absolute residual `0.004141`.
- Observed source pins: 3,180 files; 3,156 JPEG screenshots; normalized rating
  coverage 262 fashion, 443 homeware, 340 university, and 510 banking records.
- Exactly 252 unique content identities: 180 development and 72 holdout, with
  60/24 in each of e-commerce, universities, and commercial banks.
- Authority ceiling: `STATIC_TRANSFER_ONLY`.

### designer_axis_public_audit/v1 (TASTE)

- Hugging Face revision:
  `731a7f588d433214c6d864d2e9f47978d91aed6b`.
- GitHub commit: `e37f02d2e79125bb692b432214928101f026fcc9`.
- All seven Cycle 42 research digests are exact schema/validator constants.
  Stage A permits only the five metadata parquets and forbids both
  `*_with_images.parquet` files.
- Observed pins: 654 files, 644 images, 1,598,746,498 bytes, 14,460 ranking
  rows, 721 prompts, and ten evaluators.
- Whole-unit quarantine is mandatory for the source-613 two-scene collision,
  ten malformed evaluator cells/two prompt-criterion groups with eight assets,
  and twenty null-linked hallucination rows.
- `scene_id` is declared as
  `sha256(track || sorted(content_sha256 of all four scene assets))`.
- Exactly nine criteria times eight pairs = 72 globally scene-disjoint pairs;
  every pair has at least 4/5 agreement and resolves to exactly 144 selected
  image identities in this maximum-size fixture.
- Authority ceiling: `AUDIT_ONLY`; `can_activate_hcm:false`.
- The UI-judge source remains exactly `UI-JUDGE-SOURCE-UNAVAILABLE`; unofficial
  substitution is forbidden until an official licensed hash-pinnable release
  exists.

## HCM-v2 external target-matched lock

- Natural pairs: exactly 320 over 40 leakage-disjoint brief families:
  120 development/15 families, 40 validation/5 families, and 160 one-shot
  confirmatory/20 families.
- Excluded anchors: exactly 32.
- Leakage keys are unique across brief lineage, template, asset pack,
  generation run, generation seed, source example, and visual-near-duplicate
  cluster. Every pair requires equivalent-content, task, accessibility, and
  provenance gates.
- Target users: exactly 80 eligible judgments per pair, split 20 each across
  desktop A/B, desktop B/A, mobile A/B, and mobile B/A; viewports are
  1440x900 and 390x844; at least 3,200 completed participants; at most eight
  natural pairs plus two anchors per participant; zero repeat pair exposure.
- Professional audit: 12 judgments per pair, at least 96 credentialed
  designers, at most 40 pairs per designer, and ballots never pooled with
  target-user ballots.
- Governance binds nonempty external requirements for ethics/privacy
  determination, consent, compensation, population frame, locale/quotas,
  tasks, viewports, randomization, exclusions, retention, withdrawal, ballots,
  analysis, and governance ownership.
- Status remains `EXTERNAL-EVIDENCE-OPEN`. None of those fields is a receipt
  claiming that the external requirements were completed.

## Judge, statistics, and lifecycle boundaries

The fixture contains five primary configurations plus one availability reserve.
It spans three provider-organization IDs and three verified base-lineage IDs,
with two configurations per lineage and `n_eff=3.0`. Strict keys reject provider
or lineage aliases; endpoint/configuration identities are unique. Instance,
session, and invocation reuse counts are zero, self-lineage violations are zero,
and only one allowlisted infrastructure retry with a fresh session and both
attempt receipts is permitted. Substantive retries are zero.

Boundary vectors exercised by the 60-assertion suite:

| Contract edge | Accepted boundary | First rejected value |
|---|---:|---:|
| Mirrored position reversals / 240 | 6 | 7 |
| Self-lineage selections / 300 | 135–165 | 134 |
| Verbose-candidate selections / 300 | 135–165 | 166 |
| Designer both-mirror-correct / 120 | 84 | 83 |
| Designer Wilson lower 95% | `>0.60` | `<=0.60` |
| Designer macro / every stratum | `>=0.70` / `>=0.60` | below either bound |
| Target-user coverage | `>=0.80` | `0.799` |
| Brier-skill lower 95%, overall/strata | `>0` | `0` |
| Calibration-in-the-large absolute error/class | `<=0.05` | `0.051` |
| Weighted calibration error / upper 95% | `<=0.08` / `<=0.12` | `0.081` / `0.121` |
| Repeat stability | `>=0.95` | `0.949` |
| Orientation effect absolute value | `<=0.05` | `0.051` |
| Effective independent panel size | `>=3.0` | `2.99` |

Every judge output contract names `p_A`, `p_tie`, `p_B`, and `abstain`, with
probabilities required to sum to one. Correlation aggregation is pinned to
empirical error clustering, 10,000 stratified bootstrap replicates, identical
error-vector merging, CAPA lower-95 threshold 0.75, double-fault at least twice
independence with Holm `p<=.01`, upper-95 phi, at least three eligible
non-abstaining clusters, and a strict majority of at least three.

## Resource boundaries

The validator requires nonnegative integral manifest ceilings before calls and
enforces `planned <= call ceiling`, `used <= call ceiling`, infrastructure retry
usage `<= retry ceiling`, and zero substantive retries. Tests accept equality
and reject ceiling + 1 for calls and infrastructure retries.

Storage uses the exact preflight inequality:

```text
retained_CAS + remaining_selected_bound + max_active_stage + 5 GiB safety floor
  <= capacity
```

Equality passes and one byte over fails. Source, staging, quarantine, and
retained-byte ceilings likewise pass at equality and fail at ceiling + 1.
Content-addressed original bytes, reference-not-copy orientations, byte-exact
pixels, deterministic gzip with decompression verification, atomic read-only
publication, unreferenced-staging-only cleanup, and pinned claim ancestors are
mandatory.

## Focused verification

Required direct checks:

```text
$ bash tests/test-taste-source-contract-v3.sh
ok - taste-source-contract-v3 (60 assertions)

$ shellcheck -S warning bin/polylane-taste-source-contract.sh
(no output; exit 0)
```

Additional checks: both JSON files parse with jq; the repository example passes
the executable validator; `git diff --check` exits zero.

The unchanged focused checks were rerun through the lane cache. The prescribed
`$POLYLANE_PROJECT_ROOT/bin/polylane-check.sh` path is absent in this runtime;
the identical source-tree helper at `$POLYLANE_SOURCE_ROOT/bin/polylane-check.sh`
was used with the prescribed cache directory. Observed cache receipts:

```text
CHECK-CACHE: PASS .../source-contract-freeze/1119925313-122.output
CHECK-CACHE: PASS .../source-contract-freeze/1974955769-138.output
```

## Frozen example hashes

Canonical internal hashes in `source-calibration-v3.example.json`:

```text
contract body  1de30a16f51ad9f3c70e4595cd6ddf98440a922620b202e4a1f2caffc906f62a
static plan    d39618613614c884ae9509383a23056cd20552f1292aee7985ede12ad3ba53cb
TASTE plan     57a3ca1871046b67074f75a996f003ed83179b0907a4f238f88ef9f7f9b4d74f
HCM-v2 split   5f24bec2b38727bb2d53611749fde593ee2d8c47cf7fc205deefe786cf0a2031
```

File SHA-256 values before adding this verification document:

```text
47c674b77203bb5f2cfdfce615c374a3d7318524ad28b4a10babaf55633a57e4  bin/polylane-taste-source-contract.sh
651150db701f7aaf8d7d8201126f8e477a8d80880fc293ab96af03cec662bd9e  docs/polylane/taste-certification/contracts/source-calibration-v3.schema.json
df881837618901c66ab9761788f00fc1e10091548a9f5e9f84afde727abd7fd9  docs/polylane/taste-certification/contracts/source-calibration-v3.example.json
d7d53c4ef2e24713a06386270881d559703e70bd94566bda332280a9540b2be2  tests/test-taste-source-contract-v3.sh
```

## Skill receipts

SKILL-READ: data:statistical-analysis | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/statistical-analysis/SKILL.md | 2702170626-10434

SKILL-READ: data:validate-data | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/validate-data/SKILL.md | 1311249913-14916

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015

## Skill evidence

SKILL-EVIDENCE: data:statistical-analysis — helped: distinguished equivalence
acceptance from failure-to-reject bias, preserved valid negative z-scores, and
made strict versus inclusive statistical boundaries executable.

SKILL-EVIDENCE: data:validate-data — helped: source/null/deduplication checks,
denominator preservation, leakage keys, authority ceilings, and reproducible
canonical hashes became fail-closed assertions rather than narrative claims.

SKILL-EVIDENCE: engineering:testing-strategy — helped: organized coverage around
source integrity, cross-record leakage, external-governance completeness,
statistical edges, retries, and resource ceilings, with Stage B as a local-byte
contract test.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the behavior suite
was observed failing for the absent validator before production implementation,
then drove the minimal executable surface to 60 passing assertions.

## DEFERRED

- `EXTERNAL-EVIDENCE-OPEN`: no HCM-v2 ethics/privacy determination, consent,
  recruitment, compensation, participant judgments, credential verification,
  designer audit, or governance approval occurred here.
- No source download occurred. The example uses generated fixture identities,
  sizes, checksums, ballots, providers, qualifications, and resource figures;
  none may be promoted to live evidence.
- TASTE remains public audit-only evidence with unknowable contamination and
  cannot activate `HUMAN_CALIBRATED_MACHINE`.
- `UI-JUDGE-SOURCE-UNAVAILABLE` remains open until an official licensed,
  redistributable, hash-pinnable release with usable image rights appears.
- The banks 72-cell residual (maximum absolute `0.004141`) remains unexplained;
  the validator preserves the uncertainty and does not invent a cause.
- The JSON Schema encodes structural/cardinality constraints. Relational quota,
  disjointness, hash, boundary, and local-byte checks remain the executable
  validator's responsibility.
- The required project-root cache helper was unavailable; cached reruns used
  the identical source-root helper, as recorded above.
