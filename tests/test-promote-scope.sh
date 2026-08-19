#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034 # sourced runner consumes fixture globals
# PROMOTE SCOPE — the promoter stages runner-owned state and refuses everything
# else. Both halves matter: staging user source would silently promote work the
# cycle never verified, while refusing the runner's OWN leftover evidence
# deadlocks a verified promotion (live 2026-08-19: c43e's passing host gate was
# blocked by c43/c43c/c43d host-gate records still untracked in the base).
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

RUN_ID=cur-run
LANE_NAMES=(builder integrator)

owned()   { assert_ok   "owned-$2"   runner_owned_promotion_path "$1"; }
refused() { assert_fail "refused-$2" runner_owned_promotion_path "$1"; }

# --- runner state ------------------------------------------------------------
owned docs/polylane/max-state.json                       max-state
owned docs/polylane/run-stats.json                       run-stats
owned docs/polylane/spend-ledger.jsonl                   spend-ledger
owned docs/polylane/outcome-receipts/cur-run.json        current-outcome-receipt
owned docs/polylane/skill-outcomes.jsonl                 skill-outcomes

# --- host-gate evidence: any run id, exact runner filenames ------------------
owned docs/polylane/host-gate-failures/cur-run.md              current-gate-record
owned docs/polylane/host-gate-failures/cur-run.acceptance.jsonl current-gate-acceptance
owned docs/polylane/host-gate-failures/c43-older-run.md         prior-run-gate-record
refused docs/polylane/host-gate-failures/nested/x.md            gate-nested-path
refused docs/polylane/host-gate-failures/notes.txt              gate-foreign-extension
refused docs/polylane/host-gate-failures/evil/../../../etc/passwd gate-traversal

# --- skill-use receipts: exact <run-id>/<lane>.json shape only ---------------
owned docs/polylane/skill-use/cur-run/builder.json       current-run-receipt
owned docs/polylane/skill-use/old-run/otherlane.json     prior-run-receipt
refused docs/polylane/skill-use/old-run/deep/x.json      receipt-nested-path
refused docs/polylane/skill-use/old-run/evil.sh          receipt-foreign-extension
refused docs/polylane/skill-use/loose.json               receipt-missing-run-dir

# --- user source is NEVER runner-owned ---------------------------------------
refused bin/polylane-run.sh    runner-source
refused SKILL.md               skill-doc
refused tests/run.sh           test-harness
refused docs/polylane/cycle-43-plan.md cycle-plan
refused docs/verify-integration.md     integrator-evidence

finish
