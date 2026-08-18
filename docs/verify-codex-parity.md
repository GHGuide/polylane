# Verify — codex-parity (Cycle 39, run c39-visual-loop-20260812-a1)

Lane goal: ship identical visual-taste semantics through the intentionally separate
Codex-native skill + installer, with mechanical provider parity, working installed
links, script parity, and clean-install execution. Claude and Codex entry files stay
separate (preserved user decision).

## What changed (owned paths only)

- `codex/SKILL.md` — added the concise cycle-39 authoritative taste clause (>=3
  divergent candidates from one locked base, calibrated blind mirrored judging after
  deterministic hard gates, incumbent best-so-far, `SELECTED_NOT_CERTIFIED` vs
  `TASTE-CERTIFIED`/`human_certified` global-benchmark labels, post-promotion bounded
  taste memory). Rewrote the 6 doc links from `../references/…` to package-root-relative
  `references/…` so they resolve from the installed package root. Kept native Codex
  syntax; no Claude commands/models/memory imported.
- `codex/install.sh` — pinned the 14 visual/taste executables (visual, visual-capture,
  visual-quality, taste, taste-pixels, taste-ballot, taste-calibrate, taste-corpus,
  taste-stats, taste-threat, graph, graph-bench, promptlint, promptopt) as executable;
  pinned `references/prompt-blocks.md` alongside `visual-intelligence.md`; added a
  fail-closed guard that install aborts if any `](../…)` link survives in SKILL.md.
  Install stays a **pure copy** (source links already package-root-relative), so
  installed bytes equal source — no hand-editing of installed packages.
- `tests/test-skill-parity.sh` — strengthened with a codex-native authoritative block
  (candidate count, locked base, hard gates, calibrated-blind, incumbent, machine +
  human labels, global benchmark, taste memory) + provider-native command rules and a
  Claude-launch leak guard. Prose matched on a whitespace-flattened copy (line-wrap safe).
- `tests/test-visual-loop-integration.sh` — added reference-level provider-native /
  blind-judging / incumbent / candidate-count assertions, installed codex-native taste
  assertions, and an installed-link resolution loop (no `../`, every `.md` link exists).
- `tests/test-codex-taste-install.sh` — NEW fresh-`$HOME` install test: resolves every
  installed doc link, runs the focused visual/taste helpers from the installed package
  (usage banner + non-zero rc proves they execute), and proves helper + protocol
  (`visual-intelligence.md`, `prompt-blocks.md`) bytes hash-match source and are
  byte-identical across the `.codex` and `.agents` discovery roots. Shared installer
  rollback / stale-removal cases remain owned by provider-hooks (`test-install-fresh.sh`),
  not duplicated here.

## Command outputs

```
tests/test-skill-parity.sh:            72 pass, 0 fail
tests/test-visual-loop-integration.sh: 40 pass, 0 fail
tests/test-codex-taste-install.sh:     37 pass, 0 fail
shellcheck -S warning codex/install.sh: clean
git diff --check:                       clean
```

Non-owned regression guards (my installer change must not break them):

```
tests/test-installers.sh:   57 pass, 0 fail   (install-codex-standalone-source: installed==source bytes preserved)
tests/test-install-fresh.sh: 42 pass, 0 fail
```

## Temporary install-tree + hash evidence (throwaway $HOME, both roots)

```
installed: SKILL.md agents/ assets/ benchmarks/ references/ scripts/ (67 executable scripts)
references present: visual-intelligence.md prompt-blocks.md (+ full set)

resolved links (installed SKILL.md):
  OK references/discovery.md
  OK references/project-types.md
  OK references/documentation.md
  OK references/visual-intelligence.md
  OK references/evidence-driven-domain-autonomy.md
  OK references/cycle-9-control-room.md

helper + protocol hashes  source == .codex == .agents:
  MATCH b8a3736f9e1e scripts/polylane-taste.sh
  MATCH db16797ac846 scripts/polylane-visual.sh
  MATCH 206ed078984b references/visual-intelligence.md
  MATCH 1e71b1c3e4f1 references/prompt-blocks.md

native-syntax leak check (installed SKILL.md): CLEAN — no /polylane|/lanes slash command,
  no claude-<model> id, no ~/.claude memory root.
```

