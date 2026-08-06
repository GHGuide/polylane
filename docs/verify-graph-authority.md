# Graph authority verification — cycle 3 m6.3

Run: `graph-c3-20260806-194631`  
Scope: runner/supervisor authority and runtime recovery only.

## RED evidence observed first

Before the implementation, the new negative authority test reported that a
blocked lane still reached the launch path (`authority-blocked-lane-no-new-pane`
failed), `graph_authority_start` was absent (rc 127), and no
`GRAPH-AUTHORITY:` diagnostic existed. The missing-session test had no bounded
exit path: `poll_done` kept polling an unfinished lane. The Codex command had
no narrow Git metadata grant; the graph symlink dirtied a committed lane; and
the dashboard test treated any nonempty capture as a complete frame.

Commands used for RED:

```sh
bash tests/test-graph-authority.sh || true
bash tests/test-runtime-survival.sh || true
bash tests/test-agent-adapter.sh || true
bash tests/test-lane-done.sh || true
bash tests/test-dashboard.sh || true
```

## Focused assertions

`tests/test-graph-authority.sh` proves a pending `lane:blocked` is refused
before `new_pane`: the tmux-call capture does not exist, then succeeds only
after the authoritative `start` checkpoint advances. It also corrupts the
ledger and verifies a fail-closed actionable diagnostic.

`tests/test-runtime-survival.sh` proves an unfinished runner whose owned tmux
session has vanished returns the distinct recoverable status `75` and prints
`SESSION-LOST:`. `polylane-supervisor.sh` treats that status as a resume event,
retaining its existing lock so it cannot create duplicate runners/panes.

The generated workspace-write Codex command contains the narrowly quoted
shared Git directory, for example:

```sh
codex exec ... --sandbox workspace-write --add-dir /private/.../repo/.git \
  -c approval_policy=never ...
```

The adapter test also proves `read-only` and explicit `danger-full-access`
commands have no `--add-dir`; the latter remains an explicit user choice, not
the permanent workaround.

`tests/test-lane-done.sh` proves the positive runner-owned
`graphify-out -> $REPO_ROOT/graphify-out` symlink is ignored for a committed
DONE checkpoint, while `real-untracked.txt` still blocks DONE. No broad
untracked-file exemption exists.

`tests/test-dashboard.sh` waits for both `POLYLANE DASHBOARD` and the final
`hint: tmux attach -t` line, proving a complete rendered frame rather than a
nonempty partial file.

## Green commands and observed result

```sh
bash -n bin/polylane-run.sh && bash -n bin/polylane-supervisor.sh
bash tests/test-graph-shadow.sh
bash tests/test-supervisor.sh
bash tests/test-verdict-repair.sh
bash tests/test-runtime-refresh.sh
bash tests/test-agent-adapter.sh
bash tests/test-lane-done.sh
bash tests/test-dashboard.sh
bash tests/test-graph-authority.sh
bash tests/test-runtime-survival.sh
shellcheck -S warning bin/polylane-run.sh bin/polylane-supervisor.sh
```

Observed: all focused assertions passed; shellcheck emitted no warnings.
The no-side-effect proof is `authority-blocked-lane-no-new-pane`; the
missing-session recovery proof is `runtime-session-loss-distinct-recoverable-status`;
and the dashboard race proof is the complete-frame pair in `run_frame`.

PASS
