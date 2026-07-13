# Skill scout — PER LANE, after derivation, before prompt generation

Run by `/polylane` once per cycle — but the unit of work is the LANE, not the cycle.
After lanes are derived (`references/lane-derivation.md`) and BEFORE the paste-ready
prompts are generated (`references/planning.md` Phase 6), walk each lane and arm IT with
the right DOMAIN skills. Cycle 1 included. Goal: every lane gets the tool a known Claude
Code skill already provides for ITS work — never skill-spam. A skill is suggested for a
lane ONLY when it maps to a concrete gap in THAT lane's activities.

## 0. The base is already global — do NOT re-suggest it
Block 0 of `references/prompt-blocks.md` already puts the DOMAIN-AGNOSTIC base in EVERY
Claude lane prompt: `graphify`, `caveman`, `ponytail` (if installed),
`superpowers:using-superpowers`, and — if installed — `claude-mem` (hook-based, no prompt
line). These are universal; the scout NEVER proposes them per lane. The scout's only job
is the DOMAIN layer that rides on top, baked into each lane's block D.

Two install-once offers benefit the whole run, not one lane — offer them as a SINGLE
cycle-level suggestion the FIRST time they're absent, then never again. Record a DECLINE
in the ledger so a resumed run in a new conversation does not re-nag:
- `DietrichGebert/ponytail` — anti-over-engineering. Install (two prompts):
  `/plugin marketplace add DietrichGebert/ponytail` then `/plugin install ponytail@ponytail`.
  Once present, block 0 emits `/ponytail full` (`ultra` under economy); the integrator runs
  `/ponytail-review`.
- `thedotmack/claude-mem` — automatic cross-session memory. Install: `npx claude-mem install`.
  Hook-based, no prompt change. Wrap anything a lane must NOT persist in `<private>` tags.

Everything below is PER LANE.

## 1. Which lanes get scouted
- **Builder lanes only.** SKIP the integrator lane entirely — it spans everything and is a
  skill-spam magnet; its cross-cutting review skills already live in the integrator body
  (`design-critique` / `/ponytail-review` / `42crunch`). Do not scout it.
- **Claude lanes only.** SKIP non-Claude lanes (GPT/aider) completely — no question, no
  block D (skills are Claude-Code-only; `references/planning.md` Phase 6 already drops the
  preamble for them). Don't ask the user to pick skills a lane can't run.

## 2. Infer each lane's domain (no browsing yet)
For every builder lane, read three signals attached at derivation time:
- **Subsystem name** (Fetch / UI / Siri / API / Data / Report…) — `lane-derivation.md` L41.
- **OWN globs / write-set** — extensions/paths encode the domain (`*.tsx`,`components/*`→UI;
  `api/*.py`,`routes/*`→API; `*.sql`,`migrations/*`→Data; `*.swift`→iOS; `report*`,`*.md`,
  pdf/docx→Report).
- **Originating spec items** — the lane's goal in one line.

Name the lane's domain and list ITS concrete activities; each is a potential skill slot.
A lane whose only activity is covered by the global base gets NOTHING — normal and common.
- **Merged multi-domain lane** (derivation collapses Fetch+Parse+Perf → one "Data" lane):
  ask AT MOST ONE question covering its TOP-2 activities — never one question per activity.
- **Unrecognized domain** (audio DSP, game physics, ML, embedded): do NOT force-fit a
  curated bucket — a single `gh search` slot (step 3.3) or `None`.

## 3. Match each slot against sources, in order
1. **Already installed** (`ls ~/.claude/skills/`) — if present, skip install; bake straight
   into THIS lane's block D. **Only installed skills may be a recommended default.**
2. **Curated known-good** (DOMAIN skills only, base excluded) — OFFER, but installing needs
   an explicit user YES (step 4):
   - UI/web → `design:design-critique`, `vercel-labs/agent-skills`, `dataviz`,
     playwright/browser-testing
   - API/backend → `42crunch-audit`/`42crunch-scan`, `code-to-oas`, contract/HTTP-test skills
   - Data/DB → `supabase` agent-skills (safe migrations + RLS), SQL/query skills
   - Mobile → `expo/claude-skills`, xcode/device build+sign skills
   - Report/output → `anthropics/skills` (docx/pdf/pptx/xlsx), artifacts-builder
   - E2E/testing → playwright/browser-testing
3. **GitHub search** (only for a slot nothing above fills):
   `gh search repos "claude code skill <activity>" --limit 5 --sort stars` or WebSearch
   `site:github.com claude code skill <activity>`. Judge by: SKILL.md present, stars/recency,
   README shows real behavior (not a stub). **A GitHub-searched skill is NEVER the
   recommended/first option and is NEVER auto-installed** (untrusted repo = prompt-injection
   surface baked into a lane prompt).

