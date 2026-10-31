# Fixed-review-input protection regression

Hosted run 41161753242, POSIX unwired shard (3), failed at source 48dbe88d
because the chain inventory found `fixed-review-inputs.py` missing from protected
scripts. The real result was guard-parity 261 passed / 1 failed. Earlier
`a.tests.py` and `native-a.tests.ps1` failures in that log are intentional fixture
controls and were not the failing suite.

Added the exact script path to the canonical invariant list and generator's
validated baseline, then regenerated all four runtime projections. No protected
path, approval requirement or verification was removed. The existing parity
loop additionally checks direct writes are denied and reads remain allowed.
The complete local parity suite now has 264 passed / 0 failed, including its
seven embedded tests. Generated-invariant consistency and diff checks pass.

`logs.zip` retains the decoded hosted job log and local verification log.
`index.json` records their hashes and exact changed source hashes. This local
result does not replace the required hosted run on the subsequent commit.
