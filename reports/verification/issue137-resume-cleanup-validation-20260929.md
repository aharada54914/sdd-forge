# Issue 137: Resume/Cleanup input admission

Scope: approved `sdd-context-continuity` T-001 validation only. Resume does not restore a session; Cleanup does not delete files or change OS registration.

## RED checkpoint

- Source commit: `d8ab554fd5460a97ad6dd508d4965ec7f315aad7`.
- Command: `rtk proxy node --test tests/sdd-context/validation.test.mjs`.
- Actual macOS execution: 79 tests, 75 passed, 4 failed, 0 skipped; exit 1.
- The prior 66 cases remained unchanged and all passed. The four failures were valid same-owner Resume and valid Cleanup IDs at 1-byte, 1024-byte ASCII, and 1024-byte UTF-8 boundaries, rejected by the unimplemented contract branch.
- Nine added negative cases passed the existing default rejection; this alone does not prove their field checks after implementation.
- Source SHA-256 remained `2eaa0ea4adb0ae972569aa7df896c61210da99bd267b98bba843d5c1a1e74f17`.
- Fixed test SHA-256: `2920de6f167bdc8af3aa4a2a94fa461c5aa5741e59e9a9fe0544cd33d582e20e`.
- RED stdout SHA-256: `2c8f016dce3543eda4aa2fa9867ce5ab4ae51c055ec81591fe9e9e1cc1e76f4d`; stderr was empty.

## GREEN and regression verification

- RED checkpoint commit: `9673af8cfd8701d122964abe4dbe0ff5aee2931a`.
- Production fix: nine added lines reuse the existing closed-object, owner and UTF-8 identifier checks; both branches retain shared deadline, Git and path validation. Every supplied predecessor remains rejected until independent relationship proof is implemented by T-003.
- The fixed 79-case validation suite passed once: 79 passed, 0 failed, 0 skipped; exit 0. No test bytes changed after RED.
- Existing JSON admission and privacy regressions passed once: 31 passed, 0 failed, 0 skipped; exit 0. The 79-case suite was not rerun for this check.
- Source SHA-256: `5dccf1bf3d739a10b2fd565122771ce4e69c22e41562dd1ac4200f33aca7e9d6`.
- GREEN stdout SHA-256: `47f22bc4b428240a405a15195479ff54272cfc5bef26adcf503401b58b4b7a89`; regression stdout SHA-256: `07a2f71829c4a36fac47f6ff4bce0b710a48704edc03066eb47fc17ec3377a36`. Both stderr files were empty.
- An independent ordinary read-only code review found 0 Critical, 0 Major and 0 Minor findings; it verified source, fixed-test, diff and saved-log hashes without rerunning tests. This is not a formal quality-gate verdict.

This delivers input admission only. Production callers, restoration, deletion, native activation, cross-platform CI, broader T-001 completion, formal quality gate, merge and Issue closure remain unverified. T-001 stays Approved / In Progress.
