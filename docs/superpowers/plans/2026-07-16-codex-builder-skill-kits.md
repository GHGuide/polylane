# Codex Builder Skill Kits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every Codex builder exactly two predefined quality skills and two
Builder-selected lane-specific skills, bind their immutable bytes to runner-authored
verification evidence, and publish safe guardian-owned GitHub suggestion jobs.

**Architecture:** Adapter-local discovery delegates to one shared no-follow snapshot store.
The store snapshots a selected skill directory once into a bounded content-addressed tree;
selection, prompt framing, attestation, and scoring consume only those snapshots. The
one-cycle runner qualifies DONE lanes with a fresh argv verification and a runner-authored
attestation before the integrator can start. GitHub work is an informational runtime job:
the runner publishes immutable input, and only the runtime guardian may claim and execute it.

**Tech Stack:** Bash 3.2 wrappers/tests, Python 3 standard library for `openat`/`O_NOFOLLOW`
filesystem work and exact-byte framing, jq, git, tmux, Codex `exec --json`, GitHub REST via
`gh api --method GET`, Markdown skill trees.

## Global Constraints

- Builder lanes only receive kits. The integrator never appears in a kit and receives the
  original prompt bytes unchanged.
- Every builder has exactly two `predefined` and two `specific` entries. Predefined ids are
  exactly `superpowers:test-driven-development` and
  `superpowers:verification-before-completion`; the two specific capability keys differ.
- The package contains exactly fourteen domain fallbacks:
  `{ui,api,data,mobile,report,test,unknown}-{implementation,verification}`. Missing
  predefined installs use approved synthetic equivalent snapshot trees, so all four
  assignments still have immutable tree identities.
- The Builder scout is the only skill chooser. Proposal, controller, planner, guardian,
  integrator, and GitHub records may describe activities or gaps but never choose ids.
- One inventory call has the exact interface
  `inventory <output.json> <snapshot-root>`. It selects id/version/root collisions before
  reading content, opens each winning directory once, and snapshots its complete regular-file
  tree. Selector, renderer, linter, attester, and scorer never reread host skill roots.
- Snapshot bytes are exact. CRLF is neither normalized nor decoded/re-encoded. Relative
  resources are preserved. Symlinks, sockets, devices, FIFOs, control-character paths,
  non-NFC/casefold path collisions, source inode/size/mtime races, and special files fail
  closed.
- Snapshot traversal holds descriptors for every opened directory through a final root pass.
  Device/inode/type/mtime/ctime are checked before and after enumeration, after descendants,
  through each parent entry, and again for every held descriptor; file identity additionally
  binds size. Concurrent content or directory-entry mutation rejects the entire candidate.
- Frozen limits are: `file_count<=64`, `opened_directory_count<=64`, `file_bytes<=262144`,
  `SKILL.md_bytes<=131072`, `tree_bytes<=1048576`, `four_tree_bytes<=2097152`, and
  `inventory_bytes<=16777216`. GitHub responses are additionally capped at 1048576 bytes,
  20 repositories, 32 candidate paths per repository, and 131072 decoded bytes per
  candidate `SKILL.md`.
- Canonical JSON is UTF-8, `sort_keys=true`, separators `,`/`:`, and ends in one LF. SHA-256
  values use `sha256:<64 lowercase hex>`. Snapshot files are 0444 or 0555, directories 0555,
  and tree manifests are 0444.
- Prompt materialization uses length-prefixed frames. Lint parses lengths, then compares the
  exact framed bytes and metadata to the snapshot. Body text can contain marker-like lines
  without creating or terminating a frame.
- Installed external specific skills require a positive normalized activity-token match in
  both frontmatter (`name`/`description`/id) and the snapshotted `SKILL.md` body. Unknown
  lanes receive exactly the bundled unknown implementation and verification pair. Unknown
  external skills never qualify by default.
- Inventory, ledger, suggestion input/result, and attestation publication use
  generation-scoped, no-follow, conflict-detecting publication under
  PID/start-token/nonce/generation owner locks. The public lock
  directory is never renamed. A closer/reclaimer hard-links a unique close marker inside the
  opened fixed directory, revalidates its exact owner generation and directory inode, removes
  only that generation's entries, and then uses `rmdir`; a delayed initializer or reaper can
  never address a successor lock or publication.
- Inventory publication never uses replacement: while holding the owner-generation lock it
  hard-links a complete private file into an absent public name, accepts an existing name only
  when its bytes are identical, and otherwise reports an immutable same-attempt conflict.
- Ledgers have no fixed lifetime byte ceiling: every canonical record is an immutable
  content-addressed segment, every dedupe key has one conflict-detecting hashed marker, and a
  constant-size atomic root index names the two private stores. Readers stream and validate
  segments; crash leftovers are unreferenced and harmless. Score dedupe identity is the
  runner claim/generation/attempt plus the immutable attestation hash, never only run/lane.
- Builder prose, including `SKILL-EVIDENCE:` lines, is informational. Only a runner-authored
  attestation may unlock integration. It binds worker result and exact actor PID/start token/
  generation, prompt and kit hashes, four tree hashes, run-nonce DONE/verify hashes, plus a
  fresh runner-executed verification argv, exit status, stdout/stderr hashes, and artifact.
- Fresh verification uses OS pipes only as bounded transport and incrementally drains them to
  exclusive no-follow private files. Frozen caps are 4194304 bytes per stream, 6291456 bytes
  combined, and 300 seconds. Overflow kills the child and publishes a typed immutable failed
  artifact with exit 125; timeout publishes exit 124. No unbounded `subprocess.PIPE` buffering
  or worker-authored verification is accepted.
- Every result, verification artifact, attestation, and rejection receipt is namespaced by the
  runner claim/generation/attempt and actor generation. Publication is exclusive and
  conflict-detecting: a later runner attempt can never replace, alias, or collide with earlier
  evidence, even when it retries the same actor generation.
- A raw DONE first enters qualification. Attestation or verification failure atomically
  removes eligibility, writes feedback, increments that lane's actor generation, and returns
  the same lane to `WORKING`; only attested/scored DONE lanes satisfy the builder poll.
- GitHub is informational only. Requests are exact GET argv. Candidate evidence comes only
  from pinned commit/tree/blob objects and bounded root/nested `SKILL.md` bytes—not README or
  repository names. The branch response is only a ref discovery hint: the client fetches the
  immutable Git commit endpoint, reconstructs canonical unsigned or signed commit bytes,
  fetches every
  linked tree object non-recursively, reconstructs canonical mode/name/NUL/raw-id entries,
  and requires every response id, URL link, parent/tree/blob link, and recomputed object id to
  agree. A signed commit is accepted only when GitHub's extracted signed payload is byte-for-byte
  the reconstructed unsigned payload and its signature reconstructs the exact `gpgsig` header;
  every other signed commit is conservatively unavailable.
  Every decoded license and `SKILL.md` body must likewise reproduce its claimed Git blob
  object SHA-1 (`sha1(b"blob "+len+NUL+body)`) and any API response `sha`; any mismatch is a
  typed `unavailable`, never a candidate or `no_match`. No candidate text is executed,
  sourced, installed, or added to a prompt.
- Each suggestion gap has exactly one typed terminal result: `found`, `no_match`,
  `unavailable`, or `timeout`. Missing `gh` or the installed suggester helper publishes
  `unavailable`. Runtime guardian PID/start token/generation/deadline owns each job; runner,
  proposal, and controller never start the network child.
- Suggestion-input preparation starts only after every Builder pane has launched and runs as a
  detached local sidecar. Adapter timeout, malformed GitHub JSON, response-shape errors, and
  helper failure become typed `unavailable` records; none can delay worker launch or DONE
  polling. Input, owner, result, and `job_id` bind the runner claim/generation/attempt, so a
  retry preserves its predecessor instead of reusing a run-level singleton. Found records
  include repository URL, maintainer, pinned recent commit activity,
  named-lane matching evidence, GitHub repository permissions, and conservative
  permission/tooling-introduction reviews whose evidence comes only from the bounded candidate.
  License provenance records identified/missing/unknown status, SPDX when available, the
  exact repository endpoint, and the pinned commit at which the candidate was evaluated.
- Foundation's package map recursively ships `scripts/**`, `references/**`, `assets/**`,
  `config/**`, and `bundled-skills/**`; it maps the single workflow contract into installed
  references, while `tests/**` remain source-only. This plan does not add an
  `assemble_package` hook and never uses nonexistent `$stage` or `CODEX_DEST` variables.
  Package tests use Foundation's `C` and `H` destinations.
- Installed package execution resolves sibling installed helpers and its own
  `bundled-skills/`; it has no repository fallback. Source-tree tests use explicit expert
  override paths.

## Frozen JSON Contracts

Inventory entry and tree manifest fields are exact:

```json
{
  "schema_version": 2,
  "adapter": "codex",
  "snapshot_root": "/tmp/run/snapshots",
  "limits": {
    "max_files": 64,
    "max_file_bytes": 262144,
    "max_body_bytes": 131072,
    "max_tree_bytes": 1048576,
    "max_inventory_bytes": 16777216
  },
  "skills": [{
    "id": "engineering:debug",
    "origin": "external",
    "root_rank": 1,
    "version": "1.3.0",
    "snapshot_root": "/tmp/run/snapshots/sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "skill_md_rel": "SKILL.md",
    "path": "/tmp/run/snapshots/sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/SKILL.md",
    "tree_manifest": "/tmp/run/snapshots/sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/.polylane-skill-tree.json",
    "body_sha256": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "tree_sha256": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "file_count": 3,
    "total_bytes": 8192,
    "capability": "debug",
    "frontmatter": {"name":"debug","description":"Debug API failures"},
    "relevance_text_sha256": "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
  }],
  "unavailable": []
}
```

```json
{
  "schema_version": 1,
  "skill_id": "engineering:debug",
  "skill_md_rel": "SKILL.md",
  "body_sha256": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "file_count": 3,
  "total_bytes": 8192,
  "files": [
    {"path":"SKILL.md","mode":"0444","size":4096,"sha256":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},
    {"path":"references/checks.md","mode":"0444","size":3072,"sha256":"sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"},
    {"path":"scripts/probe.sh","mode":"0555","size":1024,"sha256":"sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"}
  ]
}
```

`tree_sha256` is SHA-256 of the exact canonical tree-manifest bytes. The manifest is
metadata and is not included in its own `files`, `file_count`, or `total_bytes`.

Each kit assignment copies the inventory fields `id`, `origin`, `snapshot_root`,
`skill_md_rel`, `path`, `tree_manifest`, `body_sha256`, `tree_sha256`, `file_count`,
`total_bytes`, `capability`, and `frontmatter`. A predefined synthetic equivalent adds
`resolution:"equivalent"`, `contract_sha256`, and `missing_capability`; every other entry
uses `resolution:"installed"`. The four tree hashes therefore exist in every kit.
The prelaunch template also contains exact
`runner:{claim,generation,attempt}` and `actor:null`. The live wrapper exclusively derives
the only worker-visible kit and prompt, replacing `actor:null` with exact
`{pid,start_token,generation,lane,run_id}` and recomputing `kit_sha256`; it then binds that
kit hash, prompt hash, runner scope, and actor object into the structured worker result.

Runner attestation fields are exact:

```json
{
  "schema_version": 1,
  "loop_id": "pl-abc123",
  "cycle": 3,
  "run_id": "nonce-3",
  "lane": "api",
  "attester": {"pid":1200,"start_token":"runner-ps-token","claim":"claim-7","generation":1,"attempt":2},
  "actor": {"pid":1234,"start_token":"ps-token","generation":2,"lane":"api","run_id":"nonce-3"},
  "worker_result_path": "/repo/.polylane/results/api.json",
  "worker_result_sha256": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
  "events_path": "/repo/.polylane/results/api.events.jsonl",
  "events_sha256": "sha256:2222222222222222222222222222222222222222222222222222222222222222",
  "stderr_path": "/repo/.polylane/results/api.stderr",
  "stderr_sha256": "sha256:9999999999999999999999999999999999999999999999999999999999999999",
  "prompt_path": "/repo/.polylane/builder.bound.prompt",
  "prompt_sha256": "sha256:3333333333333333333333333333333333333333333333333333333333333333",
  "kit_path": "/repo/.polylane/skill-kit.actor-g2.json",
  "kit_file_sha256": "sha256:abababababababababababababababababababababababababababababababab",
  "kit_sha256": "sha256:4444444444444444444444444444444444444444444444444444444444444444",
  "tree_sha256": ["sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"],
  "done_path": "/repo/docs/status-api.md",
  "done_sha256": "sha256:5555555555555555555555555555555555555555555555555555555555555555",
  "verify_path": "/repo/docs/verify-api.json",
  "verify_sha256": "sha256:6666666666666666666666666666666666666666666666666666666666666666",
  "verification": {"schema_version":2,"argv":["/usr/bin/test","-f","api-output.txt"],"exit_code":0,"passed":true,"failure_reason":null,"started_at":1784199999,"finished_at":1784200000,"limits":{"per_stream_bytes":4194304,"combined_bytes":6291456,"timeout_seconds":300},"stdout_path":"/repo/.polylane/api.stdout","stdout_bytes":0,"stdout_sha256":"sha256:7777777777777777777777777777777777777777777777777777777777777777","stderr_path":"/repo/.polylane/api.stderr","stderr_bytes":0,"stderr_sha256":"sha256:8888888888888888888888888888888888888888888888888888888888888888","artifact":"/repo/docs/polylane/verification-runs/nonce-3/api.json"},
  "attested_at": 1784200000
}
```

---

### Task 1: Snapshot Installed Skill Trees and Validate Kit Identity

**Files:**
- Create: `core/scripts/polylane-skill-store.py`
- Create: `core/scripts/polylane-skill-store.sh`
- Create: `codex/scripts/polylane-codex-skills.sh`
- Create: `claude-code/scripts/polylane-claude-skills.sh`
- Create: `core/bundled-skills/{ui,api,data,mobile,report,test,unknown}-{implementation,verification}/{SKILL.md,references/contract.md}`
- Create: `core/tests/skill-inventory-contract.sh`
- Create: `codex/tests/test-codex-skill-inventory.sh`
- Create: `claude-code/tests/test-claude-skill-inventory.sh`
- Create: `core/tests/test-skill-store-locks.sh`
- Create: `core/tests/test-skill-tree-validation.sh`

**Interfaces:**
- `polylane-<adapter>-skills.sh inventory <output.json> <snapshot-root>` is the only
  inventory interface.
- `polylane-skill-store.sh validate-inventory <inventory.json>` and
  `validate-assignment <assignment.json> <inventory.json>` exit 0 or 5.
- `polylane-skill-store.sh append-jsonl <target> <record> <dedupe-key>` is the compatibility
  name for the shared segmented-ledger append primitive. It publishes one content-addressed
  record segment plus one hashed-key marker and a constant-size atomic root index; it never
  accumulates a lifetime-bounded monolithic JSONL file. `read-ledger <target> <dedupe-key>`
  streams validated records without assembling the ledger in memory.
- `POLYLANE_SKILL_ENGINE` is an explicit source-test override. Installed adapters require
  sibling `scripts/polylane-skill-store.{sh,py}` and never probe `../../core`.

- [ ] **Step 1: Write the complete failing snapshot/collision contract test**

Create `core/tests/skill-inventory-contract.sh`:

```bash
#!/usr/bin/env bash
set -u
: "${ROOT:?}" "${ADAPTER:?}" "${COMMAND:?}" "${ROOTS_ENV:?}"
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
TEST_TMPDIR=$(cd "$TEST_TMPDIR" && pwd -P)
FIX="$TEST_TMPDIR/inventory"; R1="$FIX/r1"; R2="$FIX/r2"
SNAP="$FIX/snapshots"; OUT="$FIX/inventory.json"
chmod 0700 "$FIX"
sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1"
  else sha256sum "$1"; fi | awk '{print $1}'
}
mkdir -p "$R1/cache/engineering/1.3.0/skills/debug/references" \
  "$R1/cache/engineering/1.3.0/skills/debug/scripts" \
  "$R1/cache/engineering/1.3.0-rc.1/skills/debug" \
  "$R1/cache/observability/2.0.0-b/skills/tracing" \
  "$R1/cache/observability/2.0.0-a/skills/tracing" \
  "$R2/cache/engineering/9.0.0/skills/debug" \
  "$R1/direct-one" "$R2/direct-one"
write_skill() {
  dir=$1 name=$2 description=$3 body=$4
  printf '%s\r\n' '---' "name: $name" "description: $description" '---' '' "$body" > "$dir/SKILL.md"
}
write_skill "$R1/cache/engineering/1.3.0/skills/debug" debug 'Debug REST route failures' \
  'Inspect REST handlers and reproduce the failing route.'
printf '%s\r\n' '---' 'name: debug' 'description: Debug REST route failures' \
  'argument-hint: "[route]"' 'metadata:' '  author: openai' '  category: engineering' \
  '---' '' 'Inspect REST handlers and reproduce the failing route.' \
  > "$R1/cache/engineering/1.3.0/skills/debug/SKILL.md"
printf 'relative bytes\r\n<!-- frame-like text -->\r\n' \
  > "$R1/cache/engineering/1.3.0/skills/debug/references/checks.md"
printf '#!/usr/bin/env bash\nprintf probe\n' \
  > "$R1/cache/engineering/1.3.0/skills/debug/scripts/probe.sh"
chmod +x "$R1/cache/engineering/1.3.0/skills/debug/scripts/probe.sh"
write_skill "$R1/cache/engineering/1.3.0-rc.1/skills/debug" debug 'release candidate' rc
write_skill "$R2/cache/engineering/9.0.0/skills/debug" debug 'lower-priority root' other
write_skill "$R1/cache/observability/2.0.0-a/skills/tracing" tracing 'Trace REST calls' trace-a
write_skill "$R1/cache/observability/2.0.0-b/skills/tracing" tracing 'Trace REST calls' trace-b
write_skill "$R1/direct-one" direct-one 'First root wins direct collision' first
write_skill "$R2/direct-one" direct-one 'Second root loses direct collision' second

env "$ROOTS_ENV=$R1:$R2" POLYLANE_SKILL_ENGINE="$ROOT/core/scripts/polylane-skill-store.sh" \
  "$COMMAND" inventory "$OUT" "$SNAP"
assert_eq "existing-parent-mode-preserved" 0700 \
  "$(python3 -c 'import os,stat,sys; print(f"{stat.S_IMODE(os.stat(sys.argv[1]).st_mode):04o}")' "$FIX")"
assert_eq "snapshot-base-private" 0700 \
  "$(python3 -c 'import os,stat,sys; print(f"{stat.S_IMODE(os.stat(sys.argv[1]).st_mode):04o}")' "$SNAP")"
assert_eq "adapter" "$ADAPTER" "$(jq -r .adapter "$OUT")"
assert_eq "sorted-unique" 3 "$(jq '.skills|length' "$OUT")"
assert_eq "stable-release" 1.3.0 \
  "$(jq -r '.skills[]|select(.id=="engineering:debug")|.version' "$OUT")"
assert_eq "suffix-lexical" 2.0.0-a \
  "$(jq -r '.skills[]|select(.id=="observability:tracing")|.version' "$OUT")"
assert_eq "root-before-version" 1 \
  "$(jq -r '.skills[]|select(.id=="engineering:debug")|.root_rank' "$OUT")"
assert_eq "real-frontmatter-normalized" \
  '{"description":"Debug REST route failures","name":"debug"}' \
  "$(jq -c '.skills[]|select(.id=="engineering:debug")|.frontmatter' "$OUT")"
entry=$(jq -c '.skills[]|select(.id=="engineering:debug")' "$OUT")
tree=$(printf '%s' "$entry" | jq -r .snapshot_root)
manifest=$(printf '%s' "$entry" | jq -r .tree_manifest)
assert_ok "tree-content-addressed" test -d "$tree"
assert_ok "relative-resource" test -f "$tree/references/checks.md"
assert_ok "relative-script" test -x "$tree/scripts/probe.sh"
assert_eq "exact-crlf-body" "$(sha256_file "$R1/cache/engineering/1.3.0/skills/debug/SKILL.md")" \
  "$(sha256_file "$tree/SKILL.md")"
assert_eq "exact-crlf-resource" "$(sha256_file "$R1/cache/engineering/1.3.0/skills/debug/references/checks.md")" \
  "$(sha256_file "$tree/references/checks.md")"
assert_eq "manifest-body-hash" "sha256:$(sha256_file "$tree/SKILL.md")" \
  "$(jq -r .body_sha256 "$manifest")"
assert_eq "manifest-tree-hash" "sha256:$(sha256_file "$manifest")" \
  "$(printf '%s' "$entry" | jq -r .tree_sha256)"
assert_eq "manifest-count" 3 "$(jq -r .file_count "$manifest")"
assert_eq "manifest-script-mode" 0555 \
  "$(jq -r '.files[]|select(.path=="scripts/probe.sh")|.mode' "$manifest")"
assert_eq "tree-read-only-files" '' \
  "$(find "$tree" -type f -perm -200 -print)"
assert_eq "tree-read-only-dirs" '' \
  "$(find "$tree" -type d -perm -200 -print)"
assert_ok "canonical-inventory" python3 - "$OUT" <<'PY'
import json,sys
p=sys.argv[1]; raw=open(p,'rb').read(); obj=json.loads(raw)
want=(json.dumps(obj,sort_keys=True,separators=(',',':'),ensure_ascii=False)+'\n').encode()
raise SystemExit(0 if raw==want else 1)
PY
assert_ok "validate-inventory" "$ROOT/core/scripts/polylane-skill-store.sh" validate-inventory "$OUT"

# Same-attempt inventory publication is create-once or byte-idempotent. A retry of the exact
# source is accepted; changed bytes conflict without replacing the first published inventory.
inventory_hash=$(sha256_file "$OUT")
env "$ROOTS_ENV=$R1:$R2" POLYLANE_SKILL_ENGINE="$ROOT/core/scripts/polylane-skill-store.sh" \
  "$COMMAND" inventory "$OUT" "$SNAP"
assert_eq "same-attempt-inventory-idempotent" "$inventory_hash" "$(sha256_file "$OUT")"
cp "$R1/cache/engineering/1.3.0/skills/debug/SKILL.md" "$FIX/debug.before-conflict"
printf 'conflicting retry\n' >>"$R1/cache/engineering/1.3.0/skills/debug/SKILL.md"
assert_rc "same-attempt-inventory-conflict" 5 env "$ROOTS_ENV=$R1:$R2" \
  POLYLANE_SKILL_ENGINE="$ROOT/core/scripts/polylane-skill-store.sh" \
  "$COMMAND" inventory "$OUT" "$SNAP"
assert_eq "inventory-conflict-preserves-first" "$inventory_hash" "$(sha256_file "$OUT")"
cp "$FIX/debug.before-conflict" "$R1/cache/engineering/1.3.0/skills/debug/SKILL.md"

for kind in symlink fifo control too_many too_large race dir_race; do
  BAD="$FIX/bad-$kind"; BS="$FIX/snap-$kind"; BO="$FIX/out-$kind.json"
  mkdir -p "$BAD/bad"
  write_skill "$BAD/bad" bad 'REST debug candidate' 'REST body'
  case $kind in
    symlink) ln -s SKILL.md "$BAD/bad/linked" ;;
    fifo) mkfifo "$BAD/bad/pipe" ;;
    control) printf x > "$BAD/bad/$(printf 'bad\nname')" ;;
    too_many) i=0; while [ "$i" -lt 65 ]; do printf x > "$BAD/bad/f$i"; i=$((i+1)); done ;;
    too_large) dd if=/dev/zero of="$BAD/bad/large" bs=262145 count=1 2>/dev/null ;;
    race)
      POLYLANE_STORE_FAULT=after-open POLYLANE_STORE_GATE="$FIX/race.gate" \
        env "$ROOTS_ENV=$BAD" POLYLANE_SKILL_ENGINE="$ROOT/core/scripts/polylane-skill-store.sh" \
        "$COMMAND" inventory "$BO" "$BS" >"$FIX/race.out" 2>&1 & rp=$!
      i=0; while [ ! -f "$FIX/race.gate.ready" ] && [ "$i" -lt 100 ]; do sleep 0.02; i=$((i+1)); done
      printf mutation >> "$BAD/bad/SKILL.md"; : > "$FIX/race.gate"
      wait "$rp" 2>/dev/null; rc=$?
      assert_eq "reject-$kind" 0 "$rc"
      assert_eq "no-selected-$kind" 0 "$(jq '.skills|length' "$BO")"
      assert_eq "typed-rejection-$kind" snapshot_rejected "$(jq -r '.unavailable[0].reason' "$BO")"
      assert_eq "no-tree-$kind" '' \
        "$(find "$BS" -mindepth 1 -maxdepth 1 -type d -name 'sha256-*' -print -quit)"
      continue ;;
    dir_race)
      POLYLANE_STORE_FAULT=after-dir-enumeration POLYLANE_STORE_GATE="$FIX/dir-race.gate" \
        env "$ROOTS_ENV=$BAD" POLYLANE_SKILL_ENGINE="$ROOT/core/scripts/polylane-skill-store.sh" \
        "$COMMAND" inventory "$BO" "$BS" >"$FIX/dir-race.out" 2>&1 & rp=$!
      i=0; while [ ! -f "$FIX/dir-race.gate.ready" ] && [ "$i" -lt 100 ]; do sleep 0.02; i=$((i+1)); done
      printf mutation >"$BAD/bad/concurrent-entry"; : >"$FIX/dir-race.gate"
      wait "$rp" 2>/dev/null; rc=$?
      assert_eq "reject-$kind" 0 "$rc"
      assert_eq "no-selected-$kind" 0 "$(jq '.skills|length' "$BO")"
      assert_eq "typed-rejection-$kind" snapshot_rejected "$(jq -r '.unavailable[0].reason' "$BO")"
      assert_eq "no-tree-$kind" '' \
        "$(find "$BS" -mindepth 1 -maxdepth 1 -type d -name 'sha256-*' -print -quit)"
      continue ;;
  esac
  env "$ROOTS_ENV=$BAD" POLYLANE_SKILL_ENGINE="$ROOT/core/scripts/polylane-skill-store.sh" \
    "$COMMAND" inventory "$BO" "$BS" >/dev/null 2>&1; rc=$?
  assert_eq "reject-$kind" 0 "$rc"
  assert_eq "no-selected-$kind" 0 "$(jq '.skills|length' "$BO")"
  assert_eq "typed-rejection-$kind" snapshot_rejected "$(jq -r '.unavailable[0].reason' "$BO")"
  assert_eq "no-tree-$kind" '' \
    "$(find "$BS" -mindepth 1 -maxdepth 1 -type d -name 'sha256-*' -print -quit)"
done
finish
```

The contract-local `sha256_file` keeps the test portable across macOS and GNU environments.

- [ ] **Step 2: Add the two adapter entry tests and verify RED**

Create `codex/tests/test-codex-skill-inventory.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
ADAPTER=codex
COMMAND="$ROOT/codex/scripts/polylane-codex-skills.sh"
ROOTS_ENV=POLYLANE_CODEX_SKILL_ROOTS
export ROOT ADAPTER COMMAND ROOTS_ENV
. "$ROOT/core/tests/skill-inventory-contract.sh"
```

Create `claude-code/tests/test-claude-skill-inventory.sh` with the same contract variables:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
ADAPTER=claude-code
COMMAND="$ROOT/claude-code/scripts/polylane-claude-skills.sh"
ROOTS_ENV=POLYLANE_CLAUDE_SKILL_ROOTS
export ROOT ADAPTER COMMAND ROOTS_ENV
. "$ROOT/core/tests/skill-inventory-contract.sh"
```

Run:

```bash
chmod +x core/tests/skill-inventory-contract.sh codex/tests/test-codex-skill-inventory.sh \
  claude-code/tests/test-claude-skill-inventory.sh
bash codex/tests/test-codex-skill-inventory.sh
bash claude-code/tests/test-claude-skill-inventory.sh
```

Expected RED: both exit nonzero because the adapter inventory entrypoints and snapshot store
do not exist.

- [ ] **Step 3: Add the complete no-follow/CAS snapshot store**

Create `core/scripts/polylane-skill-store.py` from the complete implementation in
`core/tests/fixtures/skill-store-v2.py` below, then keep the fixture byte-identical to the
runtime file. This makes the long security-sensitive body reviewable once while the parity
test prevents drift.

```python
#!/usr/bin/env python3
import argparse, errno, hashlib, json, os, re, secrets, shutil, stat, subprocess, sys, time, unicodedata
from pathlib import Path

MAX_FILES=64; MAX_FILE=262144; MAX_BODY=131072; MAX_TREE=1048576; MAX_INV=16777216
HEX=re.compile(r"^sha256:[0-9a-f]{64}$")

class Fail(Exception): pass
def die(msg): print(f"skill-store: {msg}",file=sys.stderr); raise SystemExit(5)
def canon(obj): return (json.dumps(obj,sort_keys=True,separators=(",",":"),ensure_ascii=False)+"\n").encode()
def sha(data): return "sha256:"+hashlib.sha256(data).hexdigest()
def token(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().split(")",1)[1].split()[19]
    except Exception:
        try: return str(os.stat(f"/proc/{pid}").st_ctime_ns)
        except Exception:
            out=subprocess.run(["ps","-o","lstart=","-p",str(int(pid))],stdin=subprocess.DEVNULL,
              stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,check=False,env=dict(os.environ,LC_ALL="C")).stdout.strip()
            return sha(out) if out else ""
def owner_live(o): return int(o.get("pid",0))>1 and token(int(o["pid"]))==o.get("start_token","")
def safe_name(name,allow_manifest=False):
    if not name or name in (".","..") or (name==".polylane-skill-tree.json" and not allow_manifest): raise Fail("unsafe path")
    if unicodedata.normalize("NFC",name)!=name or any(ord(c)<32 or ord(c)==127 for c in name): raise Fail("unsafe path")
    return name
def nofollow_dir(path):
    p=Path(path).absolute(); parts=p.parts; fd=os.open(parts[0],os.O_RDONLY|os.O_DIRECTORY)
    try:
        for part in parts[1:]:
            safe_name(part); nxt=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd); os.close(fd); fd=nxt
        return fd
    except Exception: os.close(fd); raise
def ensure_dir(path,mode=0o755):
    p=Path(path).absolute(); parts=p.parts; fd=os.open(parts[0],os.O_RDONLY|os.O_DIRECTORY)
    try:
        created=False
        for index,part in enumerate(parts[1:],1):
            safe_name(part)
            made=False
            try: nxt=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
            except FileNotFoundError:
                os.mkdir(part,mode,dir_fd=fd)
                nxt=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
                os.fchmod(nxt,mode); os.fsync(nxt); made=True; created=True
            os.close(fd); fd=nxt
            if index==len(parts)-1 and not made:
                st=os.fstat(fd)
                if st.st_uid!=os.geteuid() or stat.S_IMODE(st.st_mode)&0o022: raise Fail("unsafe existing directory")
        if created: os.fsync(fd)
    finally: os.close(fd)
def read_regular(path,limit=MAX_INV,allow_manifest=False):
    p=Path(path).absolute(); pfd=nofollow_dir(p.parent); name=safe_name(p.name,allow_manifest)
    try:
        before=os.stat(name,dir_fd=pfd,follow_symlinks=False)
        if not stat.S_ISREG(before.st_mode): raise Fail("not a regular file")
        fd=os.open(name,os.O_RDONLY|os.O_NOFOLLOW,dir_fd=pfd); data=b""
        opened=os.fstat(fd)
        if (opened.st_dev,opened.st_ino,opened.st_size,opened.st_mtime_ns)!=(before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns): raise Fail("read race")
        while True:
            chunk=os.read(fd,65536)
            if not chunk: break
            data+=chunk
            if len(data)>limit: raise Fail("file too large")
        after=os.fstat(fd)
        if (after.st_size,after.st_mtime_ns)!=(opened.st_size,opened.st_mtime_ns): raise Fail("read race")
        return data
    finally:
        try: os.close(fd)
        except UnboundLocalError: pass
        os.close(pfd)
def read_json(path): return json.loads(read_regular(path))
def fsync_dir(path):
    fd=nofollow_dir(path)
    try: os.fsync(fd)
    finally: os.close(fd)
def atomic_write(path,data,mode=0o444,allow_manifest=False):
    p=Path(path).absolute(); parent=p.parent; pfd=nofollow_dir(parent)
    name=safe_name(p.name,allow_manifest); tmp=f".{name}.tmp.{os.getpid()}.{secrets.token_hex(8)}"
    try:
        try: st=os.stat(name,dir_fd=pfd,follow_symlinks=False)
        except FileNotFoundError: st=None
        if st is not None and not stat.S_ISREG(st.st_mode): raise Fail("unsafe target")
        fd=os.open(tmp,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=pfd)
        try:
            view=memoryview(data)
            while view: view=view[os.write(fd,view):]
            os.fchmod(fd,mode); os.fsync(fd)
        finally: os.close(fd)
        os.replace(tmp,name,src_dir_fd=pfd,dst_dir_fd=pfd); os.fsync(pfd)
    finally:
        try: os.unlink(tmp,dir_fd=pfd)
        except Exception: pass
        os.close(pfd)
def immutable_publish(path,data,mode=0o444,allow_manifest=False):
    """Publish once with link(2); an existing pathname must contain identical bytes."""
    p=Path(path).absolute(); pfd=nofollow_dir(p.parent)
    name=safe_name(p.name,allow_manifest); tmp=f".{name}.publish.{os.getpid()}.{secrets.token_hex(8)}"
    try:
        try:
            existing=read_regular(p,MAX_INV,allow_manifest)
        except FileNotFoundError:
            existing=None
        if existing is not None:
            if existing!=data: raise Fail("immutable publication conflict")
            return
        fd=os.open(tmp,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=pfd)
        try:
            view=memoryview(data)
            while view: view=view[os.write(fd,view):]
            os.fchmod(fd,mode); os.fsync(fd)
        finally: os.close(fd)
        try: os.link(tmp,name,src_dir_fd=pfd,dst_dir_fd=pfd,follow_symlinks=False)
        except FileExistsError:
            if read_regular(p,MAX_INV,allow_manifest)!=data:
                raise Fail("immutable publication conflict")
        os.fsync(pfd)
    finally:
        try: os.unlink(tmp,dir_fd=pfd)
        except FileNotFoundError: pass
        os.close(pfd)
def rm_tree(path):
    if Path(path).is_symlink(): raise Fail("refuse symlink tree")
    shutil.rmtree(path,ignore_errors=True)

class Lock:
    def __init__(self,target,seconds=30):
        self.public=Path(str(Path(target).absolute())+".lock")
        self.seconds=int(os.getenv("POLYLANE_STORE_LOCK_SECONDS",str(seconds)))
        self.nonce=secrets.token_hex(16); self.generation=time.time_ns(); self.held=False; self.fd=None
        self.owner={"schema_version":1,"pid":os.getpid(),"start_token":token(os.getpid()),
          "nonce":self.nonce,"generation":self.generation,"deadline_epoch":int(time.time())+self.seconds}
        self.owner_name=f"owner.{self.generation}.{self.nonce}.json"
    @staticmethod
    def read_at(fd,name,limit=65536):
        safe_name(name); f=os.open(name,os.O_RDONLY|os.O_NOFOLLOW,dir_fd=fd); data=b""
        try:
            before=os.fstat(f)
            if not stat.S_ISREG(before.st_mode): raise Fail("lock entry is not regular")
            while True:
                chunk=os.read(f,65536)
                if not chunk: break
                data+=chunk
                if len(data)>limit: raise Fail("lock entry too large")
            after=os.fstat(f)
            if (before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns)!=(after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns): raise Fail("lock read race")
            return data
        finally: os.close(f)
    def path_is_fd(self,pfd,fd):
        return self.named_is_fd(pfd,self.public.name,fd)
    @staticmethod
    def named_is_fd(pfd,name,fd):
        try: current=os.stat(name,dir_fd=pfd,follow_symlinks=False)
        except FileNotFoundError: return False
        opened=os.fstat(fd)
        return stat.S_ISDIR(current.st_mode) and (current.st_dev,current.st_ino)==(opened.st_dev,opened.st_ino)
    def remove_private(self,pfd,name,fd,owner_name,observed):
        if not self.named_is_fd(pfd,name,fd) or os.listdir(fd)!=[owner_name]: return False
        if self.read_at(fd,owner_name)!=canon(observed): return False
        os.unlink(owner_name,dir_fd=fd); os.fsync(fd)
        if not self.named_is_fd(pfd,name,fd): return False
        os.rmdir(name,dir_fd=pfd); os.fsync(pfd); return True
    def cleanup_private(self,pfd):
        prefix=self.public.name+".init."
        names=sorted(x for x in os.listdir(pfd) if x.startswith(prefix))
        if len(names)>1024: raise Fail("too many abandoned lock initializers")
        for name in names:
            fd=None
            try:
                fd=os.open(name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=pfd)
                owners=[x for x in os.listdir(fd) if x.startswith("owner.") and x.endswith(".json")]
                if len(owners)!=1: continue
                observed=json.loads(self.read_at(fd,owners[0]))
                if not owner_live(observed): self.remove_private(pfd,name,fd,owners[0],observed)
            except (OSError,Fail,ValueError,KeyError,json.JSONDecodeError): pass
            finally:
                if fd is not None: os.close(fd)
    def close_generation(self,fd,pfd,owner_name,observed,kind):
        generation=observed["generation"]; nonce=observed["nonce"]
        close=f"close.{generation}.{nonce}.{kind}.{secrets.token_hex(8)}"
        if self.read_at(fd,owner_name)!=canon(observed): return False
        os.link(owner_name,close,src_dir_fd=fd,dst_dir_fd=fd,follow_symlinks=False); os.fsync(fd)
        if self.read_at(fd,owner_name)!=self.read_at(fd,close) or self.read_at(fd,owner_name)!=canon(observed): return False
        names=os.listdir(fd); prefix=f"close.{generation}.{nonce}."
        allowed={owner_name}|{x for x in names if x.startswith(prefix)}
        if set(names)!=allowed or not self.path_is_fd(pfd,fd): return False
        for name in sorted(allowed): os.unlink(name,dir_fd=fd)
        os.fsync(fd)
        if not self.path_is_fd(pfd,fd): return False
        os.rmdir(self.public.name,dir_fd=pfd); os.fsync(pfd); return True
    def acquire(self):
        deadline=time.time()+self.seconds
        parent=self.public.parent; pfd=nofollow_dir(parent); self.cleanup_private(pfd)
        private=self.public.name+f".init.{self.generation}.{self.nonce}"
        while time.time()<deadline:
            lockfd=None
            try:
                os.mkdir(private,0o700,dir_fd=pfd)
                lockfd=os.open(private,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=pfd)
                atomic_write(parent/private/self.owner_name,canon(self.owner),0o400)
                os.fsync(lockfd); os.fsync(pfd)
                if os.getenv("POLYLANE_STORE_FAULT")=="lock-init-wait":
                    gate=Path(os.environ["POLYLANE_STORE_GATE"]); atomic_write(str(gate)+".ready",b"ready\n",0o400)
                    while True:
                        try: read_regular(gate,32); break
                        except (OSError,Fail): time.sleep(.02)
                os.rename(private,self.public.name,src_dir_fd=pfd,dst_dir_fd=pfd); os.fsync(pfd)
                if not self.path_is_fd(pfd,lockfd) or os.listdir(lockfd)!=[self.owner_name]: raise Fail("lock generation displaced")
                self.fd=lockfd; lockfd=None; self.held=True; os.close(pfd); return self
            except FileExistsError:
                if lockfd is not None: self.remove_private(pfd,private,lockfd,self.owner_name,self.owner)
            except OSError as e:
                if e.errno in (errno.EEXIST,errno.ENOTEMPTY):
                    if lockfd is not None: self.remove_private(pfd,private,lockfd,self.owner_name,self.owner)
                else: raise
            finally:
                if lockfd is not None: os.close(lockfd)
            self.reclaim(); time.sleep(.02)
        os.close(pfd); raise Fail("lock timeout")
    def reclaim(self):
        pfd=nofollow_dir(self.public.parent); fd=None
        try:
            fd=os.open(self.public.name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=pfd)
            owners=[x for x in os.listdir(fd) if x.startswith("owner.") and x.endswith(".json")]
            if len(owners)!=1: return
            observed=json.loads(self.read_at(fd,owners[0]))
            if set(observed)!={"schema_version","pid","start_token","nonce","generation","deadline_epoch"}: return
            if owner_live(observed): return
            self.close_generation(fd,pfd,owners[0],observed,"reap")
        except (OSError,Fail,ValueError,KeyError,json.JSONDecodeError): return
        finally:
            if fd is not None: os.close(fd)
            os.close(pfd)
    def release(self):
        if not self.held: return
        pfd=nofollow_dir(self.public.parent)
        try:
            if os.getenv("POLYLANE_STORE_FAULT")=="lock-close-wait":
                gate=Path(os.environ["POLYLANE_STORE_GATE"]); atomic_write(str(gate)+".ready",b"ready\n",0o400)
                while True:
                    try: read_regular(gate,32); break
                    except (OSError,Fail): time.sleep(.02)
            if not self.close_generation(self.fd,pfd,self.owner_name,self.owner,"owner"): raise Fail("lock ownership changed")
        finally:
            os.close(pfd); os.close(self.fd); self.fd=None; self.held=False
    def __enter__(self): return self.acquire()
    def __exit__(self,*_): self.release()

