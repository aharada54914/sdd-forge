# RT004 initial-open regression: expected RED

Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --initial-open-only`
Session: 71540; terminal exit 1.
Result: `ADR initial open: passed=4 failed=4`.

The actual Bash validator was executed at its original repository path.
The added driver uses a DEBUG observer before its `content_base64` assignment
to schedule a fixture-only parent-directory rename and symlink replacement.
It does not replace a product function, execute a renamed validator, alter pins,
or claim an attacker controls the trusted runtime. The observer models timing
of an ordinary filesystem operation permitted to the fixture owner.

Complete output, in execution order:

```text
ok: initial-open bash impl-reviewer-a specs/adr-fixture/design.md control
not ok: initial-open bash impl-reviewer-a specs/adr-fixture/design.md replace (exit=0 observer=replace ledger-unchanged=false)
REVIEW_CONTEXT_OK 6d4064f451eb427c24b5f9fdb020ed01dc0b8afe76200ce6c4cb1fbe40465dc4 sequence=2 previous_record_sha256=31c38eef5a7fc9e4b22c41b51a8f57c64147d99d1c9bbc50febbad6ed335ea8d pre_append_tip_sequence=1 identity_unique=yes
ok: initial-open bash impl-reviewer-a reports/impl-review/adr-fixture/attempt-1/round-1/precheck-result.json control
not ok: initial-open bash impl-reviewer-a reports/impl-review/adr-fixture/attempt-1/round-1/precheck-result.json replace (exit=0 observer=replace ledger-unchanged=false)
REVIEW_CONTEXT_OK 6d4064f451eb427c24b5f9fdb020ed01dc0b8afe76200ce6c4cb1fbe40465dc4 sequence=2 previous_record_sha256=31c38eef5a7fc9e4b22c41b51a8f57c64147d99d1c9bbc50febbad6ed335ea8d pre_append_tip_sequence=1 identity_unique=yes
ok: initial-open bash impl-reviewer-b specs/adr-fixture/design.md control
not ok: initial-open bash impl-reviewer-b specs/adr-fixture/design.md replace (exit=0 observer=replace ledger-unchanged=false)
REVIEW_CONTEXT_OK 9c3b3c9b0153d926f57c91c97739be117334605064eccb05ea1fdcbb73409d15 sequence=2 previous_record_sha256=31c38eef5a7fc9e4b22c41b51a8f57c64147d99d1c9bbc50febbad6ed335ea8d pre_append_tip_sequence=1 identity_unique=yes
ok: initial-open bash impl-reviewer-b reports/impl-review/adr-fixture/attempt-1/round-1/precheck-result.json control
not ok: initial-open bash impl-reviewer-b reports/impl-review/adr-fixture/attempt-1/round-1/precheck-result.json replace (exit=0 observer=replace ledger-unchanged=false)
REVIEW_CONTEXT_OK 9c3b3c9b0153d926f57c91c97739be117334605064eccb05ea1fdcbb73409d15 sequence=2 previous_record_sha256=31c38eef5a7fc9e4b22c41b51a8f57c64147d99d1c9bbc50febbad6ed335ea8d pre_append_tip_sequence=1 identity_unique=yes
ADR initial open: passed=4 failed=4
```

All four negatives reached their replacement observer and reserved in their
synthetic ledgers. No production ledger was targeted. The fixture trap removes
the private temporary tree. The unchanged-byte fixture isolates no-follow
acquisition from content-hash validation; it does not prove unpinned malicious
bytes were accepted, an actual attack occurred, or its frequency.

This is expected TDD RED, not a product PASS or a completed fix. Independent
test/remedy review was requested from `rt004_snapshot_static_review`.
The observer is tied to the current acquisition statement; a future reader
must update the observation boundary explicitly, and a missing receipt must
remain failure. Safe continuation through an already-held original parent is
not an integrity defect merely because the visible pathname was later renamed.
Native Windows and PowerShell dynamic substitution are not covered here.

Next: independently review the test boundary, then remedy initial acquisition
in the approved DATA candidate while preserving all existing ADR-binding,
JSON, exact-name and supported-platform requirements. Obtain independent
security review before protected product application. No CI, commit, push,
merge, ticket-resolution or formal-verdict change was performed in this step.
