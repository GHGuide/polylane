STATUS: runner-docs DONE

Lane: runner-docs (Opus 4.8, medium effort, caveman full).

Goal (LOCKED) delivered:
1. polylane-run/SKILL.md — new `## Runtime model controls (optional)` section documents
   `--intensity <economy|balanced|performance|max>` (remap whole run) and
   `--model <lane=model_id>` (repeatable, override one lane), examples layered onto the
   existing `"$RUNNER" .polylane/run.json` calls with `--dry-run` first. Base CLI
   `<manifest> [--dry-run] [--yes]` documented unchanged; `"$RUNNER"` resolver reused.
2. references/install-helpers.md — new `### Optional: live model probing` note: optional
   `ANTHROPIC_API_KEY` enables live probing via `bin/polylane-models.sh`; without it a
   curated fallback list is used. Existing install steps intact.
3. Consistency — flag spellings + helper name match Lc HARD CONTRACT exactly. No drift,
   no invented flags.

Evidence: docs/verify-runner-docs.md (verbatim quotes + spelling table).
Files edited (owned only): polylane-run/SKILL.md, references/install-helpers.md.
No forbidden files touched. No contract questions raised (nothing logged to parallel-status.md).
