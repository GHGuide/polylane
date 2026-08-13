#!/usr/bin/env bash
# Hermetic suite for benchmarks/taste-live/tools/dataone-metadata.mjs.
# All network traffic stays on a loopback fixture server owned by this test;
# fixture PIDs are real SHA-256 digests of the fixture bytes, and every fixture
# receipt must be stamped mode:"fixture" (no fixture may be stamped live).
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TOOL="$ROOT/benchmarks/taste-live/tools/dataone-metadata.mjs"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-dataone.XXXXXX")
FIX="$TMP/fix"
CACHE="$TMP/cache"
mkdir -p "$FIX" "$CACHE"
SRV_PID=""
trap 'rm -rf "$TMP"; if [ -n "$SRV_PID" ]; then kill "$SRV_PID" 2>/dev/null || true; fi' EXIT HUP INT TERM

PASS_COUNT=0
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'ok %02d %s\n' "$PASS_COUNT" "$1"; }
assert_eq() { [ "$1" = "$2" ] || fail "$3: expected '$1', got '$2'"; }

sha_of() { /usr/bin/shasum -a 256 "$1" | cut -d' ' -f1; }
size_of() { wc -c < "$1" | tr -d ' '; }

# --- 01 selftest (RED: fails while the adapter does not exist) --------------
node "$TOOL" --selftest || fail "selftest"
ok "selftest"

# --- fixture helpers ---------------------------------------------------------
# write_record OUT DOI LICENSE VERSION URL2 NAME2
write_record() {
  cat > "$1" <<EOF
{
  "@context": {"@vocab": "https://schema.org/"},
  "@type": "Dataset",
  "@id": "https://doi.org/$2",
  "identifier": "doi:$2",
  "name": "Fixture e-commerce homepage aesthetics dataset",
  "license": "$3",
  "version": "$4",
  "distribution": [
    {"@type": "DataDownload", "name": "img_0001.png",
     "contentUrl": "https://dataverse.harvard.edu/api/access/datafile/1000001",
     "contentSize": "12345"},
    {"@type": "DataDownload", "name": "$6",
     "contentUrl": "$5",
     "contentSize": "23456"}
  ]
}
EOF
}

# write_meta OUT CHECKSUM_HEX SIZE
write_meta() {
  cat > "$1" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<d1:systemMetadata xmlns:d1="http://ns.dataone.org/service/types/v2.0">
  <identifier>sha256:$2</identifier>
  <formatId>science-on-schema.org/Dataset;ld+json</formatId>
  <size>$3</size>
  <checksum algorithm="SHA-256">$2</checksum>
  <authoritativeMemberNode>urn:node:TestNode</authoritativeMemberNode>
</d1:systemMetadata>
EOF
}

# install_case FILE -> serves object+meta under its own digest, echoes hex
install_case() {
  local hex size
  hex=$(sha_of "$1")
  size=$(size_of "$1")
  cp "$1" "$FIX/obj-$hex"
  write_meta "$FIX/meta-$hex.xml" "$hex" "$size"
  printf '%s' "$hex"
}

# write_table OUT PID VERSION_JSON COUNT_JSON DOI [TOKENS_JSON]
write_table() {
  cat > "$1" <<EOF
{"e-commerce": {"doi": "$5", "pid": "$2", "version": $3,
 "title_tokens": ${6:-null}, "distributions": $4}}
EOF
}

# --- fixture server (loopback, owned by this test) ---------------------------
cat > "$TMP/server.cjs" <<'EOF'
const http = require('http'), fs = require('fs'), path = require('path');
const [dir, portfile] = process.argv.slice(2);
const srv = http.createServer((req, res) => {
  const u = decodeURIComponent(req.url);
  const m = u.match(/^\/cn\/v2\/(object|meta)\/sha256:([0-9a-f]{64})$/);
  if (!m) { res.writeHead(404); res.end('nf'); return; }
  const hex = m[2];
  if (fs.existsSync(path.join(dir, 'hang-' + hex))) return; // never answers
  if (fs.existsSync(path.join(dir, 'loop-' + hex))) {
    res.writeHead(302, { Location: req.url }); res.end(); return;
  }
  const f = path.join(dir, (m[1] === 'object' ? 'obj-' : 'meta-') + hex +
    (m[1] === 'meta' ? '.xml' : ''));
  if (!fs.existsSync(f)) { res.writeHead(404); res.end('nf'); return; }
  res.writeHead(200, { 'Content-Type':
    m[1] === 'object' ? 'application/ld+json' : 'text/xml' });
  res.end(fs.readFileSync(f));
});
srv.listen(0, '127.0.0.1', () =>
  fs.writeFileSync(portfile, String(srv.address().port)));
