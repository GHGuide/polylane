#!/usr/bin/env bash
# polylane-visual-tournament.sh — taste-tournament/v1 controller.
#
# A fail-closed visual candidate tournament. It NEVER trusts a caller-supplied
# status, score, winner, pass, or prose lens: the winner is DERIVED from real
# decoded-pixel evidence, deterministic function/accessibility/provenance vetoes,
# and a complete blind round-robin of independently calibrated human ballots.
#
# Durable state — an append-only hash-chained event log plus an atomic
# compare-and-swap champion registry — is authoritative, not the caller JSON.
# The controller COMPOSES the frozen Cycle-38 validators instead of duplicating
# them: polylane-taste-pixels.sh verifies rendered captures, polylane-taste-
# ballot.sh validates one mirrored human ballot group. This file only orchestrates
# freezing, gating, aggregation, Condorcet selection, bounded repair, and CAS
# champion persistence.
#
# Labels: a local winner is SELECTED_NOT_CERTIFIED. It can never mutate a
# separate certified registry and never claims human certification.
#
# Pure Bash 3.2 + jq + git + a SHA-256 command. Main-guarded.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PIXELS="$HERE/polylane-taste-pixels.sh"
BALLOT="$HERE/polylane-taste-ballot.sh"
US=$'\037'                       # unit separator for canonical hash inputs
ZERO64=0000000000000000000000000000000000000000000000000000000000000000

usage() {
  cat >&2 <<'EOF'
usage:
  polylane-visual-tournament.sh lock       STATE_DIR LOCK_JSON NOW
  polylane-visual-tournament.sh run        STATE_DIR TOURNAMENT_JSON NOW
  polylane-visual-tournament.sh reserve    STATE_DIR REPAIR_JSON NOW
  polylane-visual-tournament.sh repair     STATE_DIR TOURNAMENT_JSON NOW
  polylane-visual-tournament.sh select     PROJECT_ROOT TOURNAMENT_JSON RECEIPT_JSON NOW
  polylane-visual-tournament.sh champion   STATE_DIR
  polylane-visual-tournament.sh state      STATE_DIR
  polylane-visual-tournament.sh verify-log STATE_DIR
  polylane-visual-tournament.sh aggregate-match ESCROW MIN PAIR CAND_A CAND_B -- GROUP POINTWISE CALIBRATION ...
  polylane-visual-tournament.sh check-captures TOURNAMENT_JSON NOW
EOF
}

die() { printf 'TOURNAMENT: %s\n' "$1" >&2; return 2; }

# --- primitives --------------------------------------------------------------
sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else return 1; fi
}
sha256_text() {
  if command -v shasum >/dev/null 2>&1; then printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then printf '%s' "$1" | sha256sum | awk '{print $1}'
  else return 1; fi
}
valid_now() { case "$1" in ????-??-??T??:??:??Z) return 0 ;; *) return 1 ;; esac; }

