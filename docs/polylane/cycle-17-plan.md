# Cycle 17 plan — honest recovery and fresh certification

## Why this cycle exists

Cycle 16 implemented the ten domain-autonomy improvements and passed 2,088 checks,
but its single terminal gate exposed nine compatibility failures. The run correctly
ended NO-GO. This cycle preserves that evidence, repairs only the confirmed seams,
and earns a new terminal decision under a fresh run nonce.

## Frozen lanes

| Lane | Owns | Frozen outcome | Focused gate |
|---|---|---|---|
| `gate-contracts` | graph/verdict/liveness tests | New pre-verdict gates are hermetic, and stale progress messages never shorten a live worker's grace period | `test-graph-authority`, `test-verdict-repair`, `test-wedge` |
| `skill-contracts` | selected-skill delivery tests and their admission helpers | A recommendation is armed only after exact-fingerprint, lane-shaped benchmark evidence; compatibility fixtures prove that rule instead of bypassing it | `test-skill-delivery`, `test-cycle-14-contract` |
| `integrator` | merge, cross-contract evidence, provider parity, docs | Both repairs coexist with all Cycle-16 mechanisms and hand one fresh terminal gate to the coordinator | Cycle-16 contract, parity, installers |

The lanes are file-disjoint. Builders run focused checks only. The integrator may
write `READY-FOR-HOST-GATE`; only the coordinator runs the full suite, ShellCheck,
provider/install parity, and live GO/NO-GO rehearsal.

## Acceptance and safety

- Do not weaken `domain_grade_gate`, benchmark admission, receipt binding, or the
  single-terminal-gate rule to make a fixture pass.
- Consequential external actions remain simulations requiring exact-hash approval.
- Trading remains research/backtest/paper-only.
- Preserve Cycle 16's failed terminal evidence; this is a new run, not a rewritten
  history.

## Finish

The cycle may promote only after all focused checks pass, the integrator commits a
nonce-bound READY handoff, and the coordinator's one fresh terminal gate passes.
