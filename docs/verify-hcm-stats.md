# Verification — lane `hcm-stats` (run `c45-hcm-pipeline-20260819-a1`, m32.8)

Scope: the HCM-v2 analysis maths and the judge-qualification gates.
Deliverables: `bin/polylane-taste-qualify.sh`, `tests/test-hcm-v2-analysis.sh`,
`tests/test-hcm-v2-qualification.sh`.

Authority for every number below is
`docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json`, block
`source_calibration.judge_qualification_thresholds`. The lane did not modify the
contract JSON or any v3 schema.

## External boundary

m32.8a is `external`. Nothing here simulates, stands in for, or approximates a
human judgment or a study result. Every fixture in both test files is a
synthetic arithmetic vector whose correct answer is derived by hand; a fixture
is never a ballot, and no fixture is presented as evidence about real people.
`bin/polylane-taste-qualify.sh` cannot emit a certification status or a claim
label. The registry's prohibited outputs — the `TASTE-CERTIFIED` and
`HUMAN_CERTIFIED` statuses, the `TASTE-CERTIFIED` claim label, and a true
`human_certified` or `taste_certified` flag — appear nowhere in its source and
nowhere in anything it emits, which the qualification suite asserts directly
against the script file and against four emitted receipts.

## Thresholds enforced

Every acceptance level is read from the lock at run time. No threshold value is
written into the script. The gate refuses to produce a verdict at all when the
lock has lost a key it needs (`lock_block`), so a stripped lock fails loudly
instead of comparing against `null`.

| Threshold (lock key) | Lock value | Enforced at | Boundary test |
|---|---|---|---|
| `target_user.coverage_min` | 0.80 | `GATE_TARGET_USER` → `TU_COVERAGE` | exactly 0.80 passes; 0.799 and 0.7999999 fail |
| `target_user.brier_skill_lower_95_strict_min` | 0 (strict `>`) | `TU_BRIER_SKILL_LOWER` | exactly 0 fails; −1e-12 fails; +1e-12 passes |
| `target_user.strata_brier_skill_lower_95_strict_min` | 0 (strict `>`) | `TU_STRATUM_BRIER_SKILL_LOWER` | exactly 0 fails; a single bad stratum fails even when the summary minimum is fine |
| `target_user.repeat_stability_min` | 0.95 | `TU_REPEAT_STABILITY` | exactly 0.95 passes; 0.949 fails; unmeasured (`null`) fails |
| `target_user.orientation_effect_abs_max` | 0.05 | `TU_ORIENTATION_EFFECT` | ±0.05 passes; ±0.051 fails; unmeasured fails |
| `target_user.calibration_in_large_abs_max_per_class` | 0.05 | `TU_CALIBRATION_IN_LARGE` | ±0.05 passes; 0.051 fails; a bad class fails even with a stale abs-max |
| `target_user.weighted_calibration_error_max` | 0.08 | `TU_WEIGHTED_CALIBRATION_ERROR` | exactly 0.08 passes; 0.081 fails |
| `target_user.weighted_calibration_upper_95_max` | 0.12 | `TU_WEIGHTED_CALIBRATION_UPPER` | exactly 0.12 passes; 0.121 fails |
| `designer.decisive_pairs` | 120 | `DESIGNER_DECISIVE_PAIRS` | exactly 120 passes; 119 and 121 fail |
| `designer.both_mirror_correct_min` | 84 | `DESIGNER_BOTH_MIRROR_CORRECT` | **exactly 84 passes**; 83 fails |
| `designer.macro_agreement_min` | 0.70 | `DESIGNER_MACRO_AGREEMENT` | exactly 0.70 passes; 0.699 fails |
| `designer.stratum_agreement_min` | 0.60 | `DESIGNER_STRATUM_AGREEMENT` | **exactly 0.60 passes**; 0.599 fails; a bad stratum fails even with a stale summary |
| `designer.wilson_lower_95_strict_min` | 0.60 (strict `>`) | `DESIGNER_WILSON_LOWER` | **exactly 0.60 fails**; 0.5999999999 fails; 0.6000001 passes |
| `correlation.bootstrap_replicates` | 10000 | `CORRELATION_BOOTSTRAP_REPLICATES` + the bootstrap itself | 9999 fails |
| `correlation.capa_lower_95_threshold` | 0.75 | `CORRELATION_CAPA_LOWER` | exactly 0.75 passes; 0.749 fails |
| `correlation.holm_p_max` | 0.01 | `CORRELATION_HOLM_P` | exactly 0.01 passes; 0.011 fails; a failed test in the list fails even with a stale maximum |
| `correlation.double_fault_independence_multiplier` | 2 | `CORRELATION_DOUBLE_FAULT_INDEPENDENCE` | exactly 2× independent passes; 2.1× fails |
| `correlation.phi_bound` | `upper-95` | `CORRELATION_PHI_BOUND` | a receipt declaring `point` or `lower-95` fails |
| `position_bias.calls` | 480 | `POSITION_BIAS_CALLS` | exactly 480 passes; 479 and 481 fail |
| `position_bias.unique_mirrored_pairs` | 240 | `POSITION_BIAS_PAIRS` | exactly 240 passes; 239 fails |
| `position_bias.reversals_max` | 6 | `POSITION_BIAS_REVERSALS` | **exactly 6 passes**; 7 fails |
| `equivalence_bias.probes` | 300 | `EQUIVALENCE_BIAS_PROBES` | exactly 300 passes; 299 fails |
| `equivalence_bias.verbose_candidate_selection_acceptance_inclusive` | [135, 165] | `EQUIVALENCE_BIAS_VERBOSE_CANDIDATE` | **exactly 135 and exactly 165 pass**; 134 and 166 fail |
| `equivalence_bias.self_lineage_selection_acceptance_inclusive` | [135, 165] | `EQUIVALENCE_BIAS_SELF_LINEAGE` | **exactly 135 and exactly 165 pass**; 134 and 166 fail |

