# Verify — tests/test-install-fresh.sh

## Repair reflection (attempt 1)
1. What went wrong: a repair was dispatched though the prior run had already
   written the test, gone 20/0 + suite 714/0, and committed (HEAD 76be3ae).
2. Root cause: not a code failure — the lane process exited before the
   health-check registered the DONE signal, so the orchestrator re-dispatched.
3. Different approach: re-run verification to prove the committed work is still
   green rather than rewriting a passing test, then re-emit the DONE signal.


Hermetic proof a fresh clone installs BOTH documented skill layouts. Everything
runs under `$TEST_TMPDIR` fake HOMEs; the real `~/.claude` / `~/.codex` are
never touched.

## What it pins

1. **CLAUDE layout** — the documented `cp -R . ~/.claude/skills/polylane/`
   yields `SKILL.md` + executable `bin/polylane-run.sh` / `bin/polylane-memory.sh`
   + `references/` + `assets/`.
2. **CODEX layout** — `HOME=<fake> codex/install.sh` (with `<fake>/.codex/skills`
   pre-created so the installer picks the `.codex` path) lays out
   `<fake>/.codex/skills/polylane`: valid `name: polylane` frontmatter,
   >=20 executable `scripts/*.sh` (25 present), `references/prompt-blocks.md`,
   `assets/`. A **reinstall** overwrites in place — no nested
   `references/references` (the fixed `cp -R dir existing-dir` bug, pinned).
3. **Both layouts** — `polylane-memory.sh` runs standalone from its installed
   location: `init` succeeds (rc 0); a fresh state is not complete, so `met`
   exits 1. Skipped with one PASS if `jq` is absent.

## Run

```
$ bash tests/test-install-fresh.sh
test-install-fresh.sh: 20 pass, 0 fail
```

Under the full suite:

```
test-install-fresh.sh: 20 pass, 0 fail
SUMMARY: 714 passed, 0 failed, 53 test files
```

Assertions verified to bite (not vacuously green): the no-nest check catches a
seeded `references/references`; `met` returns rc 1 only because a fresh state
has zero criteria (init rc 0 vs met rc 1 confirmed by direct run).

## DEFERRED

none
