#!/usr/bin/env bash
# Focused test for the ratings-normalize lane: strict parsing of the released
# Miniukovich–Figl raw/aggregate tab-separated schemas, native-label and
# dimension preservation, proven stimulus joins, raw/compliant rater support,
# frozen-tolerance aggregate recomputation, and fail-closed rejection of schema
# drift, nonfinite values, weak support, missing joins, and inconsistent
# aggregates. Hermetic: fixtures only, no network.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
RATINGS="$ROOT/bin/polylane-taste-ratings.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-ratings.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
ASSERTIONS=0

assert_ok() { "$@" >/dev/null; ASSERTIONS=$((ASSERTIONS + 1)); }
assert_fail() {
  if "$@" >/dev/null 2>&1; then echo "expected failure: $*" >&2; exit 1; fi
  ASSERTIONS=$((ASSERTIONS + 1))
}
expect_eq() {
  if [ "$1" = "$2" ]; then ASSERTIONS=$((ASSERTIONS + 1));
  else echo "FAIL ${3:-assertion}: expected [$1] got [$2]" >&2; exit 1; fi
}
# Failure must carry the expected reason on stderr.
expect_fail_reason() {
  want=$1; shift
  if out=$("$@" 2>&1 >/dev/null); then
    echo "expected failure with [$want]: $*" >&2; exit 1
  fi
  case "$out" in
    *"$want"*) ASSERTIONS=$((ASSERTIONS + 1)) ;;
    *) echo "FAIL: wanted reason [$want] in [$out]" >&2; exit 1 ;;
  esac
}

DIMS="TYP AVG EXMPL AE US TRU"
RAW_HDR=$(printf 'stimulusId\tisDuplicate\trating\tisTraining\tdimension\tsessionId')
AGG_HDR=$(printf 'stimulusId\tTYP\tAVG\tEXMPL\tAE\tUS\tTRU')

# raw_row STIM DUP RATING TRAIN DIM SESS
raw_row() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6"; }

# Emit rows for one stimulus rated once by N sessions on all six dimensions.
rate_all_dims() { # STIM RATING SESS_PREFIX N
  s=$1; r=$2; p=$3; n=$4
  i=1
  while [ "$i" -le "$n" ]; do
    for d in $DIMS; do raw_row "$s" FALSE "$r" FALSE "$d" "$p$i"; done
    i=$((i + 1))
  done
}

# --- baseline fixture: two stimuli, five sessions each, all six dimensions ---
# Each session rates s1=1 and s2=-1 on every dimension, so the documented
# pipeline (dup-mean, within-session standardization with sample sd, mean over
# sessions) yields exactly +/- 0.5*sqrt(11/3) = 0.9574271... per dimension.
Z=0.957427
mk_baseline() { # OUTDIR
  d=$1; mkdir -p "$d"
  { printf '%s\n' "$RAW_HDR"
    i=1
    while [ "$i" -le 5 ]; do
      for dim in $DIMS; do
        raw_row s1 FALSE 1 FALSE "$dim" "sess$i"
        raw_row s2 FALSE -1 FALSE "$dim" "sess$i"
      done
      i=$((i + 1))
    done
  } >"$d/raw.txt"
  { printf '%s\n' "$AGG_HDR"
    printf 's1\t%s\t%s\t%s\t%s\t%s\t%s\n' $Z $Z $Z $Z $Z $Z
    printf 's2\t-%s\t-%s\t-%s\t-%s\t-%s\t-%s\n' $Z $Z $Z $Z $Z $Z
  } >"$d/agg.txt"
  printf 'sess1\nsess2\nsess3\nsess4\nsess5\n' >"$d/sessions.txt"
}

B="$TMP/base"; mk_baseline "$B"

norm() { # RAW AGG OUT [extra args...]
  raw=$1; agg=$2; out=$3; shift 3
  "$RATINGS" normalize --raw "$raw" --agg "$agg" \
    --domain e-commerce --source-id miniukovich-9fksqi --out "$out" "$@"
}

# --- 1. happy path without a compliant-session list -------------------------
assert_ok norm "$B/raw.txt" "$B/agg.txt" "$TMP/out1.json"
expect_eq 2 "$(jq '.records | length' "$TMP/out1.json")" "record count"
expect_eq "raw-sessions" "$(jq -r '.support_basis' "$TMP/out1.json")" "support basis"
expect_eq "not-computable-from-released-schema" \
  "$(jq -r '.aggregate_check' "$TMP/out1.json")" "aggregate check mode"
expect_eq "0.957427" \
  "$(jq -r '.records[] | select(.stimulus_id == "s1") | .labels.AE' "$TMP/out1.json")" \
  "native AE label preserved"
expect_eq "-0.957427" \
  "$(jq -r '.records[] | select(.stimulus_id == "s2") | .labels.TRU' "$TMP/out1.json")" \
  "native TRU label preserved"
expect_eq 5 \
  "$(jq '.records[] | select(.stimulus_id == "s1") | .support.TYP' "$TMP/out1.json")" \
  "per-dimension support"
expect_eq 5 \
  "$(jq '[.records[].min_support] | min' "$TMP/out1.json")" "min support"
expect_eq 0 "$(jq '.excluded | length' "$TMP/out1.json")" "no exclusions"
expect_eq "e-commerce" "$(jq -r '.records[0].domain' "$TMP/out1.json")" "domain bound"
expect_eq "miniukovich-9fksqi" "$(jq -r '.records[0].source_id' "$TMP/out1.json")" "source bound"
expect_eq '["AE","AVG","EXMPL","TRU","TYP","US"]' \
  "$(jq -c '.dimensions' "$TMP/out1.json")" "all six native dimensions kept"
