# Cycle 27 suggestions

Selected now:

1. Use installed `superpowers:systematic-debugging` for the builder because both failures cross helper boundaries.
2. Use installed `superpowers:test-driven-development` for the builder because each repair needs a red regression first.
3. Use installed `superpowers:verification-before-completion` for the integrator because promotion depends on fresh focused evidence.
4. Use installed `engineering:code-review` for the integrator because the marker exception is a trust-boundary change.
5. Install no new skill in this repair cycle; acquisition would add unrelated risk and cannot improve the narrow shell fixes.
6. Share the existing Graphify artifact and query symbols directly; do not rebuild it.
7. Keep one builder because all three fixes meet in runner acceptance semantics.
8. Validate empty and partially armed integrator-kit cases separately.
9. Reuse one predicate for deciding whether an integrator kit is active.
10. Keep path and fingerprint validation mandatory for every active integrator kit.
11. Preserve the zero-selection compatibility path for old manifests.
12. Prove a stale integrator fingerprint still fails before launch.
13. Model status normalization as one exact runner-authored rename, not a broad status-file exemption.
14. Require identical marker bytes on both sides of the permitted rename.
15. Require the canonical current-run destination and one unambiguous source.
16. Reject extra files in the normalization commit.
17. Reject stale nonce, symlink, dirty-tree, and ambiguous candidates.
18. Keep ordinary out-of-scope builder changes blocked after normalization.
19. Persist only a bounded tail of failed acceptance output.
20. Include command, return code, phase, run ID, and timestamp in failure evidence.
21. Write failure evidence atomically under `docs/polylane/host-gate-failures/`.
22. Link the retained output from both the host failure record and final report.
23. Never persist successful full-suite chatter as durable project state.
24. Keep terminal output filenames nonce-scoped to prevent stale attribution.
25. Test multiline and shell-special output without constructing unsafe JSON.
26. Keep acceptance execution in the integrator worktree and evidence in the canonical project.
27. Run focused checks through `polylane-check.sh` and do not repeat unchanged matrices.
28. Leave terminal certification open so Cycle 27 cannot consume the expensive gate.
29. Start Cycle 28 from a fresh process so every repaired runner function is actually loaded.
30. Treat only a fresh one-gate Cycle 28 GO as installable completion.
