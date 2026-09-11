# RT004 historical ADR path anchor regression

Added canonical-adr-path and newline-adr-path to the existing workflow-only
regression matrix. Each starts from the equal-layer internally consistent
history fixture, adds the same nonempty ADR set to contract/precheck, recomputes
the input digest and precheck raw hash, and updates both actual reviewer
manifests and both reserved manifests. Fixture setup independently asserts the
exact decoded path and four matching bindings. No live ADR file is created:
opening historical review must not depend on current ADR contents.

Static review: the negative case differs only in the decoded final newline
and consequent digest/hash rebinding; neither stale precheck pins nor mismatched
reserved/actual manifests should explain its rejection. This is a root review
of fixture construction, not an independent quality gate. Future candidate
GREEN verification still needs a path-specific diagnostic rather than only the
existing stage-provenance/ADR diagnostic-family assertion.

Command: rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only
Full combined output was captured through a pipefail/tee wrapper.
Session 9008 completed with exit 1: **8 passed, 30 failed**, 38 cases reached.
Full log: /tmp/rt004-path-anchor.qsF7h5
Log SHA256: 3667238e234c6f42a9a2ed1c9ae842a86e7d8e2e0cabd7d27033a2fea6bef9b6
Test source SHA256:
b9af3808abd6e29d122d018a79732fa1c59d4e303dfd415900ae43d0c6f4429e

Both Bash and PowerShell accepted the canonical positive control. Both also
incorrectly returned exit 0 / workflow-state: ok for newline-adr-path, which
the suite correctly counted as failure. The previous 28 failures remain;
historical evidence is not superseded by a claim of success. This actual
validator failure does not reproduce the unapplied candidate's regex in
isolation: the original opening bypass is another reason for acceptance.

Bash syntax and git diff --check exited 0. Original protected validators were
executed against fixture DATA; no candidate functions were extracted, applied
or executed. Native Windows, corrected candidate runtime and full integration
remain pending. No commit, push, merge, issue closure or Done transition.
