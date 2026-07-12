# Skill scout — before EVERY cycle, arm the lanes with the right skills

Run by `/polylane-max` right before each cycle's build launch (cycle 1 included).
Goal: the coming cycle's lanes should never lack a tool that a known Claude Code
skill already provides — but never install skill-spam either. A skill is suggested
ONLY when it maps to a concrete gap in THIS cycle's lanes.

## 1. Derive the cycle's needs (no browsing yet)
From the next cycle's lanes/spec, list the concrete activities: e.g. "iOS build +
install", "frontend visual polish", "API contract tests", "PDF report", "DB
migration", "video/demo asset". Each activity is a potential skill slot.

## 2. Match against sources, in order
1. **Already installed** (`ls ~/.claude/skills/`) — if present, just bake its
   trigger into the lane prompts (no install step). Never re-suggest.
2. **Curated known-good** (fast path, no search):
   - `obra/superpowers` — TDD / debugging / verification discipline (builder lanes)
   - `anthropics/skills` — docx/pdf/pptx/xlsx output, artifacts-builder (report/design lanes)
   - graphify — code-graph navigation (any lane in an unfamiliar repo)
   - caveman — terse output (every lane, token savings)
   - `vercel-labs/agent-skills` (web design review), `expo/claude-skills` (RN/Expo),
     playwright/browser-testing skills (E2E lanes)
3. **GitHub search** (only for unmatched slots):
   `gh search repos "claude code skill <activity>" --limit 5 --sort stars` or
   WebSearch `site:github.com claude code skill <activity>`. Judge by: SKILL.md
   present, stars/recency, README shows real behavior (not a stub).

## 3. Propose — with WHY, gated on real benefit
Present at most **3** suggestions as one AskUserQuestion (multiSelect), each option:
- **name + one-line WHY tied to this cycle** ("`xcode-build` — cycle 7 installs to
  a device; this skill wraps xcodebuild + signing, removing the #1 lane failure").
- First option = recommended set "(Recommended)"; auto-continue on defaults —
  the loop NEVER blocks on this question.
- If NO skill maps to a real gap: say "no skill gaps this cycle" and skip the
  question entirely. An empty scout is a valid, common outcome.

## 4. Install + bake
For each accepted skill:
```
git clone <repo> ~/.claude/skills/<name>        # or cp -r for local sources
test -f ~/.claude/skills/<name>/SKILL.md && echo ok
```
Then bake its trigger into the RELEVANT lane prompts only (the lane that has the
gap — not blanket). Claude lanes get the `/skill` or skill-name trigger line in
their preamble; non-claude agents skip (skills are Claude-Code-only).

## 5. Ledger — prove they actually help (the feedback loop)
Append to `docs/polylane-max/skills-ledger.md` per cycle:
```
| cycle | skill | why installed | used by lane? | verdict |
```
- After the cycle, the critic fills `used by lane?` (grep lane logs/verify docs
  for the skill's trigger/output) and `verdict`: helped | unused | hurt.
- **unused 2 cycles in a row → suggest removal** next scout (keep the toolbelt
  honest); `hurt` → remove immediately + log the learning to the blackboard.
- The scout READS the ledger first — never re-suggest a removed/unused skill for
  the same kind of gap.
