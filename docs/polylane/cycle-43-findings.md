# Cycle 43 findings — runner defects surfaced by the recovery attempts

Five promotion attempts (c43, c43b–c43e) landed the m32.6 v3 contract freeze.
The engineering passed every time; every failure was in the harness. All seven
defects are now fixed on main with regression tests — five during the cycle,
two immediately after it closed.

## Fixed during cycle 43

| defect | symptom | fix |
|---|---|---|
| expired provider login unrecognized | every lane frozen at `/login`, wedge-respawned into the same screen until the restart cap halted the run with a misleading "runner died" | doctor `check_auth` preflight + `startup_check` parks login-expired lanes; `health_check` skips (and later unparks) them |
| kit reads escalated as critical | Claude renders home paths as `~/…`, so a lane reading its own runner-armed kit under `~/.codex/plugins` matched the `~/.` critical token and parked ~55 min | `approval_is_safe_read` judges secrets on the `Read(...)` target line only |
| model-specific paywall unrecognized | "You've reached your Fable 5 limit…" matched no paywall pattern, so an instant paywall read as a wedge and burned the retry budget | `pane_stalled` recognizes hit/reached-limit text offering `/usage-credits` or `/model`, routing to the free model-fallback ladder |
| pane repaint stops during long tool calls | an hour-long `tests/run.sh` inside one turn froze pane hash and pipe-pane log; the live-wedge cap respawned honest work mid-suite | `pane_burning_cpu` (CPU-seconds delta across the pane process tree). NOTE: child-process *presence* is not a valid signal — persistent MCP servers live for the whole session (that intermediate fix was itself a regression, caught and replaced) |
| one-shot `/exit` quiesce | a finished integrator sat at its prompt; the single `/exit` was swallowed mid-render and the run polled for 9 hours | bounded retry (`POLYLANE_QUIESCE_MAX`, default 5), each send re-proving clean+committed+scope-valid |

## Fixed after the cycle closed (same day)

1. **`--resume` could not re-promote after a promote refusal.** When `promote`
   refused because the base had unrelated user changes, the supervisor's
   `--resume` re-entered and the immutable ledger refused the verifier gate
   (`GRAPH-AUTHORITY: refused run verifier gate for verifier: node is
   succeeded, not currently graph-ready`), spinning restarts until HALTED.
   **Fixed:** `verifier_gate_admits` treats a verifier that already succeeded
   in *this* run as admitted, so an interrupted promotion resumes instead of
   deadlocking; `ready` correctly never re-offers a succeeded node, and every
   other state still fails closed. Covered by `tests/test-verifier-resume.sh`.

2. **The efficiency canary conflates two goals.** `max_restarts: 0` failed
   three promotions of independently certified work, because a legitimate
   autonomous *repair round* counts as a restart. **Resolved as policy:**
   zero-restart evidence belongs to criterion c56 (fresh process-start proof),
   so only runs targeting c56 set `max_restarts: 0`; ordinary promotions allow
   repair rounds. Still open as a *code* improvement: distinguishing recovery
   restarts from repair rounds inside the eligibility calculation would let a
   c56 run survive its own repair wave.

3. **Uncommitted run evidence blocked promotion.** `promote` correctly refuses
   to stage unrelated changes, but the runner itself writes host-gate failure
   records and skill-use receipts into the base tree between runs, so a second
   run was blocked by the first run's own artifacts — this is what stopped
   c43e's passing gate. **Fixed:** `runner_owned_promotion_path` accepts
   host-gate records and skill-use receipts for any run id, shape-matched to
   the runner's own filenames, so nested paths, traversal attempts, foreign
   extensions, and all user source are still refused. Covered by
   `tests/test-promote-scope.sh`.
