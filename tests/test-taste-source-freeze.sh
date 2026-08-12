#!/usr/bin/env bash
# Hermetic tests for bin/polylane-taste-source-freeze.sh: reconcile canonical
# Harvard receipts with immutable DataONE receipts for the three frozen DOIs
# into one deterministic frozen acquisition plan. Every disagreement, missing
# domain, duplicate identity, caller trust bit, or post-freeze mutation must
# fail closed.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
FREEZE="$ROOT/bin/polylane-taste-source-freeze.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-source-freeze.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
ASSERTIONS=0

assert_ok() {
  "$@" >/dev/null
  ASSERTIONS=$((ASSERTIONS + 1))
}

assert_fail() {
  if "$@" >/dev/null 2>&1; then
    echo "expected failure: $*" >&2
    exit 1
  fi
  ASSERTIONS=$((ASSERTIONS + 1))
}

expect_eq() {
  if [ "$1" = "$2" ]; then
    ASSERTIONS=$((ASSERTIONS + 1))
  else
    echo "FAIL ${3:-assertion}: expected [$1] got [$2]" >&2
    exit 1
  fi
}

# Deterministic fake 64-hex sha for fixtures.
fake_sha() {
  printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
}

DOI_ECOM="doi:10.7910/DVN/9FKSQI"
DOI_UNI="doi:10.7910/DVN/XOI0HI"
DOI_BANK="doi:10.7910/DVN/Z7KLIH"
PID_ECOM="sha256:6ff2435a723445a99d8ef725da000115fc6d5716babaa776ea1604e30bb870e9"
PID_UNI="sha256:71ee5e0dbf9e0b47bb95d6291ab337e02322907f20a996d028376e3065cf20f5"
PID_BANK="sha256:6fe3377fec3aa24ce8c3b697791440c26400146381b7e5fc0ae7834daf0b78df"

# files_json DOMAIN -> shared file array (identical identity view on both sides)
files_json() {
  domain=$1
  cat <<JSON
[
  {"file_id":"${domain}-raw-1","name":"${domain}-raw.csv","role":"raw","sha256":"$(fake_sha "${domain}-raw")","size":1001},
  {"file_id":"${domain}-agg-1","name":"${domain}-aggregate.csv","role":"aggregate","sha256":"$(fake_sha "${domain}-agg")","size":1002},
  {"file_id":"${domain}-img-1","name":"${domain}-img-1.png","role":"image","sha256":"$(fake_sha "${domain}-img-1")","size":2001},
  {"file_id":"${domain}-img-2","name":"${domain}-img-2.png","role":"image","sha256":"$(fake_sha "${domain}-img-2")","size":2002}
]
JSON
}

write_harvard() {
  dir=$1; domain=$2; doi=$3; version=$4
  jq -n --arg doi "$doi" --arg domain "$domain" --arg version "$version" \
    --arg msha "$(fake_sha "harvard-meta-$domain")" \
    --arg lsha "$(fake_sha "license-$domain")" \
    --argjson files "$(files_json "$domain")" '
    {
      receipt_version: "taste-harvard-receipt/v1",
      doi: $doi,
      domain: $domain,
      dataset_version: $version,
      endpoint: "https://dataverse.harvard.edu/api/datasets/:persistentId/?persistentId=\($doi)",
      metadata_sha256: $msha,
      license: {
        spdx: "CC0-1.0",
        url: "https://creativecommons.org/publicdomain/zero/1.0/",
        sha256: $lsha
      },
      files: $files
    }' >"$dir/$domain.json"
}

write_dataone() {
  dir=$1; domain=$2; doi=$3; pid=$4; version=$5
  jq -n --arg doi "$doi" --arg domain "$domain" --arg pid "$pid" --arg version "$version" \
    --argjson files "$(files_json "$domain")" '
    {
      receipt_version: "taste-dataone-receipt/v1",
      pid: $pid,
      doi: $doi,
      domain: $domain,
      dataset_version: $version,
      member_node: "urn:node:mnUCSB1",
      license: {
        spdx: "CC0-1.0",
        url: "https://creativecommons.org/publicdomain/zero/1.0/"
      },
      distributions: [$files[] | {file_id, name, sha256, size}]
    }' >"$dir/$domain.json"
}

# Build a full valid fixture set under $1 (harvard/ + dataone/).
write_fixture() {
  base=$1
  mkdir -p "$base/harvard" "$base/dataone"
  write_harvard "$base/harvard" e-commerce "$DOI_ECOM" "4.0"
  write_harvard "$base/harvard" universities "$DOI_UNI" "3.0"
  write_harvard "$base/harvard" commercial-banks "$DOI_BANK" "2.1"
  # DataONE states the same versions with Harvard's trailing ".0" dropped.
  write_dataone "$base/dataone" e-commerce "$DOI_ECOM" "$PID_ECOM" "4"
  write_dataone "$base/dataone" universities "$DOI_UNI" "$PID_UNI" "3"
  write_dataone "$base/dataone" commercial-banks "$DOI_BANK" "$PID_BANK" "2.1"
}

