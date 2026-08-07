STATUS: context-query DONE run=prime-c11-20260807T103930Z

Delivered deterministic `refresh`, `query`, and `packet` commands in
`bin/polylane-context.sh`. Packets use a closed durable-document allowlist,
bounded source collection and max-state projection, inspectable term/recency
ranking, caller-enforced byte limits, source/section attribution, and a
deterministic checksum manifest. Optional absent sources and source limits are
reported; unsafe roots, output paths, budgets, workers, and secret-like source
names are rejected.

Verification: `bash tests/test-context.sh`, `bash -n bin/polylane-context.sh`,
and ShellCheck warning mode all passed. See `docs/verify-context-query.md`.
