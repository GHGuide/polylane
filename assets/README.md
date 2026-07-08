# assets/ — graphify query helpers polylane installs into target projects

- `q.py` — graph query CLI (`<term>` | `callers` | `uses` | `near` | `file` | `community`;
  flags `--json`, `--graph`, `--cap`). Prints `id [label] file:line (cN)`; typos get a
  fuzzy "did you mean" list. Installed to `<project>/graphify-out/q.py`.
- `graphify-nudge.sh` — non-blocking PreToolUse(Grep|Glob) hook that reminds Claude to
  query the graph instead of grepping. Always exits 0. Installed to `<project>/.claude/hooks/`.
- `settings-hook-snippet.json` — hook registration the user merges into
  `<project>/.claude/settings.json` (lanes skill can't write it under auto-mode).
