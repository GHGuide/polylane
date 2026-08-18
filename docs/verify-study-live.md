# Verify — study-live (Cycle 40, run c40-live-harness-20260812-a3)

Lane goal: a frozen live-study compiler plus a certificate-v2 extension that
accepts **only** hash-bound production calibration-v2 and ballot-v2 evidence in
the deciding roles, while every existing fixture and fail-closed path is
preserved. A compiler can validate evidence; it cannot create a browser run, a
human label, an independent panel, or a passing study. So this lane proves chain
**shape and closure**, and every study certificate records
`live_study_executed:false` with the still-external prerequisites named.

Owned surface: `bin/polylane-taste-study.sh` (new), `bin/polylane-taste.sh`
(live-mode extension), `tests/test-taste-study-live.sh`,
`tests/test-taste-live-harness-e2e.sh`, this file, and
`docs/status-study-live.md`. No producer/adapter, benchmark, or protocol file was
touched.

## Role graph — the live study evidence seam

```text
                          taste-study-spec/v1  (preregistered constants)
                                    | freeze  (write-once; refuses overwrite)
                                    v
                          taste-study-freeze/v1
                          freeze_sha256 = SHA-256( jq -cS(constants) )
                          locks: baseline_revision, current_revision,
                                 corpus_sha256, brief_order, provider_configs(>=2),
                                 calibration_sources/split, panel_cohorts,
                                 thresholds, repair_budget, evidence_prefixes,
                                 claim, analysis
                                    | compile FREEZE MANIFEST CERT SUBJECT_ROOT
        no post-freeze drift  <-----+----->  POLYLANE_TASTE_LIVE=1 taste.sh certify
        subject==current_revision           (live production compiler)
        goal/design/claim match               |
        declared_evidence==evidence_prefixes  |  every deciding role production+bound:
        corpus digest==corpus_sha256          |   calibration -> taste-calibration/v2
        brief-lock id order==brief_order      |     classification:production, session_id,
                                    |         |     corpus_holdout/image/raw/invocation/
                                    |         |     parser bindings (hex64), input_sha256
                                    |         |   ballot -> taste-ballot-validation/v2
                                    |         |     fixture_only:false, classification:production,
                                    |         |     session_ids[2] unique, group_sha256 bound
                                    |         |   threat -> taste-threat-receipt/v2 production
                                    |         |   >=2 provider/model configs; all session ids unique
                                    |         v
                                    |   taste-certificate/v2  (live_mode:true)
                                    |   derives brief wins, preference, Wilson LCB, claim
                                    v
                          taste-study-certificate/v1
                          status STUDY-CHAIN-VERIFIED | NOT-CERTIFIED
                          claim_label = inner (HUMAN_CALIBRATED_MACHINE this cycle)
                          human_certified:false (no actual human ballot exists)
                          live_study_executed:false  (+ external_prerequisites)
                          certificate_sha256 = SHA-256(inner cert)
```

Subject ancestry is delegated: because `manifest.subject_revision` must equal the
frozen `current_revision`, the certificate compiler's existing check (HEAD is the
subject or a **no-merge** descendant whose every post-subject commit touches only
`declared_evidence_paths`) binds ancestry to the frozen revision transitively. A
merge or source-file commit after the subject fails closed
(`UNDECLARED_POST_EVIDENCE_COMMIT`).

## Schema changes

### `bin/polylane-taste.sh` — additive LIVE mode (`POLYLANE_TASTE_LIVE=1`)

Live mode is opt-in and set only by the study compiler; default behaviour is
byte-for-byte unchanged (proven below). All new reason codes are computed only
when `$live` is true.

