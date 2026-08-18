# Cycle 29 research — active work and scope-plan truth

Run: `c29-active-scope-20260811-a1`

Cycle 28 remains an immutable truthful HALTED run. Its worker nevertheless
completed a useful recovered tip, `cf60d3c1646dc6a7ae3f76a636be423cef91e9a1`,
which is the source base for this cycle. The run made one successful initial
launch and then recorded eight lane restarts, zero supervisor restarts, and zero
terminal gates. No later source result may rewrite that history.

The first restart was not a provider or inference failure. The material-progress
guard observed many command starts while the worktree fingerprint remained
stable and concluded that the lane was churning. At that moment the worker was
running long regression matrices. `pane_wedged` exempts active commands, but
`material_progress_stalled` does not. The two safety policies therefore disagree:
the silence detector preserves the worker while the spend guard kills it. Active
command state must be derived from structured command start/completion events and
must suppress material-progress replanning until the command actually settles.

The completed handoff then failed the strict scope gate because
`bin/polylane-promptlint.sh` was changed but omitted from the manifest's
`own_globs`. The authored prompt required runtime-root linting, so the plan and
its ownership declaration contradicted each other. The scope gate correctly
refused promotion, but the runner treated the exact committed handoff as an
ordinary unfinished/dead lane and spent all retry and repair budgets, repeatedly
printing the same deterministic violation. A committed current-run handoff with
an invalid scope is terminal evidence: halt once, preserve the exact offending
paths, and do not respawn the completed worker.

The recovered source also exports `POLYLANE_SOURCE_ROOT` directly from the
manifest worktree string. Relative worktrees therefore stay relative after the
pane changes directory, which can double the path and break Graphify or source
commands. The staged-prompt helper already solves the same class by resolving
relative worktrees against `PROJECT_ROOT`; the source-root export must use one
absolute physical path as well.

Finally, prose-only write-set review was insufficient. Newly generated manifests
will opt into a planned-write contract: each lane lists exact expected write
paths, and preflight proves every one is covered by that lane's `own_globs`.
Legacy manifests remain readable, while current Polylane-generated plans always
enable the check. This does not predict every exploratory edit; it makes the
planner's declared implementation surface mechanically auditable before tmux or
git side effects.

The live-turn time repair from Cycle 28 is retained but independently reviewed.
High and xhigh turns need 30- and 60-minute defaults, and the finite hard ceiling
must be configurable above one hour for explicitly requested multi-hour runs.

