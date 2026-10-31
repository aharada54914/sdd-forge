# Security Spec: second-approval-mask

## Trust Boundaries

- B1: `tasks.md` content vs the workflow-state freeze. The freeze is tamper
  EVIDENCE for the task plan; lifecycle fields (Task-Review-Status, Approval,
  Status, and — with this feature — Second Approval) are excluded because
  they mutate post-freeze by design. Content enforcement for the excluded
  field lives at B2/B3, not in the hash.
- B2: agent vs human authority over approval fields. The hook guard denies
  agent writes of `Second Approval:` (existing rule, unchanged, fail-closed,
  not sudo-bypassable).
- B3: Done decision. `check-task-state` requires
  `Second Approval: Approved (<id> <ISO>)` by a named approver distinct from
  the primary for critical Done (existing, unchanged).

## STRIDE Analysis

- Spoofing/Tampering (agent forges or edits a second approval): denied at B2
  before any file change; unaffected by this feature.
- Tampering (agent deletes a recorded second approval to strand a task): the
  deletion no longer trips the freeze, but the attempt is denied at B2 (the
  edit payload names the protected line), and even if it landed, critical
  Done simply fails at B3 — fail-closed direction, no privilege gained.
- Tampering (any other tasks.md edit): still tripped by the freeze; AC-002
  pins this with negative controls in both twins.
- Repudiation: the recorded line carries the approver id + ISO timestamp and
  lands in git history via the human's commit; unchanged.
- DoS (the defect itself): the CURRENT behavior is the denial of service —
  recording a mandated approval bricks the repository-wide gate. This
  feature removes that.
- Elevation: none; no authorization logic changes.

## Security Tests

- AC-002/TEST-002 negative controls (freeze not weakened beyond the field).
- AC-003/TEST-003 CRLF handling (no normalization desync between twins that
  could mask tampering on one platform only).
- Gate regression: full-repo `check-workflow-state` ok + existing
  workflow-state suites green with the fixed twins.

## Authorization

Writing `Second Approval:` values: humans only (B2, unchanged). Applying the
fixed twins to live protected paths: humans only (human-copy, unchanged).
