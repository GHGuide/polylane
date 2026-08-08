# Phase 4c — Skill / GitHub-repo suggestions

After the outcome profile is locked, select installed skills by each lane's artifact,
activity, and evidence mode. Ecosystem results are suggestions only—never automatic
installation or executable defaults. A third-party skill runs in your context =
prompt-injection + supply-chain surface; the user approves each after review.

## Step 1 — inventory installed skills
The available-skills list in the session context + `~/.claude/skills/` + `<project>/.claude/skills/` + `.agents/skills/`. Map installed skills to lanes first; only search the web for genuine gaps.

## Step 2 — refresh from the ecosystem (WebSearch, don't trust this list as current)
Curated indexes (search these for the lane's task type):
- `obra/superpowers` — the core battle-tested library (TDD, debugging, worktrees, code-review, subagent-driven-dev). Install via its marketplace: `/plugin marketplace add obra/superpowers-marketplace`.
- `travisvn/awesome-claude-skills`, `ComposioHQ/awesome-claude-skills` (1000+), `BehiSecc/awesome-claude-skills`, `awesome-skills.com` — discovery lists.
- Query form: `WebSearch "claude code skill <task type> github 2026"` and cross-check against an awesome-list before recommending.

## Step 3 — known-useful mappings (starting points, verify current before recommending)
| Lane task type | Candidate skill/repo | Purpose |
|---|---|---|
| Any dev workflow | obra/superpowers | TDD, systematic-debugging, writing-plans, verification, worktrees, code-review |
| Artifact or evidence need | Candidate skill/repo | Purpose |
| Document, presentation, spreadsheet, or media | official document/PDF/PPTX/XLSX/media skill | produce the owned artifact |
| Dataset, notebook, model, or analysis | data-validation/reproducibility/statistical-review skill | verify samples, quality, or backtests |
| Operations runbook | incident/change-safety skill | tabletop or dry-run evidence without live intervention |
| Content campaign | editorial/brand/link-check skill | review publication-ready artifacts without publishing |
| Software specialization | frontend/design, security, MCP, or platform skill | source/build/test/UI evidence when applicable |
| Token efficiency | caveman | compressed output mode (~75% fewer output tokens) |
| Codebase Q&A | graphify | knowledge-graph over the repo for navigation |

## Step 3.5 — always-on set (assume/recommend for every round)
`superpowers` (verification, debugging, plans), `caveman` (token efficiency), `graphify` (navigation when `graphify-out/` exists). If any is missing, put it at the TOP of the suggestion list with its install command.

## Step 4 — present the suggestion list
Format each: `- <name> — <artifact/activity/evidence contribution> — install: <command>` grouped by lane. Mark already-installed ones ✓. End with: "Approve which to install; I recommend none run without you eyeballing the repo first." Do not gate prompts on installs or name a suggestion as an executable skill.
