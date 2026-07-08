# verify-assets — evidence for lane=assets

Graph under test: repo `graphify-out/graph.json` (302 nodes / 339 links). Every block is real, unedited command output (long lists truncated with `…`). Regenerate: `bash capture.sh` (scratchpad).

## 1. Every subcommand, plain + `--json` (json.load-validated)

### `q.py users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry`
```
$ python3 graphify-out/q.py users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry
users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry  [graphify-nudge.sh script]  assets/graphify-nudge.sh:1  (c29)
[1 matches for 'users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry'; showing 1] (graph@c1cbf25a)

$ python3 graphify-out/q.py --json users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry | python3 -c 'import json,sys; json.load(sys.stdin)'
{
  "query": "users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry",
  "count": 1,
  "results": [
    {
      "id": "users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry",
      "label": "graphify-nudge.sh script",
      "file": "assets/graphify-nudge.sh",
      "line": "1",
… (4 more lines)
→ json.load: OK, exit 0
```

### `q.py callers users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry`
```
$ python3 graphify-out/q.py callers users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry
-- CALLERS (point at it) (1) --
  contains     assets_graphify_nudge  assets/graphify-nudge.sh:1  (c29)

$ python3 graphify-out/q.py --json callers users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry | python3 -c 'import json,sys; json.load(sys.stdin)'
{
  "node": "users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry",
  "callers": [
    {
      "relation": "contains",
      "id": "assets_graphify_nudge",
      "file": "assets/graphify-nudge.sh",
      "line": "1",
      "community": 29
… (3 more lines)
→ json.load: OK, exit 0
```

### `q.py uses assets_graphify_nudge`
```
$ python3 graphify-out/q.py uses assets_graphify_nudge
-- USES (it points to) (1) --
  contains     users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry  assets/graphify-nudge.sh:1  (c29)

$ python3 graphify-out/q.py --json uses assets_graphify_nudge | python3 -c 'import json,sys; json.load(sys.stdin)'
{
  "node": "assets_graphify_nudge",
  "uses": [
    {
      "relation": "contains",
      "id": "users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry",
      "file": "assets/graphify-nudge.sh",
      "line": "1",
      "community": 29
… (3 more lines)
→ json.load: OK, exit 0
```

### `q.py near users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry`
```
$ python3 graphify-out/q.py near users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry
-- CALLERS (point at it) (1) --
  contains     assets_graphify_nudge  assets/graphify-nudge.sh:1  (c29)
-- USES (it points to) (0) --

$ python3 graphify-out/q.py --json near users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry | python3 -c 'import json,sys; json.load(sys.stdin)'
{
  "node": "users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry",
  "callers": [
    {
      "relation": "contains",
      "id": "assets_graphify_nudge",
      "file": "assets/graphify-nudge.sh",
      "line": "1",
      "community": 29
… (4 more lines)
→ json.load: OK, exit 0
```

### `q.py file bin`
```
$ python3 graphify-out/q.py file bin
bin_polylane_models  [polylane-models.sh]  bin/polylane-models.sh:1  (c27)
users_leonardo_downloads_polylane_bin_polylane_models_sh__entry  [polylane-models.sh script]  bin/polylane-models.sh:1  (c27)
bin_polylane_models_usage  [usage()]  bin/polylane-models.sh:21  (c27)
bin_polylane_models_fallback  [fallback()]  bin/polylane-models.sh:35  (c27)
bin_polylane_models_main  [main()]  bin/polylane-models.sh:37  (c27)
bin_polylane_run  [polylane-run.sh]  bin/polylane-run.sh:1  (c0)
… (35 more lines)

$ python3 graphify-out/q.py --json file bin | python3 -c 'import json,sys; json.load(sys.stdin)'
{
  "pattern": "bin",
  "count": 40,
  "results": [
    {
      "id": "bin_polylane_models",
      "label": "polylane-models.sh",
      "file": "bin/polylane-models.sh",
      "line": "1",
… (277 more lines)
→ json.load: OK, exit 0
```

### `q.py community 29`
```
$ python3 graphify-out/q.py community 29
community 29: 2 nodes
assets_graphify_nudge  [graphify-nudge.sh]  assets/graphify-nudge.sh:1  (c29)
users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry  [graphify-nudge.sh script]  assets/graphify-nudge.sh:1  (c29)

$ python3 graphify-out/q.py --json community 29 | python3 -c 'import json,sys; json.load(sys.stdin)'
{
  "community": 29,
  "count": 2,
  "results": [
    {
      "id": "assets_graphify_nudge",
      "label": "graphify-nudge.sh",
      "file": "assets/graphify-nudge.sh",
      "line": "1",
… (11 more lines)
→ json.load: OK, exit 0
```