def candidate(root,rank,path):
    rel=path.relative_to(root).as_posix(); parts=rel.split("/")
    if parts[-1]!="SKILL.md": return None
    if len(parts)==2: return {"id":parts[0],"version":"0.0.0","stable":1,"root_rank":rank,"dir":path.parent}
    try: i=parts.index("skills")
    except ValueError: return None
    if i<1 or i+2!=len(parts): return None
    skill=parts[i+1]; plugin=parts[i-2] if re.match(r"^v?\d+\.\d+(?:\.\d+)?(?:[-+].+)?$",parts[i-1]) else parts[i-1]
    version=parts[i-1] if plugin==parts[i-2] else "0.0.0"
    return {"id":f"{plugin}:{skill}","version":version.lstrip("v"),"stable":0 if "-" in version else 1,"root_rank":rank,"dir":path.parent}
def version_key(v):
    base=v.split("-",1)[0].split("+",1)[0]; nums=[int(x) for x in base.split(".") if x.isdigit()]
    return tuple((nums+[0,0,0])[:3])
def walk_snapshot(source):
    rootfd=nofollow_dir(source); rows=[]; seen=set(); total=0; opened_dirs=[]
    def identity(st):
        return (st.st_dev,st.st_ino,stat.S_IFMT(st.st_mode),st.st_mtime_ns,st.st_ctime_ns)
    def wait_fault(kind,prefix):
        if os.getenv("POLYLANE_STORE_FAULT")!=kind or prefix: return
        gate=Path(os.environ["POLYLANE_STORE_GATE"])
        immutable_publish(str(gate)+".ready",b"ready\n",0o400)
        while not gate.exists(): time.sleep(.02)
    def walk(fd,prefix,parent_fd=None,parent_name=None):
        nonlocal total
        if len(opened_dirs)>=MAX_FILES: raise Fail("too many directories")
        begin=identity(os.fstat(fd)); held=os.dup(fd); opened_dirs.append((held,begin,prefix))
        names=[]
        with os.scandir(fd) as it:
            for e in it: names.append(e.name)
        if identity(os.fstat(fd))!=begin: raise Fail("directory enumeration race")
        wait_fault("after-dir-enumeration",prefix)
        for name in sorted(names,key=lambda x:x.encode("utf-8")):
            safe_name(name); rel=f"{prefix}/{name}" if prefix else name
            folded=rel.casefold()
            if folded in seen: raise Fail("casefold path collision")
            seen.add(folded); before=os.stat(name,dir_fd=fd,follow_symlinks=False)
            if stat.S_ISDIR(before.st_mode):
                child=os.open(name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
                try:
                    if identity(os.fstat(child))!=identity(before): raise Fail("directory open race")
                    walk(child,rel,fd,name)
                    if identity(os.stat(name,dir_fd=fd,follow_symlinks=False))!=identity(before):
                        raise Fail("directory entry race")
                finally: os.close(child)
            elif stat.S_ISREG(before.st_mode):
                if len(rows)>=MAX_FILES: raise Fail("too many files")
                if before.st_size>MAX_FILE: raise Fail("file too large")
                f=os.open(name,os.O_RDONLY|os.O_NOFOLLOW,dir_fd=fd); data=b""
                try:
                    opened=os.fstat(f)
                    before_id=(before.st_dev,before.st_ino,stat.S_IFMT(before.st_mode),before.st_size,
                      before.st_mtime_ns,before.st_ctime_ns)
                    opened_id=(opened.st_dev,opened.st_ino,stat.S_IFMT(opened.st_mode),opened.st_size,
                      opened.st_mtime_ns,opened.st_ctime_ns)
                    if opened_id!=before_id: raise Fail("source open race")
                    while True:
                        chunk=os.read(f,65536)
                        if not chunk: break
                        data+=chunk
                        if len(data)>MAX_FILE: raise Fail("file too large")
                    after=os.fstat(f)
                    after_id=(after.st_dev,after.st_ino,stat.S_IFMT(after.st_mode),after.st_size,
                      after.st_mtime_ns,after.st_ctime_ns)
                    if after_id!=opened_id: raise Fail("source read race")
                finally: os.close(f)
                if os.getenv("POLYLANE_STORE_FAULT")=="after-open" and rel=="SKILL.md":
                    gate=Path(os.environ["POLYLANE_STORE_GATE"])
                    immutable_publish(str(gate)+".ready",b"ready\n",0o400)
                    while not gate.exists(): time.sleep(.02)
                final=os.stat(name,dir_fd=fd,follow_symlinks=False)
                final_id=(final.st_dev,final.st_ino,stat.S_IFMT(final.st_mode),final.st_size,
                  final.st_mtime_ns,final.st_ctime_ns)
                if final_id!=before_id: raise Fail("source final race")
                total+=len(data)
                if total>MAX_TREE: raise Fail("tree too large")
                rows.append((rel,0o555 if before.st_mode&0o111 else 0o444,data))
            else: raise Fail("special file")
        if identity(os.fstat(fd))!=begin: raise Fail("directory traversal race")
        if parent_fd is not None and identity(os.stat(parent_name,dir_fd=parent_fd,
          follow_symlinks=False))!=begin: raise Fail("directory parent race")
    try:
        walk(rootfd,"")
        wait_fault("before-final-directory-pass","")
        for fd,expected,_ in opened_dirs:
            if identity(os.fstat(fd))!=expected: raise Fail("directory final-pass race")
    finally:
        for fd,_,_ in opened_dirs: os.close(fd)
        os.close(rootfd)
    if not any(r[0]=="SKILL.md" for r in rows): raise Fail("missing SKILL.md")
    body=next(r[2] for r in rows if r[0]=="SKILL.md")
    if len(body)>MAX_BODY: raise Fail("SKILL.md too large")
    return rows,body,total
def frontmatter(body):
    lines=body.splitlines(keepends=True)
    if not lines or lines[0].rstrip(b"\r\n")!=b"---": raise Fail("missing frontmatter")
    end=None
    for i,line in enumerate(lines[1:],1):
        if line.rstrip(b"\r\n")==b"---": end=i; break
    if end is None: raise Fail("unterminated frontmatter")
    data={}
    for raw in lines[1:end]:
        line=raw.rstrip(b"\r\n").decode("utf-8","strict")
        if not line or line.lstrip().startswith("#"): continue
        if line[0] in " \t": continue
        match=re.match(r"^([A-Za-z][A-Za-z0-9_-]*):(?:[ \t]*(.*))?$",line)
        if not match: raise Fail("invalid top-level frontmatter")
        key,value=match.groups()
        if key not in ("name","description"): continue
        if key in data: raise Fail("duplicate required frontmatter key")
        value=(value or "").strip()
        if not value or value[0] in "|>{[&*!": raise Fail("required frontmatter scalar")
        if value[0] in "\"'":
            quote=value[0]
            if len(value)<2 or value[-1]!=quote: raise Fail("unterminated required scalar")
            value=value[1:-1]
            if quote=="'": value=value.replace("''", "'")
            else: value=json.loads('"'+value+'"')
        else:
            value=re.split(r"[ \t]+#",value,1)[0].rstrip()
        if not value or len(value.encode("utf-8"))>4096 or any(ord(x)<32 or ord(x)==127 for x in value): raise Fail("unsafe required scalar")
        data[key]=value
    if set(data)!={"name","description"}: raise Fail("missing required frontmatter keys")
    return data,b"".join(lines[end+1:]).decode("utf-8","strict")
def capability(skill_id,meta):
    words=set(re.findall(r"[a-z0-9]+",(skill_id+" "+meta["name"]+" "+meta["description"]).lower()))
    for key in ("implementation","verification","security","debug","testing","accessibility","data","api","ui","mobile","report"):
        if key in words: return key
    return "unknown"
def publish_tree(snapshot_root,skill_id,rows,body,total):
    files=[{"path":p,"mode":f"{m:04o}","size":len(d),"sha256":sha(d)} for p,m,d in rows]
    manifest={"schema_version":1,"skill_id":skill_id,"skill_md_rel":"SKILL.md","body_sha256":sha(body),
      "file_count":len(files),"total_bytes":total,"files":files}
    mbytes=canon(manifest); tree_hash=sha(mbytes); final=Path(snapshot_root)/("sha256-"+tree_hash[7:])
    with Lock(final,30):
        try: existing=os.lstat(final)
        except FileNotFoundError: existing=None
        if existing is not None:
            if not stat.S_ISDIR(existing.st_mode): raise Fail("snapshot collision")
            validate_tree({"id":skill_id,"snapshot_root":str(final),"skill_md_rel":"SKILL.md",
              "path":str(final/"SKILL.md"),"tree_manifest":str(final/".polylane-skill-tree.json"),
              "body_sha256":manifest["body_sha256"],"tree_sha256":tree_hash,
              "file_count":manifest["file_count"],"total_bytes":manifest["total_bytes"]})
        else:
            tmp=Path(snapshot_root)/f".tree.{os.getpid()}.{secrets.token_hex(8)}"; tmp.mkdir(mode=0o700)
            try:
                for rel,mode,data in rows:
                    dst=tmp/rel; dst.parent.mkdir(parents=True,exist_ok=True); atomic_write(dst,data,mode)
                atomic_write(tmp/".polylane-skill-tree.json",mbytes,0o444,True)
                for d,dirs,_ in os.walk(tmp,topdown=False):
                    for x in dirs: os.chmod(Path(d)/x,0o555)
                    os.chmod(d,0o555)
                os.rename(tmp,final); fsync_dir(final.parent)
            finally:
                if tmp.exists(): os.chmod(tmp,0o700); rm_tree(tmp)
    return final,manifest,tree_hash
def inventory(args):
    if args.adapter not in ("codex","claude-code"): raise Fail("unknown adapter")
    root_text=read_regular(args.roots_file,MAX_INV).decode("utf-8","strict")
    roots=[Path(x).absolute() for x in root_text.splitlines() if x]
    choices={}
    for rank,root in enumerate(roots,1):
        if not root.is_dir() or root.is_symlink(): continue
        for p in root.rglob("SKILL.md"):
            c=candidate(root,rank,p)
            if c: choices.setdefault(c["id"],[]).append(c)
    winners=[]
    for skill_id,items in choices.items():
        items.sort(key=lambda x:(x["root_rank"],-x["stable"],tuple(-n for n in version_key(x["version"])),x["version"],str(x["dir"])))
        winners.append(items[0])
    ensure_dir(args.snapshot_root,0o700); ensure_dir(Path(args.output).absolute().parent,0o700)
    bundled=Path(args.bundled_root).absolute() if args.bundled_root else None
    if bundled is not None:
        fd=nofollow_dir(bundled); os.close(fd)
    skills=[]; unavailable=[]; inv_total=0
    for c in sorted(winners,key=lambda x:x["id"]):
        try:
            rows,body,total=walk_snapshot(c["dir"]); inv_total+=total
            if inv_total>MAX_INV: raise Fail("inventory too large")
            meta,body_text=frontmatter(body); final,manifest,tree_hash=publish_tree(args.snapshot_root,c["id"],rows,body,total)
            reltext=(c["id"]+" "+meta["name"]+" "+meta["description"]+" "+body_text).lower().encode()
            origin="bundled" if bundled is not None and (c["dir"]==bundled or bundled in c["dir"].parents) else "external"
            skills.append({"id":c["id"],"origin":origin,"root_rank":c["root_rank"],"version":c["version"],
              "snapshot_root":str(final),"skill_md_rel":"SKILL.md",
              "path":str(final/"SKILL.md"),"tree_manifest":str(final/".polylane-skill-tree.json"),
              "body_sha256":manifest["body_sha256"],"tree_sha256":tree_hash,"file_count":manifest["file_count"],
              "total_bytes":manifest["total_bytes"],"capability":capability(c["id"],meta),
              "frontmatter":meta,"relevance_text_sha256":sha(reltext)})
        except (Fail,UnicodeError,OSError,ValueError) as e:
            unavailable.append({"id":c["id"],"reason":"snapshot_rejected","detail":str(e)})
    result={"schema_version":2,"adapter":args.adapter,"snapshot_root":str(Path(args.snapshot_root).absolute()),
      "limits":{"max_files":MAX_FILES,"max_file_bytes":MAX_FILE,"max_body_bytes":MAX_BODY,
        "max_tree_bytes":MAX_TREE,"max_inventory_bytes":MAX_INV},"skills":skills,"unavailable":unavailable}
    with Lock(args.output,30): immutable_publish(args.output,canon(result),0o444)
def existing_tree(root):
    root=Path(root).absolute(); rootfd=nofollow_dir(root); rows={}; manifests=[]
    if stat.S_IMODE(os.fstat(rootfd).st_mode)!=0o555: os.close(rootfd); raise Fail("tree directory mode")
    def walk(fd,prefix):
        names=[]
        with os.scandir(fd) as it:
            for e in it: names.append(e.name)
        for name in sorted(names,key=lambda x:x.encode("utf-8")):
            if not prefix and name==".polylane-skill-tree.json":
                st=os.stat(name,dir_fd=fd,follow_symlinks=False)
                if not stat.S_ISREG(st.st_mode) or stat.S_IMODE(st.st_mode)!=0o444: raise Fail("manifest mode")
                manifests.append(name); continue
            safe_name(name); rel=f"{prefix}/{name}" if prefix else name
            st=os.stat(name,dir_fd=fd,follow_symlinks=False)
            if stat.S_ISDIR(st.st_mode):
                if stat.S_IMODE(st.st_mode)!=0o555: raise Fail("tree directory mode")
                child=os.open(name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
                try: walk(child,rel)
                finally: os.close(child)
            elif stat.S_ISREG(st.st_mode):
                f=os.open(name,os.O_RDONLY|os.O_NOFOLLOW,dir_fd=fd); data=b""
                try:
                    while True:
                        chunk=os.read(f,65536)
                        if not chunk: break
                        data+=chunk
                        if len(data)>MAX_FILE: raise Fail("tree file too large")
                    after=os.fstat(f)
                    if (after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns)!=(st.st_dev,st.st_ino,st.st_size,st.st_mtime_ns): raise Fail("tree race")
                finally: os.close(f)
                rows[rel]={"mode":f"{stat.S_IMODE(st.st_mode):04o}","size":len(data),"sha256":sha(data)}
            else: raise Fail("special snapshot file")
    try: walk(rootfd,"")
    finally: os.close(rootfd)
    if manifests!=[".polylane-skill-tree.json"]: raise Fail("tree manifest count")
    return rows
def validate_tree(entry):
    root=Path(entry["snapshot_root"]); manifest=Path(entry["tree_manifest"]); body=root/entry["skill_md_rel"]
    if root.name!="sha256-"+entry["tree_sha256"][7:]: raise Fail("tree identity")
    if manifest!=root/".polylane-skill-tree.json" or body!=root/"SKILL.md": raise Fail("tree paths")
    mbytes=read_regular(manifest,MAX_INV,True)
    if sha(mbytes)!=entry["tree_sha256"]: raise Fail("tree manifest hash")
    m=json.loads(mbytes)
    if canon(m)!=mbytes: raise Fail("noncanonical tree manifest")
    if set(m)!={"schema_version","skill_id","skill_md_rel","body_sha256","file_count","total_bytes","files"}: raise Fail("tree manifest keys")
    if m["schema_version"]!=1 or m["skill_id"]!=entry["id"] or m["skill_md_rel"]!="SKILL.md": raise Fail("tree manifest identity")
    if not HEX.match(m["body_sha256"]): raise Fail("body hash format")
    if not isinstance(m["files"],list) or not 1<=len(m["files"])<=MAX_FILES: raise Fail("tree manifest count")
    if [x.get("path") for x in m["files"]]!=sorted([x.get("path") for x in m["files"]],key=lambda x:x.encode("utf-8")): raise Fail("tree manifest order")
    for row in m["files"]:
        if set(row)!={"path","mode","size","sha256"} or row["mode"] not in ("0444","0555") or not HEX.match(row["sha256"]): raise Fail("tree file schema")
        if not isinstance(row["size"],int) or not 0<=row["size"]<=MAX_FILE: raise Fail("tree file size")
        for part in row["path"].split("/"): safe_name(part)
    if m["body_sha256"]!=entry["body_sha256"] or sha(read_regular(body,MAX_BODY))!=entry["body_sha256"]: raise Fail("body hash")
    if m["file_count"]!=entry["file_count"] or m["total_bytes"]!=entry["total_bytes"]: raise Fail("tree totals")
    actual=existing_tree(root); expected={x["path"]:{k:x[k] for k in ("mode","size","sha256")} for x in m["files"]}
    if actual!=expected or sum(x["size"] for x in m["files"])!=m["total_bytes"]: raise Fail("tree files")
def validate_inventory(path):
    raw=read_regular(path,MAX_INV); obj=json.loads(raw)
    if canon(obj)!=raw: raise Fail("noncanonical inventory")
    if set(obj)!={"schema_version","adapter","snapshot_root","limits","skills","unavailable"}: raise Fail("inventory keys")
    limits={"max_files":MAX_FILES,"max_file_bytes":MAX_FILE,"max_body_bytes":MAX_BODY,
      "max_tree_bytes":MAX_TREE,"max_inventory_bytes":MAX_INV}
    if obj["schema_version"]!=2 or obj["adapter"] not in ("codex","claude-code") or obj["limits"]!=limits: raise Fail("inventory schema")
    base=Path(obj["snapshot_root"])
    if not base.is_absolute() or str(base)!=str(Path(str(base)).absolute()): raise Fail("snapshot base")
    fd=nofollow_dir(base); os.close(fd)
    if obj["skills"]!=sorted(obj["skills"],key=lambda x:x["id"]): raise Fail("inventory order")
    skill_keys={"id","origin","root_rank","version","snapshot_root","skill_md_rel","path",
      "tree_manifest","body_sha256","tree_sha256","file_count","total_bytes","capability",
      "frontmatter","relevance_text_sha256"}
    seen=set()
    for e in obj["skills"]:
        if set(e)!=skill_keys or e["origin"] not in ("external","bundled"): raise Fail("inventory entry keys")
        if e["id"] in seen: raise Fail("duplicate id")
        if not isinstance(e["root_rank"],int) or e["root_rank"]<1 or not isinstance(e["version"],str): raise Fail("inventory rank/version")
        if not HEX.match(e["body_sha256"]) or not HEX.match(e["tree_sha256"]) or not HEX.match(e["relevance_text_sha256"]): raise Fail("inventory hashes")
        if set(e["frontmatter"])!={"name","description"} or not all(isinstance(x,str) and x for x in e["frontmatter"].values()): raise Fail("frontmatter schema")
        tree=Path(e["snapshot_root"])
        if tree.parent!=base or e["path"]!=str(tree/"SKILL.md") or e["tree_manifest"]!=str(tree/".polylane-skill-tree.json"): raise Fail("snapshot containment")
        seen.add(e["id"]); validate_tree(e)
    if sum(x["total_bytes"] for x in obj["skills"])>MAX_INV: raise Fail("inventory total")
    if obj["unavailable"]!=sorted(obj["unavailable"],key=lambda x:x["id"]): raise Fail("unavailable order")
    unavailable=set()
    for row in obj["unavailable"]:
        if set(row)!={"id","reason","detail"} or row["reason"]!="snapshot_rejected" or not all(isinstance(row[k],str) and row[k] for k in row): raise Fail("unavailable schema")
        if row["id"] in unavailable or row["id"] in seen: raise Fail("unavailable collision")
        unavailable.add(row["id"])
def append_jsonl(target,record,key):
    rec_raw=read_regular(record,MAX_INV); rec=json.loads(rec_raw); value=rec.get(key)
    if canon(rec)!=rec_raw: raise Fail("noncanonical record")
    if not isinstance(value,str) or not value: raise Fail("missing dedupe key")
    with Lock(target,30):
        target=Path(target).absolute(); records=Path(str(target)+".segments"); keys=Path(str(target)+".keys")
        ensure_dir(records,0o700); ensure_dir(keys,0o700)
        index={"schema_version":2,"kind":"segmented-ledger","records_root":str(records),"keys_root":str(keys)}
        if target.exists():
            raw=read_regular(target,MAX_INV); existing=json.loads(raw)
            if raw!=canon(existing) or existing!=index: raise Fail("ledger index")
        record_hash=sha(rec_raw); key_hash=sha(value.encode("utf-8"))
        record_dir=records/record_hash[7:9]; key_dir=keys/key_hash[7:9]
        ensure_dir(record_dir,0o700); ensure_dir(key_dir,0o700)
        segment=record_dir/(record_hash[7:]+".json")
        if segment.exists():
            if read_regular(segment,MAX_INV)!=rec_raw: raise Fail("segment collision")
        else: atomic_write(segment,rec_raw,0o444)
        if os.getenv("POLYLANE_STORE_FAULT")=="ledger-after-segment":
            gate=Path(os.environ["POLYLANE_STORE_GATE"]); atomic_write(str(gate)+".ready",b"ready\n",0o400)
            while True:
                try: read_regular(gate,32); break
                except (OSError,Fail): time.sleep(.02)
        marker=key_dir/(key_hash[7:]+".json")
        marker_value={"schema_version":1,"dedupe_key":value,"record_sha256":record_hash}
        if marker.exists():
            raw=read_regular(marker,MAX_INV); old=json.loads(raw)
            if raw!=canon(old) or old!=marker_value: raise Fail("dedupe conflict")
        else: atomic_write(marker,canon(marker_value),0o444)
        atomic_write(target,canon(index),0o444)
def read_ledger(target,key):
    target=Path(target).absolute(); raw=read_regular(target,MAX_INV); index=json.loads(raw)
    expected={"schema_version":2,"kind":"segmented-ledger","records_root":str(Path(str(target)+".segments")),"keys_root":str(Path(str(target)+".keys"))}
    if raw!=canon(index) or index!=expected: raise Fail("ledger index")
    records=Path(index["records_root"]); keys=Path(index["keys_root"])
    kfd=nofollow_dir(keys)
    try:
        for shard in sorted(os.listdir(kfd)):
            if not re.match(r"^[0-9a-f]{2}$",shard): raise Fail("ledger key shard")
            sfd=os.open(shard,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=kfd)
            try:
                for name in sorted(os.listdir(sfd)):
                    if not re.match(r"^[0-9a-f]{64}\.json$",name): raise Fail("ledger key marker")
                    marker_raw=Lock.read_at(sfd,name,MAX_INV); marker=json.loads(marker_raw)
                    if marker_raw!=canon(marker) or set(marker)!={"schema_version","dedupe_key","record_sha256"}: raise Fail("ledger marker schema")
                    if sha(marker["dedupe_key"].encode("utf-8"))[7:]+".json"!=name: raise Fail("ledger key hash")
                    record_hash=marker["record_sha256"]
                    if not HEX.match(record_hash): raise Fail("ledger record hash")
                    segment=records/record_hash[7:9]/(record_hash[7:]+".json")
                    record_raw=read_regular(segment,MAX_INV); record=json.loads(record_raw)
                    if record_raw!=canon(record) or sha(record_raw)!=record_hash or record.get(key)!=marker["dedupe_key"]: raise Fail("ledger record")
                    sys.stdout.buffer.write(record_raw)
            finally: os.close(sfd)
    finally: os.close(kfd)
def main():
    p=argparse.ArgumentParser(); sub=p.add_subparsers(dest="cmd",required=True)
    q=sub.add_parser("inventory"); q.add_argument("--adapter",required=True); q.add_argument("--roots-file",required=True); q.add_argument("--output",required=True); q.add_argument("--snapshot-root",required=True); q.add_argument("--bundled-root")
    q=sub.add_parser("validate-inventory"); q.add_argument("path")
    q=sub.add_parser("validate-assignment"); q.add_argument("assignment"); q.add_argument("inventory")
    q=sub.add_parser("append-jsonl"); q.add_argument("target"); q.add_argument("record"); q.add_argument("key")
    q=sub.add_parser("read-ledger"); q.add_argument("target"); q.add_argument("key")
    q=sub.add_parser("process-token"); q.add_argument("pid",type=int)
    q=sub.add_parser("ensure-dir"); q.add_argument("path"); q.add_argument("mode")
    a=p.parse_args()
    try:
        if a.cmd=="inventory": inventory(a)
        elif a.cmd=="validate-inventory": validate_inventory(a.path)
        elif a.cmd=="validate-assignment":
            eraw=read_regular(a.assignment,MAX_INV); e=json.loads(eraw)
            if canon(e)!=eraw: raise Fail("noncanonical assignment")
            validate_inventory(a.inventory); inv=read_json(a.inventory)
            matches=[x for x in inv["skills"] if x["id"]==e.get("id")]
            identity=("id","origin","snapshot_root","skill_md_rel","path","tree_manifest",
              "body_sha256","tree_sha256","file_count","total_bytes","capability","frontmatter")
            if len(matches)!=1 or any(e.get(k)!=matches[0].get(k) for k in identity): raise Fail("assignment identity")
            validate_tree(e)
        elif a.cmd=="append-jsonl": append_jsonl(a.target,a.record,a.key)
        elif a.cmd=="read-ledger": read_ledger(a.target,a.key)
        elif a.cmd=="process-token":
            value=token(a.pid)
            if not value: raise Fail("process token unavailable")
            print(value)
        else:
            if not re.match(r"^0[0-7]{3}$",a.mode): raise Fail("directory mode")
            ensure_dir(a.path,int(a.mode,8))
    except (Fail,OSError,ValueError,TypeError,KeyError,json.JSONDecodeError,UnicodeError) as e: die(str(e))
if __name__=="__main__": main()
```

Create `core/scripts/polylane-skill-store.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
exec python3 "$SCRIPT_DIR/polylane-skill-store.py" "$@"
```

Copy the Python body byte-for-byte to `core/tests/fixtures/skill-store-v2.py`, then run:

```bash
chmod +x core/scripts/polylane-skill-store.py core/scripts/polylane-skill-store.sh
python3 -m py_compile core/scripts/polylane-skill-store.py
cmp core/scripts/polylane-skill-store.py core/tests/fixtures/skill-store-v2.py
bash -n core/scripts/polylane-skill-store.sh
```

Expected GREEN: all commands exit 0. The parity copy is intentional: security review can
diff the frozen audited fixture against the runtime helper.

- [ ] **Step 4: Add complete installed-only adapter entrypoints**

Create `codex/scripts/polylane-codex-skills.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PACKAGE_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
ENGINE=${POLYLANE_SKILL_ENGINE:-$SCRIPT_DIR/polylane-skill-store.sh}
[ -x "$ENGINE" ] || { echo "codex-skills: installed skill-store helper unavailable" >&2; exit 5; }
case ${1:-} in
  inventory)
    [ "$#" -eq 3 ] || exit 2
    roots=${POLYLANE_CODEX_SKILL_ROOTS:-$PACKAGE_ROOT/bundled-skills:${CODEX_HOME:-$HOME/.codex}/skills:${CODEX_HOME:-$HOME/.codex}/plugins/cache}
    roots_file=$(mktemp "${TMPDIR:-/tmp}/polylane-codex-roots.XXXXXX")
    trap 'rm -f "$roots_file"' EXIT INT TERM HUP
    old=$IFS; IFS=:
    for root in $roots; do printf '%s\n' "$root"; done > "$roots_file"
    IFS=$old
    "$ENGINE" inventory --adapter codex --roots-file "$roots_file" --output "$2" \
      --snapshot-root "$3" --bundled-root "$PACKAGE_ROOT/bundled-skills"
    ;;
  search-terms) printf '%s\n' '["Codex Agent Skill","OpenAI Codex SKILL.md"]' ;;
  *) echo "usage: polylane-codex-skills.sh inventory <output.json> <snapshot-root> | search-terms" >&2; exit 2 ;;
esac
```

Create `claude-code/scripts/polylane-claude-skills.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PACKAGE_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
ENGINE=${POLYLANE_SKILL_ENGINE:-$SCRIPT_DIR/polylane-skill-store.sh}
[ -x "$ENGINE" ] || { echo "claude-skills: installed skill-store helper unavailable" >&2; exit 5; }
case ${1:-} in
  inventory)
    [ "$#" -eq 3 ] || exit 2
    roots=${POLYLANE_CLAUDE_SKILL_ROOTS:-$PACKAGE_ROOT/bundled-skills:${CLAUDE_HOME:-$HOME/.claude}/skills:${CLAUDE_HOME:-$HOME/.claude}/plugins/cache}
    roots_file=$(mktemp "${TMPDIR:-/tmp}/polylane-claude-roots.XXXXXX")
    trap 'rm -f "$roots_file"' EXIT INT TERM HUP
    old=$IFS; IFS=:
    for root in $roots; do printf '%s\n' "$root"; done > "$roots_file"
    IFS=$old
    "$ENGINE" inventory --adapter claude-code --roots-file "$roots_file" --output "$2" \
      --snapshot-root "$3" --bundled-root "$PACKAGE_ROOT/bundled-skills"
    ;;
  search-terms) printf '%s\n' '["Claude Code Agent Skill","Agent SKILL.md"]' ;;
  *) echo "usage: polylane-claude-skills.sh inventory <output.json> <snapshot-root> | search-terms" >&2; exit 2 ;;
esac
```

These scripts deliberately have no `../../core` fallback. Source tests set
`POLYLANE_SKILL_ENGINE`; installed packages resolve the recursively shipped sibling helper.

- [ ] **Step 5: Materialize the exact fourteen bundled fallback trees**

Run this complete generator once, then commit the resulting `SKILL.md` files:

```bash
set -euo pipefail
for domain in ui api data mobile report test unknown; do
  for kind in implementation verification; do
    dir="core/bundled-skills/$domain-$kind"; mkdir -p "$dir"
    case "$kind" in
      implementation) verb="Implement the owned $domain behavior from one focused failing repository-native check." ;;
      verification) verb="Verify the owned $domain behavior with fresh focused and relevant regression commands." ;;
    esac
    apply="Record commands, exit codes, changed artifacts, and every environment-dependent check not run."
    printf '%s\n' '---' "name: polylane-$domain-$kind" \
      "description: $kind contract for $domain builder lanes" '---' '' \
      "# $domain $kind" '' "1. $verb" \
      '2. Preserve ownership boundaries and existing public contracts.' \
      "3. $apply" > "$dir/SKILL.md"
    mkdir -p "$dir/references"
    printf '%s\n' "domain=$domain" "capability=$kind" \
      'Treat this relative resource as part of the immutable skill contract.' \
      > "$dir/references/contract.md"
  done
done
test "$(find core/bundled-skills -name SKILL.md | wc -l | tr -d ' ')" = 14
test "$(find core/bundled-skills -type f | wc -l | tr -d ' ')" = 28
```

Expected: exactly fourteen skill directories, each with `SKILL.md` plus one relative
resource; the package map ships all 28 files recursively without another package hook.

- [ ] **Step 6: Add lock successor and tree-tamper tests**

Create `core/tests/test-skill-store-locks.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
TEST_TMPDIR=$(cd "$TEST_TMPDIR" && pwd -P)
STORE="$ROOT/core/scripts/polylane-skill-store.sh"; T="$TEST_TMPDIR/store"
mkdir -p "$T"; printf '%s\n' '{"dedupe_key":"a","value":1}' > "$T/a.json"
printf '%s\n' '{"dedupe_key":"b","value":2}' > "$T/b.json"
POLYLANE_STORE_LOCK_SECONDS=1 POLYLANE_STORE_FAULT=lock-init-wait \
  POLYLANE_STORE_GATE="$T/killed" "$STORE" append-jsonl "$T/killed.jsonl" \
  "$T/a.json" dedupe_key >"$T/killed.out" 2>&1 & killed=$!
i=0; while [ ! -f "$T/killed.ready" ] && [ "$i" -lt 100 ]; do sleep 0.02; i=$((i+1)); done
kill -9 "$killed" 2>/dev/null; wait "$killed" 2>/dev/null || true
POLYLANE_STORE_LOCK_SECONDS=3 "$STORE" append-jsonl "$T/killed.jsonl" "$T/b.json" dedupe_key
assert_eq "killed-initializer-successor" b \
  "$("$STORE" read-ledger "$T/killed.jsonl" dedupe_key | jq -r .dedupe_key)"
assert_fail "killed-public-lock-gone" test -e "$T/killed.jsonl.lock"

# Force the ABA schedule: the first initializer remains alive past its lease; the successor
# reclaims the exact generation and pauses while owning the same fixed public pathname; only
# then may the old initializer resume. Its open fd names the detached generation, so it cannot
# add to or remove the successor.
POLYLANE_STORE_LOCK_SECONDS=1 POLYLANE_STORE_FAULT=lock-init-wait \
  POLYLANE_STORE_GATE="$T/old-gate" "$STORE" append-jsonl "$T/aba.jsonl" \
  "$T/a.json" dedupe_key >"$T/old.out" 2>&1 & old=$!
i=0; while [ ! -f "$T/old-gate.ready" ] && [ "$i" -lt 100 ]; do sleep 0.02; i=$((i+1)); done
POLYLANE_STORE_LOCK_SECONDS=5 POLYLANE_STORE_FAULT=lock-close-wait \
  POLYLANE_STORE_GATE="$T/new-gate" "$STORE" append-jsonl "$T/aba.jsonl" \
  "$T/b.json" dedupe_key >"$T/new.out" 2>&1 & successor=$!
i=0; while [ ! -f "$T/new-gate.ready" ] && [ "$i" -lt 200 ]; do sleep 0.02; i=$((i+1)); done
: > "$T/old-gate"; sleep 1
assert_ok "successor-still-live" kill -0 "$successor"
assert_ok "successor-fixed-lock-present" test -d "$T/aba.jsonl.lock"
assert_eq "successor-publication-survives" b \
  "$("$STORE" read-ledger "$T/aba.jsonl" dedupe_key | jq -r .dedupe_key)"
wait "$old" 2>/dev/null || true
: > "$T/new-gate"; wait "$successor"
assert_fail "aba-public-lock-gone" test -e "$T/aba.jsonl.lock"

mkdir -p "$T/fake.lock"
printf '%s\n' '{"schema_version":1,"pid":999999,"start_token":"dead","nonce":"old","generation":1,"deadline_epoch":1}' \
  > "$T/fake.lock/owner.1.old.json"
chmod 0400 "$T/fake.lock/owner.1.old.json"
printf '%s\n' '{"dedupe_key":"c","value":3}' > "$T/c.json"
"$STORE" append-jsonl "$T/fake" "$T/c.json" dedupe_key
assert_eq "stale-lock-reclaimed" c \
  "$("$STORE" read-ledger "$T/fake" dedupe_key | jq -r .dedupe_key)"
assert_fail "stale-public-gone" test -e "$T/fake.lock"
printf '%s\n' '{"dedupe_key":"c","value":99}' > "$T/conflict.json"
assert_rc "same-key-different-content" 5 "$STORE" append-jsonl "$T/fake" "$T/conflict.json" dedupe_key
assert_eq "conflict-does-not-overwrite" 3 \
  "$("$STORE" read-ledger "$T/fake" dedupe_key | jq -r .value)"

