#!/usr/bin/env bash
# polylane-visual-quality.sh — rendered-taste evidence adapter.
#
# Modes:
#   run       — legacy per-surface lens verdict (Cycle 38 callers).
#   benchmark — legacy old-vs-new corpus gate.
#   certify   — Cycle 39 authoritative adapter. Derives a visual-quality-verdict/v2
#               solely from hash-bound producer receipts and a real capture
#               verification. Caller pass/status/winner/lens fields are untrusted
#               data and can never authorize a pass.
set -euo pipefail

usage() {
  echo "usage: polylane-visual-quality.sh run <evidence.json> <contract.json> <verdict.json> [repair-attempt]" >&2
  echo "       polylane-visual-quality.sh benchmark <corpus.json> <verdict.json>" >&2
  echo "       polylane-visual-quality.sh certify <project-root> <record.json> <verdict.json> [attempt]" >&2
}

evidence_shape() {
  jq -e '
    . as $e
    | .schema == 1
    and (.root | type == "string" and startswith("/"))
    and .anonymized == true
    and (.screenshots | type == "array")
    and all(.screenshots[]; (.surface | type == "string" and length > 0)
      and (.viewport | IN("desktop", "mobile"))
      and (.state | IN("default", "empty", "loading", "error", "hover", "focus"))
      and (.path | type == "string" and length > 0 and (startswith("/") | not) and (contains("..") | not)))
    and any(.screenshots[]; .viewport == "desktop" and .state == "default")
    and any(.screenshots[]; .viewport == "mobile" and .state == "default")
    and all(["empty","loading","error","hover","focus"][]; . as $state | any($e.screenshots[]; .state == $state))
    and (.flow | type == "array" and length > 0 and all(.[]; (.surface | type == "string") and (.action | type == "string") and (.result | type == "string")))
    and (.texts | type == "array" and all(.[]; type == "string"))
    and (.assets | type == "array" and all(.[]; type == "string"))
    and (.generic_patterns | type == "array" and all(.[]; type == "string"))
    and (.lenses | type == "array" and length == 3)
    and ([.lenses[].lens] | sort == ["accessibility","fit_polish","originality"])
    and all(.lenses[]; (.status | IN("passed", "failed"))
      and (.findings | type == "array")
      and all(.findings[]; (.surface | type == "string" and length > 0)
        and (.region | type == "string" and length > 0)
        and (.action | type == "string" and length > 0)))
  ' "$1" >/dev/null 2>&1
}

screenshot_has_image_signature() {
  local image="$1" signature
  [ -s "$image" ] || return 1
  signature=$(LC_ALL=C od -An -N 12 -t x1 "$image" | tr -d ' \n')
  case "$signature" in
    89504e470d0a1a0a*|ffd8ff*|52494646????????57454250*) return 0 ;;
    *) return 1 ;;
  esac
}

screenshots_exist() {
  local evidence="$1" root image
  root=$(jq -r '.root' "$evidence")
  while IFS= read -r image; do
    [ -f "$root/$image" ] && [ ! -L "$root/$image" ] &&
      screenshot_has_image_signature "$root/$image" || return 1
  done < <(jq -r '.screenshots[].path' "$evidence")
}

