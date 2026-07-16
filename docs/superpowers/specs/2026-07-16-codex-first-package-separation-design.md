# Codex-First Package Separation Design

## Goal

Restructure Polylane into a shared, platform-neutral core with separate Codex and
Claude Code distributions. Make Codex the primary development and documentation
target while preserving the existing Claude Code entrypoints during a compatibility
period.

The Codex distribution must reliably launch actual Codex CLI processes in isolated
tmux panes. It must fail closed when its manifest or runtime points at another agent,
and it must not depend on Claude Code being installed.

After initial core decisions, a persistent Codex controller must run the complete loop
autonomously for hours or days, cycle quickly, recover from internal failures, continue
through a bounded-scope perfection phase, and stop only at verified completion or when a
genuine user decision is required. An incomplete run must never become silently idle:
it must always be doing goal-directed work or executing an observable recovery action.

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
- Persistent controller watchdog, terminal-state machine, stable tmux session, and
  user-input handoff files.
- Scope, seam, acceptance, ledger, goal-tree, report, and cleanup helpers.
- Builder skill-kit selection, GitHub suggestion records, perfection convergence, and
  next-idea generation.
- Platform-neutral workflow and planning rules.

The Codex adapter owns:

- The Codex skill frontmatter and Codex-specific instructions.
- Codex installation paths and package assembly.
- The fail-closed Codex launcher.
- The persistent Codex controller launcher and controller prompt.
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

After the initial strategy and other core product decisions are locked in chat, the skill
invokes `polylane-codex-loop.sh`. That launcher creates one stable tmux session named
`polylane-<run-id>` and keeps it for the entire multi-cycle run:

- A `controller` window runs a supervised Codex CLI orchestrator. Its prompt and compact
  state are persisted under `docs/polylane/`, so the watchdog can resume it after a CLI,
  shell, app, or network interruption without losing the loop.
- A reusable `lanes` window contains the current cycle's isolated builders and later its
  integrator. Completed-cycle panes are replaced rather than creating a new session.
- The controller emits each `.polylane/run.json` with `"agent": "codex"` and invokes
  `polylane-codex.sh` for the shared one-cycle supervisor/runner pipeline.
- `polylane-codex.sh` rejects a missing or non-Codex manifest agent, exports
  `POLYLANE_AGENT=codex`, verifies `codex`, `tmux`, `jq`, and `git`, and delegates to the
  shared cycle supervisor.

Each builder and integrator pane changes into its isolated worktree and runs:

   ```text
   codex exec --sandbox workspace-write --model <model> \
     -c model_reasoning_effort=<effort> - < /absolute/path/to/prompt-file
   ```

The shared engine observes file markers and pane state, verifies the integrator verdict,
promotes only on GO, and returns control to the persistent orchestrator. The orchestrator
closes the cycle, elects the next focus, and immediately starts the next one.

`POLYLANE_AGENT_CMD` remains an explicit expert override. The Codex launcher still
enforces the Codex manifest identity, but a supplied command template may replace the
default executable command for testing or specialized Codex installations.

## Persistent Autonomy and Terminal States

The loop is designed to run for hours or days without the initiating chat remaining in
the foreground. There is no fixed cycle cap, time cap, token cap, cost cap, ROI stop, or
"diminishing returns" exit. Cost and usage remain visible in the ledger but are
informational only.

Only two terminal states exist:

1. **`COMPLETE`** — the locked goal, perfection convergence, and final certification all
   pass.
2. **`WAITING_FOR_USER`** — a genuine product/strategy pivot, unavailable credential or
   account, or irreversible externally visible action requires a user decision.

An internal lane failure, runner crash, controller crash, transient outage, rate limit,
failed approach, merge conflict, weak ROI, or elapsed time is never a terminal state.
Recovery escalates through checkpointed retry, reflection repair, alternate model,
re-carving, alternate implementation approach, and persisted exponential backoff. A
repeated tactic is recorded and not retried unchanged. Temporary limits wait and resume;
an account condition that cannot resolve without credentials becomes `WAITING_FOR_USER`.

The controller writes a structured `docs/polylane/needs-input.json` only for genuine user
input. Returning to the skill reads that request and supplies the answer without
restarting or re-interviewing the run.

## Fast Adaptive Cycles

Ordinary cycles optimize wall-clock time without weakening final correctness:

- Independent builder lanes run concurrently up to the approved machine/API concurrency.
- Research, digest preparation, skill discovery, and non-dependent verification overlap
  rather than running as a fully serial tail.
- Ordinary next-focus decisions use a fast independent three-member council. Any risky,
  regressed, or potentially final cycle uses the full five-member council including the
  adversary.
- Deep research is skipped when no new decision depends on external knowledge; previously
  covered ground is never repeated.
- Polling is event-responsive with a short adaptive fallback interval rather than fixed
  15–20 second waits at every boundary.
