#!/usr/bin/env bash
# polylane-taste-ratings.sh — strict normalizer for the released
# Miniukovich–Figl rating text schemas.
#
# Raw schema (tab-separated, header row, documented in the dataset article):
#   stimulusId  isDuplicate  rating  isTraining  dimension  sessionId
#   rating is an integer on the native [-3,3] scale; dimension is one of
#   TYP, AVG, EXMPL, AE, US, TRU. Aggregate schema: stimulusId plus exactly
#   those six dimension columns holding the source's own filtered,
#   within-participant-standardized per-page means.
#
# Columns are bound by header name, never by position. Unknown, missing, or
# duplicated columns, malformed rows, out-of-range or non-integer ratings,
# and unparsable aggregate values are terminal schema drift. `NA` ratings and
# NA/NaN/Inf aggregates are explicit exclusions. The released raw schema does
# not flag rater compliance, so without a caller-supplied compliant-session
# list the tool reports raw-session support and declares the aggregate
# recomputation not computable; with a list it recomputes the documented
# pipeline (duplicate-mean, within-session standardization with sample sd
# pooled across dimensions, mean over compliant sessions) and enforces the
# frozen 0.01 tolerance. Weak support (<5 raters), unproven joins, and
# out-of-tolerance aggregates exclude the stimulus explicitly; an empty
# record set is a failure, never a pass.
#
# Bash 3.2 safe: no associative arrays, no process substitution.
set -euo pipefail

MIN_SUPPORT=5
TOLERANCE=0.01
SCHEMA_VERSION="taste-ratings-normalize/v1"

usage() {
  cat <<'USAGE'
usage:
  polylane-taste-ratings.sh normalize --raw RAW.txt --agg AGG.txt \
      --domain DOMAIN --source-id ID --out OUT.json \
      [--compliant-sessions FILE] [--receipt RECEIPT.json]
USAGE
}

fail() { echo "TASTE-RATINGS-INVALID: $*" >&2; exit 1; }

require_tools() {
  command -v jq >/dev/null 2>&1 || fail "jq is required"
  command -v awk >/dev/null 2>&1 || fail "awk is required"
  command -v shasum >/dev/null 2>&1 || fail "shasum is required"
}

check_input() { # PATH LABEL
  [ -n "$1" ] || fail "$2 file is required"
  [ ! -L "$1" ] || fail "$2 file is a symlink: $1"
  [ -f "$1" ] || fail "$2 file is not a regular file: $1"
  [ -s "$1" ] || fail "$2 file is empty: $1"
}

check_token() { # VALUE LABEL
  case "$1" in
    "" | *[!A-Za-z0-9._-]* | [._-]*) fail "$2 must be a stable token: $1" ;;
  esac
}

