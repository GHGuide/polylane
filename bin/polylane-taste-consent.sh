#!/usr/bin/env bash
# HCM-v2 consent, privacy boundary, and claim-safety pipeline.
#
#   record SPEC OUT
#     Emit an hcm-v2-consent/v1 record carrying exactly what a preregistered
#     study needs: an opaque participant id derived from an enrolment nonce, the
#     consent version, the consent timestamp, and the withdrawal path.  No
#     personally identifying data can enter (the spec key set is exact, the
#     enrolment reference must be an opaque nonce) and none can leave (the
#     record is PII- and claim-scanned before it is written).
#
#   withdraw CONSENT WITHDRAWN_AT OUT
#     Emit the matching hcm-v2-withdrawal/v1 governance artifact from a consent
#     record, keyed only by the opaque participant id.
#
#   pii-scan FILE
#     Fail if any key or value in FILE is personally identifying.
#
#   blind-check FILE
#     Fail if a participant-facing artifact (stimulus, ballot, receipt) exposes
#     a holdout label, a split assignment, or PII.  The machine panel is
#     qualified from these artifacts, so the holdout labels must not be
#     reachable through them.
#
#   claim-scan FILE...
#     Fail if any file carries a claim label or status the evidence claim
#     registry prohibits, or sets a certification flag true.  The prohibited
#     vocabulary is read from the registry at run time; this script never
#     contains one.
#
#   external-open OUT
#     Emit the open external dependencies of the study (ethics review, consent,
#     withdrawal, retention, governance owner, ...) as an
#     hcm-v2-external-dependencies/v1 record.  Every requirement is emitted
#     unsatisfied: this repository cannot approve them, and the contract's own
#     EXTERNAL-EVIDENCE-OPEN status is asserted, so a drifted contract fails
#     loudly instead of emitting a stale record.
#
# It never simulates a human judgment, a recruited participant, a consent
# signature, or a study result.
set -euo pipefail

usage() {
  printf '%s\n' \
    'usage: polylane-taste-consent.sh record SPEC OUT' \
    '       polylane-taste-consent.sh withdraw CONSENT WITHDRAWN_AT OUT' \
    '       polylane-taste-consent.sh pii-scan FILE' \
    '       polylane-taste-consent.sh blind-check FILE' \
    '       polylane-taste-consent.sh claim-scan FILE...' \
    '       polylane-taste-consent.sh external-open OUT' >&2
}

HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
CONTRACTS="$HERE/../docs/polylane/taste-certification/contracts"
LOCK_FILE=${POLYLANE_CONTRACT_LOCK:-$CONTRACTS/CONTRACT-LOCK.v3.json}
REGISTRY_FILE=${POLYLANE_CLAIM_REGISTRY:-$CONTRACTS/EVIDENCE-CLAIM-REGISTRY.v3.json}

# Consent schema versions this script emits.
CONSENT_SCHEMA='hcm-v2-consent/v1'
WITHDRAWAL_SCHEMA='hcm-v2-withdrawal/v1'
EXTERNAL_SCHEMA='hcm-v2-external-dependencies/v1'

fail() {
  printf 'polylane-taste-consent: %s\n' "$*" >&2
  exit 1
}

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else return 1; fi
}

readable_json() {
  local file=$1
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1
}

require_json() {
  readable_json "$1" || fail "not a readable JSON file: $1"
}

# --- personally identifying data -------------------------------------------
# A key whose name carries an identifying token, or a value shaped like an
# email address, a telephone number, or an IP address.
PII_SCAN_PROGRAM='
def pii_tokens:
  ["name","names","surname","forename","firstname","lastname","initials",
   "email","emails","mail","phone","phones","telephone","tel","mobile",
   "address","street","postcode","postalcode","zip","city","dob","birth",
   "birthday","birthdate","age","gender","ssn","nin","passport","ip",
   "geo","latitude","longitude","employer","username","handle","nickname",
   "avatar","photo","selfie","signature","contact"];
[ paths(scalars) as $p
  | { path: ($p | map(tostring) | join(".")), value: getpath($p) } ]
