#!/usr/bin/env bash
# test-taste-generate-live.sh — the isolated fixed-model builder-campaign runner.
#
# FIXTURE-ONLY harness. Every "builder" here is a hermetic local shell script,
# never a real model CLI: per EXTERNAL-EVIDENCE, a fake builder can exercise the
# runner's machinery but can never mint a production candidate receipt (that
# needs a coordinator-owned allowlist entry pinning the real builder identity).
# Red-first: the harness proves the runner REJECTS the ways a build can be fake,
# missing, stale, forged, or rigged before it accepts the one clean shape.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

GEN="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-taste-generate.sh"
make_tmpdir
ROOT="$TEST_TMPDIR"
CAMP="$ROOT/campaign"; mkdir -p "$CAMP/prompts"
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
txt_sha() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

# --- frozen prompt units (one baseline + three current directions) -----------
for d in base c1 c2 c3; do
  printf 'Build the Acme storefront landing page — design direction %s.\n' "$d" > "$CAMP/prompts/$d.txt"
done

# --- the good hermetic builder: a distinct static offline site per direction --
BUILDER="$ROOT/fake-builder.sh"
cat > "$BUILDER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out="$POLYLANE_BUILD_OUTPUT"; dir="$POLYLANE_BUILD_DIRECTION_ID"; cfg="$POLYLANE_BUILD_CONFIG"
mkdir -p "$out/about"
cat > "$out/index.html" <<HTML
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Acme $dir</title>
<link rel="stylesheet" href="app.css"></head>
<body><header><h1>Acme Store — $dir edition</h1></header>
<main><p>Browse the $dir storefront: real product copy, a working catalog, and a checkout that keeps state.</p>
<a href="/about">About us</a></main><script src="app.js"></script></body></html>
HTML
printf 'body{font-family:system-ui;margin:2rem;color:#1a1a2%s}\n' "${dir: -1}" > "$out/app.css"
printf 'document.title="Acme %s ready";\n' "$dir" > "$out/app.js"
cat > "$out/about/index.html" <<HTML
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>About Acme $dir</title></head>
<body><h1>About the $dir store</h1><p>We are a small team shipping delightful commerce experiences.</p></body></html>
HTML
printf '{"dependencies":[],"usage":{"tokens_input":128,"tokens_output":690,"tokens_total":818}}\n' > "$cfg/build-meta.json"
EOF
chmod +x "$BUILDER"

# mk_manifest OUT BUILDER DEADLINE [fixture_only] -> writes $CAMP/campaign.json
mk_manifest() {
  local out="$1" builder="$2" deadline="$3" fixture="${4:-true}" bsha
  bsha=$(sha "$builder")
  cat > "$CAMP/campaign.json" <<JSON
{
  "schema_version":"taste-generate-campaign/v1",
  "run_id":"live-harness-1",
  "output_root":"$out",
  "deadline_seconds":$deadline,
  "fixture_only":$fixture,
  "builder":{"adapter_id":"fake-builder","adapter_version":"0.0.1","command_sha256":"$bsha","model":"claude-opus-4-8","effort":"xhigh"},
  "briefs":[
    {"brief_id":"brief-shop","brief_sha256":"$(txt_sha shop-brief)","required_routes":["/","/about"],
     "arms":[
       {"arm_id":"arm-base","role":"baseline","direction_id":"base","prompt_path":"prompts/base.txt","prompt_sha256":"$(sha "$CAMP/prompts/base.txt")"},
       {"arm_id":"arm-c1","role":"current","direction_id":"c1","prompt_path":"prompts/c1.txt","prompt_sha256":"$(sha "$CAMP/prompts/c1.txt")"},
       {"arm_id":"arm-c2","role":"current","direction_id":"c2","prompt_path":"prompts/c2.txt","prompt_sha256":"$(sha "$CAMP/prompts/c2.txt")"},
       {"arm_id":"arm-c3","role":"current","direction_id":"c3","prompt_path":"prompts/c3.txt","prompt_sha256":"$(sha "$CAMP/prompts/c3.txt")"}
     ]}
  ]
}
JSON
}

run_gen() { env TASTE_NOW=2026-08-12T00:00:00Z "$GEN" run "$CAMP/campaign.json" -- "$1"; }

