# Recovery runtime verification

## Red

The regression tests were added before runtime changes and initially failed:

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/recovery-runtime" -- bash tests/test-runtime-recovery.sh
```

The red boundary was a vanished mapped pane: no replacement pane, no remap, no
logger, and no retry count. The new READY-FOR-HOST-GATE verdict tests also began
red because the sentinel parsed as UNKNOWN.

## Green

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/recovery-runtime" -- bash tests/test-runtime-recovery.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/recovery-runtime" -- bash tests/test-wedge.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/recovery-runtime" -- bash tests/test-parse-verdict.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/recovery-runtime" -- bash tests/test-verdict-repair.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/recovery-runtime" -- bash tests/test-marker-contract.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/recovery-runtime" -- shellcheck -S warning bin/polylane-run.sh bin/polylane-markers.sh
```

All commands passed. Unit evidence covers: fresh tmux split, replacement index
mapping, transcript attachment, retry accounting only after launch, active-command
protection, 60-second terminal-turn recovery using durable source/evidence activity,
and nonce-bound READY-FOR-HOST-GATE conversion only after the coordinator gate.

The sentinel wording for `docs/parallel-status.md` is:
`POLYLANE-VERDICT: READY-FOR-HOST-GATE run=<RUN_ID>`.

## DEFERRED

- Live host-tmux recreation and a real Codex terminal turn are sandbox-external.
  The outer coordinator should run the terminal suite and host rehearsal once.