expect_eq "-3 3" "$(jq -r '"\(.scale.min) \(.scale.max)"' "$TMP/out1.json")" "native scale"

# --- 2. determinism: same inputs, byte-identical output ----------------------
assert_ok norm "$B/raw.txt" "$B/agg.txt" "$TMP/out1b.json"
assert_ok cmp -s "$TMP/out1.json" "$TMP/out1b.json"

# --- 3. compliant-session recompute within the frozen 0.01 tolerance ---------
assert_ok norm "$B/raw.txt" "$B/agg.txt" "$TMP/out2.json" \
  --compliant-sessions "$B/sessions.txt" --receipt "$TMP/receipt2.json"
expect_eq "compliant-sessions" "$(jq -r '.support_basis' "$TMP/out2.json")" "compliant basis"
expect_eq "recomputed-within-tolerance" "$(jq -r '.aggregate_check' "$TMP/out2.json")" \
  "aggregate recompute ran"
expect_eq "0.01" "$(jq -r '.tolerance' "$TMP/out2.json")" "frozen tolerance"
expect_eq 2 "$(jq '.records | length' "$TMP/out2.json")" "recompute keeps both"
expect_eq "taste-ratings-normalize/v1" \
  "$(jq -r '.schema_version' "$TMP/receipt2.json")" "receipt schema"
raw_sha=$(shasum -a 256 "$B/raw.txt" | awk '{print $1}')
expect_eq "$raw_sha" "$(jq -r '.inputs.raw_sha256' "$TMP/receipt2.json")" "receipt binds raw"

# --- 4. compliant subset shrinks support and can exclude ----------------------
printf 'sess1\nsess2\nsess3\nsess4\n' >"$TMP/four-sessions.txt"
assert_fail norm "$B/raw.txt" "$B/agg.txt" "$TMP/out3.json" \
  --compliant-sessions "$TMP/four-sessions.txt"   # 4 < 5 support on every record

# --- 5. inconsistent aggregate beyond tolerance excludes the stimulus ---------
mkdir -p "$TMP/mismatch"
cp "$B/raw.txt" "$TMP/mismatch/raw.txt"; cp "$B/sessions.txt" "$TMP/mismatch/sessions.txt"
{ printf '%s\n' "$AGG_HDR"
  printf 's1\t%s\t%s\t%s\t0.90\t%s\t%s\n' $Z $Z $Z $Z $Z
  printf 's2\t-%s\t-%s\t-%s\t-%s\t-%s\t-%s\n' $Z $Z $Z $Z $Z $Z
} >"$TMP/mismatch/agg.txt"
# Under the fail-closed fidelity contract a mismatch is never a success: the
# diagnostic output still records the exclusion, but the exit is non-zero.
expect_fail_reason "aggregate verification failed" \
  norm "$TMP/mismatch/raw.txt" "$TMP/mismatch/agg.txt" "$TMP/out4.json" \
  --compliant-sessions "$TMP/mismatch/sessions.txt"
expect_eq 1 "$(jq '.records | length' "$TMP/out4.json")" "mismatched stimulus dropped"
expect_eq "aggregate-mismatch" \
  "$(jq -r '.excluded[] | select(.stimulus_id == "s1") | .reason' "$TMP/out4.json")" \
  "explicit mismatch exclusion"

# --- 6. schema drift in the raw header fails ---------------------------------
tbl_drift() { # NAME HEADER
  mkdir -p "$TMP/$1"
  { printf '%s\n' "$2"; rate_all_dims s1 1 s 5; } >"$TMP/$1/raw.txt"
  cp "$B/agg.txt" "$TMP/$1/agg.txt"
}
tbl_drift unknown-col "$(printf '%s\tmystery' "$RAW_HDR")"
tbl_drift missing-col "$(printf 'stimulusId\tisDuplicate\trating\tisTraining\tdimension')"
tbl_drift dup-col "$(printf 'stimulusId\tisDuplicate\trating\tisTraining\tdimension\tdimension')"
expect_fail_reason "unknown raw column" \
  norm "$TMP/unknown-col/raw.txt" "$TMP/unknown-col/agg.txt" "$TMP/x.json"
expect_fail_reason "raw header" \
  norm "$TMP/missing-col/raw.txt" "$TMP/missing-col/agg.txt" "$TMP/x.json"
expect_fail_reason "duplicate raw column" \
  norm "$TMP/dup-col/raw.txt" "$TMP/dup-col/agg.txt" "$TMP/x.json"

# --- 7. reordered-but-complete headers are read by name, not position ---------
mkdir -p "$TMP/reorder"
{ printf 'sessionId\tdimension\tisTraining\trating\tisDuplicate\tstimulusId\n'
  i=1
  while [ "$i" -le 5 ]; do
    for dim in $DIMS; do
      printf 'sess%s\t%s\tFALSE\t1\tFALSE\ts1\n' "$i" "$dim"
      printf 'sess%s\t%s\tFALSE\t-1\tFALSE\ts2\n' "$i" "$dim"
    done
    i=$((i + 1))
  done
} >"$TMP/reorder/raw.txt"
{ printf 'stimulusId\tAE\tUS\tTRU\tTYP\tAVG\tEXMPL\n'
  printf 's1\t%s\t%s\t%s\t%s\t%s\t%s\n' $Z $Z $Z $Z $Z $Z
  printf 's2\t-%s\t-%s\t-%s\t-%s\t-%s\t-%s\n' $Z $Z $Z $Z $Z $Z
} >"$TMP/reorder/agg.txt"
assert_ok norm "$TMP/reorder/raw.txt" "$TMP/reorder/agg.txt" "$TMP/out5.json"
expect_eq "0.957427" \
  "$(jq -r '.records[] | select(.stimulus_id == "s1") | .labels.AE' "$TMP/out5.json")" \
  "header-driven column mapping"

