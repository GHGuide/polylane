# Cycle 13 emergent questions — autonomous defaults

No user decision is required for the newly discovered failures; the safe recommended
defaults were applied automatically.

- Promotion writes: stage or commit only declared runner-owned durable files before
  merge, and prove unrelated user changes remain untouched. **Selected:** recommended.
  Alternatives retained for a deeper round: isolate all runtime state outside Git; or
  surprise route—promote through a temporary bare integration ref.
- Liveness: treat an active agent process/turn as live even when output is quiet, with a
  longer bounded timeout and dead-pane recovery unchanged. **Selected:** recommended.
  Deeper option: adaptive thresholds from historical effort; bold option: explicit
  agent heartbeat protocol.
- Worker history: resolve every lane operation to the canonical project ledger and use
  its lock/sequence allocator. **Selected:** recommended. Deeper option: event IDs with
  compare-and-swap; bold option: a dedicated local event daemon.
- Skill delivery: put a trusted resolved `SKILL.md` path in each selected lane kit and
  require a read/use receipt. **Selected:** recommended. Deeper option: vendor immutable
  project-local snapshots; bold option: benchmark competing skill kits per lane.