# Parse and validate the raw ratings file. Emits into WORK:
#   sessvals.tsv  sess<TAB>stim<TAB>dim<TAB>dup-averaged-value
#   stims.txt     non-training stimulus ids
#   sessions.txt  distinct session ids
#   stats.tsv     rows<TAB>nonfinite<TAB>training
parse_raw() { # RAW WORK
  awk -v work="$2" '
    BEGIN { FS = "\t"; fatal = 0
      need = "stimulusId isDuplicate rating isTraining dimension sessionId"
      nneed = split(need, needa, " ")
      dims = "TYP AVG EXMPL AE US TRU"
      ndims = split(dims, dima, " ")
      for (i = 1; i <= ndims; i++) dimok[dima[i]] = 1
    }
    function die(msg) { print "TASTE-RATINGS-INVALID: " msg > "/dev/stderr"; fatal = 1; exit 1 }
    function token_ok(s) { return s ~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/ }
    function bool_ok(s) { return s == "TRUE" || s == "FALSE" || s == "true" || s == "false" }
    function is_true(s) { return s == "TRUE" || s == "true" }
    NR == 1 {
      sub(/\r$/, "")
      for (i = 1; i <= NF; i++) {
        ok = 0
        for (j = 1; j <= nneed; j++) if ($i == needa[j]) ok = 1
        if (!ok) die("unknown raw column: " $i)
        if ($i in col) die("duplicate raw column: " $i)
        col[$i] = i
      }
      for (j = 1; j <= nneed; j++)
        if (!(needa[j] in col)) die("raw header missing column: " needa[j])
      hdrn = NF
      next
    }
    {
      sub(/\r$/, "")
      if ($0 == "" || NF != hdrn) die("malformed raw row " NR)
      stim = $col["stimulusId"]; dup = $col["isDuplicate"]; r = $col["rating"]
      training = $col["isTraining"]; dim = $col["dimension"]; sess = $col["sessionId"]
      if (!token_ok(stim)) die("invalid stimulusId at row " NR ": " stim)
      if (!token_ok(sess)) die("invalid sessionId at row " NR ": " sess)
      if (!bool_ok(dup)) die("invalid isDuplicate at row " NR ": " dup)
      if (!bool_ok(training)) die("invalid isTraining at row " NR ": " training)
      if (!(dim in dimok)) die("unknown dimension at row " NR ": " dim)
      if (r != "NA") {
        if (r !~ /^-?[0-9]+$/) die("invalid rating at row " NR ": " r)
        if (r + 0 < -3 || r + 0 > 3) die("rating out of native [-3,3] range at row " NR ": " r)
      }
      rows++
      if (is_true(training)) { training_rows++; next }
      sessions[sess] = 1
      key = sess SUBSEP stim SUBSEP dim
      kcount[key]++
      if (kcount[key] > 2)
        die("more than two ratings for one session/stimulus/dimension: " sess " " stim " " dim)
      if (r == "NA") { nonfinite_rows++; next }
      stims[stim] = 1
      ksum[key] += r + 0; kn[key]++
    }
    END {
      if (fatal) exit 1
      for (key in ksum) {
        split(key, p, SUBSEP)
        printf "%s\t%s\t%s\t%.17g\n", p[1], p[2], p[3], ksum[key] / kn[key] > (work "/sessvals.tsv")
      }
      for (s in stims) print s > (work "/stims.txt")
      for (s in sessions) print s > (work "/sessions.txt")
      printf "%d\t%d\t%d\n", rows + 0, nonfinite_rows + 0, training_rows + 0 > (work "/stats.tsv")
    }
  ' "$1" || exit 1
  : >>"$2/sessvals.tsv"; : >>"$2/stims.txt"; : >>"$2/sessions.txt"
}

# Parse and validate the aggregate ratings file. Emits into WORK:
#   agg.tsv       stim<TAB>dim<TAB>native-value
#   nonfinite.tsv stimulus ids with any NA/NaN/Inf dimension value
#   aggstims.txt  every aggregate stimulus id
parse_agg() { # AGG WORK
  awk -v work="$2" '
    BEGIN { FS = "\t"; fatal = 0
      dims = "TYP AVG EXMPL AE US TRU"
      ndims = split(dims, dima, " ")
    }
    function die(msg) { print "TASTE-RATINGS-INVALID: " msg > "/dev/stderr"; fatal = 1; exit 1 }
    NR == 1 {
      sub(/\r$/, "")
      for (i = 1; i <= NF; i++) {
        ok = ($i == "stimulusId")
        for (j = 1; j <= ndims; j++) if ($i == dima[j]) ok = 1
        if (!ok) die("unknown aggregate column: " $i)
        if ($i in col) die("duplicate aggregate column: " $i)
        col[$i] = i
      }
      if (!("stimulusId" in col)) die("aggregate header missing column: stimulusId")
      for (j = 1; j <= ndims; j++)
        if (!(dima[j] in col)) die("aggregate header missing column: " dima[j])
      hdrn = NF
      next
    }
    {
      sub(/\r$/, "")
      if ($0 == "" || NF != hdrn) die("malformed aggregate row " NR)
      stim = $col["stimulusId"]
      if (stim !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) die("invalid aggregate stimulusId at row " NR ": " stim)
      if (stim in seen) die("duplicate aggregate stimulus: " stim)
      seen[stim] = 1
      print stim > (work "/aggstims.txt")
      bad = 0
      for (j = 1; j <= ndims; j++) {
        v = $col[dima[j]]
        if (v == "NA" || v == "NaN" || v == "Inf" || v == "-Inf") { bad = 1; continue }
        if (v !~ /^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$/)
          die("invalid aggregate value at row " NR " for " dima[j] ": " v)
        print stim "\t" dima[j] "\t" v > (work "/agg.tsv")
      }
      if (bad) print stim > (work "/nonfinite.tsv")
    }
    END { if (fatal) exit 1 }
  ' "$1" || exit 1
  : >>"$2/agg.tsv"; : >>"$2/nonfinite.tsv"; : >>"$2/aggstims.txt"
}

