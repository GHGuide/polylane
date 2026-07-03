# Lane prompt template — assemble from prompt-blocks.md

Emit ONE of these per lane, as: a launch line + a fenced paste block. Order the blocks exactly A→J. Everything in `<...>` is filled from recon + derivation; blocks C, E, G, H, I are verbatim.

## Launch line
```
cd "<PROJECT_ABS_PATH>" && claude --model <MODEL_ID>
```
(`claude-fable-5` or `claude-opus-4-8` per model-selection.md. Effort is instructed in-prompt via block B — there is no verifiable CLI effort flag.)

## Paste block skeleton (fill and inline the blocks)
```
[A identity + context]
[B model + effort header]
[0 MANDATORY-4 preamble: /graphify-auto · caveman(full) · /goal <lane goal> · superpowers:using-superpowers]
[C terse output]
[D skills for this lane]
[E graphify-first]   (omit only if graphify-out/ absent AND graphify skill unavailable — then substitute: "Use one read-only Explore agent to map <subsystem> before editing.")
[F file ownership + contract]

GOAL (LOCKED — do not re-scope):
<the spec items assigned to this lane, each with its done-when outcome>

WORKFLOW: <writing-plans → smallest steps → verify each → commit>.
[G forced verification]
[H coordination + mutex]
[I scoped git]
[J done checklist]
```

## Rules
- The GOAL is copied verbatim from the locked INTEGRATION SPEC — never paraphrased or expanded. If a builder wants scope beyond it, it must raise NEEDS DECISION, not act.
- Keep each prompt self-contained (a fresh terminal has no session context).
- Project-specific recipes (build/install commands, device IDs, known-broken tooling) are pulled from the project's CLAUDE.md and inlined into the relevant lane(s) — not hardcoded in this template.
- After all lane prompts + the integrator prompt: STOP. Do not launch, do not edit code.
