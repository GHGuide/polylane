# Cycle 36 council — focused recovery evidence

## Evidence

- Exact recovery DONE tip `5b4d921ada8f13b7c9dbd49e5159c107a5642ae5` was
  nonce-matched and merged into the owned integrator branch from base
  `50e8c8816375b28338326bec6ca16cae9cea15be`.
- The complete 16-file repair diff restores the retained Cycle 35 installer
  implementation and makes the compiled finalization contract role-aware. No
  source seam was added after the merge.
- Frozen installer coverage passed fresh at 42/0 and 57/0; it proves clean
  replacement of legacy/full packages, matching Codex discovery roots, and
  Claude source-equals-destination safety without touching a live user install.
- Canonical-path, strict-lint, provider-handoff, and orchestration checks passed
  fresh at 18/0, 35/0, 58/0, and 14/0. Syntax, warning-level ShellCheck, marker
  consistency, and 59/0 provider parity are also green.
- The continual-harness queue was drained with exactly one decline for each
  eligible `context` and `integrator` item. No terminal command or terminal gate
  ran.

## Decision

The focused recovery has independently established the only valid integrator
handoff route: the verification file carries the final sentinel and the status
file is status-only. The runner retains authority for promotion, cleanup, state
finalization, and all terminal-tier work. The unrelated visual corpus remains
external evidence only.
