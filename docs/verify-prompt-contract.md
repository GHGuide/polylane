# verify — prompt-contract (Cycle 39, run c39-visual-loop-20260812-a1)

Goal: optimized UI builder prompts mechanically preserve every manifest-derived
visual scalar and provider boundary — a UI block cannot be deleted, weakened,
duplicated, or self-certified while the compiled prompt stays contract-equivalent.

## What changed

- `bin/polylane-promptopt.sh`
  - `scalar_label`: the five UI scalars `UI-CONTRACT`, `UI-IMPLEMENT`,
    `UI-CONTENT`, `UI-EVIDENCE`, `UI-REVIEW-BOUNDARY` are now first-class
    exact-once scalars. This makes `validate_scalars` reject duplicate/conflicting
    UI labels and makes `contract_values`/`compare` **lose** if any UI scalar is
    stripped or its value changed.
  - `validate_ui_profile` (new, called from `strict_blocks`, so it runs inside
    `compile`, `check`, and `compare`): if the prompt carries *any* UI scalar it
    must carry *all five*. It validates `mode=ui`, a versioned `ui_contract=v<n>`,
    64-hex `ref_packet_sha256`/`design_lock_sha256`, `goal_sha256`/`subgoal_sha256`
    that bind the GOAL/CURRENT-SUBGOAL scalars (goal equality), safe repo-relative
    `capture_matrix`/`tournament` paths, a bounded `repair_attempt` (0–2), an
    opaque `incumbent` id, and a coordinator-owned review boundary that forbids
    builder self-certification. Prompts with no UI scalar skip this entirely.
- `bin/polylane-promptlint.sh`
  - `lint_one` signature extended: `f lane prime role agent ui_contract`
    (both new args optional → backward compatible; `agent` also from
    `$POLYLANE_LINT_AGENT`). A UI lane (`ui=1`) must carry all five UI scalars and
    keep the verdict with the coordinator; a builder-owned verdict is rejected on
    any lane.
  - `provider_syntax_leakage`: compiled Codex prompts may not carry `/model`,
    `ultrathink`, a Claude model id, or a `CLAUDE.md` memory assumption; compiled
    Claude prompts may not carry Codex-only launch syntax (`codex exec`,
    `--dangerously-bypass-approvals`, `--sandbox`, `codex_sandbox`).
  - `exact_once_labels`: UI scalars added to the strict exact-once set.
  - `lint_run`: derives the agent from `manifest.agent` and classifies each lane
    UI **only** from `surface:"ui"` + a versioned `ui_contract` — never from
    prompt keywords or filenames — then passes both into `lint_one`.

## Frozen scalars (exact-once, comparison-losing if stripped/changed)

Base contract: `ULTIMATE-GOAL`, `CURRENT-SUBGOAL`, `GOAL`, `OWN`, `FORBIDDEN`,
`PREDEFINED-SKILLS`, `LANE-SPECIFIC-SKILLS`, `TEST-CADENCE`, `DELEGATION`,
`CHECK-CACHE`, `EXTERNAL-EVIDENCE`, `VERIFY`, plus the `selected-kit` and
`nonce-done-marker` presence contracts.

UI profile (only on `surface:"ui"` lanes, all-or-nothing):
`UI-CONTRACT`, `UI-IMPLEMENT`, `UI-CONTENT`, `UI-EVIDENCE`, `UI-REVIEW-BOUNDARY`.

## Before/after compiled metrics (conservative local estimate, not provider billing)

| Prompt | source bytes | compiled bytes | UI scalars in compiled |
|---|---|---|---|
| non-UI (valid-source) | 991 | 957 | 0 (backward compatible) |
| UI (valid-source + UI profile) | 1962 | 1928 | 5 (all preserved) |

Compilation only collapses byte-identical ordinary prose; every frozen scalar,
including all five UI scalars, survives and the pre/post frozen-contract
comparison passes.

## Test outputs

```
$ bash tests/test-prompt-compiler.sh
test-prompt-compiler.sh: 34 pass, 0 fail
$ bash tests/test-promptlint.sh
test-promptlint.sh: 54 pass, 0 fail
$ shellcheck -S warning bin/polylane-promptlint.sh bin/polylane-promptopt.sh
(rc=0, no findings)
$ git diff --check
(rc=0, no whitespace errors)
```

New cases cover: missing/dropped UI scalar, duplicate UI scalar, conflicting
scalar, placeholder/stale hash, unsafe path, goal mismatch, builder-owned
verdict, stripped/weakened visual block (compare loses), provider syntax leakage
(both directions), compiled normalized parity (UI scalars are provider-blind),
manifest-derived lint-run UI classification, and non-UI backward compatibility.

## Skill receipts

- SKILL-READ: engineering:architecture | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/architecture/SKILL.md | 2056343451-2410
- SKILL-READ: engineering:documentation | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/documentation/SKILL.md | 177552282-1507
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

- SKILL-EVIDENCE: engineering:architecture — helped: drove the all-or-nothing
  boundary decision — detect the UI profile by the presence of *any* UI scalar,
  then require all five, so dropping the `UI-CONTRACT` header itself still fails
  rather than silently declassifying the lane.
- SKILL-EVIDENCE: engineering:documentation — helped: shaped this doc for the
  integrator/reviewer audience (show-don't-tell metrics table + explicit
  frozen-scalar list over prose).
- SKILL-EVIDENCE: engineering:testing-strategy — helped: chose contract/boundary
  tests (security boundary, data integrity, error paths) over trivial coverage;
  UI grammar validated structurally, provider parity as a contract test.
- SKILL-EVIDENCE: superpowers:test-driven-development — helped: fixtures and
  assertions were written first and watched fail (11 compiler + 13 lint red)
  before any implementation, then driven to green.

## Integration note (for runner-wiring / integrator)

`lint_one`'s new `agent`/`ui_contract` args are optional and default to
`claude`/`0`, so the runner's existing `polylane-promptlint.sh lint "$compiled"
"$name" "$prime" "$role"` call keeps working unchanged. To activate provider
parity and per-lane UI enforcement at launch, the runner passes the manifest
agent and the lane's UI flag as positions 5 and 6 (or sets `POLYLANE_LINT_AGENT`).
`lint-run` already derives both from the manifest, so full-manifest linting needs
no runner change.

## DEFERRED

DEFERRED: none
