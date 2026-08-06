# Cycle 1 research

The install and documentation lanes exposed a recovery weakness rather than a product-design gap: a resumed lane can lose its trusted DONE marker and be respawned after it has already committed valid work. The next reliability work should keep completion state derivable from durable, run-scoped evidence and should exercise both GO and NO-GO paths through the real runner.
