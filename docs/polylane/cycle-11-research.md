# Cycle 11 research — safe inner learning under an outer frozen gate

## Conclusion

The useful part of an RLM-style coding harness is not unrestricted self-editing. It is a fast inner loop that retains small typed memories, routes repeated failures into bounded experiments, and measures the next cycle against a check declared before activation. Polylane's outer execution graph, frozen acceptance, independent judges, and skill-evolution corpus remain authoritative. This separation gains adaptation without allowing the system to rewrite what “success” means.

## Findings

1. **Learning needs a signal-specific observation boundary.** A repeated signal is queued only when that signal kind's observation count exceeds the most recently proposed or declined boundary. This prevents one unrelated observation from reopening handled evidence while allowing genuinely new repeated evidence to reopen a subject.
2. **Declining is a first-class autonomous decision.** Forcing every observation into a code change rewards churn. A concrete decline is durable evidence that the integrator reviewed the signal and found no bounded improvement worth promoting.
3. **Expected checks must precede activation.** A local refinement declares its executable check and deadline before changing active harness state. Later-cycle failure or expiry restores the exact prior snapshot.
4. **Global learning needs a stronger gate than local learning.** Prompt and skill candidates can affect every future lane, so they stay inactive until the isolated challenger corpus, hidden cases, independent judges, token bounds, and canary rollback approve them.
5. **Long context is storage, not prompt content.** Durable documents may grow; each worker still receives one deterministic byte-bounded packet with source labels, the goal, the active subgoal, its capsule, and pending inbox items.
6. **Worker identity is semantic, not conversational.** A stable name plus versioned capsule survives pane replacement and cycle boundaries. The live process can die without erasing what the next process must know.
7. **Tmux pane numbers are locators, not identities.** Pane indices can change after a neighbor exits. Recovery must resolve the canonical worktree, rebind the surviving pane, and migrate all pane-indexed health counters before considering a respawn.
8. **Telemetry belongs at the boundary it grades.** READY efficiency proof checks that exactly one host gate is in progress, so the counter must increment before proof capture. Direct GO paths count only when terminal checks are actually reached.

## Future experiments

- Measure whether retained capsules reduce re-derivation tokens across several real product runs.
- Compare propose-versus-decline rates and later validation outcomes before tuning eligibility.
- Add more context sources only when a benchmark shows a specific missing-evidence failure.
- Accumulate enough refinement outcomes to rank recurring local changes by measured usefulness.
- Exercise pane rebind and worker resume behavior on Linux tmux and Bash implementations.

These are informational experiments. They do not keep the completed goal open.
