#!/usr/bin/env bash
# Focused hermetic test for the download-campaign lane.
#
# Exercises benchmarks/taste-live/tools/taste-download-campaign.mjs against a
# fake transport executable — no network, no Chrome. Covers: happy path,
# session-before-fetch ordering, bounded concurrency, resume without
# redownload, duplicate plan entries, partial/truncated bytes, corruption with
# bounded-retry recovery, retryable/fatal retry classes, hang + per-op
# deadline, campaign deadline with later resume, session failure, and
# interruption atomicity (no partial object ever published).
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TOOL="$ROOT/benchmarks/taste-live/tools/taste-download-campaign.mjs"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-dlc.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
ASSERTIONS=0

expect_eq() {
  if [ "$1" = "$2" ]; then ASSERTIONS=$((ASSERTIONS + 1));
  else echo "FAIL ${3:-assertion}: expected [$1] got [$2]" >&2; exit 1; fi
}
expect_file() {
  if [ -f "$1" ]; then ASSERTIONS=$((ASSERTIONS + 1));
  else echo "FAIL ${2:-file}: missing $1" >&2; exit 1; fi
}
expect_no_file() {
  if [ ! -e "$1" ]; then ASSERTIONS=$((ASSERTIONS + 1));
  else echo "FAIL ${2:-no-file}: unexpected $1" >&2; exit 1; fi
}

# --- fixtures: deterministic per-file bytes ---------------------------------
FIX="$TMP/fixtures"; mkdir -p "$FIX"
for f in f1 f2 f3 f4 f5 f6; do
  printf 'bytes-of-%s-0123456789' "$f" >"$FIX/$f"
done

# --- fake transport (single executable, env-driven modes) -------------------
FAKE="$TMP/fake-transport.mjs"
cat >"$FAKE" <<'EOF'
#!/usr/bin/env node
// Fake transport for hermetic campaign tests. Modes via env MODE:
// good | truncate | corrupt_first | fail_retryable | fail_fatal | hang |
// part_then_crash | session_fail. Logs every invocation to CALL_LOG.
import { appendFileSync, writeFileSync, readFileSync, mkdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
const a = {};
const argv = process.argv.slice(2);
const cmd = argv[0];
for (let i = 1; i < argv.length; i++) {
  if (argv[i].startsWith('--')) a[argv[i].slice(2)] = argv[++i];
}
const log = (o) => appendFileSync(process.env.CALL_LOG, `${JSON.stringify(o)}\n`);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const mode = process.env.MODE || 'good';

if (cmd === 'session') {
  log({ cmd: 'session', source: a.source, ts: Date.now() });
  if (mode === 'session_fail') { console.log(JSON.stringify({ status: 'RETRYABLE', reason: 'waf challenge' })); process.exit(0); }
  console.log(JSON.stringify({ status: 'OK', session: `sess-${a.source}` }));
  process.exit(0);
}

if (cmd === 'fetch') {
  log({ cmd: 'fetch', file: a.file, source: a.source, session: a.session, ev: 'start', ts: Date.now() });
  if (process.env.SLEEP_MS) await sleep(Number(process.env.SLEEP_MS));
  const bytes = readFileSync(join(process.env.FIXTURE_DIR, a.file));
  const state = process.env.STATE_DIR;
  mkdirSync(state, { recursive: true });
  const marker = join(state, `seen-${a.file}`);
  const first = !existsSync(marker);
  writeFileSync(marker, 'x');
  const done = (status, reason) => {
    log({ cmd: 'fetch', file: a.file, ev: 'end', ts: Date.now() });
    console.log(JSON.stringify(reason ? { status, reason } : { status }));
    process.exit(0);
  };
  if (mode === 'hang') { await sleep(60000); done('OK'); }
  if (mode === 'fail_retryable') done('RETRYABLE', 'http 503');
  if (mode === 'fail_fatal') done('FATAL', 'http 404');
  if (mode === 'truncate') { writeFileSync(a.out, bytes.slice(0, Math.floor(bytes.length / 2))); done('OK'); }
  if (mode === 'part_then_crash' && first) {
    writeFileSync(a.out, bytes.slice(0, 4));
    log({ cmd: 'fetch', file: a.file, ev: 'crash', ts: Date.now() });
    process.exit(1); // crash: no status JSON at all
  }
  if (mode === 'corrupt_first' && first) {
    const bad = Buffer.from(bytes); bad[0] ^= 0xff;
    writeFileSync(a.out, bad); done('OK');
  }
  writeFileSync(a.out, bytes); done('OK');
}

console.error('fake-transport: unknown command'); process.exit(2);
EOF
chmod +x "$FAKE"

# --- plan builder ------------------------------------------------------------
# mk_plan <out.json> <source_id:file_id[,file_id...]> ...
mk_plan() {
  local out="$1"; shift
  node -e '
    const { createHash } = require("node:crypto");
    const { readFileSync, writeFileSync } = require("node:fs");
    const [out, fixDir, ...specs] = process.argv.slice(1);
    const sources = specs.map((spec) => {
      const [sid, list] = spec.split(":");
      return {
        source_id: sid,
        pid: `doi:10.7910/TEST/${sid.toUpperCase()}`,
        files: list.split(",").map((fid) => {
          const b = readFileSync(`${fixDir}/${fid}`);
          return {
            file_id: fid,
            filename: `${fid}.bin`,
            declared_size: b.length,
            declared_md5: createHash("md5").update(b).digest("hex"),
            sha256: createHash("sha256").update(b).digest("hex"),
          };
        }),
      };
    });
    writeFileSync(out, JSON.stringify({ run: "test-run", sources }, null, 2));
  ' "$out" "$FIX" "$@"
}

sha_of() { shasum -a 256 "$1" | awk '{print $1}'; }

# run_campaign <workdir> <plan> <extra args...>; env: MODE etc. Sets RC.
run_campaign() {
  local wd="$1" plan="$2"; shift 2
  RC=0
  CALL_LOG="${CALL_LOG:-$wd/calls.jsonl}" FIXTURE_DIR="$FIX" STATE_DIR="$wd/state" \
    node "$TOOL" run --plan "$plan" --cache "$wd/cache" --receipt "$wd/receipt.jsonl" \
      --transport "$FAKE" "$@" >"$wd/out.json" 2>"$wd/err.txt" || RC=$?
}

count_calls() { # <log> <cmd> — fetch logs start+end lines, count starts only
  [ -f "$1" ] || { echo 0; return; }
  case "$2" in
    fetch) grep -c '"ev":"start"' "$1" || true ;;
    *) grep -c '"cmd":"session"' "$1" || true ;;
  esac
}
receipt_count() { # <receipt> <t>
  grep -c "\"t\":\"$2\"" "$1" || true
}