# Validate the caller-supplied compliant-session list against the raw file's
# observed sessions: every entry must be a known session, listed once.
check_sessions() { # SESSIONS_FILE WORK
  awk -v work="$2" '
    BEGIN { FS = "\t" }
    function die(msg) { print "TASTE-RATINGS-INVALID: " msg > "/dev/stderr"; exit 1 }
    FNR == NR { known[$1] = 1; next }
    {
      sub(/\r$/, "")
      if ($0 == "") next
      if ($0 !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) die("invalid compliant session id: " $0)
      if (!($0 in known)) die("unknown compliant session (not in raw file): " $0)
      if ($0 in listed) die("duplicate compliant session: " $0)
      listed[$0] = 1
    }
  ' "$2/sessions.txt" "$1" || exit 1
}

# Join support, optional compliant recomputation, and per-stimulus decisions.
# Emits records.jsonl / excluded.jsonl / counts.tsv into WORK.
join_and_decide() { # WORK COMPLIANT_FILE DOMAIN SOURCE_ID
  work=$1; compliant=$2; jd_domain=$3; jd_source_id=$4
  set -- "$work/sessvals.tsv" "$work/agg.tsv" "$work/nonfinite.tsv" \
         "$work/stims.txt" "$work/aggstims.txt"
  if [ -n "$compliant" ]; then set -- "$@" "$compliant"; fi
  awk -v work="$work" -v min_support="$MIN_SUPPORT" -v tol="$TOLERANCE" \
      -v compliant_mode="$([ -n "$compliant" ] && echo 1 || echo 0)" \
      -v domain="$jd_domain" -v source_id="$jd_source_id" '
    BEGIN { FS = "\t"; fatal = 0
      ndims = split("AE AVG EXMPL TRU TYP US", dima, " ")
    }
    function die(msg) { print "TASTE-RATINGS-INVALID: " msg > "/dev/stderr"; fatal = 1; exit 1 }
    function base(f) { n = split(f, parts, "/"); return parts[n] }
    base(FILENAME) == "sessvals.tsv" { sv_sess[++nsv] = $1; sv_stim[nsv] = $2; sv_dim[nsv] = $3; sv_val[nsv] = $4; next }
    base(FILENAME) == "agg.tsv"      { aggval[$1, $2] = $3; next }
    base(FILENAME) == "nonfinite.tsv" { nf[$1] = 1; next }
    base(FILENAME) == "stims.txt"    { rawstim[$1] = 1; next }
    base(FILENAME) == "aggstims.txt" { aggstim[++nagg] = $1; isagg[$1] = 1; next }
    { sub(/\r$/, ""); if ($0 != "") comp[$0] = 1; next }
    END {
      if (fatal) exit 1
      # Session standardization statistics (documented pipeline, sample sd
      # over each compliant session'\''s dup-averaged ratings pooled across
      # stimuli and dimensions).
      if (compliant_mode) {
        for (i = 1; i <= nsv; i++) {
          s = sv_sess[i]
          if (!(s in comp)) continue
          sn[s]++; ssum[s] += sv_val[i]; ssumsq[s] += sv_val[i] * sv_val[i]
        }
        for (s in comp) {
          if (sn[s] < 2) die("cannot standardize session (fewer than two ratings): " s)
          varr = (ssumsq[s] - ssum[s] * ssum[s] / sn[s]) / (sn[s] - 1)
          if (varr <= 1e-12) die("cannot standardize session (zero rating variance): " s)
          smean[s] = ssum[s] / sn[s]; ssd[s] = sqrt(varr)
        }
      }
      for (i = 1; i <= nsv; i++) {
        s = sv_sess[i]
        if (compliant_mode && !(s in comp)) continue
        k = sv_stim[i] SUBSEP sv_dim[i]
        sup[k]++
        if (compliant_mode) zsum[k] += (sv_val[i] - smean[s]) / ssd[s]
      }
      nrec = 0; nexcl = 0
      for (a = 1; a <= nagg; a++) {
        stim = aggstim[a]
        if (stim in nf) { reason = "nonfinite-aggregate" }
        else {
          minsup = -1; total = 0; reason = ""
          for (j = 1; j <= ndims; j++) {
            c = sup[stim, dima[j]] + 0
            total += c
            if (minsup < 0 || c < minsup) minsup = c
          }
          if (total == 0) reason = "missing-raw-join"
          else if (minsup < min_support) reason = "weak-support"
          else if (compliant_mode) {
            for (j = 1; j <= ndims; j++) {
              k = stim SUBSEP dima[j]
              d = zsum[k] / sup[k] - aggval[stim, dima[j]]
              if (d < 0) d = -d
              if (d > tol) { reason = "aggregate-mismatch"; break }
            }
          }
        }
        if (reason != "") {
          nexcl++
          printf "{\"reason\":\"%s\",\"stimulus_id\":\"%s\"}\n", reason, stim > (work "/excluded.jsonl")
          continue
        }
        nrec++
        line = "{\"stimulus_id\":\"" stim "\",\"source_id\":\"" source_id "\""
        line = line ",\"domain\":\"" domain "\",\"labels\":{"
        for (j = 1; j <= ndims; j++)
          line = line (j > 1 ? "," : "") "\"" dima[j] "\":" aggval[stim, dima[j]]
        line = line "},\"support\":{"
        for (j = 1; j <= ndims; j++)
          line = line (j > 1 ? "," : "") "\"" dima[j] "\":" sup[stim, dima[j]]
        line = line "},\"min_support\":" minsup "}"
        print line > (work "/records.jsonl")
      }
      for (s in rawstim)
        if (!(s in isagg)) {
          nexcl++
          printf "{\"reason\":\"not-in-aggregate\",\"stimulus_id\":\"%s\"}\n", s > (work "/excluded.jsonl")
        }
      printf "%d\t%d\n", nrec, nexcl > (work "/counts.tsv")
    }
  ' "$@" || exit 1
  : >>"$work/records.jsonl"; : >>"$work/excluded.jsonl"
}

