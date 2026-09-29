# Owner registry trust decision (2026-09-30)

The user approved reconciling each registry entry against an independently confirmed owner list supplied by the existing installer. Registry JSON cannot confirm its own entries. Reject unconfirmed, duplicate, or conflicting owner registrations. Confirmation grants neither access to another worktree's conversation log nor authority to release its lock.

The T-001 admission boundary already accepts `confirmedOwners` only as trusted caller input and rejects the corresponding invalid registry cases (`plugins/sdd-context/validation.mjs`, `tests/sdd-context/validation.test.mjs`). The targeted validation suite passed 150/150 on 2026-09-30 (macOS). This is synthetic evidence only: obtaining that list independently from the installed installer and native cross-worktree denial remain unverified and cannot be claimed by T-001's unit tests.

Frozen design and task review inputs are unchanged. Later installer work must bind the trusted list to actual installed registrations and independently review that wiring before any live activation claim.
