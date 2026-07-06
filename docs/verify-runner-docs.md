# Verify — lane runner-docs

Goal (LOCKED): document `--intensity` and `--model` runtime flags in
`polylane-run/SKILL.md`, and the optional `ANTHROPIC_API_KEY` probe in
`references/install-helpers.md`. Nothing else.

## Evidence — flags documented (polylane-run/SKILL.md)

New section `## Runtime model controls (optional)` (SKILL.md:80), verbatim quotes:

- SKILL.md:87 — `### `--intensity <economy|balanced|performance|max>` — remap the whole run`
- SKILL.md:96 — `### `--model <lane=model_id>` — override a single lane`
- SKILL.md:98 — `**repeatable** — pass it once per lane you want to change:`

Examples layered onto the existing `"$RUNNER" .polylane/run.json` call, dry-run first:

```
"$RUNNER" .polylane/run.json --intensity balanced --dry-run   # SKILL.md:92
"$RUNNER" .polylane/run.json --intensity balanced             # SKILL.md:93
"$RUNNER" .polylane/run.json --model backend=claude-opus-4-8 --dry-run
"$RUNNER" .polylane/run.json \
  --model backend=claude-opus-4-8 \
  --model docs=claude-fable-5
"$RUNNER" .polylane/run.json --intensity performance --model docs=claude-fable-5 --dry-run  # SKILL.md:109
```

Base CLI documented unchanged (SKILL.md:113-114):

> These flags are additive — the base CLI (`<manifest> [--dry-run] [--yes]`) is unchanged.

Resolver `"$RUNNER"` unchanged and reused in every new example (present pre-edit at SKILL.md:35).

## Evidence — API-key probe note (references/install-helpers.md)

New subsection `### Optional: live model probing` (install-helpers.md:35), verbatim quotes:

> install-helpers.md:39 — resolve model IDs through the probe helper `bin/polylane-models.sh`. Setting `ANTHROPIC_API_KEY` is **optional**:
>
> install-helpers.md:41 — **With `ANTHROPIC_API_KEY` set** — `bin/polylane-models.sh` probes the Anthropic API live and lists the models that key can actually reach.
>
> install-helpers.md:43 — **Without it** — the helper falls back to a curated built-in model list, so the runner still works unauthenticated; the list is just static rather than probed.

Existing install steps intact — section order unchanged around the insert:
`## Install the polylane-run skill` (7) → `### Runtime dependencies` (21) →
`### Optional: live model probing` (35, NEW) → `## Set two paths first` (50) →
`## Steps` (57) → `## Caveats to pass to the user` (97).

## Consistency vs Lc HARD CONTRACT — exact spellings

| Contract item | Documented spelling | Match |
|---|---|---|
| `--intensity <economy\|balanced\|performance\|max>` | `--intensity <economy\|balanced\|performance\|max>` (SKILL.md:87) | ✓ |
| `--model <lane=model_id>` (repeatable) | `--model <lane=model_id>` + "repeatable" (SKILL.md:96,98) | ✓ |
| probe helper `bin/polylane-models.sh` | `bin/polylane-models.sh` (install-helpers.md:39,41) | ✓ |
| base CLI `<manifest> [--dry-run] [--yes]` unchanged | quoted "is unchanged" (SKILL.md:113-114) | ✓ |
| resolver `"$RUNNER"` already present | reused, not modified (SKILL.md:35) | ✓ |

No drift. No invented flags. Scope: only the 2 owned files edited.
