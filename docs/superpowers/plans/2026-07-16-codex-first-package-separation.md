# Codex-First Package Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split Polylane into one shared core plus Codex and Claude Code adapters, and prove that the Codex adapter launches real Codex CLI workers through tmux without requiring Claude.

**Architecture:** Move platform-neutral scripts, references, assets, workflow rules, and tests under `core/`. Keep platform entry skills, launchers, installers, and adapter tests under `codex/` and `claude-code/`; temporary root links preserve existing Claude Code paths. Both installers assemble from identical core contents, while the Codex launcher enforces `agent: codex` and delegates to the shared supervisor.

**Tech Stack:** Bash 3.2, tmux, jq, git worktrees, Codex CLI, Claude Code compatibility, Markdown skills, GitHub Actions on Ubuntu and macOS.

## Global Constraints

- Core implementation has exactly one canonical source under `core/`.
- Codex is the primary development, documentation, and live-verification target.
- Claude Code is migrated and compatibility-tested, not redesigned.
- Codex workers run only through tmux panes managed by the shared supervisor and runner.
- Codex must not require `claude`, discover Polylane helpers through `PATH`, or fall back to `~/.claude`.
- The Codex launcher fails before worktree or tmux side effects when manifest agent identity is missing or conflicting.
- Codex prompts use stdin and receive the selected model and reasoning effort.
- Root `SKILL.md`, `bin/`, `scripts/`, `references/`, `assets/`, and `tests/run.sh` remain compatibility entrypoints.
- Every behavior change follows red-green-refactor and every task ends with an independently testable commit.
- Never auto-purchase credits, bypass account restrictions, or accept a lane without its DONE marker.

## Final File Map

- `core/scripts/` — runner, supervisor, doctor, packaging, state, merge, and all shared helpers.
- `core/workflow/polylane-loop.md` — common autonomous loop using platform hooks.
- `core/references/` and `core/assets/` — shared knowledge and assets.
- `core/tests/` — shared engine tests and mock tmux rehearsals.
- `codex/` — Codex skill, launcher, installer, runtime references, adapter tests, and live canary.
- `claude-code/` — Claude Code skill, installer, runtime references, and compatibility tests.
- Root links/wrappers — one-release compatibility surface pointing at the canonical core.

---

### Task 1: Establish the Shared Agent Contract and Modern Codex Command

**Files:**
- Create: `bin/polylane-agent.sh`
- Create: `tests/test-agent-preflight.sh`
- Modify: `bin/polylane-run.sh:99-110,188-218,503-548`
- Modify: `bin/polylane-doctor.sh:59-80,286-319`
- Modify: `tests/helpers.sh:20-35`
- Modify: `tests/test-agent-adapter.sh`
- Modify: `tests/test-doctor.sh`

**Interfaces:**
- Produces: `polylane_agent_from_manifest <manifest>`, `polylane_agent_cli <agent>`, `polylane_agent_template <agent>`, and `polylane_agent_processes <agent>`.
- Produces template placeholders `{model}`, `{prompt}`, and optional `{effort}`.
- Preserves `POLYLANE_AGENT_CMD` precedence and existing Claude/aider templates.

- [ ] **Step 1: Add negative assertions and failing Codex command expectations**

Add to `tests/helpers.sh`:

```bash
assert_not_contains() {
  if printf '%s' "$3" | grep -qF "$2"; then
    fail "$1" "output unexpectedly contains [$2]"
  else
    pass "$1"
  fi
}
```

Replace the Codex command assertions in `tests/test-agent-adapter.sh` with:

```bash
AGENT=codex
CMD=$(pane_cmd /tmp/wt gpt-5-codex /tmp/p.txt high)
assert_contains "panecmd-codex" "codex exec" "$CMD"
assert_contains "panecmd-sandbox" "--sandbox workspace-write" "$CMD"
assert_contains "panecmd-model" "--model gpt-5-codex" "$CMD"
assert_contains "panecmd-effort" "model_reasoning_effort=high" "$CMD"
assert_contains "panecmd-stdin" "- < /tmp/p.txt" "$CMD"
assert_not_contains "panecmd-no-cat" '$(cat /tmp/p.txt)' "$CMD"
assert_not_contains "panecmd-no-legacy" "--full-auto" "$CMD"
```

- [ ] **Step 2: Run the adapter test and verify RED**

Run: `bash tests/test-agent-adapter.sh`

Expected: the sandbox, effort, stdin, no-cat, and no-legacy assertions fail because the current template still uses `--full-auto` and command substitution.

- [ ] **Step 3: Write the failing pure agent contract test**

Create `tests/test-agent-preflight.sh`:

```bash
#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$(cd "$(dirname "$RUNNER")" && pwd)/polylane-agent.sh"
make_tmpdir
printf '%s\n' '{"agent":"codex"}' > "$TEST_TMPDIR/codex.json"
printf '%s\n' '{"agent":"claude"}' > "$TEST_TMPDIR/claude.json"
unset POLYLANE_AGENT POLYLANE_AGENT_CMD
assert_eq "manifest-codex" "codex" "$(polylane_agent_from_manifest "$TEST_TMPDIR/codex.json")"
assert_eq "manifest-claude" "claude" "$(polylane_agent_from_manifest "$TEST_TMPDIR/claude.json")"
POLYLANE_AGENT=codex
assert_eq "env-wins" "codex" "$(polylane_agent_from_manifest "$TEST_TMPDIR/claude.json")"
unset POLYLANE_AGENT
assert_eq "cli-codex" "codex" "$(polylane_agent_cli codex)"
assert_eq "cli-gpt" "codex" "$(polylane_agent_cli gpt)"
assert_eq "cli-claude" "claude" "$(polylane_agent_cli claude)"
assert_eq "cli-aider" "aider" "$(polylane_agent_cli aider)"
assert_fail "cli-unknown" polylane_agent_cli unknown
finish
```

