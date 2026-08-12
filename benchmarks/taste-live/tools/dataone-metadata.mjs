#!/usr/bin/env node
// dataone-metadata.mjs — strict DataONE discovery/provenance adapter for the three
// immutable metadata PIDs frozen in Cycle 41 (run c41-source-calibration-20260812-a1).
//
// DataONE is a provenance/discovery mirror ONLY. This adapter never downloads source
// bytes and never claims to: every receipt hard-codes source_bytes_supplied:false.
// A metadata disagreement is SOURCE-MISMATCH (exit 2), never a majority vote; a
// transport failure (timeout, redirect loop, HTTP error, network) is UNKNOWN (exit 3).
// Fixture runs (any --table/--base override) are stamped mode:"fixture" and can never
// be stamped live.
//
// Usage:
//   node dataone-metadata.mjs --selftest
//   node dataone-metadata.mjs table
//   node dataone-metadata.mjs verify --domain <d> --cache <dir>
//        [--base <url>] [--table <file>] [--timeout-ms <n>]

import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const DEFAULT_BASE = 'https://cn.dataone.org/cn/v2';
const HARVARD_URL_RE = /^https:\/\/dataverse\.harvard\.edu\/api\/access\/datafile\/\d+(\?format=original)?$/;
const MAX_REDIRECTS = 3;
const DEFAULT_TIMEOUT_MS = 30000;

// Frozen Cycle 41 identifiers (docs/polylane/cycle-41-research.md). version and
// distributions are enforced only where the research lock actually froze a value;
// unfrozen scalars are recorded into the receipt, never invented. title_tokens stay
// null for the same reason — domain binding rides on the frozen DOI↔domain table
// plus the PID content digest.
export const FROZEN_TABLE = {
  'e-commerce': {
    doi: '10.7910/DVN/9FKSQI',
    pid: 'sha256:6ff2435a723445a99d8ef725da000115fc6d5716babaa776ea1604e30bb870e9',
    version: '4', distributions: 1074, title_tokens: null,
  },
  'universities': {
    doi: '10.7910/DVN/XOI0HI',
    pid: 'sha256:71ee5e0dbf9e0b47bb95d6291ab337e02322907f20a996d028376e3065cf20f5',
    version: null, distributions: null, title_tokens: null,
  },
  'commercial-banks': {
    doi: '10.7910/DVN/Z7KLIH',
    pid: 'sha256:6fe3377fec3aa24ce8c3b697791440c26400146381b7e5fc0ae7834daf0b78df',
    version: null, distributions: null, title_tokens: null,
  },
};

// ---- pure helpers (hermetic; exercised by --selftest) ----------------------

export function sha256Hex(buf) {
  return createHash('sha256').update(buf).digest('hex');
}

// Canonical JSON identical to `jq -cS`: sorted keys, no whitespace.
export function stableStringify(v) {
  if (v === null || typeof v !== 'object') return JSON.stringify(v);
  if (Array.isArray(v)) return '[' + v.map(stableStringify).join(',') + ']';
  return '{' + Object.keys(v).sort()
    .map((k) => JSON.stringify(k) + ':' + stableStringify(v[k])).join(',') + '}';
}

// Collect every candidate identifier string in the JSON-LD record and extract the
// first Harvard DVN DOI. science-on-schema records vary between plain strings,
// PropertyValue objects, and arrays.
export function extractDoi(record) {
  const cands = [];
  const push = (x) => {
    if (typeof x === 'string') cands.push(x);
    else if (Array.isArray(x)) x.forEach(push);
    else if (x && typeof x === 'object') { push(x.value); push(x['@id']); push(x.url); }
  };
  push(record['@id']);
  push(record.identifier);
  push(record.sameAs);
  for (const s of cands) {
    const m = s.match(/10\.7910\/DVN\/[A-Z0-9]{4,10}/);
    if (m) return m[0];
  }
  return null;
}

export function licenseIsCc0(lic) {
  const strs = [];
  const push = (x) => {
    if (typeof x === 'string') strs.push(x);
    else if (Array.isArray(x)) x.forEach(push);
    else if (x && typeof x === 'object') { push(x['@id']); push(x.url); push(x.name); }
  };
  push(lic);
  return strs.some((s) => /creativecommons\.org\/publicdomain\/zero\/1\.0|(^|[^A-Z0-9])CC0([^A-Z0-9]|$)/i.test(s));
}

