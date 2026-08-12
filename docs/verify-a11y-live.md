# Verify — a11y-live lane (Cycle 40)

Live accessibility evidence runner + pinned engine. Automation here is **scoped
evidence, not a proof of accessibility for everyone**: an unavailable engine or a
rule the engine cannot measure stays UNKNOWN, and manual criteria stay EXTERNAL —
neither can ever become PASS.

## Owned files

| File | Role |
|---|---|
| `bin/polylane-taste-a11y-live.sh` | Trusted runner: pins the engine, binds inputs, recomputes the verdict, writes `taste-a11y-live-receipt/v1`. |
| `benchmarks/taste-live/tools/accessibility.mjs` | Pinned engine: one WCAG 2.1 AA automatable rule per criterion; emits per-criterion `result.json` + `receipt.json`, never a verdict. |
| `tests/test-taste-a11y-live.sh` | Adversarial acceptance: 46 assertions across 23 scenarios, browser-free. |
| `docs/verify-a11y-live.md` | This file. |
| `docs/status-a11y-live.md` | Lane status marker. |

Out of lane (consumed, never written here): the browser/capture adapter and the
task adapter own capture production and the `browser.adapter_receipt_sha256`; the
v1 validator, ballots, and certificate are untouched.

## Adapter / engine provenance (the pin)

The plan (`taste-a11y-live-plan/v1`) pins the engine by **package + version +
source path + source SHA-256**. The runner re-derives every leg and rejects any
drift:

- `source_path` must be a repo-relative regular file (no symlink component); its
  SHA-256 is recomputed and must equal `engine.source_sha256` — else `ENGINE_MISSING`
  / `ENGINE_MISMATCH`.
- The engine's own `result.json` must echo the pinned `engine_id`, `engine_package`,
  `engine_version`, and `engine_source_sha256` — else `ENGINE_IDENTITY_MISMATCH` /
  `ENGINE_SOURCE_MISMATCH`. (A build with a bumped `ENGINE_VERSION` is rejected even
  when everything else matches — test `engine_identity_mismatch`.)
- The engine `receipt.json` (`taste-live-engine-receipt/v1`) must bind the request
  digest and result digest and carry `executed_at` inside `[source-commit-time, now]`
  — else `STALE_RECEIPT`.

Current pinned engine: `engine_id=taste-live-a11y`,
`engine_package=polylane-taste-live-accessibility`, `engine_version=1.0.0`.

### Browser / capture / DOM / action binding

- `candidate_source_revision` (manifest) and `source_revision` (plan) must both equal
  `git HEAD` of the subject tree — else `STALE_SOURCE_REVISION`.
- For every capture, `dom_sha256` and `action_trace_sha256` are recomputed from the
  canonicalised (`jq -Sc`) payload and must match the declared digests — else
  `DOM_BINDING` / `ACTION_BINDING`. Result digests are re-bound to the manifest
  (`FORGED_CAPTURE`).
- Each capture's `captured_at` must sit inside `[source-commit-time, now]` — a capture
  older than the revision it claims, or dated in the future, is `STALE_CAPTURE`.
- The browser adapter receipt hash rides through as `browser.adapter_receipt_sha256`
  and is recorded in the receipt; a11y-live consumes it, the browser lane produces it.

## Status derivation (no caller pass)

The runner ignores any caller-authored verdict. It scans the engine output for a
smuggled verdict key with `any(paths; …)` (`CALLER_PASS`), then derives status only
from exact per-criterion outcomes and the scripted keyboard/reflow/motion checks:

```
veto (NEW_VIOLATION | REGRESSION | PREEXISTING_VIOLATION)  → FAIL
else evidence gap (any rule "skipped")                     → UNKNOWN
else manual_external_criteria present                      → EXTERNAL
else                                                       → PASS
```

