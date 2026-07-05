# Verify — integration lane (reconcile SKILL.md, re-merge HEADs, GO/NO-GO)

Lane = **integrator** (runs last). Model Opus 4.8, XHIGH effort. Caveman full.
Goal (LOCKED): re-merge current HEADs, cross-check SKILL.md vs what lanes 1–5 shipped,
smoke-test, issue GO/NO-GO. Nothing else.

Every claim below carries a quoted artifact. No trust of prior lane GO — re-verified from HEAD `5e060ee`.

---

## 0. Re-merge status — all lane work on ONE branch, 0 commits at risk

No lane branches, no worktrees, no stray dirs. All 5 lanes committed directly to `main`.

```
$ git branch -a          → * main   remotes/origin/main         (no lane branches)
$ git worktree list      → /Users/leonardo/Downloads/polylane  5e060ee [main]   (only)
$ ls -d .../polylane*    → /Users/leonardo/Downloads/polylane   (one folder, no strays)
$ git log origin/main..HEAD
  5e060ee harden q.py graph-query CLI + tighten graphify nudge hook   (graph-tooling / Lane-1+5)
  1b7ac00 prompt-gen: tighten prompt-generation core                  (prompt-gen  / Lane-4)
  f53b9e9 docs: make lane-count math concrete + confirm model table   (derivation  / Lane-3 + workflow files*)
  9fe1edb evals: expand polylane eval set with trigger + behavior      (evals       / Lane-2)
```

Per-lane merged status (from `docs/parallel-status.md`, all self-report DONE, all present on HEAD):

| Lane | Owner files | Status | On main? |
|---|---|---|---|
| evals (Lane-2) | `evals/evals.json` | DONE | ✓ 9fe1edb |
| derivation (Lane-3) | `references/lane-derivation.md`, `references/model-selection.md` | DONE | ✓ f53b9e9 |
| process-docs / workflow | `references/{install-helpers,merge-and-cleanup,skill-catalog}.md`, `README.md`, `docs/verify-workflow.md` | DONE | ✓ f53b9e9* |
| prompt-gen (Lane-4) | `references/{prompt-blocks,lane-template,interview}.md` | DONE | ✓ 1b7ac00 |
| graph-tooling (Lane-1/5) | `assets/{q.py,graphify-nudge.sh,settings-hook-snippet.json}` | DONE | ✓ 5e060ee |

*Shared-index race disclosed by derivation lane: f53b9e9 co-committed the workflow lane's
already-staged files (install-helpers, merge-and-cleanup, verify-workflow). Verified content is
the workflow lane's own, unmodified, present on HEAD. **No loss, no drift.** History not rewritten.

**→ 0 commits at risk. Re-merge complete (nothing to merge; all consolidated).**

---

## 1. Cross-checks — HARD CONTRACT (each quoted, zero contradiction)

### CC-0 · Mandatory-4 preamble order (SKILL ↔ prompt-blocks Lane-4 ↔ evals Lane-2)

Contract: `1) /graphify-auto · 2) caveman(full) · 3) /goal <lane goal> · 4) superpowers:using-superpowers`.

```
SKILL.md:42        `/graphify-auto` · caveman (full) · `/goal <lane goal>` · `superpowers:using-superpowers`
SKILL.md:36        1) `/graphify-auto`, 2) caveman skill (full), 3) `/goal <one-line lane goal>` ..., 4) `superpowers:using-superpowers`
prompt-blocks.md#0 1. /graphify-auto  2. Invoke the caveman skill (full)  3. /goal <...>  4. superpowers:using-superpowers
evals behavior_preamble_mandatory_four → "in order: 1) /graphify-auto, 2) caveman skill (full), 3) /goal <one-line lane goal>, 4) superpowers:using-superpowers"
```
**MATCH — identical order in all 3. No drift.**

### CC-1 · q.py subcommands (Lane-1) ↔ Block E (Lane-4) ↔ SKILL