| map(select(
    ( [ .path | ascii_downcase | splits("[^a-z0-9]+") ]
      | map(. as $t | (pii_tokens | index($t)) != null) | any )
    or ( (.value | type) == "string"
         and ( (.value | test("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}"))
               or (.value | test("^[+]?[0-9][0-9 ()-]{5,15}[0-9]$"))
               or (.value | test("(^|[^0-9])([0-9]{1,3}[.]){3}[0-9]{1,3}([^0-9]|$)")) ) )))
| map(.path)[]
'

pii_offenders() {
  jq -r "$PII_SCAN_PROGRAM" "$1"
}

pii_scan() {
  local file=$1 offenders
  require_json "$file"
  offenders=$(pii_offenders "$file")
  [ -z "$offenders" ] || fail "personally identifying data in $file: $(printf '%s' "$offenders" | tr '\n' ' ')"
}

# --- holdout labels ---------------------------------------------------------
# Participant-facing artifacts carry the stimulus and the participant's own
# choice; they must never carry the label, the gold answer, or the split.
HOLDOUT_SCAN_PROGRAM='
[ paths(scalars) as $p
  | { path: ($p | map(tostring) | join(".")),
      leaf: ($p | last | tostring),
      value: getpath($p) } ]
| map(select(
    ( .leaf | ascii_downcase
      | test("^(holdout|holdout_label|gold|gold_label|gold_answer|ground_truth|groundtruth|human_rating|human_label|human_score|answer_key|correct_option|correct_answer|expected_winner|split|split_assignment)$") )
    or ( .path | ascii_downcase | test("(^|[.])holdout([._]|$)") )
    or ( (.value | type) == "string"
         and (.value | ascii_downcase
              | test("^(holdout|development|validation|confirmatory)$")) )))
| map(.path)[]
'

blind_check() {
  local file=$1 offenders
  require_json "$file"
  offenders=$(jq -r "$HOLDOUT_SCAN_PROGRAM" "$file")
  [ -z "$offenders" ] || fail "holdout label reachable from participant-facing artifact $file: $(printf '%s' "$offenders" | tr '\n' ' ')"
  pii_scan "$file"
}

