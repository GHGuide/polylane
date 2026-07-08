# verify-planner-skill — evidence

Lane: planner-skill. Scope: SKILL.md + references/** (8 files). Ground truth checked against `bin/polylane-run.sh`, `polylane-run/SKILL.md`, `polylane-auto/SKILL.md`, `.polylane/SCHEMA.md`, `assets/q.py`, and the claude-api skill (read-only — none edited).

## 1. Consistency sweep — every inconsistency found → fixed

| # | Inconsistency (stale/contradictory claim) | Was at | Fixed at (current) |
|---|---|---|---|
| 1 | `merge-and-cleanup.md` claimed cleanup runs `git worktree prune` — the runner has no such call (`grep -n prune bin/polylane-run.sh` → no cleanup hit) | merge-and-cleanup.md step 4 | removed; step 4 now lists exactly what the runner removes (`.polylane/`, `docs/status-*.md`) — merge-and-cleanup.md:52-55 |
| 2 | Cleanup keep-list omitted `docs/polylane-report.md` + `docs/lane-logs/` (runner line 592 keeps the report; lane-logs kept per current engine behavior) | merge-and-cleanup.md step 5 | keep-list now: verify-*, parallel-status, polylane-report, lane-logs — merge-and-cleanup.md:57-66 |
| 3 | Step 6 "Report" said the runner only *prints* a summary — it now WRITES `docs/polylane-report.md` on both GO and NO-GO (runner `write_report()`, lines 614-726) | merge-and-cleanup.md step 6 | documented — merge-and-cleanup.md:68-69 |
| 4 | No mention of `POLYLANE_SESSION` (runner line 66-67), `POLYLANE_POLL_INTERVAL`, or the health-check auto-retry env vars (runner lines 59-62, 387-468) anywhere in my files | merge-and-cleanup.md runner section | env-var list added — merge-and-cleanup.md:16-21; install-helpers.md:46-50; interview.md:43 |
| 5 | Safety never-`rm` list didn't cover the new kept files | merge-and-cleanup.md safety rules | extended — merge-and-cleanup.md:74 |
| 6 | `lane-derivation.md` "Isolation mode" said *ask* the user (shared tree listed first, worktrees only "recommended for ≥3 lanes") — contradicted SKILL.md Phase 5 "Default isolation = one git worktree per lane; shared-tree only on explicit opt-out" | lane-derivation.md:73-77 (old) | rewritten to worktree-per-lane default + shared-index-race rationale + opt-out-only fallback — lane-derivation.md:76-82 |
| 7 | `prompt-blocks.md` block H told lanes to "Append your lane's status to docs/parallel-status.md: what changed, what's now stable…" — contradicted SKILL.md:40/91 and lane-template.md:26/101 ("cross-lane requests + NEEDS DECISION only, never a general status log, never the done signal"). Blocks are declared verbatim (lane-template.md:3), so the block and the filled example also disagreed with each other | prompt-blocks.md:63 (old) | block H = requests-only wording, matching SKILL.md and the lane-template example — prompt-blocks.md:62-64 |
| 8 | Block J required "parallel-status.md updated" in DONE — contradicted the done-signal design (docs/status-<lane>.md) and the lane-template example's own J | prompt-blocks.md:73 (old) | block J now requires verify proof + `docs/status-<lane>.md` first line `STATUS: <lane> DONE` — prompt-blocks.md:72-74 |
| 9 | Block I rationale "(other Claudes have uncommitted work in this tree)" assumed the shared tree — stale under the worktree-per-lane default; also diverged from the lane-template example's verbatim copy | prompt-blocks.md:68 (old) | rationale now "(scope every add to your own paths; on a shared tree you'd sweep other lanes' staged work)"; lane-template example synced verbatim — prompt-blocks.md:67-69, lane-template.md:103 |
| 10 | Integrator compose line hardcoded "B(Opus 4.8 xhigh)" — contradicts model-selection.md's rank-based clamp ("top non-Fable available") on restricted model sets | prompt-blocks.md:77 (old) | "B(top non-Fable available, xhigh — the integrator role clamp in model-selection.md)" — prompt-blocks.md:77 |
| 11 | `lane-template.md` launch note limited `<MODEL_ID>` to "claude-fable-5 or claude-opus-4-8" — stale vs the 4-model rank map (economy resolves to Haiku, mid to Sonnet) | lane-template.md:9 (old) | all four rank-map ids listed — lane-template.md:9 |
| 12 | Same note claimed "there is no verifiable CLI effort flag" with no mention that the runner exports `POLYLANE_EFFORT` to the pane (SCHEMA.md `effort` row; runner lines 334-339) | lane-template.md:9 (old) | POLYLANE_EFFORT surfacing documented — lane-template.md:9 |
| 13 | SKILL.md:29 described the rank map as "Fable 5 vs Opus 4.8" and frontmatter said "(Fable/Opus)" — stale vs the 4-model map | SKILL.md:3, :29 (old) | "(Fable/Opus/Sonnet/Haiku)" + "Fable 5 / Opus 4.8 / Sonnet 5 / Haiku 4.5" — SKILL.md:3, :31 |
| 14 | Caveman level: model-selection.md says intensity sets the level (ultra under economy) but SKILL.md Phase 6 and prompt-blocks block 0 hardcoded "(full)" with no reconciliation | SKILL.md:36, prompt-blocks.md:5-14 (old) | both now state: step fixed, LEVEL follows intensity (ultra under economy, full otherwise); mandatory-4 wording/order untouched — SKILL.md:38, prompt-blocks.md:14 |
| 15 | model-selection.md:3 said verify pricing "ONLY if the user asks for costs" — contradicts the new REQUIRED Phase 5 cost row | model-selection.md:3 (old) | table declared canonical, feeds the required cost row; re-verify only on doubt/new model — model-selection.md:3 |
| 16 | SKILL.md Phase 7 didn't state what cleanup keeps (report/lane-logs) nor that the runner auto-retries stuck lanes — those behaviors exist (runner report + health check) | SKILL.md:76 (old) | keeps-list + auto-retry note added — SKILL.md:78 |

Post-fix sweep (fresh, this session): `grep -rn "worktree prune|only if the user asks|other Claudes have uncommitted work|Fable 5 or claude-opus|(Fable 5 vs Opus|Append your lane's status" SKILL.md references/` → **no matches**. All remaining `parallel-status` mentions are requests/contract/conflict-resolution contexts (consistent). skill-catalog.md read end-to-end: no stale claims, unchanged.

Frozen-contract integrity (fresh greps): mandatory-4 order present verbatim (SKILL.md:38,:81; prompt-blocks.md:8-13; lane-template.md:15) · manifest schema keys unchanged (base/intensity/available_models/integrator{name,model,effort,branch,worktree,prompt_file}/lanes+own_globs — SKILL.md:48-73, lane-template.md:37-47) · DONE marker `STATUS: <lane> DONE` in 6 places, unchanged · model IDs claude-fable-5/claude-opus-4-8/claude-haiku-4-5 (+ sonnet-5) intact · q.py subcommands (search/file/community/callers/uses/near, confirmed against assets/q.py) unchanged in block E + install-helpers.

## 2. Phase 5 cost-estimate row — new SKILL.md text (quoted)

> **Cost-estimate row — REQUIRED.** The table MUST include a per-lane cost estimate plus a **TOTAL** row, so the user sees the dollars before approving: tokens-guess × the lane's resolved-model rates from the `references/model-selection.md` price table (that table is canonical for costs), computed per its "Cost-per-lane estimation" formula, and always labelled **rough** (±2× is normal). Never present the plan gate without it.

(SKILL.md:35; lane-table columns now include **est. cost** — SKILL.md:33; new Non-negotiables bullet — SKILL.md:90.)

## 3. Price-table verification note

Verified 2026-07-08 against the claude-api skill (its model table, cached 2026-06-24):

| Model | claude-api skill | model-selection.md | Match |
|---|---|---|---|
| claude-fable-5 | $10.00 / $50.00 | $10/$50 | ✓ |
| claude-opus-4-8 | $5.00 / $25.00 | $5/$25 | ✓ |
| claude-sonnet-5 | $3.00 / $15.00 (intro $2/$10 through 2026-08-31) | $3/$15 + intro footnote added | ✓ |
| claude-haiku-4-5 | $1.00 / $5.00 | $1/$5 | ✓ |

No rate changes needed; added the Sonnet 5 intro-pricing footnote (model-selection.md:12) and the verified-date note (model-selection.md:3). New section "Cost-per-lane estimation (feeds the Phase 5 plan gate — REQUIRED)" with formula, token-guess table, worked example ($97-rough for 3 lanes + integrator on balanced), and subscription-proxy note — model-selection.md:37-66.

## 4. Interview + derivation upgrades (lessons from real runs)

- Orphan protection: interview.md:46 (early heads-up) + lane-derivation.md:79 (precondition before worktree ops); SKILL.md Phase 3 already had it.
- tmux session collision question (`POLYLANE_SESSION`): interview.md:43.
- Disk-space check (`df -h .`, (N+1) checkouts): interview.md:44 + lane-derivation.md:31 (new Step-2 cap) + lane-derivation.md:80.
- Usage-limit warning for all-Fable/`max` runs: interview.md:31 (delivered inside the intensity question) + interview.md:45.

## Commits (this worktree)

- 79d531b docs(planner): Phase 5 cost row, verified price table + cost formula, cleanup keeps report/lane-logs
- 0903bce docs(planner): fold real-run lessons + fix cross-file drift in references
- (final commit adds this file + status)
