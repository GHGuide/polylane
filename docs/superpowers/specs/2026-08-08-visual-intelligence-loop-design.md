# Visual Intelligence Loop

## Objective

When Polylane builds or materially changes a user interface, it must produce a
distinctive, product-specific result rather than a generic AI-generated design.
The workflow must research real products, synthesize an original direction,
acquire only proven safe skills, preserve its decisions on disk, and block
promotion until visual evidence passes independent review.

## Pipeline

1. Detect UI work from lane names, activities, and owned paths.
2. Research three to five relevant live products plus one creative wildcard.
3. Capture URLs and desktop/mobile evidence. Extract hierarchy, typography,
   palette behavior, spatial rhythm, interaction patterns, motion, and signature
   ideas into a multi-source reference packet.
4. Generate product-native, expressive, and wildcard directions. A council
   selects one unless the alternatives imply fundamentally different brands.
5. Freeze the selected direction as a visual contract before builders edit UI.
6. Select the smallest relevant installed skill kit. If a capability is missing,
   discover candidates, quarantine them, statically audit them, run a bounded
   with/without benchmark, and install only a passing candidate at project scope,
   pinned to an immutable source revision.
7. Build staged evidence: design system and representative surface first, then
   desktop/mobile plus empty, loading, error, hover, focus, and one complete flow.
8. Run three isolated visual lenses: originality/anti-slop,
   product-reference fit/polish, and accessibility/responsive usability.
9. A failure produces region-specific structured repairs. Permit at most two
   repair rounds, then halt without promotion.
10. Certify the pipeline itself on a diverse old-versus-new prompt corpus using
    anonymized screenshots. Promotion requires at least a 70% decisive win rate
    in creative distinction and polish with no accessibility regression.

## Durable artifacts

- `docs/polylane/design/references.json`
- `docs/polylane/design/VISUAL-BRIEF.md`
- `docs/polylane/design/DESIGN-DECISION.md`
- `docs/polylane/design/SKILL-LOCK.json`
- `docs/polylane/design/visual-verdict.json`

The reference packet records a `borrow / transform / avoid` matrix. It may learn
principles and interaction logic, but it must not reproduce a source's exact
layout, copy, logos, illustrations, or branded assets. No one source may dominate
the selected direction.

## Skill trust boundary

Remote skill content is untrusted until admitted. Discovery is read-only. The
auditor rejects missing license/source identity, unresolved revisions, symlinks,
binaries, install hooks, secrets, prompt-injection instructions, destructive
commands, broad host writes, or unexplained network execution. Approved content
is copied into a temporary quarantine and evaluated without credentials. A
passing candidate is copied project-locally and recorded with repository, path,
commit SHA, license, audit evidence, benchmark scores, file hashes, and rollback
location. Repository popularity and OpenSSF metadata are advisory signals, never
sufficient proof.

## Quality decision

The three judges receive screenshots and the frozen contract, not builder
rationale. Each emits structured scores and concrete findings. All three must
pass. Mechanical checks cover evidence completeness, required viewport/state
coverage, deterministic anti-patterns, copied text/assets, and bounded repair
count. Model judges cover composition and product fit that cannot be reduced to
pixel rules.

## Intensity

- `economy`: three relevant references plus one wildcard, one council-selected
  direction, inexpensive independent judges, same hard evidence contract.
- `balanced`: four relevant references plus one wildcard and three directions.
- `max`: five relevant references plus one wildcard; a signature surface may use
  two or three isolated challenger implementations before the council selects.

Quality gates never disappear at lower intensity; only exploration breadth and
model spend change.