# --- 8. malformed raw rows fail with explicit reasons -------------------------
tbl_badrow() { # NAME ROW
  mkdir -p "$TMP/$1"
  { printf '%s\n' "$RAW_HDR"; rate_all_dims s1 1 s 5; rate_all_dims s2 -1 s 5
    printf '%s\n' "$2"; } >"$TMP/$1/raw.txt"
  cp "$B/agg.txt" "$TMP/$1/agg.txt"
}
tbl_badrow out-of-range "$(raw_row s1 FALSE 4 FALSE AE sX)"
tbl_badrow non-integer "$(raw_row s1 FALSE 2.5 FALSE AE sX)"
tbl_badrow garbage-rating "$(raw_row s1 FALSE beautiful FALSE AE sX)"
tbl_badrow bad-bool "$(raw_row s1 MAYBE 1 FALSE AE sX)"
tbl_badrow bad-dim "$(raw_row s1 FALSE 1 FALSE COLOR sX)"
tbl_badrow short-row "$(printf 's1\tFALSE\t1')"
for name in out-of-range non-integer garbage-rating bad-bool bad-dim short-row; do
  assert_fail norm "$TMP/$name/raw.txt" "$TMP/$name/agg.txt" "$TMP/x.json"
done

# --- 9. NA ratings are excluded rows, not guesses -----------------------------
mkdir -p "$TMP/na-row"
{ printf '%s\n' "$RAW_HDR"
  i=1
  while [ "$i" -le 5 ]; do
    for dim in $DIMS; do
      raw_row s1 FALSE 1 FALSE "$dim" "sess$i"
      raw_row s2 FALSE -1 FALSE "$dim" "sess$i"
    done
    i=$((i + 1))
  done
  raw_row s1 FALSE NA FALSE AE sess6
} >"$TMP/na-row/raw.txt"
cp "$B/agg.txt" "$TMP/na-row/agg.txt"
assert_ok norm "$TMP/na-row/raw.txt" "$TMP/na-row/agg.txt" "$TMP/out6.json"
expect_eq 1 "$(jq '.row_stats.nonfinite_rows' "$TMP/out6.json")" "NA row counted"
expect_eq 5 \
  "$(jq '.records[] | select(.stimulus_id == "s1") | .support.AE' "$TMP/out6.json")" \
  "NA row contributes no support"

# --- 10. weak support excludes the stimulus explicitly ------------------------
mkdir -p "$TMP/weak"
{ printf '%s\n' "$RAW_HDR"; rate_all_dims s1 1 s 5; rate_all_dims s2 -1 t 4
} >"$TMP/weak/raw.txt"
cp "$B/agg.txt" "$TMP/weak/agg.txt"
assert_ok norm "$TMP/weak/raw.txt" "$TMP/weak/agg.txt" "$TMP/out7.json"
expect_eq 1 "$(jq '.records | length' "$TMP/out7.json")" "weak stimulus dropped"
expect_eq "weak-support" \
  "$(jq -r '.excluded[] | select(.stimulus_id == "s2") | .reason' "$TMP/out7.json")" \
  "weak support is explicit"

# --- 11. joins must be proven in both directions ------------------------------
mkdir -p "$TMP/join"
{ printf '%s\n' "$RAW_HDR"; rate_all_dims s1 1 s 5; rate_all_dims s3 0 s 5
} >"$TMP/join/raw.txt"
cp "$B/agg.txt" "$TMP/join/agg.txt"   # has s1 + s2; raw has s1 + s3
assert_ok norm "$TMP/join/raw.txt" "$TMP/join/agg.txt" "$TMP/out8.json"
expect_eq 1 "$(jq '.records | length' "$TMP/out8.json")" "only proven join kept"
expect_eq "missing-raw-join" \
  "$(jq -r '.excluded[] | select(.stimulus_id == "s2") | .reason' "$TMP/out8.json")" \
  "aggregate without raw rows excluded"
expect_eq "not-in-aggregate" \
  "$(jq -r '.excluded[] | select(.stimulus_id == "s3") | .reason' "$TMP/out8.json")" \
  "raw without aggregate excluded"

# --- 12. training rows never create stimuli or support ------------------------
mkdir -p "$TMP/training"
{ printf '%s\n' "$RAW_HDR"
  i=1
  while [ "$i" -le 5 ]; do
    for dim in $DIMS; do
      raw_row s1 FALSE 1 FALSE "$dim" "sess$i"
      raw_row s2 FALSE -1 FALSE "$dim" "sess$i"
      raw_row train-1 FALSE 2 TRUE "$dim" "sess$i"
    done
    i=$((i + 1))
  done
} >"$TMP/training/raw.txt"
cp "$B/agg.txt" "$TMP/training/agg.txt"
assert_ok norm "$TMP/training/raw.txt" "$TMP/training/agg.txt" "$TMP/out9.json"
expect_eq 2 "$(jq '.records | length' "$TMP/out9.json")" "training stimulus not a record"
expect_eq 30 "$(jq '.row_stats.training_rows' "$TMP/out9.json")" "training rows counted"
expect_eq 0 "$(jq '[.excluded[] | select(.stimulus_id == "train-1")] | length' "$TMP/out9.json")" \
  "training absence from aggregate is expected, not an exclusion"

