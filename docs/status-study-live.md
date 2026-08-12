STATUS: study-live DONE run=c40-live-harness-20260812-a3

Lane: study-live — study compiler + certificate-v2 live consumer seam.

## Delivered
- bin/polylane-taste-study.sh (new): write-once study freeze
  (taste-study-spec/v1 -> taste-study-freeze/v1, freeze_sha256 =
  SHA-256(jq -cS constants)) locking baseline/current revisions, corpus
  hash+order, >=2 provider/model configs, calibration sources/splits, panel
  cohorts, thresholds, repair budget, evidence prefixes, claim, analysis; and a
  compile step binding every frozen constant to the evidence manifest (no
  post-freeze drift), delegating subject ancestry, and emitting
  taste-study-certificate/v1 with live_study_executed:false + external
  prerequisites.
- bin/polylane-taste.sh: additive POLYLANE_TASTE_LIVE mode rejecting v1/fixture
  receipts in the deciding roles — calibration-v2 production (invocation/image/
  label/raw-response/parser bindings + session_id), ballot-v2 production with
  unique per-exposure session ids, threat-v2 production, unique session ids,
  human_certified preserved false. New codes computed only when live.
- tests/test-taste-study-live.sh, tests/test-taste-live-harness-e2e.sh,
  docs/verify-study-live.md.

## Evidence (CHECK-CACHE: PASS)
- shellcheck -S warning (owned scripts + tests): clean.
- test-taste-certification.sh: PASS (backward compat preserved byte-for-byte).
- test-taste-study-live.sh: PASS (live positive chain, write-once freeze, 14
  one-mutation-per-role false-positive attacks).
- test-taste-live-harness-e2e.sh: PASS (complete production-shaped chain; real
  calibrate producer receipt proven fixture-grade and rejected in live mode;
  fixture ballot cannot cross; determinism; no live study claimed).

## Relay
- Handled prompts-live seq3 (informational; baseline 0b802ad consistent with the
  freeze).
- Posted study-live -> calibration-live (seq6) and study-live -> ballot-live
  (seq7): exact live-role consumer contract so producers converge on it rather
  than weakening validation.

## Still external (EXTERNAL-EVIDENCE)
Real browser/Playwright renders, pinned human calibration labels, an independent
human panel, and an executed evidence-passing live old-versus-new study. Until
producers emit non-fixture receipts, live compilation yields NOT-CERTIFIED, never
a fixture fallback. No Cycle-40 artifact marks m32.4 complete or mints a taste
certificate.

## Owned commit
aa2d822 feat(taste): frozen live-study compiler + certificate-v2 live production mode
