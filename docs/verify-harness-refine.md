# Harness/refinement verification

## TDD evidence

RED was observed before either production command existed:

```text
bash tests/test-harness.sh
FAIL harness-initializes-store — expected rc 0, got 1
... polylane-harness.sh: No such file or directory

bash tests/test-refine.sh
FAIL refine-initializes-harness-state — expected rc 0, got 1
... polylane-harness.sh: No such file or directory
```

GREEN:

```text
bash tests/test-harness.sh  # 23 pass, 0 fail
bash tests/test-refine.sh   # 28 pass, 0 fail
bash -n bin/polylane-harness.sh bin/polylane-refine.sh
shellcheck -S warning bin/polylane-harness.sh bin/polylane-refine.sh
```

All GREEN commands exit 0. Commit hash is recorded after the implementation commit below.

## API contract

`bin/polylane-harness.sh` owns a `polylane-harness/v1` store and exposes
`init`, `create`, `update`, `delete`, `read`, `list`, `history`, and `rollback`.
Entries are typed as `prompt`, `memory`, `skill`, or `subagent`, scoped `local`
or `global`, use stable safe IDs, retain immutable version snapshots, and require
the expected current version for every mutation. State and snapshots use lock plus
temporary-file/rename writes; mutation history is append-only with before/after
records. Base/system IDs are refused. Global `prompt` and `skill` entries are
always inactive `proposal-only` records that name
`bin/polylane-skill-evolve.sh`; global `memory` and `subagent` entries are active
and typed.

`bin/polylane-refine.sh` exposes `observe`, `eligible`, `propose`, and
`validate`. Two observations of the same signal for a subject are required; the
supported signals are `failure`, `stall`, `no-go`, and `compaction`. A proposal
captures evidence, creation/deadline cycles, an executable bounded check, and
the exact before/after harness snapshots. Validation is only allowed in a later
cycle. Passing checks mark a proposal `validated`; failing or expired checks
compare-and-swap rollback to the captured snapshot (or delete a created entry).
Every validation decision is append-only. Refinement only calls the harness API:
it cannot mark product goals complete or self-promote global prompt/skill changes.

Implementation commit hash: `291cc854afee73d4dd5198315eb832a90b18d7fa`
