# Cycle 4 digest — real walk-away proof

## Built

- The contract-v2 rehearsal now executes real supervised GO and NO-GO lifecycles. GO promotes
  and cleans; NO-GO withholds promotion, retains evidence, bounds repair, then cleans its fixture.
- Runtime paywall detection requires an actionable credits/upgrade decision instead of matching
  source or prose that happens to say “usage limit”.
- Cleanup canonicalizes macOS `/var` and `/private/var` worktree paths and accepts intentional
  durable goal-state updates while still rejecting leaked runtime markers.
- Graph and event CLIs run on Apple jq as well as Homebrew jq; the benchmark harness now does too.
- A failed verifier can resume through the declared repair loop when committed current-run GO
  evidence proves the repair finished before the prior runner died.
- Fresh-clone installers and session tests distinguish a real product failure from a worker
  sandbox that cannot write the project or open the host tmux socket.

## Verified

- Real two-builder + integrator Codex cycle reached a legitimate supervised GO and promoted.
- `tests/run.sh`: 954 passed, 0 failed across 62 test files; ShellCheck clean.
- Host rehearsal: `REHEARSE-GO ... promoted=1 cleaned=1 leaks=0`; `REHEARSE-NOGO ...
  promoted=0 evidence=1 retained=1 bounded=1 cleaned=1`.
- Homebrew jq: ready 62 ms, append 116 ms, full packet 1,861–1,882 ms.
- Apple jq: ready 54 ms, append 109 ms, full packet 1,845–1,870 ms.

## Learned

- Graph execution is not the current bottleneck. Prompt breadth, repeated skill reads, repeated
  terminal suites, dead-pane recovery, and lost resume telemetry dominate time and tokens.
- A live Codex PID is not proof of progress: one worker wedged after a skills-context error and
  stayed “working” indefinitely until externally interrupted.
- `tmux respawn-pane` against a vanished pane fails, but the old fallback sent keys to that same
  nonexistent target and still consumed retries. Recovery must recreate and remap the pane.
- Worker sandboxes cannot truthfully grade host-only tmux behavior. They need an explicit
  host-gate handoff; only the outer runner should execute and certify terminal host checks.
- The canonical project `.polylane/check-cache` is outside a linked worktree's write sandbox.
  The cache must live inside the lane worktree.
- Cycle reporting lost prior-run token and wall evidence on resume, rendering unknown as zero.
  Metrics need an append-only per-run snapshot independent of one runner process.
