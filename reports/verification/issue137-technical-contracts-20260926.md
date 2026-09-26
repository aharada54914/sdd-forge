# Issue #137 technical contract proposal

Status: read-only investigation and design proposal; not a reviewed specification,
runtime-support proof, implementation, or task approval.
Source baseline: `5d5ada70636b3c4774095b8e4139ed83c21f30c3`.

## Human decisions

The human answered OQ-001–OQ-003 on 2026-09-26:

- Automatically delete local, worktree-separated conversation records after 30 days.
- Remove secrets before persistence; disclose that removed portions cannot be
  recovered exactly. Do not retain an unredacted backup.
- Warn and continue work if user-input persistence fails. This does not waive
  manual-compaction safety checks or allow automatic compaction to be blocked.

Expiry must also cover derived copies and repair/quarantine data, not just the
primary journal. The human additionally approved an OS-standard daily job:
exclude records from recovery at 30 days, delete normally within 24 hours, and
catch up after power-off/sleep. Only this feature's logs are deletion targets.
Scheduler integration, redaction rules and warning delivery remain design/test
work; no scheduled job has been installed and no existing log deleted or processed.

## Smallest proposed technical boundaries

| Question | Proposed contract | Verification still required |
|---|---|---|
| OQ-004 | Store under the SDD worktree's `.sdd/context/`, never shared Git metadata. Bind records to canonical SDD/worktree roots, worktree git-dir, feature and host session. HEAD changes invalidate derived state, not ownership. | Two worktrees, another repository, copied journal, root alias and HEAD-change cases. |
| OQ-005 | Deduplicate only by a host-guaranteed stable event identity. Same ID with different content is an error. Without that identity retain separate deliveries; equal text or turn ID is not enough. | Actual host retry payloads; no all-host exactly-once claim. |
| OQ-006 | Serialize append and synchronize before interpreting captured data. Publish derived state via same-directory temporary file and replace. Distinguish replacement visibility from confirmed durability. | Failure injection and native OS behavior, including Windows. Do not import another feature's platform waiver. |
| OQ-007 | Capture only observed hook/transcript records. With absent or unknown transcript, disclose incomplete coverage. Preserve a valid prefix and retry an incomplete tail; do not treat interior corruption as a harmless tail. | Real transcript formats, partial records and recovery interruptions. |
| OQ-008 | Validate lifecycle delivery separately from PreToolUse enforcement, for each installed host and candidate registration. Unsupported events remain unavailable; ordinary file-based SDD remains usable. | UserPromptSubmit, Stop, manual/auto PreCompact and compact SessionStart through real entry points. |
| OQ-009 | Require untracked and effectively ignored storage; reject unsafe paths or failed Git checks. Do not auto-change the index or delete tracked files. | Missing/negated ignore rules, tracked files, Git errors and symlink targets. |
| OQ-010 | Use the approved daily OS job and catch-up policy, without a new resident service. A content-free list of explicitly registered owned worktrees permits cleanup without opening the worktree. | Native scheduler registration/removal, inactive worktrees, sleep/shutdown catch-up, failed deletion and foreign-path rejection. Never recursively scan arbitrary directories. |

## Reuse and source checks

- Reuse task-state parsing rather than a competing authority:
  `mcp/sdd-forge-mcp/src/parsers/tasks.ts:67`.
- Root resolution already canonicalizes the SDD root:
  `mcp/sdd-forge-mcp/src/root.ts:39`. This alone is not journal ownership proof.
- Existing Node/esbuild tooling can build a transport-free reader entry;
  do not import the MCP startup entry or widen the MCP write boundary:
  `mcp/sdd-forge-mcp/package.json:8`, `:11`.
- The current `.gitignore:1` through `:18` lacks the proposed storage exclusion.
  Recheck shared ignore/registration surfaces before review and implementation.
- Existing durability code distinguishes an already-visible replacement whose
  directory synchronization failed from a replacement that never happened:
  `plugins/sdd-quality-loop/scripts/resolve-project-context.py:1479`, `:1492`.
  This is a pattern to test, not proof that a new journal has the same guarantees.
- A failed `guardedRead` is not proof of safe absence. Its realpath/stat/read
  catches collapse several errors into `not-found`:
  `mcp/sdd-forge-mcp/src/path-guard.ts:186`, `:218`, `:250`.
  Treat failure as unavailable state; do not infer ENOENT from that result.

## Remaining gate

OQ-001–OQ-003 are resolved product choices. OQ-004–OQ-009 have proposed technical
boundaries, not verified host guarantees. The issue's twelve acceptance criteria
and eighteen scenarios remain in `issue137-acceptance-design-20260926.md`.
No test execution or formal review is claimed by this document.
