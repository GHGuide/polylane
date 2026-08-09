# Cycle 20 plan — clean process-start certification

## Why this cycle exists

Cycle 19 fixed two confirmed defects: optional domain grading no longer stages absent
artifacts, and a runner-created Graphify link is clean only when it resolves to a real
graph owned by a registered sibling worktree in the same Git repository. Its terminal
gate still returned NO-GO because the already-running coordinator had accumulated three
restarts before both fixes could be loaded from process start.

Cycle 20 starts at integrated commit `23cabdf`. Its manifest intentionally has no
`domain_runtime`, so the new runner must cross the optional-domain boundary as a true
no-op. Its restart budget is zero. No production change is expected.

## Frozen lane and interface

| Lane | Owns | Frozen outcome |
|---|---|---|
| `restart-accounting-audit` | Cycle 20 audit verification and status only | Attribute all Cycle 19 restarts to primary evidence, verify both source fixes are present, and prove their focused contracts without changing code |
| `integrator` | Exact-tip merge, independent review, Cycle 20 evidence/state | Preserve a clean tree, reproduce focused runtime contracts, and hand exactly one untouched terminal command to the coordinator |

## Mechanical acceptance

- `test-lane-done`, `test-share-graph`, `test-cycle-16-contract`,
  `test-verdict-repair`, `test-supervisor`, and `test-efficiency-canary` pass from the
  merged tree.
- The outer run records exactly two launches, zero restarts, one terminal gate, and
  complete cleanup.
- The terminal command runs the full suite, whole-tree ShellCheck, skill parity,
  installers, and hermetic GO plus NO-GO rehearsal exactly once.
- The outer manifest omits `domain_runtime`; no bundle, grade, or integration-evidence
  mutation may be invented by that optional skip.

## Safety and stopping rule

No external action occurs. Trading remains research/backtest/paper-only. Builders and
the integrator do not run the terminal matrix. Any restart, duplicate launch, missing
rehearsal outcome, dirty completed lane, or terminal failure is NO-GO and starts a new
truthful cycle; no failed verdict may be rewritten.
