# Cycle 25 integration verification — NO-GO

Run: `c25-finality-20260810-a1`
Branch: `lane/c25-integrator`
Frozen base: `08a0938`

The bounded context packet was read exactly once. The two selected integrator
skills were read once from the exact versioned records in the canonical
`.polylane/lane-skills.json`; no skill inventory or Graphify skill body was read,
and the shared graph was not rebuilt.

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: the
current-source 602-assertion matrix and ShellCheck supersede the earlier green
snapshot after a prompt-delivery seam changed source.

SKILL-EVIDENCE: engineering:code-review — helped: the independent prompt and
race review found the missing integrator selected-record delivery and the missing
post-completion ownership gate instead of treating builder reports as sufficient.

## Exact-tip provenance and ownership

The two asserted builder tips were merged without rewriting either branch:

| Lane | Asserted tip | Integration merge |
| --- | --- | --- |
| `handoff-contract` | `aa5a3b3a867d1dc7b82029cfff5e3c262ca56f05` | `c6da677` |
| `runtime-finality` | `24c2b616ea43d22929356063015b848d6c9ae494` | `27a3510` |

`git merge-base --is-ancestor` succeeded for both tips. The handoff tip changed
only its declared prompt/lint/reference/parity, focused-test, and lane-evidence
surfaces. The runtime tip also changed `tests/test-reflexion.sh`, outside its
declared ownership. Addressed durable request `message:98` required that path to
be restored exactly to frozen base `08a0938`; `git diff --exit-code 08a0938 --
tests/test-reflexion.sh` succeeds. Its strict-scalar coverage remains in the owned
completion test.

The runner's recovery checkpoints later copied Cycle 25 evidence over the older
`docs/verify-integration-attempt-1.md` and removed the current verdict/status
files. The older record was restored byte-for-byte from the pre-recovery commit;
the current evidence is rebuilt here for the active finalization transaction.

## Independent review and proven seam repairs

The combined diff was reviewed for fail-closed behavior, Bash 3.2 portability,
prompt parity, exact-once scalars, process races, and ownership boundaries. Four
cross-lane seams were reproduced and repaired:

1. `inject_runtime_prompt_contract` emitted a shortened finalization line that
   strict generated lint rejected. It now emits the same ordered literal as all
   Claude/Codex authored surfaces.
2. Runtime compilation now replaces the three authored runner-owned labels before
   appending nonce/path-specific forms, preventing duplicate strict scalars.
3. Contract-v2 `lane_done` now grades each completed builder's frozen-base-to-HEAD
   path set with `polylane-scope.sh check-lane` and fails closed without manifest
   or base evidence. The cross-lane integrator remains deliberately exempt.
4. `compile_prompt` previously delivered exact selected-skill records only to
   builders. The canonical integrator prompt therefore named its kit but contained
   no records. Compilation now delivers the validated path-bearing kit to every
   role; the orchestration regression proves both builder and integrator output.

No critical security, correctness, portability, performance, or maintainability
issue remains in the reviewed focused diff. Scope checking is a pure final-net-diff
gate, liveness is nonce/worktree/pane-mapping bound, and missing completion-scope
evidence fails closed.

## Focused contracts

The finalization literal is present in `SKILL.md`, `codex/SKILL.md`, planning,
prompt blocks, lane template, and runtime injection. Strict runtime lint requires
it and rejects an executable `polylane-refine.sh propose-or-decline`; prime-hybrid
instructions use `queue`, then exactly one implemented `propose` or `decline` for
each eligible item. Repair and no-progress prompts preserve the source
`DELEGATION`, `CHECK-CACHE`, and other strict scalars rather than appending copies.

The focused acceptance proves that a committed marker and READY verdict are
rejected while the mapped nonce-bound agent process is live and accepted after it
exits. Pane-local tags survive cwd drift; partial, wrong-run, and wrong-worktree
tags fail closed; fully untagged legacy cwd adoption remains supported. Scoped
inbox reads exclude old/unscoped events, while the legacy API retains history.
Manifest `intensity: custom` preserves baked model/effort, and explicit CLI presets
remain the only remapping operation.

## Current-source verification

The final cached focused matrix passed **602 assertions across 24 files with zero
failures**. It includes every frozen Cycle 24 identity/context/model acceptance,
all Cycle 25 handoff/finality checks, the new all-role selected-kit regression,
`test-scope.sh`, and `test-seams.sh`. Retained log:
`.polylane/check-cache/integrator/3744703488-936.output`.

Changed-script ShellCheck passed on `polylane-model-policy.sh`,
`polylane-promptlint.sh`, `polylane-promptopt.sh`, `polylane-run.sh`,
`polylane-scout.sh`, `polylane-state.sh`, `polylane-supervisor.sh`,
`polylane-tmux.sh`, and `polylane-workers.sh`. Retained log:
`.polylane/check-cache/integrator/1929566801-329.output`. `git diff --check`
also succeeds.

The terminal acceptance, whole repository suite, installers, and doctor rehearsal
were not run. They remain coordinator-owned, and no terminal gate was consumed.

## Fresh runtime, prompt, Graphify, and inbox evidence

Canonical `docs/polylane/run-stats.json` records one launch for each builder and
one integrator launch, so exactly two builder launches occurred. It also records:

- `handoff-contract`: **1 restart**;
- `runtime-finality`: 0 restarts;
- `integrator`: **1 restart**;
- supervisor restarts: **1**;
- terminal gates: 0;
- cleanup: pending.

The run manifest preserves custom `gpt-5.6-terra/medium` for both builders and
`gpt-5.6-sol/high` for the integrator. Current worker capsules retain all three
identities. The launch code writes `@polylane_run_id`, `@polylane_lane`, and
`@polylane_worktree` before recording a lane launch; all three launch events exist,
and a live pane-option inspection shows those exact three pane-local values on each
matching pane. This supplies launch-order plus retained-state evidence rather than
relying on cwd.

All three launch-time compiled prompts have one copy of every original strict
scalar plus relay and DONE. They were compiled from the Cycle 24 base and therefore
predate the new `POLYLANE-RUNTIME-FINALIZE` label; the builder prompts contain exact
selected records, while the integrator launch copy exposes the all-role delivery seam
repaired above. Current-source orchestration, promptopt, promptlint, parity, and
live-finality acceptances compile and grade the repaired candidate.

Completed command-field audit of the canonical lane logs found direct
`graphify-out/q.py` queries in every lane (6 handoff-contract, 4 runtime-finality,
and 20 integrator invocations), zero commands reading any Graphify/Graphify-auto
`SKILL.md`, and no graph build/rebuild command.

The canonical worker history retains historical unscoped events plus current-run
events. The earlier scoped inbox returned only `message:98`, which was handled and
acknowledged; a fresh scoped inbox now returns `[]`, so no historical/unscoped item
leaks. The refinement queue also returns `[]`, leaving no eligible `propose` or
`decline` action.

## Verdict basis and exact remaining work

The source candidate is focused-green, but this nonce is ineligible for the host
gate. The frozen plan makes any lane or supervisor restart NO-GO, and canonical
stats record two lane restarts plus one supervisor restart. Those nonce-bound facts
cannot be repaired or reclassified locally. Cleanup also remains pending.

The exact remaining certification is a fresh process from this integrated tip that
delivers selected records to all roles, proves exactly two builder launches and one
integrator launch with zero lane/supervisor restarts, and then hands the untouched
single terminal acceptance to the coordinator. No external evidence is needed.

DEFERRED: fresh zero-restart host certification and coordinator-owned cleanup.

POLYLANE-VERDICT: NO-GO run=c25-finality-20260810-a1
