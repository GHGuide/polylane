# Verify — docs lane (merge-and-cleanup.md + install-helpers.md)

Lane: **docs**. Owns `references/merge-and-cleanup.md`, `references/install-helpers.md`.
Goal: document the automated `bin/polylane-run.sh` delete-scratch-keep-evidence flow, and the polylane-run skill + tmux/jq install steps. Evidence = grep of the shipped docs against the HARD CONTRACT.

## 1. merge-and-cleanup.md — automated flow matches L1's CLI/marker contract

| Contract element | Present? | Quoted line |
|---|---|---|
| CLI signature | ✅ | `bin/polylane-run.sh <manifest> [--dry-run] [--yes]` |
| DONE marker | ✅ | "Each lane signals completion by writing `docs/status-<lane>.md` with a first line `STATUS: <lane> DONE`." |
| Verify merged = 0 at risk | ✅ | ``git log --oneline <lane-branch> ^<integration-branch>   # empty = 0 commits at risk = safe`` |
| One y/N confirm | ✅ | "asks a single `y/N` prompt. Answer `N` (the default) and it aborts without deleting anything. `--yes` pre-answers `y`. `--dry-run` stops before this prompt." |
| Hard-delete worktrees | ✅ | `git worktree remove --force <lane-worktree-path>` |
| Delete merged branches | ✅ | `git branch -d <lane-branch>   # -d refuses an unmerged branch → safe by construction` |
| Remove `.polylane/` | ✅ | "remove `.polylane/` (the runner's working state)" |
| Remove status scratch | ✅ | "remove `docs/status-*.md` (the DONE markers — scratch …)" |
| KEEP verify + parallel-status | ✅ | "`docs/verify-*.md` — the per-lane proof files … NOT scratch." · "`docs/parallel-status.md` — the coordination log." |
| Conflict → abort, delete nothing | ✅ | "**Conflict → abort, delete nothing.** If merging a lane … hits a conflict, the runner aborts the whole cleanup and deletes nothing." |
| Never `rm` outside worktrees/.polylane | ✅ | "**Never `rm` outside worktrees + `.polylane/` + status scratch.** … never `rm`s the main tree, `docs/verify-*.md`, `docs/parallel-status.md`, or any path outside that fixed set." |
| --dry-run deletes nothing | ✅ | "`--dry-run` — print exactly what would be verified and removed, then stop. Deletes nothing." |

Grep evidence (`grep -n` on the shipped file):
```
8:bin/polylane-run.sh <manifest> [--dry-run] [--yes]
20:Each lane signals completion by writing `docs/status-<lane>.md` with a first line `STATUS: <lane> DONE`.
26:git log --oneline <lane-branch> ^<integration-branch>   # empty = 0 commits at risk = safe
41:git worktree remove --force <lane-worktree-path>
42:git branch -d <lane-branch>
47:- remove `.polylane/` (the runner's working state)
48:- remove `docs/status-*.md` (the DONE markers — scratch …)
54:- `docs/verify-*.md` — the per-lane proof files …
65:- **Conflict → abort, delete nothing.** …
66:- **Never `rm` outside worktrees + `.polylane/` + status scratch.** …
```

## 2. install-helpers.md — runner skill install + deps, existing steps intact

Runner-skill install (new section):
```
13:cp -R polylane-run/ ~/.claude/skills/polylane-run/
```

Runtime deps line (new):
```
26:brew install tmux jq      # macOS (Homebrew)
```
Plus a Debian/Ubuntu variant (`sudo apt-get install -y tmux jq`) and a verify line (`command -v tmux … command -v jq …`).

Existing graphify steps untouched (grep confirms still present):
```
52:   cp "$SKILL_DIR/assets/q.py" "$PROJECT/graphify-out/q.py"
56:   cp "$SKILL_DIR/assets/graphify-nudge.sh" "$PROJECT/.claude/hooks/graphify-nudge.sh"
65:   - If `$PROJECT/.claude/settings.json` is absent: hand the user `$SKILL_DIR/assets/settings-hook-snippet.json` …
72:4. **Add the navigation rule to the project's CLAUDE.md** …
```
q.py / graphify-nudge.sh / settings-hook-snippet.json / navigation-rule steps all still present → additive edit, nothing removed.

## 3. Consistency — both docs agree with each other + the contract

- Both name the same runner: `bin/polylane-run.sh`. install-helpers points to `references/merge-and-cleanup.md` for its behavior; merge-and-cleanup names `polylane-run/` as the shipped skill install-helpers installs.
- Deps in install-helpers (tmux, jq) match the runner's needs; no behavior in merge-and-cleanup requires a tool that install-helpers doesn't cover.
- No contradiction found: marker name, keep/delete lists, and CLI flags are identical across both files and match the HARD CONTRACT.

## Result
All 11 merge-and-cleanup contract elements + both install additions present and quoted; existing install steps intact; docs mutually consistent. **PASS.**
