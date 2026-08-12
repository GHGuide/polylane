#!/usr/bin/env node
// taste-download-campaign.mjs — resumable selected-file download campaign for
// the download-campaign lane.
//
// The campaign wraps a pluggable transport executable (in production the
// dataverse-transport lane's browser/CDP adapter; in tests a hermetic fake).
// Per source it establishes exactly one fresh transport session, and only
// after that session is valid does it fan out file fetches with bounded
// concurrency. Downloaded bytes are verified against declared size, declared
// md5, and expected SHA-256, then atomically published (.part + rename) into a
// content-addressed cache. Every event lands in an append-only JSONL receipt;
// a rerun skips objects that re-verify and never redownloads them. Retries are
// classified (retryable vs fatal vs corrupt) and strictly bounded — no retry
// storm, no unbounded queue. Failure to complete is exit 3 (open), never a
// fixture PASS.
//
// Transport contract (executable, JSON status on stdout):
//   <transport> session --source <id> --pid <pid>
//     -> {"status":"OK","session":"<token>"} | {"status":"RETRYABLE"|"FATAL",...}
//   <transport> fetch --session <token> --source <id> --pid <pid> --file <id> --out <path>
//     -> writes bytes to <path>; {"status":"OK"} | {"status":"RETRYABLE"|"FATAL","reason":...}
//   Crash, missing/garbled status, or per-op timeout classify as retryable.
//
// Usage:
//   node taste-download-campaign.mjs --selftest
//   node taste-download-campaign.mjs run --plan <plan.json> --cache <dir> \
//     --receipt <file.jsonl> --transport <executable> \
//     [--concurrency 3] [--max-attempts 3] [--op-timeout-ms 120000] \
//     [--backoff-ms 500] [--deadline-ms <total>]

import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import {
  appendFileSync, existsSync, mkdirSync, readFileSync, readdirSync,
  renameSync, unlinkSync, writeFileSync,
} from 'node:fs';
import { join } from 'node:path';

// ---- pure helpers (hermetic, selftested) -----------------------------------

export function sha256Hex(buf) {
  return createHash('sha256').update(buf).digest('hex');
}

export function md5Hex(buf) {
  return createHash('md5').update(buf).digest('hex');
}

// Content-addressed path; sha is validated so it can never traverse.
export function contentAddressPath(cacheDir, sha) {
  if (!/^[0-9a-f]{64}$/.test(sha)) throw new Error(`invalid sha256: ${sha}`);
  return join(cacheDir, 'objects', sha.slice(0, 2), sha);
}

// Validate + normalize the selected-file plan. Fail closed on shape errors.
export function parsePlan(json) {
  const obj = typeof json === 'string' ? JSON.parse(json) : json;
  if (!obj || !Array.isArray(obj.sources)) throw new Error('plan: missing sources[]');
  const sources = obj.sources.map((s, i) => {
    if (!s.source_id || !s.pid) throw new Error(`plan: source[${i}] needs source_id and pid`);
    if (!Array.isArray(s.files) || s.files.length === 0) throw new Error(`plan: source ${s.source_id} has no files`);
    const files = s.files.map((f) => {
      if (!f.file_id) throw new Error(`plan: file without file_id in ${s.source_id}`);
      if (f.sha256 != null && !/^[0-9a-f]{64}$/.test(f.sha256)) throw new Error(`plan: bad sha256 for ${f.file_id}`);
      return {
        file_id: String(f.file_id),
        filename: f.filename ?? null,
        declared_size: f.declared_size ?? null,
        declared_md5: f.declared_md5 ? String(f.declared_md5).toLowerCase() : null,
        sha256: f.sha256 ?? null,
      };
    });
    return { source_id: String(s.source_id), pid: String(s.pid), files };
  });
  return { run: obj.run ?? null, sources };
}

