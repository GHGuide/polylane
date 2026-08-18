# Cycle 40 per-lane skill recommendations

The scout ran after the lane carve. Only installed, locally readable skills are armed;
no external skill is installed or trusted during this cycle. `None` remains valid, but
the autonomous recommended defaults below map to concrete lane work and are frozen in
`.polylane/lane-skills.json`.

| Lane | Armed installed skills | Why they materially help |
|---|---|---|
| `source-live` | `deep-research`, `data:validate-data`, `legal:compliance-check` | Verify primary provenance/licence, join raw and aggregate labels, and keep source substitution explicit. |
| `calibration-live` | `data:statistical-analysis`, `engineering:testing-strategy` | Check split/holdout statistics and adversarially test eligibility thresholds and bindings. |
| `judge-claude` | `engineering:system-design`, `engineering:testing-strategy` | Design a narrow provider adapter and exercise timeout, malformed output, and provenance failures. |
| `judge-codex` | `engineering:system-design`, `engineering:testing-strategy` | Preserve Codex-native invocation semantics while meeting the same provider-neutral receipt contract. |
| `judge-runner` | `engineering:architecture`, `operations:risk-assessment` | Keep isolation/retry/idempotency boundaries explicit and fail closed under partial campaigns. |
| `ballot-live` | `engineering:code-review`, `engineering:testing-strategy` | Audit every trust seam and derive rather than accept winner/eligibility fields. |
| `browser-live` | `engineering:debug`, `engineering:testing-strategy` | Make real-browser state replay deterministic and diagnose missing/stale/wrong-viewport evidence. |
| `decode-live` | `engineering:code-review`, `caveman:surgical-patch` | Keep the decoder minimal while testing malformed headers, payloads, dimensions, and digest drift. |
| `a11y-live` | `design:accessibility-review`, `engineering:testing-strategy` | Translate the accessibility floor into executable evidence without treating automation as universal coverage. |
| `task-live` | `engineering:testing-strategy`, `product-management:write-spec` | Turn each brief's observable task into exact action/state assertions and hard-gate receipts. |
| `corpus-20` | `product-management:product-brainstorming`, `product-management:write-spec`, `design:user-research` | Produce varied, realistic briefs with distinct audiences/tasks rather than twenty cosmetic prompt variants. |
| `prompts-live` | `design:design-system`, `design:ux-copy`, `humanizer` | Preserve product specificity, typography/system reasoning, and non-generic interface language in frozen prompts. |
| `generate-live` | `sites:sites-building`, `engineering:deploy-checklist`, `ponytail:ponytail` | Build functional offline pages, validate runnable output, and avoid ornamental over-engineering. |
| `study-live` | `engineering:architecture`, `engineering:code-review`, `operations:risk-assessment` | Close cross-module evidence/ancestry seams and attack false-positive certification paths. |
| `protocol-live` | `deep-research`, `engineering:documentation`, `legal:compliance-check` | Keep claims, reproduction, dataset rights, and external limitations accurate after implementation. |
| `taste-live-integrator` | `engineering:code-review`, `engineering:testing-strategy`, `ponytail:ponytail-review`, `operations:risk-assessment` | Merge by trust boundary, run the adversarial matrix, and remove needless machinery without weakening evidence. |

Cycle-level base skills remain the shared Graphify/caveman/ponytail context tools already
covered by the global prompt block; they are not redundantly suggested per lane.
