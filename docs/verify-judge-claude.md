# Verify — judge-claude visual-judge adapter

Lane `judge-claude`, run `c40-live-harness-20260812-a3`. Scope: one isolated,
noninteractive Claude visual-judge adapter that **sends exact frozen
image/request inputs and emits raw bytes plus a provenance receipt**. It never
decides eligibility, winner, or certification, and never parses a preference.

Owned files:

- `bin/polylane-taste-judge-claude.sh` — the adapter (`invoke` + `verify`).
- `benchmarks/taste-live/prompts/judge-claude-system.md` — the judge system prompt.
- `tests/test-taste-judge-claude.sh` — adversarial fake-CLI test suite.
- `docs/verify-judge-claude.md` — this file.
- `docs/status-judge-claude.md` — lane status marker.

## Exact invocation contract

```
polylane-taste-judge-claude.sh invoke \
  --model ID --system PROMPT.md --schema SCHEMA.json \
  --request STIMULUS.json --out RECEIPT.json \
  --image PNG [--image PNG ...] [--timeout SECS]

polylane-taste-judge-claude.sh verify RECEIPT.json
```

- `CLAUDE_BIN` (default `claude`) — the Claude CLI; resolved via `command -v`.
- `POLYLANE_TASTE_JUDGE_TIMEOUT` (default 180) — bounded wall clock.
- `POLYLANE_TASTE_JUDGE_LIVE=1` — operator-only opt-in; the **only** way a
  receipt is `classification: live`. Every other run is `fixture_only`.

Provider-native argv (bounded, read-only, no tools):

```
claude --print --model <ID> --output-format json \
       --permission-mode plan --allowedTools '' \
       --append-system-prompt <system prompt> \
       -p <brief clauses + rubric + ordered @image refs + response schema>
```

Config/session state is isolated per invocation: `HOME`, `CLAUDE_CONFIG_DIR`,
and `XDG_CONFIG_HOME` are redirected to a fresh throwaway dir that is deleted
after the call, so no user session leaks into the judgement.

## Receipt: `taste-judge-claude-receipt/v1`

Binds, for one invocation: `inputs.model`; `system_prompt_sha256`;
`response_schema_sha256`; `request_content_sha256`; ordered `image_sha256[]`;
`argv_template`; composite `request_sha256`; `invocation.cli_bin` + `cli_version`
+ `cli_command_sha256` + redacted argv + `permission_mode` + `allowed_tools`;
`exit_status`; `timed_out`; `timeout_seconds`; start/end UTC + epoch + duration;
`raw.stdout_path`/`stdout_sha256`/`stdout_bytes`/`stdout_parses_json`;
`raw.stderr_path`/`stderr_sha256`/`stderr_bytes`; and `environment.key_names`
(names only). Raw model bytes are escrowed to `<out>.stdout` / `<out>.stderr`
sidecars; the receipt carries their hashes, not a decoded preference.

`request_sha256` is a deterministic function of the bound components (model,
prompt sha, schema sha, request-content sha, ordered image shas, argv template).
`verify` recomputes it, so any component or the composite tampered on its own is
rejected.

**No preference is ever parsed.** `stdout_parses_json` is a structural note (does
the raw stdout parse as JSON) — not the choice. `verify` fails any receipt whose
key paths match `winner|preference|verdict|eligib`.

## Fake-CLI attack + behaviour matrix (all green)

`tests/test-taste-judge-claude.sh` drives the adapter through an injected fake
Claude CLI. Every receipt it mints is `fixture_only` and cannot enter a
production ballot. 54 assertions, 0 fail.

