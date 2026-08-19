# Verify — integrator (run `c45-hcm-pipeline-20260819-a1`, target m32.8)

Merged the three HCM-v2 pipeline lanes, proved the pipeline composes end to end
on synthetic fixtures without ever standing in for a human, and ran the frozen
m32.8 focused acceptance plus the full suite fresh in this session.

## Branch tips and ancestry

Cycle base: `5eb2181832d825843a6b8a36dbe8af04b2d65af7` (integrator branch HEAD at
start). `git merge-base` of the integrator branch with each lane tip equals the
cycle base, so every lane descends from it directly.

| lane | branch tip (current, not memorized) | status file |
|---|---|---|
| hcm-corpus | `788c7fe01758cfb48d3a72fffb03b4c06615f485` | `STATUS: hcm-corpus DONE run=c45-hcm-pipeline-20260819-a1` |
| hcm-privacy | `e80653853028a37b04dc9772a67f6efb1b71a604` | `STATUS: hcm-privacy DONE run=c45-hcm-pipeline-20260819-a1` |
| hcm-stats | `97786b45c6cc87ca51bcd902f784f04075ae018c` | `STATUS: hcm-stats DONE run=c45-hcm-pipeline-20260819-a1` |

Merges (all `--no-ff`, ort strategy, zero conflicts — file ownership was fully
disjoint): `1654304` (corpus), `133e977` (privacy), `e0a9075` (stats).
Repairs needed: **none**. No lane touched the contract JSON, a v3 schema,
SKILL.md, references/, or a state file (verified by `git diff --name-status`
against the cycle base per lane). All hits for the registry's prohibited
vocabulary in `bin/` pre-date cycle 45 and are guard comparisons inside the
pre-existing freeze/compile verbs (validators of inner certificates), not
emitters; the c45 diff introduces none.

## Reject screening

Checked every NO-GO trigger; none held:

- **No simulated human anywhere.** Corpus plans are allocations with no verdict
  field; privacy fixtures are specs and boundary probes; stats fixtures are
  synthetic arithmetic vectors with hand-derived answers, never ballots
  presented as evidence about people.
