# Codex Package Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split Polylane into one platform-neutral core and two thin distributions, then
prove the Codex distribution launches real modern Codex CLI workers through tmux without
requiring or referencing Claude Code.

**Architecture:** Root compatibility entries become relative links or tiny wrappers; no
core implementation is copied. Agent identity, manifest validation, error classes, and the
command-template interface are shared, while actual command construction, executable
discovery, prompts, model inventories, memory, and hooks remain adapter-local. Installers
assemble immutable temporary packages and swap them into place only after complete
validation.

**Tech Stack:** Bash 3.2, jq, tmux, git worktrees, Codex CLI, Claude Code compatibility,
Markdown, sha/git object hashes, shellcheck, macOS and Ubuntu CI.

## Global Constraints

- Final core files contain no Claude home path, Claude question tool, Anthropic endpoint,
  Claude-only hook, slash command, model id, price table, or Codex/Claude command template.
  The existing Aider compatibility template may remain as a shared legacy fallback.
- Codex CLI invocation is `codex exec --json --sandbox workspace-write -c approval_policy=never
  --model <id> -c model_reasoning_effort=<effort> -`, with the prompt streamed through
  stdin. Inherited interactive approval policy may never block a detached pane.
- Shared core rejects a missing agent identity. Each platform launcher and the temporary
  root compatibility wrapper selects its agent and adapter explicitly before core side effects.
- `POLYLANE_AGENT_CMD` remains an explicit test/expert override and bypasses CLI-name
  inference without bypassing Codex manifest identity.
- Root Claude entrypoints remain operational for one compatibility period.
- The shared workflow cannot terminate or pause because of cost, time, tokens, cycles,
  retries, trend, ROI, or diminishing returns.
- This plan creates the one-cycle canary only. The required persistent two-cycle recovery
  canary is owned by the autonomy plan.
- Do not install the active user skill in this plan; final installation happens only after
  all plans pass.

## Final File Map

```text
core/
  scripts/       shared engine and adapter contract
  workflow/      semantic autonomous-loop contract
  references/    platform-neutral planning and operations
  assets/        optional shared runtime assets only; omit when empty
  tests/         shared behavior and mock-tmux suites
codex/
  SKILL.md, install.sh, agents/openai.yaml
  scripts/       Codex command/policy adapter, launchers, controller, and canaries
  references/    Codex prompts, models, questions, runtime
  tests/          Codex command/package/live contracts
claude-code/
  SKILL.md, install.sh
  scripts/       Claude command/policy adapter, launcher, model probe, memory bridge
  references/    Claude prompts, models, hooks, questions
  assets/        graphify and Claude hooks
  tests/          compatibility contracts
bin/, scripts/, references/, assets/
  relative compatibility links only; no canonical source
tests/run.sh      aggregate shared plus both adapter suites
```

## Sequential Mechanical Edit Gate

Diff fences in this plan are anchored edit specifications, not directly executable patches;
abbreviated/context-only `@@` markers must never be passed to `git apply`. After every anchored
edit, stop before the next checkbox and run `git diff --check`, `bash -n` on every changed shell
file, `python3 -m py_compile` on every changed Python file, and the step's named focused test.
Confirm the step's complete expected path/content assertion before continuing. A failed check
blocks the next step; do not batch later edits over it. Full-file creation fences remain literal
complete bodies.

---

### Task 1: Extract Canonical Core Without Smuggling Claude into Codex

**Files:**
- Create: `codex/tests/test-repository-layout.sh`
- Create: `claude-code/tests/helpers.sh`
- Create: `tests/run.sh`
- Move: platform-neutral `bin/polylane-*.sh` to `core/scripts/`
- Move: `bin/polylane-claudemem.sh`, `bin/polylane-models.sh` to
  `claude-code/scripts/`
- Move: Claude hook assets to `claude-code/assets/`
- Split: current `references/` into `core/references/` and
  `claude-code/references/`
- Move: shared tests to `core/tests/` and Claude-only tests to
  `claude-code/tests/`
- Replace: root `bin/`, `scripts/`, `references/`, and `assets/` contents with links

**Interfaces:**
- Produces: one canonical source path for every implementation file.
- Produces: root compatibility paths whose `readlink` target is under `core/` or
  `claude-code/`.
- Preserves: existing root helper names and root `tests/run.sh` behavior.

- [ ] **Step 1: Add the repository-boundary test (5 minutes)**

Create `codex/tests/test-repository-layout.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
fail=0
need_dir() { [ -d "$ROOT/$1" ] || { echo "FAIL missing-dir $1"; fail=1; }; }
need_link() {
  [ -L "$ROOT/$1" ] || { echo "FAIL not-link $1"; fail=1; return; }
  case "$(readlink "$ROOT/$1")" in ../core/*|../claude-code/*|core/*) : ;;
    *) echo "FAIL wrong-target $1 -> $(readlink "$ROOT/$1")"; fail=1 ;;
  esac
}
for d in core/scripts core/workflow core/references core/tests \
         codex/scripts codex/references codex/tests codex/agents \
         claude-code/scripts claude-code/references claude-code/assets \
         claude-code/tests; do need_dir "$d"; done
for f in bin/polylane-run.sh bin/polylane-supervisor.sh \
         bin/polylane-claudemem.sh bin/polylane-models.sh; do need_link "$f"; done
[ -f "$ROOT/codex/agents/openai.yaml" ] || { echo "FAIL codex-agent-metadata"; fail=1; }
[ "$fail" = 0 ] && echo "PASS repository-layout"
exit "$fail"
```

Run: `bash -n codex/tests/test-repository-layout.sh`

Expected: exit 0; this checks only test-file syntax before the intentional RED run.

- [ ] **Step 2: Run the repository-boundary test and verify RED (2 minutes)**

Run: `bash codex/tests/test-repository-layout.sh`

Expected: exit 1 with at least `FAIL missing-dir core/scripts`,
`FAIL missing-dir claude-code/scripts`, and `FAIL not-link bin/polylane-run.sh`.

- [ ] **Step 3: Create the canonical directory skeleton (2 minutes)**

Run:

```bash
mkdir -p core/scripts core/workflow core/references core/tests \
  codex/scripts codex/references codex/tests codex/agents \
  claude-code/scripts claude-code/references claude-code/assets \
  claude-code/tests
```

Expected: exit 0; `find core codex claude-code -type d` lists every directory required
by `test-repository-layout.sh`.

- [ ] **Step 4: Move the script implementations to their owners (3 minutes)**

Run exactly:

```bash
git mv bin/polylane-*.sh core/scripts/
git mv core/scripts/polylane-claudemem.sh claude-code/scripts/
git mv core/scripts/polylane-models.sh claude-code/scripts/
```

Expected: exit 0; `bin/` contains no regular files,
`core/scripts/polylane-run.sh` exists, and the two Claude-only helpers exist only under
`claude-code/scripts/`.

- [ ] **Step 5: Move references and assets to their owners (3 minutes)**

Run exactly:

```bash
git mv assets/README.md assets/graphify-nudge.sh assets/settings-hook-snippet.json \
  assets/verify-gate.sh assets/q.py claude-code/assets/
git mv references/discovery.md references/interview.md references/install-helpers.md \
  references/model-selection.md references/prompt-blocks.md references/lane-template.md \
  references/planning.md references/skill-catalog.md references/skill-scout.md \
  claude-code/references/
git mv references/documentation.md references/lane-derivation.md \
  references/merge-and-cleanup.md core/references/
```

Expected: exit 0; `find assets references -type f` prints nothing and every named file is
present in the canonical directory listed above.

- [ ] **Step 6: Move tests and metadata to their owners (3 minutes)**

Run exactly:

```bash
git mv tests/helpers.sh tests/fixtures tests/test-*.sh core/tests/
git mv core/tests/test-claudemem.sh core/tests/test-models.sh \
  core/tests/test-verify-gate.sh claude-code/tests/
git mv codex/openai.yaml codex/agents/openai.yaml
```

Expected: exit 0; `core/tests/helpers.sh`, `claude-code/tests/test-models.sh`,
`tests/run.sh`, and `codex/agents/openai.yaml` all exist.

- [ ] **Step 7: Point the moved shared test helper at the canonical runner (2 minutes)**

Make this anchored edit:

```diff
diff --git a/core/tests/helpers.sh b/core/tests/helpers.sh
--- a/core/tests/helpers.sh
+++ b/core/tests/helpers.sh
@@
-RUNNER="$TESTS_DIR/../bin/polylane-run.sh"
+RUNNER="$TESTS_DIR/../scripts/polylane-run.sh"
```

Expected: `rg -n 'RUNNER=' core/tests/helpers.sh` prints
`RUNNER="$TESTS_DIR/../scripts/polylane-run.sh"`.

- [ ] **Step 8: Build relative root compatibility links (3 minutes)**

Run exactly:

```bash
rmdir bin references assets
mkdir bin references assets
for file in core/scripts/*.sh; do ln -s "../$file" "bin/${file##*/}"; done
for file in claude-code/scripts/*.sh; do
  [ -e "bin/${file##*/}" ] || ln -s "../$file" "bin/${file##*/}"
done
for file in claude-code/references/*.md; do
  ln -s "../$file" "references/${file##*/}"
done
for file in core/references/*.md; do
  [ -e "references/${file##*/}" ] || ln -s "../$file" "references/${file##*/}"
done
for file in claude-code/assets/*; do ln -s "../$file" "assets/${file##*/}"; done
ln -s bin scripts
```

Expected: exit 0; `find bin references assets -type f` prints nothing and
`readlink bin/polylane-run.sh` prints `../core/scripts/polylane-run.sh`.

The ownership classification executed by Steps 4-8 is normative:

Use `git mv` for canonical files. Classify these files explicitly:

```text
claude-code/scripts/: polylane-claudemem.sh, polylane-models.sh
claude-code/assets/: README.md, graphify-nudge.sh, settings-hook-snippet.json,
  verify-gate.sh, q.py
core/assets/: create only when a genuinely platform-neutral runtime asset exists; never add
  a README, installation guide, changelog, or empty marker merely to retain the directory
claude-code/references/: discovery.md, interview.md, install-helpers.md,
  model-selection.md, prompt-blocks.md, lane-template.md, planning.md,
  skill-catalog.md, skill-scout.md
claude-code/tests/: test-claudemem.sh, test-models.sh, test-verify-gate.sh
core/scripts/: every other current bin/polylane-*.sh
core/references/: documentation.md, lane-derivation.md, merge-and-cleanup.md; Task 4
  creates neutral discovery/interview/planning/prompt/skill references after the current
  platform-specific versions move to `claude-code/references/`
core/tests/: every other current tests/test-*.sh plus helpers.sh and fixtures/
```

Exception: after moving the canonical `polylane-run.sh` implementation into core, Task 2
creates `claude-code/scripts/polylane-claude-run.sh`; root
`bin/polylane-run.sh` links to that compatibility wrapper instead of directly to core.

When Task 2 adds the Claude run wrapper, replace only the generated
`bin/polylane-run.sh` link with
`../claude-code/scripts/polylane-claude-run.sh`. No canonical implementation is copied.

Never leave a regular file under a compatibility directory. Move `codex/openai.yaml` to
`codex/agents/openai.yaml`. Set `RUNNER="$TESTS_DIR/../scripts/polylane-run.sh"` in the
moved `core/tests/helpers.sh`; Claude test helpers resolve their adapter scripts through
`../../claude-code/scripts`.

- [ ] **Step 9: Add the Claude test compatibility helper (3 minutes)**

Create `claude-code/tests/helpers.sh` with this complete body; a symlink is not valid
because the shared helper derives paths from its own `BASH_SOURCE`:

```bash
#!/usr/bin/env bash
CLAUDE_TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$CLAUDE_TESTS_DIR/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
RUNNER="$ROOT/bin/polylane-run.sh"
```

Expected: `bash -n claude-code/tests/helpers.sh` exits 0 and sourcing it prints a `RUNNER`
ending in `/bin/polylane-run.sh`.

- [ ] **Step 10: Run all three moved Claude tests immediately (5 minutes)**

Run:

```bash
bash claude-code/tests/test-claudemem.sh
bash claude-code/tests/test-models.sh
bash claude-code/tests/test-verify-gate.sh
```

Expected: all three exit 0 and each final summary reports `0 fail`.

- [ ] **Step 11: Replace the aggregate test runner (3 minutes)**

Create executable `tests/run.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
files=0 failures=0 failed=""
for suite in "$ROOT/core/tests" "$ROOT/codex/tests" "$ROOT/claude-code/tests"; do
  [ -d "$suite" ] || continue
  for test_file in "$suite"/test-*.sh; do
    [ -f "$test_file" ] || continue
    files=$((files + 1)); name=${test_file#$ROOT/}
    echo "== $name =="
    if "${BASH:-bash}" "$test_file"; then :
    else failures=$((failures + 1)); failed="$failed $name"; fi
  done
done
echo "SUMMARY: $files test files, $failures failed"
[ "$files" -gt 0 ] && [ "$failures" -eq 0 ] || {
  echo "FAILED:$failed" >&2; exit 1;
}
```

Run: `chmod +x tests/run.sh`

Expected: exit 0 and `test -x tests/run.sh` succeeds.

- [ ] **Step 12: Run the layout test and verify GREEN (2 minutes)**

Run: `bash codex/tests/test-repository-layout.sh`

Expected: exit 0 with exactly `PASS repository-layout` as the final line.

- [ ] **Step 13: Run compatibility and aggregate smoke checks (5 minutes)**

```bash
bin/polylane-run.sh --help
tests/run.sh
```

Expected: both commands exit 0 and the aggregate final line matches
`SUMMARY: <positive integer> test files, 0 failed`.

- [ ] **Step 14: Commit the ownership split (2 minutes)**

Run:

```bash
git add core codex claude-code bin scripts references assets tests/run.sh
git commit -m "refactor: separate Polylane core and adapters"
```

Expected: exit 0 with commit subject
`refactor: separate Polylane core and adapters` and no unstaged Task 1 changes.

---

### Task 2: Establish the Agent Contract and Execute the Exact Codex Command

**Files:**
- Create: `core/scripts/polylane-agent.sh`
- Create: `core/scripts/polylane-fs.py`
- Create: `codex/scripts/polylane-codex-agent.sh`
- Create: `codex/scripts/polylane-codex-exec.sh`
- Create: `codex/scripts/polylane-codex-model.sh`
- Create: `claude-code/scripts/polylane-claude-agent.sh`
- Create: `claude-code/scripts/polylane-claude-run.sh`
- Create: `claude-code/scripts/polylane-claude-doctor.sh`
- Create: `claude-code/scripts/polylane-claude-compat.sh`
- Create: `core/tests/test-agent-preflight.sh`
- Create: `codex/tests/test-codex-command.sh`
- Create: `codex/tests/test-codex-model-resolver.sh`
- Modify: `core/scripts/polylane-run.sh`
- Modify: `core/scripts/polylane-doctor.sh`
- Modify: root compatibility link `bin/polylane-run.sh`
- Modify: `core/tests/test-agent-adapter.sh`
- Modify: `core/tests/test-doctor.sh`

**Interfaces:**
- Produces: shared `polylane_agent_from_manifest`, `polylane_agent_cli`,
  `polylane_agent_template`, `polylane_agent_shell`, and adapter-provided
  `polylane_adapter_template`, `polylane_adapter_shell`, `polylane_adapter_processes`, and
  `polylane_adapter_error_class`.
- `polylane_agent_error_class <agent> <structured-error.json>` delegates classification of
  an adapter-owned structured artifact; ordinary pane/transcript prose is never classified.
- Template substitution tokens: `{model}`, `{prompt}`, `{effort}`, and `{error_artifact}`.
- `pane_cmd <worktree> <model> <prompt-file> <effort>` safely quotes paths and streams
  prompt bytes through stdin.
- The installed Codex wrapper ABI remains exactly five arguments:
  `CODEX_EXE MODEL EFFORT PROMPT ERROR_ARTIFACT`; interpreter and identity bindings travel
  only through authenticated quoted pane metadata/environment.
- `polylane-codex-model.sh resolve-model [explicit-id]` prints a validated explicit id,
  otherwise `POLYLANE_CODEX_MODEL`, otherwise the top-level `model` in
  `${CODEX_HOME:-$HOME/.codex}/config.toml`; exit 4 only when none is valid.
- `polylane-codex-model.sh resolve-effort [explicit-effort] [default-effort]` uses explicit,
  then `POLYLANE_CODEX_EFFORT`, then top-level `model_reasoning_effort`, then the supplied
  default; allowed values are `low|medium|high|xhigh`.

- [ ] **Step 1: Add a negative assertion helper (2 minutes)**

Make this anchored edit to `core/tests/helpers.sh`:

```diff
diff --git a/core/tests/helpers.sh b/core/tests/helpers.sh
--- a/core/tests/helpers.sh
+++ b/core/tests/helpers.sh
@@
 assert_contains() {
@@
 }
+
+# assert_not_contains NAME NEEDLE HAYSTACK -- fixed-string negative match
+assert_not_contains() {
+  if printf '%s' "$3" | grep -qF -- "$2"; then
+    fail "$1" "output unexpectedly contains [$2]"
+  else
+    pass "$1"
+  fi
+}
```

Expected: `bash -n core/tests/helpers.sh` exits 0.

- [ ] **Step 2: Add the complete identity/preflight test (4 minutes)**

Create `core/tests/test-agent-preflight.sh` with this complete body:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
. "$ROOT/core/scripts/polylane-agent.sh"
make_tmpdir

safe_control="$TEST_TMPDIR/fs-control"
assert_ok "nofollow-create-control-root" polylane_safe_mkdirs "$safe_control" 0700
private="$safe_control/private"; public="$safe_control/public"
printf 'original\n' | polylane_private_from_stdin "$private" 0400
POLYLANE_FS_TEST_SOURCE_SWAP=1 assert_rc "source-swap-publication-rejected" 7 \
  polylane_publish_private "$private" "$public"
assert_fail "source-swap-left-no-public-link" test -e "$public"
replace_dest="$safe_control/replace-dest"; replace_source="$safe_control/replace-source"
printf 'old\n' | polylane_private_from_stdin "$replace_dest" 0600
printf 'new\n' | polylane_private_from_stdin "$replace_source" 0600
POLYLANE_FS_TEST_REPLACE_SOURCE_SWAP=1 assert_rc "replace-source-swap-rejected" 7 \
  polylane_fs replace-existing-file "$replace_source" "$replace_dest"
assert_eq "replace-source-swap-preserved-public" old "$(tr -d '\n' < "$replace_dest")"
bound_dest="$safe_control/bound-race-dest"; bound_source="$safe_control/bound-race-source"
printf 'old-bound\n' | polylane_private_from_stdin "$bound_dest" 0600
printf 'new-bound\n' | polylane_private_from_stdin "$bound_source" 0600
POLYLANE_FS_TEST_REPLACE_BOUND_SWAP=1 assert_rc "replace-bound-swap-rejected" 7 \
  polylane_fs replace-existing-file "$bound_source" "$bound_dest"
assert_eq "replace-bound-swap-rejected-before-exchange" old-bound \
  "$(tr -d '\n' < "$bound_dest")"
cooperative_dest="$safe_control/cooperative-dest"
cooperative_source_one="$safe_control/cooperative-source-one"
cooperative_source_two="$safe_control/cooperative-source-two"
cooperative_ready="$safe_control/cooperative-lock-ready"
printf 'cooperative-old\n' | polylane_private_from_stdin "$cooperative_dest" 0600
printf 'cooperative-one\n' | polylane_private_from_stdin "$cooperative_source_one" 0600
printf 'cooperative-two\n' | polylane_private_from_stdin "$cooperative_source_two" 0600
( export POLYLANE_FS_TEST_CAS_LOCK_READY="$cooperative_ready"
  polylane_fs replace-existing-file "$cooperative_source_one" "$cooperative_dest" ) &
cooperative_pid=$!; cooperative_wait=0
while [ ! -s "$cooperative_ready" ] && [ "$cooperative_wait" -lt 500 ]; do
  sleep 0.01; cooperative_wait=$((cooperative_wait + 1))
done
assert_ok "cooperative-publisher-holds-destination-lock" test -s "$cooperative_ready"
assert_rc "cooperative-second-publisher-cannot-pass-lock" 7 \
  polylane_fs replace-existing-file "$cooperative_source_two" "$cooperative_dest"
assert_eq "cooperative-destination-unchanged-while-locked" cooperative-old \
  "$(tr -d '\n' < "$cooperative_dest")"
printf 'go\n' | polylane_private_from_stdin "${cooperative_ready}.go" 0600
wait "$cooperative_pid"; cooperative_rc=$?
assert_eq "cooperative-first-publisher-commits" 0 "$cooperative_rc"
assert_eq "cooperative-first-publisher-wins" cooperative-one \
  "$(tr -d '\n' < "$cooperative_dest")"
dest_race="$safe_control/destination-race"; dest_source="$safe_control/destination-source"
printf 'old-destination\n' | polylane_private_from_stdin "$dest_race" 0600
printf 'new-destination\n' | polylane_private_from_stdin "$dest_source" 0600
POLYLANE_FS_TEST_REPLACE_DEST_CHANGE=1 assert_rc \
  "lock-bypassing-destination-race-rejected-with-final-convergence" 7 \
  polylane_fs replace-existing-file "$dest_source" "$dest_race"
assert_eq "lock-bypassing-race-finally-preserves-winner" concurrent-winner \
  "$(tr -d '\n' < "$dest_race")"
pointer_dest="$safe_control/pointer-dest"; pointer_source="$safe_control/pointer-source"
polylane_fs symlink-exclusive "$pointer_dest" /old
polylane_fs symlink-exclusive "$pointer_source" /new
POLYLANE_FS_TEST_SYMLINK_SOURCE_SWAP=1 assert_rc "pointer-source-swap-rejected" 7 \
  polylane_fs replace-symlink "$pointer_source" "$pointer_dest"
assert_eq "pointer-source-swap-preserved-public" /old "$(readlink "$pointer_dest")"
pointer_bound_dest="$safe_control/pointer-bound-dest"
pointer_bound_source="$safe_control/pointer-bound-source"
polylane_fs symlink-exclusive "$pointer_bound_dest" /old-bound
polylane_fs symlink-exclusive "$pointer_bound_source" /new-bound
POLYLANE_FS_TEST_SYMLINK_BOUND_SWAP=1 assert_rc "pointer-bound-swap-rejected" 7 \
  polylane_fs replace-symlink "$pointer_bound_source" "$pointer_bound_dest"
assert_eq "pointer-bound-swap-rejected-before-exchange" /old-bound \
  "$(readlink "$pointer_bound_dest")"
directory_source="$safe_control/directory-source"; directory_dest="$safe_control/directory-dest"
polylane_safe_mkdir_exclusive "$directory_source" 0700
POLYLANE_FS_TEST_DIR_SOURCE_SWAP=1 assert_rc "directory-source-swap-rejected" 7 \
  polylane_fs rename-exclusive-dir "$directory_source" "$directory_dest"
assert_fail "directory-source-swap-left-no-public" test -e "$directory_dest"
post_source="$safe_control/directory-post-source"; post_dest="$safe_control/directory-post-dest"
polylane_safe_mkdir_exclusive "$post_source" 0700
POLYLANE_FS_TEST_DIR_POST_MISMATCH=1 assert_rc "directory-post-mismatch-rejected" 7 \
  polylane_fs rename-exclusive-dir "$post_source" "$post_dest"
assert_fail "directory-post-mismatch-left-no-public" test -e "$post_dest"
ln -s "$safe_control" "$TEST_TMPDIR/unsafe-control"
assert_rc "nofollow-ancestor-symlink-rejected" 7 polylane_safe_mkdirs \
  "$TEST_TMPDIR/unsafe-control/child" 0700
mkdir_rc=0
for worker in 1 2 3 4 5 6 7 8; do
  ( polylane_safe_mkdirs "$TEST_TMPDIR/concurrent/a/b/c" 0700 ) &
done
for worker in 1 2 3 4 5 6 7 8; do wait || mkdir_rc=1; done
assert_eq "concurrent-mkdir-reopen" 0 "$mkdir_rc"
assert_ok "concurrent-tree-valid" polylane_fs validate-dir "$TEST_TMPDIR/concurrent/a/b/c"
assert_eq "concurrent-leaf-private-mode" 700 \
  "$(case "$(uname -s)" in Linux) stat -c '%a' "$TEST_TMPDIR/concurrent/a/b/c" ;; \
    *) stat -f '%Lp' "$TEST_TMPDIR/concurrent/a/b/c" ;; esac)"

unset POLYLANE_AGENT_ADAPTER
assert_ok "runner-source-without-adapter" bash -c '. "$1"' _ \
  "$ROOT/core/scripts/polylane-run.sh"
for helper in polylane-run.sh polylane-doctor.sh polylane-supervisor.sh \
  polylane-dashboard.sh polylane-outcomes.sh polylane-promptlint.sh polylane-scout.sh; do
  assert_eq "root-compat-$helper" ../claude-code/scripts/polylane-claude-compat.sh \
    "$(readlink "$ROOT/bin/$helper" 2>/dev/null || true)"
done
mkdir -p "$TEST_TMPDIR/compat/bin" "$TEST_TMPDIR/compat/adapter"
cp "$ROOT/claude-code/scripts/polylane-claude-compat.sh" \
  "$ROOT/claude-code/scripts/polylane-claude-agent.sh" "$TEST_TMPDIR/compat/adapter/"
cat > "$TEST_TMPDIR/compat/adapter/polylane-run.sh" <<'SH'
#!/usr/bin/env bash
printf '%s|%s\n' "$POLYLANE_AGENT" "$POLYLANE_AGENT_ADAPTER"
SH
chmod +x "$TEST_TMPDIR/compat/adapter/"*.sh
ln -s ../adapter/polylane-claude-compat.sh "$TEST_TMPDIR/compat/bin/polylane-run.sh"
compat=$(env -u POLYLANE_AGENT -u POLYLANE_AGENT_ADAPTER \
  "$TEST_TMPDIR/compat/bin/polylane-run.sh")
assert_contains "compat-selects-claude-identity" 'claude|' "$compat"
assert_contains "compat-selects-claude-adapter" '/polylane-claude-agent.sh' "$compat"

printf '%s\n' '{"agent":"codex","run_id":"r1","lanes":[{}]}' > "$TEST_TMPDIR/codex.json"
printf '%s\n' '{"agent":"claude","run_id":"r1","lanes":[{}]}' > "$TEST_TMPDIR/claude.json"
printf '%s\n' '{"agent":"wat","run_id":"r1","lanes":[{}]}' > "$TEST_TMPDIR/unknown.json"
printf '%s\n' '{"run_id":"r1","lanes":[{}]}' > "$TEST_TMPDIR/missing.json"

unset POLYLANE_AGENT POLYLANE_AGENT_CMD
assert_eq "manifest-codex" codex "$(polylane_agent_from_manifest "$TEST_TMPDIR/codex.json")"
assert_rc "manifest-missing-agent" 2 polylane_agent_from_manifest "$TEST_TMPDIR/missing.json"

. "$ROOT/codex/scripts/polylane-codex-agent.sh"
assert_eq "codex-cli" codex "$(polylane_agent_cli codex)"
assert_eq "gpt-cli" codex "$(polylane_agent_cli gpt)"
assert_eq "shared-claude-cli" claude "$(polylane_agent_cli claude)"

. "$ROOT/claude-code/scripts/polylane-claude-agent.sh"
assert_eq "claude-cli" claude "$(polylane_agent_cli claude)"
assert_rc "unknown-agent" 2 polylane_agent_cli wat
POLYLANE_AGENT_CMD='mock {model} {prompt} {effort}'
assert_eq "custom-no-cli" custom "$(polylane_agent_cli claude)"
assert_rc "custom-still-rejects-unknown" 2 polylane_agent_cli wat
unset POLYLANE_AGENT_CMD

mkdir -p "$TEST_TMPDIR/bin"
SIDE_EFFECT_LOG="$TEST_TMPDIR/side-effects"
export SIDE_EFFECT_LOG
: > "$SIDE_EFFECT_LOG"
for name in git tmux codex claude; do
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "${0##*/}" >> "$SIDE_EFFECT_LOG"' 'exit 99' \
    > "$TEST_TMPDIR/bin/$name"
  chmod +x "$TEST_TMPDIR/bin/$name"
done
PATH="$TEST_TMPDIR/bin:$PATH" POLYLANE_AGENT_ADAPTER="$ROOT/codex/scripts/polylane-codex-agent.sh" \
  assert_rc "unknown-runner-rc" 2 "$ROOT/core/scripts/polylane-run.sh" "$TEST_TMPDIR/unknown.json"
assert_eq "unknown-no-side-effects" "" "$(cat "$SIDE_EFFECT_LOG")"
POLYLANE_AGENT_CMD='mock {model} {prompt} {effort}' \
  PATH="$TEST_TMPDIR/bin:$PATH" \
  POLYLANE_AGENT_ADAPTER="$ROOT/codex/scripts/polylane-codex-agent.sh" \
  assert_rc "override-does-not-admit-unknown" 2 \
    "$ROOT/core/scripts/polylane-run.sh" "$TEST_TMPDIR/unknown.json"
assert_eq "override-no-side-effects" "" "$(cat "$SIDE_EFFECT_LOG")"

finish
```

Expected: `bash -n core/tests/test-agent-preflight.sh` exits 0.

- [ ] **Step 3: Add the complete exact Codex command test (4 minutes)**

Create `codex/tests/test-codex-command.sh` with this complete body. The fake CLI records
one argument per line and copies stdin byte-for-byte:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
. "$ROOT/core/scripts/polylane-agent.sh"
. "$ROOT/codex/scripts/polylane-codex-agent.sh"
assert_eq "source-tree-codex-fs-helper" "$ROOT/core/scripts/polylane-fs.py" \
  "$POLYLANE_CODEX_FS_HELPER"
export POLYLANE_AGENT_ADAPTER="$ROOT/codex/scripts/polylane-codex-agent.sh"
. "$ROOT/core/scripts/polylane-run.sh"
make_tmpdir
mkdir -p "$TEST_TMPDIR/bin" "$TEST_TMPDIR/work tree" "$TEST_TMPDIR/real cli" \
  "$TEST_TMPDIR/hostile"
physical_node=$(polylane_codex_resolve_path "$(command -v node)")
cp "$physical_node" "$TEST_TMPDIR/real cli/node-real"
chmod +x "$TEST_TMPDIR/real cli/node-real"
cat > "$TEST_TMPDIR/real cli/codex.js" <<'JS'
#!/usr/bin/env node
const fs = require('fs');
fs.writeFileSync(process.env.CODEX_ARGS, process.argv.slice(2).join('\n') + '\n');
fs.writeFileSync(process.env.CODEX_STDIN, fs.readFileSync(0));
switch (process.env.CODEX_MODE || 'ok') {
  case 'stdout-overflow': process.stdout.write('x'.repeat(4096)); process.exit(0);
  case 'stderr-overflow': process.stderr.write('x'.repeat(4096)); process.exit(1);
  case 'invalid':
    console.log('{"type":"thread.started","thread_id":"t-invalid"}');
    console.log('not-json');
    process.exit(9);
  case 'hold': {
    fs.writeFileSync(process.env.NODE_READY, 'ready\n');
    const deadline = Date.now() + 10000;
    const waiter = new Int32Array(new SharedArrayBuffer(4));
    while (!fs.existsSync(process.env.NODE_CONTINUE) && Date.now() < deadline)
      Atomics.wait(waiter, 0, 0, 25);
    if (!fs.existsSync(process.env.NODE_CONTINUE)) process.exit(70);
    break;
  }
}
console.log('{"type":"thread.started","thread_id":"t-command"}');
console.log('{"type":"turn.started"}');
console.log('{"type":"turn.completed"}');
JS
chmod +x "$TEST_TMPDIR/real cli/codex.js"
ln -s "$TEST_TMPDIR/real cli/codex.js" "$TEST_TMPDIR/bin/codex"
ln -s "$TEST_TMPDIR/real cli/node-real" "$TEST_TMPDIR/bin/node"
cat > "$TEST_TMPDIR/hostile/node" <<'SH'
#!/bin/sh
printf 'hostile-node\n' >> "$HOSTILE_LOG"
exit 97
SH
cat > "$TEST_TMPDIR/hostile/bash" <<'SH'
#!/bin/sh
printf 'hostile-bash\n' >> "$HOSTILE_LOG"
exit 98
SH
chmod +x "$TEST_TMPDIR/hostile/node" "$TEST_TMPDIR/hostile/bash"
export PATH="$TEST_TMPDIR/hostile:$TEST_TMPDIR/bin:$PATH" CODEX_ARGS="$TEST_TMPDIR/args" \
  CODEX_STDIN="$TEST_TMPDIR/stdin" POLYLANE_RUNTIME_DIR="$TEST_TMPDIR/runtime" \
  POLYLANE_CLAIM_TOKEN=claim-command POLYLANE_RUNNER_GENERATION=3 POLYLANE_ATTEMPT=2 \
  HOSTILE_LOG="$TEST_TMPDIR/hostile.log"
prompt="$TEST_TMPDIR/prompt with spaces.txt"
printf 'literal $HOME `ticks` "quotes"\nsecond line\n' > "$prompt"
AGENT=codex
assert_eq "canonical-codex-target" "$TEST_TMPDIR/real cli/codex.js" \
  "$(polylane_adapter_cli codex)"
frozen_bash=$(polylane_adapter_shell codex)
assert_eq "trusted-shell-never-uses-path" "$(cd /bin && pwd -P)/bash" "$frozen_bash"
assert_ok "trusted-shell-has-bound-identity" polylane_codex_identity_fields "$frozen_bash"
identity_id() {
  local dev ino mode hash
  read -r dev ino mode hash <<<"$(polylane_codex_identity_fields "$1")"
  printf '%s:%s:%s:%s\n' "$dev" "$ino" "$mode" "$hash"
}
template=$(polylane_adapter_template codex)
placeholder_count=0
for token in '{model}' '{effort}' '{prompt}' '{error_artifact}'; do
  case "$template" in *"$token"*) placeholder_count=$((placeholder_count + 1)) ;; esac
done
assert_eq "stable-wrapper-abi-has-four-user-placeholders" 4 "$placeholder_count"
cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$prompt" high)
assert_contains "tmux-command-freezes-absolute-codex" \
  "$(printf '%q' "$TEST_TMPDIR/real cli/codex.js")" "$cmd"
assert_contains "tmux-command-freezes-physical-node" \
  "$(printf '%q' "$TEST_TMPDIR/real cli/node-real")" "$cmd"
assert_contains "tmux-command-explicit-physical-bash" \
  "exec $(printf '%q' "$frozen_bash")" "$cmd"
assert_contains "tmux-command-binds-bash-identity" \
  "POLYLANE_CODEX_BASH_ID=$(identity_id "$frozen_bash")" "$cmd"
assert_contains "tmux-command-binds-wrapper-identity" \
  "POLYLANE_CODEX_WRAPPER_ID=$(identity_id "$ROOT/codex/scripts/polylane-codex-exec.sh")" "$cmd"
assert_contains "tmux-command-binds-codex-identity" \
  "POLYLANE_CODEX_EXEC_ID=$(identity_id "$TEST_TMPDIR/real cli/codex.js")" "$cmd"
assert_contains "tmux-command-binds-node-identity" \
  "POLYLANE_CODEX_INTERPRETER_ID=$(identity_id "$TEST_TMPDIR/real cli/node-real")" "$cmd"
assert_contains "runner-binds-tmux-default-shell" 'default-shell "$AGENT_SHELL"' \
  "$(cat "$ROOT/core/scripts/polylane-run.sh")"
assert_contains "runner-binds-tmux-default-command" 'default-command "$AGENT_SHELL"' \
  "$(cat "$ROOT/core/scripts/polylane-run.sh")"
assert_eq "bsd-gnu-head-byte-count" abc "$(printf abcdef | head -c 3)"
PATH="$TEST_TMPDIR/hostile:$PATH" "$frozen_bash" -c "$cmd"
assert_eq "hostile-path-node-and-bash-never-run" "" "$(cat "$HOSTILE_LOG" 2>/dev/null || true)"
assert_eq "stdin-exact" "$(cksum < "$prompt")" "$(cksum < "$CODEX_STDIN")"
args=$(cat "$CODEX_ARGS")
expected=$(printf '%s\n' exec --json --sandbox workspace-write -c approval_policy=never \
  --model gpt-5-codex -c model_reasoning_effort=high -)
assert_eq "argv-exact" "$expected" "$args"
assert_not_contains "no-legacy" "--full-auto" "$args"
assert_ok "structured-success-result" jq -e \
  '.schema_version==2 and .provider=="codex" and .kind=="none" and
   .terminal_type=="turn.completed" and .process_exit==0 and
   (.events_hash|test("^sha256:[0-9a-f]{64}$")) and
   (.stderr_hash|test("^sha256:[0-9a-f]{64}$"))' \
  "$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a2/prompt with spaces.txt.json"

POLYLANE_ATTEMPT=3; export POLYLANE_ATTEMPT
overflow_prompt="$TEST_TMPDIR/overflow.txt"; printf 'overflow\n' > "$overflow_prompt"
overflow_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$overflow_prompt" high)
CODEX_MODE=stdout-overflow POLYLANE_CODEX_MAX_EVENT_BYTES=64 \
  assert_rc "stdout-byte-cap-is-typed" 74 "$frozen_bash" -c "$overflow_cmd"
overflow_artifact="$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a3/overflow.txt.json"
assert_eq "stdout-cap-code" capture_limit "$(jq -r .code "$overflow_artifact")"
assert_eq "stdout-cap-class" transient \
  "$(polylane_agent_error_class codex "$overflow_artifact")"

POLYLANE_ATTEMPT=4; export POLYLANE_ATTEMPT
stderr_prompt="$TEST_TMPDIR/stderr-overflow.txt"; printf 'overflow\n' > "$stderr_prompt"
stderr_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$stderr_prompt" high)
CODEX_MODE=stderr-overflow POLYLANE_CODEX_MAX_STDERR_BYTES=64 \
  assert_rc "stderr-byte-cap-is-typed" 74 "$frozen_bash" -c "$stderr_cmd"
assert_eq "stderr-cap-code" capture_limit \
  "$(jq -r .code "$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a4/stderr-overflow.txt.json")"

POLYLANE_ATTEMPT=5; export POLYLANE_ATTEMPT
parser_prompt="$TEST_TMPDIR/parser-timeout.txt"; printf 'parser\n' > "$parser_prompt"
parser_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$parser_prompt" high)
POLYLANE_CODEX_TEST_PARSER_DELAY=2 POLYLANE_CODEX_PARSER_TIMEOUT=1 \
  assert_rc "parser-deadline-is-typed" 74 "$frozen_bash" -c "$parser_cmd"
assert_eq "parser-timeout-code" parser_timeout \
  "$(jq -r .code "$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a5/parser-timeout.txt.json")"

cat > "$TEST_TMPDIR/real cli/unsupported" <<'SH'
#!/usr/bin/env -S node
SH
chmod +x "$TEST_TMPDIR/real cli/unsupported"
rm "$TEST_TMPDIR/bin/codex"; ln -s "$TEST_TMPDIR/real cli/unsupported" "$TEST_TMPDIR/bin/codex"
assert_rc "unsupported-shebang-fails-closed" 2 polylane_adapter_template codex
rm "$TEST_TMPDIR/bin/codex"; ln -s "$TEST_TMPDIR/real cli/codex.js" "$TEST_TMPDIR/bin/codex"
POLYLANE_BIND_KIND=; POLYLANE_BIND_INTERPRETER=
assert_ok "native-magic-is-recognized" polylane_codex_detect_launch \
  "$TEST_TMPDIR/real cli/node-real" "$TEST_TMPDIR/bin/codex"
assert_eq "native-kind" native "$POLYLANE_BIND_KIND"

# A same-path interpreter replacement after command construction is rejected before
# Codex starts and still produces one typed terminal (inode changed despite same bytes/mode).
POLYLANE_ATTEMPT=6; export POLYLANE_ATTEMPT
swap_prompt="$TEST_TMPDIR/swap-before.txt"; printf 'swap\n' > "$swap_prompt"
swap_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$swap_prompt" high)
mv "$TEST_TMPDIR/real cli/node-real" "$TEST_TMPDIR/real cli/node-saved"
cp "$TEST_TMPDIR/real cli/node-saved" "$TEST_TMPDIR/real cli/node-real"
chmod +x "$TEST_TMPDIR/real cli/node-real"; rm -f "$CODEX_ARGS"
assert_rc "node-swap-before-run-fails-closed" 74 "$frozen_bash" -c "$swap_cmd"
swap_artifact="$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a6/swap-before.txt.json"
assert_eq "node-swap-before-run-code" launch_identity_changed \
  "$(jq -r .code "$swap_artifact")"
assert_ok "node-swap-before-run-result-mode" test \
  "$(polylane_codex_mode_of "$swap_artifact")" = 400
assert_fail "node-swap-before-run-never-started-codex" test -e "$CODEX_ARGS"
rm "$TEST_TMPDIR/real cli/node-real"
mv "$TEST_TMPDIR/real cli/node-saved" "$TEST_TMPDIR/real cli/node-real"

# Swapping the physical node path while its old inode is executing is caught by
# the post-exec identity check and produces one immutable typed terminal artifact.
POLYLANE_ATTEMPT=7; export POLYLANE_ATTEMPT
during_prompt="$TEST_TMPDIR/swap-during.txt"; printf 'during\n' > "$during_prompt"
during_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$during_prompt" high)
NODE_READY="$TEST_TMPDIR/node.ready" NODE_CONTINUE="$TEST_TMPDIR/node.continue"; export NODE_READY NODE_CONTINUE
set +e
CODEX_MODE=hold "$frozen_bash" -c "$during_cmd" & during_pid=$!
set -e
i=0; while [ ! -f "$NODE_READY" ] && [ "$i" -lt 200 ]; do sleep 0.05; i=$((i+1)); done
assert_ok "node-child-reached-running-state" test -f "$NODE_READY"
mv "$TEST_TMPDIR/real cli/node-real" "$TEST_TMPDIR/real cli/node-saved"
cp "$TEST_TMPDIR/real cli/node-saved" "$TEST_TMPDIR/real cli/node-real"
chmod +x "$TEST_TMPDIR/real cli/node-real"; : > "$NODE_CONTINUE"
set +e; wait "$during_pid"; during_rc=$?; set -e
rm "$TEST_TMPDIR/real cli/node-real"
mv "$TEST_TMPDIR/real cli/node-saved" "$TEST_TMPDIR/real cli/node-real"
assert_eq "node-swap-during-run-rc" 74 "$during_rc"
during_artifact="$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a7/swap-during.txt.json"
assert_eq "node-swap-during-run-code" launch_identity_changed \
  "$(jq -r .code "$during_artifact")"
assert_ok "typed-identity-result-mode" test "$(polylane_codex_mode_of "$during_artifact")" = 400
assert_not_contains "wrapper-never-deletes-visible-artifact" 'rm -f "$artifact"' \
  "$(cat "$ROOT/codex/scripts/polylane-codex-exec.sh")"

restricted_path_without() {
  local omitted=$1 directory=$2 dependency hash_tool
  mkdir "$directory"
  for dependency in awk basename chmod cp date dirname grep head jq ln mkdir od \
    python3 readlink rm sleep stat tr uname wc; do
    [ "$dependency" = "$omitted" ] || ln -s "$(command -v "$dependency")" "$directory/$dependency"
  done
  if command -v shasum >/dev/null 2>&1; then hash_tool=shasum; else hash_tool=sha256sum; fi
  ln -s "$(command -v "$hash_tool")" "$directory/$hash_tool"
}
MINBIN="$TEST_TMPDIR/minbin"; restricted_path_without head "$MINBIN"
POLYLANE_ATTEMPT=8; export POLYLANE_ATTEMPT
missing_prompt="$TEST_TMPDIR/missing-head.txt"; printf 'missing\n' > "$missing_prompt"
missing_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$missing_prompt" high)
missing_artifact="$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a8/missing-head.txt.json"
PATH="$MINBIN" assert_rc "missing-head-fails-before-artifact-creation" 2 \
  "$frozen_bash" -c "$missing_cmd"
assert_fail "missing-dependency-created-no-artifact" test -e "$missing_artifact"
LATEBIN="$TEST_TMPDIR/latebin"; restricted_path_without date "$LATEBIN"
POLYLANE_ATTEMPT=9; export POLYLANE_ATTEMPT
late_prompt="$TEST_TMPDIR/missing-date.txt"; printf 'missing\n' > "$late_prompt"
late_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$late_prompt" high)
late_artifact="$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a9/missing-date.txt.json"
PATH="$LATEBIN" assert_rc "missing-late-date-fails-before-artifact-creation" 2 \
  "$frozen_bash" -c "$late_cmd"
assert_fail "missing-date-created-no-artifact" test -e "$late_artifact"
POLYLANE_ATTEMPT=10; export POLYLANE_ATTEMPT
large_prompt="$TEST_TMPDIR/oversized.txt"; printf 'large\n' > "$large_prompt"
large_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$large_prompt" high)
POLYLANE_CODEX_MAX_EVENT_BYTES=999999999 assert_rc "oversized-cap-rejected" 2 \
  "$frozen_bash" -c "$large_cmd"
large_artifact="$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a10/oversized.txt.json"
assert_fail "oversized-cap-created-no-artifact" test -e "$large_artifact"

POLYLANE_ATTEMPT=11; export POLYLANE_ATTEMPT
invalid_prompt="$TEST_TMPDIR/parser-invalid.txt"; printf 'invalid\n' > "$invalid_prompt"
invalid_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$invalid_prompt" high)
CODEX_MODE=invalid assert_rc "invalid-parser-is-always-typed" 74 \
  "$frozen_bash" -c "$invalid_cmd"
invalid_artifact="$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a11/parser-invalid.txt.json"
assert_eq "invalid-parser-code" parser_invalid "$(jq -r .code "$invalid_artifact")"

POLYLANE_ATTEMPT=12; export POLYLANE_ATTEMPT
drain_prompt="$TEST_TMPDIR/drain-failure.txt"; printf 'drain\n' > "$drain_prompt"
drain_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$drain_prompt" high)
POLYLANE_FS_TEST_TEE_FAIL=1 assert_rc "tee-drain-failure-is-typed" 74 \
  "$frozen_bash" -c "$drain_cmd"
drain_artifact="$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a12/drain-failure.txt.json"
assert_eq "tee-drain-failure-code" capture_drain_failed "$(jq -r .code "$drain_artifact")"

POLYLANE_ATTEMPT=13; export POLYLANE_ATTEMPT
fifo_prompt="$TEST_TMPDIR/fifo-failure.txt"; printf 'fifo\n' > "$fifo_prompt"
fifo_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$fifo_prompt" high)
POLYLANE_FS_TEST_SECOND_FIFO_FAIL=1 assert_rc "second-fifo-failure-cleans-first" 2 \
  "$frozen_bash" -c "$fifo_cmd"
fifo_artifact="$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a13/fifo-failure.txt.json"
fifo_left=0
for candidate in "$fifo_artifact".stdout-fifo.* "$fifo_artifact".stderr-fifo.*; do
  [ ! -e "$candidate" ] && [ ! -L "$candidate" ] || fifo_left=1
done
assert_eq "second-fifo-failure-left-no-control-file" 0 "$fifo_left"

# Exercise the native branch, not just magic detection. A copied native Node binary
# stands in for a native Codex binary and executes a local `exec` fixture with the same argv.
cat > "$TEST_TMPDIR/work tree/exec" <<'JS'
const fs = require('fs');
fs.writeFileSync(process.env.CODEX_ARGS, ['exec', ...process.argv.slice(2)].join('\n') + '\n');
fs.writeFileSync(process.env.CODEX_STDIN, fs.readFileSync(0));
console.log('{"type":"thread.started","thread_id":"t-native"}');
console.log('{"type":"turn.started"}');
console.log('{"type":"turn.completed"}');
JS
rm "$TEST_TMPDIR/bin/codex"
ln -s "$TEST_TMPDIR/real cli/node-real" "$TEST_TMPDIR/bin/codex"
POLYLANE_ATTEMPT=14; export POLYLANE_ATTEMPT
native_prompt="$TEST_TMPDIR/native.txt"; printf 'native\n' > "$native_prompt"
native_template=$(polylane_adapter_template codex)
assert_contains "native-interpreter-path-is-empty" "POLYLANE_CODEX_INTERPRETER=''" "$native_template"
assert_contains "native-interpreter-id-is-empty" "POLYLANE_CODEX_INTERPRETER_ID=''" "$native_template"
assert_not_contains "native-interpreter-id-is-never-colons" 'POLYLANE_CODEX_INTERPRETER_ID=:::' \
  "$native_template"
native_cmd=$(pane_cmd "$TEST_TMPDIR/work tree" gpt-5-codex "$native_prompt" high)
assert_ok "native-codex-executes" "$frozen_bash" -c "$native_cmd"
native_artifact="$POLYLANE_RUNTIME_DIR/agent-errors/claim-command/g3/a14/native.txt.json"
assert_eq "native-terminal-result" turn.completed "$(jq -r .terminal_type "$native_artifact")"
assert_eq "native-argv-exact" "$expected" "$(cat "$CODEX_ARGS")"
assert_eq "native-stdin-exact" "$(cksum < "$native_prompt")" "$(cksum < "$CODEX_STDIN")"
rm "$TEST_TMPDIR/bin/codex"
ln -s "$TEST_TMPDIR/real cli/codex.js" "$TEST_TMPDIR/bin/codex"
finish
```

Run: `bash -n codex/tests/test-codex-command.sh`

Expected: exit 0; the fake CLI and exact stdin/argv assertions are syntactically valid.

- [ ] **Step 4: Add the complete model/effort resolver test (4 minutes)**

Create `codex/tests/test-codex-model-resolver.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
RESOLVER="$ROOT/codex/scripts/polylane-codex-model.sh"
make_tmpdir
mkdir -p "$TEST_TMPDIR/home"
cat > "$TEST_TMPDIR/home/config.toml" <<'TOML'
# only top-level keys are eligible
model = "gpt-config"
model_reasoning_effort = "high" # trailing comment
[profiles.unused]
model = "gpt-nested-must-not-win"
model_reasoning_effort = "low"
TOML

assert_eq "model-config" gpt-config "$(CODEX_HOME="$TEST_TMPDIR/home" "$RESOLVER" resolve-model)"
assert_eq "model-env" gpt-env "$(CODEX_HOME="$TEST_TMPDIR/home" POLYLANE_CODEX_MODEL=gpt-env \
  "$RESOLVER" resolve-model)"
assert_eq "model-explicit" gpt-explicit "$(CODEX_HOME="$TEST_TMPDIR/home" \
  POLYLANE_CODEX_MODEL=gpt-env "$RESOLVER" resolve-model gpt-explicit)"
assert_eq "effort-config" high "$(CODEX_HOME="$TEST_TMPDIR/home" \
  "$RESOLVER" resolve-effort '' medium)"
assert_eq "effort-env" xhigh "$(CODEX_HOME="$TEST_TMPDIR/home" \
  POLYLANE_CODEX_EFFORT=xhigh "$RESOLVER" resolve-effort '' medium)"
assert_eq "effort-explicit" low "$(CODEX_HOME="$TEST_TMPDIR/home" \
  POLYLANE_CODEX_EFFORT=xhigh "$RESOLVER" resolve-effort low medium)"

mkdir -p "$TEST_TMPDIR/nested"
printf '%s\n' '[profile.only]' 'model = "gpt-nested"' > "$TEST_TMPDIR/nested/config.toml"
assert_rc "nested-key-ignored" 4 env CODEX_HOME="$TEST_TMPDIR/nested" \
  "$RESOLVER" resolve-model
assert_rc "missing-config" 4 env CODEX_HOME="$TEST_TMPDIR/missing" \
  "$RESOLVER" resolve-model
assert_rc "bad-model-space" 2 "$RESOLVER" resolve-model 'bad model'
bad_model=$(printf 'bad\nid')
assert_rc "bad-model-newline" 2 "$RESOLVER" resolve-model "$bad_model"
bad_model=$(printf 'bad\001id')
assert_rc "bad-model-control" 2 "$RESOLVER" resolve-model "$bad_model"
for effort in low medium high xhigh; do
  assert_eq "effort-$effort" "$effort" "$($RESOLVER resolve-effort "$effort" medium)"
done
assert_rc "bad-effort" 2 "$RESOLVER" resolve-effort extreme medium
finish
```

Expected: `bash -n codex/tests/test-codex-model-resolver.sh` exits 0.

- [ ] **Step 5: Run the three tests and verify RED (3 minutes)**

```bash
bash core/tests/test-agent-preflight.sh
bash codex/tests/test-codex-command.sh
bash codex/tests/test-codex-model-resolver.sh
```

Expected: every command exits nonzero. The first reports missing
`core/scripts/polylane-agent.sh`, the second cannot produce the required argv, and the
third reports missing `polylane-codex-model.sh`.

- [ ] **Step 6: Add the complete shared agent contract (4 minutes)**

Create executable `core/scripts/polylane-fs.py`. This is the only primitive used to create
runtime, attempt, receipt, release, and control paths; every component is traversed by directory
file descriptor with `O_NOFOLLOW`, private files use `O_CREAT|O_EXCL|O_NOFOLLOW`, and publication
uses an exclusive hard link:

```python
#!/usr/bin/env python3
import ctypes, errno, fcntl, hashlib, os, platform, stat, subprocess, sys, time

if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
    raise SystemExit("polylane-fs: O_NOFOLLOW/O_DIRECTORY required")
NOFOLLOW, DIRECTORY = os.O_NOFOLLOW, os.O_DIRECTORY
UID = os.geteuid()

def verify_dir(fd, managed=False):
    st = os.fstat(fd); mode = stat.S_IMODE(st.st_mode)
    if not stat.S_ISDIR(st.st_mode): raise ValueError("component is not a directory")
    if managed:
        if st.st_uid != UID or mode & 0o022: raise ValueError("unsafe managed directory")
    elif st.st_uid not in (0, UID): raise ValueError("untrusted ancestor owner")
    elif mode & 0o022 and not (mode & stat.S_ISVTX and st.st_uid == 0):
        raise ValueError("writable ancestor")

def parts(path):
    if not os.path.isabs(path):
        raise ValueError("absolute path required")
    value = [p for p in path.split("/") if p]
    if any(p in (".", "..") for p in value):
        raise ValueError("unsafe component")
    return value

def walk_dir(path, create=False, mode=0o700):
    fd = os.open("/", os.O_RDONLY | DIRECTORY)
    managed = False
    try:
        verify_dir(fd, False)
        for component in parts(path):
            try:
                child = os.open(component, os.O_RDONLY | DIRECTORY | NOFOLLOW, dir_fd=fd)
            except FileNotFoundError:
                if not create:
                    raise
                try: os.mkdir(component, mode, dir_fd=fd); os.fsync(fd)
                except FileExistsError: pass
                child = os.open(component, os.O_RDONLY | DIRECTORY | NOFOLLOW, dir_fd=fd)
                managed = True
            st = os.fstat(child)
            if st.st_uid == UID: managed = True
            verify_dir(child, managed)
            os.close(fd); fd = child
        return fd
    except Exception:
        os.close(fd)
        raise

def parent(path, create=False, mode=0o700):
    values = parts(path)
    if not values:
        raise ValueError("root is not an entry")
    directory = "/" + "/".join(values[:-1]) if len(values) > 1 else "/"
    return walk_dir(directory, create, mode), values[-1]

def validate_prefix(path):
    fd = os.open("/", os.O_RDONLY | DIRECTORY)
    managed = False
    try:
        verify_dir(fd, False)
        for component in parts(path):
            try: child = os.open(component, os.O_RDONLY | DIRECTORY | NOFOLLOW, dir_fd=fd)
            except FileNotFoundError: return
            if os.fstat(child).st_uid == UID: managed = True
            verify_dir(child, managed)
            os.close(fd); fd = child
    finally: os.close(fd)

def regular_nofollow(path):
    st = os.stat(path, follow_symlinks=False)
    return stat.S_ISREG(st.st_mode)

def object_id(st):
    return st.st_dev, st.st_ino

def fd_digest(fd):
    digest = hashlib.sha256(); offset = 0
    while True:
        block = os.pread(fd, 131072, offset)
        if not block: return digest.digest()
        digest.update(block); offset += len(block)

def rename_flags(src_fd, src, dst_fd, dst, flag):
    libc = ctypes.CDLL(None, use_errno=True)
    old = ctypes.c_char_p(os.fsencode(src)); new = ctypes.c_char_p(os.fsencode(dst))
    system = platform.system()
    if system == "Linux" and hasattr(libc, "renameat2"):
        rc = libc.renameat2(src_fd, old, dst_fd, new, flag)
    elif system == "Darwin" and hasattr(libc, "renameatx_np"):
        # Linux RENAME_NOREPLACE/EXCHANGE are 1/2; macOS RENAME_EXCL/SWAP are 4/2.
        mac_flag = 0x00000004 if flag == 1 else 0x00000002
        rc = libc.renameatx_np(src_fd, old, dst_fd, new, mac_flag)
    else:
        raise ValueError("atomic rename primitive unavailable")
    if rc != 0:
        err = ctypes.get_errno(); raise OSError(err, os.strerror(err), dst)

def link_open_regular(fd, dst_fd, dst):
    system = platform.system(); libc = ctypes.CDLL(None, use_errno=True)
    if system == "Linux" and hasattr(libc, "linkat"):
        # AT_EMPTY_PATH may require privilege; procfs + AT_SYMLINK_FOLLOW is the documented fallback.
        rc = libc.linkat(fd, ctypes.c_char_p(b""), dst_fd,
                         ctypes.c_char_p(os.fsencode(dst)), 0x1000)
        if rc != 0:
            rc = libc.linkat(-100, ctypes.c_char_p(os.fsencode(f"/proc/self/fd/{fd}")), dst_fd,
                             ctypes.c_char_p(os.fsencode(dst)), 0x400)
        if rc != 0:
            err = ctypes.get_errno(); raise OSError(err, os.strerror(err), dst)
    elif system == "Darwin":
        source = os.fstat(fd)
        out = os.open(dst, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW,
                      stat.S_IMODE(source.st_mode), dir_fd=dst_fd)
        try:
            os.fchmod(out, stat.S_IMODE(source.st_mode)); offset = 0
            while True:
                block = os.pread(fd, 131072, offset)
                if not block: break
                view = memoryview(block)
                while view:
                    written = os.write(out, view); view = view[written:]
                offset += len(block)
            os.fsync(out)
        finally: os.close(out)
    else:
        raise ValueError("open-file publication primitive unavailable")

def random_leaf(prefix):
    return f".{prefix}.{os.getpid()}-{os.urandom(24).hex()}"

def test_cas_lock_barrier():
    marker = os.environ.get("POLYLANE_FS_TEST_CAS_LOCK_READY")
    if not marker: return
    pfd, leaf = parent(marker, False)
    try:
        fd = os.open(leaf, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW,
                     0o600, dir_fd=pfd)
        os.write(fd, b"ready\n"); os.fsync(fd); os.close(fd); os.fsync(pfd)
        deadline = time.monotonic() + 5
        while True:
            try:
                gate = os.stat(leaf + ".go", dir_fd=pfd, follow_symlinks=False)
                if not stat.S_ISREG(gate.st_mode): raise ValueError("unsafe CAS test gate")
                break
            except FileNotFoundError:
                if time.monotonic() >= deadline: raise TimeoutError("CAS test gate timeout")
                time.sleep(0.01)
    finally: os.close(pfd)

def ensure_regular_bytes(fd, dst_fd, dst):
    expected = os.fstat(fd); expected_digest = fd_digest(fd)
    while True:
        try:
            current_fd = os.open(dst, os.O_RDONLY | NOFOLLOW, dir_fd=dst_fd)
            try:
                current = os.fstat(current_fd)
                if stat.S_ISREG(current.st_mode) and current.st_size == expected.st_size and \
                   stat.S_IMODE(current.st_mode) == stat.S_IMODE(expected.st_mode) and \
                   fd_digest(current_fd) == expected_digest:
                    return
            finally: os.close(current_fd)
            quarantine = random_leaf(dst + ".cas-rejected")
            rename_flags(dst_fd, dst, dst_fd, quarantine, 1)
        except FileNotFoundError: pass
        restore = random_leaf(dst + ".cas-restore")
        link_open_regular(fd, dst_fd, restore)
        os.rename(restore, dst, src_dir_fd=dst_fd, dst_dir_fd=dst_fd)
        os.fsync(dst_fd)

def ensure_symlink_target(target, dst_fd, dst):
    while True:
        try:
            current = os.stat(dst, dir_fd=dst_fd, follow_symlinks=False)
            if stat.S_ISLNK(current.st_mode) and os.readlink(dst, dir_fd=dst_fd) == target:
                return
            quarantine = random_leaf(dst + ".cas-rejected")
            rename_flags(dst_fd, dst, dst_fd, quarantine, 1)
        except FileNotFoundError: pass
        restore = random_leaf(dst + ".cas-restore")
        os.symlink(target, restore, dir_fd=dst_fd)
        os.rename(restore, dst, src_dir_fd=dst_fd, dst_dir_fd=dst_fd)
        os.fsync(dst_fd)

def main(argv):
    command, path = argv[1], argv[2]
    if command == "process-start-token":
        pid = int(path)
        if pid <= 0: raise ValueError("invalid pid")
        system = platform.system()
        if system == "Linux":
            with open(f"/proc/{pid}/stat", "r", encoding="ascii") as handle:
                fields = handle.read().rsplit(")", 1)
            if len(fields) != 2: raise ValueError("invalid proc stat")
            tail = fields[1].split()
            if len(tail) < 20 or not tail[19].isdigit(): raise ValueError("missing start ticks")
            print(f"linux:{pid}:{tail[19]}")
        elif system == "Darwin":
            class ProcBSDInfo(ctypes.Structure):
                _fields_ = [(name, ctypes.c_uint32) for name in (
                    "flags","status","xstatus","pid","ppid","uid","gid","ruid","rgid",
                    "svuid","svgid","rfu_1")] + [("comm", ctypes.c_char * 16),
                    ("name", ctypes.c_char * 32)] + [(name, ctypes.c_uint32) for name in (
                    "nfiles","pgid","pjobc","e_tdev","e_tpgid")] + [("nice", ctypes.c_int32),
                    ("start_sec", ctypes.c_uint64), ("start_usec", ctypes.c_uint64)]
            info = ProcBSDInfo(); libproc = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
            size = ctypes.sizeof(info)
            got = libproc.proc_pidinfo(pid, 3, 0, ctypes.byref(info), size)
            if got != size or info.pid != pid or info.start_sec == 0:
                raise ValueError("high-resolution process birth identity unavailable")
            print(f"darwin:{pid}:{info.start_sec}:{info.start_usec}")
        else:
            raise ValueError("process birth identity unsupported")
        return
    if command == "mkdirs":
        fd = walk_dir(path, True, int(argv[3], 8)); os.close(fd); return
    if command == "validate-dir":
        fd = walk_dir(path, False); os.close(fd); return
    if command == "validate-prefix":
        validate_prefix(path); return
    if command == "validate-file":
        pfd, leaf = parent(path, False)
        try:
            fd = os.open(leaf, os.O_RDONLY | NOFOLLOW, dir_fd=pfd)
            try:
                found = os.fstat(fd); mode = stat.S_IMODE(found.st_mode)
                if not stat.S_ISREG(found.st_mode) or found.st_uid not in (0, UID) or mode & 0o022:
                    raise ValueError("unsafe regular file")
            finally: os.close(fd)
        finally: os.close(pfd)
        return
    if command == "mkdir-exclusive":
        pfd, leaf = parent(path, True, int(argv[3], 8))
        try:
            os.mkdir(leaf, int(argv[3], 8), dir_fd=pfd); os.fsync(pfd)
            child = os.open(leaf, os.O_RDONLY | DIRECTORY | NOFOLLOW, dir_fd=pfd)
            try: verify_dir(child, True)
            finally: os.close(child)
        finally: os.close(pfd)
        return
    if command == "create":
        mode = int(argv[3], 8); pfd, leaf = parent(path, False)
        try:
            fd = os.open(leaf, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW,
                         mode, dir_fd=pfd)
            try:
                os.fchmod(fd, mode)
                while True:
                    block = sys.stdin.buffer.read(131072)
                    if not block: break
                    view = memoryview(block)
                    while view:
                        written = os.write(fd, view); view = view[written:]
                os.fsync(fd)
            finally: os.close(fd)
            os.fsync(pfd)
        finally: os.close(pfd)
        return
    if command == "capture":
        mode = int(argv[3], 8); pfd, leaf = parent(path, False)
        try:
            fd = os.open(leaf, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW,
                         mode, dir_fd=pfd)
            try:
                os.fchmod(fd, mode)
                rc = subprocess.run(argv[4:], stdout=fd, close_fds=True).returncode
                if rc: raise ValueError(f"capture command exited {rc}")
                os.fsync(fd)
            except Exception:
                os.close(fd); fd = -1
                os.unlink(leaf, dir_fd=pfd); os.fsync(pfd)
                raise
            finally:
                if fd >= 0: os.close(fd)
            os.fsync(pfd)
        finally: os.close(pfd)
        return
    if command == "copy-exclusive":
        source = argv[2]; destination = argv[3]; mode = int(argv[4], 8)
        spfd, sleaf = parent(source, False); dpfd, dleaf = parent(destination, False)
        try:
            sfd = os.open(sleaf, os.O_RDONLY | NOFOLLOW, dir_fd=spfd)
            try:
                before = os.fstat(sfd)
                if not stat.S_ISREG(before.st_mode) or before.st_uid not in (0, UID):
                    raise ValueError("copy source must be trusted regular file")
                dfd = os.open(dleaf, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW,
                              mode, dir_fd=dpfd)
                try:
                    os.fchmod(dfd, mode)
                    while True:
                        block = os.read(sfd, 131072)
                        if not block: break
                        view = memoryview(block)
                        while view:
                            written = os.write(dfd, view); view = view[written:]
                    os.fsync(dfd)
                    after = os.stat(sleaf, dir_fd=spfd, follow_symlinks=False)
                    if (before.st_dev, before.st_ino) != (after.st_dev, after.st_ino):
                        raise ValueError("copy source changed")
                except Exception:
                    os.close(dfd); dfd = -1
                    os.unlink(dleaf, dir_fd=dpfd); os.fsync(dpfd)
                    raise
                finally:
                    if dfd >= 0: os.close(dfd)
                os.fsync(dpfd)
            finally: os.close(sfd)
        finally: os.close(spfd); os.close(dpfd)
        return
    if command == "tee-existing":
        pfd, leaf = parent(path, False)
        try:
            fd = os.open(leaf, os.O_WRONLY | os.O_APPEND | NOFOLLOW, dir_fd=pfd)
            if not stat.S_ISREG(os.fstat(fd).st_mode): raise ValueError("sink must be regular")
            try:
                while True:
                    block = sys.stdin.buffer.read(131072)
                    if not block: break
                    view = memoryview(block)
                    while view:
                        written = os.write(fd, view); view = view[written:]
                    sys.stdout.buffer.write(block); sys.stdout.buffer.flush()
                os.fsync(fd)
                if os.environ.get("POLYLANE_FS_TEST_TEE_FAIL") == "1":
                    raise OSError("injected tee failure")
            finally: os.close(fd)
        finally: os.close(pfd)
        return
    if command == "append":
        pfd, leaf = parent(path, False)
        try:
            fd = os.open(leaf, os.O_WRONLY | os.O_APPEND | NOFOLLOW, dir_fd=pfd)
            try:
                if not stat.S_ISREG(os.fstat(fd).st_mode): raise ValueError("append target not regular")
                while True:
                    block = sys.stdin.buffer.read(131072)
                    if not block: break
                    view = memoryview(block)
                    while view:
                        written = os.write(fd, view); view = view[written:]
                os.fsync(fd)
            finally: os.close(fd)
        finally: os.close(pfd)
        return
    if command == "chmod-existing":
        mode = int(argv[3], 8); pfd, leaf = parent(path, False)
        try:
            fd = os.open(leaf, os.O_RDONLY | NOFOLLOW, dir_fd=pfd)
            try:
                if not stat.S_ISREG(os.fstat(fd).st_mode): raise ValueError("chmod target not regular")
                os.fchmod(fd, mode); os.fsync(fd)
            finally: os.close(fd)
            os.fsync(pfd)
        finally: os.close(pfd)
        return
    if command == "mkfifo-exclusive":
        mode = int(argv[3], 8); pfd, leaf = parent(path, False)
        try:
            if os.environ.get("POLYLANE_FS_TEST_SECOND_FIFO_FAIL") == "1" and \
               ".stderr-fifo." in leaf:
                raise OSError("injected second fifo failure")
            os.mkfifo(leaf, mode, dir_fd=pfd)
            found = os.stat(leaf, dir_fd=pfd, follow_symlinks=False)
            if not stat.S_ISFIFO(found.st_mode): raise ValueError("fifo publication mismatch")
            os.fsync(pfd)
        finally: os.close(pfd)
        return
    if command == "unlink-fifo":
        pfd, leaf = parent(path, False)
        try:
            found = os.stat(leaf, dir_fd=pfd, follow_symlinks=False)
            if not stat.S_ISFIFO(found.st_mode): raise ValueError("unlink target not fifo")
            os.unlink(leaf, dir_fd=pfd); os.fsync(pfd)
        finally: os.close(pfd)
        return
    if command == "symlink-exclusive":
        target = argv[3]; pfd, leaf = parent(path, False)
        try:
            os.symlink(target, leaf, dir_fd=pfd); os.fsync(pfd)
            found = os.stat(leaf, dir_fd=pfd, follow_symlinks=False)
            if not stat.S_ISLNK(found.st_mode) or os.readlink(leaf, dir_fd=pfd) != target:
                raise ValueError("symlink publication mismatch")
        finally: os.close(pfd)
        return
    if command == "unlink-symlink":
        pfd, leaf = parent(path, False)
        try:
            found = os.stat(leaf, dir_fd=pfd, follow_symlinks=False)
            if not stat.S_ISLNK(found.st_mode): raise ValueError("unlink target not symlink")
            os.unlink(leaf, dir_fd=pfd); os.fsync(pfd)
        finally: os.close(pfd)
        return
    if command == "replace-symlink":
        source = argv[2]; destination = argv[3]
        spfd, sleaf = parent(source, False); dpfd, dleaf = parent(destination, False)
        lockfd = None; lock_id = None; locked = False; bound = None; saved_bound = None
        sfd = None; dfd = None; exchanged = False
        try:
            verify_dir(spfd, True); verify_dir(dpfd, True)
            lockleaf = f".{dleaf}.cas-lock"
            lockfd = os.open(lockleaf, os.O_RDWR | os.O_CREAT | NOFOLLOW, 0o600, dir_fd=dpfd)
            os.fchmod(lockfd, 0o600); lock_st = os.fstat(lockfd); lock_id = object_id(lock_st)
            if not stat.S_ISREG(lock_st.st_mode) or lock_st.st_uid != UID:
                raise ValueError("unsafe symlink replacement lock")
            fcntl.flock(lockfd, fcntl.LOCK_EX | fcntl.LOCK_NB); locked = True
            if object_id(os.stat(lockleaf, dir_fd=dpfd, follow_symlinks=False)) != lock_id:
                raise ValueError("symlink replacement lock identity changed")
            test_cas_lock_barrier()
            system = platform.system()
            if system == "Linux" and hasattr(os, "O_PATH"):
                symlink_open = os.O_PATH | NOFOLLOW
            elif system == "Darwin" and hasattr(os, "O_SYMLINK"):
                symlink_open = os.O_RDONLY | os.O_SYMLINK
            else:
                raise ValueError("symlink descriptor primitive unavailable")
            sfd = os.open(sleaf, symlink_open, dir_fd=spfd)
            try: dfd = os.open(dleaf, symlink_open, dir_fd=dpfd)
            except FileNotFoundError: dfd = None
            source_id = os.fstat(sfd); dest_id = os.fstat(dfd) if dfd is not None else None
            source_target = os.readlink(sleaf, dir_fd=spfd)
            dest_target = os.readlink(dleaf, dir_fd=dpfd) if dfd is not None else None
            if not stat.S_ISLNK(source_id.st_mode) or \
               (dest_id is not None and not stat.S_ISLNK(dest_id.st_mode)):
                raise ValueError("replacement operands must be symlinks")
            if os.environ.get("POLYLANE_FS_TEST_SYMLINK_SOURCE_SWAP") == "1":
                os.rename(sleaf, sleaf + ".swapped", src_dir_fd=spfd, dst_dir_fd=spfd)
                os.symlink("/swapped", sleaf, dir_fd=spfd); os.fsync(spfd)
            current_source = os.stat(sleaf, dir_fd=spfd, follow_symlinks=False)
            if object_id(current_source) != object_id(source_id) or \
               os.readlink(sleaf, dir_fd=spfd) != source_target:
                raise ValueError("symlink source pathname changed")
            bound = random_leaf(dleaf + ".cas-bound")
            os.symlink(source_target, bound, dir_fd=dpfd)
            bound_id = os.stat(bound, dir_fd=dpfd, follow_symlinks=False)
            if not stat.S_ISLNK(bound_id.st_mode) or os.readlink(bound, dir_fd=dpfd) != source_target:
                raise ValueError("symlink target snapshot failed")
            publish_id = object_id(bound_id)
            if os.environ.get("POLYLANE_FS_TEST_SYMLINK_BOUND_SWAP") == "1":
                saved_bound = random_leaf(dleaf + ".saved-bound")
                os.rename(bound, saved_bound, src_dir_fd=dpfd, dst_dir_fd=dpfd)
                os.symlink("/bound-swapped", bound, dir_fd=dpfd); os.fsync(dpfd)
            final_bound = os.stat(bound, dir_fd=dpfd, follow_symlinks=False)
            if not stat.S_ISLNK(final_bound.st_mode) or object_id(final_bound) != publish_id or \
               os.readlink(bound, dir_fd=dpfd) != source_target:
                raise ValueError("symlink target snapshot changed before CAS")
            if object_id(os.stat(lockleaf, dir_fd=dpfd, follow_symlinks=False)) != lock_id:
                raise ValueError("symlink replacement lock changed before CAS")
            if dest_id is None:
                # First publication needs no pathname carrier: create the captured target directly.
                os.symlink(source_target, dleaf, dir_fd=dpfd); os.fsync(dpfd)
                published = os.stat(dleaf, dir_fd=dpfd, follow_symlinks=False)
                if not stat.S_ISLNK(published.st_mode) or \
                   os.readlink(dleaf, dir_fd=dpfd) != source_target:
                    raise ValueError("exclusive symlink publication mismatch")
                os.unlink(bound, dir_fd=dpfd); bound = None
                current = os.stat(sleaf, dir_fd=spfd, follow_symlinks=False)
                if object_id(source_id) == object_id(current): os.unlink(sleaf, dir_fd=spfd)
                os.fsync(spfd); return
            current_dest = os.stat(dleaf, dir_fd=dpfd, follow_symlinks=False)
            if object_id(current_dest) != object_id(dest_id) or \
               os.readlink(dleaf, dir_fd=dpfd) != dest_target:
                raise ValueError("symlink destination changed before CAS")
            rename_flags(dpfd, bound, dpfd, dleaf, 2); exchanged = True
            published = os.stat(dleaf, dir_fd=dpfd, follow_symlinks=False)
            prior = os.stat(bound, dir_fd=dpfd, follow_symlinks=False)
            committed = object_id(published) == publish_id and \
                os.readlink(dleaf, dir_fd=dpfd) == source_target and \
                object_id(prior) == object_id(dest_id) and \
                os.readlink(bound, dir_fd=dpfd) == dest_target
            if not committed:
                rename_flags(dpfd, bound, dpfd, dleaf, 2); exchanged = False
                ensure_symlink_target(dest_target, dpfd, dleaf)
                raise ValueError("symlink replacement CAS lost an identity race")
            exchanged = False
            os.unlink(bound, dir_fd=dpfd); bound = None; os.fsync(dpfd)
            current = os.stat(sleaf, dir_fd=spfd, follow_symlinks=False)
            if object_id(source_id) == object_id(current):
                os.unlink(sleaf, dir_fd=spfd); os.fsync(spfd)
        except Exception:
            if exchanged:
                rollback_target = os.readlink(bound, dir_fd=dpfd)
                rename_flags(dpfd, bound, dpfd, dleaf, 2); exchanged = False
                ensure_symlink_target(rollback_target, dpfd, dleaf)
            raise
        finally:
            for entry in (bound, saved_bound):
                if not entry: continue
                try: os.unlink(entry, dir_fd=dpfd)
                except FileNotFoundError: pass
            if sfd is not None: os.close(sfd)
            if dfd is not None: os.close(dfd)
            if lockfd is not None:
                if locked:
                    try:
                        if object_id(os.stat(lockleaf, dir_fd=dpfd, follow_symlinks=False)) == lock_id:
                            os.unlink(lockleaf, dir_fd=dpfd); os.fsync(dpfd)
                    except FileNotFoundError: pass
                    fcntl.flock(lockfd, fcntl.LOCK_UN)
                os.close(lockfd)
            os.close(spfd); os.close(dpfd)
        return
    if command == "replace-existing-file":
        source = argv[2]; destination = argv[3]
        spfd, sleaf = parent(source, False); dpfd, dleaf = parent(destination, False)
        lockfd = None; lock_id = None; locked = False
        bound = None; saved_bound = None; concurrent_saved = None
        try:
            verify_dir(spfd, True); verify_dir(dpfd, True)
            lockleaf = f".{dleaf}.cas-lock"
            lockfd = os.open(lockleaf, os.O_RDWR | os.O_CREAT | NOFOLLOW, 0o600, dir_fd=dpfd)
            os.fchmod(lockfd, 0o600); lock_st = os.fstat(lockfd); lock_id = object_id(lock_st)
            if not stat.S_ISREG(lock_st.st_mode) or lock_st.st_uid != UID:
                raise ValueError("unsafe replacement lock")
            fcntl.flock(lockfd, fcntl.LOCK_EX | fcntl.LOCK_NB); locked = True
            if object_id(os.stat(lockleaf, dir_fd=dpfd, follow_symlinks=False)) != lock_id:
                raise ValueError("replacement lock identity changed")
            test_cas_lock_barrier()
            sfd = os.open(sleaf, os.O_RDONLY | NOFOLLOW, dir_fd=spfd)
            dfd = os.open(dleaf, os.O_RDONLY | NOFOLLOW, dir_fd=dpfd)
            exchanged = False
            try:
                source_id = os.fstat(sfd); dest_id = os.fstat(dfd)
                if not stat.S_ISREG(source_id.st_mode) or source_id.st_uid != UID or \
                   not stat.S_ISREG(dest_id.st_mode) or dest_id.st_uid != UID:
                    raise ValueError("replacement operands must be regular files")
                source_digest = fd_digest(sfd); dest_digest = fd_digest(dfd)
                if os.environ.get("POLYLANE_FS_TEST_REPLACE_SOURCE_SWAP") == "1":
                    os.rename(sleaf, sleaf + ".swapped", src_dir_fd=spfd, dst_dir_fd=spfd)
                    replacement = os.open(sleaf, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW,
                                          0o600, dir_fd=spfd)
                    os.write(replacement, b"swapped\n"); os.close(replacement); os.fsync(spfd)
                current_source = os.stat(sleaf, dir_fd=spfd, follow_symlinks=False)
                if object_id(current_source) != object_id(source_id):
                    raise ValueError("replacement source pathname changed")
                bound = random_leaf(dleaf + ".cas-bound")
                link_open_regular(sfd, dpfd, bound)
                bfd = os.open(bound, os.O_RDONLY | NOFOLLOW, dir_fd=dpfd)
                try: bound_id = os.fstat(bfd)
                finally: os.close(bfd)
                publish_id = object_id(bound_id)
                if not stat.S_ISREG(bound_id.st_mode) or bound_id.st_uid != UID or \
                   bound_id.st_size != source_id.st_size:
                    raise ValueError("open-file snapshot is invalid")
                check = os.open(bound, os.O_RDONLY | NOFOLLOW, dir_fd=dpfd)
                try:
                    if object_id(os.fstat(check)) != publish_id or fd_digest(check) != source_digest:
                        raise ValueError("open-file snapshot bytes changed")
                finally: os.close(check)
                if os.environ.get("POLYLANE_FS_TEST_REPLACE_BOUND_SWAP") == "1":
                    saved_bound = random_leaf(dleaf + ".saved-bound")
                    os.rename(bound, saved_bound, src_dir_fd=dpfd, dst_dir_fd=dpfd)
                    wrong = os.open(bound, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW,
                                    0o600, dir_fd=dpfd)
                    os.write(wrong, b"bound-swapped\n"); os.close(wrong); os.fsync(dpfd)
                final_bound = os.open(bound, os.O_RDONLY | NOFOLLOW, dir_fd=dpfd)
                try:
                    final_st = os.fstat(final_bound)
                    if not stat.S_ISREG(final_st.st_mode) or final_st.st_uid != UID or \
                       object_id(final_st) != publish_id or final_st.st_size != source_id.st_size or \
                       stat.S_IMODE(final_st.st_mode) != stat.S_IMODE(source_id.st_mode) or \
                       fd_digest(final_bound) != source_digest:
                        raise ValueError("open-file snapshot changed before CAS")
                finally: os.close(final_bound)
                if object_id(os.stat(lockleaf, dir_fd=dpfd, follow_symlinks=False)) != lock_id:
                    raise ValueError("replacement lock changed before CAS")
                if object_id(os.stat(dleaf, dir_fd=dpfd, follow_symlinks=False)) != object_id(dest_id):
                    raise ValueError("replacement destination changed before CAS")
                current_dfd = os.open(dleaf, os.O_RDONLY | NOFOLLOW, dir_fd=dpfd)
                try:
                    if fd_digest(current_dfd) != dest_digest:
                        raise ValueError("replacement destination bytes changed before CAS")
                finally: os.close(current_dfd)
                if os.environ.get("POLYLANE_FS_TEST_REPLACE_DEST_CHANGE") == "1":
                    concurrent_saved = random_leaf(dleaf + ".prior-destination")
                    os.rename(dleaf, concurrent_saved, src_dir_fd=dpfd, dst_dir_fd=dpfd)
                    winner = os.open(dleaf, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW,
                                     stat.S_IMODE(dest_id.st_mode), dir_fd=dpfd)
                    os.write(winner, b"concurrent-winner\n"); os.close(winner); os.fsync(dpfd)
                rename_flags(dpfd, bound, dpfd, dleaf, 2)
                exchanged = True
                published = os.open(dleaf, os.O_RDONLY | NOFOLLOW, dir_fd=dpfd)
                prior = os.open(bound, os.O_RDONLY | NOFOLLOW, dir_fd=dpfd)
                try:
                    published_st = os.fstat(published); prior_st = os.fstat(prior)
                    committed = object_id(published_st) == publish_id and \
                        fd_digest(published) == source_digest and \
                        object_id(prior_st) == object_id(dest_id) and \
                        fd_digest(prior) == dest_digest
                    if not committed:
                        restore_id = object_id(prior_st)
                        rename_flags(dpfd, bound, dpfd, dleaf, 2)
                        exchanged = False
                        restored = os.stat(dleaf, dir_fd=dpfd, follow_symlinks=False)
                        if object_id(restored) != restore_id:
                            ensure_regular_bytes(prior, dpfd, dleaf)
                        raise ValueError("replacement CAS lost an identity race")
                finally: os.close(published); os.close(prior)
                exchanged = False
                os.unlink(bound, dir_fd=dpfd); bound = None; os.fsync(dpfd)
            except Exception:
                if exchanged:
                    rollback = os.open(bound, os.O_RDONLY | NOFOLLOW, dir_fd=dpfd)
                    try:
                        rename_flags(dpfd, bound, dpfd, dleaf, 2); exchanged = False
                        ensure_regular_bytes(rollback, dpfd, dleaf)
                    finally: os.close(rollback)
                raise
            finally: os.close(sfd); os.close(dfd)
            try:
                current = os.stat(sleaf, dir_fd=spfd, follow_symlinks=False)
                if object_id(source_id) == object_id(current):
                    os.unlink(sleaf, dir_fd=spfd); os.fsync(spfd)
            except FileNotFoundError: pass
        finally:
            for entry in (bound, saved_bound, concurrent_saved):
                if not entry: continue
                try: os.unlink(entry, dir_fd=dpfd)
                except FileNotFoundError: pass
            if lockfd is not None:
                if locked:
                    try:
                        if object_id(os.stat(lockleaf, dir_fd=dpfd, follow_symlinks=False)) == lock_id:
                            os.unlink(lockleaf, dir_fd=dpfd); os.fsync(dpfd)
                    except FileNotFoundError: pass
                    fcntl.flock(lockfd, fcntl.LOCK_UN)
                os.close(lockfd)
            os.close(spfd); os.close(dpfd)
        return
    if command == "link-exclusive":
        source = argv[2]; destination = argv[3]
        if not os.path.isabs(source): raise ValueError("absolute source required")
        spfd, sleaf = parent(source, False); dpfd, dleaf = parent(destination, False)
        try:
            verify_dir(spfd, True); verify_dir(dpfd, True)
            sfd = os.open(sleaf, os.O_RDONLY | NOFOLLOW, dir_fd=spfd)
            try:
                before = os.fstat(sfd)
                if not stat.S_ISREG(before.st_mode) or before.st_uid != UID:
                    raise ValueError("source must be owned regular file")
                if os.environ.get("POLYLANE_FS_TEST_SOURCE_SWAP") == "1":
                    os.rename(sleaf, sleaf + ".swapped", src_dir_fd=spfd, dst_dir_fd=spfd)
                    replacement = os.open(sleaf, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW,
                                          0o400, dir_fd=spfd)
                    os.write(replacement, b"swapped\n"); os.close(replacement); os.fsync(spfd)
                os.link(sleaf, dleaf, src_dir_fd=spfd, dst_dir_fd=dpfd, follow_symlinks=False)
                dfd = os.open(dleaf, os.O_RDONLY | NOFOLLOW, dir_fd=dpfd)
                try: after = os.fstat(dfd)
                finally: os.close(dfd)
                if (before.st_dev, before.st_ino) != (after.st_dev, after.st_ino):
                    os.unlink(dleaf, dir_fd=dpfd); os.fsync(dpfd)
                    raise ValueError("source changed during publication")
                os.fsync(dpfd)
            finally: os.close(sfd)
        finally: os.close(spfd); os.close(dpfd)
        return
    if command == "rename-exclusive-dir":
        source = argv[2]; destination = argv[3]
        spfd, sleaf = parent(source, False); dpfd, dleaf = parent(destination, False)
        try:
            verify_dir(spfd, True); verify_dir(dpfd, True)
            sfd = os.open(sleaf, os.O_RDONLY | DIRECTORY | NOFOLLOW, dir_fd=spfd)
            try:
                before = os.fstat(sfd)
                if before.st_uid != UID: raise ValueError("source directory not owned")
                if os.environ.get("POLYLANE_FS_TEST_DIR_SOURCE_SWAP") == "1":
                    os.rename(sleaf, sleaf + ".swapped", src_dir_fd=spfd, dst_dir_fd=spfd)
                    os.mkdir(sleaf, 0o700, dir_fd=spfd); os.fsync(spfd)
                libc = ctypes.CDLL(None, use_errno=True)
                system = platform.system()
                old = ctypes.c_char_p(os.fsencode(sleaf)); new = ctypes.c_char_p(os.fsencode(dleaf))
                current = os.stat(sleaf, dir_fd=spfd, follow_symlinks=False)
                if (before.st_dev, before.st_ino) != (current.st_dev, current.st_ino):
                    raise ValueError("directory source changed before publication")
                if system == "Linux" and hasattr(libc, "renameat2"):
                    rc = libc.renameat2(spfd, old, dpfd, new, 1)  # RENAME_NOREPLACE
                elif system == "Darwin" and hasattr(libc, "renameatx_np"):
                    rc = libc.renameatx_np(spfd, old, dpfd, new, 0x00000004)  # RENAME_EXCL
                else:
                    raise ValueError("exclusive directory rename unavailable")
                if rc != 0:
                    err = ctypes.get_errno()
                    raise OSError(err, os.strerror(err), destination)
                os.fsync(spfd); os.fsync(dpfd)
                try:
                    dfd = os.open(dleaf, os.O_RDONLY | DIRECTORY | NOFOLLOW, dir_fd=dpfd)
                    try: after = os.fstat(dfd)
                    finally: os.close(dfd)
                    if (before.st_dev, before.st_ino) != (after.st_dev, after.st_ino) or \
                       os.environ.get("POLYLANE_FS_TEST_DIR_POST_MISMATCH") == "1":
                        raise ValueError("published directory identity mismatch")
                except Exception:
                    while True:
                        quarantine = f".{dleaf}.rejected-{os.getpid()}-{os.urandom(8).hex()}"
                        qnew = ctypes.c_char_p(os.fsencode(quarantine))
                        if system == "Linux":
                            qrc = libc.renameat2(dpfd, new, dpfd, qnew, 1)
                        else:
                            qrc = libc.renameatx_np(dpfd, new, dpfd, qnew, 0x00000004)
                        if qrc == 0: break
                        qerr = ctypes.get_errno()
                        if qerr == errno.ENOENT: break
                        if qerr in (errno.EEXIST, errno.ENOTEMPTY): continue
                        raise OSError(qerr, os.strerror(qerr), destination)
                    os.fsync(dpfd)
                    raise
            finally: os.close(sfd)
        finally: os.close(spfd); os.close(dpfd)
        return
    if command == "unlink-private":
        pfd, leaf = parent(path, False)
        try:
            verify_dir(pfd, True)
            fd = os.open(leaf, os.O_RDONLY | NOFOLLOW, dir_fd=pfd)
            try:
                if not stat.S_ISREG(os.fstat(fd).st_mode): raise ValueError("private is not regular")
            finally: os.close(fd)
            os.unlink(leaf, dir_fd=pfd); os.fsync(pfd)
        finally: os.close(pfd)
        return
    raise ValueError("unknown command")

try:
    main(sys.argv)
except (OSError, ValueError, IndexError) as exc:
    print(f"polylane-fs: {exc}", file=sys.stderr)
    raise SystemExit(7)
```

Run: `chmod +x core/scripts/polylane-fs.py && python3 -m py_compile core/scripts/polylane-fs.py`.

Create `core/scripts/polylane-agent.sh` with these exact decisions:

```bash
#!/usr/bin/env bash
POLYLANE_CONTRACT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
POLYLANE_FS_HELPER="$POLYLANE_CONTRACT_DIR/polylane-fs.py"
polylane_fs() {
  [ -f "$POLYLANE_FS_HELPER" ] && [ ! -L "$POLYLANE_FS_HELPER" ] || return 7
  command -v python3 >/dev/null 2>&1 || return 7
  python3 "$POLYLANE_FS_HELPER" "$@"
}
polylane_safe_mkdirs() { polylane_fs mkdirs "$1" "${2:-0700}"; }
polylane_safe_mkdir_exclusive() { polylane_fs mkdir-exclusive "$1" "${2:-0700}"; }
polylane_private_from_stdin() { polylane_fs create "$1" "${2:-0600}"; }
polylane_publish_private() {
  local private=$1 public=$2
  polylane_fs link-exclusive "$private" "$public" || return 7
  polylane_fs unlink-private "$private" || return 7
  [ -f "$public" ] && [ ! -L "$public" ]
}
polylane_agent_from_manifest() {
  [ -z "${POLYLANE_AGENT:-}" ] || { printf '%s' "$POLYLANE_AGENT"; return; }
  local selected
  selected=$(jq -er '.agent | select(type=="string" and length>0)' "$1" 2>/dev/null) || return 2
  printf '%s' "$selected"
}
polylane_agent_cli() {
  case "$1" in
    claude) canonical=claude ;;
    codex|gpt|openai) canonical=codex ;;
    aider) canonical=aider ;;
    *) return 2 ;;
  esac
  [ -z "${POLYLANE_AGENT_CMD:-}" ] || { printf custom; return; }
  printf '%s' "$canonical"
}
polylane_agent_template() {
  case "$1" in claude|codex|gpt|openai|aider) : ;; *) return 2 ;; esac
  [ -z "${POLYLANE_AGENT_CMD:-}" ] || { printf '%s' "$POLYLANE_AGENT_CMD"; return; }
  case "$1" in aider)
    printf '%s' 'aider --model {model} --message-file {prompt} --yes-always --no-auto-commits'
    return ;;
  esac
  type polylane_adapter_template >/dev/null 2>&1 || return 2
  polylane_adapter_template "$1"
}
polylane_agent_shell() {
  local shell
  case "$1" in claude|codex|gpt|openai|aider) : ;; *) return 2 ;; esac
  if type polylane_adapter_shell >/dev/null 2>&1; then
    polylane_adapter_shell "$1" && return
  fi
  # The only adapter-less built-in is aider; never discover its shell through PATH.
  [ "$1" = aider ] || return 2
  shell="$(cd /bin && pwd -P)/bash"
  [ -f "$shell" ] && [ ! -L "$shell" ] && [ -x "$shell" ] || return 2
  printf '%s\n' "$shell"
}
polylane_agent_processes() {
  [ "$1" != aider ] || { printf 'aider python python3'; return; }
  type polylane_adapter_processes >/dev/null 2>&1 || return 2
  polylane_adapter_processes "$1"
}
polylane_agent_error_class() {
  local agent=$1 artifact=$2
  [ "$agent" != aider ] || { printf none; return; }
  type polylane_adapter_error_class >/dev/null 2>&1 || return 2
  polylane_adapter_error_class "$agent" "$artifact"
}
```

Run: `bash -n core/scripts/polylane-agent.sh`

Expected: exit 0; the shared contract contains no side effect at source time.

- [ ] **Step 7: Add the complete bounded Codex model resolver (5 minutes)**

Create executable `codex/scripts/polylane-codex-model.sh`:

```bash
#!/usr/bin/env bash
set -u

config_file() { printf '%s/config.toml' "${CODEX_HOME:-$HOME/.codex}"; }

top_level_string() {
  local key=$1 file=$2
  [ -f "$file" ] || return 1
  awk -v want="$key" '
    /^[[:space:]]*\[/ { exit }
    {
      line=$0
      sub(/^[[:space:]]*/, "", line)
      if (line !~ "^" want "[[:space:]]*=") next
      sub(/^[^=]*=[[:space:]]*/, "", line)
      if (substr(line,1,1) != "\"") exit
      line=substr(line,2)
      end=index(line,"\"")
      if (end > 0) print substr(line,1,end-1)
      exit
    }
  ' "$file"
}

valid_model() {
  [ -n "$1" ] || return 1
  [ "$1" = "$(printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177')" ] || return 1
  LC_ALL=C printf '%s\n' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._:/-]*$'
}

valid_effort() { case "$1" in low|medium|high|xhigh) return 0 ;; *) return 1 ;; esac; }

resolve_model() {
  local candidate=${1:-}
  if [ -z "$candidate" ]; then candidate=${POLYLANE_CODEX_MODEL:-}; fi
  if [ -z "$candidate" ]; then candidate=$(top_level_string model "$(config_file)" || true); fi
  [ -n "$candidate" ] || return 4
  valid_model "$candidate" || return 2
  printf '%s\n' "$candidate"
}

resolve_effort() {
  local candidate=${1:-} fallback=${2:-}
  if [ -z "$candidate" ]; then candidate=${POLYLANE_CODEX_EFFORT:-}; fi
  if [ -z "$candidate" ]; then
    candidate=$(top_level_string model_reasoning_effort "$(config_file)" || true)
  fi
  if [ -z "$candidate" ]; then candidate=$fallback; fi
  [ -n "$candidate" ] || return 4
  valid_effort "$candidate" || return 2
  printf '%s\n' "$candidate"
}

case "${1:-}" in
  resolve-model) shift; resolve_model "${1:-}" ;;
  resolve-effort) shift; resolve_effort "${1:-}" "${2:-}" ;;
  *) echo "usage: polylane-codex-model.sh resolve-model [id] | resolve-effort [effort] [default]" >&2; exit 2 ;;
esac
```

Run: `chmod +x codex/scripts/polylane-codex-model.sh`

Expected: `bash -n codex/scripts/polylane-codex-model.sh` exits 0.

- [ ] **Step 8: Add the complete initial Codex adapter (4 minutes)**

Create `codex/scripts/polylane-codex-agent.sh`:

```bash
#!/usr/bin/env bash
POLYLANE_CODEX_ADAPTER_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
if [ -f "$POLYLANE_CODEX_ADAPTER_DIR/polylane-fs.py" ] && \
   [ ! -L "$POLYLANE_CODEX_ADAPTER_DIR/polylane-fs.py" ]; then
  # Installed packages flatten shared and adapter scripts into one sealed directory.
  POLYLANE_CODEX_FS_HELPER="$POLYLANE_CODEX_ADAPTER_DIR/polylane-fs.py"
else
  source_helper="$POLYLANE_CODEX_ADAPTER_DIR/../../core/scripts/polylane-fs.py"
  source_parent=$(cd "$(dirname "$source_helper")" 2>/dev/null && pwd -P) || source_parent=
  POLYLANE_CODEX_FS_HELPER="$source_parent/${source_helper##*/}"
fi
polylane_codex_fs() {
  [ -f "$POLYLANE_CODEX_FS_HELPER" ] && [ ! -L "$POLYLANE_CODEX_FS_HELPER" ] || return 7
  python3 "$POLYLANE_CODEX_FS_HELPER" "$@"
}
polylane_codex_safe_mkdirs() { polylane_codex_fs mkdirs "$1" "${2:-0700}"; }
polylane_codex_private_from_stdin() { polylane_codex_fs create "$1" "${2:-0600}"; }
polylane_codex_capture_dependencies() {
  local dependency
  for dependency in awk basename chmod cp date dirname grep head jq ln mkdir od \
    python3 readlink rm sleep stat tr uname wc; do
    command -v "$dependency" >/dev/null 2>&1 || return 2
  done
  command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1
}
polylane_codex_resolve_path() {
  local path=$1 target parent i=0
  polylane_codex_capture_dependencies || return 2
  case "$path" in /*) : ;; *) return 2 ;; esac
  while [ -L "$path" ] && [ "$i" -lt 40 ]; do
    target=$(readlink "$path") || return 2
    case "$target" in /*) path=$target ;; *) path="$(dirname "$path")/$target" ;; esac
    i=$((i+1))
  done
  [ "$i" -lt 40 ] && [ -f "$path" ] && [ ! -L "$path" ] && [ -x "$path" ] || return 2
  parent=$(cd "$(dirname "$path")" && pwd -P) || return 2
  printf '%s/%s\n' "$parent" "$(basename "$path")"
}
polylane_codex_command_path() {
  local path
  path=$(command -v "$1" 2>/dev/null) || return 2
  case "$path" in /*) printf '%s\n' "$path" ;; *) return 2 ;; esac
}
polylane_codex_resolve_executable() {
  polylane_codex_resolve_path "$(polylane_codex_command_path codex)"
}
polylane_codex_trusted_shell() { polylane_codex_resolve_path /bin/bash; }
polylane_codex_mode_of() {
  case "$(uname -s)" in Linux) stat -c '%a' "$1" ;; *) stat -f '%Lp' "$1" ;; esac
}
polylane_codex_device_of() {
  case "$(uname -s)" in Linux) stat -c '%d' "$1" ;; *) stat -f '%d' "$1" ;; esac
}
polylane_codex_inode_of() {
  case "$(uname -s)" in Linux) stat -c '%i' "$1" ;; *) stat -f '%i' "$1" ;; esac
}
polylane_codex_identity_fields() {
  local path=$1
  [ -f "$path" ] && [ ! -L "$path" ] && [ -x "$path" ] || return 2
  printf '%s %s %s %s\n' "$(polylane_codex_device_of "$path")" \
    "$(polylane_codex_inode_of "$path")" "$(polylane_codex_mode_of "$path")" \
    "$(polylane_codex_sha256 "$path")"
}
polylane_codex_detect_launch() {
  local executable=$1 launcher=$2 first magic requested sibling
  IFS= read -r first < "$executable" || [ -n "$first" ] || return 2
  POLYLANE_BIND_KIND=; POLYLANE_BIND_INTERPRETER=
  case "$first" in
    '#!/usr/bin/env node')
      POLYLANE_BIND_KIND=script
      # `env node` is never replayed. Bind only the `node` installed beside the
      # discovered Codex launcher; an arbitrary earlier PATH entry is not trusted.
      sibling="$(dirname "$launcher")/node"
      POLYLANE_BIND_INTERPRETER=$(polylane_codex_resolve_path "$sibling") || return 2 ;;
    '#!'/*)
      requested=${first#\#!}
      case "$requested" in *[[:space:]]*) return 2 ;; esac
      POLYLANE_BIND_KIND=script
      POLYLANE_BIND_INTERPRETER=$(polylane_codex_resolve_path "$requested") || return 2 ;;
    '#!'*) return 2 ;;
    *)
      magic=$(head -c 4 "$executable" | od -An -tx1 | tr -d ' \n')
      case "$magic" in 7f454c46|feedface|feedfacf|cefaedfe|cffaedfe|cafebabe|bebafeca|cafebabf|bfbafeca)
        POLYLANE_BIND_KIND=native ;;
        *) return 2 ;;
      esac ;;
  esac
}
polylane_adapter_cli() { [ "$1" = codex ] || return 2; polylane_codex_resolve_executable; }
polylane_adapter_shell() {
  case "$1" in codex|gpt|openai) polylane_codex_trusted_shell ;; *) return 2 ;; esac
}
polylane_adapter_template() {
  case "$1" in codex|gpt|openai)
    local adapter_dir wrapper launcher executable shell
    local shell_dev shell_ino shell_mode shell_hash wrapper_dev wrapper_ino wrapper_mode wrapper_hash
    local exec_dev exec_ino exec_mode exec_hash int_dev int_ino int_mode int_hash int_id
    adapter_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    wrapper="$adapter_dir/polylane-codex-exec.sh"
    launcher=$(polylane_codex_command_path codex) || return 2
    executable=$(polylane_codex_resolve_path "$launcher") || return 2
    shell=$(polylane_codex_trusted_shell) || return 2
    polylane_codex_detect_launch "$executable" "$launcher" || return 2
    read -r shell_dev shell_ino shell_mode shell_hash \
      <<<"$(polylane_codex_identity_fields "$shell")" || return 2
    read -r wrapper_dev wrapper_ino wrapper_mode wrapper_hash \
      <<<"$(polylane_codex_identity_fields "$wrapper")" || return 2
    read -r exec_dev exec_ino exec_mode exec_hash \
      <<<"$(polylane_codex_identity_fields "$executable")" || return 2
    int_dev=; int_ino=; int_mode=; int_hash=; int_id=
    if [ "$POLYLANE_BIND_KIND" = script ]; then
      read -r int_dev int_ino int_mode int_hash \
        <<<"$(polylane_codex_identity_fields "$POLYLANE_BIND_INTERPRETER")" || return 2
      int_id="$int_dev:$int_ino:$int_mode:$int_hash"
    fi
    printf '%s' "POLYLANE_CODEX_LAUNCH_KIND=$(printf '%q' "$POLYLANE_BIND_KIND") "
    printf '%s' "POLYLANE_CODEX_INTERPRETER=$(printf '%q' "$POLYLANE_BIND_INTERPRETER") "
    printf '%s' "POLYLANE_CODEX_INTERPRETER_ID=$(printf '%q' "$int_id") "
    printf '%s' "POLYLANE_CODEX_EXEC_ID=$(printf '%q' "$exec_dev:$exec_ino:$exec_mode:$exec_hash") "
    printf '%s' "POLYLANE_CODEX_WRAPPER_ID=$(printf '%q' "$wrapper_dev:$wrapper_ino:$wrapper_mode:$wrapper_hash") "
    printf '%s' "POLYLANE_CODEX_BASH=$(printf '%q' "$shell") "
    printf '%s' "POLYLANE_CODEX_BASH_ID=$(printf '%q' "$shell_dev:$shell_ino:$shell_mode:$shell_hash") "
    printf 'exec %q %q %q %s' "$shell" "$wrapper" "$executable" \
      '{model} {effort} {prompt} {error_artifact}' ;;
    *) return 2 ;; esac
}
polylane_adapter_processes() { printf 'codex node'; }
polylane_adapter_effort() {
  case "$1" in default|economy) printf medium ;; balanced|performance) printf high ;;
    max) printf xhigh ;; *) return 2 ;; esac
}
polylane_codex_sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'; fi
}
polylane_codex_publish() {
  local tmp=$1 dest=$2 expected
  [ -f "$tmp" ] && [ ! -L "$tmp" ] && [ ! -e "$dest" ] && [ ! -L "$dest" ] || return 7
  expected=$(polylane_codex_sha256 "$tmp") || return 7
  polylane_codex_fs link-exclusive "$tmp" "$dest" || return 7
  polylane_codex_fs unlink-private "$tmp" || return 7
  [ -f "$dest" ] && [ ! -L "$dest" ] && \
    [ "$(polylane_codex_sha256 "$dest")" = "$expected" ]
}
polylane_adapter_error_class() {
  # Codex-owned anchored pattern table; core never contains Codex or Claude messages.
  # Return exactly none, transient, rate_limit, invalid_model, or user_action.
  printf none
}
polylane_codex_result_extension_json() {
  # Builder replaces this hook with a validated object containing prompt/actor
  # bindings. Foundation calls it for every normal and transport terminal result.
  printf '{}\n'
}
polylane_codex_build_normal_result() {
  local events=$1 stderr_file=$2 private=$3 process_rc=$4 terminal terminal_type
  local raw payload status error_type code message kind extension events_hash stderr_hash
  [ -f "$events" ] && [ ! -L "$events" ] && [ -f "$stderr_file" ] && \
    [ ! -L "$stderr_file" ] && [ ! -e "$private" ] && [ ! -L "$private" ] || return 7
  terminal=$(jq -cs '
    select(length>1 and .[0].type=="thread.started" and
      ([.[]|select(.type=="thread.started")]|length)==1 and
      all(.[]; type=="object" and (.type|type)=="string")) |
    [to_entries[]|select(.value.type=="turn.completed" or .value.type=="turn.failed")] as $terminal |
    select(($terminal|length)==1 and $terminal[0].key==(length-1)) | $terminal[0].value' \
    "$events" 2>/dev/null) || return 7
  [ -n "$terminal" ] || return 7
  terminal_type=$(printf '%s' "$terminal" | jq -r .type)
  kind=none; status=0; error_type=""; code=""
  case "$terminal_type:$process_rc" in turn.completed:0) : ;; turn.failed:0|turn.completed:*) return 7 ;;
    turn.failed:*)
      raw=$(printf '%s' "$terminal" | jq -er '.error.message | select(type=="string")') || return 7
      # `item.completed` errors are diagnostics and may be unrelated (for example model
      # metadata or context-budget warnings). Only the last top-level structured error,
      # when present, must agree with the final `turn.failed` payload.
      jq -es --arg raw "$raw" '
        [.[0:-1][] | select(.type=="error") | .message |
          select(type=="string")] as $errors |
        (($errors|length)==0 or $errors[-1]==$raw)' "$events" >/dev/null || return 7
      payload=$(printf '%s' "$raw" | jq -ce 'fromjson | select(type=="object")' 2>/dev/null) || return 7
      status=$(printf '%s' "$payload" | jq -r \
        '(.status // .error.status // 0) | select(type=="number" and .>=0 and .==floor)') || return 7
      error_type=$(printf '%s' "$payload" | jq -r '.error.type // .type // ""')
      code=$(printf '%s' "$payload" | jq -r '.error.code // .code // ""')
      message=$(printf '%s' "$payload" | jq -r '.error.message // .message // "" | select(type=="string")') || return 7
      kind=unknown
      case "$status:$error_type:$code" in
        401:*|403:*|*:authentication_error:*|*:permission_denied:*|*:*:invalid_api_key|*:*:not_logged_in|*:*:account_disabled) kind=user_action ;;
        *:*:model_not_found|*:*:invalid_model|*:*:unsupported_model) kind=invalid_model ;;
        429:*|*:rate_limit_error:*|*:*:rate_limit_exceeded|*:*:insufficient_quota) kind=rate_limit ;;
        5??:*|*:server_error:*|*:api_error:*|*:upstream_error:*|*:*:service_unavailable) kind=transient ;;
      esac ;;
    *) return 7 ;;
  esac
  if [ "$kind" = unknown ]; then
    if [ "$status" = 400 ] && [ "$error_type" = invalid_request_error ] && [ -z "$code" ] && \
      printf '%s\n' "$message" | LC_ALL=C grep -Eqi \
        "^the ('[A-Za-z0-9._:/-]+' model|model [A-Za-z0-9._:/-]+) is not supported (when using Codex with a ChatGPT account|for this account)[.]?$"; then
      kind=invalid_model
    elif [ "$status" = 429 ] && printf '%s\n' "$message" | LC_ALL=C grep -Eqi \
      '^(too many requests|rate limit (exceeded|reached))([.:; ].*)?$'; then
      kind=rate_limit
    elif { [ "$status" = 0 ] || [ "$status" -ge 500 ]; } && \
      printf '%s\n' "$message" | LC_ALL=C grep -Eqi \
        '^(error sending request for url|connection (reset|refused)|request timed out|network error)([:. ].*)?$'; then
      kind=transient
    fi
  fi
  events_hash="sha256:$(polylane_codex_sha256 "$events")" || return 7
  stderr_hash="sha256:$(polylane_codex_sha256 "$stderr_file")" || return 7
  polylane_codex_safe_mkdirs "$(dirname "$private")" 0700; [ -d "$(dirname "$private")" ] && \
    [ ! -L "$(dirname "$private")" ] || return 7
  extension=$(polylane_codex_result_extension_json) || return 7
  printf '%s' "$extension" | jq -e 'type=="object"' >/dev/null || return 7
  ( set -o pipefail; jq -nS --arg kind "$kind" --arg code "$code" --arg error_type "$error_type" \
    --arg terminal_type "$terminal_type" --arg events_hash "$events_hash" \
    --arg events_path "$events" --arg stderr_path "$stderr_file" --arg stderr_hash "$stderr_hash" \
    --argjson status "$status" --argjson process_exit "$process_rc" --argjson extension "$extension" \
    '({schema_version:2,provider:"codex",kind:$kind,code:$code,status:$status,
      error_type:$error_type,terminal_type:$terminal_type,process_exit:$process_exit,
      events_path:$events_path,events_hash:$events_hash,
      stderr_path:$stderr_path,stderr_hash:$stderr_hash}) as $base |
      ($extension|keys) as $keys |
      select(all($keys[]; . as $key | ($base|has($key)|not))) |
      $base + $extension' | polylane_codex_private_from_stdin "$private" 0400 ) || {
        [ ! -e "$private" ] || polylane_codex_fs unlink-private "$private"
        return 7
      }
  [ "$(polylane_codex_mode_of "$private")" = 400 ]
}

polylane_codex_build_transport_result() {
  local events=$1 stderr_file=$2 private=$3 process_rc=$4 code=$5 extension
  [ -f "$events" ] && [ ! -L "$events" ] && [ -f "$stderr_file" ] && \
    [ ! -L "$stderr_file" ] && [ ! -e "$private" ] && [ ! -L "$private" ] || return 7
  polylane_codex_safe_mkdirs "$(dirname "$private")" 0700; [ -d "$(dirname "$private")" ] && \
    [ ! -L "$(dirname "$private")" ] || return 7
  extension=$(polylane_codex_result_extension_json) || return 7
  printf '%s' "$extension" | jq -e 'type=="object"' >/dev/null || return 7
  ( set -o pipefail; jq -nS --arg code "$code" --arg events_path "$events" \
    --arg events_hash "sha256:$(polylane_codex_sha256 "$events")" \
    --arg stderr_path "$stderr_file" \
    --arg stderr_hash "sha256:$(polylane_codex_sha256 "$stderr_file")" \
    --argjson process_exit "$process_rc" --argjson extension "$extension" \
    '({schema_version:2,provider:"codex",kind:"transient",code:$code,status:0,
      error_type:"capture_error",terminal_type:"capture.failed",process_exit:$process_exit,
      events_path:$events_path,events_hash:$events_hash,
      stderr_path:$stderr_path,stderr_hash:$stderr_hash}) as $base |
      ($extension|keys) as $keys |
      select(all($keys[]; . as $key | ($base|has($key)|not))) |
      $base + $extension' | polylane_codex_private_from_stdin "$private" 0400 ) || {
        [ ! -e "$private" ] || polylane_codex_fs unlink-private "$private"
        return 7
      }
  [ "$(polylane_codex_mode_of "$private")" = 400 ]
}
polylane_codex_publish_result() {
  local private=$1 artifact=$2
  [ -f "$private" ] && [ ! -L "$private" ] && [ ! -e "$artifact" ] && \
    [ ! -L "$artifact" ] || return 7
  polylane_codex_publish "$private" "$artifact"
}
# Public compatibility entry points retain the adapter ABI, but both now build one
# complete private payload and perform one exclusive publication at the very end.
polylane_adapter_capture_error() {
  local events=$1 stderr_file=$2 artifact=$3 process_rc=$4 private="$3.private.$$"
  polylane_codex_build_normal_result "$events" "$stderr_file" "$private" "$process_rc" || return 7
  polylane_codex_publish_result "$private" "$artifact"
}
polylane_codex_capture_transport_failure() {
  local events=$1 stderr_file=$2 artifact=$3 process_rc=$4 code=$5 private="$3.private.$$"
  polylane_codex_build_transport_result "$events" "$stderr_file" "$private" "$process_rc" "$code" || return 7
  polylane_codex_publish_result "$private" "$artifact"
}
```

Create executable `codex/scripts/polylane-codex-exec.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
case "$0" in */*) script_parent=${0%/*} ;; *) script_parent=. ;; esac
SCRIPT_DIR=$(cd "$script_parent" && pwd -P)
# Resolved beside this installed wrapper.
# shellcheck disable=SC1091
. "$SCRIPT_DIR/polylane-codex-agent.sh"
[ $# = 5 ] || { echo "usage: polylane-codex-exec.sh CODEX_EXE MODEL EFFORT PROMPT ERROR_ARTIFACT" >&2; exit 2; }
codex_exe=$1; model=$2; effort=$3; prompt=$4; artifact=$5
[ -x "$codex_exe" ] && [ -f "$codex_exe" ] && [ ! -L "$codex_exe" ] || exit 2
exe_dir=${codex_exe%/*}; exe_base=${codex_exe##*/}
[ "$(cd "$exe_dir" && pwd -P)/$exe_base" = "$codex_exe" ] || exit 2
polylane_codex_capture_dependencies || {
  echo "polylane-codex-exec: missing bounded-capture dependency" >&2; exit 2;
}
identity_token() {
  local path=$1 dev ino mode hash
  read -r dev ino mode hash <<<"$(polylane_codex_identity_fields "$path")" || return 1
  printf '%s:%s:%s:%s\n' "$dev" "$ino" "$mode" "$hash"
}
launch_identity_valid() {
  [ -n "${POLYLANE_CODEX_BASH:-}" ] && [ "$BASH" = "$POLYLANE_CODEX_BASH" ] && \
    [ "$(identity_token "$POLYLANE_CODEX_BASH")" = "${POLYLANE_CODEX_BASH_ID:-}" ] && \
    [ "$(identity_token "$0")" = "${POLYLANE_CODEX_WRAPPER_ID:-}" ] && \
    [ "$(identity_token "$codex_exe")" = "${POLYLANE_CODEX_EXEC_ID:-}" ] || return 1
  case "${POLYLANE_CODEX_LAUNCH_KIND:-}" in
    native) [ -z "${POLYLANE_CODEX_INTERPRETER:-}" ] && \
      [ -z "${POLYLANE_CODEX_INTERPRETER_ID:-}" ] ;;
    script) [ -n "${POLYLANE_CODEX_INTERPRETER:-}" ] && \
      [ "$(identity_token "$POLYLANE_CODEX_INTERPRETER")" = \
        "${POLYLANE_CODEX_INTERPRETER_ID:-}" ] ;;
    *) return 1 ;;
  esac
}
event_cap=${POLYLANE_CODEX_MAX_EVENT_BYTES:-16777216}
stderr_cap=${POLYLANE_CODEX_MAX_STDERR_BYTES:-4194304}
parser_timeout=${POLYLANE_CODEX_PARSER_TIMEOUT:-10}
bounded_uint() {
  local value=$1 max=$2 digits=$3
  case "$value" in ''|*[!0-9]*) return 1 ;; esac
  [ "${#value}" -le "$digits" ] && [ "$value" -ge 1 ] && [ "$value" -le "$max" ]
}
bounded_uint "$event_cap" 67108864 8 && bounded_uint "$stderr_cap" 16777216 8 && \
  bounded_uint "$parser_timeout" 60 2 || {
    echo "polylane-codex-exec: unsafe capture bound" >&2; exit 2;
  }
events="$artifact.events.jsonl"; stderr_file="$artifact.stderr"
result_private="$artifact.private.$$"
prompt_snapshot="$artifact.prompt.$$"
artifact_dir=${artifact%/*}; [ "$artifact_dir" != "$artifact" ] || artifact_dir=.
polylane_codex_safe_mkdirs "$artifact_dir" 0700
[ -d "$artifact_dir" ] && [ ! -L "$artifact_dir" ] || \
  { echo "polylane-codex-exec: unsafe artifact directory" >&2; exit 2; }
[ -f "$prompt" ] && [ ! -L "$prompt" ] || \
  { echo "polylane-codex-exec: unsafe prompt path" >&2; exit 2; }
for path in "$artifact" "$events" "$stderr_file" "$result_private" "$prompt_snapshot"; do
  [ ! -e "$path" ] && [ ! -L "$path" ] || \
    { echo "polylane-codex-exec: artifact path already exists" >&2; exit 2; }
done
inode_of() { case "$(uname -s)" in Linux) stat -c '%i' "$1" ;; *) stat -f '%i' "$1" ;; esac; }
polylane_codex_fs copy-exclusive "$prompt" "$prompt_snapshot" 0400 || exit 2
prompt_snapshot_created=1
exec 5< "$prompt_snapshot"
[ -f "$prompt_snapshot" ] && [ ! -L "$prompt_snapshot" ] && \
  [ "$(inode_of "$prompt_snapshot")" = "$(inode_of /dev/fd/5)" ] || exit 2
out_fifo="$artifact.stdout-fifo.$$"; err_fifo="$artifact.stderr-fifo.$$"
out_fifo_created=0; err_fifo_created=0
capture_cleanup() {
  if [ "$out_fifo_created" = 1 ] && [ -p "$out_fifo" ] && [ ! -L "$out_fifo" ]; then
    polylane_codex_fs unlink-fifo "$out_fifo" || true
  fi
  if [ "$err_fifo_created" = 1 ] && [ -p "$err_fifo" ] && [ ! -L "$err_fifo" ]; then
    polylane_codex_fs unlink-fifo "$err_fifo" || true
  fi
  if [ "${prompt_snapshot_created:-0}" = 1 ] && [ -f "$prompt_snapshot" ] && \
    [ ! -L "$prompt_snapshot" ]; then
    polylane_codex_fs unlink-private "$prompt_snapshot" || true
  fi
}
trap capture_cleanup EXIT INT TERM
[ ! -e "$out_fifo" ] && [ ! -L "$out_fifo" ] && \
  polylane_codex_fs mkfifo-exclusive "$out_fifo" 0600 || exit 2
out_fifo_created=1
[ ! -e "$err_fifo" ] && [ ! -L "$err_fifo" ] && \
  polylane_codex_fs mkfifo-exclusive "$err_fifo" 0600 || exit 2
err_fifo_created=1
polylane_codex_private_from_stdin "$events" 0600 </dev/null || exit 2
polylane_codex_private_from_stdin "$stderr_file" 0600 </dev/null || {
  polylane_codex_fs unlink-private "$events"; exit 2;
}
if ! launch_identity_valid; then
  exec 5>&-
  capture_cleanup; trap - EXIT INT TERM
  polylane_codex_fs chmod-existing "$events" 0400
  polylane_codex_fs chmod-existing "$stderr_file" 0400
  polylane_codex_build_transport_result "$events" "$stderr_file" "$result_private" 74 \
    launch_identity_changed && polylane_codex_publish_result "$result_private" "$artifact" || exit 74
  exit 74
fi
# BSD and GNU head both implement byte-count `-c`. Reading cap+1 gives one bounded
# overflow sentinel, closes the FIFO, and fences a producer that continues writing.
head -c "$((event_cap + 1))" < "$out_fifo" | \
  polylane_codex_fs tee-existing "$events" >&1 & out_drain=$!
head -c "$((stderr_cap + 1))" < "$err_fifo" | \
  polylane_codex_fs tee-existing "$stderr_file" >&2 & err_drain=$!
set +e
case "$POLYLANE_CODEX_LAUNCH_KIND" in
  script) "$POLYLANE_CODEX_INTERPRETER" "$codex_exe" exec --json \
    --sandbox workspace-write -c approval_policy=never --model "$model" \
    -c model_reasoning_effort="$effort" - <&5 > "$out_fifo" 2> "$err_fifo" ;;
  native) "$codex_exe" exec --json --sandbox workspace-write -c approval_policy=never \
    --model "$model" -c model_reasoning_effort="$effort" - <&5 \
    > "$out_fifo" 2> "$err_fifo" ;;
esac
rc=$?
wait "$out_drain"; out_rc=$?; wait "$err_drain"; err_rc=$?
set -e
exec 5>&-
capture_cleanup; trap - EXIT INT TERM
polylane_codex_fs chmod-existing "$events" 0400
polylane_codex_fs chmod-existing "$stderr_file" 0400
identity_changed=0; launch_identity_valid || identity_changed=1
event_bytes=$(wc -c < "$events" | tr -d '[:space:]')
stderr_bytes=$(wc -c < "$stderr_file" | tr -d '[:space:]')
publish_transport() {
  local code=$1
  polylane_codex_build_transport_result "$events" "$stderr_file" "$result_private" "$rc" \
    "$code" && polylane_codex_publish_result "$result_private" "$artifact"
}
discard_private() {
  [ ! -e "$result_private" ] && [ ! -L "$result_private" ] && return 0
  [ -f "$result_private" ] && [ ! -L "$result_private" ] || return 1
  polylane_codex_fs unlink-private "$result_private" || return 1
  [ ! -e "$result_private" ] && [ ! -L "$result_private" ]
}
if [ "$identity_changed" != 0 ]; then
  publish_transport launch_identity_changed || exit 74
  exit 74
fi
if [ "$event_bytes" -gt "$event_cap" ] || [ "$stderr_bytes" -gt "$stderr_cap" ]; then
  publish_transport capture_limit || exit 74
  exit 74
fi
if [ "$out_rc" != 0 ] || [ "$err_rc" != 0 ]; then
  publish_transport capture_drain_failed || exit 74
  exit 74
fi
set +e
{ [ "${POLYLANE_CODEX_TEST_PARSER_DELAY:-0}" = 0 ] || \
    sleep "$POLYLANE_CODEX_TEST_PARSER_DELAY";
  polylane_codex_build_normal_result "$events" "$stderr_file" "$result_private" "$rc"; } & parser=$!
deadline=$(( $(date +%s) + parser_timeout ))
while kill -0 "$parser" 2>/dev/null && [ "$(date +%s)" -lt "$deadline" ]; do sleep 0.05; done
if kill -0 "$parser" 2>/dev/null; then
  kill "$parser" 2>/dev/null || true; wait "$parser" 2>/dev/null || true
  discard_private || exit 74
  publish_transport parser_timeout || exit 74
  exit 74
fi
wait "$parser"; parser_rc=$?; set -e
if [ "$parser_rc" != 0 ]; then
  discard_private || exit 74
  publish_transport parser_invalid || exit 74
  exit 74
else
  polylane_codex_publish_result "$result_private" "$artifact" || exit 74
fi
exit "$rc"
```

Run: `chmod +x codex/scripts/polylane-codex-exec.sh && bash -n codex/scripts/polylane-codex-agent.sh codex/scripts/polylane-codex-exec.sh`

Expected: exit 0; the wrapper invokes the exact stdin-based `--json` Codex command, tees
stdout JSONL to the pane plus a private event file, leaves stderr unclassified, and publishes
only an atomically validated versioned result artifact for a structurally terminal success or
failure.

- [ ] **Step 9: Add the complete initial Claude adapter and wrappers (5 minutes)**

Create `claude-code/scripts/polylane-claude-agent.sh`:

```bash
#!/usr/bin/env bash
polylane_adapter_cli() { [ "$1" = claude ] || return 2; printf claude; }
polylane_adapter_shell() {
  local shell
  [ "$1" = claude ] || return 2
  shell="$(cd /bin && pwd -P)/bash"
  [ -f "$shell" ] && [ ! -L "$shell" ] && [ -x "$shell" ] || return 2
  printf '%s\n' "$shell"
}
polylane_adapter_template() {
  [ "$1" = claude ] || return 2
  local pmode=${POLYLANE_PERMISSION_MODE:-acceptEdits}
  printf 'claude --permission-mode %s --model {model} "$(cat {prompt})"' \
    "$(printf '%q' "$pmode")"
}
polylane_adapter_processes() { printf 'claude node'; }
polylane_adapter_effort() {
  case "$1" in default) printf '' ;; economy) printf medium ;;
    balanced|performance) printf high ;; max) printf xhigh ;; *) return 2 ;; esac
}
polylane_adapter_error_class() { printf none; }
```

Create `claude-code/scripts/polylane-claude-run.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
export POLYLANE_AGENT=claude
export POLYLANE_AGENT_ADAPTER="$SCRIPT_DIR/polylane-claude-agent.sh"
if [ -x "$SCRIPT_DIR/polylane-run.sh" ]; then CORE_RUN="$SCRIPT_DIR/polylane-run.sh"
else CORE_RUN="$SCRIPT_DIR/../../core/scripts/polylane-run.sh"; fi
exec "$CORE_RUN" "$@"
```

Create `claude-code/scripts/polylane-claude-doctor.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
export POLYLANE_AGENT=claude
export POLYLANE_AGENT_ADAPTER="$SCRIPT_DIR/polylane-claude-agent.sh"
if [ -x "$SCRIPT_DIR/polylane-doctor.sh" ]; then CORE_DOCTOR="$SCRIPT_DIR/polylane-doctor.sh"
else CORE_DOCTOR="$SCRIPT_DIR/../../core/scripts/polylane-doctor.sh"; fi
exec "$CORE_DOCTOR" "$@"
```

Create `claude-code/scripts/polylane-claude-compat.sh`. It resolves its real file even when
invoked through a root symlink, then selects the compatibility adapter itself:

```bash
#!/usr/bin/env bash
set -eu
ENTRY=${0##*/}; SELF=${BASH_SOURCE[0]}
while [ -L "$SELF" ]; do
  target=$(readlink "$SELF")
  case "$target" in /*) SELF=$target ;; *) SELF=$(dirname "$SELF")/$target ;; esac
done
SCRIPT_DIR=$(cd "$(dirname "$SELF")" && pwd -P)
case "$ENTRY" in
  polylane-run.sh|polylane-doctor.sh|polylane-supervisor.sh|polylane-dashboard.sh|\
  polylane-outcomes.sh|polylane-promptlint.sh|polylane-scout.sh) : ;;
  *) echo "polylane-claude-compat: unsupported entrypoint $ENTRY" >&2; exit 2 ;;
esac
export POLYLANE_AGENT=claude
export POLYLANE_AGENT_ADAPTER="$SCRIPT_DIR/polylane-claude-agent.sh"
if [ -x "$SCRIPT_DIR/$ENTRY" ] && [ "$SCRIPT_DIR/$ENTRY" != "$SELF" ]; then
  CORE_ENTRY="$SCRIPT_DIR/$ENTRY"
else
  CORE_ENTRY=$(cd "$SCRIPT_DIR/../../core/scripts" && pwd -P)/$ENTRY
fi
exec "$CORE_ENTRY" "$@"
```

Run:

```bash
chmod +x codex/scripts/polylane-codex-agent.sh \
  codex/scripts/polylane-codex-exec.sh \
  claude-code/scripts/polylane-claude-agent.sh \
  claude-code/scripts/polylane-claude-run.sh \
  claude-code/scripts/polylane-claude-doctor.sh \
  claude-code/scripts/polylane-claude-compat.sh
for helper in polylane-run.sh polylane-doctor.sh polylane-supervisor.sh \
  polylane-dashboard.sh polylane-outcomes.sh polylane-promptlint.sh polylane-scout.sh; do
  rm -f "bin/$helper"
  ln -s ../claude-code/scripts/polylane-claude-compat.sh "bin/$helper"
done
```

Expected: exit 0; every listed root entrypoint resolves the Claude adapter itself without
requiring `POLYLANE_AGENT` or `POLYLANE_AGENT_ADAPTER` from the caller.

- [ ] **Step 10: Patch the runner to validate identity before side effects (5 minutes)**

Make these anchored edits to `core/scripts/polylane-run.sh`:

```diff
diff --git a/core/scripts/polylane-run.sh b/core/scripts/polylane-run.sh
--- a/core/scripts/polylane-run.sh
+++ b/core/scripts/polylane-run.sh
@@
 SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)
+. "$SCRIPT_DIR/polylane-agent.sh"
+if [ -n "${POLYLANE_AGENT_ADAPTER:-}" ]; then
+  [ -f "$POLYLANE_AGENT_ADAPTER" ] || {
+    echo "polylane-run: adapter not found: $POLYLANE_AGENT_ADAPTER" >&2
+    return 2 2>/dev/null || exit 2
+  }
+  . "$POLYLANE_AGENT_ADAPTER"
+fi
@@
 preflight() {
-  local missing=() d
-  for d in tmux claude jq git; do
+  local missing=() d selected cli
+  [ -f "$MANIFEST" ] || { echo "polylane-run: manifest not found: $MANIFEST" >&2; exit 1; }
+  command -v jq >/dev/null 2>&1 || { echo "polylane-run: missing required dependency: jq" >&2; exit 1; }
+  jq empty "$MANIFEST" 2>/dev/null || {
+    echo "polylane-run: manifest is not valid JSON: $MANIFEST" >&2; exit 1;
+  }
+  selected=$(polylane_agent_from_manifest "$MANIFEST")
+  cli=$(polylane_agent_cli "$selected") || {
+    echo "polylane-run: unknown or mismatched agent '$selected'" >&2; exit 2;
+  }
+  AGENT_SHELL=$(polylane_agent_shell "$selected") || {
+    echo "polylane-run: no trusted physical shell for '$selected'" >&2; exit 2;
+  }
+  case "$AGENT_SHELL" in /*) : ;; *) exit 2 ;; esac
+  [ -f "$AGENT_SHELL" ] && [ ! -L "$AGENT_SHELL" ] && [ -x "$AGENT_SHELL" ] || exit 2
+  for d in tmux jq git; do
     command -v "$d" >/dev/null 2>&1 || missing+=("$d")
   done
+  [ "$cli" = custom ] || command -v "$cli" >/dev/null 2>&1 || missing+=("$cli")
@@
-  if [ ! -f "$MANIFEST" ]; then
-    echo "polylane-run: manifest not found: $MANIFEST" >&2
-    exit 1
-  fi
-  if ! jq empty "$MANIFEST" 2>/dev/null; then
-    echo "polylane-run: manifest is not valid JSON: $MANIFEST" >&2
-    exit 1
-  fi
@@
-  AGENT=$(jq -r '.agent // "claude"' "$MANIFEST")
+  AGENT=$(polylane_agent_from_manifest "$MANIFEST")
@@
-  if [ -z "${POLYLANE_AGENT_CMD:-}" ]; then
-    case "$(agent_selected)" in
-      claude|codex|gpt|openai|aider) : ;;
-      *) die "unknown agent '$(agent_selected)' — use claude|codex|gpt|aider, or set POLYLANE_AGENT_CMD with {model} {prompt}" ;;
-    esac
-  fi
+  polylane_agent_cli "$(agent_selected)" >/dev/null ||
+    die "unknown or mismatched agent '$(agent_selected)'"
@@
-agent_template() {
-  if [ -n "${POLYLANE_AGENT_CMD:-}" ]; then printf '%s' "$POLYLANE_AGENT_CMD"; return; fi
-  local pmode="${POLYLANE_PERMISSION_MODE:-acceptEdits}"
-  case "$(agent_selected)" in
-    claude)            printf 'claude --permission-mode %s --model {model} "$(cat {prompt})"' "$(printf '%q' "$pmode")" ;;
-    codex|gpt|openai)  printf 'codex exec --full-auto --model {model} "$(cat {prompt})"' ;;
-    aider)             printf 'aider --model {model} --message-file {prompt} --yes-always --no-auto-commits' ;;
-    *) echo "polylane-run: unknown agent '$(agent_selected)' — set POLYLANE_AGENT_CMD to a template containing {model} and {prompt}" >&2; return 2 ;;
-  esac
-}
+agent_template() { polylane_agent_template "$(agent_selected)"; }
@@
-agent_procs() {
-  case "$(agent_selected)" in
-    claude)            printf 'claude node' ;;
-    codex|gpt|openai)  printf 'codex node' ;;
-    aider)             printf 'aider python python3' ;;
-    *)                 printf 'claude node codex aider python python3  node' ;;
-  esac
-}
+agent_procs() { polylane_agent_processes "$(agent_selected)"; }
+
+session_id_name_matches() {
+  local id=$1
+  [ -n "$id" ] && tmux has-session -t "$id" 2>/dev/null && \
+    [ "$(tmux display-message -p -t "$id" '#{session_id}')" = "$id" ] && \
+    [ "$(tmux display-message -p -t "$id" '#S')" = "$TMUX_SESSION_NAME" ]
+}
+
+owned_session_id_matches() {
+  local id=$1
+  session_id_name_matches "$id" && \
+    [ "$(tmux show-options -qv -t "$id" @polylane_run_id)" = "$RUN_ID" ] && \
+    [ "$(tmux show-options -qv -t "$id" @polylane_loop_id)" = "$LOOP_ID" ] && \
+    [ "$(tmux show-options -qv -t "$id" @polylane_claim_token)" = "$POLYLANE_CLAIM_TOKEN" ] && \
+    [ "$(tmux show-options -qv -t "$id" @polylane_runner_generation)" = \
+      "$POLYLANE_RUNNER_GENERATION" ] && session_id_name_matches "$id"
+}
+
+capture_named_session_id() {
+  local id
+  id=$(tmux display-message -p -t "=$TMUX_SESSION_NAME" '#{session_id}') || return 1
+  session_id_name_matches "$id" || return 1
+  printf '%s\n' "$id"
+}
+
+tmux_test_boundary() {
+  local boundary=$1 id=$2 hook=${POLYLANE_TMUX_TEST_BOUNDARY_HOOK:-}
+  [ "${POLYLANE_TMUX_TEST_BOUNDARY:-}" = "$boundary" ] || return 0
+  case "$hook" in /*) : ;; *) return 2 ;; esac
+  [ -x "$hook" ] && [ -f "$hook" ] && [ ! -L "$hook" ] || return 2
+  "$hook" "$boundary" "$id" "$TMUX_SESSION_NAME"
+}
+
+set_session_option_by_id() {
+  local id=$1 option=$2 value=$3 boundary=$4
+  session_id_name_matches "$id" || return 2
+  run tmux set-option -t "$id" "$option" "$value" || return 2
+  session_id_name_matches "$id" || return 2
+  [ "$(tmux show-options -qv -t "$id" "$option")" = "$value" ] || return 2
+  tmux_test_boundary "$boundary" "$id" || return 2
+  session_id_name_matches "$id"
+}
+
+emit_attach_command() {
+  owned_session_id_matches "$TMUX_SESSION_ID" || return 2
+  # Host UX keeps the authenticated exact loop name; all internal operations use the ID.
+  local line="tmux attach -t $TMUX_SESSION_NAME"
+  if [ "${POLYLANE_HOST_FD:-}" = 9 ] && { : >&9; } 2>/dev/null; then
+    printf '%s\n' "$line" >&9
+  else
+    printf '%s\n' "$line"
+  fi
+}
+
+agent_attempt_error_dir() {
+  local claim=${POLYLANE_CLAIM_TOKEN:-} generation=${POLYLANE_RUNNER_GENERATION:-}
+  local attempt=${POLYLANE_ATTEMPT:-} root
+  case "$claim" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac
+  case "$generation:$attempt" in *[!0-9:]*|:*|*:) return 1 ;; esac
+  root="${POLYLANE_RUNTIME_DIR:-$PROJECT_ROOT/.polylane/runtime}/agent-errors"
+  polylane_fs validate-dir "$root/$claim/g$generation/a$attempt" || return 1
+  [ -d "$root/$claim/g$generation/a$attempt" ] && \
+    [ ! -L "$root/$claim" ] && [ ! -L "$root/$claim/g$generation" ] && \
+    [ ! -L "$root/$claim/g$generation/a$attempt" ] || return 1
+  printf '%s\n' "$root/$claim/g$generation/a$attempt"
+}
+
+agent_artifact_for_prompt() {
+  local prompt=$1 directory
+  directory=$(agent_attempt_error_dir) || return 1
+  case "${prompt##*/}" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac
+  printf '%s/%s.json\n' "$directory" "${prompt##*/}"
+}
+
+agent_artifact_for_pane() {
+  local pane=$1 i
+  for i in "${!LANE_PANE_IDX[@]}"; do
+    if [ "${LANE_PANE_IDX[$i]:--1}" = "$pane" ]; then
+      agent_artifact_for_prompt "${LANE_PROMPTS[$i]}"; return
+    fi
+  done
+  if [ "${INT_PANE_IDX:--1}" = "$pane" ] && [ -n "${INT_PROMPT:-}" ]; then
+    agent_artifact_for_prompt "$INT_PROMPT"; return
+  fi
+  return 1
+}
@@
-  local qwt qmodel qpf tmpl
-  qwt=$(printf '%q' "$wt"); qmodel=$(printf '%q' "$model"); qpf=$(printf '%q' "$pf")
-  [ -n "$effort" ] && pfx="POLYLANE_EFFORT=$(printf '%q' "$effort") "
+  local qwt qmodel qpf qeffort qartifact artifact tmpl
+  [ -n "$effort" ] || effort=$(polylane_adapter_effort default "")
+  qwt=$(printf '%q' "$wt"); qmodel=$(printf '%q' "$model"); qpf=$(printf '%q' "$pf")
+  qeffort=$(printf '%q' "$effort")
+  artifact=$(agent_artifact_for_prompt "$pf")
+  qartifact=$(printf '%q' "$artifact")
+  [ -n "$effort" ] && pfx="POLYLANE_EFFORT=$qeffort "
@@
   tmpl=${tmpl//'{model}'/$qmodel}
   tmpl=${tmpl//'{prompt}'/$qpf}
+  tmpl=${tmpl//'{effort}'/$qeffort}
+  tmpl=${tmpl//'{error_artifact}'/$qartifact}
@@
 new_pane() {
  if [ "${SESSION_STARTED:-0}" != "1" ]; then
+    TMUX_SESSION_NAME=${TMUX_SESSION_NAME:-$TMUX_SESSION}
+    if tmux has-session -t "=$TMUX_SESSION_NAME" 2>/dev/null; then
+      TMUX_SESSION_ID=$(capture_named_session_id) && owned_session_id_matches "$TMUX_SESSION_ID" || {
+        echo "polylane-run: foreign tmux session collision: $TMUX_SESSION_NAME" >&2; return 2;
+      }
+      tmux_test_boundary before-adopt-attach "$TMUX_SESSION_ID" || return 2
+      owned_session_id_matches "$TMUX_SESSION_ID" || return 2
+      TMUX_SESSION=$TMUX_SESSION_ID
+      emit_attach_command || return 2
+    else
-    run tmux new-session -d -s "$TMUX_SESSION" -x "${POLYLANE_TMUX_COLS:-250}" -y "${POLYLANE_TMUX_ROWS:-60}" -n "${1:-lanes}"
+    # Start the first pane with the physical shell explicitly, then bind both
+    # session defaults before any split/respawn. No pane resolves `bash`/`node`
+    # through its mutable PATH.
+    TMUX_SESSION_ID=$(tmux new-session -d -P -F '#{session_id}' -s "$TMUX_SESSION_NAME" \
+      -x "${POLYLANE_TMUX_COLS:-250}" -y "${POLYLANE_TMUX_ROWS:-60}" \
+      -n "${1:-lanes}" "$AGENT_SHELL") || {
+      # A session created after preflight is never adopted or mutated, even if its
+      # name is correct; the creator must publish all ownership tags itself.
+      echo "polylane-run: tmux session allocation raced: $TMUX_SESSION_NAME" >&2
+      return 2
+    }
+    session_id_name_matches "$TMUX_SESSION_ID" || return 2
+    tmux_test_boundary after-create "$TMUX_SESSION_ID" || return 2
+    set_session_option_by_id "$TMUX_SESSION_ID" default-shell "$AGENT_SHELL" after-default-shell || return 2
+    set_session_option_by_id "$TMUX_SESSION_ID" default-command "$AGENT_SHELL" after-default-command || return 2
+    set_session_option_by_id "$TMUX_SESSION_ID" @polylane_run_id "$RUN_ID" after-run-id || return 2
+    set_session_option_by_id "$TMUX_SESSION_ID" @polylane_loop_id "$LOOP_ID" after-loop-id || return 2
+    set_session_option_by_id "$TMUX_SESSION_ID" @polylane_claim_token \
+      "$POLYLANE_CLAIM_TOKEN" after-claim || return 2
+    set_session_option_by_id "$TMUX_SESSION_ID" @polylane_runner_generation \
+      "$POLYLANE_RUNNER_GENERATION" after-generation || return 2
+    owned_session_id_matches "$TMUX_SESSION_ID" || return 2
+    TMUX_SESSION=$TMUX_SESSION_ID
+    emit_attach_command || return 2
+    fi
     SESSION_STARTED=1
@@
 pane_errored() {
@@
-  printf '%s' "$txt" | grep -qiE \
-    'API Error|Internal server error|overloaded|rate.?limit|Connection error|network error|5[0-9][0-9] (Internal|error)|status\.claude\.com' \
-    && return 0
-  return 1
+  local artifact
+  artifact=$(agent_artifact_for_pane "$idx") || return 1
+  [ "$(polylane_agent_error_class "$(agent_selected)" "$artifact")" != none ]
 }
@@
-  echo "Launched ${LAUNCHED:-0} of ${#LANE_NAMES[@]} lane(s). Attach with: tmux attach -t $TMUX_SESSION"
+  echo "Launched ${LAUNCHED:-0} of ${#LANE_NAMES[@]} lane(s)."
```

Expected: `bash -n core/scripts/polylane-run.sh` exits 0.

After `new-session -P -F '#{session_id}'`, the runner treats that returned session ID as the
only mutation/teardown capability. It revalidates ID plus exact name before and after every
option write, pane operation, adoption, attach emission, and cleanup fence. Kill/recreate faults
at creation and each ownership-tag boundary must fail closed without touching or adopting the
same-name replacement. The single host-visible line intentionally remains exactly
`tmux attach -t polylane-<loop_id>` (the authenticated manifest name); no internal mutation or
teardown may target that reusable name.

- [ ] **Step 11: Patch doctor to use the selected adapter (5 minutes)**

Make these anchored edits to `core/scripts/polylane-doctor.sh`:

```diff
diff --git a/core/scripts/polylane-doctor.sh b/core/scripts/polylane-doctor.sh
--- a/core/scripts/polylane-doctor.sh
+++ b/core/scripts/polylane-doctor.sh
@@
 TMUX_SESSION="${POLYLANE_SESSION:-polylane}"
+SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
+. "$SCRIPT_DIR/polylane-agent.sh"
+[ -n "${POLYLANE_AGENT_ADAPTER:-}" ] && [ -f "$POLYLANE_AGENT_ADAPTER" ] && . "$POLYLANE_AGENT_ADAPTER"
@@
-  for d in tmux jq git claude; do
+  for d in tmux jq git; do
@@
-        claude) hint="npm install -g @anthropic-ai/claude-code" ;;
@@
-# --- claude version ----------------------------------------------------------------
-
-check_claude() {
-  command -v claude >/dev/null 2>&1 || return 0  # dep FAIL already covers absence
-  local v
-  v=$(claude --version 2>/dev/null | head -1)
+check_agent_cli() {
+  local agent cli v
+  agent=${POLYLANE_AGENT:-}
+  [ "$MANIFEST_OK" = 0 ] || agent=$(polylane_agent_from_manifest "$MANIFEST" 2>/dev/null || true)
+  [ -n "$agent" ] || { row FAIL "agent: identity" "manifest or launcher must select an agent"; return 0; }
+  cli=$(polylane_agent_cli "$agent") || {
+    row FAIL "agent: identity" "unknown or adapter-mismatched agent '$agent'"; return 0;
+  }
+  [ "$cli" = custom ] && { row PASS "agent: custom command" "POLYLANE_AGENT_CMD"; return 0; }
+  command -v "$cli" >/dev/null 2>&1 || { row FAIL "dep: $cli" "missing selected agent CLI"; return 0; }
+  v=$($cli --version 2>/dev/null | head -1)
   if [ -n "$v" ]; then
-    row PASS "claude: version" "$v"
+    row PASS "agent: $cli version" "$v"
   else
-    row FAIL "claude: version" "claude found but --version failed — reinstall: npm install -g @anthropic-ai/claude-code"
+    row FAIL "agent: $cli version" "$cli found but --version failed"
   fi
 }
@@
-  check_claude
+  check_agent_cli
+  if [ -f "$SCRIPT_DIR/../.polylane-core-revision" ]; then
+    row PASS "core-package: revision" "$(cat "$SCRIPT_DIR/../.polylane-core-revision")"
+  fi
```

Expected: `bash -n core/scripts/polylane-doctor.sh` exits 0.

- [ ] **Step 12: Replace the adapter contract test and point doctor tests at the wrapper (5 minutes)**

Replace `core/tests/test-agent-adapter.sh` with this complete body:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
. "$ROOT/core/scripts/polylane-agent.sh"

. "$ROOT/codex/scripts/polylane-codex-agent.sh"
AGENT=codex; unset POLYLANE_AGENT POLYLANE_AGENT_CMD
assert_contains "codex-template" "polylane-codex-exec.sh" "$(polylane_agent_template codex)"
assert_contains "codex-wrapper-explicit-interpreter" \
  '"$POLYLANE_CODEX_INTERPRETER" "$codex_exe" exec --json' \
  "$(cat "$ROOT/codex/scripts/polylane-codex-exec.sh")"
assert_eq "codex-trusted-shell" "$(cd /bin && pwd -P)/bash" "$(polylane_agent_shell codex)"
assert_eq "codex-processes" "codex node" "$(polylane_agent_processes codex)"
assert_eq "codex-default-effort" medium "$(polylane_adapter_effort default gpt-x)"
assert_rc "codex-rejects-claude" 2 polylane_agent_template claude

. "$ROOT/claude-code/scripts/polylane-claude-agent.sh"
assert_contains "claude-template" "--permission-mode acceptEdits" \
  "$(polylane_agent_template claude)"
assert_eq "claude-processes" "claude node" "$(polylane_agent_processes claude)"
assert_eq "claude-trusted-shell" "$(cd /bin && pwd -P)/bash" "$(polylane_agent_shell claude)"
POLYLANE_PERMISSION_MODE=plan
assert_contains "claude-permission-override" "--permission-mode plan" \
  "$(polylane_agent_template claude)"
unset POLYLANE_PERMISSION_MODE
assert_eq "claude-empty-default-effort" "" "$(polylane_adapter_effort default '')"

POLYLANE_AGENT_CMD='mycli --m {model} --f {prompt} --e {effort}'
assert_eq "custom-template" "$POLYLANE_AGENT_CMD" "$(polylane_agent_template claude)"
assert_eq "custom-cli" custom "$(polylane_agent_cli claude)"
assert_rc "unknown-never-overridden" 2 polylane_agent_template wat
unset POLYLANE_AGENT_CMD
finish
```

Make this anchored edit:

```diff
diff --git a/core/tests/test-doctor.sh b/core/tests/test-doctor.sh
--- a/core/tests/test-doctor.sh
+++ b/core/tests/test-doctor.sh
@@
-DOCTOR="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-doctor.sh"
+ROOT=$(cd "$(dirname "$0")/../.." && pwd)
+DOCTOR="$ROOT/claude-code/scripts/polylane-claude-doctor.sh"
```

Expected: both changed test files pass `bash -n`.

- [ ] **Step 13: Verify the focused RED tests are GREEN (4 minutes)**

```bash
bash core/tests/test-agent-preflight.sh
bash codex/tests/test-codex-command.sh
bash codex/tests/test-codex-model-resolver.sh
bash core/tests/test-agent-adapter.sh
bash core/tests/test-doctor.sh
```

Expected: all five commands exit 0; `test-codex-command.sh` reports
`PASS argv-exact` and `PASS stdin-exact`.

- [ ] **Step 14: Run the aggregate suite (5 minutes)**

Run: `tests/run.sh`

Expected: exit 0 with `SUMMARY: <positive integer> test files, 0 failed`.

- [ ] **Step 15: Commit the adapter contract (2 minutes)**

Run:

```bash
git add core/scripts/polylane-fs.py core/scripts/polylane-agent.sh core/scripts/polylane-run.sh \
  core/scripts/polylane-doctor.sh core/tests codex/scripts/polylane-codex-agent.sh \
  codex/scripts/polylane-codex-exec.sh \
  codex/scripts/polylane-codex-model.sh codex/tests/test-codex-model-resolver.sh \
  claude-code/scripts/polylane-claude-agent.sh \
  claude-code/scripts/polylane-claude-run.sh \
  claude-code/scripts/polylane-claude-doctor.sh \
  claude-code/scripts/polylane-claude-compat.sh \
  bin/polylane-run.sh bin/polylane-doctor.sh \
  codex/tests/test-codex-command.sh
git commit -m "fix(core): make agent execution adapter-aware"
```

Expected: exit 0 with commit subject `fix(core): make agent execution adapter-aware`.

---

### Task 3: Add Fail-Closed Adapter Launchers

**Files:**
- Create: `codex/scripts/polylane-codex.sh`
- Create: `claude-code/scripts/polylane-claude.sh`
- Create: `codex/tests/test-codex-launcher.sh`
- Create: `claude-code/tests/test-claude-launcher.sh`

**Interfaces:**
- `polylane-codex.sh <manifest> [runner-args...]` requires exact Codex identity.
- `polylane-claude.sh <manifest> [runner-args...]` preserves Claude compatibility.

- [ ] **Step 1: Add the complete Codex launcher test (5 minutes)**

Create `codex/tests/test-codex-launcher.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
PKG="$TEST_TMPDIR/pkg"
mkdir -p "$PKG/scripts" "$TEST_TMPDIR/bin"
cp "$ROOT/codex/scripts/polylane-codex.sh" "$PKG/scripts/"
cp "$ROOT/codex/scripts/polylane-codex-agent.sh" "$PKG/scripts/"
cp "$ROOT/core/scripts/polylane-agent.sh" "$PKG/scripts/"
SIDE_EFFECT_LOG="$TEST_TMPDIR/side-effects" CALLED="$TEST_TMPDIR/called"
export SIDE_EFFECT_LOG CALLED
for name in git tmux codex; do
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "${0##*/}" >> "$SIDE_EFFECT_LOG"' 'exit 99' \
    > "$TEST_TMPDIR/bin/$name"
  chmod +x "$TEST_TMPDIR/bin/$name"
done
cat > "$PKG/scripts/polylane-supervisor.sh" <<'SH'
#!/usr/bin/env bash
printf 'supervisor\n' >> "$SIDE_EFFECT_LOG"
printf 'agent=%s\nadapter=%s\nargs=%s\n' "$POLYLANE_AGENT" \
  "$POLYLANE_AGENT_ADAPTER" "$*" > "$CALLED"
SH
chmod +x "$PKG/scripts/"*.sh

printf '{\n' > "$TEST_TMPDIR/malformed.json"
printf '%s\n' '{"run_id":"r1"}' > "$TEST_TMPDIR/missing.json"
printf '%s\n' '{"agent":"claude","run_id":"r1"}' > "$TEST_TMPDIR/wrong.json"
printf '%s\n' '{"agent":"wat","run_id":"r1"}' > "$TEST_TMPDIR/unknown.json"
printf '%s\n' '{"agent":"codex","run_id":"r1"}' > "$TEST_TMPDIR/codex.json"
LAUNCH="$PKG/scripts/polylane-codex.sh"
for fixture in malformed missing wrong unknown; do
  : > "$SIDE_EFFECT_LOG"
  assert_rc "$fixture" 2 "$LAUNCH" "$TEST_TMPDIR/$fixture.json"
  assert_eq "$fixture-no-side-effects" "" "$(cat "$SIDE_EFFECT_LOG")"
done
: > "$SIDE_EFFECT_LOG"
PATH="$TEST_TMPDIR/bin:$PATH" assert_ok "valid" "$LAUNCH" "$TEST_TMPDIR/codex.json" --resume
assert_eq "valid-only-supervisor" supervisor "$(cat "$SIDE_EFFECT_LOG")"
assert_contains "forced-agent" "agent=codex" "$(cat "$CALLED")"
assert_contains "resume-forwarded" "--resume" "$(cat "$CALLED")"
assert_contains "adapter-forwarded" "polylane-codex-agent.sh" "$(cat "$CALLED")"
finish
```

Run: `bash -n codex/tests/test-codex-launcher.sh`

Expected: exit 0; malformed/wrong/unknown and valid fixture paths are syntactically covered.

- [ ] **Step 2: Add the complete Claude compatibility launcher test (5 minutes)**

Create `claude-code/tests/test-claude-launcher.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
PKG="$TEST_TMPDIR/pkg"
mkdir -p "$PKG/scripts" "$TEST_TMPDIR/bin"
cp "$ROOT/claude-code/scripts/polylane-claude.sh" "$PKG/scripts/"
cp "$ROOT/claude-code/scripts/polylane-claude-agent.sh" "$PKG/scripts/"
cp "$ROOT/core/scripts/polylane-agent.sh" "$PKG/scripts/"
SIDE_EFFECT_LOG="$TEST_TMPDIR/side-effects" CALLED="$TEST_TMPDIR/called"
export SIDE_EFFECT_LOG CALLED
for name in git tmux claude; do
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "${0##*/}" >> "$SIDE_EFFECT_LOG"' 'exit 99' \
    > "$TEST_TMPDIR/bin/$name"
  chmod +x "$TEST_TMPDIR/bin/$name"
done
cat > "$PKG/scripts/polylane-supervisor.sh" <<'SH'
#!/usr/bin/env bash
printf 'supervisor\n' >> "$SIDE_EFFECT_LOG"
printf 'agent=%s\nadapter=%s\nargs=%s\n' "$POLYLANE_AGENT" \
  "$POLYLANE_AGENT_ADAPTER" "$*" > "$CALLED"
SH
chmod +x "$PKG/scripts/"*.sh

printf '{\n' > "$TEST_TMPDIR/malformed.json"
printf '%s\n' '{"run_id":"r1"}' > "$TEST_TMPDIR/missing.json"
printf '%s\n' '{"agent":"claude","run_id":"r1"}' > "$TEST_TMPDIR/claude.json"
printf '%s\n' '{"agent":"codex","run_id":"r1"}' > "$TEST_TMPDIR/wrong.json"
printf '%s\n' '{"agent":"wat","run_id":"r1"}' > "$TEST_TMPDIR/unknown.json"
LAUNCH="$PKG/scripts/polylane-claude.sh"
for fixture in malformed wrong unknown; do
  : > "$SIDE_EFFECT_LOG"
  assert_rc "$fixture" 2 "$LAUNCH" "$TEST_TMPDIR/$fixture.json"
  assert_eq "$fixture-no-side-effects" "" "$(cat "$SIDE_EFFECT_LOG")"
done
for fixture in missing claude; do
  : > "$SIDE_EFFECT_LOG"
  PATH="$TEST_TMPDIR/bin:$PATH" assert_ok "$fixture-valid" \
    "$LAUNCH" "$TEST_TMPDIR/$fixture.json" --resume
  assert_eq "$fixture-only-supervisor" supervisor "$(cat "$SIDE_EFFECT_LOG")"
  assert_contains "$fixture-forced-agent" "agent=claude" "$(cat "$CALLED")"
done
finish
```

Run: `bash -n claude-code/tests/test-claude-launcher.sh`

Expected: exit 0; missing-agent compatibility and explicit-Claude paths are syntactically
covered.

- [ ] **Step 3: Run both launcher tests and verify RED (2 minutes)**

```bash
bash codex/tests/test-codex-launcher.sh
bash claude-code/tests/test-claude-launcher.sh
```

Expected: both exit nonzero because their launcher files do not exist.

- [ ] **Step 4: Add the complete fail-closed Codex launcher (5 minutes)**

Create executable `codex/scripts/polylane-codex.sh`:

```bash
#!/usr/bin/env bash
set -eu
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MANIFEST=${1:-}
[ -n "$MANIFEST" ] || { echo "usage: polylane-codex.sh <manifest> [runner-args...]" >&2; exit 2; }
shift
[ -f "$MANIFEST" ] || { echo "polylane-codex: manifest not found: $MANIFEST" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "polylane-codex: jq is required" >&2; exit 1; }
jq empty "$MANIFEST" 2>/dev/null || { echo "polylane-codex: invalid JSON" >&2; exit 2; }
agent=$(jq -r 'if has("agent") then .agent else "" end' "$MANIFEST")
[ "$agent" = codex ] || {
  echo "polylane-codex: manifest agent must be exactly codex" >&2; exit 2;
}
run_id=$(jq -r '.run_id // ""' "$MANIFEST")
[ -n "$run_id" ] || { echo "polylane-codex: run_id is required" >&2; exit 2; }
for dep in tmux jq git; do command -v "$dep" >/dev/null 2>&1 || {
  echo "polylane-codex: missing dependency: $dep" >&2; exit 1; }; done
export POLYLANE_AGENT=codex
export POLYLANE_AGENT_ADAPTER="$SCRIPT_DIR/polylane-codex-agent.sh"
if [ -x "$SCRIPT_DIR/polylane-supervisor.sh" ]; then CORE_BIN=$SCRIPT_DIR
else CORE_BIN=$(cd "$SCRIPT_DIR/../../core/scripts" && pwd); fi
. "$CORE_BIN/polylane-agent.sh"
. "$POLYLANE_AGENT_ADAPTER"
cli=$(polylane_agent_cli codex)
[ "$cli" = custom ] || command -v "$cli" >/dev/null 2>&1 || {
  echo "polylane-codex: $cli is required" >&2; exit 1;
}
exec "$CORE_BIN/polylane-supervisor.sh" "$MANIFEST" "$@"
```

Expected: `bash -n codex/scripts/polylane-codex.sh` exits 0.

- [ ] **Step 5: Add the complete Claude compatibility launcher (5 minutes)**

Create executable `claude-code/scripts/polylane-claude.sh`:

```bash
#!/usr/bin/env bash
set -eu
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MANIFEST=${1:-}
[ -n "$MANIFEST" ] || { echo "usage: polylane-claude.sh <manifest> [runner-args...]" >&2; exit 2; }
shift
[ -f "$MANIFEST" ] || { echo "polylane-claude: manifest not found: $MANIFEST" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "polylane-claude: jq is required" >&2; exit 1; }
jq empty "$MANIFEST" 2>/dev/null || { echo "polylane-claude: invalid JSON" >&2; exit 2; }
agent=$(jq -r 'if has("agent") then .agent else "claude" end' "$MANIFEST")
[ "$agent" = claude ] || {
  echo "polylane-claude: explicit manifest agent must be claude" >&2; exit 2;
}
run_id=$(jq -r '.run_id // ""' "$MANIFEST")
[ -n "$run_id" ] || { echo "polylane-claude: run_id is required" >&2; exit 2; }
for dep in tmux jq git; do command -v "$dep" >/dev/null 2>&1 || {
  echo "polylane-claude: missing dependency: $dep" >&2; exit 1; }; done
export POLYLANE_AGENT=claude
export POLYLANE_AGENT_ADAPTER="$SCRIPT_DIR/polylane-claude-agent.sh"
if [ -x "$SCRIPT_DIR/polylane-supervisor.sh" ]; then CORE_BIN=$SCRIPT_DIR
else CORE_BIN=$(cd "$SCRIPT_DIR/../../core/scripts" && pwd); fi
. "$CORE_BIN/polylane-agent.sh"
. "$POLYLANE_AGENT_ADAPTER"
cli=$(polylane_agent_cli claude)
[ "$cli" = custom ] || command -v "$cli" >/dev/null 2>&1 || {
  echo "polylane-claude: $cli is required" >&2; exit 1;
}
exec "$CORE_BIN/polylane-supervisor.sh" "$MANIFEST" "$@"
```

Run: `chmod +x codex/scripts/polylane-codex.sh claude-code/scripts/polylane-claude.sh`

Expected: both launchers pass `bash -n`.

- [ ] **Step 6: Run launcher tests and verify GREEN (3 minutes)**

```bash
bash codex/tests/test-codex-launcher.sh
bash claude-code/tests/test-claude-launcher.sh
```

Expected: both exit 0; the Codex test prints `PASS valid-only-supervisor`, and every
invalid fixture prints a `PASS <fixture>-no-side-effects` line.

- [ ] **Step 7: Run the aggregate suite (5 minutes)**

Run: `tests/run.sh`

Expected: exit 0 with zero failed test files.

- [ ] **Step 8: Commit the launchers (2 minutes)**

Run:

```bash
git add codex/scripts/polylane-codex.sh codex/tests/test-codex-launcher.sh \
  claude-code/scripts/polylane-claude.sh claude-code/tests/test-claude-launcher.sh
git commit -m "feat: add fail-closed platform launchers"
```

Expected: exit 0 with commit subject `feat: add fail-closed platform launchers`.

---

### Task 4: Rewrite the Common Workflow Semantically

**Files:**
- Create: `core/workflow/polylane-loop.md`
- Create: `core/tests/test-workflow-contract.sh`
- Create: `core/tests/test-core-neutrality.sh`
- Create: `core/tests/test-adapter-policy.sh`
- Modify: `core/tests/helpers.sh`
- Create: `codex/tests/test-codex-skill-structure.sh`
- Create: `core/references/discovery.md`, `core/references/interview.md`,
  `core/references/planning.md`, `core/references/prompt-blocks.md`,
  `core/references/lane-template.md`, `core/references/skill-catalog.md`, and
  `core/references/skill-scout.md`
- Replace: `codex/SKILL.md`, `claude-code/SKILL.md`
- Replace: root `SKILL.md` with the relative compatibility link `claude-code/SKILL.md`
- Create: `codex/references/codex-prompts.md`
- Create: `codex/references/codex-models.md`
- Create: `codex/references/codex-runtime.md`
- Create: `codex/package.json`
- Create: `codex/scripts/polylane-codex-package-policy.sh`
- Create: `codex/tests/test-codex-package-policy.sh`
- Create: `claude-code/package.json`
- Create: `claude-code/scripts/polylane-claude-package-policy.sh`
- Modify: `codex/agents/openai.yaml`
- Modify: `core/scripts/polylane-run.sh`, `core/scripts/polylane-dashboard.sh`,
  `core/scripts/polylane-outcomes.sh`, `core/scripts/polylane-promptlint.sh`, and
  `core/scripts/polylane-scout.sh`
- Modify: `core/scripts/polylane-supervisor.sh`
- Modify: `codex/scripts/polylane-codex.sh`, `claude-code/scripts/polylane-claude.sh`
- Modify: `codex/scripts/polylane-codex-agent.sh` and
  `claude-code/scripts/polylane-claude-agent.sh`

**Interfaces:**
- Common workflow consumes `SKILL_ROOT`, `BIN`, agent id, question surface, prompt hook,
  model hook, memory hook, and controller launcher from its adapter.
- Shared executable helpers consume adapter hooks for model inventory/ranking, price
  metadata, skill roots, prompt dialect tokens, slash-command equivalents, and
  agent-specific error recognition. They contain no built-in Codex or Claude values.
- Common workflow owns goal tree, cycles, verification, promotion, council inputs,
  recovery intent, and resume semantics.
- Installed `SKILL.md` is a concise progressive-disclosure router under 500 lines. The
  complete common workflow is bundled once as `references/polylane-loop.md` and loaded on
  invocation; detailed platform behavior stays in directly linked references, never copied
  into the skill body.

- [ ] **Step 1: Add the complete semantic workflow contract test (4 minutes)**

Create `core/tests/test-workflow-contract.sh`:

```bash
#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
FLOW=$(cat "$ROOT/core/workflow/polylane-loop.md" 2>/dev/null || true)
CODEX=$(cat "$ROOT/codex/SKILL.md" 2>/dev/null || true)
assert_contains "active-phases" "WORKING" "$FLOW"
assert_contains "only-terminal" "COMPLETE" "$FLOW"
assert_contains "user-terminal" "WAITING_FOR_USER" "$FLOW"
assert_contains "goal-tree" "goal tree" "$FLOW"
assert_contains "nonce" "run nonce" "$FLOW"
assert_contains "promotion" "GO-only promotion" "$FLOW"
assert_contains "resume" "resume" "$FLOW"
for forbidden in 'POLYLANE_MAX_CYCLES' 'POLYLANE_BUDGET' 'LED cap' 'LED trend' \
                 'LED roi' 'diminishing returns exit'; do
  assert_not_contains "flow-no-$forbidden" "$forbidden" "$FLOW"
done
assert_not_contains "codex-no-claude-home" '~/.claude' "$CODEX"
assert_not_contains "codex-no-question-tool" 'AskUserQuestion' "$CODEX"
assert_not_contains "codex-no-legacy-flag" '--full-auto' "$CODEX"
finish
```

Run: `bash -n core/tests/test-workflow-contract.sh`

Expected: exit 0; the future semantic assertions are valid shell.

- [ ] **Step 2: Add the complete core-neutrality test (3 minutes)**

Create `core/tests/test-core-neutrality.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
. "$ROOT/core/scripts/polylane-agent.sh"
assert_eq "shared-codex-identity" codex "$(polylane_agent_cli codex)"
assert_eq "shared-claude-identity" claude "$(polylane_agent_cli claude)"
assert_rc "unknown-still-fails-closed" 2 polylane_agent_cli unknown-platform
CORE=$(find "$ROOT/core/scripts" "$ROOT/core/workflow" "$ROOT/core/references" \
  -type f \( -name '*.sh' -o -name '*.md' \) -exec cat {} + 2>/dev/null)
assert_not_contains "no-inline-package-policy" "foreign platform policy" "$CORE"
assert_not_contains "no-inline-policy-needles" "policy_needles" "$CORE"
assert_contains "adapter-delegation" "polylane_adapter_error_class" "$CORE"
pass "core-neutrality"
finish
```

Run: `bash -n core/tests/test-core-neutrality.sh`

Expected: exit 0; source-only scanning excludes config fixtures and behavior checks remain
fail-closed.

- [ ] **Step 3: Add the complete adapter-policy execution test (5 minutes)**

Create `core/tests/test-adapter-policy.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
mkdir -p "$TEST_TMPDIR/a-root/widget" "$TEST_TMPDIR/b-root/gadget"

write_adapter() {
  local file=$1 prefix=$2 root=$3 err=$4 token=$5
  cat > "$file" <<EOF
polylane_adapter_cli() { [ "\$1" = codex ] || return 2; printf codex; }
polylane_adapter_template() { printf 'fake --model {model} --prompt {prompt} --effort {effort}'; }
polylane_adapter_processes() { printf fake; }
polylane_adapter_models() { case "\$1" in economy) printf '${prefix}-cheap\\n${prefix}-strong\\n' ;; *) printf '${prefix}-strong\\n${prefix}-cheap\\n' ;; esac; }
polylane_adapter_effort() { printf high; }
polylane_adapter_price() { [ "\$1" = '${prefix}-cheap' ] && printf '{"output_per_million":7}' || printf null; }
polylane_adapter_skill_roots() { printf '%s\\n' '$root'; }
polylane_adapter_prompt_tokens() { printf '%s\\n' '{"objective":["$token"],"question":["QUESTION"],"command":[]}'; }
polylane_adapter_error_class() { jq -er '.kind // "none"' "\$2" 2>/dev/null || printf none; }
EOF
  jq -n --arg kind "$err" '{schema_version:1,kind:$kind}' > "$TEST_TMPDIR/$prefix-error.json"
}
write_adapter "$TEST_TMPDIR/a.sh" a "$TEST_TMPDIR/a-root" transient TARGET_A
write_adapter "$TEST_TMPDIR/b.sh" b "$TEST_TMPDIR/b-root" transient TARGET_B

probe_runner() {
  local adapter=$1 models=$2 err=$3
  POLYLANE_AGENT=codex POLYLANE_AGENT_ADAPTER="$adapter" \
    bash -c '. "$1"; AVAILABLE_MODELS=($2); printf "%s|%s|%s" \
      "$(preset_model economy)" "$(model_out_price "$3")" \
      "$(polylane_agent_error_class codex "$4")"' _ \
      "$ROOT/core/scripts/polylane-run.sh" "$models" "${models%% *}" "$err"
}
assert_eq "runner-a" 'a-cheap|7|transient' \
  "$(probe_runner "$TEST_TMPDIR/a.sh" 'a-cheap a-strong' "$TEST_TMPDIR/a-error.json")"
assert_eq "runner-b" 'b-cheap|7|transient' \
  "$(probe_runner "$TEST_TMPDIR/b.sh" 'b-cheap b-strong' "$TEST_TMPDIR/b-error.json")"

for pair in "a:$TEST_TMPDIR/a.sh:a-cheap" "b:$TEST_TMPDIR/b.sh:b-cheap"; do
  label=${pair%%:*}; rest=${pair#*:}; adapter=${rest%%:*}; expected=${pair##*:}
  got=$(POLYLANE_AGENT_ADAPTER="$adapter" POLYLANE_OUTCOMES="$TEST_TMPDIR/empty-$label" \
    "$ROOT/core/scripts/polylane-outcomes.sh" tune shape)
  assert_eq "outcomes-$label" "$expected" "$got"
done

POLYLANE_AGENT_ADAPTER="$TEST_TMPDIR/a.sh" assert_ok "scout-a" \
  "$ROOT/core/scripts/polylane-scout.sh" installed widget
POLYLANE_AGENT_ADAPTER="$TEST_TMPDIR/b.sh" assert_ok "scout-b" \
  "$ROOT/core/scripts/polylane-scout.sh" installed gadget

for label in A B; do
  token="TARGET_$label"; lower=$(printf '%s' "$label" | tr A-Z a-z)
  prompt="$TEST_TMPDIR/prompt-$lower"
  printf '%s\n' "$token OWN FORBIDDEN STATUS: lane DONE run=r1 verify" > "$prompt"
  POLYLANE_AGENT_ADAPTER="$TEST_TMPDIR/$lower.sh" assert_ok "prompt-$lower" \
    "$ROOT/core/scripts/polylane-promptlint.sh" lint "$prompt" lane
done

for label in a b; do
  upper=$(printf '%s' "$label" | tr a-z A-Z)
  out=$(POLYLANE_AGENT=codex POLYLANE_AGENT_ADAPTER="$TEST_TMPDIR/$label.sh" \
    bash -c '. "$1"; text_failed "$2" && printf failed' _ \
      "$ROOT/core/scripts/polylane-dashboard.sh" "${upper}_ERR")
  assert_eq "dashboard-$label" failed "$out"
done

bad='CLAUDE_SKILLS_DIR|~/.claude|AskUserQuestion|/goal|claude-(opus|sonnet|haiku|fable)|status\\.claude|permission-mode|claude --'
for file in polylane-run.sh polylane-dashboard.sh polylane-outcomes.sh \
            polylane-promptlint.sh polylane-scout.sh; do
  out=$(rg -n "$bad" "$ROOT/core/scripts/$file" || true)
  assert_eq "neutral-$file" "" "$out"
done
finish
```

Expected: `bash -n core/tests/test-adapter-policy.sh` exits 0.

- [ ] **Step 4: Add the complete installed-skill structure test (5 minutes)**

Create `codex/tests/test-codex-skill-structure.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
SKILL="$ROOT/codex/SKILL.md"
front=$(awk 'NR==1 && $0=="---"{on=1;next} on && $0=="---"{exit} on{print}' "$SKILL")
keys=$(printf '%s\n' "$front" | sed -n 's/^\([A-Za-z_][A-Za-z0-9_-]*\):.*/\1/p' | LC_ALL=C sort)
assert_eq "frontmatter-keys" "$(printf '%s\n' description name)" "$keys"
assert_contains "name" "name: polylane" "$front"
description=$(printf '%s\n' "$front" | sed -n 's/^description:[[:space:]]*//p')
assert_contains "description-does" "autonomous" "$description"
assert_contains "description-when" "Use when" "$description"
lines=$(wc -l < "$SKILL" | tr -d ' ')
[ "$lines" -lt 500 ] && pass "under-500" || fail "under-500" "$lines lines"
for ref in polylane-loop.md codex-runtime.md codex-prompts.md codex-models.md; do
  assert_contains "direct-$ref" "references/$ref" "$(cat "$SKILL")"
done
assert_not_contains "no-embedded-state-machine" "## State machine" "$(cat "$SKILL")"
for ref in "$ROOT"/core/workflow/*.md "$ROOT"/codex/references/*.md; do
  [ -f "$ref" ] || continue
  lines=$(wc -l < "$ref" | tr -d ' ')
  if [ "$lines" -gt 100 ]; then
    head -30 "$ref" | grep -q '^## Contents$' && pass "toc-${ref##*/}" || fail "toc-${ref##*/}" "missing top-level Contents"
  fi
  nested=$(rg -n '\]\([^)]*references/' "$ref" || true)
  assert_eq "no-second-hop-${ref##*/}" "" "$nested"
done
expected=$(cat <<'YAML'
interface:
  display_name: "Polylane"
  short_description: "Run autonomous Codex teams in tmux"
  default_prompt: "Use $polylane to build this project autonomously with supervised Codex workers in tmux."
policy:
  allow_implicit_invocation: true
YAML
)
assert_eq "openai-yaml-exact" "$expected" "$(cat "$ROOT/codex/agents/openai.yaml")"
finish
```

The exact metadata expected by the last assertion is:

```yaml
interface:
  display_name: "Polylane"
  short_description: "Run autonomous Codex teams in tmux"
  default_prompt: "Use $polylane to build this project autonomously with supervised Codex workers in tmux."
policy:
  allow_implicit_invocation: true
```

Run: `bash -n codex/tests/test-codex-skill-structure.sh`

Expected: exit 0; the test contains the complete metadata and direct-reference assertions.

- [ ] **Step 5: Run all four contract tests and verify RED (4 minutes)**

```bash
bash core/tests/test-workflow-contract.sh
bash core/tests/test-core-neutrality.sh
bash core/tests/test-adapter-policy.sh
bash codex/tests/test-codex-skill-structure.sh
```

Expected: absent workflow or old budget/Claude text failures.

- [ ] **Step 6: Add the complete platform-neutral workflow (5 minutes)**

Create `core/workflow/polylane-loop.md` with this complete body:

```markdown
# Polylane autonomous loop

## Contents

- Required adapter values
- State machine
- Discovery and locked strategy
- Cycle contract
- Verification and promotion
- Recovery and resume
- Completion

## Required adapter values

- `SKILL_ROOT` is the directory containing the loaded installed `SKILL.md`.
- `BIN` is exactly `$SKILL_ROOT/scripts`; helpers are never discovered through `PATH`.
- `AGENT_ID` is the adapter's exact manifest identity.
- The adapter supplies the model/effort resolver, prompt renderer, question surface,
  optional memory hook, and loop launcher.
- Every executable helper resolves its selected adapter through
  `POLYLANE_AGENT_ADAPTER`; a missing or mismatched adapter is recoverable work.

## State machine

The run state is `WORKING`, `COMPLETE`, or `WAITING_FOR_USER`. Only `COMPLETE` and
`WAITING_FOR_USER` are terminal. An internal error, exhausted local retry, invalid model,
or unavailable worker adds recovery work to the goal tree and leaves the run `WORKING`.
Usage reporting is informational: it cannot select state, gate a cycle, change
concurrency, trim scope, or alter the goal tree.

## Discovery and locked strategy

1. Turn the user's request into a testable product goal and a goal tree.
2. Ask only decisions that materially change the product. Use the adapter question
   surface and show one recommended default.
3. Freeze acceptance checks, scope boundaries, ownership seams, and the strategy digest.
4. Research only when a new knowledge-dependent decision exists. Record the query and
   evidence digest so the same question is not researched twice.

## Cycle contract

1. Allocate a stable `loop_id`, increasing cycle number, and unique run nonce.
2. Derive file-isolated builder lanes and one integrator. Run scope and seam gates before
   creating worktrees.
3. Render prompts through the selected adapter. Each prompt includes the locked goal,
   `OWN` and `FORBIDDEN` boundaries, frozen checks, verification evidence path, and the
   exact run nonce.
4. Launch through the adapter loop launcher and watch the adapter-owned session.
5. Accept a builder marker only when its lane name and `run=<run nonce>` match.
6. Accept an integrator verdict only when its run nonce matches and all frozen checks have
   evidence. Stale markers and stale verdicts are ignored.

## Verification and promotion

The integrator compares the candidate against the frozen acceptance checks, scope gate,
seam gate, and builder evidence. A `NO_GO` result preserves the exact base and lane commits
and creates repair work. A `GO` result names `base_ref`, `expected_base`, every exact lane
commit, and `integration_commit`.
Promotion is GO-only promotion: update the base only after the integrator proves `GO`,
then verify the promoted commit and clean only owned worktrees and merged lane branches.

After each legitimate result, write the cycle digest, decision digest, research digest,
and updated goal tree atomically. The digest records usage but never turns usage into a
stop condition.

## Recovery and resume

Treat missing workers, CLI errors, stale nonces, failed promotion, and interrupted cleanup
as explicit recovery goals. Exhaust adapter-approved model and process alternatives before
requesting user action. Resume from durable state: revalidate the strategy digest, current
base, run nonce, markers, worktrees, and cycle result before launching anything. Never
infer completion from a report timestamp.

## Completion

Enter `COMPLETE` only when every goal-tree leaf and frozen acceptance check is satisfied
on the promoted base. Enter `WAITING_FOR_USER` only when progress requires a user-owned
fact or authority after internal alternatives are exhausted. Otherwise remain `WORKING`
and continue with the next recovery or product cycle.
```

Expected: `wc -l core/workflow/polylane-loop.md` reports fewer than 100 lines and
`bash core/tests/test-workflow-contract.sh` advances past its workflow assertions.

- [ ] **Step 7: Add neutral discovery and interview references (5 minutes)**

Create `core/references/discovery.md`:

```markdown
# Discovery

## Purpose

Convert an initial request into a locked, testable product goal without assuming a
platform UI. Use the adapter question surface for every user-visible choice.

## Procedure

1. Restate the desired user outcome in one sentence.
2. List observable success checks and explicitly excluded outcomes.
3. Identify decisions whose answers change architecture, data ownership, safety, or
   delivery. Ask those decisions with one recommended default.
4. Research only unresolved facts that affect a current decision. Record source, query,
   conclusion, and evidence digest; reuse matching evidence later.
5. Freeze the accepted goal, checks, constraints, and strategy digest before lane design.

Return `DISCOVERY_LOCKED`, the strategy digest, and the unresolved user-owned facts.
```

Create `core/references/interview.md`:

```markdown
# Interview

Ask short decision questions through the adapter question surface. Each question contains
the decision, two or three mutually exclusive choices, and one clearly recommended
default. Explain the product consequence of each choice in one sentence. When autonomous
defaults are authorized, record the selected default and rationale; never fabricate a
credential, legal authority, irreversible external action, or private business fact.

Stop interviewing when the remaining uncertainty can be tested cheaply during a cycle.
Return the chosen values as stable key/value decisions for the strategy digest.
```

Expected: both files exist, contain no platform name, and pass
`rg -n '~/.claude|AskUserQuestion|/goal' core/references/{discovery,interview}.md` with no
matches.

- [ ] **Step 8: Add neutral planning, prompt, and lane references (5 minutes)**

Create `core/references/planning.md`:

```markdown
# Planning

Build a goal tree whose leaves are independently verifiable. For the next cycle, select
the smallest connected set of leaves that can produce a useful verified increment. Freeze
acceptance checks before deriving lanes. Each lane owns non-overlapping file globs; shared
hubs belong to one lane or to the integrator. Run scope and seam checks before launch.
Every lane names its inputs, exact outputs, forbidden files, verification command, and
DONE evidence path. The integrator owns cross-lane validation and GO/NO_GO only.
```

Create `core/references/prompt-blocks.md`:

```markdown
# Prompt blocks

Render these blocks in order through the adapter prompt renderer:

1. identity and one-cycle objective;
2. locked product goal and frozen acceptance checks;
3. `OWN` and `FORBIDDEN` file boundaries;
4. exact interfaces consumed and produced;
5. verification commands and evidence file;
6. run nonce and exact `STATUS: <lane> DONE run=<nonce>` marker;
7. recovery instruction: record evidence and return nonzero instead of widening scope.

The adapter may add platform syntax but may not remove or reinterpret a block.
```

Create `core/references/lane-template.md`:

```markdown
# Lane template

- Lane: `<stable-name>`
- Goal leaf: `<goal-tree-id>`
- OWN: `<newline-delimited globs>`
- FORBIDDEN: `<newline-delimited globs>`
- Consumes: `<exact interfaces>`
- Produces: `<exact interfaces>`
- Verify: `<exact commands and expected output>`
- Evidence: `docs/verify-<stable-name>.md`
- Done: `STATUS: <stable-name> DONE run=<run-nonce>`

The lane may change only OWN paths. A required cross-boundary edit is returned as a seam
finding for replanning; it is never made implicitly.
```

Expected: all three files exist and each contains an exact verification or ownership
contract.

- [ ] **Step 9: Add neutral skill catalog and scout references (4 minutes)**

Create `core/references/skill-catalog.md`:

```markdown
# Skill catalog

The adapter supplies newline-delimited installed skill roots. A skill is available only
when its directory and instruction file exist below one of those roots. Catalog entries
record canonical name, instruction path, domain tags, and evidence that it was loaded.
Never infer installation from a name mentioned in a prompt.
```

Create `core/references/skill-scout.md`:

```markdown
# Skill scout

Infer a lane domain from owned paths, map that domain to candidate capabilities, and ask
the selected adapter for installed skill roots. Bake only verified installed skills into
`lane-skills.json`. The prompt must name every baked skill and its purpose; prompt lint
fails when a baked skill is absent. External discovery is optional and occurs only for a
current missing capability, with repository, revision, license, and review evidence
recorded before installation is proposed.
```

Expected: `rg -n 'CLAUDE_SKILLS_DIR|~/.claude' core/references` returns no matches.

- [ ] **Step 10: Extend both adapters with the complete policy hook set (5 minutes)**

The stable hook interface is:

```text
polylane_adapter_models <purpose>            newline-delimited approved model ids
polylane_adapter_effort <purpose> <model>    normalized effort
polylane_adapter_price <model>               informational JSON or null
polylane_adapter_skill_roots                 newline-delimited roots
polylane_adapter_prompt_tokens               JSON question/goal/command vocabulary
polylane_adapter_error_class <agent> <text>  normalized failure class
```

Make this anchored edit to `codex/scripts/polylane-codex-agent.sh`:

```diff
diff --git a/codex/scripts/polylane-codex-agent.sh b/codex/scripts/polylane-codex-agent.sh
--- a/codex/scripts/polylane-codex-agent.sh
+++ b/codex/scripts/polylane-codex-agent.sh
@@
 #!/usr/bin/env bash
+CODEX_ADAPTER_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
@@
 polylane_adapter_effort() {
@@
 }
+polylane_adapter_models() {
+  local model
+  model=$($CODEX_ADAPTER_DIR/polylane-codex-model.sh resolve-model "${POLYLANE_CODEX_MODEL:-}" 2>/dev/null) || return 2
+  printf '%s\n' "$model"
+}
+polylane_adapter_price() { printf null; }
+polylane_adapter_skill_roots() {
+  printf '%s\n' "${CODEX_HOME:-$HOME/.codex}/skills" "$HOME/.agents/skills"
+}
+polylane_adapter_prompt_tokens() {
+  printf '%s\n' '{"objective":["GOAL","Objective"],"question":["Question"],"command":[],"approval_regex":"","approval_key":"","startup_regex":""}'
+}
```

Make this anchored edit to `claude-code/scripts/polylane-claude-agent.sh`:

```diff
diff --git a/claude-code/scripts/polylane-claude-agent.sh b/claude-code/scripts/polylane-claude-agent.sh
--- a/claude-code/scripts/polylane-claude-agent.sh
+++ b/claude-code/scripts/polylane-claude-agent.sh
@@
 polylane_adapter_error_class() { printf none; }
+polylane_adapter_models() {
+  case "$1" in
+    economy) printf '%s\n' claude-haiku-4-5 claude-fable-5 claude-sonnet-5 claude-opus-4-8 ;;
+    balanced) printf '%s\n' claude-sonnet-5 claude-fable-5 claude-haiku-4-5 claude-opus-4-8 ;;
+    *) printf '%s\n' claude-opus-4-8 claude-sonnet-5 claude-fable-5 claude-haiku-4-5 ;;
+  esac
+}
+polylane_adapter_price() {
+  case "$1" in
+    claude-fable-5*) printf '%s' '{"output_per_million":50}' ;;
+    claude-opus-4-8*) printf '%s' '{"output_per_million":25}' ;;
+    claude-sonnet-5*) printf '%s' '{"output_per_million":15}' ;;
+    claude-haiku-4-5*) printf '%s' '{"output_per_million":5}' ;;
+    *) printf null ;;
+  esac
+}
+polylane_adapter_skill_roots() {
+  printf '%s\n' "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}" \
+    "$HOME/.claude/plugins" "$HOME/.claude/plugins/marketplaces"
+}
+polylane_adapter_prompt_tokens() {
+  printf '%s\n' '{"objective":["GOAL","/goal"],"question":["AskUserQuestion"],"command":["/graphify","/ponytail"],"approval_regex":"Do you want to (run|proceed|make|create|delete|allow)|Do you want to proceed\\?","approval_key":"1","startup_regex":"Do you trust the files in this (folder|directory)|Trust this (folder|workspace)|Press Enter to continue|to get started"}'
+}
```

Expected: both adapters pass `bash -n`, and only adapter files contain platform model ids,
prices, homes, or prompt vocabulary.

- [ ] **Step 11: Patch the shared runner to consume adapter models, prices, and prompt tokens (5 minutes)**

Make these anchored edits to `core/scripts/polylane-run.sh`:

```diff
diff --git a/core/scripts/polylane-run.sh b/core/scripts/polylane-run.sh
--- a/core/scripts/polylane-run.sh
+++ b/core/scripts/polylane-run.sh
@@
-# polylane-run.sh — parallel-lane build engine (worktrees · tmux · git · claude)
+# polylane-run.sh — platform-neutral parallel-lane build engine
@@
-# Splits a manifest of lanes into git worktrees, launches one seeded `claude`
+# Splits a manifest into git worktrees, launches one seeded adapter process
@@
-polylane-run.sh — parallel-lane build engine (worktrees · tmux · git · claude)
+polylane-run.sh — parallel-lane build engine (worktrees · tmux · git)
@@
-  split worktrees -> launch seeded claude panes (tmux session 'polylane';
+  split worktrees -> launch seeded worker panes (tmux session 'polylane';
@@
-DEPS: tmux, claude, jq, git
+DEPS: tmux, jq, git, and the selected adapter CLI
@@
 preset_effort() {
-  case "$1" in
-    economy)     echo medium ;;
-    balanced)    echo high ;;
-    performance) echo high ;;
-    max)         echo xhigh ;;
-    *) return 1 ;;
-  esac
+  case "$1" in economy|balanced|performance|max) : ;; *) return 1 ;; esac
+  polylane_adapter_effort "$1" ""
 }
@@
 preset_model() {
-  local preset="$1" ladder m
-  case "$preset" in
-    economy)     ladder="claude-haiku-4-5 claude-fable-5 claude-sonnet-5 claude-opus-4-8" ;;
-    balanced)    ladder="claude-sonnet-5 claude-fable-5 claude-haiku-4-5 claude-opus-4-8" ;;
-    performance) ladder="claude-opus-4-8 claude-sonnet-5 claude-fable-5 claude-haiku-4-5" ;;
-    max)         ladder="claude-opus-4-8 claude-sonnet-5 claude-fable-5 claude-haiku-4-5" ;;
-    *) return 1 ;;
-  esac
-  for m in $ladder; do
+  local preset="$1" m
+  case "$preset" in economy|balanced|performance|max) : ;; *) return 1 ;; esac
+  while IFS= read -r m; do
     if model_available "$m"; then echo "$m"; return 0; fi
-  done
+  done <<EOF
+$(polylane_adapter_models "$preset")
+EOF
   echo "${AVAILABLE_MODELS[0]}"
 }
@@
-  tmpl=$(agent_template) || tmpl='claude --model {model} "$(cat {prompt})"'
+  tmpl=$(agent_template) || return 2
@@
 pane_stalled() {
-  local idx="$1" txt
+  local idx="$1" artifact
   [ "$idx" -ge 0 ] 2>/dev/null || return 1
-  txt=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p 2>/dev/null || true)
-  printf '%s' "$txt" | grep -qiE 'usage limit|Switch to usage credits|Upgrade your plan'
+  artifact=$(agent_artifact_for_pane "$idx") || return 1
+  [ "$(polylane_agent_error_class "$(agent_selected)" "$artifact")" = user_action ]
 }
@@
+adapter_prompt_value() {
+  polylane_adapter_prompt_tokens | jq -r --arg key "$1" '.[$key] // ""'
+}
+
 pane_awaiting_approval() {
-  local idx="$1" txt
+  local idx="$1" txt regex
@@
-  printf '%s' "$txt" | grep -qiE 'Do you want to (run|proceed|make|create|delete|allow)|Do you want to proceed\?' \
-    && printf '%s' "$txt" | grep -qE '❯?[[:space:]]*1\.[[:space:]]*Yes'
+  regex=$(adapter_prompt_value approval_regex)
+  [ -n "$regex" ] && printf '%s' "$txt" | grep -qiE "$regex"
 }
@@
 approval_check() {
-  local s name wt idx txt
+  local s name wt idx txt key
@@
-      if printf '%s' "$txt" | grep -qE '2\.[[:space:]]*Yes'; then
-        tmux send-keys -t "$TMUX_SESSION:0.$idx" '2' 2>/dev/null
-      else
-        tmux send-keys -t "$TMUX_SESSION:0.$idx" '1' 2>/dev/null
-      fi
+      key=$(adapter_prompt_value approval_key)
+      [ -n "$key" ] || continue
+      tmux send-keys -t "$TMUX_SESSION:0.$idx" "$key" 2>/dev/null
       echo "approval: auto-approved a safe prompt for lane '$name'"
@@
 startup_check() {
-  local s name wt idx txt
+  local s name wt idx txt regex key
@@
-    if printf '%s' "$txt" | grep -qiE 'Do you trust the files in this (folder|directory)|Trust this (folder|workspace)'; then
-      # option 1 = "Yes, proceed" — our own worktree, always trusted
-      tmux send-keys -t "$TMUX_SESSION:0.$idx" '1' 2>/dev/null
-      tmux send-keys -t "$TMUX_SESSION:0.$idx" Enter 2>/dev/null
-      echo "startup: lane '$name' — answered folder-trust dialog"
-    elif printf '%s' "$txt" | grep -qiE 'Press Enter to continue|to get started'; then
+    regex=$(adapter_prompt_value startup_regex)
+    if [ -n "$regex" ] && printf '%s' "$txt" | grep -qiE "$regex"; then
+      key=$(adapter_prompt_value approval_key)
+      [ -z "$key" ] || tmux send-keys -t "$TMUX_SESSION:0.$idx" "$key" 2>/dev/null
       tmux send-keys -t "$TMUX_SESSION:0.$idx" Enter 2>/dev/null
-      echo "startup: lane '$name' — cleared an onboarding banner"
+      echo "startup: lane '$name' — cleared adapter onboarding"
     fi
@@
-FALLBACK_LADDER="claude-fable-5 claude-opus-4-8 claude-sonnet-5 claude-haiku-4-5"
 next_fallback_model() {
-  local cur="$1" past=0 m
-  for m in $FALLBACK_LADDER; do
+  local cur="$1" past=0 m models
+  models=$(polylane_adapter_models fallback)
+  for m in $models; do
@@
-    for m in $FALLBACK_LADDER; do
+    for m in $models; do
@@
 model_out_price() {
-  case "$1" in
-    claude-fable-5*)   echo 50 ;;
-    claude-opus-4-8*)  echo 25 ;;
-    claude-sonnet-5*)  echo 15 ;;
-    claude-haiku-4-5*) echo 5 ;;
-    *)                 echo "" ;;
-  esac
+  local data
+  data=$(polylane_adapter_price "$1") || data=null
+  [ -n "$data" ] || data=null
+  printf '%s' "$data" | jq -r 'if type=="object" then .output_per_million // empty else empty end'
 }
```

Also replace every remaining user-facing `claude` noun in this shared file with `worker`
using these anchored edits:

```diff
diff --git a/core/scripts/polylane-run.sh b/core/scripts/polylane-run.sh
--- a/core/scripts/polylane-run.sh
+++ b/core/scripts/polylane-run.sh
@@
-# launch — one seeded claude pane per lane
+# launch — one seeded worker pane per lane
@@
-# prefix claude ignores if unused).
+# prefix an adapter may ignore if unused).
@@
-# assert_prompt PATH NAME : fail loudly (before any pane opens) if a lane's prompt
+# assert_prompt PATH NAME : fail loudly before any pane opens if a lane's prompt
@@
-# dead     -> pane dropped to a shell (claude exited) -> respawn same seed
+# dead     -> pane dropped to a shell (worker exited) -> respawn same seed
```

Expected: `bash -n core/scripts/polylane-run.sh` exits 0 and the runner contains no
platform model ladder, price, home path, or executable template.

Make this anchored edit to `core/scripts/polylane-supervisor.sh` so the independent
supervisor uses the same adapter-owned safe-approval key:

```diff
diff --git a/core/scripts/polylane-supervisor.sh b/core/scripts/polylane-supervisor.sh
--- a/core/scripts/polylane-supervisor.sh
+++ b/core/scripts/polylane-supervisor.sh
@@
 drain_approvals() {
-  local name wt idx txt
+  local name wt idx txt key
@@
-      if printf '%s' "$txt" | grep -qE '2\.[[:space:]]*Yes'; then
-        tmux send-keys -t "$TMUX_SESSION:0.$idx" '2' 2>/dev/null || true
-      else
-        tmux send-keys -t "$TMUX_SESSION:0.$idx" '1' 2>/dev/null || true
-      fi
+      key=$(adapter_prompt_value approval_key)
+      [ -n "$key" ] || continue
+      tmux send-keys -t "$TMUX_SESSION:0.$idx" "$key" 2>/dev/null || true
       sup_log "auto-approved a safe prompt for lane '$name'"
```

Expected: `bash -n core/scripts/polylane-supervisor.sh` exits 0.

- [ ] **Step 12: Patch dashboard, outcomes, prompt lint, and scout to consume hooks (5 minutes)**

Make these anchored edits:

```diff
diff --git a/core/scripts/polylane-dashboard.sh b/core/scripts/polylane-dashboard.sh
--- a/core/scripts/polylane-dashboard.sh
+++ b/core/scripts/polylane-dashboard.sh
@@
 TMUX_SESSION="${POLYLANE_SESSION:-polylane}"
 STALL_SECS="${POLYLANE_STALL_SECS:-120}"
-ERR_RE='API Error|Internal server error|overloaded|rate.?limit|Connection error|network error|5[0-9][0-9] (Internal|error)|status\.claude\.com'
+SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
+. "$SCRIPT_DIR/polylane-agent.sh"
+[ -n "${POLYLANE_AGENT_ADAPTER:-}" ] || { echo "polylane-dashboard: adapter required" >&2; return 2 2>/dev/null || exit 2; }
+. "$POLYLANE_AGENT_ADAPTER"
+text_failed() {
+  [ -n "${POLYLANE_AGENT:-}" ] && [ -f "$1" ] &&
+    [ "$(polylane_agent_error_class "$POLYLANE_AGENT" "$1")" != none ]
+}
+attempt_artifact_for_prompt() {
+  local prompt=$1 claim=${POLYLANE_CLAIM_TOKEN:-} generation=${POLYLANE_RUNNER_GENERATION:-}
+  local attempt=${POLYLANE_ATTEMPT:-}
+  case "$claim" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac
+  case "$generation:$attempt" in *[!0-9:]*|:*|*:) return 1 ;; esac
+  printf '%s/agent-errors/%s/g%s/a%s/%s.json\n' \
+    "${POLYLANE_RUNTIME_DIR:-$PROJECT_ROOT/.polylane/runtime}" "$claim" \
+    "$generation" "$attempt" "${prompt##*/}"
+}
@@
-  L_NAMES=(); L_MODELS=(); L_WTS=()
+  L_NAMES=(); L_MODELS=(); L_WTS=(); L_PROMPTS=()
@@
     L_WTS+=("$(abs_path "$(jq -r ".lanes[$i].worktree // \"\"" "$MANIFEST")")")
+    L_PROMPTS+=("$(abs_path "$(jq -r ".lanes[$i].prompt_file // \"\"" "$MANIFEST")")")
@@
     L_WTS+=("$(abs_path "$(jq -r '.integrator.worktree // ""' "$MANIFEST")")")
+    L_PROMPTS+=("$(abs_path "$(jq -r '.integrator.prompt_file // ""' "$MANIFEST")")")
@@
-  if [ -n "$txt" ] && printf '%s' "$txt" | grep -qiE "$ERR_RE"; then
+  if artifact=$(attempt_artifact_for_prompt "${L_PROMPTS[$i]}") && text_failed "$artifact"; then
@@
-    R_MODEL=(claude-sonnet-5 claude-fable-5 claude-haiku-4-5 claude-opus-4-8)
+    R_MODEL=()
+    while IFS= read -r model; do [ -n "$model" ] && R_MODEL+=("$model"); done <<EOF
+$(polylane_adapter_models demo)
+EOF
+    while [ "${#R_MODEL[@]}" -lt 4 ]; do R_MODEL+=("${R_MODEL[0]:-adapter-model}"); done
diff --git a/core/scripts/polylane-outcomes.sh b/core/scripts/polylane-outcomes.sh
--- a/core/scripts/polylane-outcomes.sh
+++ b/core/scripts/polylane-outcomes.sh
@@ -15,8 +15,12 @@
 #   hub add <path> | hub list                  manage the hub-file registry
 # Pure bash-3.2 + jq; main-guarded.
 set -euo pipefail
 command -v jq >/dev/null 2>&1 || { echo "polylane-outcomes: jq required" >&2; exit 1; }
+SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
+. "$SCRIPT_DIR/polylane-agent.sh"
+[ -n "${POLYLANE_AGENT_ADAPTER:-}" ] || { echo "polylane-outcomes: adapter required" >&2; exit 2; }
+. "$POLYLANE_AGENT_ADAPTER"
-
+
 OUT_F="${POLYLANE_OUTCOMES:-docs/polylane/outcomes.jsonl}"
 HUB_F="${POLYLANE_HUBS:-docs/polylane/hubs.txt}"
 RISK_THRESHOLD="${POLYLANE_RISK_THRESHOLD:-50}"   # percent NO-GO above which predict trips
@@ -91,12 +95,12 @@
-# tune SIG : cheapest model (haiku<sonnet<opus<fable) that has EVER cleared this shape.
+# tune SIG against adapter-declared economy order; no shared model names are hard-coded.
 tune() {
-  local sig="$1"
-  [ -s "$OUT_F" ] || { echo "claude-haiku-4-5"; return; }
-  local winner
-  winner=$(jq -rs --arg s "$sig" '
-    def rank: {"claude-haiku-4-5":1,"claude-sonnet-5":2,"claude-opus-4-8":3,"claude-fable-5":4};
-    map(select(.sig==$s and .verdict=="GO"))
-    | map(.model) | unique
-    | sort_by(rank[.] // 99) | .[0] // empty' "$OUT_F")
-  [ -n "$winner" ] && printf '%s\n' "$winner" || echo "claude-sonnet-5"
+  local sig="$1" model winners
+  winners=$(jq -rs --arg s "$sig" 'map(select(.sig==$s and .verdict=="GO")) | map(.model) | unique[]' "$OUT_F" 2>/dev/null || true)
+  while IFS= read -r model; do
+    [ -n "$model" ] || continue
+    if [ ! -s "$OUT_F" ] || printf '%s\n' "$winners" | grep -qxF "$model"; then printf '%s\n' "$model"; return; fi
+  done <<EOF
+$(polylane_adapter_models economy)
+EOF
+  polylane_adapter_models balanced | sed -n '1p'
 }
diff --git a/core/scripts/polylane-promptlint.sh b/core/scripts/polylane-promptlint.sh
--- a/core/scripts/polylane-promptlint.sh
+++ b/core/scripts/polylane-promptlint.sh
@@
 set -euo pipefail
+SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
+. "$SCRIPT_DIR/polylane-agent.sh"
+[ -n "${POLYLANE_AGENT_ADAPTER:-}" ] || { echo "polylane-promptlint: adapter required" >&2; exit 2; }
+. "$POLYLANE_AGENT_ADAPTER"
@@
 lint_one() {
-  local f="$1" lane="${2:-$(basename "$1" .txt)}" miss=""
+  local f="$1" lane="${2:-$(basename "$1" .txt)}" miss="" objective
@@
-  grep -qiE 'GOAL|/goal' "$f"        || miss="$miss objective(GOAL)"
+  objective=$(polylane_adapter_prompt_tokens | jq -r '.objective[]?' | paste -sd '|' -)
+  [ -n "$objective" ] && grep -qiE "$objective" "$f" || miss="$miss objective"
diff --git a/core/scripts/polylane-scout.sh b/core/scripts/polylane-scout.sh
--- a/core/scripts/polylane-scout.sh
+++ b/core/scripts/polylane-scout.sh
@@
-    *test*|*spec*|*__tests__*)                                 echo test ;;
+    *test*|*spec*)                                              echo test ;;
@@
 set -euo pipefail
+SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
+. "$SCRIPT_DIR/polylane-agent.sh"
+[ -n "${POLYLANE_AGENT_ADAPTER:-}" ] || { echo "polylane-scout: adapter required" >&2; exit 2; }
+. "$POLYLANE_AGENT_ADAPTER"
@@
-# installed SKILL : 0 iff a skill dir OR a plugin of that name exists. Reads
-# CLAUDE_SKILLS_DIR at CALL time (not source time) so tests can point it at a fixture.
 installed() {
-  local s="${1%%:*}" dir="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"   # design:x -> design
-  [ -d "$dir/$s" ] && return 0
-  [ -d "$dir/$1" ] && return 0
-  ls -d "$HOME"/.claude/plugins/*/"$s" >/dev/null 2>&1 && return 0
-  ls -d "$HOME"/.claude/plugins/marketplaces/*"$s"* >/dev/null 2>&1 && return 0
+  local wanted=$1 short="${1%%:*}" root
+  while IFS= read -r root; do
+    [ -n "$root" ] || continue
+    [ -d "$root/$wanted" ] && return 0
+    [ -d "$root/$short" ] && return 0
+    find "$root" -type d \( -name "$wanted" -o -name "$short" \) -print -quit 2>/dev/null | grep -q . && return 0
+  done <<EOF
+$(polylane_adapter_skill_roots)
+EOF
   return 1
 }
diff --git a/core/tests/helpers.sh b/core/tests/helpers.sh
--- a/core/tests/helpers.sh
+++ b/core/tests/helpers.sh
@@
 RUNNER="$TESTS_DIR/../scripts/polylane-run.sh"
+# Shared legacy tests select the compatibility adapter explicitly. Production core still
+# requires its caller to choose an adapter and never guesses a platform path.
+export POLYLANE_AGENT_ADAPTER="${POLYLANE_AGENT_ADAPTER:-$TESTS_DIR/../../claude-code/scripts/polylane-claude-agent.sh}"
```

Expected: all four scripts pass `bash -n`; the scan in
`core/tests/test-adapter-policy.sh` reports no platform policy in core.

- [ ] **Step 13: Add complete Codex runtime, prompt, and model references (5 minutes)**

Create `codex/references/codex-runtime.md`:

```markdown
# Codex runtime

Resolve every helper relative to the installed skill. `SKILL_ROOT` contains `SKILL.md` and
`BIN` is exactly `$SKILL_ROOT/scripts`. A one-cycle foundation run invokes
`$BIN/polylane-codex.sh <manifest>`; the persistent plan replaces this entry with
`$BIN/polylane-codex-loop.sh` without changing the common workflow.

Every manifest sets exact `"agent":"codex"` and a nonempty unique `run_id`. Worker
processes execute:

`codex exec --json --sandbox workspace-write -c approval_policy=never --model <id> -c model_reasoning_effort=<effort> -`

The rendered prompt is streamed through stdin. Attach with the session name printed by
the launcher; foundation sessions use the manifest-owned session and the persistent loop
uses `tmux attach -t polylane-<loop-id>`. A missing login or organization permission is
reported as user-action evidence only after internal alternatives are exhausted.

The Codex adapter resolves and freezes one physical absolute Codex executable before tmux
launch. It preflights every external used by resolution, capture, hashing, and parsing:
`awk`, `basename`, `chmod`, `cp`, `date`, `dirname`, `grep`, `head`, `jq`, `ln`, `mkdir`,
`od`, `python3`, `readlink`, `rm`, `sleep`, `stat`, `tr`, `uname`, `wc`, plus either
`shasum` or `sha256sum`. FIFO creation and bounded teeing are Python-helper operations, not
external `mkfifo`/`tee` dependencies. The exec shim rechecks the same set before creating an
artifact directory.
```

Create `codex/references/codex-prompts.md`:

```markdown
# Codex prompts

Use plain imperative text. Include identity, locked goal, frozen acceptance checks, OWN,
FORBIDDEN, exact interfaces, verification commands, evidence path, run nonce, and DONE or
verdict marker. Require `superpowers:test-driven-development` for implementation work and
`superpowers:verification-before-completion` before any DONE marker. Ask user decisions in
normal chat with two or three choices and a clearly recommended default. Do not emit
another platform's tool names, homes, hooks, or command syntax.
```

Create `codex/references/codex-models.md`:

```markdown
# Codex models

All model selection goes through `scripts/polylane-codex-model.sh`. `resolve-model`
prefers an explicit validated id, then `POLYLANE_CODEX_MODEL`, then the top-level `model`
in the active Codex config. `resolve-effort` prefers explicit, environment, top-level
config, then the caller default. Allowed efforts are `low`, `medium`, `high`, and `xhigh`.
The package does not scan account secrets and does not maintain an independent model id
inventory. If one approved model is available, intensity changes effort only.
```

Expected: each file is under 100 lines and contains no second-level reference link.

- [ ] **Step 14: Add adapter package descriptors and policy hooks (5 minutes)**

Create `codex/package.json`:

```json
{
  "schema_version": 1,
  "name": "codex",
  "reference_namespace": "codex",
  "asset_namespace": "codex",
  "scripts_dir": "scripts",
  "references_dir": "references",
  "assets_dir": null,
  "policy_hook": "scripts/polylane-codex-package-policy.sh",
  "metadata": [{"source":"agents/openai.yaml","target":"agents/openai.yaml"}]
}
```

Create executable `codex/scripts/polylane-codex-package-policy.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
[ "${1:-}" = validate ] && [ -d "${2:-}" ] || {
  echo "usage: polylane-codex-package-policy.sh validate <package>" >&2; exit 2;
}
root=$2
command -v find >/dev/null 2>&1 && command -v grep >/dev/null 2>&1 || exit 2
bad=$(find "$root" -type f -print0 | while IFS= read -r -d '' file; do
  [ "${file#"$root/"}" != scripts/polylane-codex-package-policy.sh ] || continue
  if match=$(LC_ALL=C grep -nE \
    '~/.claude|CLAUDE_|ANTHROPIC_|AskUserQuestion|--full-auto|/goal|/graphify|/ponytail|permission-mode|claude --|claude-(opus|sonnet|haiku|fable)' \
    "$file" 2>/dev/null); then
    printf '%s:%s\n' "${file#"$root/"}" "$match"
  else
    rc=$?; [ "$rc" = 1 ] || exit 6
  fi
done)
[ -z "$bad" ] || { printf '%s\n' "$bad" >&2; exit 6; }
```

Create `claude-code/package.json`:

```json
{
  "schema_version": 1,
  "name": "claude-code",
  "reference_namespace": "claude-code",
  "asset_namespace": "claude-code",
  "scripts_dir": "scripts",
  "references_dir": "references",
  "assets_dir": "assets",
  "policy_hook": "scripts/polylane-claude-package-policy.sh",
  "metadata": []
}
```

Create executable `claude-code/scripts/polylane-claude-package-policy.sh`:

```bash
#!/usr/bin/env bash
set -eu
[ "${1:-}" = validate ] && [ -d "${2:-}" ] || {
  echo "usage: polylane-claude-package-policy.sh validate <package>" >&2; exit 2;
}
[ -s "$2/SKILL.md" ] && [ -s "$2/adapter/package.json" ] || exit 6
```

Create `codex/tests/test-codex-package-policy.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
HOOK="$ROOT/codex/scripts/polylane-codex-package-policy.sh"
make_tmpdir
mkdir -p "$TEST_TMPDIR/good/scripts" "$TEST_TMPDIR/good/adapter"
printf 'clean\n' > "$TEST_TMPDIR/good/SKILL.md"
cp "$ROOT/codex/package.json" "$TEST_TMPDIR/good/adapter/package.json"
cp "$HOOK" "$TEST_TMPDIR/good/scripts/"
assert_ok "clean-package-policy" "$HOOK" validate "$TEST_TMPDIR/good"
printf '%s\n' '~/.claude/skills' > "$TEST_TMPDIR/good/leak.txt"
assert_rc "foreign-policy-rejected" 6 "$HOOK" validate "$TEST_TMPDIR/good"
rm "$TEST_TMPDIR/good/leak.txt"; mkdir "$TEST_TMPDIR/good/.hidden"
printf '%s\n' 'CLAUDE_SECRET_SHOULD_NOT_SHIP' > "$TEST_TMPDIR/good/.hidden/leak"
PATH="$(dirname "$(command -v bash)"):$(dirname "$(command -v find)"):$(dirname "$(command -v grep)")" \
  assert_rc "hidden-file-scan-does-not-depend-on-rg" 6 \
  /usr/bin/env bash "$HOOK" validate "$TEST_TMPDIR/good"
assert_eq "codex-ref-namespace" codex "$(jq -r .reference_namespace "$ROOT/codex/package.json")"
assert_eq "claude-ref-namespace" claude-code \
  "$(jq -r .reference_namespace "$ROOT/claude-code/package.json")"
finish
```

Run:

```bash
chmod +x codex/scripts/polylane-codex-package-policy.sh \
  claude-code/scripts/polylane-claude-package-policy.sh
bash codex/tests/test-codex-package-policy.sh
```

Expected: exit 0; platform policy lives only in the selected adapter hook, and both
descriptors assign disjoint reference/asset namespaces.

- [ ] **Step 15: Replace the Codex skill with the complete progressive-disclosure router (5 minutes)**

Replace `codex/SKILL.md` with:

```markdown
---
name: polylane
description: Use when a user wants a project strategized and built autonomously by supervised parallel Codex workers in tmux, including vague product ideas, parallel implementation requests, resumed builds, and autonomous build loops.
---

# Polylane for Codex

Resolve this file's directory as `SKILL_ROOT`; set `BIN` to exactly
`$SKILL_ROOT/scripts`. Never locate Polylane helpers through `PATH`.

On every invocation, read [the common loop](references/polylane-loop.md) and the phase's
needed direct Codex reference: [runtime](references/codex-runtime.md),
[prompts](references/codex-prompts.md), or [models](references/codex-models.md). Do not
load unrelated references.

Set the manifest identity to exact `agent:codex`. Resolve model and effort with
`$BIN/polylane-codex-model.sh`. Render plain prompts through stdin. Implementation lanes
must use `superpowers:test-driven-development`; every lane and integrator must use
`superpowers:verification-before-completion` before writing its nonce-tagged marker.

Ask material decisions inline with one recommended default. If durable state shows pending
input, present that input and return without launching another cycle. For foundation
one-cycle execution, run `$BIN/polylane-codex.sh <manifest>`. When
`$BIN/polylane-codex-loop.sh` exists, use it as the persistent launch/resume entry instead.

Surface the exact owned watch command printed by the launcher. After a legitimate final
result, deliver the final summary once using the durable delivery contract; otherwise
remain in the common workflow's recovery/resume path.
```

Expected: `wc -l codex/SKILL.md` is below 500 and its frontmatter has only `name` and
`description`.

- [ ] **Step 16: Regenerate exact Codex UI metadata (3 minutes)**

Run exactly:

```bash
python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-creator/scripts/generate_openai_yaml.py" \
  codex \
  --interface 'display_name=Polylane' \
  --interface 'short_description=Run autonomous Codex teams in tmux' \
  --interface 'default_prompt=Use $polylane to build this project autonomously with supervised Codex workers in tmux.'
```

Expected: exit 0 with `[OK] Created agents/openai.yaml`.

Make this anchored edit after generation:

```diff
diff --git a/codex/agents/openai.yaml b/codex/agents/openai.yaml
--- a/codex/agents/openai.yaml
+++ b/codex/agents/openai.yaml
@@
   default_prompt: "Use $polylane to build this project autonomously with supervised Codex workers in tmux."
+policy:
+  allow_implicit_invocation: true
```

Expected: the file byte-for-byte matches the YAML fixture in Step 4.

- [ ] **Step 17: Replace the Claude skill and root compatibility link (5 minutes)**

Replace `claude-code/SKILL.md` with:

```markdown
---
name: polylane
description: Use when a user wants a project strategized and built autonomously by supervised parallel Claude Code workers in tmux, including discovery, parallel implementation, resume, and autonomous build loops.
---

# Polylane for Claude Code

Resolve this file's directory as `SKILL_ROOT`; set `BIN` to exactly
`$SKILL_ROOT/scripts`. Read `references/polylane-loop.md` on invocation, then load only the
needed direct platform reference: `references/discovery.md`, `references/interview.md`,
`references/model-selection.md`, or `references/prompt-blocks.md`.

Set `agent:claude`, use the adapter's question UI, prompt preamble, model probe, and
optional memory hook, and launch through `$BIN/polylane-claude.sh`. Preserve the common
nonce, verification, GO-only promotion, recovery, and resume contracts exactly. Use
`superpowers:test-driven-development` for implementation and
`superpowers:verification-before-completion` before DONE. Never copy the common workflow
into this file.
```

Replace the root skill with a relative link:

```bash
rm SKILL.md
ln -s claude-code/SKILL.md SKILL.md
```

Expected: `readlink SKILL.md` prints `claude-code/SKILL.md`; root
`bin/polylane-run.sh` still points to `../claude-code/scripts/polylane-claude-compat.sh`.

- [ ] **Step 18: Run the five focused tests and verify GREEN (5 minutes)**

```bash
bash core/tests/test-workflow-contract.sh
bash core/tests/test-core-neutrality.sh
bash core/tests/test-adapter-policy.sh
bash codex/tests/test-codex-skill-structure.sh
bash codex/tests/test-codex-package-policy.sh
```

Expected: all commands exit 0. Neutrality prints `PASS core-neutrality`; adapter policy
reports both `runner-a` and `runner-b`; skill structure reports `PASS openai-yaml-exact`.

- [ ] **Step 19: Run the aggregate suite (5 minutes)**

Run: `tests/run.sh`

Expected: exit 0 with zero failed test files.

- [ ] **Step 20: Commit the neutral workflow and thin skills (2 minutes)**

Run:

```bash
git add SKILL.md core/workflow core/references core/tests/test-workflow-contract.sh \
  core/tests/test-core-neutrality.sh core/tests/test-adapter-policy.sh \
  core/scripts/polylane-run.sh core/scripts/polylane-supervisor.sh \
  core/scripts/polylane-dashboard.sh core/scripts/polylane-outcomes.sh \
  core/scripts/polylane-promptlint.sh core/scripts/polylane-scout.sh \
  codex/SKILL.md codex/package.json codex/agents/openai.yaml codex/references \
  codex/tests/test-codex-skill-structure.sh codex/tests/test-codex-package-policy.sh \
  codex/scripts/polylane-codex-agent.sh codex/scripts/polylane-codex-package-policy.sh \
  claude-code/SKILL.md claude-code/package.json claude-code/references \
  claude-code/scripts/polylane-claude-agent.sh \
  claude-code/scripts/polylane-claude-package-policy.sh
git commit -m "refactor: make the autonomous workflow platform-neutral"
```

Expected: exit 0 with commit subject
`refactor: make the autonomous workflow platform-neutral`.

---

### Task 5: Assemble Deterministic Atomic Packages

**Files:**
- Create: `core/scripts/polylane-package.sh`
- Create: `core/scripts/polylane-procargs-macos`
- Create: `core/scripts/polylane-install-guard.sh`
- Create: `codex/tests/test-codex-install.sh`
- Create: `claude-code/tests/test-claude-install.sh`
- Create: `core/tests/test-package-parity.sh`
- Create: `core/tests/test-package-legacy-migration.sh`
- Create: `core/tests/test-package-activation.sh`
- Modify: `core/tests/helpers.sh`
- Modify: `codex/install.sh`, `claude-code/install.sh`
- Modify: `core/scripts/polylane-doctor.sh`, `core/tests/test-doctor.sh`
- Modify: `codex/scripts/polylane-codex.sh`, `claude-code/scripts/polylane-claude.sh`

**Interfaces:**
- `polylane-package.sh <adapter> <absolute-destination>` loads that adapter's validated
  `package.json`, assembles an atomic self-contained package, and writes the shared-core
  revision/manifest plus a deterministic `.polylane-package-manifest` sealing every shipped
  regular file's relative path, bytes, type, and normalized executable mode.
- `polylane-package.sh certify-activation <activation-journal.json>` validates the current
  candidate and atomically commits its certification transaction.
- `polylane-package.sh rollback <activation-journal.json>` validates the recorded prior
  and candidate releases, accepts only `PREPARED`/`PUBLISHED`, and under the destination
  lock restores the prior release (or removes a first-install candidate pointer) with
  pointer and state CAS. It rejects `COMMITTED`.
- `polylane-package.sh wait-activation <activation-journal.json>` is a bounded monitor for
  the independent guard. It recovers a dead/expired `PREPARED` publisher, replaces a dead
  `PUBLISHED` guard until owner death/deadline, and reconstructs malformed or unknown-state
  journals from an authenticated sealed copy, then re-enters validation until a terminal
  result is reached.
- `polylane-package.sh migration-preflight <absolute-destination>` exits 0 only when a
  legacy regular-directory destination has no owned Polylane tmux session, runtime actor,
  or live process whose executable/script path resolves inside it; exit 8 changes nothing.
- Both installers accept `--user`, `--repo`, `--dest <absolute-path>`, and
  `--print-user-dest` (read-only exact destination output), plus
  `--activation-record <absolute-json> --certification-owner-pid <pid>` for a caller that
  must certify after publication; the two guarded-activation flags are required together.

#### Package acceptance contract (normative)

Codex installation assertions scan the whole package, not just `SKILL.md`:

```bash
assert_ok "codex-launcher" test -x "$DEST/scripts/polylane-codex.sh"
assert_ok "codex-adapter" test -x "$DEST/scripts/polylane-codex-agent.sh"
assert_ok "codex-packaged-fs-helper" test -x "$DEST/scripts/polylane-fs.py"
assert_eq "codex-packaged-helper-resolution" "$DEST/scripts/polylane-fs.py" \
  "$(bash -c '. "$1"; printf "%s" "$POLYLANE_CODEX_FS_HELPER"' _ \
    "$DEST/scripts/polylane-codex-agent.sh")"
assert_ok "runner" test -x "$DEST/scripts/polylane-run.sh"
assert_ok "revision" test -s "$DEST/.polylane-core-revision"
assert_ok "agent-metadata" test -s "$DEST/agents/openai.yaml"
assert_ok "concise-skill" test "$(wc -l < "$DEST/SKILL.md")" -lt 500
assert_ok "workflow-reference" test -s "$DEST/references/polylane-loop.md"
assert_ok "adapter-reference" test -s "$DEST/references/codex/codex-prompts.md"
assert_ok "whole-package-seal" test -s "$DEST/.polylane-package-manifest"
bad=$(rg -n '~/.claude|CLAUDE_|ANTHROPIC_|AskUserQuestion|--full-auto|/goal|/graphify|/ponytail|permission-mode|claude --|claude-(opus|sonnet|haiku|fable)' "$DEST" || true)
assert_eq "codex-package-neutral" "" "$bad"
```

Run the installed launcher with `PATH` containing only fixture dependencies and a fake
supervisor inside `$DEST/scripts`; assert it succeeds without any repository path or
`~/.claude` fallback. This proves helper resolution is relative to the installed skill.

Claude package tests require its launcher, adapter, model probe, memory bridge, hooks, and
recorded revision. `core/tests/test-package-parity.sh` packages both adapters, reads both
revisions, and compares hashes for every installed path originating in `core/scripts`,
`core/references`, optional existing `core/assets`, and `core/workflow`.

Tamper any shipped adapter file in a temporary package and assert its packaged doctor reports
`core-package: mixed`; an untouched package reports `core-package: match`.

Exercise both paths explicitly. Create a complete version-A **regular legacy directory** by
dereferencing a validated package and prove its launcher works; attempt B with
`POLYLANE_PACKAGE_FAULT=after-legacy-rename` and assert the rollback guard restores that same
usable directory with no mixed manifest. Separately install A into the normal versioned-
release/symlink layout, attempt B with `POLYLANE_PACKAGE_FAULT=before-pointer-swap`, and
assert the public pointer never moved. Finally install B successfully while a reader
repeatedly opens `SKILL.md` and the launcher; on the normal layout it may observe only
complete A or complete B, never a missing or mixed tree. Kill the legacy migration publisher
with SIGKILL while its independent rollback guard remains alive and assert the guard restores
A before exiting.
Start two installers for the same destination and assert a PID/start-token-owned publish
lock serializes them. Build each candidate lock in a unique private initializer directory,
write its complete owner record there, and publish it with one atomic rename; a killed
initializer therefore never exposes an ownerless public lock. To reclaim a stale public
lock, hard-link a complete mode-0400 `.close.<claim-nonce>` record into that exact directory.
Only the live claimant named by that marker may close the still-matching owner snapshot;
concurrent claimants use disjoint markers, and a successor owner can never be removed by a
closer anchored to the predecessor.
Install B with an activation journal and a certification-owner PID/start token, then
simulate a failed post-publication certification. The publisher must durably write
`PREPARED` and start the independent guard before swapping the pointer; after the swap the
journal may advance to `PUBLISHED`. `rollback` must restore A only while B is still the
current pointer. It must reject a stale journal after a concurrent C activation, and a
failed first install must leave no public pointer. The journal contains canonical
destination, prior release or `null`, candidate release, activation nonce, owner PID/start
token/deadline, publisher PID/start token/preparation deadline, guard PID/start token/live-
ready proof, state, and both manifest hashes; no path is accepted from an unvalidated or
caller-edited journal.

Inject SIGKILL during guard bootstrap and require `wait-activation` to recover the sealed
`PREPARED` record to `ROLLED_BACK` without moving the prior pointer. Also kill the publisher
immediately before and after pointer swap. While state is
`PREPARED`, the guard watches only that publisher and rolls back if it dies, including the
post-swap/pre-state-CAS window. Once state is `PUBLISHED`, kill the certification owner (or
let its bounded deadline expire) and require rollback. Kill the certifier immediately before
the single atomic commit publication and require rollback; kill it immediately after that
publication and require `COMMITTED` to retain B. Rollback then returns 9. These results
cannot depend on `EXIT`, `INT`, or `TERM` handling.

For a legacy regular-directory destination, create fixtures for an owned active tmux run,
a detached recorded runtime actor, and a live process executing a helper below that
directory. `migration-preflight` and the installer must exit 8 before rename/pointer
mutation for each. After all owned users reach teardown, the migration succeeds under a
destination-scoped maintenance lock. A concurrent skill launch sees the maintenance record
and retries after its persisted deadline rather than starting from a half-migrated tree.
The test explicitly permits the unavoidable two-rename lookup gap on this first macOS/POSIX
migration and requires it to remain bounded to those adjacent rename operations; do not
label this legacy conversion atomic. Normal symlink-to-symlink upgrades remain atomic.

- [ ] **Step 1: Add the complete Codex package smoke test (5 minutes)**

Create `codex/tests/test-codex-install.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
DEST="$TEST_TMPDIR/codex-skill"
PKG="$ROOT/core/scripts/polylane-package.sh"

ln -s "$ROOT" "$TEST_TMPDIR/repository-alias"
assert_rc "reject-repository-alias" 2 "$PKG" codex "$TEST_TMPDIR/repository-alias"
assert_rc "reject-final-dot" 2 "$PKG" codex "$TEST_TMPDIR/."
mkdir -p "$TEST_TMPDIR/path-component"
assert_rc "reject-final-dotdot" 2 "$PKG" codex "$TEST_TMPDIR/path-component/.."

printed=$(CODEX_HOME="$TEST_TMPDIR/codex-home" "$ROOT/codex/install.sh" --print-user-dest)
assert_eq "print-user-dest" "$TEST_TMPDIR/codex-home/skills/polylane" "$printed"
assert_ok "install-a" "$ROOT/codex/install.sh" --dest "$DEST"
A=$(readlink "$DEST")
assert_ok "verify-a" "$PKG" verify-package "$A"
assert_ok "install-b-atomic-replace" "$ROOT/codex/install.sh" --dest "$DEST"
B=$(readlink "$DEST")
assert_not_contains "a-to-b-differs" "$A" "$B"
assert_ok "public-pointer" test -L "$DEST"
assert_ok "verify-b" "$PKG" verify-package "$B"
nested=$(find "$A" -maxdepth 1 -name '*.polylane-pointer.*' -print)
assert_eq "no-move-into-old-target" "" "$nested"
assert_ok "codex-launcher" test -x "$DEST/scripts/polylane-codex.sh"
assert_ok "codex-adapter" test -x "$DEST/scripts/polylane-codex-agent.sh"
assert_ok "model-resolver" test -x "$DEST/scripts/polylane-codex-model.sh"
assert_ok "runner" test -x "$DEST/scripts/polylane-run.sh"
assert_ok "revision" test -s "$DEST/.polylane-core-revision"
assert_ok "manifest" test -s "$DEST/.polylane-core-manifest"
assert_ok "whole-package-manifest" test -s "$DEST/.polylane-package-manifest"
assert_ok "agent-metadata" test -s "$DEST/agents/openai.yaml"
assert_ok "workflow-reference" test -s "$DEST/references/polylane-loop.md"
assert_ok "adapter-reference-namespaced" test -s "$DEST/references/codex/codex-prompts.md"
assert_fail "adapter-cannot-overwrite-shared-reference" test -e "$DEST/references/codex-prompts.md"
assert_contains "literal-dot-link-rewrite" "references/codex/codex-prompts.md" \
  "$(cat "$DEST/SKILL.md")"
lines=$(wc -l < "$DEST/SKILL.md" | tr -d ' ')
[ "$lines" -lt 500 ] && pass "concise-skill" || fail "concise-skill" "$lines lines"
assert_ok "codex-package-policy" "$DEST/scripts/polylane-codex-package-policy.sh" validate "$DEST"

assert_ok "codex-cli-present" command -v codex
mkdir -p "$TEST_TMPDIR/discovery-home/skills"
ln -s "$A" "$TEST_TMPDIR/discovery-home/skills/polylane"
discovery=$(CODEX_HOME="$TEST_TMPDIR/discovery-home" codex debug prompt-input 'Use $polylane')
assert_contains "codex-discovers-public-symlink" "$A/SKILL.md" "$discovery"

ODD="$TEST_TMPDIR/skill # [literal] & apostrophe's path"
assert_ok "metachar-destination-install" "$PKG" codex "$ODD"
assert_ok "metachar-destination-verify" "$PKG" verify-package "$ODD"

while IFS='  ' read -r want rel; do
  [ -n "$rel" ] || continue
  got=$(git hash-object "$DEST/$rel")
  assert_eq "manifest-$rel" "$want" "$got"
done < "$DEST/.polylane-core-manifest"

SMOKE="$TEST_TMPDIR/standalone"
cp -RL "$DEST" "$SMOKE"
chmod -R u+w "$SMOKE"
CALLED="$TEST_TMPDIR/called"; export CALLED
cat > "$SMOKE/scripts/polylane-supervisor.sh" <<'SH'
#!/usr/bin/env bash
printf 'root=%s\nagent=%s\nargs=%s\n' "$(cd "$(dirname "$0")/.." && pwd)" \
  "$POLYLANE_AGENT" "$*" > "$CALLED"
SH
chmod +x "$SMOKE/scripts/polylane-supervisor.sh"
printf '%s\n' '{"agent":"codex","run_id":"smoke"}' > "$TEST_TMPDIR/run.json"
POLYLANE_AGENT_CMD='mock {model} {prompt} {effort}' assert_ok "standalone-launch" \
  "$SMOKE/scripts/polylane-codex.sh" "$TEST_TMPDIR/run.json" --resume
assert_contains "standalone-root" "$SMOKE" "$(cat "$CALLED")"
assert_contains "standalone-agent" "agent=codex" "$(cat "$CALLED")"
finish
```

Expected: `bash -n codex/tests/test-codex-install.sh` exits 0.

- [ ] **Step 2: Add the complete Claude package smoke test (4 minutes)**

Create `claude-code/tests/test-claude-install.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
DEST="$TEST_TMPDIR/claude-skill"
HOME="$TEST_TMPDIR/home" assert_eq "print-user-dest" \
  "$TEST_TMPDIR/home/.claude/skills/polylane" \
  "$(HOME="$TEST_TMPDIR/home" "$ROOT/claude-code/install.sh" --print-user-dest)"
assert_ok "install" "$ROOT/claude-code/install.sh" --dest "$DEST"
for path in scripts/polylane-claude.sh scripts/polylane-claude-agent.sh \
  scripts/polylane-claudemem.sh scripts/polylane-models.sh \
  assets/claude-code/graphify-nudge.sh assets/claude-code/verify-gate.sh \
  references/claude-code/discovery.md adapter/package.json \
  .polylane-core-revision .polylane-core-manifest .polylane-package-manifest; do
  assert_ok "present-$path" test -e "$DEST/$path"
done
assert_ok "public-pointer" test -L "$DEST"
assert_ok "workflow-once" test -s "$DEST/references/polylane-loop.md"
assert_fail "claude-ref-not-shared" test -e "$DEST/references/discovery.md"
count=$(find -L "$DEST" -name polylane-loop.md -type f | wc -l | tr -d ' ')
assert_eq "one-workflow-copy" 1 "$count"
finish
```

Run: `bash -n claude-code/tests/test-claude-install.sh`

Expected: exit 0; the Claude package inventory assertions are valid shell.

- [ ] **Step 3: Add the complete shared parity/immutability test (5 minutes)**

Create `core/tests/test-package-parity.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
C="$TEST_TMPDIR/codex"; H="$TEST_TMPDIR/claude"
assert_ok "package-codex" "$ROOT/core/scripts/polylane-package.sh" codex "$C"
assert_ok "package-claude" "$ROOT/core/scripts/polylane-package.sh" claude-code "$H"
assert_eq "same-revision" "$(cat "$C/.polylane-core-revision")" \
  "$(cat "$H/.polylane-core-revision")"
assert_eq "same-core-manifest" "$(cat "$C/.polylane-core-manifest")" \
  "$(cat "$H/.polylane-core-manifest")"
assert_ok "codex-whole-package-valid" "$ROOT/core/scripts/polylane-package.sh" verify-package "$C"
assert_ok "claude-whole-package-valid" "$ROOT/core/scripts/polylane-package.sh" verify-package "$H"
assert_ok "codex-ref-namespace" test -s "$C/references/codex/codex-models.md"
assert_ok "claude-ref-namespace" test -s "$H/references/claude-code/model-selection.md"
assert_eq "shared-workflow-not-clobbered" "$(git hash-object "$ROOT/core/workflow/polylane-loop.md")" \
  "$(git hash-object "$C/references/polylane-loop.md")"
while IFS='  ' read -r hash rel; do
  [ -n "$rel" ] || continue
  assert_eq "parity-$rel" "$(git hash-object "$C/$rel")" "$(git hash-object "$H/$rel")"
done < "$C/.polylane-core-manifest"
writable=$(find -L "$C" -type f -perm -0222 -print 2>/dev/null || true)
assert_eq "immutable-release" "" "$writable"
out=$(POLYLANE_AGENT=codex POLYLANE_AGENT_ADAPTER="$C/scripts/polylane-codex-agent.sh" \
  "$C/scripts/polylane-doctor.sh" --package-only 2>&1)
assert_contains "doctor-match" "core-package: match" "$out"
release=$(readlink "$C")
chmod u+w "$release/SKILL.md"
printf '\n# adapter tamper\n' >> "$release/SKILL.md"
chmod a-w "$release/SKILL.md"
out=$(POLYLANE_AGENT=codex POLYLANE_AGENT_ADAPTER="$C/scripts/polylane-codex-agent.sh" \
  "$C/scripts/polylane-doctor.sh" --package-only 2>&1 || true)
assert_contains "doctor-mixed" "core-package: mixed" "$out"

MODE="$TEST_TMPDIR/mode"; LINK="$TEST_TMPDIR/link"
assert_ok "package-mode-fixture" "$ROOT/core/scripts/polylane-package.sh" codex "$MODE"
assert_eq "deterministic-whole-manifest" "$(cat "$MODE/.polylane-package-manifest")" \
  "$(cat "$C/.polylane-package-manifest")"
mode_release=$(readlink "$MODE"); chmod a-x "$mode_release/scripts/polylane-run.sh"
assert_fail "mode-tamper-rejected" "$ROOT/core/scripts/polylane-package.sh" verify-package "$MODE"

assert_ok "package-type-fixture" "$ROOT/core/scripts/polylane-package.sh" codex "$LINK"
link_release=$(readlink "$LINK"); chmod u+w "$link_release"
cp "$link_release/SKILL.md" "$TEST_TMPDIR/skill-copy"
rm "$link_release/SKILL.md"; ln -s "$TEST_TMPDIR/skill-copy" "$link_release/SKILL.md"
assert_fail "regular-to-symlink-rejected" "$ROOT/core/scripts/polylane-package.sh" verify-package "$LINK"

EXTRA="$TEST_TMPDIR/extra"; assert_ok "package-extra-fixture" \
  "$ROOT/core/scripts/polylane-package.sh" codex "$EXTRA"
extra_release=$(readlink "$EXTRA"); chmod u+w "$extra_release"
ln -s SKILL.md "$extra_release/injected-link"
assert_fail "injected-symlink-rejected" "$ROOT/core/scripts/polylane-package.sh" verify-package "$EXTRA"
rm "$extra_release/injected-link"
mkfifo "$extra_release/injected-fifo"
assert_fail "injected-fifo-rejected" "$ROOT/core/scripts/polylane-package.sh" verify-package "$EXTRA"
rm "$extra_release/injected-fifo"
mkdir "$extra_release/injected-empty-directory"
assert_fail "injected-empty-directory-rejected" \
  "$ROOT/core/scripts/polylane-package.sh" verify-package "$EXTRA"

SYMLINK_ROOT="$TEST_TMPDIR/symlink-release-root"
mkdir "$TEST_TMPDIR/hostile-release-root"
ln -s "$TEST_TMPDIR/hostile-release-root" "$SYMLINK_ROOT.polylane-releases"
assert_rc "symlink-release-root-rejected" 6 \
  "$ROOT/core/scripts/polylane-package.sh" codex "$SYMLINK_ROOT"
STAGING_DEST="$TEST_TMPDIR/staging-collision"; mkdir "$STAGING_DEST.polylane-releases"
mkdir "$STAGING_DEST.polylane-releases/.staging-fixed-collision"
POLYLANE_PACKAGE_TEST_NONCE=fixed-collision assert_rc "exclusive-staging-collision-rejected" 6 \
  "$ROOT/core/scripts/polylane-package.sh" codex "$STAGING_DEST"

FIXTURE_REPO="$TEST_TMPDIR/fixture-repo"
mkdir -p "$FIXTURE_REPO"
cp -R "$ROOT/core" "$ROOT/codex" "$ROOT/claude-code" "$FIXTURE_REPO/"
mkdir -p "$FIXTURE_REPO/core/scripts/lib/deep" "$FIXTURE_REPO/core/config/nested" \
  "$FIXTURE_REPO/core/bundled-skills/example/nested"
printf '#!/usr/bin/env bash\nreturn 0\n' > "$FIXTURE_REPO/core/scripts/lib/deep/helper.sh"
chmod +x "$FIXTURE_REPO/core/scripts/lib/deep/helper.sh"
printf 'fixture=true\n' > "$FIXTURE_REPO/core/config/nested/runtime.conf"
printf '%s\n' '---' 'name: fixture' 'description: fixture' '---' \
  > "$FIXTURE_REPO/core/bundled-skills/example/nested/SKILL.md"
FC="$TEST_TMPDIR/fixture-codex"; FH="$TEST_TMPDIR/fixture-claude"
assert_ok "recursive-core-codex" "$FIXTURE_REPO/core/scripts/polylane-package.sh" codex "$FC"
assert_ok "recursive-core-claude" "$FIXTURE_REPO/core/scripts/polylane-package.sh" claude-code "$FH"
for rel in scripts/lib/deep/helper.sh config/nested/runtime.conf \
  bundled-skills/example/nested/SKILL.md; do
  assert_ok "nested-present-$rel" test -f "$FC/$rel"
  assert_eq "nested-parity-$rel" "$(git hash-object "$FC/$rel")" "$(git hash-object "$FH/$rel")"
done
assert_ok "literal-dot-relative-path" "$FIXTURE_REPO/core/scripts/polylane-package.sh" \
  validate-relative 'references/name.with.dots.md'
for bad in $'line\nfeed' $'tab\tpath' $'carriage\rreturn' '-leading' 'space path' \
  'empty//component' 'dot/./component' 'parent/../component'; do
  assert_rc "unsafe-relative-rejected-$(printf '%s' "$bad" | cksum | awk '{print $1}')" 1 \
    "$FIXTURE_REPO/core/scripts/polylane-package.sh" validate-relative "$bad"
done
ln -s runtime.conf "$FIXTURE_REPO/core/config/nested/source-link"
assert_rc "source-symlink-rejected" 6 \
  "$FIXTURE_REPO/core/scripts/polylane-package.sh" codex "$TEST_TMPDIR/source-link"
rm "$FIXTURE_REPO/core/config/nested/source-link"
mkfifo "$FIXTURE_REPO/core/config/nested/source-fifo"
assert_rc "source-special-file-rejected" 6 \
  "$FIXTURE_REPO/core/scripts/polylane-package.sh" codex "$TEST_TMPDIR/source-fifo"
rm "$FIXTURE_REPO/core/config/nested/source-fifo"
tmp="$FIXTURE_REPO/codex/package.json.tmp"
jq '.metadata += [{"source":"agents/openai.yaml","target":"references/polylane-loop.md"}]' \
  "$FIXTURE_REPO/codex/package.json" > "$tmp" && mv "$tmp" "$FIXTURE_REPO/codex/package.json"
assert_rc "adapter-shared-target-collision-rejected" 6 \
  "$FIXTURE_REPO/core/scripts/polylane-package.sh" codex "$TEST_TMPDIR/target-collision"
cp "$ROOT/codex/package.json" "$FIXTURE_REPO/codex/package.json"
if [ "$(uname -s)" = Linux ]; then
  printf one > "$FIXTURE_REPO/core/config/Case.conf"
  printf two > "$FIXTURE_REPO/core/config/case.conf"
  assert_rc "case-colliding-source-rejected" 6 \
    "$FIXTURE_REPO/core/scripts/polylane-package.sh" codex "$TEST_TMPDIR/case-collision"
  rm "$FIXTURE_REPO/core/config/Case.conf" "$FIXTURE_REPO/core/config/case.conf"
fi
mkdir -p "$FIXTURE_REPO/core/unknown-production-root"
assert_rc "unknown-core-root-rejected" 6 \
  "$FIXTURE_REPO/core/scripts/polylane-package.sh" codex "$TEST_TMPDIR/unknown-root"
finish
```

Run: `bash -n core/tests/test-package-parity.sh`

Expected: exit 0; parity, immutability, and tamper-detection checks are syntactically valid.

Also make temporary-fixture cleanup able to remove intentionally immutable releases:

```diff
diff --git a/core/tests/helpers.sh b/core/tests/helpers.sh
--- a/core/tests/helpers.sh
+++ b/core/tests/helpers.sh
@@
   for d in $HELPER_TMPDIRS; do
     case "$d" in
-      "${TMPDIR:-/tmp}"/polylane-tests.*) rm -rf "$d" ;;
+      "${TMPDIR:-/tmp}"/polylane-tests.*)
+        chmod -R u+w "$d" 2>/dev/null || true
+        rm -rf "$d"
+        ;;
     esac
   done
```

- [ ] **Step 4: Run the three smoke/parity tests and verify RED (3 minutes)**

Run:

```bash
bash codex/tests/test-codex-install.sh
bash claude-code/tests/test-claude-install.sh
bash core/tests/test-package-parity.sh
```

Expected: all three exit nonzero because the shared package publisher and Claude installer
do not exist and the Codex installer still copies a mutable mixed tree.

- [ ] **Step 5: Add the complete legacy migration/preflight test (5 minutes)**

Create `core/tests/test-package-legacy-migration.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
PKG="$ROOT/core/scripts/polylane-package.sh"
make_tmpdir
SEED="$TEST_TMPDIR/seed"; DEST="$TEST_TMPDIR/legacy skill"
assert_ok "seed" "$PKG" codex "$SEED"
cp -RL "$SEED" "$DEST"
assert_ok "legacy-is-directory" test -d "$DEST"
assert_fail "legacy-not-link" test -L "$DEST"

snapshot() { find "$1" -type f -print | LC_ALL=C sort | while IFS= read -r f; do git hash-object "$f"; done; }
mkdir -p "$DEST/.polylane/runtime"
token=$($PKG process-start-token $$)
printf '{"pid":%s,"start_token":"%s","executable":"%s"}\n' $$ "$token" \
  "$DEST/scripts/polylane-run.sh" > "$DEST/.polylane/runtime/actor.json"
before=$(snapshot "$DEST")
assert_rc "runtime-actor-blocks" 8 "$PKG" migration-preflight "$DEST"
assert_eq "preflight-no-mutation" "$before" "$(snapshot "$DEST")"
rm -rf "$DEST/.polylane"
clean_snapshot=$(snapshot "$DEST")

cat > "$DEST/hold script.sh" <<'SH'
#!/usr/bin/env bash
while :; do sleep 1; done
SH
chmod +x "$DEST/hold script.sh"
"$(command -v bash)" "$DEST/hold script.sh" & live=$!
assert_rc "live-path-blocks" 8 "$PKG" migration-preflight "$DEST"
kill "$live" 2>/dev/null || true; wait "$live" 2>/dev/null || true

ALIAS="$TEST_TMPDIR/legacy-alias"; ln -s "$DEST" "$ALIAS"
"$(command -v bash)" "$ALIAS/hold script.sh" & live=$!
if [ "$(uname -s)" = Darwin ]; then
  assert_ok "kern-procargs2-preserves-spaced-symlink-argv" bash -c \
    '"$1" "$2" | tr "\000" "\n" | grep -Fx "$3"' _ \
    "$ROOT/core/scripts/polylane-procargs-macos" "$live" "$ALIAS/hold script.sh"
fi
assert_rc "symlink-alias-script-blocks" 8 "$PKG" migration-preflight "$DEST"
kill "$live" 2>/dev/null || true; wait "$live" 2>/dev/null || true

(cd "$DEST" && sleep 30) & live=$!
assert_rc "process-cwd-blocks" 8 "$PKG" migration-preflight "$DEST"
kill "$live" 2>/dev/null || true; wait "$live" 2>/dev/null || true

ln -s "$DEST" "$TEST_TMPDIR/relative-alias"
cp "$DEST/hold script.sh" "$DEST/hold-relative.sh"
(cd "$TEST_TMPDIR" && "$(command -v bash)" ./relative-alias/hold-relative.sh) & live=$!
assert_rc "relative-alias-script-blocks" 8 "$PKG" migration-preflight "$DEST"
kill "$live" 2>/dev/null || true; wait "$live" 2>/dev/null || true
rm "$DEST/hold-relative.sh"
rm "$DEST/hold script.sh"

mkdir -p "$TEST_TMPDIR/bin"
cat > "$TEST_TMPDIR/bin/tmux" <<SH
#!/usr/bin/env bash
printf 'owned|$DEST\\n'
SH
chmod +x "$TEST_TMPDIR/bin/tmux"
PATH="$TEST_TMPDIR/bin:$PATH" assert_rc "owned-tmux-blocks" 8 \
  "$PKG" migration-preflight "$DEST"

assert_ok "clean-preflight" "$PKG" migration-preflight "$DEST"
POLYLANE_PACKAGE_FAULT=legacy-guard-never-ready assert_rc \
  "legacy-guard-must-authenticate-before-first-rename" 7 "$PKG" codex "$DEST"
assert_ok "unready-guard-leaves-legacy-directory" test -d "$DEST"
assert_fail "unready-guard-created-no-backup" \
  compgen -G "$DEST.polylane-releases/legacy-*"
assert_eq "unready-guard-preserves-content" "$clean_snapshot" "$(snapshot "$DEST")"
assert_ok "clean-migration" "$PKG" codex "$DEST"
assert_ok "migrated-pointer" test -L "$DEST"
for public in "$DEST.polylane-releases"/.legacy-*.json \
  "$DEST.polylane-releases"/.legacy-*.json.seal \
  "$DEST.polylane-releases"/.legacy-*.json.guard-live \
  "$DEST.polylane-releases"/.legacy-*.committed; do
  [ -f "$public" ] || continue
  assert_fail "legacy-public-record-no-symlink-${public##*/}" test -L "$public"
  assert_eq "legacy-public-record-mode-${public##*/}" 0400 \
    "$($PKG mode-of "$public")"
done

rm "$DEST"
cp -RL "$SEED" "$DEST"
POLYLANE_PACKAGE_FAULT=after-legacy-rename assert_fail "ordinary-fault" "$PKG" codex "$DEST"
i=0; while [ ! -d "$DEST" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done
assert_ok "ordinary-restored-directory" test -d "$DEST"
assert_eq "ordinary-restored-content" "$clean_snapshot" "$(snapshot "$DEST")"

POLYLANE_PACKAGE_FAULT=sigkill-after-legacy-rename "$PKG" codex "$DEST" >/dev/null 2>&1 & pub=$!
wait "$pub" 2>/dev/null || true
i=0; while [ ! -d "$DEST" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done
assert_ok "sigkill-restored-directory" test -d "$DEST"
assert_eq "sigkill-restored-content" "$clean_snapshot" "$(snapshot "$DEST")"

for fault in sigkill-after-empty-legacy-marker sigkill-after-wrong-legacy-marker; do
  POLYLANE_PACKAGE_FAULT="$fault" "$PKG" codex "$DEST" >/dev/null 2>&1 & pub=$!
  wait "$pub" 2>/dev/null || true
  i=0; while [ ! -d "$DEST" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i+1)); done
  assert_ok "$fault-restores-directory" test -d "$DEST"
  assert_eq "$fault-does-not-suppress-rollback" "$clean_snapshot" "$(snapshot "$DEST")"
done

POLYLANE_PACKAGE_FAULT=sigkill-after-legacy-rename \
  POLYLANE_PACKAGE_HOLD_LEGACY_RECOVERY=1 "$PKG" codex "$DEST" >/dev/null 2>&1 & pub=$!
wait "$pub" 2>/dev/null || true
"$PKG" codex "$DEST" & successor=$!
wait "$successor"; successor_rc=$?
assert_eq "legacy-successor-publishes" 0 "$successor_rc"
assert_ok "legacy-successor-final-pointer" test -L "$DEST"
assert_ok "legacy-successor-package-complete" "$PKG" verify-package "$DEST"
sleep 1.2
assert_ok "old-guard-cannot-overwrite-successor" test -L "$DEST"

ABA="$TEST_TMPDIR/lock-init-aba-skill"
POLYLANE_PACKAGE_LOCK_INIT_DELAY=2 "$PKG" codex "$ABA" & delayed_creator=$!
i=0
while ! compgen -G "$ABA.polylane-lock.init.*" >/dev/null && [ "$i" -lt 40 ]; do
  sleep 0.05; i=$((i+1))
done
assert_ok "delayed-creator-uses-private-initializer" \
  compgen -G "$ABA.polylane-lock.init.*"
POLYLANE_PACKAGE_LOCK_HOLD_SECONDS=3 "$PKG" codex "$ABA" & successor=$!
i=0
while [ ! -s "$ABA.polylane-lock/owner.json" ] && [ "$i" -lt 40 ]; do
  sleep 0.05; i=$((i+1))
done
assert_eq "successor-owns-public-lock" "$successor" \
  "$(jq -r '.pid // 0' "$ABA.polylane-lock/owner.json")"
assert_ok "delayed-creator-cannot-overwrite-successor" kill -0 "$delayed_creator"
wait "$successor"; successor_rc=$?
wait "$delayed_creator"; delayed_rc=$?
assert_eq "successor-publisher" 0 "$successor_rc"
assert_eq "delayed-publisher-retries" 0 "$delayed_rc"
assert_ok "aba-race-package-complete" "$PKG" verify-package "$ABA"

KILLED_INIT="$TEST_TMPDIR/killed-lock-init-skill"
POLYLANE_PACKAGE_LOCK_INIT_DELAY=30 "$PKG" codex "$KILLED_INIT" & creator=$!
i=0
while ! compgen -G "$KILLED_INIT.polylane-lock.init.*" >/dev/null && [ "$i" -lt 40 ]; do
  sleep 0.05; i=$((i+1))
done
assert_ok "killed-creator-reached-private-initializer" \
  compgen -G "$KILLED_INIT.polylane-lock.init.*"
kill -9 "$creator" 2>/dev/null || true
wait "$creator" 2>/dev/null || true
assert_fail "killed-creator-never-published-ownerless-lock" test -e "$KILLED_INIT.polylane-lock"
assert_ok "successor-ignores-killed-private-initializer" "$PKG" codex "$KILLED_INIT"
assert_ok "killed-init-package-complete" "$PKG" verify-package "$KILLED_INIT"

STALE="$TEST_TMPDIR/stale-lock-skill"
mkdir "$STALE.polylane-lock"
jq -n '{pid:999999,start_token:"dead-token",nonce:"stale-nonce"}' \
  > "$STALE.polylane-lock/owner.json"
chmod 0600 "$STALE.polylane-lock/owner.json"
POLYLANE_PACKAGE_HOLD_STALE_CLOSE=1 "$PKG" codex "$STALE" & reclaimer=$!
i=0
while ! compgen -G "$STALE.polylane-lock/.close.*" >/dev/null && [ "$i" -lt 40 ]; do
  sleep 0.05; i=$((i+1))
done
assert_ok "stale-lock-close-marker-published" compgen -G "$STALE.polylane-lock/.close.*"
"$PKG" codex "$STALE" & successor=$!
wait "$reclaimer"; reclaim_rc=$?; wait "$successor"; successor_rc=$?
assert_eq "anchored-reclaimer" 0 "$reclaim_rc"
assert_eq "concurrent-closer-cannot-steal-successor" 0 "$successor_rc"
assert_fail "meta-reclaim-gate-eliminated" test -e "$STALE.polylane-lock.reclaim"
assert_ok "stale-lock-result-complete" "$PKG" verify-package "$STALE"

CLOSE_CRASH="$TEST_TMPDIR/close-marker-crash-skill"
mkdir "$CLOSE_CRASH.polylane-lock"
jq -n '{pid:999999,start_token:"dead-token",nonce:"stale-gate-owner"}' \
  > "$CLOSE_CRASH.polylane-lock/owner.json"
chmod 0600 "$CLOSE_CRASH.polylane-lock/owner.json"
POLYLANE_PACKAGE_FAULT=sigkill-after-lock-close-marker \
  "$PKG" codex "$CLOSE_CRASH" >/dev/null 2>&1 & closer=$!
wait "$closer" 2>/dev/null || true
assert_ok "crashed-close-marker-persists" \
  compgen -G "$CLOSE_CRASH.polylane-lock/.close.*"
assert_ok "successor-cleans-dead-close-marker" "$PKG" codex "$CLOSE_CRASH"
assert_fail "close-marker-not-wedged" test -e "$CLOSE_CRASH.polylane-lock"
assert_ok "close-recovery-package-complete" "$PKG" verify-package "$CLOSE_CRASH"
finish
```

Run: `bash -n core/tests/test-package-legacy-migration.sh`

Expected: exit 0; spaced argv, legacy rollback, private-initializer ABA/killed-creator
recovery, and anchored close-marker concurrency/SIGKILL recovery
fixtures are syntactically valid.

- [ ] **Step 6: Add the complete activation-journal/SIGKILL test (5 minutes)**

Create `core/tests/test-package-activation.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
PKG="$ROOT/core/scripts/polylane-package.sh"
make_tmpdir
DEST="$TEST_TMPDIR/skill"; JOURNAL="$TEST_TMPDIR/activation.json"

wait_state() {
  local want=$1 file=$2 i=0 state
  while [ "$i" -lt 160 ]; do
    state=$(jq -r '.state // ""' "$file" 2>/dev/null || true)
    [ "$state" = "$want" ] && return 0
    sleep 0.1; i=$((i+1))
  done
  return 1
}
start_owner() { sleep 30 & OWNER=$!; }
stop_owner() { kill "$OWNER" 2>/dev/null || true; wait "$OWNER" 2>/dev/null || true; }
mode_of() {
  case "$(uname -s)" in Linux) stat -c '%a' "$1" ;; *) stat -f '%Lp' "$1" ;; esac
}

assert_ok "install-a" "$PKG" codex "$DEST"
A=$(readlink "$DEST")
start_owner
mkdir "$TEST_TMPDIR/journal-target"; ln -s "$TEST_TMPDIR/journal-target" "$TEST_TMPDIR/journal-link"
assert_rc "journal-symlink-to-directory-rejected" 2 "$PKG" codex "$DEST" \
  --activation-record "$TEST_TMPDIR/journal-link" --certification-owner-pid "$OWNER"
assert_eq "unsafe-journal-no-pointer-move" "$A" "$(readlink "$DEST")"
JAUX="$TEST_TMPDIR/aux.json"; ln -s "$TEST_TMPDIR/journal-target" "$JAUX.guard-copy"
assert_rc "journal-aux-symlink-rejected" 2 "$PKG" codex "$DEST" \
  --activation-record "$JAUX" --certification-owner-pid "$OWNER"
assert_eq "unsafe-aux-no-pointer-move" "$A" "$(readlink "$DEST")"
stop_owner
start_owner
assert_ok "publish-b-guarded" "$PKG" codex "$DEST" \
  --activation-record "$JOURNAL" --certification-owner-pid "$OWNER"
B=$(readlink "$DEST")
assert_not_contains "b-differs" "$A" "$B"
assert_eq "published-state" PUBLISHED "$(jq -r .state "$JOURNAL")"
for field in destination prior_release candidate_release activation_nonce \
  certification_owner_pid certification_owner_start_token certification_deadline \
  preparation_deadline publisher_pid \
  publisher_start_token guard_pid guard_start_token prior_manifest_hash \
  candidate_manifest_hash; do
  value=$(jq -r --arg f "$field" '.[$f] // empty' "$JOURNAL")
  [ -n "$value" ] && pass "journal-$field" || fail "journal-$field" missing
done
assert_ok "guard-live-marker" test -s "$JOURNAL.guard-live"
assert_eq "guard-live-pid" "$(jq -r .guard_pid "$JOURNAL")" \
  "$(jq -r .pid "$JOURNAL.guard-live")"
assert_ok "guard-live-token" "$PKG" process-matches \
  "$(jq -r .pid "$JOURNAL.guard-live")" "$(jq -r .start_token "$JOURNAL.guard-live")"
assert_eq "journal-mode" 600 "$(mode_of "$JOURNAL")"
for sealed in "$JOURNAL.prepare-copy" "$JOURNAL.prepare-seal" "$JOURNAL.guard-copy" \
  "$JOURNAL.guard-seal" "$JOURNAL.guard-ready" "$JOURNAL.guard-live"; do
  assert_eq "sealed-mode-${sealed##*.}" 400 "$(mode_of "$sealed")"
done
stop_owner
assert_ok "owner-death-rolls-back" wait_state ROLLED_BACK "$JOURNAL"
assert_eq "owner-death-restores-a" "$A" "$(readlink "$DEST")"
assert_ok "all-activation-files-have-exact-types-and-modes" \
  "$PKG" validate-activation-files "$JOURNAL"
for protected in "$JOURNAL" "$JOURNAL.prepare-copy" "$JOURNAL.prepare-seal" \
  "$JOURNAL.guard-copy" "$JOURNAL.guard-seal" "$JOURNAL.guard-ready" \
  "$JOURNAL.guard-live"; do
  expected=400; [ "$protected" != "$JOURNAL" ] || expected=600
  chmod 0644 "$protected"
  assert_rc "wrong-mode-${protected##*.}" 7 "$PKG" validate-activation-files "$JOURNAL"
  chmod "0$expected" "$protected"
  cp -p "$protected" "$protected.audit-backup"
  rm "$protected"; ln -s "$protected.audit-backup" "$protected"
  assert_rc "symlink-${protected##*.}" 7 "$PKG" validate-activation-files "$JOURNAL"
  rm "$protected"; mv "$protected.audit-backup" "$protected"
done

start_owner
J2="$TEST_TMPDIR/commit.json"
assert_ok "publish-certify" "$PKG" codex "$DEST" --activation-record "$J2" \
  --certification-owner-pid "$OWNER"
CANDIDATE=$(readlink "$DEST")
assert_ok "certify" "$PKG" certify-activation "$J2"
assert_ok "wait-committed" "$PKG" wait-activation "$J2"
assert_rc "committed-rollback-forbidden" 9 "$PKG" rollback "$J2"
stop_owner; sleep 0.2
assert_eq "commit-survives-owner-death" "$CANDIDATE" "$(readlink "$DEST")"

start_owner
JCB="$TEST_TMPDIR/commit-before.json"; BEFORE_COMMIT=$(readlink "$DEST")
assert_ok "publish-before-commit-boundary" "$PKG" codex "$DEST" \
  --activation-record "$JCB" --certification-owner-pid "$OWNER"
POLYLANE_PACKAGE_FAULT=sigkill-before-commit-publication \
  "$PKG" certify-activation "$JCB" >/dev/null 2>&1 & certifier=$!
wait "$certifier" 2>/dev/null || true
assert_eq "pre-commit-crash-stays-published" PUBLISHED "$(jq -r .state "$JCB")"
stop_owner
assert_ok "pre-commit-owner-death-rolls-back" wait_state ROLLED_BACK "$JCB"
assert_eq "pre-commit-restores-prior" "$BEFORE_COMMIT" "$(readlink "$DEST")"

start_owner
JDEAD="$TEST_TMPDIR/owner-dies-at-certify-cas.json"; PRIOR=$(readlink "$DEST")
assert_ok "publish-owner-dies-at-certify-cas" "$PKG" codex "$DEST" \
  --activation-record "$JDEAD" --certification-owner-pid "$OWNER"
POLYLANE_PACKAGE_FAULT=delay-after-published-check-before-cas \
  "$PKG" certify-activation "$JDEAD" >/dev/null 2>&1 & certifier=$!
sleep 0.2; stop_owner
wait "$certifier" 2>/dev/null; certify_rc=$?
assert_eq "dead-owner-certifier-rejected" 9 "$certify_rc"
assert_ok "dead-owner-certifier-rolls-back" wait_state ROLLED_BACK "$JDEAD"
assert_eq "dead-owner-cannot-retain-candidate" "$PRIOR" "$(readlink "$DEST")"

start_owner
JEXPIRE="$TEST_TMPDIR/deadline-at-certify-cas.json"; PRIOR=$(readlink "$DEST")
POLYLANE_CERTIFICATION_TIMEOUT=1 assert_ok "publish-deadline-at-certify-cas" \
  "$PKG" codex "$DEST" --activation-record "$JEXPIRE" --certification-owner-pid "$OWNER"
POLYLANE_PACKAGE_FAULT=delay-after-published-check-before-cas \
  "$PKG" certify-activation "$JEXPIRE" >/dev/null 2>&1 & certifier=$!
wait "$certifier" 2>/dev/null; certify_rc=$?
assert_eq "expired-certifier-rejected" 9 "$certify_rc"
assert_eq "expired-certifier-rolls-back" ROLLED_BACK "$(jq -r .state "$JEXPIRE")"
assert_eq "expired-certifier-restores-prior" "$PRIOR" "$(readlink "$DEST")"
assert_ok "expired-certification-owner-still-live" "$PKG" process-matches "$OWNER" \
  "$(jq -r .certification_owner_start_token "$JEXPIRE.guard-copy")"
stop_owner

start_owner
JCA="$TEST_TMPDIR/commit-after.json"
assert_ok "publish-after-commit-boundary" "$PKG" codex "$DEST" \
  --activation-record "$JCA" --certification-owner-pid "$OWNER"
POLYLANE_PACKAGE_FAULT=sigkill-after-commit-publication \
  "$PKG" certify-activation "$JCA" >/dev/null 2>&1 & certifier=$!
wait "$certifier" 2>/dev/null || true
assert_ok "wait-observes-atomic-commit" "$PKG" wait-activation "$JCA"
assert_eq "post-publication-state" COMMITTED "$(jq -r .state "$JCA")"
assert_eq "atomic-commit-evidence" "$(jq -r .activation_nonce "$JCA")" \
  "$(jq -r .commit_evidence.nonce "$JCA")"
CANDIDATE=$(readlink "$DEST")
tmp="$JCA.tmp"; jq '.destination="/caller-corrupted"' "$JCA" > "$tmp" && \
  chmod 0600 "$tmp" && mv "$tmp" "$JCA"
assert_ok "committed-corruption-converges" "$PKG" wait-activation "$JCA"
assert_eq "committed-corruption-reconstructed" COMMITTED "$(jq -r .state "$JCA")"
assert_eq "committed-recovery-keeps-evidence" "$(jq -r .activation_nonce "$JCA")" \
  "$(jq -r .commit_evidence.nonce "$JCA")"
assert_eq "recovered-marker-mode" 400 "$(mode_of "$JCA.recovered")"
chmod 0600 "$JCA.recovered"
assert_rc "recovered-marker-wrong-mode-rejected" 7 \
  "$PKG" validate-activation-files "$JCA"
chmod 0400 "$JCA.recovered"
stop_owner; sleep 0.2
assert_eq "post-commit-owner-death-retains-candidate" "$CANDIDATE" "$(readlink "$DEST")"

JBOOT="$TEST_TMPDIR/bootstrap.json"; start_owner
POLYLANE_PACKAGE_FAULT=sigkill-during-guard-bootstrap \
  "$PKG" codex "$DEST" --activation-record "$JBOOT" \
  --certification-owner-pid "$OWNER" >/dev/null 2>&1 & bootstrap_publisher=$!
wait "$bootstrap_publisher" 2>/dev/null || true
assert_ok "bootstrap-death-wait-terminates" "$PKG" wait-activation "$JBOOT"
assert_eq "bootstrap-death-terminal-state" ROLLED_BACK "$(jq -r .state "$JBOOT")"
assert_eq "bootstrap-death-retains-prior" "$CANDIDATE" "$(readlink "$DEST")"
stop_owner

for boundary in delay-after-prepared-check-before-pointer-swap \
  delay-after-pointer-swap-before-published-cas; do
  JPREP="$TEST_TMPDIR/$boundary.json"; start_owner; PRIOR=$(readlink "$DEST")
  POLYLANE_PREPARATION_TIMEOUT=10 POLYLANE_PACKAGE_FAULT="$boundary" \
    "$PKG" codex "$DEST" --activation-record "$JPREP" \
    --certification-owner-pid "$OWNER" >/dev/null 2>&1 & prepared_publisher=$!
  assert_ok "$boundary-prepared-visible" wait_state PREPARED "$JPREP"
  wait "$prepared_publisher" 2>/dev/null || true
  assert_ok "$boundary-converges-rolled-back" wait_state ROLLED_BACK "$JPREP"
  assert_eq "$boundary-never-retains-expired-candidate" "$PRIOR" "$(readlink "$DEST")"
  assert_ok "$boundary-expiry-proof" test -f "$JPREP.prepare-expired"
  assert_eq "$boundary-expiry-proof-mode" 400 "$(mode_of "$JPREP.prepare-expired")"
  stop_owner
done

for fault in sigkill-before-pointer-swap sigkill-after-pointer-swap; do
  J="$TEST_TMPDIR/$fault.json"; start_owner
  POLYLANE_PACKAGE_FAULT="$fault" "$PKG" codex "$DEST" \
    --activation-record "$J" --certification-owner-pid "$OWNER" >/dev/null 2>&1 & pub=$!
  wait "$pub" 2>/dev/null || true
  assert_ok "$fault-rolled-back" wait_state ROLLED_BACK "$J"
  assert_eq "$fault-cas-restores" "$CANDIDATE" "$(readlink "$DEST")"
  stop_owner
done

JD="$TEST_TMPDIR/deadline.json"; start_owner
POLYLANE_CERTIFICATION_TIMEOUT=1 assert_ok "publish-with-deadline" "$PKG" codex "$DEST" \
  --activation-record "$JD" --certification-owner-pid "$OWNER"
assert_ok "live-but-stuck-owner-times-out" wait_state ROLLED_BACK "$JD"
assert_eq "deadline-restores-candidate" "$CANDIDATE" "$(readlink "$DEST")"
assert_ok "owner-was-still-live" "$PKG" process-matches "$OWNER" \
  "$(jq -r .certification_owner_start_token "$JD")"
stop_owner

JG="$TEST_TMPDIR/dead-guard.json"; start_owner; PRIOR=$(readlink "$DEST")
assert_ok "publish-dead-guard-fixture" "$PKG" codex "$DEST" \
  --activation-record "$JG" --certification-owner-pid "$OWNER"
guard_pid=$(jq -r .guard_pid "$JG"); kill -9 "$guard_pid" 2>/dev/null || true
wait "$guard_pid" 2>/dev/null || true
assert_eq "dead-guard-detected-while-owner-live" PUBLISHED "$(jq -r .state "$JG")"
stop_owner
assert_ok "wait-replaces-dead-guard-monitor" "$PKG" wait-activation "$JG"
assert_eq "dead-guard-terminal" ROLLED_BACK "$(jq -r .state "$JG")"
assert_eq "dead-guard-restores-prior" "$PRIOR" "$(readlink "$DEST")"

JCORRUPT="$TEST_TMPDIR/corrupt.json"; start_owner; PRIOR=$(readlink "$DEST")
assert_ok "publish-corrupt-fixture" "$PKG" codex "$DEST" \
  --activation-record "$JCORRUPT" --certification-owner-pid "$OWNER"
guard_pid=$(jq -r .guard_pid "$JCORRUPT"); kill -9 "$guard_pid" 2>/dev/null || true
wait "$guard_pid" 2>/dev/null || true
printf '{broken\n' > "$JCORRUPT"; stop_owner
assert_ok "malformed-journal-bounded-recovery" "$PKG" wait-activation "$JCORRUPT"
assert_eq "malformed-journal-reconstructed" ROLLED_BACK "$(jq -r .state "$JCORRUPT")"
assert_eq "malformed-journal-restores-prior" "$PRIOR" "$(readlink "$DEST")"

JSTATE="$TEST_TMPDIR/invalid-state.json"; start_owner; PRIOR=$(readlink "$DEST")
assert_ok "publish-invalid-state-fixture" "$PKG" codex "$DEST" \
  --activation-record "$JSTATE" --certification-owner-pid "$OWNER"
guard_pid=$(jq -r .guard_pid "$JSTATE"); kill -9 "$guard_pid" 2>/dev/null || true
wait "$guard_pid" 2>/dev/null || true
tmp="$JSTATE.tmp"; jq '.state="IMPOSSIBLE"' "$JSTATE" > "$tmp" && \
  chmod 0600 "$tmp" && mv "$tmp" "$JSTATE"
stop_owner
assert_ok "unknown-state-bounded-recovery" "$PKG" wait-activation "$JSTATE"
assert_eq "unknown-state-reconstructed" ROLLED_BACK "$(jq -r .state "$JSTATE")"
assert_eq "unknown-state-restores-prior" "$PRIOR" "$(readlink "$DEST")"

JBADTIME="$TEST_TMPDIR/bad-preparation-timeout.json"; start_owner; PRIOR=$(readlink "$DEST")
POLYLANE_PREPARATION_TIMEOUT=5 assert_rc "unsafe-preparation-timeout-rejected" 7 \
  "$PKG" codex "$DEST" --activation-record "$JBADTIME" --certification-owner-pid "$OWNER"
assert_eq "bad-preparation-timeout-no-pointer-move" "$PRIOR" "$(readlink "$DEST")"
stop_owner

FIRST="$TEST_TMPDIR/first"; JF="$TEST_TMPDIR/first.json"; start_owner
assert_ok "first-publish" "$PKG" codex "$FIRST" --activation-record "$JF" \
  --certification-owner-pid "$OWNER"
stop_owner
assert_ok "first-rollback" wait_state ROLLED_BACK "$JF"
assert_fail "first-pointer-removed" test -e "$FIRST"

JS="$TEST_TMPDIR/stale.json"; start_owner
assert_ok "stale-publish-b" "$PKG" codex "$DEST" --activation-record "$JS" \
  --certification-owner-pid "$OWNER"
STALE_CANDIDATE=$(readlink "$DEST")
assert_ok "concurrent-c" "$PKG" codex "$DEST"
NEWER=$(readlink "$DEST")
assert_not_contains "newer-differs" "$STALE_CANDIDATE" "$NEWER"
stop_owner; sleep 0.5
assert_eq "stale-cannot-overwrite-newer" "$NEWER" "$(readlink "$DEST")"
assert_rc "manual-stale-rollback-rejected" 9 "$PKG" rollback "$JS"

JWHOLE="$TEST_TMPDIR/whole-package-tamper.json"; start_owner; PRIOR=$(readlink "$DEST")
assert_ok "whole-tamper-publish" "$PKG" codex "$DEST" --activation-record "$JWHOLE" \
  --certification-owner-pid "$OWNER"
tampered=$(readlink "$DEST"); chmod u+w "$tampered/SKILL.md"
printf '\n# corrupt candidate\n' >> "$tampered/SKILL.md"; chmod a-w "$tampered/SKILL.md"
assert_rc "whole-tamper-cannot-certify" 7 "$PKG" certify-activation "$JWHOLE"
stop_owner
assert_ok "whole-tamper-rolls-back" wait_state ROLLED_BACK "$JWHOLE"
assert_eq "whole-tamper-restores-sealed-prior" "$PRIOR" "$(readlink "$DEST")"
assert_ok "whole-tamper-restored-package-valid" "$PKG" verify-package "$DEST"

JT="$TEST_TMPDIR/tamper.json"; start_owner
assert_ok "tamper-publish" "$PKG" codex "$DEST" --activation-record "$JT" \
  --certification-owner-pid "$OWNER"
tmp="$JT.tmp"; jq '.candidate_release="/tmp/caller-edited"' "$JT" > "$tmp" && mv "$tmp" "$JT"
assert_rc "caller-edited-rejected" 7 "$PKG" rollback "$JT"
stop_owner
assert_ok "caller-edit-guard-recovers-from-seal" wait_state ROLLED_BACK "$JT"

JSWAP="$TEST_TMPDIR/source-swap-cas.json"; start_owner
assert_ok "source-swap-cas-publish" "$PKG" codex "$DEST" --activation-record "$JSWAP" \
  --certification-owner-pid "$OWNER"
swap_before=$(hash_file "$JSWAP"); swap_candidate=$(jq -r .candidate_release "$JSWAP.guard-copy")
POLYLANE_FS_TEST_REPLACE_SOURCE_SWAP=1 assert_rc "source-swap-cas-rejected" 7 \
  "$PKG" certify-activation "$JSWAP"
assert_eq "source-swap-cas-journal-unchanged" "$swap_before" "$(hash_file "$JSWAP")"
assert_eq "source-swap-cas-still-published" PUBLISHED "$(jq -r .state "$JSWAP")"
assert_eq "source-swap-cas-pointer-unchanged" "$swap_candidate" "$(readlink "$DEST")"
assert_ok "source-swap-cas-clean-retry" "$PKG" certify-activation "$JSWAP"
assert_eq "source-swap-cas-committed" COMMITTED "$(jq -r .state "$JSWAP")"
stop_owner

JBOUND="$TEST_TMPDIR/journal-bound-cas.json"; start_owner
assert_ok "journal-bound-cas-publish" "$PKG" codex "$DEST" --activation-record "$JBOUND" \
  --certification-owner-pid "$OWNER"
bound_journal_before=$(hash_file "$JBOUND")
POLYLANE_FS_TEST_REPLACE_BOUND_SWAP=1 assert_rc "journal-bound-cas-rejected" 7 \
  "$PKG" certify-activation "$JBOUND"
assert_eq "journal-bound-cas-restored-published" PUBLISHED "$(jq -r .state "$JBOUND")"
assert_eq "journal-bound-cas-restored-bytes" "$bound_journal_before" "$(hash_file "$JBOUND")"
assert_ok "journal-bound-cas-clean-retry" "$PKG" certify-activation "$JBOUND"
assert_eq "journal-bound-cas-committed" COMMITTED "$(jq -r .state "$JBOUND")"
stop_owner

JDOUBLE="$TEST_TMPDIR/concurrent-certify.json"; start_owner
assert_ok "concurrent-certify-publish" "$PKG" codex "$DEST" --activation-record "$JDOUBLE" \
  --certification-owner-pid "$OWNER"
"$PKG" certify-activation "$JDOUBLE" & cert_a=$!
"$PKG" certify-activation "$JDOUBLE" & cert_b=$!
wait "$cert_a"; cert_a_rc=$?; wait "$cert_b"; cert_b_rc=$?
assert_eq "concurrent-certifier-a" 0 "$cert_a_rc"
assert_eq "concurrent-certifier-b" 0 "$cert_b_rc"
assert_eq "concurrent-certify-single-commit" COMMITTED "$(jq -r .state "$JDOUBLE")"
assert_ok "concurrent-certify-evidence-valid" "$PKG" repair-activation "$JDOUBLE"
stop_owner

stable_pointer=$(readlink "$DEST")
POLYLANE_FS_TEST_SYMLINK_SOURCE_SWAP=1 assert_rc "pointer-path-swap-rejected" 7 \
  "$PKG" codex "$DEST"
assert_eq "pointer-path-swap-kept-prior" "$stable_pointer" "$(readlink "$DEST")"
POLYLANE_FS_TEST_SYMLINK_BOUND_SWAP=1 assert_rc "pointer-bound-swap-rejected" 7 \
  "$PKG" codex "$DEST"
assert_eq "pointer-bound-swap-kept-prior" "$stable_pointer" "$(readlink "$DEST")"
POLYLANE_FS_TEST_DIR_SOURCE_SWAP=1 POLYLANE_PACKAGE_TEST_NONCE=dir-swap \
  assert_rc "release-directory-source-swap-rejected" 6 "$PKG" codex "$DEST"
published_dir_swap=$(find "$DEST.polylane-releases" -mindepth 1 -maxdepth 1 \
  -name '*-dir-swap' ! -name '.staging-*' -print -quit)
assert_eq "release-directory-source-swap-left-no-public" "" "$published_dir_swap"
finish
```

Run: `bash -n core/tests/test-package-activation.sh`

Expected: exit 0; bootstrap, pointer-boundary, certification, deadline, first-install,
tamper, and stale-CAS fixtures are syntactically valid.

- [ ] **Step 7: Run legacy and activation tests and verify RED (3 minutes)**

Run:

```bash
bash core/tests/test-package-legacy-migration.sh
bash core/tests/test-package-activation.sh
```

Expected: both exit nonzero because migration preflight, immutable releases, activation
journals, and the independent guard are not implemented.

#### Publisher and migration implementation contract (normative)

Use a temporary sibling directory and refuse empty, `/`, a final `.`/`..`, or the repository
root. Resolve physical parent aliases and any existing final directory identity before the
repository-root comparison while preserving the public symlink pathname for upgrades. Load
the selected adapter through its descriptor: copy adapter references and assets only below
its disjoint namespaces, reject collisions with shared destinations, and rewrite only the
literal direct `SKILL.md` links named by those trees. Literal rewrite must handle regex and
replacement metacharacters. Recursively map approved shared `scripts/**`, `references/**`,
`assets/**`, `config/**`, and `bundled-skills/**`; fail closed on unknown core top-level
production paths. Platform policy lives in the staged adapter hook, never in shared core.

Install the shared workflow once at `references/polylane-loop.md`. Write the sorted shared
manifest and a deterministic whole-package manifest sealing every shipped regular file
except that seal itself by relative path, bytes, type, and portable normalized executable
mode. Exact path-set comparison rejects additions, deletion, symlink substitution, and
chmod drift. Prepare, certify, rollback, doctor, and parity checks use the whole seal.
Validate all direct skill links before publishing and never concatenate the workflow into
`SKILL.md`. Store each validated tree as an immutable sibling
release under `<destination>.polylane-releases/<revision>-<nonce>` and make the public
destination a symlink to one release. Replacing an existing symlink uses an authenticated symlink
descriptor to snapshot the target, a non-reusable random bound name under the destination CAS
lock, and Linux `RENAME_EXCHANGE`/macOS `RENAME_SWAP`. It reopens and completely verifies the
candidate bound immediately before exchange, so the injected pre-exchange bound substitution is
rejected without publishing it. OS-matrix A-to-B and source/bound-swap tests cover this behavior.
All runtime, attempt, receipt, release, and activation-control ancestors are walked from `/`
with directory file descriptors plus `O_DIRECTORY|O_NOFOLLOW`; ownership and writable-mode
checks begin at the first current-user-owned component and fail closed if the platform lacks
those flags. Concurrent directory creation is reopened and revalidated. Private regular files
use `O_CREAT|O_EXCL|O_NOFOLLOW`, are fsynced with their parent, and become public only through
an exclusive dirfd hard link whose destination inode is compared to the already-open source.
Existing-file replacement snapshots the opened source with Linux `linkat(AT_EMPTY_PATH)` (or its
documented procfs fallback) and an exclusive fd-to-fd copy on macOS, then performs a guarded atomic exchange.
It validates the complete candidate again immediately before exchange and validates both the
published snapshot and displaced destination afterward. Every legitimate Polylane publisher must
acquire the same destination lock before its destination precheck and hold it through exchange,
post-exchange validation, and directory fsync; the cooperative-publisher test pauses one publisher
inside that critical section and proves a second publisher cannot check or exchange the same path.
This lock coordinates cooperating Polylane publishers. Protection against an arbitrary same-UID
process that ignores the lock and mutates these private names is outside the threat model. The
lock-bypassing destination-change injection therefore asserts only final convergence: the helper
detects the displaced mismatch, exchanges back, preserves the injected winner, and fails. It does
not claim reader invisibility during that adversarial exchange/rollback interval.
Activation journal `PUBLISHED`→`COMMITTED` reaches disk only through this same primitive.
Release directories use `renameat2(RENAME_NOREPLACE)` on Linux or
`renameatx_np(RENAME_EXCL)` on macOS, followed by parent fsync and inode comparison; absence of
an exclusive primitive is an installation failure. The release path is not pointer-visible until
post-rename identity verification; a mismatch is synchronously quarantined and the final release
name is removed before failure. Under the cooperative-publisher threat model above, source-swap and
ancestor-symlink faults may leave a private or quarantined artifact but do not commit mismatched
bytes through the public pointer.
Retain the prior release until the new pointer is published and verified. A destination-scoped
publish lock records PID, process-start token, and nonce before a unique private initializer
is atomically renamed into the public path. There is no ownerless initialization grace,
meta-reclaim gate, or rename-quarantine protocol. A stale owner is closed only by a complete,
hard-linked, claimant-owned `.close.<claim-nonce>` marker inside the observed lock directory;
the claimant revalidates owner bytes and both process identities immediately before `rmdir`.
Dead close markers are independently removable only after their claimant token is dead.
All PID identity checks use the shared fail-closed helper: Linux reads field 22 start ticks from
`/proc/<pid>/stat`, while macOS calls `proc_pidinfo(PROC_PIDTBSDINFO)` through `libproc` and binds
seconds plus microseconds. Unsupported platforms, short structures, missing processes, and parse
errors fail closed; second-resolution `ps lstart` hashes are forbidden. The same-second/PID-reuse
fixture proves a prior birth token cannot authenticate another process.

For a pre-existing legacy directory, perform a one-time rollback-safe migration: rename it
to a uniquely named legacy release, create the temporary pointer, then atomically publish
the pointer. Before the rename, persist and seal one authenticated record containing the
canonical destination, backup, expected candidate pointer, publisher PID/start token,
one-use nonce, and nonce-bound commit path; the independent guard accepts exactly that one
record argument. Record, seal, maintenance notice, guard-live proof, commit marker, and
rollback marker are mode-0400 regular files published with O_EXCL private creation plus
exclusive hard links. Before the first legacy rename, the publisher must validate a sealed
guard-live proof binding the record hash to the still-live guard PID/start token. After
publisher death the guard reclaims the destination lock, revalidates
the record, and restores only when the current pointer is absent or still exactly the
recorded candidate. A different successor pointer wins. The publisher trap handles ordinary
signals/errors while holding the same lock; the guard covers publisher SIGKILL. The two named test-only fault
points fire after the legacy rename and just before pointer publication. A first legacy
migration is rollback-safe but, because portable POSIX directory exchange is unavailable,
is performed only when no Polylane process is using that destination; every later pointer
upgrade is one lock-free atomic rename. Never delete the previous release in the publishing process.
Enforce that precondition mechanically with `migration-preflight` under the same publish/
maintenance lock, using owned tmux tags, validated runtime PID/start-token records, and
bounded process inspection that preserves complete argv strings and resolves physical
executables, script aliases, relative script paths, and process working directories on
Linux and macOS. Linux reads NUL-delimited `/proc/<pid>/cmdline`; macOS uses the bundled
`KERN_PROCARGS2` helper and fails closed if exact argv cannot be obtained, including for a
spaced symlink alias. Write a sibling maintenance record before
the final recheck; launchers encountering it persist a short recovery deadline and retry.
Build and validate the candidate and temporary symlink first, then perform the legacy-
directory rename and public-pointer rename adjacently with no intervening work. The one-time
conversion is rollback-safe maintenance, not atomic; documentation and test output must use
that wording.
Doctor follows the public pointer, verifies the complete bytes/path/type/mode seal without modifying the package, and
reports `match`, `mixed`, or `unrecorded`.
When guarded activation is requested, the publisher validates both release trees, writes
the `PREPARED` journal plus an immediate sealed preparation snapshot/deadline, and starts
`polylane-install-guard.sh` before
the public pointer swap. The detached guard validates its sealed copy and publishes a
PID/start-token live-ready proof; the publisher rechecks that proof immediately before the
swap. In `PREPARED` the guard watches publisher identity and the sealed preparation deadline,
publishing an immutable guard-owned expiry proof before blocking on the destination lock.
The publisher rechecks both that proof and the deadline immediately before the pointer swap,
so expiry is enforced even while the publisher remains live and owns the lock. After the pointer
swap it rechecks preparation state, proof, and deadline again before the `PREPARED`→`PUBLISHED`
CAS; expiry at that boundary seals expiry evidence and rolls back under that same destination
lock. The exact `delay-after-prepared-check-before-pointer-swap` and
`delay-after-pointer-swap-before-published-cas` faults cover both transactions. It then watches
only certification-owner identity and the bounded
deadline. `certify-activation` is valid only in `PUBLISHED`: under the destination lock it
revalidates the active candidate, then on both sides of the exact
`delay-after-published-check-before-cas` boundary immediately before the state CAS revalidates both the
certification-owner PID/start token and deadline. Failure uses an already-held-lock rollback
helper; success performs one atomic PUBLISHED-to-COMMITTED journal rename containing
nonce/candidate/whole-manifest commit evidence. Owner death before that
rename rolls back; owner death after it retains the candidate. There is no marker-before-
state ambiguity and no PUBLISHED-to-COMMITTED repair path. Rollback takes the same destination
lock, accepts only `PREPARED` or `PUBLISHED`, recomputes both manifests, compares the current
symlink and candidate hash to the journal, and CASes to `ROLLED_BACK`. It removes a
first-install pointer only when that symlink still names the candidate, never overwrites a
newer activation, and retains the failed release and journal for diagnostics.
If the publisher dies or the preparation deadline expires before guard bootstrap completes,
guard/wait recovery validates the sealed preparation snapshot, retains or restores the
recorded prior pointer under the destination lock, and CASes `PREPARED` to `ROLLED_BACK`
(or `STALE` if a newer pointer already won); it never waits forever for guard-ready.
In `PUBLISHED`, `wait-activation` validates guard identity on every iteration and becomes a
bounded replacement monitor when that guard dies. Malformed JSON or an unknown state is
reconstructed under the destination lock from the sealed guard copy (or sealed preparation
copy) to `COMMITTED`, `ROLLED_BACK`, or `STALE`, then revalidates that terminal state rather
than waiting indefinitely. The preparation timeout is rejected unless it safely exceeds the
fixed guard-bootstrap bound.

```bash
core_revision() {
  find "$REPO/core" -type f -print | LC_ALL=C sort | while IFS= read -r file; do
    printf '%s  %s\n' "$(git hash-object "$file")" "${file#"$REPO/"}"
  done | git hash-object --stdin
}
```

Codex copies `codex/agents/openai.yaml`; Claude does not. Codex user destination is
`${CODEX_HOME:-$HOME/.codex}/skills/polylane`, with `~/.agents/skills/polylane` as the
documented fallback only when Codex home cannot be used. Claude destination remains
`~/.claude/skills/polylane`.

- [ ] **Step 8: Add the complete deterministic package publisher (5 minutes)**

Create executable `core/scripts/polylane-procargs-macos` first. It is the exact
`KERN_PROCARGS2` helper used by legacy migration; when `/usr/bin/python3` or the sysctl is
unavailable it fails closed instead of falling back to whitespace-split `ps` text:

```bash
#!/usr/bin/env bash
set -eu
[ "$(uname -s)" = Darwin ] || { echo "polylane-procargs-macos: Darwin required" >&2; exit 2; }
[ -x /usr/bin/python3 ] || { echo "polylane-procargs-macos: /usr/bin/python3 required" >&2; exit 2; }
exec /usr/bin/python3 - "$1" <<'PY'
import ctypes, struct, sys
pid = int(sys.argv[1])
if pid <= 0:
    raise SystemExit(2)
libc = ctypes.CDLL(None, use_errno=True)
CTL_KERN, KERN_ARGMAX, KERN_PROCARGS2 = 1, 8, 49
argmax = ctypes.c_int()
size = ctypes.c_size_t(ctypes.sizeof(argmax))
mib2 = (ctypes.c_int * 2)(CTL_KERN, KERN_ARGMAX)
if libc.sysctl(mib2, 2, ctypes.byref(argmax), ctypes.byref(size), None, 0) != 0:
    raise SystemExit(2)
buf = ctypes.create_string_buffer(argmax.value)
size = ctypes.c_size_t(argmax.value)
mib3 = (ctypes.c_int * 3)(CTL_KERN, KERN_PROCARGS2, pid)
if libc.sysctl(mib3, 3, buf, ctypes.byref(size), ctypes.c_void_p(), 0) != 0:
    raise SystemExit(2)
raw = bytes(buf.raw[:size.value])
if len(raw) < 4:
    raise SystemExit(2)
argc = struct.unpack_from("=i", raw)[0]
if argc < 0 or argc > 1048576:
    raise SystemExit(2)
pos = 4
end = raw.find(b"\0", pos)
if end < 0:
    raise SystemExit(2)
pos = end + 1
while pos < len(raw) and raw[pos] == 0:
    pos += 1
argv = []
for _ in range(argc):
    end = raw.find(b"\0", pos)
    if end < 0:
        raise SystemExit(2)
    argv.append(raw[pos:end]); pos = end + 1
if len(argv) != argc:
    raise SystemExit(2)
sys.stdout.buffer.write(b"\0".join(argv) + (b"\0" if argv else b""))
PY
```

Run: `chmod +x core/scripts/polylane-procargs-macos`

Create executable `core/scripts/polylane-package.sh` with this complete body:

```bash
#!/usr/bin/env bash
set -euo pipefail
umask 077
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$SCRIPT_DIR/../.." && pwd)
GUARD="$SCRIPT_DIR/polylane-install-guard.sh"
FS="$SCRIPT_DIR/polylane-fs.py"
[ -f "$FS" ] && [ ! -L "$FS" ] && command -v python3 >/dev/null 2>&1 || exit 2
fs() { python3 "$FS" "$@"; }
safe_mkdirs() { fs mkdirs "$1" "${2:-0700}"; }
private_from_stdin() { fs create "$1" "${2:-0600}"; }
capture_private() { local path=$1 mode=$2; shift 2; fs capture "$path" "$mode" "$@"; }
copy_private() { fs copy-exclusive "$1" "$2" "${3:-0600}"; }
LOCK=""; LOCK_NONCE=""; LOCK_INIT=""; LOCK_INIT_INODE=""
LOCK_CLOSE_INIT=""; LOCK_CLOSE_MARKER=""; LOCK_CLOSE_HASH=""
LEGACY_DEST=""; LEGACY_BACKUP=""; LEGACY_COMMIT=""; LEGACY_EXPECTED=""

die() { rc=$1; shift; echo "polylane-package: $*" >&2; exit "$rc"; }
hash_file() { git hash-object "$1"; }
activation_record_path() {
  input=$1; case "$input" in /*) : ;; *) return 1 ;; esac
  base=$(basename "$input"); case "$base" in ''|.|..) return 1 ;; esac
  parent=$(cd "$(dirname "$input")" 2>/dev/null && pwd -P) || return 1
  path="$parent/$base"
  for suffix in '' .prepare-copy .prepare-seal .guard-copy .guard-seal .guard-ready \
    .guard-live .prepare-expired .recovered; do
    entry="$path$suffix"
    [ ! -L "$entry" ] || return 1
    [ ! -e "$entry" ] || [ -f "$entry" ] || return 1
  done
  printf '%s\n' "$path"
}
process_start_token() {
  fs process-start-token "$1" 2>/dev/null
}
process_matches() {
  [ -n "${1:-}" ] && [ -n "${2:-}" ] || return 1
  kill -0 "$1" 2>/dev/null && [ "$(process_start_token "$1")" = "$2" ]
}
path_inode() {
  case "$(uname -s)" in Linux) stat -c '%i' "$1" ;; *) stat -f '%i' "$1" ;; esac
}
canonical_dest() {
  case "$1" in /*) : ;; *) return 2 ;; esac
  [ "$1" != / ] && [ -n "$1" ] || return 2
  case "$1" in */.|*/..) return 2 ;; esac
  base=$(basename "$1"); case "$base" in ''|.|..) return 2 ;; esac
  safe_mkdirs "$(dirname "$1")" 0700
  parent=$(cd "$(dirname "$1")" && pwd -P)
  dest="$parent/$base"; identity=$dest
  if [ -e "$dest" ]; then
    [ -d "$dest" ] || return 2
    identity=$(cd "$dest" && pwd -P) || return 2
  fi
  [ "$identity" != "$REPO" ] || return 2
  printf '%s\n' "$dest"
}
core_revision() {
  find "$REPO/core" -type f -print | LC_ALL=C sort | while IFS= read -r file; do
    printf '%s  %s\n' "$(git hash-object "$file")" "${file#"$REPO/"}"
  done | git hash-object --stdin
}
release_manifest_hash() {
  [ "${1:-null}" != null ] && [ -f "$1/.polylane-package-manifest" ] || { printf null; return; }
  hash_file "$1/.polylane-package-manifest"
}
atomic_filter() {
  file=$1; filter=$2; shift 2
  [ -f "$file" ] && [ ! -L "$file" ] && [ "$(mode_of "$file")" = 0600 ] || return 7
  tmp="$file.tmp.$$"
  [ ! -e "$tmp" ] && [ ! -L "$tmp" ] || return 7
  capture_private "$tmp" 0600 jq "$@" "$filter" "$file" || return 7
  replace_file_nofollow "$tmp" "$file" 0600 existing
}
mode_of() {
  local permissions
  case "$(uname -s)" in
    Linux) permissions=$(stat -c '%a' "$1") ;;
    Darwin|FreeBSD|OpenBSD|NetBSD) permissions=$(stat -f '%Lp' "$1") ;;
    *) return 2 ;;
  esac
  permissions=${permissions#0}
  printf '0%s\n' "$permissions"
}
replace_file_nofollow() {
  local tmp=$1 dest=$2 mode=$3 policy=$4 expected
  [ -f "$tmp" ] && [ ! -L "$tmp" ] && [ "$(mode_of "$tmp")" = "$mode" ] || return 7
  expected=$(hash_file "$tmp")
  case "$policy" in
    absent)
      [ ! -e "$dest" ] && [ ! -L "$dest" ] || return 7
      fs link-exclusive "$tmp" "$dest" || return 7
      fs unlink-private "$tmp" ;;
    existing) [ -f "$dest" ] && [ ! -L "$dest" ] && [ "$(mode_of "$dest")" = "$mode" ] || return 7 ;;
    *) return 7 ;;
  esac
  [ "$policy" != existing ] || fs replace-existing-file "$tmp" "$dest" || return 7
  [ -f "$dest" ] && [ ! -L "$dest" ] && [ "$(mode_of "$dest")" = "$mode" ] && \
    [ "$(hash_file "$dest")" = "$expected" ]
}
publish_public_immutable() {
  local source=$1 dest=$2 mode=${3:-0400}
  [ -f "$source" ] && [ ! -L "$source" ] || return 7
  chmod "$mode" "$source" || return 7
  replace_file_nofollow "$source" "$dest" "$mode" absent
}
remove_public_if_owned() {
  local file=$1 expected=$2
  [ -f "$file" ] && [ ! -L "$file" ] && [ "$(mode_of "$file")" = 0400 ] && \
    [ "$(hash_file "$file")" = "$expected" ] || return 7
  fs unlink-private "$file"
}
activation_file_valid() {
  [ -f "$1" ] && [ ! -L "$1" ] && [ "$(mode_of "$1")" = "$2" ]
}
normalized_mode() {
  local mode
  mode=$(mode_of "$1") || return
  case "$mode" in 0444|0555) printf '%s\n' "$mode" ;; *) return 1 ;; esac
}
owner_snapshot_file() {
  local file=$1
  if [ ! -e "$file" ] && [ ! -L "$file" ]; then printf ownerless; return 0; fi
  [ -f "$file" ] && [ ! -L "$file" ] && [ "$(mode_of "$file")" = 0600 ] || return 7
  jq -cSe '
    select(type=="object" and keys==["nonce","pid","start_token"] and
      (.pid|type)=="number" and .pid>0 and .pid==(.pid|floor) and
      (.start_token|type)=="string" and (.start_token|length)>0 and
      (.nonce|type)=="string" and (.nonce|length)>0)
    | {pid,start_token,nonce}' "$file"
}
lock_owner_snapshot() {
  [ -d "$LOCK" ] && [ ! -L "$LOCK" ] || return 7
  owner_snapshot_file "$LOCK/owner.json"
}
remove_owned_init() {
  local init=${1:-} nonce=${2:-} owner
  [ -n "$init" ] && [ -d "$init" ] && [ ! -L "$init" ] || return 0
  owner=$(jq -r '.nonce // ""' "$init/owner.json" 2>/dev/null || true)
  if [ "$owner" = "$nonce" ] && [ -f "$init/owner.json" ] && \
    [ ! -L "$init/owner.json" ] && [ "$(mode_of "$init/owner.json")" = 0600 ]; then
    fs unlink-private "$init/owner.json" 2>/dev/null || return 0
    rmdir "$init" 2>/dev/null || true
  fi
}
close_marker_snapshot() {
  local marker=$1
  [ -f "$marker" ] && [ ! -L "$marker" ] && [ "$(mode_of "$marker")" = 0400 ] || return 7
  jq -cSe '
    select(type=="object" and
      keys==["claim_nonce","claimant","owner_snapshot","schema_version"] and
      .schema_version==1 and (.owner_snapshot|type)=="string" and
      (.claim_nonce|type)=="string" and (.claim_nonce|length)>0 and
      (.claimant|type)=="object" and
      (.claimant|keys)==["pid","start_token"] and
      (.claimant.pid|type)=="number" and .claimant.pid>0 and
      .claimant.pid==(.claimant.pid|floor) and
      (.claimant.start_token|type)=="string" and (.claimant.start_token|length)>0)
    | {schema_version,owner_snapshot,claim_nonce,claimant}' "$marker"
}
publish_close_marker() {
  local observed=$1 claim_nonce self_token payload current
  claim_nonce="$$-$(date +%s)-${RANDOM:-0}"
  self_token=$(process_start_token $$) || return 7
  LOCK_CLOSE_INIT="$LOCK.close-init.$claim_nonce"
  LOCK_CLOSE_MARKER="$LOCK/.close.$claim_nonce"
  [ ! -e "$LOCK_CLOSE_INIT" ] && [ ! -L "$LOCK_CLOSE_INIT" ] || return 7
  payload=$(jq -cnS --arg owner "$observed" --arg nonce "$claim_nonce" \
    --argjson pid "$$" --arg token "$self_token" \
    '{schema_version:1,owner_snapshot:$owner,claim_nonce:$nonce,
      claimant:{pid:$pid,start_token:$token}}')
  printf '%s\n' "$payload" | private_from_stdin "$LOCK_CLOSE_INIT" 0400 || return 7
  LOCK_CLOSE_HASH=$(hash_file "$LOCK_CLOSE_INIT")
  if ! fs link-exclusive "$LOCK_CLOSE_INIT" "$LOCK_CLOSE_MARKER"; then
    fs unlink-private "$LOCK_CLOSE_INIT" 2>/dev/null || true
    LOCK_CLOSE_INIT=""; LOCK_CLOSE_MARKER=""; LOCK_CLOSE_HASH=""
    return 1
  fi
  fs unlink-private "$LOCK_CLOSE_INIT" || return 7; LOCK_CLOSE_INIT=""
  current=$(close_marker_snapshot "$LOCK_CLOSE_MARKER") || { remove_own_close_marker; return 7; }
  [ "$current" = "$payload" ] && [ "$(hash_file "$LOCK_CLOSE_MARKER")" = "$LOCK_CLOSE_HASH" ] || \
    { remove_own_close_marker; return 7; }
}
remove_own_close_marker() {
  if [ -n "$LOCK_CLOSE_MARKER" ] && [ -f "$LOCK_CLOSE_MARKER" ] && \
    [ ! -L "$LOCK_CLOSE_MARKER" ] && [ "$(mode_of "$LOCK_CLOSE_MARKER")" = 0400 ] && \
    [ "$(hash_file "$LOCK_CLOSE_MARKER")" = "$LOCK_CLOSE_HASH" ]; then
    fs unlink-private "$LOCK_CLOSE_MARKER" 2>/dev/null || true
  fi
  LOCK_CLOSE_INIT=""; LOCK_CLOSE_MARKER=""; LOCK_CLOSE_HASH=""
}
clean_dead_close_artifacts() {
  local marker snapshot marker_nonce pid token current init observed
  for marker in "$LOCK"/.close.*; do
    [ -e "$marker" ] || [ -L "$marker" ] || continue
    [ "$marker" != "$LOCK_CLOSE_MARKER" ] || continue
    snapshot=$(close_marker_snapshot "$marker") || return 7
    marker_nonce=${marker##*/.close.}
    [ "$(printf '%s' "$snapshot" | jq -r .claim_nonce)" = "$marker_nonce" ] || return 7
    pid=$(printf '%s' "$snapshot" | jq -r .claimant.pid)
    token=$(printf '%s' "$snapshot" | jq -r .claimant.start_token)
    if ! process_matches "$pid" "$token"; then
      current=$(close_marker_snapshot "$marker") || return 7
      [ "$current" = "$snapshot" ] && fs unlink-private "$marker"
    fi
  done
  for init in "$LOCK/${LOCK##*/}.init."*; do
    [ -e "$init" ] || [ -L "$init" ] || continue
    [ -d "$init" ] && [ ! -L "$init" ] || return 7
    observed=$(owner_snapshot_file "$init/owner.json") || return 7
    [ "$observed" != ownerless ] || { rmdir "$init" 2>/dev/null || true; continue; }
    pid=$(printf '%s' "$observed" | jq -r .pid)
    token=$(printf '%s' "$observed" | jq -r .start_token)
    if ! process_matches "$pid" "$token"; then
      fs unlink-private "$init/owner.json"
      rmdir "$init" 2>/dev/null || true
    fi
  done
}
close_observed_lock() {
  local observed=$1 reason=$2 current pid token nonce marker
  publish_close_marker "$observed" || return
  marker=$LOCK_CLOSE_MARKER
  current=$(lock_owner_snapshot) || { remove_own_close_marker; return 7; }
  [ "$current" = "$observed" ] || { remove_own_close_marker; return 1; }
  if [ "$observed" != ownerless ]; then
    pid=$(printf '%s' "$observed" | jq -r .pid)
    token=$(printf '%s' "$observed" | jq -r .start_token)
    nonce=$(printf '%s' "$observed" | jq -r .nonce)
    case "$reason" in
      release)
        if [ "$pid" != "$$" ] || [ "$nonce" != "$LOCK_NONCE" ] || \
          ! process_matches "$pid" "$token"; then
          remove_own_close_marker; return 1
        fi ;;
      reclaim)
        ! process_matches "$pid" "$token" || { remove_own_close_marker; return 1; } ;;
      *) remove_own_close_marker; return 7 ;;
    esac
  fi
  [ "${POLYLANE_PACKAGE_HOLD_STALE_CLOSE:-0}" != 1 ] || sleep 0.5
  case "${POLYLANE_PACKAGE_FAULT:-}" in sigkill-after-lock-close-marker) kill -9 $$ ;; esac
  [ -f "$marker" ] && [ ! -L "$marker" ] && [ "$(mode_of "$marker")" = 0400 ] && \
    [ "$(hash_file "$marker")" = "$LOCK_CLOSE_HASH" ] || \
    { remove_own_close_marker; return 7; }
  current=$(lock_owner_snapshot) || { remove_own_close_marker; return 7; }
  [ "$current" = "$observed" ] || { remove_own_close_marker; return 1; }
  if [ "$observed" != ownerless ]; then
    pid=$(printf '%s' "$observed" | jq -r .pid)
    token=$(printf '%s' "$observed" | jq -r .start_token)
    [ "$reason" = release ] || ! process_matches "$pid" "$token" || \
      { remove_own_close_marker; return 1; }
    fs unlink-private "$LOCK/owner.json"
  fi
  clean_dead_close_artifacts || { remove_own_close_marker; return 7; }
  remove_own_close_marker
  rmdir "$LOCK" 2>/dev/null || true
}
cleanup() {
  [ -z "$LOCK_CLOSE_INIT" ] || { [ ! -e "$LOCK_CLOSE_INIT" ] || \
    fs unlink-private "$LOCK_CLOSE_INIT" 2>/dev/null || true; }
  remove_own_close_marker
  remove_owned_init "$LOCK_INIT" "$LOCK_NONCE"
  if [ -n "$LEGACY_BACKUP" ] && [ ! -e "$LEGACY_COMMIT" ] && [ -d "$LEGACY_BACKUP" ]; then
    current=$(readlink "$LEGACY_DEST" 2>/dev/null || printf null)
    if [ "$current" = "$LEGACY_EXPECTED" ]; then fs unlink-symlink "$LEGACY_DEST"; current=null; fi
    [ "$current" != null ] || mv "$LEGACY_BACKUP" "$LEGACY_DEST" 2>/dev/null || true
  fi
  if [ -n "$LOCK" ] && [ -d "$LOCK" ]; then
    observed=$(lock_owner_snapshot 2>/dev/null || printf corrupt)
    [ "$observed" = corrupt ] || [ "$observed" = ownerless ] || \
      [ "$(printf '%s' "$observed" | jq -r .nonce)" != "$LOCK_NONCE" ] || \
      close_observed_lock "$observed" release || true
  fi
}
trap cleanup EXIT INT TERM

acquire_lock() {
  dest=$1; LOCK="$dest.polylane-lock"; LOCK_NONCE="$$-$(date +%s)-${RANDOM:-0}"
  self_token=$(process_start_token $$)
  owner_payload=$(jq -cn --argjson pid "$$" --arg token "$self_token" --arg nonce "$LOCK_NONCE" \
    '{pid:$pid,start_token:$token,nonce:$nonce}')
  prepare_lock_init() {
    LOCK_INIT="$LOCK.init.$LOCK_NONCE"
    [ ! -e "$LOCK_INIT" ] && [ ! -L "$LOCK_INIT" ] || die 7 "lock initializer collision"
    fs mkdir-exclusive "$LOCK_INIT" 0700 || die 7 "cannot create lock initializer"
    printf '%s\n' "$owner_payload" | private_from_stdin "$LOCK_INIT/owner.json" 0600 || \
      die 7 "cannot publish lock owner"
    LOCK_INIT_INODE=$(path_inode "$LOCK_INIT") || die 7 "cannot identify lock initializer"
  }
  prepare_lock_init
  delay=${POLYLANE_PACKAGE_LOCK_INIT_DELAY:-0}
  case "$delay" in ''|*[!0-9]*) die 2 "invalid lock initializer delay" ;; esac
  [ "$delay" = 0 ] || sleep "$delay"
  while :; do
    [ ! -L "$LOCK" ] || die 7 "lock path must not be a symlink"
    if [ ! -e "$LOCK" ]; then
      init_base=${LOCK_INIT##*/}
      if mv "$LOCK_INIT" "$LOCK" 2>/dev/null; then
        current_inode=$(path_inode "$LOCK" 2>/dev/null || true)
        current_nonce=$(jq -r '.nonce // ""' "$LOCK/owner.json" 2>/dev/null || true)
        if [ "$current_inode" = "$LOCK_INIT_INODE" ] && [ "$current_nonce" = "$LOCK_NONCE" ]; then
          LOCK_INIT=""
          break
        fi
        nested="$LOCK/$init_base"
        nested_inode=$(path_inode "$nested" 2>/dev/null || true)
        nested_nonce=$(jq -r '.nonce // ""' "$nested/owner.json" 2>/dev/null || true)
        if [ "$nested_inode" = "$LOCK_INIT_INODE" ] && [ "$nested_nonce" = "$LOCK_NONCE" ]; then
          remove_owned_init "$nested" "$LOCK_NONCE"
        fi
        LOCK_INIT=""
      fi
      [ -d "$LOCK_INIT" ] || prepare_lock_init
      sleep 0.05
      continue
    fi
    [ -d "$LOCK" ] || die 7 "lock path must be a directory"
    observed=$(lock_owner_snapshot) || die 7 "invalid lock owner record"
    if [ "$observed" = ownerless ]; then
      close_observed_lock "$observed" reclaim || true
    else
      pid=$(printf '%s' "$observed" | jq -r '.pid // 0' 2>/dev/null || echo 0)
      token=$(printf '%s' "$observed" | jq -r '.start_token // ""' 2>/dev/null || true)
      process_matches "$pid" "$token" || close_observed_lock "$observed" reclaim || true
    fi
    sleep 0.05
  done
  hold=${POLYLANE_PACKAGE_LOCK_HOLD_SECONDS:-0}
  case "$hold" in ''|*[!0-9]*) die 2 "invalid lock hold duration" ;; esac
  if [ "${POLYLANE_PACKAGE_HOLD_LOCK:-0}" = 1 ] && [ "$hold" = 0 ]; then hold=1; fi
  [ "$hold" = 0 ] || sleep "$hold"
}

verify_release() {
  root=$(cd "$1" 2>/dev/null && pwd -P) || return 1
  [ -d "$root" ] && [ -s "$root/.polylane-core-revision" ] && \
    [ -s "$root/.polylane-core-manifest" ] && \
    [ -s "$root/.polylane-package-manifest" ] || return 1
  while IFS= read -r line; do
    want=${line%% *}; rel=${line#*  }
    [ -n "$rel" ] && [ -f "$root/$rel" ] && [ "$(hash_file "$root/$rel")" = "$want" ] || return 1
  done < "$root/.polylane-core-manifest"
  while IFS= read -r line; do
    want=${line%% *}; fields=${line#*  }; want_type=${fields%% *}; fields=${fields#*  }
    want_mode=${fields%% *}; rel=${fields#*  }
    [ -n "$rel" ] || return 1
    case "$want_type" in
      f) [ -f "$root/$rel" ] && [ ! -L "$root/$rel" ] && \
        [ "$(normalized_mode "$root/$rel")" = "$want_mode" ] && \
        [ "$(hash_file "$root/$rel")" = "$want" ] || return 1 ;;
      d) [ "$want" = - ] && [ -d "$root/$rel" ] && [ ! -L "$root/$rel" ] && \
        [ "$(normalized_mode "$root/$rel")" = 0555 ] || return 1 ;;
      *) return 1 ;;
    esac
  done < "$root/.polylane-package-manifest"
  actual=$(mktemp "${TMPDIR:-/tmp}/polylane-package-files.XXXXXX") || return 1
  recorded=$(mktemp "${TMPDIR:-/tmp}/polylane-recorded-files.XXXXXX") || { rm -f "$actual"; return 1; }
  find "$root" -mindepth 1 -print | while IFS= read -r file; do
    [ "$file" != "$root/.polylane-package-manifest" ] || continue
    printf '%s\n' "${file#"$root/"}"
  done | \
    LC_ALL=C sort > "$actual"
  sed 's/^[^ ]*  [^ ]*  [^ ]*  //' "$root/.polylane-package-manifest" | \
    LC_ALL=C sort > "$recorded"
  if ! cmp -s "$actual" "$recorded"; then rm -f "$actual" "$recorded"; return 1; fi
  rm -f "$actual" "$recorded"
  [ -f "$root/.polylane-package-manifest" ] && \
    [ ! -L "$root/.polylane-package-manifest" ] && \
    [ "$(normalized_mode "$root/.polylane-package-manifest")" = 0444 ] && \
    [ "$(normalized_mode "$root")" = 0555 ] || return 1
  refs=$(sed -n 's/.*](\(references\/[^)]*\)).*/\1/p' "$root/SKILL.md" | LC_ALL=C sort -u)
  for rel in $refs; do [ -f "$root/$rel" ] || return 1; done
}

safe_relative() {
  case "${1:-}" in ''|/*|..|../*|*/../*|*/..|.|./*|*/./*|*/.|*//*|*/|-*|*/-*) return 1 ;; esac
  lines=$(printf '%s\n' "$1" | wc -l | tr -d '[:space:]')
  [ "$lines" = 1 ] || return 1
  printf '%s\n' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9._/@%+=:,-]+$'
}

validate_source_tree() {
  source_root=$1; [ -e "$source_root" ] || return 0
  [ -d "$source_root" ] && [ ! -L "$source_root" ] || return 6
  special=$(find "$source_root" -mindepth 1 ! -type d ! -type f -print -quit)
  [ -z "$special" ] || return 6
  find "$source_root" -type f -print | LC_ALL=C sort | while IFS= read -r source; do
    relative=${source#"$source_root/"}; safe_relative "$relative" || exit 6
    printf '%s\n' "$relative"
  done | awk '{ folded=tolower($0); if (seen[folded]++) exit 6 }'
}

copy_tree_no_clobber() {
  src_root=$1; target_root=$2; executable=$3
  [ -d "$src_root" ] || return 0
  validate_source_tree "$src_root" || return 6
  find "$src_root" -type f -print | LC_ALL=C sort | while IFS= read -r src; do
    rel=${src#"$src_root/"}; safe_relative "$rel" || exit 6
    target="$target_root/$rel"; [ ! -e "$target" ] && [ ! -L "$target" ] || exit 6
    safe_mkdirs "$(dirname "$target")" 0700 || exit 6
    copy_private "$src" "$target" 0600 || exit 6
    [ "$executable" != 1 ] || chmod +x "$target"
  done
}

copy_core_tree() {
  src_root=$1; target_root=$2; force_executable=$3; core_manifest=$4
  [ -d "$src_root" ] || return 0
  validate_source_tree "$src_root" || return 6
  find "$src_root" -type f -print | LC_ALL=C sort | while IFS= read -r src; do
    rel=${src#"$src_root/"}; safe_relative "$rel" || exit 6
    target="$target_root/$rel"; [ ! -e "$target" ] && [ ! -L "$target" ] || exit 6
    safe_mkdirs "$(dirname "$target")" 0700 || exit 6
    copy_private "$src" "$target" 0600 || exit 6
    if [ "$force_executable" = 1 ] || [ -x "$src" ]; then
      chmod +x "$target"
    else
      chmod a-x "$target"
    fi
    package_rel=${target#"$staging/"}
    printf '%s  %s\n' "$(hash_file "$src")" "$package_rel" | fs append "$core_manifest"
  done
}

rewrite_adapter_links() {
  skill=$1; source_root=$2; kind=$3; namespace=$4
  [ -d "$source_root" ] || return 0
  safe_relative "$namespace" || return 6
  find "$source_root" -type f -print | LC_ALL=C sort | while IFS= read -r src; do
    rel=${src#"$source_root/"}; safe_relative "$rel" || exit 6
    old="$kind/$rel"; new="$kind/$namespace/$rel"; tmp="$skill.tmp.$$"
    capture_private "$tmp" 0600 awk -v old="$old" -v new="$new" '
      { line=$0; out=""; while ((at=index(line,old)) != 0) {
          out=out substr(line,1,at-1) new; line=substr(line,at+length(old))
        }
        print out line
      }' "$skill" && replace_file_nofollow "$tmp" "$skill" 0600 existing
  done
}

assemble() {
  adapter=$1; dest=$2; revision=$(core_revision)
  case "$adapter" in ''|*[!A-Za-z0-9._-]*) die 2 "invalid adapter name" ;; esac
  adapter_root="$REPO/$adapter"; descriptor="$adapter_root/package.json"
  [ -s "$descriptor" ] || die 2 "adapter descriptor not found: $adapter"
  [ ! -L "$descriptor" ] && [ -f "$adapter_root/SKILL.md" ] && \
    [ ! -L "$adapter_root/SKILL.md" ] || die 6 "adapter descriptor/skill must be regular files"
  jq -e --arg adapter "$adapter" '
    .schema_version==1 and .name==$adapter and
    (.reference_namespace|type=="string" and length>0) and
    (.asset_namespace|type=="string" and length>0) and
    (.scripts_dir|type=="string" and length>0) and
    (.references_dir|type=="string" and length>0) and
    ((.assets_dir==null) or (.assets_dir|type=="string" and length>0)) and
    (.policy_hook|type=="string" and length>0) and (.metadata|type=="array")' \
    "$descriptor" >/dev/null || die 6 "invalid adapter descriptor"
  ref_namespace=$(jq -r .reference_namespace "$descriptor")
  asset_namespace=$(jq -r .asset_namespace "$descriptor")
  scripts_dir=$(jq -r .scripts_dir "$descriptor")
  references_dir=$(jq -r .references_dir "$descriptor")
  assets_dir=$(jq -r '.assets_dir // ""' "$descriptor")
  policy_hook=$(jq -r .policy_hook "$descriptor")
  for value in "$ref_namespace" "$asset_namespace" "$scripts_dir" "$references_dir" "$policy_hook"; do
    safe_relative "$value" || die 6 "unsafe adapter descriptor path"
  done
  [ -z "$assets_dir" ] || safe_relative "$assets_dir" || die 6 "unsafe adapter assets path"
  releases="$dest.polylane-releases"
  if [ ! -e "$releases" ] && [ ! -L "$releases" ]; then
    fs mkdir-exclusive "$releases" 0755 || die 6 "cannot create release root"
  fi
  [ -d "$releases" ] && [ ! -L "$releases" ] && \
    [ "$(cd "$releases" && pwd -P)" = "$releases" ] || die 6 "release root must be physical"
  nonce=${POLYLANE_PACKAGE_TEST_NONCE:-"$(date +%s)-$$-${RANDOM:-0}"}
  case "$nonce" in ''|*[!A-Za-z0-9._-]*) die 6 "unsafe package nonce" ;; esac
  staging="$releases/.staging-$nonce"; release="$releases/$revision-$nonce"
  [ ! -e "$staging" ] && [ ! -L "$staging" ] && fs mkdir-exclusive "$staging" 0700 || \
    die 6 "exclusive staging allocation failed"
  [ -d "$staging" ] && [ ! -L "$staging" ] || die 6 "unsafe staging root"
  for directory in "$staging/scripts" "$staging/references/$ref_namespace" \
    "$staging/assets/$asset_namespace" "$staging/adapter"; do
    safe_mkdirs "$directory" 0700 || die 6 "cannot create staging directory"
  done
  manifest="$staging/.polylane-core-manifest.unsorted"
  private_from_stdin "$manifest" 0600 </dev/null || die 6 "cannot allocate core manifest"
  for entry in "$REPO/core"/*; do
    [ -e "$entry" ] || continue
    case "${entry##*/}" in
      scripts|references|workflow|assets|config|bundled-skills|tests)
        [ -d "$entry" ] && [ ! -L "$entry" ] || die 6 "core top-level path must be a directory" ;;
      *) die 6 "unmapped core top-level path: ${entry##*/}" ;;
    esac
  done
  copy_core_tree "$REPO/core/scripts" "$staging/scripts" 1 "$manifest"
  copy_core_tree "$REPO/core/references" "$staging/references" 0 "$manifest"
  copy_core_tree "$REPO/core/assets" "$staging/assets" 0 "$manifest"
  copy_core_tree "$REPO/core/config" "$staging/config" 0 "$manifest"
  copy_core_tree "$REPO/core/bundled-skills" "$staging/bundled-skills" 0 "$manifest"
  src="$REPO/core/workflow/polylane-loop.md"; rel=references/polylane-loop.md
  [ -f "$src" ] && [ ! -L "$src" ] || die 6 "core workflow must be a regular file"
  copy_private "$src" "$staging/$rel" 0600 || die 6 "cannot copy core workflow"
  printf '%s  %s\n' "$(hash_file "$src")" "$rel" | fs append "$manifest"
  copy_private "$adapter_root/SKILL.md" "$staging/SKILL.md" 0600 || die 6 "cannot copy skill"
  copy_private "$descriptor" "$staging/adapter/package.json" 0600 || die 6 "cannot copy descriptor"
  copy_tree_no_clobber "$adapter_root/$scripts_dir" "$staging/scripts" 1 || \
    die 6 "adapter script collision"
  copy_tree_no_clobber "$adapter_root/$references_dir" \
    "$staging/references/$ref_namespace" 0 || die 6 "adapter reference collision"
  [ -z "$assets_dir" ] || copy_tree_no_clobber "$adapter_root/$assets_dir" \
    "$staging/assets/$asset_namespace" 0 || die 6 "adapter asset collision"
  rewrite_adapter_links "$staging/SKILL.md" "$adapter_root/$references_dir" \
    references "$ref_namespace" || die 6 "cannot namespace adapter references"
  [ -z "$assets_dir" ] || rewrite_adapter_links "$staging/SKILL.md" \
    "$adapter_root/$assets_dir" assets "$asset_namespace" || die 6 "cannot namespace adapter assets"
  jq -c '.metadata[]' "$descriptor" | while IFS= read -r item; do
    source=$(printf '%s' "$item" | jq -r .source)
    target=$(printf '%s' "$item" | jq -r .target)
    safe_relative "$source" && safe_relative "$target" || exit 6
    [ -f "$adapter_root/$source" ] && [ ! -L "$adapter_root/$source" ] && \
      [ ! -e "$staging/$target" ] || exit 6
    safe_mkdirs "$(dirname "$staging/$target")" 0700 || exit 6
    copy_private "$adapter_root/$source" "$staging/$target" 0600 || exit 6
  done || die 6 "invalid or colliding adapter metadata"
  capture_private "$staging/.polylane-core-manifest" 0600 \
    env LC_ALL=C sort -k2,2 "$manifest" || die 6 "cannot seal core manifest"
  fs unlink-private "$manifest" || die 6 "cannot remove core manifest temporary"
  printf '%s\n' "$revision" | private_from_stdin "$staging/.polylane-core-revision" 0600 || \
    die 6 "cannot seal core revision"
  [ -x "$staging/$policy_hook" ] || die 6 "adapter policy hook is not executable"
  "$staging/$policy_hook" validate "$staging" || die 6 "adapter package policy rejected candidate"
  duplicates=$(find "$staging" -type f -print | while IFS= read -r file; do
    printf '%s\n' "${file#"$staging/"}"
  done | awk '{ folded=tolower($0); if (seen[folded]++) print $0 }')
  [ -z "$duplicates" ] || die 6 "case-colliding package destinations"
  find "$staging" -type f ! -name '.polylane-package-manifest' -print | \
    while IFS= read -r file; do
      if [ -x "$file" ]; then chmod 0555 "$file"; else chmod 0444 "$file"; fi
    done
  find "$staging" -mindepth 1 -type d -exec chmod 0555 {} +
  package_manifest="$staging/.polylane-package-manifest"
  package_manifest_tmp="$releases/.package-manifest-$nonce"
  [ ! -e "$package_manifest_tmp" ] && [ ! -L "$package_manifest_tmp" ] || die 6 "unsafe package manifest temporary"
  ( find "$staging" -mindepth 1 -print | \
    LC_ALL=C sort | while IFS= read -r file; do
      if [ -f "$file" ] && [ ! -L "$file" ]; then
        printf '%s  f  %s  %s\n' "$(hash_file "$file")" "$(normalized_mode "$file")" \
          "${file#"$staging/"}"
      elif [ -d "$file" ] && [ ! -L "$file" ]; then
        printf '%s  d  0555  %s\n' - "${file#"$staging/"}"
      else
        exit 6
      fi
    done | private_from_stdin "$package_manifest_tmp" 0444 ) || \
    die 6 "cannot create package manifest temporary"
  replace_file_nofollow "$package_manifest_tmp" "$package_manifest" 0444 absent || \
    die 6 "exclusive package manifest publication failed"
  chmod 0555 "$staging"
  verify_release "$staging" || die 6 "candidate package failed validation"
  [ ! -e "$release" ] && [ ! -L "$release" ] || die 6 "release target already exists"
  fs rename-exclusive-dir "$staging" "$release" || die 6 "exclusive release publication failed"
  [ -d "$release" ] && [ ! -L "$release" ] || die 6 "release publication raced"
  chmod -R a-w "$release"
  printf '%s\n' "$release"
}

resolve_existing_path() {
  path=$1; case "$path" in /*) : ;; *) return 1 ;; esac
  i=0
  while [ -L "$path" ] && [ "$i" -lt 40 ]; do
    target=$(readlink "$path") || return 1
    case "$target" in /*) path=$target ;; *) path="$(dirname "$path")/$target" ;; esac
    i=$((i+1))
  done
  [ "$i" -lt 40 ] && [ -e "$path" ] || return 1
  parent=$(cd "$(dirname "$path")" 2>/dev/null && pwd -P) || return 1
  printf '%s/%s\n' "$parent" "$(basename "$path")"
}

process_cwd() {
  pid=$1
  if [ -L "/proc/$pid/cwd" ]; then readlink "/proc/$pid/cwd" 2>/dev/null; return; fi
  command -v lsof >/dev/null 2>&1 || return 1
  lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1
}

process_argv_exact() {
  pid=$1
  case "$(uname -s)" in
    Linux) [ -r "/proc/$pid/cmdline" ] || return 2; cat "/proc/$pid/cmdline" ;;
    Darwin)
      helper=${POLYLANE_PROCARGS_HELPER:-$SCRIPT_DIR/polylane-procargs-macos}
      [ -x "$helper" ] && [ ! -L "$helper" ] || return 2
      "$helper" "$pid" || return 2 ;;
    *) return 2 ;;
  esac
}

process_uses_destination() {
  pid=$1; dest=$2; identity=$3; found=1
  argv_file=$(mktemp "${TMPDIR:-/tmp}/polylane-procargs.XXXXXX") || return 2
  chmod 0600 "$argv_file"
  process_argv_exact "$pid" > "$argv_file" || { rm "$argv_file"; return 2; }
  cwd=$(process_cwd "$pid" || true)
  if [ -n "$cwd" ]; then
    cwd=$(resolve_existing_path "$cwd" 2>/dev/null || printf '%s' "$cwd")
    case "$cwd/" in "$identity/"|"$identity/"*) found=0 ;; esac
  fi
  while [ "$found" != 0 ] && IFS= read -r -d '' token; do
    case "$token" in /*) candidate=$token ;; ./*|../*) [ -n "$cwd" ] || continue; candidate="$cwd/$token" ;; *) continue ;; esac
    resolved=$(resolve_existing_path "$candidate" 2>/dev/null || true)
    case "$resolved" in "$identity"|"$identity/"*) found=0; break ;; esac
  done < "$argv_file"
  rm "$argv_file"
  return "$found"
}

migration_preflight() {
  dest=$(canonical_dest "$1") || return 2
  [ -d "$dest" ] && [ ! -L "$dest" ] || return 0
  identity=$(cd "$dest" && pwd -P) || return 2
  if command -v tmux >/dev/null 2>&1; then
    while IFS='|' read -r session root; do
      [ "$root" != "$dest" ] || { echo "migration-preflight: owned tmux session $session" >&2; return 8; }
    done <<EOF
$(tmux list-sessions -F '#{session_name}|#{@polylane_skill_root}' 2>/dev/null || true)
EOF
  fi
  if [ -d "$dest/.polylane/runtime" ]; then
    for record in "$dest"/.polylane/runtime/*.json; do
      [ -f "$record" ] || continue
      pid=$(jq -r '.pid // 0' "$record" 2>/dev/null || echo 0)
      token=$(jq -r '.start_token // ""' "$record" 2>/dev/null || true)
      if process_matches "$pid" "$token"; then
        executable=$(jq -r '.executable // ""' "$record" 2>/dev/null || true)
        actor_cwd=$(jq -r '.cwd // ""' "$record" 2>/dev/null || true)
        resolved=""
        case "$executable" in
          /*) resolved=$(resolve_existing_path "$executable" 2>/dev/null || true) ;;
          *) [ -z "$actor_cwd" ] || resolved=$(resolve_existing_path "$actor_cwd/$executable" 2>/dev/null || true) ;;
        esac
        case "$resolved" in "$identity"|"$identity/"*) uses=1 ;; *) uses=0 ;; esac
        if [ "$uses" = 1 ]; then
          echo "migration-preflight: live runtime actor $pid" >&2; return 8
        fi
        process_uses_destination "$pid" "$dest" "$identity"; argv_rc=$?
        [ "$argv_rc" != 0 ] || { echo "migration-preflight: live runtime actor $pid" >&2; return 8; }
        [ "$argv_rc" != 2 ] || { echo "migration-preflight: cannot inspect actor argv $pid" >&2; return 8; }
      fi
    done
  fi
  check_file="$dest.polylane-ps-check.$$"
  ( ps -axo pid= 2>/dev/null | while IFS= read -r row; do
    row=${row#"${row%%[![:space:]]*}"}; pid=${row%%[[:space:]]*}
    [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ] || continue
    process_uses_destination "$pid" "$dest" "$identity"; argv_rc=$?
    if [ "$argv_rc" = 0 ]; then echo "$pid"; break; fi
    if [ "$argv_rc" = 2 ]; then echo "ERROR:$pid"; break; fi
  done ) | private_from_stdin "$check_file" 0600 || return 7
  blocked=$(cat "$check_file" 2>/dev/null || true); fs unlink-private "$check_file"
  [ -z "$blocked" ] || { echo "migration-preflight: live process inspection blocked: $blocked" >&2; return 8; }
}

write_maintenance() {
  dest=$1; nonce=$2; deadline=$(( $(date +%s) + 5 )); file="$dest.polylane-maintenance.json"
  tmp="$file.tmp.$$"; [ ! -e "$tmp" ] && [ ! -L "$tmp" ] || return 7
  capture_private "$tmp" 0400 jq -nS --arg dest "$dest" --arg nonce "$nonce" --argjson deadline "$deadline" \
    '{destination:$dest,kind:"rollback-safe maintenance",nonce:$nonce,
      retry_deadline:$deadline}' || return 7
  publish_public_immutable "$tmp" "$file" 0400 || return 7
  MAINTENANCE_HASH=$(hash_file "$file")
}
pointer_swap() {
  dest=$1; release=$2; tmp="$dest.polylane-pointer.$$"
  [ ! -e "$tmp" ] && [ ! -L "$tmp" ] || return 7
  fs symlink-exclusive "$tmp" "$release" || return 7
  fs replace-symlink "$tmp" "$dest"
}

legacy_publish() {
  dest=$1; release=$2; releases="$dest.polylane-releases"
  migration_preflight "$dest" || return $?
  legacy_nonce="$(date +%s)-$$-${RANDOM:-0}"
  write_maintenance "$dest" "$legacy_nonce"
  migration_preflight "$dest" || {
    remove_public_if_owned "$dest.polylane-maintenance.json" "$MAINTENANCE_HASH" || true; return 8;
  }
  LEGACY_DEST=$dest; LEGACY_BACKUP="$releases/legacy-$legacy_nonce"
  LEGACY_COMMIT="$releases/.legacy-$legacy_nonce.committed"; LEGACY_EXPECTED=$release
  record="$releases/.legacy-$legacy_nonce.json"; record_tmp="$record.tmp.$$"
  token=$(process_start_token $$)
  capture_private "$record_tmp" 0400 jq -nS --arg dest "$dest" --arg backup "$LEGACY_BACKUP" --arg candidate "$release" \
    --arg nonce "$legacy_nonce" --argjson publisher "$$" --arg token "$token" \
    --arg marker "$LEGACY_COMMIT" \
    '{schema_version:1,destination:$dest,backup:$backup,candidate:$candidate,nonce:$nonce,
      publisher_pid:$publisher,publisher_start_token:$token,commit_marker:$marker}' || return 7
  publish_public_immutable "$record_tmp" "$record" 0400 || return 7
  seal_tmp="$record.seal.tmp.$$"
  hash_file "$record" | private_from_stdin "$seal_tmp" 0400 || return 7
  publish_public_immutable "$seal_tmp" "$record.seal" 0400 || return 7
  "$GUARD" legacy "$record" >/dev/null 2>&1 & guard=$!
  guard_token=""; i=0
  while [ -z "$guard_token" ] && [ "$i" -lt 50 ]; do
    guard_token=$(process_start_token "$guard" || true); sleep 0.02; i=$((i+1))
  done
  [ -n "$guard_token" ] || {
    kill "$guard" 2>/dev/null || true
    remove_public_if_owned "$dest.polylane-maintenance.json" "$MAINTENANCE_HASH" || true
    return 7
  }
  i=0
  while ! legacy_guard_live_validate "$record" "$guard" "$guard_token" && [ "$i" -lt 100 ]; do
    process_matches "$guard" "$guard_token" || {
      remove_public_if_owned "$dest.polylane-maintenance.json" "$MAINTENANCE_HASH" || true
      return 7
    }
    sleep 0.05; i=$((i+1))
  done
  legacy_guard_live_validate "$record" "$guard" "$guard_token" || {
    kill "$guard" 2>/dev/null || true; wait "$guard" 2>/dev/null || true
    remove_public_if_owned "$dest.polylane-maintenance.json" "$MAINTENANCE_HASH" || true
    return 7
  }
  tmp="$dest.polylane-pointer.$$"
  [ ! -e "$tmp" ] && [ ! -L "$tmp" ] && fs symlink-exclusive "$tmp" "$release" || return 7
  # The first destructive legacy rename is forbidden until the sealed guard-live
  # handshake above authenticates this exact guard PID/start-token and record hash.
  mv "$dest" "$LEGACY_BACKUP"
  case "${POLYLANE_PACKAGE_FAULT:-}" in
    after-legacy-rename) return 10 ;;
    sigkill-after-legacy-rename) kill -9 $$ ;;
    sigkill-after-empty-legacy-marker)
      bad="$LEGACY_COMMIT.tmp.$$"; private_from_stdin "$bad" 0400 </dev/null && \
        publish_public_immutable "$bad" "$LEGACY_COMMIT" 0400; kill -9 $$ ;;
    sigkill-after-wrong-legacy-marker)
      bad="$LEGACY_COMMIT.tmp.$$"; capture_private "$bad" 0400 jq -n \
        '{nonce:"forged",candidate:"/forged"}' && \
        publish_public_immutable "$bad" "$LEGACY_COMMIT" 0400; kill -9 $$ ;;
  esac
  fs replace-symlink "$tmp" "$dest" || return 7
  marker_tmp="$LEGACY_COMMIT.tmp.$$"
  capture_private "$marker_tmp" 0400 jq -nS --arg nonce "$legacy_nonce" --arg candidate "$release" \
    '{nonce:$nonce,candidate:$candidate}' || return 7
  publish_public_immutable "$marker_tmp" "$LEGACY_COMMIT" 0400 || return 7
  remove_public_if_owned "$dest.polylane-maintenance.json" "$MAINTENANCE_HASH" || return 7
  LEGACY_DEST=""; LEGACY_BACKUP=""; LEGACY_COMMIT=""; LEGACY_EXPECTED=""
  echo "polylane-package: rollback-safe maintenance conversion complete" >&2
}

legacy_record_validate() {
  record=$1; [ -s "$record" ] && [ -s "$record.seal" ] || return 7
  activation_file_valid "$record" 0400 && activation_file_valid "$record.seal" 0400 || return 7
  [ "$(hash_file "$record")" = "$(cat "$record.seal")" ] || return 7
  jq -e '.schema_version==1 and (.destination|type=="string") and
    (.backup|type=="string") and (.candidate|type=="string") and
    (.nonce|type=="string") and (.publisher_pid|type=="number") and
    (.publisher_start_token|type=="string") and (.commit_marker|type=="string")' \
    "$record" >/dev/null || return 7
  dest=$(jq -r .destination "$record"); backup=$(jq -r .backup "$record")
  candidate=$(jq -r .candidate "$record"); nonce=$(jq -r .nonce "$record")
  marker=$(jq -r .commit_marker "$record"); releases="$dest.polylane-releases"
  [ "$(canonical_dest "$dest")" = "$dest" ] || return 7
  case "$backup" in "$releases/legacy-$nonce") : ;; *) return 7 ;; esac
  case "$candidate" in "$releases/"*) : ;; *) return 7 ;; esac
  [ "$marker" = "$releases/.legacy-$nonce.committed" ] || return 7
  verify_release "$candidate" || return 7
}

legacy_guard_live_validate() {
  record=$1; expected_pid=${2:-}; expected_token=${3:-}; live="$record.guard-live"
  legacy_record_validate "$record" || return 7
  activation_file_valid "$live" 0400 || return 7
  jq -e --argjson pid "$expected_pid" --arg token "$expected_token" \
    --arg hash "$(hash_file "$record")" '
      keys==["pid","record_hash","start_token"] and .pid==$pid and
      .start_token==$token and .record_hash==$hash' "$live" >/dev/null || return 7
  process_matches "$expected_pid" "$expected_token"
}

legacy_publish_guard_live() {
  record=$1; pid=$2; token=$3; live="$record.guard-live"; tmp="$live.tmp.$$"
  legacy_record_validate "$record" || return 7
  process_matches "$pid" "$token" || return 7
  capture_private "$tmp" 0400 jq -nS --argjson pid "$pid" --arg token "$token" \
    --arg hash "$(hash_file "$record")" \
    '{pid:$pid,record_hash:$hash,start_token:$token}' || return 7
  publish_public_immutable "$tmp" "$live" 0400 || return 7
  legacy_guard_live_validate "$record" "$pid" "$token"
}

legacy_recover() {
  record=$1; legacy_record_validate "$record" || return 7
  dest=$(jq -r .destination "$record"); backup=$(jq -r .backup "$record")
  candidate=$(jq -r .candidate "$record"); nonce=$(jq -r .nonce "$record")
  marker=$(jq -r .commit_marker "$record")
  acquire_lock "$dest"
  if activation_file_valid "$marker" 0400 && \
     [ "$(jq -r '.nonce // ""' "$marker" 2>/dev/null)" = "$nonce" ] && \
     [ "$(jq -r '.candidate // ""' "$marker" 2>/dev/null)" = "$candidate" ] && \
     [ "$(readlink "$dest" 2>/dev/null || true)" = "$candidate" ] && verify_release "$candidate"; then
    return 0
  fi
  [ "${POLYLANE_PACKAGE_HOLD_LEGACY_RECOVERY:-0}" != 1 ] || sleep 1
  current=$(readlink "$dest" 2>/dev/null || printf null)
  if [ "$current" = "$candidate" ]; then
    quarantine="$dest.polylane-legacy-pointer.$nonce"
    mv "$dest" "$quarantine" || return 9
    [ "$(readlink "$quarantine" 2>/dev/null || true)" = "$candidate" ] || return 9
    [ -d "$backup" ] || return 9
    mv "$backup" "$dest" || return 9; rm -f "$quarantine"
  elif [ "$current" = null ] && [ ! -e "$dest" ]; then
    [ -d "$backup" ] || return 9; mv "$backup" "$dest" || return 9
  elif [ -d "$dest" ] && [ ! -L "$dest" ] && [ ! -e "$backup" ]; then :
  else
    return 9
  fi
  rolled="$record.rolled-back.tmp.$$"
  capture_private "$rolled" 0400 jq -nS --arg nonce "$nonce" \
    '{nonce:$nonce,state:"ROLLED_BACK"}' || return 7
  publish_public_immutable "$rolled" "$record.rolled-back" 0400 || return 7
  maintenance="$dest.polylane-maintenance.json"
  [ ! -e "$maintenance" ] || {
    activation_file_valid "$maintenance" 0400 && \
      [ "$(jq -r '.nonce // ""' "$maintenance")" = "$nonce" ] || return 7
    fs unlink-private "$maintenance"
  }
}

journal_invariants() {
  jq -S '{schema_version,destination,prior_release,candidate_release,activation_nonce,certification_owner_pid,certification_owner_start_token,certification_deadline,preparation_deadline,publisher_pid,publisher_start_token,guard_pid,guard_start_token,prior_manifest_hash,candidate_manifest_hash}' "$1"
}
prepare_invariants() {
  jq -S '{schema_version,destination,prior_release,candidate_release,activation_nonce,certification_owner_pid,certification_owner_start_token,certification_deadline,preparation_deadline,publisher_pid,publisher_start_token,prior_manifest_hash,candidate_manifest_hash}' "$1"
}
prepare_validate() {
  journal=$(activation_record_path "$1") || return 7
  copy="$journal.prepare-copy"; seal="$journal.prepare-seal"
  activation_file_valid "$journal" 0600 && activation_file_valid "$copy" 0400 && \
    activation_file_valid "$seal" 0400 || return 7
  [ "$(hash_file "$copy")" = "$(cat "$seal")" ] || return 7
  [ "$(prepare_invariants "$journal")" = "$(prepare_invariants "$copy")" ] || return 7
  dest=$(jq -r .destination "$copy"); candidate=$(jq -r .candidate_release "$copy")
  prior=$(jq -r '.prior_release // "null"' "$copy")
  case "$candidate" in "$dest.polylane-releases"/*) : ;; *) return 7 ;; esac
  [ "$prior" = null ] || case "$prior" in "$dest.polylane-releases"/*) : ;; *) return 7 ;; esac
  verify_release "$candidate" || return 7
  [ "$(release_manifest_hash "$candidate")" = "$(jq -r .candidate_manifest_hash "$copy")" ] || return 7
  [ "$prior" = null ] || { verify_release "$prior" && [ "$(release_manifest_hash "$prior")" = "$(jq -r .prior_manifest_hash "$copy")" ]; } || return 7
}
journal_validate() {
  journal=$(activation_record_path "$1") || return 7
  copy="$journal.guard-copy"; seal="$journal.guard-seal"
  activation_file_valid "$journal" 0600 && activation_file_valid "$copy" 0400 && \
    activation_file_valid "$seal" 0400 && activation_file_valid "$journal.guard-ready" 0400 || return 7
  if [ -e "$journal.guard-live" ] || [ -L "$journal.guard-live" ]; then
    activation_file_valid "$journal.guard-live" 0400 || return 7
  fi
  if [ -e "$journal.recovered" ] || [ -L "$journal.recovered" ]; then
    activation_file_valid "$journal.recovered" 0400 || return 7
  fi
  [ "$(hash_file "$copy")" = "$(cat "$seal")" ] || return 7
  [ "$(journal_invariants "$journal")" = "$(journal_invariants "$copy")" ] || return 7
  dest=$(jq -r .destination "$copy"); candidate=$(jq -r .candidate_release "$copy")
  prior=$(jq -r '.prior_release // "null"' "$copy")
  case "$candidate" in "$dest.polylane-releases"/*) : ;; *) return 7 ;; esac
  [ "$prior" = null ] || case "$prior" in "$dest.polylane-releases"/*) : ;; *) return 7 ;; esac
  [ -s "$candidate/.polylane-package-manifest" ] || return 7
  [ "$(release_manifest_hash "$candidate")" = "$(jq -r .candidate_manifest_hash "$copy")" ] || return 7
  [ "$prior" = null ] || { [ -s "$prior/.polylane-package-manifest" ] && \
    [ "$(release_manifest_hash "$prior")" = "$(jq -r .prior_manifest_hash "$copy")" ]; } || return 7
  state=$(jq -r '.state // ""' "$journal" 2>/dev/null || true)
  case "$state" in PREPARED|PUBLISHED|COMMITTED|ROLLED_BACK|STALE) : ;; *) return 7 ;; esac
}

state_cas() {
  journal=$1; from=$2; to=$3
  # jq variables are supplied with --arg.
  # shellcheck disable=SC2016
  atomic_filter "$journal" \
    'if .state==$from then .state=$to else error("activation state CAS failed") end' \
    --arg from "$from" --arg to "$to"
}

commit_evidence_valid() {
  journal=$1; copy="$journal.guard-copy"
  activation_file_valid "$journal" 0600 && activation_file_valid "$copy" 0400 || return 1
  jq -e --arg nonce "$(jq -r .activation_nonce "$copy")" \
    --arg candidate "$(jq -r .candidate_release "$copy")" \
    --arg hash "$(jq -r .candidate_manifest_hash "$copy")" '
      .state=="COMMITTED" and
      .commit_evidence=={nonce:$nonce,candidate:$candidate,manifest_hash:$hash}' \
    "$journal" >/dev/null 2>&1
}

guard_live() {
  journal=$1; copy="$journal.guard-copy"; live="$journal.guard-live"
  activation_file_valid "$copy" 0400 && activation_file_valid "$live" 0400 || return 1
  pid=$(jq -r .pid "$live" 2>/dev/null); token=$(jq -r .start_token "$live" 2>/dev/null)
  [ "$pid" = "$(jq -r .guard_pid "$copy")" ] && \
    [ "$token" = "$(jq -r .guard_start_token "$copy")" ] && process_matches "$pid" "$token"
}

activation_files_validate() {
  journal=$(activation_record_path "$1") || return 7
  activation_file_valid "$journal" 0600 || return 7
  for suffix in .prepare-copy .prepare-seal .guard-copy .guard-seal .guard-ready .guard-live; do
    activation_file_valid "$journal$suffix" 0400 || return 7
  done
  if [ -e "$journal.recovered" ] || [ -L "$journal.recovered" ]; then
    activation_file_valid "$journal.recovered" 0400 || return 7
  fi
  if [ -e "$journal.prepare-expired" ] || [ -L "$journal.prepare-expired" ]; then
    activation_file_valid "$journal.prepare-expired" 0400 || return 7
  fi
}

publish_preparation_expired_locked() {
  journal=$1
  journal_validate "$journal" || return 7
  copy="$journal.prepare-copy"; marker="$journal.prepare-expired"; tmp="$marker.tmp.$$"
  guard_pid=$2; guard_token=$3; deadline=$(jq -r .preparation_deadline "$copy")
  [ "$(jq -r '.state // ""' "$journal")" = PREPARED ] || return 9
  [ "$guard_pid" = "$(jq -r .guard_pid "$journal.guard-copy")" ] && \
    [ "$guard_token" = "$(jq -r .guard_start_token "$journal.guard-copy")" ] && \
    [ "$(date +%s)" -ge "$deadline" ] && process_matches "$guard_pid" "$guard_token" || return 7
  capture_private "$tmp" 0400 jq -nS --argjson pid "$guard_pid" --arg token "$guard_token" \
    --argjson deadline "$deadline" --arg hash "$(hash_file "$copy")" \
    '{guard_pid:$pid,guard_start_token:$token,preparation_deadline:$deadline,
      prepare_hash:$hash}' || return 7
  publish_public_immutable "$tmp" "$marker" 0400
}

publish_preparation_expired() {
  journal=$(activation_record_path "$1") || return 7
  dest=$(jq -r .destination "$journal.prepare-copy") || return 7
  acquire_lock "$dest"
  publish_preparation_expired_locked "$journal" "$2" "$3"
}

publish_guard_live() {
  journal=$(activation_record_path "$1") || return 7
  pid=$2; token=$3; live="$journal.guard-live"; tmp="$live.tmp.$$"
  journal_validate "$journal" || return 7
  [ "$pid" = "$(jq -r .guard_pid "$journal.guard-copy")" ] && \
    [ "$token" = "$(jq -r .guard_start_token "$journal.guard-copy")" ] && \
    process_matches "$pid" "$token" || return 7
  [ ! -e "$live" ] && [ ! -L "$live" ] && [ ! -e "$tmp" ] && [ ! -L "$tmp" ] || return 7
  capture_private "$tmp" 0400 jq -n --argjson pid "$pid" --arg token "$token" \
    '{pid:$pid,start_token:$token,ready:true}' || return 7
  replace_file_nofollow "$tmp" "$live" 0400 absent || return 7
  guard_live "$journal"
}

recover_prepared() {
  journal=$1; prepare_validate "$journal" || return 7
  copy="$journal.prepare-copy"; publisher=$(jq -r .publisher_pid "$copy")
  publisher_token=$(jq -r .publisher_start_token "$copy")
  deadline=$(jq -r .preparation_deadline "$copy")
  if process_matches "$publisher" "$publisher_token" && [ "$(date +%s)" -lt "$deadline" ]; then
    return 8
  fi
  dest=$(jq -r .destination "$copy"); candidate=$(jq -r .candidate_release "$copy")
  prior=$(jq -r '.prior_release // "null"' "$copy"); acquire_lock "$dest"
  state=$(jq -r '.state // ""' "$journal")
  case "$state" in ROLLED_BACK) return 0 ;; PREPARED) : ;; *) return 9 ;; esac
  current=$(readlink "$dest" 2>/dev/null || printf null)
  if [ "$current" = "$candidate" ]; then
    if [ "$prior" = null ]; then [ -L "$dest" ] || return 9; fs unlink-symlink "$dest"
    else pointer_swap "$dest" "$prior"; fi
  elif [ "$current" = "$prior" ]; then :
  else state_cas "$journal" PREPARED STALE; return 9
  fi
  state_cas "$journal" PREPARED ROLLED_BACK
}

prepare_journal() {
  journal=$(activation_record_path "$1") || return 7
  for suffix in '' .prepare-copy .prepare-seal .guard-copy .guard-seal .guard-ready \
    .guard-live .prepare-expired .recovered; do
    [ ! -e "$journal$suffix" ] && [ ! -L "$journal$suffix" ] || return 7
  done
  dest=$2; prior=$3; candidate=$4; owner=$5
  owner_token=$(process_start_token "$owner"); [ -n "$owner_token" ] || return 7
  timeout=${POLYLANE_CERTIFICATION_TIMEOUT:-300}
  case "$timeout" in ''|*[!0-9]*) return 7 ;; esac
  deadline=$(( $(date +%s) + timeout ))
  prep_timeout=${POLYLANE_PREPARATION_TIMEOUT:-15}
  case "$prep_timeout" in ''|*[!0-9]*) return 7 ;; esac
  [ "$prep_timeout" -ge 10 ] || return 7
  prep_deadline=$(( $(date +%s) + prep_timeout ))
  nonce="$(date +%s)-$$-${RANDOM:-0}"; tmp="$journal.tmp.$$"
  prep_tmp="$journal.prepare-copy.tmp.$$"; prep_seal_tmp="$journal.prepare-seal.tmp.$$"
  guard_tmp="$journal.guard-copy.tmp.$$"; guard_seal_tmp="$journal.guard-seal.tmp.$$"
  ready_tmp="$journal.guard-ready.tmp.$$"
  for private in "$tmp" "$prep_tmp" "$prep_seal_tmp" "$guard_tmp" \
    "$guard_seal_tmp" "$ready_tmp"; do
    [ ! -e "$private" ] && [ ! -L "$private" ] || return 7
  done
  if [ "$prior" = null ]; then prior_json=null
  else prior_json=$(jq -n --arg path "$prior" '$path'); fi
  capture_private "$prep_tmp" 0400 jq -n --arg dest "$dest" --argjson prior "$prior_json" --arg candidate "$candidate" \
    --arg nonce "$nonce" --argjson owner "$owner" --arg owner_token "$owner_token" \
    --argjson deadline "$deadline" --argjson prep_deadline "$prep_deadline" \
    --argjson publisher "$$" --arg publisher_token "$(process_start_token $$)" \
    --arg prior_hash "$( [ "$prior" = null ] && printf null || release_manifest_hash "$prior" )" \
    --arg candidate_hash "$(release_manifest_hash "$candidate")" \
    '{schema_version:1,destination:$dest,prior_release:$prior,candidate_release:$candidate,
      activation_nonce:$nonce,certification_owner_pid:$owner,
      certification_owner_start_token:$owner_token,certification_deadline:$deadline,
      preparation_deadline:$prep_deadline,
      publisher_pid:$publisher,
      publisher_start_token:$publisher_token,guard_pid:null,guard_start_token:null,
      state:"PREPARED",prior_manifest_hash:$prior_hash,candidate_manifest_hash:$candidate_hash}' || return 7
  replace_file_nofollow "$prep_tmp" "$journal.prepare-copy" 0400 absent || return 7
  hash_file "$journal.prepare-copy" | private_from_stdin "$prep_seal_tmp" 0400 || return 7
  replace_file_nofollow "$prep_seal_tmp" "$journal.prepare-seal" 0400 absent || return 7
  capture_private "$tmp" 0600 jq -c . "$journal.prepare-copy" || return 7
  replace_file_nofollow "$tmp" "$journal" 0600 absent || return 7
  case "${POLYLANE_PACKAGE_FAULT:-}" in sigkill-during-guard-bootstrap) kill -9 $$ ;; esac
  "$GUARD" activation "$journal" >/dev/null 2>&1 & guard=$!
  guard_token=""; i=0
  while [ -z "$guard_token" ] && [ "$i" -lt 50 ]; do guard_token=$(process_start_token "$guard" || true); sleep 0.02; i=$((i+1)); done
  [ -n "$guard_token" ] || { kill "$guard" 2>/dev/null || true; return 7; }
  # jq variables are supplied with --arg/--argjson.
  # shellcheck disable=SC2016
  atomic_filter "$journal" '.guard_pid=$pid | .guard_start_token=$token' \
    --argjson pid "$guard" --arg token "$guard_token"
  capture_private "$guard_tmp" 0400 jq -c . "$journal" || return 7
  replace_file_nofollow "$guard_tmp" "$journal.guard-copy" 0400 absent || return 7
  hash_file "$journal.guard-copy" | private_from_stdin "$guard_seal_tmp" 0400 || return 7
  replace_file_nofollow "$guard_seal_tmp" "$journal.guard-seal" 0400 absent || return 7
  private_from_stdin "$ready_tmp" 0400 </dev/null || return 7
  replace_file_nofollow "$ready_tmp" "$journal.guard-ready" 0400 absent || return 7
  i=0
  while ! guard_live "$journal" && [ "$i" -lt 100 ]; do
    process_matches "$guard" "$guard_token" || return 7
    sleep 0.05; i=$((i+1))
  done
  guard_live "$journal" || return 7
  case "${POLYLANE_PACKAGE_FAULT:-}" in
    delay-live-prepared-publisher) sleep $((prep_timeout + 1)) ;;
  esac
}

rollback_locked() {
  journal=$1; copy="$journal.guard-copy"; dest=$(jq -r .destination "$copy")
  candidate=$(jq -r .candidate_release "$copy"); prior=$(jq -r '.prior_release // "null"' "$copy")
  state=$(jq -r '.state // ""' "$journal")
  case "$state" in PREPARED|PUBLISHED) : ;; COMMITTED|ROLLED_BACK|STALE|*) return 9 ;; esac
  current=$(readlink "$dest" 2>/dev/null || printf null)
  if [ "$current" = "$candidate" ]; then
    if [ "$prior" = null ]; then
      [ -L "$dest" ] || return 9
      fs unlink-symlink "$dest"
    else verify_release "$prior" || { state_cas "$journal" "$state" STALE; return 7; }
      pointer_swap "$dest" "$prior"; fi
  elif [ "$current" = "$prior" ]; then :
  else return 9
  fi
  state_cas "$journal" "$state" ROLLED_BACK
}

rollback() {
  journal=$1; journal_validate "$journal" || return 7
  dest=$(jq -r .destination "$journal.guard-copy")
  acquire_lock "$dest"
  journal_validate "$journal" || return 7
  rollback_locked "$journal"
}

certify_activation() {
  journal=$1; journal_validate "$journal" || return 7
  copy="$journal.guard-copy"; dest=$(jq -r .destination "$copy"); candidate=$(jq -r .candidate_release "$copy")
  owner=$(jq -r .certification_owner_pid "$copy")
  owner_token=$(jq -r .certification_owner_start_token "$copy")
  deadline=$(jq -r .certification_deadline "$copy")
  acquire_lock "$dest"; state=$(jq -r '.state // ""' "$journal")
  case "$state" in PUBLISHED) : ;; COMMITTED) commit_evidence_valid "$journal"; return ;; *) return 9 ;; esac
  [ "$(readlink "$dest" 2>/dev/null || true)" = "$candidate" ] || return 9
  verify_release "$candidate" || return 7
  case "${POLYLANE_PACKAGE_FAULT:-}" in sigkill-before-commit-publication) kill -9 $$ ;; esac
  case "${POLYLANE_PACKAGE_FAULT:-}" in delay-before-certify-cas) sleep 1 ;; esac
  # This is the commit linearization check. It occurs under the destination lock and
  # immediately before the PUBLISHED -> COMMITTED CAS; a stale certifier rolls back
  # through the already-held-lock helper and can never retain its candidate.
  if [ "$(date +%s)" -ge "$deadline" ] || ! process_matches "$owner" "$owner_token"; then
    rollback_locked "$journal" || return 9
    return 9
  fi
  case "${POLYLANE_PACKAGE_FAULT:-}" in
    delay-after-published-check-before-cas) sleep 2 ;;
  esac
  # The fault boundary above is inside the same held destination lock. Revalidate
  # owner/deadline again after it and immediately before the single journal rename.
  if [ "$(date +%s)" -ge "$deadline" ] || ! process_matches "$owner" "$owner_token"; then
    rollback_locked "$journal" || return 9
    return 9
  fi
  # jq variables are supplied with --arg.
  # shellcheck disable=SC2016
  atomic_filter "$journal" '
    if .state=="PUBLISHED" then
      .state="COMMITTED" |
      .commit_evidence={nonce:$nonce,candidate:$candidate,manifest_hash:$hash}
    else error("activation commit CAS failed") end' \
    --arg nonce "$(jq -r .activation_nonce "$copy")" --arg candidate "$candidate" \
    --arg hash "$(release_manifest_hash "$candidate")"
  case "${POLYLANE_PACKAGE_FAULT:-}" in sigkill-after-commit-publication) kill -9 $$ ;; esac
}

repair_activation() {
  journal=$1; journal_validate "$journal" || return 7
  commit_evidence_valid "$journal" || return 7
  copy="$journal.guard-copy"; dest=$(jq -r .destination "$copy"); candidate=$(jq -r .candidate_release "$copy")
  acquire_lock "$dest"; commit_evidence_valid "$journal" || return 7
  [ "$(readlink "$dest" 2>/dev/null || true)" = "$candidate" ] || return 9
  verify_release "$candidate" || return 7
}

mark_stale() {
  journal=$1; journal_validate "$journal" || return 7
  dest=$(jq -r .destination "$journal.guard-copy"); acquire_lock "$dest"
  state=$(jq -r '.state // ""' "$journal")
  case "$state" in PREPARED|PUBLISHED) state_cas "$journal" "$state" STALE ;; *) return 9 ;; esac
}

sealed_record_validate() {
  copy=$1; seal=$2
  activation_file_valid "$copy" 0400 && activation_file_valid "$seal" 0400 && \
    [ "$(hash_file "$copy")" = "$(cat "$seal")" ] || return 7
  jq -e '.schema_version==1 and (.destination|type=="string") and
    ((.prior_release==null) or (.prior_release|type=="string")) and
    (.candidate_release|type=="string") and (.activation_nonce|type=="string") and
    (.publisher_pid|type=="number") and (.publisher_start_token|type=="string") and
    (.candidate_manifest_hash|type=="string") and (.prior_manifest_hash|type=="string")' \
    "$copy" >/dev/null || return 7
  dest=$(jq -r .destination "$copy"); candidate=$(jq -r .candidate_release "$copy")
  prior=$(jq -r '.prior_release // "null"' "$copy")
  case "$candidate" in "$dest.polylane-releases"/*) : ;; *) return 7 ;; esac
  [ "$prior" = null ] || case "$prior" in "$dest.polylane-releases"/*) : ;; *) return 7 ;; esac
  [ -s "$candidate/.polylane-package-manifest" ] && \
    [ "$(release_manifest_hash "$candidate")" = "$(jq -r .candidate_manifest_hash "$copy")" ] || return 7
  [ "$prior" = null ] || { [ -s "$prior/.polylane-package-manifest" ] && \
    [ "$(release_manifest_hash "$prior")" = "$(jq -r .prior_manifest_hash "$copy")" ]; } || return 7
}

recover_corrupt_journal() {
  journal=$(activation_record_path "$1") || return 7
  source=""; kind=""; committed_evidence=null
  if sealed_record_validate "$journal.guard-copy" "$journal.guard-seal"; then
    source="$journal.guard-copy"; kind=guard
  elif sealed_record_validate "$journal.prepare-copy" "$journal.prepare-seal"; then
    source="$journal.prepare-copy"; kind=prepare
  else
    return 7
  fi
  if [ "$kind" = guard ] && commit_evidence_valid "$journal"; then
    committed_evidence=$(jq -c .commit_evidence "$journal")
  fi
  dest=$(jq -r .destination "$source"); candidate=$(jq -r .candidate_release "$source")
  prior=$(jq -r '.prior_release // "null"' "$source"); acquire_lock "$dest"
  sealed_record_validate "$source" "$( [ "$kind" = guard ] && printf '%s' "$journal.guard-seal" || printf '%s' "$journal.prepare-seal" )" || return 7
  if [ "$committed_evidence" != null ]; then
    commit_evidence_valid "$journal" || return 7
    [ "$(jq -c .commit_evidence "$journal")" = "$committed_evidence" ] || return 7
  fi
  current=$(readlink "$dest" 2>/dev/null || printf null); terminal=STALE
  if [ "$committed_evidence" != null ] && [ "$current" = "$candidate" ] && \
     verify_release "$candidate"; then
    terminal=COMMITTED
  elif [ "$current" = "$candidate" ]; then
    if [ "$prior" = null ]; then
      [ -L "$dest" ] || return 9; fs unlink-symlink "$dest"; terminal=ROLLED_BACK
    elif verify_release "$prior"; then
      pointer_swap "$dest" "$prior"; terminal=ROLLED_BACK
    fi
  elif [ "$current" = "$prior" ]; then
    terminal=ROLLED_BACK
  elif [ "$prior" = null ] && [ "$current" = null ] && [ ! -e "$dest" ]; then
    terminal=ROLLED_BACK
  fi
  tmp="$journal.recover.tmp.$$"
  [ ! -e "$tmp" ] && [ ! -L "$tmp" ] || return 7
  # jq variables are supplied with --arg/--argjson.
  # shellcheck disable=SC2016
  capture_private "$tmp" 0600 jq --arg state "$terminal" --argjson evidence "$committed_evidence" '
    .state=$state |
    if $state=="COMMITTED" then .commit_evidence=$evidence else del(.commit_evidence) end' \
    "$source" || return 7
  replace_file_nofollow "$tmp" "$journal" 0600 existing || return 7
  recovered="$journal.recovered.tmp.$$"
  [ ! -e "$recovered" ] && [ ! -L "$recovered" ] || return 7
  capture_private "$recovered" 0400 jq -n --arg state "$terminal" --arg source "$kind" \
    '{state:$state,sealed_source:$source}' || return 7
  if [ -e "$journal.recovered" ] || [ -L "$journal.recovered" ]; then
    activation_file_valid "$journal.recovered" 0400 && \
      [ "$(hash_file "$journal.recovered")" = "$(hash_file "$recovered")" ] || return 7
    fs unlink-private "$recovered"
  else
    replace_file_nofollow "$recovered" "$journal.recovered" 0400 absent || return 7
  fi
  [ "$terminal" != STALE ] || return 9
}

wait_activation() {
  journal=$(activation_record_path "$1") || return 7
  i=0
  while [ ! -e "$journal" ] && [ ! -L "$journal" ] && [ "$i" -lt 100 ]; do
    sleep 0.05; i=$((i+1))
  done
  activation_file_valid "$journal" 0600 || return 7
  while :; do
    state=$(jq -r '.state // ""' "$journal" 2>/dev/null || true)
    case "$state" in
      COMMITTED) journal_validate "$journal" || { recover_corrupt_journal "$journal" || return $?; continue; }
        repair_activation "$journal"; return ;;
      ROLLED_BACK) journal_validate "$journal" || prepare_validate "$journal" || return 7; return 0 ;;
      STALE) journal_validate "$journal" || prepare_validate "$journal" || return 7; return 9 ;;
      PREPARED)
        prepare_validate "$journal" || { recover_corrupt_journal "$journal" || return $?; continue; }
        publisher=$(jq -r .publisher_pid "$journal.prepare-copy")
        publisher_token=$(jq -r .publisher_start_token "$journal.prepare-copy")
        deadline=$(jq -r .preparation_deadline "$journal.prepare-copy")
        if ! process_matches "$publisher" "$publisher_token" || \
           [ "$(date +%s)" -ge "$deadline" ]; then
          recover_prepared "$journal" || return $?
        fi
        ;;
      PUBLISHED)
        journal_validate "$journal" || { recover_corrupt_journal "$journal" || return $?; continue; }
        owner=$(jq -r .certification_owner_pid "$journal.guard-copy")
        owner_token=$(jq -r .certification_owner_start_token "$journal.guard-copy")
        deadline=$(jq -r .certification_deadline "$journal.guard-copy")
        if ! process_matches "$owner" "$owner_token" || [ "$(date +%s)" -ge "$deadline" ]; then
          rollback "$journal" || mark_stale "$journal" || return $?
        elif ! guard_live "$journal"; then
          # The waiter becomes the bounded monitor until certification or owner/deadline termination.
          :
        fi
        ;;
      *) recover_corrupt_journal "$journal" || return $?; continue ;;
    esac
    sleep 0.1
  done
}

preparation_live_locked() {
  journal=$1
  journal_validate "$journal" && [ "$(jq -r '.state // ""' "$journal")" = PREPARED ] || return 1
  prep_deadline=$(jq -r .preparation_deadline "$journal.guard-copy")
  [ "$(date +%s)" -lt "$prep_deadline" ] && guard_live "$journal" && \
    [ ! -e "$journal.prepare-expired" ] && [ ! -L "$journal.prepare-expired" ]
}

publish() {
  adapter=$1; dest=$(canonical_dest "$2") || die 2 "destination must be safe and absolute"
  shift 2; journal=""; owner=""
  while [ $# -gt 0 ]; do case "$1" in
    --activation-record) shift; journal=${1:-} ;;
    --certification-owner-pid) shift; owner=${1:-} ;;
    *) die 2 "unknown package option: $1" ;;
  esac; shift; done
  if { [ -z "$journal" ] && [ -n "$owner" ]; } || { [ -n "$journal" ] && [ -z "$owner" ]; }; then
    die 2 "guarded activation flags are required together"
  fi
  if [ -n "$journal" ]; then
    journal=$(activation_record_path "$journal") || die 2 "activation record path is unsafe"
    for suffix in '' .prepare-copy .prepare-seal .guard-copy .guard-seal .guard-ready \
      .guard-live .prepare-expired .recovered; do
      [ ! -e "$journal$suffix" ] && [ ! -L "$journal$suffix" ] || \
        die 7 "activation record already exists"
    done
  fi
  acquire_lock "$dest"; release=$(assemble "$adapter" "$dest")
  prior=null
  [ ! -L "$dest" ] || prior=$(readlink "$dest")
  if [ -d "$dest" ] && [ ! -L "$dest" ]; then
    [ -z "$journal" ] || die 8 "guarded activation requires legacy migration first"
    legacy_publish "$dest" "$release"; return
  fi
  if [ -n "$journal" ]; then
    prepare_journal "$journal" "$dest" "$prior" "$release" "$owner" || die 7 "cannot prepare activation journal"
    preparation_live_locked "$journal" || die 7 "activation guard/lease is not live"
  fi
  case "${POLYLANE_PACKAGE_FAULT:-}" in
    delay-after-prepared-check-before-pointer-swap) sleep $((prep_timeout + 1)) ;;
  esac
  [ -z "$journal" ] || preparation_live_locked "$journal" || \
    die 7 "preparation lease expired before pointer publication"
  case "${POLYLANE_PACKAGE_FAULT:-}" in
    before-pointer-swap) return 10 ;;
    sigkill-before-pointer-swap) kill -9 $$ ;;
  esac
  pointer_swap "$dest" "$release"
  case "${POLYLANE_PACKAGE_FAULT:-}" in sigkill-after-pointer-swap) kill -9 $$ ;; esac
  if ! verify_release "$dest"; then
    if [ "$prior" = null ]; then fs unlink-symlink "$dest"; else pointer_swap "$dest" "$prior"; fi
    return 6
  fi
  if [ -n "$journal" ]; then
    case "${POLYLANE_PACKAGE_FAULT:-}" in
      delay-after-pointer-swap-before-published-cas) sleep $((prep_timeout + 1)) ;;
    esac
    if ! preparation_live_locked "$journal"; then
      publish_preparation_expired_locked "$journal" \
        "$(jq -r .guard_pid "$journal.guard-copy")" \
        "$(jq -r .guard_start_token "$journal.guard-copy")" || return 7
      rollback_locked "$journal" || return 9
      return 9
    fi
    state_cas "$journal" PREPARED PUBLISHED
  fi
}

case "${1:-}" in
  migration-preflight) shift; migration_preflight "${1:?destination}" ;;
  mode-of) shift; mode_of "${1:?path}" ;;
  validate-relative) shift; safe_relative "${1:?relative path}" ;;
  verify-package) shift; verify_release "${1:?package}" ;;
  process-start-token) shift; process_start_token "${1:?pid}" ;;
  process-matches) shift; process_matches "${1:?pid}" "${2:?token}" ;;
  validate-legacy-record) shift; legacy_record_validate "${1:?legacy record}" ;;
  publish-legacy-guard-live) shift; legacy_publish_guard_live \
    "${1:?legacy record}" "${2:?pid}" "${3:?start-token}" ;;
  validate-legacy-guard-live) shift; legacy_guard_live_validate \
    "${1:?legacy record}" "${2:?pid}" "${3:?start-token}" ;;
  legacy-recover) shift; legacy_recover "${1:?legacy record}" ;;
  validate-journal) shift; journal_validate "${1:?journal}" ;;
  validate-activation-files) shift; activation_files_validate "${1:?journal}" ;;
  publish-guard-live) shift; publish_guard_live "${1:?journal}" "${2:?pid}" "${3:?start-token}" ;;
  publish-preparation-expired) shift; publish_preparation_expired \
    "${1:?journal}" "${2:?pid}" "${3:?start-token}" ;;
  recover-prepared) shift; recover_prepared "${1:?journal}" ;;
  recover-corrupt) shift; recover_corrupt_journal "${1:?journal}" ;;
  rollback) shift; rollback "${1:?journal}" ;;
  certify-activation) shift; certify_activation "${1:?journal}" ;;
  repair-activation) shift; repair_activation "${1:?journal}" ;;
  mark-stale) shift; mark_stale "${1:?journal}" ;;
  wait-activation) shift; wait_activation "${1:?journal}" ;;
  '') die 2 "usage: polylane-package.sh <adapter> <absolute-destination> [guard flags] | migration-preflight|verify-package|recover-prepared|recover-corrupt|certify-activation|rollback|wait-activation ..." ;;
  *) adapter=$1; shift; [ $# -ge 1 ] || die 2 "adapter destination is required"
    [ -s "$REPO/$adapter/package.json" ] || die 2 "unknown package command or adapter: $adapter"
    publish "$adapter" "$@" ;;
esac
```

Expected: `bash -n core/scripts/polylane-package.sh` exits 0.

- [ ] **Step 9: Add the complete independent install/activation guard (5 minutes)**

Create executable `core/scripts/polylane-install-guard.sh`:

```bash
#!/usr/bin/env bash
set -u
umask 077
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PACKAGE="$SCRIPT_DIR/polylane-package.sh"

rollback_or_stale() {
  journal=$1
  "$PACKAGE" rollback "$journal" >/dev/null 2>&1 || \
    "$PACKAGE" mark-stale "$journal" >/dev/null 2>&1 || \
    "$PACKAGE" recover-corrupt "$journal" >/dev/null 2>&1 || true
}

activation_guard() {
  journal=$1; i=0
  while { [ ! -f "$journal.guard-ready" ] || [ -L "$journal.guard-ready" ]; } && \
    [ "$i" -lt 100 ]; do sleep 0.05; i=$((i+1)); done
  if [ ! -f "$journal.guard-ready" ] || [ -L "$journal.guard-ready" ]; then
    "$PACKAGE" recover-prepared "$journal" >/dev/null 2>&1 || true
    return 7
  fi
  "$PACKAGE" validate-journal "$journal" || {
    "$PACKAGE" recover-corrupt "$journal" >/dev/null 2>&1 || true; return 7;
  }
  copy="$journal.guard-copy"; token=$("$PACKAGE" process-start-token $$)
  [ "$(jq -r .guard_pid "$copy")" = "$$" ] && \
    [ "$(jq -r .guard_start_token "$copy")" = "$token" ] || return 7
  "$PACKAGE" publish-guard-live "$journal" "$$" "$token" || return 7
  while :; do
    state=$(jq -r '.state // ""' "$journal" 2>/dev/null || true)
    publisher=$(jq -r .publisher_pid "$journal.guard-copy")
    publisher_token=$(jq -r .publisher_start_token "$journal.guard-copy")
    owner=$(jq -r .certification_owner_pid "$journal.guard-copy")
    owner_token=$(jq -r .certification_owner_start_token "$journal.guard-copy")
    deadline=$(jq -r .certification_deadline "$journal.guard-copy")
    case "$state" in
      PREPARED)
        preparation_deadline=$(jq -r .preparation_deadline "$journal.guard-copy")
        if [ "$(date +%s)" -ge "$preparation_deadline" ]; then
          "$PACKAGE" publish-preparation-expired "$journal" "$$" "$token" || true
          rollback_or_stale "$journal"; return 0
        elif ! "$PACKAGE" process-matches "$publisher" "$publisher_token"; then
          rollback_or_stale "$journal"; return 0
        fi
        ;;
      PUBLISHED)
        if [ "$(date +%s)" -ge "$deadline" ] || \
           ! "$PACKAGE" process-matches "$owner" "$owner_token"; then
          rollback_or_stale "$journal"; return 0
        fi
        ;;
      COMMITTED)
        "$PACKAGE" repair-activation "$journal" >/dev/null 2>&1
        return $?
        ;;
      ROLLED_BACK|STALE) return 0 ;;
      *) "$PACKAGE" recover-corrupt "$journal" >/dev/null 2>&1 || true; return 7 ;;
    esac
    sleep 0.1
  done
 }

legacy_guard() {
  record=$1
  "$PACKAGE" validate-legacy-record "$record" >/dev/null 2>&1 || return 7
  token=$("$PACKAGE" process-start-token $$) || return 7
  case "${POLYLANE_PACKAGE_FAULT:-}" in legacy-guard-never-ready) sleep 10; return 7 ;; esac
  "$PACKAGE" publish-legacy-guard-live "$record" "$$" "$token" || return 7
  publisher=$(jq -r .publisher_pid "$record")
  publisher_token=$(jq -r .publisher_start_token "$record")
  while "$PACKAGE" process-matches "$publisher" "$publisher_token"; do
    sleep 0.05
  done
  "$PACKAGE" legacy-recover "$record"
}

case "${1:-}" in
  activation) shift; activation_guard "${1:?journal}" ;;
  legacy) shift; legacy_guard "${1:?sealed legacy record}" ;;
  *) echo "usage: polylane-install-guard.sh activation <journal> | legacy <sealed-record>" >&2; exit 2 ;;
esac
```

Run: `chmod +x core/scripts/polylane-package.sh core/scripts/polylane-procargs-macos core/scripts/polylane-install-guard.sh`

Expected: both scripts pass `bash -n`. The activation branch watches publisher identity
only in `PREPARED`, certification-owner identity plus deadline in `PUBLISHED`, and a
validated atomic commit evidence before retaining `COMMITTED`; it publishes a validated
PID/start-token live-ready proof before the pointer can move.

- [ ] **Step 10: Replace both installers with complete argument-safe frontends (5 minutes)**

Replace `codex/install.sh` with:

```bash
#!/usr/bin/env bash
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE="$REPO/core/scripts/polylane-package.sh"

user_dest() {
  if [ -n "${CODEX_HOME:-}" ]; then printf '%s/skills/polylane\n' "$CODEX_HOME"
  elif [ -d "$HOME/.codex" ] || [ -w "$HOME" ]; then printf '%s/.codex/skills/polylane\n' "$HOME"
  else printf '%s/.agents/skills/polylane\n' "$HOME"; fi
}

mode=user; dest=""; print=0; journal=""; owner=""
while [ $# -gt 0 ]; do
  case "$1" in
    --user) mode=user ;;
    --repo) mode=repo ;;
    --dest) shift; dest=${1:-} ;;
    --print-user-dest) print=1 ;;
    --activation-record) shift; journal=${1:-} ;;
    --certification-owner-pid) shift; owner=${1:-} ;;
    *) echo "usage: codex/install.sh [--user|--repo|--dest ABS] [--print-user-dest] [--activation-record ABS --certification-owner-pid PID]" >&2; exit 2 ;;
  esac
  shift
done
if [ "$print" = 1 ]; then user_dest; exit 0; fi
if [ -z "$dest" ]; then
  if [ "$mode" = repo ]; then dest="$REPO/.codex/skills/polylane"; else dest=$(user_dest); fi
fi
set -- codex "$dest"
if [ -n "$journal" ] || [ -n "$owner" ]; then
  [ -n "$journal" ] && [ -n "$owner" ] || { echo "codex/install.sh: guarded flags are required together" >&2; exit 2; }
  set -- "$@" --activation-record "$journal" --certification-owner-pid "$owner"
fi
"$PACKAGE" "$@"
echo "installed Codex skill -> $dest"
```

Create `claude-code/install.sh` with:

```bash
#!/usr/bin/env bash
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE="$REPO/core/scripts/polylane-package.sh"
user_dest() { printf '%s/.claude/skills/polylane\n' "$HOME"; }
mode=user; dest=""; print=0; journal=""; owner=""
while [ $# -gt 0 ]; do
  case "$1" in
    --user) mode=user ;;
    --repo) mode=repo ;;
    --dest) shift; dest=${1:-} ;;
    --print-user-dest) print=1 ;;
    --activation-record) shift; journal=${1:-} ;;
    --certification-owner-pid) shift; owner=${1:-} ;;
    *) echo "usage: claude-code/install.sh [--user|--repo|--dest ABS] [--print-user-dest] [--activation-record ABS --certification-owner-pid PID]" >&2; exit 2 ;;
  esac
  shift
done
if [ "$print" = 1 ]; then user_dest; exit 0; fi
if [ -z "$dest" ]; then
  if [ "$mode" = repo ]; then dest="$REPO/.claude/skills/polylane"; else dest=$(user_dest); fi
fi
set -- claude-code "$dest"
if [ -n "$journal" ] || [ -n "$owner" ]; then
  [ -n "$journal" ] && [ -n "$owner" ] || { echo "claude-code/install.sh: guarded flags are required together" >&2; exit 2; }
  set -- "$@" --activation-record "$journal" --certification-owner-pid "$owner"
fi
"$PACKAGE" "$@"
echo "installed Claude Code skill -> $dest"
```

Run: `chmod +x codex/install.sh claude-code/install.sh`

Expected: both pass `bash -n`; each `--print-user-dest` command exits 0 without creating
its printed directory.

- [ ] **Step 11: Add maintenance-record retry to both launchers (4 minutes)**

Make this anchored edit immediately after `set -eu` in both
`codex/scripts/polylane-codex.sh` and `claude-code/scripts/polylane-claude.sh`:

```diff
diff --git a/codex/scripts/polylane-codex.sh b/codex/scripts/polylane-codex.sh
--- a/codex/scripts/polylane-codex.sh
+++ b/codex/scripts/polylane-codex.sh
@@
 set -eu
+INVOKED_ROOT=$(cd -L "$(dirname "$0")/.." && pwd -L)
+MAINTENANCE="$INVOKED_ROOT.polylane-maintenance.json"
+if [ -f "$MAINTENANCE" ]; then
+  deadline=$(jq -r '.retry_deadline // 0' "$MAINTENANCE" 2>/dev/null || echo 0)
+  while [ -f "$MAINTENANCE" ] && [ "$(date +%s)" -lt "$deadline" ]; do sleep 0.1; done
+  [ ! -f "$MAINTENANCE" ] || { echo "polylane-codex: maintenance retry deadline reached" >&2; exit 75; }
+fi
diff --git a/claude-code/scripts/polylane-claude.sh b/claude-code/scripts/polylane-claude.sh
--- a/claude-code/scripts/polylane-claude.sh
+++ b/claude-code/scripts/polylane-claude.sh
@@
 set -eu
+INVOKED_ROOT=$(cd -L "$(dirname "$0")/.." && pwd -L)
+MAINTENANCE="$INVOKED_ROOT.polylane-maintenance.json"
+if [ -f "$MAINTENANCE" ]; then
+  deadline=$(jq -r '.retry_deadline // 0' "$MAINTENANCE" 2>/dev/null || echo 0)
+  while [ -f "$MAINTENANCE" ] && [ "$(date +%s)" -lt "$deadline" ]; do sleep 0.1; done
+  [ ! -f "$MAINTENANCE" ] || { echo "polylane-claude: maintenance retry deadline reached" >&2; exit 75; }
+fi
```

Expected: both launchers pass `bash -n`; the persisted record's `retry_deadline` controls
the bounded retry and no launch occurs while the record remains live.

- [ ] **Step 12: Add read-only package integrity reporting to doctor (5 minutes)**

Make these anchored edits to `core/scripts/polylane-doctor.sh`:

```diff
diff --git a/core/scripts/polylane-doctor.sh b/core/scripts/polylane-doctor.sh
--- a/core/scripts/polylane-doctor.sh
+++ b/core/scripts/polylane-doctor.sh
@@
 USAGE:
   bin/polylane-doctor.sh [manifest.json]
+  bin/polylane-doctor.sh --package-only
+
+PACKAGE OPTION:
+  --package-only  verify the sealed whole-package manifest and print match, mixed, or unrecorded
@@
+check_core_package() {
+  local root manifest verifier
+  root=$(cd "$SCRIPT_DIR/.." && pwd -P)
+  manifest="$root/.polylane-package-manifest"
+  verifier="$root/scripts/polylane-package.sh"
+  if [ ! -f "$manifest" ]; then echo "core-package: unrecorded"; return 1; fi
+  if [ -x "$verifier" ] && "$verifier" verify-package "$root" >/dev/null 2>&1; then
+    echo "core-package: match"
+  else
+    echo "core-package: mixed"; return 1
+  fi
+}
+
 doctor_main() {
@@
   case "${1:-}" in
     -h|--help) usage; exit 0 ;;
+    --package-only) check_core_package ; exit $? ;;
```

Apply this test hunk:

```diff
diff --git a/core/tests/test-doctor.sh b/core/tests/test-doctor.sh
--- a/core/tests/test-doctor.sh
+++ b/core/tests/test-doctor.sh
@@
 assert_contains "help-shows-usage"  "USAGE:" "$help_out"
+assert_contains "help-package-integrity" "--package-only" "$(sed -n '/USAGE:/,/EXIT:/p' "$ROOT/core/scripts/polylane-doctor.sh")"
```

Expected: doctor passes `bash -n`; it never writes while computing `match`, `mixed`, or
`unrecorded`.

- [ ] **Step 13: Run all five package tests and verify GREEN (5 minutes)**

```bash
bash codex/tests/test-codex-install.sh
bash claude-code/tests/test-claude-install.sh
bash core/tests/test-package-parity.sh
bash core/tests/test-package-legacy-migration.sh
bash core/tests/test-package-activation.sh
```

Expected: all five exit 0. The activation test reports publisher fields, owner-death
rollback, guard-bootstrap recovery, both pointer-boundary SIGKILL cases, first-install
removal, both sides of atomic commit publication, committed survival, bounded owner timeout, and stale CAS
rejection. The legacy test reports all three preflight blockers, ordinary/SIGKILL
restoration, private-initializer publication, anchored close-marker concurrency, and
SIGKILL close-marker recovery without a recursive meta-gate.

- [ ] **Step 14: Run package syntax, doctor, and aggregate verification (5 minutes)**

Run:

```bash
bash -n core/scripts/polylane-package.sh core/scripts/polylane-procargs-macos \
  core/scripts/polylane-install-guard.sh \
  codex/install.sh claude-code/install.sh
bash core/tests/test-doctor.sh
tests/run.sh
```

Expected: every command exits 0 and the aggregate summary reports zero failed files.

- [ ] **Step 15: Commit deterministic packaging without activating the user skill (2 minutes)**

Run:

```bash
git add core/scripts/polylane-package.sh core/scripts/polylane-procargs-macos \
  core/tests/test-package-parity.sh core/scripts/polylane-install-guard.sh \
  core/tests/test-package-legacy-migration.sh core/tests/test-package-activation.sh \
  core/scripts/polylane-doctor.sh core/tests/test-doctor.sh \
  codex/install.sh codex/scripts/polylane-codex.sh codex/tests/test-codex-install.sh \
  claude-code/install.sh claude-code/scripts/polylane-claude.sh \
  claude-code/tests/test-claude-install.sh
git commit -m "feat: assemble deterministic platform packages"
```

Expected: exit 0 with commit subject `feat: assemble deterministic platform packages`.
Do not run either installer with `--user`.

---

### Task 6: Classify Failures and Hand Recovery to the Persistent Layer

**Files:**
- Modify: `core/scripts/polylane-agent.sh`
- Modify: `codex/scripts/polylane-codex-agent.sh`
- Modify: `codex/scripts/polylane-codex-exec.sh`
- Modify: `core/scripts/polylane-run.sh`
- Modify: `core/scripts/polylane-supervisor.sh`
- Create: `core/tests/test-recovery-handoff.sh`
- Create: `core/tests/test-full-preflight-attempts.sh`
- Create: `core/tests/test-cleanup-result.sh`
- Create: `core/tests/test-owned-session-cleanup.sh`
- Create: `core/tests/fixtures/final-launcher-contract.sh`
- Create: `codex/tests/test-codex-errors.sh`
- Modify: `core/tests/test-supervisor.sh`, `core/tests/test-pane-errored.sh`

**Interfaces:**
- `polylane_agent_error_class <agent> <structured-error.json>` prints exactly `none`, `transient`,
  `rate_limit`, `invalid_model`, or `user_action`.
- Every one-cycle outcome writes a mode-0400, claim-unique schema-v2 raw result at the
  Runtime-supplied `POLYLANE_CYCLE_RESULT_RECEIPT` path under `.polylane/runtime/cycle-results/`.
  Exhausted recovery exits 75 and never selects a terminal state. Runtime owns validating and
  snapshotting this raw result, then binding it to the active claim and authoritative runner
  identity in the persistent `cycle-runner/cycle_result` event.

- [ ] **Step 1: Add the complete pure Codex classification test (4 minutes)**

Create `codex/tests/test-codex-errors.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
. "$ROOT/core/scripts/polylane-agent.sh"
. "$ROOT/codex/scripts/polylane-codex-agent.sh"
make_tmpdir
write_events() {
  name=$1; nested=$2; file="$TEST_TMPDIR/$name.jsonl"
  printf '%s\n' '{"type":"thread.started","thread_id":"t-1"}' \
    '{"type":"item.completed","item":{"type":"error","message":"Model metadata warning unrelated to the terminal provider response."}}' \
    '{"type":"turn.started"}' > "$file"
  jq -cn '{type:"item.completed",item:{type:"error",message:"Skills context-budget warning unrelated to the terminal provider response."}}' >> "$file"
  jq -cn --arg message "$nested" '{type:"error",message:$message}' >> "$file"
  jq -cn --arg message "$nested" '{type:"turn.failed",error:{message:$message}}' >> "$file"
}
while IFS='|' read -r want nested; do
  want=$(printf '%s' "$want" | tr -d '[:space:]')
  nested=$(printf '%s' "$nested" | sed 's/^[[:space:]]*//')
  name="case-$PASS_COUNT"; write_events "$name" "$nested"
  : > "$TEST_TMPDIR/$name.stderr"
  assert_ok "capture-$name" polylane_adapter_capture_error \
    "$TEST_TMPDIR/$name.jsonl" "$TEST_TMPDIR/$name.stderr" "$TEST_TMPDIR/$name.json" 1
  assert_eq "class-$PASS_COUNT-$want" "$want" \
    "$(polylane_agent_error_class codex "$TEST_TMPDIR/$name.json")"
done <<'CASES'
user_action | {"status":401,"error":{"type":"authentication_error","code":"invalid_api_key"}}
invalid_model | {"status":400,"error":{"type":"invalid_request_error","code":"model_not_found"}}
invalid_model | {"type":"error","status":400,"error":{"type":"invalid_request_error","message":"The 'gpt-5.4' model is not supported when using Codex with a ChatGPT account."}}
rate_limit | {"status":429,"error":{"type":"rate_limit_error","code":"rate_limit_exceeded"}}
rate_limit | {"type":"error","status":429,"error":{"type":"rate_limit_error","message":"Too many requests. Please retry."}}
transient | {"status":503,"error":{"type":"server_error","code":"service_unavailable"}}
transient | {"type":"error","status":0,"error":{"type":"network_error","message":"error sending request for url https://api.openai.com/responses"}}
none | {"status":400,"error":{"type":"connector_auth","code":"missing_authorization"}}
none | {"status":400,"error":{"type":"invalid_request_error","message":"warning: the model gpt-5.4 is not supported when using Codex with a ChatGPT account"}}
CASES

printf '%s\n' '429 Too Many Requests' 'Codex is not logged in' > "$TEST_TMPDIR/transcript.jsonl"
: > "$TEST_TMPDIR/stderr.txt"
assert_rc "generic-transcript-capture-rejected" 7 polylane_adapter_capture_error \
  "$TEST_TMPDIR/transcript.jsonl" "$TEST_TMPDIR/stderr.txt" "$TEST_TMPDIR/transcript.json" 1
assert_eq "generic-transcript-is-not-classified" none \
  "$(polylane_agent_error_class codex "$TEST_TMPDIR/transcript.json")"
printf '{broken\n' > "$TEST_TMPDIR/broken.json"
assert_eq "corrupt-artifact-is-none" none \
  "$(polylane_agent_error_class codex "$TEST_TMPDIR/broken.json")"
printf '%s\n' '{"type":"thread.started","thread_id":"t-1"}' \
  '{"type":"item.completed","item":{"type":"reasoning"}}' > "$TEST_TMPDIR/missing-terminal.jsonl"
assert_rc "missing-terminal-rejected" 7 polylane_adapter_capture_error \
  "$TEST_TMPDIR/missing-terminal.jsonl" "$TEST_TMPDIR/stderr.txt" "$TEST_TMPDIR/missing-terminal.json" 1
write_events multiple '{"status":503,"error":{"type":"server_error"}}'
jq -cn --arg message '{"status":503,"error":{"type":"server_error"}}' \
  '{type:"turn.failed",error:{message:$message}}' >> "$TEST_TMPDIR/multiple.jsonl"
assert_rc "multiple-terminal-events-rejected" 7 polylane_adapter_capture_error \
  "$TEST_TMPDIR/multiple.jsonl" "$TEST_TMPDIR/stderr.txt" "$TEST_TMPDIR/multiple.json" 1
write_events mismatch '{"status":503,"error":{"type":"server_error"}}'
tmp="$TEST_TMPDIR/mismatch.tmp"
while IFS= read -r event; do
  printf '%s' "$event" | jq -c \
    'if .type=="error" then .message="{\"status\":429,\"error\":{\"type\":\"rate_limit_error\"}}" else . end'
done < "$TEST_TMPDIR/mismatch.jsonl" > "$tmp" && mv "$tmp" "$TEST_TMPDIR/mismatch.jsonl"
assert_rc "duplicate-error-payload-mismatch-rejected" 7 polylane_adapter_capture_error \
  "$TEST_TMPDIR/mismatch.jsonl" "$TEST_TMPDIR/stderr.txt" "$TEST_TMPDIR/mismatch.json" 1
ln -s "$TEST_TMPDIR/mismatch.jsonl" "$TEST_TMPDIR/events-link.jsonl"
assert_rc "event-symlink-rejected" 7 polylane_adapter_capture_error \
  "$TEST_TMPDIR/events-link.jsonl" "$TEST_TMPDIR/stderr.txt" "$TEST_TMPDIR/event-link.json" 1
ln -s "$TEST_TMPDIR/mismatch.json" "$TEST_TMPDIR/result-link.json"
assert_rc "result-symlink-rejected" 7 polylane_adapter_capture_error \
  "$TEST_TMPDIR/mismatch.jsonl" "$TEST_TMPDIR/stderr.txt" "$TEST_TMPDIR/result-link.json" 1
printf '%s\n' '429 warning on stderr is never parsed' > "$TEST_TMPDIR/stderr.txt"
assert_fail "stderr-does-not-create-artifact" test -e "$TEST_TMPDIR/stderr.json"
printf '%s\n' '{"type":"thread.started","thread_id":"t-1"}' '{"type":"turn.started"}' \
  '{"type":"turn.completed"}' > "$TEST_TMPDIR/success.jsonl"
assert_ok "success-result-artifact" polylane_adapter_capture_error \
  "$TEST_TMPDIR/success.jsonl" "$TEST_TMPDIR/stderr.txt" "$TEST_TMPDIR/success.json" 0
assert_eq "success-class-none" none "$(polylane_agent_error_class codex "$TEST_TMPDIR/success.json")"
success_events_hash=$(if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$TEST_TMPDIR/success.jsonl"; else sha256sum "$TEST_TMPDIR/success.jsonl"; fi | awk '{print "sha256:"$1}')
success_stderr_hash=$(if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "$TEST_TMPDIR/stderr.txt"; else sha256sum "$TEST_TMPDIR/stderr.txt"; fi | awk '{print "sha256:"$1}')
assert_eq "artifact-binds-events-hash" "$success_events_hash" \
  "$(jq -r .events_hash "$TEST_TMPDIR/success.json")"
assert_eq "artifact-binds-stderr-hash" "$success_stderr_hash" \
  "$(jq -r .stderr_hash "$TEST_TMPDIR/success.json")"
write_events integrity '{"status":503,"error":{"type":"server_error","code":"service_unavailable"}}'
: > "$TEST_TMPDIR/integrity.stderr"
assert_ok "integrity-capture" polylane_adapter_capture_error \
  "$TEST_TMPDIR/integrity.jsonl" "$TEST_TMPDIR/integrity.stderr" \
  "$TEST_TMPDIR/integrity.json" 1
assert_eq "integrity-before-tamper" transient \
  "$(polylane_agent_error_class codex "$TEST_TMPDIR/integrity.json")"
printf '%s\n' '{"type":"item.completed","item":{"type":"error","message":"late mutation"}}' \
  >> "$TEST_TMPDIR/integrity.jsonl"
assert_eq "event-tamper-is-none" none \
  "$(polylane_agent_error_class codex "$TEST_TMPDIR/integrity.json")"
write_events integrity-stderr '{"status":503,"error":{"type":"server_error","code":"service_unavailable"}}'
: > "$TEST_TMPDIR/integrity-stderr.stderr"
assert_ok "stderr-integrity-capture" polylane_adapter_capture_error \
  "$TEST_TMPDIR/integrity-stderr.jsonl" "$TEST_TMPDIR/integrity-stderr.stderr" \
  "$TEST_TMPDIR/integrity-stderr.json" 1
printf '%s\n' 'late stderr mutation' >> "$TEST_TMPDIR/integrity-stderr.stderr"
assert_eq "stderr-tamper-is-none" none \
  "$(polylane_agent_error_class codex "$TEST_TMPDIR/integrity-stderr.json")"
finish
```

Run: `bash -n codex/tests/test-codex-errors.sh`

Expected: exit 0; every classifier case is data-only and the test has no external side
effects.

- [ ] **Step 2: Add the complete recovery handoff/nonces test (5 minutes)**

Create `core/tests/test-recovery-handoff.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
PROJ="$TEST_TMPDIR/proj"; mkdir -p "$PROJ/.polylane/runtime" "$TEST_TMPDIR/bin"
git -C "$PROJ" init -q -b main
git -C "$PROJ" config user.email test@example.invalid
git -C "$PROJ" config user.name Test
printf 'base\n' > "$PROJ/history"; git -C "$PROJ" add history; git -C "$PROJ" commit -qm base
BASE_COMMIT=$(git -C "$PROJ" rev-parse HEAD)
printf 'go\n' >> "$PROJ/history"; git -C "$PROJ" commit -qam go
GO_COMMIT=$(git -C "$PROJ" rev-parse HEAD)
MANIFEST="$PROJ/.polylane/run.json"
printf '%s\n' '{"agent":"codex","loop_id":"loop-1","cycle":3,"run_id":"run-1","base":"main","lanes":[],"integrator":{}}' > "$MANIFEST"
cat > "$TEST_TMPDIR/bin/fake-runner.sh" <<'SH'
#!/usr/bin/env bash
set -u
manifest=$1; dir=$(cd "$(dirname "$manifest")" && pwd)
result=${POLYLANE_CYCLE_RESULT_RECEIPT:?missing claim-unique receipt}
count=0; [ ! -f "$dir/count" ] || count=$(cat "$dir/count"); count=$((count+1)); echo "$count" > "$dir/count"
write_result() {
  outcome=$1; run=$2; verdict=$3; integration=$4; tmp="$result.tmp.$$"
  mkdir -p "$(dirname "$result")"
  manifest_hash=$(if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$manifest"; \
    else sha256sum "$manifest"; fi | awk '{print "sha256:"$1}')
  jq -nS --arg run "$run" --arg hash "$manifest_hash" --arg outcome "$outcome" \
    --argjson verdict "$verdict" --argjson integration "$integration" \
    '{schema_version:2,run_id:$run,manifest_hash:$hash,outcome:$outcome,verdict:$verdict,
      base_ref:"main",expected_base:$ENV.BASE_COMMIT,lane_commits:[],integration_commit:$integration}' \
    > "$tmp" && chmod 0400 "$tmp" && mv "$tmp" "$result"
}
case "${RESULT_MODE:-crash}" in
  crash) exit 137 ;;
  classified)
    error_dir="$dir/runtime/agent-errors/$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION/a$POLYLANE_ATTEMPT"
    mkdir -p "$error_dir"
    events="$error_dir/lane-1.events.jsonl"
    stderr="$error_dir/lane-1.stderr"
    nested='{"status":429,"error":{"type":"rate_limit_error","code":"rate_limit_exceeded"}}'
    printf '%s\n' '{"type":"thread.started","thread_id":"t-1"}' '{"type":"turn.started"}' > "$events"
    jq -cn --arg message "$nested" '{type:"error",message:$message}' >> "$events"
    jq -cn --arg message "$nested" '{type:"turn.failed",error:{message:$message}}' >> "$events"
    : > "$stderr"; chmod 0400 "$events" "$stderr"
    hash_one() {
      if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1"; else sha256sum "$1"; fi |
        awk '{print "sha256:"$1}'
    }
    jq -n --arg events "$events" --arg events_hash "$(hash_one "$events")" \
      --arg stderr "$stderr" --arg stderr_hash "$(hash_one "$stderr")" \
      '{schema_version:2,provider:"codex",kind:"rate_limit",code:"rate_limit_exceeded",
        status:429,error_type:"rate_limit_error",terminal_type:"turn.failed",process_exit:1,
        events_path:$events,events_hash:$events_hash,stderr_path:$stderr,stderr_hash:$stderr_hash}' \
      > "$error_dir/lane-1.json"
    # A more severe artifact from a previous attempt must never influence this attempt.
    mkdir -p "$dir/runtime/agent-errors/$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION/a1"
    jq '.kind="user_action" | .code="invalid_api_key"' "$error_dir/lane-1.json" \
      > "$dir/runtime/agent-errors/$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION/a1/lane-1.json"
    exit 137 ;;
  crash-then-go) [ "$count" -lt 2 ] && exit 137; write_result GO run-1 '"GO"' "\"$GO_COMMIT\"" ;;
  nogo) write_result NO_GO run-1 '"NO_GO"' null; exit 1 ;;
  stale) write_result GO stale-run '"GO"' '"b"' ;;
esac
SH
chmod +x "$TEST_TMPDIR/bin/fake-runner.sh"
SUP="$ROOT/core/scripts/polylane-supervisor.sh"
run_sup() {
  RESULT_MODE=$1 BASE_COMMIT="$BASE_COMMIT" GO_COMMIT="$GO_COMMIT" \
    POLYLANE_CYCLE_RESULT_RECEIPT="$RESULT" POLYLANE_REPO_ROOT="$PROJ" \
    POLYLANE_CLAIM_TOKEN=claim-a POLYLANE_RUNNER_GENERATION=4 POLYLANE_ATTEMPT=2 \
    POLYLANE_RUNNER="$TEST_TMPDIR/bin/fake-runner.sh" \
    POLYLANE_AGENT=codex \
    POLYLANE_AGENT_ADAPTER="$ROOT/codex/scripts/polylane-codex-agent.sh" \
    POLYLANE_SESSION="no-session-$$" POLYLANE_SUP_INTERVAL=1 \
    POLYLANE_SUP_MAX_RESTARTS=${2:-1} "$SUP" "$MANIFEST"
}
RESULT="$PROJ/.polylane/runtime/cycle-results/run-1.claim-a.g4.a2.json"
reset_case() { chmod 0600 "$RESULT" 2>/dev/null || true; rm -f "$PROJ/.polylane/count" "$RESULT"; }
validate_result() {
  bash -c '. "$1"; polylane_validate_cycle_result "$2" "$3" "$4"' _ \
    "$ROOT/core/scripts/polylane-agent.sh" "$1" "$MANIFEST" "$PROJ"
}

reset_case; assert_ok "crash-revives-to-go" run_sup crash-then-go 2
assert_eq "revived-twice" 2 "$(cat "$PROJ/.polylane/count")"
assert_eq "go-outcome" GO "$(jq -r .outcome "$RESULT")"
assert_eq "go-result-mode" 400 "$(case "$(uname -s)" in Linux) stat -c '%a' "$RESULT" ;; *) stat -f '%Lp' "$RESULT" ;; esac)"
assert_ok "raw-result-validator" validate_result "$RESULT"
bad_manifest="$TEST_TMPDIR/bad-manifest.json"
jq '.lanes=[{"name":"missing-lane"}]' "$MANIFEST" > "$bad_manifest"
bad_result="$TEST_TMPDIR/bad-result.json"
jq --arg hash "$(if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$bad_manifest"; else sha256sum "$bad_manifest"; fi | awk '{print "sha256:"$1}')" \
  '.manifest_hash=$hash' "$RESULT" > "$bad_result"; chmod 0400 "$bad_result"
assert_fail "exact-manifest-lane-set-required" bash -c \
  '. "$1"; polylane_validate_cycle_result "$2" "$3" "$4"' _ \
  "$ROOT/core/scripts/polylane-agent.sh" "$bad_result" "$bad_manifest" "$PROJ"
bogus="$TEST_TMPDIR/bogus-result.json"
jq '.expected_base="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' "$RESULT" > "$bogus"; chmod 0400 "$bogus"
assert_fail "bogus-commit-rejected" bash -c \
  '. "$1"; polylane_validate_cycle_result "$2" "$3" "$4"' _ \
  "$ROOT/core/scripts/polylane-agent.sh" "$bogus" "$MANIFEST" "$PROJ"
FOREIGN="$TEST_TMPDIR/foreign"; git -C "$FOREIGN" init -q -b main 2>/dev/null || {
  mkdir -p "$FOREIGN"; git -C "$FOREIGN" init -q -b main;
}
assert_fail "foreign-repository-rejected" bash -c \
  '. "$1"; polylane_validate_cycle_result "$2" "$3" "$4"' _ \
  "$ROOT/core/scripts/polylane-agent.sh" "$RESULT" "$MANIFEST" "$FOREIGN"
chmod 0600 "$RESULT"; assert_fail "mutable-result-rejected" validate_result "$RESULT"; chmod 0400 "$RESULT"
ln -s "$RESULT" "$RESULT.link"
assert_fail "result-symlink-rejected" validate_result "$RESULT.link"
rm "$RESULT.link"
reset_case; assert_rc "matching-nogo-rc" 1 run_sup nogo 1
assert_eq "nogo-no-integration" null "$(jq -r .integration_commit "$RESULT")"
reset_case; assert_rc "stale-result-rejected" 75 run_sup stale 1
assert_eq "stale-result-remains-untrusted" stale-run "$(jq -r .run_id "$RESULT")"
reset_case; assert_rc "exhausted-rc75" 75 run_sup crash 1
assert_eq "recovery-run" run-1 "$(jq -r .run_id "$RESULT")"
assert_eq "recovery-schema" 2 "$(jq -r .schema_version "$RESULT")"
assert_eq "recovery-no-integration" null "$(jq -r .integration_commit "$RESULT")"
reset_case; assert_rc "structured-rate-limit-rc75" 75 run_sup classified 0
assert_eq "structured-failure-recovery-result" RECOVERY_REQUIRED "$(jq -r .outcome "$RESULT")"
assert_eq "exact-attempt-class-only" rate_limit "$(bash -c \
  '. "$1"; . "$2"; polylane_latest_error_class codex "$3"' _ \
  "$ROOT/core/scripts/polylane-agent.sh" "$ROOT/codex/scripts/polylane-codex-agent.sh" \
  "$PROJ/.polylane/runtime/agent-errors/claim-a/g4/a2")"
bad=$(rg -n 'COMPLETE|WAITING_FOR_USER|HALTED|FAILED' "$PROJ/.polylane" || true)
assert_eq "no-terminal-state" "" "$bad"

OWNED="$TEST_TMPDIR/owned"; mkdir -p "$OWNED/cycle-results"
printf '%s\n' '{"attempt":2,"claim_token":"claim-p","run_id":"run-1","runner_generation":1}' \
  > "$OWNED/cycle-results/run-1.claim-p.g1.a2.owner.json"
chmod 0400 "$OWNED/cycle-results/run-1.claim-p.g1.a2.owner.json"
POLYLANE_RUNTIME_DIR="$OWNED" POLYLANE_MANIFEST="$MANIFEST" \
POLYLANE_CYCLE_RUN_ID=run-1 POLYLANE_CLAIM_TOKEN=claim-p POLYLANE_RUNNER_GENERATION=1 \
  POLYLANE_ATTEMPT=2 \
  POLYLANE_CYCLE_RESULT_RECEIPT="$OWNED/cycle-results/run-1.claim-p.g1.a2.json" \
  POLYLANE_BASE_BEFORE="$BASE_COMMIT" \
  bash -c '. "$1"; polylane_preflight_recovery invalid_manifest' _ \
    "$ROOT/core/scripts/polylane-agent.sh"
assert_eq "owned-preflight-result" RECOVERY_REQUIRED \
  "$(jq -r .outcome "$OWNED/cycle-results/run-1.claim-p.g1.a2.json")"
UNOWNED="$TEST_TMPDIR/unowned"; mkdir -p "$UNOWNED"
POLYLANE_RUNTIME_DIR="$UNOWNED" POLYLANE_MANIFEST="$MANIFEST" \
POLYLANE_CYCLE_RUN_ID=run-1 POLYLANE_CLAIM_TOKEN=claim-p POLYLANE_RUNNER_GENERATION=1 \
  POLYLANE_ATTEMPT=2 \
  POLYLANE_CYCLE_RESULT_RECEIPT="$UNOWNED/cycle-results/run-1.claim-p.g1.a2.json" \
  bash -c '. "$1"; polylane_preflight_recovery invalid_manifest' _ \
  "$ROOT/core/scripts/polylane-agent.sh"
assert_fail "unowned-no-result" test -e "$UNOWNED/cycle-results/run-1.claim-p.g1.a2.json"
finish
```

Run: `bash -n core/tests/test-recovery-handoff.sh`

Expected: exit 0; GO, NO_GO, stale, exhausted, owned, and unowned nonce cases are
syntactically valid.

- [ ] **Step 3: Run both tests and verify RED (2 minutes)**

```bash
bash codex/tests/test-codex-errors.sh
bash core/tests/test-recovery-handoff.sh
```

Expected: both exit nonzero because classification still returns `none` and supervisor
still trusts report timestamps instead of nonce-bound cycle results.

#### Structured recovery implementation contract (normative)

Keep `polylane_agent_error_class` in core as a pure delegate. Each adapter accepts only its
versioned JSON error artifact and maps the explicit `kind`; generic transcript phrases,
connector-auth failures, corrupt JSON, and unknown kinds return `none`. No shared or Codex
classifier contains prose/credit grep patterns. Rate limits are not transient; invalid models remain
internally recoverable by an approved alternate model; `user_action` is only a fact for the
future controller, which must exhaust internal alternatives before entering
`WAITING_FOR_USER`.

Before tmux exists, the adapter resolves Codex to a physical script/native executable, resolves
`/bin/bash` to its physical trusted executable, and, for the only supported env shebang
`#!/usr/bin/env node`, resolves `node` only from the discovered Codex launcher's directory.
It records device, inode, mode, and SHA-256 for Bash, wrapper, Codex, and Node in the pane
command, invokes the physical Bash and Node explicitly, and revalidates every identity immediately
before and after Codex. Unsupported shebangs fail closed; a post-launch replacement publishes a
typed `launch_identity_changed` capture failure and exits 74. The runner starts the first tmux pane
with that physical shell and binds the session's `default-shell` and `default-command` before
splitting or respawning panes, so mutable PATH cannot reintroduce a shell/interpreter lookup.

The Codex exec shim adds `--json`, drains stdout JSONL separately from stderr through the
no-follow filesystem helper, and accepts one
chain beginning with one `thread.started` and ending in exactly one final `turn.completed`
or `turn.failed`. Typed `item.completed` errors are incidental diagnostics and are never
classified. When top-level `error` events precede `turn.failed`, the last one's structured
payload must exactly match the final `error.message`, which must itself parse as a JSON
object. Only numeric status and structured error `type`/`code` map to the
versioned result artifact. Success and failure artifacts bind the stdout JSONL hash, process
exit, terminal type, and a separately captured (never classified) stderr path and hash. Missing,
corrupt, mismatched, or multiple terminal sequences create a typed `parser_invalid` transport
artifact rather than an untyped disappearance. Event, stderr, temp,
and result paths are no-follow; completed event/stderr files and the immutable result are mode
0400. Event-capture or result-publication failure exits 74 instead of falsely preserving
a successful Codex exit; the shim preserves the Codex process exit status only after a structurally
valid terminal sequence.
The stable `<result>.events.jsonl` and `<result>.stderr` files exist from process launch;
the result file remains absent until a terminal sequence validates. Two bounded byte-stream
drains use the Python helper's already-open no-follow sink descriptors and cap JSONL and stderr independently
without buffering an unbounded line, and the parser has its own short deadline. All capture
tools—including every external used later by hashing, publication, timing, and mode checks—
and one SHA-256 implementation are checked when the adapter is resolved, before tmux launch,
and again before a direct wrapper creates any artifact directory. Overrides are digit- and
range-checked (events 1..64 MiB, stderr 1..16 MiB, parser 1..60 seconds) before arithmetic.
A cap, drain failure, parser breach, or structurally invalid parser outcome publishes
integrity-bound `kind:"transient"`, `terminal_type:"capture.failed"` evidence with code
`capture_limit`, `capture_drain_failed`, `parser_timeout`, or `parser_invalid`, then exits 74.
These capture deadlines do not invent a failure merely because Codex is live but silent: the
runtime-owned lane deadline/fencing layer still owns process termination for silence.

Every normal, `capture_limit`, `capture_drain_failed`, `parser_timeout`, `parser_invalid`, or
`launch_identity_changed` result is assembled
as one complete, mode-0400 private payload. `polylane_codex_result_extension_json` is the sole
Builder extension point for prompt and actor bindings and is merged only when it does not overlap
Foundation keys. The wrapper performs one final exclusive hard-link publication and never deletes,
replaces, or rewrites a visible result; parser timeout may discard only the never-published private
payload before constructing its typed terminal payload.

Write every immutable result with this complete schema (non-applicable values are null):

```json
{
  "schema_version": 2,
  "run_id": "<manifest nonce>",
  "manifest_hash": "sha256:<64 lowercase hex>",
  "outcome": "RECOVERY_REQUIRED",
  "verdict": null,
  "base_ref": "main",
  "expected_base": "<commit before integration>",
  "lane_commits": [{"name": "lane-a", "commit": "<exact lane commit>"}],
  "integration_commit": null,
  "cleanup_evidence_path": null,
  "cleanup_evidence_hash": null
}
```

`GO` requires `verdict:"GO"`, the exact base ref/expected-base commit, every lane name and
commit, the resulting integration commit, and a mode-0400 cleanup sidecar bound by exact path and
SHA-256. Before any cleanup evidence is sealed, production revalidates the captured tmux session
ID, exact session name, all run/loop/claim/generation ownership tags, and its pane set. It captures
an immutable exclusion inventory before any owned-process discovery: the fence caller's exact
PID/birth token, every authenticated ancestor through init, and every caller/control PGID represented
by that chain. Discovery, record merge, and signaling all reject those PIDs and PGIDs; a pane root
colliding with the exclusion inventory fails closed. Thus the fence cannot enroll or signal its
caller, its control shell, an ancestor, or an out-of-band observer in their process groups.
It then captures
the high-resolution birth identity of every authenticated pane root, sends exact STOP to those
roots first, then repeatedly captures and STOPs recursive descendants until PID, PGID, and birth-token
membership is stable. Because tmux may SIGCONT its foreground pane group, production does not infer
quiescence from that pre-kill pass: after the fixed point and a second pane/tag revalidation it kills
that session ID, immediately STOPs the complete fixed-point set again, and recaptures/STOPs until
every still-live recorded identity is stopped with tmux no longer able to resume it. Only then does
it CONT all frozen identities, apply bounded TERM then KILL to authenticated groups (falling back
to exact PID/token pairs), and wait after each phase. After CONT, every stabilized exact identity
and authenticated PGID remains a discovery root. Each TERM-grace scan recursively enumerates live
recorded identities and every current member of those PGIDs, birth-authenticates additions, adds
them to the inventory, and STOPs each new member before the next scan. The KILL phase re-enumerates
the same lineage/group sets before every signal, kills the complete reauthenticated inventory or
safe complete group, and repeats until a global final inventory scan and every exact identity are
absent. The SIGCONT-fork fixture proves that a TERM-resistant detached worker's inherited-PGID child
is found after its original pane root is gone and is killed. That worker first creates and proves a
distinct authenticated session and PGID. A separate observer in the excluded control PGID records
the CONT, TERM-grace, KILL, and completion phase events, proving the caller survives, the function
returns, and the child entered the final fenced inventory. The fork-during-capture fixture
forces a child to appear after one process-table snapshot and verifies the next STOP/capture pass
includes and fences it. This portable guarantee covers cooperative descendants that remain beneath
a live recorded identity or in a captured authenticated PGID. An arbitrary same-UID descendant that
deliberately creates a new session/process group and becomes reparented between scans is outside the
threat model; containing that escape requires an OS process container such as a cgroup, not a tmux/PID
contract. It never falls back to the reusable session name; a stale ID or same-name foreign
replacement forces recovery. The sidecar is sealed only after lane worktrees, lane branches, that
exact session, and the complete scoped descendant/group inventory are absent. NO_GO does not invoke this fence
and retains resumable panes/worktrees. Cleanup or evidence-sealing failure publishes only a typed
`RECOVERY_REQUIRED` receipt and exits 75; a GO receipt does not exist before this cleanup
linearization point. `NO_GO` requires `verdict:"NO_GO"` and a null
integration commit; `RECOVERY_REQUIRED` requires null verdict and integration commit. The raw
result deliberately contains neither claim nor runner identity: Runtime’s independently published,
claim-hashed event is authoritative. Foundation uses true O_EXCL/no-follow temporary creation,
exclusive hard-link publication, and mode 0400. Its pure validator recomputes the manifest
SHA-256, requires the exact manifest lane-name set for GO, accepts only real commit objects from the
same repository, and verifies that every GO lane commit and the expected base are ancestors of
the promoted integration commit. Preserve `POLYLANE_AGENT`, `POLYLANE_AGENT_CMD`, model,
effort, claim token, receipt path, runner generation, and attempt through every supervisor restart. A fresh
claim-bound Runtime event/result snapshot, not report mtime or a mutable singleton, defines
legitimate one-cycle completion.

Every launcher preflight is strictly read-only and state-aware. Its `planned` pass validates the
complete manifest (including full lane/integrator actors, unique branches/worktrees/prompts, and
nonempty lane ownership globs), every prompt as a nonempty safe regular file, fresh worktree destinations, adapter template,
trusted shell, selected CLI, complete capture dependencies, Python helper, Git repository/HEAD and
base, disk threshold, exact-name tmux collision ownership, and exact planned
claim/generation/attempt/receipt identity before any runtime directory, worktree, tmux session,
owner, or receipt is created. Only then may exclusive allocation publish immutable owner records.
The runner repeats the same full pass in `allocated` state and requires exact allocated owner
identity; supervisor restart uses `planned` identity with an explicit `owned-retry` worktree policy
that accepts only physical worktrees from the same repository on their exact manifest branches.
Malformed manifests, prompts, worktrees, adapters, dependencies, or collisions therefore leave
runtime, Git, and tmux untouched. A failed preflight never fabricates a recovery result; recovery
handoff is permitted only from an already allocated attempt.

- [ ] **Step 4: Add atomic result writing and immutable attempt identity to core (5 minutes)**

Make this anchored edit to `core/scripts/polylane-agent.sh`:

```diff
diff --git a/core/scripts/polylane-agent.sh b/core/scripts/polylane-agent.sh
--- a/core/scripts/polylane-agent.sh
+++ b/core/scripts/polylane-agent.sh
@@
 polylane_agent_error_class() {
@@
 }
+
+polylane_sha256() {
+  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1"; else sha256sum "$1"; fi |
+    awk '{print "sha256:"$1}'
+}
+
+polylane_publish_immutable() {
+  local tmp=$1 dest=$2 hash
+  [ -f "$tmp" ] && [ ! -L "$tmp" ] && [ ! -e "$dest" ] && [ ! -L "$dest" ] || return 1
+  hash=$(polylane_sha256 "$tmp")
+  polylane_publish_private "$tmp" "$dest" || return 1
+  [ -f "$dest" ] && [ ! -L "$dest" ] && [ "$(polylane_sha256 "$dest")" = "$hash" ]
+}
+
+polylane_mode_of() {
+  case "$(uname -s)" in
+    Linux) stat -c '%a' "$1" ;; Darwin|FreeBSD|OpenBSD|NetBSD) stat -f '%Lp' "$1" ;;
+    *) return 1 ;;
+  esac
+}
+
+polylane_validate_cycle_result() {
+  local result=$1 manifest=$2 repo=${3:?repository root required} manifest_hash run base_ref
+  local expected integration commit name cleanup
+  [ -f "$result" ] && [ ! -L "$result" ] && [ "$(polylane_mode_of "$result")" = 400 ] && \
+    [ -f "$manifest" ] && [ ! -L "$manifest" ] || return 1
+  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 1
+  manifest_hash=$(polylane_sha256 "$manifest") || return 1
+  run=$(jq -er '.run_id | select(type=="string" and length>0)' "$manifest") || return 1
+  base_ref=$(jq -er '.base | select(type=="string" and length>0)' "$manifest") || return 1
+  jq -eS --arg run "$run" --arg manifest_hash "$manifest_hash" --arg base_ref "$base_ref" \
+    --argjson manifest_lanes "$(jq -c '[.lanes[].name]' "$manifest")" '
+    type=="object" and
+    keys==["base_ref","cleanup_evidence_hash","cleanup_evidence_path","expected_base",
+      "integration_commit","lane_commits","manifest_hash","outcome","run_id","schema_version","verdict"] and
+    .schema_version==2 and .run_id==$run and .manifest_hash==$manifest_hash and
+    .base_ref==$base_ref and (.expected_base|type)=="string" and
+    (.expected_base|test("^[0-9a-f]{40}([0-9a-f]{24})?$")) and
+    (.lane_commits|type)=="array" and
+    (all(.lane_commits[]; type=="object" and keys==["commit","name"] and
+      (.name|type)=="string" and (.name|length)>0 and
+      (.commit|type)=="string" and (.commit|test("^[0-9a-f]{40}([0-9a-f]{24})?$")))) and
+    ([.lane_commits[].name]|length)==([.lane_commits[].name]|unique|length) and
+    (.outcome!="GO" or ([.lane_commits[].name]|sort)==($manifest_lanes|sort)) and
+    ((.outcome=="GO" and .verdict=="GO" and
+       (.cleanup_evidence_path|type)=="string" and
+       (.cleanup_evidence_hash|test("^sha256:[0-9a-f]{64}$")) and
+       (.integration_commit|type)=="string" and
+       (.integration_commit|test("^[0-9a-f]{40}([0-9a-f]{24})?$"))) or
+     (.outcome=="NO_GO" and .verdict=="NO_GO" and .integration_commit==null and
+       .cleanup_evidence_path==null and .cleanup_evidence_hash==null) or
+     (.outcome=="RECOVERY_REQUIRED" and .verdict==null and .integration_commit==null and
+       .cleanup_evidence_path==null and .cleanup_evidence_hash==null))' \
+    "$result" >/dev/null || return 1
+  expected=$(jq -r .expected_base "$result")
+  git -C "$repo" cat-file -e "$expected^{commit}" 2>/dev/null || return 1
+  while IFS=$'\t' read -r name commit; do
+    git -C "$repo" cat-file -e "$commit^{commit}" 2>/dev/null || return 1
+  done < <(jq -r '.lane_commits[] | [.name,.commit] | @tsv' "$result")
+  if [ "$(jq -r .outcome "$result")" = GO ]; then
+    cleanup=$(jq -r .cleanup_evidence_path "$result")
+    [ "$cleanup" = "${result%.json}.cleanup.json" ] && [ -f "$cleanup" ] && [ ! -L "$cleanup" ] && \
+      [ "$(polylane_mode_of "$cleanup")" = 400 ] && \
+      [ "$(polylane_sha256 "$cleanup")" = "$(jq -r .cleanup_evidence_hash "$result")" ] || return 1
+    integration=$(jq -r .integration_commit "$result")
+    jq -e --arg run "$run" --arg integration "$integration" '
+      keys==["cleanup_complete","integration_commit","lane_branches_absent",
+        "lane_worktrees_absent","run_id","schema_version","session_absent"] and
+      .schema_version==1 and .run_id==$run and .integration_commit==$integration and
+      .cleanup_complete==true and .lane_worktrees_absent==true and
+      .lane_branches_absent==true and .session_absent==true' "$cleanup" >/dev/null || return 1
+    git -C "$repo" cat-file -e "$integration^{commit}" 2>/dev/null || return 1
+    git -C "$repo" merge-base --is-ancestor "$expected" "$integration" || return 1
+    while IFS=$'\t' read -r name commit; do
+      git -C "$repo" merge-base --is-ancestor "$commit" "$integration" || return 1
+    done < <(jq -r '.lane_commits[] | [.name,.commit] | @tsv' "$result")
+  fi
+}
+
+polylane_write_cycle_result() {
+  local runtime=$1 manifest=$2 outcome=$3 verdict=$4 base_ref=$5 expected_base=$6
+  local lane_commits=$7 integration_commit=$8 run result result_tmp manifest_hash result_dir
+  local cleanup_path="" cleanup_hash=""
+  local claim generation attempt expected_name
+  run=$(jq -er '.run_id | select(type=="string" and length>0)' "$manifest") || return 1
+  [ -d "$runtime" ] && [ ! -L "$runtime" ] && [ -f "$manifest" ] && [ ! -L "$manifest" ] || return 1
+  result_dir="$runtime/cycle-results"; polylane_safe_mkdirs "$result_dir" 0700 || return 1
+  [ -d "$result_dir" ] && [ ! -L "$result_dir" ] || return 1
+  result=${POLYLANE_CYCLE_RESULT_RECEIPT:-}; [ -n "$result" ] || return 1
+  claim=${POLYLANE_CLAIM_TOKEN:-}; generation=${POLYLANE_RUNNER_GENERATION:-}
+  attempt=${POLYLANE_ATTEMPT:-}
+  case "$claim" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac
+  case "$generation:$attempt" in *[!0-9:]*|:*|*:) return 1 ;; esac
+  expected_name="$run.$claim.g$generation.a$attempt.json"
+  [ "$(basename "$result")" = "$expected_name" ] || return 1
+  [ "$(dirname "$result")" = "$result_dir" ] || return 1
+  [ "$(cd "$(dirname "$result")" && pwd -P)/$(basename "$result")" = "$result" ] || return 1
+  case "$result" in "$result_dir/"*) : ;; *) return 1 ;; esac
+  manifest_hash=$(polylane_sha256 "$manifest") || return 1
+  jq -e 'type=="array" and all(.[]; type=="object" and keys==["commit","name"] and
+    (.name|type)=="string" and (.name|length)>0 and
+    (.commit|type)=="string" and (.commit|length)>0)' <<<"$lane_commits" >/dev/null || return 1
+  case "$outcome:$verdict:$integration_commit" in
+    GO:GO:?*) : ;; NO_GO:NO_GO:) : ;; RECOVERY_REQUIRED::) : ;; *) return 1 ;; esac
+  if [ "$outcome" = GO ]; then
+    cleanup_path=${POLYLANE_CLEANUP_EVIDENCE:-}
+    [ "$cleanup_path" = "${result%.json}.cleanup.json" ] && [ -f "$cleanup_path" ] && \
+      [ ! -L "$cleanup_path" ] && [ "$(polylane_mode_of "$cleanup_path")" = 400 ] || return 1
+    cleanup_hash=$(polylane_sha256 "$cleanup_path") || return 1
+  fi
+  result_tmp="$result.tmp.$$"
+  [ ! -e "$result_tmp" ] && [ ! -L "$result_tmp" ] && \
+    [ ! -e "$result" ] && [ ! -L "$result" ] || return 1
+  ( set -o pipefail; jq -nS --arg run "$run" --arg manifest_hash "$manifest_hash" \
+    --arg outcome "$outcome" --arg verdict "$verdict" --arg base_ref "$base_ref" \
+    --arg expected_base "$expected_base" --argjson lanes "$lane_commits" \
+    --arg integration "$integration_commit" --arg cleanup_path "$cleanup_path" \
+    --arg cleanup_hash "$cleanup_hash" \
+    '{schema_version:2,run_id:$run,manifest_hash:$manifest_hash,outcome:$outcome,
+      verdict:(if $verdict=="" then null else $verdict end),base_ref:$base_ref,
+      expected_base:$expected_base,lane_commits:$lanes,
+      integration_commit:(if $integration=="" then null else $integration end),
+      cleanup_evidence_path:(if $cleanup_path=="" then null else $cleanup_path end),
+      cleanup_evidence_hash:(if $cleanup_hash=="" then null else $cleanup_hash end)}' \
+    | polylane_private_from_stdin "$result_tmp" 0400 ) || return 1
+  polylane_publish_immutable "$result_tmp" "$result" || return 1
+  polylane_validate_cycle_result "$result" "$manifest" \
+    "${POLYLANE_REPO_ROOT:?repository root required}"
+}
+
+polylane_latest_error_class() {
+  local agent=$1 directory=$2 artifact class best=none best_rank=0 rank
+  for artifact in "$directory"/*.json; do
+    [ -f "$artifact" ] || continue
+    class=$(polylane_agent_error_class "$agent" "$artifact") || continue
+    case "$class" in transient) rank=1 ;; rate_limit) rank=2 ;; invalid_model) rank=3 ;;
+      user_action) rank=4 ;; *) rank=0 ;; esac
+    if [ "$rank" -gt "$best_rank" ]; then best=$class; best_rank=$rank; fi
+  done
+  printf '%s' "$best"
+}
+
+polylane_validate_attempt_identity() {
+  local runtime=$1 manifest=$2 state=${3:-planned} run receipt owner attempt_dir error_dir
+  case "$runtime:$manifest" in /*:/*) : ;; *) return 1 ;; esac
+  polylane_fs validate-dir "$(dirname "$manifest")" || return 1
+  polylane_fs validate-prefix "$runtime/cycle-results" || return 1
+  polylane_fs validate-prefix "$runtime/attempts" || return 1
+  polylane_fs validate-prefix "$runtime/agent-errors" || return 1
+  run=$(jq -er '.run_id|select(type=="string" and test("^[A-Za-z0-9._-]+$"))' "$manifest") || return 1
+  [ "$run" = "${POLYLANE_CYCLE_RUN_ID:-}" ] || return 1
+  case "${POLYLANE_CLAIM_TOKEN:-}" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac
+  case "${POLYLANE_RUNNER_GENERATION:-}:${POLYLANE_ATTEMPT:-}" in
+    *[!0-9:]*|:*|*:|0:*|*:0) return 1 ;;
+  esac
+  receipt="$runtime/cycle-results/$run.$POLYLANE_CLAIM_TOKEN.g$POLYLANE_RUNNER_GENERATION.a$POLYLANE_ATTEMPT.json"
+  [ "${POLYLANE_CYCLE_RESULT_RECEIPT:-}" = "$receipt" ] || return 1
+  [ ! -L "$receipt" ] && [ ! -L "${receipt%.json}.owner.json" ] || return 1
+  owner=${receipt%.json}.owner.json
+  attempt_dir="$runtime/attempts/$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION/a$POLYLANE_ATTEMPT"
+  error_dir="$runtime/agent-errors/$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION/a$POLYLANE_ATTEMPT"
+  if [ "$state" = planned ]; then
+    [ ! -e "$receipt" ] && [ ! -L "$receipt" ] && [ ! -e "$owner" ] && [ ! -L "$owner" ] && \
+      [ ! -e "$attempt_dir" ] && [ ! -L "$attempt_dir" ] && \
+      [ ! -e "$error_dir" ] && [ ! -L "$error_dir" ]
+    return
+  fi
+  polylane_fs validate-dir "$attempt_dir" && polylane_fs validate-dir "$error_dir" || return 1
+  [ -f "$owner" ] && [ ! -L "$owner" ] && [ "$(polylane_mode_of "$owner")" = 400 ] || return 1
+  jq -e --arg run "$run" --arg claim "$POLYLANE_CLAIM_TOKEN" \
+    --argjson generation "$POLYLANE_RUNNER_GENERATION" --argjson attempt "$POLYLANE_ATTEMPT" '
+      keys==["attempt","claim_token","run_id","runner_generation"] and
+      .run_id==$run and .claim_token==$claim and .runner_generation==$generation and
+      .attempt==$attempt' "$owner" >/dev/null
+}
+
+polylane_full_preflight() {
+  local manifest=$1 runtime=$2 identity_state=${3:?preflight identity state required}
+  local worktree_state=${4:-fresh}
+  local dependency selected cli template shell repo min_kb available loop session session_id
+  local prompt worktree branch token attempt_state repo_common lane_common lane_branch
+  case "$identity_state" in planned|allocated) attempt_state=$identity_state ;; *) return 2 ;; esac
+  case "$worktree_state" in fresh|owned-retry) : ;; *) return 2 ;; esac
+  [ "$worktree_state" != owned-retry ] || [ "$identity_state" = planned ] || return 2
+  [ -f "$manifest" ] && [ ! -L "$manifest" ] && jq empty "$manifest" 2>/dev/null || return 2
+  for dependency in awk basename chmod cksum cp date df dirname git grep head jq ln mkdir od \
+    ps python3 readlink rm sleep stat tmux tr uname wc; do
+    command -v "$dependency" >/dev/null 2>&1 || return 2
+  done
+  command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || return 2
+  [ -f "$POLYLANE_FS_HELPER" ] && [ ! -L "$POLYLANE_FS_HELPER" ] || return 2
+  python3 "$POLYLANE_FS_HELPER" validate-prefix / >/dev/null 2>&1 || return 2
+  polylane_fs validate-dir "$(dirname "$manifest")" || return 2
+  jq -e '
+    def ident: type=="string" and test("^[A-Za-z0-9._-]+$");
+    def actor: type=="object" and (.name|ident) and
+      (.model|type)=="string" and (.model|length)>0 and
+      (.effort|type)=="string" and (.effort|length)>0 and
+      (.branch|type)=="string" and (.branch|length)>0 and
+      (.worktree|type)=="string" and (.worktree|startswith("/")) and
+      (.prompt_file|type)=="string" and (.prompt_file|startswith("/"));
+    type=="object" and (.run_id|ident) and (.agent|type)=="string" and
+    (.loop_id|ident) and (.cycle|type)=="number" and .cycle>=1 and .cycle==floor and
+    (.base|type)=="string" and (.base|length)>0 and
+    (.lanes|type)=="array" and (.lanes|length)>0 and all(.lanes[]; actor and
+      (.own_globs|type)=="array" and (.own_globs|length)>0 and
+      all(.own_globs[]; type=="string" and length>0)) and (.integrator|actor) and
+    ([.lanes[].name,.integrator.name]|length)==([.lanes[].name,.integrator.name]|unique|length) and
+    ([.lanes[].branch,.integrator.branch]|length)==([.lanes[].branch,.integrator.branch]|unique|length) and
+    ([.lanes[].worktree,.integrator.worktree]|length)==([.lanes[].worktree,.integrator.worktree]|unique|length) and
+    ([.lanes[].prompt_file,.integrator.prompt_file]|length)==
+      ([.lanes[].prompt_file,.integrator.prompt_file]|unique|length)' \
+    "$manifest" >/dev/null || return 2
+  selected=$(polylane_agent_from_manifest "$manifest") || return 2
+  cli=$(polylane_agent_cli "$selected") || return 2
+  [ "$cli" = custom ] || command -v "$cli" >/dev/null 2>&1 || return 2
+  template=$(polylane_agent_template "$selected") || return 2
+  for token in '{model}' '{prompt}' '{effort}'; do case "$template" in *"$token"*) : ;; *) return 2 ;; esac; done
+  [ "$selected" != codex ] && [ "$selected" != gpt ] && [ "$selected" != openai ] || \
+    case "$template" in *'{error_artifact}'*) : ;; *) return 2 ;; esac
+  shell=$(polylane_agent_shell "$selected") || return 2
+  case "$shell" in /*) : ;; *) return 2 ;; esac
+  [ -f "$shell" ] && [ ! -L "$shell" ] && [ -x "$shell" ] || return 2
+  repo=$(git -C "$(dirname "$manifest")" rev-parse --show-toplevel 2>/dev/null) || return 2
+  git -C "$repo" rev-parse --verify HEAD^{commit} >/dev/null 2>&1 || return 2
+  git -C "$repo" rev-parse --verify "$(jq -r .base "$manifest")^{commit}" >/dev/null 2>&1 || return 2
+  while IFS= read -r prompt; do
+    case "$prompt" in /*) : ;; *) return 2 ;; esac
+    polylane_fs validate-file "$prompt" && [ -s "$prompt" ] || return 2
+  done < <(jq -r '.lanes[].prompt_file, .integrator.prompt_file' "$manifest")
+  while IFS=$'\t' read -r branch worktree; do
+    case "$branch" in ''|*[!A-Za-z0-9._/-]*|/*|*..*) return 2 ;; esac
+    case "$worktree" in /*) : ;; *) return 2 ;; esac
+    case "$worktree" in "$repo"|"$repo/.git"|"$repo/.git/"*|"$runtime"|"$runtime/"*) return 2 ;; esac
+    polylane_fs validate-prefix "$worktree" || return 2
+    if [ -e "$worktree" ] || [ -L "$worktree" ]; then
+      { [ "$identity_state" = allocated ] || [ "$worktree_state" = owned-retry ]; } && \
+        [ -d "$worktree" ] && [ ! -L "$worktree" ] || return 2
+      repo_common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir) || return 2
+      lane_common=$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir) || return 2
+      repo_common=$(cd "$repo_common" && pwd -P) || return 2
+      lane_common=$(cd "$lane_common" && pwd -P) || return 2
+      [ "$repo_common" = "$lane_common" ] || return 2
+      lane_branch=$(git -C "$worktree" symbolic-ref --quiet --short HEAD) || return 2
+      [ "$lane_branch" = "$branch" ] || return 2
+    fi
+  done < <(jq -r '.lanes[],.integrator | [.branch,.worktree] | @tsv' "$manifest")
+  min_kb=${POLYLANE_MIN_DISK_KB:-1048576}; case "$min_kb" in ''|*[!0-9]*) return 2 ;; esac
+  available=$(df -Pk "$repo" | awk 'NR==2 {print $4}')
+  case "$available" in ''|*[!0-9]*) return 2 ;; esac
+  [ "$available" -ge "$min_kb" ] || return 2
+  polylane_validate_attempt_identity "$runtime" "$manifest" "$attempt_state" || return 2
+  loop=$(jq -r .loop_id "$manifest"); session=${POLYLANE_SESSION:-polylane-$loop}
+  [ "$session" = "polylane-$loop" ] || return 2
+  if tmux has-session -t "=$session" 2>/dev/null; then
+    session_id=$(tmux display-message -p -t "=$session" '#{session_id}') || return 2
+    [ -n "$session_id" ] && [ "$(tmux display-message -p -t "$session_id" '#S')" = "$session" ] && \
+      [ "$(tmux display-message -p -t "$session_id" '#{session_id}')" = "$session_id" ] && \
+      [ "$(tmux show-options -qv -t "$session_id" @polylane_run_id)" = "$POLYLANE_CYCLE_RUN_ID" ] && \
+      [ "$(tmux show-options -qv -t "$session_id" @polylane_loop_id)" = "$loop" ] && \
+      [ "$(tmux show-options -qv -t "$session_id" @polylane_claim_token)" = "$POLYLANE_CLAIM_TOKEN" ] && \
+      [ "$(tmux show-options -qv -t "$session_id" @polylane_runner_generation)" = \
+        "$POLYLANE_RUNNER_GENERATION" ] || return 2
+    [ "$(tmux display-message -p -t "$session_id" '#S')" = "$session" ] && \
+      [ "$(tmux display-message -p -t "$session_id" '#{session_id}')" = "$session_id" ] || return 2
+  fi
+}
+
+polylane_next_number() {
+  local root=$1 prefix=$2 maximum=0 entry value
+  if [ -e "$root" ] || [ -L "$root" ]; then
+    polylane_fs validate-dir "$root" || return 1
+    for entry in "$root"/"$prefix"*; do
+      [ -e "$entry" ] || [ -L "$entry" ] || continue
+      polylane_fs validate-dir "$entry" || return 1
+      value=${entry##*/$prefix}; case "$value" in ''|*[!0-9]*|0) return 1 ;; esac
+      [ "$value" -le "$maximum" ] || maximum=$value
+    done
+  fi
+  printf '%s\n' "$((maximum + 1))"
+}
+
+polylane_plan_direct_attempt() {
+  local runtime=$1 manifest=$2 run generation receipt attempt_dir error_dir
+  run=$(jq -er '.run_id|select(type=="string" and test("^[A-Za-z0-9._-]+$"))' "$manifest") || return 1
+  POLYLANE_CYCLE_RUN_ID=$run; POLYLANE_CLAIM_TOKEN="direct-$run"
+  generation=$(polylane_next_number "$runtime/attempts/$POLYLANE_CLAIM_TOKEN" g) || return 1
+  while :; do
+    receipt="$runtime/cycle-results/$run.$POLYLANE_CLAIM_TOKEN.g$generation.a1.json"
+    attempt_dir="$runtime/attempts/$POLYLANE_CLAIM_TOKEN/g$generation/a1"
+    error_dir="$runtime/agent-errors/$POLYLANE_CLAIM_TOKEN/g$generation/a1"
+    if [ -e "$receipt" ] || [ -L "$receipt" ] || [ -e "${receipt%.json}.owner.json" ] || \
+       [ -L "${receipt%.json}.owner.json" ] || [ -e "$attempt_dir" ] || [ -L "$attempt_dir" ] || \
+       [ -e "$error_dir" ] || [ -L "$error_dir" ]; then generation=$((generation + 1)); continue; fi
+    break
+  done
+  POLYLANE_RUNNER_GENERATION=$generation; POLYLANE_ATTEMPT=1
+  POLYLANE_CYCLE_RESULT_RECEIPT=$receipt
+  export POLYLANE_CYCLE_RUN_ID POLYLANE_CLAIM_TOKEN POLYLANE_RUNNER_GENERATION \
+    POLYLANE_ATTEMPT POLYLANE_CYCLE_RESULT_RECEIPT
+  polylane_validate_attempt_identity "$runtime" "$manifest" planned
+}
+
+polylane_plan_retry_attempt() {
+  local runtime=$1 manifest=$2 next receipt attempt_dir error_dir
+  next=$(polylane_next_number \
+    "$runtime/attempts/$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION" a) || return 1
+  while :; do
+    receipt="$runtime/cycle-results/$POLYLANE_CYCLE_RUN_ID.$POLYLANE_CLAIM_TOKEN.g$POLYLANE_RUNNER_GENERATION.a$next.json"
+    attempt_dir="$runtime/attempts/$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION/a$next"
+    error_dir="$runtime/agent-errors/$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION/a$next"
+    if [ -e "$receipt" ] || [ -L "$receipt" ] || [ -e "${receipt%.json}.owner.json" ] || \
+       [ -L "${receipt%.json}.owner.json" ] || [ -e "$attempt_dir" ] || [ -L "$attempt_dir" ] || \
+       [ -e "$error_dir" ] || [ -L "$error_dir" ]; then next=$((next + 1)); continue; fi
+    break
+  done
+  POLYLANE_ATTEMPT=$next
+  POLYLANE_CYCLE_RESULT_RECEIPT=$receipt
+  export POLYLANE_ATTEMPT POLYLANE_CYCLE_RESULT_RECEIPT
+  polylane_validate_attempt_identity "$runtime" "$manifest" planned
+}
+
+polylane_allocate_attempt() {
+  local runtime=$1 manifest=$2 attempt_parent error_parent attempt_dir error_dir receipt owner
+  local owner_private attempt_owner_private payload
+  polylane_validate_attempt_identity "$runtime" "$manifest" planned || return 1
+  attempt_parent="$runtime/attempts/$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION"
+  error_parent="$runtime/agent-errors/$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION"
+  polylane_safe_mkdirs "$runtime/cycle-results" 0700 && \
+    polylane_safe_mkdirs "$attempt_parent" 0700 && polylane_safe_mkdirs "$error_parent" 0700 || return 1
+  attempt_dir="$attempt_parent/a$POLYLANE_ATTEMPT"; error_dir="$error_parent/a$POLYLANE_ATTEMPT"
+  polylane_safe_mkdir_exclusive "$attempt_dir" 0700 || return 6
+  polylane_safe_mkdir_exclusive "$error_dir" 0700 || return 6
+  receipt=$POLYLANE_CYCLE_RESULT_RECEIPT; owner=${receipt%.json}.owner.json
+  payload=$(jq -cnS --arg run "$POLYLANE_CYCLE_RUN_ID" --arg claim "$POLYLANE_CLAIM_TOKEN" \
+    --argjson generation "$POLYLANE_RUNNER_GENERATION" --argjson attempt "$POLYLANE_ATTEMPT" \
+    '{attempt:$attempt,claim_token:$claim,run_id:$run,runner_generation:$generation}') || return 1
+  owner_private="$owner.private.$$-${RANDOM:-0}"
+  printf '%s\n' "$payload" | polylane_private_from_stdin "$owner_private" 0400 || return 1
+  polylane_publish_private "$owner_private" "$owner" || return 1
+  attempt_owner_private="$attempt_dir/owner.json.private.$$-${RANDOM:-0}"
+  printf '%s\n' "$payload" | polylane_private_from_stdin "$attempt_owner_private" 0400 || return 1
+  polylane_publish_private "$attempt_owner_private" "$attempt_dir/owner.json" || return 1
+  polylane_validate_attempt_identity "$runtime" "$manifest" allocated
+}
+
```

Expected: `bash -n core/scripts/polylane-agent.sh` exits 0.

- [ ] **Step 5: Replace both adapter classifiers with complete platform-local tables (5 minutes)**

Make this anchored edit to the Codex adapter:

```diff
diff --git a/codex/scripts/polylane-codex-agent.sh b/codex/scripts/polylane-codex-agent.sh
--- a/codex/scripts/polylane-codex-agent.sh
+++ b/codex/scripts/polylane-codex-agent.sh
@@
polylane_adapter_error_class() {
-  printf none
+  local artifact=$2 kind events stderr expected_events expected_stderr
+  [ -f "$artifact" ] && [ ! -L "$artifact" ] || { printf none; return; }
+  kind=$(jq -er '
+    select(.schema_version==2 and .provider=="codex" and
+      (.events_path|type=="string" and startswith("/")) and
+      (.stderr_path|type=="string" and startswith("/")) and
+      (.events_hash|test("^sha256:[0-9a-f]{64}$")) and
+      (.stderr_hash|test("^sha256:[0-9a-f]{64}$")) and
+      (.terminal_type=="turn.completed" or .terminal_type=="turn.failed" or
+       .terminal_type=="capture.failed") and
+      (.process_exit|type=="number")) |
+    .kind | select(.=="transient" or .=="rate_limit" or .=="invalid_model" or .=="user_action")' \
+    "$artifact" 2>/dev/null) || { printf none; return; }
+  events=$(jq -r .events_path "$artifact"); stderr=$(jq -r .stderr_path "$artifact")
+  expected_events=$(jq -r .events_hash "$artifact"); expected_stderr=$(jq -r .stderr_hash "$artifact")
+  [ -f "$events" ] && [ ! -L "$events" ] && [ -f "$stderr" ] && [ ! -L "$stderr" ] &&
+    [ "sha256:$(polylane_codex_sha256 "$events")" = "$expected_events" ] &&
+    [ "sha256:$(polylane_codex_sha256 "$stderr")" = "$expected_stderr" ] || {
+      printf none; return;
+    }
+  printf '%s' "$kind"
 }
```

Make this anchored edit to the Claude adapter:

```diff
diff --git a/claude-code/scripts/polylane-claude-agent.sh b/claude-code/scripts/polylane-claude-agent.sh
--- a/claude-code/scripts/polylane-claude-agent.sh
+++ b/claude-code/scripts/polylane-claude-agent.sh
@@
-polylane_adapter_error_class() { printf none; }
+polylane_adapter_error_class() {
+  local artifact=$2 kind
+  [ -f "$artifact" ] || { printf none; return; }
+  kind=$(jq -er '
+    select(.schema_version==2 and .provider=="claude") |
+    .kind | select(.=="transient" or .=="rate_limit" or .=="invalid_model" or .=="user_action")' \
+    "$artifact" 2>/dev/null) || { printf none; return; }
+  printf '%s' "$kind"
+}
```

Expected: both adapters pass `bash -n`; only versioned, provider-matching structured
artifacts whose immutable event and stderr bytes still match their SHA-256 fields classify;
connector-auth/unknown kinds, tampered evidence, and arbitrary prose return `none`.

- [ ] **Step 6: Make the one-cycle runner write every terminal cycle outcome atomically (5 minutes)**

Make these anchored edits to `core/scripts/polylane-run.sh`:

```diff
diff --git a/core/scripts/polylane-run.sh b/core/scripts/polylane-run.sh
--- a/core/scripts/polylane-run.sh
+++ b/core/scripts/polylane-run.sh
@@
   RUN_ID=$(jq -r '.run_id // ""' "$MANIFEST")
+  LOOP_ID=$(jq -r '.loop_id // ""' "$MANIFEST")
+  CYCLE=$(jq -r '.cycle // 0' "$MANIFEST")
+  TMUX_SESSION_NAME=${POLYLANE_SESSION:-polylane-$LOOP_ID}
+  TMUX_SESSION=$TMUX_SESSION_NAME
@@
   REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
+  BASE_BEFORE=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf '')
@@
 preflight() {
+  local runtime=${POLYLANE_RUNTIME_DIR:?launcher must bind runtime before runner preflight}
+  polylane_full_preflight "$MANIFEST" "$runtime" allocated || {
+    echo "polylane-run: full immutable preflight failed" >&2; exit 2;
+  }
+  polylane_validate_attempt_identity "$runtime" "$MANIFEST" allocated || {
+    echo "polylane-run: attempt owner/receipt binding is not allocated" >&2; exit 2;
+  }
   local missing=() d selected cli
@@
+capture_cycle_result_inputs() {
+  local outcome=$1 name branch worktree commit branch_commit lane_common repo_common
+  CYCLE_RESULT_OUTCOME=$outcome; CYCLE_RESULT_LANES='[]'
+  repo_common=$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir) || return 1
+  repo_common=$(cd "$repo_common" && pwd -P) || return 1
+  while IFS=$'\t' read -r name branch worktree; do
+    [ -n "$name" ] && [ -n "$worktree" ] && [ -d "$worktree" ] && [ ! -L "$worktree" ] || return 1
+    lane_common=$(git -C "$worktree" rev-parse --path-format=absolute --git-common-dir) || return 1
+    lane_common=$(cd "$lane_common" && pwd -P) || return 1
+    [ "$lane_common" = "$repo_common" ] || return 1
+    commit=$(git -C "$worktree" rev-parse HEAD) || return 1
+    [[ "$commit" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || return 1
+    [ -z "$branch" ] || {
+      branch_commit=$(git -C "$REPO_ROOT" rev-parse "$branch") || return 1
+      [ "$branch_commit" = "$commit" ] || return 1
+    }
+    CYCLE_RESULT_LANES=$(jq -cn --argjson prior "$CYCLE_RESULT_LANES" \
+      --arg name "$name" --arg commit "$commit" '$prior + [{name:$name,commit:$commit}]')
+  done < <(jq -r '.lanes[] | [.name, (.branch // ""), (.worktree // "")] | @tsv' "$MANIFEST")
+  [ "$(jq -r 'length' <<<"$CYCLE_RESULT_LANES")" = "$(jq -r '.lanes|length' "$MANIFEST")" ] || return 1
+  CYCLE_RESULT_INTEGRATION=""
+  if [ "$outcome" = GO ]; then
+    CYCLE_RESULT_INTEGRATION=$(git -C "$REPO_ROOT" rev-parse HEAD) || return 1
+    git -C "$REPO_ROOT" merge-base --is-ancestor "$BASE_BEFORE" "$CYCLE_RESULT_INTEGRATION" || return 1
+  fi
+}
+
+seal_cleanup_evidence() {
+  local evidence private name branch worktree
+  [ "${CYCLE_RESULT_OUTCOME:-}" = GO ] && [ -n "${CYCLE_RESULT_INTEGRATION:-}" ] || return 1
+  while IFS=$'\t' read -r name branch worktree; do
+    [ ! -e "$worktree" ] && [ ! -L "$worktree" ] || return 1
+    [ -z "$branch" ] || ! git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$branch" || return 1
+  done < <(jq -r '.lanes[] | [.name, (.branch // ""), (.worktree // "")] | @tsv' "$MANIFEST")
+  [ -n "${TMUX_SESSION_ID:-}" ] && ! tmux has-session -t "$TMUX_SESSION_ID" 2>/dev/null || return 1
+  [ -n "${TMUX_FENCED_PROCESS_RECORDS:-}" ] && \
+    polylane_process_records_absent "$TMUX_FENCED_PROCESS_RECORDS" || return 1
+  evidence="${POLYLANE_CYCLE_RESULT_RECEIPT%.json}.cleanup.json"
+  private="$evidence.private.$$-${RANDOM:-0}"
+  ( set -o pipefail; jq -nS --arg run "$RUN_ID" --arg integration "$CYCLE_RESULT_INTEGRATION" '
+    {schema_version:1,run_id:$run,integration_commit:$integration,cleanup_complete:true,
+      lane_worktrees_absent:true,lane_branches_absent:true,session_absent:true}' |
+    polylane_private_from_stdin "$private" 0400 ) || return 1
+  polylane_publish_private "$private" "$evidence" || return 1
+  POLYLANE_CLEANUP_EVIDENCE=$evidence; export POLYLANE_CLEANUP_EVIDENCE
+}
+
+polylane_process_start_token() {
+  polylane_fs process-start-token "$1" 2>/dev/null
+}
+
+polylane_process_identity_alive() {
+  kill -0 "$1" 2>/dev/null && \
+    [ "$(polylane_process_start_token "$1" 2>/dev/null || true)" = "$2" ]
+}
+
+polylane_capture_process_exclusions() {
+  local caller=$1 snapshot chain pid pgid token verify
+  snapshot=$(ps -axo pid=,ppid=,pgid=) || return 1
+  chain=$(awk -v caller="$caller" '
+    { parent[$1]=$2; group[$1]=$3 }
+    END {
+      current=caller
+      while(current~/^[0-9]+$/ && (current in parent) && !seen[current]++) {
+        print current "|" group[current]
+        if(current==1) break
+        current=parent[current]
+      }
+    }' <<<"$snapshot") || return 1
+  [ -n "$chain" ] || return 1
+  while IFS='|' read -r pid pgid; do
+    case "$pid:$pgid" in *[!0-9:]*|:*) return 1 ;; esac
+    token=$(polylane_process_start_token "$pid") || return 1
+    verify=$(polylane_process_start_token "$pid") || return 1
+    [ "$verify" = "$token" ] || return 1
+    printf '%s|%s|%s\n' "$pid" "$pgid" "$token"
+  done <<<"$chain"
+  return 0
+}
+
+polylane_process_candidate_excluded() {
+  local pid=$1 pgid=$2 excluded_pid _excluded_group _excluded_token
+  case ",${POLYLANE_PROCESS_EXCLUSION_PGIDS:-}," in *",$pgid,"*) return 0 ;; esac
+  while IFS='|' read -r excluded_pid _excluded_group _excluded_token; do
+    [ -n "$excluded_pid" ] || continue
+    [ "$pid" != "$excluded_pid" ] || return 0
+  done <<<"${POLYLANE_PROCESS_EXCLUSION_RECORDS:-}"
+  return 1
+}
+
+polylane_filter_process_records() {
+  local records=$1 pid pgid token
+  while IFS='|' read -r pid pgid token; do
+    [ -n "$pid" ] || continue
+    case "$pid:$pgid:$token" in *[!0-9:]*|::*|*::*) return 1 ;; esac
+    polylane_process_candidate_excluded "$pid" "$pgid" && continue
+    printf '%s|%s|%s\n' "$pid" "$pgid" "$token"
+  done <<<"$records"
+  return 0
+}
+
+polylane_fence_observe_phase() {
+  local phase=$1 fd=${POLYLANE_FENCE_PHASE_FD:-}
+  [ -n "$fd" ] || return 0
+  case "$fd" in *[!0-9]*|'') return 1 ;; esac
+  printf '%s\n' "$phase" >&"$fd"
+}
+
+polylane_capture_descendant_records() {
+  local roots=$1 snapshot pid pgid token
+  snapshot=$(ps -axo pid=,ppid=,pgid=) || return 1
+  if [ "${POLYLANE_PROCESS_TEST_BOUNDARY:-}" = after-descendant-snapshot ]; then
+    [ -n "${POLYLANE_PROCESS_TEST_BOUNDARY_HOOK:-}" ] || return 1
+    "$POLYLANE_PROCESS_TEST_BOUNDARY_HOOK" after-descendant-snapshot "$roots" || return 1
+  fi
+  awk -v roots="$roots" '
+    BEGIN { n=split(roots,a,","); for(i=1;i<=n;i++) if(a[i]~/^[0-9]+$/) owned[a[i]]=1 }
+    { pid[NR]=$1; parent[NR]=$2; group[NR]=$3 }
+    END {
+      do { changed=0; for(i=1;i<=NR;i++)
+        if(owned[parent[i]] && !owned[pid[i]]) { owned[pid[i]]=1; changed=1 }
+      } while(changed)
+      for(i=1;i<=NR;i++) if(owned[pid[i]]) print pid[i] "|" group[i]
+    }' <<<"$snapshot" | while IFS='|' read -r pid pgid; do
+      polylane_process_candidate_excluded "$pid" "$pgid" && continue
+      token=$(polylane_process_start_token "$pid") || exit 1
+      printf '%s|%s|%s\n' "$pid" "$pgid" "$token"
+    done
+}
+
+polylane_process_records_absent() {
+  local records=$1 pid pgid token
+  while IFS='|' read -r pid pgid token; do
+    [ -n "$pid" ] || continue
+    polylane_process_identity_alive "$pid" "$token" && return 1
+  done <<<"$records"
+  return 0
+}
+
+polylane_signal_exact_records() {
+  local signal=$1 records=$2 pid _pgid token
+  while IFS='|' read -r pid _pgid token; do
+    [ -n "$pid" ] || continue
+    polylane_process_candidate_excluded "$pid" "$_pgid" && continue
+    polylane_process_identity_alive "$pid" "$token" || continue
+    kill -"$signal" "$pid" 2>/dev/null || return 1
+  done <<<"$records"
+  return 0
+}
+
+polylane_records_stopped() {
+  local records=$1 pid _pgid token state
+  while IFS='|' read -r pid _pgid token; do
+    [ -n "$pid" ] || continue
+    polylane_process_identity_alive "$pid" "$token" || return 1
+    state=$(ps -o state= -p "$pid" 2>/dev/null | tr -d '[:space:]') || return 1
+    case "$state" in T*) : ;; *) return 1 ;; esac
+  done <<<"$records"
+  return 0
+}
+
+polylane_records_quiesced() {
+  local records=$1 pid _pgid token state
+  while IFS='|' read -r pid _pgid token; do
+    [ -n "$pid" ] || continue
+    polylane_process_identity_alive "$pid" "$token" || continue
+    state=$(ps -o state= -p "$pid" 2>/dev/null | tr -d '[:space:]') || return 1
+    case "$state" in T*) : ;; *) return 1 ;; esac
+  done <<<"$records"
+  return 0
+}
+
+polylane_stabilize_descendants() {
+  local roots=$1 records=$2 require_stopped=${3:-1} refreshed verify i=0
+  while [ "$i" -lt 100 ]; do
+    if ! polylane_signal_exact_records STOP "$records"; then
+      polylane_signal_exact_records CONT "$records" || true; return 1
+    fi
+    if ! refreshed=$(polylane_capture_descendant_records "$roots") || [ -z "$refreshed" ]; then
+      polylane_signal_exact_records CONT "$records" || true; return 1
+    fi
+    if ! polylane_signal_exact_records STOP "$refreshed"; then
+      polylane_signal_exact_records CONT "$refreshed" || true; return 1
+    fi
+    records=$refreshed
+    sleep 0.02
+    if ! verify=$(polylane_capture_descendant_records "$roots") || [ -z "$verify" ]; then
+      polylane_signal_exact_records CONT "$records" || true; return 1
+    fi
+    if [ "$refreshed" = "$verify" ]; then
+      if [ "$require_stopped" != 1 ] || polylane_records_stopped "$verify"; then
+        printf '%s\n' "$verify"; return 0
+      fi
+    fi
+    records=$verify; i=$((i + 1))
+  done
+  polylane_signal_exact_records CONT "$records" || true
+  return 1
+}
+
+polylane_merge_process_records() {
+  local merged
+  merged=$(awk -F'|' 'NF==3 && !seen[$1 "|" $3]++' <<<"$1
+$2") || return 1
+  polylane_filter_process_records "$merged"
+}
+
+polylane_new_process_records() {
+  local known=$1 discovered=$2 row
+  while IFS= read -r row; do
+    [ -n "$row" ] || continue
+    [ -n "$(polylane_filter_process_records "$row")" ] || continue
+    printf '%s\n' "$known" | grep -Fqx "$row" || printf '%s\n' "$row"
+  done <<<"$discovered"
+  return 0
+}
+
+polylane_capture_owned_inventory() {
+  local records=$1 snapshot roots="" groups pid pgid token
+  while IFS='|' read -r pid _pgid token; do
+    [ -n "$pid" ] || continue
+    polylane_process_identity_alive "$pid" "$token" || continue
+    roots=${roots:+$roots,}$pid
+  done <<<"$records"
+  groups=$(awk -F'|' 'NF==3 && !seen[$2]++ {printf "%s%s", separator, $2; separator=","}' \
+    <<<"$records") || return 1
+  snapshot=$(ps -axo pid=,ppid=,pgid=) || return 1
+  awk -v roots="$roots" -v groups="$groups" '
+    BEGIN {
+      n=split(roots,a,","); for(i=1;i<=n;i++) if(a[i]~/^[0-9]+$/) root[a[i]]=1
+      n=split(groups,a,","); for(i=1;i<=n;i++) if(a[i]~/^[0-9]+$/) group_root[a[i]]=1
+    }
+    { pid[NR]=$1; parent[NR]=$2; group[NR]=$3
+      if(root[$1] || group_root[$3]) owned[$1]=1 }
+    END {
+      do { changed=0; for(i=1;i<=NR;i++)
+        if(owned[parent[i]] && !owned[pid[i]]) { owned[pid[i]]=1; changed=1 }
+      } while(changed)
+      for(i=1;i<=NR;i++) if(owned[pid[i]]) print pid[i] "|" group[i]
+    }' <<<"$snapshot" | while IFS='|' read -r pid pgid; do
+      polylane_process_candidate_excluded "$pid" "$pgid" && continue
+      if ! token=$(polylane_process_start_token "$pid"); then
+        kill -0 "$pid" 2>/dev/null && exit 1
+        continue
+      fi
+      printf '%s|%s|%s\n' "$pid" "$pgid" "$token"
+    done
+}
+
+polylane_signal_owned_records() {
+  local signal=$1 records=$2 pid pgid token groups members safe current _group
+  records=$(polylane_filter_process_records "$records") || return 1
+  groups=$(awk -F'|' '!seen[$2]++ {print $2}' <<<"$records")
+  while IFS= read -r pgid; do
+    [ -n "$pgid" ] || continue
+    polylane_process_candidate_excluded 0 "$pgid" && continue
+    current=$(ps -axo pid=,pgid= | awk -v group="$pgid" '$2==group {print $1}') || return 1
+    safe=1; members=0
+    while IFS= read -r pid; do
+      [ -n "$pid" ] || continue; members=$((members + 1))
+      polylane_process_candidate_excluded "$pid" "$pgid" && { safe=0; break; }
+      token=$(polylane_process_start_token "$pid") || { safe=0; break; }
+      printf '%s\n' "$records" | grep -Fqx "$pid|$pgid|$token" || { safe=0; break; }
+    done <<<"$current"
+    if [ "$safe" = 1 ] && [ "$members" -gt 0 ]; then
+      kill -"$signal" -- "-$pgid" 2>/dev/null || true
+    else
+      while IFS='|' read -r pid _group token; do
+        [ "$_group" = "$pgid" ] || continue
+        polylane_process_candidate_excluded "$pid" "$_group" && continue
+        polylane_process_identity_alive "$pid" "$token" || continue
+        kill -"$signal" "$pid" 2>/dev/null || true
+      done <<<"$records"
+    fi
+  done <<<"$groups"
+}
+
+fence_owned_tmux_session() {
+  local caller_pid exclusion_records exclusion_pgids
+  local id=${TMUX_SESSION_ID:-} pane_inventory row pane_pid roots="" records="" root_records=""
+  local pane_pgid pane_token refreshed frozen newly final_capture i _pane _group _token
+  caller_pid=$(/bin/sh -c 'printf "%s\n" "$PPID"') || return 1
+  case "$caller_pid" in ''|*[!0-9]*|0) return 1 ;; esac
+  exclusion_records=$(polylane_capture_process_exclusions "$caller_pid") || return 1
+  exclusion_pgids=$(awk -F'|' 'NF==3 && !seen[$2]++ {printf "%s%s", separator, $2; separator=","}' \
+    <<<"$exclusion_records") || return 1
+  [ -n "$exclusion_records" ] && [ -n "$exclusion_pgids" ] || return 1
+  local -r POLYLANE_PROCESS_EXCLUSION_RECORDS="$exclusion_records"
+  local -r POLYLANE_PROCESS_EXCLUSION_PGIDS="$exclusion_pgids"
+  export POLYLANE_PROCESS_EXCLUSION_RECORDS POLYLANE_PROCESS_EXCLUSION_PGIDS
+  TMUX_FENCE_EXCLUDED_PROCESS_RECORDS=$exclusion_records
+  TMUX_FENCE_EXCLUDED_PGIDS=$exclusion_pgids
+  export TMUX_FENCE_EXCLUDED_PROCESS_RECORDS TMUX_FENCE_EXCLUDED_PGIDS
+  [ -n "$id" ] && tmux has-session -t "$id" 2>/dev/null || return 1
+  owned_session_id_matches "$id" || return 1
+  pane_inventory=$(tmux list-panes -t "$id" \
+    -F '#{session_id}|#{pane_id}|#{pane_pid}' 2>/dev/null) || return 1
+  [ -n "$pane_inventory" ] || return 1
+  while IFS='|' read -r row _pane pane_pid; do
+    [ "$row" = "$id" ] || return 1
+    case "$pane_pid" in ''|*[!0-9]*|0) return 1 ;; esac
+    roots=${roots:+$roots,}$pane_pid
+  done <<<"$pane_inventory"
+  while IFS= read -r pane_pid; do
+    pane_pgid=$(ps -o pgid= -p "$pane_pid" 2>/dev/null | tr -d '[:space:]') || return 1
+    case "$pane_pgid" in ''|*[!0-9]*|0) return 1 ;; esac
+    pane_token=$(polylane_process_start_token "$pane_pid") || return 1
+    polylane_process_identity_alive "$pane_pid" "$pane_token" || return 1
+    polylane_process_candidate_excluded "$pane_pid" "$pane_pgid" && return 1
+    root_records=${root_records:+$root_records$'\n'}$pane_pid\|$pane_pgid\|$pane_token
+  done <<<"$(tr ',' '\n' <<<"$roots")"
+  # STOP authenticated pane roots before taking any descendant snapshot.
+  polylane_signal_exact_records STOP "$root_records" || return 1
+  # Repeatedly capture and STOP descendants until PID/PGID/birth-token membership is stable.
+  records=$(polylane_capture_descendant_records "$roots") || {
+    polylane_signal_exact_records CONT "$root_records" || true; return 1;
+  }
+  [ -n "$records" ] || {
+    polylane_signal_exact_records CONT "$root_records" || true; return 1;
+  }
+  while IFS= read -r pane_pid; do
+    printf '%s\n' "$records" | grep -Fqx "$pane_pid" || {
+      polylane_signal_exact_records CONT "$records" || true; return 1;
+    }
+  done <<<"$root_records"
+  # tmux may SIGCONT its foreground pane group, so this pre-kill pass proves membership;
+  # the second pass below proves stopped state after that tmux session no longer exists.
+  records=$(polylane_stabilize_descendants "$roots" "$records" 0) || return 1
+  if ! owned_session_id_matches "$id" || \
+     [ "$(tmux list-panes -t "$id" -F '#{session_id}|#{pane_id}|#{pane_pid}' 2>/dev/null)" != \
+       "$pane_inventory" ]; then
+    polylane_signal_exact_records CONT "$records" || true; return 1
+  fi
+  if ! tmux kill-session -t "$id" 2>/dev/null; then
+    polylane_signal_exact_records CONT "$records" || true; return 1
+  fi
+  polylane_signal_exact_records STOP "$records" || return 1
+  refreshed=$(polylane_capture_descendant_records "$roots") || return 1
+  if [ -n "$refreshed" ]; then
+    frozen=$(polylane_stabilize_descendants "$roots" "$refreshed" 1) || return 1
+    records=$(polylane_merge_process_records "$records" "$frozen")
+  fi
+  i=0; while [ "$i" -lt 100 ] && ! polylane_records_quiesced "$records"; do
+    polylane_signal_exact_records STOP "$records" || return 1
+    sleep 0.01; i=$((i + 1))
+  done
+  polylane_records_quiesced "$records" || return 1
+  polylane_signal_exact_records CONT "$records" || return 1
+  polylane_fence_observe_phase CONT || return 1
+  polylane_signal_exact_records TERM "$records" || return 1
+  polylane_fence_observe_phase TERM_GRACE || return 1
+  i=0; while [ "$i" -lt 100 ]; do
+    refreshed=$(polylane_capture_owned_inventory "$records") || return 1
+    if [ -n "$refreshed" ]; then
+      newly=$(polylane_new_process_records "$records" "$refreshed")
+      [ -z "$newly" ] || polylane_signal_exact_records STOP "$newly" || return 1
+      records=$(polylane_merge_process_records "$records" "$refreshed")
+    fi
+    polylane_process_records_absent "$records" && break
+    sleep 0.05; i=$((i + 1))
+  done
+  if ! polylane_process_records_absent "$records"; then
+    refreshed=$(polylane_capture_owned_inventory "$records") || return 1
+    [ -z "$refreshed" ] || records=$(polylane_merge_process_records "$records" "$refreshed")
+    polylane_fence_observe_phase KILL || return 1
+    polylane_signal_exact_records KILL "$records" || return 1
+    i=0; while [ "$i" -lt 100 ]; do
+      refreshed=$(polylane_capture_owned_inventory "$records") || return 1
+      if [ -n "$refreshed" ]; then
+        records=$(polylane_merge_process_records "$records" "$refreshed")
+        polylane_signal_exact_records KILL "$records" || return 1
+      fi
+      final_capture=$(polylane_capture_owned_inventory "$records") || return 1
+      if [ -z "$final_capture" ] && polylane_process_records_absent "$records"; then break; fi
+      [ -z "$final_capture" ] || records=$(polylane_merge_process_records "$records" "$final_capture")
+      sleep 0.05; i=$((i + 1))
+    done
+  fi
+  while IFS='|' read -r pane_pid _group _token; do wait "$pane_pid" 2>/dev/null || true; done <<<"$records"
+  final_capture=$(polylane_capture_owned_inventory "$records") || return 1
+  [ -z "$final_capture" ] || return 1
+  ! tmux has-session -t "$id" 2>/dev/null && \
+    polylane_process_records_absent "$records" || return 1
+  TMUX_FENCED_PROCESS_RECORDS=$records; export TMUX_FENCED_PROCESS_RECORDS
+  polylane_fence_observe_phase COMPLETE || return 1
+}
+
+publish_captured_cycle_result() {
+  local runtime verdict=""
+  runtime=${POLYLANE_RUNTIME_DIR:-$PROJECT_ROOT/.polylane/runtime}
+  [ -n "${CYCLE_RESULT_OUTCOME:-}" ] && [ -n "${CYCLE_RESULT_LANES:-}" ] || return 1
+  [ "$CYCLE_RESULT_OUTCOME" != GO ] || verdict=GO
+  [ "$CYCLE_RESULT_OUTCOME" != NO_GO ] || verdict=NO_GO
+  POLYLANE_REPO_ROOT=$REPO_ROOT; export POLYLANE_REPO_ROOT
+  polylane_write_cycle_result "$runtime" "$MANIFEST" "$CYCLE_RESULT_OUTCOME" "$verdict" \
+    "$(jq -r '.base' "$MANIFEST")" "$BASE_BEFORE" "$CYCLE_RESULT_LANES" \
+    "$CYCLE_RESULT_INTEGRATION"
+  polylane_validate_cycle_result "$POLYLANE_CYCLE_RESULT_RECEIPT" "$MANIFEST" "$REPO_ROOT"
+}
+
+# cleanup must never unlink or temporarily relocate Runtime's durable claim/receipt tree,
+# and it retains run.json until the supervisor has independently validated the receipt.
@@
-  safe_rm "$REPO_ROOT/.polylane"
+  [ -d "$REPO_ROOT/.polylane" ] && [ ! -L "$REPO_ROOT/.polylane" ] || return 1
+  [ "$(cd "$REPO_ROOT/.polylane" && pwd -P)" = "$REPO_ROOT/.polylane" ] || return 1
+  while IFS= read -r -d '' scratch; do safe_rm "$scratch"; done < <(
+    find "$REPO_ROOT/.polylane" -mindepth 1 -maxdepth 1 \
+      ! -name runtime ! -name run.json -print0
+  )
   # .polylane/ is scratch EXCEPT git-tracked files (e.g. SCHEMA.md); restore those
+
 main() {
@@
     write_report "HALTED" || true
+    capture_cycle_result_inputs RECOVERY_REQUIRED && publish_captured_cycle_result
     echo "Report written: $REPO_ROOT/docs/polylane-report.md"
-    exit 1
+    exit 75
@@
     write_report "HALTED" || true
+    capture_cycle_result_inputs RECOVERY_REQUIRED && publish_captured_cycle_result
@@
-    exit 1
+    exit 75
@@
       write_report "${VERDICT_RESULT:-GO}" || true
+      capture_cycle_result_inputs RECOVERY_REQUIRED && publish_captured_cycle_result
       echo "Promote failed — base intact, worktrees kept. See report." >&2
-      exit 1
+      exit 75
@@
     fi
+    capture_cycle_result_inputs GO || {
+      echo "polylane-run: cannot capture promoted commit provenance" >&2; exit 75;
+    }
     echo "== cleanup =="
-    cleanup
+    if ! fence_owned_tmux_session || ! cleanup; then
+      CYCLE_RESULT_OUTCOME=RECOVERY_REQUIRED; CYCLE_RESULT_INTEGRATION=""
+      publish_captured_cycle_result || true
+      echo "polylane-run: cleanup failed; GO is forbidden" >&2
+      exit 75
+    fi
+    if ! seal_cleanup_evidence; then
+      CYCLE_RESULT_OUTCOME=RECOVERY_REQUIRED; CYCLE_RESULT_INTEGRATION=""
+      publish_captured_cycle_result || true
+      echo "polylane-run: cleanup evidence could not be sealed; GO is forbidden" >&2
+      exit 75
+    fi
+    publish_captured_cycle_result || {
+      echo "polylane-run: cannot publish validated post-cleanup GO receipt" >&2; exit 75;
+    }
@@
   write_report "${VERDICT_RESULT:-UNKNOWN}" || true
+  # GO is published only after cleanup and its immutable evidence; NO_GO retains worktrees.
+  if [ "${VERDICT_RESULT:-}" != GO ]; then
+    capture_cycle_result_inputs NO_GO && publish_captured_cycle_result || exit 75
+  fi
```

Expected: `bash -n core/scripts/polylane-run.sh` exits 0; no result is inferred from a
report timestamp.

- [ ] **Step 7: Replace supervisor completion detection with nonce/schema validation (5 minutes)**

Make these anchored edits to `core/scripts/polylane-supervisor.sh`:

```diff
diff --git a/core/scripts/polylane-supervisor.sh b/core/scripts/polylane-supervisor.sh
--- a/core/scripts/polylane-supervisor.sh
+++ b/core/scripts/polylane-supervisor.sh
@@
 RUN_ID=$(jq -r '.run_id // ""' "$SUP_MANIFEST")
+LOOP_ID=$(jq -r '.loop_id // ""' "$SUP_MANIFEST")
+CYCLE=$(jq -r '.cycle // 0' "$SUP_MANIFEST")
+TMUX_SESSION=${POLYLANE_SESSION:-polylane-$LOOP_ID}
+BASE_REF=$(jq -r '.base // ""' "$SUP_MANIFEST")
+BASE_BEFORE=$(git rev-parse "$BASE_REF" 2>/dev/null || git rev-parse HEAD)
@@
 RUNNER_LOG="$MDIR/runner.log"
+RESULT=${POLYLANE_CYCLE_RESULT_RECEIPT:?launcher must supply a fresh attempt receipt}
+RUNNER_CMD=${POLYLANE_RUNNER:-$SCRIPT_DIR/polylane-run.sh}
@@
+cycle_result_valid() {
+  polylane_validate_cycle_result "$RESULT" "$SUP_MANIFEST" "$PROJECT_ROOT"
+}
+
+bind_current_attempt() {
+  local runtime=${POLYLANE_RUNTIME_DIR:?runtime required}
+  polylane_validate_attempt_identity "$runtime" "$SUP_MANIFEST" allocated || return 1
+  RESULT=$POLYLANE_CYCLE_RESULT_RECEIPT
+  RUNNER_LOG="$runtime/attempts/$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION/a$POLYLANE_ATTEMPT/runner.log"
+}
+
+allocate_restart_attempt() {
+  local runtime=${POLYLANE_RUNTIME_DIR:?runtime required}
+  polylane_plan_retry_attempt "$runtime" "$SUP_MANIFEST" || return 1
+  polylane_full_preflight "$SUP_MANIFEST" "$runtime" planned owned-retry || return 1
+  polylane_allocate_attempt "$runtime" "$SUP_MANIFEST" || return 1
+  bind_current_attempt
+}
+
 supervisor_main() {
+    bind_current_attempt || return 75
@@
-    POLYLANE_SESSION="$TMUX_SESSION" "$SCRIPT_DIR/polylane-run.sh" "$SUP_MANIFEST" $args_line >> "$RUNNER_LOG" 2>&1 &
+    POLYLANE_SESSION="$TMUX_SESSION" "$RUNNER_CMD" "$SUP_MANIFEST" $args_line >> "$RUNNER_LOG" 2>&1 &
@@
-    if report_fresh; then
-      # legitimate end — GO (rc 0) or NO-GO (rc 1). Either way: done, not a crash.
-      sup_log "runner finished legitimately (rc=$rc, report written) — supervisor exiting"
+    if cycle_result_valid; then
+      outcome=$(jq -r .outcome "$RESULT")
+      sup_log "runner finished with validated $outcome result"
       heartbeat finished "$restarts"
-      return "$rc"
+      case "$outcome" in GO) return 0 ;; NO_GO) return 1 ;; RECOVERY_REQUIRED) return 75 ;; esac
@@
     restarts=$((restarts + 1))
+    allocate_restart_attempt || {
+      sup_log "cannot allocate a fresh immutable restart attempt"
+      heartbeat recovery_required "$restarts"
+      return 75
+    }
@@
-      sup_log "runner died without a report and the restart cap ($SUP_MAX_RESTARTS) is exhausted — halting"
-      notify_event halt "supervisor: runner crashed ${restarts}x without finishing — halted, worktrees intact"
-      heartbeat halted "$restarts"
-      return 1
+      polylane_safe_mkdirs "$POLYLANE_RUNTIME_DIR/cycle-results" 0700
+      lane_commits='[]'
+      while IFS=$'\t' read -r lane_name lane_branch lane_worktree; do
+        lane_commit=""
+        if [ -n "$lane_branch" ]; then
+          lane_commit=$(git rev-parse "$lane_branch" 2>/dev/null || true)
+        elif [ -n "$lane_worktree" ]; then
+          lane_commit=$(git -C "$lane_worktree" rev-parse HEAD 2>/dev/null || true)
+        fi
+        [ -z "$lane_commit" ] || lane_commits=$(jq -cn --argjson prior "$lane_commits" \
+          --arg name "$lane_name" --arg commit "$lane_commit" \
+          '$prior + [{name:$name,commit:$commit}]')
+      done < <(jq -r '.lanes[]? | [.name, (.branch // ""), (.worktree // "")] | @tsv' "$SUP_MANIFEST")
+      POLYLANE_REPO_ROOT=$PROJECT_ROOT; export POLYLANE_REPO_ROOT
+      polylane_write_cycle_result "$POLYLANE_RUNTIME_DIR" "$SUP_MANIFEST" RECOVERY_REQUIRED "" \
+        "$BASE_REF" "$BASE_BEFORE" "$lane_commits" "" || true
+      sup_log "restart cap exhausted — handing recovery to the persistent controller"
+      heartbeat recovery_required "$restarts"
+      return 75
```

Expected: `bash -n core/scripts/polylane-supervisor.sh` exits 0 and the override preserves
all inherited agent, custom command, model, and effort environment variables.

- [ ] **Step 8: Allocate an immutable direct-launch attempt only after full preflight (4 minutes)**

Make this anchored edit immediately before the final `exec` in each launcher. Planning is read-only;
the first filesystem mutation is the exclusive attempt allocation. A repeated direct invocation
or supervisor restart advances generation/attempt and can never reuse a receipt:

```diff
diff --git a/codex/scripts/polylane-codex.sh b/codex/scripts/polylane-codex.sh
--- a/codex/scripts/polylane-codex.sh
+++ b/codex/scripts/polylane-codex.sh
@@
-exec "$CORE_BIN/polylane-supervisor.sh" "$MANIFEST" "$@"
+MANIFEST=$(cd "$(dirname "$MANIFEST")" && pwd -P)/$(basename "$MANIFEST")
+repo=$(git -C "$(dirname "$MANIFEST")" rev-parse --show-toplevel 2>/dev/null) || exit 2
+POLYLANE_RUNTIME_DIR=${POLYLANE_RUNTIME_DIR:-$repo/.polylane/runtime}; export POLYLANE_RUNTIME_DIR
+if [ -z "${POLYLANE_CLAIM_TOKEN:-}" ]; then
+  polylane_plan_direct_attempt "$POLYLANE_RUNTIME_DIR" "$MANIFEST" || exit 2
+elif polylane_validate_attempt_identity "$POLYLANE_RUNTIME_DIR" "$MANIFEST" allocated; then
+  # A caller replayed an already allocated identity: advance, never adopt/reuse it.
+  polylane_plan_retry_attempt "$POLYLANE_RUNTIME_DIR" "$MANIFEST" || exit 2
+else
+  polylane_validate_attempt_identity "$POLYLANE_RUNTIME_DIR" "$MANIFEST" planned || exit 2
+fi
+polylane_full_preflight "$MANIFEST" "$POLYLANE_RUNTIME_DIR" planned || exit 2
+polylane_allocate_attempt "$POLYLANE_RUNTIME_DIR" "$MANIFEST" || exit $?
+if [ "${POLYLANE_HOST_FD:-}" = 9 ] && { : >&9; } 2>/dev/null; then :; else exec 9>&1; fi
+POLYLANE_HOST_FD=9; export POLYLANE_HOST_FD
+exec "$CORE_BIN/polylane-supervisor.sh" "$MANIFEST" "$@"
diff --git a/claude-code/scripts/polylane-claude.sh b/claude-code/scripts/polylane-claude.sh
--- a/claude-code/scripts/polylane-claude.sh
+++ b/claude-code/scripts/polylane-claude.sh
@@
-exec "$CORE_BIN/polylane-supervisor.sh" "$MANIFEST" "$@"
+MANIFEST=$(cd "$(dirname "$MANIFEST")" && pwd -P)/$(basename "$MANIFEST")
+repo=$(git -C "$(dirname "$MANIFEST")" rev-parse --show-toplevel 2>/dev/null) || exit 2
+POLYLANE_RUNTIME_DIR=${POLYLANE_RUNTIME_DIR:-$repo/.polylane/runtime}; export POLYLANE_RUNTIME_DIR
+if [ -z "${POLYLANE_CLAIM_TOKEN:-}" ]; then
+  polylane_plan_direct_attempt "$POLYLANE_RUNTIME_DIR" "$MANIFEST" || exit 2
+elif polylane_validate_attempt_identity "$POLYLANE_RUNTIME_DIR" "$MANIFEST" allocated; then
+  polylane_plan_retry_attempt "$POLYLANE_RUNTIME_DIR" "$MANIFEST" || exit 2
+else polylane_validate_attempt_identity "$POLYLANE_RUNTIME_DIR" "$MANIFEST" planned || exit 2; fi
+polylane_full_preflight "$MANIFEST" "$POLYLANE_RUNTIME_DIR" planned || exit 2
+polylane_allocate_attempt "$POLYLANE_RUNTIME_DIR" "$MANIFEST" || exit $?
+if [ "${POLYLANE_HOST_FD:-}" = 9 ] && { : >&9; } 2>/dev/null; then :; else exec 9>&1; fi
+POLYLANE_HOST_FD=9; export POLYLANE_HOST_FD
+exec "$CORE_BIN/polylane-supervisor.sh" "$MANIFEST" "$@"
```

Expected: both launchers pass `bash -n`; all dependency/template/disk/identity checks precede
runtime creation, and each successful invocation owns a fresh receipt-adjacent owner record.

- [ ] **Step 9: Prove full preflight is read-only and crash restarts burn identities (5 minutes)**

Create `core/tests/test-full-preflight-attempts.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
. "$ROOT/core/scripts/polylane-agent.sh"
. "$ROOT/codex/scripts/polylane-codex-agent.sh"
make_tmpdir
PROJ="$TEST_TMPDIR/repo"; mkdir -p "$PROJ/.polylane"
git -C "$PROJ" init -q -b main
git -C "$PROJ" config user.email test@example.invalid
git -C "$PROJ" config user.name Test
printf 'base\n' > "$PROJ/base"; git -C "$PROJ" add base; git -C "$PROJ" commit -qm base
BASE=$(git -C "$PROJ" rev-parse HEAD)
MANIFEST="$PROJ/.polylane/run.json"
LANE_PROMPT="$PROJ/.polylane/lane.prompt"; INT_PROMPT="$PROJ/.polylane/integrator.prompt"
printf 'lane\n' > "$LANE_PROMPT"; printf 'integrate\n' > "$INT_PROMPT"
LANE_WT="$TEST_TMPDIR/wt-one"; INT_WT="$TEST_TMPDIR/wt-integrator"
jq -nS --arg lane_prompt "$LANE_PROMPT" --arg int_prompt "$INT_PROMPT" \
  --arg lane_wt "$LANE_WT" --arg int_wt "$INT_WT" '
  {agent:"codex",loop_id:"loop-1",cycle:1,run_id:"run-1",base:"main",
   lanes:[{name:"one",model:"m",effort:"high",branch:"lane/one",worktree:$lane_wt,
     prompt_file:$lane_prompt,own_globs:["one/**"]}],
   integrator:{name:"integrator",model:"m",effort:"high",branch:"lane/integrator",
     worktree:$int_wt,prompt_file:$int_prompt}}' > "$MANIFEST"
RUNTIME="$PROJ/.polylane/runtime"; TMUX_MUTATIONS="$TEST_TMPDIR/tmux-mutations"
: > "$TMUX_MUTATIONS"
ORIGINAL_PATH=$PATH
make_path() {
  local out=$1 omit=${2:-} command resolved
  mkdir -p "$out"
  for command in awk bash basename chmod cksum cp date df dirname git grep head jq ln mkdir od \
    ps python3 readlink rm sleep stat tr uname wc; do
    [ "$command" = "$omit" ] && continue
    resolved=$(command -v "$command") || return 1; ln -s "$resolved" "$out/$command"
  done
  if [ "$omit" != tmux ]; then
    cat > "$out/tmux" <<SH
#!/usr/bin/env bash
case "\${1:-}" in new-session|kill-session|set-option|set-environment) echo "\$*" >> "$TMUX_MUTATIONS" ;; esac
[ "\${1:-}" != has-session ]
SH
    chmod +x "$out/tmux"
  fi
  if command -v shasum >/dev/null 2>&1; then ln -s "$(command -v shasum)" "$out/shasum"
  else ln -s "$(command -v sha256sum)" "$out/sha256sum"; fi
}
GOOD="$TEST_TMPDIR/good-path"; make_path "$GOOD"
export POLYLANE_AGENT=codex
export POLYLANE_AGENT_CMD='mock {model} {prompt} {effort} {error_artifact}'
export POLYLANE_MIN_DISK_KB=0 POLYLANE_CYCLE_RUN_ID=run-1
export POLYLANE_CLAIM_TOKEN=claim-preflight POLYLANE_RUNNER_GENERATION=1 POLYLANE_ATTEMPT=1
export POLYLANE_CYCLE_RESULT_RECEIPT="$RUNTIME/cycle-results/run-1.claim-preflight.g1.a1.json"
worktrees_before=$(git -C "$PROJ" worktree list --porcelain)
preflight_with_path() {
  local path=$1 disk=${2:-0} manifest=${3:-$MANIFEST}
  ( PATH=$path; POLYLANE_MIN_DISK_KB=$disk; export PATH POLYLANE_MIN_DISK_KB
    polylane_full_preflight "$manifest" "$RUNTIME" planned )
}
BAD="$PROJ/.polylane/bad.json"
jq '.integrator={}' "$MANIFEST" > "$BAD"
assert_rc "incomplete-integrator-preallocation" 2 preflight_with_path "$GOOD" 0 "$BAD"
jq '.lanes[0].prompt_file="/missing-prompt"' "$MANIFEST" > "$BAD"
assert_rc "missing-prompt-preallocation" 2 preflight_with_path "$GOOD" 0 "$BAD"
EMPTY_PROMPT="$PROJ/.polylane/empty.prompt"; : > "$EMPTY_PROMPT"
jq --arg prompt "$EMPTY_PROMPT" '.integrator.prompt_file=$prompt' "$MANIFEST" > "$BAD"
assert_rc "empty-prompt-preallocation" 2 preflight_with_path "$GOOD" 0 "$BAD"
mkdir "$LANE_WT"; assert_rc "existing-worktree-preallocation" 2 \
  preflight_with_path "$GOOD" 0 "$MANIFEST"; rmdir "$LANE_WT"
assert_fail "invalid-manifests-created-no-runtime" test -e "$RUNTIME"
assert_eq "invalid-manifests-no-tmux-mutation" "" "$(cat "$TMUX_MUTATIONS")"
for omitted in python3 git tmux; do
  path="$TEST_TMPDIR/path-$omitted"; make_path "$path" "$omitted"
  assert_rc "missing-$omitted" 2 preflight_with_path "$path" 0
  assert_fail "missing-$omitted-no-runtime" test -e "$RUNTIME"
done
assert_rc "insufficient-disk" 2 preflight_with_path "$GOOD" 999999999999
assert_fail "disk-no-runtime" test -e "$RUNTIME"
assert_eq "preflight-no-worktree" "$worktrees_before" "$(git -C "$PROJ" worktree list --porcelain)"
assert_eq "preflight-no-tmux-mutation" "" "$(cat "$TMUX_MUTATIONS")"

PATH="$GOOD:$ORIGINAL_PATH"; export PATH
unset POLYLANE_CLAIM_TOKEN POLYLANE_RUNNER_GENERATION POLYLANE_ATTEMPT POLYLANE_CYCLE_RESULT_RECEIPT
assert_ok "plan-g1a1" polylane_plan_direct_attempt "$RUNTIME" "$MANIFEST"
assert_eq "direct-exact-receipt" "$RUNTIME/cycle-results/run-1.direct-run-1.g1.a1.json" \
  "$POLYLANE_CYCLE_RESULT_RECEIPT"
assert_ok "preflight-g1a1" polylane_full_preflight "$MANIFEST" "$RUNTIME" planned
assert_ok "allocate-g1a1" polylane_allocate_attempt "$RUNTIME" "$MANIFEST"
assert_ok "runner-preflight-g1a1-allocated" polylane_full_preflight \
  "$MANIFEST" "$RUNTIME" allocated
G1_OWNER="$RUNTIME/cycle-results/run-1.direct-run-1.g1.a1.owner.json"
G1_HASH=$(polylane_sha256 "$G1_OWNER")
assert_fail "receipt-not-invented-by-allocation" test -e "$RUNTIME/cycle-results/run-1.direct-run-1.g1.a1.json"
assert_ok "crash-plan-g1a2" polylane_plan_retry_attempt "$RUNTIME" "$MANIFEST"
git -C "$PROJ" branch lane/one main; git -C "$PROJ" branch lane/integrator main
git -C "$PROJ" worktree add -q "$LANE_WT" lane/one
git -C "$PROJ" worktree add -q "$INT_WT" lane/integrator
assert_rc "retry-worktrees-require-explicit-policy" 2 polylane_full_preflight \
  "$MANIFEST" "$RUNTIME" planned
assert_ok "crash-preflight-g1a2" polylane_full_preflight \
  "$MANIFEST" "$RUNTIME" planned owned-retry
assert_ok "crash-allocate-g1a2" polylane_allocate_attempt "$RUNTIME" "$MANIFEST"
assert_ok "runner-preflight-g1a2-allocated" polylane_full_preflight \
  "$MANIFEST" "$RUNTIME" allocated
git -C "$PROJ" worktree remove -f "$LANE_WT"; git -C "$PROJ" worktree remove -f "$INT_WT"
git -C "$PROJ" branch -D lane/one lane/integrator >/dev/null
assert_eq "crash-attempt-monotonic" 2 "$POLYLANE_ATTEMPT"
assert_eq "g1-owner-immutable" "$G1_HASH" "$(polylane_sha256 "$G1_OWNER")"

unset POLYLANE_CLAIM_TOKEN POLYLANE_RUNNER_GENERATION POLYLANE_ATTEMPT POLYLANE_CYCLE_RESULT_RECEIPT
assert_ok "direct-relaunch-plans-g2" polylane_plan_direct_attempt "$RUNTIME" "$MANIFEST"
assert_eq "direct-generation-monotonic" 2 "$POLYLANE_RUNNER_GENERATION"
assert_ok "preflight-g2a1" polylane_full_preflight "$MANIFEST" "$RUNTIME" planned
assert_ok "allocate-g2a1" polylane_allocate_attempt "$RUNTIME" "$MANIFEST"
assert_ok "runner-preflight-g2a1-allocated" polylane_full_preflight \
  "$MANIFEST" "$RUNTIME" allocated
G2_OWNER=${POLYLANE_CYCLE_RESULT_RECEIPT%.json}.owner.json; G2_HASH=$(polylane_sha256 "$G2_OWNER")

cat > "$TEST_TMPDIR/crash-runner" <<SH
#!/usr/bin/env bash
printf '%s:%s:%s\n' "\$POLYLANE_RUNNER_GENERATION" "\$POLYLANE_ATTEMPT" \
  "\$POLYLANE_CYCLE_RESULT_RECEIPT" >> "$TEST_TMPDIR/restart-identities"
[ "\$POLYLANE_ATTEMPT" != 1 ] || exit 137
. "$ROOT/core/scripts/polylane-agent.sh"
POLYLANE_REPO_ROOT="$PROJ"; export POLYLANE_REPO_ROOT
polylane_write_cycle_result "$RUNTIME" "$MANIFEST" RECOVERY_REQUIRED "" main "$BASE" '[]' ""
exit 75
SH
chmod +x "$TEST_TMPDIR/crash-runner"
assert_rc "supervisor-crash-handoff" 75 env PATH="$PATH" POLYLANE_RUNNER="$TEST_TMPDIR/crash-runner" \
  POLYLANE_AGENT=codex POLYLANE_AGENT_ADAPTER="$ROOT/codex/scripts/polylane-codex-agent.sh" \
  POLYLANE_AGENT_CMD="$POLYLANE_AGENT_CMD" POLYLANE_RUNTIME_DIR="$RUNTIME" \
  POLYLANE_SESSION=polylane-loop-1 POLYLANE_SUP_INTERVAL=1 POLYLANE_SUP_MAX_RESTARTS=2 \
  "$ROOT/core/scripts/polylane-supervisor.sh" "$MANIFEST"
assert_eq "supervisor-two-identities" 2 "$(wc -l < "$TEST_TMPDIR/restart-identities" | tr -d ' ')"
assert_contains "supervisor-first-a1" '2:1:' "$(sed -n 1p "$TEST_TMPDIR/restart-identities")"
assert_contains "supervisor-second-a2" '2:2:' "$(sed -n 2p "$TEST_TMPDIR/restart-identities")"
assert_eq "pre-crash-owner-immutable" "$G2_HASH" "$(polylane_sha256 "$G2_OWNER")"

assert_ok "plan-collision-candidate" polylane_plan_retry_attempt "$RUNTIME" "$MANIFEST"
COLLISION=$POLYLANE_CYCLE_RESULT_RECEIPT
printf 'occupied\n' | polylane_private_from_stdin "$COLLISION" 0400
assert_ok "collision-is-burned" polylane_plan_retry_attempt "$RUNTIME" "$MANIFEST"
assert_fail "collision-not-reused" test "$POLYLANE_CYCLE_RESULT_RECEIPT" = "$COLLISION"
finish
```

Run: `bash -n core/tests/test-full-preflight-attempts.sh`.

Expected: exit 0. Omitting Python, Git, or tmux and failing the disk threshold leave no runtime,
worktree, tmux, claim, generation, attempt, or receipt side effect. The real crash/restart uses
`g2/a1` then `g2/a2`; prior owners remain byte-identical and a collided receipt is burned.

- [ ] **Step 10: Replace obsolete preflight recovery with executable cleanup-result coverage (4 minutes)**

Create `core/tests/test-cleanup-result.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
. "$ROOT/core/scripts/polylane-agent.sh"
make_tmpdir
PROJ="$TEST_TMPDIR/repo"; mkdir -p "$PROJ/.polylane"
git -C "$PROJ" init -q -b main
git -C "$PROJ" config user.email test@example.invalid
git -C "$PROJ" config user.name Test
printf 'base\n' > "$PROJ/history"; git -C "$PROJ" add history; git -C "$PROJ" commit -qm base
BASE=$(git -C "$PROJ" rev-parse HEAD)
printf 'integration\n' >> "$PROJ/history"; git -C "$PROJ" commit -qam integration
INTEGRATION=$(git -C "$PROJ" rev-parse HEAD)
MANIFEST="$PROJ/.polylane/run.json"
printf '%s\n' '{"agent":"codex","loop_id":"loop-1","cycle":1,"run_id":"run-1","base":"main","lanes":[{"name":"one"}],"integrator":{}}' > "$MANIFEST"
RUNTIME="$PROJ/.polylane/runtime"; POLYLANE_REPO_ROOT=$PROJ
export POLYLANE_REPO_ROOT
lanes=$(jq -cn --arg commit "$INTEGRATION" '[{name:"one",commit:$commit}]')
new_attempt() {
  if [ -z "${POLYLANE_CLAIM_TOKEN:-}" ]; then polylane_plan_direct_attempt "$RUNTIME" "$MANIFEST"
  else polylane_plan_retry_attempt "$RUNTIME" "$MANIFEST"; fi &&
    polylane_allocate_attempt "$RUNTIME" "$MANIFEST"
}
assert_ok "allocate-go-attempt" new_attempt
GO_RESULT=$POLYLANE_CYCLE_RESULT_RECEIPT
assert_fail "go-without-cleanup-evidence-rejected" polylane_write_cycle_result \
  "$RUNTIME" "$MANIFEST" GO GO main "$BASE" "$lanes" "$INTEGRATION"
assert_fail "failed-go-left-no-receipt" test -e "$GO_RESULT"
cleanup="${GO_RESULT%.json}.cleanup.json"; cleanup_private="$cleanup.private.$$"
jq -nS --arg run run-1 --arg integration "$INTEGRATION" \
  '{schema_version:1,run_id:$run,integration_commit:$integration,cleanup_complete:true,
    lane_worktrees_absent:true,lane_branches_absent:true,session_absent:true}' |
  polylane_private_from_stdin "$cleanup_private" 0400
polylane_publish_private "$cleanup_private" "$cleanup"
POLYLANE_CLEANUP_EVIDENCE=$cleanup; export POLYLANE_CLEANUP_EVIDENCE
assert_ok "write-cleanup-bound-go" polylane_write_cycle_result \
  "$RUNTIME" "$MANIFEST" GO GO main "$BASE" "$lanes" "$INTEGRATION"
assert_ok "go-with-sealed-cleanup-evidence" polylane_validate_cycle_result \
  "$GO_RESULT" "$MANIFEST" "$PROJ"
chmod 0600 "$cleanup"; printf 'tamper\n' >> "$cleanup"; chmod 0400 "$cleanup"
assert_fail "go-cleanup-tamper-rejected" polylane_validate_cycle_result \
  "$GO_RESULT" "$MANIFEST" "$PROJ"
unset POLYLANE_CLEANUP_EVIDENCE

assert_ok "allocate-nogo-attempt" new_attempt
NO_GO_RESULT=$POLYLANE_CYCLE_RESULT_RECEIPT
assert_ok "write-nogo" polylane_write_cycle_result \
  "$RUNTIME" "$MANIFEST" NO_GO NO_GO main "$BASE" "$lanes" ""
assert_eq "nogo-cleanup-fields-null" null:null \
  "$(jq -r '[.cleanup_evidence_path,.cleanup_evidence_hash]|map(tostring)|join(":")' "$NO_GO_RESULT")"

assert_ok "allocate-cleanup-failure-attempt" new_attempt
CLEANUP_FAILURE=$POLYLANE_CYCLE_RESULT_RECEIPT
cleanup_after_promotion() { return 1; }
if cleanup_after_promotion; then
  fail "cleanup-fault-must-fail" "fault unexpectedly succeeded"
else
  assert_ok "cleanup-failure-publishes-recovery" polylane_write_cycle_result \
    "$RUNTIME" "$MANIFEST" RECOVERY_REQUIRED "" main "$BASE" '[]' ""
fi
assert_eq "cleanup-failure-outcome" RECOVERY_REQUIRED "$(jq -r .outcome "$CLEANUP_FAILURE")"
assert_eq "cleanup-failure-never-go" 0 \
  "$(jq -s '[.[]|select(.outcome=="GO")]|length' "$CLEANUP_FAILURE")"
assert_eq "attempts-have-distinct-receipts" 3 \
  "$(find "$RUNTIME/cycle-results" -name 'run-1.*.json' ! -name '*.owner.json' ! -name '*.cleanup.json' | wc -l | tr -d ' ')"
finish
```

Replace `core/tests/test-recovery-handoff.sh` with this final compatibility wrapper:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
out=$(bash "$ROOT/core/tests/test-cleanup-result.sh" 2>&1); rc=$?
assert_eq "cleanup-result-contract-exit" 0 "$rc"
assert_contains "cleanup-result-go" "PASS go-with-sealed-cleanup-evidence" "$out"
assert_contains "cleanup-result-tamper" "PASS go-cleanup-tamper-rejected" "$out"
assert_contains "cleanup-result-recovery" "PASS cleanup-failure-outcome" "$out"
finish
```

Run: `bash -n core/tests/test-cleanup-result.sh core/tests/test-recovery-handoff.sh`.

Expected: exit 0. GO cannot be written without sealed cleanup evidence, tamper is rejected,
NO_GO has null cleanup fields, and cleanup failure produces only `RECOVERY_REQUIRED`.

Create `core/tests/test-owned-session-cleanup.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
. "$ROOT/core/scripts/polylane-run.sh"
RUN_ID=cleanup-run; LOOP_ID=cleanup-loop; POLYLANE_CLAIM_TOKEN=cleanup-claim
POLYLANE_RUNNER_GENERATION=1; AGENT_SHELL=$(cd /bin && pwd -P)/bash
while :; do
  birth_second=$(date +%s)
  sleep 300 & birth_pid_one=$!
  sleep 300 & birth_pid_two=$!
  [ "$(date +%s)" = "$birth_second" ] && break
  kill "$birth_pid_one" "$birth_pid_two" 2>/dev/null || true
  wait "$birth_pid_one" "$birth_pid_two" 2>/dev/null || true
done
birth_token_one=$(polylane_process_start_token "$birth_pid_one")
birth_token_two=$(polylane_process_start_token "$birth_pid_two")
assert_fail "same-second-processes-have-distinct-birth-identities" test \
  "$birth_token_one" = "$birth_token_two"
assert_fail "pid-reuse-cannot-authenticate-with-prior-birth-token" \
  polylane_process_identity_alive "$birth_pid_two" "$birth_token_one"
assert_ok "exact-high-resolution-birth-identity-authenticates" \
  polylane_process_identity_alive "$birth_pid_one" "$birth_token_one"
kill "$birth_pid_one" "$birth_pid_two" 2>/dev/null || true
wait "$birth_pid_one" "$birth_pid_two" 2>/dev/null || true
if ! command -v tmux >/dev/null 2>&1; then pass "owned-session-skip-no-tmux"; finish; exit 0; fi
own_session() {
  TMUX_SESSION_NAME=$1
  TMUX_SESSION_ID=$(tmux new-session -d -P -F '#{session_id}' -s "$TMUX_SESSION_NAME" \
    "$AGENT_SHELL" -c 'sleep 300')
  tmux set-option -t "$TMUX_SESSION_ID" @polylane_run_id "$RUN_ID"
  tmux set-option -t "$TMUX_SESSION_ID" @polylane_loop_id "$LOOP_ID"
  tmux set-option -t "$TMUX_SESSION_ID" @polylane_claim_token "$POLYLANE_CLAIM_TOKEN"
  tmux set-option -t "$TMUX_SESSION_ID" @polylane_runner_generation "$POLYLANE_RUNNER_GENERATION"
  TMUX_SESSION=$TMUX_SESSION_ID
}
own_session "polylane-go-$$"; go_id=$TMUX_SESSION_ID
assert_ok "go-fences-exact-owned-session" fence_owned_tmux_session
assert_fail "go-owned-id-absent-before-seal" tmux has-session -t "$go_id"

caller_pid=$(/bin/sh -c 'printf "%s\n" "$PPID"')
caller_token=$(polylane_process_start_token "$caller_pid")
caller_pgid=$(ps -o pgid= -p "$caller_pid" | tr -d '[:space:]')
FENCE_PHASE_FIFO="$TEST_TMPDIR/fence-phase.fifo"
FENCE_PHASE_LOG="$TEST_TMPDIR/fence-phase.observer.log"
mkfifo "$FENCE_PHASE_FIFO"
(
  while IFS= read -r phase; do
    printf '%s\n' "$phase" >> "$FENCE_PHASE_LOG"
  done < "$FENCE_PHASE_FIFO"
) &
fence_observer_pid=$!
fence_observer_token=$(polylane_process_start_token "$fence_observer_pid")
fence_observer_pgid=$(ps -o pgid= -p "$fence_observer_pid" | tr -d '[:space:]')
assert_eq "observer-runs-in-excluded-control-pgid" "$caller_pgid" "$fence_observer_pgid"
exec 9>"$FENCE_PHASE_FIFO"
POLYLANE_FENCE_PHASE_FD=9; export POLYLANE_FENCE_PHASE_FD

DETACHED="$TEST_TMPDIR/detached.py"; DETACHED_PID="$TEST_TMPDIR/detached.pid"
DETACHED_CHILD="$TEST_TMPDIR/detached.child.pid"
cat > "$DETACHED" <<'PY'
import os, signal, sys, time
os.setsid()
signal.signal(signal.SIGHUP, signal.SIG_IGN)
signal.signal(signal.SIGTERM, signal.SIG_IGN)
forked = False
def after_continue(_signum, _frame):
    global forked
    if forked: return
    forked = True
    child = os.fork()
    if child == 0:
        signal.signal(signal.SIGCONT, signal.SIG_IGN)
        while True: time.sleep(60)
    with open(sys.argv[2], "w", encoding="ascii") as handle:
        handle.write(str(child)); handle.flush(); os.fsync(handle.fileno())
signal.signal(signal.SIGCONT, after_continue)
with open(sys.argv[1], "w", encoding="ascii") as handle:
    handle.write(str(os.getpid())); handle.flush(); os.fsync(handle.fileno())
while True: time.sleep(60)
PY
TMUX_SESSION_NAME="polylane-detached-$$"
TMUX_SESSION_ID=$(tmux new-session -d -P -F '#{session_id}' -s "$TMUX_SESSION_NAME" \
  "$AGENT_SHELL" -c \
  "trap '' HUP TERM; python3 '$DETACHED' '$DETACHED_PID' '$DETACHED_CHILD' & wait")
tmux set-option -t "$TMUX_SESSION_ID" @polylane_run_id "$RUN_ID"
tmux set-option -t "$TMUX_SESSION_ID" @polylane_loop_id "$LOOP_ID"
tmux set-option -t "$TMUX_SESSION_ID" @polylane_claim_token "$POLYLANE_CLAIM_TOKEN"
tmux set-option -t "$TMUX_SESSION_ID" @polylane_runner_generation "$POLYLANE_RUNNER_GENERATION"
TMUX_SESSION=$TMUX_SESSION_ID; detached_wait=0
while [ ! -s "$DETACHED_PID" ] && [ "$detached_wait" -lt 500 ]; do
  sleep 0.01; detached_wait=$((detached_wait + 1))
done
assert_ok "detached-descendant-started" test -s "$DETACHED_PID"
detached_pid=$(cat "$DETACHED_PID"); detached_token=$(polylane_process_start_token "$detached_pid")
detached_sid=$(python3 -c 'import os,sys; print(os.getsid(int(sys.argv[1])))' "$detached_pid")
detached_pgid=$(ps -o pgid= -p "$detached_pid" | tr -d '[:space:]')
assert_eq "detached-worker-authenticated-session-leader" "$detached_pid" "$detached_sid"
assert_eq "detached-worker-authenticated-process-group-leader" "$detached_pid" "$detached_pgid"
assert_fail "detached-worker-pgid-is-not-control-pgid" test "$detached_pgid" = "$caller_pgid"
assert_ok "detached-worker-identity-authenticated-before-fence" \
  polylane_process_identity_alive "$detached_pid" "$detached_token"
detached_fence_rc=0
fence_owned_tmux_session || detached_fence_rc=$?
assert_eq "detached-session-fence-function-returned" 0 "$detached_fence_rc"
phase_wait=0
while [ "$(wc -l < "$FENCE_PHASE_LOG" 2>/dev/null || printf 0)" -lt 4 ] && \
      [ "$phase_wait" -lt 500 ]; do
  sleep 0.01; phase_wait=$((phase_wait + 1))
done
assert_eq "observer-saw-cont-term-grace-kill-and-completion" \
  $'CONT\nTERM_GRACE\nKILL\nCOMPLETE' "$(cat "$FENCE_PHASE_LOG")"
assert_ok "fence-caller-survived-exactly" \
  polylane_process_identity_alive "$caller_pid" "$caller_token"
assert_ok "excluded-observer-survived-exactly" \
  polylane_process_identity_alive "$fence_observer_pid" "$fence_observer_token"
assert_contains "caller-exact-identity-was-excluded" "$caller_pid|$caller_pgid|$caller_token" \
  "$TMUX_FENCE_EXCLUDED_PROCESS_RECORDS"
assert_contains "caller-control-pgid-was-excluded" ",$caller_pgid," \
  ",$TMUX_FENCE_EXCLUDED_PGIDS,"
assert_not_contains "caller-never-entered-fenced-inventory" "$caller_pid|" \
  "$TMUX_FENCED_PROCESS_RECORDS"
assert_not_contains "observer-never-entered-fenced-inventory" "$fence_observer_pid|" \
  "$TMUX_FENCED_PROCESS_RECORDS"
assert_ok "detached-worker-forked-after-final-cont" test -s "$DETACHED_CHILD"
detached_child=$(cat "$DETACHED_CHILD")
assert_contains "post-cont-child-added-through-authenticated-pgid" "$detached_child|" \
  "$TMUX_FENCED_PROCESS_RECORDS"
assert_fail "detached-descendant-gone-before-evidence" \
  polylane_process_identity_alive "$detached_pid" "$detached_token"
assert_fail "post-cont-detached-child-gone-before-evidence" kill -0 "$detached_child"
exec 9>&-
wait "$fence_observer_pid"
unset POLYLANE_FENCE_PHASE_FD

FORKER="$TEST_TMPDIR/fork-during-capture.py"
FORK_PIDS="$TEST_TMPDIR/fork-during-capture.pids"
FORK_GATE="$TEST_TMPDIR/fork-during-capture.go"
cat > "$FORKER" <<'PY'
import os, signal, sys, time
pid_file, gate = sys.argv[1:]
signal.signal(signal.SIGHUP, signal.SIG_IGN)
signal.signal(signal.SIGTERM, signal.SIG_IGN)
def record(pid):
    with open(pid_file, "a", encoding="ascii") as handle:
        handle.write(f"{pid}\n"); handle.flush(); os.fsync(handle.fileno())
record(os.getpid())
while not os.path.exists(gate): time.sleep(0.005)
child = os.fork()
if child == 0:
    while True: time.sleep(60)
record(child)
while True: time.sleep(60)
PY
TMUX_SESSION_NAME="polylane-fork-capture-$$"
TMUX_SESSION_ID=$(tmux new-session -d -P -F '#{session_id}' -s "$TMUX_SESSION_NAME" \
  "$AGENT_SHELL" -c "trap '' HUP TERM; python3 '$FORKER' '$FORK_PIDS' '$FORK_GATE' & wait")
tmux set-option -t "$TMUX_SESSION_ID" @polylane_run_id "$RUN_ID"
tmux set-option -t "$TMUX_SESSION_ID" @polylane_loop_id "$LOOP_ID"
tmux set-option -t "$TMUX_SESSION_ID" @polylane_claim_token "$POLYLANE_CLAIM_TOKEN"
tmux set-option -t "$TMUX_SESSION_ID" @polylane_runner_generation "$POLYLANE_RUNNER_GENERATION"
TMUX_SESSION=$TMUX_SESSION_ID; fork_wait=0
while [ ! -s "$FORK_PIDS" ] && [ "$fork_wait" -lt 500 ]; do
  sleep 0.01; fork_wait=$((fork_wait + 1))
done
assert_ok "forking-descendant-ready-before-capture" test -s "$FORK_PIDS"
fork_parent=$(sed -n '1p' "$FORK_PIDS")
fork_parent_token=$(polylane_process_start_token "$fork_parent")
FORK_HOOK="$TEST_TMPDIR/fork-during-capture-hook"
cat > "$FORK_HOOK" <<'SH'
#!/usr/bin/env bash
set -u
[ "$1" = after-descendant-snapshot ] || exit 1
[ ! -e "$POLYLANE_FORK_HOOK_ONCE" ] || exit 0
: > "$POLYLANE_FORK_HOOK_ONCE"
: > "$POLYLANE_FORK_GATE"
i=0
while [ "$(wc -l < "$POLYLANE_FORK_PIDS")" -lt 2 ] && [ "$i" -lt 500 ]; do
  sleep 0.01; i=$((i + 1))
done
[ "$(wc -l < "$POLYLANE_FORK_PIDS")" -ge 2 ]
SH
chmod +x "$FORK_HOOK"
POLYLANE_PROCESS_TEST_BOUNDARY=after-descendant-snapshot
POLYLANE_PROCESS_TEST_BOUNDARY_HOOK="$FORK_HOOK"
POLYLANE_FORK_HOOK_ONCE="$TEST_TMPDIR/fork-hook.once"
POLYLANE_FORK_GATE="$FORK_GATE"; POLYLANE_FORK_PIDS="$FORK_PIDS"
export POLYLANE_PROCESS_TEST_BOUNDARY POLYLANE_PROCESS_TEST_BOUNDARY_HOOK
export POLYLANE_FORK_HOOK_ONCE POLYLANE_FORK_GATE POLYLANE_FORK_PIDS
assert_ok "fork-during-capture-session-fenced" fence_owned_tmux_session
unset POLYLANE_PROCESS_TEST_BOUNDARY POLYLANE_PROCESS_TEST_BOUNDARY_HOOK
unset POLYLANE_FORK_HOOK_ONCE POLYLANE_FORK_GATE POLYLANE_FORK_PIDS
fork_child=$(sed -n '2p' "$FORK_PIDS")
assert_contains "post-snapshot-child-entered-stable-fence" "$fork_child|" \
  "$TMUX_FENCED_PROCESS_RECORDS"
assert_fail "forking-parent-gone-before-evidence" \
  polylane_process_identity_alive "$fork_parent" "$fork_parent_token"
assert_fail "post-snapshot-child-gone-before-evidence" kill -0 "$fork_child"

own_session "polylane-nogo-$$"; nogo_id=$TMUX_SESSION_ID
# Production invokes the fence only in the GO branch; NO_GO retains resumable panes/worktrees.
outcome=NO_GO; [ "$outcome" != GO ] || fence_owned_tmux_session
assert_ok "nogo-retains-owned-session" tmux has-session -t "$nogo_id"
tmux kill-session -t "$nogo_id"

own_session "polylane-stale-$$"; stale_id=$TMUX_SESSION_ID; stale_name=$TMUX_SESSION_NAME
tmux kill-session -t "$stale_id"
foreign_id=$(tmux new-session -d -P -F '#{session_id}' -s "$stale_name" /bin/sh)
tmux set-option -t "$foreign_id" @foreign_owner keep
assert_fail "stale-owned-id-cannot-prove-process-fence" fence_owned_tmux_session
assert_ok "foreign-replacement-remains" tmux has-session -t "$foreign_id"
assert_eq "foreign-replacement-untouched" keep \
  "$(tmux show-options -qv -t "$foreign_id" @foreign_owner)"
tmux kill-session -t "$foreign_id"

own_session "polylane-adopt-race-$$"; adopt_old_id=$TMUX_SESSION_ID
ADOPT_HOOK="$TEST_TMPDIR/adopt-race-hook"
cat > "$ADOPT_HOOK" <<'SH'
#!/usr/bin/env bash
set -eu
old_id=$2; name=$3
tmux kill-session -t "$old_id"
new_id=$(tmux new-session -d -P -F '#{session_id}' -s "$name" /bin/sh)
tmux set-option -t "$new_id" @foreign_owner keep
printf '%s\n' "$new_id" > "$POLYLANE_ADOPT_RACE_ID_FILE"
SH
chmod +x "$ADOPT_HOOK"
POLYLANE_ADOPT_RACE_ID_FILE="$TEST_TMPDIR/adopt-race-id"; export POLYLANE_ADOPT_RACE_ID_FILE
TMUX_SESSION=$TMUX_SESSION_NAME; SESSION_STARTED=0
adopt_out=$(POLYLANE_TMUX_TEST_BOUNDARY=before-adopt-attach \
  POLYLANE_TMUX_TEST_BOUNDARY_HOOK="$ADOPT_HOOK" new_pane race 2>&1); adopt_rc=$?
assert_eq "adoption-race-fails-closed" 2 "$adopt_rc"
adopt_foreign_id=$(cat "$POLYLANE_ADOPT_RACE_ID_FILE")
assert_fail "adoption-race-old-id-absent" tmux has-session -t "$adopt_old_id"
assert_ok "adoption-race-foreign-remains" tmux has-session -t "$adopt_foreign_id"
assert_eq "adoption-race-foreign-untouched" keep \
  "$(tmux show-options -qv -t "$adopt_foreign_id" @foreign_owner)"
assert_not_contains "adoption-race-no-attach" "tmux attach -t $TMUX_SESSION_NAME" "$adopt_out"
tmux kill-session -t "$adopt_foreign_id"
finish
```

Run: `bash -n core/tests/test-owned-session-cleanup.sh`.

Expected: exit 0. Same-second processes receive distinct high-resolution birth identities and a
prior token cannot authenticate a different PID. GO kills the captured owned ID plus an
HUP/TERM-ignoring detached descendant before sealing. That detached worker forks from its final
SIGCONT handler; the child inherits the worker's authenticated PGID, is discovered and STOPped
during TERM grace, enters the sealed inventory, and is killed. The deterministic process-snapshot
hook separately releases one fork only after the first descendant snapshot; stabilization captures,
STOPs, and fences that new child. NO_GO retains its session. A stale ID forces recovery, and same-name
replacements racing cleanup or pre-adoption attach are never killed, mutated, adopted, or advertised.

Create executable `core/tests/fixtures/final-launcher-contract.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$1; AGENT=$2; LAUNCH_SOURCE=$3; ADAPTER_SOURCE=$4
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
PKG="$TEST_TMPDIR/pkg"; REPO="$TEST_TMPDIR/repo"; mkdir -p "$PKG/scripts" "$REPO/.polylane"
cp "$LAUNCH_SOURCE" "$PKG/scripts/"
cp "$ADAPTER_SOURCE" "$PKG/scripts/"
cp "$ROOT/core/scripts/polylane-agent.sh" "$ROOT/core/scripts/polylane-fs.py" "$PKG/scripts/"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.email test@example.invalid
git -C "$REPO" config user.name Test
printf 'base\n' > "$REPO/base"; git -C "$REPO" add base; git -C "$REPO" commit -qm base
printf 'lane\n' > "$REPO/.polylane/lane.prompt"
printf 'integrate\n' > "$REPO/.polylane/integrator.prompt"
MANIFEST="$REPO/.polylane/run.json"; RUNTIME="$REPO/.polylane/runtime"
write_manifest() {
  jq -nS --arg agent "$AGENT" --arg lane "$REPO/.polylane/lane.prompt" \
    --arg integrator "$REPO/.polylane/integrator.prompt" \
    --arg lane_wt "$TEST_TMPDIR/wt-lane" --arg int_wt "$TEST_TMPDIR/wt-integrator" '
    {agent:$agent,loop_id:"launch-loop",cycle:1,run_id:"launch-run",base:"main",
     lanes:[{name:"lane",model:"m",effort:"high",branch:"lane/one",worktree:$lane_wt,
       prompt_file:$lane,own_globs:["one/**"]}],
     integrator:{name:"integrator",model:"m",effort:"high",branch:"lane/integrator",
       worktree:$int_wt,prompt_file:$integrator}}' > "$MANIFEST"
}
write_manifest
TMUX_LOG="$TEST_TMPDIR/tmux.log"; : > "$TMUX_LOG"; mkdir "$TEST_TMPDIR/bin"
cat > "$TEST_TMPDIR/bin/tmux" <<SH
#!/usr/bin/env bash
[ "\${1:-}" = has-session ] && exit 1
printf '%s\n' "\$*" >> "$TMUX_LOG"
exit 99
SH
chmod +x "$TEST_TMPDIR/bin/tmux"
cat > "$PKG/scripts/polylane-supervisor.sh" <<'SH'
#!/usr/bin/env bash
set -u
. "$(dirname "$0")/polylane-agent.sh"
polylane_validate_attempt_identity "$POLYLANE_RUNTIME_DIR" "$1" allocated || exit 91
printf '%s|%s|%s|%s\n' "$POLYLANE_AGENT" "$POLYLANE_CLAIM_TOKEN" \
  "$POLYLANE_RUNNER_GENERATION" "$POLYLANE_ATTEMPT" > "$CALLED"
SH
chmod +x "$PKG/scripts/"* "$TEST_TMPDIR/bin/tmux"
LAUNCH="$PKG/scripts/$(basename "$LAUNCH_SOURCE")"; CALLED="$TEST_TMPDIR/called"; export CALLED
run_launch() {
  PATH="$TEST_TMPDIR/bin:$PATH" POLYLANE_AGENT_CMD='mock {model} {prompt} {effort} {error_artifact}' \
    POLYLANE_MIN_DISK_KB=0 "$LAUNCH" "$1" --resume
}
assert_read_only_failure() {
  local name=$1 fixture=$2
  : > "$TMUX_LOG"; rm -f "$CALLED"
  assert_rc "$name" 2 run_launch "$fixture"
  assert_fail "$name-no-runtime" test -e "$RUNTIME"
  assert_fail "$name-no-worktree" test -e "$TEST_TMPDIR/wt-lane"
  assert_eq "$name-no-tmux-mutation" "" "$(cat "$TMUX_LOG")"
  assert_fail "$name-no-supervisor" test -e "$CALLED"
}
BAD="$REPO/.polylane/bad.json"
jq '.integrator={}' "$MANIFEST" > "$BAD"; assert_read_only_failure incomplete-integrator "$BAD"
jq '.lanes[0].prompt_file="/missing"' "$MANIFEST" > "$BAD"; assert_read_only_failure missing-prompt "$BAD"
: > "$REPO/.polylane/empty.prompt"
jq --arg prompt "$REPO/.polylane/empty.prompt" \
  '.integrator.prompt_file=$prompt' "$MANIFEST" > "$BAD"
assert_read_only_failure empty-prompt "$BAD"
mkdir "$TEST_TMPDIR/wt-lane"; : > "$TMUX_LOG"
assert_rc "existing-worktree" 2 run_launch "$MANIFEST"
assert_ok "existing-worktree-untouched" test -d "$TEST_TMPDIR/wt-lane"
assert_fail "existing-worktree-no-runtime" test -e "$RUNTIME"
assert_eq "existing-worktree-no-tmux-mutation" "" "$(cat "$TMUX_LOG")"
assert_fail "existing-worktree-no-supervisor" test -e "$CALLED"
rmdir "$TEST_TMPDIR/wt-lane"
jq --arg agent "wrong-$AGENT" '.agent=$agent' "$MANIFEST" > "$BAD"
assert_read_only_failure wrong-agent "$BAD"
: > "$TMUX_LOG"; assert_ok "valid-final-launcher" run_launch "$MANIFEST"
assert_contains "valid-agent-bound" "$AGENT|direct-launch-run|1|1" "$(cat "$CALLED")"
assert_ok "valid-owner-published" test -f \
  "$RUNTIME/cycle-results/launch-run.direct-launch-run.g1.a1.owner.json"
assert_eq "valid-preflight-no-tmux-mutation" "" "$(cat "$TMUX_LOG")"
finish
```

Replace `codex/tests/test-codex-launcher.sh` with:

```bash
#!/usr/bin/env bash
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
exec "$ROOT/core/tests/fixtures/final-launcher-contract.sh" "$ROOT" codex \
  "$ROOT/codex/scripts/polylane-codex.sh" "$ROOT/codex/scripts/polylane-codex-agent.sh"
```

Replace `claude-code/tests/test-claude-launcher.sh` with:

```bash
#!/usr/bin/env bash
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
exec "$ROOT/core/tests/fixtures/final-launcher-contract.sh" "$ROOT" claude \
  "$ROOT/claude-code/scripts/polylane-claude.sh" \
  "$ROOT/claude-code/scripts/polylane-claude-agent.sh"
```

These replacements are the final Task-3 fixtures; the initial minimal
manifests and exit-99 Git/tmux/CLI fakes are RED-only and must not survive Task 6.

Run:

```bash
bash -n core/tests/fixtures/final-launcher-contract.sh \
  codex/tests/test-codex-launcher.sh claude-code/tests/test-claude-launcher.sh
bash codex/tests/test-codex-launcher.sh
bash claude-code/tests/test-claude-launcher.sh
```

Expected: both final launchers pass complete planned preflight, then publish exactly one allocated
owner before supervisor execution. Incomplete integrator, missing prompt, existing worktree, and
wrong-agent fixtures leave runtime, worktrees, tmux, and supervisor untouched.

The runner integration hunk in Step 6 is the production assertion that cleanup executes after
promotion and before sidecar/GO publication; this unit test covers its immutable result boundary.

- [ ] **Step 11: Update legacy supervisor/pane tests without weakening coverage (4 minutes)**

Replace `core/tests/test-supervisor.sh` with:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
out=$(bash "$ROOT/core/tests/test-full-preflight-attempts.sh" 2>&1); rc=$?
assert_eq "recovery-contract-exit" 0 "$rc"
assert_contains "covers-preflight" "PASS missing-python3" "$out"
assert_contains "covers-generation" "PASS direct-generation-monotonic" "$out"
assert_contains "covers-restart" "PASS supervisor-two-identities" "$out"
assert_contains "covers-collision" "PASS collision-not-reused" "$out"
finish
```

Make this anchored negative edit to `core/tests/test-pane-errored.sh`:

```diff
diff --git a/core/tests/test-pane-errored.sh b/core/tests/test-pane-errored.sh
--- a/core/tests/test-pane-errored.sh
+++ b/core/tests/test-pane-errored.sh
@@
 not_errored "ok-benign-noise"    "compiling module 3 of 7"
+not_errored "ok-connector-auth"  "MCP server airtable: Missing Authorization header"
```

Expected: both files pass `bash -n`.

- [ ] **Step 12: Run focused recovery tests and verify GREEN (4 minutes)**

```bash
bash codex/tests/test-codex-errors.sh
bash core/tests/test-full-preflight-attempts.sh
bash core/tests/test-cleanup-result.sh
bash core/tests/test-owned-session-cleanup.sh
bash core/tests/test-recovery-handoff.sh
bash core/tests/test-supervisor.sh
bash core/tests/test-pane-errored.sh
bash codex/tests/test-codex-launcher.sh
bash claude-code/tests/test-claude-launcher.sh
```

Expected: all nine exit 0; recovery handoff reports cleanup-bound GO/NO_GO, crash restart
identity advancement, exit 75, read-only preflight failures, and collision burning.

- [ ] **Step 13: Run the aggregate suite (5 minutes)**

Run: `tests/run.sh`

Expected: exit 0 with zero failed test files.

- [ ] **Step 14: Commit structured recovery handoff (2 minutes)**

Run:

```bash
git add core/scripts/polylane-agent.sh core/scripts/polylane-run.sh \
  core/scripts/polylane-supervisor.sh core/tests \
  codex/scripts/polylane-codex-agent.sh codex/scripts/polylane-codex.sh \
  codex/tests/test-codex-errors.sh claude-code/scripts/polylane-claude-agent.sh \
  claude-code/scripts/polylane-claude.sh
git commit -m "fix(core): route exhausted failures to persistent recovery"
```

Expected: exit 0 with commit subject
`fix(core): route exhausted failures to persistent recovery`.

---

### Task 7: Make Docs and CI Codex-First and Prove One Real Cycle

**Files:**
- Modify: `README.md`, `.polylane/SCHEMA.md`, `.github/workflows/ci.yml`, `.gitignore`
- Create: `core/tests/test-platform-docs.sh`
- Create: `codex/scripts/polylane-codex-rehearse.sh`
- Create: `codex/tests/test-codex-rehearse.sh`
- Modify: `codex/references/codex-runtime.md`

**Interfaces:**
- Produces: a Codex-first quickstart and separate Claude compatibility section.
- Produces: gated `POLYLANE_CODEX_REHEARSE=1` one-cycle builder/integrator canary.

- [ ] **Step 1: Add the complete Codex-first documentation contract test (4 minutes)**

Create `core/tests/test-platform-docs.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
README=$(cat "$ROOT/README.md")
SCHEMA=$(cat "$ROOT/.polylane/SCHEMA.md")
CI=$(cat "$ROOT/.github/workflows/ci.yml")
assert_contains "codex-heading" "## Codex quickstart" "$README"
assert_contains "codex-install" "./codex/install.sh --user" "$README"
assert_contains "codex-launcher" "polylane-codex.sh" "$README"
assert_contains "stable-watch" 'tmux attach -t polylane-<loop-id>' "$README"
assert_contains "claude-section" "## Claude Code compatibility" "$README"
assert_contains "schema-agent" '"agent": "codex"' "$SCHEMA"
assert_contains "schema-loop" '"loop_id"' "$SCHEMA"
assert_contains "schema-cycle-result" 'cycle-results/' "$SCHEMA"
assert_contains "ci-suite" 'tests/run.sh' "$CI"
assert_contains "ci-core-syntax" 'core/scripts/*.sh' "$CI"
assert_contains "ci-codex-syntax" 'codex/scripts/*.sh' "$CI"
assert_contains "ci-claude-syntax" 'claude-code/scripts/*.sh' "$CI"
assert_contains "ci-shellcheck-warning" 'shellcheck -S warning' "$CI"
assert_not_contains "no-old-final-session" 'final command is `tmux attach -t polylane`' "$README"
finish
```

Run: `bash -n core/tests/test-platform-docs.sh`

Expected: exit 0; README/schema/CI assertions are syntactically valid before RED.

- [ ] **Step 2: Add the complete gated hermetic canary test (5 minutes)**

Create `codex/tests/test-codex-rehearse.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
DEST="$TEST_TMPDIR/installed-codex"
assert_ok "package-canary" "$ROOT/core/scripts/polylane-package.sh" codex "$DEST"
RH="$DEST/scripts/polylane-codex-rehearse.sh"
out=$("$RH" 2>&1); rc=$?
assert_eq "gated-off-rc" 0 "$rc"
assert_contains "gated-off-marker" CODEX-REHEARSE-SKIP "$out"
if ! command -v tmux >/dev/null 2>&1; then pass "mock-canary-skipped-no-tmux"; finish; exit 0; fi
MOCK="$TEST_TMPDIR/mock-agent.sh"
cat > "$MOCK" <<'SH'
#!/usr/bin/env bash
set -eu
prompt=$2
mkdir -p docs
case "$prompt" in
  *builder*)
    printf 'built\n' > built.txt; git add built.txt; git commit -qm builder
    { "$POLYLANE_MARKERS" done builder "$CANARY_RUN_ID"; echo; } > docs/status-builder.md
    printf 'STATUS: builder DONE run=%s\n' "$CANARY_RUN_ID" >> "$CANARY_MARKERS"
    ;;
  *integrator*)
    git merge --no-edit lane/builder >/dev/null
    { "$POLYLANE_MARKERS" done integrator "$CANARY_RUN_ID"; echo; } > docs/status-integrator.md
    { "$POLYLANE_MARKERS" verdict GO "$CANARY_RUN_ID"; echo; } > docs/verify-integration.md
    printf 'STATUS: integrator DONE run=%s\n' "$CANARY_RUN_ID" >> "$CANARY_MARKERS"
    ;;
esac
exec sleep 300
SH
chmod +x "$MOCK"
collision_id="foreign-$$"; collision_session="polylane-canary-$collision_id"
tmux new-session -d -s "$collision_session" /bin/sh
tmux set-option -t "$collision_session" @foreign_owner keep
collision_sid=$(tmux display-message -p -t "$collision_session" '#{session_id}')
collision_out=$(POLYLANE_CODEX_REHEARSE=1 POLYLANE_CODEX_REHEARSE_TIMEOUT=10 \
  POLYLANE_CODEX_REHEARSE_RUN_ID="$collision_id" POLYLANE_CODEX_MODEL=gpt-canary \
  POLYLANE_AGENT_CMD="$MOCK {model} {prompt} {effort} {error_artifact}" "$RH" 2>&1); collision_rc=$?
assert_eq "foreign-session-collision-fails" 2 "$collision_rc"
assert_ok "foreign-session-remains" tmux has-session -t "$collision_session"
assert_eq "foreign-session-id-unchanged" "$collision_sid" \
  "$(tmux display-message -p -t "$collision_session" '#{session_id}')"
assert_eq "foreign-session-options-untouched" keep \
  "$(tmux show-options -qv -t "$collision_session" @foreign_owner)"
tmux kill-session -t "$collision_session"
RACE_HOOK="$TEST_TMPDIR/tmux-boundary-hook"
cat > "$RACE_HOOK" <<'SH'
#!/usr/bin/env bash
set -eu
boundary=$1; old_id=$2; name=$3
tmux kill-session -t "$old_id"
tmux new-session -d -s "$name" /bin/sh
tmux set-option -t "=$name" @foreign_owner "foreign-$boundary"
tmux display-message -p -t "=$name" '#{session_id}' > "$TMUX_RACE_ID_FILE"
SH
chmod +x "$RACE_HOOK"
for boundary in after-create after-default-shell after-default-command after-run-id \
  after-loop-id after-claim after-generation; do
  race_id="race-${boundary//[^A-Za-z0-9]/}-$$"; race_session="polylane-canary-$race_id"
  TMUX_RACE_ID_FILE="$TEST_TMPDIR/race-id"; export TMUX_RACE_ID_FILE
  race_out=$(POLYLANE_CODEX_REHEARSE=1 POLYLANE_CODEX_REHEARSE_TIMEOUT=10 \
    POLYLANE_CODEX_REHEARSE_RUN_ID="$race_id" POLYLANE_CODEX_MODEL=gpt-canary \
    POLYLANE_TMUX_TEST_BOUNDARY="$boundary" POLYLANE_TMUX_TEST_BOUNDARY_HOOK="$RACE_HOOK" \
    POLYLANE_AGENT_CMD="$MOCK {model} {prompt} {effort} {error_artifact}" "$RH" 2>&1)
  race_rc=$?
  assert_eq "race-$boundary-fails-closed" 75 "$race_rc"
  foreign_id=$(cat "$TMUX_RACE_ID_FILE")
  assert_ok "race-$boundary-foreign-remains" tmux has-session -t "$foreign_id"
  assert_eq "race-$boundary-foreign-id-stable" "$foreign_id" \
    "$(tmux display-message -p -t "$foreign_id" '#{session_id}')"
  assert_eq "race-$boundary-no-foreign-option-mutation" "foreign-$boundary" \
    "$(tmux show-options -qv -t "$foreign_id" @foreign_owner)"
  assert_not_contains "race-$boundary-no-foreign-attach" "tmux attach -t $race_session" "$race_out"
  tmux kill-session -t "$foreign_id"
done
out=$(POLYLANE_CODEX_REHEARSE=1 POLYLANE_CODEX_REHEARSE_TIMEOUT=30 \
  POLYLANE_CODEX_MODEL=gpt-canary \
  POLYLANE_AGENT_CMD="$MOCK {model} {prompt} {effort} {error_artifact}" "$RH" 2>&1); rc=$?
assert_eq "mock-canary-rc" 0 "$rc"
assert_contains "mock-canary-go" CODEX-REHEARSE-GO "$out"
attach_count=$(printf '%s\n' "$out" | grep -c '^tmux attach -t polylane-canary-[A-Za-z0-9._-]*$' || true)
assert_eq "mock-canary-one-standalone-attach" 1 "$attach_count"
finish
```

Run: `bash -n codex/tests/test-codex-rehearse.sh`

Expected: exit 0; both disabled and installed-package mock-canary paths are syntactically
valid before RED.

- [ ] **Step 3: Run both tests and verify RED (3 minutes)**

```bash
bash core/tests/test-platform-docs.sh
bash codex/tests/test-codex-rehearse.sh
```

Expected: both exit nonzero because docs/CI remain Claude-first and the Codex canary does
not exist.

- [ ] **Step 4: Add the complete gated one-cycle Codex canary (5 minutes)**

Create executable `codex/scripts/polylane-codex-rehearse.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
BIN=$(cd "$(dirname "$0")" && pwd)
CORE=$BIN
[ -x "$CORE/polylane-markers.sh" ] && [ -x "$CORE/polylane-run.sh" ] && \
  [ -f "$CORE/polylane-fs.py" ] && [ ! -L "$CORE/polylane-fs.py" ] || {
  echo "CODEX-REHEARSE-FAIL installed shared core is incomplete" >&2
  exit 2
}
fs() { python3 "$CORE/polylane-fs.py" "$@"; }
private_from_stdin() { fs create "$1" "${2:-0600}"; }
if [ "${POLYLANE_CODEX_REHEARSE:-0}" != 1 ]; then
  echo "CODEX-REHEARSE-SKIP set POLYLANE_CODEX_REHEARSE=1 to run"
  exit 0
fi
command -v tmux >/dev/null 2>&1 || { echo "CODEX-REHEARSE-SKIP tmux unavailable"; exit 77; }
command -v git >/dev/null 2>&1 || { echo "CODEX-REHEARSE-FAIL git unavailable" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "CODEX-REHEARSE-FAIL jq unavailable" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "CODEX-REHEARSE-FAIL python3 unavailable" >&2; exit 2; }
timeout=${POLYLANE_CODEX_REHEARSE_TIMEOUT:-300}
case "$timeout" in ''|*[!0-9]*|0) echo "CODEX-REHEARSE-FAIL invalid timeout" >&2; exit 2 ;; esac

root=$(mktemp -d "${TMPDIR:-/tmp}/polylane-codex-rehearse.XXXXXX")
rid=${POLYLANE_CODEX_REHEARSE_RUN_ID:-rh-$$-$(date +%s)}; loop="canary-$rid"
case "$loop" in ''|*[!A-Za-z0-9._-]*) echo "CODEX-REHEARSE-FAIL unsafe loop id" >&2; exit 2 ;; esac
[ "${#loop}" -le 64 ] || { echo "CODEX-REHEARSE-FAIL loop id too long" >&2; exit 2; }
session="polylane-$loop"; session_owner="$root/canary-session-owner.json"
run_pid=""
kill_owned_session() {
  local id
  [ -f "$session_owner" ] && [ ! -L "$session_owner" ] || return 0
  [ "$(jq -r .run_id "$session_owner")" = "$rid" ] &&
    [ "$(jq -r .loop_id "$session_owner")" = "$loop" ] &&
    [ "$(jq -r .session "$session_owner")" = "$session" ] || return 1
  id=$(jq -r .tmux_session_id "$session_owner")
  if tmux has-session -t "$id" 2>/dev/null; then
    [ "$(tmux display-message -p -t "$id" '#{session_id}')" = "$id" ] && \
      [ "$(tmux display-message -p -t "$id" '#S')" = "$session" ] && \
      [ "$(tmux show-options -qv -t "$id" @polylane_run_id)" = "$rid" ] && \
      [ "$(tmux show-options -qv -t "$id" @polylane_loop_id)" = "$loop" ] || return 1
    tmux kill-session -t "$id"
  fi
}
cleanup() {
  [ -z "$run_pid" ] || { kill "$run_pid" 2>/dev/null || true; wait "$run_pid" 2>/dev/null || true; }
  kill_owned_session 2>/dev/null || true
  rm -rf "$root"
}
trap cleanup EXIT INT TERM

explicit=""
[ -z "${POLYLANE_AGENT_CMD:-}" ] || explicit=${POLYLANE_CODEX_MODEL:-gpt-canary}
if ! model=$($BIN/polylane-codex-model.sh resolve-model "$explicit"); then
  echo "CODEX-REHEARSE-ACTION configure a valid Codex model and login, then rerun" >&2
  exit 4
fi
effort=$($BIN/polylane-codex-model.sh resolve-effort "${POLYLANE_CODEX_EFFORT:-}" high)

git -C "$root" init -q -b main
git -C "$root" config user.email canary@example.invalid
git -C "$root" config user.name Polylane-Canary
printf 'seed\n' > "$root/seed.txt"
git -C "$root" add seed.txt; git -C "$root" commit -qm seed
seed=$(git -C "$root" rev-parse HEAD)
fs mkdirs "$root/.polylane/lanes" 0700
private_from_stdin "$root/.polylane/lanes/builder.txt" 0600 <<EOF
GOAL: prove one Codex builder cycle. OWN: built.txt docs/status-builder.md.
FORBIDDEN: every other path. Create built.txt, verify it, commit it, then run:
$CORE/polylane-markers.sh done builder $rid > docs/status-builder.md
The first line must be STATUS: builder DONE run=$rid.
EOF
private_from_stdin "$root/.polylane/lanes/integrator.txt" 0600 <<EOF
GOAL: integrate lane/builder. OWN: docs/status-integrator.md docs/verify-integration.md.
FORBIDDEN: widening scope. Merge lane/builder, verify built.txt, then run:
$CORE/polylane-markers.sh done integrator $rid > docs/status-integrator.md
$CORE/polylane-markers.sh verdict GO $rid > docs/verify-integration.md
EOF
private_from_stdin "$root/.polylane/run.json" 0600 <<EOF
{"agent":"codex","loop_id":"$loop","cycle":1,"run_id":"$rid","base":"main",
 "available_models":["$model"],
 "lanes":[{"name":"builder","model":"$model","effort":"$effort","branch":"lane/builder","worktree":"$root/wt-builder","prompt_file":"$root/.polylane/lanes/builder.txt","own_globs":["built.txt"]}],
 "integrator":{"name":"integrator","model":"$model","effort":"$effort","branch":"lane/integrator","worktree":"$root/wt-integrator","prompt_file":"$root/.polylane/lanes/integrator.txt"}}
EOF
fs copy-exclusive "$root/.polylane/run.json" "$root/canary-manifest.json" 0600

export CANARY_RUN_ID="$rid" CANARY_MARKERS="$root/canary-markers.log"
export POLYLANE_MARKERS="$CORE/polylane-markers.sh"
set +e
claim="canary-claim-$$"; generation=1; attempt=1
receipt="$root/.polylane/runtime/cycle-results/$rid.$claim.g$generation.a$attempt.json"
POLYLANE_SESSION="$session" POLYLANE_HOST_FD=9 POLYLANE_CYCLE_RESULT_RECEIPT="$receipt" \
  POLYLANE_CLAIM_TOKEN="$claim" POLYLANE_RUNNER_GENERATION="$generation" \
  POLYLANE_ATTEMPT="$attempt" POLYLANE_CYCLE_RUN_ID="$rid" \
  POLYLANE_MIN_DISK_GB=0 POLYLANE_MIN_DISK_KB=0 POLYLANE_POLL_INTERVAL=1 \
  POLYLANE_HEALTH_INTERVAL=2 "$BIN/polylane-codex.sh" \
  "$root/.polylane/run.json" --yes 9>&1 > "$root/canary.log" 2>&1 &
run_pid=$!; deadline=$(( $(date +%s) + timeout )); timed_out=0; attach_emitted=0
while kill -0 "$run_pid" 2>/dev/null; do
  if [ "$attach_emitted" = 0 ] && tmux has-session -t "$session" 2>/dev/null; then
    sid=$(tmux display-message -p -t "=$session" '#{session_id}')
    if [ "$(tmux display-message -p -t "$sid" '#{session_id}')" = "$sid" ] && \
      [ "$(tmux display-message -p -t "$sid" '#S')" = "$session" ] && \
      [ "$(tmux show-options -qv -t "$sid" @polylane_run_id)" = "$rid" ] && \
      [ "$(tmux show-options -qv -t "$sid" @polylane_loop_id)" = "$loop" ] && \
      [ "$(tmux show-options -qv -t "$sid" @polylane_claim_token)" = "$claim" ] && \
      [ "$(tmux show-options -qv -t "$sid" @polylane_runner_generation)" = "$generation" ]; then
      fs capture "$session_owner" 0400 jq -nS --arg run "$rid" --arg loop "$loop" \
        --arg session "$session" --arg sid "$sid" \
        '{run_id:$run,loop_id:$loop,session:$session,tmux_session_id:$sid}' || exit 74
      if [ "$(tmux display-message -p -t "$sid" '#{session_id}' 2>/dev/null || true)" = "$sid" ] && \
        [ "$(tmux display-message -p -t "$sid" '#S' 2>/dev/null || true)" = "$session" ] && \
        [ "$(tmux show-options -qv -t "$sid" @polylane_run_id 2>/dev/null || true)" = "$rid" ] && \
        [ "$(tmux show-options -qv -t "$sid" @polylane_loop_id 2>/dev/null || true)" = "$loop" ] && \
        [ "$(tmux show-options -qv -t "$sid" @polylane_claim_token 2>/dev/null || true)" = "$claim" ] && \
        [ "$(tmux show-options -qv -t "$sid" @polylane_runner_generation 2>/dev/null || true)" = \
          "$generation" ]; then
        attach_emitted=1
      else
        fs unlink-private "$session_owner" || exit 74
      fi
    fi
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    timed_out=1; kill "$run_pid" 2>/dev/null || true; sleep 1
    kill -9 "$run_pid" 2>/dev/null || true; break
  fi
  sleep 1
done
wait "$run_pid"; rc=$?; run_pid=""
set -e
if [ "$timed_out" = 1 ]; then
  cat "$root/canary.log" >&2
  echo "CODEX-REHEARSE-FAIL deadline exceeded after ${timeout}s" >&2
  exit 124
fi
if [ "$rc" != 0 ]; then
  cat "$root/canary.log" >&2
  echo "CODEX-REHEARSE-ACTION verify Codex authentication/model access, then rerun" >&2
  exit "$rc"
fi
[ "$attach_emitted" = 1 ] || { echo "CODEX-REHEARSE-FAIL session never became watchable" >&2; exit 1; }

grep -qx "STATUS: builder DONE run=$rid" "$CANARY_MARKERS"
grep -qx "STATUS: integrator DONE run=$rid" "$CANARY_MARKERS"
result="$receipt"
[ "$(jq -r .schema_version "$result")" = 2 ]
[ "$(jq -r .run_id "$result")" = "$rid" ]
[ "$(jq -r .outcome "$result")" = GO ]
[ "$(jq -r .base_ref "$result")" = main ]
[ "$(jq -r .integration_commit "$result")" = "$(git -C "$root" rev-parse HEAD)" ]
[ "$(case "$(uname -s)" in Linux) stat -c '%a' "$result" ;; *) stat -f '%Lp' "$result" ;; esac)" = 400 ]
POLYLANE_REPO_ROOT="$root" bash -c '. "$1"; polylane_validate_cycle_result "$2" "$3" "$4"' _ \
  "$CORE/polylane-agent.sh" "$result" "$root/canary-manifest.json" "$root"
head=$(git -C "$root" rev-parse HEAD); [ "$head" != "$seed" ]
[ "$(git -C "$root" show HEAD:built.txt)" = built ]
[ -z "$(git -C "$root" branch --list 'lane/*')" ]
[ "$(git -C "$root" worktree list --porcelain | grep -c '^worktree ')" = 1 ]
! tmux has-session -t "$(jq -r .tmux_session_id "$session_owner")" 2>/dev/null
kill_owned_session
! tmux has-session -t "$session" 2>/dev/null
echo "CODEX-REHEARSE-GO run=$rid promoted=$head"
```

Run: `chmod +x codex/scripts/polylane-codex-rehearse.sh`

Expected: `bash -n codex/scripts/polylane-codex-rehearse.sh` exits 0.

- [ ] **Step 5: Make README Codex-first with an explicit Claude compatibility section (5 minutes)**

Make these anchored edits to `README.md`:

```diff
diff --git a/README.md b/README.md
--- a/README.md
+++ b/README.md
@@
-**Describe what you want in plain English. polylane strategizes it with you, splits it into file-isolated lanes, builds them in parallel Claude Code (or GPT/aider) terminals, merges on GO, reports, researches the next step, and keeps going — one autonomous loop toward your goal.**
+**Describe what you want in plain English. Polylane strategizes it, splits it into file-isolated lanes, builds them in supervised Codex tmux panes, and promotes only a verified GO.**
@@
-`polylane` is **one** [Claude Code](https://docs.claude.com/en/docs/claude-code) skill. Give it a goal — or even a vague one-line app idea — and it runs a product-discovery interview (numerous easy recommended-default questions + research) to strategize *with* you, locks a strategy + goal tree, then loops: derive the *right* number of file-isolated lanes from how the code actually overlaps → build them in parallel → merge on GO → **~50-bullet report** → deep-research the next step → **ensemble critic** → questions → repeat, until a critic judges the goal met or you stop.
+`polylane` ships a Codex-first skill plus a separate Claude Code compatibility distribution.
@@
-You stay in the loop for **decisions only** — a handful of click-through questions with recommended defaults. Everything else is derived, generated, launched, verified, merged, and cleaned up for you. It's resumable across conversations, budget-capped, and self-recovers from stalls, dead panes, and never-started workers.
+You stay in the loop for decisions only. Everything else is derived, launched, verified, promoted, and recovered from durable state.
@@
-## Quickstart
+## Codex quickstart
+
+```bash
+git clone https://github.com/GHGuide/polylane
+cd polylane
+./codex/install.sh --user
+brew install tmux jq   # Debian/Ubuntu: apt-get install -y tmux jq
+```
+
+Start Codex in the project and ask: `Use $polylane to build this project autonomously`.
+The fail-closed entry is `scripts/polylane-codex.sh`; the stable persistent watch command
+is `tmux attach -t polylane-<loop-id>`.
+
+## Claude Code compatibility
```

Expected: the first installation section is Codex and the historical Claude instructions
remain under their own heading.

- [ ] **Step 6: Document exact manifest/result fields and static CI coverage (5 minutes)**

Make these anchored edits:

```diff
diff --git a/.polylane/SCHEMA.md b/.polylane/SCHEMA.md
--- a/.polylane/SCHEMA.md
+++ b/.polylane/SCHEMA.md
@@
 {
+  "agent": "codex",
+  "loop_id": "loop-20260717-1",
+  "cycle": 1,
+  "run_id": "cycle-1-nonce",
   "base": "main",
@@
 | Key | Type | Meaning |
 |---|---|---|
+| `loop_id` | string | Stable persistent-loop identity. |
+| `cycle` | integer | Monotonic cycle number within the loop. |
+| `run_id` | string | Unique nonce required on every DONE/verdict/result. |
@@
+## Raw cycle results: `.polylane/runtime/cycle-results/`
+
+Each claim-unique, mode-0400 schema-v2 object contains `run_id`, manifest SHA-256,
+`outcome`, `verdict`, `base_ref`, `expected_base`, exact `lane_commits`, and
+`integration_commit`. `outcome` is exactly `GO`, `NO_GO`, or `RECOVERY_REQUIRED`.
+The persistent Runtime validates and content-addresses this raw result, then binds it to
+the active queue claim and authoritative runner identity; consumers never trust a mutable
+singleton or report timestamp.
diff --git a/.github/workflows/ci.yml b/.github/workflows/ci.yml
--- a/.github/workflows/ci.yml
+++ b/.github/workflows/ci.yml
@@
-      - name: Shellcheck all helpers
+      - name: Syntax and shellcheck all package scripts
         run: |
           rc=0
-          for f in bin/*.sh; do shellcheck -S warning "$f" || rc=1; done
+          for f in core/scripts/*.sh codex/scripts/*.sh codex/install.sh \
+                   claude-code/scripts/*.sh claude-code/install.sh tests/run.sh; do
+            bash -n "$f" || rc=1
+            shellcheck -S warning "$f" || rc=1
+          done
           exit $rc
@@
       - name: Run the test suite
-        run: tests/run.sh
+        run: ./tests/run.sh
diff --git a/.gitignore b/.gitignore
--- a/.gitignore
+++ b/.gitignore
@@
 docs/lane-logs/
+.codex/skills/*.polylane-releases/
+.codex/skills/*.polylane-lock/
+.claude/skills/*.polylane-releases/
+.claude/skills/*.polylane-lock/
+*.polylane-maintenance.json
```

Expected: workflow YAML retains both OS matrix entries and runs syntax, warning-level
shellcheck, and the root aggregate suite.

- [ ] **Step 7: Add the live-canary operation to the Codex runtime reference (3 minutes)**

Make this anchored edit:

```diff
diff --git a/codex/references/codex-runtime.md b/codex/references/codex-runtime.md
--- a/codex/references/codex-runtime.md
+++ b/codex/references/codex-runtime.md
@@
 A missing login or organization permission is reported as user-action evidence only after internal alternatives are exhausted.
+
+Run the live one-cycle foundation gate with
+`POLYLANE_CODEX_REHEARSE=1 scripts/polylane-codex-rehearse.sh`. Success prints
+`CODEX-REHEARSE-GO`. If authentication or model access is unavailable, preserve the exact
+`CODEX-REHEARSE-ACTION` line and do not report the live gate as passed.
```

Expected: reference remains under 100 lines and contains the gated live command.

- [ ] **Step 8: Run the focused documentation and hermetic canary tests and verify GREEN (3 minutes)**

```bash
bash core/tests/test-platform-docs.sh
bash codex/tests/test-codex-rehearse.sh
```

Expected: both exit 0. The canary test first reports `CODEX-REHEARSE-SKIP` with the
gate disabled, then its mock run reports `CODEX-REHEARSE-GO` when tmux is available.

- [ ] **Step 9: Run the aggregate suite and all static shell checks (5 minutes)**

```bash
POLYLANE_MIN_DISK_GB=0 tests/run.sh
for file in core/scripts/*.sh codex/scripts/*.sh codex/install.sh \
            claude-code/scripts/*.sh claude-code/install.sh tests/run.sh; do
  bash -n "$file"
  shellcheck -S warning "$file"
done
```

Expected: the aggregate suite exits 0, every `bash -n` exits 0, and every warning-level
shellcheck exits 0 on both CI operating systems.

- [ ] **Step 10: Run exactly one live Codex builder/integrator cycle (5 minutes)**

```bash
(
  set -e
  CANARY_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/polylane-live-canary.XXXXXX")
  trap 'rm -rf "$CANARY_ROOT"' EXIT
  core/scripts/polylane-package.sh codex "$CANARY_ROOT/polylane"
  POLYLANE_CODEX_REHEARSE=1 \
    "$CANARY_ROOT/polylane/scripts/polylane-codex-rehearse.sh"
)
```

Expected: a successful authenticated run prints `CODEX-REHEARSE-GO`, promotes one builder
commit through the integrator using only the installed package's shared core, writes a
matching GO cycle result, and leaves no lane branch or worktree. If authentication or model
access is unavailable, preserve the exact
`CODEX-REHEARSE-ACTION` line and do not claim that this live gate passed.

- [ ] **Step 11: Commit the verified foundation without installing the user skill (2 minutes)**

```bash
git add README.md .polylane/SCHEMA.md .github/workflows/ci.yml .gitignore \
  core/tests/test-platform-docs.sh codex/scripts/polylane-codex-rehearse.sh \
  codex/tests/test-codex-rehearse.sh codex/references/codex-runtime.md
git commit -m "test(codex): prove the tmux package foundation"
```

Expected: exit 0 with commit subject `test(codex): prove the tmux package foundation`.
Do not run `./codex/install.sh --user`; the autonomy plan owns final active installation
after the complete workflow passes.
