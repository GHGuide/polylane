# Install the graphify query helpers into the target project (recon phase)

Goal: make the graph the path of least resistance so fresh builder CLIs actually query it instead of grepping (that's where the token savings are). Do this during recon, once per project, only if a graphify graph exists.

Assets live beside this skill: `assets/q.py`, `assets/graphify-nudge.sh`, `assets/settings-hook-snippet.json`. This skill's base dir is provided at invocation — reference assets from there.

## Install polylane (one-time, per machine)

polylane is **one** skill — the whole engine (`bin/*.sh`), knowledge (`references/`),
and the `SKILL.md` loop — installed at `~/.claude/skills/polylane`:

```bash
git clone https://github.com/GHGuide/polylane ~/.claude/skills/polylane
# or, from a checkout: cp -R . ~/.claude/skills/polylane/
```

Verify:
```bash
test -f ~/.claude/skills/polylane/SKILL.md && echo installed || echo "not found — clone the repo to ~/.claude/skills/polylane"
```

### Codex (OpenAI CLI) — same engine, Codex skill layout
The engine is agent-agnostic, so polylane installs as a **Codex skill** too. From a
checkout: `codex/install.sh` (user scope `~/.codex/skills/polylane`) or
`codex/install.sh --repo` (repo scope `.codex/skills/polylane`). It lays out
`SKILL.md` + `scripts/` (the `bin/*.sh` helpers) + `references/` + `assets/`. Invoke in
Codex with `$polylane` or `/skills`. Lanes run via `codex exec` (`agent:"codex"` in the
manifest); prompts are plain instructions (no Claude preamble). Deps: `tmux` + `jq` +
`codex` on PATH. See `codex/SKILL.md` for the Codex deltas.

There are no sub-skills to install — the old `/polylane-run`, `/polylane-auto`, and
`/polylane-max` are all folded into this single `/polylane`. The build mechanics they
used live in `references/planning.md`; the runner is `bin/polylane-run.sh` (driven via
`bin/polylane-supervisor.sh`).

### Runtime dependencies

The runner drives lanes through tmux and reads its manifest with jq. Install both once:

```bash
brew install tmux jq      # macOS (Homebrew)
# Debian/Ubuntu: sudo apt-get install -y tmux jq
```

Verify:
```bash
command -v tmux >/dev/null && command -v jq >/dev/null && echo "deps ok" || echo "install tmux + jq"
```

The runner's tmux session is named `polylane` by default. For parallel runs on the same
machine, set `POLYLANE_SESSION=<name>` per run so the sessions coexist (see
`references/merge-and-cleanup.md` for the full env-var list: poll interval, health-check
auto-retry).

### Optional: live model probing

The runner's model controls (`--intensity` / `--model`, documented in
the runner `--help`) resolve model IDs through the probe helper
`bin/polylane-models.sh`. Setting `ANTHROPIC_API_KEY` is **optional**:

- **With `ANTHROPIC_API_KEY` set** — `bin/polylane-models.sh` probes the Anthropic
  API live and lists the models that key can actually reach.
- **Without it** — the helper falls back to a curated built-in model list, so the
  runner still works unauthenticated; the list is just static rather than probed.

```bash
export ANTHROPIC_API_KEY=sk-ant-...   # optional — enables live model probing
```

## Set two paths first (every command below reuses them)

```bash
SKILL_DIR="$HOME/.claude/skills/polylane"   # where this skill is installed; adjust if elsewhere
PROJECT="/absolute/path/to/target/project"  # the repo builders will edit
```

## Steps

1. **Precondition.** Only proceed if `$PROJECT/graphify-out/graph.json` exists (i.e. graphify was built). Check:
   ```bash
   test -f "$PROJECT/graphify-out/graph.json" && echo present || echo "run /graphify first (or skip graphify; use Explore agents to navigate)"
   ```

2. **Install the query helper** (safe file copies — allowed under auto-mode). Run verbatim:
   ```bash
   # q.py is portable: reads graph.json from its own dir. Copy is idempotent.
   cp "$SKILL_DIR/assets/q.py" "$PROJECT/graphify-out/q.py"
   chmod +x "$PROJECT/graphify-out/q.py"

   mkdir -p "$PROJECT/.claude/hooks"
   cp "$SKILL_DIR/assets/graphify-nudge.sh" "$PROJECT/.claude/hooks/graphify-nudge.sh"
   cp "$SKILL_DIR/assets/verify-gate.sh"    "$PROJECT/.claude/hooks/verify-gate.sh"
   chmod +x "$PROJECT/.claude/hooks/"*.sh
   ```
   `verify-gate.sh` is a **Stop hook**: it BLOCKS a lane that writes `STATUS: <lane> DONE run=<RUN_ID>`
   without leaving a non-empty `docs/verify-<lane>.md` — deterministic
   verification-before-completion (the prompt asks; the hook enforces). Registered by the
   same settings snippet below.
   Verify:
   ```bash
   python "$PROJECT/graphify-out/q.py" 2>&1 | head -1   # prints usage → q.py runs
   ```

3. **Register the hook — HAND OFF, do not write it.** Writing `$PROJECT/.claude/settings.json` installs a PreToolUse hook = a behavioral/startup-config change; auto-mode blocks the skill from doing it. So:
   - If `$PROJECT/.claude/settings.json` is absent: hand the user `$SKILL_DIR/assets/settings-hook-snippet.json` and ask them to save it as `$PROJECT/.claude/settings.json` (drop the `_comment` key). Show it with:
     ```bash
     cat "$SKILL_DIR/assets/settings-hook-snippet.json"
     ```
   - If it exists: show them the `hooks.PreToolUse` entry from that file to merge into the existing `hooks.PreToolUse` array.
   - Note they can instead re-run outside auto-mode or add a settings-write permission rule. The helper still works without the hook (via the CLAUDE.md rule + the Step-1 mandate in each lane prompt); the hook just makes it enforced.

4. **Add the navigation rule to the project's CLAUDE.md** (a normal doc edit, allowed) if not already there:
   ```
   ## Navigation — query the graph, don't grep to discover
   - Graph in graphify-out/. To find where code lives run: python graphify-out/q.py <symbol> (callers|uses|near|file|community). ~100 bytes vs reading files.
   - Grep/Glob ONLY to confirm an exact string before an edit — never to discover where things are.
   - Run /graphify-auto at session start to refresh (free).
   ```

5. **Refresh.** The ORCHESTRATOR runs `/graphify-auto` once per cycle (recon); the runner symlinks graphify-out/ into every lane worktree, so lane prompts must NOT re-run it — lanes only query.

## Caveats to pass to the user
- `q.py` is only as good as the graph. AST extraction captures imports/references/`uses` well; **`callers` can be sparse for some languages (e.g. Swift call-sites)** — don't read `callers: 0` as "nothing calls it". Prefer `search` / `file` / `community` / `uses` there.
- Graphify only saves tokens on navigation-heavy lanes (unfamiliar/large subsystems). For a lane editing a few known files, it's overhead — the hook nudges, it doesn't force.