## 2. Fuzzy fallback — zero-hit term gets 'did you mean' (max 5)
```
$ python3 graphify-out/q.py cmd_serch          # typo
[0 matches for 'cmd_serch'; showing 0] (graph@c1cbf25a)
did you mean: assets_q_cmd_search

$ python3 graphify-out/q.py callers cmd_serch; echo rc=$?
no match — try a broader term or `q.py <term>` first
did you mean: assets_q_cmd_search
rc=1

$ python3 graphify-out/q.py --json callers cmd_serch   # miss stays parseable
{
  "error": "no match for 'cmd_serch'",
  "did_you_mean": [
    "assets_q_cmd_search"
  ]
}
```

## 3. Error cases — clean message, exit 1, no traceback
```
$ python3 assets/q.py --graph /nope/graph.json foo; echo rc=$?
graph.json not found at /nope/graph.json
Run /graphify-auto to build it (free, no LLM), then retry.
rc=1

$ python3 assets/q.py --graph corrupt.json foo; echo rc=$?
could not read graph at /var/folders/vq/r0bg3jrn027bfy12km97wlt80000gn/T/tmp.rMy83txMtc/corrupt.json: Expecting property name enclosed in double quotes: line 1 column 2 (char 1)
rc=1

$ python3 assets/q.py --graph list.json foo; echo rc=$?   # valid JSON, wrong shape
graph at /var/folders/vq/r0bg3jrn027bfy12km97wlt80000gn/T/tmp.rMy83txMtc/list.json has unexpected shape (expected object with 'nodes'/'links'). Rebuild with /graphify-auto.
rc=1

$ python3 assets/q.py --graph nocomm.json --json community lonely; echo rc=$?
{
  "error": "no community found for that node"
}
rc=1
```

## 4. graphify-nudge.sh — bash -n + exit-0 trace on every path
```
$ bash -n assets/graphify-nudge.sh; echo rc=$?
rc=0

$ (unset CLAUDE_PROJECT_DIR; bash -eu -o pipefail assets/graphify-nudge.sh; echo rc=$?)
rc=0
$ CLAUDE_PROJECT_DIR=/no/such/dir bash -eu -o pipefail assets/graphify-nudge.sh; echo rc=$?
rc=0
$ CLAUDE_PROJECT_DIR='…/proj with spaces' bash -eu -o pipefail assets/graphify-nudge.sh | head -c 120; echo; echo rc=${PIPESTATUS[0]}
rc=0
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"graphify-out/q.py exists. For NAVIGATION (where
$ … | python3 -c 'import json,sys; json.load(sys.stdin)' && echo hook JSON valid
hook JSON valid

$ bash -x trace (with q.py present) — tail:
+ DIR='/var/folders/vq/r0bg3jrn027bfy12km97wlt80000gn/T/tmp.rMy83txMtc/proj with spaces'
+ '[' -f '/var/folders/vq/r0bg3jrn027bfy12km97wlt80000gn/T/tmp.rMy83txMtc/proj with spaces/graphify-out/q.py' ']'
+ cat
+ exit 0
```

## 5. Byte-compat vs HEAD (git show HEAD:assets/q.py) — stdout+stderr+rc diffed
```
IDENTICAL: q.py  users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry
IDENTICAL: q.py  callers users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry
IDENTICAL: q.py  uses assets_graphify_nudge
IDENTICAL: q.py  near users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry
IDENTICAL: q.py  file bin
IDENTICAL: q.py  community users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry
IDENTICAL: q.py  community 29
IDENTICAL: q.py --json users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry
IDENTICAL: q.py --json callers users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry
IDENTICAL: q.py --json uses assets_graphify_nudge
IDENTICAL: q.py --json near users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry
IDENTICAL: q.py --json file bin
IDENTICAL: q.py --json community users_leonardo_downloads_polylane_assets_graphify_nudge_sh__entry
IDENTICAL: q.py --json community 29
```

## 6. Full test suite (scratchpad/test_assets.py — subcommands, JSON, fuzzy, errors, nudge, README)
```
PASS  README names all 3 files

61/61 passed
```
