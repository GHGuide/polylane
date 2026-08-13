# Lifecycle and external-routing verification — m32.6

Run: `c42a-taste-contracts-20260813-a2`

## Outcome

Executable v3 now separates acceptance authority (`evidence_kind`) from cadence
(`tier`), makes worker finalization transactional, keeps worker-owned handoff bytes
immutable to the runner, and bases recovery on durable elapsed transitions rather
than pane paint. This is machine lifecycle/evidence certification only. It does not
claim human certification and does not mark any external evidence passed.

## Root-cause and RED evidence

Cycle 41 combined four independent authorities: external status was used as a proxy
for which command could execute; the runner repaired worker evidence in place;
changing pane hashes reset a check-count timer; and runner PID liveness stood in for
supervisor progress. That allowed external-open to mask autonomous failure, repair
to mutate the committed handoff, pane churn to avoid timeout, and a stalled runner to
remain live indefinitely.

The regressions were written and observed red before implementation:

- `test-memory.sh`: 63 pass, 8 fail — missing evidence-kind storage/filter/dedupe.
- `test-contract-acceptance.sh`: 41 pass, 1 fail — stale m32.4 authority remained.
- `test-finalization-watchdog.sh`: 5 pass, 13 fail — helper/state machine absent;
  changing pane output did not time out.
- `test-verdict-repair.sh`: 62 pass, 2 fail — admitted repair deleted status/verdict.
- `test-supervisor.sh`: stalled-runner case did not terminate until the RED harness
  was stopped; PID liveness had no independent progress deadline.

## Frozen contracts

### Evidence routing and provenance

- `add-accept --evidence-kind autonomous|external` is independent from
  `--tier focused|terminal`; omitted legacy kind is autonomous.
- Adding a second kind to one subgoal is rejected. Contract-v3 manifests declare a
  run kind and explicit roles; an autonomous manifest targeting an external-kind
  subgoal is rejected before launch.
- Autonomous host gates pass `--evidence-kind autonomous` in focused and terminal
  phases. External checks are never locally executed or repaired.
- `EXTERNAL-EVIDENCE-OPEN` resolves only after every selected autonomous check
  passes. A failed autonomous check remains a gate failure.
- Evidence kind is included in stored fingerprints, keyed dedupe identity, focused
  proof definitions, promotion state comparisons, unmet/regression output, and
  acceptance reports.

The host explicitly kept `docs/polylane/max-state.json` outside this lane. The owned
regression pins all three stale m32.4 entries as external and nonpassing, including
the certificate command missing `SUBJECT_ROOT`, its obsolete `confidence_lower`
predicate (v2 emits `wilson_lower_bound`), and the unregistered
`calibration-summary.json` authority. They are never executed by autonomous gates.

### Transactional finalization

`bin/polylane-finalize.sh` is invoked by the worker with explicit project root,
worktree, lane, run id, and `builder|integrator` role. It atomically persists:

`WORKING → HANDOFF_PENDING → HANDOFF_COMMITTED → QUIESCING → DONE`

The helper alone writes and commits the exact status marker and, for the explicit
integrator role, exactly one current-run verdict as the final evidence line. The
receipt binds role, run, worktree, implementation HEAD, handoff HEAD, marker hash,
verdict hash, and transition epoch. Recovery checkpoints reject
`HANDOFF_PENDING`. The runner verifies exact committed bytes, HEAD, hashes, clean
tree, scope, and worker exit; v3 paths do not clear, normalize, append, delete,
salvage-copy, or recommit status/verdict bytes.

The partial-handoff fault (`POLYLANE_FINALIZE_INTERRUPT=after-marker`) left state at
`HANDOFF_PENDING`, preserved marker bytes and HEAD across a rejected runner
checkpoint, and was recovered only by a second worker-owned finalizer invocation.
The custom integrator `verifier-x` proved role is explicit rather than name-derived.

### Timing and supervision

- Lane wedge detection persists a durable material fingerprint and
  `transition_epoch`; pane repaints cannot reset elapsed time.
- The independent supervisor watchdog fingerprints worktree HEAD/status,
  finalization receipts, run statistics, events, coordination, and the terminal
  report. A live child with no durable transition is terminated and routed through
  bounded supervisor recovery after `POLYLANE_SUP_PROGRESS_TIMEOUT` (default 7200s).
- Hook fragments receive explicit worker id, run id, and role. The verify gate maps
  evidence from role, so a custom-named integrator still uses
  `docs/verify-integration.md`.

## Backwards compatibility

- Legacy acceptance JSON without `evidence_kind` executes as autonomous.
- Contract-v2 marker-only, nonce, committed-clean, READY handoff, graph-link, and
  runtime-prompt cases remain green.
- V2 cleanup/normalization stays available only for legacy recovery; v3 uses the
  immutable receipt contract.
- Existing unkeyed acceptance and cadence-only registrations remain valid.

## Risk register

| Risk | Level | Mitigation | Status |
|---|---|---|---|
| External-open masks an autonomous failure | Critical | Kind-filter autonomous gates first; resolve routing afterward | Mitigated |
| Recovery commits a partial or mutates a final handoff | Critical | Pending-state checkpoint refusal; exact HEAD/hash/clean verification | Mitigated |
| Pane spinner prevents timeout | High | Persist elapsed time from durable transition, never pane hash | Mitigated |
| Runner stays alive but stops coordinating | High | Independent supervisor durable-progress watchdog | Mitigated |
| Stale m32.4 command is treated as authority | High | Keep all three external/nonpassing and never autonomously execute; host retires after promotion | Open, contained |

## Verification

The prescribed `$POLYLANE_PROJECT_ROOT/bin/polylane-check.sh` was absent from the
runtime bundle (only coordination/worker/refinement helpers were installed). The
same cache directory and semantics were used with the source-root identical helper:
`bin/polylane-check.sh "$PWD/.polylane/check-cache/lifecycle-external-routing"`.

Focused owned suite totals after implementation:

- `test-finalization-watchdog.sh`: 18 pass, 0 fail
- `test-memory.sh`: 71 pass, 0 fail
- `test-contract-acceptance.sh`: 42 pass, 0 fail
- `test-verdict-repair.sh`: 64 pass, 0 fail
- `test-lane-done.sh`: 27 pass, 0 fail
- `test-lane-done-live.sh`: 18 pass, 0 fail
- `test-supervisor.sh`: 41 pass, 0 fail
- `test-hooks.sh`: 57 pass, 0 fail
- `test-skill-parity.sh`: 72 pass, 0 fail

Owned test total: **410 pass, 0 fail**.

Additional required gates: ShellCheck warning-clean on every owned shell file;
marker-doc check green; skill parity included above; `git diff --check` green.

## Skill receipts

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: engineering:testing-strategy — helped: separated memory unit,
runner contract, live lifecycle, supervisor integration, and hook role cases while
retaining a fast 410-assertion owned suite.

SKILL-EVIDENCE: operations:risk-assessment — helped: prioritized four critical/high
control-plane risks and kept the stale external authority open but contained.

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: traced mutation,
evidence-routing, pane timing, and supervisor liveness to separate root causes before
changing production paths.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: each requested failure
was observed red before the minimal implementation and then retained as a regression.

## DEFERRED

DEFERRED: retire/replace the three stale m32.4 external commands in max-state — host-owned post-promotion action per coordination decision seq=2; this lane did not broaden OWN.

DEFERRED: mirror v3 lifecycle/evidence language into `codex/SKILL.md` — outside this lane's OWN; requested from the integrator before final skill packaging.