# --- 13. duplicate re-ratings collapse to one rater ---------------------------
mkdir -p "$TMP/dup"
{ printf '%s\n' "$RAW_HDR"
  i=1
  while [ "$i" -le 5 ]; do
    for dim in $DIMS; do
      raw_row s1 FALSE 1 FALSE "$dim" "sess$i"
      raw_row s1 TRUE 1 FALSE "$dim" "sess$i"
      raw_row s2 FALSE -1 FALSE "$dim" "sess$i"
    done
    i=$((i + 1))
  done
} >"$TMP/dup/raw.txt"
cp "$B/agg.txt" "$TMP/dup/agg.txt"
assert_ok norm "$TMP/dup/raw.txt" "$TMP/dup/agg.txt" "$TMP/out10.json"
expect_eq 5 \
  "$(jq '.records[] | select(.stimulus_id == "s1") | .support.AE' "$TMP/out10.json")" \
  "re-rated session counts once"

# --- 14. more than two DISTINCT rows per session/stimulus/dimension is drift --
# (a verbatim-repeated row is collapsed losslessly — case 20 — so this fixture
# uses three genuinely distinct rows)
mkdir -p "$TMP/triple"
{ printf '%s\n' "$RAW_HDR"; rate_all_dims s1 1 s 5; rate_all_dims s2 -1 s 5
  raw_row s1 TRUE 0 FALSE AE s1
  raw_row s1 TRUE 1 FALSE AE s1
} >"$TMP/triple/raw.txt"   # s1/AE/s1: three distinct exposures
cp "$B/agg.txt" "$TMP/triple/agg.txt"
assert_fail norm "$TMP/triple/raw.txt" "$TMP/triple/agg.txt" "$TMP/x.json"

# --- 15. aggregate drift and nonfinite aggregate values -----------------------
mkdir -p "$TMP/agg-bad"
cp "$B/raw.txt" "$TMP/agg-bad/raw.txt"
printf 'stimulusId\tTYP\tAVG\tEXMPL\tAE\tUS\tTRU\tEXTRA\ns1\t1\t1\t1\t1\t1\t1\t1\n' \
  >"$TMP/agg-bad/extra.txt"
printf 'stimulusId\tTYP\tAVG\tEXMPL\tAE\tUS\ns1\t1\t1\t1\t1\t1\n' >"$TMP/agg-bad/missing.txt"
{ printf '%s\n' "$AGG_HDR"
  printf 's1\t%s\t%s\t%s\t%s\t%s\t%s\n' $Z $Z $Z $Z $Z $Z
  printf 's1\t0.5\t%s\t%s\t%s\t%s\t%s\n' $Z $Z $Z $Z $Z
} >"$TMP/agg-bad/dupstim.txt"   # repeated stimulus with DIFFERENT values (identical repeats collapse, case 23)
{ printf '%s\n' "$AGG_HDR"
  printf 's1\t%s\t%s\t%s\tNA\t%s\t%s\n' $Z $Z $Z $Z $Z
  printf 's2\t-%s\t-%s\t-%s\t-%s\t-%s\t-%s\n' $Z $Z $Z $Z $Z $Z
} >"$TMP/agg-bad/na.txt"
{ printf '%s\n' "$AGG_HDR"
  printf 's1\t%s\t%s\t%s\tvery-nice\t%s\t%s\n' $Z $Z $Z $Z $Z
  printf 's2\t-%s\t-%s\t-%s\t-%s\t-%s\t-%s\n' $Z $Z $Z $Z $Z $Z
} >"$TMP/agg-bad/garbage.txt"
expect_fail_reason "unknown aggregate column" \
  norm "$B/raw.txt" "$TMP/agg-bad/extra.txt" "$TMP/x.json"
expect_fail_reason "aggregate header" \
  norm "$B/raw.txt" "$TMP/agg-bad/missing.txt" "$TMP/x.json"
expect_fail_reason "duplicate aggregate stimulus" \
  norm "$B/raw.txt" "$TMP/agg-bad/dupstim.txt" "$TMP/x.json"
assert_fail norm "$B/raw.txt" "$TMP/agg-bad/garbage.txt" "$TMP/x.json"
assert_ok norm "$B/raw.txt" "$TMP/agg-bad/na.txt" "$TMP/out11.json"
expect_eq "nonfinite-aggregate" \
  "$(jq -r '.excluded[] | select(.stimulus_id == "s1") | .reason' "$TMP/out11.json")" \
  "NA aggregate excluded explicitly"

# --- 16. every record excluded is an overall failure, never an empty pass -----
mkdir -p "$TMP/empty"
{ printf '%s\n' "$RAW_HDR"; rate_all_dims s1 1 s 4; rate_all_dims s2 -1 s 4
} >"$TMP/empty/raw.txt"
cp "$B/agg.txt" "$TMP/empty/agg.txt"
expect_fail_reason "no usable records" \
  norm "$TMP/empty/raw.txt" "$TMP/empty/agg.txt" "$TMP/x.json"

