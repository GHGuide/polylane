# Verify — claude-contract (Cycle 39, run c39-visual-loop-20260812-a1)

Lane owns: `SKILL.md` (root Claude skill, UI route only), `tests/test-claude-taste-contract.sh`,
this file, `docs/status-claude-contract.md`. Codex skill, installers, shared references,
helpers, other tests, manifests, and status files are out of scope and untouched.

## Goal

Make the root Claude skill *require and truthfully describe* the complete executable
visual-taste workflow, without bloating the skill or weakening non-UI project autonomy.
Add a focused grep/fixture test that turns red if the Claude UI route drops or
contradicts any c39 semantic, imports Codex commands/models into the UI path, permits
self-judging or a prose pass, or forgets the goal.

## What changed

- `SKILL.md` — rewrote only the UI-route bullet under **Profile safety gates**
  (lines ~91–125). The route now requires the fail-closed rendered taste tournament and
  states the honest claim boundary. Non-UI flow, frontmatter, model/command doctrine,
  goal tree, evidence safety, autonomous loop, and the separate-Codex architecture are
  unchanged. Opening bullet now explicitly reaffirms `non-UI projects skip it and keep
  full autonomy`.
- `tests/test-claude-taste-contract.sh` — new focused, offline grep/fixture test.

## Test outputs

```
$ bash tests/test-claude-taste-contract.sh
test-claude-taste-contract.sh: 42 pass, 0 fail

$ bash tests/test-skill-parity.sh          # unchanged: all pre-c39 literals preserved
test-skill-parity.sh: 59 pass, 0 fail

$ git diff --check
clean

$ shellcheck -S warning tests/test-claude-taste-contract.sh
(clean)
```

### Negative controls (proves the test fails on contradiction)

| Mutation applied to SKILL.md | Result |
|---|---|
| replace `three meaningfully divergent rendered candidates` → `three rendered options` | `FAIL req-rendered-candidates`, `FAIL ui-requires-tournament` (40 pass, 2 fail) |
| inject `codex exec` into the UI route framing | `FAIL ui-no-codex-or-models` (41 pass, 1 fail) |
| restore | 42 pass, 0 fail |

The test flattens SKILL.md whitespace before matching, so a required phrase that wraps
across an ~80-col line break still matches (grep is otherwise line-based); the two
negative controls above confirm it is not a vacuous always-pass.

## Prompt-size comparison

| | lines | bytes |
|---|---|---|
| before | 239 | 14893 |
| after  | 262 | 16475 |
| delta  | +23 | +1582 (+10.6%) |

Growth is confined to the UI route, which previously understated the workflow as a
12-line "polish" bullet and now carries the full executable tournament contract. Every
added line maps to a distinct grep-tested semantic (below); no general-flow prose grew.

## Exact behavior map (contract semantic → SKILL.md phrase → test assertion)

