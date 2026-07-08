STATUS: dashboard-tests DONE

Lane: dashboard-tests
Owns: tests/test-dashboard.sh (created)
Covers: bin/polylane-dashboard.sh — --help (exit 0), no-args / missing-manifest /
bad-interval (exit 2), --demo render, and a manifest-driven table whose DONE
state comes from a fake docs/status-<lane>.md fixture.
Result: test-dashboard.sh 10 pass / 0 fail; full tests/run.sh green
(148 passed, 0 failed, 11 test files at commit time).
Evidence: docs/verify-dashboard-tests.md
No bin/ edits; polylane-dashboard.sh was testable as-is (no follow-up request).