# --- 17. compliant-session list integrity -------------------------------------
printf 'sess1\nsess2\nsess3\nsess4\nghost\n' >"$TMP/ghost-sessions.txt"
expect_fail_reason "unknown compliant session" \
  norm "$B/raw.txt" "$B/agg.txt" "$TMP/x.json" --compliant-sessions "$TMP/ghost-sessions.txt"
mkdir -p "$TMP/flat"
{ printf '%s\n' "$RAW_HDR"
  i=1
  while [ "$i" -le 5 ]; do
    for dim in $DIMS; do
      raw_row s1 FALSE 1 FALSE "$dim" "sess$i"
      raw_row s2 FALSE 1 FALSE "$dim" "sess$i"   # zero variance per session
    done
    i=$((i + 1))
  done
} >"$TMP/flat/raw.txt"
cp "$B/agg.txt" "$TMP/flat/agg.txt"
expect_fail_reason "cannot standardize" \
  norm "$TMP/flat/raw.txt" "$TMP/flat/agg.txt" "$TMP/x.json" \
  --compliant-sessions "$B/sessions.txt"

# --- 18. file hygiene ---------------------------------------------------------
: >"$TMP/empty-file.txt"
assert_fail norm "$TMP/empty-file.txt" "$B/agg.txt" "$TMP/x.json"
assert_fail norm "$B/raw.txt" "$TMP/empty-file.txt" "$TMP/x.json"
ln -s "$B/raw.txt" "$TMP/raw-link.txt"
assert_fail norm "$TMP/raw-link.txt" "$B/agg.txt" "$TMP/x.json"
assert_fail "$RATINGS" normalize --raw "$B/raw.txt" --out "$TMP/x.json"  # missing args
assert_fail "$RATINGS" frobnicate                                        # unknown command

# --- 19. CRLF input is accepted (line endings are transport, not schema) ------
mkdir -p "$TMP/crlf"
sed $'s/$/\r/' "$B/raw.txt" >"$TMP/crlf/raw.txt"
sed $'s/$/\r/' "$B/agg.txt" >"$TMP/crlf/agg.txt"
assert_ok norm "$TMP/crlf/raw.txt" "$TMP/crlf/agg.txt" "$TMP/out12.json"
expect_eq 2 "$(jq '.records | length' "$TMP/out12.json")" "CRLF tolerated"

# --- 20. byte-identical repeated raw rows collapse losslessly ----------------
# The released banks file contains one verbatim-repeated duplicate-exposure row
# (b825.jpg / US). Collapsing an exact repeat loses no information; the
# published-aggregate tolerance gate remains the arbiter of the interpretation.
mkdir -p "$TMP/dupped"
cp "$B/agg.txt" "$TMP/dupped/agg.txt"
{ cat "$B/raw.txt"
  raw_row s1 TRUE 1 FALSE TYP sess1
  raw_row s1 TRUE 1 FALSE TYP sess1
} >"$TMP/dupped/raw.txt"
assert_ok norm "$TMP/dupped/raw.txt" "$TMP/dupped/agg.txt" "$TMP/out20.json"
expect_eq 2 "$(jq '.records | length' "$TMP/out20.json")" "exact-repeat rows collapse"
expect_eq "$(jq -r '.records[] | select(.stimulus_id=="s1") | .labels.TYP' "$TMP/out1.json")" \
  "$(jq -r '.records[] | select(.stimulus_id=="s1") | .labels.TYP' "$TMP/out20.json")" \
  "collapsed repeat leaves labels unchanged"

# Three DISTINCT rows for one session/stimulus/dimension stay a hard failure.
mkdir -p "$TMP/tripled"
cp "$B/agg.txt" "$TMP/tripled/agg.txt"
{ cat "$B/raw.txt"
  raw_row s1 TRUE 1 FALSE TYP sess1
  raw_row s1 TRUE 0 FALSE TYP sess1
} >"$TMP/tripled/raw.txt"
expect_fail_reason "more than two" norm "$TMP/tripled/raw.txt" "$TMP/tripled/agg.txt" "$TMP/x20.json"

# --- 21. per-stimulus standardized samples (compliant mode only) -------------
assert_ok norm "$B/raw.txt" "$B/agg.txt" "$TMP/out21.json" \
  --compliant-sessions "$B/sessions.txt" --samples AE
expect_eq "recomputed-within-tolerance" \
  "$(jq -r '.aggregate_check' "$TMP/out21.json")" "samples run stays compliant"
expect_eq "0.957427 0.957427 0.957427 0.957427 0.957427" \
  "$(jq -r '.records[] | select(.stimulus_id=="s1") | .samples.AE | map(tostring) | join(" ")' "$TMP/out21.json")" \
  "AE samples are the five compliant standardized session values"
expect_eq "5" "$(jq -r '.records[] | select(.stimulus_id=="s2") | .samples.AE | length' "$TMP/out21.json")" \
  "samples length equals compliant support"
# samples without a compliant list are undefined and must be refused
assert_fail norm "$B/raw.txt" "$B/agg.txt" "$TMP/x21.json" --samples AE
# unknown dimension is refused
assert_fail norm "$B/raw.txt" "$B/agg.txt" "$TMP/x21b.json" \
  --compliant-sessions "$B/sessions.txt" --samples NOPE

