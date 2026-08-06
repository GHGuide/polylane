STATUS: integrator DONE run=graph-c2-1786031267

Merged the contract and event lane tips, integrated contract-v2 graph shadowing
in `bin/polylane-run.sh`, and committed the behavioral RED/GREEN evidence and
verification record in `7a2ef48`.

Final gates: graph contract 36/36, graph events 38/38, graph shadow 46/46,
cache-routed full suite 850/850, and `shellcheck -S warning bin/*.sh` clean.