| Deciding role | Default (compat) accepts | LIVE also requires | Fail code |
|---|---|---|---|
| calibration | `taste-calibration/v1` (schema relaxed to `IN(v1,v2)`) | `taste-calibration/v2`, `classification:"production"`, hex64 `corpus_holdout_receipt_sha256` / `image_manifest_sha256` / `raw_responses_sha256` / `invocation_sha256` / `parser_sha256`, nonempty `session_id` | `CALIBRATION_NOT_PRODUCTION` |
| ballot | `taste-ballot-validation/v2` `fixture_only:false` | `classification:"production"`, `session_ids` array of 2 nonempty strings | `BALLOT_NOT_PRODUCTION` |
| threat | `taste-threat-receipt/v1|v2` clean | `taste-threat-receipt/v2` + `classification:"production"` | `THREAT_NOT_PRODUCTION` |
| session ids | — | every calibration `session_id` and every ballot `session_ids[]` globally unique | `LIVE_SESSION_NOT_UNIQUE` |
| claim | machine calibration ⇒ `HUMAN_CALIBRATED_MACHINE` | `human_certified` stays false unless **every** deciding ballot receipt has `human_certified:true` (structurally unreachable this cycle) | — |

The relaxation `schema_version == "taste-calibration/v1"` →
`IN("taste-calibration/v1","taste-calibration/v2")` is the only change on the
default path; a v2 receipt was previously rejected as `CALIBRATION_INVALID`. All
v1 calibration fixtures still validate as before. New certificate field
`live_mode` records the compilation mode.

### `bin/polylane-taste-study.sh` — new schemas

- `taste-study-spec/v1` — closed-key preregistration input; any missing or
  mistyped locked field is `FREEZE_INVALID`. Thresholds may not be weaker than
  the protocol floor (`preference>=0.70`, `wilson>=0.50`, `brief_wins>=7`,
  `brief_floor>=10`, `groups_per_brief>=5`, `accessibility_regressions==0`);
  `provider_configs` requires >=2 distinct `{provider,model}`.
- `taste-study-freeze/v1` — `{freeze_sha256, constants}`; write-once
  (`FREEZE_EXISTS`), tamper-evident (`FREEZE_BINDING` on recompute mismatch).
- `taste-study-certificate/v1` — `{status, claim_label, human_certified,
  live_study_executed:false, external_prerequisites, certificate_sha256,
  freeze_sha256, subject_revision, verdict_reason_codes}`; atomic write even on
  failure; nonzero exit unless `STUDY-CHAIN-VERIFIED`.

## Backwards-compatibility results

The default (non-live) certificate path is unchanged; every prior certificate
test passes untouched.

```text
$ shellcheck -S warning bin/polylane-taste.sh bin/polylane-taste-study.sh
(exit 0, no findings)

$ bash tests/test-taste-certification.sh
PASS: taste certification compiler        # v1 compat + full v2 hermetic chain + 24 mutations

$ bash tests/test-taste-study-live.sh
PASS: taste study-live compiler           # live positive chain + freeze + 14 mutations

$ bash tests/test-taste-live-harness-e2e.sh
PASS: taste live-harness e2e              # production chain + real producer crossing proof
```

The e2e additionally confirms the default compiler still accepts a genuine
`taste-calibration/v1` producer receipt (`fixture_only:false`, `live_mode:false`)
— the fixture-grade path is preserved exactly while the live path rejects the
same receipt.

## False-positive attacks (risk register, ranked by impact × detectability)

Each row is a way a non-study could be certified as a live study; each is
fail-closed with the exact code, proven by one mutation per role.

