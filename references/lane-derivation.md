# Phase 4a — Deriving the optimal number of lanes

Input: spec items + the file-set each touches (from recon). Output: N lanes with OWN/FORBIDDEN globs and contracts. N is COMPUTED — never default to 3.

## Algorithm

### Step 1 — Compute N from file overlap

N falls out of a mechanical procedure. Follow it in order; do not eyeball a lane count.

1. **List the work units with their write-sets.** From recon, write each spec item next to the exact set of files it must *modify* (its write-set). Reads don't count — only files a lane would edit can collide, so a shared file that both lanes only read is not an overlap.

2. **Build the overlap matrix.** For every pair of items (i, j), compute `|write-set(i) ∩ write-set(j)|` — the count of files both must edit. Lay it out as a symmetric item×item table. (You never need the diagonal; only the off-diagonal cells decide lanes.)

3. **Classify every non-zero cell.** Each cell's value plus a glance at *what* the shared files are decides one of four verdicts:
   - **0 shared files → INDEPENDENT.** Different lanes, fully parallel.
   - **Heavy overlap** (they edit the *same functions*, or share more than ~2 files with entangled logic) → **MERGE.** Splitting these would guarantee conflicts.
   - **Light overlap** (1–2 files behind a clean interface) → **CARVE.** Stays two lanes: one lane OWNS the shared file, the other gets a HARD CONTRACT ("public API of X is frozen; request changes via the status file").
   - **Producer/consumer** (item A's output is item B's input) → **SEQUENCE.** One lane, A before B — or B's lane starts only after A publishes its contract.

4. **Collapse to components — this yields N.** Draw an edge between any two items marked MERGE or SEQUENCE-into-one-lane. Each connected group of items becomes one candidate lane; items joined only by INDEPENDENT or CARVE edges stay separate. **Raw N = the number of connected components.** CARVE does *not* merge lanes — it keeps two lanes joined by a contract, not by shared ownership.

Then refine N downward with the caps below (caps can only *lower* N, never raise it).

### Step 2 — Refine and finalize

1. **Apply resource caps.**
   - One physical device / simulator / deploy target / DB → at most one lane uses it at a time; add the mutex block to those lanes and prefer merging lanes that both need it heavily.
   - Human review bandwidth: >5 lanes is rarely reviewable — merge the smallest clusters.
   - A lane smaller than ~half a session of work → merge into the nearest cluster (spawn overhead + coordination cost exceeds parallelism gain).
2. **Name each lane** by its subsystem (Fetch, UI, Siri, Efficiency…), not by spec-item number.
3. **Write the carve explicitly.** For every shared file: which lane OWNS it, what the frozen public API is, and the request path for the non-owner (status-file entry, owner applies the edit).
4. **Integrator lane (recommended, runs LAST).** If ≥2 lanes or any shared resource: add a final integrator/verifier lane that merges state, builds everything together, runs cross-lane end-to-end verification, acts as completeness critic, and issues GO/NO-GO. It fixes only cross-lane regressions (logged), never feature code. Two hard rules:
   - **Never trust a prior GO.** Re-merge the CURRENT HEAD of every lane branch first; a GO with commits after it is stale — re-verify from scratch.
   - **On GO, run merge + cleanup** (`references/merge-and-cleanup.md`): verify each branch merged, remove merged worktrees, delete merged branches, quarantine strays into `<project>-useless/`. Consolidate to one project folder.

## Worked example

Six spec items, with the files each must edit (write-sets):

| Item | Write-set |
|---|---|
| A — Fetch | `net.swift`, `cache.swift` |
| B — Parse | `parse.swift`, `cache.swift` |
| C — List UI | `list.swift` |
| D — Detail UI | `detail.swift`, `list.swift` |
| E — Siri | `siri.swift` |
| F — Perf pass | `net.swift`, `cache.swift`, `parse.swift` |

**Overlap matrix** (shared-file counts; blank = 0):

|   | A | B | C | D | E | F |
|---|---|---|---|---|---|---|
| A | – | 1 |   |   |   | 2 |
| B |   | – |   |   |   | 2 |
| C |   |   | – | 1 |   |   |
| D |   |   |   | – |   |   |
| E |   |   |   |   | – |   |
| F |   |   |   |   |   | – |

**Classify the non-zero cells:**
- A–F = 2 (`net`, `cache`) and B–F = 2 (`cache`, `parse`) → **MERGE** (F edits the same files as both).
- A–B = 1 (`cache`) → would be CARVE on its own, but A and B are both already pulled into F's group, so it's moot.
- C–D = 1 (`list.swift`, clean interface) → **CARVE** (D owns `list.swift`; C requests changes via the status file).
- E → **INDEPENDENT**.

**Collapse to components:** MERGE edges A–F and B–F glue {A, B, F} into one lane. C and D are joined only by a CARVE edge, so they stay separate. E is alone.

→ **Raw N = 4**: `{A,B,F}` (Data), `{C}` (List UI), `{D}` (Detail UI), `{E}` (Siri).

**Apply caps:** C and D are two small UI lanes sharing `list.swift` through a carve — the tiny-lane cap (each is well under half a session) merges them into one **UI** lane. Final **N = 3** builder lanes: **Data**, **UI**, **Siri** — plus the **integrator** lane (N ≥ 2). A reader following this arrives at 3 without guessing.

## Isolation mode

Ask the user at the plan gate:
- **Shared tree + scoped `git add`** — simplest; requires the never-`add -A` rule; risk: index.lock races, visible WIP.
- **Git worktrees** (one branch per lane, `superpowers:using-git-worktrees`) — real isolation, merge at the end; recommended for ≥3 lanes or when lanes rebuild the same artifacts.

## Sanity checks before presenting

- Every spec item maps to exactly one lane.
- No file appears in two lanes' OWN lists.
- Every FORBIDDEN list names the other lanes' OWN globs.
- Every contract is stated from both sides (owner keeps stable; consumer doesn't edit).