- [ ] **Step 4: Run the pure test and verify RED**

Run: `bash tests/test-agent-preflight.sh`

Expected: shell error because `bin/polylane-agent.sh` does not exist.

- [ ] **Step 5: Implement `bin/polylane-agent.sh`**

```bash
#!/usr/bin/env bash
polylane_agent_from_manifest() {
  if [ -n "${POLYLANE_AGENT:-}" ]; then printf '%s' "$POLYLANE_AGENT"
  else jq -r '.agent // "claude"' "$1"; fi
}
polylane_agent_cli() {
  case "$1" in
    claude) printf claude ;;
    codex|gpt|openai) printf codex ;;
    aider) printf aider ;;
    *) return 2 ;;
  esac
}
polylane_agent_template() {
  local agent="$1" pmode="${POLYLANE_PERMISSION_MODE:-acceptEdits}"
  if [ -n "${POLYLANE_AGENT_CMD:-}" ]; then printf '%s' "$POLYLANE_AGENT_CMD"; return; fi
  case "$agent" in
    claude) printf 'claude --permission-mode %s --model {model} "$(cat {prompt})"' "$(printf '%q' "$pmode")" ;;
    codex|gpt|openai) printf 'codex exec --sandbox workspace-write --model {model} -c model_reasoning_effort={effort} - < {prompt}' ;;
    aider) printf 'aider --model {model} --message-file {prompt} --yes-always --no-auto-commits' ;;
    *) return 2 ;;
  esac
}
polylane_agent_processes() {
  case "$1" in
    claude) printf 'claude node' ;;
    codex|gpt|openai) printf 'codex node' ;;
    aider) printf 'aider python python3' ;;
    *) printf 'claude node codex aider python python3' ;;
  esac
}
```

- [ ] **Step 6: Wire runner and doctor to the shared contract**

Source `polylane-agent.sh` beside both scripts. Make runner preflight validate the manifest first, select its agent, and require `tmux jq git` plus only that agent CLI; skip CLI inference for a custom command. Delegate template/process selection to the library. In `pane_cmd`, default empty Codex effort to `medium`, quote it, and replace `{effort}`.

Move doctor manifest resolution before dependency checks and make it report `dep: codex` for a Codex manifest. Add these assertions to `tests/test-doctor.sh` after adding `"agent":"codex"` to its good fixture:

```bash
assert_contains "deps-selected-codex" "dep: codex" "$good_out"
assert_not_contains "deps-no-claude" "dep: claude" "$good_out"
```

- [ ] **Step 7: Run focused and full tests**

```bash
bash tests/test-agent-preflight.sh
bash tests/test-agent-adapter.sh
bash tests/test-doctor.sh
tests/run.sh
```

Expected: every command exits 0 and the suite summary has zero failures.

- [ ] **Step 8: Commit**

```bash
git add bin/polylane-agent.sh bin/polylane-run.sh bin/polylane-doctor.sh \
  tests/helpers.sh tests/test-agent-preflight.sh tests/test-agent-adapter.sh tests/test-doctor.sh
git commit -m "fix(core): make agent execution adapter-aware"
```

---

### Task 2: Extract the Canonical Core and Preserve Root Paths

**Files:**
- Create: `codex/tests/test-repository-layout.sh`
- Move: `bin/` → `core/scripts/`
- Move: `references/` → `core/references/`
- Move: `assets/` → `core/assets/`
- Move: existing engine tests → `core/tests/`
- Replace: `tests/run.sh`
- Create links: `bin`, `scripts`, `references`, `assets`
- Modify: `core/tests/helpers.sh`

**Interfaces:**
- Produces canonical shared paths under `core/`.
- Preserves all existing root helper and reference paths.

- [ ] **Step 1: Write the failing layout test**

Create `codex/tests/test-repository-layout.sh`:

```bash
#!/usr/bin/env bash
ROOT=$(cd "$(dirname "$0")/../.." && pwd); fail=0
check_dir(){ [ -d "$ROOT/$1" ] || { echo "FAIL missing $1"; fail=1; }; }
check_link(){ [ -L "$ROOT/$1" ] && [ "$(readlink "$ROOT/$1")" = "$2" ] || { echo "FAIL link $1"; fail=1; }; }
for d in core/scripts core/references core/assets core/tests claude-code; do check_dir "$d"; done
check_link bin core/scripts
check_link scripts core/scripts
check_link references core/references
check_link assets core/assets
[ "$fail" = 0 ] && echo "PASS repository-layout"
exit "$fail"
```

- [ ] **Step 2: Run it and verify RED**

Run: `bash codex/tests/test-repository-layout.sh`

Expected: failures for absent core directories, Claude adapter, and links.

- [ ] **Step 3: Move files and create relative links**

```bash
mkdir -p core claude-code core/tests
git mv bin core/scripts
git mv references core/references
git mv assets core/assets
git mv tests/helpers.sh tests/fixtures tests/test-*.sh core/tests/
ln -s core/scripts bin
ln -s core/scripts scripts
ln -s core/references references
ln -s core/assets assets
```

Change `core/tests/helpers.sh` to `RUNNER="$TESTS_DIR/../scripts/polylane-run.sh"`; keep fixtures beside it.

- [ ] **Step 4: Replace root test aggregation**

Write `tests/run.sh` as:

