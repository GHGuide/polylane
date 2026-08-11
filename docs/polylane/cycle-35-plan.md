# Cycle 35 plan — clean provider-skill upgrades

Run: `c35-install-upgrade-20260811-a1`

## Frozen target

`m30.1` and `c82`: installing over a stale legacy/full-repository package must leave
only the current provider package, and both Codex discovery roots must be identical.
The pre-existing ten-product blind visual comparison remains external and is not part
of this autonomous repair.

## Lane carve

One builder owns `codex/install.sh`, `claude-code/install.sh`, installer regression
tests, and its verification/status evidence. It must reproduce the stale-root failure
before changing source, make replacement failure-safe and Bash-compatible, and cover
both fresh and upgrade installs. The integrator owns only integration/status/cycle
evidence, merges the exact builder tip, and independently reruns the focused installer
matrix.

## Economy and finish boundary

Exactly one builder plus one integrator, zero restarts, zero terminal gates, and no full
suite. The manifest explicitly declares `expected_terminal_gates: 0`; focused
acceptance is `test-install-fresh`, `test-installers`, and `test-doctor-agent`, plus
changed-shell syntax and warning-level ShellCheck. A focused GO may promote the repair;
the unrelated human visual corpus keeps the overall route
`EXTERNAL-EVIDENCE-OPEN` without blocking installation.
