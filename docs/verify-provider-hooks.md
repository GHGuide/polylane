# verify-provider-hooks — c39-visual-loop-20260812-a1

Lane: provider-hooks. Scope: fresh-install executable hooks, authoritative taste
protocol packaging, stale-removal/rollback safety. Bash 3.2 + jq only,
ShellCheck-clean at `-S warning`.

## Problem fixed

The shipped hook fragments hardcoded `$CLAUDE_PROJECT_DIR/bin/polylane-hooks.sh`
and `$(git rev-parse --show-toplevel)/bin/polylane-hooks.sh`. After a real
install the helper lives in the installed skill package
(`~/.claude/skills/polylane/bin/…`, `~/.codex/skills/polylane/scripts/…`, or the
repo-scoped equivalents), never in a blank target repo's `bin/`. Those hooks
could never execute in a stranger's project.

## Contract implemented

- One installed-helper **locator** (`polylane-hooks.sh locate`): the helper
  resolves its own canonical absolute path; rejects a symlinked/absent/non-regular/
  non-executable target and any path carrying quote/backslash characters.
- A deterministic **renderer** (`polylane-hooks.sh render claude|codex`): reads the
  shipped template beside the helper, substitutes the single
  `__POLYLANE_HOOKS_HELPER__` placeholder with the resolved absolute path, and
  records the helper SHA-256 as provenance in `_comment`/`description`. No global
  settings are edited; trust is never inferred.
- Fragments are guarded fail-safe: `h='…'; [ -x "$h" ] || exit 0; exec "$h" …`.
  A removed/unrendered helper is a silent no-op, never a crashing hook. Project is
  still resolved natively (`$CLAUDE_PROJECT_DIR` / `git rev-parse --show-toplevel`).
- Provider output schemas are unchanged (SessionStart/PreCompact/PostCompact
  bounded restore; Stop blocks only on current run/lane evidence, avoids recursion).

## Executable hook transcript (rendered → executed in a blank target repo)

```
LOCATE: /Users/leonardo/Downloads/polylane-c39-provider-hooks/bin/polylane-hooks.sh
HELPER_SHA256: 0f7552819c1092bb63b330ee25de83b1902ba38dbe927eed83b52947a8844924
RENDERED_CMD: h='…/bin/polylane-hooks.sh'; [ -x "$h" ] || exit 0; exec "$h" claude SessionStart --project "$CLAUDE_PROJECT_DIR"
EXEC_SESSIONSTART: {"continue":true,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[memory-brief] evid\n[north-star] truthful first run\n[settled-decisions] optional hooks"}}
EXEC_STOP: {"continue":true,"systemMessage":"polylane-hooks: run_id or lane unavailable; failing open for supervisor recovery"}
ABSENT_FAILSAFE_RC=0   # rendered command with helper path removed → silent no-op, exit 0
```

Symlink/tamper: `render`/`locate` invoked through a symlink to the helper fail
non-zero before emitting a fragment (`hooks-render-symlink-rejected`,
`hooks-locate-symlink-rejected`).

## Claude installer parity (build in staging, atomic swap + rollback)

Added to `claude-code/install.sh` (mirroring Codex where I may not edit it):

- Package the authoritative protocol `docs/polylane/taste-certification/PROTOCOL.md`
  → stable installed path `references/taste-certification-protocol.md` plus a
  `…​.provenance` sidecar (`source`, `sha256`, `packaged-by`). Missing source
  aborts the build (evidence failure, not approximation).
- Assert every visual/taste helper executable (`polylane-taste*.sh`,
  `polylane-visual*.sh`) and `references/visual-intelligence.md` present.
- Clean the staging dir on build-failure exit (`build_one` aborts with `exit`;
  a `cleanup_stage`/`STAGE_TO_CLEAN` EXIT trap removes litter until the atomic
  swap succeeds). Existing behaviour retained: full-package replacement removes
  stale roots, atomic `mv` swap with backup rollback, source==destination reinstall.

### Stale-removal + build-failure preservation transcript

```
INSTALL_OK
STALE_LEGACY_REMOVED=yes            # seeded LEGACY-PACKAGE.txt + obsolete engine gone
PROTOCOL_PACKAGED=yes
PROTO_SHA=7ccade797d6675fdfb0c8718919f1ee37eccda9eef89a7b51d2db99e16b76780
PROV_SHA=7ccade797d6675fdfb0c8718919f1ee37eccda9eef89a7b51d2db99e16b76780   # sidecar == packaged
GOOD_HELPER_SHA=0f7552819c1092bb63b330ee25de83b1902ba38dbe927eed83b52947a8844924
SEED_REPO_INSTALL=0
FAILED_REINSTALL_RC=1               # protocol source hidden → build aborts
PRIOR_PACKAGE_INTACT=yes            # prior helper + protocol survive the failed reinstall
NO_STAGING_LITTER=yes              # asserted by install-claude-failure-no-staging-litter (sh run)
```

