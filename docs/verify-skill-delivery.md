# Skill-delivery verification — cycle 14

## RED fixtures observed

`tests/test-skill-delivery.sh` initially failed before the implementation for:

- selected records absent from the v2 name-only kit;
- missing, unreadable, and out-of-trusted-root `SKILL.md` paths accepted at validation;
- duplicated prompt records with no typed path delivery;
- a flattering `SKILL-EVIDENCE` receipt marked `helped` without any read proof.

## GREEN evidence

Run through the lane-local cache after the implementation:

```text
CHECK-CACHE: PASS … bash tests/test-skill-delivery.sh
test-skill-delivery.sh: 23 pass, 0 fail
CHECK-CACHE: PASS … bash tests/test-scout-catalog.sh
test-scout-catalog.sh: 25 pass, 0 fail
CHECK-CACHE: PASS … bash tests/test-prompt-compiler.sh
test-prompt-compiler.sh: 12 pass, 0 fail
shellcheck -S warning bin/polylane-scout.sh bin/polylane-skill-catalog.sh bin/polylane-skill-acquire.sh bin/polylane-promptopt.sh
```

The selected record is `{id,path,reason,source,fingerprint}`. `validate` migrates a
historical v2 name list to v3 before preflight; a v2 kit audited before migration is
truthfully `unused`, because it cannot identify a trusted path or immutable file.

`compile-selected` uses kit JSON only. It does not load any skill body and emits each
typed `SELECTED-SKILL` record once, instructing builders to read only those exact
files and never rediscover an inventory. `use-audit` accepts `helped` or `hurt` only
when its `SKILL-EVIDENCE` line is paired with exact `SKILL-READ` path/fingerprint
evidence; otherwise it records `unused`.

## Builder-kit use receipts

SKILL-EVIDENCE: superpowers:test-driven-development — helped: added the requested failing missing-path, unreadable-path, out-of-root, duplicate-prompt, and fake-receipt fixtures before implementation.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: ran the fresh focused checks and ShellCheck recorded above before the completion marker.

SKILL-EVIDENCE: skill-creator — helped: kept selected-skill identity as a compact structured contract with progressive disclosure rather than adding any skill-body inventory to prompts.

SKILL-EVIDENCE: superpowers:writing-skills — helped: made the generated builder instruction an explicit positive recipe: read only the exact emitted paths and do not rediscover skills.
