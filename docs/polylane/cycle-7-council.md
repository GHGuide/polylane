# Cycle 7 council

Reject cycle 7 as the final certificate because terminal acceptance failed and cleanup did not run.
Keep the efficiency shape: two audit builders, one integrator, low/medium effort, three launches,
zero restarts, one terminal gate, and a 900-second ceiling. Commit the hermetic supervisor-test fix,
then run a fresh nonce rather than resuming the consumed gate. The next host gate must execute the
full suite under the same zero-restart environment and reach final cleanup before completion.
