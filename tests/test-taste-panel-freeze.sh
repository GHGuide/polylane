#!/usr/bin/env bash
# tests/test-taste-panel-freeze.sh — hermetic freeze tests for the machine-panel
# configuration benchmarks/taste-live/calibration/panel.v1.json.
#
# The panel is a STATIC frozen file. It may bind identities, prompt/schema/
# sampling hashes, correlation limitations, and an abstention policy. It may
# NEVER state eligibility, availability, human provenance, trust, observed CLI
# or model versions, or independence booleans — those are runtime facts owned
# by the calibration campaign/audit lanes.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
PANEL="$ROOT/benchmarks/taste-live/calibration/panel.v1.json"
TMPDIR_TEST=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-panel-freeze.XXXXXX")
trap 'rm -rf "$TMPDIR_TEST"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

sha_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'; fi
}
sha_str() {
  if command -v shasum >/dev/null 2>&1; then printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  else printf '%s' "$1" | sha256sum | awk '{print $1}'; fi
}

# verify_panel FILE -> 0 iff FILE is a valid frozen panel. Prints reason on
# failure. This is the single authority the tamper matrix attacks.
verify_panel() {
  local f="$1"

  jq -e . "$f" >/dev/null 2>&1 || { echo "not valid JSON"; return 1; }

  # ---- schema identity + top-level shape ----------------------------------
  jq -e '
    (.schema_version == "polylane.taste.panel/v1")
    and (.run_id == "c41-source-calibration-20260812-a1")
    and ((keys | sort) == ["abstention_policy","calibration_reference","claim",
          "correlation","created_utc","panel_id","run_id","runtime_observed_fields",
          "schema_version","slots"])
  ' "$f" >/dev/null 2>&1 || { echo "bad schema_version/run_id/top-level keys"; return 1; }

  # ---- forbidden vocabulary: the static file cannot decide runtime facts ---
  # No key anywhere may claim eligibility, human provenance, trust,
  # independence, availability, or an observed version.
  jq -e '
    [paths | .[] | select(type == "string")] | unique
    | map(ascii_downcase)
    | any(. as $k |
        ["eligible","eligibility","ineligible","human_certified","human_labeled",
         "human_labelled","trusted","trust","independent","independence",
         "verified","available","availability","model_version","cli_version",
         "observed_version"] | index($k) != null)
    | not
  ' "$f" >/dev/null 2>&1 || { echo "forbidden runtime-fact key present"; return 1; }

  # No boolean anywhere under a key mentioning eligib/human/trust/independ.
  jq -e '
    [paths(type == "boolean") | map(select(type == "string")) | join("/")]
    | any(test("eligib|human|trust|independ"; "i"))
    | not
  ' "$f" >/dev/null 2>&1 || { echo "eligibility/human/trust boolean present"; return 1; }

  # ---- claim ceiling -------------------------------------------------------
  jq -e '
    (.claim.ceiling == "HUMAN_CALIBRATED_MACHINE")
    and (.claim.forbidden_claims | type == "array"
         and (map(ascii_downcase) | index("human_certified") != null))
    and (.claim.eligibility_authority | type == "string" and length > 40)
  ' "$f" >/dev/null 2>&1 || { echo "claim ceiling missing or wrong"; return 1; }

  # Runtime owns observed versions: the panel must declare them deferred.
  jq -e '
    .runtime_observed_fields | type == "array"
    and (index("cli_version") != null) and (index("model_version") != null)
  ' "$f" >/dev/null 2>&1 || { echo "runtime_observed_fields incomplete"; return 1; }

  # ---- frozen calibration thresholds (reference, not decision) ------------
  jq -e '
    .calibration_reference
    | (.pairs_required == 24) and (.correct_min == 17)
      and (.wilson_lower_min == 0.50) and (.side_probe_p_min == 0.05)
      and (.mirror_contradiction_max == 1)
  ' "$f" >/dev/null 2>&1 || { echo "calibration reference thresholds drifted"; return 1; }

  # ---- abstention policy ---------------------------------------------------
  jq -e '
    .abstention_policy
    | (.recorded_classes | type == "array"
       and (index("cli_unavailable") != null) and (index("timeout") != null)
       and (index("schema_invalid_response") != null)
       and (index("provider_refusal") != null))
    and (.rules | type == "array" and length >= 3
         and all(type == "string" and length > 20))
  ' "$f" >/dev/null 2>&1 || { echo "abstention policy incomplete"; return 1; }

  # ---- slots: count, uniqueness, identity ---------------------------------
  jq -e '.slots | type == "array" and length >= 5' "$f" >/dev/null 2>&1 \
    || { echo "fewer than five slots"; return 1; }

  jq -e '
    .slots
    | (map(.slot_id) | length == (unique | length))
    and (map(.judge_id) | length == (unique | length))
    and (map(.session_namespace) | length == (unique | length))
    and (map(.model + "|" + .sampling_sha256) | length == (unique | length))
    and all(.judge_id | test("^judge-[a-z0-9-]{3,}$"))
    and all(.session_rule | type == "string" and test("unique"))
  ' "$f" >/dev/null 2>&1 || { echo "duplicate or malformed slot/judge/session identity"; return 1; }

  # Both provider families must be present (Claude AND Codex sides).
  jq -e '
    (.slots | map(.provider) | unique) as $p
    | ($p | index("anthropic") != null) and ($p | index("openai") != null)
  ' "$f" >/dev/null 2>&1 || { echo "panel does not span both providers"; return 1; }

  # ---- per-slot checks that need the filesystem ---------------------------
  local n i
  n=$(jq '.slots | length' "$f")
  i=0
  while [ "$i" -lt "$n" ]; do
    local slot adapter adapter_path provider model
    slot=$(jq -c ".slots[$i]" "$f")

    printf '%s' "$slot" | jq -e '
      (keys | sort) == ["adapter","adapter_path","cli","config","family",
        "judge_id","model","provider","response_schema_path",
        "response_schema_sha256","response_schema_version","sampling_canonical",
        "sampling_sha256","session_namespace","session_rule","slot_id",
        "system_prompt_path","system_prompt_sha256"]
    ' >/dev/null 2>&1 || { echo "slot $i has wrong key set"; return 1; }

    adapter=$(printf '%s' "$slot" | jq -r .adapter)
    adapter_path=$(printf '%s' "$slot" | jq -r .adapter_path)
    provider=$(printf '%s' "$slot" | jq -r .provider)
    model=$(printf '%s' "$slot" | jq -r .model)

    # Real adapters only — the two isolated judge CLIs that exist in bin/.
    case "$adapter" in
      polylane-taste-judge-claude|polylane-taste-judge-codex) ;;
      *) echo "slot $i names unknown adapter '$adapter'"; return 1 ;;
    esac
    [ "$adapter_path" = "bin/$adapter.sh" ] || { echo "slot $i adapter_path mismatch"; return 1; }
    [ -f "$ROOT/$adapter_path" ] && [ -x "$ROOT/$adapter_path" ] \
      || { echo "slot $i adapter_path not an executable file"; return 1; }

    # Provider/adapter/model coherence (codex adapter hard-rejects claude ids).
    case "$provider" in
      anthropic)
        [ "$adapter" = polylane-taste-judge-claude ] || { echo "slot $i provider/adapter mismatch"; return 1; }
        case "$model" in claude-*) ;; *) echo "slot $i anthropic model '$model' not claude-*"; return 1 ;; esac ;;
      openai)
        [ "$adapter" = polylane-taste-judge-codex ] || { echo "slot $i provider/adapter mismatch"; return 1; }
        case "$model" in *claude*) echo "slot $i codex slot carries claude model"; return 1 ;; esac ;;
      *) echo "slot $i unknown provider '$provider'"; return 1 ;;
    esac

    # Exact frozen hashes: prompt + response schema recomputed from the repo,
    # sampling recomputed from the canonical string in the slot itself.
    local p want got
    p=$(printf '%s' "$slot" | jq -r .system_prompt_path)
    want=$(printf '%s' "$slot" | jq -r .system_prompt_sha256)
    [ -f "$ROOT/$p" ] || { echo "slot $i system prompt missing: $p"; return 1; }
    got=$(sha_file "$ROOT/$p")
    [ "$got" = "$want" ] || { echo "slot $i system_prompt_sha256 does not match $p"; return 1; }

    p=$(printf '%s' "$slot" | jq -r .response_schema_path)
    want=$(printf '%s' "$slot" | jq -r .response_schema_sha256)
    [ -f "$ROOT/$p" ] || { echo "slot $i response schema missing: $p"; return 1; }
    got=$(sha_file "$ROOT/$p")
    [ "$got" = "$want" ] || { echo "slot $i response_schema_sha256 does not match $p"; return 1; }

    want=$(printf '%s' "$slot" | jq -r .sampling_sha256)
    got=$(sha_str "$(printf '%s' "$slot" | jq -r .sampling_canonical)")
    [ "$got" = "$want" ] || { echo "slot $i sampling_sha256 does not match sampling_canonical"; return 1; }

    i=$((i + 1))
  done

  # ---- correlation limitations --------------------------------------------
  # Every slot family must be documented with an explicit limitation, and the
  # panel must state that same-family agreement is not independent replication.
  jq -e '
    (.slots | map(.family) | unique) as $fams
    | (.correlation.families | type == "object")
    and ($fams - (.correlation.families | keys) == [])
    and (.correlation.families | to_entries
         | all(.value.slots | type == "array" and length >= 1))
    and (.correlation.families | to_entries
         | all(.value.limitation | type == "string" and length > 40))
    and (.correlation.limitations | type == "array" and length >= 3
         and all(type == "string" and length > 30))
    and (.correlation.distinct_family_count
         == (.correlation.families | keys | length))
  ' "$f" >/dev/null 2>&1 || { echo "correlation families/limitations incomplete"; return 1; }

  # Family membership lists must exactly match the slots.
  jq -e '
    . as $root
    | [.correlation.families | to_entries[] | .value.slots[]] | sort
      == ($root.slots | map(.slot_id) | sort)
  ' "$f" >/dev/null 2>&1 || { echo "correlation family slot lists drift from slots"; return 1; }

  return 0
}

