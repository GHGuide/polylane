#!/usr/bin/env bash
# Regression test for defect c42b-optimized-prompt-deletion.
#
# Required v3 control (EVIDENCE-CLAIM-REGISTRY.v3.json, boundary "prompt
# promotion artifact retention"):
#   "The frozen finalist prompt bytes and their source, compiled, delivered,
#    and consumed receipt chain remain immutable and addressable after
#    promotion."
#
# bin/polylane-taste-prompts.sh promotes a finalist pair by writing
# baseline.md/current.md plus receipt.json. This test pins that the promotion
# also retains every stage of the chain in a content-addressed, read-only store
# under <out>/artifacts/<sha256>, that receipt.json addresses all four stages,
# and that `verify` fails if any retained artifact is deleted or mutated.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROMPTS="$ROOT/bin/polylane-taste-prompts.sh"
TEMPLATES="$ROOT/benchmarks/taste-live/prompts"

sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
chain_sha() { jq -r --arg n "$2" '.retention.chain[] | select(.name == $n) | .sha256' "$1"; }
chain_stage() { jq -r --arg n "$2" '.retention.chain[] | select(.name == $n) | .stage' "$1"; }

make_tmpdir
W="$TEST_TMPDIR"

cat > "$W/brief.md" <<'BRIEF'
# Pantry Planner

A household plans meals from what is already on the shelf.

- add items with quantity and expiry
- warn when an ingredient expires within three days
BRIEF

cat > "$W/oracle.json" <<'ORACLE'
{"schema_version":"taste-task-oracle/v1","brief_id":"pantry-planner",
 "actions":[{"step":1,"do":"add item 'rice' quantity 2 expiry 2026-08-14"},
            {"step":2,"do":"open the expiry view"}],
 "assertions":[{"after_step":2,"expect":"rice appears in the expiring-soon list"}],
 "states":["default","loading","empty","error","hover","focus"]}
ORACLE

jq -n '
  {schema_version:"taste-reference-packet/v1",brief_id:"pantry-planner",category:"consumer",
   references:([
     {role:"category",category:"consumer",url:"https://example.com/a",licence:"observed-ui/no-assets-copied",
      observed:"inventory list with expiry badges",accessed:"2026-08-10",
      screenshot_sha256:("a"*64),provenance:"manual capture, research ledger row 1",
      borrow:"expiry badge grouping",transform:"flatten the shelf grid into a single expiry timeline",
      avoid:"their brand mark and mascot"},
     {role:"category",category:"consumer",url:"https://example.com/b",licence:"observed-ui/no-assets-copied",
      observed:"quantity stepper on cards",accessed:"2026-08-10",
      screenshot_sha256:("b"*64),provenance:"manual capture, research ledger row 2",
      borrow:"inline quantity edit",transform:"move edit into a keyboard-first row",avoid:"their pastel palette"},
     {role:"category",category:"consumer",url:"https://example.com/c",licence:"observed-ui/no-assets-copied",
      observed:"empty state with first-run task",accessed:"2026-08-11",
      screenshot_sha256:("c"*64),provenance:"manual capture, research ledger row 3",
      borrow:"first-run add flow",transform:"seed from a paste-a-receipt action",avoid:"their illustration set"},
     {role:"wildcard",category:"logistics",url:"https://example.com/d",licence:"observed-ui/no-assets-copied",
      observed:"warehouse aging report",accessed:"2026-08-11",
      screenshot_sha256:("d"*64),provenance:"manual capture, research ledger row 4",
      borrow:"age-bucket coloring",transform:"apply buckets to food expiry, not pallets",
      avoid:"dense enterprise chrome"}
   ])}' > "$W/packet.json"

jq -n --arg brief "$W/brief.md" --arg oracle "$W/oracle.json" --arg packet "$W/packet.json" '
  {schema_version:"taste-prompt-spec/v1",run_id:"c44-defect-controls-20260819-a1",
   brief:{id:"pantry-planner",category:"consumer",path:$brief},
   goal:"One command turns a vague project idea into a distinctive, functional, verified outcome.",
   subgoal:"Immutable addressable retention of promoted finalist prompts.",
   builder:{model:"claude-fable-5",effort:"xhigh"},
   task_oracle:$oracle,
   output_root:"benchmarks/taste-live/candidates/pantry-planner",
   incumbent:"none",
   reference_packet:$packet}' > "$W/spec.json"

OUT="$W/out"
assert_ok compile-promotes bash "$PROMPTS" compile "$W/spec.json" "$OUT"

# --- nothing in the chain is deleted after promotion --------------------------
for f in baseline.md current.md receipt.json \
         baseline.optimized.md current.optimized.md consumed-receipt.json; do
  assert_ok "retained-$f" test -f "$OUT/$f"
done
assert_ok retention-store-exists test -d "$OUT/artifacts"

# --- the receipt addresses all four chain stages ------------------------------
assert_ok retention-declared jq -e '.retention.store == "artifacts"
  and .retention.addressing == "sha256" and .retention.immutable == true' "$OUT/receipt.json"
assert_eq retention-stage-set '["compiled","consumed","delivered","source"]' \
  "$(jq -c '[.retention.chain[].stage] | unique' "$OUT/receipt.json")"