# ============================================================================
# 1. SUCCESS — clean campaign builds 4 candidates with all three receipts
# ============================================================================
OUT="$ROOT/out"
mk_manifest "$OUT" "$BUILDER" 30
assert_ok   "success-clean-campaign-completes" run_gen "$BUILDER"
assert_eq   "success-builds-four-candidates" "4" "$(find "$OUT" -name candidate.json -type f | wc -l | tr -d ' ')"
assert_eq   "success-one-baseline-three-current" "1 3" \
  "$(find "$OUT" -name build-receipt.json -type f -exec jq -r .role {} \; | LC_ALL=C sort | uniq -c | awk '{print $1}' | paste -sd' ' -)"
assert_ok   "success-emits-source-build-compute-receipts" bash -c '
  for c in "$1"/brief-shop/arm-*; do
    for r in source-receipt build-receipt compute-receipt candidate; do
      [ -f "$c/$r.json" ] || exit 1
    done
  done' _ "$OUT"
assert_ok   "success-candidate-is-taste-candidate-v1" jq -e '(keys|sort)==["brief_sha256","build_receipt_sha256","candidate_id","created_at","dependency_lock_sha256","design_lock_sha256","direction_id","schema_version","source_revision"] and .schema_version=="taste-candidate/v1"' "$OUT/brief-shop/arm-base/candidate.json"
assert_ok   "success-marks-fixture-classification" jq -e '.classification=="fixture"' "$OUT/brief-shop/arm-base/build-receipt.json"
assert_ok   "success-compute-records-usage-when-reported" jq -e '.usage.tokens_total==818 and .usage_source=="builder-reported" and (.timing.duration_ms|type=="number")' "$OUT/brief-shop/arm-base/compute-receipt.json"
assert_ok   "success-build-records-functional-start" jq -e '.functional_start.started==true and (.functional_start.required_routes==["/","/about"]) and .functional_start.routes_present==true' "$OUT/brief-shop/arm-base/build-receipt.json"
assert_ok   "success-source-receipt-recomputes-hashes" jq -e '(.source_sha256|test("^[0-9a-f]{64}$")) and (.files|length>=3) and .offline==true' "$OUT/brief-shop/arm-base/source-receipt.json"
assert_ok   "success-candidate-passes-standalone-verify" "$GEN" verify "$OUT/brief-shop/arm-c1"

# --- NO HIDDEN WINNER: blinded candidate carries no identity/rank/model -------
assert_ok   "blinded-no-model-provider-rank-in-candidate" bash -c '
  ! grep -rilE "claude-opus-4-8|provider|\"model\"|winner|rank|score|champion|effort" "$1"/*/*/candidate.json' _ "$OUT"
assert_ok   "blinded-no-winner-file-emitted" bash -c '! find "$1" -iname "*winner*" -o -iname "*champion*" -o -iname "*rank*" | grep -q .' _ "$OUT"
assert_ok   "blinded-source-has-no-model-identity" bash -c '! grep -rilF "claude-opus-4-8" "$1"/*/*/source' _ "$OUT"
assert_eq   "no-leftover-temp-workspaces" "" "$(find "$OUT" -maxdepth 1 -name '.polylane-generate.*' 2>/dev/null)"

# ============================================================================
# 2. IDEMPOTENT RESUME — second run skips verified candidates untouched
# ============================================================================
BEFORE=$(sha "$OUT/brief-shop/arm-base/candidate.json")
resume_out=$(run_gen "$BUILDER" 2>&1)
assert_contains "resume-skips-verified-candidate" "skip brief-shop/arm-base" "$resume_out"
assert_eq   "resume-is-byte-idempotent" "$BEFORE" "$(sha "$OUT/brief-shop/arm-base/candidate.json")"

# ============================================================================
# 3. PARTIAL CRASH / RESUME — a failed arm is retried, the rest are untouched
# ============================================================================
CRASHY="$ROOT/crashy-builder.sh"; cp "$BUILDER" "$CRASHY"
# exit non-zero for exactly one direction, simulating a mid-campaign crash
sed -i '' '/^mkdir -p "\$out\/about"/i\
[ "$dir" != "c2" ] || exit 7
' "$CRASHY"
chmod +x "$CRASHY"
POUT="$ROOT/partial-out"
mk_manifest "$POUT" "$CRASHY" 30
assert_fail "partial-crash-fails-campaign" run_gen "$CRASHY"
assert_eq   "partial-crash-builds-only-good-arms" "3" "$(find "$POUT" -name candidate.json -type f | wc -l | tr -d ' ')"
assert_ok   "partial-crash-leaves-no-partial-candidate-for-failed-arm" bash -c '[ ! -e "$1/brief-shop/arm-c2/candidate.json" ]' _ "$POUT"
GOOD_C1_SHA=$(sha "$POUT/brief-shop/arm-c1/candidate.json")
mk_manifest "$POUT" "$BUILDER" 30
assert_ok   "resume-after-crash-completes" run_gen "$BUILDER"
assert_eq   "resume-after-crash-fills-missing-arm" "4" "$(find "$POUT" -name candidate.json -type f | wc -l | tr -d ' ')"
assert_eq   "resume-after-crash-untouches-good-arm" "$GOOD_C1_SHA" "$(sha "$POUT/brief-shop/arm-c1/candidate.json")"
# a corrupted-but-present candidate (torn write) is rebuilt, not trusted
printf 'tampered\n' >> "$POUT/brief-shop/arm-c3/source/index.html"
assert_fail "torn-write-fails-verify" "$GEN" verify "$POUT/brief-shop/arm-c3"
assert_ok   "torn-write-is-rebuilt-on-resume" run_gen "$BUILDER"
assert_ok   "rebuilt-candidate-verifies" "$GEN" verify "$POUT/brief-shop/arm-c3"

