# Cycle 27 council — repair READY, fresh certification elected

The council accepts the integrated repair source as `READY-FOR-HOST-GATE` for run
`c27-gate-repair-20260810-a1`. Exact builder tip
`013534eef494976e66826d39e3fd2c9a845c60e8` is merged. Independent review found
and repaired the canonical acceptance-output root seam. The frozen matrices pass
124/78/183 assertions, adjacent runtime/graph tests pass 133/133, changed-script
ShellCheck is clean, and telemetry records exactly two launches, zero restarts,
and zero terminal gates.

The elected next focus is a fresh Cycle 28 one-gate certification from the promoted
repair tip. That process alone loads the final runner functions, runs the full suite,
ShellCheck, provider parity, both installers, and live GO/NO-GO doctor rehearsal,
then promotes or retains one truthful host failure with its bounded command tail.
Cycle 27 does not spend or simulate that terminal boundary.
