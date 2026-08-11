# Cycle 31 plan — fresh zero-retry terminal certification

Run: `c31-terminal-cert-20260811-a1`

Base: `candidate/c31-terminal-cert` at retained Cycle 30 tip
`6ca299cb78f376035a60d74a7c6b9ba7fa9b69ec`.

## Frozen target

Target every open or doing autonomous subgoal: `m21.1`–`m21.4`, `m22.1`–`m22.3`,
`m23.1`–`m23.3`, `m24.1`–`m24.4`, `m25.1`–`m25.5`, `m26.1`–`m26.4`, and
`m27.1`–`m27.4`. Host-owned criteria are `c57`–`c79`. Criterion `c28` remains
external and is not changed by this cycle.

## Carve

One builder audits the immutable retained source, frozen acceptance inventory,
provider parity, installer surface, and terminal route. It owns evidence only; any
new source defect is a truthful NO-GO, not an unplanned edit. The integrator merges
that exact evidence tip, performs independent focused verification, validates the
current telemetry, and emits `READY-FOR-HOST-GATE` only from a clean committed tip.

## Frozen acceptance

Run the target-scoped focused checks through `bin/polylane-check.sh`. The builder and
integrator must not execute terminal-tier commands. After READY, the runner alone
executes the frozen terminal checks, including the full test suite, production
ShellCheck, provider parity, fresh installers, and live GO/NO-GO doctor rehearsal.

## Runtime acceptance

- one builder launch and one integrator launch;
- zero lane retries or repairs;
- zero integrator repairs;
- zero supervisor restarts;
- exactly one runner-owned terminal-gate event;
- current-run efficiency proof, verified promotion, complete cleanup, and one GO
  report.

Launch with `POLYLANE_MAX_RETRIES=0`, `POLYLANE_MAX_REPAIRS=0`,
`POLYLANE_INTEGRATOR_REPAIRS=0`, and supervisor restart cap `0`. Any repair or
relaunch makes this certification NO-GO. Retain the evidence and start a new cycle;
never rewrite telemetry.

## Completion

Only a host-gated GO authorizes installing the promoted Claude and Codex variants
locally. No push, publication, deployment, account change, or other external action
is in scope.

