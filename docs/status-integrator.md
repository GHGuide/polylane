STATUS: integrator DONE

Re-merged current HEADs of lane/intensity-model, lane/planner-wiring,
lane/schema-runner, lane/runner-docs into main — 0 conflicts, 0 commits at risk.
5 hard contracts cross-checked with quoted lines from the merged tree: zero
contradiction. Runner + probe helper smoke-tested on merged main (incl. the
no-ANTHROPIC_API_KEY curated fallback, jq-validated schema, --intensity/--model
dry-run remaps, guards). Verdict: GO. Evidence: docs/verify-integration.md.
On GO: merged, then removed the 4 lane worktrees + branches and dropped
docs/status-*.md scratch (kept docs/verify-*.md + docs/parallel-status.md).
