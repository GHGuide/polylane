# verify — lane `prompt-chain`, run `c44-defect-controls-20260819-a1`

Two frozen v3 implementation defects, implemented as controls in the prompt
tournament boundary and each proven by a new regression test. The contract JSON
and the v3 schemas were read only; nothing in
`docs/polylane/taste-certification/contracts/` was edited and no defect status
was flipped — both remain `OPEN` in
`EVIDENCE-CLAIM-REGISTRY.v3.json`.

This lane implements controls only. It mints, implies, and upgrades no taste or
human certification claim.

---

## Defect 1 — `c42b-unsafe-whole-document-prompt-dedupe`

**Boundary (quoted):** `prompt compilation`

**`required_v3_control` (quoted verbatim from `EVIDENCE-CLAIM-REGISTRY.v3.json`):**

> Deduplication is restricted to typed sections and cannot alter mandatory locked bytes.

### Terms the v3 schemas do not define

`grep` over `docs/polylane/taste-certification/contracts/*.schema.json` for
`typed`, `locked`, `section`, and `dedup` returns one key across all three
schemas: `locked_at` in `execution-v3.schema.json`. Neither "typed section" nor
"mandatory locked byte" appears anywhere in the v3 schemas, in
`CONTRACT-LOCK.v3.json`, or in `EVIDENCE-CLAIM-REGISTRY.v3.json`.

**Both terms are therefore defined narrowly inside
`bin/polylane-taste-prompts.sh` (header comment, lines 16–33) and nowhere else.
No contract language was invented, extended, or written into any contract
file.** The definitions are:

- **Typed section** — a fenced region of a compiled prompt. The fences are the
  `=== NAME ===` / `=== END NAME ===` pairs the frozen templates in
  `benchmarks/taste-live/prompts/` emit, plus the three inline quoted-data pairs
  `BRIEF-BEGIN`/`BRIEF-END`, `TASK-ORACLE-BEGIN`/`TASK-ORACLE-END`, and
  `REF-PACKET-BEGIN`/`REF-PACKET-END`.
- **Mandatory locked bytes** — every byte, fences included, of the five typed
  sections whose digest this compiler already freezes into `receipt.json`:
  the quoted brief (`brief.sha256`), the quoted task oracle (`oracle_sha256`),
  the quoted reference packet (`current.ref_packet_sha256`), the pinned
  baseline material (`baseline.material_sha256`), and the design lock
  (`current.design_lock_sha256`).

The definition is deliberately narrow: locked ⇔ a digest in the receipt already
binds those bytes. Nothing else was claimed to be locked.

### How the implementation satisfies the control

`bin/polylane-taste-prompts.sh`:

| Element | What it does |
|---|---|
| `locked_fence LINE` | Classifies a line as the `open` or `close` fence of a locked typed section. |
| `locked_bytes PROMPT` | Emits every mandatory locked byte in file order; returns rc 1 on an unbalanced fence so a truncated prompt cannot compare equal by accident. |
| `dedupe_typed PROMPT` | **The optimization pass.** The seen set resets at every fence, so a repeat is dropped only when its earlier twin sits in the *same* typed section. Locked typed sections are copied byte-for-byte and contribute nothing to any seen set. |
| `optimize` | No longer shells out to `polylane-promptopt.sh compile` — the whole-document deduplicator — for the delivered bytes. It now runs `dedupe_typed`, then proves three things: the delivered prompt still passes `promptopt check` at the 16000-byte budget, `promptopt compare` still returns WIN (no locked scalar changed), and `sha256(locked_bytes(compiled)) == sha256(locked_bytes(delivered))`. Any mismatch is a fail-closed `die` at rc 2. |

`polylane-promptopt.sh` was **not** edited — it is another lane's / the
integrator's boundary. The control is implemented entirely by removing this
boundary's dependency on the unsafe whole-document pass and guarding the result.

### Red-then-green evidence

