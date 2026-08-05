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
