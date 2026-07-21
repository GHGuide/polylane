---
name: polylane
description: Use when the user gives a goal — or even a vague one-line app/product idea — and wants it strategized and BUILT autonomously by parallel Codex terminals. Opens a product-discovery interview (easy recommended-default questions + research) that turns a fuzzy idea into a locked strategy + goal tree, then loops: derive file-isolated lanes → build in parallel on Codex → integrator merges on GO → digest → research → council picks where-next → report + questions → continue, until the goal is met and shippable or the user stops. Triggers on "polylane", "build my app idea", "strategize and build", "split this into parallel prompts", "run the lanes", "autonomous build loop", "turn my idea into an app".
metadata:
  short-description: Build an app 0→100 from one prompt via parallel Codex lanes
---

# polylane (Codex) — the EXACT Claude Code build loop, on Codex models

**The full polylane loop is appended below verbatim from the Claude Code skill —
same discovery, lane derivation, parallel build, integrator + ensemble verdict,
council gate, ledger/scout/seam/scope guards, promote-on-GO, digest, report, resume.
Nothing is removed or simplified.** Read and follow it exactly. Helpers live under
`scripts/` (the same `bin/*.sh` engine); reference them there instead of `bin/`.

## Codex deltas — the ONLY differences (apply these on top of the loop below)
1. **Agent = codex.** Every emitted `.polylane/run.json` sets `"agent": "codex"`, so the
   runner launches `codex exec --json --sandbox workspace-write -c approval_policy=never
   -c model_reasoning_effort=<effort> --model <model> - < <prompt>` per lane (override
   the template with `POLYLANE_AGENT_CMD` if your Codex CLI's flags differ).
2. **Models = your Codex model ids.** Probe/ask which Codex models are available and put
   their ids in the manifest's `available_models` (e.g. `gpt-5-codex`, plus any
   mini/lighter tier). The intensity → per-lane model resolution in
   `references/model-selection.md` walks `available_models` BY RANK — so rank your Codex
   models by capability/cost (strongest first) and economy/balanced/performance/max pick
   among them exactly as they do for Claude models. Only one Codex model? All intensities
   use it and only **effort** varies (economy=medium … max=xhigh — unchanged).
3. **Lane prompts are PLAIN.** DROP the Claude-only mandatory preamble (the caveman skill, `/goal`, `superpowers:*`) — Codex has none of them. KEEP every
   agent-neutral block verbatim: identity, OWN/FORBIDDEN + frozen contract, the locked
   goal in prose, "keep output terse", forced-verify evidence file, and the mandatory
   DONE-signal `STATUS: <lane> DONE run=<RUN_ID>` + integrator
   `POLYLANE-VERDICT: … run=<RUN_ID>`. The prompt-lint + scout-lint gates still run.
4. **Questions are inline chat.** Codex has no AskUserQuestion tool — ask the discovery +
   per-cycle questions as normal messages, each with a clearly recommended default so one
   reply advances; in autonomous mode take the default and log it. `go deeper` / `surprise
   me` become extra offered options in the message.
5. **tmux visibility is mandatory.** Whenever a Polylane tmux session is active, surface
   exactly one terminal watch command in chat or state output: `tmux attach -t <session>`.
   Do not invent this line for inactive sessions.
6. **Council is advisory unless all terminal gates pass.** A council verdict, GO/NO-GO
   cycle result, digest, research result, or suggestion list is never a stopping point by
   itself. Continue into the next focus unless the locked goal, acceptance checks,
   shippability certification, and perfection pass all say complete, or a genuine user
   decision is required.
7. **Autonomous Codex mode does not idle at boundaries.** After each cycle, immediately
   pick or synthesize the next focus, arm builder lanes with predefined and lane-specific
   installed skills, record GitHub skill suggestions as informational, and launch the next
   executable work. If the initial prompt's requested goal is fully satisfied, emit exactly
   30 concise informational suggestions for what can be improved next, then keep iterating
   only on suggestions that still advance the locked goal/perfection criteria.
8. **Fast default cadence.** Use the shared runner's responsive defaults
   (`POLYLANE_POLL_INTERVAL=5`, `POLYLANE_HEALTH_INTERVAL=60`,
   `POLYLANE_SEED_VERIFY=5`) unless the user explicitly slows them down.

Everything else — the tree, gates, council, promote, cleanup, memory, resume — is
byte-for-byte the same engine and the same loop. Now follow it:

<!-- ===================================================================== -->
<!-- FULL POLYLANE LOOP (identical to the Claude Code SKILL.md) appended below -->
<!-- ===================================================================== -->
