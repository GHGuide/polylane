# verify-comparator — c44-defect-controls-20260819-a1

Lane `comparator`, builder. Boundary: **paired comparator outcome**.
Owned: `bin/polylane-taste-ballot.sh`, `tests/test-taste-comparator-outcome.sh`,
`docs/verify-comparator.md`, `docs/status-comparator.md`.
No contract JSON, schema, state file, or other lane's file was touched.

## SKILL-READ

- SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015
- SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

## Defect `c42b-comparator-pseudo-win`

`required_v3_control`, quoted verbatim from
`docs/polylane/taste-certification/contracts/EVIDENCE-CLAIM-REGISTRY.v3.json`
(and identically from the `implementation_defect_registry` in `CONTRACT-LOCK.v3.json`):

> Only a validated outcome equal to win increments wins; ties, abstentions, missing evidence, and invalid evidence remain non-wins in the fixed denominator.

Disposition: *blocks affected statistical evidence from promotion until repaired
and regression-tested.* Registry `status` stays `OPEN` — this lane implements the
control only and never flips a defect status.

### Binding lock statistics (frozen, not modified)

- `statistics.repeated_measure_unit` = `"brief"`
- `statistics.fixed_denominator` = `{final_benchmark: 1000, prompt_validation: 300, denominator_shrinkage_allowed: false, repeated_measure_inflation_allowed: false}`
- `statistics.final_benchmark.non_wins` = `["tie","abstention","missing_evidence","invalid_evidence"]`, `denominator_policy: "all-retained"`

### Root cause found before any fix (systematic-debugging Phase 1)

`bin/polylane-taste-ballot.sh` had **no outcome classification and no counter**.
Two concrete defects at the boundary:

1. `validate_exposures` derived `winner` from `exposures[0].canonical_choice`,
   required `.outcome == "resolved-$winner"`, and rejected any group whose
   exposures abstained or disagreed. A tie or an abstention therefore produced
   **no receipt at all** — the unit vanished. Any downstream count over emitted
   receipts sees only wins, i.e. a 100% win rate by construction. That is the
   pseudo-win: the denominator shrinks to the set of wins.
2. The receipt asserted `winner: exposures[0].canonical_choice` with no typed
   outcome, so no consumer could distinguish "validated win" from "a record that
   happens to name a candidate".

### How the implementation satisfies the control

`bin/polylane-taste-ballot.sh`:

- **Closed outcome vocabulary** (`comparator_outcome_of`): a group's `.outcome`
  is `resolved-stim-<12 hex>` → `win`, `tie` → `tie`, `abstention` →
  `abstention`. Anything else is rejected outright (fail-closed, no receipt).
- **Each outcome is proved, not declared** (`validate_exposures`, now taking the
  normalised outcome): `win` requires no abstention plus a unanimous
  `canonical_choice` equal to the candidate named in `.outcome`; `tie` requires
  no abstention plus exactly two distinct canonical choices; `abstention`
  requires at least one exposure with `choice == "abstain"` and a non-empty
  `abstain_reason`. Every `canonical_choice` must now also be one of the group's
  `candidate_ids`. A group cannot be laundered in either direction — a unanimous
  group declared `tie`, a tie declared `resolved-…`, and an `abstention` with no
  abstainer are all rejected.
- **Ties and abstentions are retained as validated evidence**: they now emit an
  `eligible` receipt carrying `comparator_outcome` (`win`|`tie`|`abstention`),
  `repeated_measure_unit: "brief"`, `unit_id: <brief_sha256>`, and `winner`
  **null** unless the outcome is `win`. A non-win can no longer disappear.
