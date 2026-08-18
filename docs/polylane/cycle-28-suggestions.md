# Cycle 28 suggestions

Selected now:

1. Use installed `superpowers:systematic-debugging` in the builder to trace the false halt from turn boundary through watchdog, retry, and report.
2. Use installed `superpowers:test-driven-development` in the builder so every policy change starts with a reproducing regression.
3. Use installed `superpowers:verification-before-completion` in the integrator to require fresh focused evidence before READY.
4. Use installed `engineering:code-review` in the integrator to audit failure attribution, environment trust boundaries, and backward compatibility.
5. Install no new skill this cycle; acquisition would add unrelated code and cannot improve this focused shell repair.
6. Reuse one same-repository Graphify artifact as a zero-token navigation cache.
7. Treat direct source and tests as authoritative when graph line numbers are stale.
8. Keep one builder because watchdog, telemetry, pane environment, and report truth meet in `polylane-run.sh`.
9. Express live-turn grace in seconds and derive check counts from the configured health interval.
10. Give low, medium, high, and xhigh/max effort distinct production silence budgets.
11. Let explicit operator configuration extend a default cap but never silently shorten it.
12. Keep a finite hard cap so a truly frozen live process remains recoverable.
13. Recognize the latest `turn.started` as an in-flight boundary even after older completed turns.
14. Keep an active command exempt from silence recovery while the command is demonstrably in progress.
15. Keep a completed, failed, or errored turn on the short durable-progress recovery path.
16. Make watchdog diagnostics print the actual effective seconds, not the ordinary-pane default.
17. Store one failure reason per lane and avoid duplicate lane entries.
18. Cover missing pane, dead process, transient exit, usage exhaustion, no-progress exhaustion, and live-turn hard-cap reasons.
19. Render exact failure reasons in report rows without unsafe Markdown interpolation.
20. Stop recommending provider status pages for non-provider failures.
21. Preserve the canonical worktree and transcript when a lane halts.
22. Keep the legacy aggregate `tokens` field for compatibility.
23. Add explicit input, cached-input, uncached-input, output, and reasoning-output counters.
24. Derive uncached input as `max(input-cached, 0)` and test malformed or missing fields.
25. Count only unseen current-run completions and preserve noisy append-only log handling.
26. Surface the usage breakdown in snapshots and reports without changing spend-ledger semantics unexpectedly.
27. Export `POLYLANE_SOURCE_ROOT` as the exact isolated worktree and keep `POLYLANE_PROJECT_ROOT` canonical.
28. Inject one compact runtime-roots line into compiled prompts and lint it mechanically.
29. Tell workers to query `${POLYLANE_SOURCE_ROOT:-$PWD}/graphify-out/q.py`, never infer paths by trial and error.
30. Reserve the full suite, installers, and live rehearsal for one fresh Cycle 29 terminal gate.
