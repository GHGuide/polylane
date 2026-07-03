# Phase 4c — Skill / GitHub-repo suggestions

After the spec is locked, for each lane's task type: (1) check what's already installed, (2) fill gaps from the ecosystem, (3) present a suggestion list. RECOMMEND ONLY — never auto-install. A third-party skill runs in your context = prompt-injection + supply-chain surface; the user approves each, ideally after eyeballing the source.

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
| Frontend/UI | frontend-design, design skills, web-artifacts-builder | non-generic UI, React/Tailwind/shadcn artifacts |
| iOS / device | ios-simulator-skill | build/navigate/test iOS apps via automation |
| Security / audit | Trail of Bits security skills | static analysis, variant analysis, vuln detection |
| MCP / tooling | mcp-builder | build MCP servers/clients |
| Docs output | docx / pdf / pptx / xlsx (Anthropic official) | generate formatted deliverables |
| Token efficiency | caveman | compressed output mode (~75% fewer output tokens) |
| Codebase Q&A | graphify | knowledge-graph over the repo for navigation |

## Step 3.5 — always-on set (assume/recommend for every round)
`superpowers` (verification, debugging, plans), `caveman` (token efficiency), `graphify` (navigation when `graphify-out/` exists). If any is missing, put it at the TOP of the suggestion list with its install command.

## Step 4 — present the suggestion list
Format each: `- <name> — <why it helps THIS build> — install: <command>` grouped by lane. Mark already-installed ones ✓. End with: "Approve which to install; I recommend none run without you eyeballing the repo first." Do not gate prompt generation on installs — the prompts reference skills by name and work once installed.
