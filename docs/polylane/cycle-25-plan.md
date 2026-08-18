# Cycle 25 plan — atomic handoff and fresh unattended certification

## Goal

Turn lane completion into one mechanically ordered transaction and certify the full
Cycle 24/25 candidate in a fresh process with no recovery spend. The outer coordinator
alone owns the terminal gate and promotion.

## Frozen lanes

| Lane | OWN | Required outcome |
| --- | --- | --- |
| `handoff-contract` | prompt lint, prompt/reference/skill contracts, refinement-facing tests, lane evidence | Every generated builder and integrator prompt requires final relay/inbox handling, scoped staging of every owned changed or new file, a commit-clean check, marker/verdict as the final committed mutation, and immediate exit. Replace the nonexistent refinement command with executable `queue` then `propose` or `decline` guidance. |
| `runtime-finality` | runner plus recovery/completion tests and lane evidence | `lane_done` cannot accept a marker/READY handoff while that lane's selected agent process is live. Reflexion and churn replans remain strict-prompt-valid without duplicate scalar contracts. |
| `integrator` | exact-tip merges and Cycle 25 integration evidence | Merge the two exact builder tips, independently verify focused contracts and live bootstrap evidence, then produce one truthful READY or NO-GO handoff. |

## Frozen interfaces

- `POLYLANE-RUNTIME-FINALIZE` is injected into every compiled prompt. It orders:
  final relay/inbox read; all requested autonomous work; focused verification; scoped
  staging and commit of every owned changed/new file; clean-status verification allowing
  only runner-owned prompt/graph scratch; status/verdict creation and force-add when
  ignored; one final commit; then immediate agent exit with no later reads or mutations.
- Strict prompt lint rejects a compiled runtime prompt without that finalization contract.
- Conceptual refinement choice is expressed as `queue`, then exactly one real `propose`
  or `decline` command per eligible item. No prompt invokes a nonexistent
  `propose-or-decline` subcommand.
- A contract-v2 marker or READY verdict is necessary but not sufficient while
  `pane_agent_live` is true for the matching nonce-bound lane pane.
- Repair and no-progress prompts may add ordinary prose, but must not append a second
  `DELEGATION`, `CHECK-CACHE`, or other strict scalar with a different value.
- Existing marker nonce, clean-tree, exact-HEAD, pane-local identity, legacy fully
  untagged adoption, and runner-owned scratch exceptions remain intact.

## Frozen verification

Builders use red/green focused tests only. The integrator reruns the combined focused
matrix and checks exact write sets, strict prompt compilation, marker-while-live
rejection, process-exit acceptance, actual refinement command syntax, custom intensity,
pane-local tags, and run-scoped inbox behavior. It must inspect command evidence and
confirm direct `graphify-out/q.py` queries with zero reads of a Graphify skill body.

The coordinator then consumes exactly one terminal gate:

```bash
POLYLANE_MIN_DISK_GB=0 tests/run.sh && \
shellcheck -S warning bin/*.sh && \
bash tests/test-skill-parity.sh && \
bash tests/test-installers.sh && \
POLYLANE_MIN_DISK_GB=0 bin/polylane-doctor.sh --rehearse
```

The run is GO only with three launches total (two builders plus integrator), zero lane
restarts, zero supervisor restarts, one terminal gate, successful cleanup, and a fresh
observer transcript showing all pane-local identity fields immediately after launch.
Any restart, duplicate agent for one worktree, stale-run inbox event, prompt scalar
conflict, premature marker acceptance, second terminal gate, or incomplete cleanup is
NO-GO. No push, deployment, publication, purchase, live action, or trading execution is
authorized.

