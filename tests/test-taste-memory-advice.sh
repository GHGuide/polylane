#!/usr/bin/env bash
# test-taste-memory-advice.sh — the retrieval policy: one-study overfit rejection,
# four-study support, contradiction, context mismatch / out-of-scope, the diversity and
# single-source caps, bounded + deduplicated output, memory-blind arms, and an explicit
# None result when nothing qualifies.
set -euo pipefail

ROOT="${POLYLANE_SOURCE_ROOT:-$PWD}"
CLI="$ROOT/bin/polylane-taste-memory.sh"
[ -f "$CLI" ] || { echo "missing CLI: $CLI" >&2; exit 1; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf 'ok   - %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL - %s (%s)\n' "$1" "${2:-}"; }

canon() { jq -S -c -j "$@"; }
sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256|awk '{print $1}'; else sha256sum|awk '{print $1}'; fi; }
patid() { printf 'pat-%s' "$(facets "$1" | jq -S -c -j . | sha | cut -c1-24)"; }
facets() { jq -n -c --arg lf "$1" '{layout_family:$lf,density_band:"std",navigation_archetype:"top",primary_information_unit:"card",palette_family:"cool",type_pair_class:"sans",shape_language:"round"}'; }
mk_candidate() { jq -n -c --argjson f "$1" --arg n "$2" '{facets:$f,capture:{route:"/x",state:"default",viewport:"1440x900",decoded:true,nonce:$n},pixel:{width:1440,height:900,distinct:true,nonce:$n},hard_gate:{function:"pass",accessibility:"pass",capture:"pass",context:"pass",provenance:"pass",overall:"PASS"},hashes:{capture_sha256:"",pixel_sha256:"",hard_gate_sha256:"",candidate_sha256:""}}'; }
mk_brief() { local c0 c1; c0=$(mk_candidate "$(facets "$6")" "$1a"); c1=$(mk_candidate "$(facets "$7")" "$1b")
  jq -n -c --arg br "$1" --arg aud "$2" --arg dom "$3" --arg task "$4" --arg sig "$5" --argjson c0 "$c0" --argjson c1 "$c1" --argjson w0 "$8" --argjson w1 "$9" '{brief_ref:$br,tags:{audience:$aud,domain:$dom,task:$task},product_signature:$sig,candidates:[$c0,$c1],aggregate:{candidate_group_wins:[$w0,$w1],ties:0,resolved_groups:($w0+$w1)},aggregate_sha256:""}'; }
