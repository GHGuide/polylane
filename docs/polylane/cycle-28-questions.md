# Cycle 28 emergent questions

These questions refine future policy but do not block the safe Cycle 29 route.

1. How should a long active command affect the material-progress budget?
   - Recommended: pause the churn counter until every structured command ID settles.
   - Alternative: reset the counter on each active-command observation.
   - Deeper next round: model nested and overlapping command timelines explicitly.
2. What should happen after an exact current-run DONE commit violates lane scope?
   - Recommended: fail once with exact paths and preserve the worktree.
   - Alternative: allow one non-model planner repair before failure.
   - Deeper next round: design transactional ownership expansion with a new nonce.
3. How strict should planned write-sets be for exploratory projects?
   - Recommended: exact expected paths plus broader `own_globs` where discovery is legitimate.
   - Alternative: require only exact paths and force a re-plan for every discovery.
   - Deeper next round: derive paths from a repository graph and compare plan recall.
4. How long may an xhigh live turn stay quiet?
   - Recommended: one-hour default with an explicit finite multi-hour hard ceiling.
   - Alternative: two-hour default for all xhigh work.
   - Deeper next round: learn the percentile from accepted historical lane outcomes.
5. Should Cycle 28's late worker tip count as completion evidence?
   - Recommended: no; use it only as Cycle 29 source and re-verify independently.
   - Alternative: salvage individual commits without status changes.
   - Deeper next round: formalize a signed salvage receipt separate from run verdicts.

