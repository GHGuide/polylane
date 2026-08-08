STATUS: model-policy DONE run=c13-perfection-20260808

Implemented m13.1 with one pre-launch, agent-aware model policy. Manifest
intensity is authoritative unless the CLI supplies `--intensity`; model
overrides are availability-checked; role clamps are enforced; and each lane's
final model/effort/source is printed before worktrees and panes are created.

Focused verification is recorded in `docs/verify-model-policy.md`.
