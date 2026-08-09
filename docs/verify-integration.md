# Cycle 26 integration verification — READY for the host gate

Run: `c26-terminal-finality-20260810-a1`

Branch: `lane/c26-integrator`

Frozen source/evidence boundary: `7854a1f`

Cycle 26 planning base: `0e96dc9`

The selected verification-before-completion and code-review kits governed the
evidence order and the independent transaction/error/race audit. The bounded
context packet was read exactly once. No Graphify skill body was read or invoked,
and the shared graph was not rebuilt.

## Exact-tip provenance and write set

The asserted terminal-finality tip
`a4bb7fd442c47185c644cf08cc9999be16d06d8c` was merged without rewriting it.
Integration merge `979784293cfb6c4aa614761d403add16b5f7c343` has parents
`0e96dc9b55555bee79e2184cd8eb7963a97bf8e5` and the exact asserted tip;
`git merge-base --is-ancestor` succeeded.

The builder write set is limited to the runner/supervisor, Claude/Codex prompt
guidance, prompt/reference parity, five focused test files, and its two handoff
records. Final relay review exposed two bounded integration seams, repaired in
`bin/polylane-run.sh` and `bin/polylane-state.sh` with regressions in
`tests/test-cycle-13-contract.sh` and `tests/test-state.sh`:

1. The read-only state observer now reconstructs absolute worktrees and prefers
   the current nonce's canonical compiled prompt when grading the narrow
   `.polylane-prompt.txt` exception. It no longer compares launch transport bytes
   with an authored source prompt or broadly ignores prompt scratch.
2. Prompt compilation now injects typed selected records for an integrator when
   that lane has selections. A missing integrator kit remains a no-op; present
   records still pass compile-selected validation, path/fingerprint checks,
   dedupe, strict lint, and prompt budgets.

Integration also strengthened `tests/test-verdict-repair.sh`: failed admission now
explicitly proves prompt selection, pane index/no pane action, and restart
telemetry are unchanged, in addition to HEAD and status/verdict bytes. No fixture
was weakened; fixtures were extended only to exercise the stricter production
invariants.

## Independent terminal transaction review

- `build_integrator_repair_prompt` retains the original strict block and adds
  prose only. Strict promptopt admission proves all 13 exact-once labels occur
  once.
- `repair_integrator_verdict` prepares and strictly admits a candidate before
  checkpointing, evidence archive/removal, `INT_PROMPT` selection, runtime
  refresh, pane respawn, or `lane-restart`. Forced admission failure leaves HEAD,
  committed status/verdict checksums, selected prompt, pane identity/action log,
  and restart telemetry unchanged.
- `terminal_efficiency_eligible` reads only observed launch/restart/supervisor
  overages and runs before `terminal-gate`. A rejected path records zero terminal
  events and skips proof/acceptance; eligible GO and external routes each count
  and execute the boundary exactly once. Unknown token evidence remains unknown.
- An exhausted or nonrepairable verifier route calls
  `publish_established_no_go`: the known NO-GO report is attempted even when graph
  halt bookkeeping fails, and it precedes best-effort salvage/learning. Visual
  and judge exhaustion also publish NO-GO before returning. GO/external success
  converges on the same idempotent terminal reporter.
- Graph/bookkeeping or promotion failures before a terminal verdict publish
  `HALTED`, preserving recovery rather than fabricating NO-GO. A failed report
  write preserves an older truthful report and remains reportless/recoverable.
- `report_completed_terminal` permits one publication attempt per runner process.
  The supervisor accepts only a fresh report containing the current nonce: fresh
  NO-GO ends after one launch, while HALTED, a stale-run report, and a truly
  reportless crash retain their recovery paths.
- `safe_rm` refuses unsafe paths with `return 1`, never process `exit`. Ordering
  and error propagation remain Bash-3.2-safe; no associative arrays, GNU-only
  rewrites, unbounded retry, or new deletion surface was introduced.

The review found no unresolved ordering, portability, idempotence, or race defect.
The prepared prompt is ordinary scratch until admitted; live evidence and pane
state remain authoritative until the prepare phase succeeds.

## Fresh focused verification

One cached combined run passed **700 checks across 28 files with zero failures**.
It covers pane-local identity, run-scoped inbox and worker history, live-agent
marker gating, completed-branch scope, finalization/handoff syntax, prompt
compiler/lint/optimization and provider parity, refinement commands, custom
intensity/model policy, state, supervisor, graph authority, reports, repair,
pre-terminal efficiency, recovery/resume, run stats, acceptance, verdict parsing,
and the seam scanner. Retained log:
`.polylane/check-cache/integrator/51513573-1095.output`.

After the final relay exposed the observer and skill-delivery seams, a fresh
affected matrix passed **341 checks across 10 files with zero failures**: state,
lane completion, the Cycle 13 compiled-prompt journey, skill delivery, prompt
compiler/optimization/lint, orchestration, provider parity, and verdict repair.
Retained log: `.polylane/check-cache/integrator/979932736-508.output`.

