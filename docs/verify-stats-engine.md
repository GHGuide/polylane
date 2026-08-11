# Stats engine verification

## Contract

`bin/polylane-taste-stats.sh aggregate` reads one strict JSON envelope from stdin:

```json
{"schema":"polylane.taste.ballots.v1","ballots":[{"brief_id":"brief-a","vote":"candidate"}]}
```

Every ballot is one independent brief unit. Its only accepted vote values are
`candidate`, `baseline`, and `tie`; a tie contributes 0.5 to preference
successes. The input accepts no summary counts, weights, calibration values, or
other fields. Output is compact, key-sorted JSON with schema
`polylane.taste.stats.v1`.

The engine uses the two-sided 95% Wilson lower bound (`z = 1.96`) without
rounding before the decision. It passes only when preference rate is at least
0.70 and lower bound is strictly greater than 0.50.

## Commands

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/stats-engine" -- bash tests/test-taste-stats.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/stats-engine" -- shellcheck -S warning bin/polylane-taste-stats.sh tests/test-taste-stats.sh
```

## Known-value and boundary vectors

- 7 candidate wins and 3 baseline wins: rate `0.7`, lower bound approximately
  `0.3968`, therefore `pass: false`. This proves equality at the rate boundary
  does not override a lower bound at or below 0.50.
- 10 candidate wins: lower bound approximately `0.7225`, therefore `pass: true`.
- candidate/baseline/tie: counts `1/1/1`, preference successes `1.5`, rate
  `0.5`, therefore `pass: false`. The denominator remains all three briefs.

## Adversarial input checks

The focused test rejects an empty ballot list, duplicated `brief_id`, injected
summary counts or `brief_count`, untrusted weight fields, malformed decimal
text, and `NaN`/`Infinity`. Strict object-key validation prevents denominator
and weighting tricks. The implementation forces `LC_ALL=C`; the focused test
compares the same output when called under `de_DE.UTF-8`.

## Skill receipts

SKILL-READ: data:statistical-analysis | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/statistical-analysis/SKILL.md | 2702170626-10434

SKILL-READ: data:validate-data | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/validate-data/SKILL.md | 1311249913-14916

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: data:statistical-analysis — helped: selected a Wilson interval over point-rate-only gating and preserved ties as half preference successes.

SKILL-EVIDENCE: data:validate-data — helped: strict raw-unit validation rejects duplicate sampling, injected counts, and invalid numeric payloads.

SKILL-EVIDENCE: engineering:testing-strategy — helped: focused coverage spans calculation vectors, pass boundaries, locale behavior, and hostile input.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the initial focused test was run red against the absent script before implementation.

## DEFERRED

The certificate compiler's mirrored-group receipt adapter remains a cross-lane
integration concern. This primitive accepts only one already-resolved vote per
brief and does not authorize or infer ballot eligibility.
