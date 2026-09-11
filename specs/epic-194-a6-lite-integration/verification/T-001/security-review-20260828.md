# Security Review — apply-protected-files.ps1 (epic-194-a6-lite-integration)

- **Review date:** 2026-08-28
- **Reviewer:** independent security-reviewer agent, fresh context, distinct from any implementer (no prior conversational context on this feature; findings derived solely from reading the current bytes, the design/security-spec text, the test suites, and CI execution evidence pulled directly via `gh`)
- **Subject files** (digests measured by this reviewer with `shasum -a 256`, not trusted from any prior report):
  - runner script: `sha256: 5d72ec403b6f4c9161f23e71215d3b1f06a34f15f4c33360eb4b40eb246502f0` — matches the expected digest supplied in the review request.
  - manifest file: `sha256: 588b516ce03830e8635865ce8fea65908ece7d10b4e806151dd43082bf3183e6`
  - Every staged payload file's own digest was independently recomputed and matches its manifest entry exactly, for all five declared targets.

**VERDICT: PASS** — Critical: 0, High: 0, Medium: 0, Low: 2

This replaces the prior PASS on file, which covered a deleted predecessor draft with no recorded digest and explicitly declined to re-issue over the shipped runner. This review is issued against the current, hash-verified bytes above.

---

## Subject file paths (exact digests, repeated for clarity)

- Runner: specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1
  sha256 = 5d72ec403b6f4c9161f23e71215d3b1f06a34f15f4c33360eb4b40eb246502f0
- Manifest: specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256
  sha256 = 588b516ce03830e8635865ce8fea65908ece7d10b4e806151dd43082bf3183e6

## Scope Item 1 — Anchored path containment

Assert-AnchoredPath (lines 174-226) canonicalizes root and candidate via .NET's GetFullPath, enforces prefix containment with platform-correct ordinal / ordinal-ignore-case comparison (Get-PathStringComparison, lines 150-153, IsWindows-gated), rejects a symlink/reparse-point root, then walks every existing ancestor segment from root to leaf (lines 205-217) rejecting any that is a symlink/reparse point (Test-IsLinkOrReparsePoint, lines 165-172, checks both LinkType and the ReparsePoint attribute bit). This function is a lexical check-then-open, so it is used only for: establishing the repository root and human-copy root, reading staged files pre-copy, and re-reading installed files post-copy — never for the actual protected-file write, which instead goes through the handle-relative native publisher (Item 2). This separation is correct: the write path (the actual boundary this feature protects) is TOCTOU-safe by construction; the read-side checks are defense-in-depth. See Low finding 2 below for the residual read-side gap this implies.

Deterministic seam markers verified as inert comments, not executable code. Grepped all three literal marker tokens in the runner:
- the post-copy marker appears exactly once, on its own line as a PowerShell comment, immediately before the post-copy verification call.
- the Windows directory-open marker appears exactly once, on its own line as a C# comment, inside the Windows parent-open helper.
- the POSIX directory-open marker appears three times: two are prose mentions inside doc-comments (no comment-token immediately preceding the literal), and only one is the actual seam line (comment-token immediately preceding it). Confirmed against the test suite's own injection logic: it anchors on the full line (comment-token + marker + newline) via an exact-substring Replace, so it can only match the genuine comment-prefixed seam line, not the two bare prose mentions — the historical compile failure the suite's own comments document (from an earlier, unanchored substring replace) cannot recur with the current anchoring. All three markers are ordinary line comments in their respective host languages and cannot execute.

No finding.

## Scope Item 2 — Windows handle-relative publisher (A6AnchoredPublisher)

CopyOneWindows (lines 482-508) opens the repository root via CreateFileW with backup-semantics plus open-reparse-point flags (opens the reparse point itself rather than following it), then ValidateWindowsHandle (lines 549-556) rejects it if the reparse-point attribute is set. Every subsequent ancestor open (OpenWindowsParent -> OpenWindowsRelative, lines 518-547) uses NtCreateFile with RootDirectory set to the already-held parent handle (not a path string) and the open-reparse-point option, with ValidateWindowsHandle rejecting any reparse point at every hop — this is genuinely handle-relative, no-follow directory traversal, closing the TOCTOU window a path-based check-then-open would leave. The leaf-level source and destination opens use the same no-follow discipline. Rename uses SetFileInformationByHandle with the legacy rename-info class, falling back to NtSetInformationFile with the extended rename-information class on the specific error code that signals the newer struct layout is required (line 565) — a known compatibility split for the two FILE_RENAME_INFO struct layouts — and the rename target's parent is also handle-anchored, so the rename itself cannot be redirected by a path race either. Digest is verified three times per target: staged source before copy (line 491), temporary file after copy and before rename (line 495), and the reopened installed file after rename (line 499) — matching contract points 3 and 4.

