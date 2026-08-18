#!/usr/bin/env node
// dataverse-campaign-transport.mjs — thin shim adapting the dataverse-acquire
// adapter (content-addressed, ephemeral-Chrome fetch) to the
// taste-download-campaign transport contract:
//
//   session --source <id> --pid <pid>            -> {"status":"OK","session":t}
//   fetch --session <t> --source <id> --pid <pid> --file <id> --out <path>
//
// Sessions here are bookkeeping only: every fetch clears its own fresh
// ephemeral WAF context inside dataverse-acquire (stricter isolation than one
// session per source; slower, never a credential). The shim writes the fetched
// bytes to --out; the campaign re-verifies size/md5/sha and publishes
// atomically. Failures map to RETRYABLE so the campaign's bounded attempt
// budget governs retries; nothing here retries on its own.
import { spawnSync } from 'node:child_process';
import { copyFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const ACQUIRE = join(here, 'dataverse-acquire.mjs');

const rest = process.argv.slice(2);
const cmd = rest.shift();
const args = {};
for (let i = 0; i < rest.length; i += 2) args[rest[i]] = rest[i + 1];

function out(obj, code = 0) { console.log(JSON.stringify(obj)); process.exit(code); }

if (cmd === 'session') {
  out({ status: 'OK', session: `ephemeral-${process.pid}-${Date.now()}` });
} else if (cmd === 'fetch') {
  const cache = process.env.POLYLANE_SHIM_CACHE;
  if (!cache) out({ status: 'FATAL', reason: 'POLYLANE_SHIM_CACHE unset' });
  if (!args['--pid'] || !args['--file'] || !args['--out']) {
    out({ status: 'FATAL', reason: 'fetch requires --pid, --file, --out' });
  }
  const r = spawnSync('node', [ACQUIRE, 'fetch',
    '--pid', args['--pid'], '--file', args['--file'], '--cache', cache], {
    encoding: 'utf8',
    env: { ...process.env, POLYLANE_SOURCE_CANARY_TIMEOUT_MS: process.env.POLYLANE_SOURCE_CANARY_TIMEOUT_MS || '90000' },
  });
  let msg = null;
  try { msg = JSON.parse(String(r.stdout).trim().split('\n').pop()); } catch { /* garbled */ }
  if (!msg || msg.status !== 'OK' || !/^[0-9a-f]{64}$/.test(msg.sha256 || '')) {
    out({ status: 'RETRYABLE', reason: (msg && msg.reason) || `acquire exit ${r.status}` });
  }
  try {
    copyFileSync(join(cache, 'objects', msg.sha256.slice(0, 2), msg.sha256), args['--out']);
  } catch (e) {
    out({ status: 'RETRYABLE', reason: `cache object missing after OK: ${e.message}` });
  }
  out({ status: 'OK', sha256: msg.sha256 });
} else {
  out({ status: 'FATAL', reason: `unknown command: ${cmd}` }, 1);
}