printf '%s\n' '{"dedupe_key":"d","value":4}' > "$T/d.json"
POLYLANE_STORE_FAULT=ledger-after-segment POLYLANE_STORE_GATE="$T/segment-gate" \
  "$STORE" append-jsonl "$T/segmented" "$T/d.json" dedupe_key >"$T/segment.out" 2>&1 & crashed=$!
i=0; while [ ! -f "$T/segment-gate.ready" ] && [ "$i" -lt 100 ]; do sleep 0.02; i=$((i+1)); done
kill -9 "$crashed" 2>/dev/null; wait "$crashed" 2>/dev/null || true
"$STORE" append-jsonl "$T/segmented" "$T/d.json" dedupe_key
assert_eq "crash-segment-recovered" 1 \
  "$("$STORE" read-ledger "$T/segmented" dedupe_key | wc -l | tr -d ' ')"
printf '%s\n' '{"dedupe_key":"e","value":5}' > "$T/e.json"
printf '%s\n' '{"dedupe_key":"f","value":6}' > "$T/f.json"
"$STORE" append-jsonl "$T/segmented" "$T/e.json" dedupe_key & one=$!
"$STORE" append-jsonl "$T/segmented" "$T/f.json" dedupe_key & two=$!
wait "$one"; wait "$two"
assert_eq "concurrent-segments" 3 \
  "$("$STORE" read-ledger "$T/segmented" dedupe_key | wc -l | tr -d ' ')"
assert_ok "constant-size-index" test "$(wc -c <"$T/segmented")" -lt 1024
finish
```

Create `core/tests/test-skill-tree-validation.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
TEST_TMPDIR=$(cd "$TEST_TMPDIR" && pwd -P)
SRC="$TEST_TMPDIR/src"; SNAP="$TEST_TMPDIR/snap"; OUT="$TEST_TMPDIR/inventory.json"
mkdir -p "$SRC/sample/references"
printf '%s\n' '---' 'name: sample' 'description: REST sample implementation' '---' '' 'REST implementation body' > "$SRC/sample/SKILL.md"
printf resource > "$SRC/sample/references/a.md"
printf '%s\n' "$SRC" > "$TEST_TMPDIR/roots"
"$ROOT/core/scripts/polylane-skill-store.sh" inventory --adapter codex \
  --roots-file "$TEST_TMPDIR/roots" --output "$OUT" --snapshot-root "$SNAP"
assert_ok "valid-tree" "$ROOT/core/scripts/polylane-skill-store.sh" validate-inventory "$OUT"
tree=$(jq -r '.skills[0].snapshot_root' "$OUT")
chmod 0644 "$tree/references/a.md"; printf tamper >> "$tree/references/a.md"; chmod 0444 "$tree/references/a.md"
assert_rc "resource-tamper" 5 "$ROOT/core/scripts/polylane-skill-store.sh" validate-inventory "$OUT"
chmod 0644 "$tree/references/a.md"; printf resource > "$tree/references/a.md"; chmod 0444 "$tree/references/a.md"
assert_ok "restored-tree" "$ROOT/core/scripts/polylane-skill-store.sh" validate-inventory "$OUT"
chmod 0755 "$tree/references"; rm "$tree/references/a.md"
ln -s ../SKILL.md "$tree/references/a.md"; chmod 0555 "$tree/references"
assert_rc "snapshot-file-symlink" 5 "$ROOT/core/scripts/polylane-skill-store.sh" validate-inventory "$OUT"

mkdir "$TEST_TMPDIR/real-snap"; ln -s "$TEST_TMPDIR/real-snap" "$TEST_TMPDIR/link-snap"
assert_rc "snapshot-root-symlink" 5 "$ROOT/core/scripts/polylane-skill-store.sh" inventory \
  --adapter codex --roots-file "$TEST_TMPDIR/roots" --output "$TEST_TMPDIR/link-out.json" \
  --snapshot-root "$TEST_TMPDIR/link-snap"
assert_fail "symlink-root-no-output" test -e "$TEST_TMPDIR/link-out.json"
finish
```

Run:

```bash
chmod +x codex/scripts/polylane-codex-skills.sh claude-code/scripts/polylane-claude-skills.sh \
  core/tests/test-skill-store-locks.sh core/tests/test-skill-tree-validation.sh
bash codex/tests/test-codex-skill-inventory.sh
bash claude-code/tests/test-claude-skill-inventory.sh
bash core/tests/test-skill-store-locks.sh
bash core/tests/test-skill-tree-validation.sh
```

Expected GREEN: all four exit 0. The delayed killed initializer cannot erase the successor.

- [ ] **Step 7: Run Task 1 static checks and commit**

```bash
python3 -m py_compile core/scripts/polylane-skill-store.py
bash -n core/scripts/polylane-skill-store.sh codex/scripts/polylane-codex-skills.sh \
  claude-code/scripts/polylane-claude-skills.sh core/tests/skill-inventory-contract.sh \
  core/tests/test-skill-store-locks.sh core/tests/test-skill-tree-validation.sh
shellcheck -S warning core/scripts/polylane-skill-store.sh \
  codex/scripts/polylane-codex-skills.sh claude-code/scripts/polylane-claude-skills.sh \
  core/tests/skill-inventory-contract.sh core/tests/test-skill-store-locks.sh \
  core/tests/test-skill-tree-validation.sh
git diff --check
git add core/scripts/polylane-skill-store.py core/scripts/polylane-skill-store.sh \
  core/bundled-skills core/tests/skill-inventory-contract.sh \
  core/tests/fixtures/skill-store-v2.py core/tests/test-skill-store-locks.sh \
  core/tests/test-skill-tree-validation.sh codex/scripts/polylane-codex-skills.sh \
  codex/tests/test-codex-skill-inventory.sh claude-code/scripts/polylane-claude-skills.sh \
  claude-code/tests/test-claude-skill-inventory.sh
git commit -m "feat(core): snapshot bounded immutable skill trees"
```

Expected: syntax, ShellCheck, whitespace, and focused tests are green; the commit succeeds.

---

### Task 2: Select Exact Kits, Frame Exact Bytes, and Attest Runner Evidence

**Files:**
- Create: `core/scripts/polylane-skill-kit.py`
- Create: `core/scripts/polylane-skill-kit.sh`
- Create: `core/scripts/polylane-skill-ledger.sh`
- Create: `core/tests/test-skill-kit-selection.sh`
- Create: `core/tests/test-skill-prompt-framing.sh`
- Create: `core/tests/test-skill-attestation.sh`

**Interfaces:**
- `select MANIFEST INVENTORY SNAPSHOT_ROOT PACKAGE_ROOT KIT_DIR` writes immutable
  `KIT_DIR/<lane>.json` files and an `index.json` for Builder lanes only.
- `build-prompt ORIGINAL KIT OUTPUT` writes a length-prefixed exact-byte envelope;
  `lint-prompt ORIGINAL KIT OUTPUT` reparses it and revalidates all four snapshots.
- `qualify MANIFEST KIT PROMPT WORKER_RESULT ACTOR DONE VERIFY REPO ARTIFACT_DIR OUTPUT`
  is the only attestation writer. It executes the manifest-owned verification argv directly.
- `score ATTESTATION KIT LEDGER` accepts only a successful runner attestation and uses the
  Task 1 conflict-detecting CAS append. Its public marker key binds runner claim/generation/
  attempt and attestation hash, so replay within one attempt is idempotent and a later attempt
  cannot conflict with or overwrite earlier evidence. Worker prose is never a scoring input.

- [ ] **Step 1: Write the complete selection/framing contract test**

Create `core/tests/test-skill-kit-selection.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
TEST_TMPDIR=$(cd "$TEST_TMPDIR" && pwd -P)
STORE="$ROOT/core/scripts/polylane-skill-store.sh"
KIT="$ROOT/core/scripts/polylane-skill-kit.sh"
export POLYLANE_CLAIM_TOKEN=selection-claim POLYLANE_RUNNER_GENERATION=2 POLYLANE_ATTEMPT=1
SRC="$TEST_TMPDIR/external"; BUNDLED="$TEST_TMPDIR/package/bundled-skills"
SNAP="$TEST_TMPDIR/snap"; INV="$TEST_TMPDIR/inventory.json"
mkdir -p "$SRC" "$BUNDLED" "$TEST_TMPDIR/kits"
skill() {
  root=$1 id=$2 description=$3 body=$4
  mkdir -p "$root/$id"
  printf '%s\n' '---' "name: $id" "description: $description" '---' '' "$body" \
    >"$root/$id/SKILL.md"
}
skill "$SRC" superpowers:test-driven-development 'TDD implementation contract' \
  'Write a focused failing test, then implementation.'
skill "$SRC" superpowers:verification-before-completion 'Fresh verification contract' \
  'Run fresh verification before completion.'
skill "$SRC" rest-debug 'REST API debugging' \
  'Reproduce REST API route failures and debug handler behavior.'
skill "$SRC" contract-test 'REST API contract testing' \
  'Verify REST API contract responses with focused tests.'
skill "$SRC" metadata-only 'REST API metadata' 'Unrelated rendering words.'
skill "$SRC" body-only 'Unrelated metadata' 'REST API implementation body.'
for domain in ui api data mobile report test unknown; do
  skill "$BUNDLED" "$domain-implementation" "$domain implementation fallback" \
    "Implement $domain behavior."
  skill "$BUNDLED" "$domain-verification" "$domain verification fallback" \
    "Verify $domain behavior."
done
printf '%s\n' "$BUNDLED" "$SRC" >"$TEST_TMPDIR/roots"
"$STORE" inventory --adapter codex --roots-file "$TEST_TMPDIR/roots" \
  --output "$INV" --snapshot-root "$SNAP" --bundled-root "$BUNDLED"
cat >"$TEST_TMPDIR/manifest.raw.json" <<'JSON'
{"agent":"codex","cycle":3,"loop_id":"pl-test","run_id":"nonce-3","lanes":[
 {"name":"api","role":"builder","activities":["REST API route"],"ownership_globs":["src/api/**"],
  "verification_argv":["/usr/bin/test","-f","api-output.txt"]},
 {"name":"mystery","role":"builder","activities":[],"ownership_globs":["misc/**"],
  "verification_argv":["/usr/bin/test","-f","mystery-output.txt"]},
 {"name":"integrator","role":"integrator","activities":["REST API"],"ownership_globs":["**"],
  "verification_argv":["/usr/bin/git","diff","--check"]}]}
JSON
jq -cS . "$TEST_TMPDIR/manifest.raw.json" >"$TEST_TMPDIR/manifest.json"
"$KIT" select "$TEST_TMPDIR/manifest.json" "$INV" "$SNAP" \
  "$TEST_TMPDIR/package" "$TEST_TMPDIR/kits"
jq -cS '(.lanes[] | .own_globs=.ownership_globs | del(.ownership_globs))' \
  "$TEST_TMPDIR/manifest.json" >"$TEST_TMPDIR/legacy-manifest.json"
mkdir "$TEST_TMPDIR/legacy-kits"
"$KIT" select "$TEST_TMPDIR/legacy-manifest.json" "$INV" "$SNAP" \
  "$TEST_TMPDIR/package" "$TEST_TMPDIR/legacy-kits"
assert_ok "legacy-own-globs-compatibility" test -f "$TEST_TMPDIR/legacy-kits/api.json"
jq -cS '(.lanes[0].own_globs=.lanes[0].ownership_globs)' \
  "$TEST_TMPDIR/manifest.json" >"$TEST_TMPDIR/ambiguous-manifest.json"
assert_rc "ambiguous-ownership-rejected-before-output" 5 "$KIT" select \
  "$TEST_TMPDIR/ambiguous-manifest.json" "$INV" "$SNAP" \
  "$TEST_TMPDIR/package" "$TEST_TMPDIR/ambiguous-kits"
assert_fail "ambiguous-ownership-created-no-kit-dir" test -e "$TEST_TMPDIR/ambiguous-kits"
assert_eq "builder-kit-count" 3 "$(find "$TEST_TMPDIR/kits" -name '*.json' | wc -l | tr -d ' ')"
assert_fail "no-integrator-kit" test -e "$TEST_TMPDIR/kits/integrator.json"
assert_ok "index-binds-inputs" jq -e \
  '.schema_version==1 and (.manifest_sha256|test("^sha256:[0-9a-f]{64}$")) and
   (.inventory_sha256|test("^sha256:[0-9a-f]{64}$")) and
   [.kits[].lane]==["api","mystery"] and all(.kits[];.tree_sha256|length==4)' \
  "$TEST_TMPDIR/kits/index.json"
assert_ok "four-assignments" jq -e \
  '.runner=={"attempt":1,"claim":"selection-claim","generation":2} and .actor==null and
   (.assignments|length)==4 and all(.assignments[];.tree_sha256|test("^sha256:[0-9a-f]{64}$"))' \
  "$TEST_TMPDIR/kits/api.json"
assert_ok "two-plus-two" jq -e \
  '[.assignments[]|select(.slot=="predefined")]|length==2 and
   [.assignments[]|select(.slot=="specific")]|length==2' "$TEST_TMPDIR/kits/api.json"
assert_eq "predefined-ids" \
  'superpowers:test-driven-development,superpowers:verification-before-completion' \
  "$(jq -r '[.assignments[]|select(.slot=="predefined")|.id]|sort|join(",")' "$TEST_TMPDIR/kits/api.json")"
assert_eq "specific-distinct-capabilities" 2 \
  "$(jq '[.assignments[]|select(.slot=="specific")|.capability]|unique|length' "$TEST_TMPDIR/kits/api.json")"
assert_eq "api-fallback-count" 0 "$(jq -r .fallback_count "$TEST_TMPDIR/kits/api.json")"
assert_eq "unknown-exact-pair" 'unknown-implementation,unknown-verification' \
  "$(jq -r '[.assignments[]|select(.slot=="specific")|.id]|sort|join(",")' "$TEST_TMPDIR/kits/mystery.json")"
assert_eq "unknown-fallback-count" 2 "$(jq -r .fallback_count "$TEST_TMPDIR/kits/mystery.json")"
assert_eq "metadata-body-only-rejected" 0 \
  "$(jq '[.assignments[]|select(.id=="metadata-only" or .id=="body-only")]|length' "$TEST_TMPDIR/kits/api.json")"

jq 'del(.skills[]|select(.id=="contract-test"))' "$INV" |
  jq -cS . >"$TEST_TMPDIR/one.json"
rm -rf "$TEST_TMPDIR/one-kits"; mkdir "$TEST_TMPDIR/one-kits"
"$KIT" select "$TEST_TMPDIR/manifest.json" "$TEST_TMPDIR/one.json" "$SNAP" \
  "$TEST_TMPDIR/package" "$TEST_TMPDIR/one-kits"
assert_eq "exact-one-fallback" 1 "$(jq -r .fallback_count "$TEST_TMPDIR/one-kits/api.json")"
finish
```

Create `core/tests/test-skill-prompt-framing.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
TEST_TMPDIR=$(cd "$TEST_TMPDIR" && pwd -P)
F="$TEST_TMPDIR/frame"; mkdir -p "$F"
export POLYLANE_CLAIM_TOKEN=frame-claim POLYLANE_RUNNER_GENERATION=2 POLYLANE_ATTEMPT=1
"$ROOT/core/scripts/polylane-skill-kit.sh" fixture "$F"
mkdir -p "$F/worktree"
"$ROOT/core/scripts/polylane-skill-kit.sh" materialize \
  "$F/kit.json" "$F/worktree" "$F/local-kit.json"
assert_eq "four-lane-local-trees" 4 \
  "$(jq --arg root "$F/worktree/.polylane/skill-snapshots/" \
    '[.assignments[]|select(.snapshot_root|startswith($root))]|length' "$F/local-kit.json")"
assert_ok "relative-resource-local" test -f \
  "$(jq -r '.assignments[0].snapshot_root' "$F/local-kit.json")/references/checks.md"
assert_ok "relative-script-local" test -x \
  "$(jq -r '.assignments[0].snapshot_root' "$F/local-kit.json")/scripts/probe.sh"
printf 'original marker bytes\nFRAME-COUNT 999\nBODY-BYTES 999999\n\000tail\n' >"$F/original"
"$ROOT/core/scripts/polylane-skill-kit.sh" build-prompt "$F/original" "$F/local-kit.json" "$F/prompt"
assert_ok "exact-lint" "$ROOT/core/scripts/polylane-skill-kit.sh" lint-prompt \
  "$F/original" "$F/local-kit.json" "$F/prompt"
cp "$F/prompt" "$F/tampered"; chmod 0644 "$F/tampered"
printf X >>"$F/tampered"; chmod 0444 "$F/tampered"
assert_rc "trailing-byte-rejected" 5 "$ROOT/core/scripts/polylane-skill-kit.sh" lint-prompt \
  "$F/original" "$F/local-kit.json" "$F/tampered"
tree=$(jq -r '.assignments[0].snapshot_root' "$F/local-kit.json")
chmod 0644 "$tree/SKILL.md"; printf X >>"$tree/SKILL.md"; chmod 0444 "$tree/SKILL.md"
assert_rc "snapshot-identity-rechecked" 5 "$ROOT/core/scripts/polylane-skill-kit.sh" lint-prompt \
  "$F/original" "$F/local-kit.json" "$F/prompt"
finish
```

Run:

```bash
chmod +x core/tests/test-skill-kit-selection.sh core/tests/test-skill-prompt-framing.sh
bash core/tests/test-skill-kit-selection.sh
bash core/tests/test-skill-prompt-framing.sh
```

Expected RED: the selector/framer does not exist.

- [ ] **Step 2: Add the complete selector, framer, and synthetic-equivalent helper**

Create `core/scripts/polylane-skill-kit.py`:

```python
#!/usr/bin/env python3
import argparse, hashlib, importlib.util, json, os, re, selectors, subprocess, sys, time
from pathlib import Path

HERE=Path(__file__).resolve().parent
SPEC=importlib.util.spec_from_file_location("polylane_skill_store",HERE/"polylane-skill-store.py")
store=importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(store)
MAX_FOUR=2097152
VERIFY_STREAM_MAX=4194304; VERIFY_COMBINED_MAX=6291456; VERIFY_TIMEOUT=300
PREDEFINED=("superpowers:test-driven-development","superpowers:verification-before-completion")
EQUIVALENTS={
 PREDEFINED[0]:b"---\nname: equivalent-test-driven-development\ndescription: TDD implementation equivalent\n---\n\nWrite one focused failing test, implement the smallest change, then refactor with tests green.\n",
 PREDEFINED[1]:b"---\nname: equivalent-verification-before-completion\ndescription: Fresh verification equivalent\n---\n\nRun the manifest-owned focused command freshly and report its exact result before completion.\n"}
DOMAINS=("ui","api","data","mobile","report","test")
WORDS={
 "ui":{"ui","web","frontend","css","html","accessibility","component"},
 "api":{"api","rest","route","http","endpoint","service"},
 "data":{"data","sql","database","query","analytics","etl"},
 "mobile":{"mobile","ios","android","swift","kotlin"},
 "report":{"report","document","pdf","xlsx","slides","dashboard"},
 "test":{"test","tests","testing","fixture","regression"}}
ASSIGNMENT_KEYS=("id","origin","snapshot_root","skill_md_rel","path","tree_manifest",
 "body_sha256","tree_sha256","file_count","total_bytes","capability","frontmatter")

def fail(message): raise store.Fail(message)
def canon(value): return store.canon(value)
def sha(value): return store.sha(value)
def load(path,canonical=False):
    raw=store.read_regular(path,store.MAX_INV); value=json.loads(raw)
    if canonical and canon(value)!=raw: fail("noncanonical JSON")
    return value
def load_manifest(path):
    raw=store.read_regular(path,store.MAX_INV,True); value=json.loads(raw)
    if canon(value)!=raw: fail("noncanonical tree manifest")
    return value
def publish_bytes(path,data,mode=0o444,replace=False):
    store.ensure_dir(Path(path).absolute().parent,0o755)
    with store.Lock(path,30):
        if os.path.lexists(path) and not replace:
            if store.read_regular(path,store.MAX_INV)!=data: fail("immutable publication conflict")
        elif replace: store.atomic_write(path,data,mode)
        else: store.immutable_publish(path,data,mode)
def publish(path,value,replace=False): publish_bytes(path,canon(value),0o444,replace)
def kit_hash(kit):
    value=dict(kit); value.pop("kit_sha256",None); return sha(canon(value))
def runner_scope():
    claim=os.environ.get("POLYLANE_CLAIM_TOKEN","")
    try:
        generation=int(os.environ.get("POLYLANE_RUNNER_GENERATION","-1"))
        attempt=int(os.environ.get("POLYLANE_ATTEMPT","-1"))
    except ValueError: fail("runner kit identity")
    if (not re.match(r"^[A-Za-z0-9_-][A-Za-z0-9._-]*$",claim) or claim in (".","..") or
      generation<1 or attempt<1): fail("runner kit identity")
    return {"claim":claim,"generation":generation,"attempt":attempt}
def actor_scope():
    try:
        pid=int(os.environ.get("POLYLANE_ACTOR_PID","0"))
        generation=int(os.environ.get("POLYLANE_ACTOR_GENERATION","-1"))
    except ValueError: fail("actor kit identity")
    value={"pid":pid,"start_token":os.environ.get("POLYLANE_ACTOR_START_TOKEN",""),
      "generation":generation,"lane":os.environ.get("POLYLANE_ACTOR_LANE",""),
      "run_id":os.environ.get("POLYLANE_ACTOR_RUN_ID","")}
    if (pid<=1 or store.token(pid)!=value["start_token"] or generation<1 or
      not re.match(r"^[A-Za-z0-9._-]+$",value["lane"]) or
      not re.match(r"^[A-Za-z0-9._-]+$",value["run_id"])): fail("actor kit identity")
    return value
def wordset(value):
    if isinstance(value,list): value=" ".join(str(x) for x in value)
    return {x for x in re.findall(r"[a-z0-9]+",str(value).lower()) if len(x)>=3}
def read_body(entry):
    store.validate_tree(entry)
    return store.read_regular(Path(entry["snapshot_root"])/entry["skill_md_rel"],store.MAX_BODY)
def as_assignment(entry,slot,index,resolution="installed"):
    result={key:entry[key] for key in ASSIGNMENT_KEYS}
    result.update(slot=slot,index=index,resolution=resolution)
    if resolution=="equivalent":
        result["contract_sha256"]=entry["contract_sha256"]
        result["missing_capability"]=entry["missing_capability"]
    return result
def synthetic(skill_id,snapshot_root):
    raw=EQUIVALENTS[skill_id]; meta,_=store.frontmatter(raw)
    rows=[("SKILL.md",0o444,raw)]
    root,manifest,tree_hash=store.publish_tree(snapshot_root,skill_id,rows,raw,len(raw))
    return {"id":skill_id,"origin":"synthetic","snapshot_root":str(root),
      "skill_md_rel":"SKILL.md","path":str(root/"SKILL.md"),
      "tree_manifest":str(root/".polylane-skill-tree.json"),
      "body_sha256":manifest["body_sha256"],"tree_sha256":tree_hash,
      "file_count":1,"total_bytes":len(raw),
      "capability":"implementation" if "test-driven" in skill_id else "verification",
      "frontmatter":meta,"contract_sha256":sha(raw),"missing_capability":skill_id}
def lane_ownership(lane):
    if "ownership_globs" in lane and "own_globs" in lane: fail("ambiguous ownership fields")
    value=lane.get("ownership_globs",lane.get("own_globs"))
    if not isinstance(value,list) or not value or not all(isinstance(x,str) and x for x in value):
        fail("ownership globs")
    return value
def validate_lane(lane):
    if not isinstance(lane,dict): fail("lane object")
    if not isinstance(lane.get("name"),str) or not re.match(r"^[A-Za-z0-9_-]+$",lane["name"]): fail("lane name")
    if lane.get("role") not in ("builder","integrator"): fail("lane role")
    if not isinstance(lane.get("activities"),list) or not all(isinstance(x,str) and x for x in lane["activities"]): fail("lane activities")
    lane_ownership(lane)
    argv=lane.get("verification_argv")
    if (not isinstance(argv,list) or not argv or
        not all(isinstance(x,str) and x for x in argv) or not os.path.isabs(argv[0])):
        fail("verification argv")
def lane_domain(lane):
    facts=wordset(lane.get("activities",[]))|wordset(lane_ownership(lane))
    scored=[(len(facts&WORDS[x]),-DOMAINS.index(x),x) for x in DOMAINS]
    best=max(scored)
    return best[2] if best[0] else "unknown"
def positive_relevance(entry,activity):
    metadata=wordset(entry["id"])|wordset(entry["frontmatter"]["name"])|wordset(entry["frontmatter"]["description"])
    text=wordset(read_body(entry).decode("utf-8","strict"))
    left=activity&metadata; right=activity&text
    if not left or not right: return None
    return (len(left)+len(right),len(left&right),entry["id"])
def choose_specific(lane,inventory):
    domain=lane_domain(lane); byid={x["id"]:x for x in inventory["skills"]}
    fallback_ids=(f"{domain}-implementation",f"{domain}-verification")
    fallback=[byid.get(x) for x in fallback_ids]
    if any(x is None or x.get("origin")!="bundled" for x in fallback):
        fail(f"missing trusted bundled fallback pair for {domain}")
    if domain=="unknown": return fallback,2
    activity=wordset(lane.get("activities",[])); ranked=[]
    for entry in inventory["skills"]:
        if entry["origin"]!="external" or entry["id"] in PREDEFINED: continue
        score=positive_relevance(entry,activity)
        if score: ranked.append((score,entry))
    ranked.sort(key=lambda x:(-x[0][0],-x[0][1],x[0][2]))
    selected=[]; capabilities=set()
    for _,entry in ranked:
        if entry["capability"] in capabilities: continue
        selected.append(entry); capabilities.add(entry["capability"])
        if len(selected)==2: break
    for entry in fallback:
        if len(selected)==2: break
        if entry["capability"] not in capabilities:
            selected.append(entry); capabilities.add(entry["capability"])
    if len(selected)!=2 or len(capabilities)!=2: fail("two distinct capabilities unavailable")
    return selected,sum(x["id"] in fallback_ids for x in selected)
def validate_kit(path):
    kit=load(path,True)
    if set(kit)!={"schema_version","loop_id","cycle","run_id","lane","domain",
      "activity_tokens","fallback_count","assignments","runner","actor","kit_sha256"}: fail("kit keys")
    if kit["schema_version"]!=1 or kit_hash(kit)!=kit["kit_sha256"]: fail("kit hash")
    if (not isinstance(kit["runner"],dict) or set(kit["runner"])!={"claim","generation","attempt"} or
      not re.match(r"^[A-Za-z0-9_-][A-Za-z0-9._-]*$",str(kit["runner"].get("claim",""))) or
      kit["runner"]["claim"] in (".","..") or
      not isinstance(kit["runner"].get("generation"),int) or kit["runner"]["generation"]<1 or
      not isinstance(kit["runner"].get("attempt"),int) or kit["runner"]["attempt"]<1):
        fail("kit runner")
    if kit["actor"] is not None:
        actor=kit["actor"]
        if (not isinstance(actor,dict) or set(actor)!={"pid","start_token","generation","lane","run_id"} or
          not isinstance(actor["pid"],int) or actor["pid"]<=1 or
          not isinstance(actor["generation"],int) or actor["generation"]<1 or
          actor["lane"]!=kit["lane"] or actor["run_id"]!=kit["run_id"] or
          not isinstance(actor["start_token"],str) or not actor["start_token"]): fail("kit actor")
    rows=kit["assignments"]
    if len(rows)!=4 or [x["slot"] for x in rows].count("predefined")!=2 or [x["slot"] for x in rows].count("specific")!=2: fail("kit cardinality")
    if {x["id"] for x in rows if x["slot"]=="predefined"}!=set(PREDEFINED): fail("predefined ids")
    if len({x["capability"] for x in rows if x["slot"]=="specific"})!=2: fail("specific capabilities")
    if sum(x["total_bytes"] for x in rows)>MAX_FOUR: fail("four-tree byte cap")
    fallback=sum(x["slot"]=="specific" and x["origin"]=="bundled" for x in rows)
    if fallback!=kit["fallback_count"]: fail("fallback count")
    for row in rows:
        expected=set(ASSIGNMENT_KEYS)|{"slot","index","resolution"}
        if row.get("resolution")=="equivalent": expected|={"contract_sha256","missing_capability"}
        if set(row)!=expected: fail("assignment keys")
        store.validate_tree(row)
        if row["resolution"]=="equivalent":
            raw=EQUIVALENTS.get(row["id"])
            if raw is None or row["contract_sha256"]!=sha(raw) or read_body(row)!=raw:
                fail("synthetic equivalent contract")
    return kit
def write_index(manifest_path,inventory_path,kit_dir):
    manifest_raw=store.read_regular(manifest_path,store.MAX_INV)
    inventory_raw=store.read_regular(inventory_path,store.MAX_INV)
    rows=[]; gaps=[]
    for path in sorted(Path(kit_dir).glob("*.json")):
        if path.name=="index.json": continue
        kit=validate_kit(path)
        rows.append({"lane":kit["lane"],"kit_path":str(path.absolute()),
          "kit_sha256":kit["kit_sha256"],
          "tree_sha256":[x["tree_sha256"] for x in kit["assignments"]]})
        for assignment in kit["assignments"]:
            if assignment["slot"]=="specific" and assignment["origin"]=="bundled":
                gaps.append({"gap_id":f"{kit['lane']}:{assignment['capability']}",
                  "lane":kit["lane"],"domain":kit["domain"],
                  "activities":kit["activity_tokens"],
                  "missing_capability":assignment["capability"]})
    index={"schema_version":1,"manifest_sha256":sha(manifest_raw),
      "inventory_sha256":sha(inventory_raw),"kits":rows,"gaps":sorted(gaps,key=lambda x:x["gap_id"])}
    publish(Path(kit_dir)/"index.json",index)
def select(args):
    manifest=load(args.manifest,False); inventory=load(args.inventory,True)
    store.validate_inventory(args.inventory)
    package_bundled=Path(args.package_root).absolute()/"bundled-skills"
    fd=store.nofollow_dir(package_bundled); os.close(fd)
    if manifest.get("agent")!="codex": fail("kits require Codex")
    lanes=manifest.get("lanes")
    if not isinstance(lanes,list): fail("lane schema")
    for lane in lanes: validate_lane(lane)
    if len({x["name"] for x in lanes})!=len(lanes): fail("lane schema")
    store.ensure_dir(args.kit_dir,0o700); byid={x["id"]:x for x in inventory["skills"]}
    for lane in lanes:
        if lane.get("role")!="builder": continue
        predefined=[]
        for skill_id in PREDEFINED:
            entry=byid.get(skill_id) or synthetic(skill_id,args.snapshot_root)
            predefined.append(entry)
        specific,fallback_count=choose_specific(lane,inventory)
        assignments=[]
        for i,entry in enumerate(predefined):
            resolution="equivalent" if entry["origin"]=="synthetic" else "installed"
            assignments.append(as_assignment(entry,"predefined",i,resolution))
        for i,entry in enumerate(specific):
            assignments.append(as_assignment(entry,"specific",i))
        kit={"schema_version":1,"loop_id":manifest["loop_id"],"cycle":manifest["cycle"],
          "run_id":manifest["run_id"],"lane":lane["name"],"domain":lane_domain(lane),
          "activity_tokens":sorted(wordset(lane.get("activities",[]))),
          "fallback_count":fallback_count,"assignments":assignments,
          "runner":runner_scope(),"actor":None}
        kit["kit_sha256"]=kit_hash(kit); publish(Path(args.kit_dir)/f"{lane['name']}.json",kit)
    write_index(args.manifest,args.inventory,args.kit_dir)
def local_tree(entry,worktree):
    store.validate_tree(entry)
    manifest=load_manifest(entry["tree_manifest"]); source=Path(entry["snapshot_root"]); rows=[]
    for row in manifest["files"]:
        data=store.read_regular(source/row["path"],store.MAX_FILE)
        mode=int(row["mode"],8); rows.append((row["path"],mode,data))
    base=Path(worktree).absolute()/".polylane"/"skill-snapshots"
    store.ensure_dir(base,0o700)
    body=next(x[2] for x in rows if x[0]=="SKILL.md")
    root,copied,copied_hash=store.publish_tree(base,entry["id"],rows,body,manifest["total_bytes"])
    if copied_hash!=entry["tree_sha256"] or copied!=manifest: fail("lane-local copy identity")
    result=dict(entry); result.update(snapshot_root=str(root),path=str(root/"SKILL.md"),
      tree_manifest=str(root/".polylane-skill-tree.json"))
    store.validate_tree(result); return result
def materialize(args):
    source=validate_kit(args.source_kit); fd=store.nofollow_dir(args.worktree); os.close(fd)
    rows=[local_tree(x,args.worktree) for x in source["assignments"]]
    kit=dict(source); kit["assignments"]=rows; kit.pop("kit_sha256")
    kit["kit_sha256"]=kit_hash(kit); publish(args.output_kit,kit); validate_kit(args.output_kit)
def frame_meta(row):
    keys=("slot","index","id","origin","resolution","capability","snapshot_root","skill_md_rel",
      "tree_manifest","body_sha256","tree_sha256","file_count","total_bytes","frontmatter")
    return {x:row[x] for x in keys}
def prompt_bytes(original,kit_path):
    kit=validate_kit(kit_path)
    summary=canon({"schema_version":1,"lane":kit["lane"],"kit_sha256":kit["kit_sha256"],
      "runner":kit["runner"],"actor":kit["actor"],
      "tree_sha256":[x["tree_sha256"] for x in kit["assignments"]]})
    out=b"POLYLANE-PROMPT-V1\n"+f"ORIGINAL-BYTES {len(original)}\n".encode()+original
    out+=f"\nKIT-METADATA-BYTES {len(summary)}\n".encode()+summary+b"FRAME-COUNT 4\n"
    for row in kit["assignments"]:
        meta=canon(frame_meta(row)); raw=read_body(row)
        out+=f"FRAME-METADATA-BYTES {len(meta)}\n".encode()+meta
        out+=f"BODY-BYTES {len(raw)}\n".encode()+raw
        out+=f"\nFRAME-SHA256 {sha(meta+raw)}\n".encode()
    return out+b"POLYLANE-PROMPT-END\n"
def parse_prompt(raw):
    cursor=0
    def line():
        nonlocal cursor
        end=raw.find(b"\n",cursor)
        if end<0: fail("unterminated prompt header")
        value=raw[cursor:end]; cursor=end+1; return value
    def sized(prefix):
        nonlocal cursor
        header=line()
        if not header.startswith(prefix+b" "): fail("prompt header order")
        count_text=header[len(prefix)+1:]
        if not count_text.isdigit() or len(count_text)>9: fail("prompt length")
        count=int(count_text)
        if cursor+count>len(raw): fail("truncated prompt frame")
        value=raw[cursor:cursor+count]; cursor+=count; return value
    if line()!=b"POLYLANE-PROMPT-V1": fail("prompt version")
    original=sized(b"ORIGINAL-BYTES")
    if line()!=b"": fail("prompt separator")
    summary=sized(b"KIT-METADATA-BYTES")
    if line()!=b"FRAME-COUNT 4": fail("prompt frame count")
    frames=[]
    for _ in range(4):
        meta=sized(b"FRAME-METADATA-BYTES"); body_bytes=sized(b"BODY-BYTES")
        if line()!=b"": fail("frame separator")
        digest=line()
        if digest!=f"FRAME-SHA256 {sha(meta+body_bytes)}".encode(): fail("frame digest")
        frames.append((meta,body_bytes))
    if line()!=b"POLYLANE-PROMPT-END" or cursor!=len(raw): fail("prompt trailing bytes")
    return original,summary,frames
def build_prompt(args):
    original=store.read_regular(args.original,store.MAX_INV)
    publish_bytes(args.output,prompt_bytes(original,args.kit))
def lint_prompt(args):
    original=store.read_regular(args.original,store.MAX_INV)
    actual=store.read_regular(args.prompt,store.MAX_INV)
    parsed_original,_,_=parse_prompt(actual)
    if parsed_original!=original: fail("prompt original bytes")
    if actual!=prompt_bytes(original,args.kit): fail("prompt exact-byte mismatch")
def bind_actor(args):
    source=validate_kit(args.source_kit)
    if source["actor"] is not None or source["runner"]!=runner_scope(): fail("actor bind template")
    base=store.read_regular(args.source_prompt,store.MAX_INV)
    original,_,_=parse_prompt(base)
    if base!=prompt_bytes(original,args.source_kit): fail("actor bind base prompt")
    actor=actor_scope()
    if actor["lane"]!=source["lane"] or actor["run_id"]!=source["run_id"]: fail("actor bind scope")
    bound=dict(source); bound["actor"]=actor; bound.pop("kit_sha256")
    bound["kit_sha256"]=kit_hash(bound); publish(args.output_kit,bound)
    publish_bytes(args.output_prompt,prompt_bytes(original,args.output_kit))
    print(bound["kit_sha256"])
def actor_record(args):
    raw=store.read_regular(args.worker_result,store.MAX_INV); result=json.loads(raw)
    actor=result.get("actor",{})
    expected={"pid":actor.get("pid"),"start_token":actor.get("start_token"),
      "generation":args.generation,"lane":args.lane,"run_id":args.run_id}
    if (actor!=expected or result.get("actor_generation")!=args.generation or
      result.get("runner")!=runner_scope()): fail("worker actor registration")
    publish(args.output,expected)
def failure_feedback(args):
    publish(args.output,{"schema_version":1,"lane":args.lane,
      "generation":args.generation,"reason":args.reason},True)
