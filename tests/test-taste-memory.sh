#!/usr/bin/env bash
# test-taste-memory.sh — core behaviour of the taste-memory CLI:
#   project rooting, whole-study atomicity, HUMAN_CALIBRATED rejection,
#   tie / hard-fail rejection, concurrent idempotent writes, four-study support.
set -euo pipefail

ROOT="${POLYLANE_SOURCE_ROOT:-$PWD}"
CLI="$ROOT/bin/polylane-taste-memory.sh"
[ -f "$CLI" ] || { echo "missing CLI: $CLI" >&2; exit 1; }

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf 'ok   - %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL - %s\n' "$1"; }
run_ok(){ if bash "$CLI" "$@" >/dev/null 2>&1; then return 0; else return 1; fi; }
run_no(){ if bash "$CLI" "$@" >/dev/null 2>&1; then return 1; else return 0; fi; }

# ---- fixture generator (mirrors the CLI's canonical hashing exactly) ----
canon() { jq -S -c -j "$@"; }
sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256|awk '{print $1}'; else sha256sum|awk '{print $1}'; fi; }
facets() { jq -n -c --arg lf "$1" '{layout_family:$lf,density_band:"std",navigation_archetype:"top",primary_information_unit:"card",palette_family:"cool",type_pair_class:"sans",shape_language:"round"}'; }
mk_candidate() { jq -n -c --argjson f "$1" --arg n "$2" '{facets:$f,capture:{route:"/x",state:"default",viewport:"1440x900",decoded:true,nonce:$n},pixel:{width:1440,height:900,distinct:true,nonce:$n},hard_gate:{function:"pass",accessibility:"pass",capture:"pass",context:"pass",provenance:"pass",overall:"PASS"},hashes:{capture_sha256:"",pixel_sha256:"",hard_gate_sha256:"",candidate_sha256:""}}'; }
mk_brief() { # br aud dom task sig c0key c1key w0 w1
  local c0 c1; c0=$(mk_candidate "$(facets "$6")" "$1a"); c1=$(mk_candidate "$(facets "$7")" "$1b")
  jq -n -c --arg br "$1" --arg aud "$2" --arg dom "$3" --arg task "$4" --arg sig "$5" \
    --argjson c0 "$c0" --argjson c1 "$c1" --argjson w0 "$8" --argjson w1 "$9" \
    '{brief_ref:$br,tags:{audience:$aud,domain:$dom,task:$task},product_signature:$sig,candidates:[$c0,$c1],aggregate:{candidate_group_wins:[$w0,$w1],ties:0,resolved_groups:($w0+$w1)},aggregate_sha256:""}'; }
mk_closure() { # out study run label human briefsjson
  jq -n -S --arg study "$2" --arg run "$3" --arg label "$4" --argjson human "$5" --argjson briefs "$6" \
    '{schema_version:"taste-study-closure/v1",study_id:$study,run_id:$run,closed_at:"2026-08-12T00:00:00Z",claim_label:$label,human_certified:$human,reference:{same_category:3,wildcard:1},direction:{cards:3},threat_scan:{leakage:"none",injection:"none",ocr_dom_scan:"pass"},briefs:$briefs,certificate:{briefs:($briefs|length),brief_wins:($briefs|length),preference_rate:0.9,confidence_lower:0.7,accessibility_regressions:0},hashes:{reference_sha256:"",direction_sha256:"",threat_sha256:"",certificate_sha256:"",closure_sha256:""}}' > "$1"; }
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
# build a study: 10 briefs, tasks t1..t4 cycled, candidate0 (winkey) wins 6-1.
build_study() { # out study run winkey [label] [c1prefix]
  local out="$1" study="$2" run="$3" wk="$4" label="${5:-HUMAN_CERTIFIED}" lp="${6:-lose}"
  local briefs='[]' k b
  for k in 1 2 3 4 5 6 7 8 9 10; do
    b=$(mk_brief "b$k" "smb" "fin" "t$(( (k-1)%4+1 ))" "sig$k" "$wk" "$lp$k" 6 1)
    briefs=$(jq -c --argjson b "$b" '.+[$b]' <<<"$briefs")
  done
  mk_closure "$out" "$study" "$run" "$label" true "$briefs"
  fill_hashes "$out"
}

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"; mkdir -p docs/polylane sub/docs/polylane
LED="docs/polylane/taste-memory.jsonl"

