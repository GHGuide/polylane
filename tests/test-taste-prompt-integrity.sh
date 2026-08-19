#!/usr/bin/env bash
# Regression test for defect c42b-unsafe-whole-document-prompt-dedupe.
#
# Required v3 control (EVIDENCE-CLAIM-REGISTRY.v3.json, boundary "prompt
# compilation"):
#   "Deduplication is restricted to typed sections and cannot alter mandatory
#    locked bytes."
#
# The v3 schemas define neither "typed section" nor "mandatory locked byte", so
# bin/polylane-taste-prompts.sh defines both narrowly and this test pins those
# definitions:
#   - a TYPED SECTION is a fenced region of a compiled prompt (=== NAME === /
#     === END NAME ===, BRIEF-BEGIN/END, TASK-ORACLE-BEGIN/END,
#     REF-PACKET-BEGIN/END);
#   - the MANDATORY LOCKED BYTES are every byte of the five locked typed
#     sections whose digests the receipt freezes: the quoted brief, the quoted
#     task oracle, the quoted reference packet, the pinned baseline material,
#     and the design lock.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROMPTS="$ROOT/bin/polylane-taste-prompts.sh"
PROMPTOPT="$ROOT/bin/polylane-promptopt.sh"

sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
bytes_of() { wc -c < "$1" | tr -d '[:space:]'; }

brief_block()    { sed -n '/^BRIEF-BEGIN /,/^BRIEF-END$/p' "$1"; }
oracle_block()   { sed -n '/^TASK-ORACLE-BEGIN /,/^TASK-ORACLE-END$/p' "$1"; }
packet_block()   { sed -n '/^REF-PACKET-BEGIN /,/^REF-PACKET-END$/p' "$1"; }
material_block() { sed -n '/^=== BASELINE MATERIAL ===$/,/^=== END BASELINE MATERIAL ===$/p' "$1"; }
lock_block()     { sed -n '/^=== DESIGN LOCK ===$/,/^=== END DESIGN LOCK ===$/p' "$1"; }

make_tmpdir
W="$TEST_TMPDIR"

# --- unit: section-scoped deduplication ---------------------------------------
# Source the compiler for its typed-section primitives; its main is guarded by
# BASH_SOURCE, so sourcing runs nothing.
# shellcheck source=/dev/null
. "$PROMPTS"

cat > "$W/synthetic.md" <<'SYN'
=== SHARED CONTRACT ===
alpha
alpha
BRIEF-BEGIN id=x sha256=y
| dup
| dup
| alpha
BRIEF-END
=== END SHARED CONTRACT ===

=== METHOD: X ===
alpha
=== END METHOD ===
SYN

dedupe_typed "$W/synthetic.md" > "$W/synthetic.out" 2>/dev/null || true

# `alpha` appears twice in SHARED CONTRACT and once in METHOD: X. Section-scoped
# deduplication collapses the in-section repeat and keeps the other section's
# copy, so exactly two survive. Whole-document deduplication leaves one.
alpha_total=$(grep -cx 'alpha' "$W/synthetic.out" 2>/dev/null || true)
assert_eq dedupe-section-scoped-alpha-count 2 "${alpha_total:-0}"
dup_total=$(grep -cxF '| dup' "$W/synthetic.out" 2>/dev/null || true)
assert_eq dedupe-skips-locked-section-entirely 2 "${dup_total:-0}"
locked_alpha=$(brief_block "$W/synthetic.out" | grep -cxF '| alpha' 2>/dev/null || true)
assert_eq dedupe-locked-line-survives-prose-collision 1 "${locked_alpha:-0}"

locked_src=$(locked_bytes "$W/synthetic.md")
locked_out=$(locked_bytes "$W/synthetic.out")
assert_eq locked-bytes-identical-after-dedupe "$locked_src" "$locked_out"
assert_ok locked-bytes-nonempty test -n "$locked_src"

# --- fixtures -----------------------------------------------------------------
# COLLISION is byte-identical in the brief and in the task oracle: two distinct
# locked typed sections. Whole-document deduplication deletes the second copy.
COLLISION=' "states":["default","loading","empty","error","hover","focus"]}'
DUPED='- warn when an ingredient expires within three days'

cat > "$W/brief.md" <<BRIEF
# Pantry Planner

A household plans meals from what is already on the shelf.

- add items with quantity and expiry
$DUPED
$DUPED
$COLLISION
BRIEF

cat > "$W/oracle.json" <<ORACLE
{"schema_version":"taste-task-oracle/v1","brief_id":"pantry-planner",
 "actions":[{"step":1,"do":"add item 'rice' quantity 2 expiry 2026-08-14"},
            {"step":2,"do":"open the expiry view"}],
 "assertions":[{"after_step":2,"expect":"rice appears in the expiring-soon list"}],
$COLLISION
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
   subgoal:"Typed-section deduplication that cannot alter mandatory locked bytes.",
   builder:{model:"claude-fable-5",effort:"xhigh"},
   task_oracle:$oracle,
   output_root:"benchmarks/taste-live/candidates/pantry-planner",
   incumbent:"none",
   reference_packet:$packet}' > "$W/spec.json"