# --- 22. training rows enter the standardization basis (source-exact) --------
# Reproduced exactly against the released aggregates: the source standardizes
# each session over ALL its dup-averaged (stimulus, dimension, training)
# values — training items included in the basis — then publishes the mean of
# the non-training standardized values over compliant sessions. With one
# training value 0 beside s1=1 and s2=-1 on all six dimensions, the basis is
# 13 values with mean 0 and sample sd exactly 1, so published labels are ±1.
mkdir -p "$TMP/train-basis"
{ printf '%s\n' "$RAW_HDR"
  i=1
  while [ "$i" -le 5 ]; do
    for dim in $DIMS; do
      raw_row s1 FALSE 1 FALSE "$dim" "sess$i"
      raw_row s2 FALSE -1 FALSE "$dim" "sess$i"
    done
    raw_row t1 FALSE 0 TRUE AE "sess$i"
    i=$((i + 1))
  done
} >"$TMP/train-basis/raw.txt"
{ printf '%s\n' "$AGG_HDR"
  printf 's1\t1\t1\t1\t1\t1\t1\n'
  printf 's2\t-1\t-1\t-1\t-1\t-1\t-1\n'
} >"$TMP/train-basis/agg.txt"
printf 'sess1\nsess2\nsess3\nsess4\nsess5\n' >"$TMP/train-basis/sessions.txt"
assert_ok norm "$TMP/train-basis/raw.txt" "$TMP/train-basis/agg.txt" "$TMP/out22.json" \
  --compliant-sessions "$TMP/train-basis/sessions.txt" --samples AE
expect_eq "recomputed-within-tolerance" \
  "$(jq -r '.aggregate_check' "$TMP/out22.json")" "training-basis recompute matches"
expect_eq "2" "$(jq '.records | length' "$TMP/out22.json")" "training stimulus never a record"
expect_eq "1.000000 1.000000 1.000000 1.000000 1.000000" \
  "$(jq -r '.records[] | select(.stimulus_id=="s1") | .samples.AE | map(tostring) | join(" ")' "$TMP/out22.json")" \
  "samples reflect the training-inclusive basis"

# --- 23. byte-identical duplicate aggregate rows collapse; differing die -----
# The released banks aggregate repeats the b428.jpg row verbatim.
mkdir -p "$TMP/aggdup"
cp "$B/raw.txt" "$TMP/aggdup/raw.txt"
{ cat "$B/agg.txt"; tail -1 "$B/agg.txt"; } >"$TMP/aggdup/agg.txt"
assert_ok norm "$TMP/aggdup/raw.txt" "$TMP/aggdup/agg.txt" "$TMP/out23.json"
expect_eq 2 "$(jq '.records | length' "$TMP/out23.json")" "identical agg repeat collapses"
{ cat "$B/agg.txt"; tail -1 "$B/agg.txt" | awk -F'\t' 'BEGIN{OFS="\t"}{$2="0.5"; print}'; } >"$TMP/aggdup/agg-conflict.txt"
expect_fail_reason "duplicate aggregate stimulus" \
  norm "$TMP/aggdup/raw.txt" "$TMP/aggdup/agg-conflict.txt" "$TMP/x23.json"

# --- 24. support gate scoped to the declared label dimension -----------------
# Pairs and selection consume >=5 samples of the label dimension; a stimulus
# with 5 AE raters but 4 on another dimension is usable when AE is declared,
# and still excluded under the legacy min-over-all-dimensions gate.
mkdir -p "$TMP/scoped"
{ printf '%s\n' "$RAW_HDR"
  i=1
  while [ "$i" -le 4 ]; do
    for dim in $DIMS; do
      raw_row s1 FALSE 1 FALSE "$dim" "sess$i"
      raw_row s2 FALSE -1 FALSE "$dim" "sess$i"
    done
    i=$((i + 1))
  done
  raw_row s1 FALSE 1 FALSE AE sess5
  for dim in $DIMS; do raw_row s2 FALSE -1 FALSE "$dim" sess5; done
} >"$TMP/scoped/raw.txt"
{ printf '%s\n' "$AGG_HDR"
  printf 's1\t0.957427\t0.957427\t0.957427\t1.219499\t0.957427\t0.957427\n'
  printf 's2\t-0.841535\t-0.841535\t-0.841535\t-0.841535\t-0.841535\t-0.841535\n'
} >"$TMP/scoped/agg.txt"
printf 'sess1\nsess2\nsess3\nsess4\nsess5\n' >"$TMP/scoped/sessions.txt"
assert_ok norm "$TMP/scoped/raw.txt" "$TMP/scoped/agg.txt" "$TMP/out24.json" \
  --compliant-sessions "$TMP/scoped/sessions.txt" --samples AE
expect_eq 2 "$(jq '.records | length' "$TMP/out24.json")" "AE-scoped gate keeps s1"
expect_eq 5 "$(jq '.records[] | select(.stimulus_id=="s1") | .samples.AE | length' "$TMP/out24.json")" \
  "s1 carries five AE samples"
expect_eq 4 "$(jq '.records[] | select(.stimulus_id=="s1") | .support.TYP' "$TMP/out24.json")" \
  "other-dimension support recorded honestly"
# legacy mode (no declared label dimension) still gates on every dimension
assert_ok norm "$TMP/scoped/raw.txt" "$TMP/scoped/agg.txt" "$TMP/out24b.json" \
  --compliant-sessions "$TMP/scoped/sessions.txt"
expect_eq 1 "$(jq '.records | length' "$TMP/out24b.json")" "legacy min-over-dims gate unchanged"
expect_eq "weak-support" "$(jq -r '.excluded[] | select(.stimulus_id=="s1") | .reason' "$TMP/out24b.json")" \
  "legacy exclusion reason preserved"

