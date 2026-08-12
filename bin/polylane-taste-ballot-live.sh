#!/usr/bin/env bash
# polylane-taste-ballot-live.sh — production taste-ballot-validation/v2 producer.
#
# Derives a mirrored-group winner ONLY from bound live raw responses, pointwise
# records, stimulus orientation, calibration, capture, escrow, and independence
# evidence.  Every caller field is treated as forged until recomputed: the group
# SHA, both raw response hashes, pointwise self-hashes, request/image/orientation
# hashes, candidate capture hashes, calibration receipt hash, independence
# attestations, and escrow binding are recomputed here; the winner is derived
# from the raw responses via the orientation map, never trusted from the caller.
#
# Fail-closed: contradiction, tie, alias, reuse, leakage, injection, abstention
# asymmetry, stale timestamp, missing raw bytes, or a caller-supplied winner that
# the evidence does not derive → no receipt, non-zero exit.
#
# fixture_only:false (production classification "live") is reachable ONLY when
# every raw response is bound to a declared provider-adapter invocation receipt
# classified "live".  A fixture ancestor (any non-live invocation, or a
# shape-compatible hand-authored response) degrades to a fixture receipt and can
# never mint a production receipt.
#
# Bash 3.2 + jq.  main() is guarded so tests can source the functions.
set -euo pipefail

usage() { echo "usage: polylane-taste-ballot-live.sh derive BUNDLE_DIR OUT" >&2; }

die() { echo "TASTE-BALLOT-LIVE: $*" >&2; return 1; }

# Declared provider-adapter kinds whose "live" classification can unlock
# fixture_only:false.  Anything else is fixture evidence (EXTERNAL-EVIDENCE).
adapter_kind_declared() {
  case "$1" in
    claude-visual-judge|codex-visual-judge|gemini-visual-judge) return 0 ;;
    *) return 1 ;;
  esac
}

sha256_file() {
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else die "no SHA-256 command available"; fi
}

sha256_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

sha256_canonical() { jq -cS . "$1" | shasum -a 256 | awk '{print $1}'; }

# A real regular JSON file with no duplicate keys (jq --stream path scan).
regular_json_without_duplicate_keys() {
  local file="$1" duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | sort | uniq -d)
  [ -z "$duplicates" ]
}

# Recompute a record's self hash: SHA-256 of the canonical body with the named
# hash field removed.  (Matches the pointwise/v1 convention: the newline-stripped
# compact-sorted body, hashed without a trailing newline.)
record_self_hash() { local body; body=$(jq -cS "del(.$2)" "$1"); printf '%s' "$body" | shasum -a 256 | awk '{print $1}'; }

# Case-insensitive prompt-injection / jailbreak markers in raw bytes.
has_injection() {
  LC_ALL=C grep -qiE 'ignore (all )?previous|disregard (the )?(above|previous)|you are now|new instructions|override (the )?(system|prompt)|system prompt:|end of prompt|reveal (your )?prompt' "$1" 2>/dev/null \
    || LC_ALL=C grep -q $'\xe2\x80\x8b' "$1" 2>/dev/null
}

# A candidate-identity string leaking into judge-visible bytes.
contains_any_literal() { # file literal1 literal2 ...
  local file="$1"; shift
  local lit
  for lit in "$@"; do
    [ -n "$lit" ] || continue
    LC_ALL=C grep -qF -- "$lit" "$file" 2>/dev/null && return 0
  done
  return 1
}

# Forbidden identity/provider/model keys anywhere in the blinded group record.
group_has_identity_leak() {
  jq -e '[.. | objects | keys[]]
    | map(select(. as $k | ["provider","model","provider_id","model_id","model_version",
        "generator","author","candidate_name","candidate_label","candidate_id",
        "identity","api_key","system_prompt","prompt"] | index($k)))
    | length > 0' "$1" >/dev/null 2>&1
}

