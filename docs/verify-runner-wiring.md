# verify-runner-wiring — Cycle 39 (run c39-visual-loop-20260812-a1)

Lane **runner-wiring**. Wires the authoritative visual tournament/certificate
record into runner preflight, bounded repair, promotion, and post-promotion
taste learning — without regressing legacy or non-UI runs.

Owned files only: `bin/polylane-run.sh`, `tests/test-taste-runner-gate.sh`,
`docs/verify-runner-wiring.md`, `docs/status-runner-wiring.md`.

## What changed

New, source-testable functions in `bin/polylane-run.sh` (grouped after
`visual_quality_gate`), all gated on explicit current-UI classification so
legacy/non-UI runs are byte-for-byte unchanged:

- `visual_contract_current_version` / `visual_contract_current_requested` —
  a run is "current UI" iff the manifest **explicitly** declares
  `.visual_quality.contract_version` equal to the runner's enforced constant
  (`POLYLANE_VISUAL_CONTRACT_VERSION`, default `v2`). No date/filename inference.
- `visual_taste_authority_cmd` / `visual_taste_memory_cmd` /
  `visual_taste_prompt_ui_version` — overridable seams to the quality-adapter
  authoritative helper, the taste-memory helper, and prompt-contract's
  `promptopt.sh ui-version` reader. The runner never re-derives their schemas.
- `visual_taste_preflight` — runs **before any worktree/tmux side effect**;
  fails closed on missing authoritative record/tournament/memory config, missing
  adapter declarations, a repair cap outside `0..2`, an unsafe (absolute or
  `..`) declared path, a non-executable helper, or a compiled-prompt UI-CONTRACT
  token that disagrees with the manifest version.
- `visual_taste_repair_dispatch` — writes **only** grounded
  `criterion/region/state/prior_evidence_sha256/incumbent_id/attempt` and routes
  them through the existing `repair_integrator_verdict … visual` path. No
  evidence, screenshot, lens, or prose reaches the builder.
- `visual_taste_authoritative_gate` — after engineering GO/READY, before
  promotion: calls the authoritative mode against the integrator worktree
  regardless of the integrator's prose verdict; PASS records the promoted receipt
  hash; actionable repair (exit 10) drives at most `repair_cap` (≤2) grounded
  repairs, **requires the record and artifact hashes to change** before
  re-evaluation, and preserves the attempt count durably
  (`.polylane/visual-taste/<run>.attempt`) across supervisor resumes; block /
  missing record / unchanged repair / exhausted budget all block promotion.
- `visual_taste_memory_record` — updates project taste memory **only** after a
  verified promotion (`PROMOTION_STATE=promoted`) and **only** from the exact
  promoted record + receipt hash; a helper failure is visible and fails closed;
  never learns from NO-GO/repair/unpromoted/prose/legacy runs.

Three minimal `main` insertions, each guarded by `visual_contract_current_*`:
`visual_taste_preflight` after `preflight_contract` (pre-side-effect);
`visual_taste_authoritative_gate` as the current-UI branch of the post-GO visual
boundary (legacy `visual_quality_gate` preserved verbatim in the `elif`); and
`visual_taste_memory_record` after `promote_to_main` + `finalize_cycle_state`.

## Lifecycle sequence (current-UI run)

```
parse_args → load_manifest → preflight_contract
  → visual_taste_preflight            [FAIL-CLOSED before any worktree/tmux]
  → split_worktrees → launch_panes → builders → integrator
  → gate_with_repairs                 [engineering GO / READY-FOR-HOST-GATE]
  → visual_taste_authoritative_gate   [host gate; prose GO cannot bypass]
        PASS ─────────────► record promoted receipt hash
        REPAIR(exit10) ──► grounded repair (≤2, durable, hash-must-change) ─┐
        BLOCK/unchanged/exhausted ─► halt, nothing merged                   │
        ◄──────────────────────────────────────────────────────────────────┘
  → promote_to_main → finalize_cycle_state
  → visual_taste_memory_record        [only now, from the promoted receipt]
  → cleanup → report
```

Non-UI runs skip every `visual_taste_*` step (predicate false). Legacy visual
runs take the unchanged `visual_quality_gate` `elif` branch and never touch the
authoritative gate, durable attempt state, or taste memory.

## Compatibility table

| Behavior | Non-UI | Legacy `visual_quality` | Current UI (`contract_version`) |
|---|---|---|---|
| `visual_contract_current_requested` | false | false | true |
| `visual_quality_requested` (legacy) | false | true (unchanged) | true, but current branch wins |
| Preflight | no-op | no-op | validates, fails closed |
| Post-GO visual gate | none | `visual_quality_gate` (unchanged) | `visual_taste_authoritative_gate` |
| Bounded repair route | n/a | existing visual repair | grounded-only, ≤2, durable |
| Taste memory | never | never | only after verified promotion |

## Command outputs

