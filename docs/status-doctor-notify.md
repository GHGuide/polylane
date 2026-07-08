STATUS: doctor-notify DONE

- bin/polylane-notify.sh — committed a04949b (contract: `<event> <message>`, events done|go|no-go|halt|stall, exit 0 always, quiet no-op sans osascript).
- bin/polylane-doctor.sh — PASS/WARN/FAIL table + fix hints; exit 0 no-FAIL / 1 any-FAIL; checks deps, git+orphans+collisions, manifest+prompt_files+worktrees, disk (<5GB WARN, <1GB FAIL), tmux session (POLYLANE_SESSION), claude version. Fixed during verify: worktree sanity anchors at the manifest's project root, not the caller's repo root.
- Evidence: docs/verify-doctor-notify.md (real doctor tables vs this repo + real 9-lane manifest, all failure paths, all 5 notify events fired, bash -n + shellcheck clean, ran under bash 3.2.57).
- No files outside lane ownership touched.
