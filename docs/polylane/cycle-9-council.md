# Cycle 9 council

Five independent lenses reviewed the promoted GO evidence and the live runner transcript.

## Goal alignment

Verdict: continue narrowly. The eight requested product-autonomy capabilities exist and pass, but a walk-away run should not need the operator to diagnose why a committed DONE marker is ignored.

## Adversarial reliability

Verdict: continue. `polylane-state` did not load `orchestration_contract`, so it could call a dirty worktree done while the runner correctly rejected it. This disagreement triggered unnecessary pane recreation.

## Economy

Verdict: continue. Historical terminal acceptances reran equivalent full-suite checks under different cache namespaces. Explicit same-gate dedupe is safer than broad memoization and removes the measured duplication.

## Operability

Verdict: continue. The dashboard’s hint used an ambient `POLYLANE_SESSION`, producing a different session than the manifest. Session identity must be a canonical snapshot field, not render-time environment state.

## Coordination

Verdict: continue. Prompts tell isolated worktrees to communicate through `docs/parallel-status.md`, but that file is not shared until merge. A small atomic canonical relay is needed for real-time requests, decisions, and resource claims.

## Council decision

Run one bounded cycle with four frozen regressions: keyed acceptance dedupe, runner/state/dashboard truth parity, canonical outcome rooting, and shared coordination. Do not reopen benchmark, discovery, judge count, model policy, or product scope. After those checks and the terminal gate pass, stop unless a new executable failure appears.
