# Verify — lane corpus-select (c41-source-calibration-20260812-a1)

## Repair reflection (attempt 1)

1. What went wrong: the prior run spent its whole session on read-only exploration of
   harness helpers and sibling tests, hit repeated interactive Bash approval prompts plus
   a failing PreToolUse hook, and ended without writing a single owned file.
2. Root cause: an exploration-first workflow multiplied permission-gated shell calls;
   prompt stalls and hook noise exhausted the session before a RED test ever existed.
3. Different approach now: write-first TDD — freeze the input contract in this doc,
   write the failing test and the selector immediately with few batched commands,
   hermetic fixtures only, then verify and commit small checkpoints.

## Contract

`bin/polylane-taste-corpus-select.sh` performs deterministic source selection for the
frozen three-domain corpus. It runs strictly before any judge output exists.

```
polylane-taste-corpus-select.sh select SOURCE_MANIFEST RATINGS SEED OUT_DIR
polylane-taste-corpus-select.sh verify SOURCE_MANIFEST RATINGS SEED OUT_DIR
```

Frozen constants (recorded in every receipt, never overridable):

- Domains: `e-commerce`, `universities`, `commercial-banks` (exactly these three).
- Quota per domain: 60 calibration + 24 holdout → 180+72 total. Nothing else.
- Support filter: `support >= 5` valid raters.
- Ambiguity filter: `sd <= 1.5` on the native rating scale.

### Inputs

`SOURCE_MANIFEST` (frozen source manifest, produced upstream by lane `source-freeze`):

```json
{ "format_version": 1,
  "source_revision": "<non-empty revision string>",
  "images": [ { "id": "<stable-id>", "domain": "<frozen domain>", "sha256": "<64 hex>" } ] }
```

`RATINGS` (normalized human ratings, produced upstream by lane `ratings-normalize`):

```json
{ "format_version": 1,
  "scale": { "min": <number>, "max": <number> },
  "ratings": [ { "id": "<stable-id>", "mean": <number>, "sd": <number>, "support": <int> } ] }
```

Fail-closed validation (`CORPUS-SELECT-INVALID`): non-regular/symlink files, invalid
JSON, unknown keys, duplicate ids, duplicate image digests (within or across domains —
digest leakage), domains outside the frozen set, malformed digests, malformed seed.

### Selection

Eligible = images whose rating exists and passes both filters. Rank each eligible item
by `sha256("<seed>|<id>|<image sha256>")`, ascending; per domain the first 60 become
`calibration`, the next 24 become `holdout`. Eligible < 84 in any domain is
`CORPUS-SELECT-UNAVAILABLE` naming the domain — never rebalancing, never borrowing
across domains, and no partial output is published (outputs are staged then moved).

### Outputs (separate manifest and receipt)

- `OUT_DIR/corpus-select-manifest.json` — 252 records `{id, domain, sha256, split}`,
  sorted by domain/split/id, no timestamps: byte-stable for a given (inputs, seed).
- `OUT_DIR/corpus-select-receipt.json` — binds seed, `source_revision`, SHA-256 of the
  source manifest file, SHA-256 of the ratings file, both frozen filters, per-domain
  eligible/selected counts, and the SHA-256 of the emitted manifest file.

### Post-result replacement defence

`verify` re-derives both outputs from the bound inputs and byte-compares them against
the published files, then independently re-checks quota and id/digest disjointness of
the two splits. Any drift — edited record, swapped digest, replaced input — is
`CORPUS-SELECT-REPLACED` (or `CORPUS-SELECT-INVALID` for schema damage). A failed item
therefore cannot be silently replaced after results exist.

## How to verify

```bash
bash tests/test-taste-corpus-select.sh
shellcheck -S warning bin/polylane-taste-corpus-select.sh
```

The test is hermetic: it generates fixture manifests/ratings in a temp dir and covers
determinism, exact quota, changed-seed divergence, split leakage, duplicate ids and
digests, support/ambiguity filtering, insufficient-domain unavailability (no
rebalancing, no partial publish), unknown domains, and post-result replacement attacks.

## Verification result

`bash tests/test-taste-corpus-select.sh` → `PASS: test-taste-corpus-select (29 assertions)`.
`shellcheck -S warning bin/polylane-taste-corpus-select.sh` → clean (rc=0), test script too.
The test was watched failing first (missing tool) before any implementation existed.

## Skill receipts

- SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
- SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630

- SKILL-EVIDENCE: superpowers:test-driven-development — helped: the test was written first and
  watched failing on the missing tool, and two draft defects (bad `awk -v` syntax, leftover jq
  block) were repaired before the first green run instead of shipping unexercised.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: drove the hermetic coverage plan
  (determinism, exact quota, leakage, duplicates, filters, unavailability, replacement attacks)
  enumerated before a single implementation line.
- SKILL-EVIDENCE: engineering:debug — helped: reproduce→isolate→root-cause on the prior failed
  attempt (transcript tail showed permission-prompt stalls during exploration, no files written),
  which selected the write-first repair approach.
- SKILL-EVIDENCE: operations:risk-assessment — helped: ranking post-result replacement and
  quota-rebalance as the critical risks led to the byte-compare `verify` defence and
  stage-then-move publication with no partial output on quota failure.
