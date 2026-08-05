# verify: docs-truth (run c1-1785879548)

`tests/test-docs-truth.sh` proves the README, AGENTS.md, and
`references/install-helpers.md` don't lie: the paths/scripts/flags/install
commands they quote are real. Hermetic — verifies existence, never installs.

## Result

```
$ bash tests/test-docs-truth.sh
... 13 pass, 2 fail
$ tests/run.sh
SUMMARY: 707 passed, 2 failed, 53 test files
FAILED FILES: test-docs-truth.sh
```

The 2 fails are one real doc-lie (see DEFERRED). Every other assertion is green;
the rest of the suite is unaffected (707/707 of the other files pass).

## What each section proves (all GREEN)

1. **README paths exist** — `codex/install.sh`, `references/install-helpers.md`,
   `LICENSE` all present; the Quickstart flag `codex/install.sh --user` is a real
   flag (`codex/install.sh:14`). Runtime outputs (`docs/polylane-report.md`,
   `docs/lane-logs/*`) are generated, so they are deliberately not asserted.
2. **bin scripts real+executable** — every `bin/polylane-*.sh` named in README
   (dashboard, doctor, notify, run) exists and is `-x`. Extracted by grep, so new
   doc mentions are covered automatically.
3. **tests/run.sh** — exists and is executable (the command AGENTS.md must cite).
4. **No install-path drift** — the `~/.claude/skills/polylane` clone line is
   byte-identical in `SKILL.md:660` and `install-helpers.md:13`; README's own
   `codex/install.sh` and `brew install tmux jq` lines reappear verbatim in the
   reference.

## DEFERRED — the doc-lie this test intentionally fails on

- **`agents-md-present` / `agents-md-cites-runsh` (RED):** there is **no root
  `AGENTS.md`**, yet `SKILL.md:465` certifies a shippable repo must carry
  "a root AGENTS.md exists with real run/build/test commands" and `SKILL.md:594`
  calls it "the cross-agent context anchor". polylane is self-hosting, so its own
  root must satisfy its own gate. It does not. Per the lane contract
  ("if a DOC is wrong, do NOT edit it — the test SHOULD fail red; the next cycle
  fixes the doc"), the assertion is **not weakened**. Fix = a next cycle adds a
  root `AGENTS.md` naming `tests/run.sh` as the test command; this test then goes
  fully green with no edit.

No external evidence (network / credentials / real installs) was needed — the
whole test is file/flag existence in-tree.
