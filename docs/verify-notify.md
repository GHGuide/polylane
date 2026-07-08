# Verify — lane `notify`

Target: `tests/test-notify.sh` covering `bin/polylane-notify.sh` (CLI, read-only bin).

## Evidence (`bash tests/run.sh`)

```
== test-notify.sh ==
test-notify.sh: 15 pass, 0 fail

SUMMARY: 202 passed, 0 failed, 15 test files
```

`run.sh` exit code: `0`.

My file: **15 pass, 0 fail**. New suite total: **202 passed, 0 failed, 15 test files**.

## Coverage

- help `-h` / `--help` → usage on **stdout**, exit 0 (branch reached before the osascript check).
- help lists documented events (`no-go`).
- quiet no-op when osascript absent (simulated non-macOS via `env -i`): exit 0 **and** silent.
- frozen "always exit 0" contract across every event — `done`/`go`/`no-go`/`halt`/`stall`, unknown event, empty args, extra args.
- osascript present: empty args → usage on **stderr**, exit 0 (guarded by osascript presence; skip-pass otherwise). Safe: returns before any notification is built.

## Safety

No real macOS notification is ever fired: help returns before the osascript check; all event paths run under a cleared environment (`env -i`) so `command -v osascript` misses and the no-op branch runs; the empty-args path returns before building the AppleScript. bin/ untouched (read-only).

## Non-vacuity (TDD)

Deliberately-wrong expectations were run in a throwaway (not committed) and correctly FAILED:
`SANITY-help-wrong-needle — output does not contain [THIS_SHOULD_NOT_APPEAR]` and
`SANITY-noop-not-silent — expected [GARBAGE] got []`, proving the assertions are live.
