# Cycle 43 council — recover by import; fix the harness in flight

The council's judgement across the cycle, recorded after the fact from the
decisions actually taken:

- **Import, never trust stale automation.** Only the immutable `4851bc1` handoff
  carried verified content; the WIP checkpoints created by quota-starved
  auto-retries above it were not a promotable lineage.
- **Port, never overwrite.** Main gained auth preflight, login parking, paywall
  detection and model-detection fixes *after* the handoff. A wholesale
  restoration of the candidate's runner would have reintroduced exactly the
  failure modes that stranded cycle 42A.
- **Fix the harness where it breaks, but stop the treadmill.** Each mid-flight
  runner fix invalidated the candidate merge and cost a re-run. After four
  attempts the coordinator froze `bin/polylane-run.sh` for the duration of the
  promotion attempt and recorded further findings instead of patching.
- **The frozen acceptance is the authority, not the coordinator's judgement.**
  When the host completed the promotion, it re-ran m32.6's frozen acceptance on
  the merged tree and stamped the subgoal only on that result.
