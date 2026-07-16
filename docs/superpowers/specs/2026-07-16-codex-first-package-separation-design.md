# Codex-First Package Separation Design

## Goal

Restructure Polylane into a shared, platform-neutral core with separate Codex and
Claude Code distributions. Make Codex the primary development and documentation
target while preserving the existing Claude Code entrypoints during a compatibility
period.

The Codex distribution must reliably launch actual Codex CLI processes in isolated
tmux panes. It must fail closed when its manifest or runtime points at another agent,
and it must not depend on Claude Code being installed.

## Current Problems

The repository is Claude-first at its root and assembles the Codex skill as a thin
overlay. This produces several reliability gaps:

- The installed Codex skill looks for helpers on `PATH` or under `~/.claude`, although
  its helpers are installed under the Codex skill directory.
- The shared runner and doctor require the `claude` executable even when the selected
  agent is Codex.
- A missing manifest `agent` field silently selects Claude.
- Codex uses a deprecated `--full-auto` invocation.
- Reasoning effort is exported as an environment variable that Codex does not consume.
- Prompt text is expanded into a shell argument instead of being streamed through
  stdin, increasing quoting and command-length risk.
- Core and platform-specific behavior are mixed, making it difficult to test whether
  a change applies equally to both distributions.

## Selected Architecture

Use one canonical shared core and two thin platform adapters:

```text
core/
  scripts/       shared runner, supervisor, state, merge, and diagnostics
  references/    platform-neutral workflow and planning references
  assets/        shared helper assets
  workflow/      common autonomous-loop contract
  tests/         shared engine tests and tmux rehearsals

codex/
  SKILL.md        Codex-specific skill entrypoint
  install.sh      Codex package installer
  agents/         Codex interface metadata
  references/     Codex CLI, prompt, model, and question adaptations
  scripts/        Codex launcher only
  tests/          Codex adapter and packaging contracts

claude-code/
  SKILL.md        Claude Code skill entrypoint
  install.sh      Claude Code package installer
  references/     Claude CLI, prompt, model, and question adaptations
  scripts/        Claude launcher only
  tests/          Claude adapter and packaging contracts

bin/              temporary compatibility entrypoints into core/scripts
SKILL.md           temporary compatibility entrypoint for Claude Code
tests/run.sh       compatibility wrapper for the reorganized test suites
```

Core behavior has exactly one source file. Platform folders do not copy or fork core
implementation files in the repository. Installers assemble a self-contained installed
skill by copying the current core plus the selected platform adapter.

## Ownership Boundaries

The shared core owns:

- Git worktree and branch isolation.
- tmux session and pane creation, seeding, polling, logging, and recovery.
- Manifest parsing and validation primitives.
- DONE and integrator-verdict marker contracts.
- Supervisor restart and resume behavior.
- Scope, seam, acceptance, ledger, goal-tree, report, and cleanup helpers.
- Platform-neutral workflow and planning rules.

The Codex adapter owns:

- The Codex skill frontmatter and Codex-specific instructions.
- Codex installation paths and package assembly.
- The fail-closed Codex launcher.
- Codex CLI command construction and process/error recognition.
- Codex model and reasoning-effort mapping.
- Plain Codex lane prompts and inline-chat question behavior.
- Codex-specific contract and live-canary tests.

The Claude Code adapter owns only equivalent Claude-specific concerns. This effort
migrates those concerns without redesigning or optimizing them. Future shared-core
changes automatically serve both platforms; future CLI- or skill-specific changes stay
inside the relevant adapter.

## Codex Execution Flow

The Codex skill resolves its runtime directory from the exact installed `SKILL.md`
location. It never searches `PATH` for Polylane helpers and never falls back to a Claude
directory.

For each cycle:

1. The skill emits `.polylane/run.json` with `"agent": "codex"`.
2. The skill invokes the installed `polylane-codex.sh` launcher.
3. The launcher rejects a missing or non-Codex manifest agent, exports
   `POLYLANE_AGENT=codex`, verifies `codex`, `tmux`, `jq`, and `git`, and delegates to the
   shared supervisor.
4. The supervisor launches or resumes the shared runner.
5. The runner creates one tmux pane per active lane and one later integrator pane.
6. Each pane changes into its isolated worktree and runs:

   ```text
   codex exec --sandbox workspace-write --model <model> \
     -c model_reasoning_effort=<effort> - < /absolute/path/to/prompt-file
   ```

7. The shared engine observes file markers and pane state, verifies the integrator
   verdict, promotes only on GO, and preserves recovery state on failure.

`POLYLANE_AGENT_CMD` remains an explicit expert override. The Codex launcher still
enforces the Codex manifest identity, but a supplied command template may replace the
default executable command for testing or specialized Codex installations.

