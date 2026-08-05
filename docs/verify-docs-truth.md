# verify: docs-truth (run c1-1785879548)

## Repair reflection (attempt 3)
1. What went wrong: nothing in the deliverable — it stayed green (16/0 file, 710/0
   suite); prior repair sessions ended before the harness latched DONE.
2. Root cause: session teardown races the DONE-signal latch — not a code/test/
   assertion defect (independently re-ran both from scratch this cycle, still green).
3. Different approach: stop re-touching the artifact after commit — land ONE clean
   commit of the reflection+status, then end the turn with no further tool churn so
   teardown has nothing to race.

## Repair reflection (attempt 2)
1. What went wrong: same as attempt 1 — deliverable green + committed, but the
   session again exited before the harness latched the DONE signal.
2. Root cause: DONE-signal handoff races session teardown; no test/assertion
   defect (re-ran clean: 16/0 file, 710/0 suite).
3. Different approach: land a *fresh commit* of the re-verified DONE state this
   cycle (not just re-emit in-message), so a committed artifact carries the
   signal even if teardown races again.

## Repair reflection (attempt 1)
1. What went wrong: the deliverable was fully built, green, and committed (78834ff),
   but the prior session exited before the harness registered the DONE signal.
2. Root cause: process/session termination raced the DONE-signal handoff — not a
   code, test, or assertion defect (test is 16/0, full suite 710/0).
3. Different approach: no rewrite. Re-verified committed state end-to-end
   (`bash tests/test-docs-truth.sh` + `tests/run.sh` both green) and re-emitted
   the DONE signal rather than repeating any failed build step.

`tests/test-docs-truth.sh` proves the README, `AGENTS.md`, and
`references/install-helpers.md` don't lie: the paths/scripts/flags/install
commands they quote are real. Hermetic — verifies existence, never installs.

## Result — GREEN

```
$ bash tests/test-docs-truth.sh
... 16 pass, 0 fail
$ tests/run.sh
SUMMARY: 710 passed, 0 failed, 53 test files
```

## What each section proves

1. **README paths exist** — `codex/install.sh`, `references/install-helpers.md`,
   `LICENSE` all present; the Quickstart flag `codex/install.sh --user` is a real
   flag (`codex/install.sh:14`). Runtime outputs (`docs/polylane-report.md`,
   `docs/lane-logs/*`) are generated, so they are deliberately not asserted.
2. **bin scripts real+executable** — every `bin/polylane-*.sh` named in README or
   `AGENTS.md` (dashboard, doctor, markers, notify, run) exists and is `-x`.
   Extracted by grep, so a new doc mention is covered automatically (the merged
   `AGENTS.md` added `polylane-markers.sh` and the test picked it up with no edit).
3. **AGENTS.md is the anchor SKILL.md promises** — root `AGENTS.md` is present,
   non-empty, and cites the real test command `tests/run.sh` (`AGENTS.md:16`),
   which itself exists and is executable. Satisfies the `SKILL.md:465`/`:594`
   shippability gate for a self-hosting repo.
4. **No install-path drift** — the `~/.claude/skills/polylane` clone line is
   byte-identical in `SKILL.md:660` and `install-helpers.md:13`; README's own
   `codex/install.sh` and `brew install tmux jq` lines reappear verbatim in the
   reference.

## History (resolved)

An earlier run of this test was RED (2 fails) because the worktree was behind
`main`, which lacked a root `AGENTS.md` — surfaced per the lane's do-not-weaken
contract. Merging `main` brought the real `AGENTS.md`; the test is now fully
green with no assertion weakened. The lie was never in the assertion, only in the
stale worktree.

## DEFERRED

None. Every assertion is file/flag existence in-tree — no network, credentials,
or real installs were needed.
