# Verify — model policy

## RED → GREEN

The new tests first failed because `resolve_model_policy` and the Codex tier
publication did not exist. After the policy was wired into the runner:

```text
bash tests/test-model-policy.sh  # 14 pass, 0 fail
bash tests/test-intensity.sh     # 20 pass, 0 fail
bash tests/test-models.sh        # 21 pass, 0 fail
```

The behavioral coverage proves manifest intensity, CLI precedence, Claude and
Codex tier selection, one-model compression, ordinary-builder/highest-role
clamps, unsupported model/effort rejection, deterministic explanations, and
idempotent prime-hybrid compaction evidence.

## Effective-policy examples

Claude, manifest `intensity: balanced`, all four Claude tiers available:

```text
policy lane=builder role=builder source=manifest model=claude-sonnet-5 effort=high
policy lane=mechanical role=mechanical source=role-clamp model=claude-sonnet-5 effort=medium
policy lane=security role=security source=role-clamp model=claude-opus-4-8 effort=high
policy lane=integrator role=integrator source=role-clamp model=claude-fable-5 effort=xhigh
```

Codex, `--intensity performance`, luna/terra/sol available:

```text
policy lane=builder role=builder source=CLI override model=gpt-5.6-sol effort=high
policy lane=mechanical role=mechanical source=role-clamp model=gpt-5.6-terra effort=medium
policy lane=security role=security source=role-clamp model=gpt-5.6-terra effort=high
policy lane=integrator role=integrator source=role-clamp model=gpt-5.6-sol effort=xhigh
```

If only Terra is available, every Codex intensity resolves to Terra while its
effort still changes; roles then apply their ceilings and floors.

## Compatibility evidence

- With no manifest/CLI intensity and no `--model`, explicit per-lane manifest
  model/effort settings remain unchanged after validation.
- `--model` is still accepted after intensity, but unavailable/unknown IDs now
  fail before worktrees or panes exist; a role safety clamp remains authoritative.
- `refresh_manifest_runtime_settings` fingerprints intensity, availability, and
  role fields, then reuses the same resolver after a live manifest edit.
- Claude and Codex launch templates, existing model fallback, and pane recovery
  stay unchanged. `polylane-models.sh codex --tiers` exposes the supported
  Luna → Terra → Sol order without claiming cache-only unknown IDs are tiers.
- Repeated supervisor preparation for the same run id can rebuild packets but
  records one compaction observation, so it cannot inflate refinement evidence.

SKILL-EVIDENCE: superpowers:test-driven-development — unused: no resolved kit path was available; RED/GREEN tests are behavioral evidence, not kit-use evidence.

SKILL-EVIDENCE: superpowers:systematic-debugging — unused: no resolved kit path was available; the focused failure is recorded separately.

SKILL-EVIDENCE: engineering:system-design — unused: no resolved kit path was available; the single policy entrypoint is implementation evidence only.

SKILL-EVIDENCE: operations:process-optimization — unused: no resolved kit path was available; cache and idempotence behavior is separately tested.
