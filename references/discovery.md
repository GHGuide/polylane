# Discovery & Strategy — vague idea → concrete product strategy → goal tree

Used by `/polylane-max` Phase 00 when the user gives a BRIEF, fuzzy idea ("an app
that helps me X") and wants the system to strategize + build the whole thing. Goal:
go from one line to a locked PRODUCT STRATEGY and an HTN goal tree the build loop
can execute — extracting everything from the user through easy, batched questions,
and filling the gaps they can't answer with research + sensible defaults.

## Principles
- **The user may know almost nothing.** Never ask an open "what tech stack?" — offer
  2–4 concrete options with a recommended default (first, "(Recommended)"). One click
  answers. Unanswered → take the recommended default and note it. Momentum over
  interrogation.
- **Research fills the gaps.** Before/between rounds, use `deep-research` to propose a
  feature set, a stack, look-and-feel references, and competitor norms — so the user
  is choosing from informed options, not inventing them.
- **Batched, not endless.** 2–4 questions per AskUserQuestion round, multiple rounds
  ("numerous"), re-presenting the growing strategy after each so the user sees it form.
- **Think like a product strategist, not an order-taker.** Push back gently, surface
  trade-offs, name the riskiest assumption, recommend an MVP cut. This is the
  "strategize" the user is asking for.

## The dimensions to cover (ask across batched rounds, recommended-default each)
1. **Problem & outcome** — what problem, and what a user can DO after that they couldn't.
2. **Audience** — who exactly (persona), rough size, B2C vs B2B vs personal.
3. **The one thing** — the single capability it must nail; everything else is support.
4. **MVP feature set** — from a researched candidate list, which are must-have-now vs
   later. Recommend the smallest set that delivers "the one thing."
5. **Platform** — web app / mobile / desktop / CLI / browser-extension (+ responsive).
6. **Look & feel** — style direction (minimal · playful · pro · bold) + 1–2 reference
   apps to match; or "you pick, surprise me."
7. **Accounts & data** — auth needed? user data stored? offline? privacy/PII concerns?
8. **Integrations** — payments, maps, AI/LLM, email/SMS, calendar, storage, social —
   which external services (each adds scope + possibly keys/$).
9. **Business model** — free · paid · freemium · ads · internal-tool (shapes features).
10. **Constraints** — deadline, budget, must-use/avoid tech, hosting, compliance.
11. **Ambition level** — throwaway prototype · solid MVP · production-ready · launch-ready.
12. **Definition of done** — the 3–5 measurable things that mean "this is finished"
    (these become the goal tree's `criteria`).

Skip a dimension that's obviously N/A; collapse rounds when answers are implied.

## Half-satisfiable — flag early, don't surprise the final GO
Anything the system canNOT do for the user alone: a paid service / API key, an app-
store account, a domain, a real payment processor, a product decision only they can
make. Surface these in the strategy as "NEEDS FROM YOU" so the loop plans around them
and the user isn't blindsided at the end.

## Output — the PRODUCT STRATEGY (present once, one confirmation)
A short, skimmable doc (save to `docs/polylane-max/STRATEGY.md`):
- **One-liner** — the product in a sentence.
- **Problem / audience / the one thing.**
- **MVP scope** — the feature list, must-have-now marked; explicitly what's deferred.
- **Platform + stack** (researched recommendation) · **look & feel.**
- **Accounts/data · integrations · business model.**
- **NEEDS FROM YOU** — the half-satisfiable items.
- **Success criteria** — the measurable definition of done.
- **Riskiest assumption** — the one thing most likely to be wrong, to validate first.

Confirm once (AskUserQuestion, recommended = "yes, build this"). Edits loop; an
explicit yes locks it.

## Hand-off to the goal tree (feeds Phase 0)
Turn the locked strategy into the HTN tree deterministically:
- each **success criterion** → `add-criterion` (weight by importance).
- the MVP scope → **milestones** (e.g. Foundation, Core, Polish, Ship) → weighted
  **sub-goals** (each a buildable, testable chunk); weight = leverage toward "the one
  thing" and the criteria.
- log the strategy decision: `log 0 decision "<strategy one-liner>" "discovery"`.
Then enter the normal build loop (Phase 1+). The user has now answered a handful of
click-through questions and confirmed one strategy — everything else is derived,
built, verified, and merged for them.
