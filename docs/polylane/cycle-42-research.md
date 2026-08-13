# Cycle 42A research lock — human-calibrated machine taste certification

Run: `c42a-taste-contracts-20260813-a1`

This lock synthesizes the independent research, architecture, provenance, source,
statistics, UI-contract, prompt-optimizer, and lifecycle audits completed after Cycle
41. Implementation may make the contracts stricter, but may not lower these bars after
observing benchmark outcomes.

## Evidence model

Visual preference is empirical and stochastic. A self-authored rubric, one model's
opinion, or a prose design critique can guide repairs but cannot certify taste. The
production claim is therefore bounded to a machine panel calibrated on openly licensed
human-rated website examples. The machine label is `HUMAN_CALIBRATED_MACHINE`; it is
never presented as a recruited-human verdict.

Every artifact participates in a typed evidence DAG. Nodes bind schema version,
producer, exact input digests, output digest, execution configuration, revision, and
evidence grade. Edges are verified before claims are evaluated. The effective grade is
the minimum trust over every ancestor; fixture evidence is absorbing. A missing,
unknown, stale, cyclic, schema-mismatched, or unregistered ancestor makes the claim
ineligible rather than `PASS`.

## Statistical lock

The development benchmark contains exactly 20 independent product briefs and exactly
20 binary sample units. Ties and abstentions are not silently dropped or replaced: any
one makes the study ineligible. Certification requires at least 15 wins, Wilson 95%
lower bound above 0.50, and an exact two-sided sign-test p-value at most 0.05. At 15/20,
the expected Wilson lower bound is approximately 0.531299 and the exact p-value is
approximately 0.041389. Mirrored left/right renderings are repeated measurements used
for side-bias vetoes, not extra independent samples.

The panel needs at least five distinct immutable configuration fingerprints across at
least two provider families. Each configuration must independently pass the frozen
24-pair held-out calibration, pointwise-before-pairwise ordering, mirror-consistency,
side-bias, parser, provenance, and contamination checks. Provider labels alone do not
prove independence.

## Source lock

The pinned Miniukovich–Figl source contains 3,180 files, including 3,156 JPEG website
screenshots and three instruction PNGs. The four normalized human-rating domains yield
1,555 eligible records after compliant-session filtering: fashion 262, homeware 443,
universities 340, and banks 510. Every normalized record currently joins exactly once
to source metadata by source plus stimulus filename.

Stage A is metadata-only: pin dataset/version/file id/name/size/checksum, normalize
ratings with a receipt binding the raw file and compliant-session list, reserve 60
calibration images per domain, reserve eight disjoint qualifying pair endpoints per
domain, then add eight deterministic unused holdout images per domain. It emits an
exact 252-object download plan. Stable ranking uses immutable dataset/version/file ids,
not a local image hash unavailable before acquisition. Duplicate size/checksum content
is resolved before split; the known banks b889/b952 duplicate keeps the higher-support
b952 record.

Stage B downloads only those 252 identities into the content-addressed local cache,
checks declared size and upstream checksum, computes local SHA-256, rejects challenge
HTML/partial files/symlinks/traversal, and finalizes the corpus manifest. The full raw
source is about 2.47 GB; the selected corpus is estimated near 200 MB and is the only
binary acquisition authorized by this plan.

## Execution and prompt lock

The exact prompt bytes delivered on stdin must be hashed into the request receipt. The
request receipt binds model, effort, sandbox/profile, revision, brief, contract lock,
direction lock, input assets, and output tree. Capture receipts bind real browser pixels
and DOM/state evidence to that build. Judge receipts bind blinded stimuli to calibrated
configuration fingerprints. No filename, environment variable, or fake CLI is accepted
as proof that those bytes were consumed.

Prompt optimization is a later equal-compute tournament, not global line deduplication.
The incumbent and challenger receive identical model, effort, capabilities, briefs,
repair cap, and evidence gate. Four development briefs plus two sealed holdouts require
at least 3/4 and 2/2 wins respectively with zero hard-gate regressions. The optimizer's
maximum label is `PROMPT_OPTIMIZER_SELECTED_NOT_CERTIFIED`.

## Resource and campaign lock

The host audit measured 20,203,438,080 bytes free. The frozen worst-case campaign
budget is 18,135,637,039 bytes: 12,230,057,007 bytes retained, 536,870,912 bytes active
staging, and a 5 GiB safety floor. This leaves about 1.93 GiB margin. Every campaign
phase must recompute `retained_now + remaining_manifest_bound + max_active_stage +
5 GiB`; insufficient space stops further calls without deleting evidence.

Hard ceilings are 252 selected source downloads (504 attempts), 120 candidate builds,
1,998 accepted captures (3,996 adapter attempts), 1,740 logical judge calls (3,480
attempts), 16 MiB per candidate source tree, 256 KiB per complete judge-attempt bundle,
512 MiB active staging, and 256 MiB quarantine. Accepted image bounds are
`4*width*height + 262144` bytes: 5,446,144 desktop and 1,578,784 mobile. Capture text
sidecars are capped at 524,288 bytes.

Content-addressed storage hashes original uncompressed bytes. PNG/JPEG evidence remains
byte-exact; text artifacts may use deterministic `gzip -n -9` only when decompression
reproduces the original digest. CAS objects become read-only after atomic publication.
Cleanup is run-lease-scoped and may delete only unreferenced temporary material; every
object reachable from the final certificate, calibration audit, tournament, or repair
ledger remains pinned through a second hash-verified archive.

## UI contract lock

The current incompatible v2 shapes are replaced, never silently aliased. Canonical v3
uses one exact-byte-hashed contract helper. Each UI task renders exactly three divergent
current directions before selection. A coordinator selects one; the final study has two
arms: locked incumbent versus selected current. Direction lock, prompt digest, build
receipt, capture receipt, and judge stimulus remain distinct identities. Real reference
discovery/acquisition is a producer, not an optional packet the builder may invent.

## Lifecycle lock

Cycle 41 exposed a control-plane failure: the integrator committed a valid external-open
handoff, then host checks mixed external and autonomous acceptances, appended diagnostic
text to committed evidence, deleted status files, and spawned a pointless repair. A
worker handoff must be immutable. Progress is measured from durable state transitions,
not changing tmux pane hashes. The supervisor has an independent progress deadline.
Runner recovery may checkpoint implementation, but never manufacture, normalize, delete,
or recommit worker-owned marker/verdict bytes.

## Primary references

- Miniukovich and Figl website aesthetics corpus/article:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC10823051/
- Harvard Dataverse Native API:
  https://guides.dataverse.org/en/latest/api/native-api.html
- Harvard Dataverse Data Access API:
  https://guides.dataverse.org/en/latest/api/dataaccess.html
- DataONE persistent identifier semantics:
  https://dataone-architecture-documentation.readthedocs.io/en/latest/design/PIDs.html
- Design2Code benchmark:
  https://arxiv.org/abs/2403.03163
- MLLM-as-a-Judge:
  https://arxiv.org/abs/2402.04788
- Judge positional-bias analysis:
  https://arxiv.org/abs/2406.07791
- Design Theater, preference-centered UI generation:
  https://arxiv.org/abs/2504.01435
- OPRO prompt optimization:
  https://arxiv.org/abs/2309.03409
- TextGrad:
  https://arxiv.org/abs/2406.07496