# --- 1. hermetic selftest ----------------------------------------------------
SELFTEST=$(node "$TOOL" --selftest)
case "$SELFTEST" in SELFTEST-OK*) ASSERTIONS=$((ASSERTIONS + 1)) ;; *) echo "FAIL selftest: $SELFTEST" >&2; exit 1 ;; esac

# --- 2. happy path: 2 sources, 4 files, session before fetch ------------------
W="$TMP/happy"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f1,f2" "s2:f3,f4"
MODE=good run_campaign "$W" "$W/plan.json" --concurrency 2
expect_eq 0 "$RC" "happy exit"
expect_eq 2 "$(count_calls "$W/calls.jsonl" session)" "one session per source"
expect_eq 4 "$(count_calls "$W/calls.jsonl" fetch)" "one fetch per file"
expect_eq 4 "$(receipt_count "$W/receipt.jsonl" fetch_ok)" "fetch_ok receipts"
for f in f1 f2 f3 f4; do
  s=$(sha_of "$FIX/$f")
  expect_file "$W/cache/objects/${s:0:2}/$s" "published object $f"
  expect_eq "$s" "$(sha_of "$W/cache/objects/${s:0:2}/$s")" "object digest $f"
done
# session for each source strictly precedes its first fetch
node -e '
  const lines = require("node:fs").readFileSync(process.argv[1], "utf8").trim().split("\n").map(JSON.parse);
  for (const sid of ["s1", "s2"]) {
    const si = lines.findIndex((l) => l.cmd === "session" && l.source === sid);
    const fi = lines.findIndex((l) => l.cmd === "fetch" && l.source === sid);
    if (si < 0 || fi < 0 || si > fi) { console.error(`session/fetch order broken for ${sid}`); process.exit(1); }
  }
' "$W/calls.jsonl"
ASSERTIONS=$((ASSERTIONS + 1))
# fetches carry the session token issued for their source (2 fetch lines each)
expect_eq 2 "$(grep -c '"session":"sess-s1"' "$W/calls.jsonl")" "fetch uses s1 session"
expect_eq 2 "$(grep -c '"session":"sess-s2"' "$W/calls.jsonl")" "fetch uses s2 session"

