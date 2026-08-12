#!/usr/bin/env bash
#
# polylane-taste-memory.sh — durable, project-scoped, evidence-only taste memory.
#
# Learns ONLY from whole closed HUMAN_CERTIFIED taste studies in which both compared
# candidates passed every hard gate (function/accessibility/capture/context/provenance).
# It stores compact, typed, NON-EXECUTABLE design-pattern contrasts and returns bounded,
# comparable, advisory-only lessons. It never authorizes promotion, never executes a
# stored string, and never substitutes for capture or certification.
#
# Verbs:
#   init      LEDGER                         create an append-only hash-chained JSONL ledger
#   record    LEDGER PROMOTION_RECEIPT       admit one closed HUMAN_CERTIFIED study (idempotent)
#   recommend LEDGER CONTEXT_JSON [LIMIT]    advisory, read-only, deterministic JSON lessons
#   audit     LEDGER                         replay + verify chain / provenance / safe content
#
# Data model:
#   * The ledger lives under a caller-selected docs/polylane/ path (project-rooted).
#   * Each admitted brief becomes ONE observation row: a winning vs losing PATTERN ATOM
#     (an opaque hash of visual-system facets — never candidate identity), tagged with
#     audience/domain/task, bound to the study's recomputed evidence digest.
#   * Rows are hash-chained: row_sha256 = sha256(canonical(row without row_sha256)),
#     previous_row_sha256 links to the prior line (genesis = "GENESIS").
#
# Trust rules:
#   * Every declared closure/certificate/aggregate/reference/direction/candidate/
#     capture/pixel/hard-gate/threat hash is RECOMPUTED and must match.
#   * Winner/loser/pass are DERIVED from bound aggregates; caller labels are never trusted.
#   * Machine-calibrated / machine-evaluated studies are diagnostics only — never admitted.
#   * Every stored/returned string is untrusted DATA; it is validated to a safe alphabet
#     and never reaches eval, a shell, or a glob.
#
# Pure Bash 3.2 + jq + a SHA-256 command. No network, no provider coupling.

set -euo pipefail

TM_SCHEMA_LEDGER="taste-memory-ledger/v1"
TM_SCHEMA_ROW="taste-memory-row/v1"
TM_SCHEMA_ADVICE="taste-memory-advice/v1"
TM_SCHEMA_CLOSURE="taste-study-closure/v1"
TM_GENESIS="GENESIS"

# Recommendation floors (frozen policy; see docs/verify-taste-memory.md).
TM_MIN_BRIEFS=12          # independent in-scope briefs before any favored/disfavored lesson
TM_MIN_STUDIES=4          # distinct studies
TM_MIN_TASKS=4            # distinct tasks
TM_MAX_STUDY_SHARE=34     # no single study may exceed 34% of in-scope observations
TM_MIN_SAMESIGN=70        # >=70% same-sign observations for a directional lesson
TM_PATTERN_MIN_N=4        # a lesson pattern must appear in >=4 briefs
TM_PATTERN_MIN_STUDIES=2  # ...spanning >=2 studies (caps single-source reuse)
TM_DEFAULT_LIMIT=5        # default bound on emitted lessons
TM_MAX_LIMIT=8            # hard cap on emitted lessons
TM_MAX_BYTES=8192         # hard cap on advice payload bytes

# Study-admission floors (a HUMAN_CERTIFIED corpus study; see PROTOCOL §8).
TM_STUDY_MIN_BRIEFS=10
TM_STUDY_MAX_BRIEFS=200
TM_STUDY_MIN_GROUPS=5     # eligible mirrored groups per brief
TM_STUDY_MIN_BRIEF_WINS=7

command -v jq >/dev/null 2>&1 || { echo "TASTE-MEMORY: jq required" >&2; exit 3; }

die() { printf 'TASTE-MEMORY: %s\n' "$1" >&2; exit "${2:-2}"; }

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else die "no sha-256 command" 3; fi
}
sha256_text() { printf '%s' "$1" | sha256_stdin; }

