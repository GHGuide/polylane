# Cycle 18 research — recovery incident evidence

Cycle 17's host certification hit real ENOSPC, then exposed five reproducible seams:
startup automation matched trust-dialog prose without a visible option; host failure
text dirtied a committed DONE integrator; report/event writes could misstate or damage
durable output under write failure; selected skill metadata was validated but not passed
through the runner compiler; and a graphless recovery worktree did not discover the
canonical graph from the same Git common directory.

Cycle 18 converted each observation into a deterministic failpoint or contract test.
Its builders and integrator closed those seams, and the full 107-file suite passed. The
subsequent live GO rehearsal found a separate latent optional-domain wrapper bug, which
is preserved as the evidence and scope for Cycle 19.
