# Claude CLI installation repair

- Owner: `codex/ci-claude-postinstall`, isolated checkout.
- Base: `033b02b2895cfdf1d46930c1aa784d5a18785136`; initially clean.
- Scope: post-merge run 38459088093, job 115509286091 failed to execute
  Claude after npm reported its installation script was not authorized.
- Classification: routine CI dependency installation correction. No product
  guard, approval, evidence, identity or required-check semantics change.
- Contract: explicitly authorize only Claude's package installation script;
  require executable startup before the existing real CLI suites.
- Validation: reproduce missing initialization in an isolated installation,
  verify the npm 12 scoped authorization, test both actual workflow commands
  with success/install-failure/startup-failure fixtures, run CI inventory and
  mirror checks, independent diff review, exact-head CI and post-merge CI.
- Existing workflow suites and platform coverage must remain unchanged.

## Observed reproduction

Claude Code 2.1.296 installed with scripts disabled returned exit 1 from
`claude --version`; executing its installation script made the same invocation
return exit 0. This reproduces missing native initialization, not the exact
PowerShell `Exec format error` rendering in the failing macOS job.

## Executed validation

- The new regression rejects the original workflow's installation command.
- Both workflow commands: six success/install-failure/startup-failure cases pass.
- CI suite wiring: 21 checks pass; the regression is registered in the POSIX inventory.
- Human-copy freshness: six checks pass, zero failures; 19 unapplied mirrors
  remain informational and were not changed.
- An isolated npm 12.2.0 / Node 24.15.0 installation with the package-scoped
  authorization starts Claude Code 2.1.296 successfully. No global installation
  or authentication settings were changed.
- Independent read-only review: PASS, including comparison with the baseline
  diff and independent execution of the six fixtures and 21 wiring checks.

Exact-head CI and post-merge verification remain pending.
