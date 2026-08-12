STATUS: source-adversary DONE run=c41-source-calibration-20260812-a1

## Delivered
- tests/test-taste-source-adversarial.sh — 50 hermetic black-box attack assertions, 7 seams.
- tests/test-taste-source-campaign-e2e.sh — chained cache→build→corpus→calibration rehearsal with six adversarial replays, 19 assertions, 5 seams.
- docs/verify-source-adversary.md — attack matrix, seam/risk register, integrator wiring notes.

## Verification
- `bash tests/test-taste-source-adversarial.sh` → `PASS test-taste-source-adversarial assertions=50 seams=7`
- `bash tests/test-taste-source-campaign-e2e.sh` → `PASS test-taste-source-campaign-e2e assertions=19 seams=5`
- Both bash-3.2 clean and `shellcheck -S warning` clean. Red-capability proved via scratch mutants (wrong expected code fails at the mutated assertion). Integrator mode `POLYLANE_ADVERSARY_REQUIRE_SEAMS_CLOSED=1` exits 1 while seams remain open.
- No network or provider calls; guarded canary asserted UNKNOWN-not-PASS.

## Interface mismatches for the integrator (full table in verify doc)
- Pinned source metadata bytes are digest-verified but never parsed: wrong DOI/version/licence or challenge-HTML metadata matching its own pin is accepted today (source-freeze/dataone-metadata must reject with SOURCE-MISMATCH).
- `bin/polylane-taste-corpus.sh validate` requires calibration == holdout per domain, so the frozen 60/24-per-domain production split is rejected as-is (corpus-select must reconcile).
- Challenge HTML pinned as an image object passes digest checks (cache-integrity must add content inspection).
- Cross-unit raw-response reuse is accepted by the v2 validator (calibration-campaign must enforce unique sessions).

SKILL-EVIDENCE: superpowers:test-driven-development — helped: watched stage-2 corpus validation fail red before adjusting the rehearsal split, and proved red-capability with mutated-assertion scratch runs instead of trusting first-pass green.
SKILL-EVIDENCE: engineering:testing-strategy — helped: negative-dominant attack matrix organised by trust boundary (plan schema, cache objects, join, split, campaign, receipt), one behavior per assertion.
SKILL-EVIDENCE: engineering:debug — helped: reproduced/isolated the bash-3.2 `local d="$TMP/replay-$name"` unbound-expansion fault (and its misleading exit 0) by running under /bin/bash rather than inspecting.
SKILL-EVIDENCE: operations:risk-assessment — helped: seam register ranks likelihood×impact and assigns each open defense to its owning lane (two Critical: metadata crosscheck, unbalanced-quota validator conflict).
