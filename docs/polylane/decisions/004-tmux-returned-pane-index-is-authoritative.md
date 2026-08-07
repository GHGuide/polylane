# 004 — tmux-returned pane index is authoritative

**Status:** accepted

**Cycle:** 10

## Decision

Every live pane launch captures `#{pane_index}` from `tmux new-session` or `tmux split-window` and stores that returned value in runtime state. A predicted next index is permitted only for side-effect-free dry-run output.

## Why

Tmux can renumber surviving panes after a pane is removed. During the cycle-10 self-run, a locally predicted integrator index no longer existed, the first launch failed, and recovery could create a duplicate integrator. The tmux response is the only authoritative identity.

## Consequences

- Runtime recovery targets the pane that actually exists.
- Removing or killing a pane cannot make future launch mappings drift silently.
- Tests must mock the index returned by tmux, including a value different from the local counter.
- Dry-run remains deterministic without requiring a live tmux server.
