STATUS: integrator DONE run=c14-self-hosting-truth-20260808

Integrated the runner-truth (`8df7952`), skill-delivery (`57781b5`), and
worker-ledger (`6f38155`) tips. Post-`5566152`, the runner transaction now
promotes its skill-outcomes ledger and only exact current-run lane receipts;
the user-dirt refusal and bounded credential detector regressions pass. The
non-host c14 acceptance is complete, and coordinator-owned physical GO and
NO-GO canaries both pass. The complete frozen terminal command is the single
remaining durable close operation.