```bash
#!/usr/bin/env bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
total_pass=0 total_fail=0 files=0 failed_files=""
for suite in "$ROOT/core/tests" "$ROOT/codex/tests" "$ROOT/claude-code/tests"; do
  [ -d "$suite" ] || continue
  for t in "$suite"/test-*.sh; do
    [ -f "$t" ] || continue
    files=$((files + 1)); name="${t#$ROOT/}"
    echo "== $name =="
    out=$("${BASH:-bash}" "$t" 2>&1); rc=$?
    printf '%s\n' "$out"
    p=$(printf '%s\n' "$out" | grep -c '^PASS ')
    f=$(printf '%s\n' "$out" | grep -c '^FAIL ')
    total_pass=$((total_pass + p)); total_fail=$((total_fail + f))
    if [ "$rc" -ne 0 ] || [ "$f" -gt 0 ]; then failed_files="$failed_files $name"; fi
    echo
  done
done
echo "SUMMARY: $total_pass passed, $total_fail failed, $files test files"
[ "$files" -gt 0 ] && [ -z "$failed_files" ]
```

- [ ] **Step 5: Verify layout, compatibility, and suite**

```bash
bash codex/tests/test-repository-layout.sh
bin/polylane-run.sh --help
tests/run.sh
```

Expected: layout PASS, root help exit 0, and zero suite failures.

- [ ] **Step 6: Commit**

```bash
git add core codex/tests/test-repository-layout.sh claude-code tests/run.sh \
  bin scripts references assets
git commit -m "refactor: extract shared core and platform boundaries"
```

---

### Task 3: Add the Fail-Closed Codex Launcher

**Files:**
- Create: `codex/scripts/polylane-codex.sh`
- Create: `codex/tests/test-codex-launcher.sh`
- Modify: `core/tests/test-supervisor.sh`

**Interfaces:**
- Produces `polylane-codex.sh <manifest> [runner args...]`.
- Consumes the shared supervisor either beside an installed launcher or under `../../core/scripts` in the source tree.
- Guarantees `.agent == "codex"` and `POLYLANE_AGENT=codex` on initial launch and every resume.

- [ ] **Step 1: Write the failing launcher test**

Create `codex/tests/test-codex-launcher.sh`:

```bash
#!/usr/bin/env bash
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
LAUNCH="$ROOT/codex/scripts/polylane-codex.sh"
make_tmpdir
mkdir -p "$TEST_TMPDIR/scripts"
[ -f "$LAUNCH" ] && cp "$LAUNCH" "$TEST_TMPDIR/scripts/"
cat > "$TEST_TMPDIR/scripts/polylane-supervisor.sh" <<'SH'
#!/usr/bin/env bash
printf 'agent=%s args=%s\n' "${POLYLANE_AGENT:-}" "$*" > "$(dirname "$1")/called"
SH
chmod +x "$TEST_TMPDIR/scripts/"*.sh
printf '%s\n' '{}' > "$TEST_TMPDIR/missing.json"
printf '%s\n' '{"agent":"claude"}' > "$TEST_TMPDIR/wrong.json"
printf '%s\n' '{"agent":"codex"}' > "$TEST_TMPDIR/good.json"
assert_rc "missing-agent" 2 "$TEST_TMPDIR/scripts/polylane-codex.sh" "$TEST_TMPDIR/missing.json"
assert_rc "wrong-agent" 2 "$TEST_TMPDIR/scripts/polylane-codex.sh" "$TEST_TMPDIR/wrong.json"
assert_ok "good-agent" "$TEST_TMPDIR/scripts/polylane-codex.sh" "$TEST_TMPDIR/good.json" --resume
called=$(cat "$TEST_TMPDIR/called")
assert_contains "env-forced" "agent=codex" "$called"
assert_contains "args-forwarded" "--resume" "$called"
finish
```

- [ ] **Step 2: Run it and verify RED**

Run: `bash codex/tests/test-codex-launcher.sh`

Expected: missing launcher failures.

- [ ] **Step 3: Implement the launcher**

Create `codex/scripts/polylane-codex.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
MANIFEST="${1:?usage: polylane-codex.sh <manifest.json> [runner args...]}"; shift || true
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
for dep in jq tmux git; do
  command -v "$dep" >/dev/null 2>&1 || { echo "polylane-codex: missing required dependency: $dep" >&2; exit 1; }
done
if [ -z "${POLYLANE_AGENT_CMD:-}" ]; then
  command -v codex >/dev/null 2>&1 || { echo "polylane-codex: codex CLI not found" >&2; exit 1; }
fi
[ -f "$MANIFEST" ] && jq empty "$MANIFEST" 2>/dev/null || { echo "polylane-codex: invalid manifest: $MANIFEST" >&2; exit 2; }
agent=$(jq -r 'if has("agent") then .agent else "" end' "$MANIFEST")
[ "$agent" = codex ] || { echo "polylane-codex: manifest agent must be exactly 'codex' (got '${agent:-missing}')" >&2; exit 2; }
if [ -x "$SCRIPT_DIR/polylane-supervisor.sh" ]; then CORE_BIN="$SCRIPT_DIR"
else CORE_BIN=$(cd "$SCRIPT_DIR/../../core/scripts" && pwd); fi
[ -x "$CORE_BIN/polylane-supervisor.sh" ] || { echo "polylane-codex: shared supervisor not found" >&2; exit 1; }
export POLYLANE_AGENT=codex
exec "$CORE_BIN/polylane-supervisor.sh" "$MANIFEST" "$@"
```

- [ ] **Step 4: Prove supervisor restart preserves identity**

Change the fake runner in `core/tests/test-supervisor.sh` to log:

```bash
echo "AGENT: ${POLYLANE_AGENT:-unset} ARGS: $*" >> "$D/calls.log"
```

Run its crash/revive case with `POLYLANE_AGENT=codex`, then assert every call contains `AGENT: codex`.

- [ ] **Step 5: Run tests and commit**

```bash
bash codex/tests/test-codex-launcher.sh
bash core/tests/test-supervisor.sh
git add codex/scripts/polylane-codex.sh codex/tests/test-codex-launcher.sh core/tests/test-supervisor.sh
git commit -m "feat(codex): enforce identity before tmux launch"
```

Expected: both tests exit 0 before the commit.

---

### Task 4: Classify Codex Failures Without Blind Retries or Spending

