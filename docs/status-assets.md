STATUS: assets DONE

Lane assets — graphify query helpers sharpened. All goal items shipped, evidence in docs/verify-assets.md.

1. `--json` on every subcommand (search/callers/uses/near/file/community) — json.load-validated on each.
2. Fuzzy fallback: zero-hit term → case-insensitive "did you mean" list (max 5), plain + JSON, all subcommands.
3. Errors: missing graph → exit 1 + `/graphify-auto` hint; corrupt JSON / wrong shape / missing community → clean message, exit 1, no traceback (JSON mode stays parseable).
4. graphify-nudge.sh hardened: `bash -n` clean, exit 0 on all paths (unset env, missing dir, no q.py, path with spaces) incl. `bash -eu -o pipefail`; `|| true` on cat guards EPIPE.
5. assets/README.md — 9-line micro-README (files + install destinations).

Contract held: HEAD vs new output byte-identical (stdout+stderr+rc) on all 14 hit-path invocations (plain + --json). New behavior additive only (miss paths + suggestions). Test suite: 61/61 (scratchpad/test_assets.py).
No files outside assets/** + docs/verify-assets.md + docs/status-assets.md touched.