# ============================================================================
# 4. TIMEOUT — a builder past the deadline is killed and the arm fails closed
# ============================================================================
SLOW="$ROOT/slow-builder.sh"
cat > "$SLOW" <<'EOF'
#!/usr/bin/env bash
set -eu
mkdir -p "$POLYLANE_BUILD_OUTPUT"
exec sleep 30
EOF
chmod +x "$SLOW"
mk_manifest "$ROOT/timeout-out" "$SLOW" 2
assert_fail "timeout-builder-fails-closed" run_gen "$SLOW"
assert_ok   "timeout-produces-no-candidate" bash -c '[ ! -e "$1/timeout-out/brief-shop/arm-base/candidate.json" ]' _ "$ROOT"

# ============================================================================
# 5. NONZERO EXIT — a builder that errors yields no candidate
# ============================================================================
ERRB="$ROOT/err-builder.sh"
printf '#!/usr/bin/env bash\nmkdir -p "$POLYLANE_BUILD_OUTPUT"\nexit 3\n' > "$ERRB"; chmod +x "$ERRB"
mk_manifest "$ROOT/err-out" "$ERRB" 30
assert_fail "nonzero-builder-fails-campaign" run_gen "$ERRB"

# ============================================================================
# 6. MISSING FILES — no entry index.html is rejected
# ============================================================================
NOIDX="$ROOT/noindex-builder.sh"
printf '#!/usr/bin/env bash\nset -eu\nmkdir -p "$POLYLANE_BUILD_OUTPUT"\nprintf hi > "$POLYLANE_BUILD_OUTPUT/readme.txt"\n' > "$NOIDX"; chmod +x "$NOIDX"
mk_manifest "$ROOT/noidx-out" "$NOIDX" 30
assert_fail "missing-entry-index-rejected" run_gen "$NOIDX"

# missing a required route (index present, /about absent)
NOROUTE="$ROOT/noroute-builder.sh"
cat > "$NOROUTE" <<'EOF'
#!/usr/bin/env bash
set -eu
mkdir -p "$POLYLANE_BUILD_OUTPUT"
printf '<!doctype html><title>x</title><body><main><p>A storefront page with genuine content here.</p></main></body>' > "$POLYLANE_BUILD_OUTPUT/index.html"
EOF
chmod +x "$NOROUTE"
mk_manifest "$ROOT/noroute-out" "$NOROUTE" 30
assert_fail "missing-required-route-rejected" run_gen "$NOROUTE"

# ============================================================================
# 7. DIRTY TEMPLATE — build-tool droppings (node_modules/.git) rejected
# ============================================================================
DIRTY="$ROOT/dirty-builder.sh"; cp "$BUILDER" "$DIRTY"
sed -i '' '/^printf .{.dependencies/i\
mkdir -p "$out/node_modules/left-pad"; printf junk > "$out/node_modules/left-pad/index.js"
' "$DIRTY"
chmod +x "$DIRTY"
mk_manifest "$ROOT/dirty-out" "$DIRTY" 30
assert_fail "dirty-template-droppings-rejected" run_gen "$DIRTY"

# ============================================================================
# 8. NETWORK ASSET — remote asset/font/API reference rejected (offline rule)
# ============================================================================
NET="$ROOT/net-builder.sh"; cp "$BUILDER" "$NET"
sed -i '' 's#<link rel="stylesheet" href="app.css">#<link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Inter">#' "$NET"
chmod +x "$NET"
mk_manifest "$ROOT/net-out" "$NET" 30
assert_fail "network-asset-reference-rejected" run_gen "$NET"
# a namespace URI (xmlns) is NOT a fetch and must still pass
NS="$ROOT/ns-builder.sh"; cp "$BUILDER" "$NS"
sed -i '' 's#<main>#<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8"/></svg><main>#' "$NS"
chmod +x "$NS"
mk_manifest "$ROOT/ns-out" "$NS" 30
assert_ok   "namespace-uri-not-treated-as-network-asset" run_gen "$NS"

