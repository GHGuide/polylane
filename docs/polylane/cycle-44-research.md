# Cycle 44 research — what the frozen registry told us to build

No external research; the material was the contract cycle 43 froze.

1. **A frozen defect registry is executable planning.** Each entry carried an
   `affected_boundary`, a `required_v3_control`, and a disposition naming what it
   blocks. That is enough to derive acceptance mechanically — one focused check
   per control — without a coordinator inventing success criteria.
2. **"Repaired AND regression-tested" is a two-part obligation.** Every
   disposition demanded both. Making the tests part of the frozen acceptance,
   named before any builder existed, is what stops a lane from declaring a
   control satisfied by inspection.
3. **Statistical honesty is a code property, not a policy.** The comparator
   defect (`pseudo-win`) is the clearest case: silently dropping a non-win from
   the denominator inflates a win rate while every individual step looks
   reasonable. The control had to be enforced where the tally happens.
4. **Provenance needs both ends.** The stdin defect required delivered *and*
   consumed hashes plus byte counts, bound by receipts — either half alone
   proves nothing about what the model actually read.
