# Cycle 24 integration verification — NO-GO

Run: `c24-context-hardening-20260810-a1`
Branch: `lane/c24-integrator`
Frozen base: `843102ac1e7562921b560dd7bb15b5d6abd01cc6`

## Selected-skill receipts

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

Both selected files and the bounded context packet were each read exactly once. No
Graphify skill file was read or invoked, and the shared graph was not rebuilt.

## Exact-tip provenance

The three current asserted builder tips were merged without conflict:

| Lane | Asserted tip | Integration merge |
| --- | --- | --- |
| `pane-identity` | `3a99b106b6075fd58a2cb7dd41db3adb89032e17` | `ebe5c3326b9662c7b2e3b9a58dc0d2d8e290e272` |
| `context-hygiene` | `7eadd5fba104013719f5325494ebaa1f3a8c12dc` | `f948218b4c84f7281cd1980ac6c901e9b7a99934` |
| `runner-wire` | `f8540bd3d7b7cf2b7059a7bfa18fd448e0ad94b8` | `63c11fdef204e34e7ad7ad603dbe83fc636c24e3` |

`git merge-base --is-ancestor` succeeded for every asserted tip. The original builder
ranges stayed within their frozen OWN boundaries. Integrator changes add missing
identity/navigation assertions and repair one cross-lane tmux lookup seam discovered
from canonical live evidence.

## Independent review and focused contracts

The merged diff was reviewed for correctness, security, performance, maintainability,
shell portability, and error propagation.

- Pane tags are written before dependent state, usage, or transcript work on fresh,
  adopted, recreated, and integrator paths. Complete matching pane-local tags survive
  cwd drift; partial, wrong-run, and wrong-worktree tags fail closed; a truly untagged
  pane retains legacy cwd adoption.
- Worker run IDs use the existing name grammar plus a 128-byte bound. Message, relay,
  acknowledgement, inbox, and resume-packet paths share the optional scope, while an
  unscoped caller retains the historical API.
- Prime-hybrid host calls and pane exports carry `POLYLANE_WORKER_RUN_ID`; preflight
  and lint require the exact fixed-string inbox command and reject reversed arguments.
- `graphify` and `graphify-auto` are rejected before arming or compilation while Block
  E retains direct `graphify-out/q.py` queries.
- Manifest `custom` validates baked model IDs, availability, and effort without remap;
  an explicit CLI preset still remaps and wins. Liveness helpers restore local ordinary
  word splitting after inherited `IFS=|`.

The initial combined focused command ran once through the integrator cache and passed
349/349 across 14 files. Changed-script ShellCheck also passed once. Its retained test
log is `.polylane/check-cache/integrator/1095121181-634.output`.

Independent review added coverage for partial, wrong-run, wrong-worktree, and
`graphify-auto` rejection. The later live relay then exposed a distinct tmux semantic:
`#{@polylane_run_id}` inherits a session option when the pane has no local option, so
the merged finder could mistake a fully untagged legacy pane for a partially tagged
pane. Live reproduction showed:

- `tmux show-options -p -v ... @polylane_run_id` -> `invalid option`;
- `tmux display-message ... '#{@polylane_run_id}'` -> the session nonce.

The new real-tmux regression first failed exactly `13 pass, 1 fail`. The finder was
then changed to list only pane index/cwd and query all three identity keys with
pane-scoped `show-options -p -v`, which has no session fallback. The affected cached
green matrix passed 65/65 (`test-tmux-runtime` 14, `test-state` 19,
`test-supervisor` 32), and changed-helper ShellCheck exited 0. This local repair is
required source for the next cycle but cannot erase this run's restart history.

## Canonical transcript and context evidence

Before targeted source reads, the frozen helper was queried directly for worker inbox,
prompt/model policy, tmux identity, and all runner launch/adopt/recreate surfaces. The
graph had no useful shell call edges, so direct source review remained authoritative.

The canonical logs are outside the runtime snapshot at
`/Users/leonardo/Downloads/polylane-c24/docs/lane-logs/*.log`. Command-field inspection
shows direct `q.py` queries in every builder:

- pane identity: `pane_for_worktree`, `polylane_tmux_configure`, `discover_session`;
- context hygiene: `inbox_json`, `compile_selected`, `lint_one`;
- runner wire: `launch_panes`, both adoption paths, `recreate_lane_pane`,
  `run_integrator`, and `prime_hybrid_pane_exports`.

The canonical command audit found zero reads of `graphify/SKILL.md` or
`graphify-auto/SKILL.md`.

At lane start, the exact inbox command returned three Cycle 15 imports because this
bootstrap process did not export the new run scope. They were identified as historical,
not followed, and not acknowledged. The integrated scope test proves that a `new-run`
caller sees only its two matching events, rejects an old acknowledgement, and an
unscoped legacy caller retains all five historical events. Only a fresh process can
certify the new export in live use.

## Canonical runtime truth

`/Users/leonardo/Downloads/polylane-c24/docs/polylane/run-stats.json` is decisive:

- `context-hygiene`: 1 launch, **2 restarts**;
- `supervisor_restarts`: **1**;
- all other lanes: 1 launch, 0 lane restarts;
- `terminal_gates`: 1;
- `cleanup`: `pending`.

The canonical runner log records dead-pane retries at lines 550 and 814, then a
reflexion attempt at line 995. Line 996 rejects duplicate strict `DELEGATION` scalar
values. The first restarts followed a builder handoff that did not mechanically require
committing every owned file; the marker was therefore not a valid contract-v2 handoff.
The plan states that any restart is NO-GO. Focused code health cannot override this
nonce-bound runtime evidence. The coordinator subsequently consumed the sole terminal
gate. Its efficiency proof failed with `restarts=3>0`; the host-gate failure records
that the gate is exhausted, nothing was merged or deleted, and cleanup remains pending.

## Exact repairs and next gate

Cycle 24 ends NO-GO. A fresh hardening cycle must:

1. Compile an explicit builder instruction to commit every owned changed/new file
   before the DONE marker, with a prompt contract regression.
2. Make reflexion prompt augmentation replace/dedupe strict scalar contracts rather
   than append a second `DELEGATION` value, with a red/green promptopt regression.
3. Start from the pane-local option repair in this integrator branch and certify a new
   process with zero lane restarts, zero supervisor restarts, scoped live inbox output,
   one new-run coordinator-owned terminal gate, and complete cleanup.

This lane did not run the full suite, whole-tree ShellCheck, parity, either installer,
doctor, live rehearsal, push, deployment, publication, purchase, or live action. No
external evidence is required; the ten-product visual corpus remains separate. The
refinement queue returned `[]`, so no propose-or-decline action was eligible.

SKILL-EVIDENCE: engineering:code-review — helped: the structured review found missing edge assertions and, when canonical live evidence arrived, isolated session-option inheritance as a real cross-lane correctness seam.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: canonical restart evidence overrode the earlier green focused matrix, forced withdrawal of READY, and tied the pane repair to red/green verification.

POLYLANE-VERDICT: NO-GO run=c24-context-hardening-20260810-a1
