# Verify — judge-codex (Cycle 40, run c40-live-harness-20260812-a3)

Lane goal: an isolated, noninteractive **Codex** visual-judge adapter that supplies
exact ordered images plus a frozen structured request to the native Codex CLI,
preserves the raw model output verbatim, and emits a provenance record only. It
never decides eligibility, a winner, or certification — parsing the reply is a
downstream (ballot) concern, forbidden here.

## What changed (owned paths only)

- `bin/polylane-taste-judge-codex.sh` — NEW adapter. Builds a native `codex exec`
  argv with explicit model/effort, config + rules isolation, ephemeral state,
  read-only sandbox, ordered `--image` inputs, `--output-schema`, and an
  `-o` output-last-message file; runs it under a portable pure-bash timeout
  watchdog; emits one `taste-judge-codex-invocation/v1` provenance record binding
  CLI binary/version/argv/command, model/config, prompt/schema/brief/image content
  hashes, raw stdout/stderr/output-last-message (verbatim, via `jq --rawfile`),
  exit code, timing, and environment (paths only — never secrets). Never parses a
  winner. `fingerprint sha256 75173d63123935213e2b667436f0927d8019d2e5d6666565ba7dfab92ea6765f`.
- `benchmarks/taste-live/prompts/judge-codex-system.md` — NEW frozen judge system
  prompt: pointwise image-grounded observations first, then blind mirrored
  comparison; no author/provider/tool/model identity guesses; screenshot text
  treated as untrusted data (never obeyed); explicit abstention; schema-only
  output. `fingerprint sha256 f4495f70549c1bc4af510b6761f9f6da5fce358a5d81ac122fca834f85c4c853`.
- `tests/test-taste-judge-codex.sh` — NEW adversarial contract test driven by a
  FAKE codex binary. `fingerprint sha256 7323967e1b6d81e1c2a53b93ff8e515cb768d93b45c3d6085c2eab0d1f54a6ee`.

## Command outputs

```
tests/test-taste-judge-codex.sh:                      65 pass, 0 fail
shellcheck -S warning bin/... tests/...  (check-cache): PASS (clean)
```

`bin/polylane-check.sh "$PWD/.polylane/check-cache/judge-codex"` fronts the
ShellCheck run so an unchanged tree does not reburn the check.

## Exact native invocation (recorded identical to what is executed)

```
codex exec --ephemeral --ignore-user-config --ignore-rules \
  --sandbox read-only --skip-git-repo-check \
  -C <ephemeral-run-root> -o <last-message-file> --output-schema <schema.json> \
  --color never --model <gpt-model-id> \
  -c model_reasoning_effort=<effort> -c approval_policy=never \
  --image <A.png> --image <B.png> -
# frozen system prompt + <structured-brief> + fixed image-order note piped on stdin (`-`)
```

Isolation mapping to the HARD CONTRACT:

| Requirement            | Native flag / mechanism                                   |
|------------------------|-----------------------------------------------------------|
| explicit model         | `--model <id>` (Claude ids + slash commands rejected)     |
| explicit reasoning     | `-c model_reasoning_effort=<effort>`                      |
| config isolation       | `--ignore-user-config` (no `$CODEX_HOME/config.toml`)     |
| rules isolation        | `--ignore-rules` (no user/project `.rules`, no AGENTS/CLAUDE assumption) |
| ephemeral state        | `--ephemeral` (no persisted session files)               |
| non-interactive/no-approve | `-c approval_policy=never`, read-only `--sandbox`     |
| image inputs, ordered  | repeated `--image` in exact caller order                 |
| output schema          | `--output-schema <file>`                                 |
| output file            | `-o/--output-last-message <file>`                        |
| prompt delivery        | stdin `-` (brief embedded as inert data, no shell expansion) |

Every one of these tokens is asserted present in the recorded `cli.argv`
(`argv-has-*` assertions).

## Fake-CLI attack matrix (fixture_only — see EXTERNAL-EVIDENCE)

All rows run against a throwaway fake `codex` binary under `env -i`; per
EXTERNAL-EVIDENCE these outputs are fixture-only and can never be a live receipt.

| Attack / case          | Expectation                                                        | Assertions |
|------------------------|--------------------------------------------------------------------|-----------|
| success                | valid record; raw output preserved verbatim; no winner/eligible/certified key | `success-*`, `success-no-winner-key` |
| abstain                | abstention preserved verbatim; adapter adds no choice of its own    | `abstain-*` |
| malformed output       | non-JSON preserved byte-for-byte; record still valid JSON; **no shell eval** (`$(touch INJ)` inert) | `malformed-*` |
| timeout                | watchdog kills; `timed_out=true`, `exit_code=124`                   | `timeout-*` |
| nonzero exit           | codex exit 7 captured; stderr preserved; adapter still returns 0    | `nonzero-*` |
| missing binary         | adapter returns 3 but STILL writes a record (`available:false`, exit 127) | `missing-*` |
| model drift (Claude)   | `claude-opus-4-8` and `/model gpt-5` rejected fail-closed (rc 2)    | `claude-model-rejected-rc`, `slash-model-rejected-rc` |
| schema drift           | record binds the actual schema sha; nothing silently substituted   | `schema-drift-*` |
| image drift (order)    | reversed input order preserved in `images[]` and in argv           | `imgorder-*` |
| prompt injection       | hostile brief bound as data (sha preserved), never shell-expanded (`$(touch PWNED)` inert), frozen prompt sha unchanged, no injected winner adopted | `inject-*` |

