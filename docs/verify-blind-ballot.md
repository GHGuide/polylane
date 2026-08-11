# Blind-ballot verification

Run ID: `c38-taste-engine-20260811-a1`

## Contract

`bin/polylane-taste-ballot.sh validate GROUP POINTWISE_DIR CALIBRATION OUT`
accepts only a `taste-mirrored-group/v1` fixture chain. It validates opaque
`stim-<12 hex>` candidate IDs; byte hashes of the two pointwise files;
eight complete 1–7 diagnostic dimensions (product fit, hierarchy, typography,
color, spatial rhythm, craftsmanship, originality, coherent states); immutable
timestamps; and two different, independently attested, calibrated judges.

The two exposures must be exactly A/B and B/A, agree on one canonical opaque
candidate, follow both pointwise seals, and have no identity/prior-ballot,
prompt-injection, or discussion signal. `abstain` is valid only with a reason,
but makes a group ineligible. The output is always `fixture_only: true` and
`human_certified: false`; it exposes only `brief_sha256`, opaque `winner`,
mirror group ID, and the source group hash, never a candidate/provider mapping
or candidate/baseline label.

## Commands and results

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/blind-ballot" -- \
  bash tests/test-taste-ballot.sh
# 11 pass, 0 fail

bin/polylane-check.sh "$PWD/.polylane/check-cache/blind-ballot" -- \
  shellcheck -S warning bin/polylane-taste-ballot.sh tests/test-taste-ballot.sh
```

The mirrored acceptance fixture proves an eligible A/B plus B/A pair with
different judges and the same canonical opaque winner. Rejection assertions
cover order contradiction, duplicate mirror judge, visible identity, detected
prompt injection, an out-of-range pointwise score, and failed calibrated
abstention policy. Malformed JSON, duplicate keys, unknown fields, non-regular
or symlinked inputs, missing byte hashes, timestamps, observations, or required
dimensions fail closed in the implementation.

## Skill receipts

SKILL-READ: design:design-critique | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/design-critique/SKILL.md | 3a4f260eb9f60b431782bf6d90f22afb480c0c67860267a032df58a3e1bd19cd

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 5c5e95830754bbdd838213fa05fc8f07523f591fd558fd3c86031ffd479f7a9e

SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 82e29810a762c396a56f92bbd5c5afd252f7a07c6be69a246c28f7b82c4086d9

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | bf1b8216e523851a411e91d429a7c1c2a173e79d88957bc78e348218d50edd54

SKILL-EVIDENCE: design:design-critique — helped: the required dimensions preserve hierarchy, typography, color, spatial rhythm, and coherent state observations as non-compensatory diagnostics.

SKILL-EVIDENCE: engineering:testing-strategy — helped: focused tests cover the contract's main acceptance path and the high-risk integrity boundaries.

SKILL-EVIDENCE: operations:risk-assessment — helped: identity, order, injection, shared-judge, malformed-input, and calibration risks are rejected rather than scored around.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the initial focused suite failed before the executable existed, then passed after the minimal validator was added.

## DEFERRED

No real judge, calibration corpus, browser render, human ballot, or taste
certificate was claimed or created. These fixtures validate only the ballot
contract; integration supplies real capture, calibration, aggregation, and
threat receipts in later work.
