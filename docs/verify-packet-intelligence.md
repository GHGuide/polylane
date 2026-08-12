# Verify — packet-intelligence (Cycle 39, run c39-visual-loop-20260812-a1)

Lane owns: `bin/polylane-visual.sh`, `tests/test-visual-intelligence.sh`,
`docs/verify-packet-intelligence.md`, `docs/status-packet-intelligence.md`.

Goal: turn the UI reference packet + design lock into versioned, goal-bound
inputs that force genuinely divergent rendered candidates. This lane is
**pre-render planning only** — it never marks a candidate a winner, never claims
visual quality or champion status, and never touches external sites.

## Commands and outputs

- `bash tests/test-visual-intelligence.sh` → `39 pass, 0 fail`
  (9 legacy schema-1 assertions + 30 new schema-2 assertions).
- `shellcheck -S warning bin/polylane-visual.sh` → clean.
- `shellcheck -S warning tests/test-visual-intelligence.sh` → clean.
- `git diff --check` → clean.

## Schema migration evidence (schema-1 preserved, schema-2 added)

The new versioned path is **additive**. `detect`, schema-1 `prepare`, and
schema-1 `validate` are untouched; dispatch branches on the packet's `.schema`:

- `packet_schema()` reads `.schema`; `validate_packet`/`prepare_packet` route
  `schema==2` to the v2 handlers and otherwise fall through to the original
  schema-1 body verbatim. Legacy fixtures (`winner` selected by council,
  `DESIGN-DECISION.md`) keep passing — proven by the retained schema-1 tests
  (`visual-prepares-durable-reference-packet`, `visual-reference-packet-is-valid`,
  `visual-rejects-dominant-reference-source`, `visual-rejects-unfrozen-design-decision`).

Schema-2 binds a content-addressed chain (fixed canonicalization so external
producers and this validator agree):

- text leaf → `sha256(exact bytes, no trailing newline)` (`jq -j`);
- object/array → `sha256(compact, sorted keys, no newline)` (`jq -cS | tr -d '\n'`).

Cross-checked: a Python `json.dumps(sort_keys=True, separators=(',',':'))`
packet verifies clean through the jq-based `verify_packet_hashes`, confirming the
two canonicalizations are byte-identical.

Bound fields (schema-2):

- literal goal + subgoal and their SHA-256; audience, product, domain, task;
- per-source access date, provenance, product-fit, observed screens/states, the
  seven design dimensions, borrow/transform/avoid, and **local** desktop+mobile
  screenshot files with recorded SHA-256 (URLs/prose alone are rejected);
- one immutable `design_lock_sha256` over the full lock, which itself exposes
  explicit color/type/spacing/radius/elevation/interaction tokens, responsive
  hierarchy, reduced motion, asset/copy intent, signature, anti-goals,
  `goal_hash`, and `source_packet_hash`.

Emitted deterministic artifacts on `prepare` (schema-2):

- `docs/polylane/design/references.json` — installed packet;
- `DESIGN-LOCK.json` — frozen canonical lock (validate re-derives its hash and
  requires equality with the packet `design_lock_sha256`);
- `TOURNAMENT-INPUT.json` — three **opaque** candidate slots bound 1:1 to the
  three directions, `status:"unrendered"`, `winner:false`, top-level `winner:null`,
  required capture states `[desktop,mobile,empty,loading,error,hover,focus,flow]`;
- `VISUAL-BRIEF.md` — human summary (goal, locked direction, per-source intent).

Directions must be genuinely divergent: exactly three, each with product thesis,
source synthesis, token system, layout model, motion model, signature moment,
anti-goals, risk, audience fit, and a distinct candidate slot. Rejected when two
share the normalized `(signature_moment, token_system, layout_model)` tuple or
when one reference dominates all three directions.

## Negative matrix (all reject; each verified as an assertion)