export function parseContentSize(v) {
  if (typeof v === 'number' && Number.isInteger(v) && v >= 0) return v;
  if (typeof v === 'string') {
    const m = v.match(/^(\d+)(\s*(bytes|B))?$/);
    if (m) return Number(m[1]);
  }
  return null;
}

// Validate distributions: canonical Harvard URLs, non-empty unique names, unique
// URLs, integral sizes. Returns {error:{code,detail}} or {count,totalBytes,names}.
export function validateDistributions(dists) {
  if (!Array.isArray(dists) || dists.length === 0) {
    return { error: { code: 'distribution-missing', detail: 'no distribution array' } };
  }
  const urls = new Set();
  const names = [];
  const nameSet = new Set();
  let totalBytes = 0;
  for (const d of dists) {
    const name = typeof d?.name === 'string' ? d.name.trim() : '';
    if (!name) return { error: { code: 'distribution-name', detail: 'empty distribution name' } };
    const url = typeof d?.contentUrl === 'string' ? d.contentUrl : '';
    if (!HARVARD_URL_RE.test(url)) {
      return { error: { code: 'distribution-url', detail: `non-canonical URL: ${url.slice(0, 200)}` } };
    }
    const size = parseContentSize(d?.contentSize);
    if (size === null) {
      return { error: { code: 'distribution-size', detail: `bad contentSize for ${name}` } };
    }
    if (urls.has(url) || nameSet.has(name)) {
      return { error: { code: 'duplicate-distribution', detail: `duplicate entry: ${name}` } };
    }
    urls.add(url);
    nameSet.add(name);
    names.push(name);
    totalBytes += size;
  }
  return { count: names.length, totalBytes, names };
}

// Minimal strict extraction from DataONE v2 system metadata XML. Element names may
// carry a namespace prefix and the checksum algorithm is whatever the CN declares
// (commonly MD5) — the caller verifies it by recomputing that algorithm over the
// digest-validated object bytes.
export function parseSysmeta(xml) {
  const cs = xml.match(/<(?:\w+:)?checksum[^>]*algorithm\s*=\s*["']([^"']+)["'][^>]*>\s*([0-9a-fA-F]+)\s*<\/(?:\w+:)?checksum>/);
  const node = (xml.match(/<(?:\w+:)?authoritativeMemberNode>\s*([^<\s][^<]*?)\s*<\/(?:\w+:)?authoritativeMemberNode>/) || [])[1] || null;
  const size = (xml.match(/<(?:\w+:)?size>\s*(\d+)\s*<\/(?:\w+:)?size>/) || [])[1];
  const ident = (xml.match(/<(?:\w+:)?identifier>\s*([^<\s][^<]*?)\s*<\/(?:\w+:)?identifier>/) || [])[1] || null;
  return {
    algorithm: cs ? cs[1].trim() : null,
    checksum: cs ? cs[2].toLowerCase() : null,
    node,
    size: size === undefined ? null : Number(size),
    identifier: ident,
  };
}

// Recompute the sysmeta-declared checksum algorithm over the object bytes.
// Returns the hex digest, or null when the algorithm is unsupported.
export function digestWithAlgorithm(algorithm, buf) {
  const norm = String(algorithm || '').toLowerCase().replace(/[^a-z0-9]/g, '');
  const map = { md5: 'md5', sha1: 'sha1', sha256: 'sha256', sha512: 'sha512' };
  if (!map[norm]) return null;
  return createHash(map[norm]).update(buf).digest('hex');
}

export function buildReceipt(body) {
  const receipt_sha256 = sha256Hex(stableStringify(body));
  return { ...body, receipt_sha256 };
}

// ---- transport --------------------------------------------------------------

class TransportError extends Error {
  constructor(code, detail) { super(detail); this.code = code; }
}

