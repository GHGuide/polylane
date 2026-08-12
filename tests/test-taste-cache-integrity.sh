#!/usr/bin/env bash
# Focused test for the cache-integrity lane: declared-object inventory,
# missing-vs-corrupt classification, deterministic resume planning,
# explicit-report quarantine (never delete), and cache-boundary containment.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TOOL="$ROOT/bin/polylane-taste-cache.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-cache.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
ASSERTIONS=0

assert_ok() { "$@" >/dev/null; ASSERTIONS=$((ASSERTIONS + 1)); }
assert_fail() {
  if "$@" >/dev/null 2>&1; then echo "expected failure: $*" >&2; exit 1; fi
  ASSERTIONS=$((ASSERTIONS + 1))
}
expect_eq() {
  if [ "$1" = "$2" ]; then ASSERTIONS=$((ASSERTIONS + 1));
  else echo "FAIL ${3:-assertion}: expected [$1] got [$2]" >&2; exit 1; fi
}

CACHE="$TMP/cache"
mkdir -p "$CACHE/objects"

sha_of() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

# Store bytes content-addressed; echo the sha256.
mk_obj() {
  printf '%s' "$1" >"$TMP/blob"
  s=$(shasum -a 256 "$TMP/blob" | awk '{print $1}')
  d="$CACHE/objects/${s:0:2}"; mkdir -p "$d"; cp "$TMP/blob" "$d/$s"
  printf '%s' "$s"
}

# Declared-object path for a sha (mirror of the tool's layout).
obj_dir() { printf '%s/objects/%s' "$CACHE" "${1:0:2}"; }

# Build a minimal but shape-valid plan from a list of image shas + 3 source shas.
write_plan() { # out meta agg raw img_shas...
  out=$1; meta=$2; agg=$3; raw=$4; shift 4
  : >"$TMP/imglist"
  n=0
  for s in "$@"; do
    n=$((n + 1))
    printf '%s\t%s\n' "stim-$n" "$s" >>"$TMP/imglist"
  done
  jq -Rn --arg meta "$meta" --arg agg "$agg" --arg raw "$raw" '
    {
      plan_version: "taste-source-plan/v1",
      sources: [{ id: "src-1",
                  metadata: { sha256: $meta },
                  aggregate: { sha256: $agg },
                  raw: { sha256: $raw } }],
      images: [inputs | split("\t") | { stimulus_id: .[0], source_id: "src-1", sha256: .[1] }]
    }' "$TMP/imglist" >"$out"
}

# ---------------------------------------------------------------------------
# 1. Malicious-path: the cache boundary must hold before anything else works.
# ---------------------------------------------------------------------------
echo "== malicious paths =="

META=$(mk_obj '{"pid":"doi:10.7910/DVN/9FKSQI","version":"2.0"}')
AGG=$(mk_obj '{"stim-1":{"mean":4.0}}')
RAW=$(mk_obj '{"stim-1":[4,4,4,4,4]}')
IMG1=$(mk_obj 'image-bytes-1')
IMG2=$(mk_obj 'image-bytes-2')

# Sentinel outside the cache: nothing the tool does may ever touch it.
SENTINEL="$TMP/outside-sentinel"
printf 'untouchable' >"$SENTINEL"

bad_plan() { # sha-value
  jq -n --arg bad "$1" '{
    plan_version: "taste-source-plan/v1",
    sources: [{ id: "s", metadata: { sha256: $bad },
                aggregate: { sha256: $bad }, raw: { sha256: $bad } }],
    images: [{ stimulus_id: "x", source_id: "s", sha256: $bad }]
  }' >"$TMP/bad-plan.json"
}

for bad in \
  "../../../../etc/passwd" \
  "..%2f..%2fetc%2fpasswd" \
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
  "AAAA637a1a24b7d10cba2b1e15ab7ea6466d0f425bdb0e6dc71421ff383ba7a6" \
  "637a1a24" \
  ""; do
  bad_plan "$bad"
  assert_fail bash "$TOOL" inventory "$CACHE" "$TMP/bad-plan.json" "$TMP/rep.json"
  assert_fail bash "$TOOL" plan-resume "$CACHE" "$TMP/bad-plan.json" "$TMP/work.json"
done

# Quarantine driven by a hostile report must also hold the boundary.
jq -n --arg bad "../../outside-sentinel" '{
  schema_version: "taste-cache-integrity/v1",
  objects: [{ sha256: $bad, status: "corrupt", reason: "checksum-mismatch" }]
}' >"$TMP/bad-report.json"
assert_fail bash "$TOOL" quarantine "$CACHE" "$TMP/bad-report.json"
expect_eq "untouchable" "$(cat "$SENTINEL")" "sentinel untouched after hostile report"