EOF
node "$TMP/server.cjs" "$FIX" "$TMP/port" &
SRV_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  [ -s "$TMP/port" ] && break
  sleep 0.1
done
[ -s "$TMP/port" ] || fail "fixture server did not start"
BASE="http://127.0.0.1:$(cat "$TMP/port")/cn/v2"

CC0="http://creativecommons.org/publicdomain/zero/1.0/"
GOOD_URL2="https://dataverse.harvard.edu/api/access/datafile/1000002"
DOI="10.7910/DVN/TESTAA1"

run_verify() { # TABLE [extra args...] -> stdout, records exit in RC
  local table=$1; shift
  RC=0
  OUT=$(node "$TOOL" verify --domain e-commerce --cache "$CACHE" \
    --base "$BASE" --table "$table" "$@" 2>"$TMP/err") || RC=$?
}
expect_error() { # CLASS CODE LABEL
  assert_eq "$([ "$1" = UNKNOWN ] && echo 3 || echo 2)" "$RC" "$3 exit"
  assert_eq "$1" "$(printf '%s' "$OUT" | jq -r '.error.class')" "$3 class"
  assert_eq "$2" "$(printf '%s' "$OUT" | jq -r '.error.code')" "$3 code"
  ok "$3"
}

# --- 02..04 valid case --------------------------------------------------------
write_record "$TMP/valid.json" "$DOI" "$CC0" "4" "$GOOD_URL2" "img_0002.png"
HEX=$(install_case "$TMP/valid.json")
write_table "$TMP/table-valid.json" "sha256:$HEX" '"4"' 2 "$DOI"
run_verify "$TMP/table-valid.json"
assert_eq "0" "$RC" "valid exit"
ok "valid verify exit 0"

assert_eq "polylane.taste.dataone.v1" "$(printf '%s' "$OUT" | jq -r '.schema')" "schema"
assert_eq "fixture" "$(printf '%s' "$OUT" | jq -r '.mode')" "mode"
assert_eq "false" "$(printf '%s' "$OUT" | jq -r '.source_bytes_supplied')" "source bytes"
assert_eq "$DOI" "$(printf '%s' "$OUT" | jq -r '.doi')" "doi"
assert_eq "sha256:$HEX" "$(printf '%s' "$OUT" | jq -r '.pid')" "pid"
assert_eq "$HEX" "$(printf '%s' "$OUT" | jq -r '.content_sha256')" "content sha"
assert_eq "2" "$(printf '%s' "$OUT" | jq -r '.distribution_count')" "dist count"
assert_eq "35801" "$(printf '%s' "$OUT" | jq -r '.total_distribution_bytes')" "dist bytes"
assert_eq "urn:node:TestNode" "$(printf '%s' "$OUT" | jq -r '.authoritative_member_node')" "member node"
assert_eq "4" "$(printf '%s' "$OUT" | jq -r '.version')" "version"
[ -s "$CACHE/receipts/dataone-e-commerce.json" ] || fail "receipt file missing"
ok "receipt scalars + fixture stamp + source_bytes_supplied=false"

WANT_HASH=$(printf '%s' "$OUT" | jq -r '.receipt_sha256')
GOT_HASH=$(printf '%s' "$OUT" | jq -cjS 'del(.receipt_sha256)' | /usr/bin/shasum -a 256 | cut -d' ' -f1)
assert_eq "$WANT_HASH" "$GOT_HASH" "receipt hash recompute"
ok "receipt_sha256 recomputes via jq -cS + shasum"

# --- 05 tampered bytes (pid is digest of different bytes) --------------------
write_record "$TMP/other.json" "$DOI" "$CC0" "4" "$GOOD_URL2" "img_0003.png"
OTHER_HEX=$(sha_of "$TMP/other.json")
cp "$TMP/valid.json" "$FIX/obj-$OTHER_HEX"           # serve wrong bytes
write_meta "$FIX/meta-$OTHER_HEX.xml" "$OTHER_HEX" "$(size_of "$TMP/valid.json")"
write_table "$TMP/table-tamper.json" "sha256:$OTHER_HEX" '"4"' 2 "$DOI"
run_verify "$TMP/table-tamper.json"
expect_error SOURCE-MISMATCH digest-mismatch "tampered bytes -> digest-mismatch"

