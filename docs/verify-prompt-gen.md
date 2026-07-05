# Verify — lane `prompt-gen` (prompt-generation core)

Owned files: `references/prompt-blocks.md`, `references/lane-template.md`, `references/interview.md`.
Evidence for every claim below was produced by grep on the committed files (commands + output inline). No claim without an artifact.

## 1. Mandatory-4 preamble order preserved (frozen contract)

Contract: `(1) /graphify-auto  (2) caveman full  (3) /goal  (4) superpowers:using-superpowers` — no reorder, no drop.

`grep -nE '^(1\.|2\.|3\.|4\.) ' references/prompt-blocks.md` (block 0):
```
9:1. /graphify-auto
10:2. Invoke the caveman skill (full)
11:3. /goal <one-line lock of THIS lane's goal>
12:4. superpowers:using-superpowers
```

Same order stated in SKILL.md (unedited, cross-check only):
```
1) `/graphify-auto`, 2) caveman skill (full), 3) `/goal <one-line lane goal>` (Anthropic built-in — sets + locks the objective), 4) `superpowers:using-superpowers`
```
→ **MATCH.** prompt-blocks.md block 0 == SKILL.md Phase 6 == frozen contract. Order intact.

## 2. Block labels A–J in order, matching across both files

`grep -nE '^## [A-J]\. ' references/prompt-blocks.md`:
```
16:## A. Identity + context
21:## B. Model + effort header
26:## C. Terse output ...
31:## D. Skills for this lane
37:## E. Graphify-first ...
49:## F. File ownership
56:## G. Forced verification ...
61:## H. Coordination + resource mutex
66:## I. Scoped git
71:## J. Done checklist
```

lane-template.md assembly skeleton (`grep -nE '^\[[0A-J] '`):
```
[A] [B] [0 MANDATORY-4] [C] [D] [E] [F]  GOAL/WORKFLOW  [G] [H] [I] [J]
```
→ Letter sequence **A→B→C→D→E→F→G→H→I→J is identical in both files.** Template interleaves block 0 (preamble) after B and the filled GOAL/WORKFLOW after F — by design (SKILL.md: "Every prompt MUST OPEN with the mandatory-4 preamble"; the GOAL block restates the `/goal` lock in-prompt). No letter reordered or dropped.

## 3. Block E q.py subcommands match assets/q.py

Block E lists: default `q.py <symbol>`, `callers`, `uses`, `near`, `file`.

`grep -nE 'cmd (==|in) ' assets/q.py` (real dispatch):
```
60: if cmd == "file"            -> file
68: if cmd == "community"       -> community (extra; not surfaced in block E — curated subset)
80: if cmd in ("callers","uses","near")
102: default node search        -> <symbol>
```
→ Every subcommand named in block E (`callers`/`uses`/`near`/`file` + default search) **exists in q.py exactly**. Contract subcommand names unchanged. `community` is a real extra deliberately left out of the block (niche); contract only requires the four + default, all present.

## 4. Drift fixed

Block A opened with the garbled token `LeLau-agnostic:` (not a word; absent from SKILL.md/README). Replaced with clean identity opener `Project: <PROJECT one-liner>.`

`grep -rn 'LeLau' references/ SKILL.md README.md`:
```
CLEAN: no LeLau anywhere
```

## 5. Mini-example added (lane-template.md)

`grep -n 'Filled mini-example' references/lane-template.md`:
```
37:## Filled mini-example (one lane, end to end)
```
A complete filled lane (Vue todo app, `dark-theme` lane, Opus 4.8/high) showing launch line + full A→J paste block, followed by a top-to-bottom order readout. A reader can now assemble one prompt end to end without guessing.

## 6. interview.md concreteness

Added: a worked batched round (3 user lines → draft spec → one AskUserQuestion with 3 questions + recommended-first options → re-present), and an explicit **re-present rule** (when to reprint the numbered spec, version bump + `*` on changed lines). Spec-gate exact wording ("Is this everything you expect to be integrated? Reply yes to lock it...") was already present and left unchanged.

## Result

3 owned files tighter. Mandatory-4 order intact. Block labels A–J intact and consistent across prompt-blocks.md ↔ lane-template.md. Block E == q.py subcommands. Drift removed. Mini-example lets a reader assemble a prompt end to end. No block letter or preamble step changed — no integrator decision needed.