def run_verification(argv,cwd,artifact_dir,stem):
    root=Path(artifact_dir).absolute(); store.ensure_dir(root,0o700)
    private={name:root/f".{stem}.{name}.{os.getpid()}.capture" for name in ("stdout","stderr")}
    fds={}; process=None; selector=selectors.DefaultSelector(); counts={"stdout":0,"stderr":0}
    started=int(time.time()); reason=None; deadline=time.monotonic()+VERIFY_TIMEOUT
    try:
        for name,path in private.items():
            pfd=store.nofollow_dir(path.parent)
            try:
                fds[name]=os.open(path.name,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,
                  0o600,dir_fd=pfd)
            finally: os.close(pfd)
        process=subprocess.Popen(argv,cwd=cwd,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,
          stderr=subprocess.PIPE,close_fds=True)
        selector.register(process.stdout,selectors.EVENT_READ,"stdout")
        selector.register(process.stderr,selectors.EVENT_READ,"stderr")
        while selector.get_map():
            remaining=deadline-time.monotonic()
            if remaining<=0:
                reason="timeout"; process.kill(); break
            for key,_ in selector.select(min(remaining,.2)):
                chunk=os.read(key.fileobj.fileno(),65536)
                if not chunk:
                    selector.unregister(key.fileobj); continue
                name=key.data; proposed=counts[name]+len(chunk)
                combined=counts["stdout"]+counts["stderr"]+len(chunk)
                if proposed>VERIFY_STREAM_MAX or combined>VERIFY_COMBINED_MAX:
                    reason="output_limit"; process.kill(); break
                view=memoryview(chunk)
                while view: view=view[os.write(fds[name],view):]
                counts[name]=proposed
            if reason is not None: break
        if reason is not None:
            for stream in (process.stdout,process.stderr):
                try: selector.unregister(stream)
                except (KeyError,ValueError): pass
                stream.close()
        returncode=process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        reason=reason or "timeout"; process.kill(); returncode=process.wait()
    except OSError:
        if process is not None and process.poll() is None: process.kill(); process.wait()
        raise
    finally:
        selector.close()
        for fd in fds.values(): os.fchmod(fd,0o400); os.fsync(fd); os.close(fd)
    raw={name:store.read_regular(path,VERIFY_STREAM_MAX) for name,path in private.items()}
    for path in private.values(): os.unlink(path)
    if reason=="timeout": returncode=124
    elif reason=="output_limit": returncode=125
    outputs={name:root/f"{stem}.{name}" for name in ("stdout","stderr")}
    for name,path in outputs.items(): publish_bytes(path,raw[name])
    return {"schema_version":2,"argv":argv,"exit_code":returncode,
      "passed":reason is None and returncode==0,"failure_reason":reason,
      "started_at":started,"finished_at":int(time.time()),
      "limits":{"per_stream_bytes":VERIFY_STREAM_MAX,
        "combined_bytes":VERIFY_COMBINED_MAX,"timeout_seconds":VERIFY_TIMEOUT},
      "stdout_path":str(outputs["stdout"]),"stdout_bytes":counts["stdout"],
      "stdout_sha256":sha(raw["stdout"]),"stderr_path":str(outputs["stderr"]),
      "stderr_bytes":counts["stderr"],"stderr_sha256":sha(raw["stderr"])}
def reject(args):
    kit=validate_kit(args.kit); output=Path(args.output).absolute(); root=output.parent
    store.ensure_dir(root,0o700)
    result_raw=store.read_regular(args.worker_result,store.MAX_INV); result=json.loads(result_raw)
    sources={"worker-result":args.worker_result,"launched-prompt":args.prompt,
      "prompt-capture":args.worker_result+".prompt","events":result.get("events_path","-"),
      "stderr":result.get("stderr_path","-"),"done":args.done,"verify":args.verify,
      "actor":args.actor,"verification":args.verification,"attestation":args.attestation}
    evidence={}
    for label,path in sources.items():
        if path=="-" or not os.path.lexists(path):
            evidence[label]=None; continue
        raw=store.read_regular(path,store.MAX_INV)
        target=root/f"{label}.evidence"
        if os.path.lexists(target):
            if store.read_regular(target,store.MAX_INV)!=raw: fail("rejection evidence conflict")
        else: store.atomic_write(target,raw,0o444)
        evidence[label]={"path":str(target),"sha256":sha(raw),"bytes":len(raw)}
    runner_pid=int(os.environ.get("POLYLANE_RUNNER_PID","0"))
    runner_start=os.environ.get("POLYLANE_RUNNER_START_TOKEN","")
    runner_generation=int(os.environ.get("POLYLANE_RUNNER_GENERATION","-1"))
    runner_attempt=int(os.environ.get("POLYLANE_ATTEMPT","-1"))
    if (runner_pid<=1 or store.token(runner_pid)!=runner_start or
        runner_generation<1 or runner_attempt<1):
        fail("rejection runner owner")
    receipt={"schema_version":1,"lane":args.lane,"run_id":args.run_id,
      "generation":args.generation,"reason":args.reason,
      "runner":{"pid":runner_pid,"start_token":runner_start,"generation":runner_generation,
        "attempt":runner_attempt},
      "kit_sha256":kit["kit_sha256"],"evidence":evidence}
    expected=canon(receipt)
    with store.Lock(output,30):
        if os.path.lexists(output):
            if store.read_regular(output,store.MAX_INV)!=expected: fail("rejection receipt conflict")
        else: store.atomic_write(output,expected,0o444)
def qualify(args):
    manifest=load(args.manifest,False); kit=validate_kit(args.kit)
    prompt=store.read_regular(args.prompt,store.MAX_INV); prompt_hash=sha(prompt)
    result_raw=store.read_regular(args.worker_result,store.MAX_INV); result=json.loads(result_raw)
    actor=load(args.actor,True)
    result_keys={"schema_version","provider","kind","code","status","error_type",
      "terminal_type","process_exit","events_path","events_hash","stderr_path","stderr_hash",
      "prompt_sha256","kit_sha256","actor_generation","actor","runner"}
    if (set(result)!=result_keys or result.get("schema_version")!=2 or
      result.get("provider")!="codex" or result.get("terminal_type")!="turn.completed" or
      result.get("process_exit")!=0): fail("worker result schema/success")
    expected_runner=runner_scope()
    if kit["actor"] is None or actor!=kit["actor"] or result["actor"]!=actor: fail("worker actor mismatch")
    if kit["runner"]!=expected_runner or result["runner"]!=expected_runner: fail("worker runner mismatch")
    if actor["lane"]!=kit["lane"] or actor["run_id"]!=kit["run_id"]: fail("actor scope")
    if (result["prompt_sha256"]!=prompt_hash or result["kit_sha256"]!=kit["kit_sha256"] or
      result["actor_generation"]!=actor["generation"]): fail("worker binding")
    original,_,_=parse_prompt(prompt)
    if prompt!=prompt_bytes(original,args.kit): fail("qualified prompt/kit mismatch")
    events=store.read_regular(result["events_path"],store.MAX_INV)
    if sha(events)!=result["events_hash"]: fail("events hash")
    stderr=store.read_regular(result["stderr_path"],store.MAX_INV)
    if sha(stderr)!=result["stderr_hash"]: fail("stderr hash")
    done=store.read_regular(args.done,4096)
    if done!=f"STATUS: {kit['lane']} DONE run={kit['run_id']}\n".encode(): fail("DONE nonce")
    verify=store.read_regular(args.verify,4096)
    expected_verify=canon({"lane":kit["lane"],"run_id":kit["run_id"],"schema_version":1})
    if verify!=expected_verify: fail("verify nonce")
    lane=next((x for x in manifest["lanes"] if x.get("name")==kit["lane"] and x.get("role")=="builder"),None)
    if lane is None: fail("manifest lane")
    argv=lane.get("verification_argv")
    if (not isinstance(argv,list) or not argv or
        not all(isinstance(x,str) and x for x in argv) or not os.path.isabs(argv[0])):
        fail("verification argv")
    stem=f"{kit['run_id']}-{kit['lane']}-g{actor['generation']}"
    verification=run_verification(argv,args.repo,args.artifact_dir,stem)
    artifact=Path(args.artifact_dir)/f"{stem}.json"; publish(artifact,verification)
    if not verification["passed"]: fail("fresh verification failed")
    runner_pid=int(os.environ.get("POLYLANE_RUNNER_PID","0"))
    runner_start=os.environ.get("POLYLANE_RUNNER_START_TOKEN","")
    runner_claim=expected_runner["claim"]
    runner_generation=expected_runner["generation"]
    runner_attempt=expected_runner["attempt"]
    if (runner_pid<=1 or store.token(runner_pid)!=runner_start or
      not re.match(r"^[A-Za-z0-9._-]+$",runner_claim) or runner_generation<1 or
      runner_attempt<1): fail("runner owner")
    att={"schema_version":1,"loop_id":kit["loop_id"],"cycle":kit["cycle"],
      "run_id":kit["run_id"],"lane":kit["lane"],
      "attester":{"pid":runner_pid,"start_token":runner_start,"claim":runner_claim,
        "generation":runner_generation,"attempt":runner_attempt},
      "actor":actor,"worker_result_path":str(Path(args.worker_result).absolute()),
      "worker_result_sha256":sha(result_raw),"events_path":result["events_path"],
      "events_sha256":sha(events),"stderr_path":result["stderr_path"],
      "stderr_sha256":sha(stderr),"prompt_path":str(Path(args.prompt).absolute()),
      "prompt_sha256":prompt_hash,"kit_path":str(Path(args.kit).absolute()),
      "kit_file_sha256":sha(store.read_regular(args.kit,store.MAX_INV)),
      "kit_sha256":kit["kit_sha256"],
      "tree_sha256":[x["tree_sha256"] for x in kit["assignments"]],
      "done_path":str(Path(args.done).absolute()),"done_sha256":sha(done),
      "verify_path":str(Path(args.verify).absolute()),"verify_sha256":sha(verify),
      "verification":dict(verification,artifact=str(artifact)),"attested_at":int(time.time())}
    publish(args.output,att)
def score(args):
    att=load(args.attestation,True); kit=validate_kit(args.kit)
    att_keys={"schema_version","loop_id","cycle","run_id","lane","attester","actor",
      "worker_result_path","worker_result_sha256","events_path","events_sha256",
      "stderr_path","stderr_sha256","prompt_path","prompt_sha256","kit_path",
      "kit_file_sha256","kit_sha256","tree_sha256","done_path","done_sha256",
      "verify_path","verify_sha256","verification","attested_at"}
    if set(att)!=att_keys or att["schema_version"]!=1: fail("attestation schema")
    if (att["loop_id"]!=kit["loop_id"] or att["cycle"]!=kit["cycle"] or
      att["run_id"]!=kit["run_id"] or att["lane"]!=kit["lane"] or
      att["kit_sha256"]!=kit["kit_sha256"] or att["actor"]!=kit["actor"]):
        fail("attestation kit/scope")
    if att.get("tree_sha256")!=[x["tree_sha256"] for x in kit["assignments"]]: fail("attestation trees")
    owner=att.get("attester",{}); expected={"pid":int(os.environ.get("POLYLANE_RUNNER_PID","0")),
      "start_token":os.environ.get("POLYLANE_RUNNER_START_TOKEN",""),
      "claim":os.environ.get("POLYLANE_CLAIM_TOKEN",""),
      "generation":int(os.environ.get("POLYLANE_RUNNER_GENERATION","-1")),
      "attempt":int(os.environ.get("POLYLANE_ATTEMPT","-1"))}
    if (owner!=expected or expected["pid"]<=1 or
      store.token(expected["pid"])!=expected["start_token"] or
      not re.match(r"^[A-Za-z0-9._-]+$",expected["claim"]) or
      expected["generation"]<1 or expected["attempt"]<1): fail("attestation author")
    if kit["runner"]!={"claim":expected["claim"],"generation":expected["generation"],
      "attempt":expected["attempt"]}: fail("attestation runner/kit scope")
    evidence=(("worker_result_path","worker_result_sha256"),("events_path","events_sha256"),
      ("stderr_path","stderr_sha256"),("prompt_path","prompt_sha256"),
      ("kit_path","kit_file_sha256"),("done_path","done_sha256"),("verify_path","verify_sha256"))
    for path_key,hash_key in evidence:
        if sha(store.read_regular(att[path_key],store.MAX_INV))!=att[hash_key]: fail(f"{hash_key} chain")
    if str(Path(args.kit).absolute())!=att["kit_path"]: fail("scored kit path")
    worker=json.loads(store.read_regular(att["worker_result_path"],store.MAX_INV))
    if (worker.get("actor")!=att["actor"] or worker.get("runner")!=kit["runner"] or
      worker.get("kit_sha256")!=kit["kit_sha256"] or
      worker.get("prompt_sha256")!=att["prompt_sha256"] or
      worker.get("events_hash")!=att["events_sha256"] or
      worker.get("stderr_hash")!=att["stderr_sha256"]): fail("worker chain")
    verification=att["verification"]
    if not isinstance(verification,dict) or "artifact" not in verification: fail("verification schema")
    artifact=load(verification["artifact"],True); expected_artifact=dict(verification)
    expected_artifact.pop("artifact")
    if artifact!=expected_artifact or not artifact.get("passed") or artifact.get("exit_code")!=0:
        fail("verification artifact equality")
    for stream in ("stdout","stderr"):
        raw=store.read_regular(artifact[f"{stream}_path"],VERIFY_STREAM_MAX)
        if (len(raw)!=artifact[f"{stream}_bytes"] or sha(raw)!=artifact[f"{stream}_sha256"]):
            fail(f"{stream} artifact")
    attestation_raw=store.read_regular(args.attestation,store.MAX_INV)
    attestation_hash=sha(attestation_raw)
    actor_hash=sha(canon(att["actor"]))
    dedupe_key=(f"{owner['claim']}:g{owner['generation']}:a{owner['attempt']}:"
      f"{actor_hash}:{attestation_hash}")
    record={"dedupe_key":dedupe_key,"schema_version":1,
      "run_id":att["run_id"],"lane":att["lane"],"kit_sha256":kit["kit_sha256"],
      "runner":{"claim":owner["claim"],"generation":owner["generation"],
        "attempt":owner["attempt"]},"actor":att["actor"],"actor_sha256":actor_hash,
      "attestation_sha256":attestation_hash,
      "fallback_count":kit["fallback_count"],"tree_sha256":att["tree_sha256"]}
    temporary=Path(args.ledger).with_name(f".score.{os.getpid()}.json")
    store.atomic_write(temporary,canon(record),0o400)
    try: store.append_jsonl(args.ledger,temporary,"dedupe_key")
    finally:
        try: os.unlink(temporary)
        except FileNotFoundError: pass
def fixture(args):
    root=Path(args.directory); store.ensure_dir(root,0o755); store.ensure_dir(root/"snap",0o755); assignments=[]
    ids=PREDEFINED+("unknown-implementation","unknown-verification")
    for i,skill_id in enumerate(ids):
        raw=EQUIVALENTS.get(skill_id) or f"---\nname: {skill_id}\ndescription: fixture {skill_id}\n---\n\nFRAME-COUNT marker\n".encode()
        meta,_=store.frontmatter(raw)
        resource=b"relative fixture resource\n"; script=b"#!/usr/bin/env bash\nprintf probe\n"
        files=[("SKILL.md",0o444,raw),("references/checks.md",0o444,resource),("scripts/probe.sh",0o555,script)]
        total=sum(len(x[2]) for x in files)
        tree,manifest,tree_hash=store.publish_tree(root/"snap",skill_id,files,raw,total)
        entry={"id":skill_id,"origin":"synthetic" if i<2 else "bundled",
          "snapshot_root":str(tree),"skill_md_rel":"SKILL.md","path":str(tree/"SKILL.md"),
          "tree_manifest":str(tree/".polylane-skill-tree.json"),"body_sha256":manifest["body_sha256"],
          "tree_sha256":tree_hash,"file_count":3,"total_bytes":total,
          "capability":"implementation" if i%2==0 else "verification","frontmatter":meta}
        if i<2: entry.update(contract_sha256=sha(raw),missing_capability=skill_id)
        assignments.append(as_assignment(entry,"predefined" if i<2 else "specific",i%2,
          "equivalent" if i<2 else "installed"))
    kit={"schema_version":1,"loop_id":"fixture","cycle":1,"run_id":"fixture-1",
      "lane":"fixture","domain":"unknown","activity_tokens":[],"fallback_count":2,
      "assignments":assignments,"runner":runner_scope(),"actor":None}
    kit["kit_sha256"]=kit_hash(kit); publish(root/"kit.json",kit)
def main():
    parser=argparse.ArgumentParser(); sub=parser.add_subparsers(dest="command",required=True)
    q=sub.add_parser("select")
    for name in ("manifest","inventory","snapshot_root","package_root","kit_dir"): q.add_argument(name)
    q=sub.add_parser("index")
    for name in ("manifest","inventory","kit_dir"): q.add_argument(name)
    q=sub.add_parser("materialize")
    for name in ("source_kit","worktree","output_kit"): q.add_argument(name)
    q=sub.add_parser("build-prompt")
    for name in ("original","kit","output"): q.add_argument(name)
    q=sub.add_parser("lint-prompt")
    for name in ("original","kit","prompt"): q.add_argument(name)
    q=sub.add_parser("bind-actor")
    for name in ("source_kit","source_prompt","output_kit","output_prompt"): q.add_argument(name)
    q=sub.add_parser("validate-kit"); q.add_argument("kit")
    q=sub.add_parser("actor-record")
    q.add_argument("worker_result"); q.add_argument("lane"); q.add_argument("run_id")
    q.add_argument("generation",type=int); q.add_argument("output")
    q=sub.add_parser("failure-feedback")
    q.add_argument("lane"); q.add_argument("generation",type=int); q.add_argument("reason"); q.add_argument("output")
    q=sub.add_parser("reject")
    for name in ("worker_result","prompt","kit","done","verify","actor","verification","attestation",
      "lane","run_id"): q.add_argument(name)
    q.add_argument("generation",type=int); q.add_argument("reason"); q.add_argument("output")
    q=sub.add_parser("qualify")
    for name in ("manifest","kit","prompt","worker_result","actor","done","verify","repo","artifact_dir","output"): q.add_argument(name)
    q=sub.add_parser("score")
    for name in ("attestation","kit","ledger"): q.add_argument(name)
    q=sub.add_parser("fixture"); q.add_argument("directory")
    args=parser.parse_args()
    actions={"select":select,"index":lambda x:write_index(x.manifest,x.inventory,x.kit_dir),
      "materialize":materialize,"build-prompt":build_prompt,"lint-prompt":lint_prompt,
      "bind-actor":bind_actor,
      "validate-kit":lambda x:validate_kit(x.kit),"actor-record":actor_record,
      "failure-feedback":failure_feedback,"reject":reject,"qualify":qualify,
      "score":score,"fixture":fixture}
    try: actions[args.command](args)
    except (store.Fail,OSError,ValueError,TypeError,KeyError,json.JSONDecodeError,UnicodeError) as exc:
        store.die(str(exc))
if __name__=="__main__": main()
```

Create `core/scripts/polylane-skill-kit.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
exec python3 "$SCRIPT_DIR/polylane-skill-kit.py" "$@"
```

Create `core/scripts/polylane-skill-ledger.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
[ "$#" -eq 4 ] && [ "$1" = score ] || {
  echo "usage: polylane-skill-ledger.sh score ATTESTATION KIT LEDGER" >&2
  exit 2
}
exec "$SCRIPT_DIR/polylane-skill-kit.sh" score "$2" "$3" "$4"
```

- [ ] **Step 3: Add the runner-attestation and raw-prose rejection test**

Create `core/tests/test-skill-attestation.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
TEST_TMPDIR=$(cd "$TEST_TMPDIR" && pwd -P)
KIT="$ROOT/core/scripts/polylane-skill-kit.sh"; F="$TEST_TMPDIR/attest"
mkdir -p "$F/repo" "$F/worktree" "$F/artifacts"
start=$(python3 - "$ROOT/core/scripts/polylane-skill-store.py" $$ <<'PY'
import importlib.util,sys
spec=importlib.util.spec_from_file_location("store",sys.argv[1])
store=importlib.util.module_from_spec(spec); spec.loader.exec_module(store)
print(store.token(int(sys.argv[2])))
PY
)
export POLYLANE_RUNNER_PID=$$ POLYLANE_RUNNER_START_TOKEN="$start"
export POLYLANE_CLAIM_TOKEN=attest-claim POLYLANE_RUNNER_GENERATION=1 POLYLANE_ATTEMPT=1
"$KIT" fixture "$F"
"$KIT" materialize "$F/kit.json" "$F/worktree" "$F/local-kit.json"
printf original >"$F/original"
"$KIT" build-prompt "$F/original" "$F/local-kit.json" "$F/prompt"
"$KIT" lint-prompt "$F/original" "$F/local-kit.json" "$F/prompt"
POLYLANE_ACTOR_PID=$$ POLYLANE_ACTOR_START_TOKEN="$start" POLYLANE_ACTOR_GENERATION=2 \
  POLYLANE_ACTOR_LANE=fixture POLYLANE_ACTOR_RUN_ID=fixture-1 \
  "$KIT" bind-actor "$F/local-kit.json" "$F/prompt" "$F/bound-kit.json" \
  "$F/bound-prompt" >"$F/bound-kit.sha"
"$KIT" lint-prompt "$F/original" "$F/bound-kit.json" "$F/bound-prompt"
printf pass >"$F/repo/output"
cat >"$F/manifest.raw.json" <<'JSON'
{"agent":"codex","cycle":1,"loop_id":"fixture","run_id":"fixture-1","lanes":[
 {"name":"fixture","role":"builder","activities":[],"ownership_globs":["**"],
  "verification_argv":["/usr/bin/test","-f","output"]}]}
JSON
jq -cS . "$F/manifest.raw.json" >"$F/manifest.json"
printf 'STATUS: fixture DONE run=fixture-1\n' >"$F/done"
printf '%s\n' '{"lane":"fixture","run_id":"fixture-1","schema_version":1}' >"$F/verify"
sha_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1"
  else sha256sum "$1"; fi | awk '{print "sha256:"$1}'
}
prompt_hash=$(sha_file "$F/bound-prompt")
kit_hash=$(jq -r .kit_sha256 "$F/bound-kit.json")
cat >"$F/events" <<'JSONL'
{"type":"thread.started","thread_id":"t-attest"}
{"type":"turn.started"}
{"type":"turn.completed"}
JSONL
events_hash=$(sha_file "$F/events")
printf 'diagnostic stderr\n' >"$F/stderr"
stderr_hash=$(sha_file "$F/stderr")
jq -cnS --argjson pid "$$" --arg token "$start" \
  '{pid:$pid,start_token:$token,generation:2,lane:"fixture",run_id:"fixture-1"}' >"$F/actor.json"
jq -cnS --arg events "$F/events" --arg events_hash "$events_hash" \
  --arg stderr "$F/stderr" --arg stderr_hash "$stderr_hash" \
  --arg prompt_hash "$prompt_hash" --arg kit_hash "$kit_hash" \
  --argjson pid "$$" --arg token "$start" \
  '{schema_version:2,provider:"codex",kind:"none",code:"",status:0,error_type:"",
    terminal_type:"turn.completed",process_exit:0,events_path:$events,events_hash:$events_hash,
    stderr_path:$stderr,stderr_hash:$stderr_hash,prompt_sha256:$prompt_hash,
    kit_sha256:$kit_hash,actor_generation:2,
    runner:{claim:"attest-claim",generation:1,attempt:1},
    actor:{pid:$pid,start_token:$token,generation:2,lane:"fixture",run_id:"fixture-1"}}' \
  >"$F/result.json"
printf 'SKILL-EVIDENCE: looks good\n' >"$F/raw-prose"
assert_rc "raw-prose-not-attestation" 5 "$KIT" score \
  "$F/raw-prose" "$F/bound-kit.json" "$F/ledger"
"$KIT" qualify "$F/manifest.json" "$F/bound-kit.json" "$F/bound-prompt" "$F/result.json" \
  "$F/actor.json" "$F/done" "$F/verify" "$F/repo" "$F/artifacts" "$F/attestation.json"
assert_ok "attestation-binds-all" jq -e \
  '.attester.claim=="attest-claim" and .attester.generation==1 and
   .attester.attempt==1 and .actor.generation==2 and (.tree_sha256|length)==4 and
   (.worker_result_sha256|test("^sha256:")) and (.events_sha256|test("^sha256:")) and
   (.done_sha256|test("^sha256:")) and (.verify_sha256|test("^sha256:")) and
   .actor.pid>1 and (.actor.start_token|length)>0 and .actor.lane=="fixture" and
   .verification.argv==["/usr/bin/test","-f","output"] and .verification.exit_code==0 and
   .verification.passed==true and .verification.failure_reason==null' \
  "$F/attestation.json"
"$KIT" score "$F/attestation.json" "$F/bound-kit.json" "$F/ledger"
"$KIT" score "$F/attestation.json" "$F/bound-kit.json" "$F/ledger"
assert_eq "ledger-idempotent" 1 \
  "$("$ROOT/core/scripts/polylane-skill-store.sh" read-ledger "$F/ledger" dedupe_key | wc -l | tr -d ' ')"
jq -cS '.unexpected=true' "$F/attestation.json" >"$F/attestation-extra-key.json"
assert_rc "attestation-exact-schema" 5 "$KIT" score \
  "$F/attestation-extra-key.json" "$F/bound-kit.json" "$F/schema-ledger"
jq -cS '.actor.pid+=1' "$F/attestation.json" >"$F/attestation-wrong-actor.json"
assert_rc "attestation-exact-actor-scope" 5 "$KIT" score \
  "$F/attestation-wrong-actor.json" "$F/bound-kit.json" "$F/actor-ledger"
stdout_path=$(jq -r .verification.stdout_path "$F/attestation.json")
chmod 0600 "$stdout_path"; printf tamper >"$stdout_path"; chmod 0444 "$stdout_path"
assert_rc "score-reloads-verification-stream" 5 "$KIT" score \
  "$F/attestation.json" "$F/bound-kit.json" "$F/stream-ledger"
chmod 0600 "$stdout_path"; : >"$stdout_path"; chmod 0444 "$stdout_path"

# A later runner attempt gets a distinct immutable attestation/score identity. Crash after
# its content-addressed segment write, then retry: attempt 1 remains readable, attempt 2 is
# published exactly once, and retrying attempt 2 cannot double count it.
export POLYLANE_ATTEMPT=2
mkdir "$F/artifacts-attempt-2" "$F/attempt-2"
"$KIT" fixture "$F/attempt-2"
"$KIT" materialize "$F/attempt-2/kit.json" "$F/worktree" "$F/local-kit-attempt-2.json"
"$KIT" build-prompt "$F/original" "$F/local-kit-attempt-2.json" "$F/prompt-attempt-2"
POLYLANE_ACTOR_PID=$$ POLYLANE_ACTOR_START_TOKEN="$start" POLYLANE_ACTOR_GENERATION=2 \
  POLYLANE_ACTOR_LANE=fixture POLYLANE_ACTOR_RUN_ID=fixture-1 \
  "$KIT" bind-actor "$F/local-kit-attempt-2.json" "$F/prompt-attempt-2" \
  "$F/bound-kit-attempt-2.json" "$F/bound-prompt-attempt-2" >/dev/null
prompt_hash_2=$(sha_file "$F/bound-prompt-attempt-2")
kit_hash_2=$(jq -r .kit_sha256 "$F/bound-kit-attempt-2.json")
jq -cS --arg prompt "$prompt_hash_2" --arg kit "$kit_hash_2" \
  '.runner.attempt=2|.prompt_sha256=$prompt|.kit_sha256=$kit' \
  "$F/result.json" >"$F/result-attempt-2.json"
"$KIT" qualify "$F/manifest.json" "$F/bound-kit-attempt-2.json" \
  "$F/bound-prompt-attempt-2" "$F/result-attempt-2.json" \
  "$F/actor.json" "$F/done" "$F/verify" "$F/repo" "$F/artifacts-attempt-2" \
  "$F/attestation-attempt-2.json"
POLYLANE_STORE_FAULT=ledger-after-segment POLYLANE_STORE_GATE="$F/score-gate" \
  "$KIT" score "$F/attestation-attempt-2.json" "$F/bound-kit-attempt-2.json" "$F/ledger" \
  >"$F/score-crash.out" 2>&1 & score_crash=$!
i=0
while [ ! -f "$F/score-gate.ready" ] && [ "$i" -lt 100 ]; do sleep 0.02; i=$((i+1)); done
assert_ok "score-reached-partial-segment" test -f "$F/score-gate.ready"
kill -9 "$score_crash" 2>/dev/null; wait "$score_crash" 2>/dev/null || true
assert_eq "partial-attempt-not-counted" 1 \
  "$("$ROOT/core/scripts/polylane-skill-store.sh" read-ledger "$F/ledger" dedupe_key | wc -l | tr -d ' ')"
"$KIT" score "$F/attestation-attempt-2.json" "$F/bound-kit-attempt-2.json" "$F/ledger"
"$KIT" score "$F/attestation-attempt-2.json" "$F/bound-kit-attempt-2.json" "$F/ledger"
"$ROOT/core/scripts/polylane-skill-store.sh" read-ledger "$F/ledger" dedupe_key \
  >"$F/score-records.jsonl"
assert_ok "score-attempt-identities-exact" jq -se \
  'length==2 and ([.[].runner.attempt]|sort)==[1,2] and
   all(.[];.runner.claim=="attest-claim" and .runner.generation==1 and
     .actor.pid>1 and (.actor.start_token|length)>0 and .actor.generation==2 and
     (.dedupe_key|test("^attest-claim:g1:a[12]:sha256:[0-9a-f]{64}:sha256:[0-9a-f]{64}$")))' \
  "$F/score-records.jsonl"

export POLYLANE_ATTEMPT=1
jq -cS '.actor.generation=3' "$F/result.json" >"$F/wrong-result.json"
assert_rc "wrong-generation" 5 "$KIT" qualify \
  "$F/manifest.json" "$F/bound-kit.json" "$F/bound-prompt" "$F/wrong-result.json" \
  "$F/actor.json" "$F/done" "$F/verify" "$F/repo" "$F/artifacts" "$F/no.json"
rm "$F/repo/output"
mkdir "$F/artifacts-failed"
assert_rc "fresh-command-failure" 5 "$KIT" qualify \
  "$F/manifest.json" "$F/bound-kit.json" "$F/bound-prompt" "$F/result.json" \
  "$F/actor.json" "$F/done" "$F/verify" "$F/repo" "$F/artifacts-failed" "$F/no.json"
assert_fail "failed-no-attestation" test -e "$F/no.json"
assert_ok "failed-verification-artifact-is-typed" jq -e \
  '.schema_version==2 and .passed==false and .exit_code!=0 and .failure_reason==null and
   .limits.per_stream_bytes==4194304 and .limits.combined_bytes==6291456' \
  "$F/artifacts-failed/fixture-1-fixture-g2.json"

cat >"$F/repo/overflow.sh" <<'SH'
#!/usr/bin/env bash
dd if=/dev/zero bs=65536 count=65 2>/dev/null
SH
chmod +x "$F/repo/overflow.sh"
jq -cS --arg command "$F/repo/overflow.sh" \
  '.lanes[0].verification_argv=[$command]' "$F/manifest.json" >"$F/overflow-manifest.json"
mkdir "$F/artifacts-overflow"
assert_rc "verification-output-overflow" 5 "$KIT" qualify \
  "$F/overflow-manifest.json" "$F/bound-kit.json" "$F/bound-prompt" "$F/result.json" \
  "$F/actor.json" "$F/done" "$F/verify" "$F/repo" "$F/artifacts-overflow" "$F/no-overflow.json"
assert_ok "overflow-artifact-bounded-and-typed" jq -e \
  '.schema_version==2 and .passed==false and .exit_code==125 and
   .failure_reason=="output_limit" and .stdout_bytes<=4194304 and
   .stderr_bytes<=4194304 and (.stdout_bytes+.stderr_bytes)<=6291456' \
  "$F/artifacts-overflow/fixture-1-fixture-g2.json"
finish
```

Run:

```bash
chmod +x core/scripts/polylane-skill-kit.py core/scripts/polylane-skill-kit.sh \
  core/scripts/polylane-skill-ledger.sh core/tests/test-skill-attestation.sh
python3 -m py_compile core/scripts/polylane-skill-kit.py
bash core/tests/test-skill-kit-selection.sh
bash core/tests/test-skill-prompt-framing.sh
bash core/tests/test-skill-attestation.sh
```

Expected GREEN: all four full trees are sandbox-readable under the lane worktree, raw prose
cannot score, and only a live runner-owner attestation with a fresh passing argv verification
becomes ledger evidence.

- [ ] **Step 4: Run Task 2 checks and commit**

```bash
python3 -m py_compile core/scripts/polylane-skill-kit.py
bash -n core/scripts/polylane-skill-kit.sh core/scripts/polylane-skill-ledger.sh \
  core/tests/test-skill-kit-selection.sh core/tests/test-skill-prompt-framing.sh \
  core/tests/test-skill-attestation.sh
shellcheck -S warning core/scripts/polylane-skill-kit.sh \
  core/scripts/polylane-skill-ledger.sh core/tests/test-skill-kit-selection.sh \
  core/tests/test-skill-prompt-framing.sh core/tests/test-skill-attestation.sh
bash core/tests/test-skill-kit-selection.sh
bash core/tests/test-skill-prompt-framing.sh
bash core/tests/test-skill-attestation.sh
git diff --check
git add core/scripts/polylane-skill-kit.py core/scripts/polylane-skill-kit.sh \
  core/scripts/polylane-skill-ledger.sh core/tests/test-skill-kit-selection.sh \
  core/tests/test-skill-prompt-framing.sh core/tests/test-skill-attestation.sh
git commit -m "feat(core): attest immutable builder skill kits"
```

Expected: all focused tests, syntax checks, ShellCheck, and whitespace checks are green.

---

### Task 3: Publish Guardian-Owned Informational GitHub Suggestions

**Files:**
- Create: `core/scripts/polylane-skill-suggest.py`
- Create: `core/scripts/polylane-skill-suggest.sh`
- Create: `core/scripts/polylane-skill-suggest-job.sh`
- Create: `core/tests/test-skill-suggestions.sh`

**Interfaces:**
- `enqueue GAPS SEARCH_TERMS INPUT` is runner-safe and network-free. INPUT is immutable and
  claim/generation/attempt scoped; its canonical body and `job_id` contain the same runner
  identity, so guardian ownership and ledger publication bind the exact retry attempt.
- `guardian-run INPUT OWNER RESULT LEDGER` requires immutable guardian fields
  `{role,pid,start_token,generation,deadline_epoch,job_id,input_sha256}`.
- Only Runtime guardian creates that owner record and invokes the installed job wrapper.
  Missing primary helper publishes one `unavailable/missing_helper` terminal per gap.

- [ ] **Step 1: Write the exact-GET, immutable-object, and terminal-state test**

Create `core/tests/test-skill-suggestions.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
TEST_TMPDIR=$(cd "$TEST_TMPDIR" && pwd -P)
export POLYLANE_CLAIM_TOKEN=suggest-claim POLYLANE_RUNNER_GENERATION=3 POLYLANE_ATTEMPT=1
SUGGEST="$ROOT/core/scripts/polylane-skill-suggest.sh"
JOB="$ROOT/core/scripts/polylane-skill-suggest-job.sh"
T="$TEST_TMPDIR/suggest"; mkdir -p "$T/bin" "$T/fixtures"
cat >"$T/gaps.raw.json" <<'JSON'
{"gaps":[
 {"gap_id":"api:verification","lane":"api","domain":"api",
  "activities":["REST API route"],"missing_capability":"verification"},
 {"gap_id":"mobile:implementation","lane":"mobile","domain":"mobile",
  "activities":["Android mobile screen"],"missing_capability":"implementation"}]}
JSON
jq -cS . "$T/gaps.raw.json" >"$T/gaps.json"
printf '%s\n' '["Codex Agent Skill"]' >"$T/terms.json"
"$SUGGEST" enqueue "$T/gaps.json" "$T/terms.json" "$T/input.json"
assert_ok "suggestion-input-binds-attempt" jq -e \
  '.runner=={"attempt":1,"claim":"suggest-claim","generation":3}' "$T/input.json"
input_hash=$(python3 - "$T/input.json" <<'PY'
import hashlib,sys
print("sha256:"+hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())
PY
)
first_input_hash=$input_hash
printf '%s\n' '["different retry vocabulary"]' >"$T/terms-retry.json"
assert_rc "same-attempt-input-conflict" 5 "$SUGGEST" enqueue \
  "$T/gaps.json" "$T/terms-retry.json" "$T/input.json"
assert_eq "same-attempt-conflict-preserves-input" "$first_input_hash" \
  "$(python3 - "$T/input.json" <<'PY'
import hashlib,sys
print("sha256:"+hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())
PY
)"
export POLYLANE_ATTEMPT=2
"$SUGGEST" enqueue "$T/gaps.json" "$T/terms.json" "$T/input-attempt-2.json"
assert_ok "later-attempt-has-distinct-job" jq -e \
  --arg first "$(jq -r .job_id "$T/input.json")" \
  '.runner.attempt==2 and .job_id!=$first' "$T/input-attempt-2.json"
assert_eq "prior-attempt-input-preserved" "$first_input_hash" \
  "$(python3 - "$T/input.json" <<'PY'
import hashlib,sys
print("sha256:"+hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())
PY
)"
export POLYLANE_ATTEMPT=1
start=$(python3 - "$ROOT/core/scripts/polylane-skill-store.py" $$ <<'PY'
import importlib.util,sys
spec=importlib.util.spec_from_file_location("store",sys.argv[1])
store=importlib.util.module_from_spec(spec); spec.loader.exec_module(store)
print(store.token(int(sys.argv[2])))
PY
)
deadline=$(( $(date +%s) + 60 ))
jq -cnS --argjson pid "$$" --arg token "$start" --argjson deadline "$deadline" \
  --arg job_id "$(jq -r .job_id "$T/input.json")" --arg input_hash "$input_hash" \
  '{role:"guardian",pid:$pid,start_token:$token,generation:7,deadline_epoch:$deadline,
    job_id:$job_id,input_sha256:$input_hash}' >"$T/owner.json"