**Files:**
- Create: `codex/tests/test-codex-errors.sh`
- Modify: `core/scripts/polylane-agent.sh`
- Modify: `core/scripts/polylane-run.sh:681-724,837-1068,1440-1465`
- Modify: `core/tests/test-pane-errored.sh`

**Interfaces:**
- Produces `polylane_agent_critical_pattern <agent>`, `pane_critical <idx>`, and `CRITICAL_LANES`.
- Codex limits stall, critical account/model/auth failures stop without respawn, and only transient service/network failures retry.

- [ ] **Step 1: Write failing classification tests**

Create `codex/tests/test-codex-errors.sh` and initialize its fake pane with:

```bash
#!/usr/bin/env bash
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
. "$RUNNER"
make_tmpdir
mkdir -p "$TEST_TMPDIR/bin"
cat > "$TEST_TMPDIR/bin/tmux" <<'SHIM'
#!/bin/sh
cat "$FAKE_PANE_TEXT_FILE"
SHIM
chmod +x "$TEST_TMPDIR/bin/tmux"
PATH="$TEST_TMPDIR/bin:$PATH"
export FAKE_PANE_TEXT_FILE="$TEST_TMPDIR/pane.txt"
AGENT=codex
```

It must classify:

```text
critical: ERROR: Codex is not logged in. Run codex login.
critical: ERROR: The 'x' model is not supported with this account.
critical: ERROR: account is disabled.
transient: upstream service overloaded.
transient: 503 service unavailable.
stalled: 429 Too Many Requests.
stalled: rate limit reached; retry after quota reset.
clean: MCP server airtable: Missing Authorization header.
```

The clean connector-warning case prevents a false critical stop caused by an unrelated MCP login.

Use these concrete helpers after creating a fake `tmux` executable that prints `$FAKE_PANE_TEXT_FILE` and sourcing the shared runner with `AGENT=codex`:

```bash
put(){ printf '%s\n' "$2" > "$FAKE_PANE_TEXT_FILE"; }
critical(){ put "$@"; assert_ok "$1" pane_critical 0; assert_fail "$1-not-transient" pane_errored 0; }
transient(){ put "$@"; assert_ok "$1" pane_errored 0; assert_fail "$1-not-critical" pane_critical 0; }
stalled(){ put "$@"; assert_ok "$1" pane_stalled 0; assert_fail "$1-not-transient" pane_errored 0; }
clean(){ put "$@"; assert_fail "$1-not-critical" pane_critical 0; assert_fail "$1-not-transient" pane_errored 0; }
critical critical-login "ERROR: Codex is not logged in. Run codex login."
critical critical-model "ERROR: The x model is not supported with this account."
critical critical-account "ERROR: account is disabled."
transient transient-overload "upstream service overloaded."
transient transient-503 "503 service unavailable."
stalled stalled-429 "429 Too Many Requests."
stalled stalled-rate "rate limit reached; retry after quota reset."
clean mcp-auth-noise "MCP server airtable: Missing Authorization header."
finish
```

- [ ] **Step 2: Run it and verify RED**

Run: `bash codex/tests/test-codex-errors.sh`

Expected: absent `pane_critical` failures and current rate-limit/transient misclassification.

- [ ] **Step 3: Add agent-specific critical patterns**

Add to `core/scripts/polylane-agent.sh`:

```bash
polylane_agent_critical_pattern() {
  case "$1" in
    codex|gpt|openai)
      printf '%s' 'Codex is not logged in|codex login|model .* is not supported|invalid model|account (is )?(disabled|suspended)|OpenAI authentication failed'
      ;;
    claude) printf '%s' 'authentication_error|invalid API key|account (is )?(disabled|suspended)' ;;
    *) printf '%s' 'authentication failed|account (is )?(disabled|suspended)' ;;
  esac
}
```

Implement `pane_critical` by capturing the pane once and applying only this selected-agent pattern. Never add the generic phrase `Missing Authorization`.

- [ ] **Step 4: Separate limits from transient failures**

Remove `rate.?limit` from `pane_errored`. Extend `pane_stalled` with:

```text
usage limit|Switch to usage credits|Upgrade your plan|429 Too Many Requests|rate.?limit|quota.*(reset|exceeded)
```

When `POLYLANE_ON_LIMIT` is unset, choose `wait` for Codex and preserve `fallback` for Claude. Keep `credits` explicit opt-in only.

- [ ] **Step 5: Stop critical lanes without respawn**

At the start of each `health_check` lane, evaluate `pane_critical`. On a match, append the lane once to both `CRITICAL_LANES` and `FAILED_LANES`, emit a critical diagnostic, notify halt, and continue without `respawn_lane` or Reflexion. Add a critical-failure paragraph to the report.

- [ ] **Step 6: Run tests and commit**

```bash
bash codex/tests/test-codex-errors.sh
bash core/tests/test-pane-errored.sh
tests/run.sh
git add core/scripts/polylane-agent.sh core/scripts/polylane-run.sh \
  core/tests/test-pane-errored.sh codex/tests/test-codex-errors.sh
git commit -m "fix(codex): classify critical transient and limit failures"
```

Expected: all tests pass before commit; rates are stalled, not retried.

---

### Task 5: Extract the Common Workflow and Assemble Both Distributions

**Files:**
- Create: `core/workflow/polylane-loop.md`
- Create: `core/scripts/polylane-package.sh`
- Create: `core/tests/test-package-parity.sh`
- Replace: `codex/SKILL.md`, `codex/install.sh`
- Create: `codex/references/codex-prompts.md`, `codex/references/codex-runtime.md`
- Create: `codex/tests/test-codex-install.sh`
- Create: `claude-code/SKILL.md`, `claude-code/install.sh`
- Create: `claude-code/references/claude-runtime.md`
- Create: `claude-code/tests/test-claude-install.sh`
- Replace: `SKILL.md`

