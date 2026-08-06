# Cycle 9 digest — measured product autonomy

- Started from a fully green cycle-8 tree and deliberately reopened the goal for eight requested improvements.
- Added a versioned five-case corpus of realistic vague product briefs.
- Added isolated benchmark work directories and one JSONL result per case.
- Added completion and product-quality dimensions alongside time, tokens, interventions, and score.
- Preserved unavailable or malformed metrics as `null` instead of zero.
- Rejected malformed, duplicate, incomplete, and infeasible corpus cases.
- Hardened result parsing so wrong-shaped and nested-wrong-shaped JSON stays unknown.
- Added a durable typed discovery graph.
- Added recommended, deeper, bold, and custom answer routes.
- Bounded each discovery round to at most five questions.
- Made deep and bold answers activate child questions.
- Persisted contradictions and blocked strategy locking until resolution.
- Added bounded left/right contradiction resolution.
- Generated transcript-free strategy, north-star, and goal artifacts.
- Split Claude and Codex model discovery.
- Codex model discovery now returns only `gpt-*` IDs.
- Codex manifests reject Claude IDs in lanes, integrator, available models, and overrides.
- Added lean and user Codex profiles.
- Lean launches are ephemeral and ignore user configuration.
- Preserved explicit model, effort, sandbox, approval, prompt, and git metadata access.
- Added prompt byte/token metrics.
- Added mandatory-block and budget admission before launch, respawn, and repair.
- Added installed-only skill resolution to exact `SKILL.md` paths.
- Kept GitHub skill search informational until installation is explicit.
- Bounded executable skill kits to one-to-four skills.
- Added helped, unused, and hurt skill-outcome memory.
- Ranked recommendations from the outcome ledger.
- Wired risk admission through one advanced-runtime adapter.
- Wired mechanical seam evidence through that adapter.
- Kept champion selection and salvage opt-in behind explicit manifest contracts.
- Added exactly three independent quality judges.
- Required unique judge names and lenses.
- Added bounded judge timeouts.
- Staged judge evidence privately and published it atomically.
- Added a typed one-attempt judge-repair packet with aggregate/evidence paths.
- Added judge and judge-repair nodes only when configured.
- Preserved deterministic replay for legacy graphs without judges.
- Added a canonical one-shot control-room JSON schema.
- Rendered text and JSON from the same snapshot.
- Joined goal, graph readiness, lanes, spend, verdict, heartbeat, cleanup, and next action.
- Kept missing facts unknown instead of fabricating success or zero.
- Kept DONE parsing in the runner/state authority rather than the dashboard.
- Repaired the nonce marker newline contract after a worker proposed a contradictory test.
- Repaired scout root precedence and qualified plugin namespace isolation.
- Repaired the live rehearsal fixture to create real `SKILL.md` files.
- Repaired dashboard cleanup precedence to favor durable canonical telemetry.
- Repaired documentation drift for skill-kit bounds and the JSONL ledger path.
- Ran the five-case mock benchmark with zero adapter failures and no unknown metrics.
- Ran all three configured judges successfully with separate evidence.
- Finished with 1,171 passing assertions, zero failures, clean ShellCheck, a passing host GO/NO-GO rehearsal, and runner outcome GO.

## Observed operational costs

Cycle 9 took about 84 minutes, launched five worker turns, restarted twelve times, and reported roughly 58.8 million Codex input tokens. The largest avoidable costs were repeated full-suite terminal acceptances, user-profile plugin startup noise, and completion retries caused by a generated outcome ledger dirtying the integration worktree.