# --- group shape (blinded; exactly the keys the certificate compiler reads) ---
validate_group_shape() {
  jq -e '
    (keys | sort) == ["brief_sha256","candidate_ids_escrow_sha256","exposures","mirror_group_id","outcome","pointwise_ballot_ids","schema_version"]
    and .schema_version == "taste-mirrored-group/v1"
    and (.mirror_group_id | type == "string" and test("^mg-[a-z0-9-]{3,}$"))
    and ([.brief_sha256,.candidate_ids_escrow_sha256] | all(.[]; type == "string" and test("^[a-f0-9]{64}$")))
    and (.pointwise_ballot_ids | (type == "array") and (length == 2) and ((unique | length) == 2)
         and all(.[]; type == "string" and test("^pointwise-[a-z0-9-]{1,}$")))
    and (.outcome | type == "string" and test("^resolved-stim-[a-f0-9]{12}$"))
    and (.exposures | (type == "array") and (length == 2)
         and all(.[]; (keys | sort) == ["ballot_id","canonical_choice","choice","display_order","independence_attestation_sha256","judge_id","sealed_at"]
                and (.ballot_id | type == "string" and test("^pair-[a-z0-9-]{1,}$"))
                and (.judge_id | type == "string" and test("^judge-[a-z0-9-]{3,}$"))
                and (.canonical_choice | type == "string" and test("^stim-[a-f0-9]{12}$"))
                and (.choice | IN("A","B"))
                and (.display_order | IN("A/B","B/A"))
                and (.independence_attestation_sha256 | type == "string" and test("^[a-f0-9]{64}$"))
                and (.sealed_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")))
         and ([.[].display_order] | sort) == ["A/B","B/A"]
         and ([.[].ballot_id] | unique | length) == 2)
  ' "$1" >/dev/null 2>&1
}

validate_pointwise() { # file expected-id brief-sha capture-sha winner loser
  local file="$1" id="$2" brief="$3" capture="$4" w="$5" l="$6" actual
  regular_json_without_duplicate_keys "$file" || return 1
  actual=$(record_self_hash "$file" record_sha256) || return 1
  jq -e --arg id "$id" --arg brief "$brief" --arg capture "$capture" \
        --arg body "$actual" --arg w "$w" --arg l "$l" '
    (keys | sort) == ["ballot_id","brief_sha256","candidate_id","capture_manifest_sha256","identity_visible","injection_detected","judge_discussion","judge_id","observations","prior_ballots_visible","record_sha256","schema_version","scores_1_to_7","sealed_at"]
    and .schema_version == "taste-pointwise/v1"
    and .ballot_id == $id
    and .record_sha256 == $body
    and (.judge_id | type == "string" and test("^judge-[a-z0-9-]{3,}$"))
    and .brief_sha256 == $brief
    and .capture_manifest_sha256 == $capture
    and (.candidate_id | IN($w,$l))
    and (.sealed_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
    and (.identity_visible == false and .prior_ballots_visible == false and .injection_detected == false and .judge_discussion == false)
    and (.scores_1_to_7 | (type == "object") and (keys | sort) == ["color","craftsmanship","hierarchy","originality","product_fit","spatial_rhythm","state_coherence","typography"]
         and all(.[]; type == "number" and floor == . and . >= 1 and . <= 7))
    and (.observations | (type == "array") and (length == 8)
         and ([.[].criterion] | sort) == ["color","craftsmanship","hierarchy","originality","product_fit","spatial_rhythm","state_coherence","typography"]
         and all(.[]; (keys | sort) == ["brief_clause","capture_id","criterion","reason","region_or_state"]
                and ([.capture_id,.region_or_state,.brief_clause,.reason] | all(.[]; type == "string" and length > 0))))
  ' "$file" >/dev/null 2>&1
}

# --- the derivation ----------------------------------------------------------
derive() {
  local bundle="$1" out="$2"
  [ -d "$bundle" ] && [ ! -L "$bundle" ] || die "invalid bundle directory"

  local group="$bundle/group.json" brief="$bundle/brief.json" escrow="$bundle/escrow.json" \
        orientation="$bundle/orientation.json" capture="$bundle/capture-manifest.json" \
        calibration="$bundle/calibration.json"
  local f
  for f in "$group" "$escrow" "$orientation" "$capture" "$calibration"; do
    regular_json_without_duplicate_keys "$f" || die "invalid or non-regular JSON: $f"
  done
  [ -f "$brief" ] && [ ! -L "$brief" ] || die "missing brief bytes"

  # Identity-leak scan runs first so an identity key gets its specific verdict
  # (the key-lock below would otherwise reject it as a generic shape error).
  ! group_has_identity_leak "$group" || die "IDENTITY_LEAK: forbidden identity key in blinded group"
  validate_group_shape "$group" || die "malformed blinded group"

  local group_sha brief_sha escrow_sha capture_sha calibration_sha orientation_sha
  group_sha=$(sha256_file "$group")
  brief_sha=$(sha256_file "$brief")
  escrow_sha=$(sha256_canonical "$escrow")
  capture_sha=$(sha256_file "$capture")
  calibration_sha=$(sha256_file "$calibration")
  orientation_sha=$(sha256_file "$orientation")

  # -- brief + escrow binding -------------------------------------------------
  [ "$brief_sha" = "$(jq -r .brief_sha256 "$group")" ] || die "brief bytes do not bind group.brief_sha256"
  [ "$escrow_sha" = "$(jq -r .candidate_ids_escrow_sha256 "$group")" ] || die "escrow does not bind group.candidate_ids_escrow_sha256"

  jq -e '.schema_version == "taste-stimulus-escrow/v1"
    and (.bindings | (type == "array") and (length == 2)
         and ([.[].stimulus_id] | (unique | length) == 2)
         and all(.[]; (.stimulus_id | type == "string" and test("^stim-[a-f0-9]{12}$"))
                and (.candidate_id | type == "string" and length > 0)))
    and ([.bindings[].candidate_id] | (unique | length) == 2)
  ' "$escrow" >/dev/null 2>&1 || die "ALIAS: escrow is not two distinct stimuli bound to two distinct candidates"

  # Winner and loser are the two escrowed stimuli; the winner is DERIVED below.
  local stim_a stim_b
  stim_a=$(jq -r '.bindings[0].stimulus_id' "$escrow")
  stim_b=$(jq -r '.bindings[1].stimulus_id' "$escrow")

  # -- orientation: a balanced exact mirror over exactly the escrowed pair ----
  jq -e --arg a "$stim_a" --arg b "$stim_b" '
    .schema_version == "taste-stimulus-orientation/v1"
    and (.orientation | (keys | sort) == ["A/B","B/A"])
    and (.orientation["A/B"] | (keys | sort) == ["A","B","sha256"])
    and (.orientation["B/A"] | (keys | sort) == ["A","B","sha256"])
    and (([.orientation["A/B"].A,.orientation["A/B"].B] | sort) == ([$a,$b] | sort))
    and (.orientation["A/B"].A == .orientation["B/A"].B)
    and (.orientation["A/B"].B == .orientation["B/A"].A)
    and (.orientation["A/B"].A != .orientation["A/B"].B)
  ' "$orientation" >/dev/null 2>&1 || die "orientation is not a balanced mirror over the escrowed pair"
  [ "$(jq -r '.orientation."A/B".sha256' "$orientation")" = \
    "$(sha256_text "A/B|A=$(jq -r '.orientation."A/B".A' "$orientation")|B=$(jq -r '.orientation."A/B".B' "$orientation")")" ] \
    || die "A/B orientation hash mismatch"
  [ "$(jq -r '.orientation."B/A".sha256' "$orientation")" = \
    "$(sha256_text "B/A|A=$(jq -r '.orientation."B/A".A' "$orientation")|B=$(jq -r '.orientation."B/A".B' "$orientation")")" ] \
    || die "B/A orientation hash mismatch"

  # -- capture manifest binds both candidate screenshots ----------------------
  jq -e --arg a "$stim_a" --arg b "$stim_b" '
    .schema_version == "taste-capture-manifest/v1"
    and (.captures | type == "object")
    and (.captures as $caps
         | [$a,$b] | all(. as $s
             | ($caps | has($s))
             and ($caps[$s].screenshot_png_sha256 | type == "string" and test("^[a-f0-9]{64}$"))))
  ' "$capture" >/dev/null 2>&1 || die "capture manifest is missing a bound screenshot for a candidate"

  # -- pointwise records ------------------------------------------------------
  local pw_dir="$bundle/pointwise" pw_id pw_file latest_pw="" pw_sealed
  [ -d "$pw_dir" ] && [ ! -L "$pw_dir" ] || die "missing pointwise directory"
  while IFS= read -r pw_id; do
    pw_file="$pw_dir/$pw_id.json"
    validate_pointwise "$pw_file" "$pw_id" "$brief_sha" "$capture_sha" "$stim_a" "$stim_b" \
      || die "invalid pointwise record: $pw_id"
    pw_sealed=$(jq -r .sealed_at "$pw_file")
    if [ "$pw_sealed" \> "$latest_pw" ]; then latest_pw="$pw_sealed"; fi
  done < <(jq -r '.pointwise_ballot_ids[]' "$group")

  # -- calibration: judges self-declared eligible is NOT enough; each serving
  #    judge must be eligible/independent here AND independently attested below.
  jq -e '.schema_version == "taste-ballot-calibration/v2"
    and (.judge_eligibility | (type == "array")
         and (([.[].judge_id] | length) == ([.[].judge_id] | unique | length))
         and all(.[]; (keys | sort) == ["abstention_policy","eligible","independent","judge_id","no_candidate_identity","no_shared_ballot_channel"]
                and (.judge_id | type == "string" and test("^judge-[a-z0-9-]{3,}$"))))
  ' "$calibration" >/dev/null 2>&1 || die "malformed calibration receipt"

  # -- exposures: recompute every binding, derive each choice from raw bytes --
  local now="${TASTE_NOW:-}"
  local idx=0 all_live=1
  local jid_0="" jid_1="" sess_0="" sess_1="" fp_0="" fp_1="" resp_0="" resp_1="" \
        canon_0="" canon_1="" order_0="" order_1=""
  local exp order ballot judge canon claim_choice att_sha \
        edir resp req inv att resp_sha req_sha att_calc raw_choice mapped \
        session fp img_a img_b req_img_a req_img_b

  while [ "$idx" -lt 2 ]; do
    exp=$(jq -c --argjson i "$idx" '.exposures[$i]' "$group")
    order=$(printf '%s' "$exp"   | jq -r .display_order)
    ballot=$(printf '%s' "$exp"  | jq -r .ballot_id)
    judge=$(printf '%s' "$exp"   | jq -r .judge_id)
    canon=$(printf '%s' "$exp"   | jq -r .canonical_choice)
    claim_choice=$(printf '%s' "$exp" | jq -r .choice)
    att_sha=$(printf '%s' "$exp" | jq -r .independence_attestation_sha256)

    edir="$bundle/exposures/$ballot"
    resp="$edir/response.raw"; req="$edir/request.json"; inv="$edir/invocation.json"; att="$edir/attestation.json"
    [ -d "$edir" ] && [ ! -L "$edir" ] || die "missing exposure directory: $ballot"
    # missing raw bytes fails closed
    [ -f "$resp" ] && [ ! -L "$resp" ] && [ -s "$resp" ] || die "missing raw response bytes: $ballot"
    for f in "$req" "$inv" "$att"; do
      regular_json_without_duplicate_keys "$f" || die "invalid exposure JSON: $f"
    done

    resp_sha=$(sha256_file "$resp")
    req_sha=$(sha256_file "$req")
    att_calc=$(sha256_file "$att")

    # response bytes bind the exposure's response_sha256 (carried in invocation).
    # injection / identity leakage in judge-visible bytes fail closed.
    ! has_injection "$resp" || die "INJECTION: prompt injection in raw response: $ballot"
    ! has_injection "$req"  || die "INJECTION: prompt injection in request: $ballot"
    if contains_any_literal "$resp" "$(jq -r '.bindings[0].candidate_id' "$escrow")" "$(jq -r '.bindings[1].candidate_id' "$escrow")"; then
      die "IDENTITY_LEAK: candidate identity present in raw response: $ballot"
    fi
    if contains_any_literal "$req" "$(jq -r '.bindings[0].candidate_id' "$escrow")" "$(jq -r '.bindings[1].candidate_id' "$escrow")"; then
      die "IDENTITY_LEAK: candidate identity present in request: $ballot"
    fi

    # attestation binds this exact judge, this ballot, an isolated session, and
    # declares no shared ballot channel.  Its SHA binds the blinded group edge.
    [ "$att_calc" = "$att_sha" ] || die "independence attestation hash does not bind exposure: $ballot"
    jq -e --arg j "$judge" --arg b "$ballot" '
      .schema_version == "taste-independence-attestation/v1"
      and .judge_id == $j and .ballot_id == $b
      and .no_shared_ballot_channel == true and .independent == true
      and (.session_id | type == "string" and length > 0)
      and (.judge_fingerprint | type == "string" and test("^[a-f0-9]{64}$"))
    ' "$att" >/dev/null 2>&1 || die "malformed / non-independent attestation: $ballot"
    session=$(jq -r .session_id "$att"); fp=$(jq -r .judge_fingerprint "$att")

    # request binds the two candidate images to the orientation and to capture.
    req_img_a=$(jq -r '.images.A.stimulus_id' "$req"); req_img_b=$(jq -r '.images.B.stimulus_id' "$req")
    [ "$req_img_a" = "$(jq -r --arg o "$order" '.orientation[$o].A' "$orientation")" ] \
      && [ "$req_img_b" = "$(jq -r --arg o "$order" '.orientation[$o].B' "$orientation")" ] \
      || die "request image order disagrees with orientation: $ballot"
    img_a=$(jq -r --arg s "$req_img_a" '.captures[$s].screenshot_png_sha256' "$capture")
    img_b=$(jq -r --arg s "$req_img_b" '.captures[$s].screenshot_png_sha256' "$capture")
    req_img_a=$(jq -r '.images.A.image_sha256' "$req"); req_img_b=$(jq -r '.images.B.image_sha256' "$req")
    [ "$req_img_a" = "$img_a" ] && [ "$req_img_b" = "$img_b" ] \
      || die "request image hashes do not bind capture manifest: $ballot"

    # invocation: declared provider adapter, content-bound to request+response,
    # this judge, this session.  Only a "live" declared adapter is production.
    jq -e --arg j "$judge" --arg rs "$resp_sha" --arg qs "$req_sha" --arg ss "$session" '
      .schema_version == "taste-judge-invocation/v1"
      and .judge_id == $j
      and .response_sha256 == $rs
      and .request_sha256 == $qs
      and .session_id == $ss
      and (.classification | IN("live","fixture"))
      and (.adapter | type == "object"
           and (.adapter_id | type == "string" and length > 0)
           and (.adapter_kind | type == "string" and length > 0)
           and (.command_sha256 | type == "string" and test("^[a-f0-9]{64}$")))
      and (.sealed_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
    ' "$inv" >/dev/null 2>&1 || die "malformed invocation receipt: $ballot"
    if [ "$(jq -r .classification "$inv")" != live ] || ! adapter_kind_declared "$(jq -r .adapter.adapter_kind "$inv")"; then
      all_live=0   # fixture ancestor: degrade, never mint production
    fi

    # timestamps: pairwise sealed strictly after the latest pointwise; invocation
    # no later than the sealed exposure; nothing dated in the future.
    local inv_sealed exp_sealed
    inv_sealed=$(jq -r .sealed_at "$inv"); exp_sealed=$(printf '%s' "$exp" | jq -r .sealed_at)
    [ "$exp_sealed" \> "$latest_pw" ] || die "STALE_TIMESTAMP: exposure not sealed after pointwise: $ballot"
    if [ "$inv_sealed" \> "$exp_sealed" ]; then die "STALE_TIMESTAMP: invocation sealed after its exposure: $ballot"; fi
    if [ -n "$now" ]; then
      if [ "$exp_sealed" \> "$now" ]; then die "STALE_TIMESTAMP: exposure dated in the future: $ballot"; fi
      if [ "$inv_sealed" \> "$now" ]; then die "STALE_TIMESTAMP: invocation dated in the future: $ballot"; fi
    fi

    # derive the choice from the raw response bytes, map it through orientation,
    # and require it to match the caller's blinded claim exactly.
    raw_choice=$(jq -r 'if type=="object" and .schema_version=="taste-judge-response/v1" then .choice else "invalid" end' "$resp" 2>/dev/null || echo invalid)
    case "$raw_choice" in
      A|B) : ;;
      abstain) die "ABSTENTION: raw response abstained but blinded group claims a side: $ballot" ;;
      *) die "unparseable raw response: $ballot" ;;
    esac
    [ "$raw_choice" = "$claim_choice" ] || die "CALLER_WINNER: derived side does not match blinded group choice: $ballot"
    mapped=$(jq -r --arg o "$order" --arg c "$raw_choice" '.orientation[$o][$c]' "$orientation")
    [ "$mapped" = "$canon" ] || die "CALLER_WINNER: derived canonical choice does not match group: $ballot"

    if [ "$idx" = 0 ]; then
      jid_0="$judge"; sess_0="$session"; fp_0="$fp"; resp_0="$resp_sha"; canon_0="$canon"; order_0="$order"
    else
      jid_1="$judge"; sess_1="$session"; fp_1="$fp"; resp_1="$resp_sha"; canon_1="$canon"; order_1="$order"
    fi
    idx=$((idx + 1))
  done

  # -- cross-exposure independence, no reuse, no alias ------------------------
  [ "$order_0" != "$order_1" ] || die "both exposures use the same display order"
  [ "$jid_0" != "$jid_1" ] || die "JUDGE_NOT_INDEPENDENT: one judge served both orientations"
  [ "$fp_0" != "$fp_1" ] || die "ALIAS: two judge ids share one fingerprint"
  [ "$sess_0" != "$sess_1" ] || die "REUSE: shared ballot channel (same session id)"
  [ "$resp_0" != "$resp_1" ] || die "REUSE: identical raw response reused across orientations"

  # -- each serving judge must be calibrated eligible + independent -----------
  local j
  for j in "$jid_0" "$jid_1"; do
    jq -e --arg j "$j" 'any(.judge_eligibility[]; .judge_id == $j and .eligible == true
        and .independent == true and .abstention_policy == "pass"
        and .no_candidate_identity == true and .no_shared_ballot_channel == true)' \
      "$calibration" >/dev/null 2>&1 || die "judge not calibrated-eligible: $j"
  done

  # -- winner is DERIVED: strict, unanimous, no contradiction, no tie --------
  [ "$canon_0" = "$canon_1" ] || die "SIDE_ORDER_CONTRADICTION: mirrored orientations disagree"
  local winner="$canon_0"
  case "$winner" in "$stim_a"|"$stim_b") : ;; *) die "derived winner is not an escrowed candidate" ;; esac

  # -- caller's group must claim exactly the derived winner -------------------
  [ "$(jq -r '.exposures[0].canonical_choice' "$group")" = "$winner" ] || die "CALLER_WINNER: group winner differs from derivation"
  [ "$(jq -r .outcome "$group")" = "resolved-$winner" ] || die "CALLER_WINNER: group outcome differs from derivation"

  # -- classification: live only if every invocation was declared-live --------
  local classification fixture_only reason_codes
  if [ "$all_live" = 1 ]; then
    classification="live"; fixture_only="false"; reason_codes='[]'
  else
    classification="fixture"; fixture_only="true"; reason_codes='["FIXTURE_EVIDENCE"]'
  fi

  local validator_fp tmp
  validator_fp=$(sha256_file "${BASH_SOURCE[0]}") || die "cannot fingerprint validator"
  mkdir -p "$(dirname "$out")"
  tmp=$(mktemp "${out}.tmp.XXXXXX") || return 1
  jq -n \
    --arg group_sha "$group_sha" --arg brief_sha "$brief_sha" --arg escrow_sha "$escrow_sha" \
    --arg capture_sha "$capture_sha" --arg calibration_sha "$calibration_sha" --arg orientation_sha "$orientation_sha" \
    --arg winner "$winner" --arg classification "$classification" --argjson fixture_only "$fixture_only" \
    --arg validator_fp "$validator_fp" --argjson reason_codes "$reason_codes" \
    --arg j0 "$jid_0" --arg j1 "$jid_1" --arg r0 "$resp_0" --arg r1 "$resp_1" \
    --arg c0 "$canon_0" --arg c1 "$canon_1" --arg o0 "$order_0" --arg o1 "$order_1" \
    --slurpfile group "$group" '
    ($group[0]) as $g | {
      schema_version:"taste-ballot-validation/v2",
      receipt_version:"polylane.taste.ballot-receipt.v2",
      status:"eligible",
      classification:$classification,
      fixture_only:$fixture_only,
      human_certified:false,
      mirror_group_id:$g.mirror_group_id,
      brief_sha256:$brief_sha,
      winner:$winner,
      group_sha256:$group_sha,
      input_sha256:$group_sha,
      derived:{
        winner:$winner,
        method:"unanimous-mirrored-pairwise",
        exposures:[
          {display_order:$o0,judge_id:$j0,canonical_choice:$c0,response_sha256:$r0},
          {display_order:$o1,judge_id:$j1,canonical_choice:$c1,response_sha256:$r1}
        ]
      },
      inputs:{
        group_sha256:$group_sha,
        brief_sha256:$brief_sha,
        candidate_ids_escrow_sha256:$escrow_sha,
        capture_manifest_sha256:$capture_sha,
        calibration_sha256:$calibration_sha,
        orientation_sha256:$orientation_sha
      },
      judges:[$j0,$j1],
      validator:{id:"polylane-taste-ballot-live",fingerprint:$validator_fp},
      reason_codes:$reason_codes
    }' > "$tmp" && mv "$tmp" "$out"
}

main() {
  [ "${1:-}" = derive ] && [ $# -eq 3 ] || { usage; return 2; }
  command -v jq >/dev/null 2>&1 || die "jq is required"
  derive "$2" "$3"
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
