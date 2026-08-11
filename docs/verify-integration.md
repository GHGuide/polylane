# Cycle 29 integration verification

Run: `c29-active-scope-20260811-a1`

## Exact-tip provenance and review

- Frozen recovered source: `cf60d3c1646dc6a7ae3f76a636be423cef91e9a1`.
- Integrator pre-merge tip: `940f6f69ce460366d61391998bbe8138ed21a69e`.
- Exact builder handoff: `7c24295ba86a8942b959b8016b9d4e5c6aeddd6d`, whose first line is `STATUS: active-scope DONE run=c29-active-scope-20260811-a1`; implementation parent: `0eb2b88fcdf381d121ed25671743a8c53532bce9`.
- The handoff hash was merged with `git merge --ff-only 7c24295ba86a8942b959b8016b9d4e5c6aeddd6d`. The integrator inspected the complete `940f6f6..7c24295` diff across all 17 changed files and queried Graphify for the changed runtime symbols before targeted source reads.
- Cycle 28 remains the immutable truthful HALTED run recorded at `/Users/leonardo/Downloads/polylane-c28/docs/polylane-report.md`; its eight restarts, zero terminal gates, and lack of promotion are not rewritten.

## Independent contract review

1. **Active work:** `lane_active_command` now streams raw log lines through a type-safe JSON reducer, tracks overlapping command IDs, ignores non-JSON and non-item structured warnings, and clears stale IDs at new or terminal turn boundaries. `material_progress_stalled` returns before changing fingerprint, command baseline, churn count, or replan state while any ID is active. After every ID settles, the unchanged 12-check/20-command bounded churn policy still fires.
2. **Source roots:** manifest-relative builder and integrator worktrees are anchored to the project root and existing paths resolve through `pwd -P`. Missing or empty worktree fields remain `null`/empty until required-field validation rather than becoming plausible project paths. `pane_cmd` canonicalizes again before staging, `cd`, and exporting `POLYLANE_SOURCE_ROOT`, so the exported source root is an absolute physical worktree even when the manifest path is relative or shell-escaped.
3. **Terminal scope:** only a clean, committed, exact-HEAD, exact current-run DONE handoff with no mapped live worker can become terminal scope evidence. Its real `SCOPE-VIOLATION` output is bounded and stored once; `health_check` marks it failed without retry, repair, respawn, or worktree mutation. Dirty, uncommitted, stale, live, and integrator trees remain outside this fail-fast path.
4. **Planned writes:** `write_plan_contract: 1` requires every builder to provide non-empty, unique exact paths. Preflight rejects absent, absolute, traversal, globbed, duplicate, and out-of-scope paths before worktree/tmux launch. Manifest ownership globs remain newline-delimited data until the intentional matcher, so checkout files cannot pathname-expand `src/**` before scope admission, overlap review, or final lane checking. Manifests without the opt-in remain compatible. Runtime compilation removes any authored `PLANNED-WRITES` line, injects exactly one current lane boundary, and lint now rejects zero or duplicate boundaries when enabled.
5. **Finite live-turn policy:** low/medium/high/xhigh defaults remain 300/900/1800/3600 seconds. The default finite hard cap is 14,400 seconds; `POLYLANE_LIVE_WEDGE_HARD_SECONDS` remains operator-extensible, and an explicit 7,200-second requested window is not silently clamped.

Independent review repaired five bounded seams: canonical replacement/exact-once lint for the compiled planned-write boundary; streaming, type-safe active-command reduction for mixed logs; newline-preserved ownership glob matching; preservation of missing worktree fields until validation; and one inherited trailing-whitespace failure in builder evidence. No frozen target, acceptance, retry budget, terminal gate, installer, or deployment behavior was weakened.

## Focused cached evidence

Every matrix ran through `bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- <command>`; unchanged expensive checks were not repeated. The one invalid test-harness assertion was replaced, then only matrices containing that changed test were rerun on the new fingerprint.

- `m24.1`: manifest validation 19, Cycle 13 contract 56, scout 30, orchestration contract 14, dry-run purity 11; all pass.
- `m24.2`: marker normalization 20, lane DONE 27, live DONE/scope/prompt boundary 15, scope 29; all pass on the corrected test fingerprint.
- `m24.3`: memory 60, acceptance contract 23, verdict repair 53, report writing 51; all pass.
- `m25.1`: wedge 31, runtime recovery 26, pane-error classification 16; all pass.
- `m25.2`: report writing 51 and runtime recovery 26; all pass.
- `m25.3`: run-stats concurrency/resume/usage script, report writing 51, efficiency canary 25; all pass.
- `m25.4`: agent adapter 53, prompt compiler 16, orchestration contract 14, prompt lint 32; all pass.
- `m26.1`: progress guard 21 and wedge 31; all pass.
- `m26.2`: agent adapter 53, prompt compiler 16, prompt lint 32; all pass.
- `m26.3`: live DONE 15, runtime recovery 26, report writing 51; all pass.
- `m26.4`: scope 29, manifest validation 19, orchestration contract 14; all pass.

Changed scripts `bin/polylane-run.sh`, `bin/polylane-scope.sh`, and `bin/polylane-promptlint.sh` pass `bash -n` and `shellcheck -S warning`. `git diff --check 940f6f69ce460366d61391998bbe8138ed21a69e` passes for the complete integrated worktree. The terminal full suite, terminal acceptance, doctor rehearsal, installers, push, deployment, publication, and external action were not run.

## Runtime and process evidence

Canonical runner state is `/Users/leonardo/Downloads/polylane-c29/docs/polylane/run-stats.json` with `run_id=c29-active-scope-20260811-a1`. It records exactly `active-scope: launches=1,restarts=0`, `integrator: launches=1,restarts=0`, `supervisor_restarts=0`, and `terminal_gates=0`; cleanup remains pending for the runner. Worktree-local `run-stats.json` copies are stale Cycle 23 artifacts and were excluded. The runtime relay and durable inbox had no request addressed to the integrator at review time. The refinement queue returned `[]`, so there were no eligible items requiring a `propose` or `decline` decision.

## Skill receipts

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-EVIDENCE: engineering:code-review — helped: the correctness, security, and performance review found conflicting planned-write boundaries, a type-fragile active-command reducer, cwd-driven ownership-glob expansion, and missing worktree fields normalized before validation.

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: a combined final diff check caught inherited trailing whitespace, and an unsupported test assertion was rejected as evidence even though the harness summary incorrectly remained green.

Cycle 29 is source-ready only. `m24.4`, `m25.5`, `c66`, and `c71` remain open for the fresh Cycle 30 process and its runner-owned terminal suite, parity, installers, and live GO/NO-GO rehearsal.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c29-active-scope-20260811-a1
