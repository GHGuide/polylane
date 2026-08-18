#!/usr/bin/env node
// dataverse-acquire.mjs — explicit external browser adapter for the source-live lane.
//
// The Bash 3.2 core (bin/polylane-taste-source.sh) is hermetic and never touches
// the network. This Node adapter is the ONLY component that warms a real Chrome
// context and performs same-context Harvard Dataverse API access, because Dataverse
// sits behind a WAF that blocks bare API clients. A missing Chrome, missing network,
// or a WAF challenge yields a structured UNKNOWN receipt and a non-zero exit — never
// a fixture PASS. Pure helpers are unit-tested hermetically via `--selftest`.
//
// Usage:
//   node dataverse-acquire.mjs --selftest
//   node dataverse-acquire.mjs discover --pid <doi> --cache <dir> [--base <url>]
//   node dataverse-acquire.mjs fetch --pid <doi> --file <id> --cache <dir> [--sha256 <hex>] [--base <url>]

import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, readFileSync, existsSync, renameSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const DEFAULT_BASE = 'https://dataverse.harvard.edu';

// ---- pure helpers (hermetic, no I/O beyond the cache) ---------------------

export function sha256Hex(buf) {
  return createHash('sha256').update(buf).digest('hex');
}

// Content-addressed path under a caller-supplied cache root. The sha is validated
// so it can never contain a path separator or traversal segment.
export function contentAddressPath(cacheDir, sha) {
  if (!/^[0-9a-f]{64}$/.test(sha)) throw new Error(`invalid sha256: ${sha}`);
  return join(cacheDir, 'objects', sha.slice(0, 2), sha);
}

// A Dataverse WAF challenge is a hard block, not source data. Detect it so we can
// fail closed instead of caching a challenge page as if it were a datafile.
export function detectWaf(status, headers, bodyText) {
  const h = Object.fromEntries(
    Object.entries(headers || {}).map(([k, v]) => [String(k).toLowerCase(), String(v)]),
  );
  // 202/503 are Akamai's "under attack" interstitials for a GET that should be 200.
  if ([202, 403, 406, 429, 503].includes(status)) return true;
  const server = h['server'] || '';
  if (/akamai|awselb|cloudflare|mod_security/i.test(server)) {
    if (status >= 400) return true;
  }
  const body = String(bodyText || '');
  if (/access denied|reference #\d|request blocked|attention required|__cf_|akamai/i.test(body)) {
    // Only treat as WAF when the payload is not the JSON API envelope we expect.
    if (!/^\s*[[{]/.test(body)) return true;
  }
  return false;
}

// Normalize a Dataverse tabular aggregate export (CSV) to the join shape the Bash
// core consumes: { stimulus_id: { domain, mean_rating } }.
export function normalizeAggregateCsv(text) {
  const rows = parseCsv(text);
  const out = {};
  for (const r of rows) {
    const id = r.stimulus_id;
    if (!id) continue;
    const mean = Number(r.mean_rating);
    if (!Number.isFinite(mean)) throw new Error(`non-numeric mean_rating for ${id}`);
    out[id] = { domain: String(r.domain || '').trim(), mean_rating: mean };
  }
  return out;
}

// Normalize per-participant raw ratings (CSV) to { stimulus_id: [rating, ...] }.
export function normalizeRawCsv(text) {
  const rows = parseCsv(text);
  const out = {};
  for (const r of rows) {
    const id = r.stimulus_id;
    if (!id) continue;
    const v = Number(r.rating);
    if (!Number.isFinite(v)) throw new Error(`non-numeric rating for ${id}`);
    (out[id] ||= []).push(v);
  }
  return out;
}

// Map any live failure onto the frozen taxonomy so receipts are machine-checkable:
// 'challenge' (WAF/CAPTCHA — stays UNKNOWN), 'timeout' (deadline fired), 'redirect'
// (cross-origin redirect the transport could not follow), 'checksum' (bytes arrived
// but do not match the declared digest), 'transport' (everything else: no binary,
// spawn/CDP/socket failure).
export function classifyFailure(e) {
  const known = ['challenge', 'timeout', 'redirect', 'transport', 'checksum'];
  if (e && known.includes(e.class)) return e.class;
  const msg = String(e?.message || e || '');
  if (e?.waf || /challenge|captcha|access denied/i.test(msg)) return 'challenge';
  if (/timed out|timeout/i.test(msg)) return 'timeout';
  if (/checksum mismatch/i.test(msg)) return 'checksum';
  if (/redirect/i.test(msg)) return 'redirect';
  return 'transport';
}

// Observed readiness: the WAF is considered cleared only when a probe of the
// Dataverse JSON API returns HTTP 200 with a parseable {"status":"OK"} envelope.
export function isReadyEnvelope(status, bodyText) {
  if (status !== 200) return false;
  try {
    const obj = JSON.parse(String(bodyText || ''));
    return obj?.status === 'OK';
  } catch {
    return false;
  }
}

// Extract version + file list (id, md5, filename) from a Dataverse dataset
// metadata JSON envelope.
export function parseDatasetMetadata(json) {
  const obj = typeof json === 'string' ? JSON.parse(json) : json;
  const v = obj?.data?.latestVersion || obj?.data || {};
  const version = [v.versionNumber, v.versionMinorNumber].filter((x) => x != null).join('.') || null;
  const files = (v.files || []).map((f) => {
    const df = f.dataFile || {};
    return {
      id: String(df.id ?? f.id ?? ''),
      filename: df.filename ?? f.label ?? '',
      md5: (df.md5 ?? df.checksum?.value ?? '').toLowerCase(),
    };
  });
  return { version, files };
}

// Minimal RFC-4180-ish CSV parser: first row is the header. Handles quoted fields
// and embedded commas/newlines. Enough for Dataverse tabular exports.
function parseCsv(text) {
  const fields = [];
  const rows = [];
  let cur = '';
  let inQ = false;
  const s = String(text).replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (inQ) {
      if (c === '"') {
        if (s[i + 1] === '"') { cur += '"'; i++; } else inQ = false;
      } else cur += c;
    } else if (c === '"') inQ = true;
    else if (c === ',') { fields.push(cur); cur = ''; }
    else if (c === '\n') { fields.push(cur); rows.push(fields.splice(0)); cur = ''; }
    else cur += c;
  }
  if (cur.length || fields.length) { fields.push(cur); rows.push(fields.splice(0)); }
  const nonEmpty = rows.filter((r) => r.length > 1 || (r.length === 1 && r[0] !== ''));
  if (nonEmpty.length === 0) return [];
  const header = nonEmpty[0].map((h) => h.trim());
  return nonEmpty.slice(1).map((r) => {
    const o = {};
    header.forEach((h, idx) => { o[h] = r[idx]; });
    return o;
  });
}

// ---- live Chrome (guarded; failure => UNKNOWN) ----------------------------

function chromeBinary() {
  if (process.env.CHROME_BIN) return process.env.CHROME_BIN;
  const candidates = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ];
  return candidates.find((p) => existsSync(p)) || null;
}