## Provider-syntax proof (no Claude leak)

- The adapter's model guard rejects any `claude*` id or `/`-prefixed slash
  command before an argv is ever built (`die 2`). Proven by
  `claude-model-rejected-rc` and `slash-model-rejected-rc`.
- The recorded `cli.argv` contains no `claude`, no Claude CLI flag
  (`--print`, `--permission-mode`, `--no-session-persistence`, `--bare`), and no
  bare `/command` token — only native `codex exec …`. Proven by
  `argv-no-claude-syntax` and `argv-no-slash-commands`. (The regex matches real
  Claude tokens, not the repo/tmp path substring `polylane`.)

## No-secret-output check

`CODEX_API_KEY=TOPSECRET-DO-NOT-LEAK-9x8y7z` is set on every fake run; the
emitted record never contains it (`no-secret-*` over success/abstain/nonzero/
inject). The record's `environment` block carries only the CODEX_HOME path, the
binary directory, and `uname` — never environment contents. The live smoke
record was additionally grepped for `sk-/access_token/api_key/id_token/
refresh_token/bearer`: **0 matches**, even though auth flowed through
`CODEX_HOME=$HOME/.codex`.

## Live smoke — REAL Codex CLI (clearly separated from fixtures)

A single bounded live invocation against the actually-installed **codex-cli
0.144.4** (logged in via ChatGPT), two generated 1×1 PNG swatches, the real
frozen prompt + a real output schema:

- First attempt with `gpt-5-codex` → the real CLI ran and the adapter faithfully
  recorded exit 1 with the real 400 error: *"The 'gpt-5-codex' model is not
  supported when using Codex with a ChatGPT account."* This is itself a **live
  receipt** — the real binary executed and its stderr was preserved verbatim.
- Retry with the account model `gpt-5.6-sol` → **exit 0, 24 s**, an 852-byte
  schema-conforming reply written to the output-last-message file:

```
version=codex-cli 0.144.4  model=gpt-5.6-sol  exit=0  timed_out=false
provenance_only=true  has_top_winner_key=false  secret-leak matches=0
raw.output_last_message (verbatim, NOT parsed by the adapter):
  {"pointwise":[{"candidate":"A",...},{"candidate":"B",...}],
   "comparison":{"choice":"B","reason":"...visible fills..."}}
```

The stderr of the successful run shows the frozen prompt and the fixed image-order
line ("image 1 = candidate A, image 2 = candidate B") were delivered intact. The
adapter recorded the `"choice":"B"` only as inert raw bytes — it made no eligibility,
winner, or certification decision. The live smoke artifacts live under the
gitignored `.polylane/smoke-judge-codex/` and are not committed.

**fixture vs live distinction:** the record does not self-assert liveness; it
records `cli.binary` + `cli.version` so a reader can tell. A `fake-codex 9.9.9`
binary → fixture_only; the real `codex-cli 0.144.4` above → live receipt.

## SKILL evidence

SKILL-READ: engineering:system-design | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/system-design/SKILL.md | 2894978985-1310
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-EVIDENCE: engineering:system-design — helped: drove the explicit
requirements→contract→trade-off pass. The "make trade-offs explicit" step
produced the provider-neutral record schema (`taste-judge-codex-invocation/v1`)
and the deliberate boundary that the adapter binds+records but never parses a
winner, keeping the ballot/winner concern out of this lane. The isolation-flag
table above is the "API contract" deliverable the skill asks for.
SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped the attack matrix
around business-critical + security boundaries (injection, no-secret, model
drift, timeout) rather than trivial coverage. The pyramid guidance kept this a
single focused contract suite over a fake binary (fast, deterministic) with one
real live smoke on top for confidence — exactly its "few E2E / many focused"
split. It also flagged the timeout + missing-binary provenance cases the launch
called out.

## Ponytail self-review (of this diff)

- Reused the house judge pattern from `polylane-skill-blind-judge.sh` (same
  `exec --ephemeral --ignore-user-config --ignore-rules --sandbox read-only
  --skip-git-repo-check -C … -o …` spine) instead of inventing a new invocation
  shape — smaller, consistent, correct against real codex 0.144.4.
- Timeout is a pure-bash watchdog (no GNU `timeout` dependency — confirmed absent
  on this macOS host, rc 127). Marked with the ceiling in a `ponytail:` comment.
- No abstraction with one implementation, no config for constants; the record is
  one `jq -n` call. `argv` built once and both executed and recorded, so the
  proof cannot drift from the run.
- Verdict: `Lean already. Ship.`

## Boundary honored

Only owned paths were written: the adapter, the frozen prompt, this suite, this
verify doc, and the status file. No Claude adapter, shared runner/parser, ballot,
calibration, or certificate file was touched. Relay carried no judge-codex
request at start; the shared response schema is an input (bound by sha), not
authored here.
