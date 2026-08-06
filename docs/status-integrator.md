STATUS: integrator DONE run=graph-c2-1786031267

Merged both graph lane tips and retained the shadow-only runner integration.
Repair commit `3b13536` makes frozen acceptance failures actionable while
preserving fail-closed behavior. Focused graph suites, the 852-assertion full
suite, and all-script ShellCheck passed; see `docs/verify-integration.md`.
