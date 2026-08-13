#!/usr/bin/env bash
# polylane-taste-source-freeze.sh — fail-closed source-freeze compiler.
#
# Reconciles canonical Harvard Dataverse receipts with immutable DataONE
# receipts for exactly the three frozen Miniukovich–Figl DOIs and emits one
# deterministic frozen acquisition plan (source hashes plus the selected
# raw/aggregate/image acquisition inputs per domain).
#
# The compiler is hermetic: it consumes caller-supplied receipt files only and
# never fetches or upgrades evidence. Harvard is the canonical byte/label
# authority; DataONE is an independent provenance mirror. Any DOI, domain,
# licence, version, or file-identity disagreement is SOURCE-MISMATCH and
# terminal — never a majority vote. Missing domains, duplicate file ids or
# names, caller-authored trust bits (booleans or trust-key names), and any
# post-freeze mutation of the plan or its inputs fail closed.
#
# Bash 3.2 safe: no associative arrays, no process substitution.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage:
  polylane-taste-source-freeze.sh compile HARVARD_DIR DATAONE_DIR OUT_PLAN.json
  polylane-taste-source-freeze.sh verify  HARVARD_DIR DATAONE_DIR PLAN.json

HARVARD_DIR holds one taste-harvard-receipt/v1 JSON per frozen domain
(<domain>.json); DATAONE_DIR holds the matching taste-dataone-receipt/v1
files. compile refuses to overwrite an existing plan; verify recompiles from
the receipts and requires the frozen plan to match byte for byte.
USAGE
}

fail() { echo "SOURCE-FREEZE-INVALID: $*" >&2; exit 1; }

WORKDIR=""
REPLAY=""
clean_tmp() {
  [ -n "$WORKDIR" ] && rm -rf "$WORKDIR"
  [ -n "$REPLAY" ] && rm -f "$REPLAY"
  return 0
}

require_tools() {
  command -v jq >/dev/null 2>&1 || fail "jq is required"
  command -v shasum >/dev/null 2>&1 || fail "shasum is required"
}

# Frozen three-domain source table (Cycle 41 research lock). Sorted by domain.
FROZEN_DOMAINS="commercial-banks e-commerce universities"

frozen_doi() {
  case "$1" in
    e-commerce) printf 'doi:10.7910/DVN/9FKSQI' ;;
    universities) printf 'doi:10.7910/DVN/XOI0HI' ;;
    commercial-banks) printf 'doi:10.7910/DVN/Z7KLIH' ;;
    *) fail "unknown frozen domain: $1" ;;
  esac
}

frozen_pid() {
  case "$1" in
    e-commerce) printf 'sha256:6ff2435a723445a99d8ef725da000115fc6d5716babaa776ea1604e30bb870e9' ;;
    universities) printf 'sha256:71ee5e0dbf9e0b47bb95d6291ab337e02322907f20a996d028376e3065cf20f5' ;;
    commercial-banks) printf 'sha256:6fe3377fec3aa24ce8c3b697791440c26400146381b7e5fc0ae7834daf0b78df' ;;
    *) fail "unknown frozen domain: $1" ;;
  esac
}

# Shared jq predicates injected before every validation program.
JQ_DEFS='
  def hash: type == "string" and test("^[0-9a-f]{64}$");
  def stable: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
  def posint: type == "number" and . > 0 and (floor == .);
  def https: type == "string" and test("^https://[^[:space:]]+$");
  def no_trust_bits:
    ([paths(type == "boolean")] | length == 0)
    and ([.. | objects | keys[]
          | select(test("^(eligible|certified|trusted|verified|approved)$"; "i"))]
         | length == 0);
  def norm_version: sub("\\.0$"; "");
'

receipt_file() {
  # receipt_file DIR DOMAIN SIDE -> path (fail closed on shape)
  path="$1/$2.json"
  [ ! -L "$path" ] || fail "$3 receipt is a symlink for domain $2: $path"
  [ -f "$path" ] || fail "missing $3 receipt for domain $2: $path"
  jq -e . "$path" >/dev/null 2>&1 || fail "$3 receipt is not valid JSON for domain $2"
  printf '%s' "$path"
}