**Interfaces:**
- Produces `polylane-package.sh <codex|claude-code> <destination>`.
- Installed layout contains `SKILL.md`, `scripts/`, `references/`, `assets/`, `.polylane-core-revision`, and Codex `agents/openai.yaml` where applicable.
- Common workflow receives question, prompt, memory, helper-path, model, and CLI behavior from the adapter.

- [ ] **Step 1: Write failing installation contracts**

`codex/tests/test-codex-install.sh` installs with `codex/install.sh --dest "$TEST_TMPDIR/codex/polylane"` and asserts:

```bash
assert_ok "skill" test -s "$DEST/SKILL.md"
assert_ok "launcher" test -x "$DEST/scripts/polylane-codex.sh"
assert_ok "runner" test -x "$DEST/scripts/polylane-run.sh"
assert_ok "revision" test -s "$DEST/.polylane-core-revision"
assert_contains "agent" '"agent": "codex"' "$(cat "$DEST/SKILL.md")"
assert_contains "local-bin" 'directory containing this SKILL.md' "$(cat "$DEST/SKILL.md")"
assert_not_contains "no-claude-home" '~/.claude' "$(cat "$DEST/SKILL.md")"
assert_not_contains "no-ask-tool" 'AskUserQuestion' "$(cat "$DEST/SKILL.md")"
assert_not_contains "no-claude-preamble" '/goal' "$(cat "$DEST/SKILL.md")"
```

`claude-code/tests/test-claude-install.sh` asserts its installed skill, runner, Claude adapter text, and revision. `core/tests/test-package-parity.sh` installs both, compares revision values, and compares every shared script checksum.

- [ ] **Step 2: Run package tests and verify RED**

```bash
bash codex/tests/test-codex-install.sh
bash claude-code/tests/test-claude-install.sh
bash core/tests/test-package-parity.sh
```

Expected: failures for missing packager, Claude distribution, and neutral workflow.

- [ ] **Step 3: Extract a neutral common workflow**

Move the root skill body after frontmatter into `core/workflow/polylane-loop.md`. Add this adapter contract at its top:

```markdown
## Platform adapter contract

Before this workflow starts, the selected platform entry skill defines:

- `SKILL_ROOT`: the directory containing the loaded installed `SKILL.md`.
- `BIN`: exactly `$SKILL_ROOT/scripts`; helpers are never discovered through `PATH`.
- Agent id, CLI command, model ids, and effort mapping.
- Question surface, always with a recommended default.
- Lane prompt preamble and optional platform skills.
- Optional cross-run memory bridge; absence is a supported no-op.

The adapter never changes core tmux, marker, verification, council, promotion,
cleanup, or resume behavior.
```

Use `$BIN/polylane-*.sh` throughout. Replace direct `AskUserQuestion` with “the platform question surface.” Replace Claude memory with the optional adapter memory hook. Move `/goal`, caveman, ponytail, graphify, `superpowers:*`, and `claude-mem` lane requirements into `claude-code/references/claude-runtime.md`.

Neutrality gate:

```bash
! rg -n 'AskUserQuestion|~/.claude|command -v polylane-run|/goal' core/workflow/polylane-loop.md
```

- [ ] **Step 4: Write thin platform entry skills**

Codex must state:

```markdown
## Codex adapter contract

- Set `SKILL_ROOT` to the directory containing this loaded `SKILL.md` and `BIN="$SKILL_ROOT/scripts"`.
- Emit `"agent": "codex"` in every manifest.
- Launch only with `$BIN/polylane-codex.sh .polylane/run.json`.
- Use Codex model ids and `model_reasoning_effort`.
- Generate plain prompts without Claude slash commands or Claude-only skills.
- Ask questions inline with the recommended default first.
- Use no platform memory bridge unless a Codex-native one is explicitly available.
```

Claude Code retains its existing CLI, question UI, prompt preamble, and optional memory behavior in its adapter. Root `SKILL.md` becomes a small compatibility entrypoint that requires reading `claude-code/SKILL.md`, `claude-code/references/claude-runtime.md`, and `core/workflow/polylane-loop.md` completely.

- [ ] **Step 5: Implement deterministic packaging**

`core/scripts/polylane-package.sh` must calculate current core content revision as:

```bash
core_revision() {
  find "$REPO/core" -type f -print | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s  %s\n' "$(git hash-object "$f")" "${f#$REPO/}"
  done | git hash-object --stdin
}
```

Use this assembly flow around that function:

```bash
#!/usr/bin/env bash
set -euo pipefail
ADAPTER="${1:?usage: polylane-package.sh <codex|claude-code> <destination>}"
DEST="${2:?usage: polylane-package.sh <codex|claude-code> <destination>}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$SCRIPT_DIR/../.." && pwd)
case "$ADAPTER" in codex|claude-code) ;; *) echo "unknown adapter: $ADAPTER" >&2; exit 2 ;; esac
case "$DEST" in ""|/|"$REPO") echo "unsafe package destination: $DEST" >&2; exit 2 ;; esac
PARENT=$(dirname "$DEST"); mkdir -p "$PARENT"
TMP=$(mktemp -d "$PARENT/.polylane-package.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts" "$TMP/references" "$TMP/assets"
{ cat "$REPO/$ADAPTER/SKILL.md"; echo; cat "$REPO/core/workflow/polylane-loop.md"; } > "$TMP/SKILL.md"
cp "$REPO"/core/scripts/*.sh "$TMP/scripts/"
cp -R "$REPO"/core/references/. "$TMP/references/"
cp -R "$REPO"/core/assets/. "$TMP/assets/"
[ ! -d "$REPO/$ADAPTER/scripts" ] || cp "$REPO"/$ADAPTER/scripts/*.sh "$TMP/scripts/"
[ ! -d "$REPO/$ADAPTER/references" ] || cp -R "$REPO/$ADAPTER/references/." "$TMP/references/"
if [ "$ADAPTER" = codex ]; then mkdir -p "$TMP/agents"; cp "$REPO/codex/openai.yaml" "$TMP/agents/openai.yaml"; fi
core_revision > "$TMP/.polylane-core-revision"
chmod +x "$TMP/scripts/"*.sh
rm -rf "$DEST"
mv "$TMP" "$DEST"
trap - EXIT
printf 'installed %s skill -> %s\n' "$ADAPTER" "$DEST"
```