## Resolved-link / native-syntax checks

- Root cause fixed once: the `../references/` form escaped the package root
  (`~/.codex/skills/…` has no `references/` sibling of SKILL.md), so all 6 doc links
  404'd after install. Rewriting the SOURCE links (not an install-time sed) keeps
  install a pure copy AND resolves every link — smaller diff than a rewrite step and it
  satisfies the standalone-source byte-identity test that provider-hooks pins.
- Install now hard-fails if any `](../…)` link is reintroduced.
- Codex prompts remain provider-native: `codex exec` tmux lanes, `gpt-*` model policy
  via manifest, no Claude slash commands / model ids / memory helpers (leak guard green).

## Ponytail findings (self-review of this diff)

- `install.sh` 14-helper pin loop: each entry guards a real drop/rename; not speculative. Keep.
- Link-resolution loop + flattened-grep helper duplicated across two owned test files:
  DRY-ing would require editing `tests/helpers.sh`, which is FORBIDDEN for this lane.
  Acceptable duplication, not flagged for deletion.
- SKILL clause is 5 concise lines that delegate detail to the reference — parity is NOT
  solved by copying the Claude file.
- Verdict: `Lean already. Ship.` net: -0 lines.

## SKILL evidence

SKILL-READ: caveman:safe-refactor | /Users/leonardo/.codex/plugins/cache/caveman/caveman/local/skills/safe-refactor/SKILL.md | cd52867aba26aafb53379d43068cef9b2feca3a3fff850f877a99f710ccd02c0
SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 6303932f1b301c614a6f5a0099cd87a19e1cd1b7cbfa1a1e11e996edbca6426b
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 5c5e95830754bbdd838213fa05fc8f07523f591fd558fd3c86031ffd479f7a9e
SKILL-READ: ponytail:ponytail-review | /Users/leonardo/.codex/plugins/cache/ponytail/ponytail/4.9.0/.openclaw/skills/ponytail-review/SKILL.md | 76addbc1c5293d5a2da42828f4bff1cee5050492d06c194354df2f6329398df5

SKILL-EVIDENCE: caveman:safe-refactor — helped: kept behavior-preservation the boundary.
  Chose source-link rewrite over an install-time sed so install stays a pure copy and
  installed bytes still equal source; re-ran the same install proofs (test-installers,
  test-install-fresh) before and after to confirm no behavior drift.
SKILL-EVIDENCE: engineering:code-review — helped: the correctness pass caught that the
  install-time sed broke `install-codex-standalone-source` (installed!=source cksum) in a
  FORBIDDEN suite; fixed at the root instead of shipping a green-only owned subset.
SKILL-EVIDENCE: engineering:testing-strategy — helped: layered the tests by purpose —
  parity = shared contract (grep both skills), integration = installed obligations +
  link resolution, taste-install = fresh-HOME execution + byte hashes — and skipped
  trivial coverage; avoided duplicating provider-hooks' rollback/stale cases.
SKILL-EVIDENCE: ponytail:ponytail-review — helped: kept the SKILL clause to 5 lines
  (no whole-file copy), deleted the install-time sed for a pure copy, and one guard line
  for the `../` corner; confirmed no speculative abstraction to cut.

## DEFERRED

DEFERRED: root-skill interface remains — codex/SKILL.md now carries the cycle-39
taste-memory / rendered-tournament / machine-vs-human-label / calibrated-mirrored-judging
obligations natively, enforced codex-only in test-skill-parity.sh (`codex_only …`) and
test-visual-loop-integration.sh (`codex_native …`). The frozen shared reference
(`references/visual-intelligence.md`) and the Claude `SKILL.md` do NOT yet carry the same
clauses; those files are owned by visual-doc-contract, taste-memory, tournament-engine,
and claude-contract. The integrator must land those tips and then promote each `codex_only`
/ `codex_native` assertion to `both()` so parity is enforced symmetrically. No owned-lane
work is blocked; all three owned suites are green.