## Owned-file content hashes (this run)

```
0f7552819c1092bb63b330ee25de83b1902ba38dbe927eed83b52947a8844924  bin/polylane-hooks.sh
48810838f131da558f6c5f40d9a5109c6401228047bab52fa9c6f47d7931c088  assets/hooks/claude-settings.json
585a21dda89c748ec6b5f344903c09285a37b412725065c5de79b279d523c064  assets/hooks/codex-hooks.json
e9d50780b68f06a1b703eaae8e099f470d6269704553bfd64b915a5a4db78ada  claude-code/install.sh
795f7c3bbbc63b400a007d7672958723db2765166d6f521be86abb279487043e  tests/test-hooks.sh
a426f8aaad26028d4391ef28fa56eee6f39660206c3d0fd78cea6205a19a36e0  tests/test-installers.sh
ff19004b611bd59ffef6bac314c94a17bbfe7a838ecdbabc46314dc51245ab99  tests/test-install-fresh.sh
```

## Fresh-install hermetic proof (no real user root touched)

`tests/test-install-fresh.sh` runs a real `claude-code/install.sh --user` under a
fake `$HOME`, verifies the packaged protocol hash is authentic and matches the
provenance sidecar, renders both provider fragments against the actually-installed
helpers, and executes every Claude hook command (and the Codex SessionStart command
inside a git repo) in a blank target repo. Section 5 snapshots the real
`~/.claude/settings*.json`, `~/.codex/config.toml`, and both `skills/polylane` roots
before/after and asserts them unchanged.

## Naming mismatch

Docs/tests reference the existing `tests/test-installers.sh` and
`tests/test-install-fresh.sh` (confirmed in `bin/polylane-certify.sh` terminal
gate). No misleading empty `test-install.sh` alias was created; a full-repo grep
for `test-install.sh` returns nothing outside the two real files.

## VERIFY commands (all green)

```
tests/test-hooks.sh          → 53 pass, 0 fail
tests/test-installers.sh     → 80 pass, 0 fail
tests/test-install-fresh.sh  → 63 pass, 0 fail
shellcheck -S warning bin/polylane-hooks.sh claude-code/install.sh → clean
git diff --check             → clean
```

TDD: red/green fixtures added first for locate/render (`test-hooks.sh`), protocol
packaging + build-failure preservation (`test-installers.sh`), and hermetic
render/execute + no-real-root (`test-install-fresh.sh`); each failed before the
implementation landed.

## SKILL receipts

- SKILL-READ: caveman:safe-refactor | /Users/leonardo/.codex/plugins/cache/caveman/caveman/local/skills/safe-refactor/SKILL.md | cd52867aba26aafb53379d43068cef9b2feca3a3fff850f877a99f710ccd02c0
- SKILL-READ: engineering:system-design | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/system-design/SKILL.md | 8f28eca99f2208872fc2483fcc93326b628f4f73116e91309a95e05da86a0ab5
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 5c5e95830754bbdd838213fa05fc8f07523f591fd558fd3c86031ffd479f7a9e
- SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | bf1b8216e523851a411e91d429a7c1c2a173e79d88957bc78e348218d50edd54

- SKILL-EVIDENCE: caveman:safe-refactor — helped: defined the behavior-preservation boundary — the render/locate additions and the trap-based staging cleanup preserved every existing hook output schema and installer path (existing 32 hook + prior installer assertions stayed green throughout); one ownership boundary (helper vs template vs installer) moved at a time.
- SKILL-EVIDENCE: engineering:system-design — helped: chose a single self-locating helper + template-substitution renderer over per-hook inline path logic (explicit trade-off: one locator, no duplicated fragment logic), with a guarded fail-safe exec as the runtime reliability boundary.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: covered the real risk surfaces — installed-path resolution, live hook execution in a blank repo, protocol hash authenticity, build-failure preservation, and a hermetic no-real-root boundary — rather than trivial getters.
- SKILL-EVIDENCE: superpowers:test-driven-development — helped: every behavior was written as a failing assertion first (21 hook + 5 installer reds confirmed) and driven to green with minimal code; the staging-litter red exposed that `build_one`'s `exit` skipped cleanup, which the trap fixed.

## DEFERRED

DEFERRED: Codex install parity relayed to codex-parity (coordination seq 9) —
Codex `codex/install.sh` must package the same authoritative protocol into
`references/taste-certification-protocol.md` with a sha256 provenance sidecar,
assert visual/taste helpers + protocol present, and clean staging on build
failure; `codex-hooks.json` render contract is already in place on the shared
helper. Legacy `assets/settings-hook-snippet.json` (still hardcoding the broken
path, outside this lane's write boundary) relayed to integrator (seq 10). Both
are unconfirmed at handoff.
