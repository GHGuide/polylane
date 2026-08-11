# Terminal contract repair verification

Run: `c32-contract-drift-20260811-a1`

## Red witnesses

The first cached reproductions found five failures exactly as reported by the Cycle
31 council:

- `test-load-manifest.sh`: `int-worktree`, `lane0-worktree`,
  `lane0-pollspec`, and `lane1-pollspec` expected relative `.polylane/wt/...`
  values while `load_manifest` returned physical paths rooted at `$PROJ`.
  Result: 26 pass, 4 fail.
- `test-prompt-economy.sh`: `economy-no-full-builder-suite` did not find the
  required lowercase phrase `only coordinator-owned terminal checks remain`.
  Result: 18 pass, 1 fail.

Direct runtime inspection confirms `load_manifest` applies `abs_worktree` to the
integrator worktree, every lane worktree, and therefore each lane poll spec. The
runtime contract was already correct; only expectations were stale.

## Exact repair rationale

`tests/test-load-manifest.sh` now expects `$PROJ/.polylane/wt/integration`,
`$PROJ/.polylane/wt/alpha`, and the two corresponding `name:$PROJ/...` poll
specs. `references/prompt-blocks.md` restores the frozen phrase once, as the
imperative tail of Block G's existing `TEST-CADENCE` sentence. It adds no generic
stack or provider-specific slash command.

## Focused green evidence

The frozen matrix ran once through
`.polylane/check-cache/terminal-contract-repair` after the repair:

- `bash tests/test-load-manifest.sh` — 30 pass, 0 fail.
- `bash tests/test-prompt-economy.sh` — 19 pass, 0 fail.
- `bash tests/test-abs-prompt.sh` — 6 pass, 0 fail.
- `bash tests/test-orchestration-contract.sh` — 14 pass, 0 fail.
- `git diff --check` — clean.

The exact phrase occurs once. `references/prompt-blocks.md` changed from 18,948
to 18,995 bytes: +47 bytes. `git diff --name-only -- bin` produced zero paths,
proving no production Bash changed.

## Skill receipts

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: direct inspection
separated stale test assertions from the already-correct `abs_worktree` runtime
behavior.

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the two specified
tests were observed red before the smallest expectation/prompt-contract repair,
then observed green in the frozen matrix.
