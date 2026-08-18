# Evidence-driven domain autonomy

This is the executable cycle contract for domain work. It adds evidence gates to
the shared runner; it does not authorize any external action.

## Discovery and final handoff

Initialize the selected adapter tree with
`polylane-discovery.sh init <state> <brief> <kind>`. Use `next` and `answer` as
the interaction surface. Keep **Go deeper** on the adapter-provided branch, not a
generic follow-up. At cycle close, ask a newly emergent question only when its
answer could change a deliverable, evidence, risk, or next focus. Otherwise write
the short outcome report first, then `Next:`, then continue autonomously.

The final profile handoff names actual artifact paths, source/provenance, the
bundle and grade result, residual risk/uncertainty, open external evidence, and
only material next questions. A trading handoff remains research/backtest/paper
evidence unless separately authorized live execution proof exists.

## Runner manifest gates

Opt in only after the profile record is ready:

```json
{
  "domain_runtime": {
    "enabled": true,
    "profile": "docs/polylane/PROJECT_PROFILE.json",
    "registration": ".polylane/domain-runtime/grader-registration.json",
    "bundle": "docs/polylane/domain-runtime/bundle.json",
    "grade": "docs/polylane/domain-runtime/grade.json"
  },
  "outcome_learning": {
    "enabled": true,
    "ledger": "docs/polylane/accepted-outcomes.jsonl",
    "domain": "research",
    "lane_shapes": {"evidence": "research-evidence-v1"},
    "minimum_samples": 3
  }
}
```

All four `domain_runtime` paths must be project-relative and traversal-safe;
`registration` remains under `.polylane/` runner scratch. Before panes launch the
runner validates the profile and writes an executable grader registration. Before promotion it creates a checksum-bearing
bundle in the integrator worktree and requires a `domain-runtime/grade-v1` `PASS`.
This is a profile-specific final gate, not a file-presence check.

At the plan gate, outcome learning compares only accepted, lane-shaped receipts.
It logs every recommendation and reason. It applies one available model or effort
change only when samples/confidence are measured and the role clamps permit it.
Thin samples, ties, unavailable models, integrators, and lane/context changes leave
the user's chosen intensity/default in force. After promotion it writes an accepted
cycle receipt; absent telemetry remains `unknown` and never becomes optimizer data.

## Trials and canaries

Run the compact public-source snapshot corpus deterministically:

```bash
bin/polylane-domain-trials.sh validate benchmarks/domain-trials/v1
bin/polylane-domain-trials.sh run benchmarks/domain-trials/v1 .polylane/domain-trials
bin/polylane-domain-trials.sh summarize .polylane/domain-trials --json
```

`--live --domain <kind>` is an opt-in, single read-only GET with a bounded timeout.
It writes `live-receipt.json`; network absence is `SKIP`, never `PASS`, and it does
not affect offline CI or replace the pinned raw extract.

## Soak operations

Accelerated certification (safe to run during integration):

```bash
bin/polylane-soak.sh run .polylane/soak/accelerated --accelerated --iterations 8 --seed 41
```

Wall-clock certification (operator run, never an integration wait):

```bash
bin/polylane-soak.sh configure .polylane/soak/6h --hours 6 --seed 41
bin/polylane-soak.sh run .polylane/soak/6h --hours 6 --seed 41
bin/polylane-soak.sh configure .polylane/soak/12h --hours 12 --seed 41
bin/polylane-soak.sh run .polylane/soak/12h --hours 12 --seed 41
bin/polylane-soak.sh configure .polylane/soak/24h --hours 24 --seed 41
bin/polylane-soak.sh run .polylane/soak/24h --hours 24 --seed 41
```

Re-run the same `run` command to resume. Inspect `state.json`, `state.json.bak`,
`events.jsonl`, `faults/*.json`, and `summary.json` in the selected run directory.
The run directory is isolated fixture storage; expect a small JSON/event receipt per
fault and no tmux, git branch, home-directory, network, or external-system mutation.

## Skill and action boundaries

The scout may show candidate, blocked, and **None**. Only a matching fingerprinted,
hard-passing lane-shaped benchmark with sufficient samples is `recommended` and
`safe_to_apply`; arming rejects every other status.

Before a consequential action, prepare and verify the exact payload receipt:

```bash
bin/polylane-action-preview.sh prepare <profile.json> <action> <payload.json> <receipt.json>
bin/polylane-action-preview.sh verify <receipt.json> <payload.json>
```

Surface a critical approval request in the main chat and require its `receipt_id`.
`approve` records only that exact identity. Any changed payload, receipt, secret-like
field, live/execute verb, or absent simulation evidence is rejected. The helper has
no execute command; approval never grants authority to perform the action.
