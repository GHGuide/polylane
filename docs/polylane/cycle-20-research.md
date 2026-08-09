# Cycle 20 research — restart attribution and process boundary

## Primary evidence

Cycle 19's runner log contains exactly two health respawns: builder
`optional-domain-gate` at the first dead pane and `integrator` at its first dead pane.
Between them, the owned tmux session vanished and the supervisor resumed once. The
efficiency proof therefore reported `restarts=3`, `launches=2`, and
`terminal_gates=1`, then rejected the run before promotion.

The Graphify ownership repair is commit `e26c208`; its focused evidence is 27/0 for
lane completion and 11/0 for graph sharing, including a foreign-repository rejection.
The optional-domain repair is builder commit `80849c5`; Cycle 16's contract is 35/0 and
proves both no-side-effect absence and unchanged requested grading.

## Process-boundary conclusion

A Bash runner sources its functions at process start. Merging corrected source into an
integrator worktree cannot alter functions already loaded by the outer coordinator.
Cycle 19 was therefore useful recovery evidence but cannot certify process-start
behavior. A fresh root and nonce are required; Cycle 20 supplies both.
