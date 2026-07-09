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
- **Every question has a "go deeper" escape hatch.** Include, on EVERY discovery
  question, a final option **"🔍 Go deeper — ask me more about this next round"**.
  Picking it means the user wants finer-grained questions on THAT dimension before
  committing. Collect all dimensions flagged "go deeper" in a round, and open the
  next round with 2–4 drill-down questions on each (informed by research), each of
  which ALSO carries its own "go deeper" — so the user can escalate any topic to
  arbitrary depth. Only close a dimension once the user picks a concrete answer (or
  accepts a default); never force a decision they wanted to explore first.
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

### Creative dimensions (ask these too — this is where "more creative" lives)
These aren't spec-gathering; they push the product somewhere interesting. Ask them
with BOLD options, not safe ones:
13. **North-star / 10× vision** — "if this were the best in the world at one thing,
    what?" Offer an ambitious framing the user didn't state.
14. **Differentiation** — "why would someone pick this over [the obvious incumbent]?"
    Name the incumbent (from research) and propose 2–3 angles of attack.
15. **Signature moment / delight** — the ONE interaction people screenshot and share.
    Propose a few (a surprising animation, a clever default, a zero-effort win).
16. **Anti-goals** — what it must deliberately NOT be / NOT do. Sharpens identity;
    each anti-goal is also a scope-saver.
17. **Personality & tone** — voice of the product (calm · playful · blunt · luxe ·
    nerdy). Shapes copy, colour, motion.
18. **Wildcard feature** — one non-obvious, research-surfaced capability that could
    make it remarkable (offer 2–3 the user never mentioned, clearly marked optional).
19. **Constraint-as-fuel** — pick a bold constraint that forces creativity
    ("no text", "one screen", "works offline", "60-second first win").

Skip a dimension that's obviously N/A; collapse rounds when answers are implied.

## Creative divergence — PROPOSE, don't just elicit
"More creative" means the pipeline brings ideas, not only questions. Two mechanics:

1. **Concept bake-off (do this EARLY, right after the first spec round).** Use
   `superpowers:brainstorming` + `deep-research` to generate **2–3 genuinely distinct
   product CONCEPTS** from the same brief — not tweaks, real forks (e.g. "dead-simple
   solo tool" vs "social/shared" vs "AI-native assistant"). Give each a name, a
   one-line pitch, its signature moment, and what it trades off. Present them side by
   side and let the user pick one, merge two, or say "none — here's what I actually
   want" (which is itself gold). The winner seeds the strategy; graft the best bits of
   the runners-up. This is the single biggest creativity lever — the user reacts to
   concrete visions instead of inventing from scratch.
2. **Every question carries a BOLD option, not just safe defaults.** Alongside the
   recommended default and the alternatives, include one **"✨ Surprise me / go bold"**
   option that names an ambitious, non-obvious choice (a wildcard feature, a striking
   visual direction, a contrarian scope cut). Picking it commits to the bold path;
   ignoring it costs nothing. Boldness is always on the menu, never forced.

Run the concept bake-off ONCE per discovery; the BOLD option is on every question.
When the user keeps taking bold/deeper options, lean further in — match their appetite.

## "Go deeper" drill-down mechanics
When the user picks 🔍 Go deeper on a dimension, the NEXT round replaces that one
top-level question with a small batch of finer questions that decompose it — each
still recommended-default + each still offering "go deeper". Examples:
- **MVP features → deeper:** one question per candidate feature ("include X now /
  later / never"), or "which of these 6 (researched) does 'the one thing' actually
  need?" → then deeper on a single feature's behavior/edge cases.
- **Look & feel → deeper:** colour direction → typography feel → density/whitespace →
  a specific reference screen to match.
- **Platform → deeper:** web vs mobile → if web: SPA vs SSR, which framework, which
  component kit → responsive breakpoints.
- **Integrations → deeper:** which services → for each: which provider, free tier vs
  paid, do you have the key.
Depth is unbounded — a user can escalate one topic several levels while accepting
defaults on the rest. Track how deep each dimension went in `STRATEGY.md` so the
build reflects the detail the user cared about. A dimension the user never deepens
just takes its recommended default — depth is opt-in, never forced.

## Half-satisfiable — flag early, don't surprise the final GO
Anything the system canNOT do for the user alone: a paid service / API key, an app-
store account, a domain, a real payment processor, a product decision only they can
make. Surface these in the strategy as "NEEDS FROM YOU" so the loop plans around them
and the user isn't blindsided at the end.

## Output — the PRODUCT STRATEGY (present once, one confirmation)
A short, skimmable doc (save to `docs/polylane-max/STRATEGY.md`):
- **One-liner** — the product in a sentence.
- **Chosen concept** — which bake-off concept won + the bits grafted from the others.
- **North-star / signature moment** — the 10× vision + the one shareable moment.
- **Problem / audience / the one thing.**
- **MVP scope** — the feature list, must-have-now marked; explicitly what's deferred.
- **Personality & anti-goals** — the voice, and what it deliberately is NOT.
- **Platform + stack** (researched recommendation) · **look & feel.**
- **Wildcard(s)** — the bold, non-obvious feature(s) the user opted into (if any).
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
