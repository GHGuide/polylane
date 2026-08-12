# Verify — cache-integrity lane (Cycle 41)

Cache integrity and resume planner for the uncommitted primary corpus. Owns only:

- `bin/polylane-taste-cache.sh` — the planner (new, isolated helper).
- `tests/test-taste-cache-integrity.sh` — hermetic adversarial suite (new).
- `docs/verify-cache-integrity.md`, `docs/status-cache-integrity.md`.

No existing helper/test/reference/skill/installer/manifest/status file was touched.

## What it does

Reads a pinned `taste-source-plan/v1` (the same format `polylane-taste-source.sh`
consumes: per-source metadata/aggregate/raw sha256 plus every image sha256) and a
content-addressed cache (`$CACHE/objects/<sha[0:2]>/<sha>`, download sidecars end
in `.part`).

- `inventory CACHE_DIR PLAN.json REPORT.json` — classifies every declared object
  and writes a sorted `taste-cache-integrity/v1` report atomically. Statuses:
  - `ok/verified` — regular, non-empty, bytes hash to the declared name.
  - `missing/absent` — never published; `missing/interrupted-partial` — only an
    atomic-publish `.part` sidecar exists.
  - `corrupt/symlink`, `corrupt/not-regular`, `corrupt/empty`,
    `corrupt/checksum-mismatch` — something occupies the published name but is
    not the declared bytes.
  Exit 0 when clean, exit 4 (`TASTE-CACHE-DIRTY`) when any object needs work.
  Validation is strictly read-only: it never deletes, rewrites, or moves a cache
  object, and a failed run leaves no scan temp files behind.
- `plan-resume CACHE_DIR PLAN.json WORK.json` — deterministic
  `taste-cache-resume/v1` download work list: every missing or corrupt object,
  sorted by sha256, action `download`, reason `status/reason`. Byte-identical
  across repeated runs on the same state; ok objects are never re-downloaded.
- `quarantine CACHE_DIR REPORT.json` — acts only on an explicit
  `taste-cache-integrity/v1` report, only on entries marked `corrupt`, and only
  after re-verifying each object is still corrupt right now. Still-corrupt
  objects are **moved** (never deleted) to `$CACHE/quarantine/<sha>`; objects
  repaired since the report are kept in place; missing objects are skipped.

## Boundary proof

Object ids are validated as exactly 64 lowercase hex chars **before** any path is
constructed, so an id can never carry a separator or traversal segment, and the
built path is additionally pattern-checked to sit under `$CACHE/objects/`. The
cache root must be an existing non-symlink directory. The suite drives traversal
ids, URL-encoded traversal, ids containing `/`, uppercase/short/empty ids, a
hostile quarantine report, and a symlinked cache root — all rejected — and proves
with an outside-the-cache sentinel file that nothing beyond the boundary is ever
touched.

Bash 3.2 + jq + shasum only; `main` is `BASH_SOURCE`-guarded; all JSON outputs
are rendered to a sibling temp file and `mv`d into place (atomic).

## Verify

```bash
bash tests/test-taste-cache-integrity.sh
shellcheck -S warning bin/polylane-taste-cache.sh
```

Expected: `OK: 57 assertions` and no ShellCheck output. Verified on this host's
GNU bash 3.2.57 with ShellCheck 0.11.0.
