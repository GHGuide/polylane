# Verify — shared-contract (m12.4)

Run: `c12-visual-20260808`

## RED

`bin/polylane-check.sh "$PWD/.polylane/check-cache/shared-contract" -- bash tests/test-visual-loop-integration.sh`

The installer-backed fixture initially passed the existing visual loop, then failed
as intended after adding the missing durable-certification assertions:
`test-visual-loop-integration.sh: 26 pass, 2 fail`. The missing obligations were
the Visual certification record and its linked lock/captures/verdicts/repairs/
champion evidence. This was the expected RED behavior before the contract change.

## GREEN

The same installer-backed fixture now passes: `test-visual-loop-integration.sh:
28 pass, 0 fail`.

Focused parity passes: `test-skill-parity.sh: 38 pass, 0 fail`.

ShellCheck passes:

```bash
shellcheck -S warning codex/install.sh \
  tests/test-visual-loop-integration.sh tests/test-skill-parity.sh
```

The checks were run through the lane-local check cache at
`.polylane/check-cache/shared-contract`; each final result was `CHECK-CACHE: PASS`.

## Exact coverage

- `references/visual-intelligence.md` defines UI detection; an evidence packet of
  3-5 relevant references plus a wildcard; multi-source synthesis; three directions;
  automatic council choice; and a lock for tokens, layout, motion, and signature.
- Discovery, planning, and generated prompt blocks carry the literal
  `ULTIMATE-GOAL`, require selected native-platform skills to be used, and forbid
  replacing the chosen direction with a generic aesthetic.
- The UI-only skill route is discover → quarantine → audit → isolated benchmark →
  pinned project install → arm. Rejected content never executes; a failed stage
  records why and uses the best installed kit.
- The staged evidence contract names desktop/mobile, empty/loading/error/hover/focus,
  one real flow, three independent visual lenses, and at most two targeted repairs.
- The asset/copy pass requires product-specific typography and imagery/icons/
  illustration plus humanized UX copy; it rejects the listed generic patterns unless
  evidence justifies them.
- Champion certification requires at least 10 varied prompts, anonymized screenshots,
  blind decisive comparison, at least 70% creative/polish wins, and no accessibility
  regression. A failed certification retains the current champion.
- The executable Visual certification record joins the direction/design lock, each
  capture or external blocker, three verdicts, zero-to-two repairs and re-reviews,
  blind old-vs-new tally, accessibility result, and champion decision. A missing
  artifact is external or NO-GO, never a prose-only pass.
- `codex/install.sh --repo` is exercised by a disposable fixture and rejects a
  package that does not contain the visual reference, preserving generated Codex
  parity without collapsing the distinct Claude and Codex syntax.

## External evidence

This shared-contract lane produced an executable contract and its installation
fixture, not a product UI. No live site, screenshot set, remote skill audit, or
old-vs-new visual benchmark was run here. Those artifacts remain external until a
future UI cycle records them under the contract; they are not implied by these tests.
