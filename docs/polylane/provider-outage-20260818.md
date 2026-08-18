# Provider outage — 2026-08-18

Both lane providers were unavailable simultaneously on this host:

- **Claude CLI**: OAuth credential expired (`claude auth status` → `loggedIn: false`;
  keychain `expiresAt: 0`, refresh fails). Every interactive lane freezes at
  "Login expired · Please run /login". Recovery is user-only: run `claude` in any
  terminal and complete `/login`, then resume runs.
- **Codex CLI**: usage limit exhausted; resets **2026-08-20 15:03 local**.

Observed consequences (preserved as evidence):

- Polylane cycle-17 relaunch attempts died rc=2 in a supervisor restart loop —
  the visible symptom that started this diagnosis.
- MergePaid strategy run `mp-strategy-c1-17aug26` (4 Claude lanes, launched
  2026-08-18 15:19, private socket `polylane-tmux-mp-strategy-c1-17aug-*`) — all
  panes frozen at the login prompt; its supervisor cannot help.
- Polylane c41 integrator (run `c41-source-calibration-20260812-a1`) sat ~5 days
  at an ordinary approval dialog: not a matcher gap (the dialog shape is
  recognized) but an **orphaned run** — its coordinator died on codex quota
  exhaustion, so nobody polled `approval_check`. Its work was already salvaged
  into `codex/taste-certification` (6b2da3e is in that history); the pane was a
  zombie and was cleaned up.

Toolchain hardening landed in response (commits on main, 2026-08-18):

1. `bin/polylane-doctor.sh check_auth` — pre-launch login probe for the selected
   agent; FAIL names the exact remedy. Validated against this live outage.
2. `bin/polylane-run.sh` — `startup_check` parks a login-expired lane
   (NEEDS_DECISION) instead of letting the wedge detector respawn into the same
   login screen; `health_check` skips parked lanes entirely.
3. `bin/polylane-models.sh` — codex detection reads real `.models[].slug` cache
   entries (was reading `.id`, which holds "priority" strings → permanent
   single-model fallback); claude curated list gains `claude-opus-5`; stale-cache
   warning + `POLYLANE_CODEX_MODELS_CACHE` override.

## Unblock instructions (user)

1. Run `claude` in any terminal and complete `/login` — this revives all Claude
   lane work immediately, **or** wait for the codex reset on Aug 20 15:03.
2. The c42a recovery (target `m32.6`) then starts from a fresh run ID per
   `docs/polylane/cycle-42a-outcome.md`: import content-addressed artifacts from
   the immutable `4851bc1` handoff (branches `lane/c42a-*` in the
   `polylane-c32` clone), fresh worker-owned handoffs, frozen host gate at the
   exact candidate, promote only on fresh GO.
