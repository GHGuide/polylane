# verify-integration.md — max-upgrade round (integrator)

Date: 2026-07-08 · Integrator model: claude-fable-5 (effort high) · Base: `main` @ c1cbf25 pre-merge → `a9b9fa8` post-merge+fix. Fresh re-verify of current branch tips — no prior GO trusted.

> Provenance note: this file was first written in the integrator worktree, where the live
> runner consumed it (gated GO) and then cleaned up the worktree + `lane/integrator`
> branch before the integrator's evidence commit landed. Content re-landed here on
> `main` directly, unchanged; the race is logged below in §4 and recommended for a
> runner follow-up. A disk-full (ENOSPC) window also interrupted the re-land; space was
> freed and this write completed after.

## 1. Re-merge — all 9 lane tips into main (goal 1)

All 9 builder lanes had `STATUS: <lane> DONE` as first line of their status file before merging (checked per worktree). Merge order: engine → dashboard → doctor-notify → tests → planner-skill → run-skills → readme → evals → assets. **Zero conflicts** — every merge completed clean, no manual resolution.

| Lane | Tip merged | `rev-list --count main..lane/<x>` | Result |
|---|---|---|---|
| engine | ca535c5 | 0 | merged clean (runner: --resume/--push, auto-retry, report, POLYLANE_SESSION) |
| dashboard | aabddc4 | 0 | merged clean (bin/polylane-dashboard.sh) |
| doctor-notify | b3408fa | 0 | merged clean (bin/polylane-doctor.sh, bin/polylane-notify.sh) |
| tests | 9d19a66 | 0 | merged clean (8-file suite + fixtures) |
| planner-skill | 318a466 | 0 | merged clean (SKILL.md + references/, 16 drift fixes) |
| run-skills | 127bf56 | 0 | merged clean (polylane-run/SKILL.md, polylane-auto/SKILL.md) |
| readme | 38f9465 | 0 | merged clean (README.md) |
| evals | 0fd03ef | 0 | merged clean (evals/*.json, 71 cases) |
| assets | b252050 | 0 | merged clean (assets/q.py, nudge hook) |

**0 commits at risk** — rev-list re-checked fresh immediately before the verdict was issued.
Post-check note: `lane/assets` later fast-forwarded itself to the merged main tip `d46cb65` (reflog: "merge main: Fast-forward", from inside its worktree). Its real work commit b252050 was already merged; the branch contained nothing beyond main; at-risk still 0. Harmless (branch since removed by runner cleanup).

## 2. Contract cross-checks (goal 2 — each quoted from the MERGED tree)

### (a) Runner CLI — usage() == polylane-run/SKILL.md == polylane-auto/SKILL.md == README — PASS
- `bin/polylane-run.sh:32` (usage): `bin/polylane-run.sh <manifest.json> [--dry-run] [--yes] [--resume] [--push] [--intensity <economy|balanced|performance|max>] [--model <lane=model_id>]...`
- `polylane-run/SKILL.md:144`: `[--push] [--resume] [--intensity <economy|balanced|performance|max>] ...`
- `polylane-auto/SKILL.md:135`: `[--push] [--resume] [--intensity <economy|balanced|performance|max>] ...`
- `README.md:111`: `polylane-run.sh <manifest> [--dry-run] [--yes] [--push] [--resume] [--intensity ...] [--model lane=id]`
- Same flag SET everywhere; only listing order differs (cosmetic). run-skills lane's note "usage() does not yet list --resume/--push" was written pre-engine-merge; the merged usage() DOES list both (verified live via `--help`).
- Minor: `bin/polylane-run.sh:14` file-header comment still reads `[--dry-run] [--yes]` only — stale intra-file comment in engine's own file, not a cross-lane mismatch; noted, not fixed.

### (b) Helper CLIs match scripts + docs — PASS
- doctor script `USAGE: bin/polylane-doctor.sh [manifest.json]` == `polylane-run/SKILL.md:58` + `polylane-auto/SKILL.md:68` "CLI `bin/polylane-doctor.sh [manifest]` — the manifest argument is optional". Exit contract verified live (FAILs present → exit 1).
- dashboard script `USAGE: bin/polylane-dashboard.sh <manifest.json> [--interval N]` + `--demo` == `polylane-run/SKILL.md:156` + `polylane-auto/SKILL.md:80` "CLI: `bin/polylane-dashboard.sh <manifest> [--interval N]`" == `README.md:173` `bin/polylane-dashboard.sh --demo`.
- notify script `USAGE: bin/polylane-notify.sh <event> <message>`; events in script (:49-52): `go)Glass · no-go|halt)Basso · done)Ping · stall)Sosumi` == docs event list `done|go|no-go|halt|stall` (`polylane-run/SKILL.md:163`, `polylane-auto/SKILL.md:93`).

### (c) DONE marker + report filename + manifest schema — PASS
- DONE marker `STATUS: <lane> DONE` identical in: `bin/polylane-run.sh:479` (`[ "$first" = "STATUS: $name DONE" ]`), `SKILL.md:40,:88`, `references/lane-template.md:30,:110`, `references/prompt-blocks.md:73`, `references/merge-and-cleanup.md:27`, `.polylane/SCHEMA.md` DONE-file convention, dashboard states table.
- Report filename `docs/polylane-report.md` consistent across all 7 referencing files: `bin/polylane-run.sh`, `polylane-run/SKILL.md`, `polylane-auto/SKILL.md`, `README.md`, `SKILL.md`, `references/merge-and-cleanup.md`, `tests/test-write-report.sh`.
- Manifest schema keys (`base, intensity?, available_models?, integrator{name,model,branch,worktree,prompt_file,effort?}, lanes[{…,own_globs}]`): `.polylane/SCHEMA.md` == fixture `tests/fixtures/project/.polylane/run.json` == runner load_manifest (`test-load-manifest.sh` green in suite) == planner references (keys frozen, unchanged).

### (d) Mandatory-4 order — PASS
Order `/graphify-auto → caveman → /goal → superpowers:using-superpowers` identical in: `SKILL.md:38`, `SKILL.md:81`, `references/lane-template.md:15` (`[0 MANDATORY-4 preamble: /graphify-auto · caveman(full) · /goal <lane goal> · superpowers:using-superpowers]`), `references/prompt-blocks.md` block 0 (+ :14 "never dropped or reordered"), `polylane-auto/SKILL.md:34`, `references/model-selection.md:82` (intensity varies caveman LEVEL only; step never dropped/reordered).

### (e) Price table: report == references/model-selection.md — PASS
- `references/model-selection.md:7-10`: Fable $10/$50 · Opus $5/$25 · Sonnet $3/$15 (*intro $2/$10 through 2026-08-31; sticker rate used*) · Haiku $1/$5 per 1M in/out.
- `bin/polylane-run.sh:801-803` comment: "Price table cached from references/model-selection.md (confirmed 2026-07): Fable 5 $10/$50, Opus 4.8 $5/$25, Sonnet 5 $3/$15, Haiku 4.5 $1/$5" — verbatim match.
- `model_out_price()` codes output rates 50/25/15/5 — matches the table's output column exactly.
- Generated report footer cites the source: "rough, output-rate pricing from `references/model-selection.md`" (captured live from a runner-produced report).

### (f) q.py subcommands unchanged + --json additive — PASS
- Pre-merge (c1cbf25) vs merged `assets/q.py`: dispatch set identical — default find, `callers`, `uses`, `near`, `file`, `community`; `--json`, `--graph`, `--cap` present in BOTH versions.
- Diff (+57/−6) adds only internal helpers `suggest()`/`miss()` (miss-suggestions), community field in callers/uses/near output, and a file-handle-leak fix. No CLI surface removed or renamed.
- prompt-blocks Block E lists 4 subcommands + default; `community` omitted there by documented contract design (evals + assets lanes both state this) — consistent, not a contradiction.

## 3. Test + smoke evidence (goal 3 — all run on the merged tree)

| Check | Command | Result |
|---|---|---|
| Syntax | `bash -n bin/*.sh` (5 scripts) | all OK |
| Suite | `bash tests/run.sh` | **112 passed, 0 failed, 8 test files — exit 0** (run twice: post-merge and again post-SCHEMA-fix; both green) |
| Doctor | `bin/polylane-doctor.sh tests/fixtures/project/.polylane/run.json` | runs; `12 PASS · 1 WARN · 2 FAIL` → **exit 1** (correct: fixture's placeholder `/abs/prompts/integrator.txt` missing + live tmux session `polylane` exists — both genuine findings) |
| Dashboard | `bin/polylane-dashboard.sh --demo --interval 1` (6 s capture) | renders demo table: 4 fabricated lanes, states cycling waiting/working, `0/4 done · session polylane · refresh 1s` footer |
| q.py plain | `python3 assets/q.py --graph graphify-out/graph.json parse_args` | `bin_polylane_run_parse_args [parse_args()] bin/polylane-run.sh:95` — 1 match |
| q.py --json | same + `--json` | valid JSON: `{"query": "parse_args", "count": 1, ...}` |
| Runner dry-run (fixture) | `bin/polylane-run.sh tests/fixtures/.../run.json --dry-run` | full split/launch/poll print; halts at fixture's placeholder integrator prompt with clear message, exit 1 (correct preflight) |
| Runner dry-run, complete 2-lane manifest, `--resume --push` | scratchpad copy of fixture + real integrator prompt | **exit 0**; full flow printed: split → launch (`POLYLANE_EFFORT=medium claude --model claude-sonnet-5 …` prefix present) → poll → integrator → gate on `verify-integration.md` (proceed only on GO) → cleanup → `== push: current branch == / + git -C <root> push` (--push honored) → report written |
| Flag parsing | `--bogus` → **exit 2** + usage; `--resume` → `RESUME=1` (`bin/polylane-run.sh:128`); `--push` → `PUSH=1` (`:129`); push step at `:954-956` | rejected/parsed correctly |

## 4. Missing / unverified / regressed (goal 4)

- **Unverified (accepted, bounded):** `--resume` skip-behavior against a pre-existing valid DONE file and a live (non-dry-run) `--push` were not exercised end-to-end here (needs a real multi-pane run); covered by engine lane's own 32-pass test file per its verify doc, plus the live parse/code-path evidence above. The frozen suite (`tests/`) intentionally carries no --resume/--push cases (frozen-contract scope).
- **Known wart (engine-owned, NOT fixed — intra-lane, not cross-lane):** `write_report` runs even under `--dry-run`, writing a real `docs/polylane-report.md` with a fabricated "Outcome: GO" into the repo (untracked). Evidence preserved in integrator scratchpad; residue removed. Recommend engine guard report-writing behind dry-run in a follow-up.
- **Race (runner-owned, follow-up recommended):** the runner gates on the integrator worktree's `verify-integration.md`/DONE file and starts cleanup immediately — it deleted the integrator worktree + `lane/integrator` branch BEFORE the integrator's evidence commit/merge could land. No lane work was lost (all 9 tips were already merged; cleanup uses `git branch -d`, merged-only), but integrator evidence had to be re-landed on main directly. Recommend the runner wait for the integrator's evidence commit (or copy the verify file out) before worktree removal. Runner cleanup also `rm`'d the tracked `.polylane/SCHEMA.md` along with the `.polylane/` scratch dir (restored from HEAD, content intact) and self-committed the status-scratch removal (df85444).
- **Stale intra-file comment (engine-owned, NOT fixed):** `bin/polylane-run.sh:14` header CLI comment lacks the new flags; usage() at :32 is correct.
- **Fixed on main (logged FIRST in docs/parallel-status.md, then committed as a9b9fa8):** `.polylane/SCHEMA.md` synced to the merged runner contract — CLI synopsis + `--resume`/`--push` table rows, env vars `POLYLANE_SESSION`/`POLYLANE_HEALTH_INTERVAL`/`POLYLANE_MAX_RETRIES`, pane-command `POLYLANE_EFFORT` prefix. Exactly the 3 spots the engine lane flagged for the integrator. Suite re-run green after the fix.
- **Environment:** ENOSPC (disk full) hit twice this session — once during prior round (logged then), once during this round's evidence re-land. `doctor` correctly WARNs at <5GB free.
- **Regressions:** none found — suite green, q.py CLI byte-compat vs pre-merge, no renamed contracts, all frozen names intact.
- Historical (prior round, no action): f53b9e9 shared-index ride-along already verified clean by the prior integrator.

## 5. Verdict

All 9 current tips merged with 0 conflicts and 0 commits at risk (re-checked fresh); every frozen contract (a)–(f) evidenced with quoted lines and zero unresolved contradiction; suite 112/112 green on the merged tree; smokes captured for doctor, dashboard, q.py (plain + json), and runner dry-run incl. `--resume`/`--push`.

VERDICT: GO