assert_eq chain-source-spec "$(sha256 "$W/spec.json")" "$(chain_sha "$OUT/receipt.json" spec.json)"
assert_eq chain-source-brief "$(sha256 "$W/brief.md")" "$(chain_sha "$OUT/receipt.json" brief)"
assert_eq chain-source-oracle "$(sha256 "$W/oracle.json")" "$(chain_sha "$OUT/receipt.json" task-oracle)"
assert_eq chain-source-packet "$(sha256 "$W/packet.json")" "$(chain_sha "$OUT/receipt.json" reference-packet)"
assert_eq chain-source-baseline-template "$(sha256 "$TEMPLATES/baseline-builder.md")" \
  "$(chain_sha "$OUT/receipt.json" baseline-builder.md)"
assert_eq chain-source-current-template "$(sha256 "$TEMPLATES/current-builder.md")" \
  "$(chain_sha "$OUT/receipt.json" current-builder.md)"

assert_eq chain-compiled-baseline "$(sha256 "$OUT/baseline.md")" "$(chain_sha "$OUT/receipt.json" baseline.md)"
assert_eq chain-compiled-current "$(sha256 "$OUT/current.md")" "$(chain_sha "$OUT/receipt.json" current.md)"
assert_eq chain-compiled-matches-receipt-baseline "$(jq -r .baseline.prompt_sha256 "$OUT/receipt.json")" \
  "$(chain_sha "$OUT/receipt.json" baseline.md)"
assert_eq chain-compiled-matches-receipt-current "$(jq -r .current.prompt_sha256 "$OUT/receipt.json")" \
  "$(chain_sha "$OUT/receipt.json" current.md)"

assert_eq chain-delivered-baseline "$(sha256 "$OUT/baseline.optimized.md")" \
  "$(chain_sha "$OUT/receipt.json" baseline.optimized.md)"
assert_eq chain-delivered-current "$(sha256 "$OUT/current.optimized.md")" \
  "$(chain_sha "$OUT/receipt.json" current.optimized.md)"
assert_eq chain-delivered-stage delivered "$(chain_stage "$OUT/receipt.json" current.optimized.md)"
assert_eq chain-consumed-stage consumed "$(chain_stage "$OUT/receipt.json" consumed-receipt.json)"
assert_eq chain-consumed-receipt "$(sha256 "$OUT/consumed-receipt.json")" \
  "$(chain_sha "$OUT/receipt.json" consumed-receipt.json)"

# --- the consumed receipt binds the exact delivered bytes ---------------------
assert_ok consumed-schema jq -e '.schema_version == "taste-prompt-consumed/v1"' "$OUT/consumed-receipt.json"
for arm in baseline current; do
  assert_eq "consumed-binds-$arm-digest" "$(sha256 "$OUT/$arm.optimized.md")" \
    "$(jq -r --arg a "$arm" '.consumed[] | select(.arm == $a) | .delivered_sha256' "$OUT/consumed-receipt.json")"
  assert_eq "consumed-binds-$arm-bytes" "$(wc -c < "$OUT/$arm.optimized.md" | tr -d '[:space:]')" \
    "$(jq -r --arg a "$arm" '.consumed[] | select(.arm == $a) | .delivered_bytes' "$OUT/consumed-receipt.json")"
done

# --- every chain address is resolvable and self-describing --------------------
missing=0; mismatched=0; writable=0
for sha in $(jq -r '.retention.chain[].sha256' "$OUT/receipt.json"); do
  f="$OUT/artifacts/$sha"
  if [ ! -f "$f" ] || [ -L "$f" ]; then missing=$((missing + 1)); continue; fi
  [ "$(sha256 "$f")" = "$sha" ] || mismatched=$((mismatched + 1))
  [ ! -w "$f" ] || writable=$((writable + 1))
done
assert_eq every-address-resolves 0 "$missing"
assert_eq every-address-matches-its-bytes 0 "$mismatched"
assert_eq every-address-is-read-only 0 "$writable"

# --- verify accepts an intact promotion, rejects a broken chain ---------------
assert_ok verify-intact bash "$PROMPTS" verify "$OUT"

cp -R "$OUT" "$W/deleted"; chmod -R u+w "$W/deleted"
rm -f "$W/deleted/artifacts/$(chain_sha "$OUT/receipt.json" current.optimized.md)"
assert_fail verify-detects-deleted-retained-artifact bash "$PROMPTS" verify "$W/deleted"

cp -R "$OUT" "$W/dropped"; chmod -R u+w "$W/dropped"
rm -f "$W/dropped/current.optimized.md"
assert_fail verify-detects-deleted-delivered-prompt bash "$PROMPTS" verify "$W/dropped"

cp -R "$OUT" "$W/mutated"; chmod -R u+w "$W/mutated"
printf 'x' >> "$W/mutated/artifacts/$(chain_sha "$OUT/receipt.json" current.md)"
assert_fail verify-detects-mutated-retained-artifact bash "$PROMPTS" verify "$W/mutated"

cp -R "$OUT" "$W/noconsumed"; chmod -R u+w "$W/noconsumed"
rm -f "$W/noconsumed/consumed-receipt.json"
assert_fail verify-detects-deleted-consumed-receipt bash "$PROMPTS" verify "$W/noconsumed"

# --- re-promotion is addressable to the same content --------------------------
OUT2="$W/out2"
assert_ok compile-again bash "$PROMPTS" compile "$W/spec.json" "$OUT2"
assert_eq retention-chain-deterministic "$(jq -cS .retention "$OUT/receipt.json")" \
  "$(jq -cS .retention "$OUT2/receipt.json")"
assert_ok recompile-into-same-dir bash "$PROMPTS" compile "$W/spec.json" "$OUT"
assert_ok verify-after-recompile bash "$PROMPTS" verify "$OUT"

finish
