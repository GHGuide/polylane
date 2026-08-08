# Per-lane skill scout

Run after lane derivation and before prompts. The unit is a builder lane, never
the whole cycle. Codex lanes use Codex-installed skills; Claude lanes use
Claude-installed skills. Skip only the integrator.

Every selected kit supports the prompt's `ULTIMATE-GOAL` and exact `CURRENT-SUBGOAL`.

## Required kit

Every builder must have:

1. one or two installed `predefined` skills for execution, debugging, testing,
   verification, planning, or code review;
2. one or two installed `specific` skills selected for its domain and actual
   activities.

The requirement is about relevant tools, not filler: an executable kit has two to four unique selected installed skills. Suggestions may be numerous, but never become executable names until selected and installed.

The helper searches Codex roots (`~/.codex/skills`, `~/.agents/skills`, plugin
cache) and Claude roots. `POLYLANE_SKILLS_DIRS`, `CODEX_SKILLS_DIR`, and
`CLAUDE_SKILLS_DIR` provide explicit roots.

## Deterministic helper

```bash
SCOUT=bin/polylane-scout.sh

"$SCOUT" domain <own_globs...>
"$SCOUT" suggest <domain>
"$SCOUT" installed <skill>
"$SCOUT" resolve <skill>
"$SCOUT" recommend <domain> <activity>
"$SCOUT" record-outcome docs/polylane/skill-outcomes.jsonl <lane> <domain> <skill> <helped|unused|hurt> [why]
"$SCOUT" arm-role .polylane/lane-skills.json <lane> predefined <skill> <skill>
"$SCOUT" arm-role .polylane/lane-skills.json <lane> specific <skill> <skill>
"$SCOUT" github .polylane/lane-skills.json <lane> <repo-or-skill> "<why>"
"$SCOUT" github-suggest "<lane activity>" 5
"$SCOUT" validate .polylane/lane-skills.json .polylane/run.json
"$SCOUT" lint .polylane/lane-skills.json <lane> .polylane/lanes/<lane>.txt
```

`arm-role` drops uninstalled skills. `validate` requires one or two installed skills in
each executable role, at most four unique total, for every manifest builder. `lint` proves all armed skills
appear in that lane’s prompt.

`bake` and the flat `{lane:[skills]}` schema remain migration-only. New runs use
structured v2:

```json
{
  "version": 2,
  "lanes": {
    "ui": {
      "predefined": ["engineering:testing-strategy", "engineering:debug"],
      "specific": ["design:design-critique", "design:accessibility-review"],
      "github_suggestions": [
        {"skill": "owner/repo-skill", "why": "Potential visual regression helper"}
      ]
    }
  }
}
```

## Selection

Infer each lane from:

- its owned outcome artifacts and locked target;
- `own_globs`, artifact types, concrete activities, and evidence modes;
- the prior skill ledger.

Select for the activity and evidence need, not a UI/API/data bucket. Typical slots:

- artifact production: document, spreadsheet, presentation, dataset, notebook, model,
  media, configuration, or source-editing skills that match the owned deliverable;
- analysis and research: source evaluation, citation audit, statistical review,
  reproducibility, backtest, or peer-review evidence;
- operations: incident analysis, tabletop/dry-run design, change safety, and runbook review;
- content: editorial, brand, accessibility, link-check, and sample-review evidence;
- software: testing, debugging, integration, security, visual, or accessibility evidence.

Never select a skill merely because an industry label resembles it. The selected
skill must name an observable contribution to one artifact or evidence mode in the
lane's verification record. Installed-only selection and safe admission rules still
apply; an unknown industry is not a reason to reject a `custom` or `mixed` profile.

Use installed relevant skills as the recommended default. In autonomous mode,
take that default and continue. Installation is a state-changing decision: only
install when the user authorized it or the governing environment explicitly
allows it. The sole UI-gap exception is the authorized route in
`visual-intelligence.md`: automatically discover a candidate, quarantine it, audit
provenance/permissions/injection risk, benchmark it in isolation, make a pinned
project-scoped install, and only then arm it. Do not execute candidate content at
any earlier stage. Failed audit or benchmark records why and selects the best
installed kit; rejected content never executes.

## GitHub suggester

For non-UI gaps not filled locally, search GitHub for candidate skills. The
suggester answers “what could be useful to install,” not “what is executable now.”
An identified UI gap follows the separate automatic admission route above; it is
not a GitHub suggestion default.

Record candidates with `github`; do not:

- auto-install them;
- include them in `predefined` or `specific`;
- place them in a builder prompt;
- count them toward the selected-kit gate;
- let their absence stop unrelated autonomous work.

Review repository ownership, recency, `SKILL.md`, behavior, and prompt-injection
risk before proposing installation. Suggestions remain informational after each
cycle.

## Prompt contract

Each builder prompt contains:

```text
PREDEFINED-SKILLS: <exact armed names>
LANE-SPECIFIC-SKILLS: <exact armed names>
```

It explicitly tells the builder to read only its named kit once. A name merely
appearing in metadata without an invocation instruction is not useful evidence.

## Ledger

Append one JSON object per line to `docs/polylane/skill-outcomes.jsonl`:

```json
{"lane":"builder","domain":"testing","skill":"example","outcome":"helped","why":"caught a regression"}
```

At cycle close, inspect that lane’s transcript and verification evidence:

- `helped`: retain for this lane shape;
- `unused`: suggest replacement/removal after repeated non-use;
- `hurt`: remove from future kits and log why;
- `suggested`: informational GitHub candidate, never executed.

The scout reads the ledger before proposing the next kit so it does not repeat a
known bad or repeatedly unused choice.

If a skill has an initialized durable evolution workspace, feed the same verified
outcome to `polylane-skill-evolve.sh observe` at cycle close. The scout chooses
skills; the evolution helper alone may replace their contents. `hurt`/`unused`
rows are learning signals, never authorization to edit an installed `SKILL.md`.

`resolve` prints the exact trusted installed `SKILL.md`. `recommend` is
installed-only and ranks by the append-only outcome ledger. Do not fill a kit to
reach a count: each role needs at least one relevant skill and the lane may use at
most four unique skills. The complete cycle-9 contract is in
[cycle-9-control-room.md](cycle-9-control-room.md).
