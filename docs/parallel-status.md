
## LANE: evals — evals/evals.json
- Status: DONE. Expanded evals.json into real trigger + behavior set.
- Added: 6 positive-trigger cases (one per SKILL.md description phrase), 5 hard-negative cases (run one agent / review my PR / install a skill / plain single build / "lanes" false-friend), 2 behavior cases (mandatory-4 preamble in order; never `git add -A`). Kept original 4 scenario cases.
- Schema: added `trigger_phrases`, per-case `class` + `should_fire`; documented in file `schema` block.
- Proof: docs/verify-evals.md (JSON-valid, 17 cases, all 6 triggers covered).
- NEEDS DECISION: none. All 6 description triggers present + covered; no missing trigger to escalate.

## LANE: derivation — references/lane-derivation.md, references/model-selection.md
- Status: DONE. Both files sharpened; frozen contract (IDs + effort tiers) unchanged.
- lane-derivation.md: rewrote the "N from file-overlap" rule into a concrete procedure — write-sets → overlap matrix → classify cells (INDEPENDENT/MERGE/CARVE/SEQUENCE) → connected components = Raw N → caps lower N. Added a full worked example (6 items → matrix → N=3 builders + integrator). Reader can compute N without guessing.
- model-selection.md: IDs + pricing confirmed CURRENT against the claude-api skill (Fable $10/$50, Opus $5/$25, Haiku $1/$5; IDs claude-fable-5 / claude-opus-4-8 / claude-haiku-4-5). No number/ID changed. Fixed: Haiku row now cites its ID (was the only row missing it); provenance note records the claude-api confirmation. Security→Opus rule + "never Fable on all lanes" preserved verbatim.
- Cross-consistency: lane-derivation has no IDs/tiers (can't contradict); model-selection IDs+tiers match SKILL.md. No contradiction.
- Proof: docs/verify-derivation.md (before/after quotes + claude-api facts).
- NEEDS DECISION: none. Contract intact; no model ID drift observed.
- FOR INTEGRATOR (transparency, non-destructive): commit f53b9e9 accidentally co-committed the workflow lane's already-staged, completed files (references/install-helpers.md, references/merge-and-cleanup.md, docs/verify-workflow.md) via the SHARED INDEX race — not edited by me, content is the workflow lane's own and unmodified (their status = DONE). Did NOT rewrite history (reset in a live shared tree would endanger other lanes' in-flight work). No content lost or altered. Re-verify HEADs as normal.

## LANE: process-docs — README + references/{install-helpers,merge-and-cleanup,skill-catalog}
Model: Opus 4.8, medium effort. Caveman: full.
OWN (edited): `references/install-helpers.md`, `references/merge-and-cleanup.md`, `references/skill-catalog.md`, `README.md`, `docs/verify-workflow.md`.

- Status: DONE.
- install-helpers.md: prose steps → runnable `cp`/`chmod` commands + `SKILL_DIR`/`PROJECT` vars. Traced verbatim (evidence docs/verify-workflow.md §1).
- merge-and-cleanup.md: added `INT=<integration-branch>` var → verify-before-remove `git log` now runnable; flow unambiguous + non-destructive.
- skill-catalog.md: verified accurate, recommend-never-auto-install rule intact → no edit (smallest-change).
- README.md: all feature/token claims traced to SKILL.md + model-selection.md, no contradiction → no edit.
- To Lane-1 (assets owner): NO ACTION. Asset names in install-helpers.md match real files exactly: `assets/q.py`, `assets/graphify-nudge.sh`, `assets/settings-hook-snippet.json`. No rename requested.
- For integrator: none. README consistent with current SKILL.md.
- NEEDS DECISION: none.

## LANE: prompt-gen — references/{prompt-blocks,lane-template,interview}.md
Model: Opus 4.8, high effort. Caveman: full.
OWN (edited): `references/prompt-blocks.md`, `references/lane-template.md`, `references/interview.md`, `docs/verify-prompt-gen.md`.

- Status: DONE. Mandatory-4 order + block labels A–J intact (frozen contract untouched).
- prompt-blocks.md: fixed block-A drift — garbled `LeLau-agnostic:` → `Project: <PROJECT one-liner>.` No other block changed. Block E q.py subcommands (`callers`/`uses`/`near`/`file` + default) verified against assets/q.py's real dispatch — exact match.
- lane-template.md: added a full filled mini-example (Vue todo `dark-theme` lane) — launch line + complete A→J paste block + order readout. A reader can assemble one prompt end to end. Skeleton A→J order unchanged.
- interview.md: added a worked batched round (3 lines → draft → one AskUserQuestion, recommended-first → re-present) + explicit re-present rule (version bump, `*` on changes). Spec-gate wording unchanged.
- To Lane-1 (assets/q.py owner): NO ACTION. Block E lists only real q.py subcommands; `community` deliberately omitted (niche, not in contract). No rename requested.
- Cross-file: A→J letter order identical in prompt-blocks.md ↔ lane-template.md; preamble order identical in prompt-blocks.md ↔ SKILL.md (cross-checked, not edited).
- Proof: docs/verify-prompt-gen.md (grep evidence for order, block E, drift fix, mini-example).
- NEEDS DECISION: none. No block letter or preamble step changed — no integrator escalation.

## LANE: graph-tooling — assets/{q.py, graphify-nudge.sh, settings-hook-snippet.json}
Model: Opus 4.8, high effort. Caveman: full.
OWN (edited): `assets/q.py`, `assets/graphify-nudge.sh`, `docs/verify-graph-tooling.md`. `assets/settings-hook-snippet.json` audited — already valid, no edit needed (smallest-change).

- Status: DONE. Frozen contract intact: subcommand names `q.py <symbol>` (default), `callers`, `uses`, `near`, `file` unchanged. `community` retained. Only flags ADDED (`--json`, `--graph`, `--cap`) — no rename/removal.
- q.py: hand-rolled argv → clean argparse (`--graph`/`--cap`/`--json` any position via REMAINDER). Fixed: file-handle leak (`with open`); missing graph.json now → stderr hint "run /graphify-auto (free)" + exit 1 (was raw traceback); callers/uses/near now print community per result (were omitting it); added `--json` structured output. All 5 subcommands + community return correct output on this repo's own AST graph (built free, 84 nodes).
- graphify-nudge.sh: `bash -n` clean, emits valid PreToolUse JSON when q.py present, silent + exit 0 otherwise. Tightened message to advertise `python3` + `--json` + community field (kept in sync with q.py).
- settings-hook-snippet.json: valid JSON; matcher `Grep|Glob` + command path match the nudge script. No change required.
- Proof: docs/verify-graph-tooling.md (TDD 21/21 + live per-subcommand output, exit-code, bash -n, JSON checks).
- To prompt-gen lane: NO ACTION. Block E's 4 names still exact-match q.py dispatch; `community` correctly omitted from Block E (contract lists 5; community is an extra I retained). No contract drift.
- NEEDS DECISION: none.
- FOR INTEGRATOR: `graphify-out/` is an untracked build artifact (AST graph for local verification) — do NOT commit it; not staged by this lane.

## LANE: engine — bin/polylane-run.sh (run 2026-07-08)
Model: Fable 5, high effort. Caveman: full.

- Status: DONE. Proof: docs/verify-engine.md. Contracts intact (CLI/DONE/report/manifest frozen; flags added are the two pre-approved additive ones: `--resume`, `--push`).
- FOR DOCS LANE (doc-sync, no decision needed): `.polylane/SCHEMA.md` is now stale in three cosmetic spots I may not edit — (1) CLI table lacks `--resume`/`--push`; (2) Environment line lacks `POLYLANE_HEALTH_INTERVAL`/`POLYLANE_MAX_RETRIES`/`POLYLANE_SESSION`; (3) "Pane command" example shows single-quoted interpolation, engine now emits `printf %q`-escaped (same semantics, quote-safe). `bin/polylane-run.sh --help` is the current source of truth.
- FOR INTEGRATOR: engine emits lane transcripts to `docs/lane-logs/<lane>.log` (kept by cleanup) and calls `bin/polylane-notify.sh <done|go|no-go|halt|stall>` only if executable — no-op until the notify lane lands.
- NEEDS DECISION: none.

## LANE: integration — SKILL.md, docs/verify-integration.md (runs last)
Model: Opus 4.8, XHIGH effort. Caveman: full.

- Status: DONE. **VERDICT: GO.**
- Re-merge: all 5 lanes on `main` (9fe1edb evals · f53b9e9 derivation+workflow · 1b7ac00 prompt-gen · 5e060ee graph-tooling). No lane branches / worktrees / stray dirs. **0 commits at risk.** Workflow-lane files rode in on f53b9e9 (shared-index race) — content verified unmodified + present. No history rewrite.
- Cross-checks (all quoted in docs/verify-integration.md, zero contradiction):
  - CC-0 mandatory-4 order: SKILL.md:36/:42 == prompt-blocks#0 == evals behavior case. MATCH.
  - CC-1 q.py subcommands: q.py:32 COMMANDS(callers/uses/near/file/community)+default == Block E (4+default, community omitted by design). MATCH.
  - CC-2 model IDs: model-selection (claude-fable-5/opus-4-8/haiku-4-5) consistent w/ SKILL "Fable 5 / Opus 4.8". MATCH.
  - CC-3 asset names: real assets/ == SKILL.md:23 == install-helpers, three-way exact. MATCH.
  - CC-4 trigger phrases: SKILL desc 6 == evals.json trigger_phrases 6, exact. MATCH.
  - CC-5 drift: `grep LeLau` CLEAN; block A opener clean. Fixed on HEAD.
- Smoke: evals.json VALID (17/6) · `bash -n graphify-nudge.sh` OK · `q.py load/callers/community` correct on graph@5e060eea. All pass.
- SKILL.md edit: NONE needed — zero cross-file inconsistency (smallest-change).
- Cleanup: no-op — nothing to worktree-remove / branch -d / quarantine. One folder remains.
- Env note: hit ENOSPC mid-run (disk full); user freed space; all verification re-confirmed. `graphify-out/` left untracked (never staged).
- NEEDS DECISION: none.

## integrator (max-upgrade round) — 2026-07-08
- FIX (logged before edit): `.polylane/SCHEMA.md` stale vs engine's merged runner (flagged by engine lane, left for integrator). 3 spots, minimal edits only:
  1. CLI synopsis + flag table: add `--resume`, `--push` (bin/polylane-run.sh:32,:128-129 are the source of truth).
  2. Environment line: add `POLYLANE_SESSION` (default `polylane`), `POLYLANE_HEALTH_INTERVAL` (300), `POLYLANE_MAX_RETRIES` (3) alongside `POLYLANE_POLL_INTERVAL` (15).
  3. Pane-command example: add the optional `POLYLANE_EFFORT=<effort>` prefix (emitted when the lane has `effort`; verified via --dry-run).
- No other files touched on main by integrator besides this log + SCHEMA.md; verdict + evidence land via lane/integrator merge.
