# Verification and merge readiness

## Sub-features
Existing CI aggregation, current PR binding, explicit missing evidence and freshness.

## How to get to it (user POV)
Read the マージ前の検証 section. For a new verdict run `scripts/merge-readiness.py`
with the trusted CI plan/collection and exact PR, then import its summary as owner.

## Driving it with the harness
`tests/merge-readiness.tests.py` tests the wrapper with controlled GitHub metadata
and an aggregator boundary; it is not a live GitHub verdict. Existing CI verifier tests
cover aggregation. `tests/session-hub.tests.mjs` covers auth and state transitions.
For actual target verification use the guide's CLI with gh read access, preserve exit code,
head/base and evidence hashes. Success requires current, complete evidence and clean PR state.

## Gotchas
No automatic merge or ruleset provisioning. Missing live credentials/evidence is blocked,
not permission to manufacture PASS. A green fixture cannot certify the whole repository.
