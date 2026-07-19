# Decisions — the north-star trail

- [001 Claude lanes stay interactive tmux panes (not headless -p)](001-claude-lanes-stay-interactive-tmux-panes-not-headl.md) — Keep the Claude launcher on long-lived interactive tmux panes. Do NOT convert lanes to headless 'claude -p --output-format stream-json' to mirror codex exec's stateless model.
- [002 Keep the current layout: Claude at root, Codex as a thin overlay](002-keep-the-current-layout-claude-at-root-codex-as-a-.md) — Do NOT restructure into shared-core + claude-code/ + codex/ packages. The repo stays as it is: SKILL.md + bin/ + references/ at the root (Claude Code), with codex/install.sh assembling the Codex skill as a thin overlay from those same sources.
