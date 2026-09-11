# PR #404: audit real resolver dependency skips

The Bash escalation suite previously rendered the allowlist without auditing
whether its dependencies had activated. PowerShell instead treated a specification
directory's presence as proof of integration. Neither path reliably enforced the
manifest's integration evidence for AC-004 and AC-021.

Both suites now render the same manifest-backed line and audit that actual output
against origin/main. Invalid evidence and activated dependencies fail the suite.
Zero spy invocations remain informational, not proof of resolver correctness.
No acceptance condition or existing test has been removed.

Verification on macOS with Bash and PowerShell:

- New PowerShell rendering assertion: failed before implementation (2 passed,
  1 failed); passed afterward (3 passed, 0 failed).
- Complete Bash allowlist suite: 16 passed, 0 failed.
- Complete PowerShell allowlist suite: 17 passed, 0 failed.
- New real-suite regression: 6 passed, 0 failed. Each runtime executes its full
  escalation suite with clean, activated, and invalid integration evidence.
  Clean exits 0 and audits a real line; both negative variants exit 1 and name
  the dependency evidence failure. The evaluator is not mocked.
- Bash syntax checks and git diff --check: exit 0.

Commands: bash tests/skip-allowlist-manifest.tests.sh;
pwsh -NoProfile -File tests/skip-allowlist-manifest.tests.ps1;
bash tests/escalation-skip-activation.tests.sh.

The new regression is registered in tests/run-all.sh and exercises PowerShell
when installed. A missing PowerShell executable is explicitly reported as SKIP,
not as tested parity. Local log: /tmp/pr404-escalation-activation-20260911.log.

Review of the scoped diff found no critical issue. Formal design findings,
latest-head CI, required independent approval, merge, and post-merge verification
remain outstanding; this report does not declare the Issue resolved.
