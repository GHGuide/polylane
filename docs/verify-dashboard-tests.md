# Verify — dashboard-tests lane

Goal: `tests/test-dashboard.sh` covers `bin/polylane-dashboard.sh` and runs green
under `tests/run.sh` alongside the existing suite.

## What the test covers

`bin/polylane-dashboard.sh` is a CLI whose render modes loop forever
(`while :; sleep`), so the test invokes it and asserts output + exit codes — it
never sources the script. One behavior per assertion:

| Assertion | Behavior under test |
|---|---|
| `help-exit-0` | `--help` exits 0 |
| `help-shows-usage` | `--help` prints the usage block |
| `no-args-exit-2` | no args → exit 2 |
| `missing-manifest-exit-2` | manifest path not found → exit 2 |
| `bad-interval-exit-2` | non-integer `--interval` → exit 2 |
| `demo-renders-header` | `--demo` renders a frame (`POLYLANE DASHBOARD`) |
| `demo-renders-lane` | `--demo` renders the fabricated lanes |
| `manifest-renders-lane` | `<manifest> [--interval N]` renders the lane row |
| `manifest-renders-model` | model column comes from the manifest |
| `manifest-done-from-status-file` | table state `DONE` derives from a fake `docs/status-<lane>.md` |

Frame capture: the dashboard is launched in the background, the test waits for
its first flushed frame (bash flushes stdout before its external `sleep`, so a
non-empty capture file already holds a complete frame), then kills it — bounded,
never hangs `tests/run.sh`. Fixtures (manifest + status file) are built under
`$TEST_TMPDIR`. The jq-dependent manifest block degrades to a skip-pass when jq
is absent, matching `tests/test-memory.sh`.

## Evidence — `tests/test-dashboard.sh` standalone

```
$ bash tests/test-dashboard.sh; echo "exit=$?"
PASS help-exit-0
PASS help-shows-usage
PASS no-args-exit-2
PASS missing-manifest-exit-2
PASS bad-interval-exit-2
PASS demo-renders-header
PASS demo-renders-lane
PASS manifest-renders-lane
PASS manifest-renders-model
PASS manifest-done-from-status-file
test-dashboard.sh: 10 pass, 0 fail
exit=0
```

## Evidence — full suite (`tests/run.sh`)

New file's line and the suite total:

```
== test-dashboard.sh ==
PASS help-exit-0
PASS help-shows-usage
PASS no-args-exit-2
PASS missing-manifest-exit-2
PASS bad-interval-exit-2
PASS demo-renders-header
PASS demo-renders-lane
PASS manifest-renders-lane
PASS manifest-renders-model
PASS manifest-done-from-status-file
test-dashboard.sh: 10 pass, 0 fail

SUMMARY: 148 passed, 0 failed, 11 test files
SUITE_EXIT=0
```

`test-dashboard.sh: 10 pass, 0 fail` · new suite total **148 passed, 0 failed,
11 test files**.

Note: the suite total moves as the two sibling lanes land their own
`tests/test-*.sh` files (they add PASS lines; this file adds 10 and 0 fails).