`bash tests/test-taste-runner-gate.sh` → **43 pass, 0 fail** (covers: non-UI
unchanged; legacy unchanged; current-UI preflight rejects missing/unsafe config
before side effects; v2 helper called at the integrator-worktree boundary; prose
GO cannot bypass; safe PASS promotes + captures receipt; repair receives exactly
the grounded fields and no evidence; unchanged repair blocks; third repair
blocks; resume preserves the durable attempt; memory records only after
promotion; memory never records on non-promoted/NO-GO/legacy; memory fails closed
on helper error).

RED was observed first: with the functions absent the run reported **20 pass, 22
fail** (all new-function behaviors `command not found`), then **43/0** after the
GREEN implementation.

Runner-focused regression group (all 0 fail):

```
test-visual-quality            7 pass
test-visual-loop-integration  28 pass
test-visual-intelligence       9 pass
test-visual-capture           19 pass
test-promote                   4 pass
test-verify-gate               6 pass
test-advanced-runtime         24 pass
test-graph-authority          56 pass
test-session-resume            8 pass
test-runtime-recovery         26 pass
```

`shellcheck -S warning bin/polylane-run.sh` → PASS (via
`bin/polylane-check.sh … --`). `bash -n bin/polylane-run.sh` → ok.
`git diff --check` → clean.

## Cross-lane seams (relay)

Requested exact interfaces (relay seq1–3) and handled the two requests addressed
to runner-wiring:

- prompt-contract **confirmed** (seq5) the prompt/manifest agreement mechanism —
  exact-once `UI-CONTRACT:` scalar with an `ui_contract=` token, read via
  `polylane-promptopt.sh ui-version` (grep fallback), compared to manifest
  `.visual_quality.contract_version`. Implementation aligned; ACK posted.
- a11y-evidence (seq14): no runner change — the runner routes a11y/hard gates
  through the authoritative visual-quality mode (quality-adapter), never calling
  `polylane-taste-a11y.sh` directly. ACK posted.

quality-adapter **agreed** (seq15): its canonical CLI is positional
`certify PROJECT_ROOT RECORD_JSON VERDICT_JSON [ATTEMPT]`, and it will add the
`authoritative --manifest M --worktree WT --record OUT --attempt N` alias
matching the runner's call exactly (exit 0=pass/10=repair/other=block; top-level
`.status`/`.record_sha256`/`.repair.*`, plus `.promoted_receipt_sha256` = sha256
of the written v2 verdict on pass and `.artifact_sha256[]` = the capture
manifest decoded-pixel digests — both confirmed by runner-wiring). No runner
change was needed; the existing invocation already matches.

The taste-memory `record` subcommand is **not yet confirmed** on the relay. Both
helpers stay behind overridable command variables
(`POLYLANE_VISUAL_AUTHORITY_CMD`, `POLYLANE_TASTE_MEMORY_CMD`) so only the two
dispatch call-sites change if a frozen interface differs, and the sourced tests
prove behavior with hermetic doubles.

## Skill receipts

SKILL-READ: engineering:architecture | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/architecture/SKILL.md | 2056343451-2410
SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:test-driven-development — helped: wrote the 43-assertion sourced test first and watched 22 fail before any implementation; the RED run forced the grounded-data-only repair packet and the durable-attempt/resume semantics to be pinned by assertion rather than assumed.
SKILL-EVIDENCE: engineering:architecture — helped: framed the seam as an ADR-style decision (thin overridable helper-command boundary vs. re-implementing tournament/certificate schema in the runner) and chose the boundary that keeps the runner ignorant of helper schemas, satisfying "do not duplicate the helper's schema logic".
SKILL-EVIDENCE: operations:risk-assessment — helped: enumerated the fail-closed risks (missing authoritative config, unsafe paths, prose-GO bypass, unchanged/exhausted repair, learning from an unpromoted candidate) and turned each into a blocking gate with a dedicated test.
SKILL-EVIDENCE: engineering:debug — unused: this was greenfield wiring with no reproduce→isolate→diagnose defect cycle; the RED→GREEN TDD loop covered the one failure surface (missing functions).

## DEFERRED

- quality-adapter authoritative-mode CLI — **agreed on the relay** (seq15): the
  `authoritative` alias with exit 0/10/other and the top-level
  `status`/`record_sha256`/`promoted_receipt_sha256`/`repair.*`/`artifact_sha256[]`
  fields matches the runner's call; quality-adapter ships the alias, no runner
  change. Tracked only until the alias lands in the integrated tree.
- taste-memory `record --manifest … --record … --receipt-sha256 …` CLI —
  requested (relay seq2), **not yet confirmed**. Isolated behind
  `POLYLANE_TASTE_MEMORY_CMD`.
- exact enforced current-version literal (`v1` vs `v2`) — asked prompt-contract/
  planner to confirm the stamped value; runner uses the overridable constant
  `POLYLANE_VISUAL_CONTRACT_VERSION` (default `v2`) so aligning is a one-line
  change with zero code churn.

DEFERRED: cross-lane seams remain open — the taste-memory `record` CLI and the
enforced current-version literal are still unconfirmed, and quality-adapter's
agreed `authoritative` alias is pending its merge. All are isolated behind runner
override points and proven with hermetic doubles, so the integrator can merge and
reconcile without runner logic changes.