Reject an arbitrary basename in each installer unless it came from explicit `--dest`; the shared packager itself still rejects empty, `/`, and the repository root.

Both installers accept `--user`, `--repo`, and `--dest <absolute-path>`. Codex defaults to `~/.codex/skills/polylane` when available, otherwise `~/.agents/skills/polylane`; Claude Code defaults to `~/.claude/skills/polylane`.

- [ ] **Step 6: Run package, parity, and full suites**

```bash
bash codex/tests/test-codex-install.sh
bash claude-code/tests/test-claude-install.sh
bash core/tests/test-package-parity.sh
tests/run.sh
```

Expected: both temporary packages work, revisions match, Codex contains no Claude-only directives, and the suite has zero failures.

- [ ] **Step 7: Commit**

```bash
git add core/workflow core/scripts/polylane-package.sh core/tests/test-package-parity.sh \
  codex claude-code SKILL.md
git commit -m "refactor: assemble both skills from one shared core"
```

---

### Task 6: Make Documentation and CI Codex-First

**Files:**
- Create: `core/tests/test-platform-docs.sh`
- Modify: `README.md`
- Modify: `core/references/install-helpers.md`
- Modify: `.polylane/SCHEMA.md`
- Modify: `.github/workflows/ci.yml`
- Modify: `.gitignore`

**Interfaces:**
- Produces one Codex quickstart and one separate Claude Code compatibility section.
- CI shellchecks shared and adapter scripts and runs all suites through root `tests/run.sh`.

- [ ] **Step 1: Write the failing documentation contract**

Create `core/tests/test-platform-docs.sh` using shared helpers and assert:

```bash
README=$(cat "$ROOT/README.md")
SCHEMA=$(cat "$ROOT/.polylane/SCHEMA.md")
assert_contains "codex-first" "## Codex quickstart" "$README"
assert_contains "codex-install" "./codex/install.sh --user" "$README"
assert_contains "codex-launcher" "polylane-codex.sh" "$README"
assert_contains "claude-section" "## Claude Code compatibility" "$README"
assert_contains "schema-agent" '"agent": "codex"' "$SCHEMA"
finish
```

- [ ] **Step 2: Run it and verify RED**

Run: `bash core/tests/test-platform-docs.sh`

Expected: README remains Claude-first and required headings are absent.

- [ ] **Step 3: Rewrite the primary quickstarts and requirements**

README begins with:

````markdown
## Codex quickstart

```bash
git clone https://github.com/GHGuide/polylane
cd polylane
./codex/install.sh --user
brew install tmux jq
```

Start Codex in the project to build, invoke `$polylane`, approve the strategy and lane
plan, then watch workers with `tmux attach -t polylane-c<N>`.

## Claude Code compatibility

Claude Code remains supported through `./claude-code/install.sh --user` and the
temporary root compatibility entrypoints. Its CLI and optional skills are isolated
from the Codex distribution.
````

Separate requirements by platform and explain that core fixes automatically serve both adapters while CLI/skill changes remain platform-local.

- [ ] **Step 4: Update schema and install reference**

Use `"agent": "codex"` in the primary schema example. Explain that generic core defaults to Claude only for compatibility, while the Codex launcher rejects missing or conflicting identity. Update all helper locations to the installed `scripts/` directory.

- [ ] **Step 5: Update CI file discovery**

Use:

```yaml
- name: Shellcheck all helpers
  run: |
    rc=0
    for f in core/scripts/*.sh codex/scripts/*.sh codex/install.sh claude-code/install.sh; do
      shellcheck -S warning "$f" || rc=1
    done
    exit $rc
- name: Run the test suite
  run: tests/run.sh
```

- [ ] **Step 6: Run docs, static checks, and full tests**

```bash
bash core/tests/test-platform-docs.sh
for f in core/scripts/*.sh codex/scripts/*.sh codex/install.sh claude-code/install.sh; do
  bash -n "$f"
  shellcheck -S warning "$f"
done
tests/run.sh
```

Expected: all commands exit 0 with no shellcheck warning-or-higher findings and zero tests failed.

- [ ] **Step 7: Commit**

```bash
git add README.md core/references/install-helpers.md core/tests/test-platform-docs.sh \
  .polylane/SCHEMA.md .github/workflows/ci.yml .gitignore
git commit -m "docs: make Codex the primary Polylane path"
```

---

### Task 7: Add and Run the Real Codex-in-tmux Canary

**Files:**
- Create: `codex/scripts/polylane-codex-rehearse.sh`
- Create: `codex/tests/test-codex-rehearse.sh`
- Modify: `codex/references/codex-runtime.md`

**Interfaces:**
- Produces `POLYLANE_CODEX_REHEARSE=1 polylane-codex-rehearse.sh`.
- Consumes `POLYLANE_CODEX_MODEL` or the top-level model in local Codex config.
- Demonstrates one real builder and one real integrator through tmux, nonce markers, GO, and promotion.

- [ ] **Step 1: Write the failing canary-harness test**

`codex/tests/test-codex-rehearse.sh` must assert two paths:

1. Without `POLYLANE_CODEX_REHEARSE=1`, the script exits 0 and prints `codex-rehearse-gated-off`.
2. With the flag, `POLYLANE_CODEX_MODEL=mock`, and `POLYLANE_AGENT_CMD` pointing at a mock marker writer, the harness reaches `CODEX-REHEARSE-GO` without API access.