// Flatten plan into work items; later entries repeating a file_id (or a known
// expected sha) are duplicates — downloaded once, receipted, never re-queued.
export function dedupeSelections(sources) {
  const items = [];
  const duplicates = [];
  const byFile = new Map();
  const bySha = new Map();
  for (const s of sources) {
    for (const f of s.files) {
      const dupOf = byFile.get(f.file_id) ?? (f.sha256 ? bySha.get(f.sha256) : undefined);
      if (dupOf !== undefined) {
        duplicates.push({ source_id: s.source_id, file_id: f.file_id, dup_of: dupOf });
        continue;
      }
      byFile.set(f.file_id, f.file_id);
      if (f.sha256) bySha.set(f.sha256, f.file_id);
      items.push({ source_id: s.source_id, pid: s.pid, ...f });
    }
  }
  return { items, duplicates };
}

// Classify one transport invocation. Deterministic source errors are fatal and
// never retried; crashes, timeouts, and garbled output are bounded-retryable.
export function classifyOutcome({ timedOut, code, stdout }) {
  if (timedOut) return { cls: 'retryable', reason: 'op timeout' };
  let msg = null;
  try { msg = JSON.parse(String(stdout).trim().split('\n').pop()); } catch { /* garbled */ }
  if (!msg || typeof msg.status !== 'string') {
    return { cls: 'retryable', reason: `transport crash (exit ${code}, no status)` };
  }
  if (msg.status === 'OK') return { cls: 'ok', msg };
  if (msg.status === 'FATAL') return { cls: 'fatal', reason: msg.reason ?? 'fatal' };
  return { cls: 'retryable', reason: msg.reason ?? msg.status };
}

// Verify downloaded bytes against every declared identity we have.
export function verifyBytes(buf, decl) {
  if (decl.declared_size != null && buf.length !== decl.declared_size) {
    return { ok: false, reason: `size mismatch: declared ${decl.declared_size} got ${buf.length}` };
  }
  if (decl.declared_md5 && md5Hex(buf) !== decl.declared_md5) {
    return { ok: false, reason: 'md5 mismatch vs declared checksum' };
  }
  const sha = sha256Hex(buf);
  if (decl.sha256 && sha !== decl.sha256) {
    return { ok: false, reason: `sha256 mismatch: expected ${decl.sha256} got ${sha}`, sha };
  }
  return { ok: true, sha };
}

// Recover file_id -> sha256 bindings from prior fetch_ok receipt lines, so a
// resume can re-verify cached objects even when the plan carries no sha.
export function validShaFromReceipt(text) {
  const map = new Map();
  for (const line of String(text).split('\n')) {
    if (!line.trim()) continue;
    let e; try { e = JSON.parse(line); } catch { continue; }
    if (e.t === 'fetch_ok' && e.file_id && /^[0-9a-f]{64}$/.test(e.sha256 || '')) {
      map.set(e.file_id, e.sha256);
    }
  }
  return map;
}

// ---- runtime ---------------------------------------------------------------

function makeReceipt(path) {
  return (obj) => appendFileSync(path, `${JSON.stringify({ ...obj, ts: new Date().toISOString() })}\n`);
}

// Remove stale atomic-publish debris from interrupted runs. Only our own
// *.part temp names are touched; finalized objects are never deleted.
function cleanParts(cacheDir) {
  const objects = join(cacheDir, 'objects');
  if (!existsSync(objects)) return;
  const walk = (dir) => {
    for (const name of readdirSync(dir, { withFileTypes: true })) {
      const p = join(dir, name.name);
      if (name.isDirectory()) walk(p);
      else if (name.name.endsWith('.part')) unlinkSync(p);
    }
  };
  walk(objects);
}

// A cached object is valid iff its recomputed digest and declared size match.
function objectIsValid(cacheDir, sha, decl) {
  const p = contentAddressPath(cacheDir, sha);
  if (!existsSync(p)) return false;
  const buf = readFileSync(p);
  if (sha256Hex(buf) !== sha) return false;
  return verifyBytes(buf, decl).ok;
}

