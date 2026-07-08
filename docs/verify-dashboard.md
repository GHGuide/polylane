# verify-dashboard — evidence for bin/polylane-dashboard.sh

Lane: `dashboard`. Deliverable: `bin/polylane-dashboard.sh` — standalone read-only
live tmux dashboard (`<manifest.json> [--interval N]`, default 5s, plus `--demo`
and `--help`). All output below is real captured output, run 2026-07-08 on
`GNU bash, version 3.2.57(1)-release (arm64-apple-darwin25)` (`/bin/bash`).

## 1. Syntax — `bash -n` clean

```
$ bash -n bin/polylane-dashboard.sh && echo CLEAN
bash -n: CLEAN
$ /bin/bash -n bin/polylane-dashboard.sh && echo CLEAN
/bin/bash (3.2) -n: CLEAN
```

## 2. Live render against a fake manifest + status files (goal 1)

Fixture: 4 lanes + integrator. `alpha` has a DONE file (`STATUS: alpha DONE`),
`beta` has a worktree + non-DONE status file, `gamma` has no worktree,
`delta` has `docs/lane-logs/delta.log` containing `API Error: 500 Internal
server error`, integrator has no worktree. `POLYLANE_SESSION=nosuch` so no
pane data (pure file-driven path).

```
POLYLANE DASHBOARD  .../scratchpad/fakeproj/.polylane/run.json
----------------------------------------------------------------------
LANE             MODEL                  STATE     ELAPSED   TOKENS
alpha            claude-sonnet-5        DONE      5m44s     -
beta             claude-fable-5         working   5m44s     -
gamma            claude-haiku-4-5       waiting   -         -
delta            claude-sonnet-5        FAILED    0s        -
integrate        claude-opus-4-8        waiting   -         -
----------------------------------------------------------------------
1/5 done · session nosuch · total 5m44s · refresh 1s
hint: tmux attach -t nosuch
```

Every state derives correctly: DONE from the status file (runner-identical
first-line test), working from worktree+status, waiting from missing
worktree/status, FAILED from the runner's error signature found in the
lane log. Footer shows N/M done, session, total elapsed, attach hint (goal 2).

## 3. Live render against the REAL running polylane session

Run against this repo's actual `.polylane/run.json` while the 9-lane run was
live (`POLYLANE_SESSION=polylane-fable`). Panes located by
`pane_current_path == worktree` (the real session's panes were NOT in manifest
order — positional `0.idx` addressing would have mislabeled rows):

```
POLYLANE DASHBOARD  /Users/leonardo/Downloads/polylane/.polylane/run.json
----------------------------------------------------------------------
LANE             MODEL                  STATE     ELAPSED   TOKENS
engine           claude-fable-5         working   14h36m    -
dashboard        claude-fable-5         working   14h36m    -
doctor-notify    claude-fable-5         DONE      14h36m    -
tests            claude-fable-5         DONE      15m44s    -
planner-skill    claude-fable-5         DONE      5m10s     -
run-skills       claude-fable-5         DONE      12m24s    -
readme           claude-fable-5         DONE      7m22s     -
evals            claude-fable-5         DONE      14h36m    -
assets           claude-fable-5         DONE      14h35m    -
integrator       claude-fable-5         waiting   -         -
----------------------------------------------------------------------
7/10 done · session polylane-fable · total 14h36m · refresh 2s
hint: tmux attach -t polylane-fable
```

Tokens are `-` here: this Claude Code build never leaves a "N tokens" string
in pane text or scrollback (verified by grepping `capture-pane -S -2000` on
live panes). The column is best-effort by contract; when a pane does print a
token counter the sticky cache keeps the last value seen (proof in §5).

## 4. `--demo` mode (goal 4)

`bin/polylane-dashboard.sh --demo` — no manifest, 3 fabricated lanes +
integrator cycling waiting → working → STALL/FAILED → DONE over a 16-frame
cycle (default interval 1s). Frame 6 of a real run:

```
POLYLANE DASHBOARD  (demo — fabricated lanes, no manifest)
----------------------------------------------------------------------
LANE             MODEL                  STATE     ELAPSED   TOKENS
api              claude-sonnet-5        working   5s        20.2k
ui               claude-fable-5         working   5s        30.0k
docs             claude-haiku-4-5       FAILED    5s        8.5k
integrate        claude-opus-4-8        waiting   -         -
----------------------------------------------------------------------
0/4 done · session polylane · total 5s · refresh 1s
hint: tmux attach -t polylane
```

Earlier frames show `waiting`, later frames show `STALL` (ui, frames 7–9)
and all-`DONE` (frames 15–16); 9 frames were captured in ~8.5s of runtime.

## 5. Unit checks (sourced functions, tmux stubbed)

```
stall-test: first=waiting second=STALL tokens=42.7k
fmt_dur: 42=42s 187=3m07s 3781=1h03m empty=-
err-test: state=FAILED sticky_tokens=42.7k
```

- STALL: identical pane text across frames ≥ `POLYLANE_STALL_SECS` → STALL.
- Token parse: `42.7k tokens` in pane text → `42.7k`; sticky across a later
  frame with no token text (err-test still shows 42.7k).
- FAILED: pane text matching the runner's `pane_errored` regex → FAILED.
- `fmt_dur`: seconds/minutes/hours forms + `-` for non-numeric.

## 6. Robustness / edge cases (goal 3) — exit codes captured

```
== 2. --help ==            rc=0
== 3. no args ==           rc=2
== 4. missing manifest ==  polylane-dashboard: manifest not found: /nope/run.json   rc=2
== 5. invalid JSON ==      polylane-dashboard: manifest is not valid JSON: .../bad.json   rc=2
== 6. bad --interval ==    rc=2
== 7. unknown option ==    rc=2
```

Missing worktree/status → `waiting` (§2, lanes gamma/integrate). No tmux
session → states fall back to files/logs, tokens `-` (§2 ran with
`POLYLANE_SESSION=nosuch`).

## Read-only guarantee

The script contains no redirection to any file, no `mkdir/rm/mv/touch/git`,
only `tmux capture-pane` / `list-panes` / `display-message` reads, `jq` reads
of the manifest, and reads of status files + `docs/lane-logs/*.log`.

## Contract parity with bin/polylane-run.sh (read, not modified)

- DONE test: first line of `<wt>/docs/status-<lane>.md` == `STATUS: <lane> DONE` — same logic.
- Error signature: same regex as the runner's `pane_errored()`.
- Session: `POLYLANE_SESSION`, default `polylane`; manifest paths anchored
  like the runner's `abs_prompt` (PROJECT_ROOT = parent of the manifest dir).
