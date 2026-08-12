#!/usr/bin/env node
// accessibility.mjs — pinned live accessibility rule engine (taste-live lane).
//
// A self-contained, deterministic WCAG 2.1 AA automatable-rule engine. It is the
// engine the trusted runner (bin/polylane-taste-a11y-live.sh) pins by
// package/version/source-hash and invokes once per audit. It reads the runner's
// request (bound DOM + scripted keyboard/action + reflow/motion evidence for
// every capture), applies one rule per required criterion, and emits
//   result.json  (taste-a11y-live-result/v1) — per-capture, per-criterion status
//   receipt.json (taste-live-engine-receipt/v1) — source-hash + input/output binding
//
// It NEVER emits an aggregate verdict, promotion, or caller-authored pass: the
// runner recomputes the verdict from these exact per-criterion outcomes. When a
// rule cannot be measured from the bound evidence it returns "skipped" (an
// evidence gap the runner turns into UNKNOWN — never PASS), and manual criteria
// (screen reader, cognitive, localization) are out of scope here by design.
//
// Usage (invoked by the runner):
//   POLYLANE_A11Y_REQUEST=<request.json> POLYLANE_A11Y_OUTPUT=<dir> \
//     node accessibility.mjs
// Self-test (no request needed):
//   node accessibility.mjs --selfcheck

import { readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";

export const ENGINE_ID = "taste-live-a11y";
export const ENGINE_PACKAGE = "polylane-taste-live-accessibility";
export const ENGINE_VERSION = "1.0.0";

// Canonical automatable WCAG 2.1 AA criteria — must match the runner's list and
// order. Manual criteria (screen-reader-usability, cognitive-accessibility,
// localization-rtl) are never scored here; they stay external.
export const CRITERIA = [
  "semantics-name-role-value",
  "labels-instructions",
  "error-identification",
  "heading-landmark-structure",
  "keyboard-reachable",
  "focus-order",
  "no-keyboard-trap",
  "keyboard-escape",
  "focus-visible",
  "target-size",
  "contrast",
  "non-color-state",
  "reflow-zoom-overflow",
  "reduced-motion",
  "status-announcements",
];

const STATEFUL_ROLES = new Set(["checkbox", "radio", "switch", "slider", "combobox", "spinbutton", "textbox", "searchbox", "menuitemcheckbox", "menuitemradio"]);
const INPUT_ROLES = new Set(["textbox", "searchbox", "combobox", "checkbox", "radio", "switch", "slider", "spinbutton", "listbox"]);

// --- WCAG contrast math (1.4.3 / 1.4.11) ------------------------------------
function hexToRgb(h) {
  if (typeof h !== "string") return null;
  let s = h.trim().replace(/^#/, "");
  if (s.length === 3) s = s.split("").map((c) => c + c).join("");
  if (!/^[0-9a-fA-F]{6}$/.test(s)) return null;
  return { r: parseInt(s.slice(0, 2), 16), g: parseInt(s.slice(2, 4), 16), b: parseInt(s.slice(4, 6), 16) };
}
function chanLin(c) {
  const x = c / 255;
  return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
}
function luminance(rgb) {
  return 0.2126 * chanLin(rgb.r) + 0.7152 * chanLin(rgb.g) + 0.0722 * chanLin(rgb.b);
}
export function contrastRatio(fg, bg) {
  const a = hexToRgb(fg), b = hexToRgb(bg);
  if (!a || !b) return null;
  const l1 = luminance(a), l2 = luminance(b);
  const hi = Math.max(l1, l2), lo = Math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}
function round2(n) { return Math.round(n * 100) / 100; }
// Large text: >=24px, or >=18.66px bold. WCAG 2.1 1.4.3.
function requiredRatio(font_px, bold) {
  const large = font_px >= 24 || (font_px >= 18.66 && bold === true);
  return large ? 3.0 : 4.5;
}

// A rule returns { status, measured, region }. status is one of
// pass | fail | not-applicable | skipped. measured is always a non-empty object
// (the runner rejects a bare pass/fail with no measured evidence).
const SKIP = (reason) => ({ status: "skipped", measured: { reason }, region: "engine" });
const NA = (reason, region = "main") => ({ status: "not-applicable", measured: { reason }, region });

const RULES = {
  "contrast"(dom) {
    const nodes = dom.text_nodes;
    if (!Array.isArray(nodes)) return SKIP("no text_nodes evidence");
    if (nodes.length === 0) return NA("no text on this state");
    let worst = null;
    for (const n of nodes) {
      const r = contrastRatio(n.fg, n.bg);
      if (r === null || typeof n.font_px !== "number") return SKIP(`unmeasurable color/size on ${n.id ?? "?"}`);
      const req = requiredRatio(n.font_px, n.bold);
      const rec = { id: n.id ?? "?", ratio: round2(r), required: req, region: n.region ?? "main" };
      if (!worst || rec.ratio < worst.ratio) worst = rec;
    }
    const status = worst.ratio + 1e-9 >= worst.required ? "pass" : "fail";
    return { status, measured: { min_ratio: worst.ratio, required: worst.required, selector: `#${worst.id}` }, region: worst.region };
  },
  "target-size"(dom) {
    const c = dom.controls;
    if (!Array.isArray(c)) return SKIP("no controls evidence");
    const sized = c.filter((x) => x.target_px);
    if (sized.length === 0) return NA("no interactive targets");
    let worst = null;
    for (const x of sized) {
      const t = x.target_px;
      if (typeof t.w !== "number" || typeof t.h !== "number") return SKIP(`no target size on ${x.id ?? "?"}`);
      const min = Math.min(t.w, t.h);
      if (!worst || min < worst.min) worst = { id: x.id ?? "?", w: t.w, h: t.h, min };
    }
    const status = worst.min >= 44 ? "pass" : "fail";
    return { status, measured: { min_w: worst.w, min_h: worst.h, required: 44, selector: `#${worst.id}` }, region: "main" };
  },
  "labels-instructions"(dom) {
    const c = dom.controls;
    if (!Array.isArray(c)) return SKIP("no controls evidence");
    const inputs = c.filter((x) => INPUT_ROLES.has(x.role));
    if (inputs.length === 0) return NA("no inputs on this state");
    const missing = inputs.filter((x) => !x.label);
    const status = missing.length === 0 ? "pass" : "fail";
    return { status, measured: { inputs: inputs.length, unlabeled: missing.length, selector: missing[0] ? `#${missing[0].id}` : "" }, region: "main" };
  },
  "semantics-name-role-value"(dom) {
    const c = dom.controls;
    if (!Array.isArray(c)) return SKIP("no controls evidence");
    if (c.length === 0) return NA("no UI components on this state");
    const bad = c.filter((x) => !x.role || !x.name || (STATEFUL_ROLES.has(x.role) && (x.value === undefined || x.value === null || x.value === "")));
    const status = bad.length === 0 ? "pass" : "fail";
    return { status, measured: { components: c.length, incomplete: bad.length, selector: bad[0] ? `#${bad[0].id}` : "" }, region: "main" };
  },
  "error-identification"(dom, cap) {
    if (cap.state !== "error") return NA("not an error state");
    const f = dom.error_fields;
    if (!Array.isArray(f)) return SKIP("no error_fields evidence");
    if (f.length === 0) return NA("no errors surfaced");
    const bad = f.filter((x) => x.identified_by_text !== true);
    const status = bad.length === 0 ? "pass" : "fail";
    return { status, measured: { errors: f.length, unidentified: bad.length, selector: bad[0] ? `#${bad[0].id}` : "" }, region: "form" };
  },
  "heading-landmark-structure"(dom) {
    const lands = dom.landmarks, heads = dom.headings;
    if (!Array.isArray(lands) || !Array.isArray(heads)) return SKIP("no landmark/heading evidence");
    const hasMain = lands.includes("main");
    let prev = 0, skip = null;
    for (const h of heads) {
      if (typeof h.level !== "number") return SKIP("heading without level");
      if (prev !== 0 && h.level > prev + 1) { skip = { from: prev, to: h.level }; break; }
      prev = h.level;
    }
    const status = hasMain && !skip ? "pass" : "fail";
    return { status, measured: { has_main: hasMain, headings: heads.length, level_skip: skip }, region: "document" };
  },
  "keyboard-reachable"(dom, cap, act) {
    const c = dom.controls;
    if (!Array.isArray(c)) return SKIP("no controls evidence");
    const focusable = c.filter((x) => x.focusable !== false);
    if (focusable.length === 0) return NA("no interactive controls");
    if (!Array.isArray(act.reachable)) return SKIP("no keyboard reachability trace");
    const reach = new Set(act.reachable);
    const unreached = focusable.filter((x) => !reach.has(x.id));
    const status = unreached.length === 0 ? "pass" : "fail";
    return { status, measured: { interactive: focusable.length, unreachable: unreached.length, selector: unreached[0] ? `#${unreached[0].id}` : "" }, region: "main" };
  },
  "focus-order"(dom, cap, act) {
    if (!Array.isArray(act.focus_order) || !Array.isArray(act.dom_order)) return SKIP("no focus/dom order trace");
    const dom_seq = act.dom_order.filter((id) => act.focus_order.includes(id));
    const foc_seq = act.focus_order.filter((id) => act.dom_order.includes(id));
    const ordered = JSON.stringify(dom_seq) === JSON.stringify(foc_seq);
    return { status: ordered ? "pass" : "fail", measured: { dom_order: dom_seq, focus_order: foc_seq }, region: "main" };
  },
  "no-keyboard-trap"(dom, cap, act) {
    if (typeof act.trap !== "boolean") return SKIP("no keyboard-trap trace");
    return { status: act.trap ? "fail" : "pass", measured: { trapped: act.trap, at: act.trap_at ?? null }, region: "main" };
  },
  "keyboard-escape"(dom, cap, act) {
    if (act.escape_returns_focus === null || act.escape_returns_focus === undefined) return NA("no dismissible layer on this state");
    if (typeof act.escape_returns_focus !== "boolean") return SKIP("no escape trace");
    return { status: act.escape_returns_focus ? "pass" : "fail", measured: { escape_returns_focus: act.escape_returns_focus }, region: "overlay" };
  },
  "focus-visible"(dom, cap, act) {
    const fv = act.focus_visible;
    if (!fv || typeof fv !== "object") return SKIP("no focus-visible trace");
    const ids = Object.keys(fv);
    if (ids.length === 0) return SKIP("empty focus-visible trace");
    const hidden = ids.filter((id) => fv[id] !== true);
    const status = hidden.length === 0 ? "pass" : "fail";
    return { status, measured: { focused: ids.length, no_indicator: hidden.length, selector: hidden[0] ? `#${hidden[0]}` : "" }, region: "main" };
  },
  "non-color-state"(dom) {
    const ind = dom.state_indicators;
    if (!Array.isArray(ind)) return SKIP("no state-indicator evidence");
    if (ind.length === 0) return NA("no color-coded state on this route");
    const bad = ind.filter((x) => x.color_only === true && x.has_text_or_icon !== true);
    const status = bad.length === 0 ? "pass" : "fail";
    return { status, measured: { indicators: ind.length, color_only: bad.length, selector: bad[0] ? `#${bad[0].id}` : "" }, region: "main" };
  },
  "reflow-zoom-overflow"(dom, cap) {
    const rf = cap.payload.reflow;
    if (!rf || typeof rf !== "object") return SKIP("no reflow measurement");
    if (typeof rf.content_width_px !== "number" || !rf.viewport_css_px || typeof rf.viewport_css_px.w !== "number") return SKIP("incomplete reflow measurement");
    const overflow = rf.horizontal_scroll === true || rf.content_width_px > rf.viewport_css_px.w + 1;
    return { status: overflow ? "fail" : "pass", measured: { viewport_w: rf.viewport_css_px.w, content_w: rf.content_width_px, horizontal_scroll: rf.horizontal_scroll === true }, region: "viewport" };
  },
  "reduced-motion"(dom, cap) {
    const m = cap.payload.motion;
    if (!m || typeof m !== "object") return SKIP("no motion measurement");
    if (m.has_motion !== true) return NA("no motion on this state");
    if (typeof m.prefers_reduced_motion_respected !== "boolean") return SKIP("no reduced-motion trace");
    return { status: m.prefers_reduced_motion_respected ? "pass" : "fail", measured: { has_motion: true, respected: m.prefers_reduced_motion_respected }, region: "viewport" };
  },
  "status-announcements"(dom) {
    const sr = dom.status_regions;
    if (!Array.isArray(sr)) return SKIP("no status-region evidence");
    if (sr.length === 0) return NA("no dynamic status on this state");
    const silent = sr.filter((x) => x.live !== true);
    const status = silent.length === 0 ? "pass" : "fail";
    return { status, measured: { regions: sr.length, not_live: silent.length, selector: silent[0] ? `#${silent[0].id}` : "" }, region: "status" };
  },
};

export function auditCapture(cap) {
  const dom = cap.payload && cap.payload.dom ? cap.payload.dom : {};
  const act = cap.payload && cap.payload.actions ? cap.payload.actions : {};
  const checks = [];
  for (const criterion of CRITERIA) {
    const r = RULES[criterion](dom, cap, act);
    checks.push({
      criterion,
      check_id: `${criterion}#1`,
      region: r.region || "main",
      status: r.status,
      measured: r.measured,
    });
  }
  return { capture_id: cap.capture_id, dom_sha256: cap.dom_sha256, action_trace_sha256: cap.action_trace_sha256, checks };
}

function sha256(buf) { return createHash("sha256").update(buf).digest("hex"); }

function run() {
  const reqPath = process.env.POLYLANE_A11Y_REQUEST;
  const outDir = process.env.POLYLANE_A11Y_OUTPUT;
  if (!reqPath || !outDir) { console.error("accessibility.mjs: POLYLANE_A11Y_REQUEST and POLYLANE_A11Y_OUTPUT required"); process.exit(2); }
  const reqBytes = readFileSync(reqPath);
  const req = JSON.parse(reqBytes);
  const selfSha = sha256(readFileSync(process.argv[1]));

  const result = {
    schema_version: "taste-a11y-live-result/v1",
    engine_id: ENGINE_ID,
    engine_package: ENGINE_PACKAGE,
    engine_version: ENGINE_VERSION,
    engine_source_sha256: selfSha,
    evidence_class: req.evidence_class,
    captures: req.captures.map(auditCapture),
  };
  const resPath = `${outDir}/result.json`;
  // Deterministic key order so output_sha256 is reproducible across runs.
  writeFileSync(resPath, stableStringify(result));
  const outBytes = readFileSync(resPath);

  const receipt = {
    schema_version: "taste-live-engine-receipt/v1",
    engine_id: ENGINE_ID,
    engine_version: ENGINE_VERSION,
    engine_source_sha256: selfSha,
    input_sha256: [sha256(reqBytes)],
    output_sha256: [sha256(outBytes)],
    exit_status: 0,
    executed_at: process.env.POLYLANE_A11Y_NOW || new Date().toISOString().replace(/\.\d+Z$/, "Z"),
  };
  writeFileSync(`${outDir}/receipt.json`, stableStringify(receipt));
}

// Deterministic JSON (sorted keys) so output_sha256 is reproducible.
function stableStringify(v) {
  if (v === null || typeof v !== "object") return JSON.stringify(v);
  if (Array.isArray(v)) return `[${v.map(stableStringify).join(",")}]`;
  const keys = Object.keys(v).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${stableStringify(v[k])}`).join(",")}}`;
}

// --- self-check (ponytail: one runnable check for the non-trivial logic) -----
function selfcheck() {
  const assert = (c, m) => { if (!c) { console.error("SELFCHECK FAIL:", m); process.exit(1); } };
  // Known WCAG ratios: black on white = 21:1; identical colors = 1:1.
  assert(round2(contrastRatio("#000000", "#ffffff")) === 21, "black/white must be 21:1");
  assert(round2(contrastRatio("#777", "#777")) === 1, "same color must be 1:1");
  assert(requiredRatio(16, false) === 4.5, "normal text needs 4.5");
  assert(requiredRatio(24, false) === 3.0, "large text needs 3.0");
  // Rule outcomes.
  const clean = { capture_id: "c", state: "default", dom_sha256: "x", action_trace_sha256: "y", payload: {
    dom: { landmarks: ["main"], headings: [{ level: 1 }, { level: 2 }],
      controls: [{ id: "b", role: "button", name: "Go", focusable: true, label: "Go", target_px: { w: 48, h: 48 } }],
      text_nodes: [{ id: "t", fg: "#000", bg: "#fff", font_px: 16 }],
      state_indicators: [], status_regions: [], error_fields: [] },
    actions: { reachable: ["b"], dom_order: ["b"], focus_order: ["b"], trap: false, escape_returns_focus: null, focus_visible: { b: true } },
    reflow: { viewport_css_px: { w: 320 }, content_width_px: 300, horizontal_scroll: false },
    motion: { has_motion: false } } };
  const rc = auditCapture(clean);
  assert(rc.checks.length === CRITERIA.length, "one check per criterion");
  const by = Object.fromEntries(rc.checks.map((c) => [c.criterion, c.status]));
  assert(by["contrast"] === "pass", "clean contrast passes");
  assert(by["target-size"] === "pass", "48px target passes");
  assert(by["reflow-zoom-overflow"] === "pass", "no overflow passes");
  assert(by["reduced-motion"] === "not-applicable", "no motion is n/a");
  assert(by["keyboard-escape"] === "not-applicable", "no overlay is n/a");
  // Violations.
  const bad = JSON.parse(JSON.stringify(clean));
  bad.payload.dom.text_nodes[0].fg = "#bbbbbb"; // low contrast on white
  bad.payload.dom.controls[0].target_px = { w: 20, h: 20 };
  bad.payload.actions.trap = true;
  bad.payload.reflow.horizontal_scroll = true;
  const bc = Object.fromEntries(auditCapture(bad).checks.map((c) => [c.criterion, c.status]));
  assert(bc["contrast"] === "fail", "low contrast fails");
  assert(bc["target-size"] === "fail", "small target fails");
  assert(bc["no-keyboard-trap"] === "fail", "trap fails");
  assert(bc["reflow-zoom-overflow"] === "fail", "overflow fails");
  // Skips (missing evidence must not pass).
  const gap = JSON.parse(JSON.stringify(clean));
  gap.payload.reflow = null;
  delete gap.payload.actions.trap;
  const gc = Object.fromEntries(auditCapture(gap).checks.map((c) => [c.criterion, c.status]));
  assert(gc["reflow-zoom-overflow"] === "skipped", "missing reflow is skipped");
  assert(gc["no-keyboard-trap"] === "skipped", "missing trap trace is skipped");
  console.log("SELFCHECK OK: contrast math + rule outcomes + skip-on-missing-evidence");
}

if (process.argv[2] === "--selfcheck") { selfcheck(); }
else if (process.argv[1] && process.argv[1].endsWith("accessibility.mjs")) { run(); }
