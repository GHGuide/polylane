# Cycle 14 research — failures observed in the live self-run

The evidence is direct rather than speculative. `check-accept` correctly updated the
canonical durable state before promotion, while retained-worker telemetry appended to
the canonical history. `promote_to_main` then called `git merge` against that dirty base,
so Git refused to overwrite `max-state.json` and `history.jsonl`. `write_report` received
the engineering verdict rather than a promotion result and consequently said the work
was merged and cleaned when neither happened. Separately, `lane_terminal_turn` matched
ordinary completed command events, so quiet but active high-effort Codex work consumed
the short terminal wedge budget. Finally, the integrator and canonical checkout each
allocated worker sequence 27 independently, producing an append-only merge conflict.

The repair principle is one authority per mutable truth: a declared transaction for
runner-owned pre-promotion files, an explicit `PROMOTED` outcome for reports, process and
turn semantics for liveness, a canonical root for worker history, and resolved immutable
paths for skill delivery. Every correction gets a regression reproducing the exact
cycle-13 failure.