**RED (before implementation)** — `bash tests/test-taste-prompt-integrity.sh`
against the unmodified `bin/polylane-taste-prompts.sh`:

```
FAIL dedupe-section-scoped-alpha-count — expected [2] got [0]
FAIL dedupe-skips-locked-section-entirely — expected [2] got [0]
FAIL dedupe-locked-line-survives-prose-collision — expected [1] got [0]
tests/test-taste-prompt-integrity.sh: line 72: locked_bytes: command not found
```

**RED, sharpened** — after the control landed, `optimize` was temporarily
reverted to `bash "$PROMPTOPT" compile "$prompt" > "$opt"` (whole-document
deduplication) and the suite re-run. Compilation itself now fails closed, and
the two named hazards reappear:

```
FAIL compile-happy-path — expected rc 0, got 2
FAIL baseline-repeated-brief-clause-survives — expected [2] got [1]
FAIL current-repeated-brief-clause-survives — expected [2] got [0]
FAIL baseline-collision-kept-in-brief — expected [1] got [0]
FAIL baseline-collision-kept-in-oracle — expected [1] got [0]
FAIL current-collision-kept-in-brief — expected [1] got [0]
FAIL current-collision-kept-in-oracle — expected [1] got [0]
FAIL baseline-brief-bytes-unaltered — expected [BRIEF-BEGIN id=pantry-planner …
FAIL current-packet-bytes-unaltered — expected [REF-PACKET-BEGIN sha256=24f03e…
FAIL current-design-lock-bytes-unaltered — expected [=== DESIGN LOCK ===
FAIL brief-digest-still-frozen — expected [efadccc3b850f30…] got []
```

The file was restored from a byte copy taken before the swap and re-verified.

**GREEN (after implementation)** — `bash tests/test-taste-prompt-integrity.sh`:

```
test-taste-prompt-integrity.sh: 34 pass, 0 fail
```

The two hazards the defect names are pinned by the fixture: the brief repeats
`- warn when an ingredient expires within three days`, and the line
` "states":["default","loading","empty","error","hover","focus"]}` appears
byte-identically in the brief and in the task oracle — two distinct locked typed
sections. Whole-document deduplication deletes the second copy of each; typed
-section deduplication keeps both. The synthetic unit fixture additionally pins
that deduplication is *restricted*, not *disabled*: `alpha` appears twice in one
section and once in another, and exactly two survive.

---

## Defect 2 — `c42b-optimized-prompt-deletion`

**Boundary (quoted):** `prompt promotion artifact retention`

**`required_v3_control` (quoted verbatim from `EVIDENCE-CLAIM-REGISTRY.v3.json`):**

> The frozen finalist prompt bytes and their source, compiled, delivered, and consumed receipt chain remain immutable and addressable after promotion.

### How the implementation satisfies the control

Before this change `compile` ended with
`rm -f "$out/baseline.optimized.md" "$out/current.optimized.md"` — the delivered
bytes were destroyed the moment the pair was promoted, and no consumed receipt
existed at all. That line is gone. In its place:

**Immutable, addressable store.** `retain OUT SRC` copies an artifact to
`<out>/artifacts/<sha256-of-its-own-bytes>` and `chmod 444`s it. The digest is
the filename, so an existing address already holds exactly those bytes; nothing
is ever overwritten and nothing is ever removed. Re-promoting the same spec into
the same directory is a no-op against the store.

**Four-stage chain.** `receipt.json` gains a `retention` object
(`store: "artifacts"`, `addressing: "sha256"`, `immutable: true`) whose `chain`
holds 11 `{stage, name, sha256}` entries:

| stage | entries |
|---|---|
| `source` | `spec.json`, `brief`, `task-oracle`, `reference-packet`, `baseline-builder.md`, `current-builder.md` |
| `compiled` | `baseline.md`, `current.md` — the frozen finalist prompt bytes |
| `delivered` | `baseline.optimized.md`, `current.optimized.md` |
| `consumed` | `consumed-receipt.json` |

