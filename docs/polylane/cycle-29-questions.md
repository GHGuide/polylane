# Cycle 29 emergent questions

These questions are informational and do not block safe autonomous continuation into the fresh Cycle 30 certificate.

1. Should active-command state be checkpointed instead of recomputed from the append-only log?
   - Recommended: keep the streaming reducer until profiling shows a real CPU bottleneck; it is memory-bounded and source-authoritative.
   - Alternative: maintain a runner-owned per-lane active-ID checkpoint with log-offset recovery.
   - Go deeper next round: benchmark both approaches against multi-hour logs with interruptions and malformed warning records.
2. How should exploratory files relate to exact `planned_writes`?
   - Recommended: keep exact expected paths for admission and allow discoveries only inside the already bounded `own_globs`, with the final scope gate authoritative.
   - Alternative: require a new nonce-bound plan whenever an unplanned owned file becomes necessary.
   - Go deeper next round: measure planned-write recall across software, research, data, content, and operations projects.
3. Should a terminal scope failure emit a separate machine-readable receipt?
   - Recommended: first consume the existing bounded failure reason in reports; add a new artifact only if operators need structured aggregation.
   - Alternative: write one runner-owned JSON receipt keyed by run, lane, tip, and offending paths.
   - Go deeper next round: test report and control-room consumers against both representations.
4. Should the 14,400-second default hard cap vary by provider or model tier?
   - Recommended: keep one finite default with an explicit operator override until accepted telemetry supports a safer percentile.
   - Alternative: provider-specific finite ceilings declared in the manifest.
   - Go deeper next round: derive p95/p99 quiet-turn durations from accepted runs without treating cached or historical logs as current evidence.
