# Verify — a11y-evidence lane (Cycle 39)

Trusted accessibility evidence runner. Owns only:

- `bin/polylane-taste-a11y.sh` — the runner (new, isolated helper).
- `tests/test-taste-a11y.sh` — adversarial acceptance suite (new).
- `docs/verify-a11y-evidence.md`, `docs/status-a11y-evidence.md`.

No existing helper/test/reference/skill/installer/manifest/status file was touched.

## What it does

`audit PROJECT_ROOT CAPTURE_MANIFEST A11Y_PLAN RECEIPT -- ADAPTER [args...]`

The runner consumes a verified `taste-capture-manifest/v1` and a coordinator-pinned
accessibility adapter, invokes the adapter once (env `POLYLANE_A11Y_REQUEST` +
`POLYLANE_A11Y_OUTPUT`), then **recomputes** a `PASS/FAIL/EXTERNAL` verdict from
exact per-capture/per-criterion results and emits a `taste-a11y-receipt/v1`
atomically. It never trusts a caller-authored pass boolean: every pass/fail check
must carry non-empty `measured` evidence, and any top-level verdict-shaped key in
the adapter output is rejected (`CALLER_PASS`).

Main is `BASH_SOURCE`-guarded; the receipt is written to a sibling temp file and
`mv`d into place (atomic). Bash 3.2 + jq only; the browser/AT work lives behind the
declared adapter boundary.

## Emitted schema — `taste-a11y-receipt/v1`

```
{schema_version, candidate_id, source_revision, design_lock_sha256, evidence_class,
 adapter:{adapter_id,adapter_version,command_sha256,profile_sha256},
 input_sha256:{capture_manifest,a11y_plan,adapter_result,baseline_receipt},
 coverage:{required_criteria:[...],captures:N,checks:M},
 results:[{capture_id,route,state,viewport,criterion,check_id,region,status,measured}...],
 violations:[{...,reason_code}], regressions:[{...}],
 accepted_exceptions:[{capture_id,criterion,scope_sha256,reason,manual_owner}],
 manual_external:[criterion...], derived_status:"PASS|FAIL|EXTERNAL",
 reason_codes:[...], generated_at}
```

Consumers (capture/certificate/quality/runner lanes) read `derived_status`,
`reason_codes`, `regressions`, `accepted_exceptions`, and `manual_external`. Exit is
`0` whenever a trustworthy receipt is emitted (including a `FAIL` verdict — a `FAIL`
receipt is evidence); exit `2` only when the inputs cannot be trusted (no receipt).

## Criterion coverage (automatable)

Full canonical set audited on **every** capture/state (status may be
`not-applicable`, never absent) — WCAG 2.1 AA mapping:

| criterion id | WCAG | covers |
|---|---|---|
| semantics-name-role-value | 4.1.2 | name/role/value, duplicate id |
| labels-instructions | 3.3.2 | form labels/instructions |
| error-identification | 3.3.1 | error text present & described |
| heading-landmark-structure | 1.3.1 | heading/landmark structure |
| keyboard-reachable | 2.1.1 | every control reachable |
| focus-order | 2.4.3 | logical focus order |
| no-keyboard-trap | 2.1.2 | no keyboard trap |
| keyboard-escape | 2.1.2 | escape closes overlays |
| focus-visible | 2.4.7 | visible focus indicator |
| target-size | 2.5.5 | ≥44×44 target size |
| contrast | 1.4.3 / 1.4.11 | text & non-text contrast |
| non-color-state | 1.4.1 | state not by color alone |
| reflow-zoom-overflow | 1.4.10 / 1.4.4 | reflow/zoom/overflow |
| reduced-motion | 2.3.3 / 2.2.2 | reduced-motion honored |
| status-announcements | 4.1.3 | live-region status (where applicable) |

Manual-only (never auto-passed, always surfaced as external): `screen-reader-usability`,
`cognitive-accessibility`, `localization-rtl`.

Coverage recomputed per capture: an omitted required criterion is `COVERAGE_INCOMPLETE`,
a repeat is `DUPLICATE_CHECK`, an off-list criterion is `UNKNOWN_CRITERION`, a manual
criterion reported by the adapter is `MANUAL_AUTO_PASS`. A scoped exception is checked
**after** coverage, so it can never hide a missing check.

## Regression / baseline cases

- Clean baseline + challenger fail on a criterion → `REGRESSION` (hard veto → `FAIL`).
- No baseline + challenger fail → `NEW_VIOLATION` (`FAIL`).
- Pre-existing baseline fail + challenger fail, **no** exception → `PREEXISTING_VIOLATION`
  (`FAIL`) — a pre-existing violation cannot pass unremarked.