cmd_normalize() {
  raw=""; agg=""; domain=""; source_id=""; out=""; receipt=""; compliant=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --raw) raw=${2:-}; shift 2 ;;
      --agg) agg=${2:-}; shift 2 ;;
      --domain) domain=${2:-}; shift 2 ;;
      --source-id) source_id=${2:-}; shift 2 ;;
      --out) out=${2:-}; shift 2 ;;
      --receipt) receipt=${2:-}; shift 2 ;;
      --compliant-sessions) compliant=${2:-}; shift 2 ;;
      *) usage >&2; exit 2 ;;
    esac
  done
  [ -n "$raw" ] && [ -n "$agg" ] && [ -n "$domain" ] && [ -n "$source_id" ] && [ -n "$out" ] ||
    { usage >&2; exit 2; }
  check_token "$domain" "domain"
  check_token "$source_id" "source-id"
  check_input "$raw" "raw ratings"
  check_input "$agg" "aggregate ratings"
  [ -z "$compliant" ] || check_input "$compliant" "compliant-sessions"

  work=$(mktemp -d "${out}.work.XXXXXX") || fail "mktemp failed"
  # shellcheck disable=SC2064
  trap "rm -rf '$work'" EXIT HUP INT TERM

  parse_raw "$raw" "$work"
  parse_agg "$agg" "$work"
  [ -z "$compliant" ] || check_sessions "$compliant" "$work"
  join_and_decide "$work" "$compliant" "$domain" "$source_id"

  IFS=$(printf '\t') read -r nrec _nexcl <"$work/counts.tsv"
  [ "$nrec" -gt 0 ] || fail "no usable records after normalization (all stimuli excluded)"
  IFS=$(printf '\t') read -r rows nonfinite training <"$work/stats.tsv"

  if [ -n "$compliant" ]; then
    basis="compliant-sessions"; aggcheck="recomputed-within-tolerance"
  else
    basis="raw-sessions"; aggcheck="not-computable-from-released-schema"
  fi

  jq -s '.' "$work/records.jsonl" >"$work/records.json"
  jq -s '.' "$work/excluded.jsonl" >"$work/excluded.json"

  tmp_out=$(mktemp "${out}.tmp.XXXXXX") || fail "mktemp failed"
  jq -n -S \
    --arg schema "$SCHEMA_VERSION" --arg source_id "$source_id" --arg domain "$domain" \
    --arg basis "$basis" --arg aggcheck "$aggcheck" \
    --argjson min_support "$MIN_SUPPORT" --argjson tol "$TOLERANCE" \
    --argjson rows "$rows" --argjson nonfinite "$nonfinite" --argjson training "$training" \
    --slurpfile recs "$work/records.json" --slurpfile excl "$work/excluded.json" '
    {
      schema_version: $schema,
      source_id: $source_id,
      domain: $domain,
      scale: { min: -3, max: 3 },
      dimensions: ["AE","AVG","EXMPL","TRU","TYP","US"],
      support_basis: $basis,
      aggregate_check: $aggcheck,
      min_support_required: $min_support,
      tolerance: $tol,
      records: ($recs[0] | sort_by(.stimulus_id)),
      excluded: ($excl[0] | sort_by(.stimulus_id, .reason)),
      row_stats: { raw_rows: $rows, nonfinite_rows: $nonfinite, training_rows: $training }
    }' >"$tmp_out" || { rm -f "$tmp_out"; fail "output render failed"; }
  mv -f "$tmp_out" "$out"

  if [ -n "$receipt" ]; then
    raw_sha=$(shasum -a 256 "$raw" | awk '{print $1}')
    agg_sha=$(shasum -a 256 "$agg" | awk '{print $1}')
    out_sha=$(shasum -a 256 "$out" | awk '{print $1}')
    if [ -n "$compliant" ]; then
      sess_sha=$(shasum -a 256 "$compliant" | awk '{print $1}')
    else
      sess_sha=""
    fi
    tool_fp=$(shasum -a 256 "$0" | awk '{print $1}')
    now=${TASTE_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
    tmp_receipt=$(mktemp "${receipt}.tmp.XXXXXX") || fail "mktemp failed"
    jq -n -S \
      --arg schema "$SCHEMA_VERSION" --arg source_id "$source_id" --arg domain "$domain" \
      --arg basis "$basis" --arg aggcheck "$aggcheck" --arg now "$now" \
      --arg tool_fp "$tool_fp" --arg raw_sha "$raw_sha" --arg agg_sha "$agg_sha" \
      --arg sess_sha "$sess_sha" --arg out_sha "$out_sha" \
      --argjson min_support "$MIN_SUPPORT" --argjson tol "$TOLERANCE" \
      --slurpfile outdoc "$out" '
      {
        schema_version: $schema,
        kind: "receipt",
        tool: { id: "polylane-taste-ratings", fingerprint: $tool_fp },
        executed_at: $now,
        source_id: $source_id,
        domain: $domain,
        support_basis: $basis,
        aggregate_check: $aggcheck,
        min_support_required: $min_support,
        tolerance: $tol,
        inputs: ({ raw_sha256: $raw_sha, aggregate_sha256: $agg_sha }
                 + (if $sess_sha == "" then {} else { compliant_sessions_sha256: $sess_sha } end)),
        output_sha256: $out_sha,
        records: ($outdoc[0].records | length),
        excluded: ($outdoc[0].excluded | length),
        row_stats: $outdoc[0].row_stats
      }' >"$tmp_receipt" || { rm -f "$tmp_receipt"; fail "receipt render failed"; }
    mv -f "$tmp_receipt" "$receipt"
  fi

  rm -rf "$work"
  trap - EXIT HUP INT TERM
}

main() {
  require_tools
  [ "$#" -ge 1 ] || { usage >&2; exit 2; }
  sub=$1; shift
  case "$sub" in
    normalize) cmd_normalize "$@" ;;
    *) usage >&2; exit 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
