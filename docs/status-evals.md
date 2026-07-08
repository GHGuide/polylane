STATUS: evals DONE

- `evals/polylane.json` (23 cases), `evals/polylane-run.json` (22), `evals/polylane-auto.json` (26) — 71 cases total.
- All documented trigger phrases of all 3 skills covered ≥1 positive case each (frozen contract verbatim) + 8 paraphrase expected-fire cases.
- 24 hard negatives incl. 7 plan/run/auto disambiguation cases ("run the lanes" → polylane-run, "plan and run" → polylane-auto, "make lane prompts" → polylane).
- Behavior invariants covered: mandatory-4 preamble order, never `git add -A`/`git add .`, done marker first line exactly `STATUS: <lane> DONE`, runner --dry-run before launch, auto's required end-of-run chat report.
- Shared schema documented in `evals/README.md`; all files valid JSON.
- Evidence: `docs/verify-evals.md`.
