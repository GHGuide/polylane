# ADR 001 — Claude lanes stay interactive tmux panes (not headless -p)

- **Status:** accepted
- **Cycle:** 0

## Decision
Keep the Claude launcher on long-lived interactive tmux panes. Do NOT convert lanes to headless 'claude -p --output-format stream-json' to mirror codex exec's stateless model.

## Why
Codex exec is non-interactive + machine-readable, which makes respawn cheap and state parsing trivial. Matching it would obsolete the wedge-detector, approval relay, pane-scraping state surface and respawn ladder — ~500 tested assertions of working machinery — and would delete the 'attach and watch/intervene in any lane' property that is a stated polylane selling point. The two concrete advantages codex actually had were closed WITHOUT the rewrite: effort is now applied mechanically (claude --effort) and respawn now resumes the session (claude --continue on first respawn) instead of restarting cold.

## Consequences
Claude keeps pane supervision; codex keeps exec. Platform differences live in the per-agent launcher (aligns with the codex-first package-separation design: shared core + thin claude-code/ and codex/ adapters). Revisit only if the watchable-pane property stops mattering.