# hash_stream : read newline-separated bodies on stdin; print one lowercase sha256 per
# body, in order, using a SINGLE hasher invocation. A per-object fork is ~30ms on macOS,
# so batching ~100 objects into one `shasum file...` is what keeps record/audit usable.
hash_stream() {
  local d i=0 line
  d=$(mktemp -d "${TMPDIR:-/tmp}/tm-hs.XXXXXX") || return 1
  while IFS= read -r line; do
    printf '%s' "$line" > "$d/$(printf '%08d' "$i")"
    i=$((i+1))
  done
  if [ "$i" -eq 0 ]; then rmdir "$d" 2>/dev/null; return 0; fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$d"/* | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$d"/* | awk '{print $1}'
  else
    rm -rf "$d"; die "no sha-256 command" 3
  fi
  rm -rf "$d"
}

# canon FILTER FILE... : canonical (recursively key-sorted, compact, no trailing
# newline) serialization — the only form ever hashed, so a re-read reproduces it.
canon() { jq -S -c -j "$@"; }
canon_hash_expr() { canon "$1" "$2" | sha256_stdin; }        # hash of jq FILTER over FILE

# safe_id VALUE : a bounded, non-executable token. Rejects anything that could be a
# shell metacharacter, path, glob, newline, or instruction fragment.
safe_id() {
  case "$1" in
    "" ) return 1 ;;
    *[!A-Za-z0-9._-]* ) return 1 ;;
    [A-Za-z0-9]* ) return 0 ;;
    * ) return 1 ;;
  esac
}
# safe_sha VALUE : lowercase 64-hex digest.
safe_sha() { case "$1" in *[!0-9a-f]*|"" ) return 1 ;; esac; [ "${#1}" -eq 64 ]; }

# safe_rel_regular_file ROOT PATH : PATH is a repo-relative regular file with no
# absolute prefix, no traversal, and no symlink component (defends against escape).
safe_rel_regular_file() {
  local root="$1" path="$2" part prefix old_ifs
  case "$path" in ""|/*|*'//'*) return 1 ;; esac
  prefix="$root"; old_ifs=$IFS; IFS='/'
  for part in $path; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
    prefix="$prefix/$part"
    [ ! -L "$prefix" ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
  [ -f "$root/$path" ] && [ ! -L "$root/$path" ]
}

# ledger_path_ok PATH : the ledger must be a project-rooted docs/polylane/ path with no
# traversal and no symlink component along its existing prefix (durable, not escapable).
ledger_path_ok() {
  local path="$1" part prefix="" old_ifs saw_docs=0 rooted=0 has_dp=0 prev=""
  case "$path" in ""|*'//'*) return 1 ;; esac
  case "$path" in /*) rooted=1 ;; esac
  old_ifs=$IFS; IFS='/'
  for part in $path; do
    if [ -z "$part" ]; then continue; fi
    case "$part" in ..) IFS=$old_ifs; return 1 ;; esac
    [ "$prev" = "docs" ] && [ "$part" = "polylane" ] && has_dp=1
    prev="$part"
    if [ "$rooted" = 1 ] && [ -z "$prefix" ]; then prefix="/$part"; else prefix="$prefix/$part"; fi
    [ ! -L "$prefix" ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
  [ "$has_dp" = 1 ] || return 1        # must live under a docs/polylane/ segment
  # the target itself, if it exists, must be a regular (non-symlink) file
  [ ! -e "$path" ] || { [ -f "$path" ] && [ ! -L "$path" ]; }
  saw_docs=$saw_docs   # (kept for readability; unused)
}

# json_file_ok FILE : regular, valid JSON, no duplicate object-key paths anywhere.
json_file_ok() {
  local file="$1" dups
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  dups=$(jq --stream -r 'select(length==2)|.[0]|map(tostring)|join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$dups" ]
}

# jsonl_ok FILE : append-only JSONL — regular non-symlink, trailing newline, and EVERY
# line individually valid JSON with no duplicate keys (a torn/partial line fails).
jsonl_ok() {
  local file="$1" line dups
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  [ -s "$file" ] || return 1
  [ -z "$(tail -c1 "$file")" ] || return 1
  while IFS= read -r line; do
    [ -n "$line" ] || return 1
    printf '%s' "$line" | jq -e . >/dev/null 2>&1 || return 1
    dups=$(printf '%s' "$line" | jq --stream -rc 'select(length==2)|.[0]' 2>/dev/null | LC_ALL=C sort | uniq -d)
    [ -z "$dups" ] || return 1
  done < "$file"
  return 0
}

now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo '1970-01-01T00:00:00Z'; }

# with_lock LEDGER FN ARGS... : run FN under an atomic mkdir lock with stale-lock-safe
# reacquisition (mirrors polylane-memory.sh: only the process that re-wins the dir breaks).
with_lock() {
  local ledger="$1"; shift
  local fn="$1"; shift
  local lock="$ledger.lock" tries=0 rc
  while ! mkdir "$lock" 2>/dev/null; do
    tries=$((tries+1))
    if [ "$tries" -ge 50 ]; then
      rmdir "$lock" 2>/dev/null || true
      if mkdir "$lock" 2>/dev/null; then break; else tries=0; fi
    fi
    sleep 0.1 2>/dev/null || sleep 1
  done
  set +e
  "$fn" "$@"; rc=$?
  set -e
  rmdir "$lock" 2>/dev/null || true
  return "$rc"
}

# ---------------------------------------------------------------------------
# init
# ---------------------------------------------------------------------------
cmd_init() {
  local ledger="${1:-}"
  [ -n "$ledger" ] || die "usage: init LEDGER"
  ledger_path_ok "$ledger" || die "ledger path must be a safe project docs/polylane/ path (no traversal/symlink)"
  if [ -e "$ledger" ]; then
    [ -f "$ledger" ] && [ ! -L "$ledger" ] || die "ledger exists but is not a regular file"
    echo "ledger exists: $ledger"; return 0
  fi
  mkdir -p "$(dirname "$ledger")" 2>/dev/null || die "cannot create ledger directory"
  local created row hash
  created=$(now_utc)
  row=$(jq -n -S -c --arg s "$TM_SCHEMA_LEDGER" --arg c "$created" --arg p "$TM_GENESIS" \
        '{schema:$s,genesis:true,created_at:$c,previous_row_sha256:$p}')
  hash=$(printf '%s' "$row" | sha256_stdin)
  printf '%s\n' "$(jq -n -S -c --argjson r "$row" --arg h "$hash" '$r + {row_sha256:$h}')" > "$ledger"
  echo "initialized $ledger"
}

# ---------------------------------------------------------------------------
# record — admit one closed HUMAN_CERTIFIED study
# ---------------------------------------------------------------------------

# _cmp_hash_streams BODIES DECLARED LABEL : BODIES is newline-separated canonical
# (key-sorted, compact) sub-objects; DECLARED is the matching declared digests in the
# SAME order. Recompute each body's sha and compare. Any length/value mismatch is tamper.
# Hashing in bash keeps this to a handful of jq spawns instead of one per digest.
_cmp_hash_streams() {
  local bodies="$1" declared="$2" label="$3" got
  got=$(printf '%s\n' "$bodies" | hash_stream)
  [ "$got" = "$declared" ] || die "hash-mismatch:$label"
}

# verify_declared_hashes RECEIPT : recompute every declared closure/certificate/
# aggregate/reference/direction/candidate/capture/pixel/hard-gate/threat digest and
# fail closed on any mismatch. `jq -S` emits each value key-sorted-compact — identical
# bytes to the generator's canonical form — so bash only has to sha and compare.
verify_declared_hashes() {
  local r="$1" bodies declared
  # leaves + study components, streamed in a fixed order.
  bodies=$(jq -c -S '
    .reference, .direction, .threat_scan, .certificate,
    (.briefs[].aggregate),
    (.briefs[].candidates[].capture),
    (.briefs[].candidates[].pixel),
    (.briefs[].candidates[].hard_gate)' "$r")
  declared=$(jq -r '
    .hashes.reference_sha256, .hashes.direction_sha256, .hashes.threat_sha256, .hashes.certificate_sha256,
    (.briefs[].aggregate_sha256),
    (.briefs[].candidates[].hashes.capture_sha256),
    (.briefs[].candidates[].hashes.pixel_sha256),
    (.briefs[].candidates[].hashes.hard_gate_sha256)' "$r")
  _cmp_hash_streams "$bodies" "$declared" "leaf"
  # candidate composites bind identity-free facets to their evidence digests.
  bodies=$(jq -c -S '.briefs[].candidates[] | {facets:.facets, capture_sha256:.hashes.capture_sha256, pixel_sha256:.hashes.pixel_sha256, hard_gate_sha256:.hashes.hard_gate_sha256}' "$r")
  declared=$(jq -r '.briefs[].candidates[].hashes.candidate_sha256' "$r")
  _cmp_hash_streams "$bodies" "$declared" "candidate"
  # closure binds EVERYTHING (all bodies + all declared sub-hashes).
  bodies=$(canon 'del(.hashes.closure_sha256)' "$r"); declared=$(jq -r '.hashes.closure_sha256' "$r")
  [ "$(printf '%s' "$bodies" | sha256_stdin)" = "$declared" ] || die "hash-mismatch:closure"
}

cmd_record() {
  local ledger="${1:-}" receipt="${2:-}"
  [ -n "$ledger" ] && [ -n "$receipt" ] || die "usage: record LEDGER PROMOTION_RECEIPT"
  case "$receipt" in *..*) die "receipt path must not contain traversal" ;; esac
  ledger_path_ok "$ledger" || die "ledger path invalid"
  [ -f "$ledger" ] && [ ! -L "$ledger" ] || die "no ledger at $ledger (run 'init' first)"
  json_file_ok "$receipt" || die "receipt is missing, a symlink, malformed JSON, or has duplicate keys"

  # ---- structural shape ----
  jq -e --arg s "$TM_SCHEMA_CLOSURE" '.schema_version==$s' "$receipt" >/dev/null 2>&1 \
    || die "receipt is not a $TM_SCHEMA_CLOSURE"
  jq -e '(keys - ["schema_version","study_id","run_id","closed_at","claim_label","human_certified","reference","direction","threat_scan","briefs","certificate","hashes"])|length==0' "$receipt" >/dev/null \
    || die "receipt has unknown top-level keys"

  # ---- machine outcomes are diagnostics, never training ----
  jq -e '.claim_label=="HUMAN_CERTIFIED" and .human_certified==true' "$receipt" >/dev/null 2>&1 \
    || die "only a whole HUMAN_CERTIFIED study is admissible (machine-calibrated/evaluated outcomes are diagnostics)"

  # ---- recompute every declared hash (tamper defence) ----
  verify_declared_hashes "$receipt"

  local run_id study_id closure_sha
  run_id=$(jq -r '.run_id' "$receipt"); safe_id "$run_id" || die "unsafe run_id"
  study_id=$(jq -r '.study_id' "$receipt"); safe_id "$study_id" || die "unsafe study_id"
  closure_sha=$(jq -r '.hashes.closure_sha256' "$receipt")

  # ---- threat scan must be clean ----
  jq -e '.threat_scan|(.leakage=="none" and .injection=="none" and .ocr_dom_scan=="pass")' "$receipt" >/dev/null 2>&1 \
    || die "study threat scan is not clean (leakage/injection/ocr-dom)"

  # ---- facets are stored data: fixed typed keys, safe non-executable values only ----
  jq -e '
    def safe: type=="string" and test("^[A-Za-z0-9._-]+$");
    def okfacets: (keys|sort)==["density_band","layout_family","navigation_archetype","palette_family","primary_information_unit","shape_language","type_pair_class"]
                  and all(.[]; safe);
    all(.briefs[].candidates[]; .facets|okfacets)' "$receipt" >/dev/null \
    || die "candidate facets must use the fixed typed key set with safe non-executable values"

  # ---- study-scale certificate floors, recomputed from the bound briefs ----
  local nb
  nb=$(jq '.briefs|length' "$receipt")
  [ "$nb" -ge "$TM_STUDY_MIN_BRIEFS" ] || die "study has <$TM_STUDY_MIN_BRIEFS briefs (not HUMAN_CERTIFIED)"
  [ "$nb" -le "$TM_STUDY_MAX_BRIEFS" ] || die "study exceeds bounded brief count"
  jq -e --argjson n "$nb" '.certificate.briefs==$n' "$receipt" >/dev/null || die "certificate brief count mismatch"
  jq -e '.certificate.accessibility_regressions==0' "$receipt" >/dev/null || die "study reports accessibility regressions"

  # ---- per-brief eligibility, validated in ONE pass (nothing caller-labelled is trusted) ----
  # Every brief: exactly two candidates, both passing all five hard gates, integer group
  # counts that close, >=5 eligible groups, no tie, a strict winner, and safe tag tokens.
  jq -e --argjson g "$TM_STUDY_MIN_GROUPS" '
    def safe: type=="string" and test("^[A-Za-z0-9._-]+$");
    def okg($k): (.candidates[0].hard_gate[$k]=="pass") and (.candidates[1].hard_gate[$k]=="pass");
    all(.briefs[];
      (.candidates|length)==2
      and okg("function") and okg("accessibility") and okg("capture") and okg("context") and okg("provenance")
      and (.aggregate|(.candidate_group_wins|length)==2
           and ((.candidate_group_wins[0]|type)=="number") and ((.candidate_group_wins[1]|type)=="number")
           and ((.ties|type)=="number") and ((.resolved_groups|type)=="number")
           and (.ties==0) and (.resolved_groups>=$g)
           and ((.candidate_group_wins[0]+.candidate_group_wins[1]+.ties)==.resolved_groups)
           and (.candidate_group_wins[0]!=.candidate_group_wins[1]))
      and (.brief_ref|safe) and (.product_signature|safe)
      and (.tags.audience|safe) and (.tags.domain|safe) and (.tags.task|safe))' "$receipt" >/dev/null \
    || die "study has an ineligible brief (failed hard gate, tie, non-strict winner, group floor, or unsafe tag)"

  # ---- study-scale majority + conservative bound, recomputed from the bound aggregates ----
  local pooled_wins pooled_res brief_wins pref_ok
  IFS='	' read -r pooled_wins pooled_res brief_wins <<EOF
$(jq -r '[.briefs[]|{w:([.aggregate.candidate_group_wins[0],.aggregate.candidate_group_wins[1]]|max),r:.aggregate.resolved_groups}] | "\(map(.w)|add)\t\(map(.r)|add)\t\(length)"' "$receipt")
EOF
  [ "$brief_wins" -ge "$TM_STUDY_MIN_BRIEF_WINS" ] || die "study has <$TM_STUDY_MIN_BRIEF_WINS strict brief winners"
  pref_ok=$(jq -n -r --argjson w "$pooled_wins" --argjson n "$pooled_res" '
    (1.959964) as $z | ($z*$z) as $z2 | ($w/$n) as $p
    | (1 + $z2/$n) as $d | (($p + $z2/(2*$n))/$d) as $c
    | ($z*((($p*(1-$p) + $z2/(4*$n))/$n)|sqrt)/$d) as $m
    | if ($p >= 0.70 and ($c-$m) > 0.50) then "ok" else "no" end')
  [ "$pref_ok" = "ok" ] || die "study pooled preference/Wilson bound does not meet the certification floor"

  # ---- build one observation row per brief; contrast DERIVED from group wins ----
  # Facets are canonicalised in jq (sortk|tojson == jq -S -c) so their sha atoms are
  # comparable across studies; the atom hashes facets, never candidate identity. Atoms
  # and event ids are hashed in batch; all rows are emitted by a single jq pass.
  local rows_ndjson recs wsrc_lines lsrc_lines ekey_lines wpats lpats eids combined
  recs=$(jq -r '
    def sortk: if type=="object" then to_entries|sort_by(.key)|map({key,value:(.value|sortk)})|from_entries
               elif type=="array" then map(sortk) else . end;
    .briefs[]
    | (if .aggregate.candidate_group_wins[0] > .aggregate.candidate_group_wins[1] then 0 else 1 end) as $w
    | (1-$w) as $l
    | (.aggregate.candidate_group_wins[$w]) as $ww
    | (.aggregate.resolved_groups) as $res
    | [ .brief_ref, .tags.audience, .tags.domain, .tags.task, .product_signature,
        (.candidates[$w].facets|sortk|tojson), (.candidates[$l].facets|sortk|tojson),
        (($ww*1000/$res|floor)/1000|tostring) ] | @tsv' "$receipt")
  wsrc_lines=$(printf '%s\n' "$recs" | awk -F'\t' 'NF{print $6}')
  lsrc_lines=$(printf '%s\n' "$recs" | awk -F'\t' 'NF{print $7}')
  ekey_lines=$(printf '%s\n' "$recs" | awk -F'\t' -v r="$run_id" 'NF{printf "%s\037%s\n", r, $1}')
  wpats=$(printf '%s\n' "$wsrc_lines" | hash_stream | awk '{print "pat-" substr($1,1,24)}')
  lpats=$(printf '%s\n' "$lsrc_lines" | hash_stream | awk '{print "pat-" substr($1,1,24)}')
  eids=$(printf '%s\n' "$ekey_lines" | hash_stream | awk '{print "evt-" substr($1,1,24)}')
  # zip recs + atoms + event ids (columns 9,10,11) and emit every row from one jq pass.
  combined=$(paste -d'	' <(printf '%s\n' "$recs") <(printf '%s\n' "$wpats") <(printf '%s\n' "$lpats") <(printf '%s\n' "$eids"))
  rows_ndjson=$(printf '%s\n' "$combined" | jq -R -c \
      --arg schema "$TM_SCHEMA_ROW" --arg study "$study_id" --arg run "$run_id" \
      --arg ev "$receipt" --arg evh "$closure_sha" '
      select(length>0) | split("\t")
      | if (.[8]==.[9]) then error("winner and loser share a pattern") else . end
      | {schema:$schema, event_id:.[10], study_id:$study, run_id:$run, brief_ref:.[0],
         tags:{audience:.[1],domain:.[2],task:.[3]}, product_signature:.[4],
         winning_pattern:.[8], losing_pattern:.[9],
         winning_facets:(.[5]|fromjson), losing_facets:(.[6]|fromjson),
         evidence_path:$ev, evidence_sha256:$evh, hard_gate:"PASS",
         confidence:(.[7]|tonumber), provenance:"provider-independent"}') \
    || die "row assembly failed (winner==loser or malformed brief)"
  rows_ndjson="$rows_ndjson
"

  # ---- atomic, idempotent append under lock ----
  TM_ROWS="$rows_ndjson" TM_RUN="$run_id" TM_CLOSURE="$closure_sha" \
    with_lock "$ledger" _append_rows "$ledger" || return $?
}

# _append_rows LEDGER : consumes TM_ROWS (ndjson of row bodies), TM_RUN, TM_CLOSURE.
# Idempotent: a re-record of the same study (same run + same closure digest) is a no-op;
# a run_id reused with different content, or a partial overlap, is rejected.
_append_rows() {
  local ledger="$1" existing new_eids overlap tmp prev line rowbody body h
  jsonl_ok "$ledger" || { echo "TASTE-MEMORY: ledger corrupt/torn" >&2; return 2; }
  # this study's event ids
  new_eids=$(printf '%s' "$TM_ROWS" | jq -r 'select(.!=null)|.event_id' 2>/dev/null)
  # how many of them already exist, and whether they carry the same evidence digest
  existing=$(jq -n -c '[inputs]' "$ledger" 2>/dev/null || echo '[]')
  overlap=$(printf '%s\n' "$new_eids" | jq -R 'select(length>0)' | jq -s --argjson L "$existing" --arg c "$TM_CLOSURE" '
    ($L|map(select(.event_id!=null))) as $rows
    | . as $ids
    | {present: [ $ids[] | . as $id | ($rows[]|select(.event_id==$id)) ] | length,
       total: ($ids|length),
       samehash: ([ $ids[] | . as $id | ($rows[]|select(.event_id==$id and .evidence_sha256==$c)) ]|length)}')
  local present total samehash
  present=$(printf '%s' "$overlap" | jq '.present')
  total=$(printf '%s' "$overlap" | jq '.total')
  samehash=$(printf '%s' "$overlap" | jq '.samehash')
  # run_id reuse check
  local run_present
  run_present=$(jq -r --arg run "$TM_RUN" 'select(.run_id==$run)|.run_id' "$ledger" 2>/dev/null | head -n1)
  if [ "$present" -gt 0 ]; then
    if [ "$present" -eq "$total" ] && [ "$samehash" -eq "$total" ]; then
      echo "idempotent: study already recorded ($total observations)"; return 0
    fi
    echo "TASTE-MEMORY: duplicate run/study receipt with differing content (refusing to double-count)" >&2
    return 2
  fi
  if [ -n "$run_present" ]; then
    echo "TASTE-MEMORY: run_id already present with different briefs (duplicate run receipt)" >&2
    return 2
  fi

  # chain from the last line's row_sha256
  prev=$(tail -n1 "$ledger" | jq -r '.row_sha256')
  safe_sha "$prev" 2>/dev/null || { echo "TASTE-MEMORY: ledger tail has no valid row hash" >&2; return 2; }
  tmp="$ledger.tmp.$$"
  cp "$ledger" "$tmp" || { rm -f "$tmp"; return 2; }
  # append each row, hash-chained; final links captured for report
  local appended=0
  while IFS= read -r rowbody; do
    [ -n "$rowbody" ] || continue
    body=$(jq -S -c --arg p "$prev" '. + {previous_row_sha256:$p}' <<<"$rowbody")
    h=$(printf '%s' "$body" | sha256_stdin)
    printf '%s\n' "$(jq -S -c --arg h "$h" '. + {row_sha256:$h}' <<<"$body")" >> "$tmp"
    prev="$h"; appended=$((appended+1))
  done <<EOF
$TM_ROWS
EOF
  mv "$tmp" "$ledger" || { rm -f "$tmp"; return 2; }
  echo "recorded: $appended observations"
}

# ---------------------------------------------------------------------------
# recommend — advisory, read-only, deterministic
# ---------------------------------------------------------------------------
cmd_recommend() {
  local ledger="${1:-}" ctx="${2:-}" limit="${3:-$TM_DEFAULT_LIMIT}"
  [ -n "$ledger" ] && [ -n "$ctx" ] || die "usage: recommend LEDGER CONTEXT_JSON [LIMIT]"
  ledger_path_ok "$ledger" || die "ledger path invalid"
  [ -f "$ledger" ] && [ ! -L "$ledger" ] || die "no ledger at $ledger"
  case "$limit" in ''|*[!0-9]*) limit="$TM_DEFAULT_LIMIT" ;; esac
  [ "$limit" -ge 1 ] || limit="$TM_DEFAULT_LIMIT"
  [ "$limit" -le "$TM_MAX_LIMIT" ] || limit="$TM_MAX_LIMIT"

  # CONTEXT_JSON may be an inline object or a safe file path.
  local ctx_json
  if [ -f "$ctx" ] && [ ! -L "$ctx" ]; then ctx_json=$(cat "$ctx"); else ctx_json="$ctx"; fi
  printf '%s' "$ctx_json" | jq -e 'type=="object"' >/dev/null 2>&1 || die "CONTEXT_JSON is not a JSON object"
  local aud dom task
  aud=$(printf '%s' "$ctx_json" | jq -r '.audience // ""')
  dom=$(printf '%s' "$ctx_json" | jq -r '.domain // ""')
  task=$(printf '%s' "$ctx_json" | jq -r '.task // ""')
  { [ -z "$aud" ] || safe_id "$aud"; } && { [ -z "$dom" ] || safe_id "$dom"; } && { [ -z "$task" ] || safe_id "$task"; } \
    || die "unsafe context token"

  # light integrity guard: a broken chain must not yield advice.
  if ! _chain_ok "$ledger"; then
    _emit_status "$aud" "$dom" "$task" "$limit" "unavailable"; return 0
  fi

  # all observation rows (skip genesis)
  local rows
  rows=$(jq -c 'select(.schema=="'"$TM_SCHEMA_ROW"'")' "$ledger" 2>/dev/null | jq -s '.')

  # deterministic advice, computed entirely in jq (rows are data, never executed).
  printf '%s' "$rows" | jq -S \
    --arg schema "$TM_SCHEMA_ADVICE" \
    --arg aud "$aud" --arg dom "$dom" --arg task "$task" \
    --argjson limit "$limit" \
    --argjson minB "$TM_MIN_BRIEFS" --argjson minS "$TM_MIN_STUDIES" --argjson minT "$TM_MIN_TASKS" \
    --argjson maxShare "$TM_MAX_STUDY_SHARE" --argjson sameSign "$TM_MIN_SAMESIGN" \
    --argjson patN "$TM_PATTERN_MIN_N" --argjson patS "$TM_PATTERN_MIN_STUDIES" \
    --argjson maxBytes "$TM_MAX_BYTES" '
    def wilson(w; n):
      (1.959964) as $z | ($z*$z) as $z2 | (w/n) as $p
      | (1 + $z2/n) as $d | (($p + $z2/(2*n))/$d) as $c
      | ($z*((($p*(1-$p) + $z2/(4*n))/n)|sqrt)/$d) as $m
      | ($c - $m);
    # Scope is by domain (required when supplied) refined by audience (when supplied).
    # Task is NOT a scope filter: task DIVERSITY is instead a generalization guard, so a
    # lesson cannot be an artifact of one narrow task.
    ( map(select(($dom=="" or .tags.domain==$dom) and ($aud=="" or .tags.audience==$aud))) ) as $scope
    | ($scope|length) as $nObs
    | ([$scope[].study_id]|unique|length) as $nStudies
    | ([$scope[].tags.task]|unique|length) as $nTasks
    | ([$scope[]|{s:.study_id,b:.brief_ref}]|unique|length) as $nBriefs
    # per-study share of observations (as integer percent), max over studies
    | ( if $nObs==0 then 0
        else ([ $scope|group_by(.study_id)[] | ((length*100)/$nObs)|floor ]|max) end ) as $topShare
    | { schema:$schema,
        context:{audience:$aud,domain:$dom,task:$task},
        reserved_arms:{memory_blind:true,wildcard:true},
        directions_budget:{evidence_guided_max:($limit),memory_blind_min:1,wildcard_min:1},
        bounded:{max_lessons:$limit,max_bytes:$maxBytes},
        safe_to_promote:false } as $base
    | if $nObs==0 then
        ($base + {status:"out-of-scope", none:true, lessons:[], conflicted:[]})
      elif ($nBriefs < $minB or $nStudies < $minS or $nTasks < $minT or $topShare > $maxShare) then
        ($base + {status:"insufficient", none:true, lessons:[], conflicted:[],
                  coverage:{briefs:$nBriefs,studies:$nStudies,tasks:$nTasks,top_study_share_pct:$topShare}})
      else
        # tally each pattern atom: winner=+1, loser=-1, tracking studies and briefs.
        ( [ $scope[] | {pat:.winning_pattern, sign:"win", study:.study_id, brief:(.study_id+"|"+.brief_ref)} ]
          + [ $scope[] | {pat:.losing_pattern, sign:"lose", study:.study_id, brief:(.study_id+"|"+.brief_ref)} ] ) as $obs
        | ( [ $obs|group_by(.pat)[]
              | { pattern:.[0].pat,
                  wins:  ([.[]|select(.sign=="win")]|length),
                  losses:([.[]|select(.sign=="lose")]|length),
                  n:     length,
                  studies: ([.[].study]|unique|length),
                  briefs:  ([.[].brief]|unique|length) } ]
          ) as $pats
        # a pattern must be well-supported to yield ANY directional signal.
        | ( [ $pats[] | select(.n >= $patN and .studies >= $patS) ] ) as $eligible
        | ( [ $eligible[]
              | .n as $n | .wins as $w | .losses as $l
              | (if $w>=$l then $w else $l end) as $maj
              | ((($maj*100)/$n)|floor) as $ss
              | (if $w>=$l then wilson($w; $n) else wilson($l; $n) end) as $wl
              | select($ss >= $sameSign and $wl > 0.50)
              | { pattern:.pattern,
                  direction:(if $w>=$l then "favored" else "disfavored" end),
                  observations:.n, studies:.studies, briefs:.briefs,
                  same_sign:(($ss)/100), wilson_lcb:(($wl*1000|floor)/1000) } ]
            | sort_by(.pattern) | .[0:$limit]
          ) as $lessons
        # well-supported but genuinely mixed patterns are contradictions, never lessons.
        | ( [ $eligible[]
              | .n as $n | .wins as $w | .losses as $l
              | ((((if $w>=$l then $w else $l end)*100)/$n)|floor) as $ss
              | select($ss < $sameSign)
              | {pattern:.pattern, wins:$w, losses:$l, same_sign:(($ss)/100)} ]
            | sort_by(.pattern) | .[0:$limit]
          ) as $conflicts
        | if ($lessons|length)>0 then
            ($base + {status:"ok", none:false, lessons:$lessons, conflicted:$conflicts,
                      coverage:{briefs:$nBriefs,studies:$nStudies,tasks:$nTasks,top_study_share_pct:$topShare}})
          elif ($conflicts|length)>0 then
            ($base + {status:"conflicted", none:true, lessons:[], conflicted:$conflicts,
                      coverage:{briefs:$nBriefs,studies:$nStudies,tasks:$nTasks,top_study_share_pct:$topShare}})
          else
            ($base + {status:"none", none:true, lessons:[], conflicted:[],
                      coverage:{briefs:$nBriefs,studies:$nStudies,tasks:$nTasks,top_study_share_pct:$topShare}})
          end
      end
    | . as $out
    # hard byte bound: if we somehow exceed it, degrade to a bounded summary.
    | ($out|tojson|length) as $len
    | if $len > $maxBytes then ($base + {status:"bounded-overflow", none:true, lessons:[], bytes:$len}) else $out end
  '
}

# _emit_status : minimal deterministic advice envelope for a non-computable state.
_emit_status() {
  local aud="$1" dom="$2" task="$3" limit="$4" status="$5"
  jq -n -S --arg schema "$TM_SCHEMA_ADVICE" --arg aud "$aud" --arg dom "$dom" --arg task "$task" \
    --argjson limit "$limit" --argjson maxBytes "$TM_MAX_BYTES" --arg status "$status" '
    {schema:$schema, context:{audience:$aud,domain:$dom,task:$task}, status:$status, none:true, lessons:[],
     reserved_arms:{memory_blind:true,wildcard:true},
     directions_budget:{evidence_guided_max:$limit,memory_blind_min:1,wildcard_min:1},
     bounded:{max_lessons:$limit,max_bytes:$maxBytes}, safe_to_promote:false}'
}

# ---------------------------------------------------------------------------
# audit — replay + verify
# ---------------------------------------------------------------------------

# _chain_ok LEDGER : true iff every line parses, the genesis is first, each row hash
# recomputes, and each previous_row_sha256 links the prior line.
_chain_ok() {
  local ledger="$1"
  awk 'END{exit (NR==0)}' "$ledger" || return 1
  # trailing newline required (a torn final line has none)
  [ -n "$(tail -c1 "$ledger")" ] && return 1 || :
  local prev="$TM_GENESIS" first=1 line body want got pv
  while IFS= read -r line; do
    [ -n "$line" ] || return 1
    printf '%s' "$line" | jq -e . >/dev/null 2>&1 || return 1
    want=$(printf '%s' "$line" | jq -r '.row_sha256 // ""')
    safe_sha "$want" || return 1
    body=$(printf '%s' "$line" | jq -S -c 'del(.row_sha256)')
    got=$(printf '%s' "$body" | sha256_stdin)
    [ "$want" = "$got" ] || return 1
    pv=$(printf '%s' "$line" | jq -r '.previous_row_sha256 // ""')
    if [ "$first" = 1 ]; then
      printf '%s' "$line" | jq -e '.genesis==true' >/dev/null 2>&1 || return 1
      [ "$pv" = "$TM_GENESIS" ] || return 1
      first=0
    else
      [ "$pv" = "$prev" ] || return 1
    fi
    prev="$want"
  done < "$ledger"
  return 0
}

cmd_audit() {
  local ledger="${1:-}"
  [ -n "$ledger" ] || die "usage: audit LEDGER"
  ledger_path_ok "$ledger" || die "ledger path invalid"
  [ -f "$ledger" ] && [ ! -L "$ledger" ] || die "no ledger at $ledger"
  jsonl_ok "$ledger" 2>/dev/null || die "audit: ledger is not clean JSONL (malformed/duplicate keys/partial line)"
  _chain_ok "$ledger" || die "audit: broken hash chain, invalid predecessor, or tampered/partial row"

  # semantic replay over observation rows.
  local rows
  rows=$(jq -c 'select(.schema=="'"$TM_SCHEMA_ROW"'")' "$ledger" 2>/dev/null | jq -s '.')

  # duplicate event ids
  printf '%s' "$rows" | jq -e '([.[].event_id]|length) == ([.[].event_id]|unique|length)' >/dev/null \
    || die "audit: duplicate event id"
  # duplicate run receipt: same run_id carrying two different evidence digests
  printf '%s' "$rows" | jq -e '
    (group_by(.run_id) | all(.[]; ([.[].evidence_sha256]|unique|length)==1))' >/dev/null \
    || die "audit: duplicate run receipt with conflicting evidence digest"
  # impossible promotion: hard_gate must be PASS and winner != loser
  printf '%s' "$rows" | jq -e 'all(.[]; .hard_gate=="PASS")' >/dev/null \
    || die "audit: impossible promotion (a stored row is not a passing outcome)"
  printf '%s' "$rows" | jq -e 'all(.[]; .winning_pattern != .losing_pattern)' >/dev/null \
    || die "audit: impossible promotion (winner equals loser)"
  # unsafe stored content: every id/tag/pattern/provenance token must be a safe atom;
  # evidence digest must be a 64-hex sha; nothing executable may be stored.
  printf '%s' "$rows" | jq -e '
    def safe: type=="string" and (test("^[A-Za-z0-9._-]+$"));
    def safepat: type=="string" and (test("^pat-[0-9a-f]{24}$"));
    def okfacets: type=="object"
                  and (keys|sort)==["density_band","layout_family","navigation_archetype","palette_family","primary_information_unit","shape_language","type_pair_class"]
                  and all(.[]; safe);
    all(.[];
      (.event_id|safe) and (.study_id|safe) and (.run_id|safe) and (.brief_ref|safe)
      and (.tags.audience|safe) and (.tags.domain|safe) and (.tags.task|safe)
      and (.product_signature|safe)
      and (.winning_pattern|safepat) and (.losing_pattern|safepat)
      and (.winning_facets|okfacets) and (.losing_facets|okfacets)
      and (.provenance=="provider-independent")
      and (.evidence_path|type=="string" and test("^/?[A-Za-z0-9][A-Za-z0-9._/-]*$") and ((test("\\.\\."))|not))
      and (.evidence_sha256|type=="string" and test("^[0-9a-f]{64}$")))' >/dev/null \
    || die "audit: unsafe or malformed stored content"

  local n
  n=$(printf '%s' "$rows" | jq 'length')
  echo "audit OK: $n observations, chain intact, provenance clean"
}

# ---------------------------------------------------------------------------
main() {
  local cmd="${1:-}"
  [ -n "$cmd" ] || die "usage: polylane-taste-memory.sh {init|record|recommend|audit} LEDGER ..." 2
  shift
  case "$cmd" in
    init)      cmd_init "$@" ;;
    record)    cmd_record "$@" ;;
    recommend) cmd_recommend "$@" ;;
    audit)     cmd_audit "$@" ;;
    *) die "unknown command '$cmd' (want init|record|recommend|audit)" 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
