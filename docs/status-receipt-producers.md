STATUS: receipt-producers DONE run=c39-visual-loop-20260812-a1

Lane: receipt-producers (Cycle 39). Closed the validator receipt chain: pixel,
corpus, calibration, ballot, statistics, and threat validators each emit one
atomic, versioned, hash-bound receipt with validator-derived status and
classification, exact input SHA-256, subject/adapter/tool-fingerprint bindings,
output counts, and stable reason codes. Caller-supplied pass/status/fixture
flags are never trusted; classification is `fixture` this hermetic cycle.

Verification (all green):
- tests/test-taste-pixels.sh                36 pass, 0 fail
- tests/test-taste-ballot.sh                26 pass, 0 fail
- tests/test-taste-corpus.sh                32 assertions
- tests/test-taste-calibrate.sh             pass
- tests/test-taste-stats.sh                 pass
- tests/test-taste-threat.sh                23 pass, 0 fail
- tests/test-taste-validator-receipts.sh    38 pass, 0 fail (chain closure + 7 forgery rejections)
- shellcheck -S warning on all six owned helpers: 0 findings
- git diff --check: clean

Clock fix: pixels test clock pinned to commit_epoch+3600 so slow negative cases
test their intended reason instead of expiring a frozen timestamp; stable across
repeat runs.

Owned files committed: six helpers, six focused suites, the cross-validator
suite, and docs/verify-receipt-producers.md.

DEFERRED: compiler receipt-schema convergence with certificate-v2 (its seq-6
relay requests closed key-sets + a production `fixture_only:false` ballot;
counter-proposed subset validation + fixture-only ballot via the relay — see
docs/verify-receipt-producers.md `## DEFERRED`). Producer side complete.