mechanical_failure() {
  local evidence="$1" contract="$2" generic copied
  generic=$(jq -r '.generic_patterns[]? | ascii_downcase' "$evidence" | grep -E '^(purple-gradient|centered-card|inter-font|generic-dashboard)$' || true)
  [ -z "$generic" ] || { printf 'generic:%s\n' "${generic%%$'\n'*}"; return; }
  copied=$(jq -r --slurpfile contract "$contract" '
    ((.texts // []) as $texts | ($contract[0].prohibited_text // [])[] | select(. as $x | $texts | index($x)) // empty),
    ((.assets // []) as $assets | ($contract[0].prohibited_assets // [])[] | select(. as $x | $assets | index($x)) // empty)
  ' "$evidence" | head -n 1)
  [ -z "$copied" ] || { printf 'copied:%s\n' "$copied"; return; }
  printf '%s\n' ''
}

run_quality() {
  local evidence="$1" contract="$2" verdict="$3" attempt="${4:-0}" reason status evidence_id
  case "$attempt" in *[!0-9]*|"") echo "VISUAL-QUALITY: repair attempt must be 0, 1, or 2" >&2; return 2 ;; esac
  [ "$attempt" -le 2 ] || { echo "VISUAL-QUALITY: repair budget exhausted" >&2; return 2; }
  evidence_shape "$evidence" || { echo "VISUAL-QUALITY: incomplete or malformed screenshot evidence" >&2; return 2; }
  jq -e '(.prohibited_text // []) | type == "array" and all(.[]; type == "string")' "$contract" >/dev/null 2>&1 || {
    echo "VISUAL-QUALITY: invalid frozen contract" >&2; return 2;
  }
  screenshots_exist "$evidence" || { echo "VISUAL-QUALITY: missing real screenshot evidence" >&2; return 2; }
  reason=$(mechanical_failure "$evidence" "$contract")
  evidence_id=$(cksum "$evidence" | awk '{print $1 "-" $2}')
  if [ -n "$reason" ]; then
    status=blocked
  elif jq -e 'all(.lenses[]; .status == "passed")' "$evidence" >/dev/null; then
    status=passed
  elif [ "$attempt" -ge 2 ]; then
    status=halted
  else
    status=repair
  fi
  mkdir -p "$(dirname "$verdict")"
  jq --arg status "$status" --argjson attempt "$attempt" --arg evidence_id "$evidence_id" --arg reason "$reason" '
    {schema:1,status:$status,repair_attempt:$attempt,evidence_id:$evidence_id,
     mechanical_reason:(if ($reason | length) > 0 then $reason else null end),
     lenses:[.lenses[] | {lens,status,findings}]}
  ' "$evidence" > "$verdict"
  [ "$status" = passed ]
}

benchmark_quality() {
  local corpus="$1" verdict="$2" status wins total
  jq -e '
    .schema == 1
    and (.prompts | type == "array" and length >= 10)
    and all(.prompts[];
      (.id | type == "string" and length > 0)
      and all([.old, .new][];
        type == "object"
        and (.distinction | type == "number")
        and (.polish | type == "number")
        and (.accessibility | type == "number")))
  ' "$corpus" >/dev/null 2>&1 || {
    echo "VISUAL-QUALITY: benchmark corpus must contain at least ten scored prompts" >&2; return 2;
  }
  wins=$(jq '[.prompts[] | select(.new.distinction > .old.distinction and .new.polish > .old.polish)] | length' "$corpus")
  total=$(jq '.prompts | length' "$corpus")
  if jq -e --argjson wins "$wins" --argjson total "$total" '
      ($wins * 100 >= $total * 70)
      and all(.prompts[]; .new.accessibility >= .old.accessibility)
    ' "$corpus" >/dev/null; then
    status=passed
  else
    status=blocked
  fi
  mkdir -p "$(dirname "$verdict")"
  jq --arg status "$status" --argjson wins "$wins" --argjson total "$total" '
    {schema:1,status:$status,prompts:$total,decisive_new_wins:$wins,
     decisive_win_rate:($wins / $total),
     accessibility_regressions:[.prompts[] | select(.new.accessibility < .old.accessibility) | .id]}
  ' "$corpus" > "$verdict"
  [ "$status" = passed ]
}

# ---------------------------------------------------------------------------
# certify — Cycle 39 authoritative adapter.
# ---------------------------------------------------------------------------

# The six state cards every visual-quality lock must render, at both viewports.
CERTIFY_REQUIRED_STATES='default empty error focus hover loading'

cq_reasons=''
cq_external=0
cq_blocked=0
cq_add_reason() { case " $cq_reasons " in *" $1 "*) ;; *) cq_reasons="${cq_reasons:+$cq_reasons }$1" ;; esac; }
cq_block() { cq_blocked=1; cq_add_reason "$1"; }
cq_extern() { cq_external=1; cq_add_reason "$1"; }

cq_is_sha() { [[ $1 =~ ^[0-9a-f]{64}$ ]]; }
cq_is_revision() { [[ $1 =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]]; }

cq_sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else return 1; fi
}