- The stable tmux session and controller are reused across cycles, avoiding repeated CLI,
  session, and context bootstrap work.
- User questions never block ordinary implementation choices. Recommended defaults are
  taken automatically unless the issue meets the `WAITING_FOR_USER` definition.

Potentially final cycles always run the exhaustive council, frozen acceptance suite,
regression suite, and fresh checkout install/build/boot certification.

## Continuous Work and Progress Leases

`WORKING` and `RECOVERING` are observable active phases, not terminal states. Until the
run reaches `COMPLETE` or `WAITING_FOR_USER`, the controller enforces this invariant:

> At least one goal-directed job is running, or at least one concrete recovery action is
> scheduled with a persisted `next_action_at` deadline and an active guardian responsible
> for executing it.

Every controller and lane owns a renewable progress lease. A process heartbeat only
proves that the process exists and never renews the lease by itself. Valid progress proof
is one or more of:

- New command, tool, pane, or structured event output.
- A changed worktree, artifact, marker, test result, or queue position.
- A declared long-running child process that is alive and still within its explicit
  maximum deadline.
- A completed diagnosis, retry, repair, re-carve, model switch, or provider probe.

The default watchdog cadence is five seconds and the ordinary no-progress lease is 90
seconds. Both are configurable for tests and constrained machines. A legitimately quiet
long-running command declares its own deadline before launch; remaining alive counts only
until that deadline, so a stuck child cannot renew forever. Lease and queue transitions
are written atomically under `.polylane/runtime/` and include the current action, last
progress proof, deadline, recovery attempt, and next action.

On lease expiry the guardian captures diagnostics and escalates without waiting for chat:
checkpoint and resume, retry, reflection repair, alternate approved model, task re-carve,
alternate implementation approach, then persisted provider backoff. The same failed
tactic and inputs are not repeated unchanged. The controller itself is supervised by a
non-Codex guardian loop, so a dead, wedged, or falsely-heartbeating controller is restored
from the persisted run state.

Provider unavailability changes the active phase to `RECOVERING`. The controller drains a
prepared offline queue—local tests, static analysis, diff and artifact review, merge
preparation, task re-carving, prompt preparation, documentation, and cleanup—while
periodically probing service recovery. If no offline job remains, the guardian still
executes visible scheduled probes with bounded persisted backoff; it never enters an
unreported shell sleep. Authentication, billing, permission, or account action that only
the user can resolve produces `WAITING_FOR_USER`. A transient outage does not.

Polling is event-driven. The short watchdog cadence is a safety fallback, not a mandatory
delay between completed actions or cycles. The next runnable action starts immediately
when its dependency or recovery probe completes. An incomplete empty runnable queue,
missing recovery deadline, expired guardian heartbeat, or unexplained idle interval is a
critical liveness fault and triggers automatic reconstruction from the goal tree.

## Tmux Watch Command Contract

Whenever the run's tmux session is created, resumed, or recreated, Polylane writes the
exact attach command to `.polylane/watch-command`, exposes it through
`polylane-state.sh --watch`, and prints it into Codex chat as a standalone copyable line:

```text
tmux attach -t polylane-<run-id>
```

It appears once per launch/resume and again only if the session is recreated or its name
changes. A single stable session contains controller and lane windows, so one command is
enough to observe the whole run. If more than one Polylane run is active, chat displays
one standalone command per active session.

## Builder Skill Kits and GitHub Suggestions

Every builder prompt contains exactly four required skill assignments:

- Two predefined skills: `superpowers:test-driven-development` and
  `superpowers:verification-before-completion`.
- Two lane-specific installed skills selected from the lane's concrete activities and
  domain, such as systematic debugging, accessibility, API security, design systems, or
  data analysis.

If a predefined skill is unavailable, the prompt includes its equivalent behavioral
contract and the skill is offered for installation; the lane never starts with a missing
quality gate. A deterministic prompt lint fails before launch unless all four assignments
or approved equivalents are present. Each builder's verify file records which skills it
used, the output they produced, and whether they helped. The council scores those results
so repeatedly unused or harmful choices are not suggested again.

The GitHub skill suggester runs after lane derivation and searches only for capabilities
not covered by installed skills. Each suggestion includes repository URL, maintainer,
recent activity, why it fits a named lane, and the permissions or tooling it introduces.
External skills are never auto-installed; they are informational until the user approves
them, and their absence never blocks the current cycle. Installed, previously approved
lane-specific skills may be selected automatically.

## Completion, Perfection, and Suggestions

Passing the original acceptance tree begins a **perfection phase**; it does not stop the
run. Perfection work remains limited to the locked north star and scope—new product ideas
cannot make completion recede.

