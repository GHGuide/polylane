# Verify — evals/ suite (LANE = evals)

Owner: evals lane. Scope: `evals/**` — three per-skill eval files + shared-schema README.

Files: `evals/polylane.json`, `evals/polylane-run.json`, `evals/polylane-auto.json`, `evals/README.md` (schema doc — required since suite is multi-file).

## 1. JSON validity (evidence)

```
$ python3 <validator over evals/*.json>
== evals/polylane-auto.json: VALID JSON, skill=polylane-auto, cases=26
   trigger_phrases match frozen contract verbatim: OK
== evals/polylane-run.json: VALID JSON, skill=polylane-run, cases=22
   trigger_phrases match frozen contract verbatim: OK
== evals/polylane.json: VALID JSON, skill=polylane, cases=23
   trigger_phrases match frozen contract verbatim: OK
ALL FILES VALID; contract + structure checks pass
```

Structure checks also passed: unique case names per file; `class ∈ {trigger, scenario, behavior}`; `should_fire` present on every trigger case and absent elsewhere.

## 2. Case-count table (skill × class)

| Skill | Positive triggers | — of which paraphrase | Negative triggers | — of which disambiguation | Scenario | Behavior | Total |
|---|---|---|---|---|---|---|---|
| polylane | 9 | 3 | 7 | 2 | 4 | 3 | 23 |
| polylane-run | 7 | 2 | 8 | 2 | 0 | 7 | 22 |
| polylane-auto | 9 | 3 | 9 | 3 | 0 | 8 | 26 |
| **Total** | **25** | 8 | **24** | 7 | **4** | **18** | **71** |

## 3. Trigger-phrase coverage (evidence)

Every documented phrase (frozen contract = each SKILL.md `description:` verbatim) has ≥1 non-paraphrase positive case whose input contains it:

```
polylane:      OK /polylane · OK /lanes · OK split this into prompts · OK parallel terminals · OK make lane prompts · OK orchestrate builders
polylane-run:  OK /polylane-run · OK run the lanes · OK launch the terminals · OK execute the plan · OK start the builders
polylane-auto: OK /polylane-auto · OK plan and run · OK do the whole thing · OK autopilot the lanes · OK interview and launch · OK build it end to end
```

Validator asserted `trigger_phrases` arrays equal the frozen contract exactly — no invented phrases; no missing phrases to escalate in `docs/parallel-status.md`.

## 4. Hard negatives + disambiguation

Shared hard negatives in all three files: "run one agent to fix this bug", "review my PR", "install a skill for me", single-task builds ("add a dark theme to the settings screen"). Per-skill lexical traps: highway "lanes" (polylane); "run the tests", "start the dev server", "execute the migration script" (polylane-run); "read the whole thing and summarize", "end to end test" (polylane-auto).

Plan vs run vs auto disambiguation matrix (`expected_skill` set on each):

| Input | Fires | Must NOT fire (asserted in) |
|---|---|---|
| "make lane prompts …" | polylane | polylane-run.json, polylane-auto.json |
| "run the lanes" | polylane-run | polylane.json, polylane-auto.json |
| "execute the plan" | polylane-run | polylane-auto.json |
| "plan and run …" | polylane-auto | polylane.json, polylane-run.json |

## 5. Behavior invariants (LOCKED-goal item 3) — coverage evidence

```
polylane       mandatory-4           -> behavior_preamble_mandatory_four
polylane       never git add -A      -> behavior_never_git_add_all
polylane       DONE marker exact     -> behavior_done_marker_exact
polylane-run   dry-run before launch -> behavior_dry_run_before_launch, behavior_model_flags_compose_with_dry_run
polylane-run   report to chat        -> behavior_report_relayed_to_chat
polylane-auto  mandatory-4 + git add + DONE marker -> behavior_prompts_match_planner_invariants
polylane-auto  dry-run before launch -> behavior_dry_run_record_then_yes, behavior_model_flags_compose
polylane-auto  report to chat at end -> behavior_report_back_required (Phase 8 REQUIRED)
```

`git add -A` string counts: polylane.json 3×, polylane-auto.json 2×, polylane-run.json 0× — every occurrence is a *negative* assertion ("NEVER contains…" in `expect` or a `red_flags` entry), never an emitted instruction.

## 6. Schema documentation

Suite is multi-file → shared schema documented in `evals/README.md` (top-level fields, case fields incl. `paraphrase` + `expected_skill`, class semantics, how-to-run + validity snippet). Each JSON's `schema` field points there.