- **The counter** (`tally RECEIPT_DIR DENOMINATOR OUT`) is where wins are
  incremented, against a denominator supplied by the caller and never derived
  from the evidence:
  - a receipt increments wins only if it is regular non-symlink JSON with no
    duplicate key paths, `schema_version == "taste-ballot-validation/v1"`,
    `status == "eligible"`, `repeated_measure_unit == "brief"`,
    `unit_id == brief_sha256` (64 hex), `comparator_outcome == "win"`, and a
    `winner` matching `^stim-[a-f0-9]{12}$`. Everything else — including a
    non-win carrying a winner, a `win` with a null winner, an unknown outcome
    literal, a non-eligible status, and an unparseable file — classifies as
    `invalid_evidence` and is **kept** as a unit, never skipped.
  - units are keyed by the frozen repeated-measure unit, the brief. Replicates
    of one brief collapse to one unit (`repeated_measure_inflation_allowed:
    false`), and the worst class wins: any `invalid_evidence` → invalid, else
    any `abstention` → abstention, else any `tie` → tie, else contradictory
    winners across replicates → invalid, else `win`.
  - `missing_evidence = denominator - units_observed`; briefs never measured
    stay in the denominator as non-wins. `units_observed > denominator` is a
    hard error (fail-closed, no partial output), so the denominator can neither
    shrink nor inflate.
  - the emitted `taste-comparator-tally/v1` receipt is re-checked before it is
    written: `wins + tie + abstention + missing_evidence + invalid_evidence`
    must equal `denominator` exactly, or the run errors. That identity is the
    machine-checkable form of "non-wins remain in the fixed denominator".
- The tally stays fixture-grade: `classification: "fixture"`, `fixture_only:
  true`, `human_certified: false`, and it binds the validator's own SHA-256
  fingerprint. It mints no taste or human certification claim.

## Red-then-green evidence

Regression test: `tests/test-taste-comparator-outcome.sh` (new, 49 assertions),
written first and run against the **unchanged** validator.

### RED — before implementation

```
$ tests/test-taste-comparator-outcome.sh   # rc=2
PASS comparator-accepts-win-group
FAIL comparator-win-outcome-typed — expected [win] got [MISSING]
PASS comparator-win-carries-winner
FAIL comparator-win-unit-is-brief — expected [brief] got [MISSING]
FAIL comparator-win-unit-id-is-brief-sha — expected [111…111] got [MISSING]
TASTE-BALLOT: invalid mirrored exposures or calibration
FAIL comparator-retains-tie — expected [0] got [1]
FAIL comparator-tie-outcome-typed — expected [tie] got []
FAIL comparator-tie-has-no-winner — expected [null] got []
TASTE-BALLOT: invalid mirrored exposures or calibration
FAIL comparator-retains-abstention — expected [0] got [1]
FAIL comparator-abstention-outcome-typed — expected [abstention] got []
FAIL comparator-abstention-has-no-winner — expected [null] got []
…
usage: polylane-taste-ballot.sh validate GROUP POINTWISE_DIR CALIBRATION OUT
FAIL tally-accepts-mixed-outcomes — expected [0] got [2]
FAIL tally-counts-only-validated-wins — expected [1] got []
FAIL tally-denominator-is-fixed — expected [5] got []
FAIL tally-tie-is-non-win — expected [1] got []
FAIL tally-abstention-is-non-win — expected [1] got []
FAIL tally-missing-evidence-is-non-win — expected [2] got []
FAIL tally-invalid-evidence-is-non-win — expected [0] got []
FAIL tally-unit-is-brief — expected [brief] got []
FAIL tally-partition-exhausts-denominator — expected [5] got []
FAIL tally-accepts-replicates — expected rc 0, got 2
FAIL tally-collapses-replicates-to-one-brief — expected [1] got []
FAIL tally-replicates-do-not-shrink-denominator — expected [2] got []
```

Fresh count of the red run: **10 PASS, 21 FAIL, rc=2** (the file aborts after
the replicate section because the missing tally output makes a fixture step
fail under `set -e`; the 10 passes are the pre-existing fail-closed rejections
that the control must preserve, not new behaviour). Each failure is the feature
being absent — `comparator_outcome` missing, ties/abstentions rejected outright,
`tally` not a subcommand — not a typo or a fixture error.

### GREEN — after implementation

```
$ tests/test-taste-comparator-outcome.sh   # rc=0
test-taste-comparator-outcome.sh: 49 pass, 0 fail
```