# jq-edit one receipt file in place.
mutate() {
  file=$1; expr=$2
  jq "$expr" "$file" >"$file.tmp"
  mv "$file.tmp" "$file"
}

# --- happy path: compile emits a canonical frozen plan --------------------

GOOD="$TMP/good"
write_fixture "$GOOD"
PLAN="$TMP/plan.json"
assert_ok "$FREEZE" compile "$GOOD/harvard" "$GOOD/dataone" "$PLAN"
[ -f "$PLAN" ] || { echo "plan not written" >&2; exit 1; }

expect_eq "taste-source-freeze-plan/v1" "$(jq -r '.plan_version' "$PLAN")" plan-version
expect_eq "3" "$(jq -r '.sources | length' "$PLAN")" three-domains
expect_eq "commercial-banks e-commerce universities" \
  "$(jq -r '[.sources[].domain] | join(" ")' "$PLAN")" sorted-domains
expect_eq "$DOI_ECOM" \
  "$(jq -r '.sources[] | select(.domain == "e-commerce") | .doi' "$PLAN")" ecom-doi
expect_eq "$PID_ECOM" \
  "$(jq -r '.sources[] | select(.domain == "e-commerce") | .dataone_pid' "$PLAN")" ecom-pid
# Version agreement is on the normalized value.
expect_eq "4" \
  "$(jq -r '.sources[] | select(.domain == "e-commerce") | .dataset_version' "$PLAN")" ecom-version
expect_eq "2.1" \
  "$(jq -r '.sources[] | select(.domain == "commercial-banks") | .dataset_version' "$PLAN")" bank-version
# Selected acquisition inputs: one raw, one aggregate, images.
expect_eq "e-commerce-raw-1" \
  "$(jq -r '.sources[] | select(.domain == "e-commerce") | .acquisition.raw.file_id' "$PLAN")" raw-selected
expect_eq "e-commerce-agg-1" \
  "$(jq -r '.sources[] | select(.domain == "e-commerce") | .acquisition.aggregate.file_id' "$PLAN")" agg-selected
expect_eq "2" \
  "$(jq -r '.sources[] | select(.domain == "e-commerce") | .acquisition.images | length' "$PLAN")" images-selected
# No caller-authored trust bits survive into the plan.
expect_eq "0" "$(jq '[paths(type == "boolean")] | length' "$PLAN")" no-booleans

# Freeze hash binds the canonical body.
BODY_SHA=$(jq -cS 'del(.freeze_sha256)' "$PLAN" | shasum -a 256 | awk '{print $1}')
expect_eq "$BODY_SHA" "$(jq -r '.freeze_sha256' "$PLAN")" freeze-hash

# --- canonical serialization: byte-identical recompile --------------------