| Case | Assertion | Guard |
|---|---|---|
| winner set before render | `v2-rejects-winner-before-render` | `.winner != null` |
| unknown/injected key | `v2-rejects-unknown-key` | per-object `okkeys` allow-list |
| goal hash ≠ text | `v2-rejects-bad-goal-hash` | hex64 + `verify_packet_hashes` |
| lock goal_hash drift | `v2-rejects-goal-drift-in-lock` | `goal_hash == ultimate_goal_sha256` |
| malformed hash | `v2-rejects-malformed-hash` | `^[0-9a-f]{64}$` |
| tampered source-packet hash | `v2-rejects-tampered-source-hash` | recompute `.references` hash |
| prompt-injection in field | `v2-rejects-injection-in-field` | `noinject` (`$(`, backtick, `${`, CR/LF) |
| absolute screenshot path | `v2-rejects-absolute-screenshot` | `relpath` |
| traversal screenshot path | `v2-rejects-traversal-screenshot` | `relpath` |
| duplicate direction id | `v2-rejects-duplicate-direction-id` | unique ids |
| non-divergent directions | `v2-rejects-nondivergent-directions` | normalized tuple uniqueness |
| one reference dominates all | `v2-rejects-dominant-reference` | per-source dominance bound |
| missing adjacent wildcard | `v2-rejects-missing-wildcard` | exactly one `kind=="wildcard"` |
| stale/malformed access date | `v2-rejects-stale-access-date` | ISO `YYYY-MM-DD` |
| tampered immutable lock hash | `v2-rejects-tampered-lock-hash` | recompute `.design_lock` hash |
| duplicate image bytes (2 refs) | `v2-rejects-duplicate-image-bytes` | screenshot-hash set uniqueness |
| stale screenshot bytes | `v2-rejects-stale-screenshot-bytes` | file byte hash == recorded |
| symlinked screenshot | `v2-rejects-symlinked-screenshot` | reject `-L` targets |
| unfrozen DESIGN-LOCK.json | `v2-rejects-unfrozen-design-lock` | frozen lock hash equality |

Reference-shape rules were additionally checked to reject **independently of**
the hash chain (re-hashed mutants still `REJECT` under `valid_packet_shape_v2`),
so a rule is never masked by a downstream hash mismatch.

Known ceiling (`ponytail:`): literal duplicate JSON keys in raw bytes are not
detected — jq (and every JSON parser) collapses them last-wins before validation.
Duplicate **ids/slots** (the meaningful vector) are rejected. Upgrade path: a
`jq --stream` key-path duplicate scan if a raw-bytes vector is ever demonstrated.

## External evidence boundary

This lane implements planning gates over deterministic fixtures only. It does not
browse or capture any live site, does not render candidates, and does not run a
blind tournament. Real rendered candidates, live screenshots, blind A/B judging,
Condorcet selection, and champion certification remain later integration/render
gates and cannot be replaced by these fixtures. Missing external reference access
stays explicit and cannot pass the current packet gate.

## SKILL-EVIDENCE

- SKILL-READ: design:design-system | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/design-system/SKILL.md | 1682758151-5600
- SKILL-READ: design:research-synthesis | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/research-synthesis/SKILL.md | 335799056-3014
- SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
- SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

- SKILL-EVIDENCE: superpowers:test-driven-development — helped: wrote the 30 schema-2
  assertions first and ran them RED (10 fails: positive prepare/validate/emit
  cases) before any implementation; the Iron Law caught that my early
  reference-mutation negatives could be masked by the hash chain, prompting the
  independent `valid_packet_shape_v2`-only re-check.
- SKILL-EVIDENCE: design:design-system — helped: its token taxonomy
  (color/type/spacing/borders(radius)/shadows(elevation)/motion + interaction/a11y)
  is exactly the set the design lock now forces as explicit non-empty tokens,
  and drove the reduced-motion + responsive-hierarchy lock fields.
- SKILL-EVIDENCE: design:research-synthesis — helped: its evidence-with-provenance
  discipline (quote/participant/date + implication) shaped the mandatory per-source
  record — observed screens/states, access date, provenance, product-fit reason,
  and borrow/transform/avoid — so a source is a capture, never prose.
- SKILL-EVIDENCE: engineering:debug — helped: reproduce→isolate→diagnose framing
  was used to trace the stale-screenshot and duplicate-bytes cases to a single
  root guard (recorded-hash vs. file-byte-hash, and global screenshot-hash set
  uniqueness) rather than per-caller symptom patches.

## DEFERRED
DEFERRED: none
