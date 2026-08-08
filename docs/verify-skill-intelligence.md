# Skill intelligence verification — cycle 13

## RED

The new hermetic catalog test was run before `bin/polylane-skill-catalog.sh`
existed. It failed with `catalog-index-builds-metadata` exit 127 and 21 further
metadata/recommendation assertions because no catalog output could be created.
That establishes that the test exercises the new contract rather than merely
describing existing behavior.

## GREEN

The focused checks were run through the lane cache after the implementation:

```text
bash tests/test-scout-catalog.sh: 23 pass, 0 fail
bash tests/test-scout.sh: 26 pass, 0 fail
bash tests/test-scout-outcomes.sh: 18 pass, 0 fail
bash tests/test-skill-acquire.sh: 16 pass, 0 fail
shellcheck -S warning bin/polylane-scout.sh bin/polylane-skill-catalog.sh bin/polylane-skill-acquire.sh: exit 0
```

## Relevance and near-miss fixtures

`test-scout-catalog.sh` creates only hermetic roots and caches:

- A `ui:visual-regression` skill declares browser screenshots, UI rendering,
  Codex compatibility, and `bash`/`playwright` tools. A UI lane with screenshot
  comparison activities ranks it first and its reason contains both lane
  evidence (`activities:capture screenshots`) and that capability.
- `docs:test-writing` contains the tempting word “test”, but only describes
  Markdown prose and lacks the required `playwright` tool. It is rejected, so a
  keyword coincidence cannot enter the kit.
- A malformed no-delimiter frontmatter file is skipped. Two cache copies of the
  same id collapse deterministically, and the trusted-root copy wins.
- Helped evidence boosts a relevant candidate; a hurt outcome excludes a
  candidate. A missing verify-file record is written as `unused`, never
  inferred as helped.

## Acquisition safety evidence

Admission is generic rather than UI-only and remains project-scoped. The
fixture proves the ordered gate: explicit source authorization, quarantine copy,
audit, measurable benchmark with no accessibility regression, content hashes,
source revision pin, project install, rollback-ready lock metadata, and rollback.
The negative fixtures prove that an unapproved source, symlink, and install hook
never become an executable project skill. GitHub search still writes only
informational suggestions; missing `gh` or network evidence cannot produce an
armed recommendation.

## Real metadata-only catalog example

The catalog was indexed from local trusted roots and plugin caches without
loading bodies into any builder prompt. The current entries include:

| Qualified id | Source | Name | Fingerprint |
| --- | --- | --- | --- |
| `superpowers:test-driven-development` | plugin-cache | test-driven-development | `1657109997-9015` |
| `superpowers:verification-before-completion` | plugin-cache | verification-before-completion | `1896692335-3646` |
| `superpowers:writing-skills` | plugin-cache | writing-skills | `2635151414-26360` |
| `anthropic-skills:skill-creator` | plugin-cache | skill-creator | `3823043461-33168` |

The selected kit was read from its resolved local `SKILL.md` paths exactly once;
the catalog retains only id, path, frontmatter metadata, source, and fingerprint.

## Selected-kit invocation evidence

SKILL-EVIDENCE: superpowers:test-driven-development — helped: created the catalog fixture and recorded its failing RED run before implementation.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: ran fresh focused scout/acquisition checks and ShellCheck before reporting the result.

SKILL-EVIDENCE: skill-creator — helped: used progressive-disclosure metadata fields and deterministic discovery fixtures for the catalog design.

SKILL-EVIDENCE: superpowers:writing-skills — helped: made the recommendation/audit contract executable with strong, near-miss, hostile, and outcome fixtures.