// Launch a fresh ephemeral headless Chrome (never a personal profile), hand a live
// CDP browser session to `fn`, and always kill the browser afterwards. Every step
// inside is bounded by the caller's withTimeout deadline; there is no fixed warm-up.
async function withChrome(fn) {
  const bin = chromeBinary();
  if (!bin) { const e = new Error('no Chrome binary (set CHROME_BIN)'); e.class = 'transport'; throw e; }
  if (typeof WebSocket === 'undefined') { const e = new Error('node WebSocket global unavailable'); e.class = 'transport'; throw e; }
  const udd = join(tmpdir(), `dv-chrome-${process.pid}-${Date.now()}`);
  const dlDir = join(udd, 'downloads');
  mkdirSync(dlDir, { recursive: true });
  const proc = spawn(bin, [
    '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
    `--user-data-dir=${udd}`, '--remote-debugging-port=0', 'about:blank',
  ], { stdio: 'ignore' });
  const cleanup = () => { try { proc.kill('SIGKILL'); } catch { /* ignore */ } };
  process.on('exit', cleanup); // unknown() exits the process; never leak a browser
  let spawnErr = null;
  proc.on('error', (err) => { spawnErr = err; });
  try {
    const portFile = join(udd, 'DevToolsActivePort');
    let port = null;
    // Deliberately unbounded: the caller's withTimeout deadline is the only clock,
    // so a Chrome that never opens DevTools classifies as 'timeout' while a binary
    // that fails to spawn classifies as 'transport'.
    while (port == null) {
      if (spawnErr) { const e = new Error(`Chrome launch failed: ${spawnErr.message}`); e.class = 'transport'; throw e; }
      await sleep(100);
      if (existsSync(portFile)) port = readFileSync(portFile, 'utf8').split('\n')[0].trim();
    }
    const ver = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json();
    const ws = new WebSocket(ver.webSocketDebuggerUrl);
    await new Promise((res, rej) => {
      ws.addEventListener('open', res);
      ws.addEventListener('error', () => { const e = new Error('cdp websocket error'); e.class = 'transport'; rej(e); });
    });
    const eventListeners = new Set();
    ws.addEventListener('message', (ev) => {
      let m; try { m = JSON.parse(ev.data); } catch { return; }
      if (m.method) for (const l of eventListeners) l(m);
    });
    let seq = 1;
    const send = (method, params, sessionId) => new Promise((resolve, reject) => {
      const id = seq++;
      const onMsg = (ev) => {
        let m; try { m = JSON.parse(ev.data); } catch { return; }
        if (m.id === id) { ws.removeEventListener('message', onMsg); m.error ? reject(new Error(m.error.message)) : resolve(m.result); }
      };
      ws.addEventListener('message', onMsg);
      ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
    });
    try {
      return await fn({ send, eventListeners, dlDir });
    } finally { try { ws.close(); } catch { /* ignore */ } }
  } finally {
    cleanup();
  }
}

