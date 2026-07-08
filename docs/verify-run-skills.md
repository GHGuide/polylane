# Verification — lane run-skills

Evidence: fresh `grep -n` output (2026-07-08, worktree `.polylane/wt/run-skills`, HEAD after a28d2f7) quoting every required section header and every exact CLI documented. No claim without a quoted line below.

## 1. Required sections — polylane-run/SKILL.md (`grep -n '^#'`)

```
52:### 3. Doctor preflight (always, before the dry-run)
147:## Watch the run — dashboard pane
160:## Notifications
175:## Parallel runs — POLYLANE_SESSION
185:## After a halt — `--resume`
196:## Push on GO — `--push`
206:## Stall detection (usage limits)
215:## Lane logs — audit trail
222:## Environment knobs
```
Report + health-retry live in `### 6. Explain what happens next` (line 82): report line 103, health-retry lines 85–88.

## 2. Required sections — polylane-auto/SKILL.md (`grep -n '^#'`)

```
53:### Phase 7 — run hands-off (drive the runner)      ← doctor preflight + dashboard offer + runner auto-behaviors
102:### Stall + halts (the one manual moment)
114:### Phase 8 — report back to the chat (REQUIRED — do not skip)   ← unchanged
132:## Runtime run controls (optional, same as /polylane-run)
154:## Environment knobs
163:## What stays interactive vs automatic               ← stall row added
```

## 3. Exact CLIs documented — polylane-run/SKILL.md (`grep -n`)

```
58:CLI: `bin/polylane-doctor.sh [manifest]` — the manifest argument is optional;
156:CLI: `bin/polylane-dashboard.sh <manifest> [--interval N]` — `--interval N`
163:next to it. CLI: `bin/polylane-notify.sh <event> <msg>` — events:
164:`done | go | no-go | halt | stall`.
143:`<manifest> [--dry-run] [--yes]`, extended by
144:`[--push] [--resume] [--intensity <economy|balanced|performance|max>]
180:POLYLANE_SESSION=myrun "$RUNNER" .polylane/run.json
191:"$RUNNER" .polylane/run.json --resume
201:"$RUNNER" .polylane/run.json --push
103:- **Writes `docs/polylane-report.md`** — a plain-terms digest (outcome, per-lane
217:Each lane's output is captured to `docs/lane-logs/<lane>.log`, and the logs
```
Doctor exit contract quoted at lines 59–60: "exit 0 = healthy, exit 1 = problem found".

## 4. Exact CLIs documented — polylane-auto/SKILL.md (`grep -n`)

```
68:**Doctor preflight:** CLI `bin/polylane-doctor.sh [manifest]` — the manifest
80:CLI: `bin/polylane-dashboard.sh <manifest> [--interval N]` — `--interval N`
93:- **notifies on milestones** via `bin/polylane-notify.sh <event> <msg>` —
94:  events `done | go | no-go | halt | stall` — so outcomes reach the user
134:base CLI stays `<manifest> [--dry-run] [--yes]`, extended by
135:`[--push] [--resume] [--intensity <economy|balanced|performance|max>]
110:"$RUNNER" .polylane/run.json --resume --yes
144:"$RUNNER" .polylane/run.json --intensity performance --model docs=claude-fable-5 --push --yes
151:POLYLANE_SESSION=myrun "$RUNNER" .polylane/run.json --yes
96:- **keeps per-lane logs** at `docs/lane-logs/<lane>.log` — they survive cleanup
99:  `docs/verify-*.md`. When it finishes it writes `docs/polylane-report.md` —
```

## 5. Cross-file consistency

Env tables byte-identical (diff of `grep -E '^\| .POLYLANE'` across both files → no output, `ENV-TABLES-MATCH`):

```
polylane-run/SKILL.md:226 == polylane-auto/SKILL.md:158  | `POLYLANE_SESSION` | `polylane` | tmux session name — set one per run for parallel runs |
polylane-run/SKILL.md:227 == polylane-auto/SKILL.md:159  | `POLYLANE_POLL_INTERVAL` | `15` | seconds between DONE-file polls |
polylane-run/SKILL.md:228 == polylane-auto/SKILL.md:160  | `POLYLANE_HEALTH_INTERVAL` | `300` | seconds between error-scans that auto-retry a lane stuck on a transient API/network error |
polylane-run/SKILL.md:229 == polylane-auto/SKILL.md:161  | `POLYLANE_MAX_RETRIES` | `3` | retries per lane before it is marked failed |
```

Same notify event list, same doctor exit contract, same report + log paths, same additive-flag line in both files. Stall behavior identical in both: no auto-retry, `stall` notification, manual decision, `--resume` after halt. Trigger descriptions in both frontmatters untouched and still accurate. Phase 8 of polylane-auto unchanged.

## 6. Goal checklist

- polylane-run/SKILL.md: doctor-first preflight ✓ (52), dashboard how-to ✓ (147), notify events ✓ (160–164), POLYLANE_SESSION ✓ (175), --resume ✓ (185), --push ✓ (196), stall = manual + notification ✓ (206), lane logs ✓ (215), report ✓ (103), health-retry ✓ (85–88).
- polylane-auto/SKILL.md: doctor in Phase 7 preflight ✓ (62–72), dashboard offered at launch ✓ (75–81), Phase 8 unchanged ✓ (114), env knobs ✓ (154–161), stall/--resume ✓ (102–112), --push/POLYLANE_SESSION ✓ (132–152).
- Note for bin lane logged in docs/parallel-status.md: `usage()` in bin/polylane-run.sh does not yet list `--push` / `--resume` / `POLYLANE_SESSION` (incoming features; docs follow the frozen contract).
