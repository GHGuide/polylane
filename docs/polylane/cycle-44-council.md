# Cycle 44 council — implement the controls, do not touch the lock

- **Derive acceptance, never invent it.** The lock already named the five
  controls; the coordinator's job was to translate them into runnable checks and
  freeze them before builders, not to decide what "done" means.
- **One boundary per lane.** The five defects clustered into three boundaries
  (prompt bytes, execution contract, comparator tally), which gave disjoint
  ownership with no shared files and no cross-lane contract beyond "do not touch
  the contracts".
- **Leave the registry OPEN.** Flipping a defect status re-freezes a hashed
  contract (`freeze_sha256`). Implementing a control and re-certifying the lock
  are different acts; the council declined to bundle them and recorded the
  transition question for a later cycle.
- **Test-driven or it did not happen.** Every lane carried TDD as its predefined
  skill and the integrator was instructed to reject a test that never failed
  first — the cheapest defence against controls that exist only on paper.
