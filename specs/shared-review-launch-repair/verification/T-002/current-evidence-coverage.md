# T-002 current evidence coverage

Owner: shared-review-launch-integration/sdd-forge; base HEAD:
`9ce19abe90df0cb83e385f96855e4843318a8807`.
This addendum reconciles evidence only. The frozen implementation report and
the 48f0bfc1 NEEDS_WORK evaluation remain unchanged. RT-20261009-001's exception
does not apply to T-002. No production behavior or acceptance criterion changes.

Paths below are relative to this directory.

| Criterion | Current evidence and result |
| --- | --- |
| AC-004 / TEST-007 | `current-restoration-380hac14/restored-hash-parity.log`: approved lifecycle values preserve the existing normalized digest. |
| AC-004 / TEST-008a–d | Same log: unknown or annotated status, evidence-cell and body changes are rejected. This preserves existing WFI-030 behavior, not a newly introduced normalization rule. |
| AC-005 / TEST-009 | Same log: shared impl/task hashing equals the pre-extraction recipe for LF, CRLF and mixed-case status input. |
| AC-005 / TEST-010a | Same log and `unreadable-equivalence.log`: malformed/empty/nonempty missing-field input retains prior hashing behavior; missing or exclusively locked input fails equivalently, without changing bytes, and reading recovers after lock release. |
| AC-005 / TEST-010b | Same log: mis-cased fields/values preserve prior hash behavior; stage-specific validation remains with callers. |
| Downstream preservation | `current-restoration-380hac14/restored-downstream-parity.log` and `restored-traceability.log`: exit 0. |
| Restoration | `current-restoration-380hac14/results.json` records six commands, all exit 0; `scope-check.json` records eight restored targets and unchanged owner bytes. This is disposable candidate restoration, not installed-host rollback. |

`historical-red-recovery-20261010.md` identifies the contemporaneous structural
RED before shared-helper extraction and subsequent GREEN. Fixture setup failures
are not RED evidence. The permanent equivalence follow-up extends preservation
coverage; it does not claim a new historical behavioral failure.

`permanent-equivalence-independent-review.md` records the independent supplemental
diff review. The fresh manifest must bind the permanent untracked test itself,
its complete added-file diff, this addendum, the current contract and restoration
logs. The older implementation report is historical, not the sole index of current
evidence. AC-001/002/003/006 belong to other tasks.

Formal quality PASS, native Windows, CI and merge remain unverified by this addendum.
