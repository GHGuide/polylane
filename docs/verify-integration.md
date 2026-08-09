# Cycle 17 integration verification — recovery certification

Run: `c17-recovery-cert-20260809-a1`

## Merged provenance

`lane/c17-gate-contracts` at `20aa6e8f85fc304bf60cc93c509e5d2bf00263c6` and
`lane/c17-skill-contracts` at `6e0c38fd03ea96b89d16de66e1fbcb4b651f29f8` are verified
ancestors of this integrator through merge commits `ba01c5d` and `614c571`. The recovery
preserves Cycle 16's recorded 2,088-check, nine-failure **NO-GO**; this is a fresh run,
not a rewrite of historical evidence.

## Reproduced focused acceptance

All commands ran through `bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"`:
graph authority **56/0**, verdict repair **36/0**, wedge **27/0**, skill delivery
**31/0**, and Cycle-14 compatibility **13/0**. The focused integration matrix also
passed Cycle-16 contract **29/0**, skill parity **57/0**, installers **50/0**, and fresh
installers **39/0**.

## Cross-contract and safety review

ShellCheck is clean for the changed scripts `bin/polylane-scout.sh` and
`bin/polylane-skill-catalog.sh`; `git diff --check`, marker documentation consistency,
and seam scanning are clean. The graph-only fixture stubs its domain-grade prerequisite
without replacing production coverage, while verdict repair counts one grade call before
each of three merge attempts. The liveness fixture uses the real terminal classifier to
prove an old `agent_message` does not shorten a live high-effort turn. Skill arming
re-resolves a trusted path and invokes the public benchmark gate with the current exact
fingerprint, domain, and lane shape, so missing, thin, stale, or unbenchmarked evidence
cannot arm a recommendation. Profile grading, benchmark admission, receipt hashes,
single terminal-gate accounting, paper-only trading, and exact-hash approval-bound action
simulation remain unchanged.

## Host boundary

`c51`, `c52`, `m17.1`, and `m17.2` are complete from this reproduced evidence. `m16.4`
and `m17.3` remain open for the coordinator's one fresh terminal matrix: full suite,
whole-tree ShellCheck, provider/install parity, and GO/NO-GO rehearsal. No terminal suite,
live rehearsal, real trade, deployment, publication, spend, contact, or other
consequential external action was run here.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c17-recovery-cert-20260809-a1

DOMAIN-GRADER: PASS bundle=docs/polylane/domain-runtime/bundle.json grade=docs/polylane/domain-runtime/grade.json

ACCEPTANCE-GATE: frozen checks failed; terminal gate is exhausted for this run.