# --- 06 wrong DOI -------------------------------------------------------------
write_record "$TMP/wrongdoi.json" "10.7910/DVN/TESTZZ9" "$CC0" "4" "$GOOD_URL2" "img_0002.png"
HEX2=$(install_case "$TMP/wrongdoi.json")
write_table "$TMP/table-doi.json" "sha256:$HEX2" '"4"' 2 "$DOI"
run_verify "$TMP/table-doi.json"
expect_error SOURCE-MISMATCH doi-mismatch "wrong DOI -> doi-mismatch"

# --- 07 wrong licence ----------------------------------------------------------
write_record "$TMP/wronglic.json" "$DOI" "https://creativecommons.org/licenses/by/4.0/" "4" "$GOOD_URL2" "img_0002.png"
HEX3=$(install_case "$TMP/wronglic.json")
write_table "$TMP/table-lic.json" "sha256:$HEX3" '"4"' 2 "$DOI"
run_verify "$TMP/table-lic.json"
expect_error SOURCE-MISMATCH licence-mismatch "wrong licence -> licence-mismatch"

# --- 08 wrong version -----------------------------------------------------------
write_record "$TMP/wrongver.json" "$DOI" "$CC0" "3" "$GOOD_URL2" "img_0002.png"
HEX4=$(install_case "$TMP/wrongver.json")
write_table "$TMP/table-ver.json" "sha256:$HEX4" '"4"' 2 "$DOI"
run_verify "$TMP/table-ver.json"
expect_error SOURCE-MISMATCH version-mismatch "wrong version -> version-mismatch"

# --- 09 duplicate distribution --------------------------------------------------
write_record "$TMP/dup.json" "$DOI" "$CC0" "4" "https://dataverse.harvard.edu/api/access/datafile/1000001" "img_0002.png"
HEX5=$(install_case "$TMP/dup.json")
write_table "$TMP/table-dup.json" "sha256:$HEX5" '"4"' 2 "$DOI"
run_verify "$TMP/table-dup.json"
expect_error SOURCE-MISMATCH duplicate-distribution "duplicate distribution URL"

# --- 10 distribution count mismatch ---------------------------------------------
write_table "$TMP/table-count.json" "sha256:$HEX" '"4"' 5 "$DOI"
run_verify "$TMP/table-count.json"
expect_error SOURCE-MISMATCH distribution-count-mismatch "distribution count mismatch"

# --- 11 non-canonical distribution URL -------------------------------------------
write_record "$TMP/badurl.json" "$DOI" "$CC0" "4" "https://evil.example.org/file/2" "img_0002.png"
HEX6=$(install_case "$TMP/badurl.json")
write_table "$TMP/table-url.json" "sha256:$HEX6" '"4"' 2 "$DOI"
run_verify "$TMP/table-url.json"
expect_error SOURCE-MISMATCH distribution-url "non-Harvard distribution URL"

# --- 12 title token miss ----------------------------------------------------------
write_table "$TMP/table-title.json" "sha256:$HEX" '"4"' 2 "$DOI" '["zebra"]'
run_verify "$TMP/table-title.json"
expect_error SOURCE-MISMATCH title-mismatch "title token miss"

# --- 13 sysmeta checksum mismatch ---------------------------------------------------
write_record "$TMP/sysbad.json" "$DOI" "$CC0" "4" "$GOOD_URL2" "img_0002.png"
printf ' ' >> "$TMP/sysbad.json"
HEX7=$(install_case "$TMP/sysbad.json")
write_meta "$FIX/meta-$HEX7.xml" "0000000000000000000000000000000000000000000000000000000000000000" "$(size_of "$TMP/sysbad.json")"
write_table "$TMP/table-sys.json" "sha256:$HEX7" '"4"' 2 "$DOI"
run_verify "$TMP/table-sys.json"
expect_error SOURCE-MISMATCH sysmeta-mismatch "sysmeta checksum mismatch"

