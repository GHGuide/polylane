# STORY SO FAR — corpus through cycle 4

## Earlier (one line each)
cycle 1: Cycle 1 digest — install-test + docs-truth

## Recent (verbatim, last 3 cycles)

===== cycle 2 =====
# Cycle 2 digest — explicit execution graph

## Built

- `bin/polylane-graph.sh`: deterministic contract-v2 manifest compiler, schema-v1
  validator, bounded-loop checks, terminal reachability, and ready-node routing.
- `bin/polylane-events.sh`: locked append-only transition ledger with run/graph
  scoping, strict transition validation, idempotent writes, verification, and replay.
- Runner shadow integration: each observed builder, integrator, verifier, repair,
  promotion, resume, and halt transition is checked against the compiled graph.
- 122 focused assertions across graph contract, event replay, and shadow parity.
- Failed frozen acceptance checks now name the exact subgoal and command instead of
  collapsing into an unexplained integrator NO-GO.

## Verified

- Integrator verdict: GO after one repair pass.
- Merged tree: 852 tests passed, 0 failed, 57 test files.
- `shellcheck -S warning bin/*.sh`: clean.
- `m6.1` and `m6.2` frozen acceptance passed in the integration worktree.

## Learned

- The synthetic benchmark fixture emits a schema-invalid graph, so it cannot benchmark
  production behavior yet.
- A 64-lane graph plus 10,000-event ledger currently costs about 180 ms per graph
  validate/ready call, 820 ms per event verify/replay, and 890 ms per append. Re-reading
  the full ledger on every transition will not scale as an authoritative scheduler.
- Codex `workspace-write` cannot commit through a linked worktree unless the canonical
  Git metadata directory is added as writable.
- The runner's `graphify-out` symlink can make an otherwise complete lane look dirty.
- A dead tmux session with a live polling runner is not currently self-healing.
- The dashboard test has a race: non-empty output is not proof that the first frame is
  complete.


===== cycle 3 =====
# Cycle 3 digest — authoritative graph runtime

## Built

- Contract-v2 execution now defaults to an authoritative graph scheduler. Every builder,
  join, integrator, verifier, repair, promotion, completion, and halt action is admitted
  only when the immutable graph says its node is ready.
- Codex `workspace-write` receives only the canonical linked-worktree Git metadata path;
  full filesystem access is no longer required for ordinary lanes.
- Event replay uses validated checkpoints while retaining strict fallback after malformed
  sidecars, inode replacement, truncation, or graph/run identity changes.
- Readiness semantics distinguish joins from routed nodes and include bounded loop edges.
- The 10,000-event benchmark fixture now uses only nodes declared by its valid compiled
  64-lane graph.
- Missing owned tmux sessions return a recoverable status for the supervisor.
- Runner-owned `graphify-out` links no longer make clean completed lanes look dirty.
- Post-promotion cleanup failure is now nonfatal, preserves late unverified branches, and
  `--resume` finishes cleanup/report from graph-backed durable evidence.

## Verified

- Three frozen benchmark runs: complete packets 1,836–2,001 ms; warm readiness 61–91 ms;
  warm append 116–120 ms. Independent post-promotion run: 1,864–1,892 ms.
- `tests/run.sh`: 940 passed, 0 failed across 61 test files after recovery hardening.
- `shellcheck -S warning bin/*.sh`: clean.
- Real two-builder + integrator cycle reached GO and promoted to `main`; its interrupted
  cleanup was recovered by the updated production `--resume` path.
- `bin/polylane-doctor.sh --rehearse`: both GO and NO-GO cases passed.

## Learned

- A safe `git branch -d` refusal was incorrectly fatal after promotion; transactional
  boundaries matter more than happy-path test count.
- A worker can produce a late commit after the integrator has captured its verified tip.
  The correct behavior is preserve, report, and continue—not force-delete or fail GO.
- The current rehearsal is still a legacy-contract mock, so it does not yet prove the
  authoritative graph contract end to end.
- Status markers committed for polling become tracked deletions after cleanup.
- Report next-step scraping reads historical examples and commands as if they were current
  actions; it needs structured, run-scoped extraction.
- A pane merely containing the words “usage limit” can be misclassified as a paywall even
  while the agent is discussing source code.

===== cycle 4 =====
# Cycle 4 digest — real walk-away proof

## Built

- The contract-v2 rehearsal now executes real supervised GO and NO-GO lifecycles. GO promotes
  and cleans; NO-GO withholds promotion, retains evidence, bounds repair, then cleans its fixture.
- Runtime paywall detection requires an actionable credits/upgrade decision instead of matching
  source or prose that happens to say “usage limit”.
- Cleanup canonicalizes macOS `/var` and `/private/var` worktree paths and accepts intentional
  durable goal-state updates while still rejecting leaked runtime markers.
- Graph and event CLIs run on Apple jq as well as Homebrew jq; the benchmark harness now does too.
- A failed verifier can resume through the declared repair loop when committed current-run GO
  evidence proves the repair finished before the prior runner died.
- Fresh-clone installers and session tests distinguish a real product failure from a worker
  sandbox that cannot write the project or open the host tmux socket.

## Verified

- Real two-builder + integrator Codex cycle reached a legitimate supervised GO and promoted.
- `tests/run.sh`: 954 passed, 0 failed across 62 test files; ShellCheck clean.
- Host rehearsal: `REHEARSE-GO ... promoted=1 cleaned=1 leaks=0`; `REHEARSE-NOGO ...
  promoted=0 evidence=1 retained=1 bounded=1 cleaned=1`.
- Homebrew jq: ready 62 ms, append 116 ms, full packet 1,861–1,882 ms.
- Apple jq: ready 54 ms, append 109 ms, full packet 1,845–1,870 ms.

## Learned

- Graph execution is not the current bottleneck. Prompt breadth, repeated skill reads, repeated
  terminal suites, dead-pane recovery, and lost resume telemetry dominate time and tokens.
- A live Codex PID is not proof of progress: one worker wedged after a skills-context error and
  stayed “working” indefinitely until externally interrupted.
- `tmux respawn-pane` against a vanished pane fails, but the old fallback sent keys to that same
  nonexistent target and still consumed retries. Recovery must recreate and remap the pane.
- Worker sandboxes cannot truthfully grade host-only tmux behavior. They need an explicit
  host-gate handoff; only the outer runner should execute and certify terminal host checks.
- The canonical project `.polylane/check-cache` is outside a linked worktree's write sandbox.
  The cache must live inside the lane worktree.
- Cycle reporting lost prior-run token and wall evidence on resume, rendering unknown as zero.
  Metrics need an append-only per-run snapshot independent of one runner process.