json_no_dupkeys() {
  local file="$1" duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

# safe_rel BASE REL KIND(dir|file) -> prints resolved absolute path; rejects
# empties, absolutes, traversal, and any symlink component. "." resolves to BASE.
safe_rel() {
  local base="$1" rel="$2" kind="$3" prefix part old_ifs
  case "$rel" in ""|/*|*'//'*) return 1 ;; esac
  if [ "$rel" = "." ]; then
    [ "$kind" = dir ] && [ -d "$base" ] && [ ! -L "$base" ] && { printf '%s\n' "$base"; return 0; }
    return 1
  fi
  prefix="$base"; old_ifs=$IFS; IFS='/'
  for part in $rel; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
    prefix="$prefix/$part"
    [ ! -L "$prefix" ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
  case "$kind" in
    dir)  [ -d "$base/$rel" ] && [ ! -L "$base/$rel" ] ;;
    file) [ -f "$base/$rel" ] && [ ! -L "$base/$rel" ] ;;
    *) return 1 ;;
  esac || return 1
  printf '%s\n' "$base/$rel"
}

# --- event log: append-only, hash-chained ------------------------------------
event_hash() { sha256_text "$1$US$2$US$3$US$4$US$5"; }   # seq kind recorded_at prev payload_canon

_lock() { local d="$1" i=0; until mkdir "$d/.lock" 2>/dev/null; do i=$((i + 1)); [ "$i" -lt 400 ] || return 1; done; }
_unlock() { rmdir "$1/.lock" 2>/dev/null || true; }

# chain_ok DIR : the log (if any) is contiguous, unmutated, and completely
# written. A skipped seq, a rechained previous hash, a mutated payload, or an
# interrupted (truncated) final line all fail closed.
chain_ok() {
  local dir="$1"; local logf="$dir/events.log"
  local line seq prev kind rec canon esha calc exp_seq=0 exp_prev="$ZERO64"
  [ -f "$logf" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s' "$line" | jq -e '(type=="object") and ((keys|sort)==["event_sha256","kind","payload","previous_event_sha256","recorded_at","seq"])' >/dev/null 2>&1 || return 1
    seq=$(printf '%s' "$line" | jq -r '.seq')
    [ "$seq" = "$exp_seq" ] || return 1
    prev=$(printf '%s' "$line" | jq -r '.previous_event_sha256')
    [ "$prev" = "$exp_prev" ] || return 1
    kind=$(printf '%s' "$line" | jq -r '.kind')
    rec=$(printf '%s' "$line" | jq -r '.recorded_at')
    canon=$(printf '%s' "$line" | jq -cS '.payload')
    esha=$(printf '%s' "$line" | jq -r '.event_sha256')
    calc=$(event_hash "$seq" "$kind" "$rec" "$prev" "$canon") || return 1
    [ "$calc" = "$esha" ] || return 1
    exp_prev="$esha"; exp_seq=$((exp_seq + 1))
  done < "$logf"
  return 0
}

append_event() {
  local dir="$1" kind="$2" payload="$3" now="$4" logf seq prev canon rec esha tmp
  logf="$dir/events.log"
  _lock "$dir" || { echo "TOURNAMENT: could not acquire log lock" >&2; return 2; }
  if ! chain_ok "$dir"; then _unlock "$dir"; echo "TOURNAMENT: refusing to append onto a corrupt log" >&2; return 2; fi
  if [ -f "$logf" ] && [ -s "$logf" ]; then
    seq=$(tail -n 1 "$logf" | jq -r '.seq'); seq=$((seq + 1))
    prev=$(tail -n 1 "$logf" | jq -r '.event_sha256')
  else
    seq=0; prev="$ZERO64"
  fi
  canon=$(printf '%s' "$payload" | jq -cS .) || { _unlock "$dir"; return 2; }
  rec="$now"
  esha=$(event_hash "$seq" "$kind" "$rec" "$prev" "$canon")
  tmp=$(mktemp "$logf.tmp.XXXXXX") || { _unlock "$dir"; return 2; }
  # Build the full line first, then a single atomic append: an interrupted write
  # can never leave a half-line, and chain_ok would catch it if it did.
  jq -cn --argjson seq "$seq" --arg kind "$kind" --arg rec "$rec" --arg prev "$prev" --argjson payload "$canon" --arg esha "$esha" \
    '{seq:$seq,kind:$kind,recorded_at:$rec,previous_event_sha256:$prev,payload:$payload,event_sha256:$esha}' > "$tmp" || { rm -f "$tmp"; _unlock "$dir"; return 2; }
  cat "$tmp" >> "$logf"; rm -f "$tmp"
  _unlock "$dir"
}

# project DIR : replay the verified chain into a compact state JSON on stdout.
project() {
  local dir="$1"; local logf="$dir/events.log"
  local line kind p
  chain_ok "$dir" || return 1
  local phase=NEW run_id="" base="" dlock="" goal="" cids='[]' min_groups=0 budget=0
  local reservations=0 pending=0 champ_gen=-1 incumbent="" seen='[]'
  if [ -f "$logf" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      kind=$(printf '%s' "$line" | jq -r '.kind')
      p=$(printf '%s' "$line" | jq -c '.payload')
      case "$kind" in
        TOURNAMENT_LOCKED)
          phase=LOCKED
          run_id=$(printf '%s' "$p" | jq -r '.run_id')
          base=$(printf '%s' "$p" | jq -r '.base_revision')
          dlock=$(printf '%s' "$p" | jq -r '.design_lock_sha256')
          goal=$(printf '%s' "$p" | jq -r '.goal_sha256')
          cids=$(printf '%s' "$p" | jq -c '.candidate_ids')
          min_groups=$(printf '%s' "$p" | jq -r '.min_groups')
          budget=$(printf '%s' "$p" | jq -r '.repair_budget')
          ;;
        REPAIR_RESERVED)
          reservations=$((reservations + 1))
          pending=$(printf '%s' "$p" | jq -r '.attempt')
          phase=REPAIR_RESERVED
          ;;
        SELECTION)  : ;;    # selection is advisory; the champion event is authoritative
        CHAMPION_ADVANCED)
          champ_gen=$(printf '%s' "$p" | jq -r '.generation')
          incumbent=$(printf '%s' "$p" | jq -r '.champion_candidate_id')
          seen=$(printf '%s' "$seen" | jq -c --arg c "$incumbent" '. + [$c]')
          pending=0
          phase=SELECTED
          ;;
        REPAIR_RESULT)
          # A RETAINED result keeps the incumbent and re-opens the budget for a
          # further attempt; a REPLAN result is terminal.
          pending=0
          if [ "$(printf '%s' "$p" | jq -r '.verdict')" = REPLAN ]; then phase=REPLAN; else phase=SELECTED; fi
          ;;
        REPLAN) phase=REPLAN; pending=0 ;;
      esac
    done < "$logf"
  fi
  jq -n --arg phase "$phase" --arg run_id "$run_id" --arg base "$base" --arg dlock "$dlock" --arg goal "$goal" \
    --argjson cids "$cids" --argjson min_groups "${min_groups:-0}" --argjson budget "${budget:-0}" \
    --argjson reservations "$reservations" --argjson pending "$pending" --argjson champ_gen "$champ_gen" \
    --arg incumbent "$incumbent" --argjson seen "$seen" '
    {phase:$phase,run_id:$run_id,base_revision:$base,design_lock_sha256:$dlock,goal_sha256:$goal,
     candidate_ids:$cids,min_groups:$min_groups,repair_budget:$budget,repairs_reserved:$reservations,
     pending_repair_attempt:$pending,champion_generation:$champ_gen,incumbent:$incumbent,seen_champions:$seen}'
}

pj() { printf '%s' "$1" | jq -r "$2"; }   # field from a state JSON

# --- champion registry: atomic compare-and-swap -----------------------------
advance_champion() {
  local dir="$1" cand="$2" expected_gen="$3" run_id="$4" now="$5"; local reg="$dir/champion.json"
  local on_disk prev new_gen tmp
  _lock "$dir" || return 2
  if [ -f "$reg" ]; then on_disk=$(jq -r '.generation' "$reg" 2>/dev/null || echo x); else on_disk=-1; fi
  if [ "$on_disk" != "$expected_gen" ]; then _unlock "$dir"; echo "TOURNAMENT: champion CAS stale (expected gen $expected_gen, on-disk $on_disk)" >&2; return 3; fi
  if [ -f "$reg" ]; then prev=$(sha256_file "$reg"); else prev="$ZERO64"; fi
  new_gen=$((expected_gen + 1))
  tmp=$(mktemp "$reg.tmp.XXXXXX") || { _unlock "$dir"; return 2; }
  jq -n --argjson gen "$new_gen" --arg cand "$cand" --arg run "$run_id" --arg prev "$prev" --arg now "$now" \
    '{schema_version:"taste-champion-registry/v1",generation:$gen,champion_candidate_id:$cand,label:"SELECTED_NOT_CERTIFIED",run_id:$run,previous_generation_sha256:$prev,advanced_at:$now}' > "$tmp" || { rm -f "$tmp"; _unlock "$dir"; return 2; }
  mv "$tmp" "$reg"
  _unlock "$dir"
  append_event "$dir" CHAMPION_ADVANCED "$(jq -n --argjson gen "$new_gen" --arg cand "$cand" --arg prev "$prev" '{generation:$gen,champion_candidate_id:$cand,previous_generation_sha256:$prev,label:"SELECTED_NOT_CERTIFIED"}')" "$now"
}

write_receipt() {   # DIR NAME JSON  (immutable: never overwrite)
  local dir="$1" name="$2" json="$3" path
  mkdir -p "$dir/receipts"
  path="$dir/receipts/$name.json"
  [ -e "$path" ] && { echo "TOURNAMENT: receipt $name already exists (immutable)" >&2; return 2; }
  printf '%s\n' "$json" | jq -S . > "$path"
}

# --- candidate evidence: captures + deterministic vetoes ---------------------
# Prints the candidate's decoded-pixel digest on success. Reject stale, wrong,
# duplicate, placeholder, or lock/goal-mismatched evidence via the pixel verifier
# plus a task/accessibility/provenance hard-gate receipt BEFORE any taste vote.
verify_candidate() {
  local evid="$1" cand="$2" root_rel="$3" manifest_rel="$4" gate_rel="$5" base="$6" now="$7" \
        root_abs manifest_abs gate_abs man_sha pixels_out digest
  root_abs=$(safe_rel "$evid" "$root_rel" dir) || { echo "TOURNAMENT: unsafe capture_root for $cand" >&2; return 2; }
  manifest_abs=$(safe_rel "$evid" "$manifest_rel" file) || { echo "TOURNAMENT: unsafe capture_manifest for $cand" >&2; return 2; }
  gate_abs=$(safe_rel "$evid" "$gate_rel" file) || { echo "TOURNAMENT: unsafe hard_gate for $cand" >&2; return 2; }
  json_no_dupkeys "$manifest_abs" || { echo "TOURNAMENT: manifest not clean JSON for $cand" >&2; return 2; }
  [ "$(jq -r '.candidate_source_revision' "$manifest_abs")" = "$base" ] || { echo "TOURNAMENT: capture source != frozen base for $cand" >&2; return 2; }
  # Compose the frozen pixel verifier — real decode, viewport, freshness, dup.
  pixels_out=$(TASTE_NOW="$now" "$PIXELS" verify "$root_abs" "$manifest_abs" "$now" 2>&1) || {
    echo "TOURNAMENT: capture evidence rejected for $cand: $pixels_out" >&2; return 2; }
  case "$pixels_out" in TASTE-PIXELS:\ VERIFIED*) ;; *) echo "TOURNAMENT: pixel verifier did not confirm $cand" >&2; return 2 ;; esac
  # Deterministic function/accessibility/provenance veto precedes taste.
  json_no_dupkeys "$gate_abs" || { echo "TOURNAMENT: hard-gate not clean JSON for $cand" >&2; return 2; }
  man_sha=$(sha256_file "$manifest_abs")
  jq -e --arg cand "$cand" --arg man "$man_sha" '
    (keys|sort)==["accessibility","candidate_id","capture_manifest_sha256","overall","product_specificity","schema_version","state_coverage","task_results"]
    and .schema_version=="taste-hard-gate/v1"
    and .candidate_id==$cand
    and .capture_manifest_sha256==$man
    and .overall=="PASS"
    and (.task_results|type=="array" and length>0 and all(.[]; .status=="pass"))
    and (.accessibility|type=="array" and length>0 and all(.[]; .status=="pass"))
    and (.state_coverage|type=="array" and length>0 and all(.[]; .status=="pass"))
    and (.product_specificity|type=="object" and .status=="pass")' "$gate_abs" >/dev/null 2>&1 || {
      echo "TOURNAMENT: hard-gate veto failed for $cand" >&2; return 2; }
  digest=$(sha256_text "$(jq -r '[.captures[].decoded_pixel_sha256]|sort|join("\n")' "$manifest_abs")")
  printf '%s\n' "$digest"
}

# check_all_candidates EVID TOURNAMENT NOW -> writes "<id> <digest>" lines to a
# tmp file whose path it prints; rejects cross-candidate-identical evidence.
check_all_candidates() {
  local evid="$1" tj="$2" now="$3" base out cid rr mr gr digest
  base=$(jq -r '.base_revision' "$tj")
  out=$(mktemp "${TMPDIR:-/tmp}/tourn-cand.XXXXXX") || return 2
  while IFS=$'\t' read -r cid rr mr gr; do
    digest=$(verify_candidate "$evid" "$cid" "$rr" "$mr" "$gr" "$base" "$now") || { rm -f "$out"; return 2; }
    printf '%s\t%s\n' "$cid" "$digest" >> "$out"
  done < <(jq -r '.candidates | sort_by(.index)[] | [.candidate_id,.capture_root,.capture_manifest,.hard_gate] | @tsv' "$tj")
  # Cross-candidate identical rendered evidence is a divergence failure.
  if [ "$(awk -F'\t' '{print $2}' "$out" | LC_ALL=C sort | uniq -d | head -n1)" != "" ]; then
    rm -f "$out"; echo "TOURNAMENT: cross-candidate-identical rendered evidence" >&2; return 2
  fi
  printf '%s\n' "$out"
}

# --- match aggregation: escrow-bound, blind, quorum, strict majority ---------
# Prints the winning candidate id for the pair. Any invalid group, escrow
# mismatch, judge reuse/aliasing, quorum gap, or non-strict-majority fails.
aggregate_match() {
  local escrow_abs="$1" min="$2" pair="$3" cand_a="$4" cand_b="$5"; shift 5
  [ "$1" = "--" ] || return 2; shift
  local escrow_sha reveal_keys group_abs pw_abs cal_abs out winner_stim judges_file groups=0 votes_a=0 votes_b=0 tmpwin
  json_no_dupkeys "$escrow_abs" || { echo "TOURNAMENT: escrow not clean JSON ($pair)" >&2; return 2; }
  jq -e --arg pair "$pair" --arg a "$cand_a" --arg b "$cand_b" '
    (keys|sort)==["pair","reveal","schema_version"]
    and .schema_version=="taste-tournament-escrow/v1"
    and .pair==$pair
    and (.reveal|type=="object" and length==2 and (keys|all(test("^stim-[a-f0-9]{12}$")))
         and ([.[]]|sort)==([$a,$b]|sort) and ([.[]]|unique|length)==2)' "$escrow_abs" >/dev/null 2>&1 || {
      echo "TOURNAMENT: escrow does not reveal exactly the pair candidates ($pair)" >&2; return 2; }
  escrow_sha=$(sha256_file "$escrow_abs")
  reveal_keys=$(jq -r '.reveal|keys|sort|join(",")' "$escrow_abs")
  judges_file=$(mktemp "${TMPDIR:-/tmp}/tourn-judges.XXXXXX") || return 2
  tmpwin=$(mktemp "${TMPDIR:-/tmp}/tourn-win.XXXXXX") || { rm -f "$judges_file"; return 2; }
  while [ $# -ge 3 ]; do
    group_abs="$1"; pw_abs="$2"; cal_abs="$3"; shift 3
    json_no_dupkeys "$group_abs" || { echo "TOURNAMENT: group not clean JSON ($pair)" >&2; rm -f "$judges_file" "$tmpwin"; return 2; }
    # Group must be sealed against THIS escrow and THESE two stimuli.
    [ "$(jq -r '.candidate_ids_escrow_sha256' "$group_abs")" = "$escrow_sha" ] || { echo "TOURNAMENT: group escrow mismatch ($pair)" >&2; rm -f "$judges_file" "$tmpwin"; return 2; }
    [ "$(jq -r '.candidate_ids|sort|join(",")' "$group_abs")" = "$reveal_keys" ] || { echo "TOURNAMENT: group stimuli mismatch ($pair)" >&2; rm -f "$judges_file" "$tmpwin"; return 2; }
    out=$(mktemp "${TMPDIR:-/tmp}/tourn-ballot.XXXXXX") || { rm -f "$judges_file" "$tmpwin"; return 2; }
    # Compose the frozen ballot validator (eligibility, isolation, A/B mirror,
    # leakage, injection, discussion). Any rejection kills the whole match.
    if ! "$BALLOT" validate "$group_abs" "$pw_abs" "$cal_abs" "$out" >/dev/null 2>&1; then
      echo "TOURNAMENT: ballot group invalid ($pair)" >&2; rm -f "$judges_file" "$tmpwin" "$out"; return 2
    fi
    winner_stim=$(jq -r '.winner' "$out"); rm -f "$out"
    # Independence: each of a match's exposures is a DISTINCT judge (aliases count once).
    jq -r '.exposures[].judge_id' "$group_abs" >> "$judges_file"
    printf '%s\n' "$winner_stim" >> "$tmpwin"
    groups=$((groups + 1))
  done
  if [ "$(LC_ALL=C sort "$judges_file" | uniq -d | head -n1)" != "" ]; then
    echo "TOURNAMENT: reused/aliased judge across match groups ($pair)" >&2; rm -f "$judges_file" "$tmpwin"; return 2
  fi
  rm -f "$judges_file"
  [ "$groups" -ge "$min" ] || { echo "TOURNAMENT: quorum failure ($pair): $groups < $min groups" >&2; rm -f "$tmpwin"; return 2; }
  # Map each group's blind winner stim to its candidate via the sealed escrow.
  local stim cand
  while IFS= read -r stim; do
    cand=$(jq -r --arg s "$stim" '.reveal[$s]//""' "$escrow_abs")
    [ -n "$cand" ] || { echo "TOURNAMENT: unmapped winner stimulus ($pair)" >&2; rm -f "$tmpwin"; return 2; }
    if [ "$cand" = "$cand_a" ]; then votes_a=$((votes_a + 1)); else votes_b=$((votes_b + 1)); fi
  done < "$tmpwin"
  rm -f "$tmpwin"
  # Strict majority (> half). A tie yields no winner.
  if [ "$votes_a" -gt "$votes_b" ] && [ "$votes_a" -gt $((groups / 2)) ]; then printf '%s\n' "$cand_a"
  elif [ "$votes_b" -gt "$votes_a" ] && [ "$votes_b" -gt $((groups / 2)) ]; then printf '%s\n' "$cand_b"
  else echo "TOURNAMENT: no strict majority ($pair): $votes_a/$votes_b" >&2; return 2; fi
}

# aggregate a match declared inside a tournament JSON's matches[] entry.
aggregate_match_from_tj() {
  local evid="$1" tj="$2" pair="$3" min="$4" cand_a="$5" cand_b="$6" escrow_rel escrow_abs
  local -a args
  escrow_rel=$(jq -r --arg p "$pair" '.matches[]|select(.pair==$p)|.escrow' "$tj")
  escrow_abs=$(safe_rel "$evid" "$escrow_rel" file) || { echo "TOURNAMENT: unsafe escrow ($pair)" >&2; return 2; }
  args=()
  local g pw cal ga pa ca
  while IFS=$'\t' read -r g pw cal; do
    ga=$(safe_rel "$evid" "$g" file) || { echo "TOURNAMENT: unsafe group path ($pair)" >&2; return 2; }
    pa=$(safe_rel "$evid" "$pw" dir) || { echo "TOURNAMENT: unsafe pointwise dir ($pair)" >&2; return 2; }
    ca=$(safe_rel "$evid" "$cal" file) || { echo "TOURNAMENT: unsafe calibration ($pair)" >&2; return 2; }
    args+=("$ga" "$pa" "$ca")
  done < <(jq -r --arg p "$pair" '.matches[]|select(.pair==$p)|.groups[]|[.group,.pointwise_dir,.calibration]|@tsv' "$tj")
  aggregate_match "$escrow_abs" "$min" "$pair" "$cand_a" "$cand_b" -- "${args[@]}"
}

# Reject reuse of any group or pointwise ballot id across the whole tournament.
no_ballot_reuse() {
  local evid="$1" tj="$2" gfile pfile pair g pw cal ga pa
  gfile=$(mktemp "${TMPDIR:-/tmp}/tourn-g.XXXXXX"); pfile=$(mktemp "${TMPDIR:-/tmp}/tourn-p.XXXXXX")
  while IFS=$'\t' read -r pair g pw cal; do
    ga=$(safe_rel "$evid" "$g" file) || { rm -f "$gfile" "$pfile"; return 2; }
    pa=$(safe_rel "$evid" "$pw" dir) || { rm -f "$gfile" "$pfile"; return 2; }
    jq -r '.mirror_group_id' "$ga" >> "$gfile"
    jq -r '.pointwise_ballot_ids[]' "$ga" >> "$pfile"
  done < <(jq -r '.matches[] as $m | $m.groups[] | [$m.pair,.group,.pointwise_dir,.calibration] | @tsv' "$tj")
  local dup=""
  dup=$(LC_ALL=C sort "$gfile" | uniq -d | head -n1)
  [ -z "$dup" ] || { echo "TOURNAMENT: reused mirror group id '$dup'" >&2; rm -f "$gfile" "$pfile"; return 2; }
  dup=$(LC_ALL=C sort "$pfile" | uniq -d | head -n1)
  [ -z "$dup" ] || { echo "TOURNAMENT: reused pointwise ballot id '$dup'" >&2; rm -f "$gfile" "$pfile"; return 2; }
  rm -f "$gfile" "$pfile"
}

# --- tournament shape + lock binding -----------------------------------------
validate_tournament_shape() {   # FILE MODE(initial|repair) MIN
  local tj="$1" mode="$2" min="$3" ncand npair
  json_no_dupkeys "$tj" || return 1
  case "$mode" in initial) ncand=3; npair=3 ;; repair) ncand=2; npair=1 ;; *) return 1 ;; esac
  jq -e --argjson nc "$ncand" --argjson np "$npair" --argjson min "$min" '
    (keys|sort)==["base_revision","candidates","design_lock_sha256","goal_sha256","matches","run_id","schema_version"]
    and .schema_version=="taste-tournament/v1"
    and (.run_id|type=="string" and length>0)
    and (.base_revision|type=="string" and test("^[0-9a-f]{40,64}$"))
    and ([.goal_sha256,.design_lock_sha256]|all(.[]; type=="string" and test("^[0-9a-f]{64}$")))
    and (.candidates|type=="array" and length==$nc
         and ([.[].index]|sort)==( [range(1;$nc+1)] )
         and all(.[]; (keys|sort)==["candidate_id","capture_manifest","capture_root","hard_gate","index"]
                  and (.candidate_id|test("^cand-[a-z0-9-]{3,}$"))
                  and (.index|type=="number")
                  and ([.capture_manifest,.capture_root,.hard_gate]|all(.[]; type=="string" and length>0))))
    and ((.candidates|map(.candidate_id)|unique|length)==$nc)
    and (.matches|type=="array" and length==$np
         and all(.[]; (keys|sort)==["escrow","groups","pair"]
                  and (.pair|test("^[0-9]+-[0-9]+$"))
                  and (.escrow|type=="string" and length>0)
                  and (.groups|type=="array" and length>=$min
                       and all(.[]; (keys|sort)==["calibration","group","pointwise_dir"]
                                and all(.[]; type=="string" and length>0)))))' "$tj" >/dev/null 2>&1
}

# Bind the caller JSON to the frozen durable lock. The caller may only POINT at
# evidence; identity and policy come from the lock, never the caller.
bind_to_lock() {   # STATE_JSON TOURNAMENT_FILE
  local st="$1" tj="$2"
  [ "$(jq -r '.run_id' "$tj")" = "$(pj "$st" .run_id)" ] || { echo "TOURNAMENT: run_id != frozen lock" >&2; return 2; }
  [ "$(jq -r '.base_revision' "$tj")" = "$(pj "$st" .base_revision)" ] || { echo "TOURNAMENT: base_revision != frozen lock" >&2; return 2; }
  [ "$(jq -r '.goal_sha256' "$tj")" = "$(pj "$st" .goal_sha256)" ] || { echo "TOURNAMENT: goal digest != frozen lock" >&2; return 2; }
  [ "$(jq -r '.design_lock_sha256' "$tj")" = "$(pj "$st" .design_lock_sha256)" ] || { echo "TOURNAMENT: design-lock digest != frozen lock (lock drift)" >&2; return 2; }
}

# --- subcommands -------------------------------------------------------------
cmd_lock() {
  local dir="$1" lockf="$2" now="$3"
  valid_now "$now" || die INVALID_NOW
  mkdir -p "$dir"
  [ -f "$dir/events.log" ] && [ -s "$dir/events.log" ] && die ALREADY_LOCKED
  json_no_dupkeys "$lockf" || die LOCK_NOT_CLEAN_JSON
  jq -e '
    (keys|sort)==["base_revision","brief_sha256","candidate_ids","capture_plan_sha256","design_lock_sha256","direction_sha256","goal_sha256","locked_at","min_groups","pairs","reference_sha256","repair_budget","run_id","schema_version","scope_id"]
    and .schema_version=="taste-tournament-lock/v1"
    and (.run_id|type=="string" and length>0) and (.scope_id|type=="string" and length>0)
    and (.base_revision|test("^[0-9a-f]{40,64}$"))
    and ([.goal_sha256,.brief_sha256,.reference_sha256,.direction_sha256,.design_lock_sha256,.capture_plan_sha256]|all(.[]; test("^[0-9a-f]{64}$")))
    and (.candidate_ids|type=="array" and length==3 and ((unique|length)==3) and all(.[]; test("^cand-[a-z0-9-]{3,}$")))
    and (.pairs==["1-2","1-3","2-3"])
    and (.min_groups|type=="number" and .>=5)
    and (.repair_budget|type=="number" and .==2)' "$lockf" >/dev/null 2>&1 || die LOCK_SHAPE
  local payload
  payload=$(jq -c '{run_id,scope_id,base_revision,goal_sha256,brief_sha256,reference_sha256,direction_sha256,design_lock_sha256,capture_plan_sha256,candidate_ids,pairs,min_groups,repair_budget,lock_sha256:"'"$(sha256_file "$lockf")"'"}' "$lockf")
  append_event "$dir" TOURNAMENT_LOCKED "$payload" "$now"
  echo "TOURNAMENT: LOCKED run=$(jq -r .run_id "$lockf")"
}

cmd_run() {
  local dir="$1" tj="$2" now="$3" st candfile evid min cids c1 c2 c3 w12 w13 w23 winner digest
  valid_now "$now" || die INVALID_NOW
  chain_ok "$dir" || die CORRUPT_LOG
  st=$(project "$dir") || die CORRUPT_LOG
  [ "$(pj "$st" .phase)" = LOCKED ] || die "run requires a freshly locked tournament (phase=$(pj "$st" .phase))"
  [ "$(pj "$st" .champion_generation)" = "-1" ] || die "run cannot re-open an existing champion"
  min=$(pj "$st" .min_groups)
  validate_tournament_shape "$tj" initial "$min" || die TOURNAMENT_SHAPE
  bind_to_lock "$st" "$tj" || return 2
  cids=$(printf '%s' "$st" | jq -c '.candidate_ids')
  [ "$(jq -c '.candidates|sort_by(.index)|map(.candidate_id)' "$tj")" = "$cids" ] || die "candidate ids/order != frozen lock"
  evid=$(cd "$(dirname "$tj")" && pwd -P)
  no_ballot_reuse "$evid" "$tj" || return 2
  candfile=$(check_all_candidates "$evid" "$tj" "$now") || return 2
  c1=$(jq -r '.candidates|sort_by(.index)[0].candidate_id' "$tj")
  c2=$(jq -r '.candidates|sort_by(.index)[1].candidate_id' "$tj")
  c3=$(jq -r '.candidates|sort_by(.index)[2].candidate_id' "$tj")
  # Complete blind round-robin: all three pairs must resolve.
  w12=$(aggregate_match_from_tj "$evid" "$tj" "1-2" "$min" "$c1" "$c2") || { rm -f "$candfile"; die "match 1-2 undecided -> REPLAN"; }
  w13=$(aggregate_match_from_tj "$evid" "$tj" "1-3" "$min" "$c1" "$c3") || { rm -f "$candfile"; die "match 1-3 undecided -> REPLAN"; }
  w23=$(aggregate_match_from_tj "$evid" "$tj" "2-3" "$min" "$c2" "$c3") || { rm -f "$candfile"; die "match 2-3 undecided -> REPLAN"; }
  # Unique Condorcet winner: wins BOTH its matches. No score/LOC/margin tie-break.
  winner=""
  if [ "$w12" = "$c1" ] && [ "$w13" = "$c1" ]; then winner="$c1"
  elif [ "$w12" = "$c2" ] && [ "$w23" = "$c2" ]; then winner="$c2"
  elif [ "$w13" = "$c3" ] && [ "$w23" = "$c3" ]; then winner="$c3"; fi
  [ -n "$winner" ] || { rm -f "$candfile"; die "no unique Condorcet winner (cycle/tie) -> REPLAN"; }
  # Persist immutable candidate + match + selection receipts, then advance champ.
  local id dg
  while IFS=$'\t' read -r id dg; do
    write_receipt "$dir" "candidate-$id" "$(jq -n --arg id "$id" --arg dg "$dg" --arg run "$(pj "$st" .run_id)" '{schema_version:"taste-tournament-candidate/v1",candidate_id:$id,run_id:$run,decoded_pixels_digest:$dg}')"
    append_event "$dir" CANDIDATE_VERIFIED "$(jq -n --arg id "$id" --arg dg "$dg" '{candidate_id:$id,decoded_pixels_digest:$dg}')" "$now"
  done < "$candfile"
  rm -f "$candfile"
  local pair wpair
  for pair in 1-2 1-3 2-3; do
    case "$pair" in 1-2) wpair="$w12" ;; 1-3) wpair="$w13" ;; 2-3) wpair="$w23" ;; esac
    write_receipt "$dir" "match-$pair" "$(jq -n --arg p "$pair" --arg w "$wpair" '{schema_version:"taste-tournament-match/v1",pair:$p,winner_candidate_id:$w}')"
    append_event "$dir" MATCH_AGGREGATED "$(jq -n --arg p "$pair" --arg w "$wpair" '{pair:$p,winner_candidate_id:$w}')" "$now"
  done
  append_event "$dir" SELECTION "$(jq -n --arg w "$winner" '{mode:"initial",verdict:"SELECTED",label:"SELECTED_NOT_CERTIFIED",winner_candidate_id:$w}')" "$now"
  write_receipt "$dir" "selection-gen-0" "$(jq -n --arg w "$winner" --arg run "$(pj "$st" .run_id)" '{schema_version:"taste-tournament-selection/v1",mode:"initial",verdict:"SELECTED",label:"SELECTED_NOT_CERTIFIED",winner_candidate_id:$w,run_id:$run}')"
  advance_champion "$dir" "$winner" "-1" "$(pj "$st" .run_id)" "$now" || die CHAMPION_CAS_FAILED
  write_receipt "$dir" "champion-gen-0" "$(cat "$dir/champion.json")"
  echo "TOURNAMENT: SELECTED_NOT_CERTIFIED winner=$winner label=SELECTED_NOT_CERTIFIED"
}

cmd_reserve() {
  local dir="$1" rj="$2" now="$3" st attempt incumbent dlock reservations budget
  valid_now "$now" || die INVALID_NOW
  chain_ok "$dir" || die CORRUPT_LOG
  st=$(project "$dir") || die CORRUPT_LOG
  [ "$(pj "$st" .phase)" = SELECTED ] || die "repair reservation requires a standing champion (phase=$(pj "$st" .phase))"
  json_no_dupkeys "$rj" || die REPAIR_SHAPE
  jq -e '(keys|sort)==["attempt","design_lock_sha256","failed_states","incumbent_candidate_id","started_before_work"]
    and .schema_version==null
    and (.attempt|type=="number")
    and (.incumbent_candidate_id|test("^cand-[a-z0-9-]{3,}$"))
    and (.design_lock_sha256|test("^[0-9a-f]{64}$"))
    and (.failed_states|type=="array" and length>0 and all(.[]; type=="string" and length>0))
    and (.started_before_work==true)' "$rj" >/dev/null 2>&1 || die REPAIR_SHAPE
  attempt=$(jq -r '.attempt' "$rj")
  incumbent=$(jq -r '.incumbent_candidate_id' "$rj")
  dlock=$(jq -r '.design_lock_sha256' "$rj")
  reservations=$(pj "$st" .repairs_reserved)
  budget=$(pj "$st" .repair_budget)
  # Reserve the token BEFORE any work. Contiguous attempts only; a restart replays
  # the durable ledger and cannot reset the budget.
  [ "$attempt" = "$((reservations + 1))" ] || die "repair attempt gap (expected $((reservations + 1)), got $attempt)"
  [ "$attempt" -le "$budget" ] || die "repair budget exhausted (attempt $attempt > $budget) -> REPLAN"
  [ "$incumbent" = "$(pj "$st" .incumbent)" ] || die "stale repair parent (names $incumbent, incumbent is $(pj "$st" .incumbent)) -> REPLAN"
  [ "$dlock" = "$(pj "$st" .design_lock_sha256)" ] || die "repair design-lock drift -> REPLAN"
  append_event "$dir" REPAIR_RESERVED "$(jq -n --argjson a "$attempt" --arg i "$incumbent" --arg d "$dlock" '{attempt:$a,incumbent_candidate_id:$i,design_lock_sha256:$d}')" "$now"
  echo "TOURNAMENT: REPAIR_RESERVED attempt=$attempt incumbent=$incumbent"
}

cmd_repair() {
  local dir="$1" tj="$2" now="$3" st min evid c_inc c_chal w incumbent inc_digest chal_digest inc_stored gen attempt budget verdict
  valid_now "$now" || die INVALID_NOW
  chain_ok "$dir" || die CORRUPT_LOG
  st=$(project "$dir") || die CORRUPT_LOG
  [ "$(pj "$st" .phase)" = REPAIR_RESERVED ] || die "repair requires a reserved, unresolved token (phase=$(pj "$st" .phase))"
  incumbent=$(pj "$st" .incumbent)
  min=$(pj "$st" .min_groups)
  attempt=$(pj "$st" .pending_repair_attempt); budget=$(pj "$st" .repair_budget)
  validate_tournament_shape "$tj" repair "$min" || die TOURNAMENT_SHAPE
  bind_to_lock "$st" "$tj" || return 2
  # index 1 is the incumbent, index 2 the repaired challenger.
  c_inc=$(jq -r '.candidates|sort_by(.index)[0].candidate_id' "$tj")
  c_chal=$(jq -r '.candidates|sort_by(.index)[1].candidate_id' "$tj")
  [ "$c_inc" = "$incumbent" ] || die "repair index 1 must be the standing incumbent"
  [ "$(jq -r '.matches[0].pair' "$tj")" = "1-2" ] || die "repair match must be pair 1-2 (incumbent vs challenger)"
  # Oscillation: a challenger equal to any prior champion cannot re-enter -> REPLAN.
  if printf '%s' "$st" | jq -e --arg c "$c_chal" '.seen_champions|index($c)!=null' >/dev/null 2>&1; then
    append_event "$dir" REPAIR_RESULT "$(jq -n --arg i "$incumbent" --arg c "$c_chal" '{verdict:"REPLAN",promoted:false,reason:"oscillation",incumbent_candidate_id:$i,challenger_candidate_id:$c}')" "$now"
    die "oscillation: challenger $c_chal was a prior champion -> REPLAN (incumbent retained)"
  fi
  evid=$(cd "$(dirname "$tj")" && pwd -P)
  no_ballot_reuse "$evid" "$tj" || return 2
  # Verify the two candidates individually: for a repair, identical incumbent and
  # challenger pixels is the "unchanged" case handled below, not a generic
  # cross-candidate divergence failure.
  local base rr mr gr
  base=$(pj "$st" .base_revision)
  IFS=$'\t' read -r rr mr gr < <(jq -r '.candidates|sort_by(.index)[0]|[.capture_root,.capture_manifest,.hard_gate]|@tsv' "$tj")
  inc_digest=$(verify_candidate "$evid" "$c_inc" "$rr" "$mr" "$gr" "$base" "$now") || return 2
  IFS=$'\t' read -r rr mr gr < <(jq -r '.candidates|sort_by(.index)[1]|[.capture_root,.capture_manifest,.hard_gate]|@tsv' "$tj")
  chal_digest=$(verify_candidate "$evid" "$c_chal" "$rr" "$mr" "$gr" "$base" "$now") || return 2
  # The supplied incumbent evidence must match the STORED champion render — a
  # caller cannot swap the incumbent to fake a divergence.
  inc_stored=$(jq -rs --arg c "$c_inc" '[.[]|select(.kind=="CANDIDATE_VERIFIED" and .payload.candidate_id==$c)]|last.payload.decoded_pixels_digest // ""' "$dir/events.log")
  [ "$inc_digest" = "$inc_stored" ] || die "repair incumbent evidence != standing champion render"
  gen=$(pj "$st" .champion_generation)
  # New pixels are mandatory: an unchanged (non-material) repair is terminal REPLAN.
  if [ "$chal_digest" = "$inc_stored" ]; then
    append_event "$dir" REPAIR_RESULT "$(jq -n --arg i "$incumbent" --arg c "$c_chal" '{verdict:"REPLAN",promoted:false,reason:"unchanged evidence",incumbent_candidate_id:$i,challenger_candidate_id:$c}')" "$now"
    die "unchanged repair evidence -> REPLAN (incumbent retained)"
  fi
  if ! w=$(aggregate_match_from_tj "$evid" "$tj" "1-2" "$min" "$c_inc" "$c_chal"); then
    # Undecided/quorum failure counts as a non-promotion.
    if [ "$attempt" -ge "$budget" ]; then verdict=REPLAN; else verdict=RETAINED; fi
    append_event "$dir" REPAIR_RESULT "$(jq -n --arg v "$verdict" --arg i "$incumbent" --arg c "$c_chal" '{verdict:$v,promoted:false,reason:"match undecided",incumbent_candidate_id:$i,challenger_candidate_id:$c}')" "$now"
    die "repair match undecided -> $verdict (incumbent retained)"
  fi
  if [ "$w" != "$c_chal" ]; then
    # Material loss: the incumbent stays champion; nothing mutates the registry.
    # Retry is allowed while budget remains; a loss on the last attempt is a
    # plateau -> terminal REPLAN.
    if [ "$attempt" -ge "$budget" ]; then verdict=REPLAN; else verdict=RETAINED; fi
    append_event "$dir" REPAIR_RESULT "$(jq -n --arg v "$verdict" --arg i "$incumbent" --arg c "$c_chal" '{verdict:$v,promoted:false,reason:"challenger did not beat incumbent",incumbent_candidate_id:$i,challenger_candidate_id:$c}')" "$now"
    write_receipt "$dir" "repair-result-attempt-$attempt" "$(jq -n --arg v "$verdict" --arg i "$incumbent" --arg c "$c_chal" '{schema_version:"taste-tournament-repair-result/v1",verdict:$v,promoted:false,incumbent_candidate_id:$i,challenger_candidate_id:$c}')"
    die "repair rejected: incumbent $incumbent retained ($verdict)"
  fi
  # Fail closed BEFORE writing promotion events if the registry moved under us.
  [ "$(jq -r '.generation' "$dir/champion.json" 2>/dev/null || echo -1)" = "$gen" ] || die "champion CAS stale (registry moved under us)"
  write_receipt "$dir" "candidate-$c_chal" "$(jq -n --arg id "$c_chal" --arg dg "$chal_digest" --arg run "$(pj "$st" .run_id)" '{schema_version:"taste-tournament-candidate/v1",candidate_id:$id,run_id:$run,decoded_pixels_digest:$dg}')"
  append_event "$dir" CANDIDATE_VERIFIED "$(jq -n --arg id "$c_chal" --arg dg "$chal_digest" '{candidate_id:$id,decoded_pixels_digest:$dg}')" "$now"
  append_event "$dir" MATCH_AGGREGATED "$(jq -n --arg w "$c_chal" '{pair:"1-2",winner_candidate_id:$w}')" "$now"
  append_event "$dir" SELECTION "$(jq -n --arg w "$c_chal" '{mode:"repair",verdict:"SELECTED",label:"SELECTED_NOT_CERTIFIED",winner_candidate_id:$w}')" "$now"
  write_receipt "$dir" "repair-result-attempt-$attempt" "$(jq -n --arg i "$incumbent" --arg c "$c_chal" '{schema_version:"taste-tournament-repair-result/v1",verdict:"SELECTED",promoted:true,incumbent_candidate_id:$i,challenger_candidate_id:$c}')"
  advance_champion "$dir" "$c_chal" "$gen" "$(pj "$st" .run_id)" "$now" || die CHAMPION_CAS_FAILED
  write_receipt "$dir" "champion-gen-$((gen + 1))" "$(cat "$dir/champion.json")"
  echo "TOURNAMENT: SELECTED_NOT_CERTIFIED winner=$c_chal generation=$((gen + 1))"
}

cmd_select() {
  local root="$1" tj="$2" receipt="$3" now="$4" dir st phase rc=0 out verdict winner
  dir="$root/.polylane/tournament"
  [ -f "$dir/events.log" ] || die "no frozen tournament at $dir (run 'lock' first)"
  st=$(project "$dir") || die CORRUPT_LOG
  phase=$(pj "$st" .phase)
  case "$phase" in
    LOCKED)          out=$(cmd_run "$dir" "$tj" "$now" 2>&1) || rc=$? ;;
    REPAIR_RESERVED) out=$(cmd_repair "$dir" "$tj" "$now" 2>&1) || rc=$? ;;
    *) die "select cannot dispatch from phase $phase" ;;
  esac
  printf '%s\n' "$out" >&2
  if [ "$rc" = 0 ]; then verdict=SELECTED; winner=$(printf '%s' "$out" | sed -n 's/.*winner=\([^ ]*\).*/\1/p'); else verdict=REPLAN; winner=""; fi
  mkdir -p "$(dirname "$receipt")"
  jq -n --arg v "$verdict" --arg w "$winner" --arg run "$(pj "$st" .run_id)" --arg now "$now" \
    '{schema_version:"taste-tournament-decision/v1",verdict:$v,label:"SELECTED_NOT_CERTIFIED",winner_candidate_id:$w,run_id:$run,decided_at:$now}' > "$receipt"
  return "$rc"
}

cmd_champion() {
  local dir="$1"
  [ -f "$dir/champion.json" ] || die "no champion yet"
  # The champion registry must agree with the event-projected generation.
  local st gen
  st=$(project "$dir") || die CORRUPT_LOG
  gen=$(jq -r '.generation' "$dir/champion.json")
  [ "$gen" = "$(pj "$st" .champion_generation)" ] || die "champion registry generation diverges from event log"
  cat "$dir/champion.json"
}

cmd_check_captures() {   # TOURNAMENT_JSON NOW  (capture-seam only, no ballots)
  local tj="$1" now="$2" evid candfile
  valid_now "$now" || die INVALID_NOW
  validate_tournament_shape "$tj" initial 5 >/dev/null 2>&1 || jq -e '.candidates|type=="array"' "$tj" >/dev/null 2>&1 || die TOURNAMENT_SHAPE
  evid=$(cd "$(dirname "$tj")" && pwd -P)
  candfile=$(check_all_candidates "$evid" "$tj" "$now") || return 2
  echo "TOURNAMENT: CAPTURES-OK candidates=$(wc -l < "$candfile" | tr -d ' ')"
  rm -f "$candfile"
}

main() {
  case "${1:-}" in
    lock)        shift; [ $# -eq 3 ] || { usage; return 2; }; cmd_lock "$@" ;;
    run)         shift; [ $# -eq 3 ] || { usage; return 2; }; cmd_run "$@" ;;
    reserve)     shift; [ $# -eq 3 ] || { usage; return 2; }; cmd_reserve "$@" ;;
    repair)      shift; [ $# -eq 3 ] || { usage; return 2; }; cmd_repair "$@" ;;
    select)      shift; [ $# -eq 4 ] || { usage; return 2; }; cmd_select "$@" ;;
    champion)    shift; [ $# -eq 1 ] || { usage; return 2; }; cmd_champion "$@" ;;
    state)       shift; [ $# -eq 1 ] || { usage; return 2; }; project "$1" ;;
    verify-log)  shift; [ $# -eq 1 ] || { usage; return 2; }; chain_ok "$1" && echo "TOURNAMENT: LOG-OK" || die LOG_CORRUPT ;;
    aggregate-match) shift; aggregate_match "$@" ;;
    check-captures)  shift; [ $# -eq 2 ] || { usage; return 2; }; cmd_check_captures "$@" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
