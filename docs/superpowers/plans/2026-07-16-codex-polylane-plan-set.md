# Codex Polylane Complete Implementation Plan Set

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan set task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the complete approved Codex-first Polylane migration, including
shared-core packaging, exact builder skill kits, a persistent autonomous Codex/tmux
controller, continuous liveness recovery, perfection convergence, and live continuity
certification.

**Architecture:** The work is split into three independently reviewable plans because
packaging, skill selection, and persistent runtime are separate subsystems with different
failure modes. They share explicit JSON and shell interfaces and are executed in the
dependency order below. The historical
`2026-07-16-codex-first-package-separation.md` plan is superseded and must not be run.

**Tech Stack:** Bash 3.2, Python 3, jq, tmux, git worktrees, Codex CLI, Markdown skills,
fixture-driven GitHub API tests, fake-clock fault injection, and GitHub Actions on macOS
and Ubuntu.

## Global Constraints

- Core implementation has exactly one canonical source under `core/`; adapter behavior
  lives under `codex/` or `claude-code/`.
- The installed Codex `SKILL.md` stays below 500 lines with only `name`/`description`
  frontmatter and direct progressive-disclosure references; UI metadata is regenerated and
  validated, and no auxiliary README/install/changelog clutter ships inside the skill.
- Codex is the optimized path. Claude Code keeps compatibility through the same core but
  receives no unrelated redesign.
- Codex workers and the persistent controller run through tmux and use modern stdin-driven
  `codex exec --json` commands with separated structured event logs; controller proposals
  additionally use an output schema and private last-message file.
- A one-cycle runner/supervisor exit is a child result, never outer-loop success. The
  persistent guardian acknowledges it only with a durable continuation transaction and
  remains alive across verdict, council, promotion, and next-cycle boundaries.
- An incomplete run is always observably `WORKING` or `RECOVERING`; a heartbeat alone is
  not evidence of progress.
- The only terminal states are `COMPLETE` and `WAITING_FOR_USER`.
- Cycle and council verdicts are never terminal: cycle `GO` promotes and immediately
  schedules the next open-goal/perfection/certification action; cycle `NO_GO` schedules
  repair; council `complete` nominates exhaustive certification; council `not_complete`
  selects an open focus; invalid or abstaining verdicts schedule typed recovery. Only the
  independent terminal reducer may select a terminal state, and no verdict boundary may
  leave an incomplete queue empty.
- Next-focus selection must consume and hash-bind the authenticated council artifact, not
  merely depend on its queue id. A `complete` recommendation nominates exhaustive
  certification only; focus recommendations are constrained to current open in-scope
  goals and the chosen continuation is persisted before council closure is acknowledged.
- The next-cycle barrier contains only evidence needed for safe focus selection. GitHub
  discovery and rich suggestion rendering are recoverable non-blocking sidecars; a hung
  sidecar cannot delay next-cycle reservation/launch. Council members return exact open
  goal references and core uses a deterministic weight/stable-id tie-break without another
  critical-path model call.
- Unanimous fast-council `complete` only enqueues a fresh exhaustive five-member council
  with the adversary. Exhaustive `complete` only nominates certification; neither council
  can publish a terminal state, and any negative finding immediately becomes repair work.
- Cost, time, token count, cycle count, retry count, ROI, trend, and diminishing returns
  are informational and never stop or pause an incomplete run.
- Every builder gets exactly two predefined quality skills and two lane-specific skill
  assignments. Only an unavailable predefined quality skill may use its approved embedded
  behavioral equivalent; both lane-specific assignments always resolve to installed
  external or package-bundled skills.
- Every installed assignment is snapshotted as a bounded content-addressed complete skill
  tree and passed to its detached builder as a hash-verified, materialized `SKILL.md` body;
  an id-only mention, mutable host-path reread, or self-attested evidence is insufficient.
- Council, adversary, promotion, recovery, and certification claims are accepted only from
  immutable actor artifacts plus authenticated ledger events and hashes. Tests and canaries
  derive their counters from those events; they never seed the expected totals directly.
- GitHub skill suggestions are informational, attributed, permission-audited, and never
  auto-installed.
- Every active session exposes exactly `tmux attach -t polylane-<loop-id>`.
- Completion requires two consecutive clean exhaustive certifications, then exactly 30
  ranked informational beyond-scope suggestions.
- Product source/tests/config/docs outside the closed Polylane control schema must be clean
  for both certifications. Final response waits for `TEARDOWN_COMPLETE`; the deterministic
  30-item delivery remains pending until a later real host/user receipt.
- Every behavior change is test-driven and committed only after its focused and relevant
  regression suites pass.

## Execution Order

1. [Codex Package Foundation](/Users/leonardo/Downloads/polylane/docs/superpowers/plans/2026-07-16-codex-package-foundation.md)
   establishes the canonical core, thin adapters, modern CLI contract, semantic workflow,
   package parity, and one-cycle Codex/tmux proof.
2. [Codex Builder Skill Kits](/Users/leonardo/Downloads/polylane/docs/superpowers/plans/2026-07-16-codex-builder-skill-kits.md)
   adds exact four-skill assignments, evidence scoring, and the GitHub suggester on top of
   the extracted core.