async function fetchBytes(url, timeoutMs) {
  let current = url;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), timeoutMs);
    let res;
    try {
      res = await fetch(current, { redirect: 'manual', signal: ctl.signal });
    } catch (e) {
      clearTimeout(timer);
      if (e?.name === 'AbortError' || /abort/i.test(String(e))) {
        throw new TransportError('timeout', `timeout after ${timeoutMs}ms: ${current}`);
      }
      throw new TransportError('network', `fetch failed: ${String(e?.cause || e).slice(0, 200)}`);
    }
    clearTimeout(timer);
    if ([301, 302, 303, 307, 308].includes(res.status)) {
      const loc = res.headers.get('location');
      if (!loc) throw new TransportError('redirect', `redirect without location: ${current}`);
      current = new URL(loc, current).toString();
      continue;
    }
    if (res.status !== 200) {
      throw new TransportError(`http-${res.status}`, `unexpected HTTP ${res.status}: ${current}`);
    }
    return Buffer.from(await res.arrayBuffer());
  }
  throw new TransportError('redirect', `more than ${MAX_REDIRECTS} redirects: ${url}`);
}

// ---- verify -----------------------------------------------------------------

function emit(obj) { process.stdout.write(stableStringify(obj) + '\n'); }

function fail(cls, code, detail) {
  emit({ error: { class: cls, code, detail } });
  process.exit(cls === 'UNKNOWN' ? 3 : 2);
}

function mismatch(code, detail) { fail('SOURCE-MISMATCH', code, detail); }

