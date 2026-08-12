#!/usr/bin/env node
// browser-capture.mjs — real Chrome/Playwright capture adapter for the
// browser-live lane. One invocation renders exactly ONE key (route + state +
// viewport) in ONE isolated browser context, honouring the frozen profile the
// wrapper pins, blocking every non-loopback request after bootstrap, settling
// deterministically (no wall-clock waits), and writing the screenshot, DOM,
// replayable action trace, console log, network log, and a result manifest.
//
// It grades nothing: no pixel decode, no taste. The wrapper hashes and gates
// the artifacts; the decoder/pixels lane consumes the PNGs downstream.
//
// Contract (env): POLYLANE_CAPTURE_REQUEST -> request json, POLYLANE_CAPTURE_OUTPUT -> dir.
// Exit non-zero on ANY failure so the wrapper fails closed (no partial success).
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const NAV_TIMEOUT_MS = Number(process.env.POLYLANE_BROWSER_LIVE_NAV_TIMEOUT_MS || 15000);
const SETTLE_TIMEOUT_MS = Number(process.env.POLYLANE_BROWSER_LIVE_SETTLE_TIMEOUT_MS || 8000);

function fail(msg) { process.stderr.write(`BROWSER-CAPTURE: ${msg}\n`); process.exit(1); }

const reqPath = process.env.POLYLANE_CAPTURE_REQUEST;
const outDir = process.env.POLYLANE_CAPTURE_OUTPUT;
if (!reqPath || !outDir) fail('POLYLANE_CAPTURE_REQUEST and POLYLANE_CAPTURE_OUTPUT are required');

let req;
try { req = JSON.parse(readFileSync(reqPath, 'utf8')); } catch (e) { fail(`unreadable request: ${e.message}`); }
if (req.schema_version !== 'taste-browser-live-request/v1') fail('unknown request schema');

const { route, state, base_url: baseUrl, viewport_css_px: vp, environment: env, browser, profile, actions } = req;
const width = vp.width, height = vp.height;

// Loopback allowlist: only 127.0.0.1 / localhost / ::1 (any port) may load; and
// non-http schemes the page bootstraps with (data:, about:, blob:).
function isLoopback(u) {
  try {
    const url = new URL(u);
    if (url.protocol === 'data:' || url.protocol === 'about:' || url.protocol === 'blob:') return true;
    const h = url.hostname;
    return h === '127.0.0.1' || h === 'localhost' || h === '::1' || h === '[::1]';
  } catch { return false; }
}

const ALLOWED_ACTIONS = new Set(['click', 'hover', 'focus', 'fill', 'press', 'wait_for']);

const require = createRequire(import.meta.url);
let chromium;
try { ({ chromium } = require((browser.playwright_module || 'playwright') + '/index.js')); }
catch { try { ({ chromium } = require(browser.playwright_module || 'playwright')); } catch (e) { fail(`cannot load Playwright: ${e.message}`); } }

const messages = [];   // console log
const requests = [];   // network log
const trace = [];      // action trace

