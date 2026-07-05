# Verify — evals/evals.json (LANE = evals)

Owner: evals lane. Scope: `evals/evals.json` only.

## 1. Schema (documented)

`evals.json` top-level:

| Field | Type | Meaning |
|---|---|---|
| `skill` | string | canonical skill name under test (`polylane`) |
| `purpose` | string | what the set verifies |
| `trigger_phrases` | string[] | the 6 exact phrases from SKILL.md's `description` — source of truth |
| `schema` | object | self-describing field docs |
| `cases` | object[] | `{ name, class, input, should_fire?, expect[] }`; `class ∈ {trigger, scenario, behavior}`; `should_fire` present only on `class=trigger` |
| `red_flags` | string[] | behaviors that must never appear |

## 2. JSON validity (evidence)

```
$ python3 -c "import json; d=json.load(open('evals/evals.json')); print('VALID JSON'); print('cases:',len(d['cases']))"
VALID JSON
cases: 17
```

Class counts: `{'trigger': 11, 'scenario': 4, 'behavior': 2}` (6 positive + 5 negative triggers).

## 3. Trigger-phrase coverage (evidence)

Each of the 6 SKILL.md description triggers has a matching positive case input:

```
OK  /polylane
OK  /lanes
OK  split this into prompts
OK  parallel terminals
OK  make lane prompts
OK  orchestrate builders
```

## 4. Case → expected outcome

| Case | Class | should_fire | Expected |
|---|---|---|---|
| trigger_slash_polylane | trigger | true | skill activates; enters Phase 1 interview |
| trigger_slash_lanes | trigger | true | activates; starts spec interview |
| trigger_split_into_prompts | trigger | true | activates; no output before gates |
| trigger_parallel_terminals | trigger | true | activates; interviews before lanes |
| trigger_make_lane_prompts | trigger | true | activates; presents spec, waits yes |
| trigger_orchestrate_builders | trigger | true | activates; orchestrator only |
| negative_single_agent | trigger | false | NOT active — single agent |
| negative_review_pr | trigger | false | NOT active — code review |
| negative_install_skill | trigger | false | NOT active — skill install |
| negative_plain_build | trigger | false | NOT active — single change, no lane cue |
| negative_lanes_unrelated_word | trigger | false | NOT active — "lanes" is a highway, not /lanes |
| single_goal_one_lane | scenario | — | 1 lane, no forced 3 |
| three_disjoint_three_lanes | scenario | — | 3 lanes + integrator |
| entangled_pair_carve_or_merge | scenario | — | merge or HARD CONTRACT, never shared file |
| spec_gate_blocks | scenario | — | no prompts; explicit yes required |
| behavior_preamble_mandatory_four | behavior | — | every prompt opens with mandatory-4 in order |
| behavior_never_git_add_all | behavior | — | scoped `git add`; never `git add -A` / `git add .` |

## 5. Behavior invariants asserted

- **Mandatory-4 preamble** (SKILL.md:36,42) — order `1) /graphify-auto · 2) caveman(full) · 3) /goal <lane goal> · 4) superpowers:using-superpowers`; none omitted/reordered.
- **Never `git add -A`** (SKILL.md:47, references/prompt-blocks.md:68) — scoped stage of own paths only; wait+retry on index.lock. The string `git add -A` appears in the file 3× — all as *negative* assertions (2 in `behavior_never_git_add_all.expect`, 1 in `red_flags`), never as an emitted instruction.

## 6. Contract note

All 6 description triggers are present and covered — no missing trigger to escalate to the SKILL.md owner.
