# Cycle 37 plan — falsifiable taste protocol

## Target

`m32.1`: synthesize primary research into a falsifiable visual-taste protocol and
threat model. This is a research/evidence cycle, not permission to claim that the
benchmark already passed.

## Frozen acceptance

The cycle is GO only when both
`docs/polylane/taste-certification/RESEARCH.md` and `PROTOCOL.md` exist; the research
traces claims to stable primary sources and human-rated UI data; and the protocol
mechanically specifies pointwise-before-pairwise judging, mirrored side order,
calibration/exclusion, accessibility vetoes, uncertainty, minimum corpus diversity,
and fail-closed evidence. Run the frozen `taste-research` acceptance entry for `m32.1`.

## Eight-way research carve

| Lane | Exclusive artifact | Question |
|---|---|---|
| hci-rubric | `research/hci-aesthetics.md` | validated dimensions and hard floors |
| human-corpus | `research/human-calibration-corpus.md` | open human labels, sampling, license |
| judge-science | `research/judge-reliability.md` | bias, calibration, exclusion, aggregation |
| visual-feedback | `research/visual-feedback-loops.md` | render-critique-repair evidence |
| design-practice | `research/design-practice.md` | elite critique and execution workflows |
| anti-homogenization | `research/anti-homogenization.md` | divergence, fixation, originality metrics |
| threat-model | `research/threat-model.md` | leakage, gaming, stale/fake artifacts, safety |
| red-team | `research/red-team.md` | falsification tests and counterexamples |

Each lane writes only its named research file, its verification file, and its status
marker. The integrator merges all eight tips, resolves disagreements, and exclusively
owns `RESEARCH.md`, `PROTOCOL.md`, cycle synthesis, INDEX/progress truth, and integration
evidence. Research lanes may read the initialized append-only Deep Research registry at
`/Users/leonardo/Documents/UI_Taste_Certification_Research_20260811`; they do not mutate it.

## Guardrails

- No invented human preference result and no fixture-only certification.
- No source cloning or trade-dress imitation; references contribute transformed patterns.
- No consequential external action, publication, install, or deployment.
- One finite protocol: divergent concepts, rendered candidates, and at most two targeted
  repairs. More repairs mean replan, not uncontrolled polishing.
- Implementation begins only after this protocol is frozen and committed.

## Integration check

The integrator verifies source diversity, primary-source coverage, explicit contradictory
evidence, operational thresholds, Bash-feasible data contracts, provider-neutral wording,
and the frozen `m32.1` acceptance command. It ends with GO only for the research target;
`m32.2` through `m32.5` and `c84` through `c90` remain open.