A final fingerprint-enforcement matrix then passed **246 checks across 7 files
with zero failures**: the Cycle 13 journey, skill delivery, all scout/catalog/
outcome contracts, orchestration, and provider parity. It proves an absent
integrator record remains a no-op, while a present record with a stale fingerprint
fails validation before prompt compilation. Retained log:
`.polylane/check-cache/integrator/1461801900-415.output`.

Final relay request 5 added the missing integrator-less observer boundary. The
state path resolvers now preserve empty worktree/prompt values as empty, and a
fresh **23-check** state run proves no phantom integrator lane, root worktree, or
`.txt` prompt is synthesized. Retained test and ShellCheck logs:
`.polylane/check-cache/integrator/3391859829-114.output` and
`.polylane/check-cache/integrator/1034521202-133.output`.

Final changed-script ShellCheck passed for `bin/polylane-run.sh`,
`bin/polylane-state.sh`, `bin/polylane-scout.sh`, and
`bin/polylane-supervisor.sh`; retained log:
`.polylane/check-cache/integrator/1156756985-202.output`. The real repository seam
scan passed with log `.polylane/check-cache/integrator/860521856-190.output`.
`git diff --check` also passed.

The coordinator-owned full suite, installers, terminal acceptance, and doctor
rehearsal were not run. No terminal gate was consumed by this lane.

## Live runtime, Graphify, and inbox evidence

Canonical `docs/polylane/run-stats.json` was inspected after integrator launch. It
records one `terminal-finality` launch at `1786316034`, one integrator launch at
`1786316870`, zero lane restarts, zero supervisor restarts, zero terminal gates,
unknown tokens, and pending cleanup. The builder capsule is complete and the
integrator capsule is active for Cycle 26. Thus the required builder history
before integrator launch is exactly one launch with no builder or supervisor
restart. Runtime counters are recorded here as evidence, not used by the
integrator to self-authorize GO.

The canonical manifest preserves `intensity: custom`, builder
`gpt-5.6-terra/medium`, and integrator `gpt-5.6-sol/high`. Pane 0 and pane 1 expose
matching pane-local `@polylane_run_id`, `@polylane_lane`, and
`@polylane_worktree` values for this nonce. Both canonical compiled prompts were
inspected. The launch-time integrator copy had name-only skill labels and zero
`SELECTED-SKILL` records, which is recorded as the relay-discovered seam above;
the final source and 341-check matrix now prove conditional integrator delivery.
The two exact records were read from the typed injected
`.polylane/lane-skills.json` record, once each, rather than inferred from that
defective launch-time prompt.

Before the observer fix, the live state surface reported terminal-finality as
`likely-done(verify me)` with pane `-`. Re-running the fixed worktree script against
the same canonical manifest reports terminal-finality `done`, pane `0`, head
`a4bb7fd`; the unfinished integrator remains non-done on pane `1`. This is direct
state/runner agreement evidence. The scoped durable integrator inbox returned
`[]` at both ordinary and final reads.

Direct navigation used:

```sh
python3 graphify-out/q.py --cap 8 build_integrator_repair_prompt
python3 graphify-out/q.py --cap 8 repair_integrator_verdict
python3 graphify-out/q.py --cap 8 gate_with_repairs
python3 graphify-out/q.py --cap 8 write_report
python3 graphify-out/q.py --cap 8 supervisor_main
```

These resolved the runner symbols at lines 3512, 3558, 3645, and 4191 and the
supervisor symbol at line 213 in the carried graph. A command-field audit found
direct q.py use in both lane logs (one builder command field and three integrator
command fields) and **zero Graphify skill-body read commands**. The graph was not
rebuilt.

The refinement queue returned `[]`, so no item was eligible and no `propose` or
`decline` command was invoked. Final relay requests 3 and 4 were addressed by the
two bounded seam fixes and their fresh tests; request 5 added the empty-preserving
integrator-less regression. The final scoped inbox returned `[]`. No external
evidence is claimed.

## Skill receipts

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: withheld all
completion claims through the final relay defects and required the original
700-check matrix, post-repair 341-check and 246-check matrices, changed-script
ShellCheck, repository seam scan, ancestry proof, runtime inspection, and final
clean-state checks.

SKILL-EVIDENCE: engineering:code-review — helped: structured the independent
ordering, fail-closed, Bash portability, race-window, write-set, and report
idempotence review; it also kept the observer exception narrow and integrator
skill injection conditional instead of weakening dirty-tree or selection gates.

## Verdict

The exact terminal-finality source and the accumulated Cycle 24–26 contracts are
focused-green. The integrator does not convert runtime counters into GO and leaves
the single frozen terminal boundary to the coordinator. The formal nonce-bound
handoff verdict is added only in the final marker commit.
