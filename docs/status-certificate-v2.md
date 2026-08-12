STATUS: certificate-v2 DONE run=c39-visual-loop-20260812-a1

Production taste-certificate compiler shipped. `bin/polylane-taste.sh certify`
dispatches on manifest schema: v1 stays compatible but is permanently
fixture-marked (`fixture_only:true, production:false`) so shape-only evidence
can never satisfy a current runner gate; `taste-evidence-manifest/v2` compiles a
deterministic `taste-certificate/v2` that recomputes every artifact SHA-256,
binds each validator receipt to its exact raw input (subset validation per the
receipt-producers relay contract, including the newline-inclusive canonical
stats byte rule resolved by the coordinator), requires subject-revision
ancestry with only declared evidence commits after it, enforces escrowed judge
provenance, alias/independence/diversity, 10-brief variety, 5-group quorums,
the 7-of-10 win floor with recorded losses, group-level preference >=0.70 and
Wilson LCB >0.50, accessibility/task/state/threat vetoes, the two-repair
budget, and honest claim-ladder labels. Cycle-39 producer ballots
(taste-ballot-validation/v1, fixture_only:true) always emit FIXTURE_EVIDENCE,
so no production certificate can be minted this cycle by design.

Verification: tests/test-taste-certification.sh PASS (hermetic hash-closed
chains + 24 adversarial mutations), shellcheck -S warning clean, git diff
--check clean; evidence in docs/verify-certificate-v2.md (v1/v2 authority
table, chain diagram, threshold cases, skill evidence, DEFERRED items for
integrator-owned hard-gate mapping, unassigned review/repair producers, and
optional capture authorization binding).

Commits: a9e0784 (compiler + tests), c8bdaa2 (verification evidence),
0a9e3ac (canonical-ballots byte rule).