# --- 1. the committed panel must verify ------------------------------------
[ -f "$PANEL" ] || fail "panel file missing: $PANEL"
reason=$(verify_panel "$PANEL") || fail "committed panel rejected: $reason"

# --- 2. tamper matrix: every mutation must be rejected ---------------------
tamper() { # NAME JQ_PROGRAM
  local name="$1" prog="$2" out="$TMPDIR_TEST/$1.json"
  jq "$prog" "$PANEL" > "$out" || fail "tamper fixture '$name' failed to build"
  if verify_panel "$out" >/dev/null 2>&1; then
    fail "tampered panel accepted: $name"
  fi
}

tamper four-slots            '.slots = .slots[0:4]'
tamper duplicate-slot-id     '.slots[1].slot_id = .slots[0].slot_id'
tamper duplicate-session     '.slots[1].session_namespace = .slots[0].session_namespace'
tamper duplicate-judge-id    '.slots[1].judge_id = .slots[0].judge_id'
tamper eligibility-boolean   '.slots[0].eligible = true'
tamper human-boolean         '.claim.human_certified = false'
tamper trust-boolean         '.slots[0].trusted = true'
tamper fabricated-version    '.slots[0].model_version = "2026.08"'
tamper fabricated-cli-ver    '.slots[0].cli_version = "9.9.9"'
tamper independence-boolean  '.correlation.independent = true'
tamper fake-adapter          '.slots[0].adapter = "polylane-taste-judge-fake" | .slots[0].adapter_path = "bin/polylane-taste-judge-fake.sh"'
tamper prompt-hash-drift     '.slots[0].system_prompt_sha256 = ("0" * 64)'
tamper schema-hash-drift     '.slots[0].response_schema_sha256 = ("0" * 64)'
tamper sampling-drift        '.slots[0].sampling_canonical = .slots[0].sampling_canonical + ";temperature=1.0"'
tamper single-provider       '(.slots[] | select(.provider == "openai") | .provider) |= "anthropic"'
tamper threshold-drift       '.calibration_reference.correct_min = 12'
tamper missing-limitations   '.correlation.limitations = []'
tamper family-drift          '.correlation.families = {}'
tamper claim-uncapped        '.claim.ceiling = "HUMAN_CERTIFIED"'
tamper wrong-run             '.run_id = "c40-live-harness-20260812-a3"'

printf 'PASS: test-taste-panel-freeze (schema, identity, hash, tamper matrix)\n'