Use the shared test helpers, capture the gated output, then create this executable mock for the second path:

```bash
#!/usr/bin/env bash
model="$1"; prompt="$2"; mkdir -p docs
run=$(sed -n 's/.*run=\([^[:space:]]*\).*/\1/p' "$prompt" | head -1)
case "$prompt" in
  *codex-smoke*)
    mkdir -p smoke
    printf 'built by tmux codex\n' > smoke/codex.txt
    printf 'mock model=%s\n' "$model" > docs/verify-codex-smoke.md
    git add smoke/codex.txt docs/verify-codex-smoke.md
    git commit -qm mock-builder
    printf 'STATUS: codex-smoke DONE run=%s\n' "$run" > docs/status-codex-smoke.md
    ;;
  *integrator*)
    git merge -q --no-edit lane/codex-smoke
    printf 'POLYLANE-VERDICT: GO run=%s\n' "$run" > docs/verify-integration.md
    git add docs/verify-integration.md
    git commit -qm mock-integrator
    printf 'STATUS: integrator DONE run=%s\n' "$run" > docs/status-integrator.md
    ;;
esac
exec sleep 600
```

Invoke it with `POLYLANE_AGENT_CMD="$MOCK {model} {prompt}"`, `POLYLANE_CODEX_REHEARSE=1`, and `POLYLANE_CODEX_MODEL=mock`; assert exit 0 and output contains `CODEX-REHEARSE-GO`.

- [ ] **Step 2: Run it and verify RED**

Run: `bash codex/tests/test-codex-rehearse.sh`

Expected: failure because the canary script does not exist.

- [ ] **Step 3: Implement the opt-in canary**

The executable script must:

- Skip cleanly unless `POLYLANE_CODEX_REHEARSE=1`.
- Require codex/tmux/jq/git unless a custom mock command is supplied.
- Resolve the model from `POLYLANE_CODEX_MODEL`, then `${CODEX_HOME:-$HOME/.codex}/config.toml`; otherwise print the exact `POLYLANE_CODEX_MODEL=<id>` remediation and exit 2.
- Create a throwaway git repository and nonce-tagged manifest with `"agent":"codex"`.
- Give the builder exact instructions to create and commit `smoke/codex.txt` plus evidence, then write `STATUS: codex-smoke DONE run=<nonce>`.
- Give the integrator exact instructions to merge the builder, verify the file, commit evidence, write its DONE marker, and write `POLYLANE-VERDICT: GO run=<nonce>`.
- Invoke `polylane-codex.sh` with a unique session, short poll, bounded restarts, and `POLYLANE_MIN_DISK_GB=0` only for this tiny temporary canary.
- Assert the base contains `smoke/codex.txt`, report outcome is GO, and no lane commit remains at risk.
- Trap cleanup for only its own temp repository and tmux session.

Use this complete harness structure (the prompt prose is part of the test contract):

```bash
#!/usr/bin/env bash
set -euo pipefail
[ "${POLYLANE_CODEX_REHEARSE:-0}" = 1 ] || { echo "codex-rehearse-gated-off"; exit 0; }
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LAUNCH="$SCRIPT_DIR/polylane-codex.sh"
for dep in tmux jq git; do command -v "$dep" >/dev/null 2>&1 || { echo "missing $dep" >&2; exit 2; }; done
if [ -z "${POLYLANE_AGENT_CMD:-}" ]; then command -v codex >/dev/null 2>&1 || { echo "missing codex" >&2; exit 2; }; fi
MODEL="${POLYLANE_CODEX_MODEL:-}"
if [ -z "$MODEL" ]; then
  cfg="${CODEX_HOME:-$HOME/.codex}/config.toml"
  [ ! -f "$cfg" ] || MODEL=$(awk -F '"' '/^[[:space:]]*model[[:space:]]*=/{print $2; exit}' "$cfg")
fi
[ -n "$MODEL" ] || { echo "set POLYLANE_CODEX_MODEL=<id>" >&2; exit 2; }
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/polylane-codex-rehearse.XXXXXX")
SESSION="plcx-$$"; RUN_ID="cx$(date +%s)$$"
trap 'tmux kill-session -t "$SESSION" 2>/dev/null || true; rm -rf "$ROOT"' EXIT
git -C "$ROOT" init -q -b main
git -C "$ROOT" config user.email polylane@example.invalid
git -C "$ROOT" config user.name polylane-canary
printf 'seed\n' > "$ROOT/seed.txt"
git -C "$ROOT" add seed.txt
git -C "$ROOT" commit -qm seed
mkdir -p "$ROOT/.polylane/lanes"
cat > "$ROOT/.polylane/lanes/codex-smoke.txt" <<EOF
You are the codex-smoke builder in an isolated git worktree.
Create smoke/codex.txt containing exactly: built by tmux codex
Create docs/verify-codex-smoke.md recording the exact file content and git status.
Run a direct check that smoke/codex.txt has the required line.
Stage only smoke/codex.txt and docs/verify-codex-smoke.md and commit them.
After the commit, write docs/status-codex-smoke.md whose first line is exactly:
STATUS: codex-smoke DONE run=$RUN_ID
Do not finish before that marker exists.
EOF
cat > "$ROOT/.polylane/lanes/integrator.txt" <<EOF
You are the integrator in an isolated git worktree on lane/codex-integrator.
Merge lane/codex-smoke with --no-edit. Verify smoke/codex.txt contains exactly:
built by tmux codex
Write docs/verify-integration.md with the evidence and this sentinel on its own line:
POLYLANE-VERDICT: GO run=$RUN_ID
Stage only docs/verify-integration.md and commit it.
After the commit, write docs/status-integrator.md whose first line is exactly:
STATUS: integrator DONE run=$RUN_ID
EOF
cat > "$ROOT/.polylane/run.json" <<EOF
{"base":"main","run_id":"$RUN_ID","agent":"codex","available_models":["$MODEL"],
 "integrator":{"name":"integrator","model":"$MODEL","effort":"high","branch":"lane/codex-integrator","worktree":"$ROOT/wt-integrator","prompt_file":"$ROOT/.polylane/lanes/integrator.txt"},
 "lanes":[{"name":"codex-smoke","model":"$MODEL","effort":"medium","branch":"lane/codex-smoke","worktree":"$ROOT/wt-codex-smoke","prompt_file":"$ROOT/.polylane/lanes/codex-smoke.txt","own_globs":["smoke/**","docs/verify-codex-smoke.md"]}]}
EOF
( cd "$ROOT"
  POLYLANE_SESSION="$SESSION" POLYLANE_POLL_INTERVAL=2 POLYLANE_HEALTH_INTERVAL=30 \
  POLYLANE_MAX_RETRIES=1 POLYLANE_SUP_INTERVAL=2 POLYLANE_SUP_MAX_RESTARTS=1 \
  POLYLANE_MIN_DISK_GB=0 "$LAUNCH" "$ROOT/.polylane/run.json" --yes )
grep -qx 'built by tmux codex' "$ROOT/smoke/codex.txt"
grep -q 'Outcome:.*GO\|^\*\*GO\*\*' "$ROOT/docs/polylane-report.md"
! git -C "$ROOT" show-ref --verify --quiet refs/heads/lane/codex-smoke
! git -C "$ROOT" show-ref --verify --quiet refs/heads/lane/codex-integrator
echo "CODEX-REHEARSE-GO"
```

