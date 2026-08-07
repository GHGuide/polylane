# Cycle 11 plan — continual harness and RLM continuity

## Observable target

Add the useful Prime Agent invariants to Polylane without importing a Python runtime or
weakening its evidence gates: durable local/global harness state, evidence-triggered refinement
with next-cycle validation and rollback, persistent worker capsules plus inbox, and bounded
context queries consumed by builder prompts. Global prompt/skill proposals must route through
the existing skill-evolution gate.

## Frozen acceptance

- `m10.1`: `bash tests/test-harness.sh && bash tests/test-refine.sh`
- `m10.2`: `bash tests/test-workers.sh`
- `m10.3`: `bash tests/test-context.sh`
- `m10.4`: `bash tests/test-prime-hybrid-integration.sh && bash tests/test-skill-parity.sh && bash tests/test-installers.sh`
- Terminal boundary: `tests/run.sh && shellcheck -S warning bin/*.sh`

Every builder must write its behavior tests first, run them to observe the expected missing-
feature failure, then implement only enough production code to pass. The integrator records the
red/green evidence and runs the complete terminal boundary after merge.

## Lane carve

### `harness-refine`

Owns `bin/polylane-harness.sh`, `bin/polylane-refine.sh`, `tests/test-harness.sh`,
`tests/test-refine.sh`, and `docs/verify-harness-refine.md`. Implement typed local/global CRUD,
version history, atomic compare-and-swap mutation, rollback, evidence-triggered proposals,
expected-outcome deadlines, next-cycle validation, and rollback. Global prompt/skill edits are
proposal-only and must name the skill-evolution handoff; they never activate directly.

### `worker-continuity`

Owns `bin/polylane-workers.sh`, `tests/test-workers.sh`, and
`docs/verify-worker-continuity.md`. Implement stable named worker capsules, bounded context,
append-only durable inbox messages, acknowledgement, relay import, and cycle-to-cycle resume.
Do not weaken the existing live coordination relay or worktree boundaries.

### `context-query`

Owns `bin/polylane-context.sh`, `tests/test-context.sh`, and
`docs/verify-context-query.md`. Implement a deterministic, bounded, source-attributed query and
packet layer over durable Polylane documents, decisions, evidence, harness entries, worker
capsules, and recent cycle material. Unknown or missing sources stay explicit; byte/token bounds
are hard failures or deterministic truncation, never wishful estimates.

### `integrator`

Owns shared runtime and documentation surfaces: runner/cycle wiring, prompt blocks, planning,
Claude/Codex skills and installers, parity checks, `tests/test-prime-hybrid-integration.sh`, and
`docs/verify-prime-hybrid-integration.md`. Merge the three builders, expose canonical paths to
lanes, create a context packet before launch, persist worker/refinement outcomes at cycle close,
route global proposals through skill evolution, and prove fresh-install parity. The integrator
must not replace the builders' APIs with prose-only approximations.

## Dependencies and risks

- The project remains Bash 3.2 + jq + tmux; no mandatory Python/IPython dependency.
- Harness state is advisory until frozen acceptance confirms an outcome. It cannot set goal or
  criterion status and cannot bypass the execution graph.
- Reward hacking is controlled by validating against frozen product checks, not self-authored
  lane success claims.
- Context packets must stay bounded; persistent storage is not permission to inject all history.
- Existing skill-evolution files at base commit `f477986` are immutable integration dependencies.
