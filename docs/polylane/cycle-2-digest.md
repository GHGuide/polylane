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