New execution evidence confirmed directly (not taken on faith): GitHub Actions run 33149237065 (branch feature/epic-194-done-transitions, head commit a2880f288661a53b4092208b6934718c85549c17, confirmed via gh run view --json headSha) ran the runner-contract test suite on windows-latest. Correction to the initial task briefing: this suite is registered under the "version-gates" job, not the "test" job — this reviewer initially checked the wrong job (which does not include this suite) before finding it correctly registered under version-gates (windows-latest), and pulled that job's raw log directly:
- the four deterministic TOCTOU parent-substitution regression subtests all report pass at 2026-08-28T07:12:01Z.
- the full happy-path subtests (all five targets copied, renamed, and post-copy-verified) also report pass, meaning the rename path, not just the TOCTOU-rejection path, executed successfully.
- suite total: 55 passed, 0 failed (55 rather than 56 because the one POSIX-mode-preservation subtest correctly self-skips on Windows).

What this run proves: the native Windows publisher compiles and executes correctly on a real windows-latest GitHub-hosted runner, both its happy path and its TOCTOU-rejection path, under the fixture substitution the suite constructs (a disposable, patched copy of the runner source). What it does not prove: behavior on Windows Server editions other than the GitHub-hosted image, behavior under a genuine timing-based concurrent race rather than the fixture's synchronous substitution, or behavior against network-filesystem semantics (outside this feature's stated threat model, which is the local repository filesystem).

No finding.

## Scope Item 3 — Exact-set / manifest discipline

Test-ExactSet (lines 308-329) performs true three-way set equality (declared-vs-manifest, declared-vs-payload, each direction independently) using ordinal HashSet comparers, before any hash check or copy — correct ordering for contract point 2. Get-ManifestTargets (lines 278-306) rejects CRLF and bare-CR manifest content, enforces the canonical lowercase two-space-separator digest grammar, rejects any manifest target that is absolute, contains a backslash or colon, or has an empty/dot/dot-dot path segment, and rejects duplicate targets. Get-PayloadFileSet (lines 254-276) recursively enumerates the staged tree, fails closed on any symlink/reparse point found anywhere in it, and explicitly rejects a nested reserved subtree as payload rather than silently ignoring it.

Verified independently: recomputed sha256 of all five staged payload files against the manifest — exact match on every entry (see header). Verified the staged directory contains exactly the five declared targets plus the two control files (the manifest itself and the runner script) — no extraneous or missing payload members in the current staged tree.

Mis-cased-control platform-aware behavior (TEST-008 family) is sound. Test-IsControlRelativePath (lines 155-163) does an ordinal, case-sensitive exact match, so a mis-cased control filename is classified as ordinary payload, not control — correct on every platform. The suite then probes the fixture filesystem's actual case sensitivity at runtime (rather than branching on OS name) and asserts the platform-correct fail-closed diagnostic: on a case-insensitive filesystem the canonical manifest open still finds the mis-cased file, so the runner proceeds to the exact-set comparison and rejects the mis-cased name as undeclared payload; on a case-sensitive filesystem the canonical manifest is genuinely absent, so the runner fails closed earlier, at manifest resolution. Both lanes reject before any live copy — the diagnostic differs, the fail-closed outcome does not.

No finding.

## Scope Item 4 — Failure-path truthfulness (KNOWN OPEN MINOR, assessed not resolved)

Confirmed present in the current bytes, and confirmed to be exactly the mechanism described in the task briefing. Root cause, read directly from the code:

- Copy-Payload (lines 646-692) sets the script-scoped FailedTarget variable only inside its own three catch blocks, i.e. only when the native publisher itself throws for a given target.
- If Copy-Payload returns normally — every target published and self-verified by the native publisher before returning — the PublishedTargets list contains all declared targets and FailedTarget is still null.
- Test-PostCopyHashes (lines 694-711) is a second, independent re-verification pass over every declared target; if it finds a mismatch it throws, but this throw is caught only by the entry-point catch (lines 732-743), which never touches FailedTarget.
- Write-PublishStateReport (lines 120-148) therefore computes, in this specific case: published = all five targets, failed = null, not-attempted = empty — so it prints every target, including the one that just failed post-copy re-verification, under INSTALLED, with no FAILED line for it, followed by the footer claim that each was published atomically and its published digest verified.

This is a real, narrow correctness gap in the report's own internal consistency: the exception message printed immediately before this block already names the exact target and the mismatch (from Test-PostCopyHashes's own failure message) — but the enumerated live-state report directly below it then re-asserts, for that same target, that its digest was verified and it is correctly live.

Severity assessment: Low, for three concrete reasons distinguishable in the code and tests, not asserted on faith:
1. Not silent — the mismatch is reported to the operator, by name, in the line printed immediately above the misleading enumeration.
2. Fails closed regardless — the process still exits with a nonzero code; nothing downstream that gates on exit code is fooled.
3. Self-healing on the recommended recovery — Copy-Payload unconditionally re-copies and re-verifies every declared target on each invocation (it does not skip already-installed targets), so following the report's own stated recovery (re-run the runner) republishes and re-verifies the mislabeled target from the staged, hash-checked source regardless of what the prior report claimed about it.

