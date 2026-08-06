# Worker-efficiency verification

## Scope

Implemented m8.3 agent-aware model selection and m8.7 local skill scouting/outcome ranking.

## Evidence

Executed through `bin/polylane-check.sh "$PWD/.polylane/check-cache/worker-efficiency"`:

- `bash tests/test-models.sh && bash tests/test-intensity.sh && bash tests/test-promptopt.sh && bash tests/test-scout-outcomes.sh`
  - `test-models.sh`: 20 pass, 0 fail
  - `test-intensity.sh`: 20 pass, 0 fail
  - `test-promptopt.sh`: 5 pass, 0 fail
  - `test-scout-outcomes.sh`: 17 pass, 0 fail
- `shellcheck -S warning bin/polylane-models.sh bin/polylane-promptopt.sh bin/polylane-scout.sh`
  - exit 0, no findings

The test-first failures showed Codex mode falling through to Claude fallbacks, the absent prompt optimizer, and absent scout outcome interfaces before the minimal implementations were added.

## Design tradeoffs

- Claude remains the no-argument default. Codex reads only local cache ids matching `gpt-*`; empty, malformed, or unavailable cache data falls back deterministically to `gpt-5.6-terra`.
- Prompt checks only inspect immutable files. Metrics are deterministic JSON using byte count and a whitespace-token estimate; mandatory `GOAL`, `CONTEXT`, `CONSTRAINTS`, and `VERIFICATION` blocks are enforced before budget admission.
- Scout resolution requires an exact local `SKILL.md`, preferring configured roots then read-only Codex plugin cache. GitHub suggestions remain advisory metadata and never enter resolution or recommendation output.
- The JSONL outcome ledger is append-only. Any `hurt` excludes a candidate, helped count sorts first, repeated unused records demote, and lexical skill id resolves final ties.

## Changed files

- `bin/polylane-models.sh`
- `bin/polylane-promptopt.sh`
- `bin/polylane-scout.sh`
- `tests/test-models.sh`
- `tests/test-promptopt.sh`
- `tests/test-scout-outcomes.sh`

## DEFERRED

DEFERRED: none