validate_harvard() {
  # validate_harvard FILE DOMAIN DOI
  jq -e --arg domain "$2" --arg doi "$3" "$JQ_DEFS"'
    type == "object"
    and no_trust_bits
    and ((keys - ["dataset_version","doi","domain","endpoint","files",
                  "license","metadata_sha256","receipt_version"]) == [])
    and .receipt_version == "taste-harvard-receipt/v1"
    and .domain == $domain
    and .doi == $doi
    and (.dataset_version | type == "string" and length > 0)
    and (.endpoint | https)
    and (.metadata_sha256 | hash)
    and (.license | type == "object"
      and ((keys - ["sha256","spdx","url"]) == [])
      and .spdx == "CC0-1.0"
      and (.url | https)
      and (.sha256 | hash))
    and (.files | type == "array" and length > 0
      and all(.[];
        type == "object"
        and ((keys - ["file_id","name","role","sha256","size"]) == [])
        and (.file_id | stable)
        and (.name | stable)
        and (.role as $r | ["aggregate","image","raw"] | index($r) != null)
        and (.sha256 | hash)
        and (.size | posint))
      and ([.[].file_id] | length == (unique | length))
      and ([.[].name] | length == (unique | length))
      and ([.[] | select(.role == "raw")] | length == 1)
      and ([.[] | select(.role == "aggregate")] | length == 1)
      and ([.[] | select(.role == "image")] | length >= 1))
  ' "$1" >/dev/null 2>&1 ||
    fail "harvard receipt for domain $2 violates the frozen contract (strict keys, CC0-1.0, frozen DOI, unique file id/name, one raw + one aggregate + images, no trust bits)"
}

validate_dataone() {
  # validate_dataone FILE DOMAIN DOI PID
  jq -e --arg domain "$2" --arg doi "$3" --arg pid "$4" "$JQ_DEFS"'
    type == "object"
    and no_trust_bits
    and ((keys - ["dataset_version","distributions","doi","domain","license",
                  "member_node","pid","receipt_version"]) == [])
    and .receipt_version == "taste-dataone-receipt/v1"
    and .domain == $domain
    and .doi == $doi
    and .pid == $pid
    and (.dataset_version | type == "string" and length > 0)
    and (.member_node | type == "string" and test("^urn:node:[A-Za-z0-9._-]+$"))
    and (.license | type == "object"
      and ((keys - ["spdx","url"]) == [])
      and .spdx == "CC0-1.0"
      and (.url | https))
    and (.distributions | type == "array" and length > 0
      and all(.[];
        type == "object"
        and ((keys - ["file_id","name","sha256","size"]) == [])
        and (.file_id | stable)
        and (.name | stable)
        and (.sha256 | hash)
        and (.size | posint))
      and ([.[].file_id] | length == (unique | length))
      and ([.[].name] | length == (unique | length)))
  ' "$1" >/dev/null 2>&1 ||
    fail "dataone receipt for domain $2 violates the frozen contract (strict keys, CC0-1.0, frozen DOI, immutable PID, unique file id/name, no trust bits)"
}

# Cross-check both receipts for one domain and print the frozen source object.
reconcile_domain() {
  # reconcile_domain HARVARD_FILE DATAONE_FILE DOMAIN
  jq -e -n --slurpfile h "$1" --slurpfile d "$2" "$JQ_DEFS"'
    $h[0] as $hv | $d[0] as $dv
    | (($hv.dataset_version | norm_version) == ($dv.dataset_version | norm_version))
      as $version_ok
    | ($hv.license.spdx == $dv.license.spdx) as $licence_ok
    | (([$hv.files[] | {file_id, name, sha256, size}] | sort_by(.file_id))
       == ($dv.distributions | sort_by(.file_id))) as $files_ok
    | if ($version_ok and $licence_ok and $files_ok) then
        {
          domain: $hv.domain,
          doi: $hv.doi,
          dataone_pid: $dv.pid,
          dataset_version: ($hv.dataset_version | norm_version),
          license: $hv.license,
          harvard_endpoint: $hv.endpoint,
          harvard_metadata_sha256: $hv.metadata_sha256,
          dataone_member_node: $dv.member_node,
          acquisition: {
            raw: ([$hv.files[] | select(.role == "raw")
                   | {file_id, name, sha256, size}] | first),
            aggregate: ([$hv.files[] | select(.role == "aggregate")
                         | {file_id, name, sha256, size}] | first),
            images: ([$hv.files[] | select(.role == "image")
                      | {file_id, name, sha256, size}] | sort_by(.file_id))
          }
        }
      else empty end
  ' 2>/dev/null ||
    fail "SOURCE-MISMATCH: harvard and dataone disagree on version, licence, or file identity for domain $3"
}

