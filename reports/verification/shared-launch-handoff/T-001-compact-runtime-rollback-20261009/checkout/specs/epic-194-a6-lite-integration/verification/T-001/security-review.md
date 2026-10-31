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

---

## Addendum 2026-08-25 — this PASS is stale against the shipped runner

Appended, not edited. Everything above is the 2026-08-08 record and stands as
what was reviewed then.

Two cross-model slots reported that this review's scope cannot be reconciled
with the artifact that shipped (T-001 Anthropic slot, Major). They are right,
and this addendum states the gap rather than leaving it implicit.

**The reviewed artifact no longer exists.** The header names
`specs/epic-194-a6-lite-integration/drafts/apply-protected-files.ps1`. That
path was deleted on promotion. No digest of the reviewed bytes was recorded,
so "the bytes are unmodified from the reviewed candidate" is not verifiable
from this document by any means, then or now.

**The shipped runner today is
`specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1`,
sha256 `15417bd5ef2d5bad46e8b9800d9d27a17a8df6c3fc578bfa3de57b49ab3688a8`.** Recording it here so that any FUTURE review of this file
has the comparison point this one lacked.

**Three substantive changes landed after this review, all of which touch
boundaries it assessed:**

1. `9997091c` widened the declared payload set from four targets to five.
   This review's own Scope boundary says the candidate "must not be promoted
   until a human resolves the four-target / fifth CI-target contradiction" --
   that precondition was resolved by widening, after this review was written.
2. `75fe25a3` replaced `SourceMode`'s hand-derived struct-stat byte offset
   with `File.GetUnixFileMode(SafeFileHandle)`. This review's own Nonblocking
   limitations flagged the risk in advance -- "non-x64 Linux remains
   unverified" -- and the cross-model panel later confirmed it concretely on
   aarch64 glibc, where offset 24 is `st_uid`, not `st_mode`.
3. `2499e813` replaced `Copy-Payload`'s single catch-all with three typed
   catches, so a content-integrity failure is no longer reported to the
   operator as a path-escape attempt.

**What this addendum does NOT do.** It does not re-issue the verdict. A PASS
over the current bytes requires a fresh independent security pass, which is
human-invoked. Until then the 2026-08-08 PASS should be read as scoped to a
predecessor artifact, not to what ships.

**Still unexecuted, unchanged from the original Nonblocking limitations:** the
Windows publisher path (NtCreateFile / SetFileInformationByHandle /
RtlNtStatusToDosError P/Invoke, the Windows rename, and reparse-point
validation) has been reviewed statically and never run. No log in this
feature's evidence shows it executing. That is a coverage gap a macOS host
cannot close.