```
assets/q.py:32   COMMANDS = ("callers", "uses", "near", "file", "community")   + default `q.py <symbol>` search (:220)
prompt-blocks.md Block E lists: q.py <symbol> (default), callers, uses, near, file
SKILL.md:25      query via `python graphify-out/q.py <symbol>`
```
Block E names 4 subcommands + default — **every one exists in q.py's dispatch exactly**.
`community` is a real extra in q.py, **deliberately omitted** from the curated Block E (contract = 4 + default). No rename, no removal. **MATCH.**

### CC-2 · Model IDs (Lane-3) ↔ SKILL non-negotiables

```
references/model-selection.md → claude-fable-5 · claude-opus-4-8 · claude-haiku-4-5 ; tiers low/medium/high/xhigh/max
SKILL.md:3   "...tunes model + effort per lane (Fable/Opus)..."
SKILL.md:29  "(Fable 5 vs Opus 4.8, effort level, token-efficiency rules)"
```
SKILL carries model *names* only (no raw IDs to drift); "Fable 5 / Opus 4.8" is consistent with the frozen IDs. Effort tiers used in SKILL (`effort`, `low`) are within the frozen tier set. **No contradiction. MATCH.**

### CC-3 · Asset names (Lane-1/5) ↔ SKILL ↔ install-helpers

```
$ ls assets/                → graphify-nudge.sh  q.py  settings-hook-snippet.json
SKILL.md:23                 → assets/q.py · assets/graphify-nudge.sh · assets/settings-hook-snippet.json
references/install-helpers  → assets/q.py · assets/graphify-nudge.sh · assets/settings-hook-snippet.json
```
**Three-way exact match. No rename, nothing to log for owning lane.**

### CC-4 · Trigger phrases (Lane-2 evals) ↔ SKILL description

```
SKILL.md desc  → "/polylane", "/lanes", "split this into prompts", "parallel terminals", "make lane prompts", "orchestrate builders"
evals.json trigger_phrases → ['/polylane', '/lanes', 'split this into prompts', 'parallel terminals', 'make lane prompts', 'orchestrate builders']
```
**6 = 6, exact strings. MATCH.**

### CC-5 · Drift fix landed (Lane-4)

```
$ grep -rn 'LeLau' SKILL.md README.md references/   → CLEAN: no LeLau
prompt-blocks.md Block A opener → "Project: <PROJECT one-liner>. Read THIS project's CLAUDE.md..."
```
Garbled `LeLau-agnostic:` token gone; block A opens clean. **Fixed on HEAD.**

---

## 2. Smoke tests (goal 3) — all pass

```
$ python3 -c "json.load(open('evals/evals.json'))"     → VALID JSON; cases: 17 ; triggers: 6
$ bash -n assets/graphify-nudge.sh                       → bash -n OK exit=0
$ python3 graphify-out/q.py load                         → 2 matches, file:line+community, (graph@5e060eea)
$ python3 graphify-out/q.py callers load                 → CALLERS (1): contains assets_graphify_nudge :1 (c16)
$ python3 graphify-out/q.py community 0                  → community 0: 16 nodes, listed
```
Graph queried is HEAD's own AST graph `graph@5e060eea` (matches commit 5e060ee). **All pass.**

---

## 3. Missing / unverified / regressed

- **Missing:** none. All 6 description triggers covered; all 5 subcommands live; all 3 assets present.
- **Unverified (out of scope, not blocking):** live skill-activation behavior of evals cases (static JSON only — eval *runner* not exercised); actual `/goal` built-in and third-party skill installs are runtime, not testable here.
- **Regressed:** none. No cross-file contradiction found; SKILL.md required **no edit** (smallest-change — zero inconsistency to fix).
- **Environment note:** during this run the data volume hit ENOSPC (0 bytes free); user freed space; all verification above had already completed and was re-confirmed. `graphify-out/` is an untracked build artifact (not gitignored, but never staged — integrator stages only SKILL.md + this file). Leave untracked.

---

## VERDICT: **GO**

All lane work consolidated on `main` (0 commits at risk). Five cross-checks + mandatory-4 order
+ drift-fix all pass with quoted evidence — zero contradiction. Three smoke tests green.
SKILL.md is self-consistent with everything lanes 1–5 shipped. No NO-GO condition found.
