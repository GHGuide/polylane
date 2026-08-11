# Cycle 32 integration verification

Run: `c32-contract-drift-20260811-a1`

## Exact-tip provenance

- Frozen base was `03421216f79131adb286b428911afe184c7bc8fe` on
  `candidate/c32-contract-drift`; Cycle 31 remains NO-GO.
- Builder repair commit `bf3d0c299840120a841b01682d249b9c7b4a62e0` and
  current-run DONE status commit were present before integration. The exact final
  builder tip `712e2f898cf4e21b202c8af6e6990455bffc5e06` was merged as
  `63768426036f99c7c2b3bbee78c0ebc8af469c0f`.
- The complete base-to-merge diff contains only four fixture expectation edits,
  one prompt sentence, and builder evidence/status. `git diff --name-only -- bin`
  returned no path, so production Bash is unchanged.
- Integration evidence and post-cycle records were committed as
  `febf429b9ae567f896ce8d1f231f04047a00666b`. Before this final marker
  transaction, `git status --short` contained only runner-owned
  `.polylane-prompt.txt`.

The physical source worktree is
`/Users/leonardo/Downloads/polylane-c32/.polylane/worktrees/c32-integrator`.
The coordination/control root is
`/Users/leonardo/Downloads/polylane-c32/.polylane/runtime/c32-contract-drift-20260811-a1`.
Source review and checks stayed in the former; relay, inbox, and refinement state
stayed in the latter.

## Independent diff review

No correctness, security, performance, or maintainability blocker was found.
The repair changes assertions and prompt clarity without weakening runtime:

- `load_manifest` still passes the integrator worktree and every lane worktree
  through `abs_worktree`, then builds each `LANE_POLLSPEC` from that canonical
  lane value.
- `int-worktree`, `lane0-worktree`, `lane0-pollspec`, and `lane1-pollspec` now
  expect paths rooted at the fixture project's absolute `$PROJ`; no assertion
  substitutes the integrator cwd or a hard-coded host path.
- Block G contains `only coordinator-owned terminal checks remain` exactly once.
  `superpowers:using-superpowers`, the frozen generic skill stack sentinel, is
  absent. The terminal boundary remains coordinator-owned.
- `references/prompt-blocks.md` is 18,995 bytes, up from 18,948: a 47-byte
  addition. The 19/19 prompt-economy contract and 14/14 orchestration contract,
  including over-budget rejection, prove that the compact prompt remains inside
  its frozen mechanical admission contract.

The change introduces no executable path, loop, input parser, external action,
credential flow, or mutable runtime state.

## Focused results

The frozen matrix ran once through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"` after exact-tip
merge and complete-diff review:

- `bash tests/test-load-manifest.sh` — 30 pass, 0 fail;
- `bash tests/test-prompt-economy.sh` — 19 pass, 0 fail;
- `bash tests/test-abs-prompt.sh` — 6 pass, 0 fail;
- `bash tests/test-orchestration-contract.sh` — 14 pass, 0 fail.

The four retained logs are
`.polylane/check-cache/integrator/3699034007-122.output`,
`2881796738-123.output`, `1942568877-119.output`, and
`2790844805-131.output`; each records `CHECK-CACHE: PASS` for source
`3743065850:7384`. Cached `git diff --check` passed, and after the owned evidence
was staged, cached `git diff --cached --check` passed at source
`950915092:17234`. The failed first whitespace attempt exposed and removed four
extra EOF blank lines before commit; it is not counted as product acceptance.

No terminal suite, complete ShellCheck, installer, doctor rehearsal, promotion,
deployment, publication, push, or external action ran. The refinement queue
returned `[]`, so there was no eligible item to propose or decline.

## Canonical telemetry

The canonical file
`/Users/leonardo/Downloads/polylane-c32/docs/polylane/run-stats.json` records:

- `terminal-contract-repair`: one launch, zero restarts;
- `integrator`: one launch, zero restarts;
- zero supervisor restarts;
- zero terminal gates.

The run ID is exact. Cleanup remains runner-owned and token state remains unknown;
neither is falsely presented as completed or zero. The final relay and durable
inbox contained no request addressed to the integrator.

## Skill receipts

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: engineering:code-review — helped: the structured review tied all
four assertions to `$PROJ`, checked the still-canonical runtime path flow, and
confirmed that the prompt-only sentence does not weaken terminal ownership.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: the final
gate required exact-tip ancestry, fresh cached counts, prompt-byte and negative
contracts, canonical zero-restart/zero-terminal telemetry, and a clean owned tree
before permitting GO.

## Final verdict

The two frozen Cycle 32 contract drifts are repaired with focused local proof and
the required zero-restart, zero-terminal runtime. This verdict does not rewrite
Cycle 31's terminal NO-GO and does not certify older autonomous subgoals. Fresh
Cycle 33 owns terminal certification.

POLYLANE-VERDICT: GO run=c32-contract-drift-20260811-a1
