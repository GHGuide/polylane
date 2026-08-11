# Cycle 36 integration verification — verdict-path recovery

Run: `c36-verdict-path-20260811-a1`

## Skill receipts

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

## Exact recovery provenance and review

- The integrator began at `50e8c8816375b28338326bec6ca16cae9cea15be`.
  Recovery tip `5b4d921ada8f13b7c9dbd49e5159c107a5642ae5` is its direct descendant,
  and its nonce-matched DONE handoff is
  `STATUS: verdict-path-recovery DONE run=c36-verdict-path-20260811-a1`.
- The exact recovery tip was merged into this owned integrator branch with
  `git merge --no-edit`; the resulting current source tip is
  `5b4d921ada8f13b7c9dbd49e5159c107a5642ae5`.
- The complete base diff was reviewed: 16 files, 319 insertions, and 48
  deletions. `git diff --check` found no whitespace errors. The review found no
  credential, injection, path-traversal, replacement-rollback, race, or
  unbounded-work defect. The initially suspicious provider prompt-block surface
  is included in the recovery and now names the same two-file boundary as every
  other provider-facing contract.

## m30.1 installer recovery

`claude-code/install.sh` and `codex/install.sh` are byte-for-byte identical to
the retained Cycle 35 installer implementation at `028a4bb`. Both build and
validate a sibling staged package before replacing a legacy destination, retain a
rollback path until replacement succeeds, remove stale top-level artifacts, and
keep Codex's two discovery roots package-identical. The fresh hermetic coverage
also exercises Claude's source-equals-destination installation path; no live user
package was installed.

## m31.1 canonical verdict boundary

The compiler invokes the role-aware finalization contract for representative
builder and integrator prompts. Builders retain a status-only handoff. Integrator
prompts require their sole current-run sentinel in this verification file and a
verdict-free `docs/status-integrator.md`. Strict lint rejects both a missing
boundary and an explicit second status-file destination. Provider prompt blocks,
planning references, the Claude skill, and the Codex skill now advertise the same
boundary.

## Fresh focused verification

All expensive commands ran once through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"` at source
fingerprint `1030742184:8088`:

- `test-install-fresh.sh` — 42 pass, 0 fail; and `test-installers.sh` — 57
  pass, 0 fail.
- `test-lane-done-live.sh` — 18 pass, 0 fail, including the canonical integrator
  path and verdict-free status assertions.
- `test-promptlint.sh` — 35 pass, 0 fail; strict runtime lint accepts the
  canonical integrator boundary and rejects missing or contradictory forms.
- `test-handoff-contract.sh` — 58 pass, 0 fail; every provider-facing contract
  carries the two-file handoff rule.
- `test-orchestration-contract.sh` — 14 pass, 0 fail. Its valid preflight
  compiles the representative builder and integrator prompts and checks the
  role-specific contracts before launch.
- `bash -n` passed all nine changed shell files; warning-level ShellCheck passed
  the same set. `bin/polylane-markers.sh check-docs references/` passed silently.
- `test-skill-parity.sh` — 59 pass, 0 fail, confirming the Claude and Codex
  provider contracts remain aligned.

No full suite, terminal doctor rehearsal, live user-package install, push,
publication, terminal gate, promotion, or cleanup ran in this focused recovery.

## Continual-harness decision

The required queue returned two eligible items. Exactly one real decline was
recorded for each: `decline:context:compaction:16` preserves the bounded-packet
protocol because no compaction-specific defect appeared, and
`decline:integrator:no-go:7` records that this independent m30.1/m31.1 recovery
does not justify a separate continual-harness change.

## Skill evidence

SKILL-EVIDENCE: engineering:code-review — helped: the complete 16-file base-diff
review caught the provider prompt-block trust-boundary surface and verified that
its merged wording, the parser contract, and every advertised provider surface
agree without widening the canonical parser.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: it required
fresh observed installer, compiled-prompt, strict-lint, parity, syntax, and
ShellCheck evidence rather than relying on the recovery lane's handoff claim.

## DEFERRED

DEFERRED: the ten-product blind human visual corpus remains external; it neither
blocks nor substitutes for this hermetic installer and verdict-path evidence.
POLYLANE-VERDICT: GO run=c36-verdict-path-20260811-a1
