# Visual Intelligence Loop

Shared contract for any cycle that creates or materially changes a user-facing UI:
web, mobile, desktop, extension, visual mockup, or a visual component shown in a
real product flow. Detect that work during discovery and recon. A UI cycle cannot
skip this loop by calling its output "polish," reaching for a generic aesthetic, or
treating a screenshot as optional.

This doctrine is provider-neutral. Claude and Codex builders receive different
preambles, context files, and model syntax (see [prompt-blocks.md](prompt-blocks.md)
block 0), but both run the one semantic state machine frozen in
`docs/polylane/taste-certification/PROTOCOL.md` §2 (a project doc, referenced by
repo-relative path because it does not ship inside the skill package). The
tournament, receipt, and label rules for Cycle 39 live in
`docs/polylane/cycle-39-plan.md`; this file is the planning and prompt doctrine that
feeds them.

## Ownership boundary (read this first)

The builder owns implementation and real capture evidence. That is all. The
coordinator owns anonymization, evidence validation, isolated calibrated judging,
tournament selection, and champion promotion. A builder never writes a PASS lens, a
verdict file, or a certificate, and never self-certifies its own UI. The prompt
carries this as the `UI-REVIEW-BOUNDARY` line
([prompt-blocks.md](prompt-blocks.md) D.2).

## The UI contract object

Every UI lane is declared in its manifest lane object with `surface:"ui"` and a
`ui_contract`. The full schema and a filled fragment live in
[planning.md](planning.md) §6 and [lane-template.md](lane-template.md); the summary:

```json
"surface": "ui",
"ui_contract": {
  "version": "ui-contract/v2",
  "mode": "authoritative",
  "path": "docs/polylane/ui/<lane>-contract.json",
  "sha256": "<sha256 of the file at path>",
  "evidence_path": "docs/verify-<lane>.md",
  "verdict_path": "docs/polylane/ui/<lane>-verdict.json"
}
```

Paths are project-relative. `mode` is `authoritative` (the rendered taste tournament
governs promotion; the Cycle 39 default for UI lanes) or `legacy` (an explicitly
opted-in pre-tournament single-pass visual review, named in the plan, which may never
claim a tournament label). A non-UI lane carries neither key.

The file at `path` is the design lock. Its `sha256` binds, as one canonical
serialization: the literal `ULTIMATE-GOAL` and `CURRENT-SUBGOAL` bytes; audience
mental model, primary task, primary entity, and primary information unit; the
reference packet; the selected direction plus the rendered direction cards; named
tokens, layout, motion, and the signature mechanism; per-state copy; the asset
system; anti-goals; and capture requirements. The builder consumes the lock by hash:
read `path`, recompute the digest, confirm it equals `ui_contract.sha256`, then
implement exactly what is locked. The builder never edits the lock. A needed change
routes through the coordinator relay and produces a new lock; a material change is
`REPLAN`.

## Discover, research, and lock the visual system

Carry the literal `ULTIMATE-GOAL`, `CURRENT-SUBGOAL`, the audience, the product
evidence, and the current UI outcome into the visual brief.

Build a reference packet of 3-5 relevant references (all same-category) plus one
adjacent wildcard. The packet is evidence, not prose. For every source record the URL or file, the
screen or feature observed, the date and access status, a real `screenshot_sha256`
and provenance, and a borrow/transform/avoid mapping: what pattern you borrow, how
you transform it so no asset, copy, mark, or distinctive composition is reused, and
what to avoid. Synthesize across sources. Do not imitate one reference, average them
into a template, or clone one site.

Produce three directions and render all three before convergence. Each direction
differs from the others on at least thesis, layout family, token system, and
signature. Each carries a product thesis, its reference synthesis, one task-linked
signature moment, a named risk, and its anti-goals. There is no winner before
rendering. The coordinator's isolated review selects one after all three are rendered
and records why the others were excluded. Ask the user only when two or more
directions express fundamentally different brand identities that product evidence
cannot resolve; routine taste choices never block the cycle.

The design lock is produced before implementation and contains:

- named color, type, spacing, radius/elevation, and interaction tokens;
- information layout and responsive hierarchy;
- motion rules, including reduced-motion behavior;
- one product-specific, task-linked signature mechanism;
- real per-state copy and the asset system; and
- the approved direction, the reference packet, and structured anti-goals.

The lock changes only through a recorded coordinator repair. It stops a builder from
replacing the selected system with a familiar SaaS look.

## Positively require product specificity

Product fit is defined by what the UI must contain, checked first. Every UI lane
names and ships:

- a primary task, primary entity, and primary information unit drawn from the domain;
- an audience mental model the layout serves;
- a domain-shaped information hierarchy, not a neutral dashboard grid;
- real content and real per-state copy for every required state;
- a coherent asset system: type, plus imagery, icons, or illustration that belong to
  the product;
