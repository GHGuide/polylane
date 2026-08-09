# Decisions — the north-star trail

- [001 Claude lanes stay interactive tmux panes (not headless -p)](001-claude-lanes-stay-interactive-tmux-panes-not-headl.md) — Keep the Claude launcher on long-lived interactive tmux panes. Do NOT convert lanes to headless 'claude -p --output-format stream-json' to mirror codex exec's stateless model.
- [002 Keep the current layout: Claude at root, Codex as a thin overlay](002-keep-the-current-layout-claude-at-root-codex-as-a-.md) — Do NOT restructure into shared-core + claude-code/ + codex/ packages. The repo stays as it is: SKILL.md + bin/ + references/ at the root (Claude Code), with codex/install.sh assembling the Codex skill as a thin overlay from those same sources.
- [003 Marathon self-run parameters](003-marathon-self-run-parameters.md) — Performance intensity; POLYLANE_MAX_CYCLES=99 (open-ended until mechanical COMPLETE); POLYLANE_AUTONOMOUS=1; target = polylane itself production-grade.
- [004 tmux-returned pane index is authoritative](004-tmux-returned-pane-index-is-authoritative.md) — Live launches store the pane index returned by tmux; predicted indices are dry-run previews only.
- [005 Evidence-first domain autonomy](005-evidence-first-domain-autonomy.md) — Use declarative adapters, profile-aware graders, accepted-outcome learning, benchmark-gated skills, resumable fault tests, and two-phase external-action previews.