### Proof that the thresholds are read, not remembered

`tests/test-hcm-v2-qualification.sh` writes mutated copies of the lock and
re-runs the same metrics against them through `POLYLANE_CONTRACT_LOCK`:

- `designer.both_mirror_correct_min = 85` flips the 84-correct designer to fail,
  and the emitted receipt echoes 85 as the threshold it applied.
- `position_bias.reversals_max = 5` flips the 6-reversal judge to fail.
- `correlation.double_fault_independence_multiplier = 1` flips the 2× judge to fail.
- `equivalence_bias.verbose_...acceptance_inclusive = [140,160]` flips 135 to fail.
- `target_user.coverage_min = 0.9` flips the 0.80-coverage judge to fail.
- deleting `designer.both_mirror_correct_min` produces no verdict at all; the run
  fails with `contract lock missing …both_mirror_correct_min` on stderr.

The suite also asserts each frozen value directly against the lock, so a change
to the lock breaks this lane's tests before it can silently change a verdict.

## Independent derivations

Each statistic is checked against a synthetic dataset whose answer is worked out
by hand, not read off the implementation.

**Brier score, reference and skill.** 8 items, 4 outcomes of 1 and 4 of 0, so the
base rate is 0.5 and every reference squared error is `(0.5 − o)² = 0.25`.
Forecasts 0.75 on the ones and 0.25 on the zeros give squared error 0.0625
everywhere, so Brier = 0.0625, reference = 0.25 and skill = 1 − 0.0625/0.25 =
0.75. Every per-item contribution `dᵢ = 0.25 − 0.0625 = 0.1875` is identical, so
sd(d) = 0 and the lower bound equals the point estimate, 0.75. Asserted to 1e-12.

**Brier skill lower 95% bound with real variance.** 4 items, outcomes 1,1,0,0,
forecasts 0.9, 0.7, 0.1, 0.5. Squared errors 0.01, 0.09, 0.01, 0.25 → Brier 0.09.
d = 0.24, 0.16, 0.24, 0.00 → mean 0.16, sample variance 0.0384/3 = 0.0128, sd =
0.1131370850, se = sd/√4 = 0.0565685425. Lower mean = 0.16 − 1.96·se =
0.0491256567; divided by the reference 0.25 the bound is **0.1965026268** and the
point estimate is 0.64. Asserted to 1e-9. The bound is the one-sided normal
interval on the mean of the per-item contributions, scaled by the (strictly
positive) reference score, so its sign is the sign of the numerator — which is
exactly what the frozen strict `> 0` gate is asking about.

