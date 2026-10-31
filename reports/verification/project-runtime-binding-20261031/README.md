# Runtime binding correction

An independent task-mode reproduction ran a temporary runtime successfully,
replaced its bytes at the same path, and observed that the old v1 validator
still reported passed. V2 now binds executable content and filesystem identity,
declared helpers, loaded runner/validator/schema sources and the inherited
execution environment. Historical v1 does not project fresh execution fields.

A second independent copied-tree reproduction imported the runner, inverted the
on-disk success expression, and observed old loaded code claiming the new source
hash. Import-time source pins now reject that path with runtime-changed before
execution. Permanent regressions cover runner, validator and schema-validator
replacement. Both negative findings were independently replayed after repair.

Local suites: lifecycle 36 PASS, observation 37 PASS, collector 21 PASS. Retained
raw suite output and source hashes are scoped evidence, not a reusable verdict
or native host attestation. Shell bookkeeping is removed from the actual child
environment as well as the digest; no plaintext environment is recorded.

No original historical evidence was rewritten. Undeclared dynamic libraries and
subprocesses are not magically included in the tool closure. No OS sandbox,
human approval, or Full/Lite owner integration result is inferred from these tests.
