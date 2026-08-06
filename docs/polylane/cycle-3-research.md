# Cycle 3 research — measured runtime evidence

The production bottleneck was repeated full JSONL replay and graph-wide scans, not tmux or
model latency. The initial valid 64-lane/10,000-event packet projected roughly fourteen
minutes because validation repeatedly rescanned topology and ledger state. Indexed graph
validation plus a disposable, identity-checked replay checkpoint reduced the same packet to
about two seconds without relaxing strict replay. Adversarial fixtures proved that malformed
checkpoints, replaced files, complete-row truncation, undeclared ledger nodes, retry routes,
and pre-verifier promotion all fail closed.

The self-hosted run then supplied evidence unavailable to unit tests: late worker commits can
appear after the integrator merges an earlier verified tip; cleanup is a post-commit maintenance
phase and cannot be allowed to erase the durable GO boundary; and a supervisor needs a specific
post-promotion recovery transaction rather than replaying a now-invalid completed subgoal.
Cycle 4 should therefore exercise contract-v2 rehearsal through the real supervisor and tighten
observer/report semantics before declaring the walk-away loop complete.
