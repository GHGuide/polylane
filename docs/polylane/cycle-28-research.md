# Cycle 28 research — recover the false watchdog halt truthfully

Cycle 27's source repair completed after the runner had already published an
immutable `HALTED` report. The preserved runner process loaded the pre-repair
watchdog and classified the still-live high-effort Codex integrator as wedged after
40 quiet health checks. Its agent process remained alive, later finished normally,
and committed exact READY tip `38ee3fa8bd0720d02755d2f3215f9bd936a17a78`.
Cycle 28 starts from that late tip without rewriting or claiming Cycle 27 GO.

The failure is a policy bug, not merely a slow host. `pane_wedged` gives a live
high-effort turn only 40 checks. At the Cycle 27 ten-second health interval this is
about 400 seconds, shorter than legitimate high-effort synthesis. The corresponding
regression test explicitly requires recovery at that old threshold. The production
repair must use time-based effort tiers, protect a latest `turn.started` boundary,
retain a finite hard cap, preserve the short post-terminal recovery path, and remain
compatible with an explicit operator extension.

The HALTED report compounds the error by rendering every `FAILED_LANES` row as
`errored after retries` and always recommending provider-status recovery. Runtime
failures can instead be a live-turn silence cap, missing pane, dead process, usage
limit, or material-progress exhaustion. The exact bounded reason must survive until
report publication and drive both the lane row and next-step text.

Cycle 27 telemetry also exposed a presentation problem. Codex reported 12,201,803
input tokens for the builder, but 11,948,288 were cached; output was 42,842. The
current run-stat helper collapses input plus output into one undifferentiated total,
making a mostly cached workload look like equally expensive fresh context. Durable
accounting should preserve the legacy total while separately summing input, cached
input, derived uncached input, output, and reasoning output from each unseen current-
run completion exactly once.

Finally, panes intentionally use `POLYLANE_PROJECT_ROOT` for canonical coordination
state even though their writable source is the isolated worktree. That overloaded
name caused workers to search the control root for `graphify-out/q.py` and retry
several invalid paths. Every pane should also receive `POLYLANE_SOURCE_ROOT`, and the
compiled prompt should explain the split and give one source-root Graphify query
contract. Coordination, workers, harness, and acceptance evidence remain rooted to
the canonical control root.

The free Graphify policy correctly declined a mixed code/docs rebuild rather than
spend model tokens. Cycle 28 reuses the same-repository Cycle 27 graph as a read-only
navigation cache, then verifies every changed symbol directly against source. It
does not treat stale graph line numbers as authority.
