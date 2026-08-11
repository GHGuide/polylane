# Certificate compiler verification

## Scope

`bin/polylane-taste.sh certify MANIFEST CERTIFICATE` is the only public compiler.
It treats the manifest as a versioned index of regular, non-symlink receipt paths;
it derives verdict facts from brief locks, candidates, captures, hard gates,
mirrored groups, calibration receipts, cross-brief reviews, threat receipt, and
repair ledger. It never accepts an input status, score, eligibility, count, or
pass flag.

## Commands

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/cert-aggregator" -- tests/test-taste-certification.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/cert-aggregator" -- shellcheck -S warning bin/polylane-taste.sh
```

Both commands passed in this lane. The test creates a hermetic ten-brief fixture;
it proves compiler mechanics only and is not described as, or usable as, a real
benchmark.

## Positive threshold fixture

The fixture has ten unique brief locks/tasks/categories/source revisions and
non-duplicate decoded pixels. Every brief has five complete A/B + B/A groups,
all 50 groups choose the target, and all 100 machine judges have independently
listed eligible `taste-calibration/v1` receipts. It produces:

- `status: TASTE-CERTIFIED`
- `human_calibrated: true`
- `human_certified: false`
- 10 brief wins, preference 1.0, and a Wilson lower bound above 0.50.

## Fail-closed coverage

The focused test verifies a nonzero exit plus an atomically replaced, valid
`NOT-CERTIFIED` certificate for caller status/score injection, fewer than ten
briefs, fewer than five groups, a missing judge calibration, a missing hard-gate
receipt, and a missing threat receipt. The compiler also blocks malformed or
unknown manifest shapes, path traversal/symlinks, duplicate brief/category/task/
revision/pixel evidence, invalid mirrored orders or shared judges, no strict
brief winner, fewer than seven brief wins, preference below 0.70, Wilson lower
bound at or below 0.50, failed or missing task/accessibility/state gates,
unresolved cross-brief review, any unclean/unknown threat axis, and invalid
repair ledger.

Atomic-write proof: each negative case first places non-JSON bytes at its target;
after the nonzero compiler return, the target parses as an honest failure
certificate and no `CERTIFICATE.tmp.*` file remains.

## Skill receipts

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

## DEFERRED

The hermetic receipts do not prove live browser execution, a real human panel,
identity assurance, or the planned benchmark. Those require the producer lanes'
adapters and later integration evidence.

SKILL-EVIDENCE: engineering:code-review — helped: caught the need to reject caller verdict fields and receipt-path trust boundaries.

SKILL-EVIDENCE: engineering:testing-strategy — helped: focused the fixture on thresholds, error paths, and atomic output behavior.

SKILL-EVIDENCE: operations:risk-assessment — helped: made missing/tampered evidence a hard failure, rather than a fallback.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the initial missing compiler and later caller-status case were both observed red before their implementation.