# Cache root itself must be a real, existing directory — not a symlink.
ln -s "$TMP" "$TMP/cache-link"
write_plan "$TMP/plan-ok.json" "$META" "$AGG" "$RAW" "$IMG1" "$IMG2"
assert_fail bash "$TOOL" inventory "$TMP/cache-link" "$TMP/plan-ok.json" "$TMP/rep.json"
assert_fail bash "$TOOL" inventory "$TMP/no-such-dir" "$TMP/plan-ok.json" "$TMP/rep.json"

# A failed run must not leave scan droppings next to the requested output.
leftovers=$(find "$TMP" -name 'rep.json.scan.*' -o -name 'work.json.scan.*' | wc -l | tr -d ' ')
expect_eq "0" "$leftovers" "no temp scan files leak on failure"

# Plan gate: wrong version or invalid JSON is terminal.
jq -n '{plan_version: "other/v9", sources: [], images: []}' >"$TMP/wrong-ver.json"
assert_fail bash "$TOOL" inventory "$CACHE" "$TMP/wrong-ver.json" "$TMP/rep.json"
printf 'not json' >"$TMP/not-json"
assert_fail bash "$TOOL" inventory "$CACHE" "$TMP/not-json" "$TMP/rep.json"

# ---------------------------------------------------------------------------
# 2. Interrupted cache: missing vs corrupt, every rejection class.
# ---------------------------------------------------------------------------
echo "== interrupted cache =="

# missing/absent: declared but never downloaded
MISSING=$(sha_of 'never-downloaded-bytes')
# missing/interrupted-partial: only an atomic-publish .part sidecar exists
PARTIAL=$(sha_of 'interrupted-download-bytes')
mkdir -p "$(obj_dir "$PARTIAL")"
printf 'first-half-' >"$(obj_dir "$PARTIAL")/$PARTIAL.part"
# corrupt/empty
EMPTY=$(sha_of 'would-be-empty-object')
mkdir -p "$(obj_dir "$EMPTY")"
: >"$(obj_dir "$EMPTY")/$EMPTY"
# corrupt/checksum-mismatch: wrong bytes at the declared name
WRONG=$(sha_of 'declared-bytes')
mkdir -p "$(obj_dir "$WRONG")"
printf 'tampered-bytes' >"$(obj_dir "$WRONG")/$WRONG"
# corrupt/symlink
SYM=$(sha_of 'symlinked-object')
mkdir -p "$(obj_dir "$SYM")"
ln -s "$SENTINEL" "$(obj_dir "$SYM")/$SYM"
# corrupt/not-regular: a directory squatting on the object path
DIRSHA=$(sha_of 'directory-object')
mkdir -p "$(obj_dir "$DIRSHA")/$DIRSHA"

write_plan "$TMP/plan-mixed.json" "$META" "$AGG" "$RAW" \
  "$IMG1" "$MISSING" "$PARTIAL" "$EMPTY" "$WRONG" "$SYM" "$DIRSHA"

# Inventory writes the report and signals issues with exit 4.
set +e
bash "$TOOL" inventory "$CACHE" "$TMP/plan-mixed.json" "$TMP/report.json" >/dev/null 2>&1
rc=$?
set -e
expect_eq "4" "$rc" "inventory exit code on dirty cache"

status_of() { jq -r --arg s "$1" '.objects[] | select(.sha256 == $s) | "\(.status)/\(.reason)"' "$TMP/report.json"; }
expect_eq "ok/verified"                  "$(status_of "$IMG1")"    "intact object"
expect_eq "ok/verified"                  "$(status_of "$META")"    "metadata object"
expect_eq "missing/absent"               "$(status_of "$MISSING")" "absent object"
expect_eq "missing/interrupted-partial"  "$(status_of "$PARTIAL")" "partial sidecar"
expect_eq "corrupt/empty"                "$(status_of "$EMPTY")"   "empty object"
expect_eq "corrupt/checksum-mismatch"    "$(status_of "$WRONG")"   "mismatched bytes"
expect_eq "corrupt/symlink"              "$(status_of "$SYM")"     "symlink object"
expect_eq "corrupt/not-regular"          "$(status_of "$DIRSHA")"  "directory object"

expect_eq "taste-cache-integrity/v1" "$(jq -r .schema_version "$TMP/report.json")" "report schema"
expect_eq "10" "$(jq -r .counts.declared "$TMP/report.json")" "declared count"
expect_eq "4"  "$(jq -r .counts.ok "$TMP/report.json")" "ok count"
expect_eq "2"  "$(jq -r .counts.missing "$TMP/report.json")" "missing count"
expect_eq "4"  "$(jq -r .counts.corrupt "$TMP/report.json")" "corrupt count"

