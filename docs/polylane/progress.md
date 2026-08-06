# Polylane progress

Generated mechanically from `max-state.json`. Conversation summaries are not authoritative.

## Cycle 9

subgoals: 13/21 done · criteria: 10/18 done · 58%

**Route:** `CONTINUE m8.1  Ship a realistic vague-brief product benchmark corpus and reproducible scorecard runner`

## Open autonomous work

- `m8.1` [open, w18] — Ship a realistic vague-brief product benchmark corpus and reproducible scorecard runner
- `m8.2` [open, w17] — Ship a durable adaptive discovery question graph and strategy synthesis surface
- `m8.3` [open, w16] — Ship measured lean Codex worker profiles plus prompt-budget optimization gates
- `m8.4` [open, w15] — Wire advanced risk, seam, outcome, selection, and salvage helpers into the Codex runtime contract
- `m8.5` [open, w14] — Extend the immutable graph with typed bounded quality routing while preserving deterministic replay budgets
- `m8.6` [open, w13] — Gate promotion through three independent product judges with actionable bounded repair evidence
- `m8.7` [open, w12] — Make skill scouting activity-specific, path-resolved, and self-improving from outcome evidence
- `m8.8` [open, w11] — Upgrade the dashboard into a canonical one-shot control room and certify the complete expansion

## External/user evidence

- None

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
- `c11` [open] — A versioned corpus of realistic vague app briefs runs reproducibly and scores completion, product quality, time, and tokens.
- `c12` [open] — Discovery persists an adaptive question graph with recommended, deeper, and bold routes and can synthesize a locked strategy without transcript memory.
- `c13` [open] — Codex workers launch through a measured lean profile and generated prompts obey a mechanical context budget without losing required contracts.
- `c14` [open] — Codex orchestration mechanically wires preflight risk, seam and judge gates, outcome learning, selection, and configured salvage instead of leaving helpers dormant.
- `c15` [open] — The execution graph exposes only typed, bounded quality routes and replay remains deterministic and benchmark-safe.
- `c16` [open] — At least three independent product-quality judges can block promotion with actionable evidence and bounded repair.
- `c17` [open] — Per-lane skill recommendations are installed-only by default, activity-specific, path-resolved, and ranked by measured helped/unused/hurt outcomes.
- `c18` [open] — A truthful one-shot control-room surface reports goal, cycle, graph, lanes, spend, verdict, and next action from canonical state without stale markers.

## Acceptance checks

- Total: 22
- Pass: 13
- Fail: 0
- Unchecked: 9
  - `m8.1` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && bash tests/test-product-benchmark.sh >/dev/null 2>&1
  - `m8.2` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && bash tests/test-discovery-graph.sh >/dev/null 2>&1
  - `m8.3` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && bash tests/test-codex-profile.sh >/dev/null 2>&1 && bash tests/test-promptopt.sh >/dev/null 2>&1
  - `m8.4` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && bash tests/test-advanced-runtime.sh >/dev/null 2>&1
  - `m8.5` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && bash tests/test-graph-quality-loop.sh >/dev/null 2>&1
  - `m8.6` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && bash tests/test-judges.sh >/dev/null 2>&1
  - `m8.7` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && bash tests/test-scout-outcomes.sh >/dev/null 2>&1
  - `m8.8` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && bash tests/test-control-room.sh >/dev/null 2>&1
  - `m8.8` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && bin/polylane-check.sh "$PWD/.polylane/check-cache/terminal-m8" -- tests/run.sh && shellcheck -S warning bin/*.sh
