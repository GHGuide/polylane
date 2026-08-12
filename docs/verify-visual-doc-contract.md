# Verify — visual-doc-contract (Cycle 39)

Lane scope: rewrite the shared planning/prompt doctrine into a provider-neutral,
manifest-derived UI contract that positively defines product fit and forbids builder
self-certification. Owned files only: `references/visual-intelligence.md`,
`references/prompt-blocks.md`, `references/planning.md`, `references/lane-template.md`,
plus this evidence file and the status file. No compiler, linter, test, provider
`SKILL.md`, or installer was edited.

## What changed

- `references/visual-intelligence.md` — rewritten. Adds the ownership boundary
  (builder owns implementation + capture only; coordinator owns anonymization,
  judging, tournament selection, promotion, verdicts), the `ui_contract` object
  summary, hash-consumed design lock, positive product-specificity requirements,
  generic-pattern signals as secondary hashed exceptions, reference packet with real
  screenshot/provenance hashes and borrow/transform/avoid mappings, three directions
  differing on thesis/layout family/token system/signature rendered before
  convergence, benchmark separation (`SELECTED_NOT_CERTIFIED` vs `TASTE-CERTIFIED`,
  `human_certified:true` only by real humans), and honest external claims.
- `references/prompt-blocks.md` — block 0 now emits one of two provider preambles
  (Claude reads `CLAUDE.md`, Codex reads `AGENTS.md`; different skill + model syntax),
  and states the neutral body never assumes `CLAUDE.md`/memory/`/model`/"ultrathink"/
  slash commands. Block A dereferences the context file from the preamble. Block B is
  provider-aware (both agents have a real CLI effort flag). Block D.2 is rewritten to
  carry the five manifest-derived lines `UI-CONTRACT`, `UI-IMPLEMENT`, `UI-CONTENT`,
  `UI-EVIDENCE`, `UI-REVIEW-BOUNDARY`; the builder-supplies-three-lenses instruction
  is removed. Block F adds the frozen `ui_contract` to the hard contract.
- `references/planning.md` — §1 makes UI classification automatic and auto-attaches
  `surface:"ui"` + `ui_contract` (mode `authoritative`, with `legacy` defined); §5
  requires the provider preamble and points the UI block at the five UI-* lines with
  coordinator-owned verdicts; §6 adds the full UI lane fragment, the
  `ui-design-lock/v2` file schema, the production receipt chain, and taste memory as
  project-scoped, human-certified-only, bounded untrusted data.
- `references/lane-template.md` — stale "there is no CLI effort flag" claim replaced
  with the real per-provider effort flags (`claude --effort`, `codex -c
  model_reasoning_effort=`) plus `POLYLANE_EFFORT`; skeleton gains the provider
  preamble note and the D.2 UI block; manifest-emit section documents the two
  sanctioned UI keys; mini-example labeled as the Claude form with the Codex swap and
  the UI-lane additions.

## Before/after contradictions removed

| Before (contradiction) | After |
|---|---|
| Builder "supplies independent design, accessibility, and originality lenses" and the council selects (prompt-blocks D.2, planning §5) | Builder captures evidence only; coordinator-owned isolated calibrated judges own all lenses/verdicts (`UI-REVIEW-BOUNDARY`) |
| Generic-pattern blacklist "unless the product/reference evidence specifically justifies" (free-form) | Positive product-specificity is primary; generic motifs are secondary risk signals with a structured hashed `constraint_exception` reviewed by the coordinator |
| Neutral block A hardcodes "Read THIS project's CLAUDE.md" | Context file dereferenced from the provider preamble (Claude `CLAUDE.md` / Codex `AGENTS.md`) |
| Block B: "confirm with /model, ultrathink" for every agent | Provider-aware header; `/model`+ultrathink only on the Claude form |
| lane-template:11 "there is no CLI effort flag" | Both agents pass effort via CLI (`--effort` / `-c model_reasoning_effort=`), confirmed against `bin/polylane-run.sh:1839,1842` |
| Design lock "may change only through a recorded council repair," builder-selectable direction | Lock produced before implementation, consumed by the builder by SHA-256, never invented; direction selected by the coordinator after all three render |

## Evidence

### Marker / doc-grep tests (focused reference checks, via check-cache)

```
test-prompt-economy.sh          19 pass, 0 fail
test-handoff-contract.sh        58 pass, 0 fail
test-visual-loop-integration.sh 28 pass, 0 fail   (installs Codex fixture; asserts the
                                                   installed references/visual-intelligence.md
                                                   research/lock/directions/certification
                                                   contract survives the rewrite)
```

