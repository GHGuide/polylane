# Discovery — vague goal → locked project strategy → goal tree

Discovery turns a vague request into a repository-backed, evidence-bearing project.
It is adaptive: ask only what materially changes the outcome, then load the selected
route in [project-types.md](project-types.md). Do not presume the outcome is an app.

## Interaction contract

- Ask 2–4 concise questions at a time. Put a concrete recommended answer first.
  In autonomous mode, record and take that default; in interactive mode, keep the
  user in control of material decisions.
- Every question offers **“🔍 Go deeper — ask me more about this next round”** and
  **“✨ Surprise me / go bold”**. Deeper opens narrow follow-ups; bold commits to a
  named ambitious but bounded option. Both remain opt-in.
- Reflect the evolving profile after about three answers, surface contradictions,
  and converge once new answers stop changing deliverables, evidence, risk, or
  finish conditions. Research unknown facts before presenting choices.
- A user-facing UI is conditional work, not a discovery default. When one exists,
  follow [visual-intelligence.md](visual-intelligence.md); otherwise do not ask UI
  style questions or require visual certification.

## Ask these first

1. **Outcome and profile** — What durable change, answer, asset, or operating result
   is wanted? Which project profile best fits: software, trading/quant research,
   research/analysis, operations/business, content/creative, data/automation, or
   custom/mixed? Recommend the route that best matches the wording and explain why.
2. **Deliverables and stakeholders** — What repository-backed artifacts are expected,
   who will use/review them, and what decision or workflow do they support?
3. **Evidence and finish** — What would credibly prove success: executable checks,
   source provenance, measurements, review, or external proof? What conditions mean
   finished, and which are explicitly outside Polylane’s authority?
4. **Risk and constraints** — What can cause harm or invalidation: privacy, capital,
   compliance, rights, safety, reversibility, deadlines, budget, dependencies, or
   uncertainty? Who owns a consequential decision or action?

Write the answers to `docs/polylane/PROJECT_PROFILE.md` before goal decomposition.
Use its required fields exactly; unknowns and external blockers remain explicit.

## Then load only the selected route

Read the matching profile in [project-types.md](project-types.md) and ask only its
relevant questions. Useful examples:

- **Software:** user path, data, integration, platform, compatibility, and (only if
  UI) visual direction and accessibility.
- **Trading/quant:** market/universe, data source and timestamps, hypothesis,
  evaluation window, costs/slippage, risk limits, and whether paper research—not
  live capital—is the intended endpoint.
- **Research/analysis:** question, audience, sources, inclusion rules, method,
  uncertainty, and citation/review standard.
- **Operations/business:** owner, current workflow, controls, service level,
  approvals, rollout, escalation, and reversible pilot.
- **Content/creative:** audience, message/claims, voice, channel, rights, review,
  and publication authority.
- **Data/automation:** source, schema, transformation, PII/retention, quality bar,
  schedule, destination, failure handling, and rollback.
- **Custom/mixed:** component profiles, dependencies, shared outcome, and the
  strictest applicable evidence and safety boundary.

## Research, options, and lock

Research gaps proportionately and distinguish observed facts from proposals. Offer
2–3 materially different strategies when a choice would alter the outcome; a
“bold” option may sharpen scope or method, but never evade safety, rights, or
authority. Identify the riskiest assumption and the cheapest credible validation.

Before decomposition, lock a concise `docs/polylane/STRATEGY.md` that links the
profile and states outcome, deliverables, approach, constraints, evidence plan,
risks, external-action boundary, and measurable finish conditions. Create
`NORTHSTAR.md`, `ULTIMATE_GOAL.md`, and the decision trail with the same truthful
language. The goal tree receives only observable subgoals and frozen acceptance;
manual or external evidence remains `external`, never silently passed.

## External-action boundary

Drafting, simulating, analyzing, or preparing instructions is autonomous work.
Sending communications, publishing, deploying, trading live capital, spending,
changing production data, or physical execution requires explicit user authority
and actual evidence. Continue independent work while requesting the smallest
specific authorization; never report the action as completed without proof.