## Shared Agent Contract

The core runner becomes agent-aware without becoming Codex-specific:

- Base dependencies are `tmux`, `jq`, and `git`.
- The selected manifest or environment agent determines the required CLI.
- `claude` requires `claude`; `codex`, `gpt`, and `openai` require `codex`; `aider`
  requires `aider`; a custom command template bypasses executable-name inference.
- Doctor reports the same selected-agent dependency contract as the runner.
- Unknown agents fail before worktrees or tmux sessions are created.
- The core retains Claude as its generic backward-compatible default. Platform launchers
  override this default and enforce their own identity.

The command-template contract supports `{model}`, `{prompt}`, and optional `{effort}`.
The Codex default consumes all three values correctly. Existing Claude and custom
templates remain compatible when they use only the original `{model}` and `{prompt}`
placeholders.

## Error Handling

Codex failures are classified before recovery:

- Authentication, account, invalid-model, and permission failures are critical. The
  lane is parked, the run is reported as blocked, and no blind respawn loop occurs.
- Transient service, network, connection, and overload failures use the existing bounded
  checkpoint-and-respawn flow.
- Rate or usage limits never trigger a paid-credit decision automatically. They remain
  visible and resumable.
- A lane process that exits without a valid DONE marker is never considered successful.
- A missing prompt, wrong agent, missing executable, malformed manifest, or tmux session
  collision fails before token spend.
- Supervisor restart preserves the original Codex identity and command contract.

## Packaging and Compatibility

`codex/install.sh` and `claude-code/install.sh` assemble self-contained installed skills
from the same core revision. Each package records that core revision so tests and support
output can detect stale or mixed installations.

The Codex installer targets `~/.codex/skills/polylane` when available, with the existing
documented fallback supported explicitly. Repo-scoped installation remains available.

For one compatibility period:

- Root `SKILL.md` continues to expose the Claude Code skill.
- Root `bin/polylane-*.sh` paths continue to invoke the canonical shared scripts.
- Root `tests/run.sh` runs shared and platform contract suites.
- Existing root commands emit no behavior change except corrected agent-aware dependency
  checks.

New documentation presents Codex first, gives it a complete quickstart, and clearly
separates Claude Code instructions rather than mixing both CLIs in one path.

## Test Strategy

Development follows red-green-refactor for every behavior change.

Shared-core tests cover:

- Agent-aware dependency selection and manifest validation.
- Template substitution, including optional effort.
- tmux pane construction, literal seeding, polling, recovery, resume, and promotion.
- Existing marker, scope, seam, ledger, memory, and report behavior.
- Mock-agent GO and NO-GO rehearsals through real tmux.

Codex adapter tests cover:

- Fail-closed rejection when `agent` is absent or not Codex.
- No Claude executable requirement or Claude path fallback.
- The current stdin-based `codex exec` command, model, sandbox, and reasoning effort.
- Installed-skill helper resolution relative to the skill directory.
- Temporary Codex package installation and core-revision parity.
- Supervisor restart retaining Codex identity.

Claude adapter tests retain its existing command and installation contract and confirm it
consumes the same core revision.

An opt-in real-Codex canary builds a throwaway git repository through one builder pane and
one integrator pane using the locally configured Codex model. It must produce valid DONE
and GO markers, promote the integrator result, and leave no lane commit at risk. This
canary is run once during this migration after all hermetic tests pass; it is not required
in unauthenticated CI.

## Acceptance Criteria

The migration is complete when all of the following are demonstrated:

1. The repository has canonical `core/`, `codex/`, and `claude-code/` boundaries plus the
   documented temporary root compatibility entrypoints.
2. Core implementation files have one source and both installers package the identical
   recorded core revision.
3. A Codex manifest launches Codex CLI processes inside tmux without requiring Claude.
4. The Codex launcher rejects missing or conflicting agent identity before side effects.
5. Codex receives its selected model and reasoning effort, and reads the prompt through
   stdin.
6. The installed Codex skill resolves only its own installed helpers.
7. Hermetic shared, Codex, Claude, installer, and tmux rehearsal suites pass.
8. The real-Codex tmux canary reaches a valid GO and promotion in a throwaway repository.
9. The verified Codex package is installed into the active user Codex skill location.
10. Existing root Claude Code entrypoints remain operational during the compatibility
    period.

## Non-Goals

- Redesigning Claude Code prompts or optimizing Claude model selection.
- Supporting non-tmux execution in this migration.
- Replacing the file-marker and integrator-verdict protocols.
- Changing Polylane product discovery, goal-tree, council, or promotion semantics beyond
  the minimum platform-neutral extraction required by the new boundaries.
- Automatically purchasing usage credits or bypassing account-level restrictions.
