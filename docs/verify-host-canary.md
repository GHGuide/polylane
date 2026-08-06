# Host canary verification

The hermetic contract-v3 fixture drives `polylane-run.sh` with two real lane
worktrees and a bounded local mock agent. On GO, the integrator commits only
the nonce-bound candidate `POLYLANE-VERDICT: READY-FOR-HOST-GATE run=<nonce>`.
The rehearsal then requires the real outer runner to promote both lane outputs,
record exactly `terminal_gates=1` in durable
`docs/polylane/run-stats.json`, preserve the three-agent-call bound, and remove
the tmux session, worktrees, and runtime status markers.

On NO-GO it keeps the nonce-bound integrator evidence inspectable in the
integrator worktree, withholds both lane outputs from `main`, retains the same
three-call bound, then performs the explicit clean teardown.

Validation command (cache-routed):

`bin/polylane-check.sh "$PWD/.polylane/check-cache/host-canary" -- env POLYLANE_REHEARSE=1 bash tests/test-rehearse.sh`

Shell syntax and ShellCheck pass. The live command is currently blocked in this
workspace before any lane launches because its sandbox denies tmux server-socket
access (`Operation not permitted`); the failure is cache-recorded and requires
an environment that permits tmux to produce the final live transcript.
