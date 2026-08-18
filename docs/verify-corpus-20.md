# Verify — corpus-20 (Cycle 40, run c40-live-harness-20260812-a3)

Frozen twenty-brief study corpus for the old-versus-new taste study. Five schema-v1
ideas carried over verbatim (title and brief prose byte-identical to
`benchmarks/schema-v1/*.json`) plus the fifteen named additions from the Cycle 40
plan. Every unit is `taste-study-brief/v1`; the study manifest is
`taste-study-manifest/v1` per PROTOCOL §4.3. All units were frozen before any
generation; the study subject is the `PENDING-CYCLE-40-GO` placeholder resolved only
after the Cycle 40 GO verdict.

## Schema and validation command

```bash
bash tests/test-taste-corpus-20.sh          # 991 assertions, exit 0
bin/polylane-check.sh "$PWD/.polylane/check-cache/corpus-20" -- bash tests/test-taste-corpus-20.sh
shellcheck -S warning tests/test-taste-corpus-20.sh
```

The validator enforces: exact frozen top-level key set (unknown fields fail closed),
duplicate-JSON-key rejection per file, filename/id match, target-population shape,
`task-<brief_id>` core-task convention, route syntax, state partition of the common
seven with substantive not-applicable reasons, state recipes for every non-default
required state, the frozen action-op allowlist with `data-testid` target convention,
first-step `goto` on a required route, exactly three acceptance facts per brief,
five-part product signatures, anti-goals, fictional content seeds, offline flag,
protocol licence allowlist, safety booleans, decision-support disclaimers on the two
sensitive units, verbatim originals, corpus-wide uniqueness, and reproducible study
digests.

## Diversity table (20 rows)

| brief_id | stratum | category | locale | product shape | not-applicable states |
|---|---|---|---|---|---|
| dog-walk-route | consumer | pet-recreation-planning | en-US | single-page web app | loading, validation-error |
| pantry-planner | consumer | home-food-inventory | en-CA | mobile-first web app | loading |
| repair-reminder | operations | rental-maintenance-tracking | en-GB | web dashboard | loading |
| shift-handoff | health | clinic-shift-continuity | en-US | responsive web app | loading |
| study-circle | education | adult-learning-group | en-IE | collaborative web app | loading |
| bookstore-events | culture | indie-bookstore-events | en-GB | storefront events page | loading |
| climate-data-explorer | data | local-climate-records | en-AU | read-only data explorer | loading, empty, validation-error |
| neighborhood-bulk-order | collaboration | neighborhood-bulk-buying | en-PH | community coordination page | loading |
| field-recording-catalog | creative | field-audio-archive | ja-JP | library-style catalog app | loading |
| makerspace-booking | operations | equipment-reservation | fr-CA | kiosk-style booking board | loading |
| pediatric-appointment | health | pediatric-visit-preparation | es-US | mobile-first checklist app | loading |
| art-residency-portfolio | creative | residency-application-portfolio | pt-BR | curation workspace | loading |
| freight-dispatch | logistics | regional-freight-dispatch | en-ZA | operations control board | loading |
| farmers-market-portal | finance | market-vendor-ledger | en-NZ | tablet-friendly reconciliation portal | loading |
| cash-runway | finance | small-business-cash-runway | en-SG | single-page projection dashboard | loading |
| urban-tree-census | data | urban-tree-inventory | nl-NL | field-entry web app | loading |
| fermentation-tracker | consumer | home-fermentation-log | sv-SE | kitchen logbook app | loading |
| live-music-calendar | culture | live-music-listings | de-DE | filterable listings site | loading, validation-error |
| language-exchange | education | language-partner-exchange | it-IT | matching board | loading |
| tabletop-atlas | collaboration | shared-campaign-atlas | es-AR | wiki-style atlas | loading |