- [ ] **Step 4: Prove the harness hermetically**

```bash
bash codex/tests/test-codex-rehearse.sh
tests/run.sh
```

Expected: zero failures. Do not start real Codex if any hermetic test is red.

- [ ] **Step 5: Run the real Codex/tmux canary**

```bash
POLYLANE_CODEX_REHEARSE=1 codex/scripts/polylane-codex-rehearse.sh
```

Expected: `CODEX-REHEARSE-GO`, valid nonce-tagged DONE/GO evidence, successful base promotion, and exit 0.

- [ ] **Step 6: Commit**

```bash
git add codex/scripts/polylane-codex-rehearse.sh codex/tests/test-codex-rehearse.sh \
  codex/references/codex-runtime.md
git commit -m "test(codex): add real tmux Codex canary"
```

---

### Task 8: Final Verification and Active Codex Installation

**Files:**
- Installed output: `~/.codex/skills/polylane/`
- Source changes only if verification exposes a defect; each defect first receives a failing regression test.

**Interfaces:**
- Produces an active Codex skill whose recorded core revision and scripts match a fresh package.

- [ ] **Step 1: Run fresh syntax and static verification**

```bash
git diff --check
for f in core/scripts/*.sh codex/scripts/*.sh codex/install.sh claude-code/install.sh tests/run.sh; do
  bash -n "$f"
  shellcheck -S warning "$f"
done
```

Expected: all exit 0, no `git diff --check` output, no shellcheck findings.

- [ ] **Step 2: Run the complete suite fresh**

```bash
POLYLANE_MIN_DISK_GB=0 tests/run.sh
```

Expected: zero failures across shared, Codex, and Claude suites. The override is only for temporary rehearsals on this currently low-space machine.

- [ ] **Step 3: Re-run the real canary fresh**

```bash
POLYLANE_CODEX_REHEARSE=1 codex/scripts/polylane-codex-rehearse.sh
```

Expected: `CODEX-REHEARSE-GO` and exit 0.

- [ ] **Step 4: Install the verified Codex distribution**

```bash
./codex/install.sh --user
```

Expected: active Codex destination reported and exit 0.

- [ ] **Step 5: Compare active installation to a fresh package**

```bash
tmp=$(mktemp -d "${TMPDIR:-/tmp}/polylane-final.XXXXXX")
./codex/install.sh --dest "$tmp/polylane"
cmp "$tmp/polylane/.polylane-core-revision" "$HOME/.codex/skills/polylane/.polylane-core-revision"
cmp "$tmp/polylane/scripts/polylane-run.sh" "$HOME/.codex/skills/polylane/scripts/polylane-run.sh"
cmp "$tmp/polylane/scripts/polylane-codex.sh" "$HOME/.codex/skills/polylane/scripts/polylane-codex.sh"
rm -rf "$tmp"
```

Expected: every comparison exits 0.

- [ ] **Step 6: Audit repository and tmux state**

```bash
git status --short
git log --oneline -10
tmux list-sessions 2>/dev/null || true
```

Expected: clean source tree, planned commits present, and no canary session. Do not kill unrelated existing tmux sessions.

- [ ] **Step 7: Avoid an empty verification commit**

If verification changes no source, create no commit. If it adds exact verified commands or compatibility notes, stage only those documentation files and use:

```bash
git commit -m "docs: record Codex package verification"
```

---

## Spec Coverage Audit

| Design requirement | Implemented and proven by |
|---|---|
| Canonical shared core plus two platform adapters | Tasks 2 and 5 |
| Root Claude compatibility entrypoints | Tasks 2, 5, and 8 |
| Agent-aware runner and doctor | Task 1 |
| Modern stdin-based Codex CLI with model and effort | Task 1 |
| Fail-closed Codex identity | Task 3 |
| Supervisor restart retains Codex identity | Task 3 |
| Critical/transient/limit separation | Task 4 |
| No automatic credit decision | Task 4 |
| Neutral common workflow and platform-local skill rules | Task 5 |
| Identical recorded core revision in both packages | Task 5 |
| Installed helper resolution from Codex skill directory | Tasks 3 and 5 |
| Codex-first docs and cross-platform CI | Task 6 |
| Real builder and integrator Codex CLIs in tmux | Task 7 |
| Active user Codex skill matches verified package | Task 8 |
