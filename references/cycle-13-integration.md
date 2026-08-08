# Cycle 13 integration controls

This reference keeps the root Claude and Codex `SKILL.md` files focused. It
describes the shared Bash controls; each installed package retains its own
entrypoint and prompt syntax.

## Before a pane opens

Set manifest `intensity` to `economy`, `balanced`, `performance`, or `max` and
declare only models the selected agent can actually use in `available_models`.
The runner resolves that policy once, applies any `--intensity` and `--model
lane=id` command-line requests, applies role safety clamps, and prints one
`policy lane=... model=... effort=...` line per lane before creating a worktree
or tmux pane. A user model choice is final within the safe role ceiling; a
mechanical, security, hardest, or integrator clamp is never bypassed.

Contract-v2 source prompts first pass strict lint. The runner then writes
launch-only copies under `.polylane/compiled-prompts/<run-id>/`, compares their
frozen contracts to the sources, lints them again, and launches only those
copies. Compilation removes byte-identical ordinary lines; it never rewrites
the source prompt or resolves a duplicate/conflicting scalar contract.

## Metadata-only skill planning and close-loop evidence

Build a local catalog before selecting a kit; it contains frontmatter metadata,
paths, source, and a fingerprint, never a skill body:

```bash
bin/polylane-scout.sh catalog-index .polylane/skill-catalog.json
bin/polylane-scout.sh catalog-recommend .polylane/skill-catalog.json \
  .polylane/<lane>-spec.json docs/polylane/skill-outcomes.jsonl
```

Use the explained candidates to choose the existing 1–2 predefined and 1–2
lane-specific installed skills. Put only those selected names in the lane prompt
and `.polylane/lane-skills.json`; do not place a catalog or skill inventory in a
builder prompt. GitHub discovery remains advisory. An untrusted skill may be
armed only after the existing project-local quarantine, audit, benchmark, pin,
and rollback gate.

After each contract-v2 builder completes, the runner records a JSON receipt in
`docs/polylane/skill-use/<run-id>/` and appends only explicit
`SKILL-EVIDENCE: <id> — helped: ...`, `unused: ...`, or `hurt: ...` outcomes to
the canonical outcome ledger. Missing evidence is `unused`; prose never turns
missing evidence into `helped`.

## Optional lifecycle hooks

`assets/hooks/codex-hooks.json` and `assets/hooks/claude-settings.json` are
project-scoped fragments, not installers. Review and merge the appropriate
fragment into the target project only when the user trusts project hooks. They
call `polylane-hooks.sh` to restore a bounded allowlisted context and reject a
Stop without an exact current-run marker plus run-tagged verification evidence.
They never change global settings, permissions, runner state, worktrees, or the
supervisor; the supervisor remains the sole runtime authority.

## Certification matrix

Use `bin/polylane-certify.sh focused` while integrating. It runs named discovery,
planning/prompt, model-policy, skill-routing, graph/runtime/recovery,
integration/learning, install/parity, and targeted ShellCheck layers. Run
`bin/polylane-certify.sh terminal` exactly once at the current source boundary
for a fresh full suite, both fresh installs, all ShellCheck, and the doctor
GO/NO-GO rehearsal. Terminal evidence is not reused after source changes.
