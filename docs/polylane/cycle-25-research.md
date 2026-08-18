# Cycle 25 research — atomic completion is a protocol, not a marker

Cycle 24 preserved its work and ended with a truthful NO-GO. Its live transcript
isolated three defects that focused unit checks had not exercised together.

1. The context-hygiene worker wrote correct evidence and a current-run DONE marker
   but twice exited without committing all owned files. The runner correctly refused
   the dirty handoff, yet the authored prompt only said `Commit often`; it did not
   define a final commit-clean transaction.
2. Recovery appended a second `DELEGATION:` scalar to an already strict prompt.
   `polylane-promptopt.sh` correctly rejected the contradiction, so the supervisor
   spent a restart on a repair prompt that could never launch.
3. The integrator committed READY and DONE, then performed its final relay read and
   discovered decisive host evidence. The runner consumed the committed marker while
   the Codex process was still active. The integrator later corrected its branch to
   NO-GO, proving that a valid marker is not terminal while the worker can still mutate
   the handoff.
4. Prime-hybrid prompts tell workers to run
   `bin/polylane-refine.sh propose-or-decline`, but that subcommand does not exist.
   The helper exposes `queue`, followed by a real `propose` or `decline` operation.
5. The Cycle 24 integrator fixed a separate live tmux bug: pane lookup queried user
   options at session scope and inherited the session nonce into untagged panes. The
   corrected helper now reads pane-local options; only a fresh process can certify it.

The design is deliberately small. Prompt text makes finalization marker-last and
commit-clean; strict lint makes that contract mandatory. Runtime completion additionally
waits for the lane's selected agent process to exit. Repair/replan prompts replace or
preserve strict scalar values instead of appending conflicts. Refinement documentation
names only executable commands. A fresh private-tmux run then certifies these changes
plus the Cycle 24 identity, context, Graphify, and custom-intensity work.

