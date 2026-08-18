# Cycle 24 plan — runtime identity and bounded builder context

## Goal

Remove the live contradictions observed after Cycle 23: false `no-pane`
state, stale prior-run inbox instructions, and a full Graphify skill read before
small direct graph queries. Also repair the dry-run proof that documented `custom`
intensity metadata is currently rejected. Preserve legacy behavior only where a
run has no nonce.

## Frozen lanes

| Lane | OWN | Outcome |
| --- | --- | --- |
| `pane-identity` | tmux identity helper, state/supervisor observers, focused tests, lane evidence | Implement nonce-bound pane tags and a cwd-only fallback exclusively for fully untagged legacy panes |
| `context-hygiene` | worker API, prompt lint/optimizer/scout, skill/navigation references, focused tests, lane evidence | Scope active inbox events to the run and prevent Graphify from becoming selected-skill context |
| `runner-wire` | runner/model policy plus prime-hybrid/session/intensity integration tests and lane evidence | Tag every launch/adopt/recreate boundary, export worker run scope, enforce exact prime-hybrid prompt syntax, and preserve baked settings for manifest `custom` |
| `integrator` | exact-tip merges and Cycle 24 integration evidence | Merge without rewriting lane ownership, grade focused behavior, and hand one READY candidate to the coordinator |

## Frozen cross-lane interfaces

- `polylane_tmux_tag_pane SESSION PANE RUN_ID LANE WORKTREE` writes pane-local
  `@polylane_run_id`, `@polylane_lane`, and canonical `@polylane_worktree` options.
- `polylane_tmux_find_pane SESSION RUN_ID WORKTREE` returns the matching pane index.
  A fully untagged pane may match canonical cwd for migration; a partially tagged,
  wrong-run, or wrong-worktree pane must not fall back.
- `POLYLANE_WORKER_RUN_ID` is emitted to prime-hybrid panes and host-side worker
  calls. New message/relay events carry it; a scoped inbox returns only matching
  events. No scope preserves the legacy all-history API.
- A prime-hybrid prompt must contain the literal command
  `"$POLYLANE_PROJECT_ROOT/bin/polylane-workers.sh" inbox "$POLYLANE_PROJECT_ROOT" "$POLYLANE_WORKER_ID"`.
- `graphify` and `graphify-auto` are navigation infrastructure, never selected
  builder-kit records. Builders query the shared helper directly.
- Manifest `intensity: "custom"` validates available model ids and baked effort
  values but performs no remap. Only an explicit CLI `--intensity` selects a preset.
  The bootstrap Cycle 24 manifest omits intensity because the pre-fix runner cannot
  launch with `custom`; the red test and post-merge dry-run provide that proof.

## Verification and terminal boundary

Builders run only their focused contracts through the lane-local check cache. The
integrator reruns the combined focused matrix, inspects exact write sets, and checks
that a tagged pane remains discoverable after its process cwd drifts. The coordinator
alone runs the frozen terminal acceptance: the complete suite, whole-tree ShellCheck,
skill parity, and live GO plus intentional NO-GO rehearsal. A fresh transcript must
show direct graph queries and zero reads of `graphify/SKILL.md`.

No push, install, deployment, publication, purchase, live action, or trading
execution is authorized. Any stale context leak, wrong-run pane match, restart,
second terminal gate, unintended model/effort remap, failed frozen check, or
incomplete cleanup is NO-GO.