| Case | Fed | Asserted |
|---|---|---|
| success | well-formed JSON, exit 0 | rc 0, receipt+verify OK, ordered image shas bound, stdout escrowed+hashed, no preference key |
| abstain | `choice:"abstain"`, exit 0 | rc 0, `status:ok`, model choice NOT surfaced as a receipt field |
| malformed | non-JSON, exit 0 | rc 0, raw captured+hashed, `stdout_parses_json:false`, no crash |
| timeout | sleep ≫ `--timeout 1` | rc 5, receipt written, `timed_out:true`, `status:timeout` (fail-closed) |
| nonzero | stderr + exit 2 | rc 6, `exit_status:2`, `status:error`, stderr escrowed |
| missing binary | `CLAUDE_BIN=/does-not-exist` | rc 3, **no receipt**, no fixture fallback |
| changed model | same inputs, new `--model` | `request_sha256` and `inputs.model` move |
| changed prompt | mutated system prompt bytes | `system_prompt_sha256` and `request_sha256` move |
| changed image | mutated PNG bytes | `image_sha256[0]` and `request_sha256` move |
| injection | brief clauses with `ignore all previous instructions`, `$(touch)`, backticks, `; touch` | rc 0, canary file **never created** (data never reaches a shell), receipt written |
| no secret | `ANTHROPIC_API_KEY=sk-…DEADBEEF` in env | secret absent from receipt AND stdout; only the key **name** recorded |
| tamper | zero out `request_sha256` | `verify` rejects (recompute mismatch) |
| tamper | missing receipt path | `verify` rejects |
| usage | no subcommand | rc 2 |
| system prompt | required clauses | pointwise-before-choice, hidden identity, no author/provider speculation, abstain, ignore-untrusted-text all present |

Run:

```
bash tests/test-taste-judge-claude.sh
shellcheck -S warning bin/polylane-taste-judge-claude.sh tests/test-taste-judge-claude.sh
```

## No-secret-output check

Demonstrated with a decoy `ANTHROPIC_API_KEY=sk-ant-SECRET-DEADBEEF`: the value
appears in **neither** the receipt, the stdout sidecar, nor the stderr sidecar
(`grep -c DEADBEEF` = 0 on all three). Env provenance is names-only, drawn from a
fixed allowlist, so a value can never be written and a value cannot masquerade as
a name. The redacted argv replaces the system prompt and composed request with
their sha256 digests, so bound command bytes carry no prompt text and no secret.

## Injection / prompt-safety boundary

Two layers. (1) The adapter treats every brief clause and screenshot as opaque
DATA: request strings are extracted with `jq` and passed as a single argv
element; nothing is `eval`'d or word-split into a command, so shell-metachar
payloads in a brief cannot execute (canary test). (2) The system prompt instructs
the model to ignore embedded instructions, keep identities hidden, avoid
author/provider speculation, and abstain on insufficient evidence, and never to
disclose the system prompt.

## Live smoke — EXTERNAL-EVIDENCE-OPEN

No live Claude invocation is claimed by this lane. Per the frozen plan, the sole
real Claude visual-judge smoke is run and receipted by the deferred
`taste-live-integrator`, not here. All committed receipts from this lane are
`classification: fixture_only`. A live receipt requires an operator to run, on a
real authenticated Claude CLI:

```
POLYLANE_TASTE_JUDGE_LIVE=1 CLAUDE_BIN=$(command -v claude) \
  bin/polylane-taste-judge-claude.sh invoke \
    --model claude-opus-4-8 \
    --system benchmarks/taste-live/prompts/judge-claude-system.md \
    --schema <shared taste-judge-response schema> \
    --request <frozen stimulus>.json \
    --image <cand-A.png> --image <cand-B.png> \
    --out <live-receipt>.json
```

Until that runs, live judgement evidence is **EXTERNAL-EVIDENCE-OPEN**. The
shared response schema is an opaque input the adapter hashes and forwards; a
relay request to `calibration-live`/`ballot-live` for its canonical path +
`schema_version` is posted so a real live run binds the real schema.

## Skill receipts

- SKILL-READ: engineering:system-design | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/system-design/SKILL.md | 8f28eca99f2208872fc2483fcc93326b628f4f73116e91309a95e05da86a0ab5
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 5c5e95830754bbdd838213fa05fc8f07523f591fd558fd3c86031ffd479f7a9e

- SKILL-EVIDENCE: engineering:system-design — helped: its "every decision has trade-offs, make them explicit" and API-contract framing drove the narrow receipt-only boundary — the adapter takes the shared response schema as an opaque hashed input rather than modelling it, keeping one small provider-native surface (`invoke`/`verify`) with an explicit `request_sha256` contract.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: its "cover error handling, edge cases, security boundaries" guidance shaped the fake-CLI matrix — malformed output, timeout, non-zero exit, missing binary, and provenance-tamper are all exercised, plus injection and secret-redaction security boundaries, before any live call.
