# Cycle 26 per-lane skill suggestions

Autonomous mode selected only already-installed, task-specific skills. No marketplace
or GitHub installation is needed before this cycle.

## `terminal-finality` builder

- **Selected — `superpowers:systematic-debugging`:** the task is a reproduced
  multi-process failure chain; use evidence ordering and root-cause isolation before
  changing the runner.
- **Selected — `superpowers:test-driven-development`:** encode the exact NO-GO,
  failed-admission, evidence-preservation, and supervisor behavior red-first.
- Not selected: UI, data, API, document, and broad inventory skills have no concrete
  activity in this lane.

## `integrator`

- **Selected — `engineering:code-review`:** independently inspect ordering,
  fail-closed behavior, shell portability, and recovery state transitions.
- **Selected — `superpowers:verification-before-completion`:** require fresh focused
  evidence, immutable runtime stats, and one coordinator-owned terminal boundary.

Selected skill files are read once by their assigned lane and must produce explicit
`SKILL-READ` and `SKILL-EVIDENCE` receipts. `graphify` and `graphify-auto` are excluded
from skill delivery because the shared query helper is infrastructure.