async function verify(args) {
  const domain = args['--domain'];
  const cache = args['--cache'];
  const base = args['--base'] || DEFAULT_BASE;
  const timeoutMs = args['--timeout-ms'] ? Number(args['--timeout-ms']) : DEFAULT_TIMEOUT_MS;
  const tableFile = args['--table'] || null;
  if (!domain || !cache || !Number.isFinite(timeoutMs) || timeoutMs <= 0) usage();

  const table = tableFile
    ? JSON.parse(readFileSync(tableFile, 'utf8'))
    : FROZEN_TABLE;
  const entry = table[domain];
  if (!entry || !/^sha256:[0-9a-f]{64}$/.test(String(entry.pid || ''))) usage();
  const pidHex = entry.pid.slice('sha256:'.length);
  // Live only against the real CN with the builtin frozen table; anything else is a
  // fixture and is permanently stamped as one.
  const mode = (base === DEFAULT_BASE && !tableFile) ? 'live' : 'fixture';

  const enc = encodeURIComponent(entry.pid);
  let objectBytes, sysmetaXml;
  try {
    objectBytes = await fetchBytes(`${base}/object/${enc}`, timeoutMs);
    sysmetaXml = (await fetchBytes(`${base}/meta/${enc}`, timeoutMs)).toString('utf8');
  } catch (e) {
    if (e instanceof TransportError) fail('UNKNOWN', e.code, e.message);
    fail('UNKNOWN', 'network', String(e).slice(0, 200));
  }

  // 1. Immutable content digest first — everything downstream trusts these bytes.
  const contentSha = sha256Hex(objectBytes);
  if (contentSha !== pidHex) {
    mismatch('digest-mismatch', `object sha256 ${contentSha} != pid ${pidHex}`);
  }

  // 2. Digest-bound bytes must be the JSON-LD record, not a challenge page.
  let record;
  try {
    record = JSON.parse(objectBytes.toString('utf8'));
  } catch {
    mismatch('non-json', 'digest-valid object bytes are not JSON');
  }

  // 3. Exact frozen DOI (this is also the domain binding).
  const doi = extractDoi(record);
  if (doi !== entry.doi) {
    mismatch('doi-mismatch', `record DOI ${doi} != frozen ${entry.doi}`);
  }

  // 4. Title: required non-empty, recorded; token check only when tokens are frozen.
  const title = typeof record.name === 'string' ? record.name.trim() : '';
  if (!title) mismatch('title-mismatch', 'record has no title');
  if (Array.isArray(entry.title_tokens) && entry.title_tokens.length > 0) {
    const lower = title.toLowerCase();
    if (!entry.title_tokens.some((t) => lower.includes(String(t).toLowerCase()))) {
      mismatch('title-mismatch', `title "${title.slice(0, 120)}" lacks frozen tokens`);
    }
  }

  // 5. CC0 licence.
  if (!licenseIsCc0(record.license)) {
    mismatch('licence-mismatch', `licence is not CC0: ${JSON.stringify(record.license).slice(0, 200)}`);
  }

  // 6. Version: non-empty always; exact when frozen.
  const version = record.version === undefined || record.version === null
    ? '' : String(record.version).trim();
  if (!version) mismatch('version-mismatch', 'record has no version');
  if (entry.version !== null && entry.version !== undefined && version !== String(entry.version)) {
    mismatch('version-mismatch', `record version ${version} != frozen ${entry.version}`);
  }

  // 7. Distributions: canonical Harvard URLs, unique, sized; exact count when frozen.
  const dist = validateDistributions(record.distribution);
  if (dist.error) mismatch(dist.error.code, dist.error.detail);
  if (entry.distributions !== null && entry.distributions !== undefined
    && dist.count !== Number(entry.distributions)) {
    mismatch('distribution-count-mismatch',
      `record has ${dist.count} distributions, frozen ${entry.distributions}`);
  }

  // 8. System metadata must agree with the immutable digest and observed size.
  // The sysmeta checksum is verified with its own declared algorithm recomputed over
  // the already digest-validated object bytes (DataONE CNs commonly declare MD5).
  const sys = parseSysmeta(sysmetaXml);
  if (sys.identifier !== entry.pid) {
    mismatch('sysmeta-mismatch', `sysmeta identifier ${sys.identifier} != pid ${entry.pid}`);
  }
  const recomputed = digestWithAlgorithm(sys.algorithm, objectBytes);
  if (recomputed === null) {
    mismatch('sysmeta-mismatch', `unsupported sysmeta checksum algorithm: ${sys.algorithm}`);
  }
  if (sys.checksum !== recomputed) {
    mismatch('sysmeta-mismatch',
      `sysmeta ${sys.algorithm} checksum ${sys.checksum} != recomputed ${recomputed}`);
  }
  if (sys.size !== objectBytes.length) {
    mismatch('sysmeta-mismatch', `sysmeta size ${sys.size} != observed ${objectBytes.length}`);
  }
  if (!sys.node || !/^urn:node:[A-Za-z0-9_.-]+$/.test(sys.node)) {
    mismatch('sysmeta-mismatch', `bad authoritative member node: ${sys.node}`);
  }

  const receipt = buildReceipt({
    schema: 'polylane.taste.dataone.v1',
    run: 'c41-source-calibration-20260812-a1',
    mode,
    domain,
    doi,
    pid: entry.pid,
    base,
    content_sha256: contentSha,
    content_bytes: objectBytes.length,
    title,
    license_cc0: true,
    version,
    distribution_count: dist.count,
    total_distribution_bytes: dist.totalBytes,
    distribution_names_sha256: sha256Hex(stableStringify([...dist.names].sort())),
    authoritative_member_node: sys.node,
    sysmeta_checksum_algorithm: sys.algorithm,
    source_bytes_supplied: false,
    retrieved_at: new Date().toISOString(),
  });

  const dir = join(cache, 'receipts');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, `dataone-${domain}.json`), stableStringify(receipt) + '\n');
  emit(receipt);
}

// ---- selftest ----------------------------------------------------------------

