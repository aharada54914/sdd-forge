# T-002 evidence response, 2026-10-10

Owner: shared-review-launch-integration/sdd-forge; HEAD:
9ce19abe90df0cb83e385f96855e4843318a8807. This is a non-frozen supplemental
record, not a replacement verdict, task approval or implementation report.
Existing candidate changes and rejected evidence remain unchanged.

## RED and equivalence are different claims

`historical-red-recovery-20261010.md` identifies the original pre-extraction
command, tool-call identity, timestamp and failure: the implementation caller
still defined its own recipe instead of loading the shared recipe. Its subsequent
success establishes the refactor's structural RED to GREEN. It is not a newly
manufactured old-code execution, and is not a digest-algorithm defect claim.

AC-005 / TEST-009 and TEST-010 require old/new recipe equivalence. Deliberately
making the old digest algorithm fail would contradict that requirement. Their
boundary/error-path results are preservation evidence, not independent product
REDs. AC-004's traceability fixtures likewise verify the authorized normalization
boundary; the recovered fixture-preparation failures are not product REDs.
The task-level structural RED does not establish a separate pre-fix behavioral
failure for every acceptance criterion. Evaluate this distinction against the
approved task and calibration; do not apply RT-20261009-001's exception to T-002.

## Current disposable restoration

`current-restoration-fjg8_bgi/results.json` records six successful commands,
including the downstream parity command that failed in the prior incomplete
fixture. `restoration-retry-scope-20261010.md` explains the missing registered
directory topology and its bounded repair. `verify-disposable.py` mutates and
restores eight candidate files, verifies their exact hashes and checks behavior
before/after restoration. This supersedes the earlier restoration failure only;
the earlier output is retained. It does not prove installed-host rollback,
Windows execution, full integration CI or release.

## Parent continuation and provenance

The parent resumed by reading the current approved task, canonical implementation
report, original invocation and supplemental declaration, original evaluator
output and persisted restoration results from this checkout. No implementation
is inferred from a conversation summary. The original report's disclosed
compaction remains true; this continuation is not represented as a compaction-free
implementation session or a new implementation run. Existing implementation
manifest and its identities are retained. Fresh evaluator inputs are copied and
hash-checked before a new canonical launch; a reservation is not reused.

The parent admits these additional artifacts for independent evaluation, not as
a PASS or a task-state transition. If an existing admission contract requires
more, the ordinary preflight must reject without being bypassed.

## Minor findings

The prior snapshot's Planned task and current Implementation Complete task differ
only by the documented lifecycle update; the approved task body is unchanged.
The initial traceability retry failed because `/bin/rmdir` was absent from PATH;
its failed output remains alongside the corrected successful execution. Neither
environment repair nor status change is presented as a product RED.