3. [Codex Persistent Autonomy and Liveness](/Users/leonardo/Downloads/polylane/docs/superpowers/plans/2026-07-16-codex-persistent-autonomy.md)
   adds the stable tmux loop, runtime event ledger, progress leases, recovery queue,
   guardian, fast cycles, perfection, soak testing, real two-cycle continuity canary, and
   final active installation.

Execute strictly in the listed order: finish and verify Package Foundation, then finish and
verify Builder Skill Kits, then start Persistent Autonomy. This avoids shared-file races in
the workflow, prompt, scout, package, and test surfaces. Do not install the active user
skill until all three plans are green.

## Shared Interface Freeze

The three plans use these exact names:

```text
stable loop identifier: loop_id
per-cycle marker nonce: run_id
session: polylane-<loop_id>
windows: controller, lanes
durable controller state: docs/polylane/controller-state.json
operational state pointer: .polylane/runtime/current
atomic operational snapshots: .polylane/runtime/snapshots/<revision>/
watch command: .polylane/watch-command
skill kit: docs/polylane/skill-kits/cycle-<N>.json
skill evidence ledger: docs/polylane/skills-ledger.jsonl
GitHub suggestions: docs/polylane/github-suggestions.jsonl
perfection state: docs/polylane/perfection.json
final suggestions: docs/polylane/final-suggestions.json
```

`loop_id` remains stable across cycles. Each manifest `run_id` is unique to that cycle, so
stale DONE or verdict markers can never satisfy a later cycle. In user-facing text,
`loop_id` is the run id shown in `tmux attach -t polylane-<run-id>`; the internal name only
distinguishes it from the already-frozen per-cycle marker field.

## Completion Gate for the Plan Set

- [ ] All focused tests named by all three plans pass.
- [ ] `POLYLANE_MIN_DISK_GB=0 tests/run.sh` passes with zero failed test files.
- [ ] All shipped shell files pass `bash -n` and `shellcheck -S warning`.
- [ ] The accelerated six-hour fault soak records
  `max_unexplained_idle_gap=0`.
- [ ] The real Codex continuity canary completes two cycles in one stable tmux session,
  recovers one injected failure, and records two GO promotions.
- [ ] A fresh Codex package exactly matches the installed active Codex skill.
- [ ] A fresh real Codex CLI invokes the active installed `$polylane` skill from a
  user-style prompt and reaches tmux-backed verified completion with final delivery.
- [ ] The active install uses pre-swap guarded activation, rolls back on publisher SIGKILL
  before `PUBLISHED` and certification-owner SIGKILL before `COMMITTED`, and never migrates
  a legacy directory while an owned Polylane user is active.
- [ ] Queue reservation rejects stale revisions, changed ownership proofs, and overlapping
  canonical `ownership_globs` or `resource_locks`; activation binds the claim to one
  worker PID/start token, every later mutation revalidates that identity, and an expired
  worker is fenced before its ownership can be reserved again.
- [ ] Every installed file is covered by a deterministic whole-package manifest in addition
  to shared-core parity; activation and installed-skill comparison reject adapter or skill
  tampering as well as core tampering.
- [ ] Runtime event content is hash-chained and replay-verified; tamper, deletion, reorder,
  reducer crash, compactor crash, stale wake metadata, and ENOSPC fixtures all recover or
  fail closed without an unexplained idle interval.
- [ ] Council-boundary crash fixtures prove that verdict persistence, promotion, and
  next-cycle enqueue are replay-safe: `GO`, `NO_GO`, abstention, and invalid evidence all
  continue autonomously and none directly stops, tears down, or emits a terminal state.
- [ ] With GitHub discovery and suggestion rendering deliberately hung, an authenticated
  council result still produces a running next-cycle claim within one guardian tick; the
  sidecars recover independently and their durable outputs remain replayable.
- [ ] The legacy cycle supervisor may return a typed cycle result, but Codex integration
  tests prove its exit code/report cannot terminate the persistent controller, become a
  final host response, or satisfy shutdown while any locked goal remains open.
- [ ] Controller overrides preserve arbitrary safe argv elements without shell evaluation,
  and reject noncanonical executables or unsafe argv-file permissions.
- [ ] Root Claude Code compatibility tests remain green.
- [ ] The worktree is clean and no canary tmux session remains.
- [ ] Runtime evidence is `TEARDOWN_COMPLETE`, all owned actor/guardian/finalizer PIDs are
  gone, and final delivery is replayable until a later receipt.

## Acceptance-Criteria Routing

| Approved criterion | Owning plan |
|---|---|
| 1–8 and 10: layout, shared parity, Codex CLI, fail-closed identity, package proof, compatibility | Package Foundation |
| 9: install the fully verified active Codex skill | Persistent Autonomy |
| 11–14: persistent resume, terminal states, adaptive cycles, watch command | Persistent Autonomy |
| 15–16: four-skill builders and GitHub suggestions | Builder Skill Kits |
| 17–18: two clean certifications and cycle/final suggestions | Persistent Autonomy |
| 19–23: progress leases, queue invariant, provider recovery, event replay, soak/live continuity | Persistent Autonomy |

## Execution Protocol

This file is an index and cross-plan acceptance contract, not a fourth implementation
plan. Track work only in the three child plans. Finish every checkbox and commit in one
child plan before opening the next. After the third plan, run this file's Completion Gate
as the final cross-plan audit; do not mark a child step complete from this index.