mk_closure() { jq -n -S --arg study "$2" --arg run "$3" --arg label "$4" --argjson human "$5" --argjson briefs "$6" '{schema_version:"taste-study-closure/v1",study_id:$study,run_id:$run,closed_at:"2026-08-12T00:00:00Z",claim_label:$label,human_certified:$human,reference:{same_category:3,wildcard:1},direction:{cards:3},threat_scan:{leakage:"none",injection:"none",ocr_dom_scan:"pass"},briefs:$briefs,certificate:{briefs:($briefs|length),brief_wins:($briefs|length),preference_rate:0.9,confidence_lower:0.7,accessibility_regressions:0},hashes:{reference_sha256:"",direction_sha256:"",threat_sha256:"",certificate_sha256:"",closure_sha256:""}}' > "$1"; }
hash_lines() { local d i=0 line; d=$(mktemp -d); while IFS= read -r line; do [ -n "$line" ] || continue; printf '%s' "$line" > "$d/$(printf '%08d' "$i")"; i=$((i+1)); done <<EOF
$1
EOF
  [ "$i" -eq 0 ] && { rmdir "$d"; return 0; }
  shasum -a 256 "$d"/* | awk '{print $1}'; rm -rf "$d"; }
jl() { printf '%s' "$1" | jq -R . | jq -s .; }
fill_hashes() { # file — batched: minimises jq/sha spawns so long test runs finish fast
  local f="$1" tmp caps pixs hgs aggs comps rh dh th cth clh
  caps=$(hash_lines "$(jq -c -S '.briefs[].candidates[].capture' "$f")")
  pixs=$(hash_lines "$(jq -c -S '.briefs[].candidates[].pixel' "$f")")
  hgs=$(hash_lines "$(jq -c -S '.briefs[].candidates[].hard_gate' "$f")")
  aggs=$(hash_lines "$(jq -c -S '.briefs[].aggregate' "$f")")
  tmp="$f.t"; jq --argjson caps "$(jl "$caps")" --argjson pixs "$(jl "$pixs")" --argjson hgs "$(jl "$hgs")" --argjson aggs "$(jl "$aggs")" '
    reduce range(0;.briefs|length) as $i (.;
      .briefs[$i].aggregate_sha256=$aggs[$i]
      | reduce range(0;2) as $j (.;
          .briefs[$i].candidates[$j].hashes.capture_sha256=$caps[$i*2+$j]
          | .briefs[$i].candidates[$j].hashes.pixel_sha256=$pixs[$i*2+$j]
          | .briefs[$i].candidates[$j].hashes.hard_gate_sha256=$hgs[$i*2+$j]))' "$f" > "$tmp" && mv "$tmp" "$f"
  comps=$(hash_lines "$(jq -c -S '.briefs[].candidates[] | {facets:.facets,capture_sha256:.hashes.capture_sha256,pixel_sha256:.hashes.pixel_sha256,hard_gate_sha256:.hashes.hard_gate_sha256}' "$f")")
  tmp="$f.t"; jq --argjson comps "$(jl "$comps")" '
    reduce range(0;.briefs|length) as $i (.;
      reduce range(0;2) as $j (.; .briefs[$i].candidates[$j].hashes.candidate_sha256=$comps[$i*2+$j]))' "$f" > "$tmp" && mv "$tmp" "$f"
  rh=$(jq -c -S -j '.reference' "$f"|sha); dh=$(jq -c -S -j '.direction' "$f"|sha); th=$(jq -c -S -j '.threat_scan' "$f"|sha); cth=$(jq -c -S -j '.certificate' "$f"|sha)
  tmp="$f.t"; jq --arg r "$rh" --arg d "$dh" --arg t "$th" --arg c "$cth" '.hashes.reference_sha256=$r|.hashes.direction_sha256=$d|.hashes.threat_sha256=$t|.hashes.certificate_sha256=$c' "$f" > "$tmp" && mv "$tmp" "$f"
  clh=$(jq -c -S -j 'del(.hashes.closure_sha256)' "$f"|sha)
  tmp="$f.t"; jq --arg c "$clh" '.hashes.closure_sha256=$c' "$f" > "$tmp" && mv "$tmp" "$f"
}
# build_uniform: N briefs, every brief candidate0=c0key (wins 6-1) vs candidate1=c1key.
build_uniform() { local out="$1" study="$2" run="$3" c0="$4" c1="$5" n="${6:-10}"; local briefs='[]' k b
  k=1; while [ "$k" -le "$n" ]; do b=$(mk_brief "b$k" "smb" "fin" "t$(( (k-1)%4+1 ))" "sig$k" "$c0" "$c1" 6 1); briefs=$(jq -c --argjson b "$b" '.+[$b]' <<<"$briefs"); k=$((k+1)); done
  mk_closure "$out" "$study" "$run" "HUMAN_CERTIFIED" true "$briefs"; fill_hashes "$out"; }
# build_multi: 12 briefs, winners cycle P1..P6 twice, each loser unique per (study,brief).
build_multi() { local out="$1" study="$2" run="$3"; local briefs='[]' k b w
  k=1; while [ "$k" -le 12 ]; do w="P$(( (k-1)%6+1 ))"; b=$(mk_brief "b$k" "smb" "fin" "t$(( (k-1)%4+1 ))" "sig$k" "$w" "L${study}_${k}" 6 1); briefs=$(jq -c --argjson b "$b" '.+[$b]' <<<"$briefs"); k=$((k+1)); done
  mk_closure "$out" "$study" "$run" "HUMAN_CERTIFIED" true "$briefs"; fill_hashes "$out"; }
rec() { bash "$CLI" recommend "$1" "$2" "${3:-}"; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"; mkdir -p docs/polylane

# ---- one-study overfit rejection ----
L1="docs/polylane/one.jsonl"; bash "$CLI" init "$L1" >/dev/null
build_uniform "$WORK/o1.json" one onerun P L
bash "$CLI" record "$L1" "$WORK/o1.json" >/dev/null
a=$(rec "$L1" '{"domain":"fin"}')
[ "$(echo "$a"|jq -r .status)" = insufficient ] && ok "one study alone is insufficient (overfit rejected)" || bad "overfit" "$a"

# ---- four-study support (favored) + memory-blind arms + bounded fields ----
L2="docs/polylane/four.jsonl"; bash "$CLI" init "$L2" >/dev/null
P=$(patid P)
for s in 1 2 3 4; do build_uniform "$WORK/f$s.json" "f$s" "fr$s" P "L$s" 10; bash "$CLI" record "$L2" "$WORK/f$s.json" >/dev/null; done
a=$(rec "$L2" '{"domain":"fin","task":"t1"}')
echo "$a" | jq -e --arg p "$P" '.status=="ok" and any(.lessons[];.pattern==$p and .direction=="favored")' >/dev/null \
  && ok "four studies support a favored lesson" || bad "four-study favored" "$a"
echo "$a" | jq -e '.safe_to_promote==false' >/dev/null && ok "advice never sets safe_to_promote" || bad "safe_to_promote" "$a"
echo "$a" | jq -e '.reserved_arms.memory_blind==true and .reserved_arms.wildcard==true' >/dev/null \
  && ok "a memory-blind arm and a wildcard are reserved" || bad "reserved arms" "$a"
echo "$a" | jq -e '.directions_budget.memory_blind_min>=1 and .directions_budget.wildcard_min>=1' >/dev/null \
  && ok "directions budget always leaves memory-free slots" || bad "budget" "$a"
echo "$a" | jq -e 'all(.lessons[];(.pattern|test("^pat-[0-9a-f]{24}$")))' >/dev/null \
  && ok "lessons carry opaque atom ids only" || bad "opaque atoms" "$a"

# ---- contradiction: same pattern wins in two studies, loses in two others ----
L3="docs/polylane/conflict.jsonl"; bash "$CLI" init "$L3" >/dev/null
Q=$(patid Q)
build_uniform "$WORK/cA.json" cA cAr Q LA 10; bash "$CLI" record "$L3" "$WORK/cA.json" >/dev/null
build_uniform "$WORK/cB.json" cB cBr Q LB 10; bash "$CLI" record "$L3" "$WORK/cB.json" >/dev/null
build_uniform "$WORK/cC.json" cC cCr WC Q 10; bash "$CLI" record "$L3" "$WORK/cC.json" >/dev/null
build_uniform "$WORK/cD.json" cD cDr WD Q 10; bash "$CLI" record "$L3" "$WORK/cD.json" >/dev/null
a=$(rec "$L3" '{"domain":"fin"}')
echo "$a" | jq -e --arg p "$Q" '.status=="conflicted" and any(.conflicted[];.pattern==$p)' >/dev/null \
  && ok "a pattern that both wins and loses is a contradiction, not a lesson" || bad "contradiction" "$a"

# ---- context mismatch / out-of-scope ----
a=$(rec "$L2" '{"domain":"healthcare"}')
echo "$a" | jq -e '.status=="out-of-scope" and .none==true and (.lessons|length)==0' >/dev/null \
  && ok "an unseen domain is out-of-scope with a None result" || bad "out-of-scope" "$a"

# ---- single-source (34%) cap ----
L4="docs/polylane/share.jsonl"; bash "$CLI" init "$L4" >/dev/null
build_uniform "$WORK/big.json" big bigrun P Lb 20; bash "$CLI" record "$L4" "$WORK/big.json" >/dev/null
for s in 1 2 3; do build_uniform "$WORK/sm$s.json" "sm$s" "smr$s" P "Ls$s" 10; bash "$CLI" record "$L4" "$WORK/sm$s.json" >/dev/null; done
a=$(rec "$L4" '{"domain":"fin"}')
echo "$a" | jq -e '.status=="insufficient" and .coverage.top_study_share_pct>34' >/dev/null \
  && ok "a single study over 34% of evidence blocks a lesson" || bad "34% cap" "$a"

# ---- bounded + deduplicated output ----
L5="docs/polylane/bounded.jsonl"; bash "$CLI" init "$L5" >/dev/null
for s in 1 2 3 4; do build_multi "$WORK/m$s.json" "m$s" "mr$s"; bash "$CLI" record "$L5" "$WORK/m$s.json" >/dev/null; done
a=$(rec "$L5" '{"domain":"fin"}' 2)
nl=$(echo "$a" | jq '.lessons|length')
[ "$nl" -le 2 ] && ok "lessons bounded by the requested limit ($nl<=2)" || bad "bound" "$a"
uniq=$(echo "$a" | jq '([.lessons[].pattern]) as $p | ($p|length)==($p|unique|length)')
[ "$uniq" = true ] && ok "emitted patterns are deduplicated" || bad "dedup" "$a"
bytes=$(echo -n "$a" | wc -c | tr -d ' ')
[ "$bytes" -le 8192 ] && ok "advice payload is byte-bounded ($bytes<=8192)" || bad "bytes" "$bytes"
# a huge requested limit is clamped, not honored verbatim
a=$(rec "$L5" '{"domain":"fin"}' 999)
[ "$(echo "$a"|jq '.lessons|length')" -le 8 ] && ok "an oversized limit is clamped to the hard cap" || bad "limit clamp" "$a"

# ---- explicit None: gate passes but no pattern spans >=2 studies ----
L6="docs/polylane/none.jsonl"; bash "$CLI" init "$L6" >/dev/null
for s in 1 2 3 4; do build_uniform "$WORK/n$s.json" "n$s" "nr$s" "W$s" "X$s" 10; bash "$CLI" record "$L6" "$WORK/n$s.json" >/dev/null; done
a=$(rec "$L6" '{"domain":"fin"}')
echo "$a" | jq -e '.status=="none" and .none==true and (.lessons|length)==0' >/dev/null \
  && ok "single-source-only patterns yield an explicit None result" || bad "none" "$a"

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" = 0 ]
