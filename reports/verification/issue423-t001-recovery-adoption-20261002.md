# T-001 recovery evidence adoption

The parent independently checked the old canonical report, the recovery report,
all six declared output hashes, and all 28 owner/snapshot input hashes. The
complete task-input validator returned TASK_INPUT_OK. Existing test evidence
records 17 passing tests after manifest validation.

The old canonical report is preserved byte-for-byte at
`specs/sdd-domain-multitarget/verification/T-001/recovery-20261002/T-001.original.md`
(SHA-256 `c0c126c812a308baed537e9f734522d02642346e2e08f6a5adc456c6e11993d8`).
The new canonical report is the unchanged recovery candidate, SHA-256
`f5c8d034a55f68baf34329139e4c25b76a359934bbf0221cf530ab434bb74ebf`.
Its candidate/pending-adoption wording records its author-time state; this note
records the subsequent parent adoption, not a historical launch or gate verdict.

The copied task-input manifest is at
`specs/sdd-domain-multitarget/verification/T-001/recovery-20261002/task-input-manifest.json`,
SHA-256 `bbcfbf1f824da0f2969d83ff0b5a52b78764ca1fd4c43fc9cd6d32509314ba2d`.
Historical handoffs, approvals, task status, and review verdicts are unchanged.

Formal gate launch remains pending: the host rejected the read-only command
`rtk proxy python3 plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py --help`
with its PreToolUse protected-file denial. That command did not execute; no
alternate executor was used. No evaluator reservation, QG, CI, or merge occurred.

This is local evidence containing absolute host paths. Public publication needs
a separate privacy review; do not bulk-stage these records for push.
