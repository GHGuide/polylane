# Report-item extractor verification

`bin/polylane-report-items.sh` accepts an explicit list of current-run markdown
evidence files and writes only top-level, nonempty bullets under exact `Deferred`,
`External`, or `Open items` headings. It ends a section at the next heading.

The focused fixture covers the cycle-5 pollution: wrapped continuation prose,
`STATUS:` and `POLYLANE-VERDICT:` sentinels, shell-command bullets, blank bullets,
near-match headings, and an unlisted historical evidence file. Only the three
explicit action bullets are emitted.

Verification run:

```sh
bash tests/test-report-items.sh
shellcheck -S warning bin/polylane-report-items.sh
```

Result: 1 pass, 0 fail; ShellCheck clean.

CLI integration seam:

```sh
bin/polylane-report-items.sh docs/verify-alpha.md docs/verify-integration.md
```