# ============================================================================
# 9. PLACEHOLDER-ONLY & HIDDEN PROVENANCE
# ============================================================================
PH="$ROOT/placeholder-builder.sh"
cat > "$PH" <<'EOF'
#!/usr/bin/env bash
set -eu
mkdir -p "$POLYLANE_BUILD_OUTPUT/about"
printf '<!doctype html><title>x</title><body>Lorem ipsum</body>' > "$POLYLANE_BUILD_OUTPUT/index.html"
printf '<!doctype html><title>a</title><body>Lorem ipsum</body>' > "$POLYLANE_BUILD_OUTPUT/about/index.html"
EOF
chmod +x "$PH"
mk_manifest "$ROOT/ph-out" "$PH" 30
assert_fail "placeholder-only-screen-rejected" run_gen "$PH"

PROV="$ROOT/prov-builder.sh"; cp "$BUILDER" "$PROV"
sed -i '' 's#<script src="app.js">#<meta name="generator" content="built by claude-opus-4-8"><script src="app.js">#' "$PROV"
chmod +x "$PROV"
mk_manifest "$ROOT/prov-out" "$PROV" 30
assert_fail "hidden-provenance-rejected" run_gen "$PROV"

# ============================================================================
# 10. CHANGED PROMPT / CHANGED MODEL(builder) — pinned identity enforced
# ============================================================================
mk_manifest "$ROOT/cp-out" "$BUILDER" 30
# tamper the frozen prompt on disk after it was pinned
printf 'MUTATED\n' >> "$CAMP/prompts/base.txt"
assert_fail "changed-frozen-prompt-rejected" run_gen "$BUILDER"
# restore
printf 'Build the Acme storefront landing page — design direction base.\n' > "$CAMP/prompts/base.txt"

# swap the builder binary so its sha no longer matches the pinned command_sha256
OTHER="$ROOT/other-builder.sh"; cp "$BUILDER" "$OTHER"; printf '# drift\n' >> "$OTHER"; chmod +x "$OTHER"
mk_manifest "$ROOT/cm-out" "$BUILDER" 30
assert_fail "changed-builder-model-sha-rejected" run_gen "$OTHER"

# ============================================================================
# 11. DUPLICATE CANDIDATES — identical output across arms rigs the tournament
# ============================================================================
SAME="$ROOT/same-builder.sh"
cat > "$SAME" <<'EOF'
#!/usr/bin/env bash
set -eu
out="$POLYLANE_BUILD_OUTPUT"; mkdir -p "$out/about"
printf '<!doctype html><title>Same</title><body><main><p>Identical storefront output for every design direction here.</p><a href="/about">About</a></main></body>' > "$out/index.html"
printf '<!doctype html><title>Same about</title><body><h1>About</h1><p>Identical about page for all directions.</p></body>' > "$out/about/index.html"
EOF
chmod +x "$SAME"
mk_manifest "$ROOT/dup-out" "$SAME" 30
assert_fail "duplicate-source-across-arms-rejected" run_gen "$SAME"

# ============================================================================
# 12. SYMLINK / PATH ESCAPE — output-root symlink and in-tree symlinks rejected
# ============================================================================
mkdir -p "$ROOT/realout"; ln -s "$ROOT/realout" "$ROOT/out-symlink"
mk_manifest "$ROOT/out-symlink" "$BUILDER" 30
assert_fail "symlinked-output-root-rejected" run_gen "$BUILDER"

SYM="$ROOT/symlink-builder.sh"; cp "$BUILDER" "$SYM"
sed -i '' '/^printf .{.dependencies/i\
ln -s /etc/hosts "$out/escape.html"
' "$SYM"
chmod +x "$SYM"
mk_manifest "$ROOT/sym-out" "$SYM" 30
assert_fail "in-tree-symlink-escape-rejected" run_gen "$SYM"

