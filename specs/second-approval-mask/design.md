# Design: second-approval-mask

Impl-Review-Status: Passed

## Architecture

Single-point change inside the two workflow-state validator twins. No new
components, files, or data flows; the task-stage normalization function in
each twin gains one deletion rule executed alongside the existing three
value masks.

```
tasks.md ──▶ normalized_hash()/Get-NormalizedHash(stage=task)
              ├─ mask Task-Review-Status: → Pending      (existing)
              ├─ mask Approval:           → Draft        (existing)
              ├─ mask Status:             → Planned      (existing)
              └─ DELETE ^Second Approval:* lines          (NEW)
             ──▶ sha256 ──▶ compare with task-review contract tasks_sha256
```

## Components

- `plugins/sdd-quality-loop/scripts/check-workflow-state.sh` —
  `normalized_hash()` task branch: add `-e "/^Second Approval:/d"` to the
  existing sed invocation. sed `d` removes the whole pattern space including
  the line terminator; a CRLF line matches because the pattern is a prefix
  match. PROTECTED — staged at
  `specs/second-approval-mask/human-copy/check-workflow-state.sh`.
- `plugins/sdd-quality-loop/scripts/check-workflow-state.ps1` —
  `Get-NormalizedHash` task branch: add
  `$text = [regex]::Replace($text, "(?m)^Second Approval:[^\r\n]*\r?\n?", '')`
  after the three masks. The `\r?\n?` tail consumes the terminator so a
  deleted final line without trailing newline matches sed semantics
  byte-for-byte. PROTECTED — staged at
  `specs/second-approval-mask/human-copy/check-workflow-state.ps1`.
- `tests/second-approval-mask.tests.sh` — new agent-editable suite per
  acceptance-tests.md, fixture pattern from workflow-state-parity.tests.sh
  (temp root + `--registry`), plus registration in `tests/run-all.sh`
  (agent-editable one-line append).

## API / Contract Plan

No interface change: both twins keep their CLI (`[--feature <f>]`,
`[--registry <path>]`), exit codes, and diagnostic format. The only
observable change is the normalized-hash function's treatment of one line
prefix. Existing task-review contracts stay valid: every frozen `tasks.md`
in this repository contains no column-0 `Second Approval:` line, so deletion
is a no-op on their recorded hashes (verified at the gate by running the
full repository `check-workflow-state` with the fixed twins).

## Test Strategy

1. RED first: TEST-001 fixture against the PRE-FIX live twins must fail with
   `task plan hash is stale`; recorded as red.log.
2. GREEN: same corpus against the staged fixed twins passes; TEST-002
   negative controls (arbitrary-line add, checkbox flip) must fail in BOTH
   red and green runs, proving the freeze is not weakened.
3. Parity: per-case sh/ps1 exit-status and rule-ID equality; CRLF corpus.
4. Regression at gate: full `check-workflow-state` (no --feature) over the
   real registry with the fixed twins → `workflow-state: ok`;
   `tests/workflow-state-parity.tests.sh`, `workflow-state-ci-integration`,
   and `workflow-state-registry` suites re-run green.

## Security Boundaries

The freeze intentionally stops covering exactly one line class. Field
integrity remains enforced elsewhere: the hook guard denies agent writes of
`Second Approval:` (fail-closed, not sudo-bypassable) and `check-task-state`
requires the well-formed distinct-approver value at critical Done. The mask
is anchored (column 0, exact prefix) and AC-002 pins the anchor with negative
controls. No secrets, no network, no new inputs.

## External Integrations

None. Both twins are self-contained; CI invokes them through the existing
test suites only.

## Deployment / CI Plan

Agents stage both fixed twins under `specs/second-approval-mask/human-copy/`
with a SHA-256 MANIFEST; a human applies them to the live protected paths
(apply-human-copy procedure). The new suite runs in `tests/run-all.sh`.
Rollback: human re-copies the prior twin files; revert the test commit.

## Cross-Layer Dependencies

Consumed by the epic-136-phase1-guards critical tasks (T-001/T-002): after
this fix is live, the human records the named primary + second approvals
(scratchpad record-approvals.sh) without breaking stage provenance. No other
feature depends on this change.
