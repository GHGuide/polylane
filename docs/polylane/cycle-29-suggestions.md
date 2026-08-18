# Cycle 29 per-lane skill suggestions

The scout ran before prompt generation. It found no unfilled capability gap, so
no install is recommended and no external skill is allowed into a worker prompt.

## Builder: `active-scope`

Selected installed kit:

1. `superpowers:systematic-debugging` — trace the witnessed restart from
   structured command boundaries through material-progress state and retry logic.
2. `superpowers:test-driven-development` — freeze active-command, absolute-root,
   scope-fail-fast, and planned-write failures before production edits.

Other useful installed options considered:

3. `engineering:debug` — relevant but overlaps systematic debugging.
4. `engineering:testing-strategy` — useful for broad test architecture, but the
   required regressions are already exact and its prior outcome ledger is weaker.
5. `superpowers:writing-plans` — useful to the orchestrator for exact path plans,
   but builder execution starts after the plan is frozen.
6. `superpowers:verification-before-completion` — valuable at the independent
   integration boundary rather than duplicating builder context.
7. `ponytail:ponytail-review` — useful for complexity reduction, but this repair
   needs behavioral root-cause work more than another review framework.
8. `engineering:code-review` — deferred to the integrator for independent review.

## Integrator

Selected installed kit:

9. `superpowers:verification-before-completion` — require current exact-tip
   evidence and truthful zero-restart telemetry before READY.
10. `engineering:code-review` — audit Bash 3.2 compatibility, command-state
    parsing, path trust, fail-fast semantics, and legacy manifest compatibility.

Other useful installed options considered:

11. `superpowers:requesting-code-review` — unnecessary because the integrator is
    already the independent reviewer.
12. `superpowers:receiving-code-review` — useful only if a later review sends
    concrete findings back to this lane.
13. `engineering:testing-strategy` — overlaps the frozen matrix design.
14. `ponytail:ponytail-review` — optional complexity audit if direct review finds
    a new abstraction rather than a narrow fix.

## GitHub candidates

15. `obra/superpowers` — its debugging, TDD, planning, and verification skills
    directly match this failure class; the relevant skills are already installed
    and pinned, so no install is needed.
16. `trailofbits/skills` differential review — potentially useful for a future
    security-sensitive diff lane, but it does not close a current Bash/tmux gap
    and remains informational.
17. The local GitHub helper returned unavailable for the broad shell/tmux query.
    The cycle therefore used source-reviewed candidates only and did not invent,
    install, or arm an unverified result.

Decision: use the four selected installed skills, install none, keep Graphify as
navigation infrastructure rather than a selected execution skill.

