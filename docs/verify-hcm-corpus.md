# verify — lane `hcm-corpus` (run `c45-hcm-pipeline-20260819-a1`, target m32.8)

Goal: bind the frozen HCM-v2 target-matched split and the stimulus exposure
rules into `bin/polylane-taste-study.sh`, each proven by a regression test.

Authority: the `source_calibration.hcm_v2` block of
`docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json` (read-only
for this lane).

## What was built

Three new verbs on `bin/polylane-taste-study.sh` (freeze/compile untouched):

- `hcm-split-digest SPLIT` — the canonical content digest of a produced split.
  Canonicalization is documented in the source: the schema line, each excluded
  anchor id (sorted), then each natural pair id with its stratum (sorted by pair
  id), tab-separated, newline-terminated, SHA-256. Input array order is
  irrelevant (proved by `digest-is-order-independent`).
- `hcm-split SPLIT` — binds a produced split to the frozen block. Prints
  `SPLIT-BOUND <digest>` (rc 0) or `SPLIT-NOT-BOUND <codes…>` (rc 1).
- `hcm-exposure PLAN [OTHER_PLAN]` — binds a stimulus exposure allocation plan.
  Prints `EXPOSURE-BOUND` (rc 0) or `EXPOSURE-NOT-BOUND <codes…>` (rc 1). With
  two plans it additionally enforces ballot-stream separation.

## Frozen parameters bound

Every number is read from the lock at runtime — none is inlined in the script.
Both tests additionally assert the lock's literal values, so a lock change fails
the suite loudly instead of drifting silently.

| lock field | value | enforced at | reason code on violation |
|---|---|---|---|
| `natural_pairs.total` | 320 | `hcm_split` (declared total **and** `assignments\|length`) | `HCM_SPLIT_TOTAL` |
| `natural_pairs.development` | 120 | `hcm_split` (declared **and** counted per stratum) | `HCM_SPLIT_STRATUM_COUNT` |
| `natural_pairs.validation` | 40 | same | `HCM_SPLIT_STRATUM_COUNT` |
| `natural_pairs.confirmatory` | 160 | same | `HCM_SPLIT_STRATUM_COUNT` |
| dev+val+conf == total | 320 | `hcm_split` lock-integrity check | `HCM_LOCK_INCONSISTENT` |
| `anchors_excluded` | 32 | `hcm_split` (count, uniqueness, and disjointness from the natural set) | `HCM_SPLIT_ANCHOR_COUNT`, `HCM_SPLIT_ANCHOR_OVERLAP` |
| `split_sha256` | `5f24bec2…cf0a2031` | `hcm_split` final gate, after self-consistency | `HCM_SPLIT_LOCK_MISMATCH` |
| (self-consistency) | declared == recomputed | `hcm_split` | `HCM_SPLIT_DIGEST_MISMATCH` |
| `source_id` | `HCM-v2` | `hcm_split` lock-integrity check | `HCM_LOCK_INCONSISTENT` |
| `target_users.viewports` | exactly `1440x900`, `390x844` | `hcm_plan_codes` (membership **and** both-covered) | `HCM_EXPOSURE_VIEWPORT`, `HCM_EXPOSURE_VIEWPORT_COVERAGE` |
| `target_users.max_natural_pairs_per_participant` | 8 | `hcm_plan_codes`, target stream | `HCM_EXPOSURE_NATURAL_CAP` |
| `target_users.max_anchors_per_participant` | 2 | `hcm_plan_codes`, target stream | `HCM_EXPOSURE_ANCHOR_CAP` |
| `target_users.pair_repeat_exposures` | 0 | `hcm_plan_codes`, all streams (guarded: a non-zero lock value is `HCM_LOCK_INCONSISTENT`) | `HCM_EXPOSURE_REPEAT` |
| `target_users.judgments_per_pair` | 80 | `hcm_plan_codes`, target stream (every natural pair, exactly) | `HCM_EXPOSURE_JUDGMENT_COUNT` |
| `target_users.min_completed_participants` | 3200 | `hcm_plan_codes`, target stream | `HCM_EXPOSURE_PARTICIPANT_FLOOR` |
| `designers.max_pairs_per_designer` | 40 | `hcm_plan_codes`, designer stream | `HCM_EXPOSURE_DESIGNER_PAIR_CAP` |
| `designers.judgments_per_pair` | 12 | `hcm_plan_codes`, designer stream (every natural pair, exactly) | `HCM_EXPOSURE_JUDGMENT_COUNT` |
| `designers.min_credentialed_designers` | 96 | `hcm_plan_codes`, designer stream | `HCM_EXPOSURE_DESIGNER_FLOOR` |
| `designers.separate_from_target_user_ballots` | true | `hcm_exposure` two-plan mode (guarded: a false lock value is `HCM_LOCK_INCONSISTENT`) | `HCM_EXPOSURE_STREAM_DUPLICATE`, `HCM_EXPOSURE_BALLOT_OVERLAP` |

Derived coverage also enforced from the lock: the plan's distinct natural pair
ids must equal `natural_pairs.total` (`HCM_EXPOSURE_PAIR_COVERAGE`), and a
target-user plan's distinct anchor ids must equal `anchors_excluded`
(`HCM_EXPOSURE_ANCHOR_COVERAGE`).

## The lock is read at runtime, not inlined — proved

Same fixture, two locks. Copies of `bin/` plus a mutated lock were placed in the
scratchpad; only the lock differed.

