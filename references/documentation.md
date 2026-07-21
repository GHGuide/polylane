# Documentation — keep context current, keep it tight

The built app must stay understandable to a FRESH agent (or the next polylane run) with
zero prior conversation. That's what these docs are for. The research is blunt: **bloated,
LLM-generated context files HURT** (measured −3% task success, +20% cost) — so every doc
here is short, specific, and human-curated. A few sharp sections beat a wall of prose.

## The one file that matters most: `AGENTS.md` at the built-app root
The 2026 cross-agent standard — Claude Code, Codex, and others all read it. polylane
writes it at strategy-lock and REFRESHES it every cycle (a living spec, not stale docs).
Keep it to these sections, each a few tight lines:
- **Mission** — the north-star one-liner (the why). From `NORTHSTAR.md`.
- **Stack + key decisions** — the chosen tech + the pivotal calls a new agent must not
  re-litigate. From the decision records (`polylane-decision.sh … context`).
- **Run / build / test** — the REAL commands, verified to work (not guessed). This is the
  single highest-value thing an agent needs and can't infer.
- **Conventions** — only the non-obvious rules (naming, structure) worth stating.
- **Status** — what's done · what's next (one line each, from the goal tree `dump`).
Specific over vague ("Vitest, `npm test`, 2-space, named exports" not "write good code"),
and say WHY for any hard rule. If a section would be generic filler, cut it.

Claude Code also reads `CLAUDE.md`; if the project wants both, make `CLAUDE.md` a one-line
pointer to `AGENTS.md` (single source, no drift) — don't maintain two copies.

## `docs/polylane/INDEX.md` — the home MOC (vault pattern: one front page, links over folders)
Obsidian-vault practice, applied: a knowledge base is navigated through ONE "map of
content" front page + links, never deep folders. `docs/polylane/INDEX.md` is that page —
the FIRST file a fresh agent (or the resume path) reads. Keep it a plain linked list,
a few lines per entry, refreshed in Phase 5 alongside AGENTS.md:
```
# <project> — polylane index
Vision: [NORTHSTAR](NORTHSTAR.md) · Strategy: [STRATEGY](STRATEGY.md) · Goal: [ULTIMATE_GOAL](ULTIMATE_GOAL.md)
Decisions: [decisions/INDEX.md](decisions/INDEX.md) — do not contradict
State: max-state.json (tree; query via polylane-memory.sh) · Story so far: [corpus](corpus.md)
Cycles: [c1 digest](cycle-1-digest.md) · [c1 research](cycle-1-research.md) · …latest first
```
**Link habit (atomic notes + backlinks):** every doc is atomic (one decision per file, one
cycle per digest) and CROSS-LINKS its relatives with relative markdown links — a digest
links the decisions it produced; a decision links the digest that motivated it. The
council/harvest then FOLLOW links instead of globbing the directory. Links replace both
folders and duplication; if a fact is needed twice, link it, never restate it.

## The polylane working docs (under `docs/polylane/`) — roles, not duplication
- `STRATEGY.md` — the locked product strategy. **Update it FIRST when scope changes**, then
  build (spec-first; the tree + AGENTS.md follow from it).
- `NORTHSTAR.md` — vision · the one thing · anti-goals. The anchor injected into every lane.
- `decisions/` — one file per BIG decision (what · why · consequences). The "don't contradict".
- `max-state.json` — the goal tree + blackboard (machine state, not prose).
- `cycle-<N>-digest.md` — what each cycle built (the record; the chat gets one paragraph).
- `corpus.md` — the bounded "story so far" the council/research read (recent verbatim,
  older one-lined) so long runs stay context-bounded.
Each has ONE job. Never restate the same fact in two of them — cross-reference instead.

## Living, not archival
Update the spec (STRATEGY + tree) and `AGENTS.md` as part of closing each cycle (Phase 5),
BEFORE the next build. A doc that lies is worse than no doc — if a run invalidates a
decision, edit the record + log the change, don't leave the old claim standing.