cat >"$T/fixtures/search.json" <<'JSON'
{"items":[{"repository":{"full_name":"acme/skills"}}]}
JSON
jq -cn '{default_branch:"main",owner:{login:"maintainer"},
  license:{key:"apache-2.0",name:"Apache License 2.0",spdx_id:"Apache-2.0",
    url:"https://api.github.com/licenses/apache-2.0"},
  permissions:{admin:false,push:false,pull:true,maintain:false,triage:true}}' >"$T/fixtures/repo.json"
printf 'MIT license at pinned commit\n' >"$T/fixtures/license-body"
printf 'bounded README fixture\n' >"$T/fixtures/readme"
mkdir "$T/git-objects"; git -C "$T/git-objects" init -q
license_blob=$(git -C "$T/git-objects" hash-object -w "$T/fixtures/license-body")
license_content=$(base64 <"$T/fixtures/license-body" | tr -d '\n')
jq -cn --arg sha "$license_blob" --arg content "$license_content" \
  '{name:"LICENSE",path:"LICENSE",sha:$sha,size:29,encoding:"base64",content:$content,
    license:{key:"mit",name:"MIT License",spdx_id:"MIT",
      url:"https://api.github.com/licenses/mit"}}' >"$T/fixtures/license.json"
printf '200\n' >"$T/fixtures/license.status"
printf '%s\n' '---' 'name: generic' 'description: generic helper' '---' '' \
  'unrelated rendering content' >"$T/fixtures/root-skill"
printf '%s\n' '---' 'name: api-contract-verification' \
  'description: Verify REST API route contracts' 'metadata:' '  source: fixture' '---' '' \
  'Run REST API route verification against actual contract responses.' >"$T/fixtures/nested-skill"
forty_c=$(git -C "$T/git-objects" hash-object -w "$T/fixtures/root-skill")
forty_d=$(git -C "$T/git-objects" hash-object -w "$T/fixtures/nested-skill")
readme_blob=$(git -C "$T/git-objects" hash-object -w "$T/fixtures/readme")
root_size=$(wc -c <"$T/fixtures/root-skill" | tr -d ' ')
nested_size=$(wc -c <"$T/fixtures/nested-skill" | tr -d ' ')
api_tree=$(printf '100644 blob %s\tSKILL.md\n' "$forty_d" | git -C "$T/git-objects" mktree)
skills_tree=$(printf '040000 tree %s\tapi\n' "$api_tree" | git -C "$T/git-objects" mktree)
forty_b=$(printf '100644 blob %s\tLICENSE\n100644 blob %s\tREADME.md\n100644 blob %s\tSKILL.md\n040000 tree %s\tskills\n' \
  "$license_blob" "$readme_blob" "$forty_c" "$skills_tree" | git -C "$T/git-objects" mktree)
commit_epoch=$(python3 - <<'PY'
import datetime
print(int(datetime.datetime.fromisoformat("2026-07-15T17:45:00+05:45").timestamp()))
PY
)
python3 - "$forty_b" "$commit_epoch" "$T/fixtures" <<'PY'
import pathlib,sys
tree,epoch,fixture_root=sys.argv[1:]
root=pathlib.Path(fixture_root)
message=b"Pinned fixture commit\n"
headers=[f"tree {tree}".encode(),
  f"author Fixture Author <author@example.test> {epoch} +0545".encode(),
  f"committer Fixture Committer <committer@example.test> {epoch} +0545".encode()]
unsigned=b"\n".join(headers+[b"",message])
signature=(b"-----BEGIN PGP SIGNATURE-----\n\nfixture-signature\n"
  b"-----END PGP SIGNATURE-----\n")
gpgsig=b"gpgsig "+b"\n ".join(signature.splitlines())
(root/"commit.unsigned").write_bytes(unsigned)
(root/"commit.signature").write_bytes(signature)
(root/"commit.payload").write_bytes(b"\n".join(headers+[gpgsig,b"",message]))
PY
forty_a=$(git hash-object -t commit "$T/fixtures/commit.payload")
jq -cn --arg commit "$forty_a" '{sha:$commit}' >"$T/fixtures/commit.json"
jq -cn --arg commit "$forty_a" --arg tree "$forty_b" \
  --rawfile signature "$T/fixtures/commit.signature" \
  --rawfile payload "$T/fixtures/commit.unsigned" \
  '{sha:$commit,url:("https://api.github.com/repos/acme/skills/git/commits/"+$commit),
    author:{name:"Fixture Author",email:"author@example.test",date:"2026-07-15T17:45:00+05:45"},
    committer:{name:"Fixture Committer",email:"committer@example.test",date:"2026-07-15T17:45:00+05:45"},
    message:"Pinned fixture commit\n",tree:{sha:$tree,
      url:("https://api.github.com/repos/acme/skills/git/trees/"+$tree)},parents:[],
    verification:{signature:$signature,payload:$payload}}' >"$T/fixtures/git-commit.json"
jq -cn --arg sha "$forty_b" --arg license "$license_blob" --arg readme "$readme_blob" \
  --arg root "$forty_c" --arg skills "$skills_tree" --argjson root_size "$root_size" \
  '{sha:$sha,url:("https://api.github.com/repos/acme/skills/git/trees/"+$sha),truncated:false,tree:[
    {path:"LICENSE",mode:"100644",type:"blob",size:29,sha:$license,url:("https://api.github.com/repos/acme/skills/git/blobs/"+$license)},
    {path:"README.md",mode:"100644",type:"blob",size:23,sha:$readme,url:("https://api.github.com/repos/acme/skills/git/blobs/"+$readme)},
    {path:"SKILL.md",mode:"100644",type:"blob",size:$root_size,sha:$root,url:("https://api.github.com/repos/acme/skills/git/blobs/"+$root)},
    {path:"skills",mode:"040000",type:"tree",sha:$skills,url:("https://api.github.com/repos/acme/skills/git/trees/"+$skills)}]}' \
  >"$T/fixtures/root-tree.json"
jq -cn --arg sha "$skills_tree" --arg api "$api_tree" \
  '{sha:$sha,url:("https://api.github.com/repos/acme/skills/git/trees/"+$sha),truncated:false,
    tree:[{path:"api",mode:"040000",type:"tree",sha:$api,url:("https://api.github.com/repos/acme/skills/git/trees/"+$api)}]}' \
  >"$T/fixtures/skills-tree.json"
jq -cn --arg sha "$api_tree" --arg nested "$forty_d" --argjson nested_size "$nested_size" \
  '{sha:$sha,url:("https://api.github.com/repos/acme/skills/git/trees/"+$sha),truncated:false,
    tree:[{path:"SKILL.md",mode:"100644",type:"blob",size:$nested_size,sha:$nested,
      url:("https://api.github.com/repos/acme/skills/git/blobs/"+$nested)}]}' \
  >"$T/fixtures/api-tree.json"
for which in root nested; do
  encoded=$(base64 <"$T/fixtures/$which-skill" | tr -d '\n')
  blob=$(git hash-object "$T/fixtures/$which-skill")
  jq -cn --arg sha "$blob" --arg content "$encoded" \
    '{sha:$sha,encoding:"base64",content:$content}' \
    >"$T/fixtures/$which-blob.json"
done
nested_content=$(jq -r .content "$T/fixtures/nested-blob.json")
cat >"$T/bin/gh" <<'SH'
#!/usr/bin/env bash
if [ "$#" -eq 9 ] && [ "$1" = api ] && [ "$2" = --method ] && [ "$3" = GET ] &&
  [ "$4" = -H ] && [ "$5" = 'Accept: application/vnd.github+json' ] &&
  [ "$6" = -H ] && [ "$7" = 'X-GitHub-Api-Version: 2022-11-28' ] &&
  [ "$8" = --include ]; then
  printf 'CALL\n' >>"$GH_LOG"; printf 'ARG:%s\n' "$@" >>"$GH_LOG"
  case "$9" in
    "/repos/acme/skills/license?ref=$GH_COMMIT")
      status=$(cat "$GH_FIX/license.status")
      if [ "$status" = 404 ]; then
        printf 'HTTP/2 404 Not Found\r\nContent-Type: application/json\r\n\r\n'
        printf '%s\n' '{"message":"Not Found"}'
        exit 1
      fi
      printf 'HTTP/2 200 OK\r\nContent-Type: application/json\r\n\r\n'
      cat "$GH_FIX/license.json"
      exit 0 ;;
    *) exit 91 ;;
  esac
fi
[ "$#" -eq 8 ] && [ "$1" = api ] && [ "$2" = --method ] && [ "$3" = GET ] &&
  [ "$4" = -H ] && [ "$5" = 'Accept: application/vnd.github+json' ] &&
  [ "$6" = -H ] && [ "$7" = 'X-GitHub-Api-Version: 2022-11-28' ] || exit 90
printf 'CALL\n' >>"$GH_LOG"; printf 'ARG:%s\n' "$@" >>"$GH_LOG"
case "$8" in
  /search/code*) cat "$GH_FIX/search.json" ;;
  /repos/acme/skills) cat "$GH_FIX/repo.json" ;;
  /repos/acme/skills/commits/main) cat "$GH_FIX/commit.json" ;;
  "/repos/acme/skills/git/commits/$GH_COMMIT") cat "$GH_FIX/git-commit.json" ;;
  "/repos/acme/skills/git/trees/$GH_ROOT_TREE") cat "$GH_FIX/root-tree.json" ;;
  "/repos/acme/skills/git/trees/$GH_SKILLS_TREE") cat "$GH_FIX/skills-tree.json" ;;
  "/repos/acme/skills/git/trees/$GH_API_TREE") cat "$GH_FIX/api-tree.json" ;;
  "/repos/acme/skills/git/blobs/$GH_ROOT_BLOB")
    cat "$GH_FIX/root-blob.json" ;;
  "/repos/acme/skills/git/blobs/$GH_NESTED_BLOB")
    cat "$GH_FIX/nested-blob.json" ;;
  *) exit 91 ;;
esac
SH
chmod +x "$T/bin/gh"
export GH_LOG="$T/gh.log" GH_FIX="$T/fixtures" GH_ROOT_BLOB="$forty_c" \
  GH_NESTED_BLOB="$forty_d" GH_COMMIT="$forty_a" GH_ROOT_TREE="$forty_b" \
  GH_SKILLS_TREE="$skills_tree" GH_API_TREE="$api_tree" POLYLANE_GH="$T/bin/gh"
"$JOB" run "$T/input.json" "$T/owner.json" "$T/result.json" "$T/ledger"
assert_eq "found-terminal" found \
  "$(jq -r '.terminals[]|select(.gap_id=="api:verification")|.status' "$T/result.json")"
assert_eq "no-match-terminal" no_match \
  "$(jq -r '.terminals[]|select(.gap_id=="mobile:implementation")|.status' "$T/result.json")"
assert_ok "pinned-candidate-evidence" jq -e --arg nested "$forty_d" \
  --arg commit "$forty_a" --arg tree "$forty_b" \
  '.terminals[]|select(.gap_id=="api:verification")|.candidate |
   .path=="skills/api/SKILL.md" and
   .commit_sha==$commit and .tree_sha==$tree and
   .blob_sha==$nested and
   .repository_url=="https://github.com/acme/skills" and
   .maintainer=="maintainer" and
   .repository_permissions.pull==true and .repository_permissions.triage==true and
   .recent_activity.committed_at=="2026-07-15T17:45:00+05:45" and
   .license_evidence.status=="identified" and .license_evidence.spdx_id=="MIT" and
   .license_evidence.source_endpoint==("/repos/acme/skills/license?ref="+$commit) and
   .license_evidence.ref==$commit and
   (.license_evidence.blob_sha|test("^[0-9a-f]{40}$")) and
   (.license_evidence.content_sha256|test("^sha256:[0-9a-f]{64}$")) and
   .why.lane=="api" and .why.gap_id=="api:verification" and
   (.why.matched_metadata_tokens|length)>0 and (.why.matched_body_tokens|length)>0 and
   .introduced_permissions.status=="manual_review_required" and
   (.introduced_permissions.candidate_text_mentions|type)=="array" and
   .introduced_tooling.status=="manual_review_required" and
   (.introduced_tooling.candidate_text_mentions|type)=="array" and
   (.body_sha256|test("^sha256:[0-9a-f]{64}$"))' "$T/result.json"
assert_not_contains "never-fetch-readme" '/README' "$(cat "$T/gh.log")"
assert_eq "root-and-nested-fetched" 4 \
  "$(grep -c '/git/blobs/' "$T/gh.log" | tr -d ' ')"
assert_eq "ledger-one" 1 \
  "$("$ROOT/core/scripts/polylane-skill-store.sh" read-ledger "$T/ledger" job_id | wc -l | tr -d ' ')"

# A default-branch repository license is never used as pinned-candidate evidence. The pinned
# endpoint may be missing or NOASSERTION; both remain informational and conservative.
printf '404\n' >"$T/fixtures/license.status"
"$JOB" run "$T/input.json" "$T/owner.json" "$T/missing-license.json" \
  "$T/missing-license-ledger"
assert_ok "missing-license-conservative" jq -e --arg commit "$forty_a" \
  '.terminals[]|select(.status=="found")|.candidate.license_evidence |
   .status=="missing" and .spdx_id==null and .blob_sha==null and
   .source_endpoint==("/repos/acme/skills/license?ref="+$commit) and
   .ref==$commit' \
  "$T/missing-license.json"
printf '200\n' >"$T/fixtures/license.status"
jq -cS '.license={key:"other",name:"Other",spdx_id:"NOASSERTION",url:null}' \
  "$T/fixtures/license.json" >"$T/fixtures/license.tmp"
mv "$T/fixtures/license.tmp" "$T/fixtures/license.json"
"$JOB" run "$T/input.json" "$T/owner.json" "$T/unknown-license.json" \
  "$T/unknown-license-ledger"
assert_ok "unknown-license-conservative" jq -e --arg commit "$forty_a" \
  '.terminals[]|select(.status=="found")|.candidate.license_evidence |
   .status=="unknown" and .spdx_id==null and
   (.blob_sha|test("^[0-9a-f]{40}$")) and
   (.content_sha256|test("^sha256:[0-9a-f]{64}$")) and
   .source_endpoint==("/repos/acme/skills/license?ref="+$commit) and
   .ref==$commit' \
  "$T/unknown-license.json"

# Pinned object ids are claims until the decoded bytes reproduce Git's canonical blob SHA-1.
# Keeping the endpoint/tree/API sha fixed while changing bytes must yield unavailable—not a
# candidate and not no_match—for both license and skill bodies.
printf 'BAD license at pinned commit\n' >"$T/fixtures/bad-license-body"
bad_license_content=$(base64 <"$T/fixtures/bad-license-body" | tr -d '\n')
jq -cS --arg content "$bad_license_content" '.content=$content' \
  "$T/fixtures/license.json" >"$T/fixtures/license.tmp"
mv "$T/fixtures/license.tmp" "$T/fixtures/license.json"
"$JOB" run "$T/input.json" "$T/owner.json" "$T/license-object-mismatch.json" \
  "$T/license-object-mismatch-ledger"
assert_ok "license-object-mismatch-unavailable" jq -e \
  '(.terminals|length)==2 and
   all(.terminals[];.status=="unavailable" and
     .reason=="license_blob_object_mismatch" and
     (has("candidate")|not))' "$T/license-object-mismatch.json"
jq -cS --arg content "$license_content" '.content=$content' \
  "$T/fixtures/license.json" >"$T/fixtures/license.tmp"
mv "$T/fixtures/license.tmp" "$T/fixtures/license.json"

printf 'not the claimed pinned skill blob\n' >"$T/fixtures/bad-skill-body"
bad_skill_content=$(base64 <"$T/fixtures/bad-skill-body" | tr -d '\n')
jq -cS --arg content "$bad_skill_content" '.content=$content' \
  "$T/fixtures/nested-blob.json" >"$T/fixtures/nested-blob.tmp"
mv "$T/fixtures/nested-blob.tmp" "$T/fixtures/nested-blob.json"
"$JOB" run "$T/input.json" "$T/owner.json" "$T/skill-object-mismatch.json" \
  "$T/skill-object-mismatch-ledger"
assert_ok "skill-object-mismatch-unavailable" jq -e \
  '(.terminals|length)==2 and
   all(.terminals[];.status=="unavailable" and
     .reason=="skill_blob_object_mismatch" and
     (has("candidate")|not))' "$T/skill-object-mismatch.json"
jq -cS --arg content "$nested_content" '.content=$content' \
  "$T/fixtures/nested-blob.json" >"$T/fixtures/nested-blob.tmp"
mv "$T/fixtures/nested-blob.tmp" "$T/fixtures/nested-blob.json"

cp "$T/fixtures/git-commit.json" "$T/fixtures/git-commit.valid.json"
jq -cS '.message="tampered commit bytes\n"' "$T/fixtures/git-commit.json" \
  >"$T/fixtures/git-commit.tmp"
mv "$T/fixtures/git-commit.tmp" "$T/fixtures/git-commit.json"
"$JOB" run "$T/input.json" "$T/owner.json" "$T/signed-payload-mismatch.json" \
  "$T/signed-payload-mismatch-ledger"
assert_ok "signed-payload-mismatch-unavailable" jq -e \
  'all(.terminals[];.status=="unavailable" and .reason=="commit_signed_payload" and
    (has("candidate")|not))' "$T/signed-payload-mismatch.json"
mv "$T/fixtures/git-commit.valid.json" "$T/fixtures/git-commit.json"

cp "$T/fixtures/git-commit.json" "$T/fixtures/git-commit.valid.json"
jq -cS '.verification.signature += "tampered\n"' "$T/fixtures/git-commit.json" \
  >"$T/fixtures/git-commit.tmp"
mv "$T/fixtures/git-commit.tmp" "$T/fixtures/git-commit.json"
"$JOB" run "$T/input.json" "$T/owner.json" "$T/commit-object-mismatch.json" \
  "$T/commit-object-mismatch-ledger"
assert_ok "signed-commit-object-mismatch-unavailable" jq -e \
  'all(.terminals[];.status=="unavailable" and .reason=="commit_object_mismatch" and
    (has("candidate")|not))' "$T/commit-object-mismatch.json"
mv "$T/fixtures/git-commit.valid.json" "$T/fixtures/git-commit.json"

cp "$T/fixtures/root-tree.json" "$T/fixtures/root-tree.valid.json"
jq -cS '(.tree[]|select(.path=="SKILL.md")|.mode)="100755"' \
  "$T/fixtures/root-tree.json" >"$T/fixtures/root-tree.tmp"
mv "$T/fixtures/root-tree.tmp" "$T/fixtures/root-tree.json"
"$JOB" run "$T/input.json" "$T/owner.json" "$T/tree-object-mismatch.json" \
  "$T/tree-object-mismatch-ledger"
assert_ok "tree-object-mismatch-unavailable" jq -e \
  'all(.terminals[];.status=="unavailable" and .reason=="tree_object_mismatch" and
    (has("candidate")|not))' "$T/tree-object-mismatch.json"
mv "$T/fixtures/root-tree.valid.json" "$T/fixtures/root-tree.json"

rm "$T/result.json"
"$JOB" run "$T/input.json" "$T/owner.json" "$T/result.json" "$T/concurrent-ledger" & first=$!
"$JOB" run "$T/input.json" "$T/owner.json" "$T/result.json" "$T/concurrent-ledger" & second=$!
wait "$first"; wait "$second"
assert_eq "concurrent-idempotent-result" 1 \
  "$("$ROOT/core/scripts/polylane-skill-store.sh" read-ledger "$T/concurrent-ledger" job_id | wc -l | tr -d ' ')"
POLYLANE_SUGGEST_ENGINE="$T/missing-helper" "$JOB" run \
  "$T/input.json" "$T/owner.json" "$T/missing-result.json" "$T/missing-ledger"
assert_eq "missing-helper-terminal-count" 2 \
  "$(jq '[.terminals[]|select(.status=="unavailable" and .reason=="missing_helper")]|length' "$T/missing-result.json")"
POLYLANE_GH=definitely-missing-gh "$JOB" run \
  "$T/input.json" "$T/owner.json" "$T/no-gh.json" "$T/no-gh-ledger"
assert_eq "missing-gh-terminal-count" 2 \
  "$(jq '[.terminals[]|select(.status=="unavailable" and .reason=="gh_unavailable")]|length' "$T/no-gh.json")"
cat >"$T/bin/slow-gh" <<'SH'
#!/usr/bin/env bash
sleep 3
SH
chmod +x "$T/bin/slow-gh"
deadline=$(( $(date +%s) + 2 ))
jq -cnS --argjson pid "$$" --arg token "$start" --argjson deadline "$deadline" \
  --arg job_id "$(jq -r .job_id "$T/input.json")" --arg input_hash "$input_hash" \
  '{role:"guardian",pid:$pid,start_token:$token,generation:8,deadline_epoch:$deadline,
    job_id:$job_id,input_sha256:$input_hash}' >"$T/timeout-owner.json"
POLYLANE_GH="$T/bin/slow-gh" "$JOB" run "$T/input.json" "$T/timeout-owner.json" \
  "$T/timeout.json" "$T/timeout-ledger"
assert_eq "timeout-terminal-count" 2 \
  "$(jq '[.terminals[]|select(.status=="timeout" and .reason=="guardian_deadline")]|length' "$T/timeout.json")"

# Malformed external response shapes are terminal data, never a missing result.
printf '%s\n' '[]' >"$T/fixtures/search.json"
rm "$T/result.json"
"$JOB" run "$T/input.json" "$T/owner.json" "$T/malformed.json" "$T/malformed-ledger"
assert_eq "malformed-response-terminal-count" 2 \
  "$(jq '[.terminals[]|select(.status=="unavailable" and .reason=="invalid_response")]|length' "$T/malformed.json")"

cat >"$T/bin/slow-adapter" <<'SH'
#!/usr/bin/env bash
sleep 6
SH
chmod +x "$T/bin/slow-adapter"
jq -cnS '{schema_version:1,gaps:[{activities:["REST API route"],domain:"api",
  gap_id:"api:verification",lane:"api",missing_capability:"verification"}],kits:[],
  manifest_sha256:"sha256:0000000000000000000000000000000000000000000000000000000000000000",
  inventory_sha256:"sha256:0000000000000000000000000000000000000000000000000000000000000000"}' \
  >"$T/index.json"
"$SUGGEST" enqueue-index "$T/index.json" "$T/bin/slow-adapter" "$T/preflight.json"
assert_ok "adapter-timeout-is-durable-input" jq -e \
  '.preflight_unavailable=="adapter_timeout" and .search_terms==[]' "$T/preflight.json"
cat >"$T/bin/malformed-adapter" <<'SH'
#!/usr/bin/env bash
printf '%s\n' '{"unexpected":"shape"}'
SH
chmod +x "$T/bin/malformed-adapter"
"$SUGGEST" enqueue-index "$T/index.json" "$T/bin/malformed-adapter" \
  "$T/malformed-preflight.json"
assert_ok "malformed-adapter-is-durable-input" jq -e \
  '.preflight_unavailable=="adapter_unavailable" and .search_terms==[]' \
  "$T/malformed-preflight.json"
finish
```

Run:

```bash
chmod +x core/tests/test-skill-suggestions.sh
bash core/tests/test-skill-suggestions.sh
```

Expected RED: the enqueue and guardian job helpers do not exist.

- [ ] **Step 2: Add the complete pinned-object informational suggester**

Create `core/scripts/polylane-skill-suggest.py`:

```python
#!/usr/bin/env python3
import argparse, base64, datetime, hashlib, importlib.util, json, os, re, selectors, shutil, subprocess, time
from pathlib import Path
from urllib.parse import quote

HERE=Path(__file__).resolve().parent
SPEC=importlib.util.spec_from_file_location("polylane_skill_store",HERE/"polylane-skill-store.py")
store=importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(store)
MAX_RESPONSE=1048576; MAX_REPOS=20; MAX_PATHS=32; MAX_SKILL=131072
MAX_TREE_OBJECTS=64
HEADERS=("Accept: application/vnd.github+json","X-GitHub-Api-Version: 2022-11-28")
SHA40=re.compile(r"^[0-9a-f]{40}$")
ISO8601=re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
SPDX=re.compile(r"^[A-Za-z0-9.+-]+$")
PERMISSION_TERMS={"credential","credentials","database","filesystem","network",
  "permission","permissions","secret","secrets","shell","subprocess","write"}
TOOLING_TERMS={"bash","curl","docker","gh","git","jq","node","npm","npx","pip",
  "pipx","python","ruby","rust","wget"}

class Unavailable(Exception): pass
class TimedOut(Exception): pass
def fail(message): raise store.Fail(message)
def canon(value): return store.canon(value)
def sha(value): return store.sha(value)
def git_blob_sha(value):
    header=b"blob "+str(len(value)).encode("ascii")+b"\0"
    return hashlib.sha1(header+value).hexdigest()
def git_object_sha(kind,value):
    header=kind.encode("ascii")+b" "+str(len(value)).encode("ascii")+b"\0"
    return hashlib.sha1(header+value).hexdigest()
def exact_git_url(full_name,kind,object_id):
    return f"https://api.github.com/repos/{full_name}/git/{kind}/{object_id}"