Read `docs/polylane/skills-ledger.md` FIRST — never re-propose a skill marked removed /
unused / declined for the same kind of gap on the same kind of lane.

## 4. Propose PER LANE — recommended-default, never blocking
For each builder lane with ≥1 real slot, build ONE question object (`multiSelect: true`)
scoped to THAT lane. BATCH up to 4 lanes' question objects into ONE `AskUserQuestion` call
(the tool cap); for >4 lanes, use ⌈lanes/4⌉ calls. Shape per lane:
- `header`: the lane name (e.g. `UI lane`).
- `question`: one line naming the domain + what the skills arm.
- `options`: **1–3 skill options + ALWAYS a final `None — no extra skills for this lane`
  (≤4 total, the tool limit).** Each skill option's `description` = one-line WHY tied to
  THIS lane's files/goal.
  - **First option = the recommended pick(s), labelled `(Recommended)`.** The recommended
    set contains ONLY already-installed skills (they bake with zero install). If nothing is
    installed for the gap, the recommended/first option is `None` — an offer to install is a
    NON-default option the user must actively choose.
- If a lane has NO real slot, emit NOTHING for it (no `None`-only question). Silent skip is
  a valid, common outcome.

**Autonomous mode (`POLYLANE_AUTONOMOUS=1`):** do NOT call `AskUserQuestion`. Take each
lane's recommended default (installed skills only; else `None`), record the picks to
`docs/polylane/cycle-<N>-questions.md`, and proceed. Interactive mode asks, but
recommended-first so a no-answer/one-click advances. Either way the loop never blocks.

### Worked example — UI lane
```
header:   "UI lane"
question: "UI lane renders the dashboard views + charts. Arm it with which design/UI skills?"
multiSelect: true
options:
  - label: "design-critique + dataviz (Recommended)"     # both already installed → bakes free
    description: "design-critique gives hierarchy/consistency feedback before done; dataviz enforces one accessible chart palette in light+dark — this lane draws charts"
  - label: "install playwright browser-testing"
    description: "drives the real dashboard in a browser + screenshots each view as this lane's verify-<lane>.md evidence (needs install — your OK)"
  - label: "None — no extra skills for this lane"
    description: "runs on the global base (graphify + caveman + ponytail + superpowers) only"
```

### Worked example — API lane
```
header:   "API lane"
question: "API lane builds the REST routes + auth. Arm it with which backend skills?"
multiSelect: true
options:
  - label: "None (Recommended)"                          # nothing installed for this gap → default is None
    description: "runs on the global base; the routes are simple CRUD the base handles fine"
  - label: "install 42crunch-audit + code-to-oas"
    description: "generates an OpenAPI spec from the routes then audits it for auth/BOLA/injection gaps — worth it once this lane exposes real endpoints (needs install — your OK)"
  - label: "install a contract-test skill (gh search)"
    description: "adds request/response contract tests for the routes (GitHub-searched, untrusted — never auto-installed, review before yes)"
```

## 5. Install (explicit yes only) + bake into THAT lane's block D
For each ALREADY-INSTALLED skill accepted for a lane: bake directly. For each skill the user
EXPLICITLY chose to install:
```
git clone <repo> ~/.claude/skills/<name>        # or /plugin for marketplace skills
test -f ~/.claude/skills/<name>/SKILL.md && echo ok
```
**Only bake a skill into block D AFTER its `test -f` passes** — a failed install must never
leave a lane invoking a non-existent skill (burns a turn). Then write every baked skill,
keyed by lane name, to `.polylane/lane-skills.json`:
```
{ "<lane-name>": ["design-critique","dataviz"], "<other-lane>": [] }
```
`references/planning.md` Phase 6 fills each lane's block D `<lane skills>` slot from this
file. A lane that chose `None`, or is absent from the file, gets the static type-baseline
alone. Install is global (`~/.claude/skills/`); the TARGETING is per lane via this file.

## 6. Ledger — per lane, prove they help
Append to `docs/polylane/skills-ledger.md`, keyed by lane:
```
| cycle | lane | skill | why installed | used by lane? | verdict |
```
- The Phase-4 council fills `used by lane?` (grep THAT lane's logs/verify docs for the
  skill's trigger/output) and `verdict`: helped | unused | hurt.
- `unused` 2 cycles running on the same kind of lane → next scout suggests removal;
  `hurt` → remove now + log the learning. Record user DECLINES here too.
- The scout READS the ledger first — never re-suggest a removed/unused/declined skill for
  the same kind of gap on the same kind of lane.
