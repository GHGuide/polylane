# Verify: task-live functional hard gate

Lane `task-live`, Cycle 40. Proves a candidate product's **functional success** and
**product-specificity** from replayed browser traces, not prose.

- Schema: `benchmarks/taste-live/task-schema.json`
- Validator / hard-gate compiler: `bin/polylane-taste-task.sh`
- Adversarial acceptance: `tests/test-taste-task-live.sh` (48 assertions, all green)
- Evidence cache: `.polylane/check-cache/task-live/` (ShellCheck `-S warning` + test run)

## What the gate is

The browser/capture lane emits a `taste-capture-manifest/v1` that pins, per capture,
an opaque `dom_sha256` and `action_trace_sha256`. The coordinator pins a
`taste-task-plan/v1` that declares the per-brief tasks, the state each reaches, and
the **success oracle** (`expected`) for every assertion. A pinned browser task
adapter replays an allowlisted action trace and reports only **observed** measured
evidence bound to the pinned DOM. `polylane-taste-task.sh gate` then:

1. binds the subject (manifest ⇄ plan ⇄ git HEAD; candidate id; brief + design-lock hashes);
2. pins the adapter by digest and runs it in an isolated workspace under a timeout;
3. content-addresses each replayed trace + DOM back to the manifest pins;
4. rejects any non-allowlisted action / unsafe selector / external route;
5. **derives** every assertion verdict by joining the pinned oracle with the observed
   evidence — it never trusts a caller `status`/`pass`/`verdict` field;
6. requires every task, state, and assertion to resolve, and the product signature to
   be proven with its counterfactual absent;
7. writes a `taste-task-receipt/v1` (classification always `fixture`,
   `human_certified:false`).

`gate` usage:

```
polylane-taste-task.sh gate <project-root> <capture-manifest.json> \
    <task-plan.json> <receipt-out.json> -- <adapter> [args...]
```

The adapter is invoked once with `POLYLANE_TASK_REQUEST` (a request file the gate
writes) and `POLYLANE_TASK_OUTPUT` (a directory) in its environment; it must emit
`result.json` (`taste-task-adapter-result/v1`) and `receipt.json`
(`taste-adapter-receipt/v1`).

## Schema examples

### Task plan (oracle lives here, never in the adapter)

```json
{
  "schema_version": "taste-task-plan/v1",
  "candidate_id": "cand-grocery-a",
  "source_revision": "<40–64 hex git rev>",
  "brief_sha256": "<64 hex>", "design_lock_sha256": "<64 hex>",
  "evidence_class": "fixture", "baseline_receipt_path": "",
  "adapter": {"adapter_id":"task-replay","adapter_version":"fixture-v1",
              "command_path":"tools/task-adapter","command_sha256":"<64 hex>","profile_sha256":"<64 hex>"},
  "required_states": ["empty","populated"],
  "tasks": [
    {"task_id":"task-empty-state","brief_clause":"An empty list shows a call to action",
     "reaches_state":"empty",
     "assertions":[{"assertion_id":"assert-empty-cta","kind":"exists","selector":"[data-testid=empty-cta]","expected":null}]},
    {"task_id":"task-add-item","brief_clause":"Users can add an item to the list",
     "reaches_state":"populated",
     "assertions":[
       {"assertion_id":"assert-row-count","kind":"count","selector":"[data-testid=item-row]","expected":1},
       {"assertion_id":"assert-add-visible","kind":"exists","selector":"[data-testid=add-btn]","expected":null}]},
    {"task_id":"task-title","brief_clause":"The header shows the grocery list name",
     "reaches_state":"populated",
     "assertions":[{"assertion_id":"assert-title-present","kind":"text_present","selector":"h1","expected":"Grocery List"}]}
  ],
  "product_signature": {
    "mechanism": "add-to-list-appends-row-and-titles-count",
    "clause_trace": ["Users can add an item to the list"],
    "rendered_anchor": {"capture_id":"cap-populated","task_id":"task-title","assertion_id":"assert-title-present"},
    "task_proof": ["task-add-item"],
    "counterfactual": {"unrelated_brief_id":"brief-flight-booker","selector":"[data-testid=flight-search]"}
  },
  "manual_external_tasks": []
}
```

### Adapter result (observed evidence only — no verdict field)

