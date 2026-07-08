# verify-readme — evidence for the README refresh

Lane: `readme`. Scope: `README.md` only. Every claim below is backed by an artifact
(the frozen lane contract, `bin/polylane-run.sh`, or a sibling lane's frozen
HARD CONTRACT read read-only from `.polylane/lanes/*.txt`).

## Sections added / changed (one line + reason each)

| Section | Change | Reason |
|---|---|---|
| Title hook + intro | Rewritten: product = 3 skills (plan / run / auto), not just paste-prompts | Old hook described plan-only product; runner + auto now exist |
| Three entry points | Moved from Install to top, bullets kept verbatim | Goal item 1: "3 entry points" up front |
| Quickstart | NEW: clone + 2 `cp` installs, `brew install tmux jq` (shellcheck optional), 5-line happy path (`/polylane-auto` → two gates → walk away → `docs/polylane-report.md`) | Goal item 1 |
| Why vs swarm table | ONLY "Cost" cell updated ("You launch the terminals" → one visible tmux pane per lane, `tmux attach`) | Stale: runner now launches; rest of table untouched (goal item 3: keep voice) |
| Why vs brainstorming | Pipeline line gains "launch" step | Stale: pipeline now includes launching |
| Token efficiency | Unchanged | Not stale |
| Step by step | Steps 6–7 rewritten: runner launches/polls/retries; report added | Old text said "You launch the prompts" only |
| The feature tour | NEW: runner CLI line + one short section each — report, auto-retry, stall detection, `--resume`, `--push`, `POLYLANE_SESSION`, dashboard (`--demo`, `--interval`), doctor, notify sounds, lane logs | Goal item 2 (incl. niche features) |
| Requirements | Rewritten honest: tmux+jq only for run/auto; notify macOS-only; shellcheck optional dev-only | Goal item 4 |
| Troubleshooting | NEW: usage-limit stalls (what you'll see / what to do), disk space (doctor thresholds), tmux session collisions → `POLYLANE_SESSION` | Goal item 4 |
| Design principles, License | Unchanged | Not stale |

## CLI-string audit — every string in README vs its artifact

Extraction command (run on final README):

```
grep -o -E '\-\-[a-z-]+|POLYLANE_[A-Z_]+|polylane-(run|dashboard|doctor|notify)\.sh|docs/(polylane-report\.md|lane-logs/...)' README.md | sort | uniq -c
```

| README string | Artifact confirming it |
|---|---|
| `polylane-run.sh <manifest> [--dry-run] [--yes] [--push] [--resume] [--intensity ...] [--model lane=id]` | Lane contract (frozen, verbatim); `--dry-run/--yes/--intensity/--model` also live in `bin/polylane-run.sh:31-46` usage |
| `--push` (git push current branch after GO+cleanup, off by default) | `.polylane/lanes/engine.txt:14,23` (frozen contract) |
| `--resume` (skip lanes with valid DONE file) | `.polylane/lanes/engine.txt:14,18` |
| `bin/polylane-dashboard.sh <manifest> [--interval N]`, default 5s, read-only, states waiting/working/DONE/FAILED/STALL, `--demo` = 3 fake lanes | `.polylane/lanes/dashboard.txt:14,17,20` |
| `bin/polylane-doctor.sh [manifest]`, PASS/FAIL/WARN, exit 0/1, disk WARN <5GB FAIL <1GB | `.polylane/lanes/doctor-notify.txt:14,17` |
| `bin/polylane-notify.sh <event> <message>`, events done\|go\|no-go\|halt\|stall, sounds Ping/Glass/Basso/Sosumi, macOS-only silent no-op | `.polylane/lanes/doctor-notify.txt:14,18` |
| `POLYLANE_SESSION` (default `polylane`) | `bin/polylane-run.sh:66-67` |
| `POLYLANE_POLL_INTERVAL` (default 15) | `bin/polylane-run.sh:59,467` |
| `POLYLANE_HEALTH_INTERVAL` (default 300) / `POLYLANE_MAX_RETRIES` (default 3) | `bin/polylane-run.sh:60-62,442,468` |
| Auto-retry: transient API 500/overloaded/network, respawn ≤3×, past cap halt + report | `bin/polylane-run.sh:395-397`; `polylane-run/SKILL.md:72-75` |
| Stall: pane matches `usage limit` / `Switch to usage credits` / `Upgrade your plan`; STALL, notify once, NO auto-answer/respawn | `.polylane/lanes/engine.txt:21` |
| `docs/polylane-report.md` on GO and NO-GO; cost figures rough | `bin/polylane-run.sh:614-617,702-726`; engine goal "cost in report"; honesty clause in lane contract |
| `docs/lane-logs/<lane>.log` via tmux pipe-pane; cleanup keeps | `.polylane/lanes/engine.txt:14,24` |
| Install `cp -r … polylane-run/ polylane-auto/` | `polylane-run/SKILL.md:123-127`, `polylane-auto/SKILL.md:113-116`; both dirs exist in repo root |
| tmux + jq required for run/auto only | `polylane-run/SKILL.md:15-20`, `polylane-auto/SKILL.md:107-111` |

No README CLI string exists outside the frozen contract set. Honesty clauses honored:
cost = "rough estimates"; notify = "macOS only"; stall = "that call is yours" (manual).

## Files touched by this lane

- `README.md` (rewrite)
- `docs/verify-readme.md` (this file)
- `docs/status-readme.md` (done signal)

Nothing else edited. Staged with explicit paths only (never `git add -A`).
