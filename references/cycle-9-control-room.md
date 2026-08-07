# Cycle 9 runtime contracts

This is the compact operational reference for the measured-product-autonomy
surface. `docs/polylane/cycle-9-plan.md` is the frozen source of truth; do not
invent flags, defaults, success states, or substitute a local reconstruction.

## Product evidence and discovery

- `bin/polylane-product-benchmark.sh validate <corpus-dir>` validates every
  benchmark case. `run <corpus-dir> <out-dir> -- <adapter...>` isolates every
  case and exports `POLYLANE_BENCH_CASE`, `POLYLANE_BENCH_WORKDIR`, and
  `POLYLANE_BENCH_RESULT`. `summarize <out-dir> [--json]` keeps unknown metrics
  unknown; it never turns them into zero.
- `bin/polylane-discovery.sh init <state> <brief>`, `next <state> [limit]`,
  `answer <state> <question-id> <recommended|deep|bold|custom> [text]`,
  `contradict <state> <answer-id> <answer-id> <reason>`,
  `resolve <state> <contradiction-id> <accept-left|accept-right|accept-both> [note]`,
  `summary <state>`, and `lock <state> <docs-dir>` provide durable discovery.
  Deep and bold answers create or activate a child; strategy summaries stay
  transcript-free.

## Agent-aware launch and lean prompts

- `bin/polylane-models.sh [claude|codex]` keeps model families separate. Codex
  reads `${CODEX_HOME:-$HOME/.codex}/models_cache.json` when available and
  returns only `gpt-*` IDs, with a current Codex fallback.
- Manifest `codex_profile` is `lean|user`, default `lean`. Lean Codex launches
  add `--ephemeral --ignore-user-config`; the explicit model, effort, sandbox,
  and approval policy remain visible in the launch contract.
- `bin/polylane-promptopt.sh check <prompt> [budget]` and `metrics <prompt>`
  preserve all strict blocks and reject an over-budget prompt before launch.
  Manifest `prompt_token_budget` defaults to 8000; optional `prompt_byte_budget`
  adds a separate byte ceiling.
- `polylane-scout.sh resolve <skill>` prints the trusted installed `SKILL.md`.
  `recommend <domain> <activity>` is installed-only and ledger-ranked;
  `record-outcome <ledger> <lane> <domain> <skill> <helped|unused|hurt> [why]`
  appends learning. Select the smallest useful kit: at least one skill per role,
  no more than four unique skills, never filler.

## Runtime quality boundary

- `bin/polylane-advanced.sh preflight|select|salvage|seams|record <manifest> ...` is
  the only runner-facing adapter for outcomes, seams, champion selection, and
  configured salvage. It reports absent optional work as `not-requested`.
- `bin/polylane-judges.sh run <manifest> <tree> <out-dir>` requires exactly
  three independent manifest-defined `quality_judges` with `name`, `lens`,
  `command`, and `timeout_s`. Its typed graph boundary is `judges` then one
  bounded `judge-repair` route; repair cannot loop indefinitely.

## Canonical control room

`bin/polylane-dashboard.sh <manifest> --once --json` emits one read-only
`polylane-control-room/v1` snapshot. Its required fields are `schema`, `goal`,
`cycle`, `run_id`, `route`, `graph`, `lanes`, `spend`, `verdict`, `heartbeat`,
`cleanup`, and `next_action`. It projects `polylane-state --json`, the durable
max-state, graph event ledger, report, spend ledger, and cleanup telemetry.
Missing facts are `null`/`unknown`, never made into a pass or zero. Interactive
dashboard rendering repeatedly consumes that same snapshot.

## Skill evolution boundary

`bin/polylane-skill-evolve.sh` is the only skill champion/challenger state
machine. It snapshots evaluators at `init`, records deduplicated cycle evidence,
hides promotion cases from mutation packets, and admits promotion only after
development/hidden deltas, cost ceilings, and three blind judges pass. Activation
is compare-and-swap protected; `canary` rolls back a failing promoted generation
and `recover` resolves an interrupted activation journal. See
`skill-evolution.md`; never rewrite an active skill from a reflection hook.

## Prime hybrid continuity boundary

`"prime_hybrid": true` is the opt-in runtime for long product work. Before a
lane launches, `polylane-run.sh` initializes canonical harness and worker state,
validates prior-cycle refinement checks, imports the append-only relay, retains
stable identities, and generates `.polylane/context/<lane>.md` within a hard
byte budget. Every pane receives `POLYLANE_HARNESS_DIR`, `POLYLANE_WORKERS_DIR`,
`POLYLANE_WORKER_ID`, and `POLYLANE_CONTEXT_PACKET`; the packet is read once and
follow-ups use the durable inbox. Completion capsules and observations of failure,
stall, NO-GO, and compaction remain under `docs/polylane/`, not a worktree.

Repeated evidence may produce a local proposal only with an executable expected
check; the next cycle validates or rolls back its immutable snapshot. Global
prompt/skill proposals are inactive handoffs to `bin/polylane-skill-evolve.sh`.
They cannot directly overwrite either `SKILL.md` or an installed skill.

Lane status comes solely from `polylane-state` and runner helpers. A DONE marker
must be the exact current-run first line `STATUS: <lane> DONE run=<run_id>` with
the literal nonce. A final newline is optional: `polylane-markers.sh done` emits
the exact marker without one. Bare, stale, mismatched, incomplete, or
first-line-extra markers are not done.
The dashboard must not grow a competing marker parser or state engine.