Every check must carry non-empty `measured` evidence (`MISSING_MEASURED_EVIDENCE`);
the required-criteria matrix must be complete, unique, and free of unknown or
auto-scored-manual criteria (`COVERAGE_INCOMPLETE` / `DUPLICATE_CHECK` /
`UNKNOWN_CRITERION` / `MANUAL_AUTO_PASS`).

## Baseline regression + manual-exception boundary

- The baseline must be an eligible `taste-a11y-live-receipt/v1` of the **same
  evidence class** — a `production` baseline cannot gate a `fixture` study
  (`BASELINE_INELIGIBLE`).
- A failing criterion is classified against the baseline: no baseline →
  `NEW_VIOLATION`; baseline passed → `REGRESSION`; baseline failed → `PREEXISTING_VIOLATION`
  unless a matching scoped exception waives it (`ACCEPTED_EXCEPTION`). Any of the first
  three vetoes.
- A scoped exception needs a **frozen id, rationale, scope hash, reviewer boundary,
  and `created_at ≤ study_started_at`** (pre-registered before the study). An exception
  minted after the cutoff is `EXCEPTION_DRIFT`. Automation never approves an exception;
  it only honours a pre-frozen one.

## Positive / negative matrix (46 assertions, browser-free)

| # | Scenario | Input | Outcome |
|---|---|---|---|
| A | clean pass | all 15 measured, no gap/violation/manual | rc0 · PASS · `CLEAN` |
| B | **red→green** | broken engine build / same inputs on pinned engine | rc2 `ENGINE_FAILED` → rc0 PASS |
| C | evidence gap | reflow evidence absent (rule skipped) | rc0 · **UNKNOWN** · `EVIDENCE_GAP` |
| D | contrast violation | fg `#bbbbbb` on white, no baseline | rc0 · FAIL · `NEW_VIOLATION` |
| E | keyboard trap | `actions.trap=true` | rc0 · FAIL · `no-keyboard-trap` |
| F | lost focus | `focus_visible.go=false` | rc0 · FAIL · `focus-visible` |
| G | overflow | reflow horizontal scroll / content > viewport | rc0 · FAIL · `reflow-zoom-overflow` |
| H | contrast regression | baseline pass → challenger fail | rc0 · FAIL · `REGRESSION` |
| I | target regression | baseline pass → 20×20 target | rc0 · FAIL · `REGRESSION` |
| J | motion regression | baseline pass → reduced-motion not respected | rc0 · FAIL · `REGRESSION` |
| K | pre-existing violation | baseline fail, no exception | rc0 · FAIL · `PREEXISTING_VIOLATION` |
| L | accepted exception | baseline fail + pre-study frozen exception | rc0 · **PASS** · `ACCEPTED_EXCEPTION` |
| M | exception drift | exception `created_at` after study cutoff | rc2 · `EXCEPTION_DRIFT` |
| N | caller pass | `measured.verdict="pass"` smuggled (nested) | rc2 · `CALLER_PASS` |
| O | forged capture | DOM tampered after digest fixed | rc2 · `DOM_BINDING` |
| P | stale capture | `captured_at` before the source revision | rc2 · `STALE_CAPTURE` |
| Q | partial matrix (captures) | engine drops a capture | rc2 · `MATRIX_MISMATCH` |
| R | partial matrix (criteria) | engine drops a required check | rc2 · `COVERAGE_INCOMPLETE` |
| S | missing engine | pinned `source_path` absent | rc2 · `ENGINE_MISSING` |
| T | engine identity | different-version build executed | rc2 · `ENGINE_IDENTITY_MISMATCH` |
| U | manual review | `manual_external_criteria` present, clean otherwise | rc0 · **EXTERNAL** · `MANUAL_EXTERNAL` |
| V | ineligible baseline | production baseline vs fixture study | rc2 · `BASELINE_INELIGIBLE` |
| W | stale receipt | engine `executed_at` outside run window | rc2 · `STALE_RECEIPT` |

### Baseline-regression proof (H)

