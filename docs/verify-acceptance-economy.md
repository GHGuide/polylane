# m9.1 acceptance-economy verification

Implemented keyed frozen acceptance checks in `bin/polylane-memory.sh`.

| Command | Exit status | Behavior demonstrated |
| --- | --- | --- |
| `bin/polylane-check.sh "$PWD/.polylane/check-cache/acceptance-economy" -- bash tests/test-accept-dedupe.sh` | 0 | 26 checks: keyed checks execute once per invocation, propagate pass/fail only to selected keyed members, keep empty keys independent, reject invalid keys without mutation, and tag frozen commands without changing them. |
| `bin/polylane-check.sh "$PWD/.polylane/check-cache/acceptance-economy" -- bash tests/test-memory.sh` | 0 | 53 checks: legacy memory behavior, acceptance tiers, regression tracking, optional unkeyed memoization, atomic writers, and keyed metadata compatibility remain intact. |

The cache reported `RUN` for both commands; both test suites executed in this worktree.
Coordination relay was unavailable and no cross-lane request was required.

## DEFERRED

DEFERRED: none
