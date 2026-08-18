#!/usr/bin/env bash
# test-visual-taste-memory-integration.sh — taste memory sits DOWNSTREAM of the visual
# loop and can never shortcut it: it learns only from whole HUMAN_CERTIFIED studies whose
# candidates passed real capture + hard gates, it is advisory-only (never authorises
# promotion), and it always preserves a memory-blind arm + wildcard so the tournament
# keeps exploring. Nothing here re-implements capture/certification — it proves memory
# cannot bypass them.
set -euo pipefail

ROOT="${POLYLANE_SOURCE_ROOT:-$PWD}"
CLI="$ROOT/bin/polylane-taste-memory.sh"
[ -f "$CLI" ] || { echo "missing CLI: $CLI" >&2; exit 1; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf 'ok   - %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL - %s (%s)\n' "$1" "${2:-}"; }
run_no(){ if bash "$CLI" "$@" >/dev/null 2>&1; then return 1; else return 0; fi; }

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
fill_hashes() {
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
build_uniform() { local out="$1" study="$2" run="$3" c0="$4" c1="$5" n="${6:-10}" label="${7:-HUMAN_CERTIFIED}" human="${8:-true}"; local briefs='[]' k b
  k=1; while [ "$k" -le "$n" ]; do b=$(mk_brief "b$k" "smb" "fin" "t$(( (k-1)%4+1 ))" "sig$k" "$c0" "$c1" 6 1); briefs=$(jq -c --argjson b "$b" '.+[$b]' <<<"$briefs"); k=$((k+1)); done
  mk_closure "$out" "$study" "$run" "$label" "$human" "$briefs"; fill_hashes "$out"; }
rec() { bash "$CLI" recommend "$1" "$2" "${3:-}"; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"; mkdir -p docs/polylane
LED="docs/polylane/visual-taste.jsonl"; bash "$CLI" init "$LED" >/dev/null

# 1. memory can NEVER learn from a machine-only study — no certification bypass
build_uniform "$WORK/mach.json" ms mr P L 10 MACHINE_EVALUATED false
run_no record "$LED" "$WORK/mach.json" && ok "MACHINE_EVALUATED visual study is not admissible (no cert bypass)" || bad "machine bypass"
build_uniform "$WORK/cal.json" cs cr P L 10 HUMAN_CALIBRATED_MACHINE false
run_no record "$LED" "$WORK/cal.json" && ok "HUMAN_CALIBRATED_MACHINE study is not admissible" || bad "calibrated bypass"
# a study that claims human_certified but with a machine label is still rejected
build_uniform "$WORK/spoof.json" sp spr P L 10 MACHINE_EVALUATED true
run_no record "$LED" "$WORK/spoof.json" && ok "machine label + human_certified:true is still rejected" || bad "spoof label"

# 2. memory can NEVER learn from an uncaptured/failed-capture study — no capture bypass
build_uniform "$WORK/nocap.json" nc ncr P L 10
jq '.briefs[0].candidates[0].hard_gate.capture="unknown"' "$WORK/nocap.json" > "$WORK/nocap2.json"; fill_hashes "$WORK/nocap2.json"
run_no record "$LED" "$WORK/nocap2.json" && ok "a candidate without a passing capture gate blocks admission" || bad "capture gate"
build_uniform "$WORK/miss.json" mi mir P L 10
jq 'del(.briefs[0].candidates[0].capture)' "$WORK/miss.json" > "$WORK/miss2.json"   # drop capture bytes, keep stale hash
run_no record "$LED" "$WORK/miss2.json" && ok "missing capture evidence fails the recomputed hash chain" || bad "missing capture"
build_uniform "$WORK/a11y.json" ay ayr P L 10
jq '.certificate.accessibility_regressions=1' "$WORK/a11y.json" > "$WORK/a11y2.json"; fill_hashes "$WORK/a11y2.json"
run_no record "$LED" "$WORK/a11y2.json" && ok "an accessibility regression blocks admission" || bad "a11y regression"

# the ledger is still empty of observations — nothing bypassed capture/certification
[ "$(jq -s length "$LED")" = 1 ] && ok "no non-certified/uncaptured study left a memory row" || bad "leak: $(jq -s length "$LED")"

# 3. a real, captured, HUMAN_CERTIFIED corpus DOES train memory (positive control)
P=$(patid P)
for s in 1 2 3 4; do build_uniform "$WORK/g$s.json" "g$s" "gr$s" P "loser$s" 10; bash "$CLI" record "$LED" "$WORK/g$s.json" >/dev/null; done
bash "$CLI" audit "$LED" >/dev/null && ok "certified captured corpus audits clean" || bad "audit"
a=$(rec "$LED" '{"domain":"fin","task":"t1"}')
echo "$a" | jq -e --arg p "$P" '.status=="ok" and any(.lessons[];.pattern==$p and .direction=="favored")' >/dev/null \
  && ok "memory returns a favored lesson from the certified corpus" || bad "favored" "$a"

# 4. memory is advisory only — it can NEVER authorise promotion or replace certification
echo "$a" | jq -e '.safe_to_promote==false' >/dev/null \
  && ok "advice sets safe_to_promote:false (never authorises promotion)" || bad "safe_to_promote" "$a"
echo "$a" | jq -e 'has("certified")|not' >/dev/null \
  && ok "advice carries no certification claim" || bad "no certified key" "$a"
# lessons expose ONLY opaque atoms — no capture/pixel/screenshot payload to shortcut with
echo "$a" | jq -e 'all(.lessons[]; keys - ["pattern","direction","observations","studies","briefs","same_sign","wilson_lcb"] | length==0)' >/dev/null \
  && ok "lessons expose only opaque taxonomy atoms (no capture/pixel payload)" || bad "opaque only" "$a"
echo "$a" | jq -e '[.. | strings] | all(test("screenshot|png|http|data:|<script")|not)' >/dev/null \
  && ok "advice contains no raw web/asset/instruction strings" || bad "raw strings" "$a"

# 5. memory-blind arm + wildcard are always preserved so the tournament keeps exploring
echo "$a" | jq -e '.reserved_arms.memory_blind==true and .reserved_arms.wildcard==true' >/dev/null \
  && ok "a memory-blind arm and a wildcard are reserved on every recommendation" || bad "reserved arms" "$a"
echo "$a" | jq -e '.directions_budget.memory_blind_min>=1 and .directions_budget.wildcard_min>=1' >/dev/null \
  && ok "the directions budget always leaves >=1 memory-blind and >=1 wildcard slot" || bad "budget" "$a"

# no command in this lane edits an installed skill or global memory
skill_writes=$(grep -REn "\.claude/skills|\.codex/plugins|/CLAUDE.md|global memory" "$ROOT/bin/polylane-taste-memory.sh" || true)
[ -z "$skill_writes" ] && ok "the CLI never references installed skills or global memory" || bad "skill/global write ref" "$skill_writes"

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" = 0 ]
