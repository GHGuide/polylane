# Verify — lane `protocol-live` (Cycle 40)

Run: `c40-live-harness-20260812-a3` · branch `lane/c40-protocol-live` · base HEAD `5165aca`

## Scope

This lane owns documentation only. It updated four shipped/project docs from
future/fixture language to the **exact live harness boundary**, added a contract
test, and produced this verification. It wrote no executable producer, corpus, or
benchmark data (all `FORBIDDEN`).

Owned + written:

- `docs/polylane/taste-certification/PROTOCOL.md` (updated)
- `docs/polylane/taste-certification/RESEARCH.md` (updated)
- `references/visual-intelligence.md` (updated)
- `references/prompt-blocks.md` (updated)
- `tests/test-taste-protocol-live.sh` (new)
- `docs/verify-protocol-live.md` (this file)
- `docs/status-protocol-live.md` (final handoff marker)

## Method

Read once, in listed order: the three selected skills, then AGENTS-side kit —
Cycle 37 research (`cycle-37-research.md`), Cycle 39 implementation proof
(`cycle-39-digest.md`, `cycle-39-plan.md`), Cycle 40 research lock
(`cycle-40-research.md`, `cycle-40-plan.md`), and the provider prompt contracts
(`references/prompt-blocks.md`, `codex/SKILL.md`). Ground truth for every schema,
label, and dimension came from **reading the live producers** in `bin/`
(`polylane-taste.sh`, `polylane-taste-ballot.sh`, `polylane-taste-stats.sh`,
`polylane-taste-calibrate.sh`, `polylane-taste-corpus.sh`, `polylane-check.sh`)
and the runner's `visual_taste_*` gate — never edited, only read to make the docs
match. Graphify (`graphify-out/q.py`) seeded the producer map before broad reads.

## Source citations (primary provenance)

Primary corpus — Miniukovich & Figl homepage-evaluation corpus, three CC0 1.0
Harvard Dataverse releases (dataset id `6830013`, release `4.0`, 1,074 files):

- Commercial banking: https://doi.org/10.7910/DVN/Z7KLIH
- E-commerce: https://doi.org/10.7910/DVN/9FKSQI
- University: https://doi.org/10.7910/DVN/XOI0HI
- Dataset article + methods (`[-3,3]` scale, filtering, standardization, per-page
  aggregation; 3,156 pages, 3,319 sessions): https://pmc.ncbi.nlm.nih.gov/articles/PMC10823051/

Secondary, separately pinned audit — TASTE (14,460 ranking rows, 644 images, five
evaluators/group): Hugging Face `purvanshi/TASTE` at repo SHA
`731a7f588d433214c6d864d2e9f47978d91aed6b` — https://huggingface.co/datasets/purvanshi/TASTE

Acquisition honesty: direct Dataverse API → AWS **WAF** `202`; a real Chrome
session completes the challenge and a same-context API request returns the dataset
and a byte-exact canary (`ratings.avg.fashion.txt`). Cycle 40 productizes this as
an explicit browser adapter (`source-live`), never a bypass or a fixture fallback.
(Full standing bibliography: `RESEARCH.md` §Stable bibliography, refs [1]–[29].)

## Before → after truth audit

| # | Doc claim | Before (future/fixture) | After (live boundary) | Evidence (producer) |
|---|---|---|---|---|
| 1 | Status of the spec | "executable specification for a **future** implementation … creates no browser render … in Cycle 37"; "**no source is written in this cycle**" | Live fail-closed validator core in tree; live adapters frozen for Cycle 40; three-tier §0 map | `bin/polylane-taste*.sh` exist + executable |
| 2 | Pointwise dimensions | 11 (`product_fit,hierarchy,typography,color_imagery,spatial_rhythm,simplicity,expressiveness,craftsmanship,originality,state_coherence,interaction_feedback`) | 8 (`product_fit,hierarchy,typography,color,spatial_rhythm,craftsmanship,originality,state_coherence`) | `polylane-taste-ballot.sh` `validate_pointwise` key-set |
| 3 | Certificate | single `taste-certificate/v1` example, inaccurate field set, `claim_label` enum incl. `MACHINE_EVALUATED`/`UNKNOWN` | two accurate shapes: `v1` (always `fixture_only:true,production:false`) and `v2` production compiler; derived `claim_label` ∈ {`HUMAN_CERTIFIED`,`HUMAN_CALIBRATED_MACHINE`,`NOT-CERTIFIED`} | `polylane-taste.sh` `write_certificate` + `V2_CERT_FILTER` |
| 4 | `MACHINE_EVALUATED` | listed as an emittable label | marked **reserved — the live compiler never emits it** | `grep MACHINE_EVALUATED bin/` → none |
| 5 | Fixture vs production | not distinguished | every live producer stamps `classification:"fixture"`/`fixture_only:true`; `v2` cert is `fixture_only:false` only with `taste-ballot-validation/v2` (Cycle-40 `ballot-live`, not in tree) | producer comments L122–126 (ballot), L395–407 (taste) |
| 6 | Corpus acquisition | "selected **future** input, not acquired evidence" | WAF-`202`/Chrome-challenge/browser-adapter path stated honestly; dataset id `6830013` v`4.0`; TASTE secondary, never a silent substitute | `cycle-40-research.md` lock |
| 7 | Claim ceiling | `HUMAN_CERTIFIED` framed as the target | ceiling this cycle is `HUMAN_CALIBRATED_MACHINE` (`human_certified:false`); no recruited humans | `V2_CERT_FILTER` `$all_human` derivation |
| 8 | Skill receipts | Cycle-37 kit (research-synthesis, code-review, testing-strategy) | Cycle-40 kit (deep-research, engineering:documentation, legal:compliance-check) with fingerprints | launch record |