- **No weakened threshold, no reachable prohibited claim.** Each lane reads the
  lock/registry at runtime and carries drift tests (mutated-lock runs recorded
  in each lane's verify doc; re-verified by the passing suites below). The
  claim-safety suite asserts the registry's prohibited labels, statuses, and
  certification flags are absent from sources and unreachable in emissions.
- **No contract/schema edits** (per-lane name-status diffs above).
- **No unbound inlined constants.** The only inlined frozen strings
  (two status literals in the consent script) are bound by
  `assert_external_open_contract`, which fails the command if the contract's
  value changes; every numeric threshold is read from the lock at runtime.
- **Red-then-green proven per lane.** Corpus: both suites red first
  (23/45 and 14/56 passing, gate assertions all red at rc=64). Privacy: judged
  its own file-not-found red as weak and ran an 11-mutation battery, adding
  tests until the 2 surviving mutants were killed. Stats: exit-127 red
  (analysis) and usage-banner red (qualification), plus three real defects
  found by tests before implementation.

## Seam check (cross-module composition, this session)

`git diff --check`: clean. Then a 9-check composition script
(scratchpad `seam-composition.sh`) drove all three lanes' CLIs over shared
fixture artifacts:

1. faithful target+designer allocation → `EXPOSURE-BOUND` (corpus)
2. synthetic 320/32 split passes every structural gate and stops **only** at the
   frozen `split_sha256` gate, rc 1 — the external boundary held (corpus)
3. a stimulus derived from the plan passes `blind-check` (corpus→privacy)
4. the same stimulus carrying a split assignment or a label key is rejected
   (corpus→privacy negative)
5. consent record is PII-free; `external-open` emits all 14 requirements
   unsatisfied (privacy)
6. five analyses → five gates → qualified judge, thresholds from the lock at
   runtime (stats)
7. a blind ballot naming a pair from the corpus plan's universe is admitted and
   binds the SHA-256 of its qualification receipt (stats→privacy→corpus)
8. a ballot carrying a split assignment fails `blind-check` before it can be
   cast (composition-order negative)
9. `claim-scan` over all 14 artifacts the composition emitted: clean

Result: `PASS: hcm-v2 seam composition (9 checks)`.

## Frozen m32.8 focused acceptance (fresh, via check cache)

Exactly the six commands frozen in `docs/polylane/max-state.json`
(sid m32.8, tier focused), all run through
`bin/polylane-check.sh .polylane/check-cache/integrator`:

| command | fresh result |
|---|---|
| `bash tests/test-hcm-v2-split.sh` | PASS — 45 pass, 0 fail |
| `bash tests/test-hcm-v2-exposure.sh` | PASS — 56 pass, 0 fail |
| `bash tests/test-hcm-v2-privacy.sh` | PASS — 62 assertions |
| `bash tests/test-hcm-v2-analysis.sh` | PASS: hcm-v2 analysis |
| `bash tests/test-hcm-v2-qualification.sh` | PASS: hcm-v2 qualification |
| `bash tests/test-hcm-v2-claim-safety.sh` | PASS — 26 assertions |

`shellcheck -S warning bin/*.sh`: clean.

## Full suite (fresh, once)

`POLYLANE_MIN_DISK_GB=0 bash tests/run.sh` (this session, after all three
merges): **SUMMARY: 4340 passed, 0 failed, 186 test files**, exit 0.

## Frozen parameters bound (name → lock value → enforcing lane → proving test → fresh result)

Lock: `docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json`.
Registry: `EVIDENCE-CLAIM-REGISTRY.v3.json`. Every row is read from the
lock/registry at runtime by the enforcing script and re-asserted literally by
the proving test, so a lock change fails the suite before it can change a
verdict. Fresh results are this session's runs from the table above.

| frozen parameter | lock value | lane | proving test | fresh |
|---|---|---|---|---|
| `hcm_v2.natural_pairs.total` | 320 | corpus | test-hcm-v2-split.sh | 45/45 |
| `hcm_v2.natural_pairs.development` | 120 | corpus | test-hcm-v2-split.sh | 45/45 |
| `hcm_v2.natural_pairs.validation` | 40 | corpus | test-hcm-v2-split.sh | 45/45 |
| `hcm_v2.natural_pairs.confirmatory` | 160 | corpus | test-hcm-v2-split.sh | 45/45 |
| `hcm_v2.anchors_excluded` | 32 | corpus | test-hcm-v2-split.sh + test-hcm-v2-exposure.sh | 45/45, 56/56 |
| `hcm_v2.split_sha256` | `5f24bec2…cf0a2031` | corpus | test-hcm-v2-split.sh (lock gate stop) | 45/45 |
| `hcm_v2.source_id` | `HCM-v2` | corpus + privacy | split + privacy suites | 45/45, 62 |
| `hcm_v2.target_users.viewports` | `1440x900`, `390x844` | corpus | test-hcm-v2-exposure.sh | 56/56 |
| `hcm_v2.target_users.max_natural_pairs_per_participant` | 8 | corpus | test-hcm-v2-exposure.sh | 56/56 |
| `hcm_v2.target_users.max_anchors_per_participant` | 2 | corpus | test-hcm-v2-exposure.sh | 56/56 |
| `hcm_v2.target_users.pair_repeat_exposures` | 0 | corpus | test-hcm-v2-exposure.sh | 56/56 |
| `hcm_v2.target_users.judgments_per_pair` | 80 | corpus | test-hcm-v2-exposure.sh | 56/56 |
| `hcm_v2.target_users.min_completed_participants` | 3200 | corpus | test-hcm-v2-exposure.sh | 56/56 |
| `hcm_v2.designers.max_pairs_per_designer` | 40 | corpus | test-hcm-v2-exposure.sh | 56/56 |
| `hcm_v2.designers.judgments_per_pair` | 12 | corpus | test-hcm-v2-exposure.sh | 56/56 |
| `hcm_v2.designers.min_credentialed_designers` | 96 | corpus | test-hcm-v2-exposure.sh | 56/56 |
| `hcm_v2.designers.separate_from_target_user_ballots` | true | corpus | test-hcm-v2-exposure.sh | 56/56 |
| `hcm_v2.governance_requirements_are_external` | true | privacy | test-hcm-v2-privacy.sh | 62 |
| `hcm_v2.status` / `hcm_v2.authority` | external-open / target-matched | privacy | test-hcm-v2-privacy.sh | 62 |
| registry `private_hcm_v2_prerequisite` certification flags | both false | privacy | test-hcm-v2-claim-safety.sh | 26 |
| registry `external_requirements` | 14 items, never satisfiable | privacy | test-hcm-v2-privacy.sh | 62 |
| registry `certification_mint_authority` | `NONE_IN_V3` | privacy | test-hcm-v2-claim-safety.sh | 26 |
| registry prohibited labels/statuses/flags | unreachable | privacy | test-hcm-v2-claim-safety.sh | 26 |
| `target_user.coverage_min` | 0.80 | stats | test-hcm-v2-qualification.sh | PASS |
| `target_user.brier_skill_lower_95_strict_min` | 0 (strict) | stats | analysis + qualification suites | PASS |
| `target_user.strata_brier_skill_lower_95_strict_min` | 0 (strict) | stats | qualification suite | PASS |
| `target_user.repeat_stability_min` | 0.95 | stats | qualification suite | PASS |
| `target_user.orientation_effect_abs_max` | 0.05 | stats | qualification suite | PASS |
| `target_user.calibration_in_large_abs_max_per_class` | 0.05 | stats | qualification suite | PASS |
| `target_user.weighted_calibration_error_max` | 0.08 | stats | analysis + qualification suites | PASS |
| `target_user.weighted_calibration_upper_95_max` | 0.12 | stats | qualification suite | PASS |
| `designer.decisive_pairs` | 120 | stats | qualification suite | PASS |
| `designer.both_mirror_correct_min` | 84 | stats | qualification suite (84 passes, 83 fails) | PASS |
| `designer.macro_agreement_min` | 0.70 | stats | qualification suite (one-ULP boundary pinned) | PASS |
| `designer.stratum_agreement_min` | 0.60 | stats | qualification suite (Simpson fixture) | PASS |
| `designer.wilson_lower_95_strict_min` | 0.60 (strict) | stats | qualification suite (0.60 exactly fails) | PASS |
| `correlation.bootstrap_replicates` | 10000 | stats | analysis + qualification suites | PASS |
| `correlation.capa_lower_95_threshold` | 0.75 | stats | qualification suite | PASS |
| `correlation.holm_p_max` | 0.01 | stats | qualification suite | PASS |
| `correlation.double_fault_independence_multiplier` | 2 | stats | qualification suite | PASS |
| `correlation.phi_bound` | `upper-95` | stats | qualification suite (declaration check) | PASS |
| `position_bias.calls` | 480 | stats | qualification suite | PASS |
| `position_bias.unique_mirrored_pairs` | 240 | stats | qualification suite | PASS |
| `position_bias.reversals_max` | 6 | stats | qualification + seam (6 passes, 7 fails) | PASS |
| `equivalence_bias.probes` | 300 | stats | qualification suite | PASS |
| `equivalence_bias.verbose_candidate_selection_acceptance_inclusive` | [135, 165] | stats | qualification suite (endpoints pass, 134/166 fail) | PASS |
| `equivalence_bias.self_lineage_selection_acceptance_inclusive` | [135, 165] | stats | qualification suite | PASS |

## External dependencies still open

m32.8a is external and stays `EXTERNAL-EVIDENCE-OPEN`: ethics/privacy
determination, consent execution, compensation, population frame, locale
quotas, tasks, viewport rollout, randomization, exclusions, retention,
withdrawal handling, real ballots, the analysis run on them, and a named
governance owner — 14 registry requirements, each emitted `satisfied: false`
with no code path to true. Binding the real split needs the external HCM-v2
corpus: no synthetic split can hash to the frozen `split_sha256`, so
`hcm-split`'s success line is deliberately unreachable in this repository.
This cycle certifies a pipeline, not a study; no ethics review, recruitment, or
collected ballot is claimed.

## Limitations

- The `SPLIT-BOUND` success path has no end-to-end test (external boundary);
  the eight structural gates before it are proven by code-absence assertions.
- Exposure plans validate the pair universe by count, not by identity against
  the frozen split (the split is external).
- The PII scan is a heuristic backstop; the guarantee is the exact spec key set
  plus the opaque nonce.
- `blind-check` is a boundary, not a router — the seam script proves the
  composition works when routed through it; live wiring is the study runner's
  job in m32.8a.
- Estimator conventions in stats (z = 1.96, ten fixed reliability bins,
  percentile bootstrap from a seeded Lehmer generator, 1e-9 inclusive-only
  slack) are the analyst's documented choices; the lock freezes acceptance
  levels, not interval construction.
- Raw p-values for the Holm family come from upstream; this pipeline adjusts
  and gates them.

## Skill receipts and evidence

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: engineering:testing-strategy — helped: its pyramid framing
identified exactly which tier the lanes had not covered — each lane shipped
unit/contract suites, but no test drove the three CLIs over *shared* artifacts.
The 9-check seam script is that integration tier, and the skill's "security
boundaries and data integrity" focus is why checks 4 and 8 are leak
*negatives* (a split-carrying stimulus and a split-carrying ballot must be
refused at the privacy boundary) rather than only happy-path composition.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: used as the audit
standard for the reject gate "a regression test that never demonstrably failed
first". Its "watch it fail for the expected reason" rule is the criterion that
made the corpus lane's rc=64 usage reds and the stats lane's exit-127 red
acceptable, and it is the same standard by which the privacy lane's
file-not-found red would have been insufficient alone — that lane's 11-mutation
battery (with two surviving mutants killed by new tests) is what satisfied the
criterion, so no lane was rejected on this gate.
POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c45-hcm-pipeline-20260819-a1