The realistic trigger for this gap (a file changing between the native publisher's own internal post-publish digest check and the outer post-copy re-check moments later) requires an actor with write access to the destination file at that exact narrow window — a capability that already lets that actor tamper with the protected file directly, independent of this runner's own behavior. It is not a privilege-escalation or bypass of the write-boundary guarantee; it is a truthfulness defect in an already-fail-closed diagnostic path.

Missing test, confirmed by direct inspection of the suite: the existing post-copy-corruption subtests already construct exactly this scenario (corruption injected after Copy-Payload returns, via the runner's own deterministic after-copy seam) and assert the thrown message names the corrupted target — but stop there; they never inspect the live-state report's own INSTALLED/FAILED enumeration for that run. A separate mid-batch-failure test suite does assert report-vs-filesystem accuracy, but its fixture is the different scenario where Copy-Payload's own per-target catch fires (content changes during the copy, not after it) — FailedTarget is correctly set in that case, so that suite cannot and does not exercise the gap described above. No existing test asserts on the report text for the case where post-copy verification fails after Copy-Payload fully succeeded. A regression test here would assert that the corrupted target from the after-copy-corruption fixture is not shown as INSTALLED without qualification in the accompanying live-state report — currently it is.

## Scope Item 5 — Other findings

Low (residual, defense-in-depth note, not a bypass of the core write-boundary guarantee): the read-side verification paths — Assert-AnchoredPath's own lexical ancestor walk, and the sha256 read calls used in the pre-copy and post-copy hash checks — resolve by path string, not by an already-held directory handle, unlike the native publisher's write path. A local actor able to race a directory-ancestor swap during that narrow window could in principle cause a verification read to follow a substituted path. This does not weaken the write-boundary guarantee (the actual protected-file write always goes through the no-follow, handle-relative native publisher, proven correct on all three platforms by the CI evidence below) and requires the same ancestor-directory write capability that would already let an actor tamper with the protected files directly — i.e., it is not a capability the runner's own execution creates or extends. No action recommended beyond noting it; this matches the stated threat model (an implementation-phase agent is denied direct writes by the repository's existing protected-path guard; a human invoking this runner is the trusted actor the design assumes, not an adversary racing their own filesystem).

No other material findings. Copy-Payload's exception-classification correctly separates content-integrity/path-shape failures from genuine path-escape rejections, addressing a prior review comment about mislabeled diagnostics; the one Unix symlink-creation P/Invoke declared in the native publisher is provably never called on any production path (mechanically asserted by its own dedicated subtest, which passed locally); the source-file POSIX mode is read via the portable runtime API rather than a hand-derived struct-stat offset, closing a prior aarch64/x86-64 offset-divergence bug — and this is now exercised on genuine arm64 hardware via both this reviewer's own local run (Darwin arm64) and the macOS CI job (GitHub's macOS runners are Apple Silicon/arm64), not only the static log the runner's own comments cite.

## Execution evidence by platform

Platform | What ran | Result | Source
--- | --- | --- | ---
macOS (local, this review) | runner-contract pwsh suite, Darwin 25.5.0 arm64, PowerShell 7.6.2, run fresh by this reviewer | 56 passed, 0 failed (all subtests including the four TOCTOU regression subtests) | this session, direct execution
Linux CI (ubuntu-latest) | runner-contract bash suite and pwsh suite, GH Actions run 33149237065, version-gates job (ubuntu-latest), commit a2880f28 | 56/56 (bash) and 56/56 (pwsh), 0 failed each; TOCTOU subtests pass in both | gh run view --log, inspected directly
macOS CI (macos-latest) | same two suites, version-gates job (macos-latest) | 56/56 (bash) and 56/56 (pwsh), 0 failed each | gh run view --log, inspected directly
Windows CI (windows-latest) | runner-contract pwsh suite only (bash variant correctly self-skips on Windows), version-gates job (windows-latest) | 55 passed, 0 failed (one subtest self-skips, POSIX-only); TOCTOU subtests pass; full rename happy path passes | gh run view --log, inspected directly

What remains untested:
- No execution on Windows Server editions other than the windows-latest GitHub-hosted image; no execution on non-Apple-Silicon macOS or on a non-glibc/non-standard Linux libc.
- The TOCTOU tests are deterministic fixture substitutions (a patched, disposable copy of the source executed synchronously), not genuine timing-based concurrent races — appropriate for CI determinism, but they prove rejection of a specific substitution shape, not exhaustive coverage of every possible race window.
- The live-state report's INSTALLED/FAILED-enumeration accuracy gap identified in Scope Item 4 is not covered by any existing assertion, on any platform.
- No test exercises a genuinely corrupted/malicious manifest against the real, live five-target payload outside the fixture harness — the suite's own fixtures are synthetic trees, not the live directory. This is expected practice (tests should not mutate the live staged payload) and not itself a gap, but it means the exact-set logic's correctness against the live manifest was verified in this review only by independent digest recomputation (see header), not by driving the real CLI against a tampered copy of the live tree.