# Validation is read-only: partial sidecar and tampered bytes still in place.
expect_eq "first-half-" "$(cat "$(obj_dir "$PARTIAL")/$PARTIAL.part")" "sidecar untouched"
expect_eq "tampered-bytes" "$(cat "$(obj_dir "$WRONG")/$WRONG")" "corrupt bytes untouched"

# Clean cache: exit 0.
write_plan "$TMP/plan-clean.json" "$META" "$AGG" "$RAW" "$IMG1" "$IMG2"
assert_ok bash "$TOOL" inventory "$CACHE" "$TMP/plan-clean.json" "$TMP/report-clean.json"
expect_eq "0" "$(jq -r '.counts.missing + .counts.corrupt' "$TMP/report-clean.json")" "clean cache"

# ---------------------------------------------------------------------------
# 3. Deterministic resume planning.
# ---------------------------------------------------------------------------
echo "== resume planning =="

assert_ok bash "$TOOL" plan-resume "$CACHE" "$TMP/plan-mixed.json" "$TMP/work-1.json"
assert_ok bash "$TOOL" plan-resume "$CACHE" "$TMP/plan-mixed.json" "$TMP/work-2.json"
cmp -s "$TMP/work-1.json" "$TMP/work-2.json" || { echo "resume plan not deterministic" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

expect_eq "taste-cache-resume/v1" "$(jq -r .schema_version "$TMP/work-1.json")" "work schema"
expect_eq "6" "$(jq -r '.work | length' "$TMP/work-1.json")" "work covers missing+corrupt"
# Sorted by sha256 and download-only actions.
expect_eq "true" "$(jq '[.work[].sha256] == ([.work[].sha256] | sort)' "$TMP/work-1.json")" "work sorted"
expect_eq "true" "$(jq '[.work[].action] | unique == ["download"]' "$TMP/work-1.json")" "download actions"
# ok objects are never re-downloaded.
expect_eq "0" "$(jq -r --arg s "$IMG1" '[.work[] | select(.sha256 == $s)] | length' "$TMP/work-1.json")" "no rework for ok"
# Clean cache → empty work.
assert_ok bash "$TOOL" plan-resume "$CACHE" "$TMP/plan-clean.json" "$TMP/work-clean.json"
expect_eq "0" "$(jq -r '.work | length' "$TMP/work-clean.json")" "clean cache empty work"

# ---------------------------------------------------------------------------
# 4. Quarantine: explicit report only, move-never-delete, re-verify first.
# ---------------------------------------------------------------------------
echo "== quarantine =="

# Repair one corrupt object between report and quarantine: it must be skipped.
printf 'declared-bytes' >"$(obj_dir "$WRONG")/$WRONG"

assert_ok bash "$TOOL" quarantine "$CACHE" "$TMP/report.json"

# Repaired object stays live.
expect_eq "declared-bytes" "$(cat "$(obj_dir "$WRONG")/$WRONG")" "repaired object kept"
[ ! -e "$CACHE/quarantine/$WRONG" ] || { echo "repaired object was quarantined" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# Still-corrupt objects moved (not deleted): bytes preserved under quarantine/.
[ -e "$CACHE/quarantine/$EMPTY" ] || { echo "empty object not quarantined" >&2; exit 1; }
[ ! -e "$(obj_dir "$EMPTY")/$EMPTY" ] || { echo "empty object still live" >&2; exit 1; }
[ -L "$CACHE/quarantine/$SYM" ] || { echo "symlink not quarantined as symlink" >&2; exit 1; }
[ -d "$CACHE/quarantine/$DIRSHA" ] || { echo "dir object not quarantined" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 3))

# ok/missing entries in the report are never touched.
expect_eq "image-bytes-1" "$(cat "$(obj_dir "$IMG1")/$IMG1")" "ok object untouched"
[ ! -e "$CACHE/quarantine/$MISSING" ] || { echo "missing object 'quarantined'" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# Quarantine requires the exact report schema.
jq -n '{schema_version: "something-else/v1", objects: []}' >"$TMP/alien-report.json"
assert_fail bash "$TOOL" quarantine "$CACHE" "$TMP/alien-report.json"

# Sentinel outside the cache survived the whole suite.
expect_eq "untouchable" "$(cat "$SENTINEL")" "sentinel untouched at end"

echo "OK: $ASSERTIONS assertions"
