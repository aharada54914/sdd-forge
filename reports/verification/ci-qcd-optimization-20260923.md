# Cross-platform CI QCD optimization (2026-09-23)

## Change

The `loops-routing` matrix now runs on `windows-latest` and `ubuntu-latest`.
The macOS leg was removed because this lane exercises file/manifest and
runtime-family parity checks that are already covered by Windows (native
PowerShell plus Git Bash) and Ubuntu (native Bash plus PowerShell). The
macOS-specific behavior remains covered by the existing platform-sensitive,
version-gate, installer, MCP, and hook jobs. No assertion, fixture, required
job, or platform-specific test was removed.

The POSIX `apply-human-copy` suites were already parallelized by merged PR
#466; this change does not duplicate or alter that implementation.

## Local verification

- `git diff --check`: PASS
- Workflow YAML parse with Ruby Psych: PASS
- `tests/ci-suite-wiring.tests.sh`: PASS (20 behavioral cases)
- `tests/apply-human-copy.tests.sh`: PASS
- `tests/apply-human-copy.tests.ps1`: PASS
- Full GitHub Actions workflow: pending until the PR head is available

The resulting lane uses two runners instead of three, a one-third reduction
for this platform-neutral job while preserving the cross-platform execution
families and all existing checks.

Patch artifact SHA-256:

`340f1a7ca2687b8123475d5c6b0bf9da546221ccb6212021c61d301dfb67fc8b`
