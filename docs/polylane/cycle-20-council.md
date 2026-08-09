# Cycle 20 council — clean process-start handoff

## Decision

Accept the evidence-only restart-accounting audit and the integrator's focused recovery
matrix as current local evidence. The exact nonce-matched builder tip `716624a` was
merged only after its committed DONE marker was confirmed, and its complete range from
the Cycle 20 base changed only `docs/verify-restart-accounting.md` and
`docs/status-restart-accounting-audit.md`. The focused `m20.1` acceptance is therefore
passed; the `m20.1` subgoal, `m18.3`, and `c56` remain open because only a fresh outer
process can prove zero restarts, two launches, one terminal gate, cleanup, and both
rehearsal outcomes.

## Safety rulings

- Preserve the optional-domain no-op, requested-profile grade, same-repository graph
  ownership predicate, clean-tree checkpoint, approval hashes, and frozen acceptance.
- Treat the existing graph as an aid only: both changed-helper caller queries returned
  stale fuzzy documentation rather than source nodes, so current commits and hermetic
  contracts remain the proof.
- Do not run the full suite, doctor rehearsal, live action, or real trading from this
  lane. Trading remains research/backtest/paper-only.

## Verdict posture

`READY-FOR-HOST-GATE` is warranted only as a nonce-bound handoff after the fresh focused
and cross-contract evidence. It is not terminal GO; the coordinator's single untouched
terminal command alone can close or truthfully reject `m18.3` and `c56`.