- Pre-existing baseline fail + challenger fail **with** a separately hashed
  `{scope_sha256,reason,manual_owner}` exception → recorded in `accepted_exceptions`,
  not a veto (verdict falls through to `EXTERNAL`/`PASS`).

## Trust rejections (exit 2, no receipt), stable reason codes

`UNSAFE_ROOT`, `MANIFEST_UNAVAILABLE/SHAPE`, `PLAN_UNAVAILABLE/SHAPE`,
`STALE_SOURCE_REVISION`, `CANDIDATE_MISMATCH`, `ADAPTER_UNAVAILABLE`,
`ADAPTER_MISMATCH` (pin recomputed ≠ plan), `PROFILE_MISMATCH`, `FIXTURE_RELABELED`
(evidence_class drift), `MATRIX_MISMATCH`, `FORGED_CAPTURE` (DOM/action digest ≠
manifest), `MISSING_MEASURED_EVIDENCE`, `UNKNOWN_CRITERION`, `MANUAL_AUTO_PASS`,
`DUPLICATE_CHECK`, `COVERAGE_INCOMPLETE`, `CALLER_PASS`, `STALE_RECEIPT`
(adapter receipt outside `[source_commit_time, now]`), `ADAPTER_RESULT_MISSING/SHAPE`,
`ADAPTER_RECEIPT`, `BASELINE_SHAPE`, `UNSAFE_PATH`, `RECEIPT_PATH_UNSAFE`.

## Test outputs

```
$ bash tests/test-taste-a11y.sh
test-taste-a11y.sh: 53 pass, 0 fail

$ shellcheck -S warning bin/polylane-taste-a11y.sh
(clean)

$ git diff --check
(clean)
```

Red→green was observed: the suite reported `1 pass, 51 fail` before the runner
existed, then `53 pass, 0 fail` after implementation (with two fixture bugs — a stray
`)` in a jq row program and a missing pre-test `write_plan` — caught and fixed).

Cases exercised (contract list, all present): missing label, duplicate id,
unreachable keyboard control, keyboard trap, invisible focus, low contrast,
color-only error, overflow/reflow, motion violation, missing state (omitted check),
stale adapter receipt, forged/tampered adapter, baseline regression, pre-existing
without exception, scoped exception, exception-cannot-hide-missing, manual external,
fixture-to-production relabel, stale source revision, bare-pass-without-evidence,
duplicate check, unknown criterion, manual auto-pass, and the complete positive
fixture (→ `EXTERNAL` with manual pending; a no-manual variant → `PASS`).

## Claim boundary (what is NOT proven here)

- The adapter is a **fixture** in the tests. Real accessibility measurement (axe/DOM
  parsing, computed contrast, actual keyboard walk) is the adapter's job and remains
  external benchmark/manual evidence — this lane proves the **trust envelope** around
  it, not the measurements.
- Raw DOM-bytes ↔ `dom_sha256` verification is the capture lane's job; this runner
  binds the adapter to the manifest's already-verified digests and to the pinned
  command, and never re-derives capture authenticity itself.
- Manual screen-reader, cognitive, and localization judgments are surfaced as
  `manual_external` and can never be auto-passed. No real screen-reader run, real
  disability-user judgment, package install, or external action was performed or
  authorized (EXTERNAL-EVIDENCE preserved).
- `derived_status: PASS` is the automatable envelope only; it is not a claim of full
  accessibility conformance and not `TASTE-CERTIFIED`.

## Skill receipts

SKILL-READ: design:accessibility-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/accessibility-review/SKILL.md | 2943520804-4278
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: design:accessibility-review — helped: its WCAG 2.1 AA quick reference and common-issues list became the canonical criterion set and the fixture violation cases (contrast 1.4.3, labels 3.3.2, keyboard 2.1.1, focus 2.4.7, target 2.5.5, name-role-value 4.1.2); its "test with real AT catches what I can't" note anchored the manual-external boundary.
SKILL-EVIDENCE: engineering:testing-strategy — helped: "security boundaries, error handling, edge cases" focus drove the adversarial-first suite (forged/stale adapter, relabel, coverage gaps) over happy-path coverage; frontend row explicitly lists accessibility as a test dimension.
SKILL-EVIDENCE: operations:risk-assessment — helped: framed the reject taxonomy by failure mode (tamper, stale, relabel, missing coverage, caller pass) and the "cannot hide missing coverage" ordering as a compliance/security control rather than a nice-to-have.
SKILL-EVIDENCE: superpowers:test-driven-development — helped: enforced red (1 pass, 51 fail) before writing the runner, then green; the iron law caught that the positive test needed a real failing baseline before it could pass.

## DEFERRED

DEFERRED: none
