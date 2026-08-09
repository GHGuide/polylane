# Cycle 16 integration — evidence-driven domain autonomy

## Merged tips and seams

The exact builder tips `c929c99` (`lane/c16-domain-runtime`), `a1c7622`
(`lane/c16-learning-economy`), and `3449e63` (`lane/c16-trials-soak`) are merged
ancestors of `lane/c16-integrator`; ancestry was verified. The graph snapshot was queried
for every changed helper and caller before source reading, then runner/scout/advanced
anchors were inspected directly. The durable inbox warning `message:98` was acknowledged
and repaired: `arm-recommendation` now rejects any candidate lacking both
`status: recommended` and `safe_to_apply: true`.

## Integration decisions

- The runner registers `domain_runtime` in per-run `.polylane/` scratch before pane
  creation. After integrator completion it re-bundles and profile-grades the exact
  integrator tree, appends the result to integration evidence, and commits the bundle,
  grade, and evidence on that branch before promotion.
- Typed discovery now has an explicit `after-cycle` materiality decision. `none`
  continues automatically; only deliverables, evidence, risk, or next-focus creates a
  new question. Existing typed deep paths remain profile-specific.
- Outcome learning writes a visible plan-gate record for every configured lane. Only a
  measured, available, builder-safe single model/effort change applies. Lane count and
  context remain planner-owned so scope/prompt proof cannot be mutated after validation.
  Promotion writes an accepted receipt without converting unknown telemetry into data.
- The provider entrypoints stay separate packages: root Claude shared core plus a thin
  native Codex overlay. Both describe adapters, graders, trials, canaries, learning,
  benchmarks, soak, action receipts, and truthful profile handoff.

## Adversarial review

Reviewed malformed JSON, jq/tool absence, locale-stable ordering, check-cache reuse,
atomic temp writes, duplicate ledger identities, concurrent benchmark writes, stale
receipt/payload mismatch, unsafe relative paths, profile/deliverable symlinks,
secret-shaped previews, command construction, timeout/cleanup behavior, thin-sample
confidence, Goodhart pressure, and false PASS/SKIP. Repairs reject profile
traversal/symlink evidence, preserve `SKIP` for network canaries, keep unknown
measurements out of the optimizer, and commit final runtime grader evidence before branch
promotion. The Ponytail review found no removable abstraction in
the small adapter boundary; `polylane-advanced.sh` remains the one runner adapter instead
of duplicating policy in the supervisor.

## Evidence

Fresh cached checks: domain runtime **76/0**, learning economy **57/0**, real-domain
trials **15/0**, soak **21/0**, cross-contract **29/0**, and agent adapter **49/0**.
Provider parity, isolated installers, whole-tree ShellCheck, marker validation, profile
validation, and seam scan are fresh: **57/0**, **50/0**, no warnings, and no scan output,
respectively. No live trade, deployment, publication, spend, contact, live canary, or
6-hour wait occurred.

The named verification, code-review, Ponytail, and documentation kits were not accessible
in this environment. Their stated verification/review/documentation intent was applied
directly and this limitation is recorded rather than substituted with a skill-inventory
search.
