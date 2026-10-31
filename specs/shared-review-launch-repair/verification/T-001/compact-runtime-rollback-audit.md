# T-001 compact caller with current runtime: isolated rollback

Approved delegated current-runtime verification; high-risk T-001, diagnostic
only. Writes are limited to this new directory. Owner source, old rollback
evidence, canonical evidence, task states and ledgers are not modified.
context.json pins owner HEAD/dirty state and original evidence hashes before
application. The prior mixed-version diagnostic remains unchanged at
T-001-compact-rollback-20261009, including failures and restored 42-test success.

Dependency closure checked before apply: paired validators invoke
review-conditional-inputs.py and supplemental-delivery-inputs.py; supplemental
imports conditional; conditional imports validate-facet-manifest.py and calls
only validate_against_schema with domain-contract v1/v2 schema bytes. The facet
helper and both domain schemas are byte-identical between owner and baseline.
They remain present in the independently copied baseline. No generated guard
module is invoked by these validators. The 22 previous caller/helper targets plus
two paired validators comprise the 24 current-byte application targets.

Preflight: candidate target SHA-256 must equal the saved owner hash;
restored target SHA-256 or absence must equal the saved baseline; exactly 26
original hashes must equal before-hashes.json; nonzero test status fails the
phase; owner/baseline target hashes are rechecked after apply and restoration.
These mismatch assertions are implemented in verify.mjs. Candidate target modes
are made writable only in the new checkout and restored after rollback.

Procedure: verify copied 26 original hashes; apply current 24 targets using
apply_patch; verify candidate hashes; run six original suites; reverse patch;
verify 26 hashes and all 24 baseline bytes/absences; run four baseline suites;
repeat source preservation checks. Local TMPDIR and Python no-bytecode mode keep
test artifacts in this directory. Git storage is standalone without alternates
or commondir. Formal quality-gate, native reviewer launch, CI and installation
are outside this diagnostic.

## Result

Current 24-target application via apply_patch succeeded; check-candidate verified
every pinned candidate hash. All six candidate suites exited 0 (62 tests):
quality-nontty-transport 20; host-review-preflight 7; unified-task-launch 9;
unified-launch-order 9; review-conditional-inputs 16; shared-launch-build 1.
The current paired runtime removed the mixed-version failures without any source
or acceptance-criteria edit in this diagnostic.

Reverse apply_patch succeeded. All 26 original before-hashes match; every one of
the 24 targets equals its baseline hash or expected absence; original modes were
restored. Owner target hashes and old baseline hashes remain unchanged. The four
restored-baseline suites exited 0 (42 tests): transport 18, host 7, task 9, order 8.
check-restored was rerun after these tests and passed again.

The pinned compact transport SHA-256 is
`9b635597729d85e4808b850c76961af2c0853213d40e52bf7a88efa4580b6d70`;
probe SHA-256 is
`83abc29c14dc199a399ff7a92c19235e1c5ddc7688f98dbc46f39fa1f39db33c`.
Full 24-target hashes are in target-hashes.json. Phase exit values are in
candidate-results.json and restored-results.json; complete stdout/stderr is in
the ten phase-suite logs. baseline-hashes.json and restored-26-hashes.json bind
the original rollback contract; check-candidate.json/check-restored.json record
source preservation as well as disposable state.

evidence-index.json maps twenty diagnostic artifacts to proposed unique
verification/T-001/compact-runtime-rollback-* destinations, with exact SHA-256.
It is a copy index only, not a write to canonical evidence or a formal verdict.
Native launch, independent evaluator decision, CI and installation: NOT RUN.