| # | Risk | Impact | Control | Code | Proven in |
|---|---|---|---|---|---|
| 1 | Fixture/v1 calibration promoted as production | Critical | live requires calibration-v2 + production bindings | `CALIBRATION_NOT_PRODUCTION` | study `(a)`, e2e `(2)` real producer |
| 2 | Fixture ballot promoted (v1 or `fixture_only:true`) | Critical | live requires ballot-v2 `fixture_only:false` production | `FIXTURE_EVIDENCE`, `BALLOT_NOT_PRODUCTION` | study `(b)(c)`, e2e `(3)` |
| 3 | Replayed / shared session (fabricated independence) | High | every session id globally unique | `LIVE_SESSION_NOT_UNIQUE` | study `(d)` |
| 4 | Non-production threat gate | High | live requires threat-v2 production | `THREAT_NOT_PRODUCTION` | study `(e)` |
| 5 | Subject swapped after freeze | Critical | `subject_revision == current_revision` | `STUDY_SUBJECT_DRIFT` | study `(f)` |
| 6 | Corpus content/order changed after freeze | Critical | corpus digest + brief-lock id order bound | `STUDY_CORPUS_DRIFT`, `STUDY_BRIEF_ORDER_DRIFT` | study `(g)(i)` |
| 7 | Evidence closure widened after freeze | High | `declared_evidence_paths == evidence_prefixes` | `STUDY_EVIDENCE_DRIFT` | study `(h)` |
| 8 | Claim inflated after freeze | Critical | manifest+inner claim == frozen claim | `STUDY_CLAIM_DRIFT` | study `(j)` |
| 9 | Freeze mutated after results | High | recompute `freeze_sha256`; write-once | `FREEZE_BINDING`, `FREEZE_EXISTS` | study `(k)` + freeze re-write |
| 10 | Undeclared post-freeze source commit / merge | Critical | delegated no-merge, evidence-only ancestry | `UNDECLARED_POST_EVIDENCE_COMMIT` | study `(l)` |
| 11 | Threshold weakened after freeze | High | inner results must clear frozen (>=protocol) floors | `STUDY_THRESHOLD_DRIFT` | study `(m)` |
| 12 | Single-configuration monoculture | High | inner `unique_judge_configurations >= 2` | `STUDY_CONFIG_FLOOR` | study `(n)` |
| 13 | Machine panel represented as human | Critical | `human_certified` needs actual human ballots | (label stays `HUMAN_CALIBRATED_MACHINE`) | study `(3)`, e2e `(1)` |
| 14 | Harness mistaken for a real live study | Medium | `live_study_executed:false` + `external_prerequisites` | (asserted) | e2e `(1)` |

Preserved certificate-v2 attacks (still fail closed, unchanged):
`RECEIPT_MISSING`, `RECEIPT_BINDING`, `HASH_MISMATCH`, `STALE_REVISION`,
`SUBJECT_REVISION_INVALID`, `MANIFEST_INVALID`, `JUDGE_NOT_INDEPENDENT`,
`JUDGE_ALIAS`, `JUDGE_NOT_CALIBRATED`, `BALLOT_QUORUM`, `BRIEF_QUORUM`,
`DUPLICATE_RENDER`, `SIDE_ORDER_CONTRADICTION`, `ACCESSIBILITY_VETO`,
`REPAIR_BUDGET`, `STATS_MISMATCH`, `RECEIPT_SCHEMA`, `THREAT_GATE`,
`CLAIM_NOT_MET`, `BRIEF_WIN_FLOOR`, `PREFERENCE_FLOOR`, `WILSON_FLOOR`.

## Claim ladder

`MACHINE_EVALUATED` < `HUMAN_CALIBRATED_MACHINE` < `HUMAN_CERTIFIED`. The label is
derived from ballot/calibration provenance, never supplied. This cycle every live
study can reach at most `HUMAN_CALIBRATED_MACHINE`: ballot receipts carry
`human_certified:false` by the c39 constraint (EXTERNAL-EVIDENCE forbids real
human ballots), so the live human gate can never flip
`human_certified` to true, and `human_certified:false` is preserved end to end.
A freeze whose `claim:"HUMAN_CERTIFIED"` would therefore never verify — a stronger
required claim is never silently weakened.

## ADR — one fail-closed compiler, env-gated live mode