```json
{
  "schema_version": "taste-task-adapter-result/v1",
  "adapter_id": "task-replay", "adapter_version": "fixture-v1",
  "profile_sha256": "<64 hex>", "evidence_class": "fixture",
  "captures": [
    {"capture_id":"cap-populated","dom_sha256":"<pin>","action_trace_sha256":"<pin>",
     "action_trace":[
       {"type":"navigate","route":"/"},
       {"type":"fill","selector":"input[name=item]","value":"Milk"},
       {"type":"click","selector":"[data-testid=add-btn]"},
       {"type":"wait_for","selector":"[data-testid=item-row]"}],
     "tasks":[
       {"task_id":"task-add-item","reaches_state":"populated","assertions":[
         {"assertion_id":"assert-row-count","kind":"count","selector":"[data-testid=item-row]","measured":{"dom_sha256":"<pin>","match_count":1}},
         {"assertion_id":"assert-add-visible","kind":"exists","selector":"[data-testid=add-btn]","measured":{"dom_sha256":"<pin>","match_count":1}}]},
       {"task_id":"task-title","reaches_state":"populated","assertions":[
         {"assertion_id":"assert-title-present","kind":"text_present","selector":"h1","measured":{"dom_sha256":"<pin>","text":"Grocery List — 1 item"}}]}]}
  ],
  "signature": {"anchor":{"capture_id":"cap-populated","task_id":"task-title","assertion_id":"assert-title-present"},
    "counterfactual":{"selector":"[data-testid=flight-search]","measured":{"dom_sha256":"<pin>","match_count":0}}}
}
```

## Allowlists and safety (frozen)

- **Actions**: `navigate click fill select press wait_for submit`. No `eval`/`script`/`exec`
  type and no extra action key can appear — an arbitrary type is `ARBITRARY_ACTION`;
  `navigate` may only target a relative in-app route (`^/[A-Za-z0-9/_-]*$`, no `//`, no
  `..`, no scheme/host) — anything else is `NETWORK_ACTION`.
