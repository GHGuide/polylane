# Cycle 12 — Visual Intelligence Loop

## Observable target

Polylane detects UI cycles, researches multiple real references plus a wildcard,
locks an original visual contract, safely acquires missing skills, captures all
required visual states, and refuses promotion until three independent visual
judges pass. The behavior is shared by Claude Code and Codex and is certified by
an old-versus-new benchmark contract.

## Frozen acceptance

- `tests/test-visual-intelligence.sh`
- `tests/test-skill-acquire.sh`
- `tests/test-visual-quality.sh`
- `tests/test-visual-loop-integration.sh`
- `tests/run.sh`
- `shellcheck -S warning bin/*.sh`
- `tests/test-skill-parity.sh`
- `bin/polylane-doctor.sh --rehearse`

## Lane carve

Disk recon found only 622 MiB free. Four builders plus an integrator would violate
the worktree safety margin, so the executable mechanisms are intentionally one
vertical slice rather than three undersized worktrees.

### visual-mechanisms

Owns `bin/polylane-visual.sh`, `bin/polylane-skill-acquire.sh`,
`bin/polylane-visual-quality.sh`, `bin/polylane-scout.sh`,
`bin/polylane-judges.sh`, `bin/polylane-run.sh`, `bin/polylane-graph.sh`,
`tests/test-visual-intelligence.sh`, `tests/test-skill-acquire.sh`,
`tests/test-visual-quality.sh`, and any directly affected existing script tests.
It implements reference validation, design locking, originality constraints,
quarantine/audit/benchmark/install, visual evidence validation, three lenses, and
two bounded repair rounds. It must write and run each focused test RED before its
production implementation.

### shared-contract

Owns `SKILL.md`, `codex/SKILL.md`, `references/prompt-blocks.md`,
`references/planning.md`, `references/discovery.md`, `references/documentation.md`,
`references/visual-intelligence.md`, `references/skill-scout.md`,
`tests/test-visual-loop-integration.sh`, and parity/install documentation. It
wires the feature into both platforms, defines the builder contract, and defines
the A/B certification contract. It must pressure-test the consuming contract,
not merely grep for prose.

No source file belongs to two builders. The integrator owns only merge conflict
resolution, generated install parity, cross-lane verification, and verdict.

## Risks

- Network or browser access can be unavailable. Existing locked evidence may be
  reused only when its URLs, screenshots, product scope, and source hashes remain
  valid; otherwise UI work is blocked rather than guessed.
- Visual model judges can share bias. Lenses and prompts are isolated, evidence
  is anonymized, mechanical checks run first, and the benchmark requires a
  decisive aggregate improvement.
- Remote skills are code-like instructions. They remain inert until the trust
  boundary passes; project scope and immutable pinning limit blast radius.
- Visual repair can burn tokens. Findings must identify exact surfaces and the
  loop is capped at two rounds.