# --- 25. source fidelity is verified before (and regardless of) eligibility --
# A weak-support stimulus with a wrong published aggregate must still poison
# the global claim: verification covers every finite joined value, and only
# afterwards may weak-support exclude the stimulus.
mkdir -p "$TMP/fidelity"
cp "$TMP/scoped/raw.txt" "$TMP/fidelity/raw.txt"
cp "$TMP/scoped/sessions.txt" "$TMP/fidelity/sessions.txt"
{ printf '%s\n' "$AGG_HDR"
  printf 's1\t0.957427\t0.957427\t0.957427\t1.219499\t0.957427\t0.957427\n'
  printf 's2\t-0.841535\t-0.841535\t2.000000\t-0.841535\t-0.841535\t-0.841535\n'
} >"$TMP/fidelity/agg.txt"   # s2 EXMPL is wrong by ~2.8
# A mismatched source is never a success: diagnostic output is preserved but
# the exit is non-zero, so no downstream step can consume it as validated.
expect_fail_reason "aggregate verification failed" \
  norm "$TMP/fidelity/raw.txt" "$TMP/fidelity/agg.txt" "$TMP/out25.json" \
  --compliant-sessions "$TMP/fidelity/sessions.txt" --samples AE
expect_eq "recomputed-with-mismatches" \
  "$(jq -r '.aggregate_check' "$TMP/out25.json")" "diagnostic output records the poisoned claim"
expect_eq "1" "$(jq -r '.verification.mismatched_values' "$TMP/out25.json")" "mismatch counted"
expect_eq "aggregate-mismatch" \
  "$(jq -r '.excluded[] | select(.stimulus_id=="s2") | .reason' "$TMP/out25.json")" \
  "mismatch exclusion precedes weak-support"
# clean run: counters present, zero mismatches, full coverage
expect_eq "0" "$(jq -r '.verification.mismatched_values' "$TMP/out24.json")" "clean run has zero mismatches"
jq -e '.verification.verified_values >= 12
       and .verification.unverified_values == 0
       and .verification.expected_finite_values == .verification.verified_values
       and (.verification.max_abs_error | type == "number")' \
  "$TMP/out24.json" >/dev/null || { echo "FAIL verification counters missing" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# --- 25b. a joined stimulus with an unverifiable finite dimension is a
# coverage gap: never within-tolerance, never a success. Five sessions each
# rate s1=+1 and s2=-1 on all six dimensions plus s3=0 on AE only: the basis
# is 13 dup-means with mean 0 and sample sd exactly 1, so recompute is exact
# for every rated value while s3's five unrated dimensions stay unverifiable.
mkdir -p "$TMP/gap"
{ printf '%s\n' "$RAW_HDR"
  i=1
  while [ "$i" -le 5 ]; do
    for dim in $DIMS; do
      raw_row s1 FALSE 1 FALSE "$dim" "sess$i"
      raw_row s2 FALSE -1 FALSE "$dim" "sess$i"
    done
    raw_row s3 FALSE 0 FALSE AE "sess$i"
    i=$((i + 1))
  done
} >"$TMP/gap/raw.txt"
{ printf '%s\n' "$AGG_HDR"
  printf 's1\t1\t1\t1\t1\t1\t1\n'
  printf 's2\t-1\t-1\t-1\t-1\t-1\t-1\n'
  printf 's3\t0\t0\t0\t0\t0\t0\n'
} >"$TMP/gap/agg.txt"
printf 'sess1\nsess2\nsess3\nsess4\nsess5\n' >"$TMP/gap/sessions.txt"
expect_fail_reason "aggregate verification failed" \
  norm "$TMP/gap/raw.txt" "$TMP/gap/agg.txt" "$TMP/out25b.json" \
  --compliant-sessions "$TMP/gap/sessions.txt" --samples AE
expect_eq "recomputed-incomplete" \
  "$(jq -r '.aggregate_check' "$TMP/out25b.json")" "coverage gap poisons the claim"
expect_eq "5" "$(jq -r '.verification.unverified_values' "$TMP/out25b.json")" "five s3 dimensions unverifiable"

# --- 25c. declared label dimension is explicit in the output -----------------
expect_eq "AE" "$(jq -r '.label_dimension' "$TMP/out24.json")" "label dimension recorded"
expect_eq "5" "$(jq -r '.records[] | select(.stimulus_id=="s1") | .label_support' "$TMP/out24.json")" \
  "label_support carries the scoped support"

# --- 26. strict demographics -> compliant-sessions helper --------------------
mkdir -p "$TMP/demo"
demo_hdr=$(printf 'sessionId\tGender\tsusCheat\tuid')
{ printf '%s\n' "$demo_hdr"
  printf 'sess1\tF\tFALSE\tu1\n'
  printf 'sess2\tM\tfalse\tu2\n'
  printf 'sess3\tF\tTRUE\tu3\n'
  printf 'sessX\tM\tFALSE\tu4\n'
} >"$TMP/demo/demo.txt"
assert_ok "$RATINGS" sessions --demographics "$TMP/demo/demo.txt" --raw "$B/raw.txt" \
  --out "$TMP/demo/list.txt" --receipt "$TMP/demo/receipt.json"
