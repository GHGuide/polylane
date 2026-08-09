# Cycle 18 integration verification — walk-away recovery truth

Run: `c18-walkaway-truth-20260809-a1`.

## Exact provenance

Merged committed builder tips only: runtime-resilience `631bd3ab1eda4f20262bd4d890e41109324a3efd`
through merge `0cf81ca`, and skill-context `e21c26ac086f314796934bc5c4a346e00430d9c5`
through merge `6a22ecc`. Their committed first-line DONE markers match this run. The
integrator then corrected one cross-lane caller seam: `compile_prompt` now passes the
single preflight-validated `lane_skills_file` JSON to `compile-selected`, rather than
mistaking a `SELECTED-SKILL` record's `SKILL.md` path for that JSON kit.

The new runner-delivery assertions in `test-cycle-13-contract.sh` were red with the
original caller (40 pass, 4 fail: zero selected records and no receipt contract), then
green after the correction (44 pass, 0 fail). The compiled builder fixture contains all
four trusted records, including exact id/path/source/fingerprint/reason data, immediately
after the named-kit instruction; the integrator fixture remains unselected.

## Reproduced local matrix

All commands ran from this merged worktree through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"` unless noted.

- Runtime recovery: `test-wedge.sh` 29/0; `test-lane-done.sh` 26/0;
  `test-verdict-repair.sh` 40/0; `test-graph-events.sh` 47/0;
  `test-write-report.sh` 33/0; `test-supervisor.sh` 26/0; and
  `test-share-graph.sh` 11/0.
- Selected-skill delivery: `test-skill-delivery.sh` 44/0 and
  `test-prompt-compiler.sh` 16/0.
- Cross-contract/provider evidence: `test-cycle-13-contract.sh` 44/0,
  `test-cycle-16-contract.sh` 29/0, `test-skill-parity.sh` 57/0,
  `test-installers.sh` 50/0, and `test-install-fresh.sh` 39/0.
- Static/document evidence: whole-tree `shellcheck -S warning bin/*.sh`,
  `bin/polylane-markers.sh check-docs references/`,
  `bin/polylane-seams.sh scan "$PWD"`, and
  `git diff --check candidate/c18-base` all exited 0.

The adversarial fixtures prove prose-only trust and banner text send no tmux keys;
canonical host-gate failure leaves a committed READY integrator clean and resumable;
simulated report and event failures preserve the prior report/JSONL replay; the
10,000-event replay remains linear; fake low disk waits without spending restart budget;
and a recovery worktree receives only a same-common-repository graph link without
overwriting a local path. No test fills real disk, and all trading/action behavior remains
paper-only, simulated, and approval-bound.

## Review and remaining boundary

The correctness/security/maintainability review found and closed the selected-kit caller
mismatch above; no other actionable issue remained after the final matrix. Ponytail
review result: `Lean already. Ship.` The canonical graph was queried before implementation
inspection; its indexed C17-era topology did not contain the new runtime helpers, while
the same-repository fallback was independently exercised by the merged fixture. The
coordinator alone must still run the untouched terminal `tests/run.sh` matrix and live
GO/NO-GO rehearsal; the optional 6/12/24-hour soak is operator certification, not CI.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c18-walkaway-truth-20260809-a1

DOMAIN-GRADER: PASS bundle=docs/polylane/domain-runtime/bundle.json grade=docs/polylane/domain-runtime/grade.json
