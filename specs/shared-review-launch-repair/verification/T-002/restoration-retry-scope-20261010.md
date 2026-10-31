# T-002 restoration fixture retry

Owner: shared-review-launch-integration/sdd-forge. HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807.
Existing dirty implementation and evidence are retained. This repair changes only
verify-disposable.py and adds new verification output; no production validator,
registry, frozen specification, approval, verdict or task state is changed.

The prior downstream fixture failed because registered specification directories
were absent. Recreate only the registered directory topology in the disposable
checkout, as in native attempt 4. Preserve registry bytes and require each source
directory to exist. Required validation: exact eight-file mutation/restoration,
before/after hash and traceability tests, downstream parity, unreadable-input
equivalence, and unchanged owning source hashes. This is current-candidate
restoration, not historical RED or installed-host rollback. RT-20261009-001's
alternative-evidence exception is not applied to T-002.
