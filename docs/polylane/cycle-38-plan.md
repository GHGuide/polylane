# Cycle 38 plan — executable taste-certification engine

## Target

`m32.2`: implement live rendering, blinded ballots, calibration, aggregation, and
fail-closed taste certification. This cycle converts the frozen Cycle 37 protocol
into Bash 3.2 + jq executables and adversarial regression tests. It does not claim
that the real old-versus-new benchmark has passed.

## Frozen acceptance

Cycle 38 is GO only when all of the following pass from the integrated tree:

```bash
tests/test-taste-certification.sh
tests/test-visual-capture.sh
shellcheck -S warning bin/polylane-taste.sh bin/polylane-visual-capture.sh
```

The integrator also runs every new focused `test-taste-*` test, `git diff --check`,
the marker/doc contract, and the repository seam scanner. A fixture may test a
rejection path, but no tiny PNG signature, caller-supplied `pass`, prose verdict,
or missing adapter receipt may produce a positive certificate.

## Eight-way implementation carve

| Lane | Exclusive implementation | Frozen responsibility |
|---|---|---|
| capture-engine | `bin/polylane-visual-capture.sh`, `tests/test-visual-capture.sh` | invoke a declared browser adapter, capture the complete viewport/state matrix, and emit fresh provenance receipts |
| pixel-verifier | `bin/polylane-taste-pixels.sh`, `tests/test-taste-pixels.sh` | decode PNG structure and dimensions; reject header-only, duplicate, stale, linked, traversal, wrong-viewport, or synthetic-placeholder evidence |
| calibration-corpus | `bin/polylane-taste-corpus.sh`, `tests/test-taste-corpus.sh` | validate pinned open-corpus manifests, license receipts, deterministic samples, hashes, domain balance, and holdout separation |
| judge-calibration | `bin/polylane-taste-calibrate.sh`, `tests/test-taste-calibrate.sh` | recompute held-out judge accuracy, Wilson uncertainty, consistency, and eligibility; weak judges cannot vote |
| blind-ballot | `bin/polylane-taste-ballot.sh`, `tests/test-taste-ballot.sh` | enforce opaque identities, sealed pointwise-before-pairwise records, mirrored sides, independence, abstention, and leakage checks |
| stats-engine | `bin/polylane-taste-stats.sh`, `tests/test-taste-stats.sh` | deterministic Wilson and tie-aware aggregation primitives with strict numeric and sample-unit validation |
| cert-aggregator | `bin/polylane-taste.sh`, `tests/test-taste-certification.sh` | derive the certificate from evidence; require diversity, thresholds, confidence, calibration, function/a11y vetoes, and honest machine-versus-human labels |
| threat-engine | `bin/polylane-taste-threat.sh`, `tests/test-taste-threat.sh` | detect prompt injection, receipt tampering, cross-brief template sameness, suspicious duplicate pixels, and provenance failures without claiming AI authorship |

Every builder writes only its two implementation/test files, its verification file,
and its status marker. The integrator merges all eight current tips and may repair
cross-module interfaces on its own branch. It owns `docs/verify-integration.md` and
`docs/parallel-status.md`.

## Shared executable contract

- JSON inputs are versioned, regular repository-relative files; symlinks, traversal,
  duplicate keys, malformed numbers, stale source revisions, and unknown schema
  versions fail closed.
- Every positive capture has decoded pixels, exact declared viewport/state/route,
  content hash, source revision, adapter identity, start/end time, and freshness.
- Judge eligibility is recomputed from held-out human labels. Ballots cannot carry
  their own trusted eligibility or final score.
- Pointwise dimensional judgments are sealed before pairwise preference; candidate
  identities are opaque and A/B order is mirrored across isolated judges.
- `bin/polylane-taste.sh certify MANIFEST CERTIFICATE` is the one public compiler.
  It writes a deterministic certificate atomically and returns nonzero unless every
  required gate passes. The caller never supplies `status`.
- `TASTE-CERTIFIED` requires at least ten varied briefs, at least five eligible
  independent votes per brief, at least 70% preference, Wilson lower bound above
  0.50, zero function/accessibility regressions, and clean threat/provenance gates.
- A machine panel calibrated on human labels reports `human_calibrated: true` and
  `human_certified: false`. Only actual eligible human ballots may set the latter.
- Common gradients, fonts, cards, or layouts are genericness review signals only;
  appearance never proves AI authorship or copying.

## Guardrails

- Pure Bash 3.2 + jq for the core. Browser and image decoders are declared optional
  adapters with receipts; absence yields `UNKNOWN`/not certified, never PASS.
- No corpus download, package install, publication, deployment, or external action in
  this cycle. Use hermetic fixtures and local browser adapters for focused tests.
- Preserve the Cycle 37 protocol as the semantic authority. Interface simplification
  is allowed only when it remains versioned, deterministic, and fail-closed.
- Do not mark `m32.3`, `m32.4`, `m32.5`, or `c84`–`c90` done. Later cycles integrate
  builder prompts, run the live benchmark, and certify both installed providers.

