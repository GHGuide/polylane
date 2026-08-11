# Threat-engine verification

Run from the repository root:

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/threat-engine" -- bash tests/test-taste-threat.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/threat-engine" -- shellcheck -S warning bin/polylane-taste-threat.sh tests/test-taste-threat.sh
```

`bin/polylane-taste-threat.sh check MANIFEST OUT` accepts only
`taste-threat/v1` evidence and writes a deterministic `taste-threat-receipt/v1`.
It checks bound file hashes and receipt payload hashes before deriving the four
separate result axes:

- `genericness_review`: a three-brief unrelated-template cluster becomes
  `CROSS_BRIEF_REVIEW` and `UNKNOWN`; it does not assert copying, AI authorship,
  bad taste, or a provenance failure.
- `quality_risk`: a function or accessibility failure is a hard veto. This is
  independent of provenance.
- `context_fit`: absent or mismatched supplied context remains `UNKNOWN` and is
  never inferred from appearance.
- `provenance_integrity`: visible prompt injection, ballot identity leakage,
  path/hash mismatch, receipt mutation, duplicate capture pixels, and broken
  sidecar bindings block the evidence chain.

The focused test reproduces each required attack: visible instruction injection,
candidate/provider identity leakage, receipt hash tampering, duplicate captures,
and three unrelated briefs with an identical template. It also proves the
false-positive guard: sharing one palette alone remains clean, while the cluster
receipt keeps `provenance_integrity: unknown` and `attribution_claim: false`.
The final case proves accessibility is a hard `quality_risk` veto without being
misreported as provenance evidence.

SKILL-READ: design:accessibility-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/accessibility-review/SKILL.md | 2943520804-4278

SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: design:accessibility-review — helped: the verification keeps accessibility as an explicit hard quality veto rather than an appearance or provenance signal.

SKILL-EVIDENCE: operations:risk-assessment — helped: the receipt separates high-impact integrity failures from review-only template-risk signals.

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: the schema failure was traced to the nested `axis_results` jq scope before the targeted correction.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the missing executable was demonstrated by the red focused test before implementation.

## DEFERRED

This lane does not infer copyright, copying, AI authorship, or taste from visual
similarity. Ambiguous similarity remains a blinded human review, and integration
owns wiring this receipt into the public certificate compiler.
