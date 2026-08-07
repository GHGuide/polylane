# Strategy

Polylane stays a small Bash 3.2, jq, git, and tmux harness. It adopts the useful
runtime invariants of long-lived RLM agents without replacing isolated worktrees,
the execution graph, frozen acceptance, or evidence-gated promotion.

The durable control plane has three layers:

1. The goal tree and frozen acceptance remain the authority for product completion.
2. A continual harness records small local prompt, memory, skill-routing, and worker-role
   refinements. Local changes may help the current run immediately; global prompt or skill
   changes are proposals until the existing champion/challenger evolution gate promotes them.
3. Persistent worker capsules, an append-only inbox, and a bounded context-query packet let a
   later cycle resume useful expertise without replaying an unbounded transcript.

Every refinement names evidence, an expected measurable outcome, and a validation deadline.
An unvalidated or regressing change is rolled back. The system optimizes verified product
criteria, not lane prose, model confidence, or activity volume.