// In-page same-origin fetch through an attached page session. Returns
// { status, server, bytes }. Used for readiness probes and JSON metadata only;
// redirected binary data files go through the CDP download path instead.
async function pageFetch(send, sessionId, url) {
  const expr = `(async () => {
    const r = await fetch(${JSON.stringify(url)}, { credentials: 'same-origin' });
    const b = new Uint8Array(await r.arrayBuffer());
    let s = ''; for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
    return JSON.stringify({ status: r.status, server: r.headers.get('server') || '', b64: btoa(s) });
  })()`;
  const res = await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true }, sessionId);
  if (res.exceptionDetails) {
    const e = new Error(`in-page fetch failed: ${res.exceptionDetails.exception?.description || res.exceptionDetails.text || 'exception'}`);
    e.class = 'transport';
    throw e;
  }
  const parsed = JSON.parse(res.result.value);
  return { status: parsed.status, server: parsed.server, bytes: Buffer.from(parsed.b64, 'base64') };
}

// Observed JSON readiness: poll the Dataverse version endpoint until the WAF clears
// and a valid {"status":"OK"} envelope is observed. No magic warm-up delay; the
// caller's withTimeout deadline bounds the poll, so a persistent challenge ends as
// a bounded UNKNOWN instead of a guessed sleep.
async function waitForReadiness(send, sessionId, base) {
  const probe = `${base}/api/info/version`;
  for (;;) {
    try {
      const r = await pageFetch(send, sessionId, probe);
      if (isReadyEnvelope(r.status, r.bytes.toString('utf8'))) return;
    } catch { /* page still settling or challenge in flight; keep observing */ }
    await sleep(500);
  }
}

// Open a fresh tab on `base`, wait for observed readiness, then run `fn(pageCtx)`.
async function withReadyPage(base, fn) {
  return withChrome(async ({ send, eventListeners, dlDir }) => {
    const { targetId } = await send('Target.createTarget', { url: base });
    const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
    await send('Page.enable', {}, sessionId);
    await waitForReadiness(send, sessionId, base);
    return fn({ send, sessionId, eventListeners, dlDir });
  });
}

// Fetch a same-origin JSON API URL from the warmed page context.
async function fetchJsonSameOrigin(base, url) {
  return withReadyPage(base, async ({ send, sessionId }) => {
    const r = await pageFetch(send, sessionId, url);
    if (detectWaf(r.status, { server: r.server }, r.bytes.toString('utf8').slice(0, 512))) {
      const e = new Error(`WAF challenge (status ${r.status})`);
      e.class = 'challenge'; e.waf = true;
      throw e;
    }
    if (r.status !== 200) { const e = new Error(`unexpected status ${r.status}`); e.class = 'transport'; throw e; }
    return r.bytes;
  });
}

