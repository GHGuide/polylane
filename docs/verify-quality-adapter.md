# Verify — quality-adapter (Cycle 39, run c39-visual-loop-20260812-a1)

Lane owns: `bin/polylane-visual-quality.sh`, `tests/test-visual-quality.sh`,
`docs/verify-quality-adapter.md`, `docs/status-quality-adapter.md`.

## What changed

Added an authoritative `certify PROJECT_ROOT RECORD_JSON VERDICT_JSON [ATTEMPT]`
mode to `polylane-visual-quality.sh`. It derives a `visual-quality-verdict/v2`
solely from hash-bound producer receipts and a real capture verification. The
legacy `run` (per-surface lens verdict) and `benchmark` (old-vs-new corpus)
modes are byte-for-byte unchanged; legacy self-authored lens statuses are never
consulted by `certify`.

`certify` binds, in one record (`visual-quality-record/v2`): run id, literal-goal
/ packet / design-lock hashes, tournament input+receipt paths and hashes, the
selected candidate id and source revision, the verified capture manifest, the
function/accessibility hard-gate receipt, the threat receipt, the repair ledger,
the incumbent/champion decision, and an optional taste-memory proposal. Strict
key allow-lists reject unknown or duplicate keys, so a caller `status`/`winner`/
`pass`/prose field is a hard `RECORD_INVALID` block rather than a pass.

## Trust boundary — how each helper is used

| Helper | Cycle | Use | Rationale |
|---|---|---|---|
| `polylane-taste-pixels.sh verify` | 38 | **Invoked** on the selected candidate's capture manifest against the real git `PROJECT_ROOT`. | Decoded-pixel evidence must be produced by the pinned decoder, not asserted; adapter absence is `external`, tamper is `blocked`, never a pass. |
| `taste-hard-gate/v1` predicate | 38 | **Strictly validated** (same predicate as `polylane-taste.sh`). | Function + accessibility + state coverage are non-compensatory vetoes. |
| `taste-threat-receipt/v1` predicate | 38 | **Strictly validated** (same predicate as `polylane-taste.sh`). | Injection / provenance / generic-review are hard vetoes; generic motifs stay a risk signal, never attribution. |
| `taste-repair-ledger/v1` | 38 | **Strictly validated + hash surfaced**. | Durable two-token repair budget binding. |
| `taste-tournament-receipt/v1` | 39 | **Strictly validated + hash bound**; the Condorcet winner is **re-derived**, never read from a caller field. | The Cycle-39 tournament helper binary is owned by tournament-engine and is not present in this lane's tree; the receipt is validated by strict schema + SHA-256 binding, and human certification can never be minted from it (see external limits). |

`polylane-taste.sh` (the corpus-level `HUMAN_CERTIFIED` compiler) is deliberately
**not** invoked: the local tournament emits only `SELECTED_NOT_CERTIFIED`, and
`human_claim` is hard-coded `false`. A real human panel / live site / champion
claim remains `external`/`blocked` from fixtures.

## Compatibility proof (old-mode)

Legacy callers of `run` and `benchmark` keep their exact contract:

```
PASS visual-quality-all-lenses-must-pass
PASS visual-quality-writes-promotion-verdict
PASS visual-quality-rejects-nonimage-evidence
PASS visual-quality-rejects-non-anonymized-evidence
PASS visual-benchmark-requires-seventy-percent-decisive-wins
PASS visual-benchmark-rejects-tradeoff-that-loses-polish
PASS visual-benchmark-rejects-accessibility-regression
```

The `run`/`benchmark` functions and their `schema:1` verdict output are
untouched; `certify` is additive (new `main` case + isolated `cq_*` functions).

## Attack matrix (adversarial acceptance)

