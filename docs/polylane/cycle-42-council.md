# Cycle 42 council — recover by import, never by trusting stale automation

The council reviewed the 42A NO-GO and the outage evidence. Verdict-adjacent WIP
checkpoints created by quota-starved auto-retries are not a promotable lineage: only
the immutable `4851bc1` handoff carries verified content. The highest-value
continuation is a minimal one-builder import cycle (43) that ports — never
overwrites — the runner/supervisor deltas onto main, because main gained auth
preflight, login-expired parking, dying-words reporting, and model-detection fixes
after the handoff, and losing them would reintroduce the exact opaque failure modes
that stranded this cycle. The frozen m32.6 focused acceptance is the only
certification bar; the host owns the terminal gate. No new scope enters through
recovery.
