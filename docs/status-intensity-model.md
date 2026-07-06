STATUS: intensity-model DONE

Lane: intensity-model — price-sensitivity intensity presets for the polylane skill.

Owned file edited: `references/model-selection.md`.

Delivered:
- INTENSITY PRESETS table — frozen names `economy | balanced | performance | max | custom`, each → {model-rank, effort, caveman-level}.
- Capability/price RANK MAP — `claude-fable-5` > `claude-opus-4-8` > `claude-sonnet-5` > `claude-haiku-4-5`; price mirrors capability.
- RESOLUTION RULE — economy=cheapest available, max=most capable available, balanced=mid, performance=best agentic non-Fable; unknown probed model → planner asks user to place it. Presets pick by RANK within `available_models`, never a hardcoded ID.
- Old rules reconciled — assignment table + "security→Opus" + "never Fable on all lanes" kept intact; new Precedence ladder states intensity = round DEFAULT, per-lane role adjustments + hard rules clamp, per-lane user override final.

Contract frozen for downstream lanes: preset names EXACTLY `economy | balanced | performance | max | custom`.

Evidence: `docs/verify-intensity-model.md` (quotes presets table + rank map + worked example available=[opus,haiku]/economy).

No FORBIDDEN files touched. No cross-lane decisions needed — contract self-defined.
