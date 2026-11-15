# Session model selection implementation

Date: 2026-11-15 UTC
Run ID: work-session-model-selection-20261115
Task Attempt Count: 1
Status: implementation and independent review in progress; not a consumer SDD Done verdict

## Development authorization

The user explicitly authorized local development skills, independent review and tests
instead of the normal consumer SDD approval workflow for this Work session after
both the hook canary and Project Context key dependency were diagnosed. No native
runtime attestation, Project Context approval or review PASS was fabricated.
The original requirements are preserved in session-model-selection-readiness.md.

## Changes

- Project-private preferences, separate per-host main settings, per-role choices,
  supported effort choices, disabled optional roles, explicit session confirmation.
- Startup context hooks for Claude/Codex, a Gemini model-selection extension,
  bootstrap/ship fallback, and manual selection/reselection commands.
- Honest listed/unverified candidates; Codex documented discovery reused; no
  inference calls, credential-file reads or automatic login during discovery.
- Confirmed preferences bridge to pinned policy requests, isolated Codex reviewers,
  and the unchanged vendor panelist collection boundaries.
- Gemini install/uninstall registration parity and public JSON schema/ADR/user guide.

## Material limits

Main model switching uses the native CLI UI and explicit user acknowledgment.
A saved preference is never a proof of model delivery or inference access.
No generic Gemini independent-review adapter exists; unsupported routes stop and
require reselection rather than bypassing isolation. Claude/Gemini CLI binaries
are absent here, so their live startup and model execution remain unverified.

## Verification so far

- session-models.tests.py: 33 tests passed.
- codex-review-launcher.tests.py: 20 passed, 1 opt-in live permission test skipped.
- Existing hook diagnostic suites from the preceding checkpoint: 985 shell
  assertions plus 12 Python tests passed; approval-sidecar suite: 50 passed.
- Further installer/package/regression checks and final independent review pending.
