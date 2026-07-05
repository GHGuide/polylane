# verify-integration.md — integrator verdict (polylane self-upgrade)

Integrator lane. Re-merged the **current tips** of all four lane branches into
`main`, cross-checked the four frozen contracts against the real files on the
merged tree, and smoke-tested `bin/polylane-run.sh`. Every claim below is real
command output captured this run — no prior GO trusted. (Supersedes the prior
lanes-1–5 verdict now in git history at `9d8e63d`; those lanes are already in
the merge base `1f3f227`.)

Merged `main` tip after integration: **a2845df**. Merge base of every lane:
`1f3f227` (the current `main` at start — no stale prior-GO commits in play).

---

## 1. Per-lane merged status (0 commits at risk)

Each lane was 1 commit ahead of `main`, 0 behind. Merged with `git merge --no-ff`,
zero conflicts. Post-merge ancestry check:

```
lane/runner-engine:       MERGED (0 at risk)   tip d998b53  -> merge 5941340
lane/planner-integration: MERGED (0 at risk)   tip 70e0d0b  -> merge bc46ab6
lane/runner-skill:        MERGED (0 at risk)   tip cef2958  -> merge 15f1cb8
lane/docs:                MERGED (0 at risk)   tip 4b07d7d  -> merge a2845df
```

`git rev-list --count main..<lane>` = `0` for all four. All four DONE markers
present with exact first line:

```
docs/status-runner-engine.md       :: STATUS: runner-engine DONE
docs/status-planner-integration.md :: STATUS: planner-integration DONE
docs/status-runner-skill.md        :: STATUS: runner-skill DONE
docs/status-docs.md                :: STATUS: docs DONE
```

Lane self-verifications (all PASS with their own evidence): `verify-runner-engine.md`
(TDD suite `PASS=37 FAIL=0`), `verify-planner-integration.md`, `verify-runner-skill.md`,
`verify-docs.md`.

---

## 2. Frozen-contract cross-checks (quoted from merged `main`)

### Contract 1 — Manifest keys: `.polylane/SCHEMA.md` (L1) == SKILL.md Phase 6 emit (L2)

`.polylane/SCHEMA.md` (L1) defines, per lane/integrator object:

> `.polylane/SCHEMA.md:42` — "Each **lane** object (and the **integrator** object) has:"
> keys `name` · `model` · `branch` · `worktree` · `prompt_file` · `own_globs` *(lanes only)*; top-level `base` · `integrator` · `lanes[]`.

`SKILL.md` Phase 6 emits the identical schema:

> `SKILL.md:48-63` —
> `"base": ...`, `"integrator": { "name","model","branch","worktree","prompt_file" }`,
> `"lanes": [ { "name","model","branch","worktree","prompt_file","own_globs" } ]`
> `SKILL.md:69` — "The integrator object omits `own_globs` … every lane object includes it."

Engine reads exactly these keys — `bin/polylane-run.sh:137-153` (`jq -r '.base'`,
`.integrator.{name,model,branch,worktree,prompt_file}`, `.lanes[i].{name,model,branch,worktree,prompt_file}`).
**KEYS MATCH EXACTLY — PASS.**

Non-blocking note (example value, not a key): SCHEMA's illustrative JSON and
`verify-runner-engine.md` show `prompt_file` as `.polylane/prompts/<lane>.txt`,
whereas SKILL Phase 6 + `lane-template.md` emit `.polylane/lanes/<lane>.txt`. The
manifest carries the actual path and the engine `cat`s whatever path it is given
(`bin/polylane-run.sh:197` pane_cmd `cat '<prompt_file>'`), so a real run works
regardless — the divergence is a doc/example inconsistency only, not a key or
runtime break. Does not gate GO.

### Contract 2 — CLI signature: engine (L1) == polylane-run/SKILL.md (L3) == docs (L4)

> L1 `bin/polylane-run.sh:32-33` (usage) — "`bin/polylane-run.sh <manifest.json> [--dry-run] [--yes]`"; `-h,--help` → exit 0.
> L1 `.polylane/SCHEMA.md:58` — "`bin/polylane-run.sh <manifest.json> [--dry-run] [--yes]`"
> L3 `polylane-run/SKILL.md:46` — "`bin/polylane-run.sh .polylane/run.json --dry-run`"; `:54` bare launch; `:57` `--yes` optional.
> L4 `references/merge-and-cleanup.md:8` — "`bin/polylane-run.sh <manifest> [--dry-run] [--yes]`"
> L4 `references/install-helpers.md:9` — names `bin/polylane-run.sh`, defers flags to merge-and-cleanup.md (no conflicting signature).

Same program, same flags, same manifest path `.polylane/run.json`. No invented
flags anywhere. **SIGNATURE MATCHES ACROSS L1/L3/L4 — PASS.**

### Contract 3 — DONE marker `STATUS: <lane> DONE`: poller (L1) == baked prompts (L2) == docs (L4)

> L1 poller `bin/polylane-run.sh:225` — `[ "$first" = "STATUS: $name DONE" ]` on `<wt>/docs/status-<name>.md`.
> L1 `.polylane/SCHEMA.md:84-90` — first line "exactly" `STATUS: <name> DONE`.
> L2 baked prompt `references/lane-template.md:30` — "write docs/status-<lane>.md, first line EXACTLY `STATUS: <lane> DONE`"; mini-example `:103`.
> L2 `SKILL.md:38,82` — "first line is exactly `STATUS: <lane> DONE`".
> L4 `references/merge-and-cleanup.md:20` — "`docs/status-<lane>.md` with a first line `STATUS: <lane> DONE`".