# --- 3. bounded concurrency ---------------------------------------------------
W="$TMP/conc"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f1,f2,f3,f4,f5,f6"
MODE=good SLEEP_MS=120 run_campaign "$W" "$W/plan.json" --concurrency 2
expect_eq 0 "$RC" "conc exit"
MAXC=$(node -e '
  const lines = require("node:fs").readFileSync(process.argv[1], "utf8").trim().split("\n").map(JSON.parse)
    .filter((l) => l.cmd === "fetch" && (l.ev === "start" || l.ev === "end"))
    .sort((x, y) => x.ts - y.ts);
  let cur = 0, max = 0;
  for (const l of lines) { cur += l.ev === "start" ? 1 : -1; max = Math.max(max, cur); }
  console.log(max);
' "$W/calls.jsonl")
[ "$MAXC" -le 2 ] || { echo "FAIL concurrency bound: max=$MAXC" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# --- 4. resume: second run touches transport zero times -----------------------
W="$TMP/happy"
LINES_BEFORE=$(wc -l <"$W/receipt.jsonl")
cp "$W/receipt.jsonl" "$W/receipt.before"
: >"$W/calls2.jsonl"
CALL_LOG="$W/calls2.jsonl" MODE=good run_campaign "$W" "$W/plan.json"
expect_eq 0 "$RC" "resume exit"
expect_eq 0 "$(count_calls "$W/calls2.jsonl" session)" "resume: no session"
expect_eq 0 "$(count_calls "$W/calls2.jsonl" fetch)" "resume: no fetch"
expect_eq 4 "$(receipt_count "$W/receipt.jsonl" skip_valid)" "resume: skip_valid receipts"
# receipt is append-only: first run's lines are an untouched prefix
if ! head -n "$LINES_BEFORE" "$W/receipt.jsonl" | cmp -s - "$W/receipt.before"; then
  echo "FAIL: resume rewrote earlier receipt lines" >&2; exit 1
fi
ASSERTIONS=$((ASSERTIONS + 1))
[ "$(wc -l <"$W/receipt.jsonl")" -gt "$LINES_BEFORE" ] || { echo "FAIL: resume appended nothing" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# --- 5. duplicate plan entries download once ----------------------------------
W="$TMP/dup"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f1,f1"
MODE=good run_campaign "$W" "$W/plan.json"
expect_eq 0 "$RC" "dup exit"
expect_eq 1 "$(count_calls "$W/calls.jsonl" fetch)" "duplicate fetched once"
expect_eq 1 "$(receipt_count "$W/receipt.jsonl" duplicate)" "duplicate receipt"

# --- 6. partial/truncated bytes never published, bounded attempts --------------
W="$TMP/part"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f1"
MODE=truncate run_campaign "$W" "$W/plan.json" --max-attempts 2
expect_eq 3 "$RC" "partial exit UNKNOWN"
expect_eq 2 "$(count_calls "$W/calls.jsonl" fetch)" "partial: bounded attempts"
s=$(sha_of "$FIX/f1")
expect_no_file "$W/cache/objects/${s:0:2}/$s" "partial not published"
expect_eq 2 "$(receipt_count "$W/receipt.jsonl" corrupt)" "corrupt receipts"
expect_eq 1 "$(receipt_count "$W/receipt.jsonl" failed)" "failed receipt"

# --- 7. corruption on first attempt recovers within retry budget ---------------
W="$TMP/corr"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f1"
MODE=corrupt_first run_campaign "$W" "$W/plan.json" --max-attempts 3
expect_eq 0 "$RC" "corrupt-recover exit"
expect_eq 2 "$(count_calls "$W/calls.jsonl" fetch)" "corrupt: retry once then good"
expect_eq 1 "$(receipt_count "$W/receipt.jsonl" corrupt)" "corrupt receipt"
s=$(sha_of "$FIX/f1")
expect_eq "$s" "$(sha_of "$W/cache/objects/${s:0:2}/$s")" "recovered object digest"

# --- 8. retryable failures: exactly max-attempts, no storm ---------------------
W="$TMP/retry"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f1"
MODE=fail_retryable run_campaign "$W" "$W/plan.json" --max-attempts 3 --backoff-ms 10
expect_eq 3 "$RC" "retryable exit"
expect_eq 3 "$(count_calls "$W/calls.jsonl" fetch)" "retryable: exactly max attempts"
expect_eq 1 "$(grep -c '"class":"retryable"' "$W/receipt.jsonl")" "retryable class recorded"

# --- 9. deterministic/fatal failures: exactly one attempt ----------------------
W="$TMP/fatal"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f1"
MODE=fail_fatal run_campaign "$W" "$W/plan.json" --max-attempts 3
expect_eq 3 "$RC" "fatal exit"
expect_eq 1 "$(count_calls "$W/calls.jsonl" fetch)" "fatal: single attempt"
expect_eq 1 "$(grep -c '"class":"fatal"' "$W/receipt.jsonl")" "fatal class recorded"

# --- 10. hang is bounded by per-op deadline ------------------------------------
W="$TMP/hang"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f1"
START=$(date +%s)
MODE=hang run_campaign "$W" "$W/plan.json" --max-attempts 2 --op-timeout-ms 300 --backoff-ms 10
ELAPSED=$(( $(date +%s) - START ))
expect_eq 3 "$RC" "hang exit"
expect_eq 2 "$(count_calls "$W/calls.jsonl" fetch)" "hang: bounded attempts"
[ "$ELAPSED" -lt 20 ] || { echo "FAIL: hang not bounded (${ELAPSED}s)" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# --- 11. campaign deadline halts scheduling; later run completes ---------------
W="$TMP/deadline"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f1,f2"
MODE=good run_campaign "$W" "$W/plan.json" --deadline-ms 0
expect_eq 3 "$RC" "deadline exit"
expect_eq 0 "$(count_calls "$W/calls.jsonl" fetch)" "deadline: nothing scheduled"
expect_eq 1 "$(receipt_count "$W/receipt.jsonl" deadline)" "deadline receipt"
MODE=good run_campaign "$W" "$W/plan.json"
expect_eq 0 "$RC" "post-deadline resume completes"
expect_eq 2 "$(receipt_count "$W/receipt.jsonl" fetch_ok)" "post-deadline fetch_ok"

# --- 12. session failure: no fetches, campaign stays open ----------------------
W="$TMP/sess"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f1,f2"
MODE=session_fail run_campaign "$W" "$W/plan.json"
expect_eq 3 "$RC" "session-fail exit"
expect_eq 0 "$(count_calls "$W/calls.jsonl" fetch)" "session-fail: no fetch attempted"
expect_eq 2 "$(grep -c '"class":"session"' "$W/receipt.jsonl")" "session class recorded"

# --- 13. interruption atomicity: crash leaves no published object --------------
W="$TMP/crash"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f1"
MODE=part_then_crash run_campaign "$W" "$W/plan.json" --max-attempts 1
expect_eq 3 "$RC" "crash exit"
s=$(sha_of "$FIX/f1")
expect_no_file "$W/cache/objects/${s:0:2}/$s" "crash: nothing published"
# no stray finalized objects at all — only tmp/.part debris is tolerable
FINALS=$(find "$W/cache/objects" -type f ! -name '*.part' 2>/dev/null | wc -l | tr -d ' ')
expect_eq 0 "$FINALS" "crash: zero finalized objects"
# resume with a healthy transport publishes the real bytes and clears debris
: >"$W/calls.jsonl"
MODE=good run_campaign "$W" "$W/plan.json"
expect_eq 0 "$RC" "post-crash resume exit"
expect_eq "$s" "$(sha_of "$W/cache/objects/${s:0:2}/$s")" "post-crash object digest"
PARTS=$(find "$W/cache" -name '*.part' 2>/dev/null | wc -l | tr -d ' ')
expect_eq 0 "$PARTS" "post-crash: no .part debris"

# --- 14. tampered cache object is re-verified and redownloaded on resume ------
W="$TMP/tamper"; mkdir -p "$W"; : >"$W/calls.jsonl"
mk_plan "$W/plan.json" "s1:f2"
MODE=good run_campaign "$W" "$W/plan.json"
expect_eq 0 "$RC" "tamper: initial run"
s=$(sha_of "$FIX/f2")
printf 'tampered-bytes' >"$W/cache/objects/${s:0:2}/$s"
: >"$W/calls.jsonl"
MODE=good run_campaign "$W" "$W/plan.json"
expect_eq 0 "$RC" "tamper: resume exit"
expect_eq 1 "$(count_calls "$W/calls.jsonl" fetch)" "tamper: redownloaded"
expect_eq "$s" "$(sha_of "$W/cache/objects/${s:0:2}/$s")" "tamper: repaired digest"

echo "PASS test-taste-download-campaign assertions=$ASSERTIONS"