The run reaches `COMPLETE` only after two consecutive exhaustive certifications discover
no new in-scope actionable defect, stub, broken flow, regression, security issue,
accessibility issue, performance failure, documentation/runbook gap, or shippability
failure. Each certification includes the full five-member council, adversarial review,
all frozen checks, and a fresh checkout install/build/boot test. Any new finding becomes a
top-weight sub-goal, resets the consecutive-clean counter, and the loop continues.

After each ordinary cycle, Polylane reports concrete work completed and a ranked set of
possible next moves while automatically continuing with the council-elected focus. After
`COMPLETE`, it produces exactly 30 ranked informational ideas beyond the locked scope.
Those ideas are not defects, do not reopen the completed goal, and are never built
automatically. Selecting one starts a new locked run.

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
  controller first tries already-approved alternate models or approaches; if no internal
  remedy exists, it enters `WAITING_FOR_USER` without terminating or discarding state.
- Transient service, network, connection, and overload failures use checkpointed retry,
  persisted backoff, and automatic resume.
- Rate or usage limits never trigger a paid-credit decision automatically. They remain
  visible, activate the offline/recovery queue, and resume automatically when service
  becomes available. Any backoff has a persisted next action and remains observable.
- A lane process that exits without a valid DONE marker is never considered successful.
- A missing prompt, wrong agent, missing executable, malformed manifest, or tmux session
  collision fails before token spend, is repaired or re-carved by the controller, and is
  not treated as a completed run.
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
- Persistent controller crash/resume, stable-session reuse, and on-disk input requests.
- Progress leases that cannot be renewed by a heartbeat alone; declared quiet-command
  deadlines; atomic runtime records; and immediate queue advancement.
- Automatic recovery from a frozen lane, killed controller, stale marker, empty queue,
  cycle-boundary crash, expired guardian heartbeat, and provider recovery.
- Rate-limit and provider-outage fixtures that drain offline work, perform scheduled
  probes, and never produce an unexplained idle interval or false user-input stop.
- Proof that internal failures, cycle counts, ROI, and ledger totals cannot select a
  terminal state.
- Fast ordinary-cycle and exhaustive-final-cycle gate selection.
- Exact standalone tmux watch-command emission on create, resume, and recreation.
- Four-skill prompt assignment, prompt lint, evidence, and ledger scoring.
- Perfection convergence requiring two consecutive clean exhaustive passes.
- Per-cycle suggestion output and exactly 30 non-executing final suggestions.
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

Liveness validation has two additional layers:

1. A deterministic accelerated soak advances a fake clock through multiple simulated
   hours while injecting frozen panes, killed processes, false heartbeats, rate limits,
   provider outages, stale completion signals, and crashes between cycles. The test fails
   if any incomplete interval exceeds its lease without useful work or an executed,
   persisted recovery action.
2. A real Codex/tmux continuity canary completes at least two consecutive small cycles,
   injects one recoverable lane failure, observes automatic recovery, and verifies the
   stable watch command and runtime ledger. It records the maximum unexplained idle gap,
   which must be zero.

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
11. A persistent Codex controller survives a forced exit, resumes from disk, and starts
    another cycle without chat intervention.
12. The only terminal-state values reachable in tests are `COMPLETE` and
    `WAITING_FOR_USER`; budget, cycle, ROI, and internal-failure fixtures never terminate.
13. Ordinary cycles take the fast adaptive path while final candidates take the full
    five-member and fresh-checkout certification path.
14. Every created, resumed, or recreated active session makes the exact standalone
    `tmux attach -t polylane-<run-id>` command available and surfaces it to chat.
15. Every builder prompt passes a mechanical gate for two predefined and two
    lane-specific skills, with usage evidence recorded after execution.
16. The GitHub suggester emits attributed lane-specific candidates without installing
    them or blocking the cycle.
17. Completion requires two consecutive clean exhaustive certifications after the
    original acceptance tree passes.
18. Each cycle emits ranked next-move suggestions, and final completion emits exactly 30
    informational ideas that do not execute or alter completed scope.
19. A heartbeat without progress expires its lease and is recovered; an active quiet
    command remains valid only until its declared deadline.
20. Every incomplete runtime snapshot contains running goal-directed work or a persisted
    recovery action with `next_action_at`; an empty queue reconstructs automatically.
21. Provider-outage tests stay in observable `RECOVERING`, drain offline work, probe and
    resume without entering `WAITING_FOR_USER` unless a concrete account action is needed.
22. Accelerated multi-hour fault-injection soak tests and the real two-cycle Codex/tmux
    continuity canary pass with zero unexplained idle gaps.

## Non-Goals

- Redesigning Claude Code prompts or optimizing Claude model selection.
- Supporting non-tmux execution in this migration.
- Replacing the file-marker and integrator-verdict protocols.
- Automatically purchasing usage credits or bypassing account-level restrictions.
- Automatically building any of the 30 post-completion informational suggestions.
- Treating cost, elapsed time, cycle count, or diminishing ROI as permission to stop an
  incomplete run.
