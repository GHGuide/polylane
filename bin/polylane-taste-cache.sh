#!/usr/bin/env bash
# polylane-taste-cache.sh — cache integrity and resume planner for the
# uncommitted primary taste corpus.
#
# Reads a pinned taste-source-plan/v1 and a content-addressed cache
# ($CACHE/objects/<sha[0:2]>/<sha>, atomic-publish sidecars end in .part) and:
#   inventory   — classify every declared object: ok, missing (absent or
#                 interrupted-partial), or corrupt (symlink, not-regular,
#                 empty, checksum-mismatch). Read-only; writes a report.
#   plan-resume — deterministic download work list (missing + corrupt).
#   quarantine  — move (never delete) still-corrupt objects named by an
#                 explicit integrity report into $CACHE/quarantine/. Each
#                 object is re-verified first; repaired objects are kept.
#
# Object ids are 64-hex sha256 names validated before any path is built, so a
# constructed path can never leave the cache root. The cache root itself must
# be an existing non-symlink directory.
#
# Bash 3.2 safe: no associative arrays, no process substitution.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage:
  polylane-taste-cache.sh inventory   CACHE_DIR PLAN.json REPORT.json
  polylane-taste-cache.sh plan-resume CACHE_DIR PLAN.json WORK.json
  polylane-taste-cache.sh quarantine  CACHE_DIR REPORT.json
USAGE
}

fail() { echo "TASTE-CACHE-INVALID: $*" >&2; exit 1; }

require_tools() {
  command -v jq >/dev/null 2>&1 || fail "jq is required"
  command -v shasum >/dev/null 2>&1 || fail "shasum is required"
}

# The declared boundary: an existing directory reached without a symlink root.
check_cache_root() {
  [ -n "$1" ] || fail "cache dir is empty"
  [ ! -L "$1" ] || fail "cache root is a symlink: $1"
  [ -d "$1" ] || fail "cache dir does not exist: $1"
}

