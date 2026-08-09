# polylane self-run — index

Vision: [NORTHSTAR](NORTHSTAR.md) · Goal: [ULTIMATE_GOAL](ULTIMATE_GOAL.md) ·
Strategy: [STRATEGY](STRATEGY.md) · [project profile](PROJECT_PROFILE.md) ·
Decisions: [decisions/INDEX.md](decisions/INDEX.md)

State: `max-state.json` (query through `bin/polylane-memory.sh`; never infer it from prose).

Cycle 20 certification: [plan](cycle-20-plan.md) ·
[research](cycle-20-research.md) · [skill suggestions](cycle-20-suggestions.md) ·
[council](cycle-20-council.md) · [digest](cycle-20-digest.md) ·
[questions](cycle-20-questions.md) · [Cycle 20 outcome](cycle-20-outcome.md) ·
[Cycle 19 terminal outcome](cycle-19-outcome.md).
The live run recorded one builder restart after an exact DONE line landed under the
wrong status filename, and the integrator missed a canonical relay request because its
compiled prompt did not contain the literal relay command. Commit `763fb00` repairs both
seams with red-first tests and a 381/0 runtime/prompt/parity matrix. Its host rejection
then exposed dirty gate evidence and false report attribution; `e1de56a` fixes both with
a 261/0 matrix and nonce-verifies the canonical proof. Post-run inspection showed the
wrong marker path originated in the plan rather than the worker; `f58d3cb` now rejects
that ownership or prompt mismatch prelaunch and passed a 292/0 matrix. Cycle 20 remains a
truthful NO-GO; `m20.1`, `m18.3`, and `c56` stay open for Cycle 21's untouched
zero-restart terminal gate and both rehearsal outcomes.

Cycle 19 recovery: [plan](cycle-19-plan.md) · [research](cycle-19-research.md) ·
[skill suggestions](cycle-19-suggestions.md) · [questions](cycle-19-questions.md) ·
[council](cycle-19-council.md) · [digest](cycle-19-digest.md) ·
[integration verification](../verify-integration.md). The nonce-bound optional-domain
repair is locally verified: generic projects now preserve `not-requested` as a true
no-op and requested profiles retain their bundle/grade/PASS commit. `m19.1` and `c55`
are done. Its terminal gate still returned truthful NO-GO because the contaminated
recovery process accumulated three restarts; Cycle 20 owns the fresh certification.

Cycle 18 recovery history: [plan](cycle-18-plan.md) · [research](cycle-18-research.md) ·
[skill suggestions](cycle-18-suggestions.md) · [questions](cycle-18-questions.md) ·
[council](cycle-18-council.md) · [digest](cycle-18-digest.md) ·
[integration verification](../verify-integration.md). Every builder, integration, and
full-suite check passed, but the live GO rehearsal exposed an unconditional attempt to
stage optional domain artifacts. Promotion was correctly withheld; Cycle 19 owns the
fresh recovery rather than rewriting that terminal result.

Cycle 17 recovery history: [plan](cycle-17-plan.md) ·
[skill suggestions](cycle-17-suggestions.md) · [questions](cycle-17-questions.md) ·
[council](cycle-17-council.md) · [digest](cycle-17-digest.md). Focused contracts passed,
but the host gate was interrupted by ENOSPC and the resumed run exposed recovery seams.
It remains truthful NO-GO evidence; a later isolated suite pass is diagnostic, not a
retroactive promotion.

Cycle 16 recovery history: [plan](cycle-16-plan.md) · [questions](cycle-16-questions.md) ·
[council](cycle-16-council.md) · [digest](cycle-16-digest.md) ·
[integration](cycle-16-integration.md). Its 2,088-check terminal run correctly ended
**NO-GO** on nine compatibility failures. That history remains intact; Cycle 17 is a
fresh nonce-bound recovery certification, not a rewrite of the failed evidence.

Closed cycle 15: [plan](cycle-15-plan.md) · [research](cycle-15-research.md) ·
[integration](cycle-15-integration.md) · [skill suggestions](cycle-15-suggestions.md).
Project outcomes—not apps—are now the core abstraction, with trading/research,
operations, content/data, software, and custom profiles plus consequential-action gates.

Closed cycle 14: [plan](cycle-14-plan.md) · [research](cycle-14-research.md) ·
[30-candidate audit](cycle-14-suggestions.md) · [questions](cycle-14-questions.md) ·
[council](cycle-14-council.md) · [digest](cycle-14-digest.md) ·
[integration proof](../verify-integration.md). Transactional promotion/reporting,
process-aware liveness, one canonical worker ledger, and resolved skill delivery are
certified. Route: `EXTERNAL-EVIDENCE-OPEN` for the ten-product blind visual corpus only.

Closed cycle 13: [plan](cycle-13-plan.md) · [research](cycle-13-research.md) ·
[questions](cycle-13-questions.md) · [council](cycle-13-council.md) ·
[digest](cycle-13-digest.md) · [integration proof](../verify-integration.md).

Closed cycle 12: [plan](cycle-12-plan.md) · [research](cycle-12-research.md) ·
[questions](cycle-12-questions.md) · [council](cycle-12-council.md) ·
[digest](cycle-12-digest.md) · [integration proof](../verify-integration.md).

Previous cycle 11: [plan](cycle-11-plan.md) · [research](cycle-11-research.md) ·
[questions](cycle-11-questions.md) · [council](cycle-11-council.md) ·
[digest](cycle-11-digest.md).

Earlier digests: [c1](cycle-1-digest.md) · [c2](cycle-2-digest.md) ·
[c3](cycle-3-digest.md) · [c4](cycle-4-digest.md) · [c5](cycle-5-digest.md) ·
[c6](cycle-6-digest.md) · [c7](cycle-7-digest.md) · [c8](cycle-8-digest.md) ·
[c9](cycle-9-digest.md) · [c10](cycle-10-digest.md).

Post-goal packet: [original 30 suggestions](next-suggestions.md). Every independent
autonomous criterion is complete. Cycle 12's rendered ten-product visual comparison
remains external and is the only unfinished evidence in the frozen goal tree.
