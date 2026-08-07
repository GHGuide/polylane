# Cycle 11 questions — emergent decisions

No critical question requires user input before completion. The implementation and live evidence selected conservative defaults for the relevant questions:

- **Should repeated evidence directly edit the harness?** No. It enters a deduplicated queue; the integrator must propose a bounded check-backed change or explicitly decline it.
- **Should a decline permanently suppress a subject?** No. It handles only the observations seen at that decision boundary; new evidence reopens the subject.
- **Should a local refinement validate immediately?** No. It must survive its declared expected check in a later cycle or roll back.
- **Should global prompt or skill learning use the local refinement path?** No. It remains an inactive handoff to the frozen skill-evolution challenger gate.
- **Should workers receive all durable history?** No. They receive one source-attributed hard-bounded packet, then use the acknowledged inbox for follow-ups.
- **Should worker continuity depend on a live pane or chat session?** No. Stable identity and the canonical capsule survive process replacement.
- **Should recovery trust a remembered tmux pane index?** No. Canonical worktree identity wins; counters migrate to the pane currently attached to that worktree.
- **Should terminal-gate telemetry increment after proof capture?** No. READY boundaries count before their efficiency certificate; direct GO counts only when terminal checks run.
- **Should future research keep the autonomous loop alive after all checks pass?** No. Record it as informational and stop until a new goal or failure appears.

Every decision can be reopened through deeper discovery when new evidence materially changes the tradeoff. None blocks this completed cycle.