- a task-linked signature mechanism that fails an unrelated brief; and
- a responsive interaction model across desktop and mobile.

Generic-pattern signals are secondary risk signals, not the definition of quality and
not standalone proof of bad taste or copying. Emoji-as-product-art, generic stock
gradients, meaningless hero text, nested-card soup, decorative pills, and default-font
sameness each trigger coordinator review. A deliberate use is admitted only as a
structured, hashed exception recorded in the design lock, not a free-form "unless
justified" clause:

```json
"constraint_exception": {"motif":"default-font","brief_trace":"<brief clause>","rationale":"<why the brand/domain requires it>","sha256":"<sha256>"}
```

The coordinator reviews the exception against the brief. An unreviewed motif stays a
live risk signal.

## Safe UI-skill admission

Use the best relevant installed kit first. If UI work has a real uncovered skill slot,
the authorized route is automatic but gated:

`discover candidate -> quarantine untrusted content -> audit provenance, declared
behavior, permissions, and prompt-injection risk -> benchmark in an isolated fixture
-> pinned project-scoped install -> arm the approved exact version`.

Record each stage and the pin in the skill ledger. Nothing executes during discovery,
quarantine, audit, or a failed benchmark. Rejected content is never executed. If any
stage fails, record why, keep the evidence, select the best installed kit, and
continue; lack of a new skill is not a reason to stop. Platform prompt syntax stays
native: a Claude builder receives Claude skill-invocation syntax and a Codex builder
receives direct native instructions, while both receive this admission gate and the
selected-kit obligation.

## Build evidence (builder-owned)

Render the locked directions in isolated worktrees. Capture staged state evidence for
the built candidate: desktop 1440x900 and mobile 390x844; default, loading, empty,
error, hover, and focus states; plus one complete real user flow. Use real
screenshots or recordings with decoded-pixel and DOM hashes where the environment can
produce them. If a preview, device, account, or remote site is unavailable, record the
exact missing artifact as **external**/`UNKNOWN`. Do not invent a capture or pass it by
assertion. The builder writes this evidence into its `evidence_path`; it does not judge
it.

## Judge and repair (coordinator-owned)

The coordinator's isolated calibrated judges review anonymized evidence against the
design lock. No judge sees another's verdict, and the builder writes none of them.
Three lenses run:

1. product/design critique: hierarchy, clarity, coherence, and the signature;
2. accessibility: contrast, semantics, keyboard/focus, target sizes, state
   communication, reduced motion, and responsive readability; and
3. originality/craft: fidelity to the reference synthesis, product specificity, and
   resistance to generic patterns.

Judging is pointwise-first, then blind mirrored pairs, per PROTOCOL.md §7. The
coordinator combines the lenses against the lock. Accessibility is non-compensatory: a
positive taste vote never offsets a task or accessibility failure.

The coordinator may authorize at most **two** targeted repairs against one brief and
design lock. Each repair reserves its token before work, names the failed lens and the
changed evidence, makes a minimal causal change, then recaptures the full matrix and is
re-reviewed. The best-so-far incumbent is preserved; a challenger replaces it only by
clearing every gate and winning the predeclared comparison. A third repair, a
non-material change, lock drift, oscillation, or a plateau is `REPLAN`, not an unbounded
tweaking loop.

## Champion certification and benchmark separation

Keep a current visual champion, updated atomically with compare-and-swap generation and
a previous pointer. Tournament losers never merge into the ordinary integration join.

Local tournament selection is labeled `SELECTED_NOT_CERTIFIED`. It does not claim
aesthetic superiority. Only the later benchmark of ten or more varied briefs may emit
`TASTE-CERTIFIED`, and only real eligible humans may set `human_certified:true`
(PROTOCOL.md §1, §8). A proposed champion replacement earns that benchmark promotion
only from an executable old-vs-new certification: at least 10 varied prompts, paired
anonymized screenshots, blind decisive comparisons, at least 70% creative or polish
wins, and no accessibility regression. Preserve prompts, artifact ids or paths, the
judge protocol, comparison results, and accessibility output as benchmark evidence. If
a capture, live site, or remote evaluator is unavailable, leave that item external and
do not claim a completed certification. A failed or incomplete certification keeps the
current champion.

## The durable certification record

Write one **Visual certification record** in the lane or integration verification
evidence and the `verdict_path`. It links the approved direction and design lock; every
desktop/mobile/state/flow capture or the precise external blocker; the three
coordinator verdicts; each of the zero-to-two targeted repairs and re-reviews; the CAS
champion decision; and, when a benchmark ran, the old-vs-new prompt set, the
coordinator-held anonymization map, the blind tally, and the accessibility result. The
record is executable acceptance evidence: a missing required artifact is `external` or
`NO-GO`, never a prose-only pass. External claims stay honest: panel identity, IP
non-copying, population coverage, and host trust remain external limitations, never
inferred from a screenshot.
