# Runtime integrity verification

## RED

```bash
bash tests/test-cleanup.sh
bash tests/test-write-report.sh
bash tests/test-pane-stalled.sh
```

Observed expected failures before implementation: cleanup 2, report 4, pane stall 2.

## GREEN

```bash
bash tests/test-cleanup.sh
bash tests/test-write-report.sh
bash tests/test-pane-stalled.sh
bash tests/test-graph-shadow.sh
bash tests/test-supervisor.sh
shellcheck -S warning bin/*.sh
```

Passed: cleanup 12, report 23, pane stall 5, graph shadow 52, supervisor 18; 110 assertions total. ShellCheck produced no warnings.

## DEFERRED

DEFERRED: none
