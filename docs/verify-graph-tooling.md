# Verify — graph-tooling lane

Evidence for goals: harden `assets/q.py` into a robust graph-query CLI (all 5 documented
subcommands), tighten `assets/graphify-nudge.sh` and `assets/settings-hook-snippet.json`.

Owned files: `assets/q.py`, `assets/graphify-nudge.sh`, `assets/settings-hook-snippet.json`.
Contract intact: subcommand names `q.py <symbol>` (default search), `callers`, `uses`, `near`,
`file` unchanged. `community` retained. Only flags ADDED (`--json`, `--graph`, `--cap`).

Graph used: this repo's own AST graph, built free via `graphify update .`
(84 nodes / 76 edges / 12 communities, no LLM). `graph@1b7ac005`.

---

## Goal 1 — q.py: all 5 subcommands + community + graceful missing-graph

### Automated TDD suite (fixture graph, deterministic) — 21/21 PASS
Harness: `scratchpad/test_q.py` drives the real script via subprocess against a controlled
3-node fixture. Covers search, callers, uses, near, file, community, missing-graph exit-1,
and `--json`.
```
... (21 checks) ...
PASS  --json callers includes community field

ALL PASS
```

### Live runs against this repo's real graph

**`q.py <symbol>` (default search)** — prints `id [label] file:line (cN)`:
```
$ python3 assets/q.py --graph graphify-out/graph.json load
users_leonardo_..._graphify_nudge_sh__entry  [graphify-nudge.sh script]  assets/graphify-nudge.sh:1  (c16)
assets_q_load  [load()]  assets/q.py:40  (c0)
[2 matches for 'load'; showing 2] (graph@1b7ac005)
```

**`callers <node>`** — incoming edges, each with file:line + community:
```
$ python3 assets/q.py --graph graphify-out/graph.json callers load
-- CALLERS (point at it) (1) --
  contains     assets_graphify_nudge  assets/graphify-nudge.sh:1  (c16)
```

**`uses <node>`** — outgoing edges, each with file:line + community:
```
$ python3 assets/q.py --graph graphify-out/graph.json uses cmd_edges
-- USES (it points to) (4) --
  calls        assets_q_die  assets/q.py:35  (c0)
  calls        assets_q_edge_dict  assets/q.py:77  (c0)
  calls        assets_q_resolve  assets/q.py:87  (c0)
  calls        assets_q_emit_json  assets/q.py:97  (c0)
```

**`near <node>`** — both directions:
```
$ python3 assets/q.py --graph graphify-out/graph.json near main
-- CALLERS (point at it) (1) --
  contains     assets_q  assets/q.py:1  (c0)
-- USES (it points to) (9) --
  calls        assets_q_die  assets/q.py:35  (c0)
  ... (9 callees, each file:line + c0) ...
```

**`file <path-sub>`** — nodes in matching files:
```
$ python3 assets/q.py --graph graphify-out/graph.json file q.py
assets_q  [q.py]  assets/q.py:1  (c0)
assets_q_die  [die()]  assets/q.py:35  (c0)
assets_q_load  [load()]  assets/q.py:40  (c0)
... (each file:line + community) ...
```

**`community <N|node>`** — sibling cluster:
```
$ python3 assets/q.py --graph graphify-out/graph.json community 0
community 0: 16 nodes
assets_q  [q.py]  assets/q.py:1  (c0)
assets_q_die  [die()]  assets/q.py:35  (c0)
...
```

**Missing graph → exit 1 + hint (no traceback):**
```
$ python3 assets/q.py --graph /nope/graph.json foo
graph.json not found at /nope/graph.json
Run /graphify-auto to build it (free, no LLM), then retry.
$ echo $?
1
```

**`--json` (added flag) — machine-readable, community field present:**
```
$ python3 assets/q.py --graph graphify-out/graph.json --json callers load
{
  "node": "...graphify_nudge_sh__entry",
  "callers": [
    { "relation": "contains", "id": "assets_graphify_nudge",
      "file": "assets/graphify-nudge.sh", "line": "1", "community": 16 }
  ]
}
```

**Deployed sibling resolution** (`graphify-out/q.py` reads sibling `graph.json`, no `--graph`):
```
$ python3 graphify-out/q.py resolve
assets_q_resolve  [resolve()]  assets/q.py:87  (c...)
```

Robustness note: on a raw (un-clustered) extraction missing the `community` field, results
degrade gracefully to `(c?)` rather than crashing.

---

## Goal 2 — graphify-nudge.sh

```
$ bash -n assets/graphify-nudge.sh && echo "bash -n OK"
bash -n OK
$ CLAUDE_PROJECT_DIR=. bash assets/graphify-nudge.sh | python3 -c "import json,sys;print(json.load(sys.stdin)['hookSpecificOutput']['hookEventName'])"
PreToolUse                       # embedded PreToolUse JSON parses
$ CLAUDE_PROJECT_DIR=/tmp bash assets/graphify-nudge.sh; echo "exit=$?"
exit=0                           # silent + exit 0 when no q.py present
```
Tightened: message now advertises `python3`, the `--json` flag, and that each hit carries
community — kept in sync with q.py. Non-blocking, always exits 0.

---

## Goal 3 — settings-hook-snippet.json

```
$ python3 -c "import json;json.load(open('assets/settings-hook-snippet.json'));print('snippet JSON OK')"
snippet JSON OK
```
Matches the hook the nudge expects: `PreToolUse` matcher `Grep|Glob`, command
`"$CLAUDE_PROJECT_DIR/.claude/hooks/graphify-nudge.sh"`.

---

## Summary
- q.py: clean argparse, all 5 subcommands + `community`, file:line + community on every result,
  graceful exit-1 on missing graph, `--json`/`--graph`/`--cap` added. TDD 21/21 + live runs.
- graphify-nudge.sh: `bash -n` clean, valid PreToolUse JSON, exits 0.
- settings-hook-snippet.json: valid JSON, matches nudge hook.
- Contract intact; no renames/removals.
