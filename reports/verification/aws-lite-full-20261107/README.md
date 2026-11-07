# AWS development workflow validation — 2026-11-07

Baseline: origin/main `08398f03` (latest fetched at task start).
Issue: https://github.com/aharada54914/sdd-forge/issues/732

## Result

**Initial attempt: Lite and Full end-to-end Done were blocked by authentication.**
The isolated `verify-codex` profile was used for installation and a real model connectivity probe. The probe failed with HTTP 401 and a token-refresh authentication error before any workflow could run. Host-chat availability does not establish independent CLI authentication. No review verdict, human approval, Done state, or cloud observation was fabricated.

The cloud documentation also requires Full for production cloud runtime. A Lite local development example and a Full example require separate workflow runs after CLI authentication is restored. Live AWS acceptance additionally needs an explicit sandbox identity, scope and protected CI prerequisites; none are configured in this environment. Local fixture tests do not establish deployed AWS health.

## Installation defect and repair

The pre-existing verification marketplace pointed to the bare development checkout. Installing the opt-in AWS plugin into a materialized install root emitted `already added from a different source`, but the installer treated that as success. Codex then cached the bare AWS plugin without its required shared runtime.

Both installers now reject this conflict before plugin installation and explain recovery. Existing truly idempotent registration behavior is preserved. Added Bash and PowerShell regression cases pass. The isolated marketplace was explicitly re-registered from `/workspace/.tools/sdd-forge-dev/verification-install`; AWS cached runtime modules are now present. An installed CLI invocation returns the expected typed input-error envelope rather than SHARED_RUNTIME_UNAVAILABLE.

## Verification

- Bash installer idempotency: 8 passed, 0 failed.
- PowerShell installer idempotency: all scenarios passed, including source conflict.
- Cloud contracts/routing/execution/verification and packaging: see results.json. These are offline fixtures, not live cloud evidence.
- AWS native preparation: 28 passed, 0 skipped after installing locked Node 26.13.0 / CDK 2.1145.0 / aws-cdk-lib 2.273.0 / constructs 10.5.0. Official Node archive checksum verified; npm lifecycle scripts disabled. Actual synth, immutable validate, mutation denials and installed runtime boundary exercised. Azure native tools remain outside this AWS task.
- Workflow state fixtures: passed, including inaccessible-review fail-closed checks.
- Lite CLI chain: 8 passed, 0 failed.
- Lite full-upgrade backstop: 5 passed, 0 failed.
- Ship track selection: 161 passed, 0 failed.
- Workflow scenarios: 121 passed, 0 failed.
- `git diff --check`: passed.

Initial standalone shell invocations lacked Ruby/PowerShell on PATH. Repeating with the provided onboarding environment fixed the dependency setup; this was not a product defect.

Test evidence is in test-evidence.zip. Raw authentication logs are excluded. No repository-wide full-suite or live AWS validation is claimed.

## Continuation after reauthentication

A fresh user-approved device login succeeded. Its credential file was moved into the isolated verification profile without copying or changing host credentials. An actual independent model request returned READY. Earlier authentication failures above describe the initial attempt, not the current state.

Both normal bootstrap tracks then reproduced missing safe Codex handshake capture guidance (#737). The shared challenge now provides a Codex response template and native file-edit capture instructions. Both corrected native sessions produced HOOK_ACTIVE from their own real canary denials. Full then reproduced an unconditional optional domain-sync prerequisite even without domain/ (#738); the interviewer now preserves the existing absence/skip contract. Existing domain-sync regression: 25/25 passed with its supported Pester 4 syntax.

Lite source handling was narrowed to an explicit feature requirement file, excluding test-execution instructions from the risk input; the unchanged initial gate had conservatively matched the word credentials in those instructions. The generated Lite T-001 initially stopped at Draft/Planned. The actual user then explicitly approved T-001 through the asynchronous question; the harness recorded the user decision and exact artifact hashes in reports/bootstrap/user-approval.json before changing only the approval field. The normal installed ship entry is now running. No synthetic approval or Done has been inserted.

Full additionally encountered the already tracked native identity/allocation defect (#730). Existing product fixes from 6b2df273 and f996c4d0 were reused, excluding unrelated UI work and prior-task report artifacts. Identity, launcher, installed precheck, safe evidence-write, risk context, and review-order regression suites passed. Protected-boundary checks: 228 passed. Current native Full bootstrap is running against the integrated implementation. Candidate byte-pin fixtures were updated for intentional skill/runtime changes; frozen staged specifications remain unchanged and pins do not constitute approval.

Current machine-readable state: results.json. Native outcome evidence will be added after the running stage finishes. Full end-to-end Done remains unproven.
