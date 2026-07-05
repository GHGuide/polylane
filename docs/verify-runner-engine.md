# verify-runner-engine.md — evidence for bin/polylane-run.sh

Lane: **runner-engine**. Owns `bin/polylane-run.sh`, `.polylane/SCHEMA.md`.
Built TDD: 37-assertion fixture suite (sourced functions + fake status/manifest
fixtures) run to green before this doc. Every claim below is real command output.

Host note: `tmux` + `claude` are present in the test shell; the missing-dep case
below is exercised by running with a PATH that excludes `tmux`.

---

## Goal 1 — arg parsing + `--help`; non-zero on bad args

```
$ bash -n bin/polylane-run.sh && echo OK
OK

$ bash bin/polylane-run.sh --help   # (exit 0)
polylane-run.sh — parallel-lane build engine (worktrees · tmux · git · claude)
USAGE:
  bin/polylane-run.sh <manifest.json> [--dry-run] [--yes]
... (full usage) ...
[exit=0]
```

Bad args (from the suite):
- no args → exit **2**
- `--bogus` unknown flag → exit **2**
- `--help` → exit **0**
- defaults: `--dry-run`/`--yes` off unless passed

## Goal 2 — preflight names the missing dep, exits 1

Real run with `tmux` removed from PATH:

```
$ PATH="<no-tmux>" bash bin/polylane-run.sh sample.json
polylane-run: missing required dependencies: tmux
  tmux = pane management, claude = builders, jq = manifest parse, git = worktrees
  install the missing tool(s) and retry.
[exit=1]
```

Invalid-JSON manifest → `polylane-run: manifest is not valid JSON` + exit 1
(suite: `preflight: bad json exit 1`).

## Goal 3 — split creates worktrees idempotently

Dry-run prints the add per lane, branched from `base`:

```
== split: 2 lane worktrees ==
+ git worktree add ../pl-api -b lane/api main
+ git worktree add ../pl-ui -b lane/ui main
```

Real-git idempotency (suite `add_worktree: idempotent skip 2nd time`): second
`add_worktree` on the same path prints `worktree/path already exists, skipping`
and returns 0 — no duplicate worktree.

## Goal 4 — launch: tmux session `polylane`, one seeded pane per lane

Dry-run prints every command; the pane seeds `claude` from the prompt file and
carries the clipboard fallback:

```
== launch: tmux session 'polylane' ==
+ tmux new-session -d -s polylane -n api
+ tmux send-keys -t polylane cd '../pl-api' && claude --model 'claude-opus-4-8' "$(cat '.polylane/prompts/api.txt')" || { pbcopy < '.polylane/prompts/api.txt' 2>/dev/null || xclip -selection clipboard < '.polylane/prompts/api.txt' 2>/dev/null; echo 'SEED FAILED — prompt copied to clipboard; paste it into claude'; claude --model 'claude-opus-4-8'; } C-m
+ tmux split-window -t polylane
+ tmux select-layout -t polylane tiled
+ tmux send-keys -t polylane cd '../pl-ui' && claude --model 'claude-fable-5' "$(cat '.polylane/prompts/ui.txt')" || { ... clipboard fallback ... } C-m
```

`--dry-run` PRINTS every command and executes nothing (no worktree, tmux, or
delete side effects); a real run opens the panes.

## Goal 5 — poll until every DONE file's first line matches

Real run against hand-written status files:

```
$ poll_done "a:.../wt-a" "b:.../wt-b"   # both first lines == "STATUS: <n> DONE"
poll: 2/2 lanes DONE
[exit=0]
```

With one file whose DONE is NOT the first line, the loop reports `poll: 1/2
lanes DONE` and keeps polling (never exits) — proving the first-line-exact check.
`lane_done` unit cases: correct-first-line → 0; DONE-on-later-line → 1; missing
file → 1.

## Goal 6 — integrator starts automatically after builders DONE

```
== integrator: integrator ==
+ git worktree add ../pl-integrator -b lane/integrator main
+ tmux split-window -t polylane
+ tmux select-layout -t polylane tiled
+ tmux send-keys -t polylane cd '../pl-integrator' && claude --model 'claude-opus-4-8' "$(cat '.polylane/prompts/integrator.txt')" || { ... } C-m
+ (dry-run) would poll for DONE: integrator:../pl-integrator
```

`main` runs the builder poll, then `run_integrator`, then the integrator poll —
no manual step between.

## Goal 7 — merge gate: proceed only on explicit GO

Real NO-GO verdict → stop, print verdict, exit non-zero, delete nothing:

```
$ merge_gate   # verify-integration.md ends "VERDICT: NO-GO"
Integrator verdict: NO-GO — NOT a GO. Stopping. Nothing deleted.
--- .../verify-integration.md ---
# integration
conflicts found
VERDICT: NO-GO
[exit=1]
```

`parse_verdict` cases: `VERDICT: GO` → GO; `NO-GO` → NO-GO (checked first, so the
`GO` substring inside `NO-GO` cannot false-positive); no verdict / missing file →
UNKNOWN (treated as not-GO).

## Goal 8 — one confirm → delete (kept evidence)

Cleanup (dry-run, `--yes` skips the prompt) removes worktrees, merged branches,
and scratch — and keeps the evidence:

```
== cleanup ==
+ git worktree remove --force ../pl-api
+ git worktree remove --force ../pl-ui
+ git worktree remove --force ../pl-integrator
+ git branch -d lane/api
+ git branch -d lane/ui
+ git branch -d lane/integrator
+ rm -rf <repo>/.polylane
+ rm -f <repo>/docs/status-api.md
+ rm -f <repo>/docs/status-ui.md
+ rm -f <repo>/docs/status-integrator.md
Cleanup complete. Kept: docs/verify-*.md, docs/parallel-status.md
```

Without `--yes` the engine prompts `Delete N worktrees + branches + .polylane
scratch? [y/N]` and aborts on anything but yes.

## Goal 9 — safety

- `git branch -d` only (suite asserts the output never contains `branch -D`).
- `safe_rm` refuses any path outside the repo root:
  ```
  $ safe_rm /etc/hosts       # REPO_ROOT set elsewhere
  safe_rm REFUSED (outside repo root <repo>): /etc/hosts
  [exit=1]
  ```
- Merge conflict → `assert_no_conflict` exits non-zero, worktrees intact
  (checks `git ls-files --unmerged`).
- No `git add -A` anywhere in the script (grep-clean).

## Goal 10 — .polylane/SCHEMA.md

Documents the manifest keys, the CLI + exit codes, the DONE-file convention, the
verdict file, the full lifecycle + pane command, deps, and safety guarantees.

---

## Test suite result

```
PASS=37 FAIL=0
```

Covers: parse_args (7), preflight incl. missing-dep + bad-JSON, lane_done (3) +
poll, parse_verdict (4), split/launch/integrator dry-run, cleanup + safe_rm,
real-git worktree idempotency.
```
$ bash -n bin/polylane-run.sh   # → OK, no syntax errors
```