**Coverage.** 8 resolved of 10 judgments = 0.80 exactly; the two unresolved
judgments never enter the Brier arithmetic (the skill on the remaining 8 is still
0.75).

**Repeat stability.** 20 repeat groups of two exposures, one of them
inconsistent → 19/20 = 0.95 exactly. Single-exposure items are not repeats and
never enter the ratio.

**Orientation effect.** Accuracy under `ab` minus accuracy under `ba`, where a
judgment is correct when `(p ≥ 0.5) == (outcome == 1)`. On the variance fixture
the `ab` items are both correct (1.0) and the `ba` items split (0.5, because a
forecast of exactly 0.5 decides for outcome 1 against an outcome of 0), so the
effect is exactly 0.5.

**Calibration in large.** Per class, mean(p) − mean(outcome). Class `hi` has mean
p 0.55 against a base rate of 0.5 → exactly +0.05; class `lo` has 0.40 → exactly
−0.10; the reported absolute maximum is 0.10.

**Weighted calibration error and its upper bound.** Fixed 0.1-wide reliability
bins. 200 items at p = 0.8 with 140 ones (bin outcome mean 0.7, gap 0.1) and 200
at p = 0.3 with 60 ones (gap 0.0) give ECE = 0.5·0.1 + 0.5·0.0 = **0.05**. The
bound treats bins as independent and each bin outcome mean as binomial:
se = √(0.5²·0.7·0.3/200 + 0.5²·0.3·0.7/200) = 0.0229128785, so the upper 95%
value is 0.05 + 1.96·se = **0.0949092418**. Asserted to 1e-9.

**Wilson lower 95% bound.** For 84 of 120 at z = 1.96: p̂ = 0.7, denominator
1 + z²/n = 1.0320133333, centre 0.7 + z²/2n = 0.7160066667, margin
z·√((p̂(1−p̂) + z²/4n)/n) = 0.0835404903, so the bound is **0.6128469050**.
Asserted to 1e-9 — and it clears the frozen strict 0.60, which is why 84 of 120
is a coherent floor rather than two thresholds that disagree.

**Designer aggregation.** 120 decisive pairs over three strata of 40 with 28
both-mirror-correct in each gives 84 total, every stratum at 0.70 and a macro of
0.70. A second fixture with 36/28/20 still totals 84 and still macros at 0.70
while its weakest stratum is 0.50 — this is the case a pooled number hides, and
the gate catches it. A third fixture proves one correct mirror is not enough, and
a fourth proves indecisive pairs leave the denominator.

**CAPA and its bootstrap lower bound.** CAPA is the chance-adjusted pairwise
agreement `(p_o − p_e)/(1 − p_e)` between the judge's label and the consensus
label. Two derivations:

1. *Exact, generator-independent.* On a perfectly agreeing set every resample has
   `p_o = 1`, so CAPA = `(1 − p_e)/(1 − p_e) = 1` in every one of the 10,000
   replicates whatever the draws are. The lower bound is therefore exactly 1.0,
   asserted to 1e-12. This is the one bootstrap answer that can be known without
   reimplementing the resampler, and it is the check that the percentile logic
   is wired to the right end of the distribution.
2. *Known point value with a band.* 100 items, 80 agreements, both marginals
   split 50/50 → `p_e = 0.5` and CAPA = (0.8 − 0.5)/0.5 = **0.6** exactly. Since
   `p_e` is pinned at 0.5, CAPA ≈ 2·p_o − 1, so sd(CAPA) ≈ 2·√(0.8·0.2/100) =
   0.08 and the 2.5th percentile should land near 0.6 − 1.96·0.08 ≈ 0.443. The
   test asserts the bound is below the point estimate and inside (0.38, 0.50).

The resampler is a Lehmer generator (`x ← 16807·x mod 2147483647`) seeded from
the SHA-256 of the canonical input, so the interval is reproducible: the suite
asserts that the same records twice produce byte-identical output. Every
intermediate stays below 2⁵³, so the recurrence is exact in double precision.
The bounds are the ceil(0.025·R)-th and ceil(0.975·R)-th order statistics
(250th and 9750th of 10,000).