def git_person(value):
    if not isinstance(value,dict) or set(value)!={"name","email","date"}: raise Unavailable("commit_person")
    name=value["name"]; email=value["email"]; date=value["date"]
    if (not all(isinstance(x,str) and x for x in (name,email,date)) or
      any(x in name+email for x in "\r\n<>\0")): raise Unavailable("commit_person")
    try: parsed=datetime.datetime.fromisoformat(date.replace("Z","+00:00"))
    except ValueError: raise Unavailable("commit_date")
    offset=parsed.utcoffset()
    if offset is None or offset.total_seconds()%60: raise Unavailable("commit_timezone")
    minutes=int(offset.total_seconds()//60); sign="+" if minutes>=0 else "-"; minutes=abs(minutes)
    zone=f"{sign}{minutes//60:02d}{minutes%60:02d}"
    return f"{name} <{email}> {int(parsed.timestamp())} {zone}".encode(),date
def commit_payload(tree_sha,parents,author,committer,message,signature=None):
    lines=[b"tree "+tree_sha.encode()]
    lines.extend(b"parent "+parent.encode() for parent in parents)
    lines.extend((b"author "+author,b"committer "+committer))
    if signature is not None:
        if (not isinstance(signature,str) or not signature or len(signature.encode("utf-8"))>262144 or
          "\0" in signature or "\r" in signature):
            raise Unavailable("commit_signature")
        signature_lines=signature.encode("utf-8").splitlines()
        if not signature_lines: raise Unavailable("commit_signature")
        lines.append(b"gpgsig "+b"\n ".join(signature_lines))
    return b"\n".join(lines+[b"",message.encode("utf-8")])
def verified_commit(gh,full_name,commit_sha,deadline):
    endpoint=f"/repos/{full_name}/git/commits/{commit_sha}"
    value=request(gh,endpoint,deadline)
    if (not isinstance(value,dict) or value.get("sha")!=commit_sha or
      value.get("url")!=exact_git_url(full_name,"commits",commit_sha)):
        raise Unavailable("commit_response_identity")
    tree=value.get("tree"); parents=value.get("parents"); message=value.get("message")
    if (not isinstance(tree,dict) or not SHA40.match(str(tree.get("sha"))) or
      tree.get("url")!=exact_git_url(full_name,"trees",tree["sha"]) or
      not isinstance(parents,list) or not isinstance(message,str) or "\0" in message):
        raise Unavailable("commit_shape")
    author,_=git_person(value.get("author")); committer,committed_at=git_person(value.get("committer"))
    parent_ids=[]
    for parent in parents:
        sha1=parent.get("sha") if isinstance(parent,dict) else None
        if (not SHA40.match(str(sha1)) or
          parent.get("url")!=exact_git_url(full_name,"commits",sha1)):
            raise Unavailable("commit_parent")
        parent_ids.append(sha1)
    unsigned=commit_payload(tree["sha"],parent_ids,author,committer,message)
    verification=value.get("verification",{})
    if not isinstance(verification,dict): raise Unavailable("commit_verification")
    signature=verification.get("signature"); signed_payload=verification.get("payload")
    if signature is None:
        if signed_payload is not None: raise Unavailable("commit_verification")
        payload=unsigned
    else:
        if (not isinstance(signed_payload,str) or len(signed_payload.encode("utf-8"))>MAX_RESPONSE or
          signed_payload.encode("utf-8")!=unsigned):
            raise Unavailable("commit_signed_payload")
        payload=commit_payload(tree["sha"],parent_ids,author,committer,message,signature)
    if git_object_sha("commit",payload)!=commit_sha: raise Unavailable("commit_object_mismatch")
    return tree["sha"],committed_at
def verified_tree(gh,full_name,tree_sha,deadline):
    value=request(gh,f"/repos/{full_name}/git/trees/{tree_sha}",deadline)
    if (not isinstance(value,dict) or value.get("sha")!=tree_sha or
      value.get("url")!=exact_git_url(full_name,"trees",tree_sha) or
      value.get("truncated") is not False or not isinstance(value.get("tree"),list)):
        raise Unavailable("tree_response_identity")
    rows=[]; encoded=[]; order=[]
    for item in value["tree"]:
        if not isinstance(item,dict): raise Unavailable("tree_entry")
        path=item.get("path"); kind=item.get("type"); object_id=item.get("sha"); mode=item.get("mode")
        if (not isinstance(path,str) or "/" in path or not SHA40.match(str(object_id)) or
          kind not in ("blob","tree","commit") or mode not in ("100644","100755","040000","40000","120000","160000")):
            raise Unavailable("tree_entry")
        store.safe_name(path); canonical_mode="40000" if mode=="040000" else mode
        url_kind={"blob":"blobs","tree":"trees","commit":"commits"}[kind]
        if item.get("url")!=exact_git_url(full_name,url_kind,object_id): raise Unavailable("tree_entry_link")
        name=path.encode("utf-8"); sort_key=name+(b"/" if kind=="tree" else b"")
        order.append(sort_key); encoded.append(canonical_mode.encode()+b" "+name+b"\0"+bytes.fromhex(object_id))
        rows.append({"path":path,"type":kind,"mode":canonical_mode,"sha":object_id,
          "size":item.get("size")})
    if order!=sorted(order) or len(order)!=len(set(order)): raise Unavailable("tree_order")
    if git_object_sha("tree",b"".join(encoded))!=tree_sha: raise Unavailable("tree_object_mismatch")
    return rows
def walk_verified_trees(gh,full_name,root_sha,deadline):
    pending=[("",root_sha)]; all_rows=[]; objects=0
    while pending:
        prefix,tree_sha=pending.pop(0); objects+=1
        if objects>MAX_TREE_OBJECTS: raise Unavailable("tree_object_limit")
        for row in verified_tree(gh,full_name,tree_sha,deadline):
            full=f"{prefix}/{row['path']}" if prefix else row["path"]
            linked=dict(row,path=full); all_rows.append(linked)
            if row["type"]=="tree": pending.append((full,row["sha"]))
    return all_rows
def load(path):
    raw=store.read_regular(path,store.MAX_INV); value=json.loads(raw)
    if raw!=canon(value): fail("noncanonical suggestion JSON")
    return value,raw
def publish(path,value):
    store.ensure_dir(Path(path).absolute().parent,0o700)
    expected=canon(value)
    with store.Lock(path,30):
        if os.path.lexists(path):
            if store.read_regular(path,store.MAX_INV)!=expected: fail("suggestion publication conflict")
        else: store.atomic_write(path,expected,0o444)
def tokens(value):
    if isinstance(value,list): value=" ".join(str(x) for x in value)
    return {x for x in re.findall(r"[a-z0-9]+",str(value).lower()) if len(x)>=3}
def runner_scope():
    claim=os.environ.get("POLYLANE_CLAIM_TOKEN","")
    try:
        generation=int(os.environ.get("POLYLANE_RUNNER_GENERATION","-1"))
        attempt=int(os.environ.get("POLYLANE_ATTEMPT","-1"))
    except ValueError: fail("runner suggestion identity")
    if (not re.match(r"^[A-Za-z0-9._-]+$",claim) or generation<1 or attempt<1):
        fail("runner suggestion identity")
    return {"claim":claim,"generation":generation,"attempt":attempt}
def introduction_review(meta,body):
    # Candidate text is untrusted and incomplete, so absence is never represented as
    # permission/tooling safety. These are bounded mentions for mandatory manual review.
    words=tokens(json.dumps(meta,sort_keys=True))|tokens(body)
    return ({"status":"manual_review_required",
      "candidate_text_mentions":sorted(words&PERMISSION_TERMS)},
      {"status":"manual_review_required",
      "candidate_text_mentions":sorted(words&TOOLING_TERMS)})
def request_raw(gh,path,deadline,include=False):
    if deadline<=time.time(): raise TimedOut()
    argv=[gh,"api","--method","GET","-H",HEADERS[0],"-H",HEADERS[1]]
    if include: argv.append("--include")
    argv.append(path)
    process=subprocess.Popen(argv,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,close_fds=True)
    selector=selectors.DefaultSelector()
    selector.register(process.stdout,selectors.EVENT_READ,"stdout")
    selector.register(process.stderr,selectors.EVENT_READ,"stderr")
    chunks={"stdout":bytearray(),"stderr":bytearray()}
    try:
        while selector.get_map():
            remaining=deadline-time.time()
            if remaining<=0:
                process.kill(); process.wait(); raise TimedOut()
            for key,_ in selector.select(min(remaining,.2)):
                data=os.read(key.fileobj.fileno(),65536)
                if not data:
                    selector.unregister(key.fileobj); continue
                chunks[key.data]+=data
                limit=MAX_RESPONSE if key.data=="stdout" else 65536
                if len(chunks[key.data])>limit:
                    process.kill(); process.wait(); raise Unavailable("response_too_large")
        rc=process.wait(timeout=max(.1,deadline-time.time()))
    except subprocess.TimeoutExpired:
        process.kill(); process.wait(); raise TimedOut()
    finally: selector.close()
    return rc,bytes(chunks["stdout"])
def request(gh,path,deadline):
    rc,raw=request_raw(gh,path,deadline)
    if rc!=0: raise Unavailable("gh_request_failed")
    try: return json.loads(raw)
    except json.JSONDecodeError: raise Unavailable("invalid_json")
def included_response(raw):
    matches=list(re.finditer(rb"(?m)^HTTP/[0-9.]+ ([0-9]{3})[^\r\n]*\r?$",raw))
    if not matches: raise Unavailable("license_status")
    match=matches[-1]; starts=[]
    for marker in (b"\r\n\r\n",b"\n\n"):
        found=raw.find(marker,match.end())
        if found>=0: starts.append((found+len(marker),found))
    if not starts: raise Unavailable("license_headers")
    start,_=min(starts,key=lambda item:item[1])
    return int(match.group(1)),raw[start:]
def pinned_license(gh,full_name,commit_sha,tree_rows,deadline):
    endpoint=f"/repos/{full_name}/license?ref={commit_sha}"
    rc,raw=request_raw(gh,endpoint,deadline,True); status,body=included_response(raw)
    missing={"status":"missing","spdx_id":None,"github_license_url":None,
      "source_endpoint":endpoint,"ref":commit_sha,"path":None,"blob_sha":None,
      "content_sha256":None}
    if status==404: return missing
    if rc!=0 or status!=200: raise Unavailable("license_request_failed")
    try: value=json.loads(body)
    except json.JSONDecodeError: raise Unavailable("license_json")
    if not isinstance(value,dict): raise Unavailable("license_response")
    path=value.get("path"); blob_sha=value.get("sha"); size=value.get("size")
    if (not isinstance(path,str) or not path or path.startswith("/") or
      not SHA40.match(str(blob_sha)) or not isinstance(size,int) or
      size<0 or size>MAX_SKILL or value.get("encoding")!="base64" or
      not isinstance(value.get("content"),str)):
        raise Unavailable("license_identity")
    for part in path.split("/"): store.safe_name(part)
    matching=[x for x in tree_rows if x.get("path")==path and x.get("type")=="blob" and
      x.get("sha")==blob_sha]
    if len(matching)!=1: raise Unavailable("license_tree_binding")
    try: content=base64.b64decode(value["content"],validate=True)
    except ValueError: raise Unavailable("license_encoding")
    if len(content)!=size: raise Unavailable("license_blob")
    if git_blob_sha(content)!=blob_sha:
        raise Unavailable("license_blob_object_mismatch")
    license_value=value.get("license"); spdx_id=None; github_license_url=None
    if isinstance(license_value,dict):
        candidate=license_value.get("spdx_id")
        if (isinstance(candidate,str) and SPDX.match(candidate) and
          candidate!="NOASSERTION"): spdx_id=candidate
        url=license_value.get("url")
        if isinstance(url,str) and url.startswith("https://api.github.com/licenses/"):
            github_license_url=url
    return {"status":"identified" if spdx_id else "unknown","spdx_id":spdx_id,
      "github_license_url":github_license_url,"source_endpoint":endpoint,
      "ref":commit_sha,"path":path,"blob_sha":blob_sha,
      "content_sha256":sha(content)}
def validate_owner(input_path,owner_path):
    job,input_raw=load(input_path); guardian,_=load(owner_path)
    job_base=dict(job); job_id=job_base.pop("job_id",None)
    runner=job.get("runner")
    if (job_id!=sha(canon(job_base)) or not isinstance(runner,dict) or
      set(runner)!={"claim","generation","attempt"} or
      not re.match(r"^[A-Za-z0-9._-]+$",str(runner.get("claim",""))) or
      not isinstance(runner.get("generation"),int) or runner["generation"]<1 or
      not isinstance(runner.get("attempt"),int) or runner["attempt"]<1):
        fail("suggestion job identity")
    keys={"role","pid","start_token","generation","deadline_epoch","job_id","input_sha256"}
    if set(guardian)!=keys or guardian["role"]!="guardian" or guardian["job_id"]!=job["job_id"] or guardian["input_sha256"]!=sha(input_raw): fail("guardian owner schema")
    if not isinstance(guardian["generation"],int) or guardian["generation"]<0: fail("guardian generation")
    if int(guardian["pid"])<=1 or store.token(int(guardian["pid"]))!=guardian["start_token"]: fail("guardian not live")
    if int(guardian["deadline_epoch"])<=int(time.time()): fail("guardian deadline")
    return job,input_raw,guardian
def relevance(gap,skill_id,meta,body):
    wanted=tokens(gap["activities"])|tokens(gap["domain"])|tokens(gap["missing_capability"])
    metadata=tokens(skill_id)|tokens(meta["name"])|tokens(meta["description"])
    body_words=tokens(body); left=wanted&metadata; right=wanted&body_words
    if not left or not right: return None
    return {"total":len(left)+len(right),"shared":len(left&right),
      "metadata_tokens":sorted(left),"body_tokens":sorted(right)}
def repository_candidates(gh,full_name,gap,deadline):
    if not re.match(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$",full_name): raise Unavailable("repository_name")
    repo=request(gh,f"/repos/{full_name}",deadline); branch=repo.get("default_branch")
    if not isinstance(branch,str) or not branch: raise Unavailable("default_branch")
    reference=request(gh,f"/repos/{full_name}/commits/{quote(branch,safe='')}",deadline)
    commit_sha=reference.get("sha") if isinstance(reference,dict) else None
    if not SHA40.match(str(commit_sha)): raise Unavailable("immutable_commit")
    tree_sha,commit_date=verified_commit(gh,full_name,commit_sha,deadline)
    tree_rows=walk_verified_trees(gh,full_name,tree_sha,deadline)
    license_evidence=pinned_license(gh,full_name,commit_sha,tree_rows,deadline)
    paths=[x for x in tree_rows if x.get("type")=="blob" and
      (x.get("path")=="SKILL.md" or str(x.get("path","")).endswith("/SKILL.md"))]
    paths=sorted(paths,key=lambda x:x["path"])[:MAX_PATHS]
    permissions={x:bool(repo.get("permissions",{}).get(x,False))
      for x in ("admin","push","pull","maintain","triage")}
    maintainer=repo.get("owner",{}).get("login")
    if not isinstance(maintainer,str) or not maintainer: raise Unavailable("maintainer")
    found=[]
    for item in paths:
        blob_sha=item.get("sha")
        if not SHA40.match(str(blob_sha)) or int(item.get("size",MAX_SKILL+1))>MAX_SKILL: continue
        blob=request(gh,f"/repos/{full_name}/git/blobs/{blob_sha}",deadline)
        if blob.get("encoding")!="base64" or not isinstance(blob.get("content"),str): continue
        response_sha=blob.get("sha")
        if response_sha is not None and (not SHA40.match(str(response_sha)) or
          response_sha!=blob_sha):
            raise Unavailable("skill_blob_response_mismatch")
        try: raw=base64.b64decode(blob["content"],validate=True)
        except ValueError: continue
        if len(raw)>MAX_SKILL: continue
        if git_blob_sha(raw)!=blob_sha:
            raise Unavailable("skill_blob_object_mismatch")
        try: meta,body=store.frontmatter(raw)
        except (store.Fail,UnicodeError,ValueError): continue
        score=relevance(gap,item["path"],meta,body)
        if score is None: continue
        introduced_permissions,introduced_tooling=introduction_review(meta,body)
        found.append({"repository":full_name,"repository_url":f"https://github.com/{full_name}",
          "path":item["path"],"commit_sha":commit_sha,
          "tree_sha":tree_sha,"blob_sha":blob_sha,"maintainer":maintainer,
          "repository_permissions":permissions,"frontmatter":meta,"body_sha256":sha(raw),
          "license_evidence":license_evidence,
          "recent_activity":{"commit_sha":commit_sha,"committed_at":commit_date},
          "why":{"lane":gap["lane"],"gap_id":gap["gap_id"],
            "matched_metadata_tokens":score["metadata_tokens"],
            "matched_body_tokens":score["body_tokens"]},
          "introduced_permissions":introduced_permissions,
          "introduced_tooling":introduced_tooling,
          "score":{"total":score["total"],"shared":score["shared"]}})
    return found
def evaluate_gap(gh,job,gap,deadline):
    try:
        repositories=[]
        for term in job["search_terms"]:
            query=quote(f'filename:SKILL.md "{term}"',safe="")
            response=request(gh,f"/search/code?q={query}&per_page=20",deadline)
            for item in response.get("items",[]):
                full=item.get("repository",{}).get("full_name")
                if isinstance(full,str) and full not in repositories: repositories.append(full)
                if len(repositories)>=MAX_REPOS: break
            if len(repositories)>=MAX_REPOS: break
        candidates=[]
        for full_name in repositories:
            candidates.extend(repository_candidates(gh,full_name,gap,deadline))
        if not candidates: return {"gap_id":gap["gap_id"],"status":"no_match"}
        candidates.sort(key=lambda x:(-x["score"]["total"],-x["score"]["shared"],x["repository"],x["path"]))
        return {"gap_id":gap["gap_id"],"status":"found","candidate":candidates[0]}
    except TimedOut:
        return {"gap_id":gap["gap_id"],"status":"timeout","reason":"guardian_deadline"}
    except Unavailable as exc:
        return {"gap_id":gap["gap_id"],"status":"unavailable","reason":str(exc)}
    except (OSError,ValueError,TypeError,KeyError,AttributeError,json.JSONDecodeError,UnicodeError):
        return {"gap_id":gap["gap_id"],"status":"unavailable","reason":"invalid_response"}
def make_input(gaps,terms,path,preflight_unavailable=None):
    required={"gap_id","lane","domain","activities","missing_capability"}
    if set(gaps)!={"gaps"} or not isinstance(gaps["gaps"],list) or any(set(x)!=required for x in gaps["gaps"]): fail("gap schema")
    if len({x["gap_id"] for x in gaps["gaps"]})!=len(gaps["gaps"]): fail("duplicate gap")
    if (not isinstance(terms,list) or not all(isinstance(x,str) and x for x in terms) or
        (not terms and preflight_unavailable is None)): fail("search terms")
    if preflight_unavailable not in (None,"adapter_timeout","adapter_unavailable"):
        fail("suggestion preflight status")
    base={"schema_version":1,"runner":runner_scope(),"gaps":gaps["gaps"],"search_terms":terms,
      "preflight_unavailable":preflight_unavailable,
      "limits":{"response_bytes":MAX_RESPONSE,"repositories":MAX_REPOS,
        "paths_per_repository":MAX_PATHS,"skill_md_bytes":MAX_SKILL}}
    result=dict(base); result["job_id"]=sha(canon(base)); publish(path,result)
def enqueue(args):
    gaps,_=load(args.gaps); terms,_=load(args.search_terms); make_input(gaps,terms,args.input)
def enqueue_index(args):
    index,_=load(args.index)
    if not isinstance(index.get("gaps"),list): fail("kit index gaps")
    try:
        run=subprocess.run([args.adapter,"search-terms"],stdin=subprocess.DEVNULL,
          stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=5,check=False)
    except subprocess.TimeoutExpired:
        make_input({"gaps":index["gaps"]},[],args.input,"adapter_timeout"); return
    except OSError:
        make_input({"gaps":index["gaps"]},[],args.input,"adapter_unavailable"); return
    if run.returncode!=0 or len(run.stdout)>65536:
        make_input({"gaps":index["gaps"]},[],args.input,"adapter_unavailable"); return
    try: terms=json.loads(run.stdout)
    except (json.JSONDecodeError,UnicodeError):
        make_input({"gaps":index["gaps"]},[],args.input,"adapter_unavailable"); return
    if not isinstance(terms,list) or not terms or \
      not all(isinstance(x,str) and x for x in terms):
        make_input({"gaps":index["gaps"]},[],args.input,"adapter_unavailable"); return
    make_input({"gaps":index["gaps"]},terms,args.input)
def guardian_run(args):
    job,input_raw,guardian=validate_owner(args.input,args.owner)
    if Path(args.result).exists():
        existing,_=load(args.result)
        if existing.get("job_id")==job["job_id"] and existing.get("input_sha256")==sha(input_raw):
            store.append_jsonl(args.ledger,args.result,"job_id"); return
        fail("result conflict")
    gh=shutil.which(os.environ.get("POLYLANE_GH","gh"))
    if job.get("preflight_unavailable") is not None:
        terminals=[{"gap_id":x["gap_id"],"status":"unavailable",
          "reason":job["preflight_unavailable"]} for x in job["gaps"]]
    elif gh is None:
        terminals=[{"gap_id":x["gap_id"],"status":"unavailable","reason":"gh_unavailable"} for x in job["gaps"]]
    else:
        terminals=[evaluate_gap(gh,job,x,float(guardian["deadline_epoch"])) for x in job["gaps"]]
    allowed={"found","no_match","unavailable","timeout"}
    if (len(terminals)!=len(job["gaps"]) or
        [x.get("gap_id") for x in terminals]!=[x["gap_id"] for x in job["gaps"]] or
        any(x.get("status") not in allowed for x in terminals)): fail("terminal coverage")
    result={"schema_version":1,"job_id":job["job_id"],"input_sha256":sha(input_raw),
      "owner":guardian,"terminals":terminals}
    publish(args.result,result); store.append_jsonl(args.ledger,args.result,"job_id")
def main():
    parser=argparse.ArgumentParser(); sub=parser.add_subparsers(dest="command",required=True)
    q=sub.add_parser("enqueue"); q.add_argument("gaps"); q.add_argument("search_terms"); q.add_argument("input")
    q=sub.add_parser("enqueue-index"); q.add_argument("index"); q.add_argument("adapter"); q.add_argument("input")
    q=sub.add_parser("guardian-run")
    for name in ("input","owner","result","ledger"): q.add_argument(name)
    args=parser.parse_args()
    try: {"enqueue":enqueue,"enqueue-index":enqueue_index,"guardian-run":guardian_run}[args.command](args)
    except (store.Fail,OSError,ValueError,TypeError,KeyError,json.JSONDecodeError,UnicodeError) as exc:
        store.die(str(exc))
if __name__=="__main__": main()
```

Create `core/scripts/polylane-skill-suggest.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
exec python3 "$SCRIPT_DIR/polylane-skill-suggest.py" "$@"
```

- [ ] **Step 3: Add guardian-only job wrapper and missing-helper fallback**

Create `core/scripts/polylane-skill-suggest-job.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
[ "$#" -eq 5 ] && [ "$1" = run ] || {
  echo "usage: polylane-skill-suggest-job.sh run INPUT OWNER RESULT LEDGER" >&2
  exit 2
}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ENGINE=${POLYLANE_SUGGEST_ENGINE:-$SCRIPT_DIR/polylane-skill-suggest.sh}
if [ -x "$ENGINE" ]; then
  exec "$ENGINE" guardian-run "$2" "$3" "$4" "$5"
fi
python3 - "$SCRIPT_DIR/polylane-skill-store.py" "$2" "$3" "$4" "$5" <<'PY'
import importlib.util,json,os,re,sys,time
from pathlib import Path
spec=importlib.util.spec_from_file_location("store",sys.argv[1])
store=importlib.util.module_from_spec(spec); spec.loader.exec_module(store)
input_path,owner_path,result_path,ledger=sys.argv[2:]
job_raw=store.read_regular(input_path,store.MAX_INV); job=json.loads(job_raw)
owner_raw=store.read_regular(owner_path,store.MAX_INV); owner=json.loads(owner_raw)
job_base=dict(job); job_id=job_base.pop("job_id",None); runner=job.get("runner")
expected={"role","pid","start_token","generation","deadline_epoch","job_id","input_sha256"}
valid=(job_raw==store.canon(job) and job_id==store.sha(store.canon(job_base)) and
  isinstance(runner,dict) and set(runner)=={"claim","generation","attempt"} and
  re.match(r"^[A-Za-z0-9._-]+$",str(runner.get("claim",""))) and
  isinstance(runner.get("generation"),int) and runner["generation"]>=1 and
  isinstance(runner.get("attempt"),int) and runner["attempt"]>=1 and
  owner_raw==store.canon(owner) and
  set(owner)==expected and owner["role"]=="guardian" and owner["job_id"]==job["job_id"] and
  owner["input_sha256"]==store.sha(job_raw) and
  store.token(int(owner["pid"]))==owner["start_token"] and
  int(owner["deadline_epoch"])>int(time.time()))
if not valid: store.die("invalid guardian owner")
terminals=[{"gap_id":x["gap_id"],"status":"unavailable","reason":"missing_helper"}
  for x in job["gaps"]]
result={"schema_version":1,"job_id":job["job_id"],"input_sha256":store.sha(job_raw),
  "owner":owner,"terminals":terminals}
store.ensure_dir(Path(result_path).absolute().parent,0o700)
expected_result=store.canon(result)
with store.Lock(result_path,30):
  if os.path.lexists(result_path):
    if store.read_regular(result_path,store.MAX_INV)!=expected_result:
      store.die("suggestion result conflict")
  else: store.atomic_write(result_path,expected_result,0o444)
store.append_jsonl(ledger,result_path,"job_id")
PY
```

The fallback is data-only: it does not invoke `gh`, inspect repositories, execute candidate
content, or install anything.

- [ ] **Step 4: Run Task 3 checks and commit**

```bash
chmod +x core/scripts/polylane-skill-suggest.py core/scripts/polylane-skill-suggest.sh \
  core/scripts/polylane-skill-suggest-job.sh core/tests/test-skill-suggestions.sh
python3 -m py_compile core/scripts/polylane-skill-suggest.py
bash -n core/scripts/polylane-skill-suggest.sh \
  core/scripts/polylane-skill-suggest-job.sh core/tests/test-skill-suggestions.sh
shellcheck -S warning core/scripts/polylane-skill-suggest.sh \
  core/scripts/polylane-skill-suggest-job.sh core/tests/test-skill-suggestions.sh
bash core/tests/test-skill-suggestions.sh
git diff --check
git add core/scripts/polylane-skill-suggest.py core/scripts/polylane-skill-suggest.sh \
  core/scripts/polylane-skill-suggest-job.sh core/tests/test-skill-suggestions.sh
git commit -m "feat(core): publish guardian-owned skill suggestions"
```

Expected: exact GET-only argv, immutable commit/tree/blob evidence, identified/missing/unknown
license provenance, attempt-scoped jobs, typed terminals, missing-helper fallback,
concurrency, and segmented-ledger idempotence are green.

---

### Task 4: Wire Installed Codex Cycles and Package Parity End to End

**Files:**
- Create: `core/scripts/polylane-skill-cycle.sh`
- Modify: `core/scripts/polylane-run.sh`
- Modify: `core/scripts/polylane-doctor.sh`
- Modify: `core/scripts/polylane-package.sh`
- Modify: `core/scripts/polylane-scope.sh`
- Modify: `core/scripts/polylane-outcomes.sh`
- Modify: `codex/scripts/polylane-codex-exec.sh`
- Modify: `codex/scripts/polylane-codex-agent.sh`
- Modify: `codex/scripts/polylane-codex.sh`
- Modify: `codex/scripts/polylane-codex-rehearse.sh`
- Modify: `codex/install.sh`
- Modify: `claude-code/scripts/polylane-claude.sh`
- Modify: `claude-code/install.sh`
- Modify: `codex/package.json`
- Modify: `claude-code/package.json`
- Modify: `core/workflow/polylane-loop.md`
- Modify: `.polylane/SCHEMA.md`
- Modify: `core/tests/test-package-parity.sh`
- Modify: `core/tests/test-workflow-contract.sh`
- Create: `codex/tests/test-codex-skill-kits-installed.sh`
- Modify: `codex/tests/test-codex-errors.sh`
- Modify: `codex/tests/test-codex-rehearse.sh`
- Create: `core/tests/test-builder-foundation-dry-apply.sh`
- Create: `core/tests/test-builder-foundation-sequential-apply.sh`
- Create: `core/tests/fixtures/builder-foundation-base.commit`

**Interfaces:**
- The runner inventories/selects before git/tmux side effects, materializes/lints after
  worktree creation and before launch, and never changes `INT_PROMPT`. Only after
  `launch_panes` returns does it start the unawaited, network-free suggestion-input publisher.
- `lane_done` for a Builder means raw DONE plus local-tree lint, actor/result binding, fresh
  verification, runner attestation, and ledger score. Integrator DONE remains the existing
  exact raw-marker contract and receives no kit.
- Suggestion enqueue writes only immutable input under `runtime/skill-suggestions/inputs/`.
  Runtime guardian is the sole caller of `polylane-skill-suggest-job.sh`.

- [ ] **Step 1: Write the installed-package cycle test and verify RED**

Create `codex/tests/test-codex-skill-kits-installed.sh` from the complete body in Step 6
now, then run it before implementation:

```bash
chmod +x codex/tests/test-codex-skill-kits-installed.sh
bash codex/tests/test-codex-skill-kits-installed.sh
```

Expected RED: the installed runner does not yet frame/materialize kits or qualify DONE.

- [ ] **Step 2: Add the complete one-cycle skill orchestration library**

Create `core/scripts/polylane-skill-cycle.sh`:

```bash
#!/usr/bin/env bash
# Sourced by polylane-run.sh. This file owns Builder skill state; it never chooses
# proposal/controller work and never waits for a suggestion result.

POLYLANE_SKILLS_ACTIVE=0
POLYLANE_SKILL_GENERATIONS=()
POLYLANE_SKILL_ELIGIBLE=()
POLYLANE_SKILL_ORIGINAL_PROMPTS=()
POLYLANE_SKILL_KITS=()
POLYLANE_SKILL_ATTESTATIONS=()

polylane_skill_die() { echo "polylane-skill-cycle: $*" >&2; return 5; }
polylane_skill_lane_index() {
  local name=$1 i
  for i in "${!LANE_NAMES[@]}"; do
    [ "${LANE_NAMES[$i]}" = "$name" ] && { printf '%s\n' "$i"; return; }
  done
  return 1
}
polylane_skill_installed_helpers() {
  POLYLANE_SKILL_STORE=${POLYLANE_SKILL_STORE:-$SCRIPT_DIR/polylane-skill-store.sh}
  POLYLANE_SKILL_KIT=${POLYLANE_SKILL_KIT:-$SCRIPT_DIR/polylane-skill-kit.sh}
  POLYLANE_SKILL_LEDGER=${POLYLANE_SKILL_LEDGER:-$SCRIPT_DIR/polylane-skill-ledger.sh}
  POLYLANE_SKILL_SUGGEST=${POLYLANE_SKILL_SUGGEST:-$SCRIPT_DIR/polylane-skill-suggest.sh}
  POLYLANE_SKILL_ADAPTER=${POLYLANE_SKILL_ADAPTER:-$SCRIPT_DIR/polylane-codex-skills.sh}
  local helper
  for helper in "$POLYLANE_SKILL_STORE" "$POLYLANE_SKILL_KIT" \
    "$POLYLANE_SKILL_LEDGER" "$POLYLANE_SKILL_SUGGEST" "$POLYLANE_SKILL_ADAPTER"; do
    [ -x "$helper" ] || polylane_skill_die "installed helper unavailable: $helper" || return
  done
}
polylane_skills_prepare() {
  [ "$(agent_selected)" = codex ] || return 0
  case ${RUN_ID:-} in ''|*[!A-Za-z0-9._-]*) polylane_skill_die "unsafe run_id"; return ;; esac
  case ${POLYLANE_CLAIM_TOKEN:-} in
    ''|*[!A-Za-z0-9._-]*) polylane_skill_die "unsafe runner claim"; return ;;
  esac
  case ${POLYLANE_RUNNER_GENERATION:-}:${POLYLANE_ATTEMPT:-} in
    *[!0-9:]*|:*|*:|0:*|*:0) polylane_skill_die "unsafe runner generation/attempt"; return ;;
  esac
  polylane_skill_installed_helpers || return
  POLYLANE_SKILL_RUNTIME=${POLYLANE_RUNTIME_DIR:-$PROJECT_ROOT/.polylane/runtime}
  POLYLANE_SKILL_EVIDENCE_SCOPE=$POLYLANE_CLAIM_TOKEN/g$POLYLANE_RUNNER_GENERATION/a$POLYLANE_ATTEMPT
  POLYLANE_SKILL_INVENTORY=$POLYLANE_SKILL_RUNTIME/skill-inventory/$RUN_ID/$POLYLANE_SKILL_EVIDENCE_SCOPE.json
  POLYLANE_SKILL_SNAPSHOTS=$POLYLANE_SKILL_RUNTIME/skill-snapshots/$RUN_ID/$POLYLANE_SKILL_EVIDENCE_SCOPE
  POLYLANE_SKILL_KIT_DIR=$POLYLANE_SKILL_RUNTIME/skill-kits/$RUN_ID/$POLYLANE_SKILL_EVIDENCE_SCOPE
  POLYLANE_SKILL_SUGGEST_INPUT=$POLYLANE_SKILL_RUNTIME/skill-suggestions/inputs/$RUN_ID/$POLYLANE_SKILL_EVIDENCE_SCOPE.json
  POLYLANE_SKILL_LEDGER_PATH=$POLYLANE_SKILL_RUNTIME/skill-ledger/scores
  POLYLANE_SKILL_ARTIFACT_DIR=$POLYLANE_SKILL_RUNTIME/skill-verification/$RUN_ID/$POLYLANE_SKILL_EVIDENCE_SCOPE
  POLYLANE_SKILL_ATTESTATION_DIR=$POLYLANE_SKILL_RUNTIME/skill-attestations/$RUN_ID/$POLYLANE_SKILL_EVIDENCE_SCOPE
  "$POLYLANE_SKILL_STORE" ensure-dir "$POLYLANE_SKILL_RUNTIME" 0700
  "$POLYLANE_SKILL_STORE" ensure-dir "$(dirname "$POLYLANE_SKILL_INVENTORY")" 0700
  "$POLYLANE_SKILL_STORE" ensure-dir "$POLYLANE_SKILL_SNAPSHOTS" 0700
  "$POLYLANE_SKILL_STORE" ensure-dir "$POLYLANE_SKILL_KIT_DIR" 0700
  "$POLYLANE_SKILL_STORE" ensure-dir "$(dirname "$POLYLANE_SKILL_SUGGEST_INPUT")" 0700
  "$POLYLANE_SKILL_STORE" ensure-dir "$(dirname "$POLYLANE_SKILL_LEDGER_PATH")" 0700
  "$POLYLANE_SKILL_STORE" ensure-dir "$POLYLANE_SKILL_ARTIFACT_DIR" 0700
  "$POLYLANE_SKILL_STORE" ensure-dir "$POLYLANE_SKILL_ATTESTATION_DIR" 0700
  POLYLANE_RUNNER_PID=$$
  POLYLANE_RUNNER_START_TOKEN=$("$POLYLANE_SKILL_STORE" process-token "$$")
  export POLYLANE_RUNNER_PID POLYLANE_RUNNER_START_TOKEN POLYLANE_RUNNER_GENERATION
  "$POLYLANE_SKILL_ADAPTER" inventory "$POLYLANE_SKILL_INVENTORY" \
    "$POLYLANE_SKILL_SNAPSHOTS"
  "$POLYLANE_SKILL_KIT" select "$MANIFEST" "$POLYLANE_SKILL_INVENTORY" \
    "$POLYLANE_SKILL_SNAPSHOTS" "$(cd "$SCRIPT_DIR/.." && pwd)" "$POLYLANE_SKILL_KIT_DIR"
  local i
  for i in "${!LANE_NAMES[@]}"; do
    # Generation zero is pre-launch only. The launch hook increments before every initial
    # launch and every respawn, so a crashed actor can never reuse immutable bound paths.
    POLYLANE_SKILL_GENERATIONS[i]=0
    POLYLANE_SKILL_ELIGIBLE[i]=0
    POLYLANE_SKILL_ORIGINAL_PROMPTS[i]=${LANE_PROMPTS[$i]}
    POLYLANE_SKILL_KITS[i]=""
    POLYLANE_SKILL_ATTESTATIONS[i]=""
  done
  POLYLANE_SKILLS_ACTIVE=1
}
polylane_skills_enqueue_suggestions() {
  [ "$POLYLANE_SKILLS_ACTIVE" = 1 ] || return 0
  # This local, network-free publisher starts only after launch_panes returns. It is never
  # awaited by the runner; the Runtime guardian waits for and claims the immutable input.
  ( "$POLYLANE_SKILL_SUGGEST" enqueue-index "$POLYLANE_SKILL_KIT_DIR/index.json" \
      "$POLYLANE_SKILL_ADAPTER" "$POLYLANE_SKILL_SUGGEST_INPUT" ||
      echo "polylane-skill-cycle: suggestion input unavailable; builders continue" >&2
  ) &
  POLYLANE_SKILL_ENQUEUE_PID=$!
}
polylane_skills_materialize() {
  [ "$POLYLANE_SKILLS_ACTIVE" = 1 ] || return 0
  local i name wt local_dir local_kit local_prompt exclude
  for i in "${!LANE_NAMES[@]}"; do
    name=${LANE_NAMES[$i]}; wt=${LANE_WORKTREES[$i]}
    local_dir=$wt/.polylane; local_kit=$local_dir/skill-kit.json
    local_prompt=$local_dir/builder.$POLYLANE_CLAIM_TOKEN.rg$POLYLANE_RUNNER_GENERATION.a$POLYLANE_ATTEMPT.prelaunch.prompt
    "$POLYLANE_SKILL_STORE" ensure-dir "$local_dir" 0700
    "$POLYLANE_SKILL_KIT" materialize "$POLYLANE_SKILL_KIT_DIR/$name.json" "$wt" "$local_kit"
    "$POLYLANE_SKILL_KIT" build-prompt "${POLYLANE_SKILL_ORIGINAL_PROMPTS[$i]}" \
      "$local_kit" "$local_prompt"
    "$POLYLANE_SKILL_KIT" lint-prompt "${POLYLANE_SKILL_ORIGINAL_PROMPTS[$i]}" \
      "$local_kit" "$local_prompt"
    [ "$(jq -r '.assignments|length' "$local_kit")" = 4 ] || \
      { polylane_skill_die "lane $name did not receive four skills"; return; }
    exclude=$(git -C "$wt" rev-parse --git-path info/exclude)
    grep -qxF '/.polylane/' "$exclude" 2>/dev/null || printf '%s\n' '/.polylane/' >>"$exclude"
    POLYLANE_SKILL_KITS[i]=$local_kit
    LANE_PROMPTS[i]=$local_prompt
  done
  "$POLYLANE_SKILL_KIT" index "$MANIFEST" "$POLYLANE_SKILL_INVENTORY" \
    "$POLYLANE_SKILL_KIT_DIR"
}
polylane_skill_prepare_launch() {
  local wt=$1 i generation base_prompt
  [ "$POLYLANE_SKILLS_ACTIVE" = 1 ] || return 0
  for i in "${!LANE_WORKTREES[@]}"; do
    if [ "${LANE_WORKTREES[$i]}" = "$wt" ]; then
      generation=$(( ${POLYLANE_SKILL_GENERATIONS[$i]:-0} + 1 ))
      base_prompt=$wt/.polylane/builder.$POLYLANE_CLAIM_TOKEN.rg$POLYLANE_RUNNER_GENERATION.a$POLYLANE_ATTEMPT.actor-g$generation.prompt
      "$POLYLANE_SKILL_KIT" build-prompt "${POLYLANE_SKILL_ORIGINAL_PROMPTS[$i]}" \
        "${POLYLANE_SKILL_KITS[$i]}" "$base_prompt" || return
      "$POLYLANE_SKILL_KIT" lint-prompt "${POLYLANE_SKILL_ORIGINAL_PROMPTS[$i]}" \
        "${POLYLANE_SKILL_KITS[$i]}" "$base_prompt" || return
      POLYLANE_SKILL_GENERATIONS[i]=$generation
      LANE_PROMPTS[i]=$base_prompt
      return
    fi
  done
}
polylane_skill_actor_prefix() {
  local wt=$1 i generation bound_kit bound_prompt
  [ "$POLYLANE_SKILLS_ACTIVE" = 1 ] || return 0
  for i in "${!LANE_WORKTREES[@]}"; do
    if [ "${LANE_WORKTREES[$i]}" = "$wt" ]; then
      generation=${POLYLANE_SKILL_GENERATIONS[$i]}
      [ "$generation" -ge 1 ] || { polylane_skill_die "actor generation is prelaunch"; return; }
      bound_kit=$wt/.polylane/skill-kit.actor-g$generation.json
      bound_prompt=$wt/.polylane/builder.$POLYLANE_CLAIM_TOKEN.rg$POLYLANE_RUNNER_GENERATION.a$POLYLANE_ATTEMPT.actor-g$generation.bound.prompt
      printf 'POLYLANE_ACTOR_LANE=%q POLYLANE_ACTOR_RUN_ID=%q POLYLANE_ACTOR_GENERATION=%q ' \
        "${LANE_NAMES[$i]}" "$RUN_ID" "$generation"
      printf 'POLYLANE_ACTOR_BASE_KIT=%q POLYLANE_ACTOR_BOUND_KIT=%q POLYLANE_ACTOR_BOUND_PROMPT=%q ' \
        "${POLYLANE_SKILL_KITS[$i]}" "$bound_kit" "$bound_prompt"
      return
    fi
  done
}
polylane_skill_qualify() {
  local wt=$1 name=$2 i result done verify actor attestation feedback generation pane
  local verification rejection next_generation bound_prompt bound_kit
  i=$(polylane_skill_lane_index "$name") || return 1
  [ "${POLYLANE_SKILL_ELIGIBLE[$i]}" = 1 ] && return 0
  result=$(agent_artifact_for_prompt "${LANE_PROMPTS[$i]}")
  [ -f "$result" ] && [ ! -L "$result" ] || return 1
  done=$wt/docs/status-$name.md; verify=$wt/docs/verify-$name.json
  generation=${POLYLANE_SKILL_GENERATIONS[$i]}
  bound_kit=$wt/.polylane/skill-kit.actor-g$generation.json
  bound_prompt=$wt/.polylane/builder.$POLYLANE_CLAIM_TOKEN.rg$POLYLANE_RUNNER_GENERATION.a$POLYLANE_ATTEMPT.actor-g$generation.bound.prompt
  actor=$POLYLANE_SKILL_ARTIFACT_DIR/$name.g$generation.actor.json
  attestation=$POLYLANE_SKILL_ATTESTATION_DIR/$name.g$generation.json
  verification=$POLYLANE_SKILL_ARTIFACT_DIR/$RUN_ID-$name-g$generation.json
  if "$POLYLANE_SKILL_KIT" lint-prompt "${POLYLANE_SKILL_ORIGINAL_PROMPTS[$i]}" \
      "$bound_kit" "$bound_prompt" && \
    "$POLYLANE_SKILL_KIT" actor-record "$result" "$name" "$RUN_ID" "$generation" "$actor" && \
    "$POLYLANE_SKILL_KIT" qualify "$MANIFEST" "$bound_kit" \
      "$bound_prompt" "$result" "$actor" "$done" "$verify" "$wt" \
      "$POLYLANE_SKILL_ARTIFACT_DIR" "$attestation" && \
    "$POLYLANE_SKILL_LEDGER" score "$attestation" "$bound_kit" \
      "$POLYLANE_SKILL_LEDGER_PATH"; then
    POLYLANE_SKILL_ELIGIBLE[i]=1
    POLYLANE_SKILL_ATTESTATIONS[i]=$attestation
    return 0
  fi
  rejection=$POLYLANE_SKILL_RUNTIME/skill-rejections/$RUN_ID/$name/actor-g$generation/$POLYLANE_SKILL_EVIDENCE_SCOPE/receipt.json
  "$POLYLANE_SKILL_KIT" reject "$result" "$bound_prompt" \
    "$bound_kit" "$done" "$verify" "$actor" "$verification" \
    "$attestation" "$name" "$RUN_ID" "$generation" qualification_failed "$rejection" || \
    { polylane_skill_die "could not preserve rejected generation $generation for $name"; return; }
  # The generation-scoped result, event stream, stderr, prompt capture, runner artifacts,
  # and rejection receipt are immutable. Only the two lane-local mutable signals are reset.
  rm -f "$done" "$verify"
  next_generation=$((generation + 1))
  feedback=$wt/.polylane/qualification-feedback.json
  "$POLYLANE_SKILL_KIT" failure-feedback "$name" "$next_generation" qualification_failed "$feedback"
  pane=$(pane_index_for "$name")
  [ "$pane" -ge 0 ] || { polylane_skill_die "no pane for failed qualification: $name"; return; }
  echo "qualification: lane '$name' evidence rejected; generation $next_generation is WORKING" >&2
  # respawn_lane advances actor generation directly before its pane_cmd_for command
  # substitution, so array state and new immutable base/bound paths survive in the runner.
  respawn_lane "$pane" "$name" "$wt"
  return 1
}
polylane_skill_lane_done() {
  local wt=$1 name=$2
  [ "$POLYLANE_SKILLS_ACTIVE" = 1 ] || return 0
  [ "$name" = "${INT_NAME:-}" ] && return 0
  polylane_skill_qualify "$wt" "$name"
}
```

- [ ] **Step 3: Bind structured Codex results to actor generation and prompt bytes**

Apply the exact patch in Step 3 below:

```diff
diff --git a/codex/scripts/polylane-codex-agent.sh b/codex/scripts/polylane-codex-agent.sh
--- a/codex/scripts/polylane-codex-agent.sh
+++ b/codex/scripts/polylane-codex-agent.sh
@@ -130,5 +130,36 @@
 polylane_codex_result_extension_json() {
-  # Builder replaces this hook with a validated object containing prompt/actor
-  # bindings. Foundation calls it for every normal and transport terminal result.
-  printf '{}\n'
+  local actor_pid=${POLYLANE_RESULT_ACTOR_PID:-null}
+  [[ "${POLYLANE_RESULT_PROMPT_SHA256:-}" =~ ^sha256:[0-9a-f]{64}$ ]] || return 7
+  case "$actor_pid" in null|[1-9][0-9]*) : ;; *) return 7 ;; esac
+  if [ "$actor_pid" = null ]; then
+    [ "${POLYLANE_RESULT_ACTOR_GENERATION:-null}" = null ] && \
+      [ -z "${POLYLANE_RESULT_ACTOR_START:-}" ] && \
+      [ -z "${POLYLANE_RESULT_ACTOR_LANE:-}" ] && \
+      [ -z "${POLYLANE_RESULT_ACTOR_RUN_ID:-}" ] || return 7
+  else
+    [[ "${POLYLANE_RESULT_KIT_SHA256:-}" =~ ^sha256:[0-9a-f]{64}$ ]] && \
+      [[ "${POLYLANE_CLAIM_TOKEN:-}" =~ ^[A-Za-z0-9_-][A-Za-z0-9._-]*$ ]] && \
+      [[ "${POLYLANE_RUNNER_GENERATION:-}" =~ ^[1-9][0-9]*$ ]] && \
+      [[ "${POLYLANE_ATTEMPT:-}" =~ ^[1-9][0-9]*$ ]] || return 7
+    [ -n "${POLYLANE_RESULT_ACTOR_START:-}" ] && \
+      [[ "${POLYLANE_RESULT_ACTOR_GENERATION:-}" =~ ^[1-9][0-9]*$ ]] && \
+      [[ "${POLYLANE_RESULT_ACTOR_LANE:-}" =~ ^[A-Za-z0-9._-]+$ ]] && \
+      [[ "${POLYLANE_RESULT_ACTOR_RUN_ID:-}" =~ ^[A-Za-z0-9._-]+$ ]] || return 7
+  fi
+  jq -cnS --arg prompt_sha256 "$POLYLANE_RESULT_PROMPT_SHA256" \
+    --arg kit_sha256 "${POLYLANE_RESULT_KIT_SHA256:-}" \
+    --arg runner_claim "${POLYLANE_CLAIM_TOKEN:-}" \
+    --argjson runner_generation "${POLYLANE_RUNNER_GENERATION:-null}" \
+    --argjson runner_attempt "${POLYLANE_ATTEMPT:-null}" \
+    --arg actor_start "${POLYLANE_RESULT_ACTOR_START:-}" \
+    --arg actor_lane "${POLYLANE_RESULT_ACTOR_LANE:-}" \
+    --arg actor_run "${POLYLANE_RESULT_ACTOR_RUN_ID:-}" \
+    --argjson actor_pid "$actor_pid" \
+    --argjson actor_generation "${POLYLANE_RESULT_ACTOR_GENERATION:-null}" \
+    '{prompt_sha256:$prompt_sha256} |
+      if $actor_pid==null then . else . + {kit_sha256:$kit_sha256,
+        runner:{claim:$runner_claim,generation:$runner_generation,attempt:$runner_attempt},
+        actor_generation:$actor_generation,
+        actor:{pid:$actor_pid,start_token:$actor_start,generation:$actor_generation,
+          lane:$actor_lane,run_id:$actor_run}} end'
 }
diff --git a/codex/scripts/polylane-codex-exec.sh b/codex/scripts/polylane-codex-exec.sh
--- a/codex/scripts/polylane-codex-exec.sh
+++ b/codex/scripts/polylane-codex-exec.sh
@@ -9,3 +9,24 @@
 codex_exe=$1; model=$2; effort=$3; prompt=$4; artifact=$5
+actor_lane=${POLYLANE_ACTOR_LANE:-}; actor_run=${POLYLANE_ACTOR_RUN_ID:-}
+actor_generation=${POLYLANE_ACTOR_GENERATION:-}; actor_pid=""; actor_start=""
+if [ -n "$actor_lane$actor_run$actor_generation" ]; then
+  [ -n "$actor_lane" ] && [ -n "$actor_run" ] && \
+    [[ "$actor_generation" =~ ^[1-9][0-9]*$ ]] && \
+    [[ "$actor_lane" =~ ^[A-Za-z0-9._-]+$ ]] && [[ "$actor_run" =~ ^[A-Za-z0-9._-]+$ ]] || \
+    { echo "polylane-codex-exec: incomplete actor identity" >&2; exit 2; }
+  store="$SCRIPT_DIR/polylane-skill-store.sh"
+  [ -x "$store" ] || { echo "polylane-codex-exec: installed skill store unavailable" >&2; exit 2; }
+  actor_pid=$$
+  actor_start=$("$store" process-token "$$")
+  kit_helper="$SCRIPT_DIR/polylane-skill-kit.sh"
+  [ -x "$kit_helper" ] && [ -n "${POLYLANE_ACTOR_BASE_KIT:-}" ] && \
+    [ -n "${POLYLANE_ACTOR_BOUND_KIT:-}" ] && [ -n "${POLYLANE_ACTOR_BOUND_PROMPT:-}" ] || \
+    { echo "polylane-codex-exec: actor binding helper unavailable" >&2; exit 2; }
+  POLYLANE_RESULT_KIT_SHA256=$(POLYLANE_ACTOR_PID=$actor_pid \
+    POLYLANE_ACTOR_START_TOKEN=$actor_start "$kit_helper" bind-actor \
+    "$POLYLANE_ACTOR_BASE_KIT" "$prompt" "$POLYLANE_ACTOR_BOUND_KIT" \
+    "$POLYLANE_ACTOR_BOUND_PROMPT") || exit 2
+  prompt=$POLYLANE_ACTOR_BOUND_PROMPT
+fi
 [ -x "$codex_exe" ] && [ -f "$codex_exe" ] && [ ! -L "$codex_exe" ] || exit 2
 exe_dir=${codex_exe%/*}; exe_base=${codex_exe##*/}
