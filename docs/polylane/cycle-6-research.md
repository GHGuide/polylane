# Cycle 6 research — why the efficient candidate still failed

The initial execution path met every runtime budget before acceptance: two builders and one
integrator, no restarts, one host gate, and 412 seconds. The failure was in failure handling, not
lane execution. A terminal suite returned nonzero without a durable log. The runner treated that
as repairable integration feedback, restarted the model, and consumed a second gate. The final
certificate correctly rejected both additions.

Replaying the exact pre-repair integration commit in a detached clean worktree produced 1,026
passes and no failures. The correct response is therefore not a retry inside the consumed run.
The terminal command now uses its content cache as a durable log; any failure stops the run. A
fresh run starts from a run-ID-scoped empty telemetry window, while same-ID supervisor resumes
continue the existing window. This makes both transient failures and efficiency claims auditable.