All ten preregistered strata are covered (consumer 3, collaboration 2, operations 2,
health 2, finance 2, data 2, culture 2, logistics 1, education 2, creative 2).
Categories, titles, brief prose, core-task ids and summaries, audience roles,
signature mechanisms, all 60 acceptance facts, and file digests are unique
corpus-wide (validator sorts each list and fails on any duplicate). Every brief
carries `loading` as not-applicable with a brief-specific synchronous-local-data
rationale; `empty` and `validation-error` applicability varies by product as shown.

## Hashes

Per-brief SHA-256 (also recorded in `benchmarks/taste-live/study-v1.json .briefs`):

```
dog-walk-route          e0187e9cf3d1ad51d23b0b312a5e4fe5c0717a859b4100e55533942294481f26
pantry-planner          1f7e87f085bb568eb51d9a6f23113656209a87890d77d34c36ba78d82f060ca5
repair-reminder         f903015d63dd0399920e5fca9ade090dba29d37cb7b9547d0c62dc301f983d07
shift-handoff           9975e293e18bbb27bfdc075bacf89a832bca0bf15f53d10006dda569aedad24d
study-circle            ee56f616bcc38337f17a0d9e0ffe0e19bc408663c5c0e246988ff94453584836
bookstore-events        1bddea166b0e4c03434a2222827cb08a2dfd0a7ee31db57f7a1c222ed3c7f7c1
climate-data-explorer   d858c8a2438a2f55ccc94e58eefe0b87eb483e6882ed6f12dbd962aca1a525d2
neighborhood-bulk-order 47ab2d4a715b96d5968027f077f72691a8f8b973aeaf91ccd318ef6c566b0bd7
field-recording-catalog a782b1eee46ce47a6550a54d0edb3aeab9cd54d142dda69478a2a5522e222a08
makerspace-booking      b500994df1a286cec42ff794004455ac89506ac2e47a57448c3789af39009d30
pediatric-appointment   61510c84de19bd50510f4f85295069e43bf855199755321afa39f665428b9433
art-residency-portfolio d05cea418c8d7805852c52848994976bb8a4f67337a508dabffaa5b73d492886
freight-dispatch        e5c2af63e0751611590121b4efaf81adc05f4e59ba6033014a406ed782287ee5
farmers-market-portal   b142cdfa94e50b87ab42f51717e227a53230f5a2acd05ce3cdee597d449c438e
cash-runway             eec064cd99e80a8b98918131ea2b90bd017b650bbd354c450a41849f9937b70b
urban-tree-census       2661fca7773c7bf2eb64093eb2305f0ff7a29867ad097503c391c91eb99a74e6
fermentation-tracker    18dcbbebc29ce48e62b3f46fa333689cd5b8aff0230691b28fcfc0b591854c41
live-music-calendar     f8a33f987e83a2eb8a2a39daaa2fa4500864f0c0b401150e0bdc118baec547db
language-exchange       41d4323d37ebaefaeac58c64329111b312d74d8bfe72860bc62fe8f32bd370e2
tabletop-atlas          604fee4cb4d8d8b7b3c84a07cd30f7b1f2fd64e4c66dc9e49ba504766f01ada2
```

Study digests (recomputed independently by the validator from the ordered brief
files; any byte change to any brief breaks all three):

```
brief_sampling.manifest_sha256        d8fdf43b93df377ee5eba1c24ce662eb09b1ec62b8e0a955e4cf42ed4c132ff9
executable_core.task_scripts_sha256   3a0c2b9505ad42ee666a54285c0fd79438afc583b1e93378091285657b0a514c
study_digest_sha256                   0a044dec63ebaf299018745ebf297182850e6ce9f6ea991cb083267af664fbae
seed                                  c40-corpus-20-stratified-draw-0b802ad1-20260812
```

Recompute rules: `manifest_sha256` = SHA-256 over `"<id> <sha256(file)>\n"` lines in
`brief_order`; `task_scripts_sha256` = same over `"<id> <sha256(jq -cS .action_oracle)>\n"`;
`study_digest_sha256` = SHA-256 of the four newline-terminated lines
manifest-digest, task-digest, baseline revision, seed.

