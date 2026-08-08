# Cycle 13 digest — whole-system capability pass

Cycle 13 made effort/model selection agent-aware and manifest-driven, replaced the
hard-coded skill list with metadata and outcome-ranked recommendations, added a real
prompt compiler with conservative token bounds, installed project-scoped Claude and
Codex lifecycle hooks, and introduced one named certification matrix. Four Codex
builders and an integrator completed the work; the final integrated tree passed 1,778
tests across 96 files, ShellCheck, 43 parity checks, 34 installer checks, and physical
GO/NO-GO rehearsal. The self-run also exposed four concrete orchestration defects:
runner-owned state dirtied the base before promotion, the report claimed a merge after
that merge failed, active high-effort turns could look terminal to the wedge detector,
and worktree-local worker ledgers could allocate duplicate sequence numbers.

**Next:** cycle 14 fixes those observed self-hosting failures and proves them with one
transactional promotion/recovery certification before any speculative expansion.
