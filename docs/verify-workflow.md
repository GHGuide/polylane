# verify — process-docs lane (install-helpers, merge-and-cleanup, skill-catalog, README)

Lane = process docs polish. Evidence below. No "done" without it.

## Files edited
- `references/install-helpers.md` — prose install steps → runnable `cp`/`chmod` commands + path vars.
- `references/merge-and-cleanup.md` — added `INT=<integration-branch>` var so verify-before-remove `git log` is runnable verbatim.
- `references/skill-catalog.md` — verified accurate, recommend-never-auto-install rule intact → no edit (smallest-change).
- `README.md` — verified matches SKILL.md → no edit.

## 1. install-helpers.md steps runnable verbatim (traced against this repo)

Ran the doc's commands (SKILL_DIR=PROJECT=this repo):

```
== Step1 precondition check ==     present            # test -f graph.json branch works
== Step2 q.py runs (usage line) == graphify query helper — navigate the repo WITHOUT reading files.
== asset names present ==          graphify-nudge.sh q.py settings-hook-snippet.json
== nudge script syntax ok ==       bash -n OK
== settings snippet valid JSON ==  json OK
```

Result: precondition check, `cp`/`chmod` of `q.py` + `graphify-nudge.sh`, and the settings-snippet hand-off all reference real, runnable assets. Steps are copy/paste-ready.

## 2. Asset-name contract (must match Lane-1's real files)

install-helpers.md references exactly: `assets/q.py`, `assets/graphify-nudge.sh`, `assets/settings-hook-snippet.json`.
`ls assets/` → `graphify-nudge.sh  q.py  settings-hook-snippet.json`. **Match. No rename. No mismatch to log for Lane-1.**
Also matches SKILL.md:23 verbatim.

## 3. README claims vs SKILL.md (no contradiction)

Each README claim traced to a SKILL source line via grep:

| README claim | SKILL source |
|---|---|
| never `git add -A` (README:93) | SKILL.md:47 |
| integrator re-merges current HEADs, never stale GO (README:21,62) | SKILL.md:39,44 |
| quarantine strays into one folder (README:22,62) | SKILL.md:39,46 |
| no "done" without evidence file (README:21,93) | SKILL.md:48 |
| installs graphify helpers during recon (README:40) | SKILL.md:23,25 |
| Fable-only-where-needed / Opus default (README:47) | model-selection.md:17,24 |
| security lanes pinned to Opus (README:47) | model-selection.md:25 |
| high builders / xhigh integrator / medium mechanical (README:48) | model-selection.md:17,18,19,26 |

Result: README feature claims and token-efficiency section are truthful. No stale claim. No integrator escalation needed.

## 4. merge-and-cleanup safety (verify-before-remove → remove → branch -d → quarantine)

Flow reads unambiguous and non-destructive:
- §1 `git log --oneline <lane-branch> ^"$INT"` must be empty before any removal (runnable now that `INT` is defined).
- §3 removal is `git worktree remove --force` (git-aware; discards only build artifacts) — never `rm`.
- §4 `git branch -d` refuses unmerged branches by construction.
- §5 quarantine is `mv` into `<project>-useless/`, never delete; excludes cwd + folders with unique uncommitted work.
Reader can execute cleanup without data loss.
