STATUS: ballot-live DONE run=c40-live-harness-20260812-a3

Lane: ballot-live
Producer: bin/polylane-taste-ballot-live.sh (taste-ballot-validation/v2)
Tests: tests/test-taste-ballot-live.sh — 50 pass / 0 fail
ShellCheck: clean (script + test)
Evidence: docs/verify-ballot-live.md

## Summary
Production v2 producer derives the mirrored-group winner only from bound live raw
responses. Every caller field is recomputed before trust: group/brief/escrow
(canonical)/capture/calibration/orientation SHAs, both raw-response hashes,
pointwise self-hashes, request/image hashes, candidate-capture hashes, and
independence attestations. Winner is derived from raw bytes through the
recomputed orientation map and must agree across two distinct, independent,
calibrated judges on mirrored orders. fixture_only:false only when every
invocation is declared "live" by a declared provider adapter; any fixture
ancestor degrades. All forbidden modes (contradiction, tie, alias, reuse,
leakage, injection, abstention asymmetry, stale/future timestamp, missing raw
bytes, caller winner) fail closed with no receipt.

## Cross-lane contract
Receipt satisfies the v2 certificate consumer's promotion predicate
(polylane-taste.sh V2_CERT_FILTER, lines 398-407): schema v2, status eligible,
human_certified false, mirror_group_id + brief_sha256 bound to group,
fixture_only false, group_sha256 == raw-file SHA (consumer S()), winner ==
exposures[0].canonical_choice. Consumer is a forbidden neighbour — asserted, not
invoked.

## Boundaries honoured
OWN written: bin/polylane-taste-ballot-live.sh, tests/test-taste-ballot-live.sh,
docs/verify-ballot-live.md, docs/status-ballot-live.md. No neighbour path touched
(v1 ballot, provider adapters, certificate compiler read-only for contract).

## Relay
Start + final relay pending checked; no request addressed to ballot-live
(pending traffic addressed to task-live / generate-live / study-live).

## Skill receipts
SKILL-READ: engineering:code-review | .../skills/code-review/SKILL.md | 936987158-4285
SKILL-READ: engineering:testing-strategy | .../skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-EVIDENCE: engineering:code-review — helped: trust-seam audit surfaced the
winner-derivation and forbidden-self-attestation (residual liveness) seams.
SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped red-first,
one-mutation-per-edge structure over trivial-path coverage.
