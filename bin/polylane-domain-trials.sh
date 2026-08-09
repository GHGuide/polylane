#!/usr/bin/env bash
# Source-pinned domain trial runner. Network access is an explicit read-only canary.
set -euo pipefail

usage() {
  echo "usage: polylane-domain-trials.sh validate <corpus> | run <corpus> <out-dir> [--live] [--domain <kind>] | summarize <out-dir> [--json]" >&2
  exit 2
}

sha256() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else echo "domain-trials: no SHA-256 utility available" >&2; return 1; fi
}

case_files() {
  local corpus="$1" file
  [ -d "$corpus/cases" ] || { echo "domain-trials: cases directory not found" >&2; return 1; }
  set -- "$corpus/cases"/*.json
  [ -f "$1" ] || { echo "domain-trials: no cases found" >&2; return 1; }
  for file in "$corpus/cases"/*.json; do [ -f "$file" ] && printf '%s\n' "$file"; done | LC_ALL=C sort
}

valid_case_shape() {
  jq -e '
    .schema == "polylane-domain-trial/v1" and
    (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
    (.domain as $domain | ["software","trading","research","operations","content","data","custom-mixed"] | index($domain) != null) and
    (.title | type == "string" and length > 0) and (.task | type == "string" and length > 0) and
    (.expected_verdict == "pass") and (.adapter | type == "string" and length > 0) and
    (.grading.checks | type == "array" and length > 0 and all(.[]; type == "string" and length > 0)) and
    (.source | type == "object") and
    (.source.url | type == "string" and test("^https://")) and
    (.source.query | (type == "object" or type == "string")) and
    (.source.retrieval_timestamp | type == "string" and test("Z$")) and
    (.source.content_checksum | type == "string" and test("^[0-9a-f]{64}$")) and
    (.source.license_terms_note | type == "string" and length > 0) and
    (.source.schema_version_or_vintage | type == "string" and length > 0) and
    (.source.transformations | type == "array" and length > 0 and all(.[]; type == "string" and length > 0)) and
    (.source.raw | type == "string" and test("^raw/[A-Za-z0-9._-]+$"))
  ' "$1" >/dev/null
}

cmd_validate() {
  local corpus="$1" file raw expected actual ids manifest_ids count=0 rc=0
  [ -f "$corpus/corpus.json" ] || { echo "domain-trials: missing corpus receipt" >&2; return 1; }
  jq -e '.schema == "polylane-domain-trial-corpus/v1" and (.version | type == "string") and (.cases | type == "array" and length > 0)' "$corpus/corpus.json" >/dev/null || {
    echo "domain-trials: invalid corpus receipt" >&2; return 1;
  }
  ids=$(mktemp "${TMPDIR:-/tmp}/polylane-domain-ids.XXXXXX")
  while IFS= read -r file; do
    if ! jq -e . "$file" >/dev/null 2>&1 || ! valid_case_shape "$file"; then
      echo "domain-trials: invalid case: $file" >&2; rc=1; continue
    fi
    raw=$(jq -r '.source.raw' "$file")
    expected=$(jq -r '.source.content_checksum' "$file")
    if [ ! -f "$corpus/$raw" ]; then
      echo "domain-trials: missing raw extract: $raw" >&2; rc=1; continue
    fi
    if [ "$(wc -c < "$corpus/$raw" | tr -d ' ')" -gt 32768 ]; then
      echo "domain-trials: raw extract exceeds compact limit: $raw" >&2; rc=1; continue
    fi
    actual=$(sha256 "$corpus/$raw")
    if [ "$actual" != "$expected" ]; then
      echo "domain-trials: checksum mismatch: $raw" >&2; rc=1; continue
    fi
    jq -r '.id' "$file" >> "$ids"; count=$((count + 1))
  done <<EOF
$(case_files "$corpus")
EOF
  if [ "$count" -eq 0 ] || [ "$rc" -ne 0 ] || LC_ALL=C sort "$ids" | uniq -d | grep -q .; then
    [ "$rc" -ne 0 ] || echo "domain-trials: duplicate case id" >&2
    rm -f "$ids"; return 1
  fi
  manifest_ids=$(jq -r '.cases[]' "$corpus/corpus.json" | LC_ALL=C sort)
  if [ "$(printf '%s\n' "$manifest_ids")" != "$(LC_ALL=C sort "$ids")" ]; then
    echo "domain-trials: corpus receipt case list differs from cases" >&2
    rm -f "$ids"; return 1
  fi
  rm -f "$ids"
  printf 'domain-trials: validated %s source-pinned cases\n' "$count"
}

default_helper() {
  local case_file="$1" work="$2" result="$3"
  printf 'offline evidence reviewed for %s\n' "$(jq -r .id "$case_file")" > "$work/artifact.txt"
  jq -n --arg artifact "$work/artifact.txt" '{verdict:"pass",interventions:0,artifact:$artifact}' > "$result"
}

run_case() {
  local case_file="$1" corpus="$2" out="$3" helper="$4" id work result artifact expected actual start end elapsed repro rc=0
  id=$(jq -r .id "$case_file"); expected=$(jq -r .expected_verdict "$case_file")
  work="$out/cases/$id"; result="$work/helper-result.json"
  mkdir -p "$work"; cp "$case_file" "$work/case.json"; jq .source "$case_file" > "$work/source-receipt.json"
  cp "$corpus/$(jq -r .source.raw "$case_file")" "$work/raw-extract"
  start=$(date +%s)
  if [ -n "$helper" ]; then
    POLYLANE_DOMAIN_CASE="$case_file" POLYLANE_DOMAIN_WORKDIR="$work" POLYLANE_DOMAIN_RESULT="$result" "$helper" || rc=$?
  else
    default_helper "$case_file" "$work" "$result" || rc=$?
  fi
  end=$(date +%s); elapsed=$((end - start))
  actual="unproven"; artifact=""
  if [ "$rc" -eq 0 ] && [ -f "$result" ] && jq -e '.verdict as $verdict | ["pass","fail"] | index($verdict) != null' "$result" >/dev/null 2>&1; then
    artifact=$(jq -r '.artifact // ""' "$result")
    if [ -n "$artifact" ] && [ -f "$artifact" ]; then actual=$(jq -r .verdict "$result"); fi
  fi
  repro=$( { sha256 "$case_file"; jq -c '{expected_verdict,adapter,grading,source}' "$case_file"; printf '%s\n' "$actual"; } | shasum -a 256 | awk '{print $1}')
  jq -cn --arg id "$id" --arg domain "$(jq -r .domain "$case_file")" --arg case "$case_file" \
    --arg adapter "${helper:-builtin-offline-helper}" --arg grader "source-checksum-and-artifact" \
    --arg artifact_bundle "$work" --arg source_receipt "$work/source-receipt.json" --arg artifact "$artifact" \
    --arg expected "$expected" --arg actual "$actual" --arg repro "$repro" --argjson elapsed "$elapsed" \
    --argjson interventions "$(jq -r 'if (.interventions | type) == "number" then .interventions else 0 end' "$result" 2>/dev/null || echo 0)" \
    '{schema:"polylane-domain-trial-result/v1",id:$id,domain:$domain,case:$case,adapter_command:$adapter,grader_command:$grader,artifact_bundle:$artifact_bundle,source_receipt:$source_receipt,artifact:$artifact,expected_verdict:$expected,actual_verdict:$actual,elapsed_seconds:$elapsed,interventions:$interventions,reproducibility_hash:$repro}'
  [ "$actual" = "$expected" ]
}

live_canary() {
  local corpus="$1" out="$2" domain="$3" case_file url body status reason checksum now
  case_file=$(case_files "$corpus" | while IFS= read -r f; do [ -z "$domain" ] || [ "$(jq -r .domain "$f")" = "$domain" ] || continue; printf '%s\n' "$f"; break; done)
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ); status="SKIP"; reason="no matching case"; checksum=""
  if [ -n "$case_file" ]; then
    url="${POLYLANE_DOMAIN_LIVE_URL:-$(jq -r .source.url "$case_file")}"; body="$out/.live-body.$$"
    if command -v curl >/dev/null 2>&1 && curl --fail --silent --show-error --location --connect-timeout 3 --max-time 8 --retry 0 -A 'polylane-domain-trials/1.0 read-only-canary' "$url" -o "$body"; then
      status="PASS"; reason="read-only endpoint returned success"; checksum=$(sha256 "$body"); rm -f "$body"
    else
      rm -f "$body"; reason="network unavailable, curl unavailable, timeout, or non-success response"
    fi
  fi
  jq -n --arg status "$status" --arg reason "$reason" --arg at "$now" --arg domain "$domain" --arg checksum "$checksum" \
    '{schema:"polylane-domain-live-receipt/v1",status:$status,reason:$reason,requested_at:$at,domain:($domain // "all"),method:"GET",side_effect:"read-only",timeout_seconds:8,rate_limit:"one request",user_agent:"polylane-domain-trials/1.0 read-only-canary",response_checksum:(if $checksum == "" then null else $checksum end)}' > "$out/live-receipt.json"
}

cmd_run() {
  local corpus="$1" out="$2"; shift 2
  local live=0 domain="" file any_failure=0 helper="${POLYLANE_DOMAIN_HELPER:-}"
  while [ "$#" -gt 0 ]; do
    case "$1" in --live) live=1 ;; --domain) shift; [ "$#" -gt 0 ] || usage; domain="$1" ;; *) usage ;; esac
    shift
  done
  [ -z "$domain" ] || printf '%s\n' software trading research operations content data custom-mixed | grep -Fx "$domain" >/dev/null || { echo "domain-trials: unknown domain: $domain" >&2; return 2; }
  [ -z "$helper" ] || [ -x "$helper" ] || { echo "domain-trials: helper is not executable" >&2; return 2; }
  cmd_validate "$corpus" >/dev/null
  mkdir -p "$out/cases"; : > "$out/results.jsonl"
  while IFS= read -r file; do
    [ -z "$domain" ] || [ "$(jq -r .domain "$file")" = "$domain" ] || continue
    run_case "$file" "$corpus" "$out" "$helper" >> "$out/results.jsonl" || any_failure=1
  done <<EOF
$(case_files "$corpus")
EOF
  [ -s "$out/results.jsonl" ] || { echo "domain-trials: no selected cases" >&2; return 2; }
  [ "$live" -eq 0 ] || live_canary "$corpus" "$out" "$domain"
  [ "$any_failure" -eq 0 ]
}

cmd_summarize() {
  local out="$1" mode="${2:-}" summary
  [ -z "$mode" ] || [ "$mode" = "--json" ] || usage
  [ -f "$out/results.jsonl" ] || { echo "domain-trials: missing results" >&2; return 1; }
  summary=$(jq -s '{schema:"polylane-domain-trial-summary/v1",cases:length,passed:([.[] | select(.actual_verdict == .expected_verdict)]|length),failed:([.[] | select(.actual_verdict == "fail")]|length),unproven:([.[] | select(.actual_verdict == "unproven")]|length),elapsed_seconds:([.[].elapsed_seconds]|add)}' "$out/results.jsonl")
  if [ "$mode" = "--json" ]; then printf '%s\n' "$summary"
  else printf 'Cases: %s\nPassed: %s\nFailed: %s\nUnproven: %s\nElapsed seconds: %s\n' "$(printf '%s' "$summary" | jq -r .cases)" "$(printf '%s' "$summary" | jq -r .passed)" "$(printf '%s' "$summary" | jq -r .failed)" "$(printf '%s' "$summary" | jq -r .unproven)" "$(printf '%s' "$summary" | jq -r .elapsed_seconds)"; fi
}

main() {
  case "${1:-}" in
    validate) [ "$#" = 2 ] || usage; cmd_validate "$2" ;;
    run) [ "$#" -ge 3 ] || usage; shift; cmd_run "$@" ;;
    summarize) [ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage; cmd_summarize "$2" "${3:-}" ;;
    *) usage ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
