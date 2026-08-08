# Documentation — keep project context current and reproducible

Every repository-backed project must be understandable to a fresh agent or handoff
without the old conversation. Keep docs short, specific, linked, and truthful: a
compact operating record is better than generic prose.

## Root operating instructions

Create or refresh `AGENTS.md` at the project root as the cross-agent entry point:

- **Mission and profile** — outcome and selected project profile.
- **Operating instructions** — real commands or procedures to reproduce, validate,
  inspect, or safely operate the project. For software these may be run/build/test;
  for research, operations, content, or data they may be analysis, review, or handoff
  steps.
- **Key decisions and constraints** — settled calls, owners, safety boundaries, and
  non-obvious conventions.
- **Artifact provenance** — source locations, versions, licenses/rights, collection
  method, and transformations where relevant.
- **Status and handoff** — what is complete, what is next, and every external blocker.

Use verified commands and observed procedures, never guessed ones. If `CLAUDE.md` is
needed, make it a pointer to `AGENTS.md` rather than duplicate context.

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
- `PROJECT_PROFILE.md` — outcome, deliverables, stakeholders, constraints, evidence,
  risk, external actions, and finish conditions; write it before decomposition.
- `STRATEGY.md` — the locked project strategy. **Update it FIRST when scope changes**,
  then execute (profile-first; the tree + AGENTS.md follow from it).
- `NORTHSTAR.md` — outcome, intended change, and anti-goals. The anchor injected into every lane.
- `decisions/` — one file per BIG decision (what · why · consequences). The "don't contradict".
- `max-state.json` — the goal tree + blackboard (machine state, not prose).
- `cycle-<N>-digest.md` — what each cycle delivered, validated, and left external.
- `corpus.md` — the bounded "story so far" the council/research read (recent verbatim,
  older one-lined) so long runs stay context-bounded.
Each has ONE job. Never restate the same fact in two of them — cross-reference instead.

## Run handoff: canonical control snapshot

When documenting a live or completed run, cite the one-shot control room rather
than copying pane observations: `bin/polylane-dashboard.sh .polylane/run.json
--once --json`. It joins authoritative state with durable max-state, graph events,
report, spend ledger, heartbeat, and cleanup. Preserve `null`/`unknown`; a missing
fact is not zero, GO, or clean cleanup. The schema and adjacent product/discovery,
models, prompt-budget, advanced-runtime, and judge interfaces are frozen in
[cycle-9-control-room.md](cycle-9-control-room.md).

## Frozen acceptance keys

`polylane-memory.sh <state> add-accept <subgoal> <command> --key <safe-id>`
marks checks that grade the same source. In one `check-accept` invocation, the
first selected member executes and its pass/fail result is stamped onto every
later selected member with that key. The result is invocation-local: it is never
reused by a later call or a different key. Checks without a key keep their
independent behavior. Use `tag-accept <subgoal> --key <safe-id>` to add metadata
to already frozen commands without changing them. Safe IDs start with an
alphanumeric character and otherwise contain only alphanumerics, `.`, `_`, or `-`.

## Living, not archival
Update the profile, strategy, tree, provenance, and `AGENTS.md` as part of closing each
cycle, before the next execution wave. Record reproduction/validation commands, decisions,
and handoff state; a claim of external execution needs authority plus actual proof. A doc
that lies is worse than no doc—if a run invalidates a decision, edit and link the record.