The `visual-reference-research` assertion required the literal `3-5 relevant
references`; the rewrite preserves that exact phrasing. The whole-file
`design lock -> capture -> three -> verdict -> repair -> champion` ordered assertion
(`visual-reference-certification-artifacts`) passes.

### Schema / JSON checks

- The two JSON fragments added to `references/planning.md` (UI lane object; the
  `ui-design-lock/v2` file) parse as valid JSON (Python `json.loads`, 745 + 1397
  bytes). The one invalid `json` block found under `references/` is the pre-existing
  `run.json` schema in lane-template with unquoted `<N>` placeholders — not introduced
  here.
- All five `UI-*` line names are defined in prompt-blocks D.2 (authoritative source)
  and referenced consistently in planning §5/§6 and lane-template.

### Link / path audit

- Every markdown `[](...)` link in the four owned files resolves to an existing
  sibling in `references/` (verified by resolver loop: 0 broken).
- The installed skill package `~/.claude/skills/polylane/` ships `references/` but not
  `docs/`. Project docs (`docs/polylane/taste-certification/PROTOCOL.md`,
  `docs/polylane/cycle-39-plan.md`) are therefore referenced by repo-relative backtick
  path — matching the existing convention in `references/cycle-9-control-room.md:4` —
  not by a `../docs/` markdown link that would dangle from the package root.

### Provider-neutral vs native cross-check (manual)

- Every `/model`, `ultrathink`, and `CLAUDE.md` occurrence in the four files is either
  inside a Claude-labeled preamble/form, a Claude-labeled example, or an explicit
  statement that the neutral body must not assume them / that the Codex side lacks
  them. `AGENTS.md` is paired on the Codex side throughout.
- One semantic state machine is preserved: both preambles point at the frozen state
  machine in `docs/polylane/taste-certification/PROTOCOL.md` §2.

### Diff gate

- `git diff --check -- references/` is clean (no whitespace/conflict markers).
- `git status --short` shows only the four owned `references/*.md` plus runner-owned
  untracked `.polylane-prompt.txt` and `graphify-out/`.

### Relay

- Executable seam relayed (I cannot edit the compiler/schema): request from
  `visual-doc-contract` to `prompt-contract` asking that the compiler preserve the
  five `UI-*` scalars verbatim through optimization and that the manifest schema
  accept `surface:"ui"` + `ui_contract`, with builders unable to self-certify. Sent
  via the canonical append-only coordination file.

## Skill receipts

SKILL-READ: product-management:write-spec | /Users/leonardo/.codex/plugins/cache/claude-cowork/product-management/1.2.0/skills/write-spec/SKILL.md | 3505650752-12326
SKILL-READ: engineering:documentation | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/documentation/SKILL.md | 177552282-1507
SKILL-READ: design:ux-copy | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/ux-copy/SKILL.md | 504283359-3436
SKILL-READ: humanizer | /Users/leonardo/.agents/skills/humanizer/SKILL.md | 2132021092-27725

SKILL-EVIDENCE: product-management:write-spec — helped: its goals/non-goals and testable acceptance-criteria framing shaped the shift from a free-form generic blacklist to positively defined, checkable product-specificity requirements (primary task/entity/information unit, per-state done-when copy).
SKILL-EVIDENCE: engineering:documentation — helped: "write for the reader," "start with the most useful information," and "link, don't duplicate" produced the ownership-boundary-first ordering of visual-intelligence.md and the backtick-path (not duplicated content) references to the frozen PROTOCOL.md.
SKILL-EVIDENCE: design:ux-copy — helped: its error/empty-state/CTA structure informed `UI-CONTENT` and the real per-state copy requirement (default/loading/empty/error/success/focus/mobile) in the `ui-design-lock/v2` schema.
SKILL-EVIDENCE: humanizer — helped: removed em-dash overuse, rule-of-three, and "unless justified" hedging from the rewritten visual-intelligence.md; the new prose uses straight quotes, plain copulas, and positive definitions (added em-dashes that remain are pre-existing house style in lines I only lightly touched).

## DEFERRED

DEFERRED: manifest schema acceptance of `surface:"ui"` + `ui_contract` and verbatim compiler preservation of the five UI-* scalars — relayed to prompt-contract; integration must confirm the compiler/schema lanes implement it (compiler work remains, owned outside this lane).
DEFERRED: `ui-design-lock/v2` field set — options left open: reconcile the lock fields with the certificate-v2 / packet-intelligence binding at integration, or freeze the documented set as-is; this lane defines the doctrine, the binding lanes own the executable schema.
