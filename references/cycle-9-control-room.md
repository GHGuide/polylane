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
- `polylane-scout.sh resolve <skill>` prints the trusted installed `SKILL.md`.
  `recommend <domain> <activity>` is installed-only and ledger-ranked;
  `record-outcome <ledger> <lane> <domain> <skill> <helped|unused|hurt> [why]`
  appends learning. Select the smallest useful kit: at least one skill per role,
  no more than four unique skills, never filler.

## Runtime quality boundary

- `bin/polylane-advanced.sh preflight|select|salvage|record <manifest> ...` is
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

Lane status comes solely from `polylane-state` and runner helpers. A DONE marker
must be the exact current-run first line `STATUS: <lane> DONE run=<run_id>` with
the literal nonce. A final newline is optional: `polylane-markers.sh done` emits
the exact marker without one. Bare, stale, mismatched, incomplete, or
first-line-extra markers are not done.
The dashboard must not grow a competing marker parser or state engine.
