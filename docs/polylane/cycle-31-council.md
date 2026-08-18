# Cycle 31 council

## Evidence

- Exact builder DONE tip `cff6ec32f988726471af51a9622f9cba53b56aa9` is
  integrated, with retained repairs `809c246` and `6ca299c` confirmed as
  ancestors.
- Independent review confirmed nested evidence de-authorization, atomic proof
  path/nonce export and unset behavior, and explicit zero integrator-repair
  precedence.
- All 24 target-scoped focused entries passed once through the integrator cache;
  changed retained scripts pass syntax and bounded production ShellCheck.
- The manifest exactly targets all 27 open/doing autonomous subgoals and owns
  four terminal-tier entries.
- Canonical pre-handoff stats contain one builder launch, one integrator launch,
  zero lane or supervisor restarts, and zero terminal gates.

## Decision

The clean exact committed source was handed to the runner-owned terminal gate.
The gate counted exactly once, but both distinct terminal commands failed because
`tests/run.sh` ended at 2,444 pass / 5 fail. Four failures in
`test-load-manifest.sh` still expected relative worktree paths after the runtime
contract intentionally made them absolute; one failure in
`test-prompt-economy.sh` found that the optimized prompt source had lost its exact
coordinator-owned-terminal sentence. Emit NO-GO. Nothing was promoted or cleaned,
and Cycle 30's one-restart NO-GO remains immutable.

Cycle 32 repairs only these two contract drifts under focused acceptance. A later
fresh process must own terminal certification; this consumed Cycle 31's only gate.
