# Cycle 24 integration verification — host gate pending

Run: `c24-context-hardening-20260810-a1`
Branch: `lane/c24-integrator`
Frozen base: `843102ac1e7562921b560dd7bb15b5d6abd01cc6`

## Selected-skill receipts

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

Both files were read exactly once before review or verification. The bounded context
packet was also read exactly once. No Graphify skill file was read or invoked, and the
shared graph was not rebuilt.

## Exact-tip provenance

The three current asserted builder tips were merged without conflict or rewritten
ownership:

| Lane | Asserted tip | Integration merge | Owned result |
| --- | --- | --- | --- |
| `pane-identity` | `3a99b106b6075fd58a2cb7dd41db3adb89032e17` | `ebe5c3326b9662c7b2e3b9a58dc0d2d8e290e272` | shared tmux identity, state/supervisor observers, focused tests, evidence |
| `context-hygiene` | `7eadd5fba104013719f5325494ebaa1f3a8c12dc` | `f948218b4c84f7281cd1980ac6c901e9b7a99934` | scoped worker API, exact prompt syntax, query-only Graphify policy, focused tests, evidence |
| `runner-wire` | `f8540bd3d7b7cf2b7059a7bfa18fd448e0ad94b8` | `63c11fdef204e34e7ad7ad603dbe83fc636c24e3` | runner/model-policy wiring, liveness repair, focused tests, evidence |

`git merge-base --is-ancestor` returned success for every asserted tip at the merged
head. The three builder ranges are disjoint at their frozen OWN boundaries. The only
integrator code-adjacent changes are two missing edge-case assertions in
`tests/test-tmux-runtime.sh` and `tests/test-skill-delivery.sh`; production source was
not rewritten after merging.

## Independent code review

The merged diff was reviewed for correctness, security, performance, maintainability,
shell portability, and error propagation.

- `polylane_tmux_find_pane` canonicalizes the target, accepts only a complete matching
  nonce/worktree identity, and permits cwd fallback only for a fully untagged pane. A
  partial identity or conflicting same-worktree identity suppresses fallback. Pane tags
  are written before state, usage, or transcript work on fresh builder, adopted builder,
  recreated builder, fresh integrator, and adopted integrator paths.
- Worker run IDs use the existing name grammar plus a 128-byte bound. Message, relay,
  acknowledgement, inbox, and resume-packet paths share the scope. An absent scope
  deliberately preserves the historical all-history API.
- Prime-hybrid host calls and pane exports both carry `POLYLANE_WORKER_RUN_ID`. The
  preflight and prompt linter require the exact fixed-string inbox command and reject
  reversed arguments.
- `graphify` and `graphify-auto` are rejected before selected records are armed or
  compiled. Block E still mandates direct `graphify-out/q.py` queries.
- Manifest `custom` validates baked model IDs, availability, and effort without preset
  remap. An explicit CLI preset remains the remap operation and takes precedence.
- The runner liveness helpers restore ordinary local word splitting, so an inherited
  manifest-reader `IFS=|` cannot collapse the agent process list.

No correctness, security, performance, portability, or maintainability defect was
found. Review did find two evidence omissions: the pane test did not exercise
partial/wrong tag rejection, and the delivery test named only `graphify`. The
integrator added assertions for partial, wrong-run, wrong-worktree, and
`graphify-auto` rejection. They passed in the one combined focused run.

## Frozen graph and transcript context evidence

Before targeted source reads, the existing helper was queried directly for the worker
inbox, runner compile/load/launch/adopt surfaces, tmux identity files, and model-policy
surface. The frozen shell graph located `inbox_json`, `compile_prompt`, `load_manifest`,
`launch_panes`, `adopt_existing_session`, and `adopt_integrator`; it had no shell call
edges, so direct source review remained authoritative.

Captured builder scrollback shows direct helper queries in all three panes:

- pane identity queried `pane_for_worktree`, `polylane_tmux_configure`, and observer
  discovery symbols;
- context hygiene queried `inbox_json`, `compile_selected`, and `lint_one`;
- runner wire queried `launch_panes`, both adoption paths, `recreate_lane_pane`,
  `run_integrator`, and `prime_hybrid_pane_exports`.

A command-pattern audit of each builder transcript found zero reads of any
`graphify/SKILL.md` or `graphify-auto/SKILL.md`. The live bootstrap panes have only the
session-level run tag and blank lane/worktree tags because this run began with the
pre-fix launcher; that is the observed red baseline, not evidence attributed to the
merged runner.

At lane start, the exact durable-inbox command returned three unacknowledged Cycle 15
relay imports. This bootstrap process did not export the new worker run scope, so the
result reproduces the documented stale-context defect. The messages were recognized as
historical and were neither followed nor acknowledged. The integrated focused test
creates old-run, new-run, and unscoped events: a `new-run` caller sees only its two
events, rejects an old acknowledgement, and the unscoped legacy caller retains all
five historical events. A fresh host run is required to certify the merged export in a
new process.

## Focused verification

The combined command ran once through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" --`. The retained log is
`.polylane/check-cache/integrator/1095121181-634.output`.

| Test | Result |
| --- | --- |
| `test-tmux-runtime.sh` | 14 pass, 0 fail |
| `test-state.sh` | 19 pass, 0 fail |
| `test-supervisor.sh` | 32 pass, 0 fail |
| `test-worker-run-scope.sh` | 13 pass, 0 fail |
| `test-workers.sh` | 47 pass, 0 fail |
| `test-worker-canonical-state.sh` | 23 pass, 0 fail |
| `test-promptlint.sh` | 25 pass, 0 fail |
| `test-skill-delivery.sh` | 47 pass, 0 fail |
| `test-promptopt.sh` | 9 pass, 0 fail |
| `test-model-policy.sh` | 17 pass, 0 fail |
| `test-prime-hybrid-integration.sh` | 60 pass, 0 fail |
| `test-session-resume.sh` | 8 pass, 0 fail |
| `test-runtime-recovery.sh` | 15 pass, 0 fail |
| `test-intensity.sh` | 20 pass, 0 fail |

Focused total: **349 pass, 0 fail across 14 files**.

Changed-script ShellCheck ran once through the same cache for the nine changed scripts
and exited 0. `git diff --check` exited 0 after evidence writing. The refinement queue
returned `[]`, so no propose-or-decline action was eligible.

## Boundary and verdict

This lane did not run the full suite, whole-tree ShellCheck, skill parity, either
installer, doctor, live rehearsal, push, deployment, publication, purchase, or live
action. No external evidence is required for this engineering verdict; the existing
ten-product visual corpus remains separate and cannot affect it. The coordinator owns
the sole fresh-process host gate and any later promotion or cleanup.

SKILL-EVIDENCE: engineering:code-review — helped: the structured correctness and edge-case review found two missing assertions, confirmed fail-closed behavior, and avoided an unnecessary production seam rewrite.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: the READY decision is tied to one fresh 349/0 cached matrix, one clean changed-script ShellCheck, exact-tip ancestry, and transcript evidence rather than builder claims.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c24-context-hardening-20260810-a1
