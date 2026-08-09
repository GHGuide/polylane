STATUS: pane-identity DONE run=c24-context-hardening-20260810-a1

Committed `9b4d26b` implements nonce-bound pane tags and a fail-closed finder.
Focused tmux/state/supervisor checks and ShellCheck are green; verification is in
`docs/verify-pane-identity.md`. The integrator's inherited-IFS runner finding was
relayed to runner-wire because it is outside this lane's owned files.