**Context.** Cycle 40 must reject v1/fixture receipts in live roles yet keep every
c39 fixture and fail-closed path exactly. **Options.** (A) reimplement the full
transitive-binding chain inside `taste-study.sh`; (B) add an env-gated live mode
to the existing v2 compiler and orchestrate freeze + delegation in
`taste-study.sh`. **Decision: B.** (A) duplicates ~780 lines of hostile-input
validation and creates two compilers to keep in lockstep — a drift/false-negative
risk larger than the coupling it removes. (B) keeps one authority: the live gates
are additive reason codes computed only when `$live`, so the default path is
provably unchanged, and the study compiler is the sole caller that sets the flag.
**Consequence.** A hidden env coupling, mitigated by making the study compiler the
only setter and documenting it; the diff is minimal and every prior test is green.

## Exact prerequisites still external (EXTERNAL-EVIDENCE)

A `STUDY-CHAIN-VERIFIED` certificate proves the frozen chain is production-shaped
and hash-closed. It is **not** a live study. The following remain external and are
recorded in every study certificate's `external_prerequisites`:

- a real browser/Playwright render of every required route/state/viewport;
- pinned human calibration labels from the frozen source corpus;
- an independent, isolated, human deciding panel;
- an executed, evidence-passing live old-versus-new study.

Until real producers (calibration-live, ballot-live, browser-live, decode-live,
a11y-live, task-live, corpus-20, generate-live) emit non-fixture receipts, live
compilation of their genuine hermetic output yields `NOT-CERTIFIED`
(`CALIBRATION_NOT_PRODUCTION`, etc.), never a fixture fallback — proven in the e2e
against the real calibrate producer. No Cycle-40 artifact marks `m32.4` complete
or mints a taste certificate.

## Relay

- Received `prompts-live → study-live` (seq 3): prompts-live spec inputs and the
  digest-pinned baseline `0b802ad…:SKILL.md`. Consistent — the study freeze locks
  `baseline_revision:0b802ad13ada13a0dc7cc702a526ed17d3348851`; no change needed.
- Posted `study-live → calibration-live` and `study-live → ballot-live`: the exact
  live-role consumer contract (production schema strings, required binding fields,
  and session-id semantics) so producers converge on it rather than the consumer
  weakening validation.

## Skill receipts

SKILL-READ: engineering:architecture | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/architecture/SKILL.md | 2056343451-2410
SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630

SKILL-EVIDENCE: operations:risk-assessment — helped: the false-positive table
above is a likelihood/impact risk register built before code; ranking
"fixture promoted as production" and "post-freeze drift" as Critical drove the
one-mutation-per-role negative matrix and the decision to bind the freeze to the
manifest by content hash rather than trust, which is where the
corpus/brief-order/evidence-prefix drift attacks came from.
SKILL-EVIDENCE: engineering:architecture — helped: its options→trade-offs→
consequences ADR frame produced the "one fail-closed compiler, env-gated live
mode" decision, rejecting a second full compiler on the explicit consequence that
two hostile-input validators drift apart; the freeze receipt was likewise chosen
as a self-contained content-addressed record (recomputable freeze_sha256) over
trusting a cross-lane certificate.
SKILL-EVIDENCE: engineering:code-review — helped: reviewing my own jq edits under
its correctness/edge-case lens caught the trailing-newline mismatch between the
freeze `printf '%s' | sha256` and the compile `jq -cS | sha256` (a
`FREEZE_BINDING` false-positive on the honest path) before it shipped, and
confirmed jq `and`/`or` short-circuits so the new `$prod` bindings raise no error
on absent v1 fields in the default path.

## DEFERRED

DEFERRED: the production calibration-v2 and ballot-v2 producers themselves
(calibration-live, ballot-live) are integrator/producer-owned; this lane defines
and enforces their live consumer contract with hermetic production-shaped
fixtures and proves the real c39 producer's fixture output cannot cross it.
DEFERRED: wiring `POLYLANE_TASTE_LIVE` into a runner gate is integrator-owned; the
study compiler is the sole intended setter this cycle.