**Double-fault independence and phi.** 100 items where the judge and the peer each
fault 20 times with 4 joint faults: observed double-fault rate 0.04, independent
product 0.2·0.2 = 0.04, and the 2×2 fault table (4, 16, 16, 64) gives
`phi = (4·64 − 16·16)/√(20·80·20·80) = 0` exactly. The gate compares the observed
rate against `multiplier × independent`; `phi_bound` is enforced as a declaration
check, so a receipt reporting a point estimate or a lower bound where the lock
freezes `upper-95` is rejected.

**Holm step-down.** Raw p 0.001, 0.004, 0.02 with k = 3 adjusts to 0.003,
max(0.003, 2·0.004) = 0.008, max(0.008, 0.02) = 0.02 → maximum 0.02.
Raw 0.001, 0.002, 0.003 adjusts to 0.003, 0.004, 0.004 (monotone: a later small
p can never adjust below an earlier one). Raw 0.6, 0.7, 0.8 caps at 1.

**Position bias.** 240 pairs each presented in both orders is 480 calls; a
reversal is a pair whose chosen item changes with presentation order. Fixtures at
0, 6 and 240 reversals; a pair missing its mirror is counted as a call but not as
a mirrored pair.

**Equivalence bias.** Straight counts over 300 probes.

### Rounding

Inclusive thresholds are compared with 1e-9 of slack, because the mean of three
ratios of 28/40 is 0.6999999999999998 rather than 0.70 and a judge exactly on the
frozen floor must not be rejected by binary rounding. The slack is never applied
to the strict inequalities. Both properties are tested: one ULP below 0.70 still
qualifies, 1e-7 below does not, and a Wilson bound 1e-10 below 0.60 still fails.

## A failing judge cannot vote

The path is `records → metrics → gate → qualify → vote`. `qualify` requires one
passing gate for **every** kind the lock freezes thresholds for — the required
set is read from the lock's own keys, so a newly frozen gate cannot be skipped by
omission. `vote` is the only route from a qualification receipt to a countable
ballot.

Tested explicitly:

- For each of the five kinds in turn, one failing gate is substituted and the
  judge is disqualified with `QUALIFICATION_GATE_FAILED:<kind>`; the ballot is
  then refused with `VOTE_REFUSED_NOT_QUALIFIED` and the refusal receipt carries
  no `choice` field.
- A missing gate kind disqualifies (`QUALIFICATION_GATE_MISSING:correlation`).
- Gates belonging to another judge disqualify (`QUALIFICATION_JUDGE_MISMATCH`).
- Duplicate gate kinds are refused outright rather than counted twice.
- A hand-edited receipt claiming `qualified: true` while still carrying reason
  codes, a short `gate_kinds` list, or a stale `lock_sha256` is refused with
  `VOTE_REFUSED_QUALIFICATION_INVALID` — a forged receipt cannot buy a vote.
- A ballot whose `judge_id` differs from the receipt is refused with
  `VOTE_REFUSED_JUDGE_MISMATCH`.
- A malformed ballot and a missing qualification file are both refused.
- An admitted ballot binds the SHA-256 of the qualification receipt it rode in on.

An end-to-end section drives all five gates from records rather than hand-written
metric vectors, qualifies the judge, admits a ballot, then changes a single call
in the position-bias records so the judge reverses seven times instead of six —
and the same judge can no longer vote. That section is what proves the two halves
share one contract: if an analysis command renamed a field the gate reads, both
halves would still pass in isolation.

## Red then green

TDD was followed per half; the implementation did not exist when the tests first
ran.

| Step | Command | Result |
|---|---|---|
| RED (analysis) | `tests/test-hcm-v2-analysis.sh` | exit 127 — `bin/polylane-taste-qualify.sh: No such file or directory` |
| GREEN (analysis) | `tests/test-hcm-v2-analysis.sh` | `PASS: hcm-v2 analysis` |
| RED (qualification) | `tests/test-hcm-v2-qualification.sh` | the lock assertions passed, then `gate` printed the usage banner and `FAIL: tu all on boundary: expected pass=true, got pass=` — the `gate`, `qualify` and `vote` subcommands did not exist |
| GREEN (qualification) | `tests/test-hcm-v2-qualification.sh` | `PASS: hcm-v2 qualification` |

Three failures found by the tests rather than by inspection, each fixed against
the test that caught it:

