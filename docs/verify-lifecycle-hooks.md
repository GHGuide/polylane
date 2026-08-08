# Lifecycle-hook verification

## Scope

`bin/polylane-hooks.sh` is an optional, project-scoped defense in depth. It
only restores compact context and asks for one evidence-focused continuation.
It does not parse transcripts, change files, grant permissions, schedule work,
or replace the supervisor, runner gates, worktree isolation, or approval
policy.

The helper reads exactly `.polylane/lifecycle-hooks.json` beneath the selected
project. Its allowlisted state is `memory_brief`, `north_star`,
`settled_decisions`, and `byte_cap`; `assets/hooks/lifecycle-hooks-state.example.json`
is the reviewable template. Any other state field is excluded. The hard limit
is the smaller of the state cap, `POLYLANE_HOOK_MAX_BYTES`, and 4096 bytes;
caps below 64 are invalid and fail open visibly.

For Stop, the lane is complete only when the first line of
`docs/status-<lane>.md` is exactly `STATUS: <lane> DONE run=<run-id>` and its
required verification file contains `run=<run-id>`. Integrator evidence is
`docs/verify-integration.md`; every other lane uses `docs/verify-<lane>.md`.
The helper takes a run id/lane from lifecycle JSON when supplied, otherwise it
uses `.polylane/run.json` or `docs/polylane/run-stats.json` for the run id and
`POLYLANE_WORKER_ID` for the lane. If those values are unavailable it allows
the runner to recover and emits a diagnostic, rather than inventing authority.

## RED then GREEN fixture evidence

The focused test was intentionally run before the helper and registration
fragments existed. The configuration-fragment assertions failed:

```text
FAIL hooks-codex-fragment-json — expected rc 0, got 2
FAIL hooks-claude-fragment-json — expected rc 0, got 2
FAIL hooks-codex-fragment-project-local — output does not contain [git rev-parse --show-toplevel]
FAIL hooks-claude-fragment-project-local — output does not contain [CLAUDE_PROJECT_DIR]
test-hooks.sh: 24 pass, 4 fail
```

After implementation, the cached focused command was green:

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/lifecycle-hooks" -- bash tests/test-hooks.sh
test-hooks.sh: 29 pass, 0 fail
```

The coverage includes JSON fixtures for Codex and Claude `SessionStart`,
`PreCompact`, `PostCompact`, and `Stop`, plus source labels, hard byte cap,
ignored unbounded state, exact current-run marker, run-tagged evidence,
already-active stop recursion, invalid JSON, missing state, and provider
semantic parity.

## Exact normalized outputs

Given the fixture state and `SessionStart`, both providers emit the same
valid context shape (the compact text is shown verbatim):

```json
{"continue":true,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[memory-brief] Keep the hook helper portable and limited to context and completion truth.\n[north-star] A stranger's first unattended Polylane run is truthful and verified.\n[settled-decisions] Hooks are optional project-scoped defense in depth. | The supervisor remains runtime authority. | Never silently grant broad permissions."}}
```

For `PreCompact` and `PostCompact`, both providers emit the same valid common
hook fields, with the same capped text in `systemMessage`:

```json
{"continue":true,"systemMessage":"[memory-brief] …\n[north-star] …\n[settled-decisions] …"}
```

With `STATUS: fixture-lane DONE run=fixture-run` and verification text that
contains `run=fixture-run`, both Stop fixtures emit:

```json
{"continue":true}
```

With a stale marker, both emit one focused continuation request:

```json
{"decision":"block","reason":"Polylane completion evidence is incomplete: write the exact current-run marker 'STATUS: fixture-lane DONE run=fixture-run' and run-tagged verification evidence before stopping. Request one focused continuation; the supervisor remains runtime authority."}
```

With `stop_hook_active: true`, both emit `continue: true` and the visible
`systemMessage` `polylane-hooks: continuation already active; allow runner to
recover without a stop loop`.

## Configuration and semantic differences

`assets/hooks/codex-hooks.json` is copied only to a repository's
`.codex/hooks.json`; it resolves the helper from `git rev-parse --show-toplevel`.
Codex requires review/trust of project hooks and uses its native `SessionStart`,
`PreCompact`, `PostCompact`, and `Stop` handlers. `SessionStart` carries the
context in `hookSpecificOutput.additionalContext`; Codex's compact-event
handlers use the portable common `systemMessage` shape.

`assets/hooks/claude-settings.json` is merged only into that repository's
`.claude/settings.json` and resolves paths through `CLAUDE_PROJECT_DIR`. The
legacy `assets/settings-hook-snippet.json` is a tested compatible replacement:
it retains the graph-navigation `PreToolUse` nudge while its Stop registration
now calls the same lifecycle helper instead of the older verify-file-only gate.

Both providers therefore restore identical allowed context, have the same
byte cap, require the same current-run marker and run-tagged evidence, request
at most one continuation, and fail open visibly if optional state is invalid.
They are not security coverage for hosted tools or every execution path.

SKILL-EVIDENCE: superpowers:test-driven-development — unused: no resolved `SKILL.md` path was supplied in this runtime.
SKILL-EVIDENCE: superpowers:systematic-debugging — unused: no resolved `SKILL.md` path was supplied in this runtime.
SKILL-EVIDENCE: engineering:system-design — unused: no resolved `SKILL.md` path was supplied in this runtime.
SKILL-EVIDENCE: operations:risk-assessment — unused: no resolved `SKILL.md` path was supplied in this runtime.