function selftest() {
  const assert = (cond, msg) => { if (!cond) { console.error(`selftest FAIL: ${msg}`); process.exit(1); } };

  assert(stableStringify({ b: 1, a: [2, { d: 3, c: 4 }] }) === '{"a":[2,{"c":4,"d":3}],"b":1}',
    'stableStringify sorts keys recursively');
  assert(sha256Hex(Buffer.from('abc')) ===
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', 'sha256Hex');

  assert(extractDoi({ identifier: 'doi:10.7910/DVN/9FKSQI' }) === '10.7910/DVN/9FKSQI', 'doi string');
  assert(extractDoi({ identifier: { '@type': 'PropertyValue', value: 'https://doi.org/10.7910/DVN/XOI0HI' } })
    === '10.7910/DVN/XOI0HI', 'doi PropertyValue');
  assert(extractDoi({ identifier: 'doi:10.5061/other' }) === null, 'foreign doi rejected');

  assert(licenseIsCc0('http://creativecommons.org/publicdomain/zero/1.0/'), 'cc0 url');
  assert(licenseIsCc0({ name: 'CC0 1.0' }), 'cc0 object');
  assert(!licenseIsCc0('https://creativecommons.org/licenses/by/4.0/'), 'cc-by rejected');

  assert(parseContentSize('12345') === 12345, 'size numeric string');
  assert(parseContentSize('12345 bytes') === 12345, 'size with unit');
  assert(parseContentSize(42) === 42, 'size number');
  assert(parseContentSize('1.2 MB') === null, 'lossy size rejected');

  const good = [
    { name: 'a.png', contentUrl: 'https://dataverse.harvard.edu/api/access/datafile/1', contentSize: '10' },
    { name: 'b.png', contentUrl: 'https://dataverse.harvard.edu/api/access/datafile/2', contentSize: 20 },
  ];
  const v = validateDistributions(good);
  assert(v.count === 2 && v.totalBytes === 30, 'distributions valid');
  const dup = validateDistributions([good[0], { ...good[1], contentUrl: good[0].contentUrl }]);
  assert(dup.error && dup.error.code === 'duplicate-distribution', 'duplicate url detected');
  const bad = validateDistributions([{ ...good[0], contentUrl: 'https://evil.example/x' }]);
  assert(bad.error && bad.error.code === 'distribution-url', 'non-canonical url detected');

  const sys = parseSysmeta('<identifier>sha256:' + 'b'.repeat(64) + '</identifier>'
    + '<size> 99 </size><checksum algorithm="SHA-256">' + 'a'.repeat(64)
    + '</checksum><authoritativeMemberNode>urn:node:TestNode</authoritativeMemberNode>');
  assert(sys.checksum === 'a'.repeat(64) && sys.node === 'urn:node:TestNode' && sys.size === 99
    && sys.algorithm === 'SHA-256' && sys.identifier === 'sha256:' + 'b'.repeat(64), 'sysmeta parse');
  const sysNs = parseSysmeta('<d1:checksum algorithm=\'MD5\'>ABCDEF0123456789abcdef0123456789</d1:checksum>'
    + '<d1:authoritativeMemberNode>urn:node:X</d1:authoritativeMemberNode>');
  assert(sysNs.algorithm === 'MD5' && sysNs.checksum === 'abcdef0123456789abcdef0123456789'
    && sysNs.node === 'urn:node:X', 'namespaced sysmeta parse');
  assert(digestWithAlgorithm('MD5', Buffer.from('abc')) === '900150983cd24fb0d6963f7d28e17f72', 'md5 recompute');
  assert(digestWithAlgorithm('SHA-256', Buffer.from('abc')) === sha256Hex(Buffer.from('abc')), 'sha256 recompute');
  assert(digestWithAlgorithm('CRC32', Buffer.from('abc')) === null, 'unsupported algorithm rejected');

  const r1 = buildReceipt({ z: 1, a: 'x' });
  const r2 = buildReceipt({ a: 'x', z: 1 });
  assert(r1.receipt_sha256 === r2.receipt_sha256, 'receipt hash key-order independent');
  assert(sha256Hex(stableStringify({ a: 'x', z: 1 })) === r1.receipt_sha256, 'receipt hash recomputes');

  console.log('selftest OK');
}

// ---- cli -----------------------------------------------------------------------

function usage() {
  console.error('usage: dataone-metadata.mjs --selftest | table | verify --domain <d> --cache <dir> [--base <url>] [--table <file>] [--timeout-ms <n>]');
  process.exit(4);
}

const argv = process.argv.slice(2);
const cmd = argv[0];
if (cmd === '--selftest') {
  selftest();
} else if (cmd === 'table') {
  emit(FROZEN_TABLE);
} else if (cmd === 'verify') {
  const args = {};
  for (let i = 1; i < argv.length; i += 2) {
    if (!argv[i].startsWith('--') || argv[i + 1] === undefined) usage();
    args[argv[i]] = argv[i + 1];
  }
  await verify(args);
} else if (cmd !== undefined) {
  usage();
}
