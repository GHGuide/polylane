# Cycle 43 research — what the harness failures taught

No external research was performed; the material was the running system.

1. **Interactive-agent lanes have no durable activity signal.** Codex lanes emit
   JSONL command events, so a long tool call is visibly alive. Claude Code stops
   repainting during a tool call, so pane hash and pipe-pane log both freeze and
   an honest hour-long suite is indistinguishable from a hang. Process-tree CPU
   burn turned out to be the agent-agnostic equivalent — child-process presence
   is not, because MCP servers live for the whole session.
2. **Paywalls and auth failures are not errors.** They present as ordinary text
   with no menu, match no error signature, and cannot be answered by a respawn.
   Each needs its own recognizer routed to a policy (park for a human, or fall
   back down the free model ladder) rather than the generic wedge path.
3. **One-shot recovery actions are a liveness hazard.** A single `/exit` that a
   busy CLI swallows hangs a finished run forever. Bounded retry, with the full
   safety precondition re-proved on every attempt, is strictly better than
   never-repeat.
4. **Efficiency canaries must be scoped to the criterion that needs them.** A
   zero-restart requirement applied to every promotion makes any legitimate
   autonomous repair round fatal.
5. **A runner that writes evidence into its own base blocks its next run.** The
   promoter's refusal to stage unrelated changes is correct; the fix is to
   recognize runner-owned artifacts by shape, not to loosen the promoter.
