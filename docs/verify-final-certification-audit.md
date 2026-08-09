# Cycle 21 final-certification audit

Run: `c21-final-cert-20260809-a1`
Lane: `final-certification-audit`
Scope: read-only provenance audit; no production source or test was edited.

## Skill receipts

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

## Graph query

The pre-refreshed graph was queried before document or source reads. Its first BFS query
located `compile_prompt` at `bin/polylane-run.sh:L662`, `preflight_contract` at `L729`,
and `supervisor_stop` at `bin/polylane-supervisor.sh:L87`. `graphify explain` located
`write_efficiency_proof` at `bin/polylane-run.sh:L131` (reported callers: `merge_gate`
and `cleanup`) and `finalize_cycle_criteria` at `L3694` (reported caller: `cleanup`).
It had no node for `normalize_lane_status_marker`.

Usefulness: the locations narrowed the primary-commit inspection and confirmed the
cleanup/proof relationship. Limitation: the graph's extracted call directions for the
other three nodes were stale or non-conventional, and its missing normalizer node means
it cannot establish complete caller coverage. Commit patches and the frozen focused
checks, not the graph, are the authoritative evidence below. The graph was not rebuilt.

## Cycle 20 causal trace and provenance

The committed Cycle 20 terminal outcome (`0a9cf7b`) records run
`c20-clean-cert-20260809-a1`: two launches, one restart, one host-boundary entry, zero
full terminal-acceptance executions, known 4,424,983 tokens, and retained cleanup. It
states that the host efficiency proof failed at `restarts=1>0`, so the terminal command
was not consumed. The same commit's updated integration evidence identifies the actual
near-miss as `docs/status-restart-accounting.md` where the required marker was
`docs/status-restart-accounting-audit.md`; its nonce-bound first line belonged to the
same lane and run. This attributes the restart to a plan/observer path mismatch, not to
worker noncompliance.

The raw frozen `.polylane` manifest, authored prompt, live relay, and telemetry files
for Cycle 20 are not retained in this fresh worktree's scratch area or in its reachable
Git tree. Thus this audit can prove the committed outcome and repair provenance, but
cannot honestly claim to have reopened the original manifest/prompt bytes. That is a
NO-GO limitation for any stronger raw-artifact assertion; it does not rewrite Cycle 20
or turn its recorded NO-GO into a pass.

| Commit | Guard confirmed from the primary patch | Regression coverage added in that patch | Fresh prescribed coverage |
| --- | --- | --- | --- |
| `763fb00176bc65ece61f534fc977d90229e187ad` | `normalize_status_marker` permits only contract-v2, current-run, one clean committed regular candidate and is attempted before a restart; `compile_prompt` injects literal live-relay/DONE contracts after optimization and runtime lint requires them exactly once. | `tests/test-status-marker-normalization.sh` adds positive, stale, foreign, uncommitted, ambiguous, dirty, and symlink cases; compiler contract assertions were added to `tests/test-cycle-13-contract.sh`. | `test-prompt-compiler.sh`: 16/0. |
| `e1de56a562ea64081f53ed1d93bd61766d925af5` | Gate proofs are host-canonical and nonce-scoped; the proof verifier rejects a mismatched run; report failure points to canonical host evidence and unknown cost is not rendered as zero. | `tests/test-efficiency-canary.sh` adds wrong-run, clean-integrator, canonical-path, exported-proof, and report-path assertions; `tests/test-write-report.sh` adds reporting coverage. | No additional test was authorized by this lane's five-command cadence. |
| `f58d3cbd72b5ae05b26b15338f50487283560335` | Contract-v2 scope/preflight rejects noncanonical, broad, or duplicate status ownership and prompt lint rejects missing runtime contract. | `tests/test-scope.sh`, `tests/test-orchestration-contract.sh`, and `tests/test-promptlint.sh` gain rejection assertions. | `test-scope.sh`: 19/0; `test-orchestration-contract.sh`: 14/0. |
| `dabd6f016475754d65faad42fab4c57147f28606` | `supervisor_stop` traps `INT`/`TERM`, propagates the child stop, releases the lock, and exits; help is inert before manifest/runner work. | `tests/test-supervisor.sh` adds help-no-runner and TERM-child/lock assertions. | `test-supervisor.sh`: 32/0. |
| `864050dcb8736e9849561f0c753b2ca0b7eb1fa0` | `target_criteria` must be open at preflight; `finalize_cycle_criteria` is reached only after final `write_efficiency_proof` succeeds in cleanup. | Contract acceptance checks defer the criterion until finalization; orchestration rejects an unknown criterion; dry-run keeps it open. | `test-contract-acceptance.sh`: 19/0; `test-orchestration-contract.sh`: 14/0. |

Each named repair has a committed regression test addition. A final patch cannot itself
prove the historical ordering of a red run before the fix. The retained Cycle 20 prose
claims red-first executions for the earlier repairs, but this lane did not manufacture a
red state by reverting production code, because its scope is evidence-only and the
prescribed five checks were run exactly once. This is an explicit historical-evidence
limit, not a substituted success claim.

## Fresh focused verification

Each command was executed once through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/final-certification-audit" --`.

| Command | Result |
| --- | --- |
| `bash tests/test-supervisor.sh` | 32 pass, 0 fail |
| `bash tests/test-contract-acceptance.sh` | 19 pass, 0 fail |
| `bash tests/test-orchestration-contract.sh` | 14 pass, 0 fail |
| `bash tests/test-scope.sh` | 19 pass, 0 fail |
| `bash tests/test-prompt-compiler.sh` | 16 pass, 0 fail |

Total: 100 pass, 0 fail. No full suite, whole-tree ShellCheck, skill parity, installer,
doctor, rehearsal, browser, installation, deployment, push, or external action was run.

## Limits and conclusion

This is evidence that the specified repair commits contain the stated guards and that
the five frozen checks pass at the current tip. It is not terminal GO: the coordinator
retains the untouched terminal boundary, and the unavailable raw Cycle 20
manifest/prompt bytes prevent a stronger direct-artifact claim about their contents.

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: separated the recorded path mismatch and host-gate failure from the unavailable raw scratch artifacts, preventing a causal claim beyond primary evidence.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: required one fresh cached execution of each prescribed command and exact 100/0 output before the scoped evidence commit.
