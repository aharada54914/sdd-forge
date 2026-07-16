# ADR 0011: Handle-relative protected-file publication

Status: Accepted

Date: 2026-07-14

## Context

The Phase 2 human-copy runner originally rechecked source and destination paths
immediately before `[IO.File]::Copy`. A filesystem namespace could still change
between the final check and the path-based open. Path overwrite also follows a
destination hard-link alias and can change bytes visible through another name
outside the protected inventory.

## Decision

Embed an ASCII, C# 5-compatible `AnchoredCopySession` in the immutable Windows
PowerShell 5.1 runner. It opens a local accepted-filesystem repository root and
walks normalized relative names one segment at a time with `NtCreateFile`, an
`OBJECT_ATTRIBUTES.RootDirectory` directory handle, and
`FILE_OPEN_REPARSE_POINT`. It validates handle attributes and retains source
and destination-parent handles without write/delete sharing.

Canonical authority, manifest, and source bytes are read through anchored
handles. Every source is hashed and later copied through the same held handle.
After all source validation, the helper prepares, flushes, and re-hashes an
exclusive temporary file in each held destination parent. Only after every
temporary passes does it publish each target using
`SetFileInformationByHandle(FileRenameInfo)` with the destination parent handle
as `FILE_RENAME_INFO.RootDirectory` and a single leaf name. No path-based copy
fallback is permitted.

## Consequences

- Late source or destination-parent rename/delete/substitution cannot redirect
  the copy.
- Replacing a hard-linked destination changes the intended directory entry but
  not the other hard-link alias.
- A validation, preparation, capability, or cleanup failure occurs before any
  live replacement. All temporary handles are cleaned up.
- Each target rename is atomic, but the 18-target batch is not one transaction.
  A rename-time OS failure may leave a deterministic installed prefix and must
  be recovered with a reviewed full rollback batch. An isolated, fixture-only
  fixed-index failure test must prove the exact candidate-prefix/previous-
  suffix state and then prove rollback restores every recorded pre-install
  digest.
- The runner is intentionally limited to Windows PowerShell 5.1 Full Language
  mode on a local drive and a filesystem accepted by its native capability
  preflight; the reviewed minimum is NTFS.
- Existing per-file ACLs, alternate streams, and file identity are not promised
  to survive entry replacement. Git content and R-10 protection remain the
  integrity authority for these repository files.

## Verification

TEST-013 includes static native-contract checks, pre-existing link/reparse
denials, hard-link-alias preservation, held-source and destination-parent
substitution attempts, verified-temporary cleanup, no-live-change preparation
failure, and isolated post-install R-10 denial.
