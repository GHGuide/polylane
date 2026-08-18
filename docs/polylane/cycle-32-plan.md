# Cycle 32 plan — repair two terminal contract drifts

Run: `c32-contract-drift-20260811-a1`

Base: `candidate/c32-contract-drift` at retained Cycle 31 READY tip
`73212596280a32682f81919a75cf13301669ec91`. Cycle 31 remains NO-GO.

## Frozen target

- `m28.1`: update four stale manifest assertions to the absolute physical-worktree
  contract and restore one compact coordinator-owned-terminal sentence.
- `c80`: both contracts agree mechanically with current runtime behavior.

## Carve and acceptance

One builder owns `tests/test-load-manifest.sh`, `references/prompt-blocks.md`, and
its evidence/status files. The integrator independently runs the frozen focused
matrix and reviews the complete diff. Frozen acceptance:

`bash tests/test-load-manifest.sh && bash tests/test-prompt-economy.sh && bash tests/test-abs-prompt.sh && bash tests/test-orchestration-contract.sh`

Also run changed-file whitespace review. No production Bash is expected. Do not
run `tests/run.sh`, complete ShellCheck, installers, or doctor rehearsal.

## Runtime acceptance

Exactly one builder launch and one integrator launch, zero lane/integrator/supervisor
restarts, and zero terminal gates. Because older autonomous work remains outside
this focused target, the integrator emits GO, never READY. A later fresh cycle owns
terminal certification and installation authorization.

