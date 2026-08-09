# Context-hygiene verification — Cycle 24

## Contract and red/green evidence

`POLYLANE_WORKER_RUN_ID` is optional.  When set, `send` and `import-relay`
persist the validated nonce; `inbox` and `ack` require the same nonce.  With no
nonce, the historical all-history inbox and acknowledgement API remains intact.
The canonical-project/worktree validation and worker lock remain on every path.

The run-scope test was run against `HEAD^` before the checkpoint implementation
(in a temporary detached worktree):
8 passed and 5 failed, specifically current-run inbox isolation, same-run event
tags, rejection of an old acknowledgement, invalid nonce rejection, and the
129-byte nonce bound.  This is the expected RED result.  The current checkpoint
then passed all 13 assertions.

The exact prime-hybrid command is linted as a fixed string, including argument
order:

```bash
"$POLYLANE_PROJECT_ROOT/bin/polylane-workers.sh" inbox "$POLYLANE_PROJECT_ROOT" "$POLYLANE_WORKER_ID"
```

The prompt-lint fixture rejects the reversed form.  Selected and armed kits
reject `graphify` and `graphify-auto` with a navigation-infrastructure error;
direct `graphify-out/q.py` queries remain mandatory when present, without loading
the Graphify skill body.

## Focused green checks

All commands ran through `.polylane/check-cache/context-hygiene`.

| Check | Result |
| --- | --- |
| `bash tests/test-worker-run-scope.sh` | 13 pass, 0 fail |
| `bash tests/test-workers.sh` | 47 pass, 0 fail |
| `bash tests/test-worker-canonical-state.sh` | 23 pass, 0 fail |
| `bash tests/test-promptlint.sh` | 25 pass, 0 fail |
| `bash tests/test-skill-delivery.sh` | 46 pass, 0 fail |
| `bash tests/test-promptopt.sh` | 9 pass, 0 fail |
| ShellCheck: four owned scripts | clean |

Focused total: **163 pass, 0 fail**.

## Legacy compatibility and prompt economy

The scoped test proves that an unscoped caller still sees five historical
events and can acknowledge the old message; a `new-run` caller sees only its
two matching message/relay events and cannot acknowledge the old event.

The observed Graphify skill body is 37,063 bytes.  Keeping it out of every
selected builder kit avoids **37,063 bytes per lane** of navigation-manual
context.  This is a fixed observed baseline, not a dependency on a user-local
installation.

## Exact checkpoint diff

`HEAD^..HEAD` changes nine owned files: 69 insertions and 30 deletions.

| File | + | - |
| --- | ---: | ---: |
| `bin/polylane-promptlint.sh` | 1 | 2 |
| `bin/polylane-promptopt.sh` | 3 | 0 |
| `bin/polylane-scout.sh` | 12 | 1 |
| `bin/polylane-workers.sh` | 35 | 19 |
| `references/prompt-blocks.md` | 4 | 5 |
| `references/skill-catalog.md` | 2 | 2 |
| `references/skill-scout.md` | 4 | 0 |
| `tests/test-promptlint.sh` | 4 | 1 |
| `tests/test-skill-delivery.sh` | 4 | 0 |

This lane additionally adds `tests/test-worker-run-scope.sh` (13 assertions).

## Skill receipts

- SKILL-READ: engineering:testing-strategy | `/Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md` | `2811424084-1279`
- SKILL-READ: superpowers:test-driven-development | `/Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md` | `1657109997-9015`
- SKILL-EVIDENCE: engineering:testing-strategy — helped: split the regression into worker scope, legacy API, prompt contract, and selected-kit boundaries.
- SKILL-EVIDENCE: superpowers:test-driven-development — helped: the scope regression was demonstrated red against `HEAD^` before green confirmation on the checkpoint.

The refinement queue was checked and returned `[]`; no eligible refinement item
required a propose-or-decline decision.

## DEFERRED

DEFERRED: none.
