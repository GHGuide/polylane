#!/usr/bin/env bash
# share_graph — graphify-out/ is gitignored (0 tracked files), so `git worktree add`
# births every lane GRAPHLESS: its mandatory "query the graph" step either rebuilt the
# whole graph per lane or fell back to an Explore agent. add_worktree now symlinks the
# parent repo's graphify-out/ into each fresh worktree (read-only by contract; the
# orchestrator refreshes once per cycle, lanes only query).
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

command -v git >/dev/null 2>&1 || { pass "share-graph-skipped-no-git"; finish; exit 0; }
make_tmpdir

R="$TEST_TMPDIR/repo"
mkdir -p "$R"; (
  cd "$R"; git init -q -b main .; git config user.email t@t; git config user.name t
  echo 'graphify-out/' > .gitignore
  echo seed > seed.txt; git add -A; git commit -qm seed
  mkdir -p graphify-out
  echo '{"nodes":[]}' > graphify-out/graph.json
  printf '#!/usr/bin/env python3\nprint("usage")\n' > graphify-out/q.py
) >/dev/null 2>&1

REPO_ROOT="$R"; BASE=main; DRY_RUN=0

# a fresh worktree gets the parent's graph via symlink
WT="$TEST_TMPDIR/wt-a"
( cd "$R" && add_worktree "$WT" lane/a ) >/dev/null 2>&1
assert_ok "wt-created"        test -d "$WT"
assert_ok "graph-symlinked"   test -L "$WT/graphify-out"
assert_ok "graph-readable"    test -f "$WT/graphify-out/graph.json"
assert_ok "qpy-runs-in-lane"  sh -c "cd '$WT' && python3 graphify-out/q.py | grep -q usage"

# a refresh in the PARENT is instantly visible in the lane (one graph, N readers)
echo '{"nodes":["fresh"]}' > "$R/graphify-out/graph.json"
assert_contains "refresh-propagates" "fresh" "$(cat "$WT/graphify-out/graph.json")"

# idempotent: re-adding over an existing link never fails or doubles up
( cd "$R" && share_graph "$WT" ) >/dev/null 2>&1
assert_ok "share-idempotent" test -L "$WT/graphify-out"

# a project with NO graph: worktree is clean, no dangling link
R2="$TEST_TMPDIR/repo2"
mkdir -p "$R2"; ( cd "$R2"; git init -q -b main .; git config user.email t@t; git config user.name t; echo s>f; git add -A; git commit -qm s ) >/dev/null 2>&1
REPO_ROOT="$R2"
WT2="$TEST_TMPDIR/wt-b"
( cd "$R2" && add_worktree "$WT2" lane/b ) >/dev/null 2>&1
assert_ok "no-graph-no-link" test '!' -e "$WT2/graphify-out"

finish
