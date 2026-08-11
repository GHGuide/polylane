# Cycle 36 emergent questions

1. Should a future marker helper emit a complete integrator handoff template containing
   both files, so prompt prose cannot drift independently from the parser?
2. Should dry-run render the exact gate input file and sentinel line in its launch
   summary for easier operator inspection?
3. Should the compiled-prompt summary expose the role and its final handoff files,
   so a human can compare the builder and integrator boundaries before launch?

Deeper next-round option: add a hermetic mock-agent rehearsal that intentionally follows
only the final runtime block and proves a compiled GO reaches promotion without relying
on model interpretation.