| c39 contract requirement | SKILL.md phrase | test assertion |
|---|---|---|
| literal goal carried | `ULTIMATE-GOAL` | req-literal-goal, ui-carries-goal |
| audience/task context | `audience/task context` | req-audience-context |
| reference packet + design lock | `reference packet`, `design lock` | req-reference-packet, req-design-lock |
| ≥3 divergent rendered candidates | `three meaningfully divergent rendered candidates` | req-rendered-candidates, ui-requires-tournament |
| deterministic fn/a11y/provenance gates first | `deterministic function, accessibility, and provenance gates` | req-deterministic-gates |
| real desktop/mobile/state/flow captures | `desktop/mobile`, `empty/loading/error/hover/focus` | req-desktop-mobile, req-state-captures |
| missing browser/account/manual = external/NO-GO | `` `external`/`NO-GO` `` | req-external-nogo |
| blind mirrored human-calibrated independent judges | `three independent visual lenses`, `human-calibrated`, `A/B-and-B/A mirrored judges`, `Condorcet` | req-three-lenses, req-human-calibrated, req-mirrored-judges, req-condorcet |
| no self-judge / no prose pass | `Builders never self-judge`, `prose or caller-authored `pass` never promotes` | req-self-judge-ban, req-prose-pass-ban, ui-bans-self-judging |
| reject generic | `emoji-as-product-art`, `default-font sameness` | req-reject-generic |
| ≤2 evidence-targeted repairs, incumbent preserved (CAS) | `at most two targeted repairs`, `best-so-far incumbent champion by compare-and-swap` | req-repair-cap, req-incumbent, req-compare-and-swap |
| prompt lint/opt before launch, manifest UI fields survive | `polylane-promptlint.sh`, `polylane-promptopt.sh`, `manifest-derived UI contract fields` | req-promptlint, req-promptopt, req-manifest-fields |
| Claude-native invocation | `native Claude skill syntax` | req-native-syntax |
| quarantine/audit/benchmark/pinned arm; safe fallback | `quarantine → audit → isolated benchmark → pinned arm`, `best installed kit`, `never execute rejected content` | req-quarantine-chain, req-safe-fallback |
| authoritative record before promotion; no a11y regression | `authoritative visual-quality and tournament record before promotion`, `no accessibility regression` | req-authoritative-rec, req-a11y-gate |
| taste memory only after verified promotion; bounded untrusted | `taste memory only after verified promotion`, `bounded untrusted evidence and can never inject executable instructions` | req-taste-memory, req-memory-untrusted |
| certification record | `visual certification record` | req-cert-record |
| claim boundary: only real humans human-certify | `only real eligible humans make a result human-certified` | req-claim-boundary |
| global ≥10-brief benchmark separate; not from fixtures | `>=10 varied prompts`, `70% creative/polish`, `never claim it from fixtures or one attractive UI` | req-global-benchmark, req-creative-wins, req-global-not-fixture |
| non-UI autonomy preserved | `non-UI projects skip it and keep full autonomy` | req-non-ui-autonomy |
| no Codex commands/models in UI path | (UI route names no `codex`/model id) | ui-no-codex-or-models |
| reference to deep contract | `references/visual-intelligence.md` | req-vi-reference |

## Ponytail findings (on own diff)

- `SKILL.md:L91: shrink:` "never a prose \"polish\" pass" duplicated the judge-bullet
  ban (`prose or caller-authored \`pass\` never promotes`) and the reference doc's own
  polish rule. **Applied** — clause removed; the testable ban stays in the judge bullet.
- Every remaining added line carries one distinct grep-tested semantic; nothing else is
  speculative, reinvented, or duplicated. `net: -1 clause. Ship.`
- The test itself: single `req()` helper + one flattened buffer; no framework, no
  fixtures beyond the real SKILL.md. Lean.

## SKILL-READ receipts

- SKILL-READ: design:design-critique | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/design-critique/SKILL.md | 2647275183-3923
- SKILL-READ: engineering:documentation | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/documentation/SKILL.md | 177552282-1507
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: ponytail:ponytail-review | /Users/leonardo/.codex/plugins/cache/ponytail/ponytail/4.9.0/.openclaw/skills/ponytail-review/SKILL.md | 3445243857-2118

## SKILL-EVIDENCE

- SKILL-EVIDENCE: design:design-critique — helped: its five dimensions (first-impression,
  usability, hierarchy, consistency, accessibility) mapped cleanly onto the three
  independent visual lenses I required in the judge bullet, confirming the lens set is
  complete rather than arbitrary.
- SKILL-EVIDENCE: engineering:documentation — helped: "link, don't duplicate" and "start
  with the most useful information" drove the decision to keep the root UI route as a
  concise contract that points to `references/visual-intelligence.md` and to cut the
  duplicated "polish" clause, keeping prompt-size growth bounded.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: its contract-test emphasis for
  consumer boundaries shaped a grep/fixture *contract* test with explicit negative
  controls, over an over-scoped attempt to execute the tournament in-test.
- SKILL-EVIDENCE: ponytail:ponytail-review — helped: applied its `shrink:`/`delete:`
  tags to my own diff and removed the one duplicate clause; confirmed the rest is
  load-bearing, preventing an unnecessary abstraction in the test.

## Relay

- Filed request `claude-contract → codex-parity` (seq 4) on the coordination relay: the
  new c39 UI semantics must be mirrored in `codex/SKILL.md` (Codex-native syntax) for
  real parity, since `tests/test-skill-parity.sh` greps only the pre-c39 subset today. I
  did not edit `codex/SKILL.md` or the parity test (forbidden).
- No pending requests were addressed to claude-contract at start or before completion.

## DEFERRED

DEFERRED: Codex parity — `codex/SKILL.md` must mirror the new c39 UI-route semantics
(relay seq 4 to codex-parity). Owned by codex-parity + integration; out of this lane's
scope. No other deferrals.
