# Cycle 43 findings — runner defects surfaced by the recovery attempts

Five promotion attempts (c43, c43b–c43e) landed the m32.6 v3 contract freeze.
The engineering passed every time; every failure was in the harness. Four
defects were fixed in-flight (all on main, all regression-tested); two remain
open for the next cycle.

## Fixed during cycle 43

| defect | symptom | fix |
|---|---|---|
| expired provider login unrecognized | every lane frozen at `/login`, wedge-respawned into the same screen until the restart cap halted the run with a misleading "runner died" | doctor `check_auth` preflight + `startup_check` parks login-expired lanes; `health_check` skips (and later unparks) them |
| kit reads escalated as critical | Claude renders home paths as `~/…`, so a lane reading its own runner-armed kit under `~/.codex/plugins` matched the `~/.` critical token and parked ~55 min | `approval_is_safe_read` judges secrets on the `Read(...)` target line only |
| model-specific paywall unrecognized | "You've reached your Fable 5 limit…" matched no paywall pattern, so an instant paywall read as a wedge and burned the retry budget | `pane_stalled` recognizes hit/reached-limit text offering `/usage-credits` or `/model`, routing to the free model-fallback ladder |
| pane repaint stops during long tool calls | an hour-long `tests/run.sh` inside one turn froze pane hash and pipe-pane log; the live-wedge cap respawned honest work mid-suite | `pane_burning_cpu` (CPU-seconds delta across the pane process tree). NOTE: child-process *presence* is not a valid signal — persistent MCP servers live for the whole session (that intermediate fix was itself a regression, caught and replaced) |
| one-shot `/exit` quiesce | a finished integrator sat at its prompt; the single `/exit` was swallowed mid-render and the run polled for 9 hours | bounded retry (`POLYLANE_QUIESCE_MAX`, default 5), each send re-proving clean+committed+scope-valid |

## Open for the next cycle

1. **`--resume` cannot re-promote after a promote refusal.** When `promote`
   refuses because the base has unrelated user changes, the supervisor's
   `--resume` re-enters and the immutable ledger refuses the verifier gate
   (`GRAPH-AUTHORITY: refused run verifier gate for verifier: node is
   succeeded, not currently graph-ready`), spinning restarts until HALTED.
   A verified run whose only blocker is a dirty base should be resumable
   straight into promotion once the base is clean.

2. **The efficiency canary conflates two goals.** `max_restarts: 0` failed
   three promotions of independently certified work, because a legitimate
   autonomous *repair round* counts as a restart. Zero-restart evidence belongs
   to criterion c56 (fresh process-start proof), not to every target's
   promotion. Consider distinguishing recovery restarts from repair rounds in
   the eligibility calculation, or scoping the canary to runs that target c56.

3. **Uncommitted run evidence blocks promotion.** `promote` correctly refuses
   to stage unrelated changes, but the runner itself writes host-gate failure
   records and skill-use receipts into the base tree between runs, so a second
   run can be blocked by the first run's own artifacts. Either commit those
   under a runner-owned path allowance or write them outside the base tree.
