# Cycle 8 research — measuring current-run Codex usage correctly

The final canary initially reported tokens as unknown even though each pane log contained a valid
`turn.completed.usage` object. The old parser fed the complete transcript to `jq -s`; non-JSON MCP
and marketplace warnings made the entire parse fail. Reused lane names made a naive noise-tolerant
parser unsafe because logs are append-only across cycles.

The corrected design uses two boundaries. Before a fresh process is seeded, the runner records the
current log byte offset in run-scoped telemetry. Final capture parses only valid JSON lines after
that offset. As a fallback for an unbaselined legacy run, it keeps only the trailing completion
records matching this run's launch/restart count. A regression combines historical turns, warning
text, a shell prompt, and one current turn; only the current 11 tokens are counted.