expect_eq "sess1
sess2" "$(cat "$TMP/demo/list.txt")" "case-insensitive FALSE, raw-joined, sorted unique"
jq -e --arg d "$(shasum -a 256 "$TMP/demo/demo.txt" | awk '{print $1}')" '
  .inputs.demographics_sha256 == $d
  and .counts.suscheat_false == 3 and .counts.in_raw == 2' "$TMP/demo/receipt.json" >/dev/null \
  || { echo "FAIL sessions receipt bindings" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))
# duplicate session row is terminal
{ printf '%s\n' "$demo_hdr"; printf 'sess1\tF\tFALSE\tu1\nsess1\tF\tFALSE\tu1\n'; } >"$TMP/demo/dup.txt"
expect_fail_reason "duplicate demographics session" \
  "$RATINGS" sessions --demographics "$TMP/demo/dup.txt" --raw "$B/raw.txt" --out "$TMP/demo/x.txt"
# malformed susCheat value is terminal
{ printf '%s\n' "$demo_hdr"; printf 'sess1\tF\tmaybe\tu1\n'; } >"$TMP/demo/badval.txt"
expect_fail_reason "invalid susCheat" \
  "$RATINGS" sessions --demographics "$TMP/demo/badval.txt" --raw "$B/raw.txt" --out "$TMP/demo/x.txt"
# missing susCheat column is terminal
{ printf 'sessionId\tGender\n'; printf 'sess1\tF\n'; } >"$TMP/demo/nocol.txt"
expect_fail_reason "susCheat" \
  "$RATINGS" sessions --demographics "$TMP/demo/nocol.txt" --raw "$B/raw.txt" --out "$TMP/demo/x.txt"
# zero compliant sessions after the raw join is terminal
{ printf '%s\n' "$demo_hdr"; printf 'sessZ\tF\tFALSE\tu1\n'; } >"$TMP/demo/none.txt"
expect_fail_reason "no compliant sessions" \
  "$RATINGS" sessions --demographics "$TMP/demo/none.txt" --raw "$B/raw.txt" --out "$TMP/demo/x.txt"

# --- 27. verification covers finite siblings of NA rows ----------------------
mkdir -p "$TMP/nasib"
cp "$B/raw.txt" "$TMP/nasib/raw.txt"
{ printf '%s\n' "$AGG_HDR"
  printf 's1\t%s\t%s\t%s\tNA\t%s\t%s\n' $Z $Z $Z $Z $Z
  printf 's2\t-%s\t-%s\t-%s\t-%s\t-%s\t-%s\n' $Z $Z $Z $Z $Z $Z
} >"$TMP/nasib/agg.txt"
assert_ok norm "$TMP/nasib/raw.txt" "$TMP/nasib/agg.txt" "$TMP/out27.json" \
  --compliant-sessions "$B/sessions.txt" --samples AE
jq -e '.verification.expected_finite_values == 11
       and .verification.verified_values == 11
       and .verification.unverified_values == 0' "$TMP/out27.json" >/dev/null \
  || { echo "FAIL NA-sibling cells must be verified: $(jq -c .verification "$TMP/out27.json")" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# --- 28. training-stimulus aggregate cells are verified via training values --
mkdir -p "$TMP/traincell"
cp "$TMP/train-basis/raw.txt" "$TMP/traincell/raw.txt"
{ cat "$TMP/train-basis/agg.txt"
  printf 't1\tNA\tNA\tNA\t0\tNA\tNA\n'
} >"$TMP/traincell/agg.txt"
assert_ok norm "$TMP/traincell/raw.txt" "$TMP/traincell/agg.txt" "$TMP/out28.json" \
  --compliant-sessions "$TMP/train-basis/sessions.txt" --samples AE
jq -e '.verification.expected_finite_values == 13
       and .verification.verified_values == 13
       and .verification.mismatched_values == 0' "$TMP/out28.json" >/dev/null \
  || { echo "FAIL training-stimulus cell must be verified: $(jq -c .verification "$TMP/out28.json")" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))
expect_eq 2 "$(jq '.records | length' "$TMP/out28.json")" "training stimulus still never a record"
# a mismatched training-stimulus cell poisons the claim
{ cat "$TMP/train-basis/agg.txt"
  printf 't1\tNA\tNA\tNA\t0.5\tNA\tNA\n'
} >"$TMP/traincell/agg-bad.txt"
expect_fail_reason "aggregate verification failed" \
  norm "$TMP/traincell/raw.txt" "$TMP/traincell/agg-bad.txt" "$TMP/out28b.json" \
  --compliant-sessions "$TMP/train-basis/sessions.txt" --samples AE

# --- 29. sessions subcommand binds raw sessionId by header name --------------
mkdir -p "$TMP/reord"
awk -F'\t' 'BEGIN{OFS="\t"} {print $6,$1,$2,$3,$4,$5}' "$B/raw.txt" >"$TMP/reord/raw.txt"
assert_ok "$RATINGS" sessions --demographics "$TMP/demo/demo.txt" --raw "$TMP/reord/raw.txt" \
  --out "$TMP/reord/list.txt"
expect_eq "sess1
sess2" "$(cat "$TMP/reord/list.txt")" "reordered raw header still binds sessionId"
awk -F'\t' 'BEGIN{OFS="\t"} NR==1{$6="sessionIdX"} {print}' "$B/raw.txt" >"$TMP/reord/nosess.txt"
expect_fail_reason "raw header missing column: sessionId" \
  "$RATINGS" sessions --demographics "$TMP/demo/demo.txt" --raw "$TMP/reord/nosess.txt" --out "$TMP/reord/x.txt"

echo "ok - $ASSERTIONS assertions"
