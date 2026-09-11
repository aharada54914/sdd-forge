# RT004 optional precheck acquisition — candidate DATA only

Scope: close the optional-precheck path acquisition gap in the composed
PowerShell history candidate. This is not a product application, independent
security review, quality-gate verdict, or merge authorization.

Previous candidate SHA256:
748d6b63eb0dfba4ed5371367fb86e85482822d80b549e6223e664e29efcdb97
Updated candidate:
reports/verification/adr-workflow-powershell-history-composed-candidate-20260909.patch
SHA256: 4f8b317929208b86fa4bedf2b645f144d13e88d1643bab4f8fd8e2c93d66f5f6

## Change and root static review

The former optional-precheck branch used Test-Path before component-safe
acquisition. That predicate is not proof that no directory entry exists.
The candidate now obtains the optional path through the same safe component
walk as mandatory evidence. Only an absent final entry may return null;
parent absence, enumeration errors, wrong-case final entries, reparse points
and non-regular entries still fail. Only the precheck call enables this option.
After validating the snapshots, an initially absent precheck is checked again:
its appearance, a wrong-case alias or unsafe replacement must fail. Returned
binding objects still originate from the original verified byte snapshots.

Static review found no new mandatory-file omission path in this delta.
This is not atomic no-follow acquisition: transient same-user replacement
and restoration remains outside the before/after stability guarantee.
Complete Bash/PowerShell acquisition parity, current-stage integration and
independent whole-candidate review remain required. The Bash candidate's
optional absence handling also needs equivalent scrutiny for wrong-case
entries; the PowerShell delta alone does not establish parity.

Format-only git apply --numstat initially failed because the edited hunk
length was overcounted by three. The count and subsequent offsets were
corrected; it then exited 0, reporting 679 additions and 6 deletions.
No application or extracted-candidate execution was performed.

## Regression fixture preparation

The first test invocation, /tmp/rt004-optional-path.BUBG9N, exited 1 after
the first legacy control. Root cause: the new fixture incorrectly assumed
the copied historical round had no precheck; the source has a 522-byte
precheck-result.json. This was fixture preparation failure, not evidence
of product rejection or successful regression coverage.

One fixture repair moves that copied file into the isolated fixture root
before constructing three explicit cases: genuinely absent precheck
(positive), dangling precheck symlink (negative), and wrong-case regular
precheck entry (negative). Only copied DATA is changed. Original validators
are invoked, not the candidate. All previous mutation cases are retained.

## Actual original-validator result

Command: rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only
(combined output captured with the checked mktemp and pipefail/tee wrapper).
Session 89192 terminated with exit 1: **10 passed, 34 failed**, all 44 cases
reached. Log: /tmp/rt004-optional-path.GUTRE4.
Log SHA256: 11eb62110c541dfde81a73c6d2d05c87aef838334bf428010b13cc723a05cfa5
Test source SHA256:
ede7dd332f6691e81131d44390744c9a1223e6d1ce662313329be555c0920d4c

Both runtimes accepted the absent-precheck positive. Both incorrectly accepted
the dangling and wrong-case entries (exit 0, workflow-state: ok), giving four
additional detected failures. The previous 30 failures persist. These original
validator observations do not isolate the unapplied candidate predicate:
the original opening fast path can independently explain acceptance.

Syntax check for the test and git diff --check exited 0. Protected original
validator hashes remain 15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e
(Bash) and 7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644
(PowerShell). No candidate runtime validation, native Windows evidence,
commit, push, merge, issue closure or Done transition is claimed.
