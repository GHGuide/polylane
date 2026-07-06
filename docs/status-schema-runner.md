STATUS: schema-runner DONE

Lane: schema-runner. Owns `.polylane/SCHEMA.md`, `bin/polylane-run.sh`, `bin/polylane-models.sh`.

Delivered (goal LOCKED — nothing beyond):
- Manifest schema: global `intensity` (economy|balanced|performance|max|custom),
  global `available_models` (string[]), per-lane/integrator `effort`
  (low|medium|high|xhigh|max). Documented in SCHEMA.md; JSON example validates
  with `jq`.
- `bin/polylane-run.sh`: `--intensity <preset>` remaps every lane + integrator
  (effort fixed per preset, model resolved from `available_models` via a
  preference ladder with graceful fallback); `--model <lane=id>` overrides one
  lane (repeatable, applied after --intensity so it wins). Applied before any
  worktree/pane. Existing base CLI + behavior unchanged when neither flag passed.
- `bin/polylane-models.sh`: probes the Anthropic /v1/models API; prints the
  curated fallback list (claude-fable-5, claude-opus-4-8, claude-sonnet-5,
  claude-haiku-4-5) on no key / no tool / failure. One id per line, exit 0.
- Guards: unknown intensity → exit 2; malformed/unknown-lane --model → exit 2;
  --intensity with empty available_models → exit 1. No panes/worktrees on abort.

Evidence: docs/verify-schema-runner.md (bash -n both scripts, no-key fallback
output, dry-run remap for all scenarios, single-override, guard errors, jq
validation). TDD suites: models 8/8, run 24/24 GREEN.

Contract frozen for L2/L3/L4: schema keys + the two CLI flags above.
No cross-lane contract questions raised; docs/parallel-status.md untouched.
