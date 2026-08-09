# Cycle 24 research — live identity and bounded context

Cycle 23 passed its frozen terminal gate, but its live transcript exposed three
post-certification defects worth a fresh cycle rather than rewriting that result.

1. Direct queries against the private tmux server showed live Codex panes while
   `polylane-state.sh` repeatedly rendered those lanes as `no-pane`. A hermetic
   simple-cwd fixture passes, narrowing the defect to real agent-process cwd drift.
   tmux pane-local user options were probed successfully and remain visible even
   when `pane_current_path` is unrelated to the lane.
2. The integrator first ran a malformed durable-inbox command, then the corrected
   command returned unacknowledged Cycle 15 relay instructions during Cycle 23.
   Durable capsules are useful cross-cycle context; stale imperative messages are
   not safe active instructions in a new nonce-bound run.
3. The graph itself worked: direct `graphify-out/q.py` queries narrowed the source
   paths correctly. However, a builder first loaded the complete Graphify skill
   body (37,063 bytes) merely to issue those already-prompted queries. Graphify is
   navigation infrastructure here, not an executable per-lane skill.
4. The first Cycle 24 dry-run rejected manifest `intensity: "custom"` before tmux
   opened. The checked-in schema says `custom` is advisory metadata that preserves
   baked lane model/effort choices; only an explicit CLI `--intensity` may remap.

The selected design is mechanical: nonce-bound pane tags with an untagged legacy
fallback, nonce-scoped worker events with legacy behavior only when no scope is
provided, exact prompt lint for the inbox command, and a compile-time rejection of
Graphify as a selected builder skill while retaining direct graph queries, plus a
true no-remap path for documented custom intensity metadata.