**Consumed receipt.** `compile` writes
`<out>/consumed-receipt.json` (`taste-prompt-consumed/v1`) recording, per arm,
the delivered filename, its sha256, its exact byte count, `locked_scalars:
"unchanged"`, and the document-level `dedupe_scope: "typed-section"` /
`locked_bytes: "unaltered"` facts. This is honest about what was consumed *at
this boundary*: the optimization pass read the delivered bytes to prove no
locked scalar and no mandatory locked byte moved. Downstream stdin
delivery/consumption is the `execution-proof` lane's boundary and is not claimed
here.

`compile` asserts the chain post-condition itself: 11 entries, every `sha256`
matching `^[0-9a-f]{64}$`, and every address resolving to a file in the store —
otherwise it dies at rc 2.

**`verify OUT_DIR` enforces the control after promotion.** It now fails closed if:
the receipt does not declare a four-stage retention chain with all of
`["compiled","consumed","delivered","source"]`; any of `baseline.optimized.md`,
`current.optimized.md`, `consumed-receipt.json` is missing or a symlink; any
chain address is missing; any retained artifact's bytes no longer hash to its own
address; any promoted file no longer matches its retained address; the consumed
receipt is invalid or does not bind the delivered digests; or the delivered bytes
are not reproducible from the compiled prompt by `dedupe_typed`.

### Red-then-green evidence

**RED (before implementation)** — `bash tests/test-taste-artifact-retention.sh`
against the unmodified script (abridged; the run aborted at the store path
because `<out>/artifacts/` did not exist):

```
FAIL retention-declared — expected rc 0, got 1
FAIL retention-stage-set — expected [["compiled","consumed","delivered","source"]] got []
FAIL chain-source-spec — expected [f5823a5840bbaa1559f41cce3b28466c9b863eaa201407f0f4e8bc0f1e97a6f8] got []
FAIL chain-source-brief — expected [a4c88d88bce9b5716497f03562c0c5a9981d34540936b3d4878f9b1199cb2542] got []
FAIL chain-source-oracle — expected [91f09d2b9b267af3a4832b7f2cef640c67206708740a4129b5d105c3efcc412d] got []
FAIL chain-source-packet — expected [491467863da5d8047c880d000e6e97c80d92279ea49e613e9b20a4c7d7c60657] got []
FAIL chain-source-baseline-template — expected [c5aded580185dbfbb676b738a5d918a59a4c89d6bd8fc46a80c865a05a920495] got []
FAIL chain-source-current-template — expected [7bdfef352f56bfe84c318f0377b92c84eb8c664a1b0d0b99ff2a13e0eef4949e] got []
FAIL chain-compiled-baseline — expected [1583abd0f2506b06edfc2176e654bdec22d8a6d77c5bfc23b45d2cda937127ee] got []
FAIL chain-compiled-current — expected [b5072df3ba1761333d5b0994fbba4bad9afa0375083c36aa81bdcef73856111c] got []
FAIL chain-delivered-stage — expected [delivered] got []
FAIL chain-consumed-stage — expected [consumed] got []
FAIL consumed-schema — expected rc 0, got 2
FAIL verify-detects-deleted-retained-artifact — expected non-zero rc, got 0
FAIL verify-detects-deleted-delivered-prompt — expected non-zero rc, got 0
shasum: …/out/baseline.optimized.md: No such file or directory
shasum: …/out/current.optimized.md: No such file or directory
shasum: …/out/consumed-receipt.json: No such file or directory
tests/…/mutated/artifacts/: No such file or directory
```

`shasum: …/current.optimized.md: No such file or directory` is the defect itself:
the delivered prompt had been deleted at promotion.

**GREEN (after implementation)** — `bash tests/test-taste-artifact-retention.sh`:

```
test-taste-artifact-retention.sh: 42 pass, 0 fail
```

---

## Fresh counts — every command run in this lane

