# Cycle 25 council — truthful NO-GO

The council rejects promotion for run `c25-finality-20260810-a1`. The final combined
source passes 602 focused assertions and changed-script ShellCheck, but canonical stats
record one `handoff-contract` restart, one integrator restart, and one supervisor
restart. The frozen plan makes any restart NO-GO, and the coordinator-owned terminal
gate remains untouched.

The exact two builder tips are preserved. Integration repaired the strict runtime
finalization seam, restored an out-of-ownership test to the frozen base while retaining
its regression in an owned test, added a fail-closed completed-branch scope gate, and
delivered exact selected-skill records to the integrator as well as builders. These
repairs are source for a fresh nonce; they cannot retroactively sanitize this run's
restart history.