**MARKER IDENTICAL ACROSS THE THREE NAMED SOURCES — PASS.**

Non-blocking note: `references/prompt-blocks.md` (a raw block library, not one of
the three named contract sources; unchanged this run; forbidden to the integrator)
block J still lists "parallel-status.md updated" as a DONE criterion and omits the
status marker. Harmless: the L2 assembler (`lane-template.md` skeleton + mini-example)
injects the `STATUS: <lane> DONE` line into every assembled prompt, and the
canonical mini-example folds the marker into its DONE line (`lane-template.md:105`).
Flagged by planner-integration itself (`verify-planner-integration.md:94`). A future
tightening, not a contract break.

### Contract 4 — Mandatory-4 preamble order unchanged

> `SKILL.md:36,75` — "1) `/graphify-auto`, 2) caveman skill (full), 3) `/goal <one-line lane goal>` …, 4) `superpowers:using-superpowers`".
> `references/lane-template.md:15,70-73` — same four, same order.

Order is unchanged from the pre-merge `main` (planner-integration touched Phase 6
wording but left the preamble list intact). **PASS.**

---

## 3. Smoke tests — `bin/polylane-run.sh` on merged `main`

Deps present: `tmux · claude · jq · git` (preflight requirement).

```
A.  bash -n bin/polylane-run.sh            -> exit 0 (syntax OK)
B.  bin/polylane-run.sh --help             -> exit 0, full usage printed
B2. bin/polylane-run.sh   (no args)        -> exit 2 (bad-args guard)
D.  SCHEMA.md documented JSON example | jq -> valid JSON (jq exit 0)
```

**C — dry-run (2-lane + integrator sample manifest, worktrees in scratchpad):**
Printed every git/tmux command prefixed `+`, then exit 0. Verified NO side effects:
`polylane` tmux sessions 0 → 0; git worktrees 5 → 5; sample integrator worktree
`wt-int` not created. Excerpt:

```
== split: 2 lane worktrees ==
+ git worktree add .../wt-api -b lane/api main
+ git worktree add .../wt-ui  -b lane/ui  main
== launch: tmux session 'polylane' ==
+ tmux new-session -d -s polylane -n api
+ tmux send-keys -t polylane cd '.../wt-api' && claude --model 'claude-opus-4-8' "$(cat '.polylane/lanes/api.txt')" || { ...clipboard fallback... } C-m
...
== cleanup ==
+ git worktree remove --force .../wt-api
+ git branch -d lane/api
+ rm -rf /Users/leonardo/Downloads/polylane/.polylane
Cleanup complete. Kept: docs/verify-*.md, docs/parallel-status.md
dry-run exit=0
```

**E — poll logic reads the real status files** (sourced the script; dry-run
short-circuits the poll, so the read path was exercised directly against fake
status files):

```
lane_done wt-api api   (first line "STATUS: api DONE")      -> exit 0   (expect 0)
lane_done wt-ui  ui    (DONE on line 2, not first)          -> exit 1   (expect 1)
lane_done nope   x     (missing file)                       -> exit 1   (expect 1)
poll_done api:wt-api ui:wt-ui  (both first lines DONE)       -> "poll: 2/2 lanes DONE", exit 0
```

First-line-exact matching confirmed: DONE on a later line does NOT satisfy the
poller. Aggregate poll returns only when all lanes' first lines match.

Post-smoke repo state: `git status` clean; no stray `lane/api|ui|integrator`
branches (dry-run creates none); 5 worktrees intact. Sample + fake files live in
the scratchpad, never the repo.

---

## 4. Missing / unverified / regressed

- **Regressions:** none. All four merges conflict-free; four hard contracts hold;
  smoke suite green.
- **Not exercised (by design — needs live agents/terminals):** a real (non-dry)
  end-to-end run that actually opens tmux panes, launches `claude`, waits on real
  builder DONE files, and performs the destructive cleanup. Dry-run + sourced
  unit-level checks + the runner-engine lane's `PASS=37` TDD suite cover the logic;
  a full live run is out of an integrator's scope and untestable without spawning
  real lane sessions.
- **Non-blocking doc nits (2), both logged above (`parallel-status.md` left frozen
  per commit `6ded401`, not touched):**
  (1) `prompt_file` example path `prompts/` (L1 examples) vs emitted `lanes/` (L2)
  — cosmetic, engine is path-agnostic; (2) `prompt-blocks.md` block J DONE-checklist
  omits the status marker that the L2 assembler injects — pre-existing, forbidden
  file. Neither breaks a frozen contract. No SKILL.md fix was required (SKILL.md is
  already self-consistent with L1/L3/L4 on all four contracts).

---

## Verdict

Four lane branches re-merged into `main` at current tips (0 commits at risk);
all four frozen contracts cross-checked with quoted evidence and hold; runner
smoke suite (syntax, help, arg-guard, dry-run-no-side-effects, poll-reads-status,
SCHEMA-example-JSON) all pass. Two cosmetic doc nits noted, neither gating.

**VERDICT: GO**
