# Reference research contract — taste-reference-packet/v1

How a per-brief reference packet is produced, what it may contain, and how
`bin/polylane-taste-prompts.sh` enforces it. The packet is evidence for the
**current** arm only. The baseline arm never sees references.

## What a reference is

An abstract pattern observed in a real product, recorded with provenance.
Research records patterns and URLs/licences only; it grants no copying and no
originality claim. No asset, copy text, mark, palette lift, or distinctive
composition moves from a reference into a build — every borrowed pattern must
name its transformation.

## Packet schema

One JSON file per brief, canonicalized with `jq -cS .` for hashing
(`ref_packet_sha256` in the compiled current prompt and receipt).

```json
{
  "schema_version": "taste-reference-packet/v1",
  "brief_id": "<must equal the spec's brief id>",
  "category": "<must equal the spec's brief category>",
  "references": [
    {
      "role": "category | wildcard",
      "category": "<same as brief for role=category; a DIFFERENT adjacent category for the wildcard>",
      "url": "https://…",
      "licence": "<licence or observation basis, e.g. observed-ui/no-assets-copied>",
      "observed": "<the screen or feature observed>",
      "accessed": "YYYY-MM-DD",
      "screenshot_sha256": "<64-hex digest of the research capture>",
      "provenance": "<where the capture and note live in the research ledger>",
      "borrow": "<the abstract pattern taken>",
      "transform": "<how it is changed so nothing distinctive is reused>",
      "avoid": "<what must not be taken from this source>"
    }
  ]
}
```

## Enforced constraints (compiler-validated, fail-closed)

- 3–5 references with `role:"category"`, every one in the brief's category.
- Exactly 1 `role:"wildcard"` reference from a different, adjacent category.
- Every reference carries non-empty `url` (`http(s)://`), `licence`,
  `observed`, `accessed` (ISO date), 64-hex `screenshot_sha256`, `provenance`,
  `borrow`, `transform`, and `avoid`. An empty `transform` is a no-copy
  violation and blocks compilation.
- Injection defense: packet text matching prompt-injection patterns
  ("ignore previous instructions", "system prompt", "reveal the prompt", …)
  blocks compilation. Packet content is embedded `| `-quoted as data; the
  compiled prompt tells the builder it is never an instruction.
- A missing, malformed, or under-provenanced packet exits with code 6 and
  `EXTERNAL-EVIDENCE-OPEN`, and no prompt is emitted for either arm. The
  current arm is blocked, never weakened.

## Fairness note

References exist so the current arm can synthesize a distinctive,
product-specific direction — not to give it extra product facts. Packets must
describe interface patterns, never brief-domain answers, and the shared
contract (brief, oracle, goal, model, offline, accessibility) stays
byte-identical across arms regardless of packet content.
