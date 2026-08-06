# Ultimate goal
polylane is production-grade: a stranger can clone it, install both skills (Claude Code +
Codex), pass doctor, and complete a flawless first run — with every advertised feature
actually working, proven by executable checks, live canaries, and a real self-run.

## Success criteria
- c1 Fresh-clone install works for BOTH platforms from a clean environment (no repo-local state).
- c2 Full test suite green AND every script shellcheck-clean.
- c3 Live rehearse canary passes BOTH cases (GO promotes, NO-GO gates) via doctor --rehearse.
- c4 Docs match reality: README quickstart + AGENTS.md commands all executable as written.
- c5 A real 2-lane self-run (Claude agent) completes to GO end-to-end unattended.
- c6 Recovery recreates missing panes, recognizes inactive agents, and delegates host-only
  verification to the coordinator without repeated model work.
- c7 Reports retain cumulative token, wall-time, restart, terminal-gate, and cleanup evidence
  across every supervisor resume; unknown measurements are never rendered as zero.
- c8 Every builder receives the ultimate goal, its exact sub-goal, a writable lane-local check
  cache, and only the selected relevant skills—never a broad skill-inventory reading task.
- c9 The 64-lane/10,000-event graph packet stays within its frozen dual-jq budget and a fresh
  efficiency canary reaches GO with zero manual intervention and clean teardown.
