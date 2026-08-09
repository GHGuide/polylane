# Cycle 25 integration verification — NO-GO

Run: `c25-finality-20260810-a1`
Branch: `lane/c25-integrator`
Frozen base: `08a0938`

The selected verification-before-completion and code-review kits guided the
evidence ordering and the independent shell/race review. The bounded context packet
was read exactly once. No Graphify skill file was read or invoked, and the shared
graph was not rebuilt.

## Exact-tip provenance and ownership

The two asserted builder tips were merged without rewriting either branch:

| Lane | Asserted tip | Integration merge |
| --- | --- | --- |
| `handoff-contract` | `aa5a3b3a867d1dc7b82029cfff5e3c262ca56f05` | `c6da677` |
| `runtime-finality` | `24c2b616ea43d22929356063015b848d6c9ae494` | `27a3510` |

`git merge-base --is-ancestor` succeeded for both tips. The handoff tip changed only
its prompt/lint/reference/parity surfaces, focused tests, and lane evidence. The
runtime tip changed its runner/completion surfaces, but also changed
`tests/test-reflexion.sh` outside its asserted owned test set. Addressed durable inbox
message `message:98` required that file to be restored exactly to frozen base
`08a0938`; `git diff --exit-code 08a0938 -- tests/test-reflexion.sh` now succeeds. Its
strict-scalar regression is retained in owned `tests/test-lane-done-live.sh`.

## Independent review and seam repairs

The merged diff was reviewed for fail-closed behavior, shell portability, generated
prompt parity, exact-once scalars, process races, and branch ownership. Three proven
cross-lane seams were repaired:

1. `inject_runtime_prompt_contract` emitted a shortened finalization line that the
   strict generated linter rejected. It now emits the same ordered literal contract
   as every Claude/Codex prompt surface.
2. Authored prompts already advertise runtime labels. The injector now replaces those
   three runner-owned labels before appending the nonce/path-specific compiled forms,
   avoiding duplicate runtime scalars. Three explicit BSD-sed expressions are used;
   the rejected GNU-style alternation is not retained.
3. Prelaunch scope checks did not grade a builder's completed diff. Contract-v2
   `lane_done` now checks every frozen-base-to-HEAD builder path with
   `polylane-scope.sh check-lane`, fails closed when manifest/base evidence is missing,
   surfaces exact violations, and deliberately excludes the cross-lane integrator.

The finalization contract is present in `SKILL.md`, `codex/SKILL.md`, planning,
prompt blocks, lane template, and the compiled runtime injector. Strict generated lint
requires the ordered literal and rejects a fictional executable
`polylane-refine.sh propose-or-decline`. Prime-hybrid instructions instead run `queue`,
then one implemented `propose` or `decline` for each eligible item. Repair and churn
prompts preserve the original `DELEGATION`, `CHECK-CACHE`, and all other strict
scalars. A committed status marker and READY handoff are rejected while the mapped
nonce-bound agent is live and accepted after exit.

Cycle 24 behavior remains intact: complete pane-local tags survive cwd drift; partial,
wrong-run, and wrong-worktree tags fail closed; fully untagged legacy cwd adoption
still works. A scoped inbox sees only matching-run events while the legacy unscoped API
retains history. Manifest `intensity: custom` preserves baked model/effort values, and
explicit CLI presets remain the only remapping operation.

## Focused verification

The final combined cached matrix passed **599 assertions across 24 files with zero
failures**. It includes the 14 frozen Cycle 24 identity/context/model checks, all Cycle
25 handoff/finality checks, `test-scope.sh`, and `test-seams.sh`. The retained log is
`.polylane/check-cache/integrator/3744703488-936.output`.

Changed-script ShellCheck passed once on the final source across:
`polylane-model-policy.sh`, `polylane-promptlint.sh`, `polylane-promptopt.sh`,
`polylane-run.sh`, `polylane-scout.sh`, `polylane-state.sh`,
`polylane-supervisor.sh`, `polylane-tmux.sh`, and `polylane-workers.sh`. Its retained
log is `.polylane/check-cache/integrator/1929566801-329.output`. `git diff --check`
also succeeds.

The terminal acceptance, whole repository suite, installers, and doctor rehearsal were
not run; they remain coordinator-owned and no host gate was consumed.

## Fresh runtime, Graphify, and inbox evidence

Canonical evidence is under `/Users/leonardo/Downloads/polylane-c25`, not the bounded
runtime snapshot. `docs/polylane/run-stats.json` records exactly one launch for each of
the two builders and one integrator launch. It also records:

- `handoff-contract`: **1 restart**;
- `runtime-finality`: 0 restarts;
- `integrator`: 0 restarts;
- supervisor restarts: 0;
- terminal gates: 0;
- tokens: unknown (never rendered as zero);
- cleanup: pending.

The three current worker capsules retain their role, run registration, and bounded
context identity. All three live panes expose pane-local `@polylane_run_id`,
`@polylane_lane`, and `@polylane_worktree`; the values match this nonce and the exact
handoff, runtime, and integrator worktrees. The frozen custom manifest preserves
`gpt-5.6-terra/medium` for both builders and `gpt-5.6-sol/high` for the integrator.

All three canonical compiled prompts were inspected. They contain one ultimate goal,
subgoal, goal, delegation, check-cache, exact inbox route, selected builder records,
relay, and nonce-bound DONE path. Because this self-run launched from the Cycle 24 base
in order to build Cycle 25, its launch-time compiled copies predate the new formal
`POLYLANE-RUNTIME-FINALIZE` label; the merged candidate's compilation is independently
covered by the green orchestration and live-finality acceptances above.

Command-field audit of all three canonical lane logs found direct
`graphify-out/q.py` use (`handoff-contract` 8 invocations across its original and
restarted transcript, `runtime-finality` 5, integrator 17) and **zero reads of any
Graphify or Graphify-auto `SKILL.md`**. The shared graph was never rebuilt.

The canonical worker history contains 99 events: 96 historical unscoped events and
three events scoped to this run. The scoped integrator inbox returned only current-run
`message:98`; no old or unscoped event leaked into the result. That request exposed the
ownership and missing post-completion scope gate repaired above. The refinement queue
returned `[]`, so no `propose` or `decline` action was eligible.

## Verdict

The source candidate is focused-green, but the run is not promotable. The frozen plan
makes any lane restart NO-GO, and canonical stats record one `handoff-contract`
restart. No local repair can erase nonce-bound restart history. A fresh run from this
integrated tip must prove exactly two builder launches, zero lane and supervisor
restarts, then leave the one terminal gate to the coordinator. Cleanup for this failed
run also remains coordinator-owned.

## DEFERRED

DEFERRED: fresh zero-restart host certification — rerun this integrated source in a
new nonce; only that process may become eligible for the terminal gate.
