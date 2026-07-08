STATUS: dashboard DONE

Lane dashboard complete.

- Deliverable: `bin/polylane-dashboard.sh` — standalone read-only live tmux
  dashboard. CLI: `bin/polylane-dashboard.sh <manifest.json> [--interval N]`
  (default 5s), plus `--demo` and `--help`.
- Table: lane · model · state (waiting/working/DONE/FAILED/STALL) · elapsed ·
  last-seen tokens. Footer: N/M done · session (POLYLANE_SESSION, default
  polylane) · total elapsed · `tmux attach -t <session>` hint.
- State sources: runner-identical DONE-file test, runner-identical error
  regex on pane/log text, stall = pane unchanged ≥ POLYLANE_STALL_SECS (120).
  Panes located by `pane_current_path == worktree` with positional fallback.
- Robustness: missing manifest/invalid JSON/bad flags → usage + exit 2;
  missing worktree/status → waiting; no tmux → file/log fallback. bash-3.2
  safe (verified on /bin/bash 3.2.57); `bash -n` clean; jq only for manifest.
- Evidence: `docs/verify-dashboard.md` (real captured renders: fake-manifest
  fixture, the live polylane-fable run, --demo frames, unit checks, exit codes).
- Commits in this worktree: 911f304, c854b96, plus docs commit. Staged only
  bin/polylane-dashboard.sh, docs/verify-dashboard.md, docs/status-dashboard.md.