- **Assertions**: `exists absent unique count text_equals text_present value_equals attr_equals state_is`.
- **Selectors**: bounded CSS/attribute charset; the substrings `javascript:`, `<`,
  `` ` ``, `;`, `{`, `}`, `$` are forbidden (`UNSAFE_SELECTOR`).
- **Paths**: `baseline_receipt_path` is a repo-relative regular file with no symlink
  component (`safe_relative_regular_file`); an escape is `UNSAFE_PATH`.

`tests/test-taste-task-live.sh` asserts the allowlists embedded in the validator are
byte-identical to `benchmarks/taste-live/task-schema.json` (`schema-actions-match-code`,
`schema-assertions-match-code`) so schema and code can never drift.

## Verdict derivation (executable oracle)

Per assertion, with `$expected` from the **plan** and `measured` from the **adapter**:

| kind | PASS iff |
|---|---|
| `exists` | `match_count >= 1` |
| `absent` | `match_count == 0` |
| `unique` | `match_count == 1` |
| `count` | `match_count == expected` |
| `text_present` | `text` contains `expected` |
| `text_equals` / `value_equals` / `attr_equals` | `observed == expected` |
| `state_is` | `state == expected` |

`derived_status`:

- `FAIL` if any veto: a failed assertion (`ASSERTION_FAILED`), a task that reached the
  wrong state (`STATE_NOT_REACHED`), an unproven mechanism anchor
  (`SIGNATURE_UNPROVEN`), or a present unrelated-brief marker (`SIGNATURE_GENERIC`);
- else `EXTERNAL` if the plan lists `manual_external_tasks` (never auto-passed);
- else `PASS` (`reason_codes: ["CLEAN"]`).

Structural problems (missing/unknown/duplicate/forged/unsafe/stale) are **fail-closed
rejects**: the gate exits non-zero and writes no receipt.

## Product signature (specificity, not prose)

A PASS requires all of:

1. **Mechanism** — a brief-specific name.
2. **Rendered anchor** — `{capture_id, task_id, assertion_id}` that resolves to a real
   capture/task/assertion whose derived verdict PASSes (`mechanism_proven:true`),
   i.e. the distinctive mechanism is actually rendered in a real trace.
3. **Clause trace** — every entry equals some task's `brief_clause` (plan-checked).
4. **Task proof** — tasks whose passing proves the mechanism works end to end.
5. **Unrelated-brief counterfactual** — an unrelated brief's distinctive selector,
   evaluated as an `absent` oracle against the anchor capture's pinned DOM. If it is
   present (`match_count > 0`) the product is generic → `SIGNATURE_GENERIC` veto
   (`counterfactual_absent:false`).

Together: **this** brief's marker present **and** an unrelated brief's marker absent ⇒
the product is specific to the brief, falsifiably and deterministically.

## Deterministic replay

- Each capture's `action_trace_sha256` must equal the manifest pin **and** the
  recomputed canonical hash of the emitted `action_trace` (`jq -cS` then SHA-256). A
  trace that does not reproduce the pinned bytes is `NONDETERMINISTIC`.
- All measured evidence carries `dom_sha256` equal to the capture's pinned DOM
  (`STALE_DOM` otherwise), so every verdict is provably derived from the pinned render.
- Receipt timestamps use `POLYLANE_TASK_NOW` when set. The test asserts
  `deterministic-replay-identical`: two runs over identical inputs produce a
  byte-identical receipt.

## Full attack matrix (red-first, all rejected/vetoed)

Every row is an executable test in `tests/test-taste-task-live.sh`; the adapter injects
each attack via an environment knob so the trust boundary is probed without a browser.

| # | Attack | Injection | Outcome |
|---|---|---|---|
| 1 | valid task + missing task | drop a required task (matrix intact) | reject `MISSING_TASK`, no receipt |
| 2 | missing state | sole reacher of a state claims another | reject `MISSING_STATE` |
| 3 | selector ambiguity | `count` oracle matched 2 nodes | FAIL `ASSERTION_FAILED` (`match_count:2` recorded) |
| 4 | wrong value | text oracle no longer satisfied | FAIL `ASSERTION_FAILED` |
| 5 | stale DOM | measured `dom_sha256` ≠ pinned render | reject `STALE_DOM`, no receipt |
| 6 | skipped assertion | drop a required assertion from a task | reject `COVERAGE_INCOMPLETE` |
| 7 | caller pass | inject a `status` field into `measured` | reject `CALLER_PASS`, no receipt |
| 8 | arbitrary script | non-allowlisted action `type:"eval"` | reject `ARBITRARY_ACTION` |
| 9 | network | `navigate` to an absolute/external URL | reject `NETWORK_ACTION` |
| 10 | unsafe selector | injection-shaped selector | reject `UNSAFE_SELECTOR` |
| 11 | selector tamper | assertion selector swapped off the pinned oracle | reject `ASSERTION_TAMPERED` |
| 12 | timeout | adapter exceeds `POLYLANE_TASK_TIMEOUT` | reject `ADAPTER_TIMEOUT`, no receipt |
| 13 | nondeterminism | safe extra action breaks the pinned digest | reject `NONDETERMINISTIC` |
| 14 | forged capture | echoed DOM digest ≠ manifest pin | reject `FORGED_CAPTURE` |
| 15 | signature counterfactual | unrelated-brief marker present | FAIL `SIGNATURE_GENERIC` (`counterfactual_absent:false`) |
| 16 | signature unproven | anchor mechanism assertion fails | FAIL `SIGNATURE_UNPROVEN` |
| 17 | fixture→production relabel | adapter claims `production` | reject `FIXTURE_RELABELED` |
| 18 | stale adapter receipt | `executed_at` before source | reject `STALE_RECEIPT` |
| 19 | forged adapter | file mutated after the plan pin | reject `ADAPTER_MISMATCH` |
| 20 | stale source revision | manifest rev ≠ HEAD | reject `STALE_SOURCE_REVISION` |
| 21 | candidate mismatch | plan/manifest candidate ids differ | reject `CANDIDATE_MISMATCH` |

Positive, determinism, manual→EXTERNAL, and a post-attack restored-PASS regression
guard bracket the matrix. `EXTERNAL-EVIDENCE`: only replayed actions + derived
assertions count; the hand-written fixture world and receipts are `classification:
"fixture"`, `human_certified:false`, and can never mint a production PASS.

## How to reproduce

```
shellcheck -S warning bin/polylane-taste-task.sh tests/test-taste-task-live.sh
bash tests/test-taste-task-live.sh        # 48 pass, 0 fail
jq -e . benchmarks/taste-live/task-schema.json
# cached:
bin/polylane-check.sh "$PWD/.polylane/check-cache/task-live" -- bash tests/test-taste-task-live.sh
```

## Skill evidence

- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: product-management:write-spec | /Users/leonardo/.codex/plugins/cache/claude-cowork/product-management/1.2.0/skills/write-spec/SKILL.md | 3505650752-12326
- SKILL-EVIDENCE: engineering:testing-strategy — helped: its "cover business-critical paths, error handling, edge cases, security boundaries" framing shaped the 21-row red-first attack matrix (data-integrity: forged/stale/nondeterministic; security: arbitrary/network/unsafe/caller-pass) with one executable, deterministic oracle per row rather than prose acceptance.
- SKILL-EVIDENCE: product-management:write-spec — helped: its Given/When/Then acceptance-criteria discipline and "avoid ambiguous words; each criterion independently testable" rule became the plan's per-assertion oracle (`kind`+`selector`+`expected` derived by the validator) and the product-signature clause trace / unrelated-brief counterfactual that turns "distinctive" into a falsifiable check.