# --- integration: compile, then inspect the delivered bytes -------------------
OUT="$W/out"
assert_ok compile-happy-path bash "$PROMPTS" compile "$W/spec.json" "$OUT"

for arm in baseline current; do
  assert_ok "$arm-delivered-artifact-exists" test -f "$OUT/$arm.optimized.md"
done

# Mandatory locked bytes are byte-identical between the compiled prompt and the
# delivered (deduplicated) prompt, section by section.
assert_eq baseline-brief-bytes-unaltered \
  "$(brief_block "$OUT/baseline.md")" "$(brief_block "$OUT/baseline.optimized.md")"
assert_eq baseline-oracle-bytes-unaltered \
  "$(oracle_block "$OUT/baseline.md")" "$(oracle_block "$OUT/baseline.optimized.md")"
assert_eq baseline-material-bytes-unaltered \
  "$(material_block "$OUT/baseline.md")" "$(material_block "$OUT/baseline.optimized.md")"
assert_eq current-brief-bytes-unaltered \
  "$(brief_block "$OUT/current.md")" "$(brief_block "$OUT/current.optimized.md")"
assert_eq current-oracle-bytes-unaltered \
  "$(oracle_block "$OUT/current.md")" "$(oracle_block "$OUT/current.optimized.md")"
assert_eq current-packet-bytes-unaltered \
  "$(packet_block "$OUT/current.md")" "$(packet_block "$OUT/current.optimized.md")"
assert_eq current-design-lock-bytes-unaltered \
  "$(lock_block "$OUT/current.md")" "$(lock_block "$OUT/current.optimized.md")"

# The exact hazards the defect names.
for arm in baseline current; do
  n=$(brief_block "$OUT/$arm.optimized.md" | grep -cF -- "| $DUPED" || true)
  assert_eq "$arm-repeated-brief-clause-survives" 2 "${n:-0}"
  b=$(brief_block "$OUT/$arm.optimized.md" | grep -cF -- "| $COLLISION" || true)
  o=$(oracle_block "$OUT/$arm.optimized.md" | grep -cF -- "| $COLLISION" || true)
  assert_eq "$arm-collision-kept-in-brief" 1 "${b:-0}"
  assert_eq "$arm-collision-kept-in-oracle" 1 "${o:-0}"
done

# The receipt's frozen digests still describe the delivered locked bytes.
assert_eq brief-digest-still-frozen "$(sha256 "$W/brief.md")" "$(jq -r .brief.sha256 "$OUT/receipt.json")"
assert_eq packet-digest-still-frozen \
  "$(jq -cS . "$W/packet.json" | shasum -a 256 | awk '{print $1}')" \
  "$(jq -r .current.ref_packet_sha256 "$OUT/receipt.json")"
assert_eq design-lock-digest-still-frozen \
  "$(lock_block "$OUT/current.optimized.md" | shasum -a 256 | awk '{print $1}')" \
  "$(jq -r .current.design_lock_sha256 "$OUT/receipt.json")"

# Deduplication is still doing work, and no locked scalar moved.
for arm in baseline current; do
  raw=$(bytes_of "$OUT/$arm.md"); opt=$(bytes_of "$OUT/$arm.optimized.md")
  if [ "$opt" -le "$raw" ]; then pass "$arm-optimization-never-grows"
  else fail "$arm-optimization-never-grows" "delivered $opt bytes vs compiled $raw bytes"; fi
  assert_ok "$arm-no-locked-scalar-change" bash "$PROMPTOPT" compare "$OUT/$arm.md" "$OUT/$arm.optimized.md"
  assert_ok "$arm-delivered-passes-promptopt" bash "$PROMPTOPT" check "$OUT/$arm.optimized.md" 16000
done

assert_eq receipt-optimization-baseline no-scalar-change "$(jq -r .baseline.optimization "$OUT/receipt.json")"
assert_eq receipt-optimization-current no-scalar-change "$(jq -r .current.optimization "$OUT/receipt.json")"

# --- verify rejects a delivered prompt whose locked bytes were edited ---------
assert_ok verify-intact bash "$PROMPTS" verify "$OUT"
cp -R "$OUT" "$W/tampered"
chmod -R u+w "$W/tampered"
grep -vF -- "| $COLLISION" "$W/tampered/current.optimized.md" > "$W/tampered/current.optimized.md.new"
mv "$W/tampered/current.optimized.md.new" "$W/tampered/current.optimized.md"
assert_fail verify-detects-locked-byte-edit bash "$PROMPTS" verify "$W/tampered"

finish
