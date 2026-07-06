STATUS: planner-wiring DONE

Lane: planner-wiring — intensity + model detection wired into the planner.
Model: claude-opus-4-8, HIGH effort. Caveman: full.

OWN (edited): SKILL.md, references/interview.md, references/lane-template.md.
  references/lane-derivation.md — owned but unchanged (unrelated to intensity/models; smallest-change).

Delivered (all 6 goal items):
1. interview.md + SKILL.md Phase 1 — ONE intensity question (economy|balanced|performance|max|custom, balanced recommended) + optional "which models do you have" step + default probe path (assume model-selection.md trio).
2. SKILL.md Phase 4 — resolve per-lane model+effort from the intensity preset against available_models via model-selection.md rank map; graceful degrade; custom = per-lane at gate.
3. SKILL.md Phase 5 — table shows preset-resolved model+effort; user may override ANY single lane (bump/drop) before approval.
4. SKILL.md Phase 6 — manifest emits global `intensity` + `available_models[]` + per-object `effort` (lanes + integrator), matching Lc's .polylane/SCHEMA.md. JSON validated.
5. lane-template.md — model/effort provenance = resolved preset; embedded manifest JSON carries the new keys.
6. Consistency — preset names + manifest keys identical across touched files; mandatory-4 preamble order + A→J block order intact.

Contract honored: presets + keys exactly as frozen by La/Lc. model-selection.md (La) referenced not edited. No FORBIDDEN file touched.

Proof: docs/verify-planner-wiring.md.
NEEDS DECISION: none.
