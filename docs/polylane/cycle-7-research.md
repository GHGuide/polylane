# Cycle 7 research — environment ownership at nested process boundaries

The failing pattern was deterministic: `test-supervisor.sh` passed 22/22 alone and failed 15/22
when invoked with `POLYLANE_SUP_MAX_RESTARTS=0`. The first crash-recovery and HALTED-recovery
fixtures each launched only once because their copied supervisor inherited the outer benchmark's
zero-restart cap. Direct GO, NO-GO, lock, and explicit-cap cases still passed, matching that cause.

The minimal correction is fixture isolation, not runner repair: the supervisor test exports its
own normal retry budget before invoking copied supervisors, while its explicit cap case still
overrides that value locally. The exact hostile invocation and the full 67-file suite now pass.