# ============================================================================
# 13. FORGED BUILD RECEIPT — tamper-evident chain caught by verify
# ============================================================================
FORGE="$ROOT/forge-out"
mk_manifest "$FORGE" "$BUILDER" 30
run_gen "$BUILDER" >/dev/null 2>&1
FDIR="$FORGE/brief-shop/arm-base"
# (a) edit the build receipt body — candidate.build_receipt_sha256 no longer matches
cp "$FDIR/build-receipt.json" "$FDIR/build-receipt.json.orig"
jq '.model="claude-forged"' "$FDIR/build-receipt.json.orig" > "$FDIR/build-receipt.json"
assert_fail "forged-build-receipt-breaks-candidate-binding" "$GEN" verify "$FDIR"
mv "$FDIR/build-receipt.json.orig" "$FDIR/build-receipt.json"
assert_ok   "restored-receipt-verifies-again" "$GEN" verify "$FDIR"
# (b) forge source hash inside the build receipt AND re-point the candidate to it
jq '.source_sha256="'"$(txt_sha forged)"'"' "$FDIR/build-receipt.json" > "$FDIR/bad.json"
mv "$FDIR/bad.json" "$FDIR/build-receipt.json"
NEWSHA=$(sha "$FDIR/build-receipt.json")
jq '.build_receipt_sha256="'"$NEWSHA"'"' "$FDIR/candidate.json" > "$FDIR/candc.json"
mv "$FDIR/candc.json" "$FDIR/candidate.json"
assert_fail "forged-source-hash-caught-by-recompute" "$GEN" verify "$FDIR"

# ============================================================================
# 14. MANIFEST SHAPE — malformed campaign contracts rejected up front
# ============================================================================
mk_manifest "$ROOT/shape-out" "$BUILDER" 30
# wrong arm mix: two baselines
jq '.briefs[0].arms[1].role="baseline"' "$CAMP/campaign.json" > "$ROOT/bad-mix.json"
assert_fail "manifest-wrong-baseline-current-mix-rejected" env TASTE_NOW=2026-08-12T00:00:00Z "$GEN" run "$ROOT/bad-mix.json" -- "$BUILDER"
# duplicate directions within a brief
jq '.briefs[0].arms[2].direction_id="c1"' "$CAMP/campaign.json" > "$ROOT/bad-dir.json"
assert_fail "manifest-duplicate-direction-rejected" env TASTE_NOW=2026-08-12T00:00:00Z "$GEN" run "$ROOT/bad-dir.json" -- "$BUILDER"
# unknown schema version
jq '.schema_version="taste-generate-campaign/v9"' "$CAMP/campaign.json" > "$ROOT/bad-schema.json"
assert_fail "manifest-unknown-schema-rejected" env TASTE_NOW=2026-08-12T00:00:00Z "$GEN" run "$ROOT/bad-schema.json" -- "$BUILDER"
# prompt path traversal
jq '.briefs[0].arms[0].prompt_path="../secret.txt"' "$CAMP/campaign.json" > "$ROOT/bad-path.json"
assert_fail "manifest-prompt-traversal-rejected" env TASTE_NOW=2026-08-12T00:00:00Z "$GEN" run "$ROOT/bad-path.json" -- "$BUILDER"

# ============================================================================
# 15. PRODUCTION TRUST BOUNDARY — fixture cannot self-promote to production
# ============================================================================
mk_manifest "$ROOT/prod-out" "$BUILDER" 30 false
assert_fail "production-without-allowlist-blocked" run_gen "$BUILDER"
# a coordinator-owned allowlist pinning this exact identity authorizes production
BCANON="$(cd "$(dirname "$BUILDER")" && pwd -P)/$(basename "$BUILDER")"
ALLOW="$ROOT/allowlist.json"
jq -n --arg p "$BCANON" --arg v "0.0.1" --arg c "$(sha "$BUILDER")" --arg m "claude-opus-4-8" --arg e "xhigh" \
  '{schema_version:"taste-generate-allowlist/v1",entries:[{builder_path:$p,adapter_version:$v,command_sha256:$c,model:$m,effort:$e}]}' > "$ALLOW"
assert_ok   "production-with-allowlist-authorized" env TASTE_NOW=2026-08-12T00:00:00Z POLYLANE_GENERATE_ALLOWLIST="$ALLOW" "$GEN" run "$CAMP/campaign.json" -- "$BUILDER"
assert_ok   "production-candidate-marked-production" jq -e '.classification=="production"' "$ROOT/prod-out/brief-shop/arm-base/build-receipt.json"
# an arbitrary builder not named by the allowlist cannot pose as authorized
mk_manifest "$ROOT/prod-out2" "$OTHER" 30 false
assert_fail "production-unlisted-builder-blocked" env TASTE_NOW=2026-08-12T00:00:00Z POLYLANE_GENERATE_ALLOWLIST="$ALLOW" "$GEN" run "$CAMP/campaign.json" -- "$OTHER"

finish
