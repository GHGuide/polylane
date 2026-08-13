# Verify — source-adversary (c41-source-calibration-20260812-a1)

Lane: `source-adversary`. Independent black-box attacks against the Cycle-41
source/calibration chain plus a hermetic end-to-end campaign rehearsal.

## How to run

```bash
bash tests/test-taste-source-adversarial.sh
bash tests/test-taste-source-campaign-e2e.sh
```

Both are hermetic and deterministic: fixtures are built in test temp
directories, no network, no provider calls (`EXTERNAL-EVIDENCE: none needed`).
Observed on this tree (bash 3.2 and shellcheck `-S warning` clean):

```
PASS test-taste-source-adversarial assertions=50 seams=7
PASS test-taste-source-campaign-e2e assertions=19 seams=5
```

Integrator mode: `POLYLANE_ADVERSARY_REQUIRE_SEAMS_CLOSED=1` makes any
`SEAM-OPEN` / `SEAM-CANDIDATE-PRESENT` line fatal (exit 1). After merging the
sibling lanes the integrator should run both tests in integrator mode and close
every seam listed below; a seam line never counts as a PASS.

## Attack matrix (runnable today)

Targets: `bin/polylane-taste-source.sh`, `bin/polylane-taste-corpus.sh`,
`bin/polylane-taste-calibration-live.sh`. Every attack asserts a rejection (or
a binding property) observed black-box; none was weakened to fit missing code.

