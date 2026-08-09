STATUS: runner-wire DONE run=c24-context-hardening-20260810-a1

Runner boundaries use the frozen pane-identity helpers without fallback copies;
fresh, recreated, and adopted panes are tagged before dependent state/log work.
Pane liveness now also remains correct after a manifest reader inherits `IFS=|`.
Prime-hybrid workers and panes receive the nonce, and contract-v2 enforces the
frozen durable-inbox command. Manifest `custom` validates baked choices without
remapping; an explicit CLI preset remaps and wins.

Evidence: `docs/verify-runner-wire.md`; implementation commit `935866a`.