# --- prohibited claims ------------------------------------------------------
# The forbidden labels, statuses, and certification flags come from the
# registry at run time so no prohibited token is ever written in this file.
registry_prohibited_tokens() {
  require_json "$REGISTRY_FILE"
  jq -e -r '
    .prohibited_outputs
    | (.claim_labels // []) + (.statuses // [])
    | unique
    | select(length > 0)
    | .[]' "$REGISTRY_FILE" ||
    fail "registry lists no prohibited claim labels or statuses: $REGISTRY_FILE"
}

# Flag names whose true value the registry forbids, derived from its own
# "<flag>_true_forbidden" keys.  Both certification flags must stay forbidden;
# a registry that stopped forbidding one is a drift, not a permission.
registry_forbidden_flags() {
  require_json "$REGISTRY_FILE"
  jq -e -r '
    .prohibited_outputs
    | to_entries
    | map(select((.key | endswith("_true_forbidden")) and .value == true)
          | .key | sub("_true_forbidden$"; ""))
    | select((index("human_certified") != null) and (index("taste_certified") != null))
    | .[]' "$REGISTRY_FILE" ||
    fail "registry no longer forbids both certification flags: $REGISTRY_FILE"
}

claim_scan_file() {
  local file=$1 token flag tokens flags
  [ -f "$file" ] && [ ! -L "$file" ] || fail "not a readable file: $file"
  # Assigned before use so a drifted registry aborts the scan instead of
  # silently scanning for nothing.
  tokens=$(registry_prohibited_tokens) || exit 1
  flags=$(registry_forbidden_flags) || exit 1
  while IFS= read -r token; do
    [ -n "$token" ] || continue
    if LC_ALL=C grep -F -q -- "$token" "$file"; then
      fail "prohibited claim token in $file"
    fi
  done <<EOF
$tokens
EOF
  while IFS= read -r flag; do
    [ -n "$flag" ] || continue
    if LC_ALL=C grep -E -q -- "\"?${flag}\"?[[:space:]]*[:=][[:space:]]*true" "$file"; then
      fail "prohibited certification flag set true in $file"
    fi
    if readable_json "$file" &&
       jq -e --arg flag "$flag" '
         [ paths(scalars) as $p
           | select(($p | last | tostring) == $flag)
           | getpath($p) | select(. == true) ] | length > 0' "$file" >/dev/null; then
      fail "prohibited certification flag set true in $file"
    fi
  done <<EOF
$flags
EOF
}

# --- frozen contract values -------------------------------------------------
# Reads one frozen value; a missing value is a drifted contract, not a default.
json_value() {
  local file=$1 filter=$2 value
  require_json "$file"
  value=$(jq -r "$filter" "$file" 2>/dev/null) || fail "cannot read $filter from $file"
  [ -n "$value" ] && [ "$value" != null ] || fail "$file is missing $filter"
  printf '%s\n' "$value"
}

lock_value() {
  json_value "$LOCK_FILE" "$1"
}

registry_value() {
  json_value "$REGISTRY_FILE" "$1"
}

# Every constant below is asserted against the contract, so a lock or registry
# that drifts fails here instead of silently producing a stale artifact.
assert_external_open_contract() {
  local expected_status='EXTERNAL-EVIDENCE-OPEN'
  local expected_authority='EXTERNAL_TARGET_MATCHED'
  [ "$(lock_value '.source_calibration.hcm_v2.governance_requirements_are_external')" = true ] ||
    fail "lock no longer marks HCM-v2 governance requirements external"
  [ "$(lock_value '.source_calibration.hcm_v2.status')" = "$expected_status" ] ||
    fail "lock HCM-v2 status is no longer $expected_status"
  [ "$(lock_value '.source_calibration.hcm_v2.authority')" = "$expected_authority" ] ||
    fail "lock HCM-v2 authority is no longer $expected_authority"
  [ "$(registry_value '.private_hcm_v2_prerequisite.status')" = "$expected_status" ] ||
    fail "registry HCM-v2 prerequisite status is no longer $expected_status"
  [ "$(registry_value '.private_hcm_v2_prerequisite.human_certified')" = false ] ||
    fail "registry HCM-v2 prerequisite claims human certification"
  [ "$(registry_value '.private_hcm_v2_prerequisite.taste_certified')" = false ] ||
    fail "registry HCM-v2 prerequisite claims taste certification"
  [ "$(registry_value '.private_hcm_v2_prerequisite.external_requirements | length')" -gt 0 ] ||
    fail "registry lists no external requirements for the HCM-v2 prerequisite"
}

# --- emission ---------------------------------------------------------------
# Nothing lands on disk until it has passed the PII and claim scans.
emit() {
  local out=$1 tmpdir
  [ ! -e "$out" ] || fail "refusing to overwrite $out"
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-consent.XXXXXX") || fail 'mktemp failed'
  cat >"$tmpdir/artifact.json"
  jq -e . "$tmpdir/artifact.json" >/dev/null 2>&1 || { rm -rf "$tmpdir"; fail 'emitted artifact is not JSON'; }
  if ! ( pii_scan "$tmpdir/artifact.json" && claim_scan_file "$tmpdir/artifact.json" ); then
    rm -rf "$tmpdir"
    fail "refusing to emit $out: it would carry personal data or a prohibited claim"
  fi
  mv "$tmpdir/artifact.json" "$out"
  rm -rf "$tmpdir"
}

cmd_record() {
  [ $# -eq 2 ] || { usage; exit 2; }
  local spec=$1 out=$2 study_id version nonce consented_at withdrawal_path participant_id mint
  require_json "$spec"
  jq -e '
    type == "object"
    and ((keys_unsorted | sort)
         == ["consent_version","consented_at","enrolment_nonce","study_id","withdrawal_path"])' \
    "$spec" >/dev/null ||
    fail 'spec keys must be exactly study_id, consent_version, enrolment_nonce, consented_at, withdrawal_path'
  pii_scan "$spec"

  study_id=$(jq -r '.study_id' "$spec")
  version=$(jq -r '.consent_version' "$spec")
  nonce=$(jq -r '.enrolment_nonce' "$spec")
  consented_at=$(jq -r '.consented_at' "$spec")
  withdrawal_path=$(jq -r '.withdrawal_path' "$spec")

  assert_external_open_contract
  [ "$study_id" = "$(lock_value '.source_calibration.hcm_v2.source_id')" ] ||
    fail "study_id does not match the frozen HCM-v2 source id in the lock"
  printf '%s' "$version" | LC_ALL=C grep -E -q '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' ||
    fail 'consent_version must be a short alphanumeric version string'
  printf '%s' "$nonce" | LC_ALL=C grep -E -q '^[0-9a-f]{64}$' ||
    fail 'enrolment_nonce must be an opaque 64-hex nonce, never an identifier'
  assert_rfc3339_utc "$consented_at" consented_at
  printf '%s' "$withdrawal_path" | LC_ALL=C grep -E -q '^https://[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+$' ||
    fail 'withdrawal_path must be an https URL that identifies nobody'

  participant_id=$(printf '%s:%s' "$study_id" "$nonce" | sha256_stdin) ||
    fail 'no SHA-256 implementation available'
  mint=$(registry_value '.claim_minting.certification_mint_authority')

  jq -n \
    --arg schema "$CONSENT_SCHEMA" \
    --arg study_id "$study_id" \
    --arg version "$version" \
    --arg participant_id "$participant_id" \
    --arg consented_at "$consented_at" \
    --arg withdrawal_path "$withdrawal_path" \
    --arg status "$(registry_value '.private_hcm_v2_prerequisite.status')" \
    --arg mint "$mint" \
    '{schema: $schema,
      study_id: $study_id,
      consent_version: $version,
      participant_id: $participant_id,
      consented_at: $consented_at,
      withdrawal: {path: $withdrawal_path, revocable: true},
      contains_personal_data: false,
      certification_mint_authority: $mint,
      governance: {ethics_review: "EXTERNAL", status: $status}}' |
    emit "$out"
}

cmd_withdraw() {
  [ $# -eq 3 ] || { usage; exit 2; }
  local consent=$1 withdrawn_at=$2 out=$3
  require_json "$consent"
  jq -e --arg schema "$CONSENT_SCHEMA" '.schema == $schema' "$consent" >/dev/null ||
    fail "not an $CONSENT_SCHEMA record: $consent"
  pii_scan "$consent"
  claim_scan_file "$consent"
  assert_rfc3339_utc "$withdrawn_at" withdrawn_at

  jq --arg schema "$WITHDRAWAL_SCHEMA" --arg withdrawn_at "$withdrawn_at" \
    '{schema: $schema,
      study_id: .study_id,
      participant_id: .participant_id,
      consent_version: .consent_version,
      withdrawn_at: $withdrawn_at,
      path: .withdrawal.path,
      contains_personal_data: false,
      certification_mint_authority: .certification_mint_authority,
      effect: "every ballot and receipt bound to this participant_id must be destroyed and excluded from analysis"}' \
    "$consent" | emit "$out"
}

cmd_external_open() {
  [ $# -eq 1 ] || { usage; exit 2; }
  local out=$1
  assert_external_open_contract
  jq -n \
    --arg schema "$EXTERNAL_SCHEMA" \
    --arg study_id "$(lock_value '.source_calibration.hcm_v2.source_id')" \
    --arg status "$(registry_value '.private_hcm_v2_prerequisite.status')" \
    --arg authority "$(lock_value '.source_calibration.hcm_v2.authority')" \
    --slurpfile registry "$REGISTRY_FILE" \
    '{schema: $schema,
      study_id: $study_id,
      status: $status,
      authority: $authority,
      satisfied: false,
      governance_requirements_are_external: true,
      requirements: [ $registry[0].private_hcm_v2_prerequisite.external_requirements[]
                      | {requirement: ., satisfied: false, evidence: "EXTERNAL"} ],
      note: "this repository cannot approve, recruit, or seal any of these; each stays open until external evidence arrives"}' |
    emit "$out"
}

assert_rfc3339_utc() {
  printf '%s' "$1" | LC_ALL=C grep -E -q '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' ||
    fail "$2 must be an RFC 3339 UTC timestamp"
}

main() {
  [ $# -ge 1 ] || { usage; exit 2; }
  local command=$1
  shift
  case "$command" in
    record) cmd_record "$@" ;;
    withdraw) cmd_withdraw "$@" ;;
    pii-scan) [ $# -eq 1 ] || { usage; exit 2; }; pii_scan "$1" ;;
    blind-check) [ $# -eq 1 ] || { usage; exit 2; }; blind_check "$1" ;;
    claim-scan)
      [ $# -ge 1 ] || { usage; exit 2; }
      local file
      for file in "$@"; do claim_scan_file "$file"; done
      ;;
    external-open) cmd_external_open "$@" ;;
    -h|--help|help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
