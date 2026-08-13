# Verify: ratings-normalize (`bin/polylane-taste-ratings.sh`)

Strict normalizer for the released Miniukovich–Figl rating text schemas
(Harvard Dataverse releases `10.7910/DVN/9FKSQI`, `10.7910/DVN/XOI0HI`,
`10.7910/DVN/Z7KLIH`; schema documented in the dataset article,
PMC10823051).

## Run the verification

```bash
bash tests/test-taste-ratings-normalize.sh
shellcheck -S warning bin/polylane-taste-ratings.sh
```

Expected: `ok - 70 assertions` and a clean shellcheck exit.

## Documented source schemas (bound by header name, never position)

- Raw (`ratings.raw.*.txt`, tab-separated, header row): exactly the columns
  `stimulusId, isDuplicate, rating, isTraining, dimension, sessionId`.
  `rating` is an integer on the native `[-3,3]` scale or `NA`;
  `dimension` is one of `TYP, AVG, EXMPL, AE, US, TRU`; booleans are
  `TRUE/FALSE` (lowercase accepted).
- Aggregate (`ratings.avg.*.txt`, tab-separated, header row): exactly
  `stimulusId` plus the six dimension columns, holding the source's own
  filtered, within-participant-standardized per-page means (native labels;
  the tool never rescales them).

## Command

```bash
bin/polylane-taste-ratings.sh normalize \
  --raw ratings.raw.f.txt --agg ratings.avg.f.txt \
  --domain e-commerce --source-id miniukovich-9fksqi \
  --out normalized.json [--receipt receipt.json] \
  [--compliant-sessions sessions.txt]
```

Output: `taste-ratings-normalize/v1` — sorted canonical records
(`stimulus_id`, `source_id`, `domain`, all six native `labels`,
per-dimension `support`, `min_support`), sorted explicit `excluded`
entries with reasons, `row_stats`, and the frozen constants. The optional
receipt binds input/output SHA-256, tool fingerprint, and counts
(`TASTE_NOW` pins the timestamp for reproducible receipts).

## Fail / exclude taxonomy (never guess)

Hard fail (`TASTE-RATINGS-INVALID`, exit 1): unknown/missing/duplicate
column, malformed row, non-integer or out-of-range rating, invalid
boolean/dimension/id token, unparsable aggregate value, duplicate
aggregate stimulus, more than two rows per session/stimulus/dimension,
empty or symlinked input, unknown/duplicate compliant session, a
compliant session that cannot be standardized (fewer than two ratings or
zero variance), and an all-excluded result (`no usable records`).

Explicit per-stimulus exclusion (recorded in `excluded`): `NA` raw rating
rows (`row_stats.nonfinite_rows`), `nonfinite-aggregate` (NA/NaN/Inf),
`missing-raw-join` (aggregate stimulus with no raw rows),
`weak-support` (any dimension below the frozen 5 distinct raters),
`not-in-aggregate` (non-training raw stimulus absent from the aggregate
file), `aggregate-mismatch` (recomputed aggregate beyond tolerance).
Training rows are counted but create neither stimuli nor support.

## Compliant-rater support and the honest boundary

The released raw schema does **not** flag rater compliance (compliance was
derived by the authors from demographics/recognition/consistency data).
Therefore:

- Without `--compliant-sessions`: `support_basis:"raw-sessions"` (distinct
  raw sessions, an upper bound on compliant support) and
  `aggregate_check:"not-computable-from-released-schema"`. No consistency
  is claimed that the schema cannot prove.
- With `--compliant-sessions` (one session id per line, each proven to
  exist in the raw file): support counts only listed sessions, and the
  documented aggregation pipeline is recomputed with a pinned definition —
  duplicate re-ratings averaged per session/stimulus/dimension, each
  session standardized with mean and **sample** standard deviation (n−1,
  matching R `scale()`) pooled across all of that session's dup-averaged
  ratings, then the per-stimulus/dimension mean over compliant sessions.
  Every dimension must match the released aggregate within the frozen
  `0.01` tolerance or the stimulus is excluded as `aggregate-mismatch`.
  If the pinned definition is wrong for the real files, the gate fails
  visibly; it can never silently pass.

## Frozen constants

`min_support_required = 5` raters per dimension and `tolerance = 0.01`
(protocol §7.2 source contract) are hard-coded, not flags.

## Known stop conditions for the integrator

- Real files with quoted headers/fields (R `quote=TRUE`) or headerless
  layout will fail as schema drift — that is the intended fail-closed
  behavior; the schema binding must then be updated deliberately, never
  loosened in place.
- This lane ships fixtures only; the integrator validates against real
  rating files per the frozen plan.

## Risk register (top items)

| Risk | Level | Mitigation |
|---|---|---|
| Real file drift (quotes, column changes, no header) | Medium/High | Fail-closed header binding with explicit reasons; integrator sees exact column name in the error. |
| Wrong pinned standardization definition | Medium/Medium | Only active with a compliant-session list; mismatch excludes/fails explicitly, never passes. |
| Silent weak labels entering calibration | Low/High | Frozen ≥5 support per dimension; empty result is a failure, not a pass. |
| Aggregate treated as `[-3,3]` values downstream | Medium/Medium | Output documents standardized native labels; no rescaling performed here. |
