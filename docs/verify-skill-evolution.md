# Skill evolution verification

Verified 2026-08-07.

## Contract

- Only repeated, verified `hurt`, `unused`, `correction`, or `regression`
  observations make a skill eligible for evolution.
- Champion and challenger snapshots are immutable. Train, development, hidden,
  and three blind-judge adapters are frozen at workspace initialization.
- Unknown evaluator output, hard-case failure, quality regression, excessive
  token/time/intervention cost, or fewer than two blind-judge wins produces
  `NO-GO`.
- Promotion uses a compare-and-swap active hash and an activation journal.
  Post-promotion hidden-case failure automatically restores the previous
  generation.
- Evolution workspaces may not overlap the active skill tree, preventing
  recursive snapshots and self-moving activation journals.

## Behavioral benchmark

A real Codex old-champion/current-challenger comparison returned `GO`:

- development score: `0.500000 -> 0.833333`
- hidden score: `0.700000 -> 0.900000`
- mean token proxy: `4069.25 -> 4468.5` (within the frozen 15% ceiling)
- mean duration: `12500ms -> 7000ms`
- blind judges: candidate won `2/3`

The local Claude CLI was not authenticated, so its real-agent run returned
`Not logged in · Please run /login`; the gate rejected it rather than promoting
unknown output. Claude package layout, corpus resolution, and adapter behavior
remain covered hermetically.

## Verification commands

```bash
bash tests/run.sh
shellcheck -S warning bin/*.sh
bin/polylane-doctor.sh
bin/polylane-doctor.sh --rehearse
```

Fresh Claude and Codex installs both validate the bundled four-case corpus and
its three bounded judges from their platform-specific layouts.
