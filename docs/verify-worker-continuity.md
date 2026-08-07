# Worker continuity verification

Implementation commit: `3b64f89a2082d0efbc41c6839c81cc5163fe67ae`.

## RED then GREEN

The test-first credential-storage case initially produced the required RED run:

```text
FAIL workers-capsule-rejects-secret — expected non-zero rc, got 0
FAIL workers-secret-rejects-write — expected [no] got [yes]
test-workers.sh: 38 pass, 3 fail
```

The runtime now rejects credential-shaped content before persisting capsule
fields, durable messages, or imported relay records.  The final focused run was
green: `bash tests/test-workers.sh` reported **45 pass, 0 fail**.

The mandatory static gates also passed:

```text
bash -n bin/polylane-workers.sh
shellcheck -S warning bin/polylane-workers.sh
```

## Durable API

All state is rooted below the explicitly supplied canonical project at
`docs/polylane/workers/`; writes take one directory lock and append one JSONL
history event. Reads never create a missing runtime or identity.

```bash
# Create version 1, then update it only if version 1 is still current.
bin/polylane-workers.sh capsule "$PROJECT" alpha 0 builder 11 active \
  'public API stable' 'read relay and focused tests' 'bash tests/test-workers.sh'
bin/polylane-workers.sh capsule "$PROJECT" alpha 1 builder 12 waiting \
  'handoff ready' 'resume at cycle start' 'docs/verify-worker-continuity.md'

# Append a recipient-addressed message; inspect only outstanding work; acknowledge it.
MESSAGE=$(bin/polylane-workers.sh send "$PROJECT" alpha beta 12 'review API' | jq -r .id)
bin/polylane-workers.sh inbox "$PROJECT" beta
bin/polylane-workers.sh ack "$PROJECT" beta "$MESSAGE"

# Import public relay JSONL without changing it, then build a bounded resume packet.
bin/polylane-workers.sh import-relay "$PROJECT" "$PROJECT/.polylane/coordination.jsonl" 12
bin/polylane-workers.sh resume "$PROJECT" beta 600
```

`capsule` uses expected-version compare-and-swap and returns 75 for stale
writers. `ack` is recipient-scoped, idempotent, and appends exactly one audit
event. Relay imports preserve their original event object, treat only relay
`request` events as inbox items, and deduplicate by canonical relay path plus
relay sequence; decisions therefore remain decisions.

## Concurrency and bounds

Two simultaneous `send` invocations completed with exit code 0. The recipient
inbox contained all four outstanding durable messages, with four unique,
sequence-derived IDs—no append was lost. Capsule summary/context/evidence,
message, and relay-event byte limits are enforced before persistence. Resume
packets use deterministic truncation and carry explicit `sources` labels and a
`truncated` flag while remaining at or below the requested byte cap.

The test also proves that credential-shaped capsule text, messages, and relay
events are rejected without creating durable residue. The relay is read-only;
its checksum is unchanged by import.