## Duplicate / copy checks

- File SHA-256 values are pairwise distinct (no unit copies another).
- Categories, titles, brief prose, core-task ids/summaries, roles, signature
  mechanisms, and every acceptance fact deduplicate to their full counts.
- The five originals are byte-compared against `benchmarks/schema-v1/`: `title` and
  `brief` must match exactly; drift fails the validator.
- Additions must carry `origin: "cycle-40-plan"`; originals `origin: "schema-v1"`.
- Duplicate JSON key paths inside any file fail via `jq --stream` per PROTOCOL §5.

## Study freeze (benchmarks/taste-live/study-v1.json)

- Order: the 20-item `brief_order` above; strata map places all 20 across 10 strata.
- Baseline revision `0b802ad13ada13a0dc7cc702a526ed17d3348851` (one prompt, one build).
- Current subject: `PENDING-CYCLE-40-GO`, resolved only after the Cycle 40 GO verdict
  to the final clean merge revision, frozen before generation.
- Builder frozen: provider `anthropic`, model `claude-fable-5`, single fixed
  configuration for both arms.
- Rules frozen: 3 current directions, 2-repair cap, 20-brief target, 10-brief floor.
- Thresholds unchanged from PROTOCOL: pooled preference >= 0.70, Wilson LCB > 0.50,
  >= 7 brief wins, >= 5 mirrored groups per brief, 0 accessibility regressions,
  calibration 17/24 with Wilson >= 0.50, side probe p >= 0.05, < 2 mirror
  contradictions.
- Tracks and optional audits mirror PROTOCOL §4.3; compiler capacity 100.

## Safety boundaries

- Every unit: `offline: true`, remote assets forbidden, licence allowlist frozen to
  the protocol set (owned, public-domain, CC0, OFL, MIT, BSD, Apache).
- Every unit: `no_medical_claim`, `no_financial_claim`, `no_live_transaction`, and
  `fictional_data_required` all true; content seeds are entirely invented.
- `pediatric-appointment` and `cash-runway` carry mandatory decision-support
  disclaimers (validator-enforced, must contain "decision support"): not medical
  advice / not financial advice, fictional data only. `shift-handoff` adds a
  voluntary not-a-medical-record disclaimer; `fermentation-tracker` forbids
  food-safety verdicts via anti-goals.
- Money-adjacent units (`farmers-market-portal`, `bookstore-events`,
  `neighborhood-bulk-order`, `cash-runway`) are record-keeping or projection only;
  anti-goals forbid payment processing, ticket sales, and money movement.

## External-evidence boundary

These are locally authored benchmark briefs. They are not evidence of market demand,
user preference, or deployment; no external claim is made or implied.

## Skill receipts

SKILL-READ: design:user-research | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/user-research/SKILL.md | 42109971-1751

SKILL-READ: product-management:product-brainstorming | /Users/leonardo/.codex/plugins/cache/claude-cowork/product-management/1.2.0/skills/product-brainstorming/SKILL.md | 3615960678-15944

SKILL-READ: product-management:write-spec | /Users/leonardo/.codex/plugins/cache/claude-cowork/product-management/1.2.0/skills/write-spec/SKILL.md | 3505650752-12326

SKILL-EVIDENCE: design:user-research — helped: its "who has this problem and what are they doing today" framing drove one distinct role/locale/coverage-limit triple per brief (twenty distinct roles, fourteen locales) instead of a generic "user" audience.

SKILL-EVIDENCE: product-management:product-brainstorming — helped: varying solutions along meaningful dimensions (scope, information unit, interaction) produced twenty distinct signature mechanisms (capacity bars, reciprocal-pair matcher, backlink web, seat meters, decade comparator) rather than one CRUD list re-skinned.

SKILL-EVIDENCE: product-management:write-spec — helped: its testable acceptance-criteria discipline ("avoid ambiguous words, each criterion independently testable") shaped the three concrete acceptance facts and deterministic success oracles per brief, each anchored to seeded numbers the validator can cross-check.