function runTransport(cmd, args, timeoutMs) {
  return new Promise((resolve) => {
    const proc = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    let timedOut = false;
    proc.stdout.on('data', (d) => { stdout += d; });
    proc.stderr.resume();
    const t = setTimeout(() => { timedOut = true; proc.kill('SIGKILL'); }, timeoutMs);
    proc.on('error', () => { clearTimeout(t); resolve({ timedOut, code: -1, stdout }); });
    proc.on('close', (code) => { clearTimeout(t); resolve({ timedOut, code, stdout }); });
  });
}

// Fixed-size worker pool: the queue is exactly the selected pending items —
// nothing is ever re-enqueued beyond an item's own bounded attempts.
async function runPool(items, n, fn) {
  let next = 0;
  const worker = async () => {
    while (next < items.length) {
      const item = items[next++];
      await fn(item);
    }
  };
  await Promise.all(Array.from({ length: Math.max(1, n) }, worker));
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function fetchOne(item, ctx) {
  const { opts, receipt, session, counters } = ctx;
  for (let attempt = 1; attempt <= opts.maxAttempts; attempt++) {
    if (ctx.pastDeadline()) { counters.remaining.push(item.file_id); return; }
    receipt({ t: 'attempt', file_id: item.file_id, n: attempt });
    const tmp = join(opts.cache, 'objects', `tmp-${process.pid}-${counters.seq++}.part`);
    const res = await runTransport(opts.transport, [
      'fetch', '--session', session, '--source', item.source_id,
      '--pid', item.pid, '--file', item.file_id, '--out', tmp,
    ], opts.opTimeoutMs);
    const outcome = classifyOutcome(res);

    if (outcome.cls === 'ok') {
      let buf = null;
      if (existsSync(tmp)) { buf = readFileSync(tmp); unlinkSync(tmp); }
      const v = buf ? verifyBytes(buf, item) : { ok: false, reason: 'transport reported OK but wrote no bytes' };
      if (v.ok) {
        const dest = contentAddressPath(opts.cache, v.sha);
        mkdirSync(join(opts.cache, 'objects', v.sha.slice(0, 2)), { recursive: true });
        const part = `${dest}.part`;
        writeFileSync(part, buf);
        renameSync(part, dest); // atomic publish: full bytes or nothing, repairs tampered objects
        receipt({ t: 'fetch_ok', file_id: item.file_id, sha256: v.sha, bytes: buf.length, attempts: attempt });
        counters.ok++;
        return;
      }
      receipt({ t: 'corrupt', file_id: item.file_id, reason: v.reason, got_sha256: v.sha ?? null });
      if (attempt === opts.maxAttempts) {
        receipt({ t: 'failed', file_id: item.file_id, class: 'corrupt', reason: v.reason, attempts: attempt });
        counters.failed++;
        return;
      }
      continue; // corrupt bytes count against the same bounded attempt budget
    }

    if (existsSync(tmp)) unlinkSync(tmp);
    if (outcome.cls === 'fatal') {
      receipt({ t: 'failed', file_id: item.file_id, class: 'fatal', reason: outcome.reason, attempts: attempt });
      counters.failed++;
      return;
    }
    if (attempt === opts.maxAttempts) {
      receipt({ t: 'failed', file_id: item.file_id, class: 'retryable', reason: outcome.reason, attempts: attempt });
      counters.failed++;
      return;
    }
    await sleep(opts.backoffMs * attempt);
  }
}

async function runCampaign(opts) {
  const planText = readFileSync(opts.plan, 'utf8');
  const plan = parsePlan(planText);
  const receipt = makeReceipt(opts.receipt);
  mkdirSync(join(opts.cache, 'objects'), { recursive: true });
  cleanParts(opts.cache);
  receipt({ t: 'campaign_start', run: plan.run, plan_sha256: sha256Hex(Buffer.from(planText)) });

  const priorShas = existsSync(opts.receipt) ? validShaFromReceipt(readFileSync(opts.receipt, 'utf8')) : new Map();
  const { items, duplicates } = dedupeSelections(plan.sources);
  for (const d of duplicates) receipt({ t: 'duplicate', ...d });

  const started = Date.now();
  const pastDeadline = () => opts.deadlineMs != null && Date.now() - started > opts.deadlineMs;
  const counters = { ok: 0, skipped: 0, failed: 0, remaining: [], seq: 0 };

  // Resume: an object that re-verifies is never redownloaded.
  const pendingBySource = new Map();
  for (const item of items) {
    const sha = item.sha256 ?? priorShas.get(item.file_id) ?? null;
    if (sha && objectIsValid(opts.cache, sha, item)) {
      receipt({ t: 'skip_valid', file_id: item.file_id, sha256: sha });
      counters.skipped++;
      continue;
    }
    if (!pendingBySource.has(item.source_id)) pendingBySource.set(item.source_id, []);
    pendingBySource.get(item.source_id).push(item);
  }

  // One fresh transport session per source; concurrency only after it is valid.
  for (const source of plan.sources) {
    const pending = pendingBySource.get(source.source_id) || [];
    if (pending.length === 0) continue;
    if (pastDeadline()) { counters.remaining.push(...pending.map((i) => i.file_id)); continue; }
    const res = await runTransport(opts.transport, [
      'session', '--source', source.source_id, '--pid', source.pid,
    ], opts.opTimeoutMs);
    const outcome = classifyOutcome(res);
    receipt({ t: 'session', source_id: source.source_id, status: outcome.cls === 'ok' ? 'OK' : outcome.reason });
    if (outcome.cls !== 'ok') {
      for (const item of pending) {
        receipt({ t: 'failed', file_id: item.file_id, class: 'session', reason: outcome.reason });
        counters.failed++;
      }
      continue;
    }
    const session = String(outcome.msg.session ?? '');
    await runPool(pending, opts.concurrency, (item) => fetchOne(item, { opts, receipt, session, counters, pastDeadline }));
  }

  if (counters.remaining.length > 0) {
    receipt({ t: 'deadline', remaining: counters.remaining });
  }
  const summary = {
    t: 'done', ok: counters.ok, skipped: counters.skipped,
    duplicates: duplicates.length, failed: counters.failed, remaining: counters.remaining.length,
  };
  receipt(summary);
  const complete = counters.failed === 0 && counters.remaining.length === 0;
  console.log(JSON.stringify({ status: complete ? 'OK' : 'UNKNOWN', ...summary }));
  process.exit(complete ? 0 : 3);
}

// ---- selftest ----------------------------------------------------------------

function selftest() {
  let n = 0;
  const ok = (cond, msg) => { if (!cond) { console.error(`SELFTEST-FAIL: ${msg}`); process.exit(1); } n++; };
  const throws = (fn) => { try { fn(); return false; } catch { return true; } };

  const bytes = Buffer.from('campaign bytes');
  const sha = sha256Hex(bytes);
  ok(/^[0-9a-f]{64}$/.test(sha), 'sha256 shape');
  ok(/^[0-9a-f]{32}$/.test(md5Hex(bytes)), 'md5 shape');
  ok(contentAddressPath('/c', sha).endsWith(`/objects/${sha.slice(0, 2)}/${sha}`), 'content-address path');
  ok(throws(() => contentAddressPath('/c', '../../etc/passwd')), 'content-address rejects traversal');

  ok(throws(() => parsePlan('{}')), 'plan rejects missing sources');
  ok(throws(() => parsePlan({ sources: [{ source_id: 's', pid: 'p', files: [] }] })), 'plan rejects empty files');
  ok(throws(() => parsePlan({ sources: [{ source_id: 's', pid: 'p', files: [{ file_id: 'f', sha256: 'nope' }] }] })), 'plan rejects bad sha');
  const plan = parsePlan({ run: 'r', sources: [{ source_id: 's', pid: 'p', files: [{ file_id: 'f', declared_md5: 'ABC' }] }] });
  ok(plan.sources[0].files[0].declared_md5 === 'abc', 'plan lowercases md5');

  const { items, duplicates } = dedupeSelections([
    { source_id: 's1', pid: 'p', files: [{ file_id: 'a', sha256: sha }, { file_id: 'a' }] },
    { source_id: 's2', pid: 'p', files: [{ file_id: 'b', sha256: sha }] },
  ]);
  ok(items.length === 1 && duplicates.length === 2, 'dedupe by file_id and sha');
  ok(duplicates.every((d) => d.dup_of === 'a'), 'duplicates point at original');

  ok(classifyOutcome({ timedOut: true, code: null, stdout: '' }).cls === 'retryable', 'timeout is retryable');
  ok(classifyOutcome({ timedOut: false, code: 1, stdout: 'garbage' }).cls === 'retryable', 'crash is retryable');
  ok(classifyOutcome({ timedOut: false, code: 0, stdout: '{"status":"OK"}' }).cls === 'ok', 'ok status');
  ok(classifyOutcome({ timedOut: false, code: 0, stdout: '{"status":"FATAL","reason":"404"}' }).cls === 'fatal', 'fatal status');
  ok(classifyOutcome({ timedOut: false, code: 0, stdout: '{"status":"RETRYABLE"}' }).cls === 'retryable', 'retryable status');

  ok(verifyBytes(bytes, { declared_size: bytes.length, declared_md5: md5Hex(bytes), sha256: sha }).ok, 'verify ok');
  ok(!verifyBytes(bytes, { declared_size: bytes.length + 1 }).ok, 'verify catches size');
  ok(!verifyBytes(bytes, { declared_md5: md5Hex(Buffer.from('x')) }).ok, 'verify catches md5');
  ok(!verifyBytes(bytes, { sha256: sha256Hex(Buffer.from('x')) }).ok, 'verify catches sha');

  const map = validShaFromReceipt(`{"t":"fetch_ok","file_id":"a","sha256":"${sha}"}\n{"t":"corrupt","file_id":"b"}\nnot json\n`);
  ok(map.get('a') === sha && !map.has('b'), 'receipt sha recovery');

  console.log(`SELFTEST-OK n=${n}`);
}

// ---- main --------------------------------------------------------------------

function parseArgs(argv) {
  const o = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) { o[argv[i].slice(2)] = argv[i + 1]?.startsWith('--') || argv[i + 1] === undefined ? true : argv[++i]; }
  }
  return o;
}

async function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  if (cmd === '--selftest') return selftest();
  if (cmd !== 'run') {
    console.error('usage: taste-download-campaign.mjs --selftest | run --plan <json> --cache <dir> --receipt <jsonl> --transport <exe> [...]');
    process.exit(2);
  }
  const a = parseArgs(rest);
  for (const req of ['plan', 'cache', 'receipt', 'transport']) {
    if (!a[req] || a[req] === true) { console.error(`run requires --${req}`); process.exit(2); }
  }
  const opts = {
    plan: a.plan,
    cache: a.cache,
    receipt: a.receipt,
    transport: a.transport,
    concurrency: Number(a.concurrency ?? 3),
    maxAttempts: Number(a['max-attempts'] ?? 3),
    opTimeoutMs: Number(a['op-timeout-ms'] ?? 120000),
    backoffMs: Number(a['backoff-ms'] ?? 500),
    deadlineMs: a['deadline-ms'] !== undefined ? Number(a['deadline-ms']) : null,
  };
  try {
    await runCampaign(opts);
  } catch (e) {
    console.log(JSON.stringify({ status: 'UNKNOWN', reason: `campaign error: ${e.message}` }));
    process.exit(3);
  }
}

main();
