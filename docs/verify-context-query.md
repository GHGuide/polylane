# Context query verification

Implementation commit: `89eab02995e9cea2db887e04437bec2ec8ac12b4`.

## TDD evidence

The strengthened test was run before the implementation correction and was red:
`bash tests/test-context.sh` reported `24 pass, 2 fail`. The failures proved that
acknowledged inbox JSONL entries were injected and lexical selection omitted
`cycle-12-digest.md` in favor of older single-digit cycles.

After the correction, `bash tests/test-context.sh` was green: `26 pass, 0 fail`.
It covers source attribution and section labels, supplied locked goal/subgoal
preservation, relevance ordering, numeric recency, pending-only worker inbox
selection, hard byte bounds, malformed and unsafe paths, secret-like sources,
missing optional sources, and query/packet repeatability.

## Packet proof

The green fixture builds a packet with a 2200-byte caller limit. Its
`packet-hard-byte-bound` assertion verifies `wc -c context.md <= 2200`; its
manifest assertion verifies that this exact count equals `manifest.byte_count`.
The repeated `query` invocation produces byte-identical Markdown and the same
`cksum:<number>:<bytes>` manifest checksum (`packet-repeatable-content` and
`packet-repeatable-checksum`).

## Static checks

`bash -n bin/polylane-context.sh` passed.

`bin/polylane-check.sh "$PWD/.polylane/check-cache/context-query" -- shellcheck -S warning bin/polylane-context.sh`
ran and passed (cache key source fingerprint `3258453592:254`).