async function main() {
  const browserInstance = await chromium.launch({
    executablePath: browser.executable_path,
    headless: true,
    args: ['--hide-scrollbars', '--force-color-profile=srgb', '--disable-lcd-text'],
  });
  try {
    // One isolated context/page per capture — no shared cookies/storage/cache.
    const context = await browserInstance.newContext({
      viewport: { width, height },
      deviceScaleFactor: env.device_scale_factor,
      locale: env.locale,
      timezoneId: env.timezone,
      colorScheme: env.color_scheme,
      reducedMotion: 'reduce',
      bypassCSP: false,
    });
    context.setDefaultNavigationTimeout(NAV_TIMEOUT_MS);
    context.setDefaultTimeout(SETTLE_TIMEOUT_MS);

    // Block non-loopback after bootstrap: loopback + data/about/blob continue,
    // everything else is aborted and recorded (the page cannot phone home).
    await context.route('**/*', (r) => {
      const url = r.request().url();
      const loop = isLoopback(url);
      if (loop) { r.continue(); }
      else {
        requests.push({ url, method: r.request().method(), resource_type: r.request().resourceType(), status: 0, loopback: false, blocked: true });
        r.abort();
      }
    });

    const page = await context.newPage();
    page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') messages.push({ type: m.type(), text: m.text() }); });
    page.on('pageerror', (e) => { messages.push({ type: 'error', text: `pageerror: ${e.message}` }); });
    page.on('requestfailed', (r) => {
      const url = r.url();
      if (isLoopback(url) && !requests.some((x) => x.url === url && x.blocked)) {
        requests.push({ url, method: r.method(), resource_type: r.resourceType(), status: 0, loopback: true, blocked: false, failed: true });
      }
    });
    page.on('response', (resp) => {
      const url = resp.url();
      if (isLoopback(url)) requests.push({ url, method: resp.request().method(), resource_type: resp.request().resourceType(), status: resp.status(), loopback: true, blocked: false });
    });

    // --- navigate (bootstrap) --------------------------------------------------
    const target = baseUrl + route;
    let resp;
    try { resp = await page.goto(target, { waitUntil: 'load' }); }
    catch (e) { fail(`navigation to ${target} failed: ${e.message}`); }
    if (!resp) fail(`navigation to ${target} produced no response`);
    if (resp.status() >= 400) fail(`navigation to ${target} returned status ${resp.status()}`);
    trace.push({ step: trace.length, type: 'navigate', target: route, ok: true, status: resp.status() });

    // --- replay allowlisted state actions -------------------------------------
    for (const a of (actions || [])) {
      if (!ALLOWED_ACTIONS.has(a.type)) fail(`action type not allowlisted: ${a.type}`);
      try {
        if (a.type === 'click') await page.click(a.selector);
        else if (a.type === 'hover') await page.hover(a.selector);
        else if (a.type === 'focus') await page.focus(a.selector);
        else if (a.type === 'fill') await page.fill(a.selector, a.value);
        else if (a.type === 'press') await page.keyboard.press(a.key);
        else if (a.type === 'wait_for') await page.waitForSelector(a.selector);
      } catch (e) { fail(`action ${a.type} failed: ${e.message}`); }
      trace.push({ step: trace.length, type: a.type, selector: a.selector || null, ok: true });
    }

    // --- deterministic settle: freeze animation, fonts ready, two rAFs --------
    // No setTimeout / wall-clock sleeps — the settle is a fixed amount of work.
    await page.addStyleTag({ content: '*,*::before,*::after{animation:none!important;transition:none!important;animation-duration:0s!important;caret-color:transparent!important;scroll-behavior:auto!important}' });
    await page.evaluate(async () => {
      try { await document.fonts.ready; } catch { /* fonts API may be absent */ }
      await new Promise((res) => requestAnimationFrame(() => requestAnimationFrame(res)));
    });
    trace.push({ step: trace.length, type: 'settle', ok: true });

    // --- artifacts -------------------------------------------------------------
    const dom = await page.content();
    const png = await page.screenshot({ type: 'png', animations: 'disabled', caret: 'hide', scale: 'css' });

    writeFileSync(`${outDir}/screenshot.png`, png);
    writeFileSync(`${outDir}/dom.html`, dom);
    writeFileSync(`${outDir}/action-trace.json`, JSON.stringify({ schema_version: 'taste-browser-live-actions/v1', route, state, actions: trace }));
    const consoleErrorCount = messages.filter((m) => m.type === 'error').length;
    writeFileSync(`${outDir}/console.json`, JSON.stringify({ schema_version: 'taste-browser-live-console/v1', messages, error_count: consoleErrorCount }));
    const blocked = requests.filter((r) => r.blocked === true && r.loopback !== true).length;
    const netErrors = requests.filter((r) => r.loopback === true && ((r.status || 0) >= 400 || r.failed === true)).length;
    writeFileSync(`${outDir}/network.json`, JSON.stringify({ schema_version: 'taste-browser-live-network/v1', requests, blocked_nonloopback_count: blocked, error_count: netErrors }));

    const now = process.env.POLYLANE_CAPTURE_NOW || new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
    const result = {
      schema_version: 'taste-browser-live-result/v1',
      route, state, navigation_status: 'ok',
      viewport_css_px: { width, height },
      captured_at: now,
      profile,
      screenshot: 'screenshot.png', dom: 'dom.html', action_trace: 'action-trace.json',
      console: 'console.json', network: 'network.json',
      console_error_count: consoleErrorCount,
      network_error_count: netErrors,
      blocked_nonloopback_count: blocked,
    };
    writeFileSync(`${outDir}/result.json`, JSON.stringify(result));
    await context.close();
  } finally {
    await browserInstance.close();
  }
}

main().catch((e) => fail(e && e.stack ? e.stack : String(e)));
