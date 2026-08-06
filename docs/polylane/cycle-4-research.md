# Cycle 4 research — where the time and tokens went

The graph hot path is comfortably inside the frozen budget on both supported jq runtimes. The
64-lane/10,000-event production packet is about 1.9 seconds; warm admission is 54–62 ms and a
warm event append is 109–116 ms. Further graph micro-optimization would not materially improve a
run dominated by model and recovery churn.

The runtime evidence points elsewhere. The integrator transcript grew to 9.9 MB, reread broad
skill inventories after its implementation was already green, ran the 954-test suite repeatedly,
and then wedged after a Codex skills-context error. Missing-pane retries could not recreate their
target. A sandbox-only tmux denial triggered model repair even though the outer host rehearsal
passed. The final resume report retained none of the earlier token samples and measured only its
last 130-second process, not the roughly 72-minute end-to-end cycle. At least the runtime lane's
structured completion alone consumed 1,441,731 input tokens (1,368,320 cached) and 10,705 output
tokens; interrupted lanes have no truthful terminal usage record, so their value is unknown—not
zero. The next optimization must therefore shorten prompts, move host checks out of workers,
make recovery state-based, and persist telemetry incrementally.
