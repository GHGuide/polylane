#!/usr/bin/env bash
# Visual packet creation starts only for manifests that explicitly request UI work.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

VISUAL="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-visual.sh"
make_tmpdir
MANIFEST="$TEST_TMPDIR/manifest.json"
printf '%s\n' '{"lanes":[{"name":"ui","own_globs":["src/components/**"]}]}' > "$MANIFEST"

assert_eq "visual-detects-ui-manifest" "ui" "$("$VISUAL" detect "$MANIFEST" 2>/dev/null)"

# A prepared packet is durable, multi-source, and carries one creative wildcard.
ROOT="$TEST_TMPDIR/project"; mkdir -p "$ROOT/.polylane" "$ROOT/evidence"
cp "$MANIFEST" "$ROOT/.polylane/run.json"
for image in a-d b-d c-d w-d a-m b-m c-m w-m; do printf '%s' fixture > "$ROOT/evidence/$image.png"; done
PACKET="$TEST_TMPDIR/references.json"
cat > "$PACKET" <<'JSON'
{"schema":1,"intensity":"economy","references":[
 {"id":"a","kind":"relevant","source_url":"https://a.example","desktop_screenshot":"evidence/a-d.png","mobile_screenshot":"evidence/a-m.png","dimensions":{"hierarchy":"cards","typography":"sans","palette":"warm","spatial_rhythm":"airy","interaction":"tabs","motion":"subtle","signature_ideas":"rail"},"borrow":["hierarchy"],"transform":["rail"],"avoid":["copy"]},
 {"id":"b","kind":"relevant","source_url":"https://b.example","desktop_screenshot":"evidence/b-d.png","mobile_screenshot":"evidence/b-m.png","dimensions":{"hierarchy":"grid","typography":"serif","palette":"cool","spatial_rhythm":"tight","interaction":"sheet","motion":"none","signature_ideas":"timeline"},"borrow":["grid"],"transform":["timeline"],"avoid":["copy"]},
 {"id":"c","kind":"relevant","source_url":"https://c.example","desktop_screenshot":"evidence/c-d.png","mobile_screenshot":"evidence/c-m.png","dimensions":{"hierarchy":"stack","typography":"mono","palette":"neutral","spatial_rhythm":"dense","interaction":"menu","motion":"soft","signature_ideas":"meter"},"borrow":["stack"],"transform":["meter"],"avoid":["copy"]},
 {"id":"w","kind":"wildcard","source_url":"https://w.example","desktop_screenshot":"evidence/w-d.png","mobile_screenshot":"evidence/w-m.png","dimensions":{"hierarchy":"poster","typography":"display","palette":"bold","spatial_rhythm":"asymmetry","interaction":"scroll","motion":"kinetic","signature_ideas":"orbit"},"borrow":["poster"],"transform":["orbit"],"avoid":["copy"]}],
 "directions":[{"id":"native","sources":["a","b"],"summary":"native"},{"id":"expressive","sources":["b","c"],"summary":"expressive"},{"id":"wild","sources":["c","w"],"summary":"wild"}],
 "council":[{"direction":"native","score":8},{"direction":"expressive","score":7},{"direction":"wild","score":6}],"winner":"native"}
JSON
assert_ok "visual-prepares-durable-reference-packet" "$VISUAL" prepare "$ROOT/.polylane/run.json" "$PACKET"
assert_ok "visual-reference-packet-is-valid" "$VISUAL" validate "$ROOT/.polylane/run.json"
assert_eq "visual-reference-winner-is-frozen" "native" "$(jq -r .winner "$ROOT/docs/polylane/design/references.json")"
assert_ok "visual-brief-is-durable" test -s "$ROOT/docs/polylane/design/VISUAL-BRIEF.md"
assert_contains "visual-decision-records-winner" "winner: native" "$(cat "$ROOT/docs/polylane/design/DESIGN-DECISION.md")"
assert_contains "visual-decision-records-source-mix" "sources: a, b" "$(cat "$ROOT/docs/polylane/design/DESIGN-DECISION.md")"

# A single source may inform a direction but cannot dominate every proposal.
jq '.directions |= map(.sources = ["a", "b"])' "$PACKET" > "$TEST_TMPDIR/dominant.json"
assert_fail "visual-rejects-dominant-reference-source" "$VISUAL" prepare "$ROOT/.polylane/run.json" "$TEST_TMPDIR/dominant.json"

printf '%s\n' '# tampered' > "$ROOT/docs/polylane/design/DESIGN-DECISION.md"
assert_fail "visual-rejects-unfrozen-design-decision" "$VISUAL" validate "$ROOT/.polylane/run.json"
finish
