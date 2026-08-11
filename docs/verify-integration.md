# Cycle 37 integration verification

Run: `c37-taste-research-20260811-a1`
Scope: research integration for `m32.1`; no implementation, benchmark, render,
human label, human panel, calibration, external action, or taste certificate is
claimed.

## Inputs independently checked

- Cycle 37 plan and research scope; frozen `m32.1` `taste-research` command.
- All eight lane reports and verification records from `lane/c37-hci-rubric`,
  `lane/c37-human-corpus`, `lane/c37-judge-science`, `lane/c37-visual-feedback`,
  `lane/c37-design-practice`, `lane/c37-anti-homogenization`,
  `lane/c37-threat-model`, and `lane/c37-red-team`.
- Canonical relay, including the 50-source/49-evidence registry update, the
  independent anti-pattern four-axis correction, and the incumbent-preserving
  visual-loop controls.
- Final relay follow-ups: the 32-source corpus audit (separate cleared executable
  core and non-pooled fidelity/taste/grounding/function tracks), multimodal judge
  guardrails (cross-family/atomic/staged/abstaining diagnostics), and the
  prompt-as-sampled-unit preference-study analysis (20-brief target, 100-brief
  manifest capacity, Davidson/Thurstone/cluster-uncertainty extension).
- Refinement queue: both eligible records were declined once with a documented
  no-new-local-repair rationale; the queue was then empty.

## Merge evidence

`RESEARCH.md` has an explicit eight-lane merge table. `PROTOCOL.md` implements
the corresponding state machine and versioned contracts for briefs/references,
candidate IDs, live browser captures, hard gates, pointwise records, calibration,
mirrored ballots, exclusions, aggregation/confidence, sameness axes, repairs,
and labels. It resolves the direction-count and mirror/isolation tensions in
`cycle-37-council.md`, by source strength and operational falsifiability rather
than majority wording.

## Exact verification commands

```bash
git diff --check
test -s docs/polylane/taste-certification/RESEARCH.md
test -s docs/polylane/taste-certification/PROTOCOL.md
rg -qi 'human[- ]rated|human label' docs/polylane/taste-certification/RESEARCH.md
rg -qi 'pointwise.*pairwise|pairwise.*pointwise' docs/polylane/taste-certification/PROTOCOL.md
rg -qi 'position bias|side.*mirror' docs/polylane/taste-certification/PROTOCOL.md
rg -n 'MACHINE_EVALUATED|HUMAN_CALIBRATED_MACHINE|HUMAN_CERTIFIED|NOT-CERTIFIED|UNKNOWN' docs/polylane/taste-certification/PROTOCOL.md
rg -n '1440|390|five eligible|0\.70|Wilson|accessibility|two.*repair|genericness_review|provenance_integrity' docs/polylane/taste-certification/PROTOCOL.md
```

The frozen focused command is run once through the required check cache during
final verification. URL validation uses the bibliography URL list in
`RESEARCH.md`, accepts ordinary 2xx/3xx responses and records known automated
client access-restriction responses separately; a network failure is recorded,
never silently removed from the bibliography.

Final frozen `m32.1` `taste-research` command: **PASS** through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"`; its cached
receipt records the two required artifacts, human-rated/label evidence, the
pointwise-before-pairwise contract, and the side/mirror position-bias control.

Observed integration checks before the final focused command: `git diff --check`
passed; every eight-lane merge key and named red-team contract scenario was
present; post-relay corpus/judge/statistical controls were present. Read-only URL
validation checked 31 unique bibliography URLs over 7 domains: 23 returned
2xx/3xx, 8 DOI endpoints returned access-restricted 403, and none was missing.
The check initially exposed a parenthesized DOI extraction defect; the URL was
encoded, then the full validation reran with zero failures.

Final relay review also identified a potentially confusing `candidate_id` concern
in the capture example. The contract now explicitly distinguishes the single root
`candidate_id` from `candidate_source_revision`; all 16 fenced JSON examples were
parsed with `jq --stream` and had no duplicate object-key paths.

## Red-team result

The protocol was challenged against the reproduced header-only PNG,
arbitrary-reference-byte, duplicate self-scored corpus, static-state theater,
desktop-as-mobile, caller-supplied judge pass, accessibility-veto, ballot
correlation, side bias, calibration leakage, identity/prompt injection,
cherry-picking, repair-reset, goal-drift, cross-run receipt, and common-motif
false-positive cases. Each has a defined `NOT-CERTIFIED`, `UNKNOWN`, invalidation,
or `REPLAN` transition. Same-family self-judging, strict mirrored machine
abstention, visual prompt-injection transfer, and judge-debate inflation were
also added as machine-diagnostic failures. In particular, appearance never
establishes AI authorship, copying, bad taste, or provenance.

## Unresolved limits

- The live corpus acquisition, licences/checksums, raw-label joins, and held-out
  split remain unperformed external evidence.
- Browser/decoder/OCR/accessibility adapters, their host integrity, and exact
  perceptual thresholds are future implementation/policy work.
- Human identity, consent, independence, representative coverage, assistive-tech
  experience, semantic product fit, and IP/non-copying are external review scopes.
- All stated policy thresholds require future preregistered calibration; no number
  is presented as a universal human-taste law.

## Next implementation carve

Implement only the contract parser/event-chain validator and negative fixtures
first; then declared capture/adapters, corpus importer, ballot packager,
aggregator, cross-brief review, and repair controller in the sequence specified
by `PROTOCOL.md`. Do not implement a certificate issuer or claim live evidence
until each prerequisite slice and its external receipts pass.

## Selected-skill receipt and evidence

SKILL-READ: deep-research | /Users/leonardo/.agents/skills/deep-research/SKILL.md | 3883242303-4343

SKILL-READ: design:research-synthesis | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/research-synthesis/SKILL.md | 335799056-3014

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-EVIDENCE: deep-research — helped: separated primary HCI/dataset/standard support from preprint, first-party-practice, and external evidence limits, then kept URLs traceable.

SKILL-EVIDENCE: design:research-synthesis — helped: merged eight lanes into explicit themes and resolved the direction-count and mirrored-isolation tensions without flattening their limits.

SKILL-EVIDENCE: engineering:code-review — helped: found the malformed parenthesized DOI during the reachability audit and checked the closed-contract failure paths for identity, provenance, and stale evidence.

SKILL-EVIDENCE: engineering:testing-strategy — helped: turned each red-team false pass and final-relay risk into negative fixture requirements, explicit transition outcomes, and a staged implementation map.
POLYLANE-VERDICT: GO run=c37-taste-research-20260811-a1