# Compile the frozen plan from receipts into OUT (no overwrite checks here;
# callers own that policy). Output is canonical: jq -S over sorted content.
compile_to() {
  harvard_dir=$1; dataone_dir=$2; out=$3
  [ -d "$harvard_dir" ] || fail "harvard receipt dir does not exist: $harvard_dir"
  [ -d "$dataone_dir" ] || fail "dataone receipt dir does not exist: $dataone_dir"

  WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/taste-source-freeze.XXXXXX")

  for domain in $FROZEN_DOMAINS; do
    doi=$(frozen_doi "$domain")
    pid=$(frozen_pid "$domain")
    hfile=$(receipt_file "$harvard_dir" "$domain" harvard)
    dfile=$(receipt_file "$dataone_dir" "$domain" dataone)
    validate_harvard "$hfile" "$domain" "$doi"
    validate_dataone "$dfile" "$domain" "$doi" "$pid"
    reconcile_domain "$hfile" "$dfile" "$domain" >"$WORKDIR/source-$domain.json"
  done

  jq -s -S '{
    plan_version: "taste-source-freeze-plan/v1",
    classification: "frozen-three-domain-source",
    sources: sort_by(.domain)
  }' "$WORKDIR/source-commercial-banks.json" \
     "$WORKDIR/source-e-commerce.json" \
     "$WORKDIR/source-universities.json" >"$WORKDIR/body.json"

  freeze_sha=$(jq -cS . "$WORKDIR/body.json" | shasum -a 256 | awk '{print $1}')
  jq -S --arg sha "$freeze_sha" '. + {freeze_sha256: $sha}' \
    "$WORKDIR/body.json" >"$WORKDIR/plan.json"
  mv "$WORKDIR/plan.json" "$out"
  rm -rf "$WORKDIR"
  WORKDIR=""
}

cmd_compile() {
  [ $# -eq 3 ] || { usage >&2; exit 2; }
  out=$3
  [ ! -e "$out" ] && [ ! -L "$out" ] ||
    fail "plan already frozen, refusing to overwrite: $out (use verify)"
  compile_to "$1" "$2" "$out"
  echo "SOURCE-FREEZE-OK: $out"
}

cmd_verify() {
  [ $# -eq 3 ] || { usage >&2; exit 2; }
  plan=$3
  [ ! -L "$plan" ] || fail "plan is a symlink: $plan"
  [ -f "$plan" ] || fail "plan does not exist: $plan"
  jq -e . "$plan" >/dev/null 2>&1 || fail "plan is not valid JSON: $plan"

  claimed=$(jq -r '.freeze_sha256 // empty' "$plan")
  actual=$(jq -cS 'del(.freeze_sha256)' "$plan" | shasum -a 256 | awk '{print $1}')
  [ -n "$claimed" ] && [ "$claimed" = "$actual" ] ||
    fail "post-freeze mutation: freeze_sha256 does not match the plan body: $plan"

  REPLAY=$(mktemp "${TMPDIR:-/tmp}/taste-source-freeze-replay.XXXXXX")
  compile_to "$1" "$2" "$REPLAY"
  cmp -s "$REPLAY" "$plan" ||
    fail "post-freeze mutation: plan does not match a fresh compile of its receipts: $plan"
  rm -f "$REPLAY"
  REPLAY=""
  echo "SOURCE-FREEZE-VERIFIED: $plan"
}

main() {
  require_tools
  trap clean_tmp EXIT HUP INT TERM
  [ $# -ge 1 ] || { usage >&2; exit 2; }
  cmd=$1; shift
  case "$cmd" in
    compile) cmd_compile "$@" ;;
    verify) cmd_verify "$@" ;;
    -h | --help | help) usage ;;
    *) usage >&2; exit 2 ;;
  esac
}

main "$@"