Frozen thresholds preserved verbatim in both docs (no post-result change):
20-target / 10-floor, 7 wins, 0.70 preference, Wilson > 0.50, five mirrored groups
per brief, zero accessibility regression, two repairs, 180/72 split (60/24/domain),
judge eligibility 24 pairs / ≥17 / Wilson ≥0.50 / side-probe p≥0.05 / <2 mirror
contradictions.

## Parsed JSON examples

`PROTOCOL.md` carries **17** fenced `json` examples. The contract test extracts
each with the same `awk` the doc prescribes (§5) and asserts (a) `jq -e .` parses
and (b) no duplicate key path via `jq --stream`. Result: **17/17 parse, 0
duplicate-key paths**. One duplicate (`capture_manifest_sha256`, introduced while
expanding the pointwise example to the live 14-key shape) was caught by this test
and removed before commit — the test earns its keep.

## Cross-doc assertions (schema ↔ producer)

The test binds every LIVE `schema_version` the docs present to a real `bin/`
producer, so the docs cannot invent a schema the code lacks:

`taste-evidence-manifest/v1,v2 · taste-certificate/v1,v2 · taste-ballot-validation/v1 ·
taste-pointwise/v1 · taste-mirrored-group/v1 · taste-calibration/v1 ·
taste-capture-manifest/v1 · taste-hard-gate/v1 · taste-corpus-receipt/v1 ·
taste-pixels-receipt/v1 · taste-provenance-escrow/v1 · polylane.taste.stats.v1 ·
polylane.taste.ballots.v1` → all present in `bin/`.

`taste-ballot-validation/v2` is referenced only as a **not-yet-live Cycle-40
`ballot-live` deliverable**; the test fails if the docs call it live while
`bin/polylane-taste-ballot.sh` still lacks it (and fails the other way once it
merges — a reminder to update the docs then).

## Test evidence

```
bash tests/test-taste-protocol-live.sh   → PASS=69 FAIL=0
bash tests/test-docs-truth.sh            → PASS=25 FAIL=0
bash tests/test-marker-contract.sh       → PASS=9  FAIL=0
bash tests/test-skill-parity.sh          → PASS=72 FAIL=0
shellcheck -S warning tests/test-taste-protocol-live.sh → PASS (via bin/polylane-check.sh)
```

`tests/run.sh` globs `test-*.sh`, so the new test joins the full suite the
integrator runs. Full `shellcheck bin/*.sh` and the fifteen-lane e2e are integrator
/ sibling-lane scope, not this doc lane.

## Claims deliberately still forbidden (external / `UNKNOWN`)

These are stated as forbidden in the docs and are **not** asserted anywhere:

- `human_certified:true` / `HUMAN_CERTIFIED` — no recruited deciding human panel exists.
- Host integrity — a receipt binds an adapter's reported facts, not a trusted host.
- Panel identity / independence / collusion — authenticity beyond the attestation is external.
- Population coverage — floors (10/20 briefs, 5 groups) are auditable minima, not power calculations.
- IP / trade-dress non-infringement — appearance never proves copying; routes to external/IP review.
- Manual accessibility — assistive-technology experience is external; automated a11y is a veto, not a proof of usability.
- "Universally better" / "accessible for everyone" / "not AI-made" — no producer emits these.
- Cycle-40 live adapters (browser capture, provider judges, production ballot-v2, 20-brief corpus) are **not** described as merged in this tree.

## Relay

Start and pre-completion relay (`polylane-coordinate.sh pending`) returned
`{"requests":[],"claims":{}}` — no request addressed to `protocol-live`, no name
collision to reconcile. Schema names were aligned to the merged Cycle-39 producer
strings read directly from `bin/`.

## SKILL-EVIDENCE

- SKILL-EVIDENCE: deep-research — helped: its claim-support discipline (every
  factual claim cited to a primary source, evidence-status vocabulary) shaped the
  source-citation section and the before/after audit's "Evidence (producer)" column.
- SKILL-EVIDENCE: engineering:documentation — helped: "keep it current — outdated
  docs are worse than none" and "show, don't tell" drove the fixture/production/
  external three-tier §0 table and the exact producer/command/schema map over prose.
- SKILL-EVIDENCE: legal:compliance-check — helped: its rights/limitations framing
  fixed the CC0-vs-TASTE source-rights split, the WAF-acquisition honesty, and the
  "claims deliberately still forbidden" register (IP/trade-dress, population, host).

## DEFERRED

- DEFERRED: internal schema drift between the two live consumers of
  `taste-mirrored-group/v1` — `polylane-taste-ballot.sh` (exposures carry
  `response_sha256`, `taste-pairwise/v1`) vs `polylane-taste.sh` v2
  (`independence_attestation_sha256`) — documented as-is; reconciling the producers
  is `ballot-live`/`study-live` scope, not this doc lane (FORBIDDEN to edit them).
- DEFERRED: `taste-ballot-validation/v2` field-level shape — left described by role,
  not by exact key-set, because `ballot-live` has not merged; update PROTOCOL §0/§11
  when it lands.
- DEFERRED: whether `MACHINE_EVALUATED` should be removed from the §1 ladder entirely
  vs. kept as a reserved rung — kept + marked reserved this cycle; options left open
  for a future producer that emits it.
