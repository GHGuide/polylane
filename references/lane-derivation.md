# Phase 4a — Deriving the optimal number of lanes

Input: spec items + the file-set each touches (from recon). Output: N lanes with OWN/FORBIDDEN globs and contracts. N is COMPUTED — never default to 3.

## Algorithm

1. **Cluster by file overlap.** Build an item×item matrix: shared files between each pair.
   - Zero overlap → separate clusters (parallel-safe).
   - Heavy overlap (entangled logic, same functions) → SAME lane.
   - Light overlap (1-2 files with a clean interface) → CARVE: one lane owns the shared file; the other gets a HARD CONTRACT ("public API of X stays stable; request changes via status file").
   - Producer/consumer (one item's output feeds another) → SEQUENCE inside one lane, or lane B starts after lane A's contract is published.
2. **Apply resource caps.**
   - One physical device / simulator / deploy target / DB → at most one lane uses it at a time; add the mutex block to those lanes and prefer merging lanes that both need it heavily.
   - Human review bandwidth: >5 lanes is rarely reviewable — merge the smallest clusters.
   - A lane smaller than ~half a session of work → merge into the nearest cluster (spawn overhead + coordination cost exceeds parallelism gain).
3. **Name each lane** by its subsystem (Fetch, UI, Siri, Efficiency…), not by spec-item number.
4. **Write the carve explicitly.** For every shared file: which lane OWNS it, what the frozen public API is, and the request path for the non-owner (status-file entry, owner applies the edit).
5. **Integrator lane (recommended, runs LAST).** If ≥2 lanes or any shared resource: add a final integrator/verifier lane that merges state, builds everything together, runs cross-lane end-to-end verification, acts as completeness critic, and issues GO/NO-GO. It fixes only cross-lane regressions (logged), never feature code. Two hard rules:
   - **Never trust a prior GO.** Re-merge the CURRENT HEAD of every lane branch first; a GO with commits after it is stale — re-verify from scratch.
   - **On GO, run merge + cleanup** (`references/merge-and-cleanup.md`): verify each branch merged, remove merged worktrees, delete merged branches, quarantine strays into `<project>-useless/`. Consolidate to one project folder.

## Isolation mode

Ask the user at the plan gate:
- **Shared tree + scoped `git add`** — simplest; requires the never-`add -A` rule; risk: index.lock races, visible WIP.
- **Git worktrees** (one branch per lane, `superpowers:using-git-worktrees`) — real isolation, merge at the end; recommended for ≥3 lanes or when lanes rebuild the same artifacts.

## Sanity checks before presenting

- Every spec item maps to exactly one lane.
- No file appears in two lanes' OWN lists.
- Every FORBIDDEN list names the other lanes' OWN globs.
- Every contract is stated from both sides (owner keeps stable; consumer doesn't edit).