# --- 14 sysmeta with MD5 checksum + namespaced elements must PASS -------------------
# Real DataONE CN sysmeta may declare an MD5 checksum and prefix element names; the
# adapter must verify the declared algorithm against the digest-validated bytes.
write_record "$TMP/md5ok.json" "$DOI" "$CC0" "4" "$GOOD_URL2" "img_0002.png"
printf '\n\n' >> "$TMP/md5ok.json"
HEXM=$(sha_of "$TMP/md5ok.json")
MD5M=$(/sbin/md5 -q "$TMP/md5ok.json")
cp "$TMP/md5ok.json" "$FIX/obj-$HEXM"
cat > "$FIX/meta-$HEXM.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<d1v2:systemMetadata xmlns:d1v2="http://ns.dataone.org/service/types/v2.0">
  <d1v2:identifier>sha256:$HEXM</d1v2:identifier>
  <d1v2:size>$(size_of "$TMP/md5ok.json")</d1v2:size>
  <d1v2:checksum algorithm='MD5'>$MD5M</d1v2:checksum>
  <d1v2:authoritativeMemberNode>urn:node:TestNode</d1v2:authoritativeMemberNode>
</d1v2:systemMetadata>
EOF
write_table "$TMP/table-md5.json" "sha256:$HEXM" '"4"' 2 "$DOI"
run_verify "$TMP/table-md5.json"
assert_eq "0" "$RC" "md5 sysmeta exit"
assert_eq "urn:node:TestNode" "$(printf '%s' "$OUT" | jq -r '.authoritative_member_node')" "md5 member node"
assert_eq "MD5" "$(printf '%s' "$OUT" | jq -r '.sysmeta_checksum_algorithm')" "md5 algorithm recorded"
ok "MD5 + namespaced sysmeta verifies against recomputed digest"

# --- 15 sysmeta identifier disagreeing with pid -> mismatch --------------------------
write_record "$TMP/idbad.json" "$DOI" "$CC0" "4" "$GOOD_URL2" "img_0002.png"
printf '\n\n\n' >> "$TMP/idbad.json"
HEXI=$(install_case "$TMP/idbad.json")
/usr/bin/sed -i '' "s|<identifier>sha256:$HEXI</identifier>|<identifier>sha256:$HEX</identifier>|" "$FIX/meta-$HEXI.xml"
write_table "$TMP/table-id.json" "sha256:$HEXI" '"4"' 2 "$DOI"
run_verify "$TMP/table-id.json"
expect_error SOURCE-MISMATCH sysmeta-mismatch "sysmeta identifier != pid"

# --- 16 non-JSON body with correct digest -------------------------------------------
printf '<html><body>challenge</body></html>\n' > "$TMP/nonjson.html"
HEX8=$(install_case "$TMP/nonjson.html")
write_table "$TMP/table-nonjson.json" "sha256:$HEX8" '"4"' 2 "$DOI"
run_verify "$TMP/table-nonjson.json"
expect_error SOURCE-MISMATCH non-json "non-JSON digest-valid body"

# --- 15 redirect loop -----------------------------------------------------------------
LOOP_HEX=$(printf 'redirect-loop-case' | /usr/bin/shasum -a 256 | cut -d' ' -f1)
touch "$FIX/loop-$LOOP_HEX"
write_table "$TMP/table-loop.json" "sha256:$LOOP_HEX" '"4"' 2 "$DOI"
run_verify "$TMP/table-loop.json"
expect_error UNKNOWN redirect "redirect loop"

# --- 16 timeout --------------------------------------------------------------------------
HANG_HEX=$(printf 'timeout-case' | /usr/bin/shasum -a 256 | cut -d' ' -f1)
touch "$FIX/hang-$HANG_HEX"
write_table "$TMP/table-hang.json" "sha256:$HANG_HEX" '"4"' 2 "$DOI"
run_verify "$TMP/table-hang.json" --timeout-ms 500
expect_error UNKNOWN timeout "timeout"

# --- 17 unknown domain -> usage --------------------------------------------------------------
RC=0
node "$TOOL" verify --domain not-a-domain --cache "$CACHE" --base "$BASE" \
  --table "$TMP/table-valid.json" >/dev/null 2>&1 || RC=$?
assert_eq "4" "$RC" "usage exit"
ok "unknown domain -> usage exit 4"

printf 'PASS test-taste-dataone-metadata (%d checks)\n' "$PASS_COUNT"
