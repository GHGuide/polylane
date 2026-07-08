# verify-engine.md — runner-engine hardening evidence

Lane: **engine** · file owned: `bin/polylane-run.sh` · date: 2026-07-08
Test harness: scratchpad `test_engine.sh` (32 tests; sources the script — guarded main intact; `tests/**` untouched, owned by the tests lane).

## Goal 1 — shellcheck-clean

Installed via `brew install shellcheck` (0.11.0). Baseline had SC2034 + 4× SC2004; now:

```
$ shellcheck bin/polylane-run.sh
exit=0
$ /bin/bash -n bin/polylane-run.sh    # bash 3.2.57
OK
```

Two intentional, commented directives remain in-file: SC2034 (`BASE_WT`, kept for sourcers) and SC2016 (`$(cat …)` must expand in the pane's shell).
Quote-safety: `pane_cmd` now `%q`-escapes worktree/model/prompt/effort; seeded commands go through `tmux send-keys -l` (literal). Prompt content is never embedded (read at pane runtime via `cat`).

## Goal 2 — --resume

Unit tests: `resume: done lane skipped at launch`, `pane indices track launched only`, `off -> all lanes launch`, `integrator gets next free pane idx` — all pass.

Demo (scratch repo, lane `alpha` given a fake valid DONE file, lane `beta` unfinished):

```
$ bin/polylane-run.sh .polylane/run.json --dry-run --yes --resume --push
resume: lane 'alpha' already DONE — skipping launch
== split: 2 lane worktrees ==
+ git worktree add …/wt-beta -b lane/beta main        # alpha NOT re-split
lane beta: model=claude-haiku-4-5 effort=low          # only beta launches
+ tmux new-session -d -s polylane -n beta             # beta -> pane 0.0
…
lane int: model=claude-opus-4-8 effort=xhigh          # integrator -> pane 0.1
Launched 1 of 2 lane(s).
```

Pane targeting moved to an explicit index map (`LANE_PANE_IDX`/`INT_PANE_IDX`) so health-check respawn / stats / stall checks stay on the right pane when lanes are skipped. Integrator with a valid DONE file is also skipped (`resume: integrator already DONE — skipping launch` path in main).

## Goal 3 — checkpoint-before-retry

Test `checkpoint: WIP committed on lane branch before respawn` (real git repo + worktree, PATH-shim tmux faking an `API Error: 500` pane):

- after `health_check`: `git log -1` on the lane worktree = `WIP checkpoint (polylane auto-retry: z)`
- `git show HEAD:src.txt` contains the WIP edit (`precious wip`) — work survives the respawn
- branch is `lane/z`; shim log shows `respawn-pane` ran AFTER the checkpoint
- clean tree → no empty commit, retry still runs (second test)

`commit -am` covers tracked edits only — untracked files survive a respawn anyway and bulk-adding would violate the never-`git add -A` rule. A failed commit warns and never blocks the retry.

## Goal 4 — poll status line

Tests `poll: per-lane status line (DONE + elapsed)` + `poll: failed lane line + rc 3`. Live shape (from stall test run):

```
  z · stalled · 0m01s
poll: 0/1 DONE
```

One line per lane per poll: `name · DONE|working|failed|stalled · elapsed`.

## Goal 5 — usage-limit stall detection

Pattern: `usage limit|Switch to usage credits|Upgrade your plan` (case-insensitive) on the pane text. Real-tmux fake-pane tests:

- `stall: paywall pane detected, normal pane not` — pane printing "Upgrade your plan…" detected; pane printing normal output not
- `stall: sticky + notify exactly once` — two consecutive scans fire the `stall` notify event exactly once (hook call log = 1 line)
- `stall: health_check never respawns stalled` — a stalled lane showing an API-error banner consumes 0 retries, is never respawned, never marked failed
- `stall: poll line shows stalled state` — live poll printed `z · stalled · 0m01s`

Stall is a money decision: nothing is auto-answered, nothing respawned; polling waits (a human can answer the pane and the lane resumes). Report gets a `STALLED — usage limit (human decision needed)` row + an attach hint in next steps.

## Goal 6 — cost in report

Price table inlined in `model_out_price` citing `references/model-selection.md` (2026-07): Fable $50, Opus $25, Sonnet $15, Haiku $5 per 1M output tokens. Rough estimate = parsed pane token count × output rate. Sample generated via `write_report`:

```
| Lane | Model | Branch | Result | Tokens | Est. $ |
|---|---|---|---|---|---|
| engine | claude-fable-5 | lane/engine | Goal achieved (312.4k tokens · 41m 2s) | 312400 | $15.62 |
| docs | claude-haiku-4-5 | lane/docs | Goal achieved (88k tokens · 12m) | 88000 | $0.44 |
| evals | claude-opus-4-8 | lane/evals | STALLED — usage limit (human decision needed) | ? | ? |

**Estimated total: $16.06** — rough, output-rate pricing from `references/model-selection.md`; …
```

Parser tests: `32.5k` → 32500, `1.2M` → 1200000, `4567 tokens` → 4567, none → empty; unknown model/stat → `?` and excluded from the total.

## Goal 7 — --push

Parsed (`push: --push parsed`, default off). Dry-run E2E prints on GO after cleanup:

```
== push: current branch ==
+ git -C …/demo.mvCByF push
```

Absent without the flag (`push: absent without flag`).

## Goal 8 — pipe-pane lane logs

Wired after every pane launch (lanes + integrator) and re-issued after respawn (`-o` = no-op if the pipe survived). Live smoke test `pipe-pane: live transcript lands in docs/lane-logs`: text typed into a real pane appeared in `docs/lane-logs/mylane.log`. Dry-run E2E shows the wiring:

```
+ mkdir -p …/docs/lane-logs
+ tmux pipe-pane -o -t polylane:0.0 cat >> …/docs/lane-logs/beta.log
```

Cleanup does not touch `docs/lane-logs/` (kept; cleanup output line updated). Logging is best-effort — an unwritable dir warns and never breaks the run.

## Notify wiring (contract line)

`notify_event` fires `bin/polylane-notify.sh <event> <msg>` ONLY if the sibling hook exists and is executable (tests: called with args / missing → no-op / non-executable → no-op). Events wired: `done` (all builders), `go`, `no-go` (incl. UNKNOWN), `halt` (lane-fail + integrator-fail paths), `stall`.

## Contracts intact (probed fresh)

- CLI: `--help` exit 0; unknown flag exit 2; `--intensity` w/o `available_models` exit 1; unknown preset exit 2; `--model beta=claude-sonnet-5` remaps one lane. New flags additive only: `--resume`, `--push`.
- DONE marker `docs/status-<lane>.md` / report filename `docs/polylane-report.md` / manifest schema: unchanged (no key reads added or renamed).
- `POLYLANE_SESSION` kept. bash-3.2 safe: suite runs under `/bin/bash` 3.2.57; `grep -E 'declare -A|git add -A|branch -D'` → no code hits.
- Source-able: `. bin/polylane-run.sh` executes nothing (guarded main).

## Final test run

```
$ /bin/bash test_engine.sh
pass=32 fail=0
```