// Download a (possibly cross-origin redirected) data file through the browser's own
// download pipeline. Browser.setDownloadBehavior names the file by GUID inside the
// ephemeral profile and Browser.downloadProgress events signal completion, so the
// object-store redirect is followed natively by Chrome inside the same fresh
// ephemeral WAF-cleared session — no session material is read, logged, or copied.
async function downloadDatafile(base, url) {
  return withReadyPage(base, async ({ send, sessionId, eventListeners, dlDir }) => {
    await send('Browser.setDownloadBehavior', { behavior: 'allowAndName', downloadPath: dlDir, eventsEnabled: true });
    const done = new Promise((resolve, reject) => {
      let guid = null;
      eventListeners.add((m) => {
        if (m.method === 'Browser.downloadWillBegin') guid = m.params.guid;
        if (m.method === 'Browser.downloadProgress' && (guid === null || m.params.guid === guid)) {
          if (m.params.state === 'completed') resolve(m.params.guid);
          if (m.params.state === 'canceled') {
            const e = new Error('download canceled mid-redirect by browser');
            e.class = 'redirect';
            reject(e);
          }
        }
      });
    });
    // Navigating to an attachment URL starts the download; a navigation error
    // (net::ERR_ABORTED) is the normal signal that it became a download.
    await send('Page.navigate', { url }, sessionId).catch(() => ({}));
    // If no download begins and a page renders instead, inspect it exactly once:
    // a WAF interstitial is a 'challenge'; anything else keeps waiting for the
    // download until the bounded deadline classifies it as 'timeout'.
    const challengeProbe = (async () => {
      await sleep(2000);
      const res = await send('Runtime.evaluate', {
        expression: 'document.documentElement ? document.documentElement.outerHTML.slice(0, 2048) : ""',
        returnByValue: true,
      }, sessionId).catch(() => null);
      const html = res?.result?.value || '';
      if (/access denied|reference #|request blocked|attention required|captcha/i.test(html)) {
        const e = new Error('WAF challenge page instead of datafile');
        e.class = 'challenge'; e.waf = true;
        throw e;
      }
      return new Promise(() => {}); // inconclusive page; keep waiting on the download
    })();
    const guid = await Promise.race([done, challengeProbe]);
    return readFileSync(join(dlDir, guid));
  });
}

function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

// Hard bound on any live operation so a black-hole network can never hang the
// canary. Default 30s; override with POLYLANE_SOURCE_CANARY_TIMEOUT_MS.
function withTimeout(promise, label) {
  const ms = Number(process.env.POLYLANE_SOURCE_CANARY_TIMEOUT_MS || 30000);
  let t;
  const timeout = new Promise((_, rej) => { t = setTimeout(() => rej(new Error(`${label} timed out after ${ms}ms`)), ms); });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(t));
}

function storeObject(cacheDir, bytes) {
  const sha = sha256Hex(bytes);
  const p = contentAddressPath(cacheDir, sha);
  mkdirSync(join(cacheDir, 'objects', sha.slice(0, 2)), { recursive: true });
  const tmp = `${p}.part`;
  writeFileSync(tmp, bytes);
  renameSync(tmp, p); // atomic publish — no partial object at the final path
  return sha;
}

function unknown(reason, extra = {}) {
  console.log(JSON.stringify({ status: 'UNKNOWN', reason, ...extra }));
  process.exit(3);
}

function parseArgs(argv) {
  const o = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) { o[argv[i].slice(2)] = argv[i + 1]?.startsWith('--') || argv[i + 1] === undefined ? true : argv[++i]; }
  }
  return o;
}

// ---- selftest -------------------------------------------------------------

