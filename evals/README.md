# polylane eval suite

Trigger + behavior coverage for the three skills, one file per skill:

| File | Skill under test | Trigger source of truth |
|---|---|---|
| `polylane.json` | `/polylane` (planner) | root `SKILL.md` description |
| `polylane-run.json` | `/polylane-run` (executor) | `polylane-run/SKILL.md` description |
| `polylane-auto.json` | `/polylane-auto` (fused plan+run) | `polylane-auto/SKILL.md` description |

`trigger_phrases` in each file are copied **verbatim** from the owning
SKILL.md's `description:` line. Do not invent phrases here — if a phrase is
missing from a SKILL.md, log it for that lane in `docs/parallel-status.md`.

## Shared schema (all files)

Top level:

| Field | Type | Meaning |
|---|---|---|
| `skill` | string | canonical skill name under test |
| `purpose` | string | what this eval set verifies |
| `schema` | string | pointer to this README |
| `trigger_phrases` | string[] | exact phrases from the SKILL.md description |
| `cases` | object[] | the eval cases (below) |
| `red_flags` | string[] | behaviors that must never appear in any run |

Case object:

| Field | Type | When | Meaning |
|---|---|---|---|
| `name` | string | always | unique snake_case id; prefix hints class (`trigger_`, `paraphrase_`, `negative_`, `behavior_`) |
| `class` | enum | always | `trigger` \| `scenario` \| `behavior` |
| `input` | string | always | the user prompt (trigger/scenario) or the situation under test (behavior) |
| `should_fire` | bool | `class=trigger` only | whether the skill under test must activate |
| `paraphrase` | bool | optional | `true` = realistic rewording of a documented phrase, still expected to fire |
| `expected_skill` | string | optional | on disambiguation negatives: the sibling skill that SHOULD own this input |
| `expect` | string[] | always | graded expectations — each must hold for a pass |

Case classes:

- **trigger** — does the right skill activate? Positives cover every documented
  phrase (≥1 case each) plus paraphrases; negatives cover unrelated prompts and
  plan-only vs run-only vs auto disambiguation (`expected_skill` names the owner).
- **scenario** — end-to-end planning behavior on a realistic goal set (lane
  count, model routing, gates).
- **behavior** — invariants of the generated artifacts / flow: mandatory-4
  preamble order, scoped `git add` (never `git add -A` / `git add .`), done
  marker first line exactly `STATUS: <lane> DONE`, runner dry-run before
  launch, auto's required end-of-run chat report.

## How to run

These are model-graded specs, not executable tests. For each case: present
`input` to a fresh Claude Code session with the three skills installed, then
grade every line of `expect` (and scan `red_flags`) against the transcript.
A case passes only if all `expect` lines hold and no red flag appears.

Validity check:

```
python3 - <<'EOF'
import json, glob
for f in sorted(glob.glob('evals/*.json')):
    d = json.load(open(f))
    print(f, 'OK', len(d['cases']), 'cases')
EOF
```
