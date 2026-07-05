STATUS: runner-skill DONE

Lane: runner-skill. Built the SEPARATE `/polylane-run` skill (`polylane-run/SKILL.md`).

Delivered:
- `polylane-run/SKILL.md` — new standalone skill.
  - Frontmatter: name `polylane-run`; trigger-focused description covering all 5 triggers
    ("/polylane-run", "run the lanes", "launch the terminals", "execute the plan", "start the builders").
  - Body (followable end-to-end): (a) check `.polylane/run.json` exists, else tell user run `/polylane`;
    (b) preflight tmux/jq/claude; (c) dry-run `bin/polylane-run.sh .polylane/run.json --dry-run` + show panes;
    (d) launch bare on go-ahead; (e) explain auto-poll / auto-integrate / merge-on-GO / scratch-delete-after-one-confirm.
  - Deps documented (tmux, jq, claude); consumes exactly what `/polylane` emits; generic, no hardcoded paths.
  - Install line: `cp -r polylane-run/ ~/.claude/skills/polylane-run/`.

CLI contract: honored EXACTLY — `bin/polylane-run.sh .polylane/run.json [--dry-run] [--yes]`. No invented flags.

Verify: docs/verify-runner-skill.md (fresh grep/sed evidence for frontmatter, triggers, CLI signature, dry-run-first, deps, install).

Coordination: no NEEDS DECISION. CLI matched the frozen signature — no escalation to L1.

Touched only: polylane-run/**, docs/verify-runner-skill.md, docs/status-runner-skill.md. No forbidden files touched.
