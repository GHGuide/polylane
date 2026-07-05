# verify: runner-skill lane

Lane: runner-skill. Owns `polylane-run/**` (new standalone skill). Evidence below
gathered fresh from `polylane-run/SKILL.md` via grep/sed (see commands run).

## 1. Frontmatter — name + trigger-focused description

Quoted lines 1–4:

```
---
name: polylane-run
description: Use when the user wants to actually LAUNCH the lanes that /polylane planned — locates the run manifest and drives bin/polylane-run.sh to open the tmux panes, auto-poll each lane, auto-integrate, merge on GO, and clean up scratch. Triggers on "/polylane-run", "run the lanes", "launch the terminals", "execute the plan", "start the builders".
---
```

- `name: polylane-run` present.
- Description is trigger-focused (says *when* to fire), not a workflow dump.
- All 5 required triggers present — `grep -qF` per phrase, all OK:
  `/polylane-run` · `run the lanes` · `launch the terminals` · `execute the plan` · `start the builders`.

## 2. Exact CLI invocation matches the frozen L1 contract

Frozen contract: `bin/polylane-run.sh <manifest.json> [--dry-run] [--yes]`,
manifest at `.polylane/run.json`.

SKILL body (grep evidence):

```
46:bin/polylane-run.sh .polylane/run.json --dry-run
54:bin/polylane-run.sh .polylane/run.json
```

- Program: `bin/polylane-run.sh` — exact.
- Manifest arg: `.polylane/run.json` — exact path `/polylane` emits.
- Flags used: `--dry-run` (line 46), bare (line 54), `--yes` documented optional.
  No invented flags. Matches signature exactly.

## 3. Dry-run-FIRST flow

```
28:Run these in order. Do not skip the dry-run.
46:bin/polylane-run.sh .polylane/run.json --dry-run
52:Only after the user approves the dry-run, run the same command **without** `--dry-run`:
```

- Step 3 = dry-run (line 46), shown to user as the review gate.
- Step 4 = bare launch (line 54) only *after* user approves. Dry-run precedes
  bare launch in file order — flow is dry-run-first as required.

## 4. Body followable end-to-end (goal items a–e)

- (a) manifest existence check → line 32 `test -f .polylane/run.json`; MISSING → tell user run `/polylane` first (line 34).
- (b) preflight tmux/jq/claude → line ~38 loop `for t in tmux jq claude`.
- (c) dry-run + show panes → step 3, line 46.
- (d) launch on go-ahead → step 4, line 54.
- (e) explain auto-poll / auto-integrate / merge-on-GO / delete-scratch-after-one-confirm → step 5.

## 5. Deps documented + install line

```
17:- **tmux** — the runner puts each lane in its own pane. `brew install tmux`.
18:- **jq** — the runner reads the manifest with it. `brew install jq`.
19:- **claude** — the Claude Code CLI, on PATH; each pane launches one.
75:cp -r polylane-run/ ~/.claude/skills/polylane-run/
```

- Deps tmux + jq (+ claude) documented with install commands.
- Consumes exactly `.polylane/run.json` (stated: "No other input").
- No hardcoded project paths — generic.
- Install line present (line 75).

## Verdict

All locked done-checklist items satisfied with fresh grep/sed evidence:
frontmatter + 5 triggers + exact CLI signature + dry-run-first + deps + install.
runner-skill lane DONE.