# Content-addressed object path. The sha is hex-validated so it can never
# contain a path separator or a traversal segment; the result is then
# explicitly required to sit under the cache root.
obj_path() {
  case "$2" in
    *[!0-9a-f]* | "") fail "non-hex object id: $2" ;;
  esac
  [ "${#2}" -eq 64 ] || fail "object id is not a 64-hex sha256: $2"
  p="$1/objects/${2:0:2}/$2"
  case "$p" in
    "$1"/objects/*) ;;
    *) fail "object path escaped the cache root: $p" ;;
  esac
  printf '%s' "$p"
}

# Classify one declared object. Prints "status<TAB>reason".
# missing = the bytes were never published (absent, or an interrupted .part
# sidecar); corrupt = something occupies the published name but is not the
# declared bytes. Read-only.
classify_object() {
  path=$(obj_path "$1" "$2")
  if [ -L "$path" ]; then
    printf 'corrupt\tsymlink'
  elif [ ! -e "$path" ]; then
    if [ -e "$path.part" ] || [ -L "$path.part" ]; then
      printf 'missing\tinterrupted-partial'
    else
      printf 'missing\tabsent'
    fi
  elif [ ! -f "$path" ]; then
    printf 'corrupt\tnot-regular'
  elif [ ! -s "$path" ]; then
    printf 'corrupt\tempty'
  else
    actual=$(shasum -a 256 "$path" | awk '{print $1}')
    if [ "$actual" = "$2" ]; then
      printf 'ok\tverified'
    else
      printf 'corrupt\tchecksum-mismatch'
    fi
  fi
}

# Extract the declared object set from a pinned plan: every per-source
# metadata/aggregate/raw sha plus every image sha, deduplicated and sorted.
# Any shape drift fails closed before a single path is built.
declared_shas() {
  jq -e . "$1" >/dev/null 2>&1 || fail "plan is not valid JSON: $1"
  jq -r '
    def hash: if type == "string" and test("^[0-9a-f]{64}$") then .
              else error("bad-object-id") end;
    if type == "object" and .plan_version == "taste-source-plan/v1"
       and (.sources | type == "array") and (.images | type == "array")
    then ( [ .sources[] | (.metadata.sha256 | hash),
                          (.aggregate.sha256 | hash),
                          (.raw.sha256 | hash) ]
           + [ .images[].sha256 | hash ] ) | unique | .[]
    else error("bad-plan-shape") end
  ' "$1" 2>/dev/null || fail "plan must be taste-source-plan/v1 with 64-hex object ids"
}

# Scan the declared set into a TSV of "sha status reason" at $1.
scan_to_tsv() { # out cache plan
  : >"$1"
  declared_shas "$3" |
    while IFS= read -r sha; do
      line=$(classify_object "$2" "$sha")
      printf '%s\t%s\n' "$sha" "$line" >>"$1"
    done
  # An empty scan means declared_shas failed inside the pipeline.
  [ -s "$1" ] || fail "no declared objects extracted from plan: $3"
}

# Atomic JSON write: render to a sibling temp file, then mv into place.
emit_json() { # out jq-filter tsv
  tmp=$(mktemp "$1.tmp.XXXXXX") || fail "mktemp failed"
  jq -Rn "$2" "$3" >"$tmp" || { rm -f "$tmp"; fail "report render failed"; }
  mv -f "$tmp" "$1"
}

cmd_inventory() {
  cache=$1; plan=$2; report_out=$3
  check_cache_root "$cache"
  scan="$report_out.scan.$$"
  # shellcheck disable=SC2064
  trap "rm -f '$scan'" EXIT HUP INT TERM
  scan_to_tsv "$scan" "$cache" "$plan"
  emit_json "$report_out" '
    [inputs | split("\t") | { sha256: .[0], status: .[1], reason: .[2] }]
    | sort_by(.sha256)
    | { schema_version: "taste-cache-integrity/v1",
        counts: {
          declared: length,
          ok:      ([.[] | select(.status == "ok")] | length),
          missing: ([.[] | select(.status == "missing")] | length),
          corrupt: ([.[] | select(.status == "corrupt")] | length)
        },
        objects: . }' "$scan"
  bad=$(jq -r '.counts.missing + .counts.corrupt' "$report_out")
  [ "$bad" -eq 0 ] || { echo "TASTE-CACHE-DIRTY: $bad of $(jq -r .counts.declared "$report_out") declared objects need work (see $report_out)" >&2; exit 4; }
}

cmd_plan_resume() {
  cache=$1; plan=$2; work_out=$3
  check_cache_root "$cache"
  scan="$work_out.scan.$$"
  # shellcheck disable=SC2064
  trap "rm -f '$scan'" EXIT HUP INT TERM
  scan_to_tsv "$scan" "$cache" "$plan"
  emit_json "$work_out" '
    [inputs | split("\t") | { sha256: .[0], status: .[1], reason: .[2] }]
    | [ .[] | select(.status != "ok")
        | { sha256, action: "download", reason: "\(.status)/\(.reason)" } ]
    | sort_by(.sha256)
    | { schema_version: "taste-cache-resume/v1", count: length, work: . }' "$scan"
}

# Quarantine only what an explicit integrity report names as corrupt, and only
# after re-verifying that the object is still corrupt right now. Objects are
# moved — never deleted — into $CACHE/quarantine/<sha>.
cmd_quarantine() {
  cache=$1; report=$2
  check_cache_root "$cache"
  jq -e '.schema_version == "taste-cache-integrity/v1" and (.objects | type == "array")' \
    "$report" >/dev/null 2>&1 || fail "not a taste-cache-integrity/v1 report: $report"
  qdir="$cache/quarantine"
  jq -r '.objects[] | select(.status == "corrupt") | .sha256' "$report" |
    while IFS= read -r sha; do
      path=$(obj_path "$cache" "$sha")
      state=$(classify_object "$cache" "$sha")
      case "$state" in
        "corrupt	"*)
          dest="$qdir/$sha"
          [ ! -e "$dest" ] && [ ! -L "$dest" ] || fail "quarantine destination already exists: $dest"
          mkdir -p "$qdir"
          mv "$path" "$dest"
          echo "QUARANTINED: $sha (${state#corrupt	})"
          ;;
        "ok	"*)      echo "SKIPPED: $sha now verifies; kept in place" ;;
        "missing	"*) echo "SKIPPED: $sha not present; nothing to quarantine" ;;
      esac
    done
}

main() {
  require_tools
  [ "$#" -ge 1 ] || { usage >&2; exit 2; }
  sub=$1; shift
  case "$sub" in
    inventory)   [ "$#" -eq 3 ] || { usage >&2; exit 2; }; cmd_inventory "$@" ;;
    plan-resume) [ "$#" -eq 3 ] || { usage >&2; exit 2; }; cmd_plan_resume "$@" ;;
    quarantine)  [ "$#" -eq 2 ] || { usage >&2; exit 2; }; cmd_quarantine "$@" ;;
    *) usage >&2; exit 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
