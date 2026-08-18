# Cycle 42 emergent questions

No user decision is required before cycle 43; these resolve inside the recovery or
the next planned cycles:

1. Should worker sandboxes that cannot bind loopback or private tmux sockets skip
   host-capability tests with an explicit SANDBOX-SKIP receipt instead of forcing a
   NO-GO the normal host must re-litigate? (Candidate runner change, post-43.)
2. Does the `--evidence-kind` acceptance extension subsume the current tier system,
   or must both coexist for backward compatibility with pre-42 state files?
3. After recovery, m32.7's producers implement against the frozen lock — does the
   lock's checksum registry need a doctor check so drift is caught pre-launch?
