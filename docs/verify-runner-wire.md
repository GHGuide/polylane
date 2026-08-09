# Runner-wire verification — Cycle 24

Run: `c24-context-hardening-20260810-a1`

## Boundary wiring

- `pane_for_worktree` delegates exclusively to
  `polylane_tmux_find_pane "$TMUX_SESSION" "${RUN_ID:-}" WORKTREE`; it retains
  no cwd lookup copy.
- Fresh builder panes: `launch_panes` tags the returned pane before state index,
  usage baseline, and transcript pipe.
- Fresh integrator pane: `run_integrator` tags the returned pane before state,
  usage baseline, and transcript pipe.
- Recreated builder pane: `recreate_lane_pane` tags after existence validation
  and before pane state reindexing and its transcript pipe.
- Legacy builder adoption: `adopt_existing_session` tags after lookup and before
  the adoption transcript pipe.
- Legacy integrator adoption: `adopt_integrator` tags after lookup and before
  its transcript pipe.
- `prime_hybrid_workers` and `prime_hybrid_pane_exports` both export
  `POLYLANE_WORKER_RUN_ID=${RUN_ID:-legacy}`. Contract-v2 prime-hybrid preflight
  requires the frozen literal inbox command.
- Manifest `intensity: custom` validates declared available model IDs and baked
  effort values without preset remap or role clamp. An explicit CLI intensity
  remains the remapping operation and wins over manifest metadata.

## Red then green evidence

Initial focused red run (cached command `bash tests/test-model-policy.sh`) failed
`policy-manifest-custom-preserves-baked-settings`: the runner rejected `custom`
as an unknown preset. The same red run showed missing alpha/integrator run-ID
exports and missing frozen-inbox preflight syntax in
`tests/test-prime-hybrid-integration.sh` (three failures).

After the implementation, the lane-local check cache recorded:

- `bash tests/test-model-policy.sh` — 17 pass, 0 fail.
- `bash tests/test-prime-hybrid-integration.sh` — 60 pass, 0 fail.
- `bash tests/test-session-resume.sh` — 8 pass, 0 fail; its narrow pane-identity
  double recorded the legacy builder tag.
- `bash tests/test-runtime-recovery.sh` — 15 pass, 0 fail; its narrow
  pane-identity double recorded the recreated-pane tag while preserving state
  reindexing and pipe assertions. A late relay regression first failed with
  inherited `IFS=|` (`quiet-codex-child-is-live` returned 1); both liveness
  helpers now set local default `IFS`, and the same cached test passed 15/15.
- `bash tests/test-intensity.sh` — 20 pass, 0 fail.
- `shellcheck -S warning bin/polylane-run.sh bin/polylane-model-policy.sh` —
  exit 0, no findings.

`bin/polylane-refine.sh queue "$POLYLANE_PROJECT_ROOT/docs/polylane/harness"`
returned `[]`; no eligible refinement required a proposal or decline.

## Exact diff

Base: `843102ac1e7562921b560dd7bb15b5d6abd01cc6`.

`git diff --check` exited 0. The exact changed implementation/test paths are:

- `bin/polylane-run.sh`
- `bin/polylane-model-policy.sh`
- `tests/test-prime-hybrid-integration.sh`
- `tests/test-session-resume.sh`
- `tests/test-runtime-recovery.sh`
- `tests/test-model-policy.sh`
- `docs/verify-runner-wire.md`
- `docs/status-runner-wire.md`

The committed patch is inspectable with
`git diff 843102ac1e7562921b560dd7bb15b5d6abd01cc6..HEAD --` for this exact list.

## Skill receipts

SKILL-READ: engineering:architecture | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/architecture/SKILL.md | 2056343451-2410

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: engineering:architecture — helped: kept pane identity in the
sibling API and separated advisory manifest metadata from explicit CLI remaps.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: recorded
the focused red failures before implementation and current green cached checks
before the completion handoff.
