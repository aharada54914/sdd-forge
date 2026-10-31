# Issue 427: Windows synthetic worker candidate

Status: local verification passed; Windows verification pending. Issue remains open.
Base: `5362378989f046a851b5005637abad6f942b1841`.
Worktree: `/private/tmp/sdd-427-retry`.
Authorized retry: 2026-09-26, candidate 2 of at most 3.

## Evidence and change

The latest issue evidence is run 36169716643 attempt 1, job 108186448021:
the synthetic Gemini boundary iteration 3 had no initial receipt and the
awaited process remained alive at timeout. The unchanged attempt 2 passed.
Neither observation locates the delay inside process scheduling, `.cmd`
startup, PowerShell initialization or receipt I/O.

The existing test starts nested PowerShell inside the measured process budget
(`tests/cross-model.tests.ps1:267-273` at the base). This candidate replaces
only the Windows worker with Python stdlib, resolved and probed before timed
execution. The `.cmd` wrapper remains. The existing Windows 3-second budget,
1200-ms deadline-relative margin, five repetitions per runner, six phase
receipts, genuine verdict parsing, hang/child checks and process observations
remain. Production runners and POSIX worker are unchanged.

This removes nested PowerShell initialization as one source of timed work;
it does not prove that initialization caused the reported Windows failure.
No process2 candidate was found in the existing worktrees. Its previously
reported two-second assumption is not adopted as a replacement for the
current Windows three-second test contract.

## Executed checks on macOS

- PowerShell parser: exit 0; no syntax errors.
- `pwsh -NoProfile -File tests/cross-model.tests.ps1`: exit 0,
  **78 passed / 0 failed**; completed session 65115. This exercises the
  unchanged POSIX worker and both production runners.
- Extracted Python worker: real JSON parsing, six phase receipts and exact
  deadline receipt passed. Two-second budget / 800-ms margin: startup 29 ms,
  elapsed 1206 ms, output before deadline; exit 0.
- Extracted Python worker: five repetitions of the Windows 3000-ms /
  1200-ms contract passed on macOS. Startup ms: 20, 34, 37, 40, 32.
  Output margin ms: 1189, 1189, 1189, 1190, 1189. Completed session 70741.
- Python hang mode: one-second timeout occurred, both PID receipts existed,
  and the spawned process group was killed and reaped by the diagnostic.
  This is not Windows `Kill(true)` proof; the Windows suite carries that
  existing assertion.
- `git diff --check`: exit 0.

Independent review found no Critical/Major findings and one cleanup gap:
interpreter detection preceded the cleanup `try/finally`. Candidate 2 moves
that existing cleanup boundary before fixture setup. A missing-command
failure was injected into the Windows branch in memory on macOS; it failed
as expected and left no newly created `sdd-cross-model-tests-*` directory.
No production source or persistent test input was changed by that check.

No terminal sessions remain active. Publication and Windows verification
follow separately; no merge, task status, review verdict or issue state is
changed by this local report.

## Remaining verification

The existing Windows worker branch now requires a functional Python 3.9+
command. Hosted CI already supplies Python, but the command probe fails
explicitly if an alias or unsupported interpreter is selected. Actual Windows
execution is **pending first real execution at CI/release time**: compare
startup receipts and run the full suite, including one-second timeout,
descendant cleanup and all ten boundary cases. macOS checks do not establish
Windows `.cmd` / interpreter behavior or eliminate scheduling jitter.
