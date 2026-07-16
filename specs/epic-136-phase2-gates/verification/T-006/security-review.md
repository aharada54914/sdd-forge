# T-006 Security Review

Date: 2026-07-15

Scope: staged candidate `human-copy/specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`, TEST-013 fixture coverage, and its staged manifest binding. No protected live file was reviewed as changed.

## Result

PASS for the staged implementation, subject to the task's independent critical-tier gates.

## Verified controls

- The runner accepts only normalized, repository-relative inventory paths and validates canonical data, manifest membership, ordering, and lowercase SHA-256 digests before publication.
- Windows PowerShell 5.1 FullLanguage, local fixed NTFS, and native API availability are required before a live replacement; unsupported capability fails closed.
- Canonical data, manifest, and each staged source are opened by a root-handle-relative, no-follow walk. Each source is hashed and copied from the same retained handle; no path-based copy or source-hash fallback remains.
- Destination parent handles are retained during preparation and publication. Every same-parent temporary is flushed and re-hashed before the first replacement.
- Publication uses handle-relative rename. The only `SetFileInformationByHandle` fallback is Win32 error 87 to `NtSetInformationFile` with the same parent and temporary handles; any other failure aborts without a path fallback.
- TEST-013 covers path escape, final/intermediate reparse, hard-link preservation, late source and namespace substitution, preparation cleanup, fixed-index rename failure, full rollback, native API absence, and post-install protected-write denial.
- Targeted secret scan found no credential, token, private key, or API-key literal in the staged runner, TEST-013 test source, or T-006 evidence.

## Residual operational constraints

- The runner is intentionally Windows/NTFS/PowerShell-5.1 specific and must be executed only by the human-copy procedure.
- It replaces file contents only; it does not claim to preserve unrelated ACL or alternate-data-stream metadata.
- Cross-model consensus, signed evidence, a distinct second human approval, human execution of the reviewed protected copy, and an independent quality-gate PASS remain mandatory before T-006 can become Done.