| Attack | Injection point | Derived status | Reason code | Test |
|---|---|---|---|---|
| Old-mode compatibility | legacy `run`/`benchmark` | passed/blocked as before | (schema:1) | 7 legacy PASS rows above |
| v2 missing pixel receipt | `capture_manifest` → nonexistent | `blocked` | `CAPTURE_MANIFEST_INVALID` | certify-missing-capture-receipt-blocks |
| Prose-as-proof | extra `verdict:"…pass"` key | `blocked` | `RECORD_INVALID` | certify-prose-field-rejected |
| Caller winner | `selected_candidate_id`≠derived Condorcet | `blocked` | `CALLER_WINNER_MISMATCH` | certify-caller-winner-reason |
| Hash mismatch | `tournament.receipt_sha256` forged | `blocked` | `TOURNAMENT_RECEIPT_INVALID` | certify-hash-mismatch-reason |
| Weak judge | judge `calibration!="eligible"` in a deciding exposure | `blocked` | `WEAK_JUDGE` | certify-weak-judge-reason |
| Accessibility regression | hard-gate `accessibility[].status="fail"` | `blocked` | `ACCESSIBILITY_VETO` | certify-accessibility-veto-reason |
| Missing state | capture matrix drops a required state | `blocked` | `MISSING_STATE:<state>` | certify-missing-state-reason |
| Prompt injection | threat receipt `status!="clean"` | `blocked` | `PROVENANCE_VETO` | certify-injection-reason |
| Safe external status | decoder adapter path missing | `external` | `PIXELS_DECODER_UNAVAILABLE` | certify-missing-adapter-is-external |
| Unchanged repair | attempt 1, `repair.changed=false` | `halted` | `REPAIR_UNCHANGED` | certify-unchanged-repair-reason |
| Third repair | attempt 3 | `halted` | `REPAIR_BUDGET_EXHAUSTED` | certify-third-repair-reason |
| Positive authoritative record | full valid chain, real captures | `passed` | (none) | certify-accepts-authoritative-record |

Bonus green: a grounded, evidence-changed repair with an open finding at
attempt 1 → `repair` with a grounded `repair_targets[0]` (certify-grounded-repair).

## Reason-code table

| Code | Status | Meaning |
|---|---|---|
| `RECORD_INVALID` | blocked | Record fails the strict `visual-quality-record/v2` shape (unknown/duplicate key, bad hash, over-shape). |
| `CAPTURE_MANIFEST_INVALID` | blocked | Capture manifest not a safe `taste-capture-manifest/v1` file. |
| `MISSING_STATE:<s>` / `LOCK_MISSING_STATE:<s>` / `MISSING_VIEWPORT` | blocked | Declared desktop/mobile × default/empty/error/focus/hover/loading coverage incomplete. |
| `SELECTION_REVISION_MISMATCH` | blocked | Selected source revision ≠ captured candidate revision. |
| `PIXELS_<reason>` | external* / blocked | Real capture verification failed; `DECODER/JQ/SHA256/SOURCE_*/MANIFEST_UNAVAILABLE` → external, all else → blocked. |
| `TOURNAMENT_RECEIPT_INVALID` | blocked | Tournament receipt unsafe path / wrong schema / **hash mismatch**. |
| `TOURNAMENT_SCHEMA_INVALID` / `TOURNAMENT_PAIR_MISMATCH` | blocked | Not exactly 3 candidates / 3 pairs, or a pair winner not in its pair. |
| `WEAK_JUDGE` | blocked | A deciding exposure judge is not calibration-eligible, or a mirror is one-sided. |
| `TOURNAMENT_INDECISIVE` | blocked | No unique Condorcet winner (tie/cycle) → preserve incumbent. |
| `CALLER_WINNER_MISMATCH` | blocked | Record's selected candidate ≠ re-derived winner. |
| `HARD_GATE_INVALID` / `HARD_GATE_NOT_PASS` / `HARD_GATE_CANDIDATE_MISMATCH` | blocked | Function/a11y/state receipt malformed, not `PASS`, or wrong candidate. |
| `FUNCTION_VETO` / `ACCESSIBILITY_VETO` / `STATE_COVERAGE_VETO` | blocked | A hard non-compensatory gate failed. |
| `THREAT_RECEIPT_INVALID` / `PROVENANCE_VETO` | blocked | Threat receipt malformed or not clean (injection / attribution / generic-review). |
| `REPAIR_LEDGER_INVALID` | blocked | Repair ledger not a valid `taste-repair-ledger/v1`. |
| `CHAMPION_CAS_MISSING` / `CHAMPION_INCONSISTENT` | blocked | Incumbent without CAS previous pointer, or decision ≠ derived. |
| `REPAIR_UNGROUNDED` / `REPAIR_UNCHANGED` | halted | Repair without a bound change, or evidence not actually moved. |
| `REPAIR_BUDGET_EXHAUSTED` | halted | Third attempt, or open finding after the two-token budget. |