| Attack class | Concrete attacks asserted |
|---|---|
| Mirror substitution | DataONE-flavoured bytes swapped under the pinned Harvard metadata digest → checksum rejection; secondary-audit plan refused by `build`; fixture plan refused by `secondary`; receipt classification derived from plan, never attacker-declared |
| Wrong DOI/version/licence | non-allowlisted SPDX, `http://` licence URL, empty `dataset_version`, empty `dataset_pid`, `http://` dataset URL → plan rejection |
| Challenge HTML cached as data | WAF challenge page pinned as aggregate or raw ratings → join rejection (non-object / missing raw) |
| Redirected partials | zero-byte object, truncated object, digest pinned to a `<sha>.part`-only artifact → rejection (`.part` never satisfies a pin) |
| Duplicate ids/digests | duplicate source id, duplicate image digest across stimuli, same stimulus id joined from a second "mirror" source (no majority vote) → rejection |
| Symlink/traversal | traversal string as digest, uppercase-hex digest, 63-hex digest, symlinked cache object with correct bytes, symlinked plan document → rejection |
| Rating/image mismatch | image remapped to a ghost stimulus, aggregate inflated beyond the native 1–5 scale (within the 0.5 disagreement window), raw ballots out of range, caller-authored trust key (`verified:true`) → rejection |
| Split leakage | calibration/holdout disjoint by asset digest and record id; same-seed rebuild byte-identical; seed re-roll visibly changes the split (and so breaks the receipt's manifest binding); calibration image smuggled into the held-out campaign → `TUNING_HOLDOUT_OVERLAP` |
| Post-result replacement | swapping an image after the receipt breaks `manifest_sha256`; swapping cache bytes after the verdict fails both `verify-cache` and calibration (`IMAGE_BINDING`); no silent item replacement |
| Answer-key leakage | `correct_stimulus` smuggled into a unit, gold field on a ballot → `SCHEMA_REJECTED`; flipped answer key without re-binding → `LABELS_INVALID`; re-bound flipped key → `ACCURACY_FLOOR` plus a visibly different bound labels digest |
| Session reuse | one transcript reused for primary+mirror in two units → `MIRROR_INSTABILITY`; cross-unit transcript reuse probed (currently accepted → seam `session-uniqueness`) |
| Parser replay | last-`FINAL:`-line semantics enforced (early replayed verdict cannot win); near-miss verdict line (trailing space) → `RESPONSE_UNPARSEABLE`; stale parser digest declared per-ballot → `INVOCATION_DRIFT` |
| Fixture promotion | one inline response demotes an otherwise file-backed record to `fixture_only`; `production:true` declared in input → `SCHEMA_REJECTED`; guarded canary without the live env emits `EXTERNAL-EVIDENCE-OPEN`, no receipt |
| Human-certification escalation | `judge.human_certified:true` and `label_provenance:"human-certified"` → `SCHEMA_REJECTED`; every receipt emitted across every case (eligible and rejected) is checked for `human_certified:false` + `machine_panel_claim:"HUMAN_CALIBRATED_MACHINE"` |

## End-to-end rehearsal (test-taste-source-campaign-e2e.sh)

Real chained bindings, not per-tool fixtures: the 24 campaign unit images are
the exact cache objects the manifest selected as holdout; the labels and freeze
blocks bind the stage-2 manifest digest; the campaign input binds the stage-2
acquisition receipt digest. Stages: cache+plan → verify-cache/build →
`corpus validate` → deterministic rebuild → 24-unit mirrored campaign →
eligible **production** `taste-calibration/v2` receipt → six adversarial
replays against the completed run (split leakage, post-result replacement,
receipt replay via `input_sha256`, answer-key rewrite, fixture demotion,
human-certification escalation).

## Interface mismatches and seams for the integrator

Recorded as `SEAM-OPEN` in test output. Each names the owning sibling lane and
the exact assertion to wire at merge time. Risk levels follow the
likelihood×impact matrix (all are High impact for certification honesty).

| Seam | Owner lane | What must reject at merge time | Risk |
|---|---|---|---|
| `dataone-metadata-crosscheck` | source-freeze / dataone-metadata | Pinned metadata bytes are digest-verified but never parsed: wrong-DOI / wrong-version / wrong-licence / challenge-HTML metadata matching its own pin is accepted today. Must cross-check exact DOI, domain, licence, version, file identity; disagreement is `SOURCE-MISMATCH`, never a majority vote | Critical |
| `image-content-verification` | cache-integrity | Challenge HTML pinned as an image object builds successfully today (digest matches by construction). Add content inspection: image magic bytes and minimum plausible size on top of digest checks | High |
| `session-uniqueness` | calibration-campaign | Cross-unit raw-response reuse (same transcript digest in two ballots) is accepted by the v2 validator. Campaign must enforce unique sessions per work unit and reject duplicate raw-response digests across ballots | High |
| `corpus-select-unbalanced-quota` | corpus-select | Frozen production split is 60/24 per domain, but `bin/polylane-taste-corpus.sh validate` requires calibration == holdout per domain and rejects it. Reconcile the unbalanced quota with (or replace) that validator before the real 180+72 corpus can pass | Critical |
| `distribution-drift` | dataone-metadata | No local interface verifies the declared distribution inventory (count/size/checksum) against fetched files | High |
| `download-resume-ledger` | download-campaign | `.part` artifacts never satisfy pins (proved), but bounded-retry resumable download with atomic promotion has no local interface | Medium |
| `benchmark-preflight-gate` | benchmark-preflight | No single deterministic readiness gate before the generation wave | Medium |
| `pair-manifest-freeze` | pair-builder | Unambiguous mirrored pair construction, bootstrap-interval rule, frozen pair manifest: no local interface | High |
| `dataverse-transport-rehearsal` | dataverse-transport | CDP/ephemeral-session transport (readiness poll, redirected download, no personal profile) cannot be rehearsed locally | Medium |
| `ratings-normalize-schema` | ratings-normalize | Fixtures use the cycle-40 normalized shape; actual raw/aggregate source schemas must be parsed without lossy guessing | High |
| `calibration-audit-recompute` | calibration-audit | Independent recompute of correctness/Wilson/side-bias/mirror/config identity over the campaign ledger absent | High |
| `panel-freeze-claim-ceiling` | panel-freeze | Frozen panel configuration and claim ceiling absent | High |

Residual risk (no mechanical check possible at this layer, note for
source-protocol/threat docs): swapping two image digests **between** stimuli of
the same source keeps every digest valid; only upstream filename↔stimulus↔digest
binding during ratings-normalize can pin it. Answer keys leaked *inside prompt
text* are likewise invisible to digest checks; the campaign prompt builder must
never interpolate label material.

## TDD / verification evidence

- Both tests watched failing first where behavior was unknown: stage-2 corpus
  validation genuinely failed on the unbalanced split (became seam
  `corpus-select-unbalanced-quota`), and a bash-3.2 `local` expansion fault was
  found and fixed by running, not by inspection.
- Red-capability proof: scratch copies with one deliberately wrong expected
  code (`MIRROR_INSTABILITY`→`WILSON_FLOOR`, `TUNING_HOLDOUT_OVERLAP`→`SIDE_BIAS`)
  fail at exactly the mutated assertion; integrator seam mode exits 1 on both.
- Cross-unit session-reuse and HTML-as-image attacks were run, observed
  accepted, and recorded as seams — not converted into weakened assertions.

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | bf1b8216e523851a
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 5c5e95830754bbdd
SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | e50bb92cbcb27151
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 82e29810a762c396