@@ -47,22 +68,41 @@
 events="$artifact.events.jsonl"; stderr_file="$artifact.stderr"
 result_private="$artifact.private.$$"
 prompt_snapshot="$artifact.prompt.$$"
+prompt_capture="$artifact.prompt"
 artifact_dir=${artifact%/*}; [ "$artifact_dir" != "$artifact" ] || artifact_dir=.
 polylane_codex_safe_mkdirs "$artifact_dir" 0700
 [ -d "$artifact_dir" ] && [ ! -L "$artifact_dir" ] || \
   { echo "polylane-codex-exec: unsafe artifact directory" >&2; exit 2; }
 [ -f "$prompt" ] && [ ! -L "$prompt" ] || \
   { echo "polylane-codex-exec: unsafe prompt path" >&2; exit 2; }
-for path in "$artifact" "$events" "$stderr_file" "$result_private" "$prompt_snapshot"; do
+for path in "$artifact" "$events" "$stderr_file" "$result_private" \
+  "$prompt_snapshot" "$prompt_capture"; do
   [ ! -e "$path" ] && [ ! -L "$path" ] || \
     { echo "polylane-codex-exec: artifact path already exists" >&2; exit 2; }
 done
 inode_of() { case "$(uname -s)" in Linux) stat -c '%i' "$1" ;; *) stat -f '%i' "$1" ;; esac; }
 polylane_codex_fs copy-exclusive "$prompt" "$prompt_snapshot" 0400 || exit 2
+# Publish only the complete hardened snapshot. The exclusive publisher unlinks its private
+# source and refuses an existing public capture, so no incomplete or replaced path is visible.
+polylane_codex_publish "$prompt_snapshot" "$prompt_capture" || exit 74
 prompt_snapshot_created=1
-exec 5< "$prompt_snapshot"
-[ -f "$prompt_snapshot" ] && [ ! -L "$prompt_snapshot" ] && \
-  [ "$(inode_of "$prompt_snapshot")" = "$(inode_of /dev/fd/5)" ] || exit 2
+exec 5< "$prompt_capture"
+[ -f "$prompt_capture" ] && [ ! -L "$prompt_capture" ] && \
+  [ "$(inode_of "$prompt_capture")" = "$(inode_of /dev/fd/5)" ] || exit 2
+prompt_hash="sha256:$(polylane_codex_sha256 "$prompt_capture")"
+POLYLANE_RESULT_PROMPT_SHA256=$prompt_hash
+POLYLANE_RESULT_ACTOR_PID=null; POLYLANE_RESULT_ACTOR_GENERATION=null
+POLYLANE_RESULT_ACTOR_START=""; POLYLANE_RESULT_ACTOR_LANE=""; POLYLANE_RESULT_ACTOR_RUN_ID=""
+if [ -n "$actor_pid" ]; then
+  POLYLANE_RESULT_ACTOR_PID=$actor_pid
+  POLYLANE_RESULT_ACTOR_GENERATION=$actor_generation
+  POLYLANE_RESULT_ACTOR_START=$actor_start
+  POLYLANE_RESULT_ACTOR_LANE=$actor_lane
+  POLYLANE_RESULT_ACTOR_RUN_ID=$actor_run
+fi
+export POLYLANE_RESULT_PROMPT_SHA256 POLYLANE_RESULT_ACTOR_PID \
+  POLYLANE_RESULT_KIT_SHA256 POLYLANE_RESULT_ACTOR_GENERATION POLYLANE_RESULT_ACTOR_START \
+  POLYLANE_RESULT_ACTOR_LANE POLYLANE_RESULT_ACTOR_RUN_ID
 out_fifo="$artifact.stdout-fifo.$$"; err_fifo="$artifact.stderr-fifo.$$"
 out_fifo_created=0; err_fifo_created=0
 capture_cleanup() {
diff --git a/codex/tests/test-codex-errors.sh b/codex/tests/test-codex-errors.sh
--- a/codex/tests/test-codex-errors.sh
+++ b/codex/tests/test-codex-errors.sh
@@ -4,5 +4,7 @@
 . "$ROOT/core/tests/helpers.sh"
 . "$ROOT/core/scripts/polylane-agent.sh"
 . "$ROOT/codex/scripts/polylane-codex-agent.sh"
 make_tmpdir
+export POLYLANE_RESULT_PROMPT_SHA256=sha256:0000000000000000000000000000000000000000000000000000000000000000
+export POLYLANE_RESULT_ACTOR_PID=null POLYLANE_RESULT_ACTOR_GENERATION=null
 write_events() {
@@ -82,6 +84,8 @@
   "$(jq -r .events_hash "$TEST_TMPDIR/success.json")"
 assert_eq "artifact-binds-stderr-hash" "$success_stderr_hash" \
   "$(jq -r .stderr_hash "$TEST_TMPDIR/success.json")"
+assert_eq "artifact-binds-prompt-before-publication" "$POLYLANE_RESULT_PROMPT_SHA256" \
+  "$(jq -r .prompt_sha256 "$TEST_TMPDIR/success.json")"
 write_events integrity '{"status":503,"error":{"type":"server_error","code":"service_unavailable"}}'
 : > "$TEST_TMPDIR/integrity.stderr"
 assert_ok "integrity-capture" polylane_adapter_capture_error \
```

The wrapper PID/start-token is captured while that process is live. Foundation's normal and
transport builders both validate and merge the actor/prompt extension into the complete
private result before their shared exclusive result publisher runs. Prompt capture has its
own exclusive hard-link publication. No incomplete public pathname is visible, and no
published prompt or result is replaced, deleted, or reused.

Create `core/tests/test-builder-foundation-dry-apply.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
BASE=$TEST_TMPDIR/foundation; PATCHED=$TEST_TMPDIR/patched; PATCH_FILE=$TEST_TMPDIR/builder.diff
mkdir -p "$BASE/codex/scripts" "$BASE/codex/tests" "$PATCHED"
python3 - "$ROOT/docs/superpowers/plans/2026-07-16-codex-package-foundation.md" \
  "$ROOT/docs/superpowers/plans/2026-07-16-codex-builder-skill-kits.md" "$BASE" "$PATCH_FILE" <<'PY'
import pathlib,re,sys
foundation=pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
builder=pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
root=pathlib.Path(sys.argv[3]); patch=pathlib.Path(sys.argv[4])
labels={
 "codex/scripts/polylane-codex-agent.sh":"Create `codex/scripts/polylane-codex-agent.sh`:",
 "codex/scripts/polylane-codex-exec.sh":"Create executable `codex/scripts/polylane-codex-exec.sh`:",
 "codex/tests/test-codex-errors.sh":"Create `codex/tests/test-codex-errors.sh`:"}
for relative,label in labels.items():
    match=re.search(re.escape(label)+r"\n\n```bash\n(.*?)\n```",foundation,re.S)
    if not match: raise SystemExit(f"Foundation body missing: {label}")
    target=root/relative; target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(match.group(1)+"\n",encoding="utf-8")
start=builder.index("Apply the exact patch in Step 3 below:")
match=re.search(r"```diff\n(.*?)\n```",builder[start:],re.S)
if not match: raise SystemExit("Builder Step 3 diff missing")
patch.write_text(match.group(1)+"\n",encoding="utf-8")
PY
cp -R "$BASE/." "$PATCHED/"
assert_ok "builder-diff-dry-applies-to-final-foundation" \
  bash -c 'cd "$1" && git apply --check "$2"' _ "$BASE" "$PATCH_FILE"
assert_ok "builder-diff-applies-to-final-foundation" \
  bash -c 'cd "$1" && git apply "$2"' _ "$PATCHED" "$PATCH_FILE"
assert_ok "patched-complete-bodies-parse" bash -n \
  "$PATCHED/codex/scripts/polylane-codex-agent.sh" \
  "$PATCHED/codex/scripts/polylane-codex-exec.sh" \
  "$PATCHED/codex/tests/test-codex-errors.sh"
EXEC=$(cat "$PATCHED/codex/scripts/polylane-codex-exec.sh")
AGENT=$(cat "$PATCHED/codex/scripts/polylane-codex-agent.sh")
assert_contains "five-argument-abi" 'CODEX_EXE MODEL EFFORT PROMPT ERROR_ARTIFACT' "$EXEC"
assert_contains "exact-executable-used" '"$codex_exe" exec --json' "$EXEC"
assert_contains "bounded-fifo-capture-preserved" 'out_fifo="$artifact.stdout-fifo.$$"' "$EXEC"
assert_contains "event-cap-preserved" 'event_cap=${POLYLANE_CODEX_MAX_EVENT_BYTES:-16777216}' "$EXEC"
assert_contains "parser-timeout-preserved" 'parser_timeout=${POLYLANE_CODEX_PARSER_TIMEOUT:-10}' "$EXEC"
assert_contains "capture-limit-artifact-preserved" 'publish_transport capture_limit || exit 74' "$EXEC"
assert_contains "transport-failure-path-preserved" polylane_codex_build_transport_result "$EXEC"
assert_contains "normal-result-path-preserved" polylane_codex_build_normal_result "$EXEC"
assert_contains "shared-result-publisher-preserved" polylane_codex_publish_result "$EXEC"
assert_contains "prompt-private-before-exclusive-publication" \
  'polylane_codex_publish "$prompt_snapshot" "$prompt_capture"' "$EXEC"
assert_contains "hardened-prompt-copy-preserved" \
  'polylane_codex_fs copy-exclusive "$prompt" "$prompt_snapshot" 0400' "$EXEC"
assert_contains "live-actor-binds-worker-kit-and-prompt" '"$kit_helper" bind-actor' "$EXEC"
assert_contains "result-binds-live-kit-hash" 'POLYLANE_RESULT_KIT_SHA256' "$EXEC$AGENT"
assert_contains "result-binds-runner-scope" 'runner:{claim:$runner_claim' "$AGENT"
assert_contains "result-exclusive-publication-still-used" \
  'polylane_codex_publish "$private" "$artifact"' "$AGENT"
assert_contains "prompt-bound-before-publication" 'prompt_sha256:$prompt_sha256' "$AGENT"
assert_eq "extension-called-for-normal-and-transport" 2 \
  "$(printf '%s' "$AGENT" | grep -Fc 'extension=$(polylane_codex_result_extension_json)')"
assert_not_contains "visible-result-never-deleted" 'rm -f "$artifact"' "$EXEC$AGENT"
finish
```

This is a cross-plan drift gate: it extracts Foundation's current complete bodies, dry-applies
the exact Builder patch, parses the patched full bodies, and proves the 5-argument executable
binding, both terminal builders, exclusive publications, and every bounded-capture path
survived.

After the Foundation commit is frozen, write its full 40-hex commit id plus LF to
`core/tests/fixtures/builder-foundation-base.commit`. Create
`core/tests/test-builder-foundation-sequential-apply.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
BASE_COMMIT=$(tr -d '\n' <"$ROOT/core/tests/fixtures/builder-foundation-base.commit")
case "$BASE_COMMIT" in *[!0-9a-f]*|'') fail "invalid frozen Foundation commit" ;; esac
[ "${#BASE_COMMIT}" -eq 40 ] || fail "invalid frozen Foundation commit length"
git -C "$ROOT" cat-file -e "$BASE_COMMIT^{commit}"
FROZEN=$TEST_TMPDIR/foundation-final; PATCHES=$TEST_TMPDIR/patches
mkdir -p "$FROZEN" "$PATCHES"
git -C "$ROOT" archive "$BASE_COMMIT" | tar -x -C "$FROZEN"
python3 - "$ROOT/docs/superpowers/plans/2026-07-16-codex-builder-skill-kits.md" \
  "$PATCHES" <<'PY'
import pathlib,re,sys
text=pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
patches=re.findall(r"```diff\n(.*?)\n```",text,re.S)
if not patches: raise SystemExit("Builder patches missing")
for number,body in enumerate(patches,1):
    if re.search(r"(?m)^@@$",body): raise SystemExit(f"bare hunk header in patch {number}")
    (pathlib.Path(sys.argv[2])/f"{number:02}.diff").write_text(body+"\n",encoding="utf-8")
PY
for patch in "$PATCHES"/*.diff; do
  (cd "$FROZEN" && git apply --recount --check "$patch")
  (cd "$FROZEN" && git apply --recount "$patch")
done
find "$FROZEN/core/scripts" "$FROZEN/codex/scripts" "$FROZEN/claude-code/scripts" \
  "$FROZEN/core/tests" "$FROZEN/codex/tests" -type f -name '*.sh' -print0 | \
  xargs -0 bash -n
find "$FROZEN/core/scripts" "$FROZEN/codex/scripts" "$FROZEN/claude-code/scripts" \
  "$FROZEN/core/tests" "$FROZEN/codex/tests" -type f -name '*.sh' -print0 | \
  xargs -0 shellcheck -s bash -S error
jq -e . "$FROZEN/codex/package.json" "$FROZEN/claude-code/package.json" >/dev/null
finish
```

This gate applies every Builder unified diff in document order to one immutable Foundation
tree. `--recount` tolerates only line-number drift; missing context, reordered dependencies,
or a semantic collision still fails. No Step 4/5 hunk has a bare `@@` header.

- [ ] **Step 4: Wire the runner before launch and inside DONE eligibility**

Apply the exact patch in Step 4 below:

```diff
diff --git a/core/scripts/polylane-run.sh b/core/scripts/polylane-run.sh
--- a/core/scripts/polylane-run.sh
+++ b/core/scripts/polylane-run.sh
@@ -1,3 +1,3 @@
-  for d in tmux jq git; do
+  for d in tmux jq git python3; do
     command -v "$d" >/dev/null 2>&1 || missing+=("$d")
   done
@@ -1,2 +1,4 @@
  . "$POLYLANE_AGENT_ADAPTER"
 fi
+# shellcheck disable=SC1091
+. "$SCRIPT_DIR/polylane-skill-cycle.sh"
@@ -1,2 +1,2 @@
 pane_cmd() {
-  local wt="$1" model="$2" pf="$3" effort="${4:-}" pfx=""
+  local wt="$1" model="$2" pf="$3" effort="${4:-}" pfx
@@ -1,1 +1,2 @@
-  [ -n "$effort" ] && pfx="POLYLANE_EFFORT=$qeffort "
+  pfx=$(polylane_skill_actor_prefix "$wt")
+  [ -n "$effort" ] && pfx="${pfx}POLYLANE_EFFORT=$qeffort "
@@ -1,2 +1,3 @@
     echo "lane ${LANE_NAMES[$i]}: model=${LANE_MODELS[$i]} effort=${LANE_EFFORTS[$i]:-(default)}"
+    polylane_skill_prepare_launch "${LANE_WORKTREES[$i]}" || return
     pc=$(pane_cmd "${LANE_WORKTREES[$i]}" "${LANE_MODELS[$i]}" "${LANE_PROMPTS[$i]}" "${LANE_EFFORTS[$i]:-}")
@@ -1,2 +1,3 @@
   wedge_hash_set "$name" ""; wedge_cnt_set "$name" 0
+  polylane_skill_prepare_launch "$wt" || return
   cmd=$(pane_cmd_for "$name")
@@ -1,6 +1,9 @@
  if [ -n "${RUN_ID:-}" ]; then
-    [ "$first" = "STATUS: $name DONE run=$RUN_ID" ]   # nonce mode: only THIS run's marker
+    [ "$first" = "STATUS: $name DONE run=$RUN_ID" ] || return 1
   else
-    [ "$first" = "STATUS: $name DONE" ]               # legacy: unchanged frozen contract
+    [ "$first" = "STATUS: $name DONE" ] || return 1
   fi
+  # Integrator keeps the exact raw-marker contract. A Codex Builder remains WORKING
+  # until the runner—not worker prose—authors and scores all structured evidence.
+  polylane_skill_lane_done "$wt" "$name"
 }
@@ -1,3 +1,5 @@
   load_manifest
   apply_overrides   # --intensity / --model remap BEFORE any worktree/pane exists
-  mark_resumed      # --resume: flag already-DONE lanes BEFORE split/launch
+  # Inventory, immutable source snapshots, and deterministic selection happen before any
+  # git worktree or tmux side effect. Informational suggestion input is off the launch path.
+  polylane_skills_prepare
@@ -1,2 +1,6 @@
   echo "== split: ${#LANE_NAMES[@]} lane worktrees =="
   split_worktrees
+  # Every selected full tree is copied under its Builder worktree and the exact
+  # length-framed prompt is linted before resume eligibility or launch.
+  polylane_skills_materialize
+  mark_resumed
@@ -1,1 +1,3 @@
  launch_panes
+  # Network-free and unawaited. Runtime guardian owns every later GitHub child.
+  polylane_skills_enqueue_suggestions
```

Also add `polylane-skill-cycle.sh` to the Foundation package's recursive script inventory
test. Do not add an assemble hook, staging directory, `CODEX_DEST`, source-tree fallback, or
integrator-specific branch: Foundation's recursive package map ships this sibling unchanged.

- [ ] **Step 5: Freeze workflow/schema ownership and extend package parity**

Apply the exact patches in Step 5 below:

```diff
diff --git a/core/workflow/polylane-loop.md b/core/workflow/polylane-loop.md
--- a/core/workflow/polylane-loop.md
+++ b/core/workflow/polylane-loop.md
@@ -1,9 +1,30 @@
-2. Derive file-isolated builder lanes and one integrator. Run scope and seam gates before
-   creating worktrees.
-3. Render prompts through the selected adapter. Each prompt includes the locked goal,
+2. The proposal and controller describe each lane's `activities`, `ownership_globs`, and
+   one absolute `verification_argv`. They never name, select, rank, or install skills.
+3. The Builder skill scout is the sole skill chooser. Before worktree/tmux side effects it
+   inventories complete immutable installed/bundled trees and assigns exactly four skills
+   to each Builder: test-driven development, verification-before-completion, one distinct
+   domain implementation skill, and one distinct domain verification skill. Unknown-domain
+   fallback is exactly `unknown-implementation` plus `unknown-verification`.
+4. External GitHub suggestions are informational only. The runner writes an immutable
+   suggestion input and continues; only the Runtime guardian may execute a GET-only job.
+   A hung, unavailable, no-match, or missing-helper result cannot change the four-skill kit,
+   concurrency, lane scope, launch, DONE eligibility, or cycle state.
+5. Derive file-isolated builder lanes and one integrator. Run scope and seam gates before
+   creating worktrees. Copy all four complete selected trees under the Builder worktree and
+   length-frame their exact metadata/body bytes; relative references and scripts remain usable.
+6. Render prompts through the selected adapter. Each prompt includes the locked goal,
    `OWN` and `FORBIDDEN` boundaries, frozen checks, verification evidence path, and the
-   exact run nonce.
-4. Launch through the adapter loop launcher and watch the adapter-owned session.
-5. Accept a builder marker only when its lane name and `run=<run nonce>` match.
-6. Accept an integrator verdict only when its run nonce matches and all frozen checks have
+   exact run nonce. A Builder also reads `.polylane/qualification-feedback.json` when present.
+7. Launch through the adapter loop launcher and watch the adapter-owned session.
+8. A Builder writes canonical `docs/verify-<lane>.json` with exactly
+   `{"lane":"<lane>","run_id":"<nonce>","schema_version":1}` before its exact raw
+   status marker. Raw prose, marker text, and worker-authored claims are never attestation.
+9. Accept a Builder only after the runner binds the live actor generation, structured result,
+   launched prompt digest, all four local tree digests, DONE/verify bytes, and a fresh direct
+   execution of the manifest argv into an immutable attestation and segmented score ledger.
+   Rejection snapshots and preserves the complete generation under an immutable attempt
+   namespace with a runner-authored receipt, clears only the lane-local mutable marker/verify
+   files, increments actor generation, and leaves the lane WORKING.
+10. The integrator receives its original prompt byte-for-byte, receives no skill kit, and keeps
+   the exact raw-marker contract. Accept its verdict only when its run nonce matches and checks have
    evidence. Stale markers and stale verdicts are ignored.
```

Apply this schema hunk; use these names globally in Builder, Foundation, and Persistent plans:

```diff
diff --git a/.polylane/SCHEMA.md b/.polylane/SCHEMA.md
--- a/.polylane/SCHEMA.md
+++ b/.polylane/SCHEMA.md
@@ -1,3 +1,6 @@
       "prompt_file": ".polylane/prompts/api.txt",
-      "own_globs": ["backend/api/**"],
+      "role": "builder",
+      "activities": ["implement REST API route"],
+      "ownership_globs": ["backend/api/**"],
+      "verification_argv": ["/usr/bin/test", "-f", "api-output.txt"],
       "effort": "high"
@@ -1,1 +1,5 @@
-| `own_globs` | string[] | *(lanes only)* Files the lane owns. Informational — the engine does not enforce it. |
+| `role` | string | Exactly `builder` for parallel lanes and `integrator` for the integrator. |
+| `activities` | string[] | Declarative work/activity phrases used by the Builder scout as relevance evidence. |
+| `ownership_globs` | string[] | Declarative owned paths used by scope/seam gates and domain inference. |
+| `own_globs` | string[] | Deprecated compatibility alias; rejected when `ownership_globs` is also present. |
+| `verification_argv` | string[] | Nonempty argv array for fresh verification. Element zero is an absolute executable; no shell is used. |
```

The schema has no `selected_skills`, `skills`, `skill_ids`, or proposal-owned kit field.
`ownership_globs` is canonical, but the compatibility reader accepts legacy `own_globs` only
when the canonical field is absent. Patch every inherited consumer and Foundation's canary in
the same commit:

```diff
diff --git a/core/scripts/polylane-scope.sh b/core/scripts/polylane-scope.sh
--- a/core/scripts/polylane-scope.sh
+++ b/core/scripts/polylane-scope.sh
@@ -1,1 +1,1 @@
-_lane_globs() { jq -r --arg n "$2" '.lanes[] | select(.name==$n) | .own_globs[]?' "$1"; }
+_lane_globs() { jq -r --arg n "$2" '.lanes[] | select(.name==$n) | (.ownership_globs // .own_globs // [])[]' "$1"; }
diff --git a/core/scripts/polylane-outcomes.sh b/core/scripts/polylane-outcomes.sh
--- a/core/scripts/polylane-outcomes.sh
+++ b/core/scripts/polylane-outcomes.sh
@@ -1,1 +1,1 @@
-    globs=$(jq -r --arg n "$lane" '.lanes[]|select(.name==$n)|.own_globs[]?' "$mf")
+    globs=$(jq -r --arg n "$lane" '.lanes[]|select(.name==$n)|(.ownership_globs // .own_globs // [])[]' "$mf")
diff --git a/core/tests/test-workflow-contract.sh b/core/tests/test-workflow-contract.sh
--- a/core/tests/test-workflow-contract.sh
+++ b/core/tests/test-workflow-contract.sh
@@ -1,2 +1,10 @@
 ROOT=$(cd "$(dirname "$0")/../.." && pwd)
+make_tmpdir
+CANONICAL=$TEST_TMPDIR/canonical.json; LEGACY=$TEST_TMPDIR/legacy.json
+printf '%s\n' '{"lanes":[{"name":"api","ownership_globs":["api/**"]}]}' >"$CANONICAL"
+printf '%s\n' '{"lanes":[{"name":"api","own_globs":["api/**"]}]}' >"$LEGACY"
+assert_ok "canonical-ownership-scope" "$ROOT/core/scripts/polylane-scope.sh" \
+  check-static "$CANONICAL"
+assert_ok "legacy-ownership-scope" "$ROOT/core/scripts/polylane-scope.sh" \
+  check-static "$LEGACY"
 FLOW=$(cat "$ROOT/core/workflow/polylane-loop.md" 2>/dev/null || true)
diff --git a/codex/scripts/polylane-codex-rehearse.sh b/codex/scripts/polylane-codex-rehearse.sh
--- a/codex/scripts/polylane-codex-rehearse.sh
+++ b/codex/scripts/polylane-codex-rehearse.sh
@@ -1,3 +1,5 @@
-GOAL: prove one Codex builder cycle. OWN: built.txt docs/status-builder.md.
+GOAL: prove one Codex builder cycle. OWN: built.txt docs/status-builder.md docs/verify-builder.json.
 FORBIDDEN: every other path. Create built.txt, verify it, commit it, then run:
+Write canonical {"lane":"builder","run_id":"$rid","schema_version":1} to
+docs/verify-builder.json before the DONE marker.
 $CORE/polylane-markers.sh done builder $rid > docs/status-builder.md
@@ -1,1 +1,1 @@
- "lanes":[{"name":"builder","model":"$model","effort":"$effort","branch":"lane/builder","worktree":"$root/wt-builder","prompt_file":"$root/.polylane/lanes/builder.txt","own_globs":["built.txt"]}],
+ "lanes":[{"name":"builder","role":"builder","activities":["implement and verify fixture output"],"model":"$model","effort":"$effort","branch":"lane/builder","worktree":"$root/wt-builder","prompt_file":"$root/.polylane/lanes/builder.txt","ownership_globs":["built.txt","docs/status-builder.md","docs/verify-builder.json"],"verification_argv":["/usr/bin/test","-f","built.txt"]}],
@@ -1,1 +1,1 @@
- "integrator":{"name":"integrator","model":"$model","effort":"$effort","branch":"lane/integrator","worktree":"$root/wt-integrator","prompt_file":"$root/.polylane/lanes/integrator.txt"}}
+ "integrator":{"name":"integrator","role":"integrator","activities":["merge and verify builder output"],"model":"$model","effort":"$effort","branch":"lane/integrator","worktree":"$root/wt-integrator","prompt_file":"$root/.polylane/lanes/integrator.txt","ownership_globs":["docs/status-integrator.md","docs/verify-integration.md"],"verification_argv":["/usr/bin/test","-f","built.txt"]}}
diff --git a/codex/tests/test-codex-rehearse.sh b/codex/tests/test-codex-rehearse.sh
--- a/codex/tests/test-codex-rehearse.sh
+++ b/codex/tests/test-codex-rehearse.sh
@@ -1,3 +1,5 @@
   *builder*)
     printf 'built\n' > built.txt; git add built.txt; git commit -qm builder
+    jq -cnS --arg lane builder --arg run_id "$CANARY_RUN_ID" \
+      '{lane:$lane,run_id:$run_id,schema_version:1}' > docs/verify-builder.json
     { "$POLYLANE_MARKERS" done builder "$CANARY_RUN_ID"; echo; } > docs/status-builder.md
```

Extend the workflow/schema contract test with one canonical manifest and one legacy-alias
manifest. Both must pass scope checks; a manifest containing both ownership fields must fail
before inventory, worktree, or tmux creation. The installed Codex rehearsal must complete with
the canonical fields above.

Make Python an explicit installed runtime dependency rather than an accidental transitive
dependency:

```diff
diff --git a/core/scripts/polylane-doctor.sh b/core/scripts/polylane-doctor.sh
--- a/core/scripts/polylane-doctor.sh
+++ b/core/scripts/polylane-doctor.sh
@@ -1,1 +1,1 @@
-  for d in tmux jq git; do
+  for d in tmux jq git python3; do
@@ -1,1 +1,2 @@
         git)    hint="xcode-select --install" ;;
+        python3) hint="install Python 3.9 or newer" ;;
diff --git a/codex/scripts/polylane-codex.sh b/codex/scripts/polylane-codex.sh
--- a/codex/scripts/polylane-codex.sh
+++ b/codex/scripts/polylane-codex.sh
@@ -1,1 +1,1 @@
-for dep in tmux jq git; do command -v "$dep" >/dev/null 2>&1 || {
+for dep in tmux jq git python3; do command -v "$dep" >/dev/null 2>&1 || {
diff --git a/claude-code/scripts/polylane-claude.sh b/claude-code/scripts/polylane-claude.sh
--- a/claude-code/scripts/polylane-claude.sh
+++ b/claude-code/scripts/polylane-claude.sh
@@ -1,1 +1,1 @@
-for dep in tmux jq git; do command -v "$dep" >/dev/null 2>&1 || {
+for dep in tmux jq git python3; do command -v "$dep" >/dev/null 2>&1 || {
diff --git a/codex/install.sh b/codex/install.sh
--- a/codex/install.sh
+++ b/codex/install.sh
@@ -1,2 +1,5 @@
 if [ "$print" = 1 ]; then user_dest; exit 0; fi
+command -v python3 >/dev/null 2>&1 || {
+  echo "codex/install.sh: missing dependency: python3" >&2; exit 1;
+}
 if [ -z "$dest" ]; then
diff --git a/claude-code/install.sh b/claude-code/install.sh
--- a/claude-code/install.sh
+++ b/claude-code/install.sh
@@ -1,2 +1,5 @@
 if [ "$print" = 1 ]; then user_dest; exit 0; fi
+command -v python3 >/dev/null 2>&1 || {
+  echo "claude-code/install.sh: missing dependency: python3" >&2; exit 1;
+}
 if [ -z "$dest" ]; then
diff --git a/codex/package.json b/codex/package.json
--- a/codex/package.json
+++ b/codex/package.json
@@ -1,1 +1,2 @@
-  "metadata": [{"source":"agents/openai.yaml","target":"agents/openai.yaml"}]
+  "metadata": [{"source":"agents/openai.yaml","target":"agents/openai.yaml"}],
+  "runtime_commands": ["tmux", "jq", "git", "python3"]
diff --git a/claude-code/package.json b/claude-code/package.json
--- a/claude-code/package.json
+++ b/claude-code/package.json
@@ -1,1 +1,2 @@
-  "metadata": []
+  "metadata": [],
+  "runtime_commands": ["tmux", "jq", "git", "python3"]
diff --git a/core/scripts/polylane-package.sh b/core/scripts/polylane-package.sh
--- a/core/scripts/polylane-package.sh
+++ b/core/scripts/polylane-package.sh
@@ -1,2 +1,3 @@
-    (.policy_hook|type=="string" and length>0) and (.metadata|type=="array")' \
+    (.policy_hook|type=="string" and length>0) and (.metadata|type=="array") and
+    .runtime_commands==["tmux","jq","git","python3"]' \
     "$descriptor" >/dev/null || die 6 "invalid adapter descriptor"
```

Both installed descriptors and the package assembler now freeze the same runtime contract.

Insert this exact block in `core/tests/test-package-parity.sh` immediately after the two
initial whole-package verifications and before Foundation's later intentional `C` tamper:

```bash
assert_ok "codex-runtime-contract" jq -e \
  '.runtime_commands==["tmux","jq","git","python3"]' "$C/adapter/package.json"
assert_ok "claude-runtime-contract" jq -e \
  '.runtime_commands==["tmux","jq","git","python3"]' "$H/adapter/package.json"
assert_eq "codex-fallback-count" 14 \
  "$(find -L "$C/bundled-skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')"
assert_eq "claude-fallback-count" 14 \
  "$(find -L "$H/bundled-skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')"
assert_eq "codex-nested-resource-count" 14 \
  "$(find -L "$C/bundled-skills" -path '*/references/contract.md' -type f | wc -l | tr -d ' ')"
assert_eq "claude-nested-resource-count" 14 \
  "$(find -L "$H/bundled-skills" -path '*/references/contract.md' -type f | wc -l | tr -d ' ')"
while IFS= read -r rel; do
  assert_eq "fallback-parity-$rel" "$(git hash-object "$C/$rel")" "$(git hash-object "$H/$rel")"
done < <(cd "$C" && find bundled-skills -type f | LC_ALL=C sort)

C_RELEASE=$(cd "$C" && pwd -P); H_RELEASE=$(cd "$H" && pwd -P)
BODY=$C_RELEASE/bundled-skills/unknown-implementation/SKILL.md
RESOURCE=$C_RELEASE/bundled-skills/unknown-verification/references/contract.md
H_RESOURCE=$H_RELEASE/bundled-skills/unknown-verification/references/contract.md
cp "$BODY" "$TEST_TMPDIR/fallback-body.saved"
cp "$RESOURCE" "$TEST_TMPDIR/fallback-resource.saved"
cp "$H_RESOURCE" "$TEST_TMPDIR/h-fallback-resource.saved"

chmod 0644 "$BODY"; printf '\nbody tamper\n' >>"$BODY"; chmod 0444 "$BODY"
assert_fail "fallback-body-tamper-rejected" \
  "$ROOT/core/scripts/polylane-package.sh" verify-package "$C"
chmod 0644 "$BODY"; cp "$TEST_TMPDIR/fallback-body.saved" "$BODY"; chmod 0444 "$BODY"
assert_ok "fallback-body-restored" "$ROOT/core/scripts/polylane-package.sh" verify-package "$C"

chmod 0644 "$RESOURCE"; printf '\nresource tamper\n' >>"$RESOURCE"; chmod 0444 "$RESOURCE"
assert_fail "nested-resource-tamper-rejected" \
  "$ROOT/core/scripts/polylane-package.sh" verify-package "$C"
chmod 0644 "$RESOURCE"; cp "$TEST_TMPDIR/fallback-resource.saved" "$RESOURCE"; chmod 0444 "$RESOURCE"
chmod 0644 "$RESOURCE"
assert_fail "nested-resource-mode-rejected" \
  "$ROOT/core/scripts/polylane-package.sh" verify-package "$C"
chmod 0444 "$RESOURCE"

RESOURCE_DIR=$(dirname "$RESOURCE"); chmod 0755 "$RESOURCE_DIR"
rm "$RESOURCE"; ln -s "$TEST_TMPDIR/fallback-resource.saved" "$RESOURCE"
assert_fail "nested-resource-symlink-rejected" \
  "$ROOT/core/scripts/polylane-package.sh" verify-package "$C"
rm "$RESOURCE"; cp "$TEST_TMPDIR/fallback-resource.saved" "$RESOURCE"; chmod 0444 "$RESOURCE"
chmod 0555 "$RESOURCE_DIR"

chmod 0755 "$C_RELEASE/bundled-skills"
printf 'extra\n' >"$C_RELEASE/bundled-skills/unrecorded.txt"; chmod 0444 "$C_RELEASE/bundled-skills/unrecorded.txt"
assert_fail "fallback-extra-rejected" "$ROOT/core/scripts/polylane-package.sh" verify-package "$C"
rm "$C_RELEASE/bundled-skills/unrecorded.txt"; chmod 0555 "$C_RELEASE/bundled-skills"

H_RESOURCE_DIR=$(dirname "$H_RESOURCE"); chmod 0755 "$H_RESOURCE_DIR"; rm "$H_RESOURCE"
assert_fail "nested-resource-delete-rejected" \
  "$ROOT/core/scripts/polylane-package.sh" verify-package "$H"
cp "$TEST_TMPDIR/h-fallback-resource.saved" "$H_RESOURCE"; chmod 0444 "$H_RESOURCE"
chmod 0555 "$H_RESOURCE_DIR"
assert_ok "all-codex-fallback-tampers-restored" \
  "$ROOT/core/scripts/polylane-package.sh" verify-package "$C"
assert_ok "all-claude-fallback-tampers-restored" \
  "$ROOT/core/scripts/polylane-package.sh" verify-package "$H"

NO_PY=$TEST_TMPDIR/no-python; mkdir -p "$NO_PY"
for command_name in dirname jq git; do
  ln -s "$(command -v "$command_name")" "$NO_PY/$command_name"
done
ln -s /usr/bin/true "$NO_PY/tmux"; ln -s /usr/bin/true "$NO_PY/codex"
ln -s /usr/bin/true "$NO_PY/claude"
printf '%s\n' '{"agent":"codex","run_id":"python-check"}' >"$TEST_TMPDIR/codex-python.json"
printf '%s\n' '{"agent":"claude","run_id":"python-check"}' >"$TEST_TMPDIR/claude-python.json"
out=$(PATH="$NO_PY" /bin/bash "$C/scripts/polylane-codex.sh" \
  "$TEST_TMPDIR/codex-python.json" 2>&1); rc=$?
assert_eq "codex-python-missing-rc" 1 "$rc"
assert_contains "codex-python-missing-before-runner" "missing dependency: python3" "$out"
out=$(PATH="$NO_PY" /bin/bash "$H/scripts/polylane-claude.sh" \
  "$TEST_TMPDIR/claude-python.json" 2>&1); rc=$?
assert_eq "claude-python-missing-rc" 1 "$rc"
assert_contains "claude-python-missing-before-runner" "missing dependency: python3" "$out"
CODEX_NO_PY_DEST=$TEST_TMPDIR/codex-no-python-install
CLAUDE_NO_PY_DEST=$TEST_TMPDIR/claude-no-python-install
out=$(PATH="$NO_PY" /bin/bash "$ROOT/codex/install.sh" --dest "$CODEX_NO_PY_DEST" 2>&1); rc=$?
assert_eq "codex-installer-python-missing-rc" 1 "$rc"
assert_contains "codex-installer-python-missing" "missing dependency: python3" "$out"
assert_fail "codex-installer-python-missing-no-side-effect" test -e "$CODEX_NO_PY_DEST"
assert_fail "codex-installer-python-missing-no-release-root" test -e \
  "$CODEX_NO_PY_DEST.polylane-releases"
assert_fail "codex-installer-python-missing-no-lock" test -e \
  "$CODEX_NO_PY_DEST.polylane-lock"
out=$(PATH="$NO_PY" /bin/bash "$ROOT/claude-code/install.sh" --dest "$CLAUDE_NO_PY_DEST" 2>&1); rc=$?
assert_eq "claude-installer-python-missing-rc" 1 "$rc"
assert_contains "claude-installer-python-missing" "missing dependency: python3" "$out"
assert_fail "claude-installer-python-missing-no-side-effect" test -e "$CLAUDE_NO_PY_DEST"
assert_fail "claude-installer-python-missing-no-release-root" test -e \
  "$CLAUDE_NO_PY_DEST.polylane-releases"
assert_fail "claude-installer-python-missing-no-lock" test -e \
  "$CLAUDE_NO_PY_DEST.polylane-lock"
```

This uses Foundation's actual `C`/`H` installed package variables. It neither invokes an
assemble hook nor invents a staging path or `CODEX_DEST`; body, nested resource, mode,
symlink, extra-file, and deletion tampering are each rejected and restored.

- [ ] **Step 6: Add the complete source-unavailable installed-package E2E**

Create `codex/tests/test-codex-skill-kits-installed.sh`:

```bash
#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
. "$ROOT/core/tests/helpers.sh"
make_tmpdir
TEST_TMPDIR=$(cd "$TEST_TMPDIR" && pwd -P)
SRC=$TEST_TMPDIR/source; C=$TEST_TMPDIR/codex; H=$TEST_TMPDIR/claude
mkdir -p "$SRC"
cp -R "$ROOT/." "$SRC/"
assert_ok "package-installed-codex" "$SRC/core/scripts/polylane-package.sh" codex "$C"
assert_ok "package-installed-claude" "$SRC/core/scripts/polylane-package.sh" claude-code "$H"
assert_ok "installed-codex-valid" "$SRC/core/scripts/polylane-package.sh" verify-package "$C"
assert_ok "installed-claude-valid" "$SRC/core/scripts/polylane-package.sh" verify-package "$H"
mv "$SRC" "$SRC.offline"

FAKE=$TEST_TMPDIR/fake; STATE=$TEST_TMPDIR/tmux-state; CAPTURE=$TEST_TMPDIR/capture
mkdir -p "$FAKE" "$STATE" "$CAPTURE"
cat >"$FAKE/tmux" <<'SH'
#!/usr/bin/env bash
set -u
state=${FAKE_TMUX_STATE:?}; action=${1:-}; shift || true
index_of() { printf '%s\n' "${1##*.}"; }
launch() {
  idx=$1; command_text=$2
  old=$(cat "$state/pid.$idx" 2>/dev/null || true)
  [ -z "$old" ] || kill "$old" 2>/dev/null || true
  /bin/bash -c "$command_text" >"$state/pane.$idx.log" 2>&1 &
  printf '%s\n' "$!" >"$state/pid.$idx"
}
case "$action" in
  new-session) printf '1\n' >"$state/next" ;;
  split-window)
    idx=$(cat "$state/next" 2>/dev/null || printf 1)
    printf '%s\n' "$((idx + 1))" >"$state/next" ;;
  select-layout|pipe-pane|select-pane) : ;;
  send-keys)
    target=""; literal=0; payload=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -t) target=$2; shift 2 ;;
        -l) literal=1; payload=$2; shift 2 ;;
        *) payload=$1; shift ;;
      esac
    done
    idx=$(index_of "$target")
    if [ "$literal" = 1 ]; then printf '%s' "$payload" >"$state/cmd.$idx"
    elif [ "$payload" = C-m ] || [ "$payload" = Enter ]; then
      launch "$idx" "$(cat "$state/cmd.$idx")"
    fi ;;
  respawn-pane)
    target=""; payload=""
    while [ "$#" -gt 0 ]; do
      case "$1" in -k) shift ;; -t) target=$2; shift 2 ;; *) payload=$1; shift ;; esac
    done
    launch "$(index_of "$target")" "$payload" ;;
  display-message)
    target=""
    while [ "$#" -gt 0 ]; do
      case "$1" in -t) target=$2; shift 2 ;; *) shift ;; esac
    done
    cat "$state/pid.$(index_of "$target")" ;;
  capture-pane) : ;;
  list-panes)
    for file in "$state"/pid.*; do
      [ -f "$file" ] || continue; idx=${file##*.}; printf '%s\t%s\n' "$idx" "$(cat "$file")"
    done ;;
  has-session) exit 0 ;;
  kill-session)
    for file in "$state"/pid.*; do [ ! -f "$file" ] || kill "$(cat "$file")" 2>/dev/null || true; done ;;
  *) echo "fake tmux: unsupported $action" >&2; exit 64 ;;