PLAN2="$TMP/plan2.json"
assert_ok "$FREEZE" compile "$GOOD/harvard" "$GOOD/dataone" "$PLAN2"
cmp -s "$PLAN" "$PLAN2" || { echo "compile is not deterministic" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# --- replay: verify accepts the untouched plan ----------------------------

assert_ok "$FREEZE" verify "$GOOD/harvard" "$GOOD/dataone" "$PLAN"

# --- post-freeze mutation fails closed ------------------------------------

TAMPERED="$TMP/tampered.json"
jq '.sources[0].acquisition.images[0].sha256 = "1111111111111111111111111111111111111111111111111111111111111111"' \
  "$PLAN" >"$TAMPERED"
assert_fail "$FREEZE" verify "$GOOD/harvard" "$GOOD/dataone" "$TAMPERED"
# Even with a recomputed freeze hash over the tampered body, replay must fail.
TAMPERED_SHA=$(jq -cS 'del(.freeze_sha256)' "$TAMPERED" | shasum -a 256 | awk '{print $1}')
jq --arg sha "$TAMPERED_SHA" '.freeze_sha256 = $sha' "$TAMPERED" >"$TAMPERED.2"
assert_fail "$FREEZE" verify "$GOOD/harvard" "$GOOD/dataone" "$TAMPERED.2"
# Input mutation after freeze also fails replay.
MUT="$TMP/mut-input"
write_fixture "$MUT"
mutate "$MUT/harvard/e-commerce.json" '.files[2].sha256 = "2222222222222222222222222222222222222222222222222222222222222222"'
mutate "$MUT/dataone/e-commerce.json" '.distributions[2].sha256 = "2222222222222222222222222222222222222222222222222222222222222222"'
assert_fail "$FREEZE" verify "$MUT/harvard" "$MUT/dataone" "$PLAN"

# Compiling onto an existing plan is a mutation attempt.
assert_fail "$FREEZE" compile "$GOOD/harvard" "$GOOD/dataone" "$PLAN"

# --- all-three-domain quota -----------------------------------------------

MISSING="$TMP/missing"
write_fixture "$MISSING"
rm "$MISSING/harvard/universities.json"
assert_fail "$FREEZE" compile "$MISSING/harvard" "$MISSING/dataone" "$TMP/out-missing.json"
write_fixture "$TMP/missing-d1"
rm "$TMP/missing-d1/dataone/commercial-banks.json"
assert_fail "$FREEZE" compile "$TMP/missing-d1/harvard" "$TMP/missing-d1/dataone" "$TMP/out-missing-d1.json"

# --- identity disagreements are terminal ----------------------------------

freshly_broken() {
  name=$1; side=$2; domain=$3; expr=$4
  base="$TMP/$name"
  write_fixture "$base"
  mutate "$base/$side/$domain.json" "$expr"
  assert_fail "$FREEZE" compile "$base/harvard" "$base/dataone" "$TMP/out-$name.json"
}

# DOI disagreement (both against frozen table and across mirrors).
freshly_broken doi-swap dataone e-commerce ".doi = \"$DOI_UNI\""
freshly_broken doi-frozen harvard e-commerce '.doi = "doi:10.7910/DVN/WRONG"'
# Wrong immutable DataONE PID.
freshly_broken pid-wrong dataone universities ".pid = \"$PID_ECOM\""
# Domain label disagreement inside a receipt.
freshly_broken domain-label dataone e-commerce '.domain = "universities"'
# Licence drift on either side.
freshly_broken licence-drift-d dataone e-commerce '.license.spdx = "CC-BY-4.0"'
freshly_broken licence-drift-h harvard universities '.license.spdx = "MIT"'
# Version drift (normalized values must agree).
freshly_broken version-drift dataone e-commerce '.dataset_version = "3"'
freshly_broken version-drift-h harvard commercial-banks '.dataset_version = "2.2"'
# File identity drift: checksum, name, size, missing, extra.
freshly_broken file-sha dataone e-commerce '.distributions[2].sha256 = "3333333333333333333333333333333333333333333333333333333333333333"'
freshly_broken file-name dataone e-commerce '.distributions[2].name = "renamed.png"'
freshly_broken file-size dataone e-commerce '.distributions[2].size = 9999'
freshly_broken file-missing dataone e-commerce '.distributions |= .[0:3]'
freshly_broken file-extra dataone e-commerce '.distributions += [{"file_id":"ghost-1","name":"ghost.png","sha256":"4444444444444444444444444444444444444444444444444444444444444444","size":1}]'

# --- duplicate file id / name ---------------------------------------------

freshly_broken dup-id harvard e-commerce '.files[3].file_id = .files[2].file_id'
freshly_broken dup-name harvard e-commerce '.files[3].name = .files[2].name'
freshly_broken dup-id-d dataone e-commerce '.distributions[3].file_id = .distributions[2].file_id'

# --- caller-authored trust bits -------------------------------------------

freshly_broken trust-key harvard e-commerce '.verified = "yes"'
freshly_broken trust-key-nested dataone e-commerce '.distributions[0].approved = "x"'
freshly_broken trust-bool harvard e-commerce '.files[0].size_ok = true'

# --- strict keys and shapes -----------------------------------------------

freshly_broken extra-key harvard e-commerce '.surprise = "field"'
freshly_broken extra-file-key harvard e-commerce '.files[0].note = "hello"'
freshly_broken extra-key-d dataone e-commerce '.extra = 1'
freshly_broken bad-version-tag harvard e-commerce '.receipt_version = "taste-harvard-receipt/v0"'
freshly_broken bad-sha harvard e-commerce '.metadata_sha256 = "abc"'
freshly_broken bad-role harvard e-commerce '.files[0].role = "mystery"'
freshly_broken http-endpoint harvard e-commerce '.endpoint = "http://dataverse.harvard.edu/insecure"'
# Role quota: exactly one raw, one aggregate, at least one image.
freshly_broken no-images harvard e-commerce '.files |= [.[] | select(.role != "image")]'
freshly_broken no-images-d dataone e-commerce '.distributions |= .[0:2]'
freshly_broken two-raw harvard e-commerce '.files[1].role = "raw"'

# Broken JSON and symlinked receipts fail closed.
BAD="$TMP/badjson"
write_fixture "$BAD"
echo '{' >"$BAD/harvard/e-commerce.json"
assert_fail "$FREEZE" compile "$BAD/harvard" "$BAD/dataone" "$TMP/out-badjson.json"
LINKED="$TMP/linked"
write_fixture "$LINKED"
mv "$LINKED/harvard/e-commerce.json" "$LINKED/harvard/real.json"
ln -s "$LINKED/harvard/real.json" "$LINKED/harvard/e-commerce.json"
assert_fail "$FREEZE" compile "$LINKED/harvard" "$LINKED/dataone" "$TMP/out-linked.json"

# Failed compiles must not leave partial plans behind.
for leftover in "$TMP"/out-*.json; do
  [ -e "$leftover" ] && { echo "failed compile left partial plan: $leftover" >&2; exit 1; }
done
ASSERTIONS=$((ASSERTIONS + 1))

echo "ok - taste-source-freeze ($ASSERTIONS assertions)"