function selftest() {
  let n = 0;
  const ok = (cond, msg) => { if (!cond) { console.error(`SELFTEST-FAIL: ${msg}`); process.exit(1); } n++; };

  const bytes = Buffer.from('hello taste');
  const sha = sha256Hex(bytes);
  ok(/^[0-9a-f]{64}$/.test(sha), 'sha256 shape');
  ok(contentAddressPath('/c', sha).endsWith(`/objects/${sha.slice(0, 2)}/${sha}`), 'content-address path');
  let threw = false;
  try { contentAddressPath('/c', '../../etc/passwd'); } catch { threw = true; }
  ok(threw, 'content-address rejects traversal');

  ok(detectWaf(403, { server: 'AkamaiGHost' }, 'Access Denied Reference #18.abc'), 'waf on 403');
  ok(detectWaf(202, {}, '') && detectWaf(503, {}, ''), 'waf on 202/503 interstitial');
  ok(detectWaf(200, { server: 'AkamaiGHost' }, '<html>Attention Required</html>'), 'waf on challenge body');
  ok(!detectWaf(200, { server: 'Apache' }, '{"status":"OK"}'), 'no waf on json 200');

  const agg = normalizeAggregateCsv('stimulus_id,domain,mean_rating\nc-1,consumer,4.2\nc-2,consumer,3.1\n');
  ok(agg['c-1'].domain === 'consumer' && agg['c-1'].mean_rating === 4.2, 'aggregate parse');
  const raw = normalizeRawCsv('stimulus_id,participant,rating\nc-1,p1,4\nc-1,p2,5\nc-1,p3,4\n');
  ok(raw['c-1'].length === 3 && raw['c-1'][1] === 5, 'raw parse');

  const meta = parseDatasetMetadata({ data: { latestVersion: { versionNumber: 2, versionMinorNumber: 0, files: [{ dataFile: { id: 42, filename: 'agg.tab', md5: 'ABC123' } }] } } });
  ok(meta.version === '2.0' && meta.files[0].id === '42' && meta.files[0].md5 === 'abc123', 'metadata parse');

  ok(classifyFailure({ waf: true, message: 'WAF challenge (status 202)' }) === 'challenge', 'classify challenge');
  ok(classifyFailure(new Error('discover timed out after 1500ms')) === 'timeout', 'classify timeout');
  ok(classifyFailure(new Error('checksum mismatch: expected a got b')) === 'checksum', 'classify checksum');
  ok(classifyFailure(new Error('cross-origin redirect blocked in-page fetch')) === 'redirect', 'classify redirect');
  ok(classifyFailure(new Error('spawn ENOENT')) === 'transport', 'classify transport default');
  const tagged = new Error('download canceled'); tagged.class = 'redirect';
  ok(classifyFailure(tagged) === 'redirect', 'classify honors explicit tag');

  ok(isReadyEnvelope(200, '{"status":"OK","data":{"version":"6.8"}}'), 'ready on OK envelope');
  ok(!isReadyEnvelope(202, '{"status":"OK"}'), 'not ready on 202');
  ok(!isReadyEnvelope(200, '<html>Attention Required</html>'), 'not ready on challenge html');
  ok(!isReadyEnvelope(200, '{"status":"ERROR"}'), 'not ready on error envelope');

  console.log(`SELFTEST-OK n=${n}`);
}

// ---- main -----------------------------------------------------------------

async function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  if (cmd === '--selftest') return selftest();
  const a = parseArgs(rest);
  const base = a.base || DEFAULT_BASE;

  if (cmd === 'discover') {
    if (!a.pid || !a.cache) return unknown('discover requires --pid and --cache');
    try {
      const url = `${base}/api/datasets/:persistentId/?persistentId=${encodeURIComponent(a.pid)}`;
      const bytes = await withTimeout(fetchJsonSameOrigin(base, url), 'discover');
      const meta = parseDatasetMetadata(bytes.toString('utf8'));
      const sha = storeObject(a.cache, bytes);
      console.log(JSON.stringify({ status: 'OK', kind: 'metadata', pid: a.pid, metadata_sha256: sha, version: meta.version, files: meta.files }));
    } catch (e) { return unknown(`discover failed: ${e.message}`, { class: classifyFailure(e), waf: !!e.waf, pid: a.pid }); }
    return;
  }

  if (cmd === 'fetch') {
    if (!a.pid || !a.file || !a.cache) return unknown('fetch requires --pid, --file and --cache');
    const want = typeof a.sha256 === 'string' ? a.sha256.toLowerCase() : null;
    // Resumable: a verified content-addressed object short-circuits the network.
    if (want) {
      try {
        const p = contentAddressPath(a.cache, want);
        if (existsSync(p) && sha256Hex(readFileSync(p)) === want) {
          console.log(JSON.stringify({ status: 'OK', kind: 'datafile', pid: a.pid, file_id: String(a.file), resumed: true, sha256: want }));
          return;
        }
      } catch { /* malformed digest or unreadable object: fall through to live */ }
    }
    try {
      const url = `${base}/api/access/datafile/${encodeURIComponent(a.file)}?format=original`;
      const bytes = await withTimeout(downloadDatafile(base, url), 'fetch');
      const sha = storeObject(a.cache, bytes);
      if (want && want !== sha) {
        return unknown(`checksum mismatch: expected ${want} got ${sha}`, { class: 'checksum', got_sha256: sha, pid: a.pid, file_id: String(a.file) });
      }
      console.log(JSON.stringify({ status: 'OK', kind: 'datafile', pid: a.pid, file_id: String(a.file), resumed: false, bytes: bytes.length, sha256: sha }));
    } catch (e) { return unknown(`fetch failed: ${e.message}`, { class: classifyFailure(e), waf: !!e.waf, pid: a.pid, file_id: String(a.file) }); }
    return;
  }

  console.error('usage: dataverse-acquire.mjs --selftest | discover ... | fetch ...');
  process.exit(2);
}

main();
