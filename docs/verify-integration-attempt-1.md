# Cycle 13 integration verification

Run: `c13-perfection-20260808` on `lane/c13-integrator`.

## Integrated tips and cross-lane repairs

All current builder tips are ancestors of this branch and merged cleanly:

| Lane | Tip | Integrator merge |
| --- | --- | --- |
| model policy | `a6ca9885f138e0f8d527b234d7132f2403f24662` | `32671e0` |
| skill intelligence | `822a7659d8519ab8d973c891331f372bd5415e12` | `d035768` |
| prompt compiler | `c0d8ca11723c556f94ec1cd50a27c402e9db946e` | `2149afb` |
| lifecycle hooks | `1cf08fd585c285938d1f7f6051ae515e90f3b122` | `6f1531a` |

The runner compiles launch-only prompt copies before panes exist, checks their
frozen contracts again, and leaves authored prompts untouched. The compiler
also accepts the historical inline `OWN: … FORBIDDEN: …` boundary. The live
rehearsal fixtures now include the required `VERIFY:` contract and isolate
their temporary tmux server from an inherited client socket; the latter cannot
be exercised on this host because it denies new UNIX sockets.

Model-policy refresh now restores the prior runtime setting atomically if a
new policy is invalid. Legacy manifests with explicit custom models/effort and
no intensity or availability list retain their existing behavior; declared
availability still receives strict validation.

## Executed evidence

Focused acceptance, through the required cache:

```sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- \
  bash bin/polylane-memory.sh "$PWD/docs/polylane/max-state.json" check-accept \
  --cycle 13 --targets m13.1,m13.2,m13.3,m13.4,m13.5 --focused
```

All five focused acceptance records passed. The hermetic vague-brief journey
in `bash tests/test-cycle-13-contract.sh` passed 38/0: recommended discovery
answers, plan/manifest, both providers' policy/skill/prompt/hook contracts,
simulated GO close, emergent questions, and `CONTINUE` routing. Focused
installer and semantic-parity checks passed 34/0 and 43/0 respectively.

The current terminal command was run after the final source repair, without a
stale source cache result:

```sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- \
  env POLYLANE_MIN_DISK_GB=0 bash bin/polylane-memory.sh \
  "$PWD/docs/polylane/max-state.json" check-accept --cycle 13 \
  --targets m13.5 --only-terminal
```

Its frozen command was:

```sh
POLYLANE_MIN_DISK_GB=0 tests/run.sh && shellcheck -S warning bin/*.sh && \
  bash tests/test-skill-parity.sh && \
  POLYLANE_MIN_DISK_GB=0 bin/polylane-doctor.sh --rehearse
```

Results before the live rehearsal: full suite **1778 pass, 0 fail, 96 test
files**; full `bin/*.sh` ShellCheck clean; skill parity **43 pass, 0 fail**.
The GO rehearsal then failed with `ready=0 promoted=0 terminal_gates=0
cleaned=0 leaks=1` because tmux reported `Operation not permitted` creating
its UNIX socket under the managed host's temporary directory. The doctor stops
at that failed GO case, so its NO-GO case was not started and is not claimed.
This is a real terminal failure, so c30–c34 are implemented and
focused-verified but their terminal close is intentionally not claimed.

## Observable policy, prompt, skill, and hook evidence

Policy examples are emitted before launch. A Claude balanced manifest resolves
builder `claude-sonnet-5/high`; mechanical is clamped to medium; security to
`claude-opus-4-8/high`; and integrator to `claude-fable-5/xhigh`. With Codex
performance plus a CLI override, builder resolves `gpt-5.6-sol/high`,
mechanical `gpt-5.6-terra/medium`, security `gpt-5.6-terra/high`, and
integrator `gpt-5.6-sol/xhigh`.

The frozen prompt fixture changed from 991 bytes / 331 compatibility estimate
to 957 bytes / 319 after compiling: one repeated 34-byte non-contract line
was removed and the contracts compared equal. These are local deterministic
estimates, not provider token or quality claims.

Metadata recommendations enter planning/scouting only; builder prompts receive
only selected kits. `use-audit` records helped, unused, or hurt receipts under
`docs/polylane/skill-use/<run>/<lane>.json` and the outcome ledger; a missing
verify file is explicitly `unused`, not inferred helped. Project admission is
still authorization, quarantine, audit, measurable benchmark, pin, install,
and rollback gated.

Both installed packages carry project-scoped hook fragments. The Codex
SessionStart output includes `hookSpecificOutput.additionalContext`; the stop
path emits a structured `block` decision requesting one continuation when the
exact marker/evidence is absent. Claude emits the same capped context in
`systemMessage`. Hooks remain optional defense in depth; the supervisor stays
the runtime authority.

## Lifecycle, refinements, and external boundary

The durable worker inbox was read and all historical acknowledgements were
recorded. Eligible refinement decisions are explicit in
`docs/polylane/harness/refinement-decisions.jsonl`: declined
`context:compaction:7` (no demonstrated context-loss regression) and
`integrator:no-go:2` (historical c12 event, no new local defect). No promotion
was claimed from either.

`c28`, the historical ten-product rendered visual comparison, remains external
and open. It does not block independent cycle-13 engineering and has not been
converted to PASS by prose. Because the terminal criterion remains open, the
current mechanical route is `CONTINUE m13.1`; it is a retry route, not evidence
that the terminal or external boundary has passed.

## Skill-evidence scores

SKILL-EVIDENCE: polylane — helped: used the context packet, durable inbox,
refinement queue/decisions, cache routing, and cycle routing mechanics.

SKILL-EVIDENCE: engineering:code-review — unused: no resolved kit path was
provided for this integrator run.

SKILL-EVIDENCE: superpowers:verification-before-completion — unused: no
resolved kit path was provided for this integrator run.

SKILL-EVIDENCE: operations:risk-assessment — unused: no resolved kit path was
provided for this integrator run.

SKILL-EVIDENCE: engineering:testing-strategy — unused: no resolved kit path
was provided for this integrator run.

POLYLANE-VERDICT: NO-GO run=c13-perfection-20260808
