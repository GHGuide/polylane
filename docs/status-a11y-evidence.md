STATUS: a11y-evidence DONE run=c39-visual-loop-20260812-a1

Lane: a11y-evidence (Cycle 39). Isolated helper/test only; no existing file touched.

Delivered:
- bin/polylane-taste-a11y.sh — `audit ROOT CAPTURE_MANIFEST A11Y_PLAN RECEIPT -- ADAPTER`.
  Bash 3.2 + jq, main-guarded, atomic receipt write. Pins the accessibility adapter
  (recomputed command_sha256 == plan pin), binds candidate/source-revision/DOM/action
  hashes + design lock + evidence_class, recomputes full-matrix criterion coverage,
  compares challenger to a baseline receipt, and emits taste-a11y-receipt/v1 with
  derived PASS/FAIL/EXTERNAL and stable reason codes.
- tests/test-taste-a11y.sh — 53/0 adversarial cases (missing label, duplicate id,
  unreachable/trap/escape, invisible focus, low contrast, color-only error,
  reflow/overflow, motion, missing state, stale+forged adapter, baseline regression,
  pre-existing w/ + w/o scoped exception, exception-cannot-hide-missing, manual
  external, fixture relabel, bare-pass, duplicate/unknown criterion, positive fixture).
- docs/verify-a11y-evidence.md — schema, criterion coverage, regression cases, reject
  taxonomy, claim boundary, SKILL-READ + SKILL-EVIDENCE rows, DEFERRED: none.

Verification: `bash tests/test-taste-a11y.sh` → 53 pass, 0 fail; `shellcheck -S warning
bin/polylane-taste-a11y.sh` clean; `git diff --check` clean. Red (1 pass/51 fail)
observed before implementation.

Consumer relay: taste-a11y-receipt/v1 field paths sent to certificate-v2,
quality-adapter, capture-hardening, runner-wiring. No requests were addressed to
a11y-evidence.

Claim boundary: adapter is a fixture in tests; real axe/DOM/contrast/keyboard
measurement and screen-reader/cognitive/localization judgments remain external
(manual_external, never auto-passed). No package install or external action performed.

DEFERRED: none
