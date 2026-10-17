# Issue 423 recovery-source independent inspection

Independent reviewer: `issue423_recovery_source_review`, separate Codex context. This record transcribes the completed independent inspection; it is not a canonical quality-gate verdict, reservation, or task-state transition.

Result: PASS for the bounded association claim below. Historical failures remain unchanged.

## Checked evidence

The reviewer inspected native session `01a1030d-9eeb-7453-95eb-5fece30a5976`. Its 2026-10-03T18:36:35.103Z command explicitly selected the owning checkout; the 18:36:35.296Z result returned that directory with exit 0. The 18:37:59.449Z patch targeted the owner report `reports/implementation/sdd-domain-multitarget/T-003-attempt2.md`; its report identity, attempt and relative scratch declaration agree with the current artifacts. The 18:37:59.531Z tool result was an empty object, not a signature or creation-time hash.

| Artifact | SHA-256 |
|---|---|
| T-003-attempt2.md | a204e954986c2207f9719174f11c5fca2cf9fcbb877828d78f06f5fea7a6d462 |
| T-003-attempt2.scratch-owner.json and byte-identical candidate | 1a2a624f1b6ef291384172914f851cc90a150a60bfdde045bd8403b939ae34d0 |
| T-003-attempt2.owner-observation.candidate.json | 4114ddada34bdf7d76d158f5321c4f8b3772517372980a86be726e0b8a04d679 |
| T-003-attempt2.source-inspection.candidate.md | 7cb1e2731938d8a2cb1f8bb035ce3bcf5cc93223fb200966b87a70c1c9bafe1f |

The reviewer checked Bash validator lines 1137–1190 and PowerShell lines 1251–1304: owner, admitted hashes, report identity, observation and relative-path safety are checked in both implementations. The parent separately executed 62 applied-validator regressions; this reviewer did not claim to rerun them.

## Limits and required admission

This establishes a declaration's owner/report/run association only. It does not establish past scratch existence, execution, OS isolation, creation-time integrity, or equality between native and logical session identities. Source authenticity and current-cycle authorization remain caller responsibilities.

The candidate declaration saying the adjacent receipt is absent is stale: the receipt now exists with the candidate hash above. Older bundle-readiness hashes are also stale and must not be treated as current proof. A new current-cycle declaration must bind the recovery artifacts and this completed independent inspection before any receipt admission. No existing ledger entry, reservation, frozen artifact, approval or task status was changed.
