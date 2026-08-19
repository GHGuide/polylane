# Cycle 43 emergent questions

No user decision is required before cycle 44.

1. Should a worker sandbox that cannot bind loopback or a private tmux socket
   emit an explicit `SANDBOX-SKIP` receipt for host-capability tests instead of
   forcing a NO-GO the normal host must re-litigate? (Recurred from cycle 42;
   still unresolved, still not blocking.)
2. Should the efficiency canary distinguish *recovery* restarts from *repair*
   rounds inside the eligibility calculation, so a c56 run can survive its own
   repair wave without abandoning the zero-restart claim?
3. Now that the defect registry is frozen with `status: OPEN`, what re-freezes
   it when a control lands — does flipping a status require a new lock hash and
   a fresh certification, and which cycle owns that transition?
