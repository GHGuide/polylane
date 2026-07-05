STATUS: planner-integration DONE

Lane: planner-integration — wire polylane PLANNER to emit runner-consumed outputs.
Owned/edited: SKILL.md, references/lane-template.md.

Done:
- SKILL.md Phase 6 → "Generate prompts + emit run manifest": emits .polylane/lanes/<lane>.txt per lane + .polylane/run.json (frozen L1 schema, key-for-key match). Done-signal baked into every generated prompt = docs/status-<lane>.md, first line `STATUS: <lane> DONE`.
- SKILL.md Phase 5 → default isolation = one worktree per lane; shared-index race cited (shared tree = one index → one lane's commit bundles another's staged files). shared-tree only on explicit opt-out.
- SKILL.md non-negotiables: added done-signal, worktree-default, manifest-emit lines.
- references/lane-template.md: launch line `cd "<WORKTREE_ABS_PATH>" && claude --model <MODEL_ID>`; manifest-emit section (mirrors Phase 6); DONE-SIGNAL in skeleton + mini-example + order readout; parallel-status narrowed to cross-lane requests.
- mandatory-4 preamble order unchanged. Frozen contract untouched.

Cross-consistency: SKILL.md ↔ lane-template.md agree on DONE marker, parallel-status role, worktree-default, manifest schema, preamble order. No contradiction.

Evidence: docs/verify-planner-integration.md (grep quotes for every claim).

NEEDS DECISION: none. Non-blocking note logged in verify doc for L1 — prompt-blocks.md (forbidden here) blocks H/J still name parallel-status.md as status/done; not a contract violation; parallel-status.md left unmodified (frozen audit trail).
