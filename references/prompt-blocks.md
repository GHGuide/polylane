# Reusable prompt blocks (compose these into each lane prompt)

Fill `<...>` slots from recon + derivation. Keep blocks verbatim otherwise — they encode hard-won rules.

## 0. MANDATORY skill preamble — ALWAYS in EVERY lane prompt, in this order
These four are non-negotiable in every generated prompt:
```
Before anything else, in order:
1. /graphify-auto                              # free graph refresh (then query via q.py — see block E)
2. Invoke the caveman skill (full)             # terse output, ~75% fewer output tokens
3. /goal <one-line lock of THIS lane's goal>   # Anthropic built-in: set the objective, keep working until it's met; do not re-scope. (The GOAL block below documents the same lock in-prompt.)
4. superpowers:using-superpowers               # then this lane's specific superpowers (block D)
```
All four are real on this install (graphify + caveman + superpowers skills; /goal built-in command). The caveman LEVEL in step 2 follows the round's intensity — write `(ultra)` when the round is `economy`, `(full)` otherwise (per `model-selection.md`); the step itself is never dropped or reordered. Fallbacks only if a project genuinely lacks one: caveman → the terse instruction in block C; graphify → the Explore-agent fallback in block E. Never omit the intent.

## A. Identity + context
```
Project: <PROJECT one-liner>. Read THIS project's CLAUDE.md and memory/MEMORY.md first. IGNORE any unrelated CLAUDE.md from other projects. YOUR LANE = <LANE NAME>. Other Claudes run <other lanes> in parallel — do NOT touch their files.
```

## B. Model + effort header
```
Run on <MODEL> at <EFFORT> effort: confirm with /model, ultrathink before non-trivial steps.
```

## C. Terse output (token efficiency) — ALWAYS (block 0 already invokes the caveman skill; this is the wording + fallback)
```
Keep output terse (caveman-style: drop articles/filler/hedging, fragments OK). Write code, commits, and PRs in normal prose. Act when you have enough information; do not re-derive settled facts or narrate options you won't pursue.
```

## D. Skills for this lane
```
Invoke: superpowers:using-superpowers, then <lane skills>. Your goal is LOCKED (below) — do NOT open superpowers:brainstorming; go straight to writing-plans/execution.
```
Lane-skill map: debugging/fix → `systematic-debugging` + `verification-before-completion`; build → `writing-plans` + `test-driven-development` + `verification-before-completion`; UI → design skills + `/design-critique`; anything → `verification-before-completion`.

## E. Graphify-first (navigation) — MANDATORY, blocking Step 1 when graphify-out/ exists
```
STEP 1 (before ANY Read/Grep): run /graphify-auto (free AST refresh), then build a map of your subsystem by QUERYING the graph with the helper — do NOT grep to discover where things are:
  python graphify-out/q.py <symbol>           # find nodes -> file:line + community
  python graphify-out/q.py callers <symbol>   # who points AT it
  python graphify-out/q.py uses <symbol>      # what it points to
  python graphify-out/q.py near <symbol>      # both directions
  python graphify-out/q.py file <path-sub>    # nodes defined in a file
Query every key symbol in your OWN file set + the shared-file boundary, print the resulting map, and work from it. Each result gives file:line so you can do a TARGETED Read only when you truly need the source. Use Grep/Glob ONLY to confirm an exact string right before an edit — never to find where code lives.
```
If `graphify-out/q.py` is absent: substitute one read-only Explore agent to map the subsystem before editing.

## F. File ownership
```
YOU OWN (edit only these): <OWN globs>
FORBIDDEN (other lanes own — do not edit/refactor): <FORBIDDEN globs>
HARD CONTRACT: <frozen public APIs>. If you need a change in a file you don't own, log the request in docs/parallel-status.md addressed to the owning lane; do NOT edit it.
```

## G. Forced verification (no done without proof)
```
VERIFY with evidence — no claim without it. Write docs/verify-<lane>.md containing: <lane-appropriate evidence>. Never say "done"/"works"/"looks good" without the artifact in that file. <For UI: preview_start + screenshots. For device: build/install/log. For logic: test output.>
```

## H. Coordination + resource mutex
```
Use docs/parallel-status.md ONLY for cross-lane requests: a shared-file edit ask addressed to the owning lane, or a NEEDS DECISION: line if you hit a fork only the user can resolve (then continue other work, don't stall). It is not a general status log and not the done signal. <If shared resource:> Before using <device/DB/deploy>, claim it in docs/parallel-status.md: append "IN USE — @<lane> <time>"; release when done. Never use it while another lane holds it.
```

## I. Scoped git
```
Commit often. Stage ONLY your paths (git add <your files>) — NEVER git add -A or git add . (scope every add to your own paths; on a shared tree you'd sweep other lanes' staged work). On index.lock, wait + retry.
```

## J. Done checklist
```
DONE = all true: <per-lane observable criteria> + docs/verify-<lane>.md has proof + docs/status-<lane>.md written with first line `STATUS: <lane> DONE` + no new errors. Drive with the skills; no generic output.
```

## Integrator lane (append when used)
Compose A/B(top non-Fable available, xhigh — the integrator role clamp in `model-selection.md`)/C/E + a merge-build-install-verify-critic body:
- **Re-merge current HEADs first — never trust a prior GO.** For each lane branch, merge its CURRENT tip; if a prior GO exists but commits followed it, it's stale — re-verify from scratch.
- Read all verify-*.md + status, build everything together, run cross-lane end-to-end checks WITH evidence, list what's missing/unverified/regressed, write docs/verify-integration.md with GO/NO-GO. Fix only cross-lane regressions, each logged in status.
- **Ensemble verdict — never a single-judge GO (self-consistency).** Before deciding, dispatch an ODD number of INDEPENDENT verifier subagents (≥3) — each judges GO/NO-GO from the merged tree + evidence on its own, and at least ONE is adversarial (told to REFUTE the GO: hunt for the regression that makes this NO-GO). The verdict is the MAJORITY vote; a tie, or any adversarial refutation the others can't rebut with evidence, resolves to **NO-GO** (safe default). Record each verifier's vote + one-line reason in docs/verify-integration.md, then set the sentinel to the majority. This is what kills a flukey false-GO.
- **End docs/verify-integration.md with the verdict sentinel on its OWN line, EXACTLY** `POLYLANE-VERDICT: GO` (or `POLYLANE-VERDICT: NO-GO`). The runner's merge gate reads this line — prose that merely mentions "GO"/"NO-GO", or a stray fixture file, can no longer flip the gate. `git commit` verify-integration.md in your worktree so the evidence survives cleanup.
- **Batch the human device/voice/visual sign-off here** (diff-aware — only re-verify surfaces changed since last sign-off; note each re-install invalidates prior voice/visual proof).
- **On GO: run merge + cleanup** (references/merge-and-cleanup.md) — verify each branch merged, `git worktree remove` merged worktrees, `git branch -d` merged branches, MOVE strays/duplicates into `<project>-useless/` (never rm, never touch the main tree's uncommitted work or the harness cwd). Leave one project folder. If auto-mode blocks a destructive step, hand the user the exact commands.
- Stage only docs/verify-integration.md + logged glue fixes.
