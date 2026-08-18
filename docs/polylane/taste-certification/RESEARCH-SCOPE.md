# Taste-certification research scope

## Decision to support

Define the smallest executable protocol that lets Polylane claim a UI workflow is
better-tasting without confusing a model's confidence, a JSON fixture, or a single
reviewer's preference with human evidence.

## Core questions

1. Which aesthetic dimensions have validated human-measurement support for websites?
2. Which functional and accessibility checks must be hard vetoes rather than taste votes?
3. How should pointwise scoring, blinded pairwise choice, mirrored order, judge
   calibration, exclusion, aggregation, and uncertainty work?
4. What rendered-feedback process improves UI generation without creating an infinite
   polish loop or forgetting the product goal?
5. How should 3-5 category references plus a wildcard create a product-specific visual
   grammar without copying a single source or converging on the same fashionable template?
6. What evidence is sufficient for `TASTE-CERTIFIED`, and what must remain explicitly
   external or machine-evaluated?

## Evidence standard

- Prefer peer-reviewed HCI, evaluation, and UI-generation work; standards and public
  dataset cards are primary evidence for their own contracts and licenses.
- Triangulate every load-bearing mechanism with at least three independent sources.
- Record contrary findings and known limits, especially demographic taste variation,
  model-judge bias, position effects, prompt leakage, and benchmark overfitting.
- Keep all quotations short; write the synthesis in original language with stable URLs.
- Do not label the system human-certified unless a human panel actually supplied the
  deciding ballots. A model panel may be certified only against held-out human labels.

## Frozen implementation implications

The final protocol must require real browser-rendered images, at least ten varied product
briefs, at least five eligible independent ballots per brief, pointwise reasoning before
pairwise choice, mirrored A/B order, a human-labeled calibration gate, an accessibility
veto, a product-specificity/homogenization check, and an uncertainty bound. It must fail
closed on missing or duplicated evidence.
