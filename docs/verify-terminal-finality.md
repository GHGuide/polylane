# Terminal finality verification

## Root-cause ordering

1. Cycle 25 treated an immutable restart/supervisor failure as repairable, so a
   completed integrator was asked to repair runner-owned telemetry.
2. The integration repair addendum repeated strict `DELEGATION` and
   `CHECK-CACHE` scalars. Prompt admission correctly rejected that replacement.
3. Recovery had already checkpointed and removed current status/verdict evidence
   before it learned admission failed.
4. A post-integrator graph return skipped reporting, so the supervisor interpreted
   the reportless exit as a crash and revived it.

## Red/green evidence

The initial cached red run of `test-promptopt.sh` rejected the repair prompt with
`duplicated exact-once label` and counted both scalar labels twice. The final
cached focused set is green: 391 assertions across promptopt (22), verdict repair
(50), supervisor (34), write report (41), efficiency (25), graph authority (56),
skill parity (59), runtime recovery (15), session resume (8), clear markers (5),
run stats (1), state (19), contract acceptance (19), parse verdict (23), and
orchestration contract (14).

## Transaction invariants

- Repair construction writes a prepared replacement and strictly admits it before
  branch checkpointing, evidence archival/removal, `INT_PROMPT` replacement,
  runtime refresh, pane respawn, or restart telemetry.
- A forced admission rejection proves unchanged HEAD, committed status bytes,
  committed verdict bytes, pane activity, and restart counters.
- Repair addenda retain original scalar lines and add only ordinary prose; strict
  promptopt admission proves every scalar occurs once.
- Known excessive launches or lane/supervisor restarts produce runner-owned,
  nonrepairable NO-GO before `terminal_gates` changes. Unknown tokens remain
  `unknown`, never zero.
- Post-integrator graph/bookkeeping failures report `HALTED` and remain
  recoverable; genuine exhausted visual/judge or established NO-GO paths make one
  NO-GO report attempt before returning. Publication is idempotent. Report write
  failure remains reportless and recoverable. Supervisor terminality requires both
  freshness and `**Run:**` for the current nonce, while a current fresh NO-GO ends
  after one launch.

## Compatibility boundaries

Preflight and unfinished-lane crashes still produce no terminal report and remain
supervisor-recoverable. Marker nonce, clean-tree completion, scope, pane identity,
worker inbox, custom policy, frozen acceptance, and graph admission stay covered by
the focused compatibility checks above.

## ShellCheck and diff

`shellcheck -S warning bin/polylane-run.sh bin/polylane-supervisor.sh
bin/polylane-efficiency.sh bin/polylane-run-stats.sh` passed through the lane cache.

Exact owned diff: `bin/polylane-run.sh`, `bin/polylane-supervisor.sh`, `SKILL.md`,
`codex/SKILL.md`, `references/planning.md`, `references/prompt-blocks.md`,
`tests/test-promptopt.sh`, `tests/test-verdict-repair.sh`, `tests/test-supervisor.sh`,
`tests/test-graph-authority.sh`, and this verification record.

## Skill receipts

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: separated the observed chain into scalar admission, destructive recovery ordering, and reportless supervisor recovery before changing semantics.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the strict-scalar and forced-admission regressions failed before the corresponding runner changes and pass afterward.
