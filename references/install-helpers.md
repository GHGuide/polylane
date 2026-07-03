# Install the graphify query helpers into the target project (recon phase)

Goal: make the graph the path of least resistance so fresh builder CLIs actually query it instead of grepping (that's where the token savings are). Do this during recon, once per project, only if a graphify graph exists.

Assets live beside this skill: `assets/q.py`, `assets/graphify-nudge.sh`, `assets/settings-hook-snippet.json`. This skill's base dir is provided at invocation — reference assets from there.

## Steps

1. **Precondition.** Only proceed if `graphify-out/graph.json` exists in the project (i.e. graphify was built). If not, tell the user to run `/graphify` first, or skip graphify entirely for this run and use Explore agents for navigation.

2. **Install the query helper** (safe file copies — allowed under auto-mode):
   - Copy `assets/q.py` → `<project>/graphify-out/q.py`, `chmod +x`. It's portable: it reads `graph.json` from its own directory. Skip if already present and identical.
   - Copy `assets/graphify-nudge.sh` → `<project>/.claude/hooks/graphify-nudge.sh`, `chmod +x`.

3. **Register the hook — HAND OFF, do not write it.** Writing `<project>/.claude/settings.json` installs a PreToolUse hook = a behavioral/startup-config change; auto-mode blocks the skill from doing it. So:
   - If `<project>/.claude/settings.json` is absent: show the user `assets/settings-hook-snippet.json` and ask them to save it as `.claude/settings.json`.
   - If it exists: show them the `hooks.PreToolUse` entry to merge in.
   - Note they can instead re-run outside auto-mode or add a settings-write permission rule. The helper still works without the hook (via the CLAUDE.md rule + the Step-1 mandate in each lane prompt); the hook just makes it enforced.

4. **Add the navigation rule to the project's CLAUDE.md** (a normal doc edit, allowed) if not already there:
   ```
   ## Navigation — query the graph, don't grep to discover
   - Graph in graphify-out/. To find where code lives run: python graphify-out/q.py <symbol> (callers|uses|near|file|community). ~100 bytes vs reading files.
   - Grep/Glob ONLY to confirm an exact string before an edit — never to discover where things are.
   - Run /graphify-auto at session start to refresh (free).
   ```

5. **Refresh.** Ensure each lane prompt starts with `/graphify-auto` (free AST refresh) so queries aren't stale.

## Caveats to pass to the user
- `q.py` is only as good as the graph. AST extraction captures imports/references/`uses` well; **`callers` can be sparse for some languages (e.g. Swift call-sites)** — don't read `callers: 0` as "nothing calls it". Prefer `search` / `file` / `community` / `uses` there.
- Graphify only saves tokens on navigation-heavy lanes (unfamiliar/large subsystems). For a lane editing a few known files, it's overhead — the hook nudges, it doesn't force.
