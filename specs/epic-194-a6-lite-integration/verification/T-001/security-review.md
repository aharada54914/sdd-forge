# T-001 Independent Security Re-review

- Date: 2026-08-08
- Reviewer: `security_review_t001` (independent read-only agent; not implementer)
- Reviewed artifact: `specs/epic-194-a6-lite-integration/drafts/apply-protected-files.ps1`
- Independent command: `pwsh -NoProfile -File tests/human-copy-runner-contract.tests.ps1 -SecurityRegression ancestor-symlink -RunnerUnderTest specs/epic-194-a6-lite-integration/drafts/apply-protected-files.ps1`
- Independent result at review time: 31 passed, 0 failed (the implementer later added four manifest-set assertions; final full result is 45/45)
- Verdict: **PASS — Critical 0, High 0**

## Previously Critical boundaries

1. **Case-sensitive control/digest decisions: resolved.** Control names use
   `StringComparison.Ordinal`; manifest text is constrained to lowercase
   SHA-256 grammar; target/digest collections and comparisons are ordinal.
   TEST-008 exercises both a real CLI mis-cased-control rejection and an
   uppercase-digest rejection before any of the four live files changes.
2. **Ancestor symlink, canonical containment, and substitution race:
   resolved.** Lexical/canonical validation rejects escapes. POSIX publishing
   opens every segment relative to a held root/parent descriptor with
   `openat(O_NOFOLLOW|O_DIRECTORY)`, creates and renames the temporary relative
   to the held destination parent, then reopens and hashes it there. Windows
   performs segment-relative `NtCreateFile` using `RootDirectory` plus
   `FILE_OPEN_REPARSE_POINT`, validates handles, and uses a handle-relative
   rename/reopen. TEST-009 requires the deterministic substitution seam to
   execute and proves explicit rejection, external-canary preservation, and
   preservation of the moved repository live file.
3. **Recursive PROPOSED semantics: resolved.** Payload enumeration is recursive;
   only exact, ordinal control paths are excluded; a nested `PROPOSED/` path is
   explicitly rejected before exact-set/hash/copy processing. TEST-010 proves
   the diagnostic and that all four live targets remain unchanged.

## Nonblocking limitations

- The host is macOS, so the Windows fixture branch was reviewed statically but
  not executed on a Windows machine. The test now selects the Windows seam and
  prepared Junction on Windows; an actual Windows CI run remains desirable.
- A Windows failure after temporary creation can leave the temporary file as
  residue (Low/Medium operational risk, not a path-escape boundary).
- The POSIX source-mode extraction uses the validated macOS layout on this host
  and a Linux layout used by the intended x64 CI runner; non-x64 Linux remains
  unverified.

## Scope boundary

This PASS applies to the non-protected candidate only. The unchanged protected
runner remains the deliberately broken RED baseline and must not be used. The
candidate also must not be promoted until a human resolves the four-target /
fifth CI-target contradiction and applies the protected artifacts.
