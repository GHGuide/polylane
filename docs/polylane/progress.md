# Polylane progress

Generated mechanically from `max-state.json`. Conversation summaries are not authoritative.

## Cycle 14

subgoals: 37/43 done · criteria: 33/39 done · 85%

**Route:** `CONTINUE m14.1  Make promotion and reporting transactional when the runner has updated durable base state`

## Open autonomous work

- `m14.1` [open, w50] — Make promotion and reporting transactional when the runner has updated durable base state
- `m14.2` [open, w48] — Replace false terminal-turn wedge detection with process-aware liveness evidence
- `m14.3` [open, w46] — Route worker capsules messages and acknowledgements through one canonical ledger
- `m14.4` [open, w44] — Deliver selected skills by resolved trusted path and audit actual builder use
- `m14.5` [open, w42] — Certify cycle-14 promotion recovery concurrency skill delivery parity and live lifecycle

## External/user evidence

- `m12.4` — Keep Claude and Codex contracts aligned and certify the new loop against the old workflow — real 10-product rendered old-vs-new blind corpus remains external

## Blocked

- None

## Criteria

- `c1` [done] — fresh-clone install works on both platforms
- `c2` [done] — suite green + shellcheck clean
- `c3` [done] — rehearse canary GO+NO-GO green
- `c4` [done] — docs executable as written
- `c5` [done] — real 2-lane self-run reaches GO unattended
- `c6` [done] — versioned graph execution is correct, recoverable, auditable, and benchmark-efficient
- `c7` [done] — Recovery completes without manual tmux surgery and host-only gates run once in the coordinator
- `c8` [done] — Reports preserve truthful token, wall-time, restart, and cleanup evidence across resume
- `c9` [done] — Builder prompts use writable lane-local caching and only selected relevant skills
- `c10` [done] — Dual-jq graph budget and a fresh zero-intervention efficiency canary pass
- `c11` [done] — A versioned corpus of realistic vague app briefs runs reproducibly and scores completion, product quality, time, and tokens.
- `c12` [done] — Discovery persists an adaptive question graph with recommended, deeper, and bold routes and can synthesize a locked strategy without transcript memory.
- `c13` [done] — Codex workers launch through a measured lean profile and generated prompts obey a mechanical context budget without losing required contracts.
- `c14` [done] — Codex orchestration mechanically wires preflight risk, seam and judge gates, outcome learning, selection, and configured salvage instead of leaving helpers dormant.
- `c15` [done] — The execution graph exposes only typed, bounded quality routes and replay remains deterministic and benchmark-safe.
- `c16` [done] — At least three independent product-quality judges can block promotion with actionable evidence and bounded repair.
- `c17` [done] — Per-lane skill recommendations are installed-only by default, activity-specific, path-resolved, and ranked by measured helped/unused/hurt outcomes.
- `c18` [done] — A truthful one-shot control-room surface reports goal, cycle, graph, lanes, spend, verdict, and next action from canonical state without stale markers.
- `c19` [done] — Identical frozen acceptances share one explicit dedupe key per invocation and propagate truthful evidence without cross-source caching.
- `c20` [done] — Canonical state and control-room session/DONE truth match the runner even with ambient session variables or dirty committed markers.
- `c21` [done] — Advanced outcome memory is rooted to the canonical run project and never leaves generated ledgers in worker or integrator worktrees.
- `c22` [done] — Cross-lane requests, decisions, and resource claims use one atomic shared relay visible from every isolated worktree.
- `c23` [done] — Versioned local/global continual harness has atomic CRUD, immutable base, conflict protection, and rollback.
- `c24` [done] — Evidence-triggered refinements declare expected outcomes and next-cycle deadlines; regression or expiry rolls back.
- `c25` [done] — Stable worker identities preserve bounded context and an acknowledged append-only inbox across cycles.
- `c26` [done] — Builders consume bounded source-attributed context packets over durable project knowledge.
- `c27` [done] — Global prompt and skill learning cannot bypass frozen evolution gates and remains install-parity proven.
- `c28` [external] — UI cycles produce distinctive product-specific visual systems proven by desktop/mobile/state evidence and three independent judges
- `c29` [done] — Missing lane skills may be auto-acquired only through quarantine, deterministic audit, with-without benchmark, immutable pin, project install, and rollback metadata
- `c30` [done] — Manifest intensity and per-lane effort resolve correctly for Claude and Codex with role and safety clamps
- `c31` [done] — Every builder receives an explainable relevant installed skill kit, and authorized missing skills pass quarantine, benchmark, pin, and rollback before use
- `c32` [done] — Builder prompts are contradiction-free, deduplicated, goal-complete, and kept within a conservative measured context budget
- `c33` [done] — Claude and Codex lifecycle guards restore compact context and prevent dishonest completion without weakening runtime supervision
- `c34` [done] — One named certification matrix proves discovery through next-cycle continuation, installs, runtime, integration, and learning
- `c35` [open] — Verified promotion is transactional with runner-owned durable state and reports failure truthfully
- `c36` [open] — Health recovery distinguishes active high-effort turns from genuinely wedged or dead workers
- `c37` [open] — All worktrees append to one canonical monotonic worker history without merge conflicts
- `c38` [open] — Selected skills reach builders as trusted readable paths and usefulness receipts reflect actual use
- `c39` [open] — A cycle-14 certification reproduces and closes every failure discovered by the cycle-13 self-run

## Acceptance checks

- Total: 51
- Pass: 45
- Fail: 0
- Unchecked: 6
  - `m14.1` [unchecked] — bash tests/test-promotion-transaction.sh && bash tests/test-write-report.sh
  - `m14.2` [unchecked] — bash tests/test-wedge.sh && bash tests/test-runtime-recovery.sh
  - `m14.3` [unchecked] — bash tests/test-workers.sh && bash tests/test-worker-canonical-state.sh
  - `m14.4` [unchecked] — bash tests/test-scout-catalog.sh && bash tests/test-skill-acquire.sh && bash tests/test-prompt-compiler.sh && bash tests/test-skill-delivery.sh
  - `m14.5` [unchecked] — bash tests/test-cycle-14-contract.sh
  - `m14.5` [unchecked] — POLYLANE_MIN_DISK_GB=0 tests/run.sh && shellcheck -S warning bin/*.sh && bash tests/test-skill-parity.sh && bash tests/test-installers.sh && POLYLANE_MIN_DISK_GB=0 bin/polylane-doctor.sh --rehearse
