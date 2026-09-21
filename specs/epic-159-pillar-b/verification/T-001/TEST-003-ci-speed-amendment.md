# T-001 TEST-003 CI-speed amendment

Date: 2026-09-22
Scope: `tests/bump-version-gate.tests.sh` and
`tests/bump-version-gate.tests.ps1` TEST-003 only.

## Decision

The fixture-only ordering probe uses a minimal passing
`loop-consistency.tests.sh` stub that writes an execution sentinel. The
fixture's failing `loop-inventory.tests.sh` stub consumes that sentinel and
then exits non-zero. This preserves the assertions that the first gate leg
ran, the second leg fails closed, and the fixture has zero Git mutations,
without executing the full loop-consistency suite a second time in the same
version-gate test process.

This is a test-fixture optimization, not a production bypass or a replacement
for the real suite. The unmodified loop-consistency and loop-inventory suites
remain executed independently by the `loops-routing` CI lane in
`.github/workflows/test.yml`.

## Freeze and traceability

The passed `requirements.md`, `design.md`, `acceptance-tests.md`, and
`tasks.md` artifacts are unchanged. This addendum records the implementation
interpretation for the optimization and supersedes only the fixture mechanism
used by TEST-003; it does not change the acceptance outcome or remove any
required CI check. The PowerShell and POSIX twins use the same sentinel
contract.

## Evidence

- Bash focused suite: TEST-003 marker, fail-closed, and zero-mutation checks
  pass; full result is recorded in the implementation run.
- PowerShell focused suite: the same TEST-003 assertions pass.
- Dedicated `loops-routing` workflow continues to invoke both real suites.
