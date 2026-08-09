# Trials and soak verification

Run: `c16-evidence-autonomy-20260809-a1`  
Scope: deterministic source-pinned cross-domain trials and isolated resumable fault recovery.

## Trial evidence

`bin/polylane-domain-trials.sh validate benchmarks/domain-trials/v1` reported
`validated 7 source-pinned cases`. An offline isolated run reported 7 passed, 0 failed,
0 unproven, and 0 elapsed seconds at shell resolution. The corpus is versioned at
`benchmarks/domain-trials/v1`; live values never replace its golden extracts.

| Case / public primary source | Immutable raw extract SHA-256 |
| --- | --- |
| software — `https://raw.githubusercontent.com/git/git/v2.45.0/Documentation/RelNotes/2.45.0.txt` | `be27894b04f6b69ed93530c5bd6c8bd5c10fe89cd086d58db34afe3c0314f2f2` |
| trading — `https://fred.stlouisfed.org/graph/fredgraph.csv?id=SP500` | `c47262fa2fa06d69ae49a596f73ada617a3c28dbe54019658b07a81b50671910` |
| research — `https://api.crossref.org/works/10.1038/nphys1170` | `9cfcd2621268f16031df9a6846be7a01fbebdb047f19b0f9015c4bc4674424d3` |
| operations — `https://csrc.nist.gov/pubs/sp/800/61/r3/final` | `4e80f2eaa170dd1a430b3e81ff53bcb486597827e969360c60a51f64237616d5` |
| content — `https://www.wikidata.org/wiki/Special:EntityData/Q42.json` | `60b586bec602b6357235b8397fe9dcd30bbab72d119ed6097d028acd277d77b6` |
| data — `https://api.census.gov/data/2023/acs/acs5?get=NAME,B01003_001E&for=state:06` | `8067f6df8b3bc26e5b5a58a228388a453a1a6b424c3000d018c6ab091fdf7722` |
| custom/mixed — `https://www.rfc-editor.org/rfc/rfc9110` | `1f76553e3389e8ce678f3432eea9f1c434cba0e1ab00ae6c1c5a5f235059636e` |

Every case receipt also carries its source query/parameters, retrieval timestamp
(`2026-08-09T00:00:00Z`), terms/license note, schema/vintage, transformation list, and
compact raw path. Tampering with the FRED CSV failed validation before a helper was run.
The trading case requires `chronological_no_leakage`; the research case is a real Crossref
bibliographic record; the operations case identifies NIST SP 800-61r3.

The isolated runner records the adapter and grader commands, source-receipt path, artifact
bundle and artifact, expected/actual verdict, elapsed time, interventions, and a SHA-256
reproducibility hash in `results.jsonl`. A missing result, invalid verdict, or missing
artifact becomes `unproven` and makes the run nonzero.

## Live canary

One explicitly enabled, read-only Crossref canary was attempted with one GET, an 8-second
maximum timeout, no retry, and user agent `polylane-domain-trials/1.0 read-only-canary`.
At `2026-08-09T13:55:52Z` DNS could not resolve `api.crossref.org`; its receipt truthfully
recorded `status: SKIP`, no response checksum, and no suite failure. This was not counted
as a PASS and did not refresh any golden snapshot.

## Fault timeline and recovery

Accelerated seed 41, 8 iterations, zero sleeps, isolated fixture driver:

| Iteration | Injected fixture fault | Recovery result |
| --- | --- | --- |
| 1 | resume | restored |
| 2 | worker-death | restored |
| 3 | stale-nonce-marker | restored |
| 4 | malformed-state | restored |
| 5 | interrupted-atomic-write | restored |
| 6 | lost-session | restored |
| 7 | scheduled resume | receipt already present; no duplicate injection |
| 8 | scheduled worker-death | receipt already present; no duplicate injection |

The terminal summary was `passed`, with `steady_state.restored: true`, six exactly-once
fault receipts, and `sleep_seconds: 0`. The interruption experiment stopped after iteration
3 with exit 75 and `state.status: interrupted`; after the primary checkpoint was deliberately
malformed, resume recovered the valid atomic backup and completed without a second
`worker-death` receipt. A max-recovery-attempts value of zero produced a nonzero run and
truthful `terminal_status: failed` rather than a recovery claim. A foreign
`markers/nonce` was left untouched, proving stale-run isolation.

The controllable material risks are source drift (checksum-pinned snapshots), duplicate or
lost fault accounting (atomic state plus append-only events and receipt existence checks),
and accidental external impact (fixture-only driver; no tmux, git branch, home, network, or
external-system mutation). The two refinement-queue items are cross-lane `context` and
`integrator` concerns, not this lane's owned implementation surface; they are declined here
with the bounded check that these focused trial/soak checks remain green. No shared memory
or relay was edited.

## Checks and red-before-green

Initial focused execution was red: the new validators used an unsupported jq `IN/7` form,
so validation failed before trial output and state validity failed before soak iteration.
Tracing the first errors showed a jq-version compatibility issue, not a corpus or recovery
failure. Replacing it with array membership repaired the actual boundary. The same red run
also exposed two test-expression defects: a streamed check produced trailing false values,
and a literal newline was included in an expected scalar. Both now test their intended
single-value contract.

Final cached checks:

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/trials-soak" -- bash tests/test-domain-trials.sh
# 15 pass, 0 fail
bin/polylane-check.sh "$PWD/.polylane/check-cache/trials-soak" -- bash tests/test-soak.sh
# 21 pass, 0 fail
shellcheck -S warning bin/polylane-domain-trials.sh bin/polylane-soak.sh
# clean
```

SKILL-EVIDENCE: 2237429195-5669 — helped: the append-only fault timeline distinguishes detection, recovery, and terminal state for every injected fixture.
SKILL-EVIDENCE: 2811424084-1279 — helped: deterministic corpus validation, isolated runner integration, and optional live canary are separate layers.
SKILL-EVIDENCE: 3889652016-1630 — helped: fixture-only fault scope, checksum pinning, and bounded recovery address the controllable material risks.
SKILL-EVIDENCE: 4111822586-9465 — helped: earliest jq error was traced before repair, avoiding fixes to downstream missing-result symptoms.

## DEFERRED

A physical 6-, 12-, or 24-hour certification remains an operator option. Configure an
isolated directory with `bin/polylane-soak.sh configure <safe-run-dir> --hours 6 --seed 41`,
then run `bin/polylane-soak.sh run <safe-run-dir> --hours 6 --seed 41`; only 6, 12, and 24
are accepted. The resumable wall-clock state machine is complete and the accelerated proof
does not wait for that external elapsed-time certification.