\* external is chosen over blocked only for adapter/environment absence, never
for tamper — "missing external browser evidence is blocked/external, never pass."

## Command outputs

```
### tests/test-visual-quality.sh
test-visual-quality.sh: 37 pass, 0 fail

### shellcheck -S warning bin/polylane-visual-quality.sh
(clean, exit 0)

### git diff --check
(no whitespace errors, exit 0)
```

## Separated dimensions (unchanged intent)

Product fit, hierarchy, typography, color, spatial rhythm, craftsmanship,
originality, state coherence, assets/copy, and accessibility remain distinct.
Mechanical generic-pattern flags (`generic_pattern_signals`) are surfaced as
risk/context signals in the verdict and **never** veto or attribute AI/copying.

## Skill receipts

SKILL-READ: design:accessibility-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/accessibility-review/SKILL.md | 2943520804-4278
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the red/green loop caught two silent jq defects in the tournament validator (`index(.judge_id)` evaluating against the array, and `reduce … as $wins` needing parentheses) that made the positive record wrongly `blocked` with `WEAK_JUDGE`/`TOURNAMENT_INDECISIVE`; without watching the positive assertion fail first those would have shipped as a false hard-block. Deviation noted honestly: the implementation file was authored just before the test file rather than strictly test-first, but no completion was claimed until red was observed and driven to green.
SKILL-EVIDENCE: engineering:testing-strategy — helped: framed the adversarial matrix as the "security boundaries + edge cases" layer (contract tests over receipt schemas) rather than adding unit tests for trivial helpers, keeping the suite to 37 behavior-level cases with one real end-to-end capture fixture.
SKILL-EVIDENCE: design:accessibility-review — helped: confirmed the accessibility dimension is the WCAG 2.1 AA set (contrast 1.4.3/1.4.11, keyboard 2.1.1, focus 2.4.3/2.4.7, target 2.5.5, reflow, name/role/value 4.1.2) and that these are non-compensatory, justifying `ACCESSIBILITY_VETO` as a hard block no taste vote can offset.
SKILL-EVIDENCE: operations:risk-assessment — helped: reinforced treating `generic_pattern_signals` as likelihood/impact risk-context signals in the verdict, explicitly not an AI/copying attribution, matching the hard contract.

## Relay handled (run c39-visual-loop-20260812-a1)

- **runner-wiring seq1** → answered with COUNTER: canonical CLI stays `certify
  PROJECT_ROOT RECORD_JSON VERDICT_JSON [ATTEMPT]` (v2 verdict, exit 0 iff
  passed). Offered an additive `authoritative --manifest/--worktree/--record/
  --attempt` alias mapping status pass|repair|block and exit 0/10/other, pending
  their confirm on `.promoted_receipt_sha256` and `.artifact_sha256[]` meaning.
- **a11y-evidence seq12** → CONFIRMED: accessibility is a hard non-compensatory
  veto; will consume `taste-a11y-receipt/v1 .derived_status`/`.regressions[]`.
  Standalone-a11y-receipt vs folded hard-gate reconciliation is integrator-owned.

## DEFERRED

DEFERRED: authoritative-alias-wire — the runner-wiring `authoritative` subcommand
surface (top-level `.status`/`.record_sha256`/`.promoted_receipt_sha256`/
`.repair`/`.artifact_sha256[]` fields and exit codes 0/10/other) is proposed but
not yet confirmed by runner-wiring; the integrator reconciles the final consumer
wire. The canonical `certify` mode and this lane's frozen tests are complete and
green regardless.