cq_regular_json_no_dupes() {
  local file="$1" duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

# cq_bind_receipt REL EXPECTED_SCHEMA [DECLARED_SHA] -> prints canonical json, or fails.
# Rejects absolute paths, traversal, and any symlink component. When DECLARED_SHA
# is given the recomputed SHA-256 must match it (hash binding).
cq_bind_receipt() {
  local rel="$1" expected="$2" declared="${3:-}" path part prefix old_ifs actual
  case "$rel" in ''|/*|*'..'*|*'//'*) return 1 ;; esac
  path="$cq_record_dir/$rel"
  prefix="$cq_record_dir"; old_ifs=$IFS; IFS='/'
  for part in $rel; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
    prefix="$prefix/$part"
    [ ! -L "$prefix" ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
  cq_regular_json_no_dupes "$path" || return 1
  jq -e --arg expected "$expected" 'type == "object" and .schema_version == $expected' "$path" >/dev/null 2>&1 || return 1
  if [ -n "$declared" ]; then
    actual=$(cq_sha256_file "$path" 2>/dev/null || true)
    [ "$actual" = "$declared" ] || return 1
  fi
  jq -c . "$path"
}

cq_record_shape() {
  jq -e '
    type == "object"
    and ([keys[]] | sort == ["capture_manifest","champion","design_lock_sha256","generic_patterns","hard_gate","literal_goal_sha256","outstanding_findings","packet_sha256","repair","repair_ledger","required_states","run_id","schema_version","taste_memory_proposal","threat_receipt","tournament"])
    and .schema_version == "visual-quality-record/v2"
    and (.run_id | type == "string" and length > 0)
    and all([.literal_goal_sha256,.packet_sha256,.design_lock_sha256][]; type == "string" and test("^[0-9a-f]{64}$"))
    and (.capture_manifest | type == "string" and length > 0)
    and (.hard_gate | type == "string" and length > 0)
    and (.threat_receipt | type == "string" and length > 0)
    and (.repair_ledger | type == "string" and length > 0)
    and (.generic_patterns | type == "array" and all(.[]; type == "string"))
    and (.required_states | type == "array" and length > 0 and (length == (unique | length)) and all(.[]; type == "string"))
    and (.outstanding_findings | type == "array" and all(.[]; type == "object" and (keys | sort == ["criterion","region_or_state"]) and (.criterion | type == "string" and length > 0) and (.region_or_state | type == "string" and length > 0)))
    and (.taste_memory_proposal | (. == null) or (type == "object"))
    and (.tournament | type == "object" and (keys | sort == ["input_sha256","receipt","receipt_sha256","selected_candidate_id","selected_source_revision"])
      and (.input_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
      and (.receipt | type == "string" and length > 0)
      and (.receipt_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
      and (.selected_candidate_id | type == "string" and length > 0)
      and (.selected_source_revision | type == "string" and test("^[0-9a-f]{40,64}$")))
    and (.champion | type == "object" and (keys | sort == ["decision","generation","incumbent_candidate_id","previous_champion_sha256"])
      and (.decision | IN("promote","preserve","repair"))
      and (.generation | type == "number" and floor == . and . >= 0)
      and (.incumbent_candidate_id | (. == null) or (type == "string" and length > 0))
      and (.previous_champion_sha256 | (. == null) or (type == "string" and test("^[0-9a-f]{64}$"))))
    and (.repair | (. == null) or (type == "object" and (keys | sort == ["changed","failed_criterion","prior_evidence_sha256","region_or_state"])
      and (.changed | type == "boolean")
      and (.failed_criterion | type == "string" and length > 0)
      and (.region_or_state | type == "string" and length > 0)
      and (.prior_evidence_sha256 | type == "string" and test("^[0-9a-f]{64}$"))))
  ' "$1" >/dev/null 2>&1
}

# Classify a polylane-taste-pixels.sh rejection: adapter/environment absence is
# external (never a pass); tamper/invalid evidence is blocked.
cq_classify_pixels() {
  case "$1" in
    *DECODER_UNAVAILABLE*|*JQ_UNAVAILABLE*|*SHA256_UNAVAILABLE*|*SOURCE_REVISION_UNAVAILABLE*|*SOURCE_TIME_UNAVAILABLE*|*MANIFEST_UNAVAILABLE*)
      cq_extern "PIXELS_${1##*: }" ;;
    *) cq_block "PIXELS_${1##*: }" ;;
  esac
}

# Re-derive the unique Condorcet winner from three blind pairwise results.
# Prints the winning candidate id, or nothing when indecisive (tie/cycle).
cq_condorcet_winner() {
  local receipt="$1"
  jq -r '
    [.candidates[].candidate_id] as $ids
    | (reduce .pairs[] as $p ({}; .[$p.canonical_winner] = ((.[$p.canonical_winner] // 0) + 1))) as $wins
    | [$ids[] | select(($wins[.] // 0) == 2)]
    | if length == 1 then .[0] else empty end
  ' <<<"$receipt" 2>/dev/null || true
}

certify_quality() {
  local root="$1" record="$2" verdict="$3" attempt="${4:-0}"
  local now record_json capture_rel manifest_json
  local tournament_json winner selected selected_rev hard_json threat_json repair_json
  local capture_sha tournament_sha hard_sha threat_sha repair_sha=''
  local run_id lock_sha
  local status label calibrated=false pixels_out pixels_rc

  case "$attempt" in *[!0-9]*|"") echo "VISUAL-QUALITY: attempt must be 0, 1, or 2" >&2; return 2 ;; esac
  [ -d "$root" ] || { echo "VISUAL-QUALITY: project root not a directory" >&2; return 2; }
  cq_regular_json_no_dupes "$record" || { echo "VISUAL-QUALITY: record is not safe JSON" >&2; return 2; }
  cq_record_dir=$(CDPATH='' cd -- "$(dirname -- "$record")" 2>/dev/null && pwd -P) || { echo "VISUAL-QUALITY: unresolved record dir" >&2; return 2; }

  record_json=$(jq -c . "$record")
  run_id=$(jq -r '.run_id // ""' <<<"$record_json")
  lock_sha=$(jq -r '.design_lock_sha256 // ""' <<<"$record_json")

  # A malformed or over-budget record is a hard block; nothing else is trusted.
  if ! cq_record_shape "$record"; then
    cq_block RECORD_INVALID
  fi
  if [ "$attempt" -gt 2 ]; then
    cq_add_reason REPAIR_BUDGET_EXHAUSTED
    cq_write_verdict halted "$verdict" "$record_json" NOT-CERTIFIED
    return 1
  fi

  if [ "$cq_blocked" -eq 1 ]; then
    cq_write_verdict blocked "$verdict" "$record_json" NOT-CERTIFIED
    return 1
  fi

  selected=$(jq -r '.tournament.selected_candidate_id' <<<"$record_json")
  selected_rev=$(jq -r '.tournament.selected_source_revision' <<<"$record_json")

  # --- Capture manifest: real, hash-independent verification via the pixel adapter.
  capture_rel=$(jq -r '.capture_manifest' <<<"$record_json")
  if manifest_json=$(cq_bind_receipt "$capture_rel" taste-capture-manifest/v1 2>/dev/null); then
    capture_sha=$(cq_sha256_file "$cq_record_dir/$capture_rel")
    # State coverage declared by the lock must be complete, both viewports.
    local st
    for st in $CERTIFY_REQUIRED_STATES; do
      jq -e --arg s "$st" '.required_states | index($s) != null' <<<"$manifest_json" >/dev/null 2>&1 || cq_block "MISSING_STATE:$st"
      jq -e --arg s "$st" '.required_states | index($s) != null' <<<"$record_json" >/dev/null 2>&1 || cq_block "LOCK_MISSING_STATE:$st"
    done
    jq -e 'any(.captures[]; .viewport == "desktop") and any(.captures[]; .viewport == "mobile")' <<<"$manifest_json" >/dev/null 2>&1 || cq_block MISSING_VIEWPORT
    [ "$(jq -r '.candidate_source_revision' <<<"$manifest_json")" = "$selected_rev" ] || cq_block SELECTION_REVISION_MISMATCH
    now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    pixels_rc=0
    pixels_out=$(bash "$cq_here/polylane-taste-pixels.sh" verify "$root" "$cq_record_dir/$capture_rel" "$now" 2>&1) || pixels_rc=$?
    [ "$pixels_rc" -eq 0 ] || cq_classify_pixels "$pixels_out"
  else
    cq_block CAPTURE_MANIFEST_INVALID
    capture_sha=''
  fi

  # --- Tournament receipt: strict schema, hash bound, winner re-derived.
  tournament_sha=$(jq -r '.tournament.receipt_sha256' <<<"$record_json")
  if tournament_json=$(cq_bind_receipt "$(jq -r '.tournament.receipt' <<<"$record_json")" taste-tournament-receipt/v1 "$tournament_sha" 2>/dev/null); then
    if jq -e --arg run "$run_id" --arg lock "$lock_sha" '
        (keys | sort == ["candidates","design_lock_sha256","event_log_sha256","judges","pairs","previous_event_sha256","run_id","schema_version","selection_label"])
        and .run_id == $run and .design_lock_sha256 == $lock
        and .selection_label == "SELECTED_NOT_CERTIFIED"
        and (.candidates | type == "array" and length == 3 and ([.[].candidate_id] | length == (unique | length)) and ([.[].source_revision] | length == (unique | length)) and all(.[]; (.candidate_id | type == "string" and length > 0) and (.source_revision | type == "string" and test("^[0-9a-f]{40,64}$")) and (.direction_id | type == "string" and length > 0)))
        and (.pairs | type == "array" and length == 3 and ([.[].pair] | sort == ["1-2","1-3","2-3"]))
        and (.judges | type == "array" and length > 0)
        and (.event_log_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
      ' <<<"$tournament_json" >/dev/null 2>&1; then
      # Every deciding exposure judge must be a calibration-eligible judge.
      if jq -e '
          ([.judges[] | select(.calibration == "eligible") | .judge_id]) as $ok
          | all(.pairs[]; (.exposures | type == "array" and length == 2)
              and ([.exposures[].display_order] | sort == ["A/B","B/A"])
              and (.exposures[0].judge_id != .exposures[1].judge_id)
              and (.exposures[0].canonical_choice == .exposures[1].canonical_choice)
              and (.canonical_winner == .exposures[0].canonical_choice)
              and all(.exposures[]; .judge_id as $j | ($ok | index($j)) != null))
        ' <<<"$tournament_json" >/dev/null 2>&1; then
        calibrated=true
      else
        cq_block WEAK_JUDGE
      fi
      # Each pair winner must be one of that pair's two candidates.
      jq -e '
        [.candidates[].candidate_id] as $ids
        | all(.pairs[]; . as $p | ($p.pair | split("-") | map(($ids[(tonumber-1)]))) as $duo | ($duo | index($p.canonical_winner)) != null)
      ' <<<"$tournament_json" >/dev/null 2>&1 || cq_block TOURNAMENT_PAIR_MISMATCH
      winner=$(cq_condorcet_winner "$tournament_json")
      [ -n "$winner" ] || cq_block TOURNAMENT_INDECISIVE
      if [ -n "$winner" ] && [ "$winner" != "$selected" ]; then cq_block CALLER_WINNER_MISMATCH; fi
    else
      cq_block TOURNAMENT_SCHEMA_INVALID
      winner=''
    fi
  else
    cq_block TOURNAMENT_RECEIPT_INVALID
    winner=''
    tournament_sha=''
  fi

  # --- Function / accessibility / state hard gate: any failure is a veto.
  if hard_json=$(cq_bind_receipt "$(jq -r '.hard_gate' <<<"$record_json")" taste-hard-gate/v1 2>/dev/null); then
    hard_sha=$(cq_sha256_file "$cq_record_dir/$(jq -r '.hard_gate' <<<"$record_json")")
    [ "$(jq -r '.candidate_id // ""' <<<"$hard_json")" = "$selected" ] || cq_block HARD_GATE_CANDIDATE_MISMATCH
    jq -e '.overall == "PASS"' <<<"$hard_json" >/dev/null 2>&1 || cq_block HARD_GATE_NOT_PASS
    jq -e '.task_results | type == "array" and length > 0 and all(.[]; .status == "pass")' <<<"$hard_json" >/dev/null 2>&1 || cq_block FUNCTION_VETO
    jq -e '.accessibility | type == "array" and length > 0 and all(.[]; .status == "pass")' <<<"$hard_json" >/dev/null 2>&1 || cq_block ACCESSIBILITY_VETO
    jq -e '.state_coverage | type == "array" and length > 0 and all(.[]; .status == "pass")' <<<"$hard_json" >/dev/null 2>&1 || cq_block STATE_COVERAGE_VETO
  else
    cq_block HARD_GATE_INVALID
    hard_sha=''
  fi

  # --- Threat receipt: clean, no injection, no authorship attribution.
  if threat_json=$(cq_bind_receipt "$(jq -r '.threat_receipt' <<<"$record_json")" taste-threat-receipt/v1 2>/dev/null); then
    threat_sha=$(cq_sha256_file "$cq_record_dir/$(jq -r '.threat_receipt' <<<"$record_json")")
    jq -e '
      (keys | sort) == ["axis_results","reason_codes","review","schema_version","status"]
      and .status == "clean"
      and .axis_results.genericness_review == "pass" and .axis_results.quality_risk == "pass"
      and .axis_results.context_fit == "pass" and .axis_results.provenance_integrity == "pass"
      and .review.status == "not-required" and .review.attribution_claim == false
      and (.reason_codes | type == "array" and length == 0)
    ' <<<"$threat_json" >/dev/null 2>&1 || cq_block PROVENANCE_VETO
  else
    cq_block THREAT_RECEIPT_INVALID
    threat_sha=''
  fi

  # --- Repair ledger: durable (brief, design-lock) attempt ledger, hash bound.
  if repair_json=$(cq_bind_receipt "$(jq -r '.repair_ledger' <<<"$record_json")" taste-repair-ledger/v1 2>/dev/null); then
    repair_sha=$(cq_sha256_file "$cq_record_dir/$(jq -r '.repair_ledger' <<<"$record_json")")
    jq -e '.status == "valid" and (.sha256 | type == "string" and test("^[0-9a-f]{64}$"))' <<<"$repair_json" >/dev/null 2>&1 || cq_block REPAIR_LEDGER_INVALID
  else
    cq_block REPAIR_LEDGER_INVALID
    repair_sha=''
  fi

  # --- Champion decision must be internally consistent, not caller-forced.
  local decision incumbent prev_ptr derived_decision
  decision=$(jq -r '.champion.decision' <<<"$record_json")
  incumbent=$(jq -r '.champion.incumbent_candidate_id // ""' <<<"$record_json")
  prev_ptr=$(jq -r '.champion.previous_champion_sha256 // ""' <<<"$record_json")
  if [ -n "$incumbent" ] && ! cq_is_sha "$prev_ptr"; then cq_block CHAMPION_CAS_MISSING; fi

  # --- Repair attempt: grounded, evidence-changed, budget-bounded.
  local outstanding_count repair_present
  outstanding_count=$(jq '.outstanding_findings | length' <<<"$record_json")
  repair_present=$([ "$(jq -r '.repair == null' <<<"$record_json")" = false ] && echo 1 || echo 0)
  local halt=0
  if [ "$attempt" -gt 0 ]; then
    if [ "$repair_present" -ne 1 ]; then
      halt=1; cq_add_reason REPAIR_UNGROUNDED
    else
      # Changed evidence: the repair must actually move the pixels/DOM/action
      # evidence — prior hash must differ from the fresh capture manifest hash.
      if [ "$(jq -r '.repair.changed' <<<"$record_json")" != true ]; then
        halt=1; cq_add_reason REPAIR_UNCHANGED
      elif [ -n "$capture_sha" ] && [ "$(jq -r '.repair.prior_evidence_sha256' <<<"$record_json")" = "$capture_sha" ]; then
        halt=1; cq_add_reason REPAIR_UNCHANGED
      fi
    fi
  fi

  # --- Derive the status. Priority: external > blocked > halted > repair > pass.
  if [ "$cq_external" -eq 1 ]; then
    status=external; label=UNKNOWN
  elif [ "$cq_blocked" -eq 1 ]; then
    status=blocked; label=NOT-CERTIFIED
  elif [ "$halt" -eq 1 ]; then
    status=halted; label=NOT-CERTIFIED
  elif [ "$outstanding_count" -gt 0 ]; then
    if [ "$attempt" -ge 2 ]; then status=halted; label=NOT-CERTIFIED; cq_add_reason REPAIR_BUDGET_EXHAUSTED
    else status=repair; label=UNKNOWN; fi
  else
    status=passed; label=SELECTED_NOT_CERTIFIED
    derived_decision=promote
    [ "$decision" = "$derived_decision" ] || { status=blocked; label=NOT-CERTIFIED; cq_add_reason CHAMPION_INCONSISTENT; }
  fi

  cq_capture_sha="$capture_sha"; cq_tournament_sha="$tournament_sha"; cq_hard_sha="$hard_sha"
  cq_threat_sha="$threat_sha"; cq_repair_sha="$repair_sha"; cq_winner="$winner"; cq_calibrated="$calibrated"
  cq_write_verdict "$status" "$verdict" "$record_json" "$label"
  [ "$status" = passed ]
}

cq_write_verdict() {
  local status="$1" verdict="$2" record_json="$3" label="$4" tmp codes_json targets_json
  codes_json=$(printf '%s' "$cq_reasons" | tr ' ' '\n' | sed '/^$/d' | jq -R . | jq -s .)
  targets_json=$(jq -c '.outstanding_findings // []' <<<"$record_json")
  mkdir -p "$(dirname "$verdict")"
  tmp=$(mktemp "${verdict}.tmp.XXXXXX") || return 1
  jq -n \
    --arg status "$status" \
    --argjson record "$record_json" \
    --arg capture_sha "${cq_capture_sha:-}" \
    --arg tournament_sha "${cq_tournament_sha:-}" \
    --arg hard_sha "${cq_hard_sha:-}" \
    --arg threat_sha "${cq_threat_sha:-}" \
    --arg repair_sha "${cq_repair_sha:-}" \
    --arg winner "${cq_winner:-}" \
    --arg label "$label" \
    --argjson calibrated "${cq_calibrated:-false}" \
    --argjson attempt "${cq_attempt:-0}" \
    --argjson codes "$codes_json" \
    --argjson targets "$targets_json" '
    {
      schema_version: "visual-quality-verdict/v2",
      status: $status,
      run_id: $record.run_id,
      attempt: $attempt,
      literal_goal_sha256: $record.literal_goal_sha256,
      packet_sha256: $record.packet_sha256,
      design_lock_sha256: $record.design_lock_sha256,
      tournament_input_sha256: $record.tournament.input_sha256,
      tournament_receipt_sha256: (if ($tournament_sha | length) > 0 then $tournament_sha else null end),
      capture_manifest_sha256: (if ($capture_sha | length) > 0 then $capture_sha else null end),
      hard_gate_sha256: (if ($hard_sha | length) > 0 then $hard_sha else null end),
      threat_receipt_sha256: (if ($threat_sha | length) > 0 then $threat_sha else null end),
      repair_ledger_sha256: (if ($repair_sha | length) > 0 then $repair_sha else null end),
      selected_candidate_id: $record.tournament.selected_candidate_id,
      selected_source_revision: $record.tournament.selected_source_revision,
      condorcet_winner: (if ($winner | length) > 0 then $winner else null end),
      champion: $record.champion,
      generic_pattern_signals: $record.generic_patterns,
      failed_criteria: $codes,
      repair_targets: (if $status == "repair" then $targets else [] end),
      claim_label: $label,
      calibrated_claim: $calibrated,
      human_claim: false,
      taste_memory_proposal: $record.taste_memory_proposal,
      external_limitations: ["panel identity, live-site and champion assurance remain externally scoped; local tournament label is SELECTED_NOT_CERTIFIED only"],
      reason_codes: $codes
    }
  ' > "$tmp" && mv -f "$tmp" "$verdict" || { rm -f "$tmp"; return 1; }
}

main() {
  cq_here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
  case "${1:-}" in
    run) { [ $# -eq 4 ] || [ $# -eq 5 ]; } || { usage; return 2; }; run_quality "$2" "$3" "$4" "${5:-0}" ;;
    benchmark) [ $# -eq 3 ] || { usage; return 2; }; benchmark_quality "$2" "$3" ;;
    certify) { [ $# -eq 4 ] || [ $# -eq 5 ]; } || { usage; return 2; }; cq_attempt="${5:-0}"; certify_quality "$2" "$3" "$4" "${5:-0}" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
