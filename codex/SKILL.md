---
name: polylane
description: Use when the user gives a goal — or even a vague one-line app/product idea — and wants it strategized and BUILT autonomously by parallel Codex terminals. Opens a product-discovery interview (easy recommended-default questions + research) that turns a fuzzy idea into a locked strategy + goal tree, then loops: derive file-isolated lanes → build in parallel on Codex → integrator merges on GO → digest → research → council picks where-next → report + questions → continue, until the goal is met and shippable or the user stops. Triggers on "polylane", "build my app idea", "strategize and build", "split this into parallel prompts", "run the lanes", "autonomous build loop", "turn my idea into an app".
---

# polylane (Codex) — the EXACT Claude Code build loop, on Codex models

**The full polylane loop is appended below verbatim from the Claude Code skill —
same discovery, lane derivation, parallel build, integrator + ensemble verdict,
council gate, ledger/scout/seam/scope guards, promote-on-GO, digest, report, resume.
Nothing is removed or simplified.** Read and follow it exactly. Helpers live under
`scripts/` (the same `bin/*.sh` engine); reference them there instead of `bin/`.

## Codex deltas — the ONLY differences (apply these on top of the loop below)
1. **Agent = codex.** Every emitted `.polylane/run.json` sets `"agent": "codex"`, so the
   runner launches `codex exec --full-auto --model <model> "$(cat <prompt>)"` per lane
   (override the template with `POLYLANE_AGENT_CMD` if your Codex CLI's flags differ).
2. **Models = your Codex model ids.** Probe/ask which Codex models are available and put
   their ids in the manifest's `available_models` (e.g. `gpt-5-codex`, plus any
   mini/lighter tier). The intensity → per-lane model resolution in
   `references/model-selection.md` walks `available_models` BY RANK — so rank your Codex
   models by capability/cost (strongest first) and economy/balanced/performance/max pick
   among them exactly as they do for Claude models. Only one Codex model? All intensities
   use it and only **effort** varies (economy=medium … max=xhigh — unchanged).
3. **Lane prompts are PLAIN.** DROP the Claude-only mandatory preamble (`/graphify-auto`,
   the caveman skill, `/goal`, `superpowers:*`) — Codex has none of them. KEEP every
   agent-neutral block verbatim: identity, OWN/FORBIDDEN + frozen contract, the locked
   goal in prose, "keep output terse", forced-verify evidence file, and the mandatory
   DONE-signal `STATUS: <lane> DONE run=<RUN_ID>` + integrator
   `POLYLANE-VERDICT: … run=<RUN_ID>`. The prompt-lint + scout-lint gates still run.
4. **Questions are inline chat.** Codex has no AskUserQuestion tool — ask the discovery +
   per-cycle questions as normal messages, each with a clearly recommended default so one
   reply advances; in autonomous mode take the default and log it. `go deeper` / `surprise
   me` become extra offered options in the message.

Everything else — the tree, gates, council, promote, cleanup, memory, resume — is
byte-for-byte the same engine and the same loop. Now follow it:

<!-- ===================================================================== -->
<!-- FULL POLYLANE LOOP (identical to the Claude Code SKILL.md) appended below -->
<!-- ===================================================================== -->
