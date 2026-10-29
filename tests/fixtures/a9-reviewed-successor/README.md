# Prior A9 successor bytes

These two files are byte-for-byte snapshots from commit `55fb04ee2c1f6af182305eb85882b5719bc62cb6`, the reviewed PR #640 recovery successors. `tests/lib/component-coverage-successors.py` verifies their existing SHA-256 bindings and negative mutations. They are test data; they are not installed or executed as product scripts.

The live prechecks also contain the research integration. Their combined candidate bytes are bound separately by `research-consumer-current-publication.json` and require their own review. This fixture does not assert that the combined bytes inherited the prior review or that any task/quality gate is approved.