Baseline receipt marks `contrast` as `pass` at `/ · default · desktop`; the
challenger's bound DOM measures the same key as `fail`. The runner keys both on
`route+state+viewport+criterion`, classifies `REGRESSION`, vetoes → `FAIL`, and lists
the offending criterion under `.regressions`. Cases I/J repeat the proof for
`target-size` and `reduced-motion`; K/L show the pre-existing-vs-waived split.

### Missing-manual-evidence behavior (C, U)

Two distinct "we cannot prove this" outcomes, neither a PASS:

- **Automatable rule unmeasurable** (missing reflow/action/DOM evidence, or an
  unavailable engine): rule returns `skipped` → `EVIDENCE_GAP` → **UNKNOWN** (C). A
  wholly unavailable engine fails closed at rc2 (`ENGINE_FAILED`/`ENGINE_MISSING`, B/S)
  — still never a PASS.
- **Manual criterion required** (screen reader, cognitive, localization-rtl): never
  auto-scored → **EXTERNAL** (U). Human judgement stays outside this automation.

## Red-first evidence

```
# broken engine build (historical run() ReferenceError):
$ node broken-engine.mjs  → ReferenceError: resText is not defined  (exit 1)
  runner → rc2 TASTE-A11Y-LIVE: ENGINE_FAILED         # red_first_broken_engine
# same inputs, pinned engine:
  runner → rc0 TASTE-A11Y-LIVE: PASS                  # red_first_pinned_green
```
The engine bug (`void resText;` after the receipt write) was live before this cycle;
removing it turns the clean path green. The CALLER_PASS guard was also hardened from a
`paths | jq -e` stream test (which only inspects the *last* emitted value) to
`any(paths; …)`, so a verdict key nested anywhere is caught (case N).

## Test outputs

```
$ bash tests/test-taste-a11y-live.sh
test-taste-a11y-live.sh: 46 pass, 0 fail
$ node benchmarks/taste-live/tools/accessibility.mjs --selfcheck
SELFCHECK OK: contrast math + rule outcomes + skip-on-missing-evidence
$ bin/polylane-check.sh .polylane/check-cache/a11y-live -- \
    shellcheck -S warning bin/polylane-taste-a11y-live.sh tests/test-taste-a11y-live.sh
CHECK-CACHE: PASS   # rc 0, no warnings
```

## Claim boundary (what is NOT proven here)

- Automated checks cannot claim accessibility for everyone. A PASS means: the 15
  automatable WCAG 2.1 AA criteria measured clean on every captured state, with no
  regression against an eligible baseline. It says nothing about screen-reader
  usability, cognitive load, or localization/RTL — those are EXTERNAL by design.
- Evidence quality is only as good as the capture. The runner binds digests and
  timing but trusts the browser/task adapters (owned elsewhere) to have produced
  faithful DOM/action traces; it verifies provenance, not physical rendering.
- A green run is scoped to one `source_revision`, one engine pin, and one capture
  matrix. It is not a standing certification.

## Skill receipts

- SKILL-READ: design:accessibility-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/accessibility-review/SKILL.md | 2943520804-4278
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

- SKILL-EVIDENCE: design:accessibility-review — helped: its WCAG 2.1 AA criterion set
  (1.4.3/1.4.11 contrast, 2.1.1 keyboard, 2.4.3/2.4.7 focus order/visible, 2.5.5 target
  size, 4.1.2 name/role/value) grounded the 15 automatable rule ids and, crucially, its
  "automated scan catches ~30%" note plus the screen-reader/manual line justified the
  EXTERNAL/UNKNOWN boundary — automation as scoped evidence, not proof.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: its "cover error handling,
  edge cases, security boundaries; identify gaps" framing shaped the red-first negative
  matrix — every trust boundary (forged pass, stale capture, exception drift, partial
  matrix, engine identity/receipt) has a dedicated adversarial case rather than only the
  happy path.
