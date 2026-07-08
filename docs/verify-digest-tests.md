# Verify — digest-tests lane

Lane: `digest-tests` (branch `lane/digest-tests`). Model: Opus 4.8.

## What was added

`tests/test-digest.sh` — covers `bin/polylane-digest.sh <baseline-ref> [repo-root]`
(read-only change-inventory dumper). CLI is invoked, never sourced. Fixture is a
throwaway git repo built under `$TEST_TMPDIR`.

6 behaviors, one assertion each:

| Assertion | Behavior covered |
|---|---|
| `digest-commits` | `## Commits` — `git log --oneline BASE..HEAD` lists the new commit |
| `digest-diffstat` | `## Files changed (diffstat)` — diffstat summary (`insertion`) printed |
| `digest-new-files` | `## New files` — added file shown as `  + added.txt` |
| `digest-verify-summary` | `## Verify-file summaries` — `docs/verify-*.md` summarised |
| `digest-usage-exit-2` | no args → usage on stderr, **exit 2** |
| `digest-unknown-ref-exit-1` | unresolvable baseline ref → **exit 1** |

No jq dependency in the target → no skip guard needed (git only; git is a suite given).

## Evidence — my file alone

```
$ bash tests/test-digest.sh
PASS digest-commits
PASS digest-diffstat
PASS digest-new-files
PASS digest-verify-summary
PASS digest-usage-exit-2
PASS digest-unknown-ref-exit-1
test-digest.sh: 6 pass, 0 fail
```

## Evidence — full suite (`tests/run.sh`)

```
== test-abs-prompt.sh ==
== test-digest.sh ==
test-digest.sh: 6 pass, 0 fail
== test-intensity.sh ==
== test-lane-done.sh ==
== test-load-manifest.sh ==
== test-memory.sh ==
== test-pane-errored.sh ==
== test-parse-args.sh ==
== test-parse-verdict.sh ==
== test-reflexion.sh ==
== test-write-report.sh ==
SUMMARY: 144 passed, 0 failed, 11 test files
```

My file: **6 pass, 0 fail**. New suite total: **144 passed, 0 failed, 11 test files** (0 failed files).
