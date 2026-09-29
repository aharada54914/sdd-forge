# Issue #137 — approved diagnostic and registry completion

Date: 2026-09-29. Scope: T-001 input validation only; non-frozen addendum.

The human approved both definitions below in the current conversation. They
supersede only the undefined diagnostic vocabulary and registry admission
policy in the earlier contract-completion addendum. Frozen specifications,
approval/status fields, historical reviews and evidence remain unchanged.

- `OutcomeV1.reasonCode`: successful results use `ok`; failure codes are exactly
  `unsupported`, `validation-rejected`, `privacy-rejected`, `storage-failed`,
  `integrity-failed`, `reconcile-failed`, `publication-failed`,
  `ownership-mismatch`, `expired`, `cleanup-failed`, `budget-exhausted`.
  Optional `diagnostic` uses this same case-sensitive fixed vocabulary, never
  free text, exception details, secrets or private paths. This defines encoding,
  not proof that an operation succeeded.
- `OwnerRegistryV1`: compare registrations with an owner list independently
  confirmed through the existing installer; never treat a registry entry as
  its own authority. Reject unconfirmed owners, duplicate owner tuples,
  duplicate registration IDs and conflicting registrations. This grants no
  permission to read another worktree's logs or remove its locks.

Existing closed fields and result-specific obligations remain authoritative:
`specs/sdd-context-continuity/design.md:77–101,175–188`. No persistence,
installer changes, native activation, test PASS, quality-gate decision or
delivery completion is established by this approval record.