esac
SH
chmod +x "$FAKE/tmux"

cat >"$FAKE/codex" <<'SH'
#!/usr/bin/env bash
set -eu
[ "$#" -eq 11 ] && [ "$1" = exec ] && [ "$2" = --json ] && \
  [ "$3" = --sandbox ] && [ "$4" = workspace-write ] && [ "$5" = -c ] && \
  [ "$6" = approval_policy=never ] && [ "$7" = --model ] && [ "$9" = -c ] && \
  [ "$11" = - ] || { echo "unexpected Codex argv: $*" >&2; exit 64; }
if [ "${POLYLANE_BIND_CRASH_PROBE:-0}" = 1 ]; then
  cat >/dev/null
  printf '%s\n' "$$" >"${POLYLANE_BIND_CRASH_CHILD:?}"
  sleep 30
  exit 70
fi
if [ "${POLYLANE_FAST_READER_PROBE:-0}" = 1 ]; then
  cat >/dev/null
  printf '%s\n' '{"type":"thread.started","thread_id":"fast-reader"}'
  printf '%s\n' '{"type":"turn.started"}'
  printf '%s\n' '{"type":"turn.completed"}'
  sleep .2
  exit 0
fi
capture=${POLYLANE_TEST_CAPTURE:?}; run_id=${POLYLANE_TEST_RUN_ID:?}
lane=${POLYLANE_ACTOR_LANE:-integrator}; generation=${POLYLANE_ACTOR_GENERATION:-0}
cat >"$capture/$lane-$generation.prompt"
printf '%s\n' "$*" >"$capture/$lane-$generation.argv"
mkdir -p docs
if [ "$lane" = api ]; then
  kit=.polylane/skill-kit.json
  jq -e '.assignments|length==4' "$kit" >/dev/null
  jq -e --arg root "$PWD/.polylane/skill-snapshots/" \
    'all(.assignments[];. as $a | ($a.snapshot_root|startswith($root)) and
      ($a.tree_manifest|startswith($a.snapshot_root)) and ($a.file_count>=2))' "$kit" >/dev/null
  while IFS= read -r root; do
    [ -f "$root/SKILL.md" ] && [ -f "$root/.polylane-skill-tree.json" ] || exit 65
  done < <(jq -r '.assignments[].snapshot_root' "$kit")
  printf 'kit-ok\n' >"$capture/api-$generation.tree-check"
  printf 'built generation %s\n' "$generation" >api-output.txt
  if [ "$generation" = 1 ]; then verify_run=wrong-run; else verify_run=$run_id; fi
  jq -cnS --arg lane api --arg run_id "$verify_run" \
    '{lane:$lane,run_id:$run_id,schema_version:1}' >docs/verify-api.json
  printf 'STATUS: api DONE run=%s\n' "$run_id" >docs/status-api.md
  git add api-output.txt docs/status-api.md docs/verify-api.json
  git commit -qm "builder generation $generation"
else
  git merge --no-edit lane/api >/dev/null
  printf 'STATUS: integrator DONE run=%s\n' "$run_id" >docs/status-integrator.md
  "$POLYLANE_TEST_BIN/polylane-markers.sh" verdict GO "$run_id" >docs/verify-integration.md
  git add docs/status-integrator.md docs/verify-integration.md
  git commit -qm integration
fi
printf '%s\n' '{"type":"thread.started","thread_id":"installed-e2e"}'
printf '%s\n' '{"type":"turn.started"}'
printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message","text":"complete"}}'
printf '%s\n' '{"type":"turn.completed"}'
sleep 1
SH
chmod +x "$FAKE/codex"

# Direct wrapper probes must carry the same frozen launch identity as a pane command.
# Bind physical regular files and the explicit interpreter; never infer these through the
# hostile PATH used below.
CODEX_BOUND_BASH=$(cd /bin && pwd -P)/bash
CODEX_BOUND_WRAPPER=$(cd "$C/scripts" && pwd -P)/polylane-codex-exec.sh
CODEX_BOUND_EXEC=$(cd "$FAKE" && pwd -P)/codex
identity_id() {
  local path=$1 dev ino mode hash
  [ -f "$path" ] && [ ! -L "$path" ] && [ -x "$path" ] || return 2
  case $(uname -s) in
    Linux) dev=$(stat -c %d "$path"); ino=$(stat -c %i "$path"); mode=$(stat -c %a "$path") ;;
    *) dev=$(stat -f %d "$path"); ino=$(stat -f %i "$path"); mode=$(stat -f %Lp "$path") ;;
  esac
  hash=$(if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$path"
    else sha256sum "$path"; fi | awk '{print $1}')
  printf '%s:%s:%s:%s\n' "$dev" "$ino" "$mode" "$hash"
}
CODEX_BOUND_BASH_ID=$(identity_id "$CODEX_BOUND_BASH")
CODEX_BOUND_WRAPPER_ID=$(identity_id "$CODEX_BOUND_WRAPPER")
CODEX_BOUND_EXEC_ID=$(identity_id "$CODEX_BOUND_EXEC")

cat >"$FAKE/slow-gh" <<'SH'
#!/usr/bin/env bash
sleep 30
SH
chmod +x "$FAKE/slow-gh"

SHADOW=$TEST_TMPDIR/hostile-path; mkdir -p "$SHADOW"
cat >"$SHADOW/codex" <<'SH'
#!/usr/bin/env bash
echo "hostile PATH Codex must not run" >&2
exit 99
SH
chmod +x "$SHADOW/codex"

# Adversarial reader: the first visible result must already contain all bindings, and
# neither inode nor hash may ever change after that first visibility.
FAST_FIX=$TEST_TMPDIR/fast-reader-fixture; FAST_WT=$FAST_FIX/worktree
mkdir -p "$FAST_FIX" "$FAST_WT"
export POLYLANE_CLAIM_TOKEN=publication-claim POLYLANE_RUNNER_GENERATION=1 POLYLANE_ATTEMPT=1
"$C/scripts/polylane-skill-kit.sh" fixture "$FAST_FIX"
"$C/scripts/polylane-skill-kit.sh" materialize \
  "$FAST_FIX/kit.json" "$FAST_WT" "$FAST_FIX/local-kit.json"
printf 'immutable prompt\n' >"$FAST_FIX/original.prompt"
"$C/scripts/polylane-skill-kit.sh" build-prompt "$FAST_FIX/original.prompt" \
  "$FAST_FIX/local-kit.json" "$FAST_FIX/base.prompt"
"$C/scripts/polylane-skill-kit.sh" lint-prompt "$FAST_FIX/original.prompt" \
  "$FAST_FIX/local-kit.json" "$FAST_FIX/base.prompt"
cat >"$TEST_TMPDIR/fast-reader.sh" <<'SH'
#!/usr/bin/env bash
set -eu
artifact=$1; observed=$2
i=0
while [ ! -f "$artifact" ] && [ "$i" -lt 500 ]; do sleep .01; i=$((i + 1)); done
[ -f "$artifact" ] || exit 67
jq -e '.schema_version==2 and .terminal_type=="turn.completed" and
  (.prompt_sha256|test("^sha256:[0-9a-f]{64}$")) and
  (.kit_sha256|test("^sha256:[0-9a-f]{64}$")) and
  .runner=={"attempt":1,"claim":"publication-claim","generation":1} and
  .actor.generation==9 and .actor.lane=="fixture" and .actor.run_id=="fixture-1"' \
  "$artifact" >/dev/null
case $(uname -s) in Linux) inode=$(stat -c %i "$artifact") ;; *) inode=$(stat -f %i "$artifact") ;; esac
hash=$(if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$artifact"; else sha256sum "$artifact"; fi | awk '{print $1}')
count=0
while [ "$count" -lt 40 ]; do
  case $(uname -s) in Linux) now_inode=$(stat -c %i "$artifact") ;; *) now_inode=$(stat -f %i "$artifact") ;; esac
  now_hash=$(if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$artifact"; else sha256sum "$artifact"; fi | awk '{print $1}')
  [ "$now_inode" = "$inode" ] && [ "$now_hash" = "$hash" ] || exit 66
  count=$((count + 1)); sleep .01
done
printf '%s %s\n' "$inode" "$hash" >"$observed"
SH
chmod +x "$TEST_TMPDIR/fast-reader.sh"

# Generation 8 binds successfully and is then killed before result publication. A simulated
# respawn uses generation 9 and distinct immutable paths, proving kill-after-bind recovery
# cannot collide with the abandoned actor's kit or prompt.
CRASH_ARTIFACT=$TEST_TMPDIR/bind-crash-g8.json
PATH="$SHADOW:$FAKE:$PATH" POLYLANE_BIND_CRASH_PROBE=1 \
  POLYLANE_BIND_CRASH_CHILD="$TEST_TMPDIR/bind-crash-child.pid" \
  POLYLANE_CODEX_BASH="$CODEX_BOUND_BASH" POLYLANE_CODEX_BASH_ID="$CODEX_BOUND_BASH_ID" \
  POLYLANE_CODEX_WRAPPER_ID="$CODEX_BOUND_WRAPPER_ID" \
  POLYLANE_CODEX_EXEC_ID="$CODEX_BOUND_EXEC_ID" POLYLANE_CODEX_LAUNCH_KIND=script \
  POLYLANE_CODEX_INTERPRETER="$CODEX_BOUND_BASH" \
  POLYLANE_CODEX_INTERPRETER_ID="$CODEX_BOUND_BASH_ID" \
  POLYLANE_ACTOR_LANE=fixture POLYLANE_ACTOR_RUN_ID=fixture-1 POLYLANE_ACTOR_GENERATION=8 \
  POLYLANE_ACTOR_BASE_KIT="$FAST_FIX/local-kit.json" \
  POLYLANE_ACTOR_BOUND_KIT="$FAST_FIX/bound-g8-kit.json" \
  POLYLANE_ACTOR_BOUND_PROMPT="$FAST_FIX/bound-g8.prompt" \
  "$CODEX_BOUND_BASH" "$CODEX_BOUND_WRAPPER" "$CODEX_BOUND_EXEC" gpt-installed high \
  "$FAST_FIX/base.prompt" "$CRASH_ARTIFACT" >/dev/null 2>&1 & CRASH_WRAPPER=$!
i=0
while { [ ! -f "$FAST_FIX/bound-g8.prompt" ] || \
  [ ! -f "$TEST_TMPDIR/bind-crash-child.pid" ]; } && [ "$i" -lt 500 ]; do
  sleep .01; i=$((i + 1))
done
assert_ok "kill-after-bind-reached-codex" test -f "$TEST_TMPDIR/bind-crash-child.pid"
assert_ok "kill-after-bind-prompt-published" test -f "$FAST_FIX/bound-g8.prompt"
kill -9 "$CRASH_WRAPPER" 2>/dev/null || true
CRASH_CHILD=$(cat "$TEST_TMPDIR/bind-crash-child.pid")
kill -9 "$CRASH_CHILD" 2>/dev/null || true
wait "$CRASH_WRAPPER" 2>/dev/null || true
assert_fail "killed-generation-published-no-result" test -e "$CRASH_ARTIFACT"

FAST_ARTIFACT=$TEST_TMPDIR/fast-reader-result.json
"$TEST_TMPDIR/fast-reader.sh" "$FAST_ARTIFACT" "$TEST_TMPDIR/fast-reader.observed" & FAST_READER=$!
PATH="$SHADOW:$FAKE:$PATH" POLYLANE_FAST_READER_PROBE=1 \
  POLYLANE_CODEX_BASH="$CODEX_BOUND_BASH" POLYLANE_CODEX_BASH_ID="$CODEX_BOUND_BASH_ID" \
  POLYLANE_CODEX_WRAPPER_ID="$CODEX_BOUND_WRAPPER_ID" \
  POLYLANE_CODEX_EXEC_ID="$CODEX_BOUND_EXEC_ID" POLYLANE_CODEX_LAUNCH_KIND=script \
  POLYLANE_CODEX_INTERPRETER="$CODEX_BOUND_BASH" \
  POLYLANE_CODEX_INTERPRETER_ID="$CODEX_BOUND_BASH_ID" \
  POLYLANE_ACTOR_LANE=fixture POLYLANE_ACTOR_RUN_ID=fixture-1 \
  POLYLANE_ACTOR_GENERATION=9 POLYLANE_ACTOR_BASE_KIT="$FAST_FIX/local-kit.json" \
  POLYLANE_ACTOR_BOUND_KIT="$FAST_FIX/bound-g9-kit.json" \
  POLYLANE_ACTOR_BOUND_PROMPT="$FAST_FIX/bound-g9.prompt" \
  "$CODEX_BOUND_BASH" "$CODEX_BOUND_WRAPPER" "$CODEX_BOUND_EXEC" gpt-installed high \
  "$FAST_FIX/base.prompt" "$FAST_ARTIFACT" >/dev/null
fast_wrapper_rc=$?
assert_eq "fast-reader-wrapper-turn-completed-rc" 0 "$fast_wrapper_rc"
wait "$FAST_READER"; assert_eq "fast-reader-saw-only-complete-result" 0 "$?"
assert_ok "fast-reader-used-turn-completed-path" jq -e \
  '.terminal_type=="turn.completed" and .process_exit==0 and .kind=="none"' "$FAST_ARTIFACT"
assert_ok "killed-actor-kept-generation-eight" jq -e '.actor.generation==8' \
  "$FAST_FIX/bound-g8-kit.json"
assert_ok "respawn-bound-generation-nine" jq -e '.actor.generation==9' \
  "$FAST_FIX/bound-g9-kit.json"
assert_fail "respawn-bound-prompt-is-distinct" cmp "$FAST_FIX/bound-g8.prompt" \
  "$FAST_FIX/bound-g9.prompt"
read -r first_inode first_hash <"$TEST_TMPDIR/fast-reader.observed"
case $(uname -s) in Linux) final_inode=$(stat -c %i "$FAST_ARTIFACT") ;; *) final_inode=$(stat -f %i "$FAST_ARTIFACT") ;; esac
final_hash=$(if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$FAST_ARTIFACT"; else sha256sum "$FAST_ARTIFACT"; fi | awk '{print $1}')
assert_eq "published-result-inode-immutable" "$first_inode" "$final_inode"
assert_eq "published-result-hash-immutable" "$first_hash" "$final_hash"

PROJECT=$TEST_TMPDIR/project; API_WT=$TEST_TMPDIR/wt-api; INT_WT=$TEST_TMPDIR/wt-integrator
RUNTIME=$PROJECT/.polylane/runtime; RUN=installed-cycle-1
mkdir -p "$PROJECT/.polylane/lanes"
git -C "$PROJECT" init -q -b main
git -C "$PROJECT" config user.email installed@example.invalid
git -C "$PROJECT" config user.name Installed-E2E
printf 'seed\n' >"$PROJECT/seed.txt"
git -C "$PROJECT" add seed.txt; git -C "$PROJECT" commit -qm seed
cat >"$PROJECT/.polylane/lanes/api.txt" <<EOF
GOAL: build api-output.txt. OWN: api-output.txt docs/status-api.md docs/verify-api.json.
FORBIDDEN: every other tracked path. If .polylane/qualification-feedback.json exists, read it.
Write canonical docs/verify-api.json, commit, then write STATUS: api DONE run=$RUN.
EOF
cat >"$PROJECT/.polylane/lanes/integrator.txt" <<EOF
GOAL: merge lane/api and verify api-output.txt. OWN: integration marker files only.
Write STATUS: integrator DONE run=$RUN and a GO verdict with the installed marker helper.
EOF
cp "$PROJECT/.polylane/lanes/integrator.txt" "$TEST_TMPDIR/integrator.original"
cat >"$PROJECT/.polylane/run.raw.json" <<EOF
{"agent":"codex","loop_id":"installed-loop","cycle":1,"run_id":"$RUN","base":"main",
 "available_models":["gpt-installed"],
 "lanes":[{"name":"api","role":"builder","activities":["implement REST API route"],
   "ownership_globs":["api-output.txt","docs/status-api.md","docs/verify-api.json"],
   "verification_argv":["/usr/bin/test","-f","api-output.txt"],
   "model":"gpt-installed","effort":"high","branch":"lane/api","worktree":"$API_WT",
   "prompt_file":"$PROJECT/.polylane/lanes/api.txt"}],
 "integrator":{"name":"integrator","role":"integrator","activities":["integrate"],
   "ownership_globs":["docs/status-integrator.md","docs/verify-integration.md"],
   "verification_argv":["/usr/bin/test","-f","api-output.txt"],
   "model":"gpt-installed","effort":"high","branch":"lane/integrator","worktree":"$INT_WT",
   "prompt_file":"$PROJECT/.polylane/lanes/integrator.txt"}}
EOF
jq -cS . "$PROJECT/.polylane/run.raw.json" >"$PROJECT/.polylane/run.json"

cat >"$TEST_TMPDIR/guardian.sh" <<'SH'
#!/usr/bin/env bash
set -eu
input=$1; owner=$2; result=$3; ledger=$4; store=$5; job=$6; slow_gh=$7
until [ -f "$input" ]; do sleep .05; done
token=$("$store" process-token "$$"); deadline=$(( $(date +%s) + 2 ))
input_hash=$(if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$input"; else sha256sum "$input"; fi | awk '{print "sha256:"$1}')
jq -cnS --argjson pid "$$" --arg token "$token" --argjson deadline "$deadline" \
  --arg job_id "$(jq -r .job_id "$input")" --arg input_hash "$input_hash" \
  '{role:"guardian",pid:$pid,start_token:$token,generation:1,deadline_epoch:$deadline,
    job_id:$job_id,input_sha256:$input_hash}' >"$owner"
POLYLANE_GH="$slow_gh" exec "$job" run "$input" "$owner" "$result" "$ledger"
SH
chmod +x "$TEST_TMPDIR/guardian.sh"
SUGGEST_SCOPE=installed-claim/g1/a1
SUGGEST_INPUT=$RUNTIME/skill-suggestions/inputs/$RUN/$SUGGEST_SCOPE.json
SUGGEST_OWNER=$RUNTIME/skill-suggestions/owners/$RUN/$SUGGEST_SCOPE.json
SUGGEST_RESULT=$RUNTIME/skill-suggestions/results/$RUN/$SUGGEST_SCOPE.json
SUGGEST_LEDGER=$RUNTIME/skill-suggestions/ledger
mkdir -p "$(dirname "$SUGGEST_OWNER")" "$(dirname "$SUGGEST_RESULT")"
"$TEST_TMPDIR/guardian.sh" "$SUGGEST_INPUT" "$SUGGEST_OWNER" "$SUGGEST_RESULT" \
  "$SUGGEST_LEDGER" "$C/scripts/polylane-skill-store.sh" \
  "$C/scripts/polylane-skill-suggest-job.sh" "$FAKE/slow-gh" & GUARDIAN_PID=$!

export FAKE_TMUX_STATE=$STATE POLYLANE_TEST_CAPTURE=$CAPTURE POLYLANE_TEST_RUN_ID=$RUN
export POLYLANE_TEST_BIN=$C/scripts POLYLANE_AGENT=codex
export POLYLANE_AGENT_ADAPTER=$C/scripts/polylane-codex-agent.sh
export POLYLANE_RUNTIME_DIR=$RUNTIME CODEX_HOME=$TEST_TMPDIR/empty-codex
export POLYLANE_CLAIM_TOKEN=installed-claim POLYLANE_RUNNER_GENERATION=1 POLYLANE_ATTEMPT=1
mkdir -p "$CODEX_HOME"
out=$(cd "$PROJECT" && PATH="$FAKE:$PATH" POLYLANE_POLL_INTERVAL=1 \
  POLYLANE_HEALTH_INTERVAL=9999 POLYLANE_SEED_VERIFY=0 POLYLANE_MIN_DISK_GB=0 \
  "$C/scripts/polylane-run.sh" "$PROJECT/.polylane/run.json" --yes 2>&1); rc=$?
assert_eq "installed-cycle-rc" 0 "$rc"
wait "$GUARDIAN_PID"; guardian_rc=$?
assert_eq "guardian-job-rc" 0 "$guardian_rc"
assert_ok "source-remains-unavailable" test ! -e "$SRC"
assert_ok "generation-one-ran" test -f "$CAPTURE/api-1.prompt"
assert_ok "generation-two-ran" test -f "$CAPTURE/api-2.prompt"
assert_fail "no-generation-three" test -e "$CAPTURE/api-3.prompt"
assert_ok "both-generations-had-four-complete-trees" test -f "$CAPTURE/api-1.tree-check"
assert_ok "second-generation-had-four-complete-trees" test -f "$CAPTURE/api-2.tree-check"
assert_ok "integrator-prompt-byte-exact" cmp "$TEST_TMPDIR/integrator.original" \
  "$CAPTURE/integrator-0.prompt"
assert_not_contains "integrator-has-no-kit-frame" POLYLANE-PROMPT-V1 \
  "$(cat "$CAPTURE/integrator-0.prompt")"
assert_contains "builder-framed" POLYLANE-PROMPT-V1 "$(cat "$CAPTURE/api-2.prompt")"
assert_eq "builder-four-frames" 4 "$(grep -c '^FRAME-METADATA-BYTES ' "$CAPTURE/api-2.prompt")"
assert_ok "real-codex-json-argv" grep -qx \
  'exec --json --sandbox workspace-write -c approval_policy=never --model gpt-installed -c model_reasoning_effort=high -' \
  "$CAPTURE/api-2.argv"

REJECTION=$RUNTIME/skill-rejections/$RUN/api/actor-g1/installed-claim/g1/a1/receipt.json
GEN1_RESULT=$RUNTIME/agent-errors/installed-claim/g1/a1/builder.installed-claim.rg1.a1.actor-g1.prompt.json
GEN2_RESULT=$RUNTIME/agent-errors/installed-claim/g1/a1/builder.installed-claim.rg1.a1.actor-g2.prompt.json
assert_ok "generation-one-result-preserved" test -f "$GEN1_RESULT"
assert_ok "generation-two-result-separate" test -f "$GEN2_RESULT"
assert_ok "generation-one-rejection-receipt" jq -e \
  '.generation==1 and .reason=="qualification_failed" and
   .runner.generation==1 and .runner.attempt==1 and
   (.evidence["worker-result"].sha256|test("^sha256:")) and
   (.evidence["prompt-capture"].sha256|test("^sha256:")) and
   (.evidence.done.sha256|test("^sha256:")) and (.evidence.verify.sha256|test("^sha256:"))' \
  "$REJECTION"
assert_ok "rejected-result-copy-still-matches" cmp "$GEN1_RESULT" \
  "$(jq -r '.evidence["worker-result"].path' "$REJECTION")"
ATTEST=$RUNTIME/skill-attestations/$RUN/installed-claim/g1/a1/api.g2.json
assert_ok "runner-attestation" jq -e \
  '.lane=="api" and .actor.generation==2 and
   .attester.claim=="installed-claim" and .attester.generation==1 and
   .attester.attempt==1 and (.tree_sha256|length)==4 and
   .verification.argv==["/usr/bin/test","-f","api-output.txt"] and
   .verification.schema_version==2 and .verification.exit_code==0 and
   .verification.passed==true and .verification.failure_reason==null and
   .verification.limits.per_stream_bytes==4194304 and
   .verification.limits.combined_bytes==6291456 and
   (.verification.stdout_sha256|test("^sha256:[0-9a-f]{64}$")) and
   (.verification.stderr_sha256|test("^sha256:[0-9a-f]{64}$"))' "$ATTEST"
assert_eq "segmented-score-once" 1 \
  "$("$C/scripts/polylane-skill-store.sh" read-ledger "$RUNTIME/skill-ledger/scores" dedupe_key | wc -l | tr -d ' ')"
assert_ok "suggestion-input-enqueued" jq -e \
  '.schema_version==1 and (.gaps|length)>=1 and
   .runner=={"attempt":1,"claim":"installed-claim","generation":1}' "$SUGGEST_INPUT"
assert_ok "hung-github-terminal-is-informational" jq -e \
  --argjson guardian "$GUARDIAN_PID" \
  '.owner.pid==$guardian and all(.terminals[];.status=="timeout" or .status=="unavailable")' \
  "$SUGGEST_RESULT"
assert_contains "qualification-retry-stayed-working" "generation 2 is WORKING" "$out"
assert_not_contains "no-installed-source-fallback" '../../core' \
  "$(cat "$C/scripts/polylane-codex-skills.sh" "$C/scripts/polylane-skill-cycle.sh")"
assert_not_contains "proposal-never-selects-skills" selected_skills \
  "$(cat "$PROJECT/.polylane/run.json")"
finish
```

This test intentionally makes the guardian's GitHub command hang past its deadline while
the installed runner launches from bundled/default roots, rejects generation 1, qualifies
generation 2, integrates, and finishes without ever reading a suggestion result. The test
uses the installed sibling scripts only after the copied source tree is renamed away.

- [ ] **Step 7: Run the full Builder audit and commit**

```bash
set -euo pipefail
chmod +x core/scripts/polylane-skill-cycle.sh core/tests/test-builder-foundation-dry-apply.sh \
  core/tests/test-builder-foundation-sequential-apply.sh \
  codex/tests/test-codex-skill-kits-installed.sh
python3 -m py_compile core/scripts/polylane-skill-store.py \
  core/scripts/polylane-skill-kit.py core/scripts/polylane-skill-suggest.py
bash -n core/scripts/polylane-skill-store.sh core/scripts/polylane-skill-kit.sh \
  core/scripts/polylane-skill-ledger.sh core/scripts/polylane-skill-suggest.sh \
  core/scripts/polylane-skill-suggest-job.sh core/scripts/polylane-skill-cycle.sh \
  core/scripts/polylane-run.sh core/scripts/polylane-doctor.sh \
  core/scripts/polylane-scope.sh core/scripts/polylane-outcomes.sh \
  codex/scripts/polylane-codex-exec.sh codex/scripts/polylane-codex.sh \
  codex/scripts/polylane-codex-rehearse.sh codex/install.sh \
  claude-code/scripts/polylane-claude.sh claude-code/install.sh \
  core/tests/test-skill-store-locks.sh core/tests/test-skill-tree-validation.sh \
  core/tests/test-skill-kit-selection.sh core/tests/test-skill-prompt-framing.sh \
  core/tests/test-skill-attestation.sh \
  core/tests/test-skill-suggestions.sh core/tests/test-package-parity.sh \
  core/tests/test-workflow-contract.sh core/tests/test-builder-foundation-dry-apply.sh \
  core/tests/test-builder-foundation-sequential-apply.sh \
  codex/tests/test-codex-rehearse.sh codex/tests/test-codex-skill-kits-installed.sh
shellcheck -S warning core/scripts/polylane-skill-store.sh \
  core/scripts/polylane-skill-kit.sh core/scripts/polylane-skill-ledger.sh \
  core/scripts/polylane-skill-suggest.sh core/scripts/polylane-skill-suggest-job.sh \
  core/scripts/polylane-skill-cycle.sh core/scripts/polylane-scope.sh \
  core/scripts/polylane-outcomes.sh codex/scripts/polylane-codex-exec.sh \
  codex/scripts/polylane-codex-rehearse.sh codex/install.sh \
  claude-code/install.sh \
  core/tests/test-skill-store-locks.sh core/tests/test-skill-tree-validation.sh \
  core/tests/test-skill-kit-selection.sh core/tests/test-skill-prompt-framing.sh \
  core/tests/test-skill-attestation.sh core/tests/test-skill-suggestions.sh \
  core/tests/test-workflow-contract.sh core/tests/test-builder-foundation-dry-apply.sh \
  core/tests/test-builder-foundation-sequential-apply.sh \
  codex/tests/test-codex-rehearse.sh codex/tests/test-codex-skill-kits-installed.sh
cmp core/scripts/polylane-skill-store.py core/tests/fixtures/skill-store-v2.py

bash core/tests/test-skill-store-locks.sh
bash core/tests/test-skill-tree-validation.sh
bash core/tests/test-skill-kit-selection.sh
bash core/tests/test-skill-prompt-framing.sh
bash core/tests/test-skill-attestation.sh
bash core/tests/test-skill-suggestions.sh
bash core/tests/test-package-parity.sh
bash core/tests/test-workflow-contract.sh
bash core/tests/test-builder-foundation-dry-apply.sh
bash core/tests/test-builder-foundation-sequential-apply.sh
bash codex/tests/test-codex-rehearse.sh
bash codex/tests/test-codex-skill-kits-installed.sh
tests/run.sh

PLAN=docs/superpowers/plans/2026-07-16-codex-builder-skill-kits.md
command -v shellcheck >/dev/null
python3 - "$PLAN" <<'PY'
import pathlib, py_compile, re, subprocess, sys, tempfile
path=pathlib.Path(sys.argv[1]); lines=path.read_text(encoding="utf-8").splitlines(True)
blocks=[]; language=None; start=0; body=[]
for number,line in enumerate(lines,1):
    match=re.match(r"^```([A-Za-z0-9_-]*)\s*$",line.rstrip("\n"))
    if match:
        if language is None:
            language=match.group(1); start=number; body=[]
        else:
            blocks.append((language,start,"".join(body))); language=None
        continue
    if language is not None: body.append(line)
if language is not None: raise SystemExit(f"unclosed Markdown fence at line {start}")
if not blocks: raise SystemExit("no fenced bodies found")
with tempfile.TemporaryDirectory(prefix="polylane-plan-audit-") as directory:
    root=pathlib.Path(directory)
    for index,(kind,line,source) in enumerate(blocks):
        if kind in ("python","py"):
            target=root/f"fence-{index}.py"; target.write_text(source,encoding="utf-8")
            py_compile.compile(str(target),doraise=True)
        if kind in ("bash","sh","shell"):
            target=root/f"fence-{index}.sh"; target.write_text(source,encoding="utf-8")
            subprocess.run(["bash","-n",str(target)],check=True)
            subprocess.run(["shellcheck","-s","bash","-S","error",str(target)],check=True)
            shell_lines=source.splitlines(True); cursor=0
            while cursor < len(shell_lines):
                if re.search(r"<<'PY'(?:\s|$)",shell_lines[cursor]):
                    end=cursor+1
                    while end<len(shell_lines) and shell_lines[end].rstrip("\n")!="PY": end+=1
                    if end==len(shell_lines): raise SystemExit(f"unterminated Python heredoc in fence {line}")
                    embedded="".join(shell_lines[cursor+1:end])
                    target=root/f"heredoc-{index}-{cursor}.py"
                    target.write_text(embedded,encoding="utf-8")
                    py_compile.compile(str(target),doraise=True); cursor=end
                cursor+=1
print(f"audited {len(blocks)} fenced bodies; Markdown fences balanced")
PY

residual_pattern='<''!-- TASK[0-9_]*|TO''DO|T''BD|pseudo''code|omitted bo''dy|fill this i''n'
test -z "$(rg -n "$residual_pattern" "$PLAN" || true)"
stale_evidence_pattern='deletes stale evid''ence|forget_worker_evid''ence|rm'' -f[^\n]*(res''ult|events|stderr|attestation)'
test -z "$(rg -n "$stale_evidence_pattern" "$PLAN" || true)"
test -z "$(rg -n 'selected_skills|skill_ids' core/workflow .polylane/SCHEMA.md \
  core/scripts codex/scripts claude-code/scripts || true)"
rg -n 'verification_argv' .polylane/SCHEMA.md \
  docs/superpowers/plans/2026-07-16-codex-{builder-skill-kits,persistent-autonomy}.md
git diff --check
git status --short
```

Expected: every focused test, installed-package test, package parity/tamper test, and the
aggregate suite pass. Every Bash fence parses and passes ShellCheck at error severity,
every Python fence and embedded Python heredoc compiles, Markdown fences balance, the
placeholder scan is empty, and `git diff --check` is clean. Review `git status --short`;
the known-residual report must say **zero** before committing.

```bash
git add core/bundled-skills core/scripts/polylane-skill-store.py \
  core/scripts/polylane-skill-store.sh core/scripts/polylane-skill-kit.py \
  core/scripts/polylane-skill-kit.sh core/scripts/polylane-skill-ledger.sh \
  core/scripts/polylane-skill-suggest.py core/scripts/polylane-skill-suggest.sh \
  core/scripts/polylane-skill-suggest-job.sh core/scripts/polylane-skill-cycle.sh \
  core/scripts/polylane-run.sh core/scripts/polylane-doctor.sh \
  core/scripts/polylane-package.sh core/scripts/polylane-scope.sh \
  core/scripts/polylane-outcomes.sh core/workflow/polylane-loop.md \
  core/tests/fixtures/skill-store-v2.py core/tests/test-skill-store-locks.sh \
  core/tests/test-skill-tree-validation.sh core/tests/test-skill-kit-selection.sh \
  core/tests/test-skill-prompt-framing.sh core/tests/test-skill-attestation.sh \
  core/tests/test-skill-suggestions.sh core/tests/test-package-parity.sh \
  core/tests/test-workflow-contract.sh core/tests/test-builder-foundation-dry-apply.sh \
  core/tests/test-builder-foundation-sequential-apply.sh \
  core/tests/fixtures/builder-foundation-base.commit \
  codex/scripts/polylane-codex-exec.sh codex/scripts/polylane-codex.sh codex/package.json \
  codex/scripts/polylane-codex-agent.sh codex/scripts/polylane-codex-rehearse.sh \
  codex/install.sh codex/tests/test-codex-errors.sh codex/tests/test-codex-rehearse.sh \
  codex/tests/test-codex-skill-kits-installed.sh claude-code/scripts/polylane-claude.sh \
  claude-code/install.sh claude-code/package.json .polylane/SCHEMA.md
git commit -m "feat(codex): qualify builders with immutable skill kits"
```

Expected: one Builder commit with no unrelated path staged; suggestion results remain
informational data and are never installed or executed.