# 1. project rooting
run_ok init "$LED" && [ -f "$LED" ] && ok "init creates a project-rooted ledger" || bad "init"
run_no init "logs/taste.jsonl"        && ok "init rejects a non-docs/polylane path" || bad "init rejects non-rooted path"
run_no init "docs/polylane/../../etc/x.jsonl" && ok "init rejects traversal in path" || bad "init rejects traversal"
ln -s /etc "$WORK/docs/polylane/evil" 2>/dev/null || true
run_no init "docs/polylane/evil/x.jsonl" && ok "init rejects a symlinked path component" || bad "init rejects symlink component"

# 2. whole-study admission + audit + atomicity
build_study "$WORK/s1.json" study1 run1 winA
run_ok record "$LED" "$WORK/s1.json" && ok "record admits a whole HUMAN_CERTIFIED study" || bad "record valid study"
[ "$(jq -s length "$LED")" = 11 ] && ok "whole study appended as 10 rows + genesis" || bad "row count $(jq -s length "$LED")"
run_ok audit "$LED" && ok "audit passes on a clean ledger" || bad "audit clean"

# 3. HUMAN_CALIBRATED / MACHINE_EVALUATED are diagnostics, never admitted
build_study "$WORK/mc.json" study2 run2 winB HUMAN_CALIBRATED_MACHINE
run_no record "$LED" "$WORK/mc.json" && ok "HUMAN_CALIBRATED_MACHINE study rejected" || bad "reject calibrated"
build_study "$WORK/me.json" study3 run3 winB MACHINE_EVALUATED
run_no record "$LED" "$WORK/me.json" && ok "MACHINE_EVALUATED study rejected" || bad "reject machine-evaluated"

# 4. tie rejection (no strict winner) — mutate one brief to a tie, rehash
build_study "$WORK/tie.json" study4 run4 winC
jq '.briefs[0].aggregate={candidate_group_wins:[3,3],ties:0,resolved_groups:6}' "$WORK/tie.json" > "$WORK/tie2.json"
fill_hashes "$WORK/tie2.json"
run_no record "$LED" "$WORK/tie2.json" && ok "tie brief rejected (no strict winner)" || bad "reject tie"

# 5. hard-fail rejection — a candidate fails an accessibility gate
build_study "$WORK/hf.json" study5 run5 winD
jq '.briefs[0].candidates[1].hard_gate.accessibility="fail"' "$WORK/hf.json" > "$WORK/hf2.json"
fill_hashes "$WORK/hf2.json"
run_no record "$LED" "$WORK/hf2.json" && ok "study with a failed hard gate rejected" || bad "reject hard-fail"

# atomicity: none of the rejected studies left any rows behind
[ "$(jq -s length "$LED")" = 11 ] && ok "rejected studies leave the ledger unchanged (atomic)" || bad "atomicity: $(jq -s length "$LED")"

# 6. concurrent idempotent writes of the SAME study -> exactly one copy
LED2="docs/polylane/concurrent.jsonl"
run_ok init "$LED2"
build_study "$WORK/c.json" studyC runC winE
bash "$CLI" record "$LED2" "$WORK/c.json" >/dev/null 2>&1 &
bash "$CLI" record "$LED2" "$WORK/c.json" >/dev/null 2>&1 &
wait
n=$(jq -s length "$LED2")
[ "$n" = 11 ] && ok "concurrent idempotent writes yield one copy (10 rows + genesis)" || bad "concurrent produced $n rows"
run_ok audit "$LED2" && ok "audit passes after concurrent writes" || bad "audit after concurrent"

# 7. four-study support -> a favored lesson for the shared winning pattern
LED3="docs/polylane/support.jsonl"
run_ok init "$LED3"
WPAT="pat-$(facets winA | jq -S -c -j . | sha | cut -c1-24)"
for s in 1 2 3 4; do
  build_study "$WORK/sup$s.json" "sup$s" "supr$s" winA HUMAN_CERTIFIED "los${s}_"
  bash "$CLI" record "$LED3" "$WORK/sup$s.json" >/dev/null 2>&1
done
adv=$(bash "$CLI" recommend "$LED3" '{"domain":"fin","task":"t1"}')
echo "$adv" | jq -e --arg p "$WPAT" '.status=="ok" and any(.lessons[]; .pattern==$p and .direction=="favored")' >/dev/null \
  && ok "four studies yield a favored lesson for the shared pattern" || bad "four-study favored ($adv)"

echo "----"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = 0 ]