```
# split, lock mutated to development 121 / confirmatory 159
real lock   : SPLIT-NOT-BOUND HCM_SPLIT_LOCK_MISMATCH
drifted lock: SPLIT-NOT-BOUND HCM_SPLIT_STRATUM_COUNT HCM_SPLIT_LOCK_MISMATCH

# exposure, lock mutated to max_natural_pairs_per_participant 7 + a third viewport
real lock   : EXPOSURE-BOUND
drifted lock: EXPOSURE-NOT-BOUND HCM_EXPOSURE_VIEWPORT_COVERAGE HCM_EXPOSURE_NATURAL_CAP
```

## Red-then-green evidence

Both tests were written and run **before** any implementation existed. At that
point the verbs were unknown to the dispatcher, so every behavioural assertion
failed with `rc=64` (usage) and empty output:

| test | RED (before implementation) | GREEN (after) |
|---|---|---|
| `tests/test-hcm-v2-split.sh` | 23 pass, 22 fail | 45 pass, 0 fail |
| `tests/test-hcm-v2-exposure.sh` | 14 pass, 42 fail | 56 pass, 0 fail |

Representative RED lines actually observed:

```
FAIL digest-matches-documented-canonicalization — expected [e37c88f2…] got []
FAIL faithful-split-is-hard-failure-rc1 — expected [1] got [64]
FAIL faithful-split-blocked-by-lock — output does not contain [HCM_SPLIT_LOCK_MISMATCH]
```

The passes in the RED column are the lock drift-guard assertions (which read the
contract only) and the prohibited-output sweeps (vacuously true against empty
output); every gate assertion was red.

## Fresh verification (this session, after the final edit)

```
$ shellcheck -S warning bin/polylane-taste-study.sh
SHELLCHECK: clean rc=0
$ bash tests/test-hcm-v2-split.sh
tests/test-hcm-v2-split.sh rc=0 | test-hcm-v2-split.sh: 45 pass, 0 fail
$ bash tests/test-hcm-v2-exposure.sh
tests/test-hcm-v2-exposure.sh rc=0 | test-hcm-v2-exposure.sh: 56 pass, 0 fail
$ bash tests/test-taste-study-live.sh          # pre-existing suite for this file
tests/test-taste-study-live.sh rc=0 | PASS: taste study-live compiler
$ git diff --check
git diff --check: clean
```

Wall clock: split ≈1.3 s, exposure ≈23 s (the faithful target-user fixture is
3 200 participants × 10 exposures = 32 000 rows, which is what the frozen floor
requires; the plan runs were de-duplicated so the external-boundary sweep reuses
captured output instead of re-running every fixture).

## External boundary held

- `m32.8a` is external. Nothing here simulates a human judgment, a recruited
  participant, a consent signature, or a study result. A plan is an
  **allocation** — who *would* be shown which pair, at which viewport — and
  carries no verdict field at all.
- The frozen `split_sha256` gate is deliberately unreachable offline: no
  synthetic split can hash to `5f24bec2…`, so `hcm-split` on a structurally
  faithful fixture stops at exactly one code, `HCM_SPLIT_LOCK_MISMATCH`, at rc 1.
  The test asserts the *absence* of all eight earlier codes, which is how every
  earlier gate is proven green without fabricating the external corpus.
- Prohibited outputs stay unreachable: both tests sweep the concatenated output
  of every run for `TASTE-CERTIFIED`, `HUMAN_CERTIFIED`, `human_certified`, and
  `WARN`. The split test additionally asserts `SPLIT-BOUND` never appears.
- No defect status was flipped; the contract JSON and v3 schemas were read only.

## Limitations

- **`hcm-split` cannot return rc 0 in this repository.** That is the intended
  external boundary, not a bug, but it means the `SPLIT-BOUND` success line has
  no end-to-end test — only its code path and the eight gates before it are
  covered. Binding the real split needs the external HCM-v2 corpus (m32.8a).
- Exposure plans are not cross-checked against a split file: the pair universe is
  validated by *count* (320 natural, 32 anchors) rather than by identity against
  the frozen split, because the frozen split is external.
- Designer plans are not required to carry anchors and no designer anchor cap is
  enforced — the lock defines anchor caps only for `target_users`.
- Viewport rules are applied to both streams. The lock states viewports under
  `target_users`; treating them as the frozen stimulus rendering set for
  designers too is this lane's reading, and it is strictly more restrictive.
- `tests/test-taste-certification.sh` was not run to completion (it exceeded a
  2-minute budget in this session). It does not reference
  `bin/polylane-taste-study.sh`. The full suite and doctor rehearsals are the
  integrator's and coordinator's to run, per this lane's cadence.

## Skill evidence

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015
SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: superpowers:test-driven-development — helped: writing
`tests/test-hcm-v2-split.sh` before the implementation forced the design
decision that mattered most in this lane. To make a self-consistent fixture the
test had to reimplement the canonicalization independently, which is what exposed
that the digest needed to be a separate `hcm-split-digest` verb rather than an
inline step of `hcm-split` — and the RED run then showed the intended positive
path was unreachable offline, which is what produced the "assert the absence of
the eight earlier codes" design instead of a fabricated green.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: the gate
function caught a real overclaim. After the first green run I was ready to write
"the frozen numbers are bound", but the claim actually requiring proof was "bound
*from the lock at runtime*" — indistinguishable from inlined constants by the
test suite alone. Running the same fixtures against a mutated copy of the lock
(different codes, same input) is the evidence now recorded above; without the
skill's "what command proves this claim?" step that section would have been an
assertion rather than a transcript.
