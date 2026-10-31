# T-006 Native rename API addendum

Date: 2026-07-15

The approved security property remains unchanged: publish a verified temporary
to a held destination parent by a single leaf-name, parent-handle-relative
atomic rename. The staged runner first calls
`SetFileInformationByHandle(FileRenameInfo)` with the reviewed
`FILE_RENAME_INFO` buffer. On the reviewed Windows PowerShell 5.1 / NTFS host,
that call returns `ERROR_INVALID_PARAMETER` (87) when `RootDirectory` is
non-null, even though the current API reference describes the relative-handle
form.

Only for that specific native API incompatibility, the runner calls the
equivalent user-mode native operation
`NtSetInformationFile(FileRenameInformation)` with the same temporary handle,
held parent handle, leaf name, replacement flag, and buffer. It does not use a
path name, current-directory lookup, or path-based copy fallback. Any other
`SetFileInformationByHandle` error, an `NtSetInformationFile` failure, or an
unavailable entry point fails before post-install verification.

The TEST-013 static contract and isolated fixtures bind both APIs and prove the
same hard-link, namespace-substitution, prefix-state, and rollback outcomes.
This non-frozen addendum records the host-compatibility correction without
altering the passed design artifact.
