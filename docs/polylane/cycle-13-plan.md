# Cycle 13 plan — policy, skill intelligence, prompt quality, lifecycle truth

## Locked outcome

Improve every Polylane layer through a measured whole-system pass without weakening the
existing frozen gates. Cycle 13 implements the 18 selected candidates in
`cycle-13-suggestions.md`; lower-confidence and external items remain explicit.

## Integration spec

1. Make intensity/model/effort one manifest-authoritative, CLI-overridable, agent-aware policy with role clamps and a pre-launch explanation.
2. Build a metadata-indexed, evidence-ranked skill scout with exact lane reasons and safe authorized acquisition for real gaps.
3. Compile smaller contradiction-free builder prompts and report conservative token estimates instead of word counts.
4. Add project-scoped Claude/Codex lifecycle guards that restore compact goal context and reject dishonest completion without replacing the supervisor.
5. Add a named whole-system certification matrix and a hermetic vague-brief-to-next-cycle journey for both agent manifests.

## Lane carve

| Lane | Owns | Excludes | Frozen evidence |
|---|---|---|---|
| `model-policy` | model/policy runner logic and policy tests | scout, prompt compiler, hooks/docs | manifest intensity, agent tiers, role clamps, unsupported combinations |
| `skill-intelligence` | scout/catalog/acquisition helpers and tests | runner, prompt compiler, hooks/docs | metadata relevance, explanations, outcome ranking, safe admission |
| `prompt-compiler` | prompt optimizer/linter/compiler and tests | runner, scout, hooks/docs | conservative estimate, dedupe/conflict checks, frozen comparisons |
| `lifecycle-hooks` | portable hook helper/assets and tests | runner, scout, prompt compiler/docs | compact restore, stop truth, Claude/Codex semantic parity |
| `integrator` | cross-lane wiring, shared skill/docs/install parity, certification | builder-owned implementation except cross-lane repair | full suite, ShellCheck, fresh installs, GO+NO-GO rehearsal |

Intensity is `balanced`, selected autonomously because this is a correctness-heavy known
Bash codebase: builders run high effort on the only locally available Codex model; the
integrator runs xhigh. The policy lane must make this a real manifest-driven choice rather
than preserving that limitation.