1. An all-outcomes-1 repeat-stability fixture was rejected, correctly: with a
   degenerate base rate the reference Brier score is zero and skill is undefined.
   The fixture was rebalanced; the rejection stayed.
2. `($labels | index($items[.].judge_label))` rebinds `.` to `$labels` inside
   `index`, so the row builder indexed an array with a string. Fixed by binding
   the loop variable explicitly.
3. `mean(0.70, 0.70, 0.70) = 0.6999999999999998` failed `>= 0.70` by one ULP,
   which would have disqualified a designer sitting exactly on the frozen floor.
   Fixed with the documented 1e-9 slack on inclusive comparisons only, and pinned
   by tests at 1e-7 and 1e-5.

## Fresh counts

Re-run at worktree HEAD `5eb2181` with this lane's new files in place:

```
tests/test-hcm-v2-analysis.sh       PASS: hcm-v2 analysis        9s
tests/test-hcm-v2-qualification.sh  PASS: hcm-v2 qualification  27s
shellcheck -S warning bin/polylane-taste-qualify.sh tests/test-hcm-v2-*.sh   clean
```

Adjacent existing suites that enumerate `bin/` scripts or docs, re-run because
this lane adds a script:

```
tests/test-docs-truth.sh      PASS
tests/test-install-fresh.sh   PASS
tests/test-skill-parity.sh    PASS
bin/polylane-markers.sh check-docs references/   PASS
```

| File | Lines | Assertions |
|---|---|---|
| `bin/polylane-taste-qualify.sh` | 764 | — |
| `tests/test-hcm-v2-analysis.sh` | 356 | 101 |
| `tests/test-hcm-v2-qualification.sh` | 526 | 125 |

`tests/run.sh` and doctor rehearsals were not run (out of lane scope).

## Limitations

- **The pipeline is proven; the study is not run.** Nothing here produces or
  approximates a human judgment. m32.8a stays `EXTERNAL-EVIDENCE-OPEN`.
- **Estimator choices are the analyst's, not the lock's.** z = 1.96, ten
  0.1-wide reliability bins, the percentile convention for the bootstrap bounds,
  and the 1e-9 comparison slack are method constants documented in the script;
  the lock fixes acceptance levels, not how an interval is built. If the study
  protocol wants a different interval (BCa rather than percentile, or bins keyed
  to the observed forecast distribution), that is a change here, not in the lock.
- **The Brier skill bound is a normal approximation** on the mean of per-item
  contributions. With the frozen sample sizes that is comfortable, but it is not
  a bootstrap and it will be optimistic in a small or heavily skewed stratum.
- **Per-stratum Brier skill uses the pooled reference score** as its denominator
  so strata stay comparable; a per-stratum reference would give different (and
  less comparable) numbers.
- **Raw p-values for the Holm family come from upstream.** This lane adjusts and
  gates them; it does not compute the correlation tests that produce them.
- **`phi_bound` is enforced as a declaration**, since the lock freezes the bound's
  side but no numeric acceptance level for phi. The numeric independence gate is
  the frozen ×2 double-fault rule.
- **The bootstrap is a percentile interval from a Lehmer generator.** It is
  deterministic and reproducible, which is what an audit needs, but a single
  fixed stream means the interval carries no Monte-Carlo error estimate.
- **`qualify` requires all five gate kinds from one judge.** If a later protocol
  wants cohort-specific qualification (target users never sit the designer
  gate), that is a change to `qualify`, and the lock's threshold-block keys are
  where the required set comes from.

## Skill evidence

SKILL-EVIDENCE: data:statistical-analysis — helped: its "practical significance
vs statistical significance" and multiple-comparisons sections are why the gate
scans the whole `strata`, `calibration_in_large` and `holm` lists instead of
trusting the pooled summary the analysis emits. The 36/28/20 designer fixture (84
correct, macro 0.70, weakest stratum 0.50) is a direct instance of the skill's
Simpson's-paradox warning — a pooled number that passes while a segment fails —
and it is now a permanent regression test.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: watching the red
run is what produced the three fixes listed above. The degenerate-base-rate
rejection and the `index()` rebinding bug were both caught by a test that failed
before any implementation existed, and the one-ULP macro-agreement failure was
caught by the end-to-end test written before the gate had a tolerance — a
tests-after pass would have hard-coded the implementation's own rounding as the
expected answer.