## Fresh counts — every command run for this verification

| command | result |
|---|---|
| `tests/test-taste-comparator-outcome.sh` (before implementation) | 10 pass, 21 fail, rc=2 |
| `tests/test-taste-comparator-outcome.sh` (after) | **49 pass, 0 fail** |
| `tests/test-taste-ballot.sh` | 26 pass, 0 fail |
| `tests/test-taste-validator-receipts.sh` | 38 pass, 0 fail |
| `tests/test-taste-tournament.sh` | 13 pass, 0 fail |
| `tests/test-visual-tournament.sh` | 20 pass, 0 fail |
| `tests/test-taste-protocol-live.sh` | 80 pass, 0 fail |
| `tests/test-installers.sh` | 80 pass, 0 fail |
| `tests/test-codex-taste-install.sh` | 37 pass, 0 fail |
| `tests/test-skill-parity.sh` | 72 pass, 0 fail |
| `tests/test-taste-certification.sh` | `PASS: taste certification compiler` |
| `shellcheck -S warning bin/polylane-taste-ballot.sh tests/test-taste-comparator-outcome.sh` | clean, 0 findings |

Scope of the neighbour set: every suite that invokes
`bin/polylane-taste-ballot.sh` (`test-taste-ballot`,
`test-taste-validator-receipts`, `test-taste-protocol-live`), every suite
covering its one in-repo caller `bin/polylane-visual-tournament.sh`
(`test-taste-tournament`, `test-visual-tournament`), and the packaging/parity
suites that ship the file. `tests/run.sh` and doctor rehearsals were not run —
those are the integrator's and coordinator's boundaries.

## Limitations

- **Fixture-grade only.** Nothing here upgrades a claim: `validate` still stamps
  `classification: "fixture"`, `human_certified: false`, and `tally` does the
  same. No taste or human certification is minted, implied, or upgraded.
- **The denominator is an input, not a proof.** `tally` enforces that the
  supplied denominator is a positive integer, is never exceeded, and is exactly
  partitioned; it does not itself prove the caller passed the lock's 1000 (final
  benchmark) or 300 (prompt validation). Binding the caller to those constants
  belongs to the benchmark runner, not to this boundary.
- **`tally` does not re-verify receipt integrity.** `taste-ballot-validation/v1`
  carries no self-hash, so a hand-edited receipt that is still structurally
  valid counts as its stated outcome. It does bind the validator fingerprint,
  and every structural deviation classifies as `invalid_evidence` rather than
  being dropped.
- **Only `*.json` files in the receipt directory are read.** A receipt saved
  under another extension is not silently counted as a win — it is simply not
  observed, so its brief remains `missing_evidence`, a non-win.
- **Win semantics are per-group, not per-arm.** `win` means the paired group
  resolved to one validated candidate. Which arm (challenger vs baseline) that
  candidate belongs to is not carried by `taste-mirrored-group/v1`, and adding
  an arm label would change a schema this lane does not own.
- **`bin/polylane-taste-ballot-live.sh` (ballot v2) is out of scope** and still
  fails closed on ties and abstentions. The same non-win-retention question
  applies to that live boundary; it belongs to whoever owns that file.

## SKILL-EVIDENCE

- SKILL-EVIDENCE: superpowers:test-driven-development — helped: the RED run
  caught that 10 of my 49 assertions (the whole "vocabulary cannot be laundered"
  block) already passed against the unchanged validator. Had I written the test
  after the fix, I would have reported those as proof of the new control; the
  failing run showed exactly which 21 assertions the implementation actually
  earns, and the doc now separates the two.
- SKILL-EVIDENCE: superpowers:systematic-debugging — helped: Phase 1 stopped me
  fixing the symptom. The obvious reading of "pseudo-win" is "add a win counter",
  but tracing the data flow backwards from the receipt showed the receipt is only
  ever emitted on the win path — so a counter alone would have counted an
  already-100%-win population honestly and still been statistically dishonest.
  The root cause was tie/abstention rejection deleting units from the
  denominator, which is why the fix has two halves.
