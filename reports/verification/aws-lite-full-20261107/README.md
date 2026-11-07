# AWS development workflow validation — 2026-11-07

Baseline: origin/main `08398f03` (latest fetched at task start).
Issue: https://github.com/aharada54914/sdd-forge/issues/732

## Result

**Lite and Full end-to-end Done: BLOCKED, not demonstrated.**
The isolated `verify-codex` profile was used for installation and a real model connectivity probe. The probe failed with HTTP 401 and a token-refresh authentication error before any workflow could run. Host-chat availability does not establish independent CLI authentication. No review verdict, human approval, Done state, or cloud observation was fabricated.

The cloud documentation also requires Full for production cloud runtime. A Lite local development example and a Full example require separate workflow runs after CLI authentication is restored. Live AWS acceptance additionally needs an explicit sandbox identity, scope and protected CI prerequisites; none are configured in this environment. Local fixture tests do not establish deployed AWS health.

## Installation defect and repair

The pre-existing verification marketplace pointed to the bare development checkout. Installing the opt-in AWS plugin into a materialized install root emitted `already added from a different source`, but the installer treated that as success. Codex then cached the bare AWS plugin without its required shared runtime.

Both installers now reject this conflict before plugin installation and explain recovery. Existing truly idempotent registration behavior is preserved. Added Bash and PowerShell regression cases pass. The isolated marketplace was explicitly re-registered from `/workspace/.tools/sdd-forge-dev/verification-install`; AWS cached runtime modules are now present. An installed CLI invocation returns the expected typed input-error envelope rather than SHARED_RUNTIME_UNAVAILABLE.

## Verification

- Bash installer idempotency: 8 passed, 0 failed.
- PowerShell installer idempotency: all scenarios passed, including source conflict.
- Cloud contracts/routing/execution/verification and packaging: see results.json. These are offline fixtures, not live cloud evidence.
- Lite CLI chain: 8 passed, 0 failed.
- Lite full-upgrade backstop: 5 passed, 0 failed.
- Ship track selection: 161 passed, 0 failed.
- Workflow scenarios: 121 passed, 0 failed.
- `git diff --check`: passed.

Initial standalone shell invocations lacked Ruby/PowerShell on PATH. Repeating with the provided onboarding environment fixed the dependency setup; this was not a product defect.

Test evidence is in test-evidence.zip. Raw authentication logs are excluded. No repository-wide full-suite or live AWS validation is claimed.