Run from `/Users/leonardo/Downloads/polylane/.polylane/worktrees/c44-prompt-chain`
after the final edit, in one session:

| command | result |
|---|---|
| `bash -n bin/polylane-taste-prompts.sh` | rc 0 |
| `bash tests/test-taste-prompt-integrity.sh` | **34 pass, 0 fail** |
| `bash tests/test-taste-artifact-retention.sh` | **42 pass, 0 fail** |
| `bash tests/test-taste-prompts-live.sh` | **93 pass, 0 fail** (pre-existing neighbour suite, unchanged) |
| `shellcheck -S warning bin/polylane-taste-prompts.sh tests/test-taste-prompt-integrity.sh tests/test-taste-artifact-retention.sh` | rc 0, no output |
| `git diff --check` | clean |

`tests/test-taste-prompts-live.sh` is the only pre-existing suite that exercises
`bin/polylane-taste-prompts.sh` (`grep -rn taste-prompts bin tests assets`
returns that file and the cycle plans only). It is not owned by this lane and was
not edited; it stays at 93/0.

`tests/run.sh` and doctor rehearsals were **not** run — the integrator and
coordinator own those boundaries.

## Limitations

- **"Typed section" and "mandatory locked byte" are local definitions.** The v3
  schemas define neither. They are defined in the script header and pinned by
  `tests/test-taste-prompt-integrity.sh`. If a later contract version defines
  either term differently, this implementation must be re-reconciled against it.
  Nothing was written into any contract file to make these definitions
  authoritative.
- **On today's frozen templates the optimization pass is byte-neutral.** With
  `benchmarks/taste-live/prompts/*.md` and a realistic spec, delivered bytes
  equal compiled bytes (baseline 4833, current 10861 in the integrity fixture):
  the templates contain no in-section duplicate and no trimmable whitespace. The
  integration assertion is therefore `delivered ≤ compiled`
  (`*-optimization-never-grows`); that deduplication still *functions* and is
  correctly section-scoped is proven by the synthetic unit fixture, not by the
  real templates.
- **The `consumed` stage covers this boundary only.** It receipts the
  compile-time consumption of the delivered bytes by the optimization/comparison
  pass. Delivered-vs-consumed stdin proof across the execution contract is
  `c42b-missing-consumed-stdin-proof`, owned by the `execution-proof` lane; this
  lane makes no claim about it.
- **Immutability is filesystem-level, not cryptographic-chain-level.** Retained
  artifacts are `chmod 444` and content-addressed, and `verify` recomputes every
  address, so silent mutation and deletion are both detected. A privileged actor
  who rewrites both the store *and* `receipt.json` is out of scope at this
  boundary.
- **Defect statuses stay `OPEN`.** Flipping them re-freezes a hashed contract and
  is the integrator's/coordinator's decision once every c44 control is in one
  tree.
- No network, no installs, no live provider calls, no external evidence of any
  kind was used.

## Skill receipts

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015
SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: superpowers:test-driven-development — helped: its "Verify RED — watch it fail / test passes immediately means you're testing existing behaviour" rule caught a dead assertion. The first green run showed `baseline-collision-kept-in-brief — expected [1] got [0]`, and chasing that failure exposed that my grep needle `|$COLLISION` was one space short of what `quote_file`'s `sed 's/^/| /'` actually emits. The same wrong needle was in the tamper step, so `verify-detects-locked-byte-edit` had been passing vacuously against an unmodified file — a test that would never have caught a regression. Both were fixed before the suite went green.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: its regression-test pattern ("Write → Run (pass) → Revert fix → Run MUST FAIL → Restore → Run pass") drove the sharpened red above. The original red only proved `dedupe_typed`/`locked_bytes` did not exist yet — a missing-symbol failure, not proof the test catches whole-document deduplication. Swapping `optimize` back to `promptopt compile`, re-running, and restoring from a byte copy produced the real failing output (`current-repeated-brief-clause-survives — expected [2] got [0]`) that this document now records.
